<!--
{
  "documentType" : "article",
  "framework" : "Updates",
  "identifier" : "/documentation/Updates/SwiftData",
  "metadataVersion" : "0.1.0",
  "role" : "article",
  "title" : "SwiftData updates"
}
-->

# SwiftData updates

Learn about important changes to SwiftData.

## Overview

Browse notable changes in <doc://com.apple.documentation/documentation/SwiftData>.

## June 2026

- Section your query results by creating your query with a macro that takes a `sectionBy` parameter, as listed on the <doc://com.apple.documentation/documentation/SwiftData/AdditionalQueryMacros> page.
- Use types that conform to <doc://com.apple.documentation/documentation/Swift/Codable> in a model, including types you don’t control directly, by using the  <doc://com.apple.documentation/documentation/SwiftData/Schema/Attribute/Option/codable> option for <doc://com.apple.documentation/documentation/SwiftData/Schema/Attribute>.
- Receive real-time updates to models that match specified fetch criteria by using the <doc://com.apple.documentation/documentation/SwiftData/ResultsObserver> type.
- Observe remote model changes with the <doc://com.apple.documentation/documentation/SwiftData/HistoryObserver> type.

## June 2025

- Increase the flexibility of your models by adopting inheritance through the <doc://com.apple.documentation/documentation/SwiftData/Model()> macro.
- Gain added flexibility in accessing and sorting transaction history using <doc://com.apple.documentation/documentation/SwiftData/HistoryDescriptor/sortBy> in the <doc://com.apple.documentation/documentation/SwiftData/HistoryDescriptor>.

## June 2024

### Macros

- Improve performance of sorts and predicate-based fetches by using the <doc://com.apple.documentation/documentation/SwiftData/Index(_:)-74ia2> macro to define individual and compound indexes.
- Define a unique constraint that includes one or more model attributes using the <doc://com.apple.documentation/documentation/SwiftData/Unique(_:)> macro, enabling SwiftData to regard tuples of attributes as unique.
- Specify `nil` as a relationship’s `inverse` to create a unidirectional relationship.

### Persistent history

- Fetch historical changes for one or more persistent models using the model context’s <doc://com.apple.documentation/documentation/SwiftData/ModelContext/fetchHistory(_:)> method.
- Delete stale model history from a persistent store by calling the context’s <doc://com.apple.documentation/documentation/SwiftData/ModelContext/deleteHistory(_:)> method.
- Provide an alternate change tracking strategy for your custom persistent store by adopting the <doc://com.apple.documentation/documentation/SwiftData/HistoryProviding> protocol.

### Custom persistent stores

- Adopt the <doc://com.apple.documentation/documentation/SwiftData/DataStore> protocol (and related protocols) to provide custom storage for your app’s persistent models.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)