import Foundation
import FoundationModels
import SymbolGraphIndex

/// Summarizes a framework's new APIs with the on-device language model.
///
/// The summarizer splits an oversized payload into chunks, makes a digest
/// for each chunk, and merges the digests into one summary.
public nonisolated enum FrameworkSummarizer {
  /// A Boolean value that indicates whether the on-device model can run.
  public static var isAvailable: Bool {
    SystemLanguageModel.default.isAvailable
  }

  /// The payload size threshold that keeps a request in the model's 4,000
  /// token context window, with room left for the instructions, the prompt
  /// scaffold, and the generated response.
  ///
  /// Identifier-dense text tokenizes at roughly three bytes per token, so
  /// this budget spends about 3,200 of the window's tokens on the payload.
  public static let payloadByteBudget = 8000

  // Below this floor a request cannot be meaningfully smaller, so the
  // overflow retry stops halving and the error propagates.
  private static let minimumPayloadByteBudget = 2000

  /// The largest number of new symbols that gets a fixed sentence instead
  /// of a model digest.
  public static let smallDeltaLimit = 4

  // Validate prompt and instruction changes with the eval harness in
  // `Evals/` before shipping.
  private static let instructions = """
  You summarize new Apple framework APIs for a developer audience. Write \
  one paragraph of plain prose. Never use bullet points, bold text, \
  headings, or a symbol-by-symbol list. Group members under the type that \
  owns them and name only the most notable types. A type line may end with \
  a colon followed by its documentation abstract. Base descriptions on \
  those abstracts, describe only what the symbol list shows, and never \
  guess at behavior the names don't state. After first mentioning a symbol, \
  refer to it by its short name. Never say an addition simplifies, \
  enhances, improves, or makes something easier. State what each addition \
  is, not its benefits, and write no closing sentence about what the \
  framework enables.
  """

  /// Returns a digest of the framework's new-symbol tree for the given
  /// releases. The method runs off the caller's actor.
  ///
  /// - Parameters:
  ///   - module: The framework name.
  ///   - releasesLabel: The label naming the selected releases.
  ///   - tree: The framework's new-symbol tree to digest.
  /// - Returns: The digest text.
  /// - Throws: An error when the on-device language model fails to generate
  ///   a response.
  @concurrent
  public static func summarize(
    module: String, releasesLabel: String,
    tree: [SymbolTreeNode]
  ) async throws -> String {
    let matchCount = NewAPIExport.matchCount(in: tree)
    if matchCount <= smallDeltaLimit {
      return NewAPIExport.plainDigest(module: module, tree: tree)
    }
    return try await summarize(
      module: module, releasesLabel: releasesLabel, tree: tree,
      matchCount: matchCount, budget: payloadByteBudget
    )
  }

  // MARK: - Private

  private static func summarize(
    module: String, releasesLabel: String, tree: [SymbolTreeNode],
    matchCount: Int, budget: Int
  ) async throws -> String {
    do {
      return try await attempt(
        module: module, releasesLabel: releasesLabel, tree: tree,
        matchCount: matchCount, budget: budget
      )
    } catch let error
      where isContextOverflow(error) && budget / 2 >= minimumPayloadByteBudget
    {
      // The bytes-per-token estimate behind the budget is imprecise.
      return try await summarize(
        module: module, releasesLabel: releasesLabel, tree: tree,
        matchCount: matchCount, budget: budget / 2
      )
    }
  }

  private static func attempt(
    module: String, releasesLabel: String, tree: [SymbolTreeNode],
    matchCount: Int, budget: Int
  ) async throws -> String {
    let sentenceTarget = Self.sentenceTarget(for: matchCount)
    let full = NewAPIExport.modelLines(tree: tree)
    if full.utf8.count <= budget {
      let text = try await digest(
        module: module, releasesLabel: releasesLabel,
        payload: full, isPartial: false, sentenceLimit: sentenceTarget
      )
      return try await polish(text, sentenceLimit: sentenceTarget)
    }

    let chunks = pack(NewAPIExport.modelLineChunks(tree: tree), budget: budget)
    var partials: [String] = []
    for chunk in chunks {
      try await partials.append(
        digest(
          module: module, releasesLabel: releasesLabel, payload: chunk,
          isPartial: true, sentenceLimit: partialSentenceLimit
        )
      )
    }
    guard partials.count > 1 else {
      return try await polish(
        partials.first ?? "", sentenceLimit: sentenceTarget
      )
    }
    let merged = try await merge(
      partials, module: module, releasesLabel: releasesLabel,
      sentenceLimit: sentenceTarget, budget: budget
    )
    return try await polish(merged, sentenceLimit: sentenceTarget)
  }

  private static func isContextOverflow(_ error: any Error) -> Bool {
    if let generationError = error as? LanguageModelSession.GenerationError,
       case .exceededContextWindowSize = generationError
    {
      return true
    }
    return false
  }

  /// Returns the sentence cap for a digest of the given size.
  ///
  /// - Parameter matchCount: The number of new symbols in the digest.
  /// - Returns: The maximum sentence count for the digest.
  public static func sentenceTarget(for matchCount: Int) -> Int {
    switch matchCount {
    case ..<15: 2
    case ..<60: 3
    case ..<150: 4
    default: 6
    }
  }

  // A short cap keeps the merge input small.
  private static let partialSentenceLimit = 3

  private static func digest(
    module: String, releasesLabel: String, payload: String, isPartial: Bool,
    sentenceLimit: Int
  ) async throws -> String {
    let session = LanguageModelSession(instructions: instructions)
    let scope =
      isPartial
        ? "part of the list of symbols newly introduced"
        : "the symbols newly introduced"
    let prompt = """
    Summarize \(scope) in the \(module) framework. \(releasesLabel). Write \
    at most \(sentenceLimit) sentences.

    \(payload)
    """
    return try await session.respond(to: prompt).content
  }

  // A wide release selection can produce more partials than one merge
  // request can hold, so the merge runs in rounds.
  private static func merge(
    _ partials: [String], module: String, releasesLabel: String,
    sentenceLimit: Int, budget: Int
  ) async throws -> String {
    var current = partials
    while current.count > 1 {
      let groups = mergeGroups(current, budget: budget)
      if groups.count == 1 {
        return try await mergeOnce(
          groups[0], module: module, releasesLabel: releasesLabel,
          sentenceLimit: sentenceLimit
        )
      }
      guard groups.count < current.count else {
        return try await mergeOnce(
          current, module: module, releasesLabel: releasesLabel,
          sentenceLimit: sentenceLimit
        )
      }
      var reduced: [String] = []
      for group in groups {
        try await reduced.append(
          mergeOnce(
            group, module: module, releasesLabel: releasesLabel,
            sentenceLimit: partialSentenceLimit
          )
        )
      }
      current = reduced
    }
    return current.first ?? ""
  }

  private static func mergeGroups(_ partials: [String], budget: Int)
    -> [[String]]
  {
    var groups: [[String]] = []
    var group: [String] = []
    var size = 0
    for partial in partials {
      let cost = partial.utf8.count + 2
      if !group.isEmpty, size + cost > budget {
        groups.append(group)
        group = []
        size = 0
      }
      group.append(partial)
      size += cost
    }
    if !group.isEmpty { groups.append(group) }
    return groups
  }

  private static func mergeOnce(
    _ partials: [String], module: String, releasesLabel: String,
    sentenceLimit: Int
  ) async throws -> String {
    let session = LanguageModelSession(instructions: instructions)
    let prompt = """
    Combine these partial summaries of the \(module) framework's new APIs \
    into one digest of at most \(sentenceLimit) sentences. \(releasesLabel).

    \(partials.joined(separator: "\n\n"))
    """
    return try await session.respond(to: prompt).content
  }

  private static func polish(_ text: String, sentenceLimit: Int) async throws
    -> String
  {
    var result = text
    if looksLikeList(result) {
      result = try await rewrite(
        result,
        as:
        "one paragraph of plain prose with no lists, bold text, or headings, keeping every fact"
      )
    }
    if sentenceCount(result) > sentenceLimit + 1 {
      result = try await rewrite(
        result,
        as:
        "at most \(sentenceLimit) sentences, keeping only the most notable additions"
      )
    }
    // The model cannot count sentences reliably. If a rewrite is still too
    // long, the method cuts it at a sentence boundary and does not retry.
    if sentenceCount(result) > sentenceLimit + 1 {
      result = truncated(result, toSentences: sentenceLimit + 1)
    }
    return result
  }

  private static func truncated(_ text: String, toSentences limit: Int)
    -> String
  {
    let boundaries = text.ranges(of: /[.!?]+(?:\s+|$)/)
    guard boundaries.count > limit else { return text }
    return String(text[..<boundaries[limit - 1].upperBound])
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static func rewrite(_ text: String, as target: String) async throws
    -> String
  {
    let session = LanguageModelSession(instructions: instructions)
    let prompt = """
    Rewrite this as \(target).

    \(text)
    """
    let rewritten = try await session.respond(to: prompt).content
    return rewritten.replacingOccurrences(of: "**", with: "")
  }

  private static func looksLikeList(_ text: String) -> Bool {
    text.contains("**") || text.contains("##")
      || text.range(
        of: #"(?m)^\s*(?:[-•*+]|\d+[.)])\s"#, options: .regularExpression
      )
      != nil
      || text.range(of: #"\*[^*\n]+\*"#, options: .regularExpression) != nil
  }

  private static func sentenceCount(_ text: String) -> Int {
    text.ranges(of: /[.!?]+(?:\s+|$)/).count
  }

  // The method truncates an oversized block instead of dropping it. Every
  // subtree stays present in the output.
  private static func pack(_ blocks: [String], budget: Int) -> [String] {
    var chunks: [String] = []
    var current = ""
    for block in blocks {
      let trimmed = truncate(block, at: budget)
      if current.isEmpty {
        current = trimmed
      } else if current.utf8.count + trimmed.utf8.count + 1 <= budget {
        current += "\n" + trimmed
      } else {
        chunks.append(current)
        current = trimmed
      }
    }
    if !current.isEmpty { chunks.append(current) }
    return chunks
  }

  private static func truncate(_ block: String, at budget: Int) -> String {
    guard block.utf8.count > budget else { return block }
    var kept: [Substring] = []
    var size = 0
    for line in block.split(separator: "\n") {
      size += line.utf8.count + 1
      if size > budget { break }
      kept.append(line)
    }
    return kept.joined(separator: "\n")
  }
}
