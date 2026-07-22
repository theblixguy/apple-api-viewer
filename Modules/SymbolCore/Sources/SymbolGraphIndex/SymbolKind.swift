/// The kind of a symbol, normalized from the symbol-graph kind identifier.
///
/// This identifier arrives language-prefixed, for example `swift.struct` or
/// `swift.enum.case`.
public enum SymbolKind: String, Sendable, Codable, Hashable, CaseIterable {
  /// A class declaration.
  case `class`
  /// A structure declaration.
  case structure
  /// An enumeration declaration.
  case enumeration
  /// A protocol declaration.
  case `protocol`
  /// A type alias.
  case typeAlias
  /// An associated type requirement.
  case associatedType
  /// An instance method.
  case method
  /// A static or class method.
  case typeMethod
  /// An initializer.
  case initializer
  /// An instance property.
  case property
  /// A static or class property.
  case typeProperty
  /// An enumeration case.
  case enumCase
  /// A subscript, instance or type.
  case `subscript`
  /// An operator function.
  case `operator`
  /// A free function.
  case function
  /// A global variable.
  case variable
  /// A macro declaration.
  case macro
  /// A kind the parser does not classify.
  case other

  init(symbolGraphIdentifier identifier: String) {
    switch identifier {
    case "class": self = .class
    case "struct": self = .structure
    case "enum": self = .enumeration
    case "protocol": self = .protocol
    case "typealias": self = .typeAlias
    case "associatedtype": self = .associatedType
    case "method": self = .method
    case "type.method": self = .typeMethod
    case "init": self = .initializer
    case "property": self = .property
    case "type.property": self = .typeProperty
    case "enum.case": self = .enumCase
    case "subscript", "type.subscript": self = .subscript
    case "func.op": self = .operator
    case "func": self = .function
    case "var": self = .variable
    case "macro": self = .macro
    default: self = .other
    }
  }
}
