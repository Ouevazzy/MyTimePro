<!--
{
  "availability" : [
    "Mac Catalyst: 16.0.0 -",
    "iOS: 16.0.0 -",
    "iPadOS: 16.0.0 -",
    "macOS: 13.0.0 -",
    "tvOS: 16.0.0 -",
    "visionOS: 1.0.0 -",
    "watchOS: 9.0.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "AppIntents",
  "identifier" : "/documentation/AppIntents",
  "metadataVersion" : "0.1.0",
  "role" : "Framework",
  "symbol" : {
    "kind" : "Framework",
    "modules" : [
      "App Intents"
    ],
    "preciseIdentifier" : "AppIntents"
  },
  "title" : "App Intents"
}
-->

# App Intents

Make content and actions discoverable by Apple Intelligence and support system experiences like Siri, Spotlight, Shortcuts, and widgets.

## Overview

Make your app’s actions and data available outside your app using the App Intents framework.
Every app has code to perform specific actions, such as playing music or displaying
photos. Apps also have data, such as songs or photos, that people might want to use outside
your app.

![A hero image of an App Intents framework icon.](images/com.apple.AppIntents/app-intents-hero@2x.png)

With App Intents, you express your app’s actions and data in a structured
way that makes them discoverable by Apple Intelligence and provides deeper integration with system features people use frequently. For example:

- People can interact with your app’s content through Siri.
- Spotlight helps people navigate to your data directly from search results.
- The Shortcuts app helps people configure workflows that include your app’s actions.
- People can configure Apple Pencil or the Action button on iPhone to perform your app’s actions when pressed.
- [Widgets](doc://com.apple.documentation/documentation/WidgetKit), [controls](doc://com.apple.documentation/documentation/WidgetKit/Controls-Collection), and [Live Activities](doc://com.apple.documentation/documentation/ActivityKit) can use your app’s actions to perform relevant tasks.
- You can define custom Focus modes, and respond to Focus changes.

Use this framework to declare the actions your app performs as one or more *app intents*. You can also create
*app entities* and *app enums* to make your app’s key data types available to the system. For example, a
music app might define entities for the songs and albums it manages, and define an app intent to play them.
During compilation, the compiler generates information that Apple Intelligence, Siri, and other system features need to discover
and use your intents, entities, and app enum types.

For design guidance on how to implement features that involve [Widgets](doc://com.apple.documentation/design/Human-Interface-Guidelines/widgets),
[Controls](doc://com.apple.documentation/design/Human-Interface-Guidelines/controls),
[App Shortcuts](doc://com.apple.documentation/design/Human-Interface-Guidelines/app-shortcuts),
[Siri](doc://com.apple.documentation/design/Human-Interface-Guidelines/siri), or the
[Action button](doc://com.apple.documentation/design/Human-Interface-Guidelines/action-button),
see [Human Interface Guidelines](doc://com.apple.documentation/design/human-interface-guidelines).

## Topics

### Essentials

Learn the fundamentals of the App Intents framework.

[Getting started with the App Intents framework](/documentation/AppIntents/getting-started-with-the-app-intents-framework)

Make your app’s actions and content available to the rest of the system using the App Intents framework.

  <doc://com.apple.documentation/documentation/Updates/AppIntents>

### App-specific content

Define the actions, data, and types that represent your app’s capabilities to the system.

[App intents](/documentation/AppIntents/app-intents)

Make your app’s custom actions available to the system by using app intent types.

[App entities](/documentation/AppIntents/app-entities)

Make your app’s core types and data concepts available to the system using app entity types.

[App enums](/documentation/AppIntents/app-enums)

Make your app’s enumerations and predefined values available to the system by using app enum types.

[Common data types](/documentation/AppIntents/common-data-types)

Use framework-defined types for common parameter and result data types such as contacts, files, currencies, and more.

[App extension](/documentation/AppIntents/app-extension)

Deliver app intents in an app extension or other package that lives outside your
app’s code.

### System integration

Adopt schemas for well-known actions, display visual results, and donate behavioral signals to  Apple Intelligence.

[App schema domains](/documentation/AppIntents/app-schema-domains)

Declare support for well-known actions and content by applying system-defined schemas to
your app intents, app entities, and app enumerations.

[Visual presentation](/documentation/AppIntents/visual-presentation)

Display app intents and app entities visually using snippets, and associate intents and
entities with your app’s scenes and views.

[Donations and discovery](/documentation/AppIntents/donations-and-discovery)

Donate your app’s intents and entities to the system to help it identify trends and predict
future behaviors.

### Feature integration

Make your app intents and entities available to Siri, Spotlight, Shortcuts, widgets, and other system features.

[Adopting App Intents to support system experiences](/documentation/AppIntents/adopting-app-intents-to-support-system-experiences)

Create app intents and entities so people can use your app’s content and actions across system experiences.

[Apple Intelligence and Siri AI](/documentation/AppIntents/apple-intelligence-and-siri-ai)

Integrate your app with Apple Intelligence and bring it to Siri AI.

[Spotlight integration](/documentation/AppIntents/spotlight)

Add your entities to your app’s Spotlight index, and automate the indexing of your content.

[App Shortcuts](/documentation/AppIntents/app-shortcuts)

Improve the experience of using your app intents and entities in system experiences like Siri, Spotlight, and the Shortcuts app.

[Widgets, Live Activities, and Controls](/documentation/AppIntents/widgets-live-activities-and-controls)

Implement interactive widgets, controls, watch complications, and Live Activities using app intents.

[Hardware interactions](/documentation/AppIntents/hardware-interactions)

Run your App Shortcuts from the Action button on iPhone or Apple Watch, or launch your own conversational app from the
side button on iPhone.

[Focus](/documentation/AppIntents/focus)

Adjust your app’s behavior and filter incoming notifications when the
current Focus changes.

[Visual intelligence](/documentation/AppIntents/visual-intelligence)

Match images to your app’s content and report the results to the Visual Intelligence framework
using an app intent.

### Testing

Verify that your intent, entity, query, and enum types work correctly.

[Verifying your App Intents implementation](/documentation/AppIntents/verifying-your-app-intents-implementation)

Confirm that your app intents work correctly, the system can understand your content, and that it can run your app’s actions.

  <doc://com.apple.documentation/documentation/AppIntentsTesting/testing-your-app-intents-code>

  <doc://com.apple.documentation/documentation/AppIntentsTesting>

### Errors

Handle errors that occur when running your app intents.

[`struct AppIntentError`](/documentation/AppIntents/AppIntentError)

An error that indicates a problem occurred while performing an app intent.

[`protocol CustomAppIntentErrorConvertible`](/documentation/AppIntents/CustomAppIntentErrorConvertible)

A type that the system automatically converts to an app intent error.

### Deprecated

Avoid deprecated classes and protocols in your apps.

[Deprecated symbols](/documentation/AppIntents/Deprecated-symbols)

Review unsupported symbols and their replacements.

### Structures

[`struct EmptySnippetIntent`](/documentation/AppIntents/EmptySnippetIntent)

A snippet intent that renders an empty view.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)