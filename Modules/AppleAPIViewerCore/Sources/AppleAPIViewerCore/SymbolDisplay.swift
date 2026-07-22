import Foundation
import SymbolGraphIndex

/// Presentation helpers mapping a symbol kind to a label and SF Symbol.
public nonisolated enum SymbolDisplay {
  /// Returns a localized, human-readable name for a symbol kind, for
  /// example "Instance method".
  ///
  /// - Parameter kind: The symbol kind to name.
  /// - Returns: The localized, human-readable name.
  public static func label(for kind: SymbolKind) -> String {
    let label: String.LocalizationValue =
      switch kind {
      case .class: "Class"
      case .structure: "Struct"
      case .enumeration: "Enum"
      case .protocol: "Protocol"
      case .typeAlias: "Type alias"
      case .associatedType: "Associated type"
      case .method: "Instance method"
      case .typeMethod: "Type method"
      case .initializer: "Initializer"
      case .property: "Instance property"
      case .typeProperty: "Type property"
      case .enumCase: "Enum case"
      case .subscript: "Subscript"
      case .operator: "Operator"
      case .function: "Func"
      case .variable: "Var"
      case .macro: "Macro"
      case .other: "Symbol"
      }
    return String(localized: label)
  }

  /// Returns an SF Symbol name. Every kind maps to a name in the system
  /// symbol set.
  ///
  /// - Parameter kind: The symbol kind to name.
  /// - Returns: The SF Symbol name.
  public static func systemImageName(for kind: SymbolKind) -> String {
    switch kind {
    case .class: "c.square"
    case .structure: "s.square"
    case .enumeration: "e.square"
    case .protocol: "p.square"
    case .typeAlias: "t.square"
    case .associatedType: "a.square"
    case .method, .typeMethod: "m.square"
    case .function: "function"
    case .operator: "plusminus"
    case .property, .typeProperty: "p.circle"
    case .initializer: "i.square"
    case .enumCase: "e.circle"
    case .subscript: "s.circle"
    case .variable: "v.square"
    case .macro: "number"
    case .other: "questionmark.square"
    }
  }
}
