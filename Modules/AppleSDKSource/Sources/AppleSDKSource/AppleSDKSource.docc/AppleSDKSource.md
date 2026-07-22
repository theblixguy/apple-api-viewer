# ``AppleSDKSource``

Indexes Apple's bundled SDK frameworks as a symbol source.

## Overview

It enumerates the modules in the installed platform SDKs, extracts and parses
each symbol graph, and merges a module that appears in several SDKs into one
framework index. Because availability is absolute, indexing the latest Xcode is
enough to answer questions about earlier releases too.

## Topics

### The Apple SDK source

- ``SDKSymbolSource``
