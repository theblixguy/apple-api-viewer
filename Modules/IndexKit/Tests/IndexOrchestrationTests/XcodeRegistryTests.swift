import CoreModel
import Dependencies
import Foundation
import SDKDiscovery
import Testing
@testable import IndexOrchestration

@Suite("Xcode registry", .tags(.xcodes))
struct XcodeRegistryTests {
  @Test("Auto-detected and manually added Xcodes merge")
  func mergesAutoDetectedAndManuallyAddedXcodes() async throws {
    let auto = xcodeInstallation("Xcode", 26)
    let extra = xcodeInstallation("Xcode-beta", 27)

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(
        installed: [auto], system: auto, resolvable: [extra]
      )
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      try await registry.add(applicationURL: extra.applicationURL)

      let entries = await registry.entries()
      #expect(entries.count == 2)
      #expect(
        entries.contains {
          $0.applicationURL == extra.applicationURL && $0.isManuallyAdded
        }
      )
      #expect(
        entries.contains {
          $0.applicationURL == auto.applicationURL && !$0.isManuallyAdded
        }
      )
      #expect(entries.first?.applicationURL == extra.applicationURL)
    }
  }

  @Test("Adding rejects a non-Xcode bundle")
  func addRejectsANonXcodeBundle() async {
    await withDependencies {
      $0.sdkDiscovery = Self.discovery()
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      await #expect(throws: XcodeRegistryError.self) {
        try await registry.add(
          applicationURL: URL(filePath: "/Applications/Nope.app")
        )
      }
      #expect(await registry.entries().isEmpty)
    }
  }

  @Test("Removing a manual entry drops it")
  func removingAManualEntryDropsIt() async throws {
    let extra = xcodeInstallation("Xcode-beta", 27)

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(resolvable: [extra])
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      try await registry.add(applicationURL: extra.applicationURL)
      #expect(await registry.entries().count == 1)

      registry.remove(applicationURL: extra.applicationURL)
      #expect(await registry.entries().isEmpty)
    }
  }

  @Test("Removing an auto-detected Xcode is a no-op")
  func removingAnAutoDetectedXcodeIsANoOp() async {
    let auto = xcodeInstallation("Xcode", 26)

    await withDependencies {
      $0.sdkDiscovery = Self.discovery(installed: [auto], resolvable: [auto])
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      registry.remove(applicationURL: auto.applicationURL)
      #expect(
        await registry.entries().contains {
          $0.applicationURL == auto.applicationURL && !$0.isManuallyAdded
        }
      )
    }
  }

  @Test("A stale manual entry is marked broken")
  func aStaleManualEntryIsMarkedBroken() async throws {
    let ghost = xcodeInstallation("Xcode-ghost", 27)
    let store = XcodeRegistryStore.inMemory()

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(resolvable: [ghost])
    } operation: {
      try await XcodeRegistry(store: store).add(
        applicationURL: ghost.applicationURL
      )
    }

    await withDependencies {
      $0.sdkDiscovery = Self.discovery()
    } operation: {
      let entry = await XcodeRegistry(store: store).entries().first {
        $0.applicationURL == ghost.applicationURL
      }
      #expect(entry?.isBroken == true)
      #expect(entry?.isManuallyAdded == true)
    }
  }

  @Test("The active Xcode follows the system when no default is pinned")
  func activeFollowsSystemWhenNoDefaultIsPinned() async {
    let stable = xcodeInstallation("Xcode", 26)
    let beta = xcodeInstallation("Xcode-beta", 27)

    await withDependencies {
      $0.sdkDiscovery = Self.discovery(
        installed: [stable, beta], system: stable
      )
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      #expect(await registry.activeXcode() == stable)
      #expect(!registry.hasPinnedDefault())
      let active = await registry.entries().first { $0.isDefault }
      #expect(active?.applicationURL == stable.applicationURL)
      #expect(active?.isSystemSelected == true)
    }
  }

  @Test("A pinned default overrides the system Xcode")
  func pinnedDefaultOverridesTheSystemXcode() async throws {
    let stable = xcodeInstallation("Xcode", 26)
    let beta = xcodeInstallation("Xcode-beta", 27)

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(
        installed: [stable, beta], system: stable, resolvable: [stable, beta]
      )
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      try registry.setDefault(applicationURL: beta.applicationURL)
      #expect(await registry.activeXcode() == beta)
      #expect(registry.hasPinnedDefault())
    }
  }

  @Test("A typed path without a trailing slash pins a scanned Xcode")
  func typedPathWithoutTrailingSlashPinsAScannedXcode() async throws {
    let stable = xcodeInstallation("Xcode", 26, scanned: true)
    let beta = xcodeInstallation("Xcode-beta", 27, scanned: true)

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(
        installed: [stable, beta], system: stable, resolvable: [stable, beta]
      )
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      try registry.setDefault(
        applicationURL: URL(filePath: "/Applications/Xcode-beta.app")
      )
      #expect(await registry.activeXcode() == beta)
      let pinned = await registry.entries().first { $0.isDefault }
      #expect(pinned?.installation == beta)
    }
  }

  @Test("Adding a scanned Xcode by typed path is a no-op")
  func addingAScannedXcodeByTypedPathIsANoOp() async throws {
    let auto = xcodeInstallation("Xcode", 26, scanned: true)

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(
        installed: [auto], system: auto, resolvable: [auto]
      )
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      try await registry.add(
        applicationURL: URL(filePath: "/Applications/Xcode.app")
      )
      let entries = await registry.entries()
      #expect(entries.count == 1)
      #expect(entries.first?.isManuallyAdded == false)
    }
  }

  @Test("A pinned Xcode outside the scanned directories stays active")
  func pinnedXcodeOutsideTheScannedDirectoriesStaysActive() async throws {
    let stable = xcodeInstallation("Xcode", 26)
    let outside = xcodeInstallation("Xcodes/Xcode-26.0", 26, build: "2A")

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(
        installed: [stable], system: stable, resolvable: [stable, outside]
      )
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      try registry.setDefault(applicationURL: outside.applicationURL)
      #expect(await registry.activeXcode() == outside)
      #expect(registry.hasPinnedDefault())
    }
  }

  @Test("A broken pinned default falls back to the system Xcode")
  func aBrokenPinnedDefaultFallsBackToTheSystemXcode() async throws {
    let stable = xcodeInstallation("Xcode", 26)
    let pinned = xcodeInstallation("Xcode-pinned", 27)
    let store = XcodeRegistryStore.inMemory()

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(
        installed: [stable], system: stable, resolvable: [stable, pinned]
      )
    } operation: {
      let registry = XcodeRegistry(store: store)
      try await registry.add(applicationURL: pinned.applicationURL)
      try registry.setDefault(applicationURL: pinned.applicationURL)
      #expect(await registry.activeXcode() == pinned)
    }

    await withDependencies {
      $0.sdkDiscovery = Self.discovery(installed: [stable], system: stable)
    } operation: {
      let registry = XcodeRegistry(store: store)
      #expect(await registry.activeXcode() == stable)
      #expect(!registry.hasPinnedDefault())
    }
  }

  @Test("Removing the pinned manual default unpins it")
  func removingThePinnedManualDefaultUnpinsIt() async throws {
    let stable = xcodeInstallation("Xcode", 26)
    let beta = xcodeInstallation("Xcode-beta", 27)

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(
        installed: [stable], system: stable, resolvable: [stable, beta]
      )
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      try await registry.add(applicationURL: beta.applicationURL)
      try registry.setDefault(applicationURL: beta.applicationURL)
      registry.remove(applicationURL: beta.applicationURL)
      #expect(!registry.hasPinnedDefault())
      #expect(await registry.activeXcode() == stable)
    }
  }

  @Test("The active Xcode falls to the newest when there is no system Xcode")
  func activeFallsToNewestWhenNoSystemXcode() async {
    let older = xcodeInstallation("Xcode", 26)
    let newer = xcodeInstallation("Xcode-beta", 27)

    await withDependencies {
      $0.sdkDiscovery = Self.discovery(installed: [older, newer], system: nil)
    } operation: {
      #expect(await XcodeRegistry(store: .inMemory()).activeXcode() == newer)
    }
  }

  @Test("Clearing the default restores the system Xcode")
  func clearingTheDefaultRestoresTheSystemXcode() async throws {
    let stable = xcodeInstallation("Xcode", 26)
    let beta = xcodeInstallation("Xcode-beta", 27)

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(
        installed: [stable, beta], system: stable, resolvable: [stable, beta]
      )
    } operation: {
      let registry = XcodeRegistry(store: .inMemory())
      try registry.setDefault(applicationURL: beta.applicationURL)
      #expect(await registry.activeXcode() == beta)

      registry.clearDefault()
      #expect(await registry.activeXcode() == stable)
      #expect(!registry.hasPinnedDefault())
    }
  }

  // MARK: - Ordering

  @Test("Equal versions order by numeric build not lexicographically")
  func ordersEqualVersionsByNumericBuildNotLexicographically() async {
    let older = xcodeInstallation("Xcode-rc", 26, build: "17F65")
    let newer = xcodeInstallation("Xcode", 26, build: "17F113")
    let beta = xcodeInstallation("Xcode-beta", 27, build: "27A5218g")

    await withDependencies {
      $0.sdkDiscovery = Self.discovery(installed: [older, newer, beta])
    } operation: {
      let entries = await XcodeRegistry(store: .inMemory()).entries()
      #expect(entries.compactMap(\.installation) == [beta, newer, older])
    }
  }

  @Test("The active Xcode prefers the newest build among equal versions")
  func activePrefersTheNewestBuildAmongEqualVersions() async {
    let older = xcodeInstallation("Xcode-rc", 26, build: "17F65")
    let newer = xcodeInstallation("Xcode", 26, build: "17F113")

    await withDependencies {
      $0.sdkDiscovery = Self.discovery(installed: [older, newer], system: nil)
    } operation: {
      #expect(await XcodeRegistry(store: .inMemory()).activeXcode() == newer)
    }
  }

  @Test("Broken entries order last tied by path")
  func ordersBrokenEntriesLastTiedByPath() async throws {
    let valid = xcodeInstallation("Xcode", 26)
    let ghostA = xcodeInstallation("Xcode-ghost-a", 27)
    let ghostB = xcodeInstallation("Xcode-ghost-b", 27)
    let store = XcodeRegistryStore.inMemory()

    try await withDependencies {
      $0.sdkDiscovery = Self.discovery(resolvable: [ghostA, ghostB])
    } operation: {
      let registry = XcodeRegistry(store: store)
      try await registry.add(applicationURL: ghostB.applicationURL)
      try await registry.add(applicationURL: ghostA.applicationURL)
    }

    await withDependencies {
      $0.sdkDiscovery = Self.discovery(installed: [valid])
    } operation: {
      let entries = await XcodeRegistry(store: store).entries()
      #expect(entries.first?.installation == valid)
      #expect(
        entries.dropFirst().map(\.applicationURL) == [
          ghostA.applicationURL, ghostB.applicationURL,
        ]
      )
    }
  }

  // MARK: - Helpers

  // The real discovery resolves a bundle on disk, and a trailing slash
  // makes no difference there, so the fake uses the same canonical path.
  static func discovery(
    installed: [XcodeInstallation] = [],
    system: XcodeInstallation? = nil,
    resolvable: [XcodeInstallation] = []
  ) -> SDKDiscoveryClient {
    let byPath = Dictionary(
      (installed + resolvable).map {
        (XcodeRegistry.canonicalPath(for: $0.applicationURL), $0)
      },
      uniquingKeysWith: { first, _ in first }
    )
    return SDKDiscoveryClient(
      installedXcodes: { _ in installed },
      sdks: { _ in [] },
      xcodeAt: { byPath[XcodeRegistry.canonicalPath(for: $0)] },
      systemSelectedXcode: { system }
    )
  }
}
