# ``SymbolGraphIndex``

The extracted symbol model and the in-memory tree the browser shows.

## Overview

A parsed symbol graph becomes a ``FrameworkIndex`` of ``IndexedSymbol`` values.
From a version selection the index builds the tree of types and members that are
new in those releases.

## Topics

### Symbols

- ``IndexedSymbol``
- ``FrameworkIndex``
- ``SymbolKind``

### Parsing symbol graphs

- ``SymbolGraphParser``

### Browsing by version

- ``VersionSelection``
- ``SymbolTreeNode``
