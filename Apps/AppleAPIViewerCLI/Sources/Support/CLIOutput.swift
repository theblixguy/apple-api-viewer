import CoreModel
import Foundation
import SymbolGraphIndex

enum JSONLine {
  static func string(_ value: some Encodable) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    guard let data = try? encoder.encode(value),
          let string = String(data: data, encoding: .utf8)
    else {
      return "null"
    }
    return string
  }
}

func emit<Item: Encodable>(
  _ items: [Item], as format: OutputFormat, line: (Item) -> String
) {
  switch format {
  case .json:
    print(JSONLine.string(items))
  case .text:
    if items.isEmpty {
      print("No results.")
    } else {
      for item in items { print(line(item)) }
    }
  }
}

func emitOne(
  _ value: some Encodable, as format: OutputFormat, line: () -> String
) {
  switch format {
  case .json: print(JSONLine.string(value))
  case .text: print(line())
  }
}

func introducedReleases(_ symbol: IndexedSymbol) -> [String: String] {
  var result: [String: String] = [:]
  for (platform, version) in symbol.introduced where !version.isUnversioned {
    result[platform.rawValue] = version.description
  }
  return result
}
