<!--
{
  "documentType" : "article",
  "framework" : "Updates",
  "identifier" : "/documentation/Updates/AppIntents",
  "metadataVersion" : "0.1.0",
  "role" : "article",
  "title" : "App Intents updates"
}
-->

# App Intents updates

Learn about important changes in App Intents.

## Overview

Browse notable changes in <doc://com.apple.documentation/documentation/AppIntents>.

## June 2026

### Apple Intelligence

- Integrate your app with Apple intelligence by conforming your app intents, app entities, and app enums to an app schema in one of the <doc://com.apple.documentation/documentation/AppIntents/app-schema-domains>.
- Indicate that your app entities have identifiers that remain stable across devices by adopting <doc://com.apple.documentation/documentation/AppIntents/SyncableEntity>, so people can continue a task on another device.
- Prompt for confirmation before destructive or sensitive actions on shared or publicly accessible entities by adopting <doc://com.apple.documentation/documentation/AppIntents/OwnershipProvidingEntity> and returning an <doc://com.apple.documentation/documentation/AppIntents/EntityOwnership> value.
- Enable Apple Intelligence to suggest media-related entities like songs or albums during workouts and similar contexts with <doc://com.apple.documentation/documentation/AppIntents/RelevantEntities>.
- Bridge your app entities to system intent value types by using <doc://com.apple.documentation/documentation/AppIntents/IntentValueRepresentation> in your entity’s `transferRepresentation` property.

### App intents

- Let people perform App Shortcuts, custom shortcuts, system actions, or open another app from interactive widgets with <doc://com.apple.documentation/documentation/AppIntents/RunSystemShortcutIntent>.
- Extend an app intent’s background runtime by adopting <doc://com.apple.documentation/documentation/AppIntents/LongRunningIntent> and calling <doc://com.apple.documentation/documentation/AppIntents/LongRunningIntent/performBackgroundTask(options:operation:)> with a <doc://com.apple.documentation/documentation/AppIntents/LongRunningTaskOptions> value, reporting progress as the task runs.
- Handle cancellation cleanup gracefully by adopting <doc://com.apple.documentation/documentation/AppIntents/CancellableIntent>. Inspect <doc://com.apple.documentation/documentation/AppIntents/IntentCancellationReason> to distinguish a deliberate cancellation from a timeout.
- Reverse the effect of an app intent’s action by adopting <doc://com.apple.documentation/documentation/AppIntents/UndoableIntent>.
- Specify whether your app intent runs in the foreground, the background, or both by setting the `supportedModes` property to an <doc://com.apple.documentation/documentation/AppIntents/IntentModes> value, then consult <doc://com.apple.documentation/documentation/AppIntents/IntentSystemContext/currentMode> inside `perform()` to adapt your code at runtime.
- Tell the system which target may perform your app intent or entity query — the main app, the App Intents extension, or a widget extension — by setting the `allowedExecutionTargets` property to an <doc://com.apple.documentation/documentation/AppIntents/IntentExecutionTargets> option set.

### App entities

- Refer to a large set of entities efficiently using <doc://com.apple.documentation/documentation/AppIntents/EntityCollection>, which stores only entity identifiers and resolves the full <doc://com.apple.documentation/documentation/AppIntents/AppEntity> instances on demand. Use the type for an app intent parameter to avoid resolving every identifier during parameter resolution.
- Define union-type Shortcuts parameters with rich picker UI and custom metadata by adopting <doc://com.apple.documentation/documentation/AppIntents/AppUnionValue> on the type the `@UnionValue` macro generates, along with the <doc://com.apple.documentation/documentation/AppIntents/AppUnionValueCasesProviding> cases enum.
- Have the system retrieve indexed entities by identifier from the Spotlight index by adopting <doc://com.apple.documentation/documentation/AppIntents/IndexedEntityQuery>.

### Errors

- Provide a localized description for failures by initializing an <doc://com.apple.documentation/documentation/AppIntents/AppIntentError> with `init(description:)`, or wrap an existing error that conforms to <doc://com.apple.documentation/documentation/Foundation/CustomLocalizedStringResourceConvertible>.

## June 2025

