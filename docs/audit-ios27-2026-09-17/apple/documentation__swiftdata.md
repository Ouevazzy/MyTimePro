<!--
{
  "availability" : [
    "iOS: 17.0 -",
    "iPadOS: 17.0 -",
    "macCatalyst: 17.0 -",
    "macOS: 14.0 -",
    "tvOS: 17.0 -",
    "visionOS: 1.0 -",
    "watchOS: 10.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "SwiftData",
  "identifier" : "/documentation/SwiftData",
  "metadataVersion" : "0.1.0",
  "role" : "Framework",
  "symbol" : {
    "kind" : "Framework",
    "modules" : [
      "SwiftData"
    ],
    "preciseIdentifier" : "SwiftData"
  },
  "title" : "SwiftData"
}
-->

# SwiftData

Write your model code declaratively to add managed persistence and efficient
model fetching.

## Overview

Combining Core Data’s proven persistence technology and Swift’s modern
concurrency features, SwiftData enables you to add persistence to your app
quickly, with minimal code and no external dependencies. Using modern language
features like macros, SwiftData enables you to write code that is fast,
efficient, and safe, enabling you to describe the entire model layer
(or object graph) for your app. The framework handles storing the underlying
model data, and optionally, syncing that data across multiple devices.

SwiftData has uses beyond persisting locally created content. For example, an
app that fetches data from a remote web service might use SwiftData to
implement a lightweight caching mechanism and provide limited offline
functionality.

![A white Swift logo containing ones and zeros on a blueprint-style background.](images/com.apple.SwiftData/swiftdata-hero@2x.png)

SwiftData is unintrusive by design and supplements your app’s existing model
classes. Attach the [`Model()`](/documentation/SwiftData/Model()) macro to any model class to make it persistable.
Customize the behavior of that model’s properties with the [`Attribute(_:originalName:hashModifier:)`](/documentation/SwiftData/Attribute(_:originalName:hashModifier:))
and [`Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:)`](/documentation/SwiftData/Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:))
macros. Use the [`ModelContext`](/documentation/SwiftData/ModelContext) class to insert, update, and delete instances
of that model, and to write unsaved changes to disk.

To display models in a SwiftUI view, use the [`Query()`](/documentation/SwiftData/Query()) macro and specify a
predicate or fetch descriptor. SwiftData performs the fetch when the view
appears, and tells SwiftUI about any subsequent changes to the fetched models
so the view can update accordingly. You can access the model context in any
SwiftUI view using the <doc://com.apple.documentation/documentation/SwiftUI/EnvironmentValues/modelContext>
environment value, and specify a particular model container or context for a
view with the <doc://com.apple.documentation/documentation/SwiftUI/View/modelContainer(_:)>
and <doc://com.apple.documentation/documentation/SwiftUI/View/modelContext(_:)>
view modifiers.

## Topics

### Essentials

[Preserving your app’s model data across launches](/documentation/SwiftData/Preserving-your-apps-model-data-across-launches)

Describe your model classes to SwiftData using the framework’s macros, and
store instances of those models so they exist beyond the app’s runtime.

[Adding and editing persistent data in your app](/documentation/SwiftData/Adding-and-editing-persistent-data-in-your-app)

Create a data entry form for collecting and changing data managed by SwiftData.

  <doc://com.apple.documentation/documentation/CoreData/adopting-swiftdata-for-a-core-data-app>

  <doc://com.apple.documentation/documentation/Updates/SwiftData>

[Adopting inheritance in SwiftData](/documentation/SwiftData/Adopting-inheritance-in-SwiftData)

Add flexibility to your models using class inheritance.

### Model definition

[`macro Model()`](/documentation/SwiftData/Model())

Converts a Swift class into a stored model that’s managed by SwiftData.

[`macro Attribute(Schema.Attribute.Option..., originalName: String?, hashModifier: String?)`](/documentation/SwiftData/Attribute(_:originalName:hashModifier:))

Specifies the custom behavior that SwiftData applies to the annotated property
when managing the owning class.

[`macro Unique<T>([PartialKeyPath<T>]...)`](/documentation/SwiftData/Unique(_:))

Specifies the key-paths that SwiftData uses to enforce the uniqueness of model
instances.

[`macro Index<T>([PartialKeyPath<T>]...)`](/documentation/SwiftData/Index(_:)-74ia2)

Specifies the key-paths that SwiftData uses to create one or more binary
indices for the associated model.

[`macro Index<T>(Schema.Index<T>.Types<T>...)`](/documentation/SwiftData/Index(_:)-7d4z0)

Specifies the key-paths that SwiftData uses to create one or more indicies for
the associated model, where each index is either binary or R-tree.

[Defining data relationships with enumerations and model classes](/documentation/SwiftData/Defining-data-relationships-with-enumerations-and-model-classes)

Create relationships for static and dynamic data stored in your app.

[`macro Relationship(Schema.Relationship.Option..., deleteRule: Schema.Relationship.DeleteRule, minimumModelCount: Int?, maximumModelCount: Int?, originalName: String?, inverse: AnyKeyPath?, hashModifier: String?)`](/documentation/SwiftData/Relationship(_:deleteRule:minimumModelCount:maximumModelCount:originalName:inverse:hashModifier:))

Specifies the options that SwiftData needs to manage the annotated property as
a relationship between two models.

[`macro Transient()`](/documentation/SwiftData/Transient())

Tells SwiftData not to persist the annotated property when managing the owning
class.

### Model life cycle

