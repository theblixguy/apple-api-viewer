# ``IndexOrchestration``

The UI-free entry point for building and locating the index.

## Overview

It ties discovery, staleness checks, and index building together behind one
type, and holds the shared on-disk location the app and the CLI both use.

## Topics

### Managing the index

- ``IndexWorkspace``

### Choosing the Xcode

- ``XcodeRegistry``
- ``XcodeEntry``
- ``XcodeRegistryError``

### Filesystem locations

- ``AppPaths``