- Create app intents that conform to <doc://com.apple.documentation/documentation/AppIntents/SnippetIntent> to display an interactive snippet.
- Make app entities available in Spotlight that conform to <doc://com.apple.documentation/documentation/AppIntents/IndexedEntity> and use the `@ComputedProperty(indexingKey:)` or `@Property(indexingKey:)` Swift macros for attributes you want to add to the Spotlight index.
- Integrate your app with visual intelligence by providing app entities to the system using an <doc://com.apple.documentation/documentation/AppIntents/IntentValueQuery>.
- Create an <doc://com.apple.documentation/documentation/AppIntents/AppEntity> that conforms to the <doc://com.apple.documentation/documentation/CoreTransferable/Transferable> protocol and associate the app entity with a <doc://com.apple.documentation/documentation/Foundation/NSUserActivity> using the activity’s <doc://com.apple.documentation/documentation/Foundation/NSUserActivity/appEntityIdentifier> property to make onscreen content available to Siri without adopting an assistant schema.

## November 2024

### Siri and Apple Intelligence

- Make onscreen content available to Siri and Apple Intelligence by describing it as an <doc://com.apple.documentation/documentation/AppIntents/AppEntity> and adopting an assistant schema. Additionally, adopt the <doc://com.apple.documentation/documentation/CoreTransferable/Transferable> protocol, and associate the app entity with a <doc://com.apple.documentation/documentation/Foundation/NSUserActivity> using the activity’s <doc://com.apple.documentation/documentation/Foundation/NSUserActivity/appEntityIdentifier> property.

## June 2024

### System integration

- Integrate your app with Siri and Apple Intelligence using <doc://com.apple.documentation/documentation/AppIntents/app-schema-domains>.
- Use <doc://com.apple.documentation/documentation/AppIntents/ControlConfigurationIntent> and <doc://com.apple.documentation/documentation/WidgetKit> to allow users to put controls on the Lock Screen or in Control Center.
- Create a locked camera capture extension for your app and implement a <doc://com.apple.documentation/documentation/AppIntents/CameraCaptureIntent> to allow people to capture photos and videos from controls or the Action button.
- Create app intents that capture audio by implementing <doc://com.apple.documentation/documentation/AppIntents/AudioRecordingIntent>.
- Allow people to find app entities in Spotlight by adopting the <doc://com.apple.documentation/documentation/AppIntents/IndexedEntity> protocol.

### Content sharing

- Make it possible to share and transfer data you describe as <doc://com.apple.documentation/documentation/AppIntents/app-entities> by conforming to <doc://com.apple.documentation/documentation/CoreTransferable/Transferable>.
- Receive content other apps make available with app intents by using <doc://com.apple.documentation/documentation/AppIntents/IntentFile> for your app intent parameters.
- Describe the file that stores your app intent data using <doc://com.apple.documentation/documentation/AppIntents/FileEntity>.

### General

- Provide additional information about errors with <doc://com.apple.documentation/documentation/AppIntents/AppIntentError/PermissionRequired>, <doc://com.apple.documentation/documentation/AppIntents/AppIntentError/Unrecoverable>, and <doc://com.apple.documentation/documentation/AppIntents/AppIntentError/UserActionRequired>.
- Pass a condition to <doc://com.apple.documentation/documentation/AppIntents/AppIntent/requestConfirmation(conditions:actionName:dialog:)> to only require user confirmation if a person’s context meets the provided condition.
- Use <doc://com.apple.documentation/documentation/AppIntents/URLRepresentableIntent>, <doc://com.apple.documentation/documentation/AppIntents/URLRepresentableEntity>, and <doc://com.apple.documentation/documentation/AppIntents/URLRepresentableEnum> to represent your app intents, app entities, and app enums as universal links that you use to provide deep links to your app’s content.
- Define a set of types for an intent parameter using the <doc://com.apple.documentation/documentation/AppIntents/UnionValue()> macro to create flexible app intents because a parameter can be of one of several pre-defined union types.
- Create entities that have just one singular instance with <doc://com.apple.documentation/documentation/AppIntents/UniqueAppEntity> and the corresponding <doc://com.apple.documentation/documentation/AppIntents/UniqueAppEntityQuery>. For example, to provide an app intent for app settings that appear in your app or in System Settings, create a singleton entity that encapsulates all settings as properties. Use it in the app intent that offers actions to change your app’s settings.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)