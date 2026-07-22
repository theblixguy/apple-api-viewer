# ``CoreModel``

The shared domain models for the app, covering platforms, OS versions,
availability, and sources.

## Overview

These value types are the vocabulary the rest of the engine speaks. They depend
on nothing in the index, the UI, or any source, so every higher layer can pass
them around freely.

## Topics

### Platforms and versions

- ``ApplePlatform``
- ``SemanticVersion``

### Availability

- ``Availability``
- ``AvailabilityDomain``

### Sources

- ``Source``
- ``SourceKind``

### SDKs and Xcode

- ``XcodeInstallation``
- ``InstalledSDK``

### Indexing

- ``IndexingProgress``
- ``PauseController``