[`class ModelContainer`](/documentation/SwiftData/ModelContainer)

An object that manages an app’s schema and model storage configuration.

[`class ModelContext`](/documentation/SwiftData/ModelContext)

An object that enables you to fetch, insert, and delete models, and save any
changes to disk.

[Fetching and filtering time-based model changes](/documentation/SwiftData/Fetching-and-filtering-time-based-model-changes)

Track all inserts, updates, and deletes that occur in a data store and process
them as a series of chronological transactions.

  <doc:History>

[`HistoryDescriptor`](/documentation/SwiftData/HistoryDescriptor)

[Deleting persistent data from your app](/documentation/SwiftData/Deleting-persistent-data-from-your-app)

Explore different ways to use SwiftData to delete persistent data.

[Reverting data changes using the undo manager](/documentation/SwiftData/Reverting-data-changes-using-the-undo-manager)

Automatically record data change operations that people perform in your
SwiftUI app, and let them undo and redo those changes.

[Syncing model data across a person’s devices](/documentation/SwiftData/Syncing-model-data-across-a-persons-devices)

Add the required capabilities and define a compatible schema to enable
SwiftData to automatically sync your app’s model data using iCloud.

[Concurrency support](/documentation/SwiftData/ConcurrencySupport)

Types you use to access model attributes and perform storage-related tasks in
a safe and isolated way.

### Model fetch

[Filtering and sorting persistent data](/documentation/SwiftData/Filtering-and-sorting-persistent-data)

Manage data store presentation using predicates and dynamic queries.

[`macro Query()`](/documentation/SwiftData/Query())

Fetches all instances of the attached model type.

[Additional query macros](/documentation/SwiftData/AdditionalQueryMacros)

Supplementary macros that enable you to narrow query results and tell SwiftData
how to sort, order, and section those results.

[`struct Query`](/documentation/SwiftData/Query)

A type that fetches models using the specified criteria, and manages those
models so they remain in sync with the underlying data.

[`struct FetchDescriptor`](/documentation/SwiftData/FetchDescriptor)

A type that describes the criteria, sort order, and any additional
configuration to use when performing a fetch.

### Model storage

[Maintaining a local copy of server data](/documentation/SwiftData/Maintaining-a-local-copy-of-server-data)

Create and update a persistent store to cache read-only network data.

[`class DefaultStore`](/documentation/SwiftData/DefaultStore)

A data store that uses Core Data as its undelying storage mechanism.

[`protocol DataStore`](/documentation/SwiftData/DataStore)

An interface that enables SwiftData to read and write model data without
knowledge of the underlying storage mechanism.

[`protocol DataStoreBatching`](/documentation/SwiftData/DataStoreBatching)

An interface that enables a custom data store to support batch requests.

[`protocol HistoryProviding`](/documentation/SwiftData/HistoryProviding)

An interface that enables a custom data store to provide the history of changes
for its persisted models.

  <doc://com.apple.documentation/documentation/SwiftUI/Building-a-document-based-app-using-SwiftData>

[`struct ModelDocument`](/documentation/SwiftData/ModelDocument)

A document type that uses SwiftData to manage its storage.

### History life cycle

[`enum HistoryChange`](/documentation/SwiftData/HistoryChange)

Values that describe data history transactions.

[`protocol HistoryDelete`](/documentation/SwiftData/HistoryDelete)

An interface that enables a custom data store to delete items from the history of changes to its persisted models.

[`protocol HistoryInsert`](/documentation/SwiftData/HistoryInsert)

[`protocol HistoryToken`](/documentation/SwiftData/HistoryToken)

[`protocol HistoryTransaction`](/documentation/SwiftData/HistoryTransaction)

[`protocol HistoryUpdate`](/documentation/SwiftData/HistoryUpdate)

[`struct HistoryTombstone`](/documentation/SwiftData/HistoryTombstone)

[`struct DefaultHistoryInsert`](/documentation/SwiftData/DefaultHistoryInsert)

[`struct DefaultHistoryUpdate`](/documentation/SwiftData/DefaultHistoryUpdate)

[`struct DefaultHistoryDelete`](/documentation/SwiftData/DefaultHistoryDelete)

[`struct DefaultHistoryToken`](/documentation/SwiftData/DefaultHistoryToken)

[`struct DefaultHistoryTransaction`](/documentation/SwiftData/DefaultHistoryTransaction)

### Data store observation

[`class ResultsObserver`](/documentation/SwiftData/ResultsObserver)

Observes and tracks changes to a collection of persistent models in a model context.

[`class HistoryObserver`](/documentation/SwiftData/HistoryObserver)

Monitors a model container’s data stores for remote changes and notifies
when new history transactions are available.

### Codeable support

[`enum DataStoreSnapshotCodingKey`](/documentation/SwiftData/DataStoreSnapshotCodingKey)

The key space to use when implementing custom coders and decoders for data store snapshots,

### Errors

[`struct SwiftDataError`](/documentation/SwiftData/SwiftDataError)

A type that describes a SwiftData error.

[`enum DataStoreError`](/documentation/SwiftData/DataStoreError)

A type that describes a data store error.

### Structures

[`struct ResultsSection`](/documentation/SwiftData/ResultsSection)

A section of fetched results grouped by a common section key path value.

[`struct SectionedResults`](/documentation/SwiftData/SectionedResults)

A `RandomAccessCollection` of [`ResultsSection`](/documentation/SwiftData/ResultsSection) instances representing sectioned query results.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)