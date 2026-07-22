import Foundation
import Synchronization

struct XcodeRegistryStore: Sendable {
  var stringArray: @Sendable (String) -> [String]
  var string: @Sendable (String) -> String?
  var setStringArray: @Sendable ([String], String) -> Void
  var setString: @Sendable (String, String) -> Void
  var removeValue: @Sendable (String) -> Void

  static func userDefaults(suiteName: String) -> XcodeRegistryStore {
    @Sendable func defaults() -> UserDefaults {
      UserDefaults(suiteName: suiteName) ?? .standard
    }
    return XcodeRegistryStore(
      stringArray: { defaults().array(forKey: $0) as? [String] ?? [] },
      string: { defaults().string(forKey: $0) },
      setStringArray: { defaults().set($0, forKey: $1) },
      setString: { defaults().set($0, forKey: $1) },
      removeValue: { defaults().removeObject(forKey: $0) }
    )
  }

  static func inMemory() -> XcodeRegistryStore {
    final class Storage: Sendable {
      let arrays = Mutex<[String: [String]]>([:])
      let strings = Mutex<[String: String]>([:])
    }
    let storage = Storage()
    return XcodeRegistryStore(
      stringArray: { key in storage.arrays.withLock { $0[key] ?? [] } },
      string: { key in storage.strings.withLock { $0[key] } },
      setStringArray: { value, key in
        storage.arrays.withLock { $0[key] = value }
      },
      setString: { value, key in
        storage.strings.withLock { $0[key] = value }
      },
      removeValue: { key in
        storage.arrays.withLock { _ = $0.removeValue(forKey: key) }
        storage.strings.withLock { _ = $0.removeValue(forKey: key) }
      }
    )
  }
}
