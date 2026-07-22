// Lexicographic comparison of raw Xcode build strings misorders builds whose
// numeric run differs in width. For example, `17F65` sorts above `17F113`.
// `XcodeBuildNumber` parses the leading number, the train letters, the build
// number, and any rebuild suffix so comparison orders them correctly.
struct XcodeBuildNumber: Comparable {
  private let major: Int
  private let train: String
  private let number: Int
  private let suffix: String

  init(_ raw: String) {
    var rest = Substring(raw)
    func take(while predicate: (Character) -> Bool) -> Substring {
      let end = rest.firstIndex { !predicate($0) } ?? rest.endIndex
      defer { rest = rest[end...] }
      return rest[..<end]
    }
    major = Int(take(while: \.isNumber)) ?? 0
    train = String(take(while: \.isLetter))
    number = Int(take(while: \.isNumber)) ?? 0
    suffix = String(rest)
  }

  static func < (lhs: XcodeBuildNumber, rhs: XcodeBuildNumber) -> Bool {
    (lhs.major, lhs.train, lhs.number, lhs.suffix)
      < (rhs.major, rhs.train, rhs.number, rhs.suffix)
  }
}
