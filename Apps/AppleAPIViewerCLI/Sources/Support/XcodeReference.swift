import CoreModel
import Foundation
import IndexOrchestration

func fileURL(forArgument argument: String) -> URL {
  let expanded = (argument as NSString).expandingTildeInPath
  let base = URL(filePath: FileManager.default.currentDirectoryPath)
  return URL(filePath: expanded, relativeTo: base).absoluteURL
    .standardizedFileURL
}

func resolveXcodeReference(_ reference: String, in entries: [XcodeEntry])
  -> URL?
{
  if reference.contains("/") || reference.hasSuffix(".app") {
    return fileURL(forArgument: reference)
  }
  return entries.first { $0.installation?.build == reference }?.applicationURL
}

struct XcodeListItem: Encodable {
  let path: String
  let version: String?
  let build: String?
  let displayName: String?
  let isDefault: Bool
  let systemSelected: Bool
  let manuallyAdded: Bool
  let broken: Bool

  init(_ entry: XcodeEntry) {
    path = entry.applicationURL.path(percentEncoded: false)
    version = entry.installation?.version.description
    build = entry.installation?.build
    displayName = entry.installation?.displayName
    isDefault = entry.isDefault
    systemSelected = entry.isSystemSelected
    manuallyAdded = entry.isManuallyAdded
    broken = entry.isBroken
  }
}

func xcodeListLine(_ item: XcodeListItem) -> String {
  let mark = item.isDefault ? "*" : " "
  guard let displayName = item.displayName else {
    return "\(mark) \(item.path)  (missing)"
  }
  let selected = item.systemSelected ? "  (xcode-select)" : ""
  let source = item.manuallyAdded ? "  (added)" : ""
  return "\(mark) \(displayName)\(selected)\(source)"
}

struct ActiveXcodeOutput: Encodable {
  let active: XcodeListItem?
}

struct XcodeSummary: Encodable {
  let version: String
  let build: String
  let displayName: String

  init(_ xcode: XcodeInstallation) {
    version = xcode.version.description
    build = xcode.build
    displayName = xcode.displayName
  }
}
