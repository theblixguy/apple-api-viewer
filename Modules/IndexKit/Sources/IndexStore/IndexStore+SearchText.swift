import SymbolGraphIndex

extension IndexStore {
  static func ftsMatchExpression(for query: String) -> String? {
    // Splitting on non-alphanumeric boundaries keeps FTS5 operator
    // characters out of the match expression. Quoting each token keeps a
    // bare uppercase keyword, NOT, AND, or OR, from parsing as an
    // operator.
    let tokens = query.split { !$0.isLetter && !$0.isNumber }.map(String.init)
    guard !tokens.isEmpty else { return nil }
    return tokens.map { "\"\($0)\"*" }.joined(separator: " ")
  }

  static func searchText(for symbol: IndexedSymbol) -> String {
    "\(splitIdentifierWords(symbol.name)) \(symbol.name) \(symbol.title)"
  }

  static func splitIdentifierWords(_ identifier: String) -> String {
    let characters = Array(identifier)
    var result = ""
    result.reserveCapacity(characters.count + 4)
    for index in characters.indices {
      let current = characters[index]
      if index > 0 {
        let previous = characters[index - 1]
        let next = index + 1 < characters.count ? characters[index + 1] : nil
        let lowerToUpper = previous.isLowercase && current.isUppercase
        let acronymToWord =
          previous.isUppercase && current.isUppercase
            && (next?.isLowercase ?? false)
        let letterDigitBoundary =
          (previous.isLetter && current.isNumber)
            || (previous.isNumber && current.isLetter)
        if lowerToUpper || acronymToWord || letterDigitBoundary {
          result.append(" ")
        }
      }
      result.append(current)
    }
    return result
  }
}
