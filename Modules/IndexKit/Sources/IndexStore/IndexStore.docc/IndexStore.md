# ``IndexStore``

The SQLite-backed store for the symbol index and its query-result rows.

## Overview

The store holds the extracted symbols and their availability, with a full-text
table for search. Writes replace the whole index or a single framework
atomically, and reads return small value types for the UI.

## Topics

### The store

- ``IndexStore``

### Query results

- ``FrameworkSummary``
- ``SearchHit``
