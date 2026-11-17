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
  "identifier" : "/documentation/SwiftData/ModelActor",
  "metadataVersion" : "0.1.0",
  "role" : "Protocol",
  "symbol" : {
    "kind" : "Protocol",
    "modules" : [
      "SwiftData"
    ],
    "preciseIdentifier" : "s:9SwiftData10ModelActorP"
  },
  "title" : "ModelActor"
}
-->

# ModelActor

An interface for providing mutually-exclusive access to the attributes of a conforming model.

```
protocol ModelActor : Actor
```

## Topics

### Accessing the container and context

[`var modelContainer: ModelContainer`](/documentation/SwiftData/ModelActor/modelContainer)

The ModelContainer for the ModelActor
The container that manages the app’s schema and model storage configuration

[`var modelContext: ModelContext`](/documentation/SwiftData/ModelActor/modelContext)

The context that serializes any code running on the model actor.

### Accessing the executors

[`var modelExecutor: any ModelExecutor`](/documentation/SwiftData/ModelActor/modelExecutor)

The executor that coordinates access to the model actor.

[`var unownedExecutor: UnownedSerialExecutor`](/documentation/SwiftData/ModelActor/unownedExecutor)

The optimized, unonwned reference to the model actor’s executor.

### Accessing specific models

[`subscript<T>(PersistentIdentifier, as _: T.Type) -> T?`](/documentation/SwiftData/ModelActor/subscript(_:as:))

Returns the model for the specified identifier, downcast to the appropriate class.

## Relationships

### Inherits From

[`Sendable`](/documentation/Swift/Sendable)

[`SendableMetatype`](/documentation/Swift/SendableMetatype)

[`Actor`](/documentation/Swift/Actor)

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)