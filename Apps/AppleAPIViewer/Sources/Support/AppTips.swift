import SwiftUI
import TipKit

// The UI gives no other hint that tree rows expand on double-click.
// This tip points that out.
struct DoubleClickTreeTip: Tip {
  var title: Text {
    Text("Double-click to expand")
  }

  var message: Text? {
    Text(
      "Double-click a row to expand or collapse it. Double-clicking an API opens its documentation."
    )
  }

  var image: Image? {
    Image(systemName: "cursorarrow.motionlines.click")
  }

  var options: [any TipOption] {
    MaxDisplayCount(3)
  }
}

struct PerXcodeIndexTip: Tip {
  var title: Text {
    Text("One index per Xcode")
  }

  var message: Text? {
    Text(
      "Each Xcode keeps its own index, so switching to one you've indexed before is instant."
    )
  }

  var image: Image? {
    Image(systemName: "square.stack.3d.up")
  }

  var options: [any TipOption] {
    MaxDisplayCount(3)
  }
}
