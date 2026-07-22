import SwiftUI

nonisolated enum Spacing {
  static let xxSmall: CGFloat = 2
  static let xSmall: CGFloat = 4
  static let small: CGFloat = 8
  static let medium: CGFloat = 12
  static let large: CGFloat = 16
  static let xLarge: CGFloat = 20
  static let xxLarge: CGFloat = 24
  static let huge: CGFloat = 40
}

nonisolated enum CornerRadius {
  static let card: CGFloat = 24
  static let inset: CGFloat = 10
  static let menuRow: CGFloat = 6
}

nonisolated enum IconSize {
  static let kindGlyphWidth: CGFloat = 20
  static let detailHeader: CGFloat = 34
  static let statusGlyph: CGFloat = 40
}

nonisolated enum Typography {
  static let cardTitle = Font.title2.weight(.semibold)
  static let detailTitle = Font.title.weight(.semibold)
  static let sectionLabel = Font.caption2.weight(.semibold)
  static let badge = Font.caption2.weight(.bold)
  static let codePath = Font.caption.monospaced()
}

nonisolated enum Metrics {
  static let windowMinWidth: CGFloat = 960
  static let windowMinHeight: CGFloat = 640
  static let windowDefaultWidth: CGFloat = 1100
  static let windowDefaultHeight: CGFloat = 720

  static let cardWidth: CGFloat = 360
  static let cardContentMaxWidth: CGFloat = 360
  static let platformLabelWidth: CGFloat = 72

  static let versionButtonLabelWidth: CGFloat = 80
  static let versionPopoverWidth: CGFloat = 200
  static let versionPopoverHeight: CGFloat = 220
  static let versionRowHeight: CGFloat = 24

  static let kindPopoverWidth: CGFloat = 230
  static let kindPopoverHeight: CGFloat = 320

  static let menuBarWidth: CGFloat = 320
  static let menuBarListHeight: CGFloat = 280
  static let menuBarEmptyHeight: CGFloat = 60
  static let menuBarResultLimit = 30

  enum Column {
    static let sidebarMin: CGFloat = 240
    static let sidebarIdeal: CGFloat = 290
    static let sidebarMax: CGFloat = 360
    static let contentMin: CGFloat = 300
    static let contentIdeal: CGFloat = 380
    static let contentMax: CGFloat = 540
    static let detailMin: CGFloat = 360
    static let detailIdeal: CGFloat = 520
  }
}
