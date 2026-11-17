<!--
{
  "availability" : [
    "iOS: 17.0.0 -",
    "iPadOS: 17.0.0 -",
    "macCatalyst: 17.0.0 -",
    "macOS: 14.0.0 -",
    "swift: 5.9.0 -",
    "tvOS: 17.0.0 -",
    "visionOS: 1.0.0 -",
    "watchOS: 10.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "SwiftData",
  "identifier" : "/documentation/SwiftData/FetchDescriptor",
  "metadataVersion" : "0.1.0",
  "role" : "Structure",
  "symbol" : {
    "kind" : "Structure",
    "modules" : [
      "SwiftData"
    ],
    "preciseIdentifier" : "s:9SwiftData15FetchDescriptorV"
  },
  "title" : "FetchDescriptor"
}
-->

# FetchDescriptor

A type that describes the criteria, sort order, and any additional
configuration to use when performing a fetch.

```
struct FetchDescriptor<T> where T : PersistentModel
```

## Overview

Use a fetch descriptor to capture the criteria necessary to select, and
optionally sort, a specific collection of models from your app’s persistent
storage. A fetch descriptor retrieves only a single type of persistent model,
and relies on type inference to determine the appropriate type. However, you
can configure a fetch descriptor to prefetch related models of different types
using the [`relationshipKeyPathsForPrefetching`](/documentation/SwiftData/FetchDescriptor/relationshipKeyPathsForPrefetching) property.

To fetch a collection of models, first create a fetch descriptor and specify a
predicate and one or more sort descriptors. The predicate describes the
attributes to filter by and the constraints to apply to those attributes. If
you don’t specify a predicate, the fetch returns all models of the inferred
type. You can further tweak a fetch by limiting the number of models it
returns, or indicating whether the fetch evaluates any unsaved changes when it
selects the models to return. After configuring the fetch descriptor, pass it
to the model context’s [`fetch(_:)`](/documentation/SwiftData/ModelContext/fetch(_:)) method to run the fetch.

```swift
let descriptor = FetchDescriptor<Recipe>(
    predicate: #Predicate { $0.isFavorite == true },
    sortBy: [
        .init(\.createdAt)
    ]
)
descriptor.fetchLimit = 10

let favoriteRecipes = try modelContext.fetch(descriptor)
```

If you’re displaying the fetched models in a SwiftUI view, use the descriptor
with the [`Query(_:animation:)`](/documentation/SwiftData/Query(_:animation:)) macro instead.

```
struct FavoriteRecipesList: View {
    static var fetchDescriptor: FetchDescriptor<Recipe> {
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [
                .init(\.createdAt)
            ]
        )
        descriptor.fetchLimit = 10
        return descriptor
    }

    @Query(FavoriteRecipesList.fetchDescriptor) private var favoriteRecipes: [Recipe]
    
    var body: some View {
        List(favoriteRecipes) { RecipeRowView($0) }
    }
} 
```

## Topics

### Creating a fetch descriptor

[`init(predicate: Predicate<T>?, sortBy: [SortDescriptor<T>])`](/documentation/SwiftData/FetchDescriptor/init(predicate:sortBy:))

Creates a fetch descriptor with the specified predicate that, optionally,
arranges the fetched models in a particular order.

  <doc://com.apple.documentation/documentation/Foundation/Predicate>

  <doc://com.apple.documentation/documentation/Foundation/SortDescriptor>

### Constraining the fetch

[`var predicate: Predicate<T>?`](/documentation/SwiftData/FetchDescriptor/predicate)

The logical condition that determines whether the fetch includes a specific
model in its results.

[`var sortBy: [SortDescriptor<T>]`](/documentation/SwiftData/FetchDescriptor/sortBy)

The sort descriptors that tell the fetch how to order its results.

[`var fetchLimit: Int?`](/documentation/SwiftData/FetchDescriptor/fetchLimit)

The maximum number of models the fetch can return.

[`var fetchOffset: Int?`](/documentation/SwiftData/FetchDescriptor/fetchOffset)

The offset of the first matching model to fetch.

[`var includePendingChanges: Bool`](/documentation/SwiftData/FetchDescriptor/includePendingChanges)

A Boolean value that indicates whether, when the fetch runs, it matches against
currently unsaved changes in the model context.

### Specifying the fetched attributes

[`var relationshipKeyPathsForPrefetching: [PartialKeyPath<T>]`](/documentation/SwiftData/FetchDescriptor/relationshipKeyPathsForPrefetching)

The key paths that identify any related models to include as part of the fetch.

[`var propertiesToFetch: [PartialKeyPath<T>]`](/documentation/SwiftData/FetchDescriptor/propertiesToFetch)

The specific subset of attributes to fetch if you don’t require them all.

## Relationships

### Conforms To

[`SendableMetatype`](/documentation/Swift/SendableMetatype)

[`Equatable`](/documentation/Swift/Equatable)

[`Sendable`](/documentation/Swift/Sendable)

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)