<!--
{
  "availability" : [

  ],
  "documentType" : "symbol",
  "framework" : "Updates",
  "identifier" : "/documentation/Updates",
  "metadataVersion" : "0.1.0",
  "role" : "Featured",
  "symbol" : {
    "kind" : "Featured",
    "modules" : [
      "Updates"
    ],
    "preciseIdentifier" : "Updates"
  },
  "title" : "Updates"
}
-->

# Updates

Latest additions to documentation and platform release notes.

## The 27 platform releases – June 2026

Read about the latest updates to the 27 platform releases. This page highlights changes to framework and tools documentation, as well as release notes for Xcode, macOS, iOS, iPadOS, visionOS, watchOS, and Safari.

---

### Xcode 27

Agentic <doc://com.apple.documentation/documentation/Xcode/coding-intelligence> features in <doc://com.apple.documentation/documentation/Xcode> get even more powerful with support for skills that help you modernize and add new features to your app. For instance, skills can help you ensure your iOS apps respond perfectly as people resize your app using iPhone Mirroring on macOS.

![Screenshot of Xcode 27.](images/com.apple.Updates/xcode-hero@2x.png)

- Xcode works closely with your AI agents of choice.  Read <doc://com.apple.documentation/documentation/Xcode/setting-up-coding-intelligence> to discover how to connect your AI agents to your Xcode project and workspace. Learn about <doc://com.apple.documentation/documentation/Xcode/extending-and-customizing-agents> to understand how Xcode 27 uses skills to supercharge your coding with agents.
- Learn about <doc://com.apple.documentation/documentation/Xcode/writing-code-with-intelligence-in-xcode> and <doc://com.apple.documentation/documentation/Xcode/using-coding-intelligence-in-the-source-editor> to explore new ideas, migrate to new API, and speed your development workflow.
- Read <doc://com.apple.documentation/documentation/Xcode/running-your-app-on-simulated-or-physical-devices> and <doc://com.apple.documentation/documentation/Xcode/managing-your-simulated-and-physical-devices-in-device-hub> to learn about the new <doc://com.apple.documentation/documentation/Xcode/device-hub>.
- Reach more people all over the world by having Xcode help you with <doc://com.apple.documentation/documentation/Xcode/localizing-your-app-using-agents>. This improved localizing workflow is integrated directly into Xcode, bringing your apps to a wider market much faster and easier.

#### Performance and analysis

- Learn how to use the tools and frameworks Xcode provides by reading <doc://com.apple.documentation/documentation/Xcode/improving-your-app-s-performance>. Tools like Instruments and <doc://com.apple.documentation/documentation/MetricKit> can give you the insights you need to make your app perform at its best.
- The new <doc://com.apple.documentation/documentation/StateReporting> framework works with <doc://com.apple.documentation/documentation/MetricKit> and helps you record a specific state for a feature within your app using the <doc://com.apple.documentation/documentation/StateReporting/StateReporter> class.
- Learn to use Instruments when <doc://com.apple.documentation/documentation/Xcode/analyzing-cpu-profiles-with-call-tree-views> to improve app performance, while using <doc://com.apple.documentation/documentation/os/OSSignposter> to annotate your code.

---

### Apple Intelligence and Machine Learning

The 27 platform releases include powerful new developer features that supercharge apps with AI capabilities. <doc://com.apple.documentation/documentation/AppIntents> can connect your app with Siri, Spotlight, and Shortcuts. <doc://com.apple.documentation/documentation/FoundationModels> gives you a standard interface to perform powerful AI tasks across Apple-provided and third-party models. <doc://com.apple.documentation/documentation/CoreAI> lets you connect your own models into the Apple tools as first-class providers. And the <doc://com.apple.documentation/documentation/Evaluations> framework provides a standard interface to evaluate your app’s intelligence-powered features.

#### Siri, Intents, and Spotlight

Your app can integrate with Apple Intelligence in the 27 releases across Apple platforms by leveraging <doc://com.apple.documentation/documentation/AppIntents>,
which make the core features of your app available to Siri, Spotlight, and Shortcuts.
Widgets and Live Activities also interact with your core app through its intents.

- Read the new <doc://com.apple.documentation/documentation/AppIntents/getting-started-with-the-app-intents-framework> guide to acclimate yourself to app intents. And the new <doc://com.apple.documentation/documentation/AppIntents/Creating-your-first-app-intent> article gets you familiar with using intents in your own code.
- Learn how to connect your app into <doc://com.apple.documentation/documentation/AppIntents/apple-intelligence-and-siri-ai>, and explore the code in a sample messaging app in <doc://com.apple.documentation/documentation/AppIntents/integrating-your-messaging-app-with-apple-intelligence>.
- Read <doc://com.apple.documentation/documentation/AppIntentsTesting/testing-your-app-intents-code> to discover how the new <doc://com.apple.documentation/documentation/AppIntentsTesting> framework makes it easier than ever to test your intents to ensure they behave correctly across different user experiences.
- Messaging apps can use the new <doc://com.apple.documentation/documentation/SuggestedActions> framework to privately and securely present actions next to messages. The system can intelligently discover useful information in message text and offer to add an event to the calendar, or add a task to Reminders, or open a location in Maps.
- Use the new <doc://com.apple.documentation/documentation/MediaIntents> framework to enable your media player app to handle Siri requests. Siri turns whatever phrase someone says into an  <doc://com.apple.documentation/documentation/MediaIntents/AudioSearch> type that is sent to your app for handling. The <doc://com.apple.documentation/documentation/MediaIntents/responding-to-audio-search-and-playback-requests> article shows how to add this capability into your own apps.
- Use <doc://com.apple.documentation/documentation/AppIntents/app-entities> types to give additional information about your app to Siri and Apple Intelligence. Read  <doc://com.apple.documentation/documentation/AppIntents/making-app-entities-available-in-spotlight> to see how to make that information available to Spotlight, as well.
- Follow the sample code to learn about <doc://com.apple.documentation/documentation/AppIntents/adopting-app-intents-to-support-system-experiences> and ensure Apple Intelligence can interact with your app across Shortcuts, Spotlight, and Siri.
- Experiment with the Travel Tracking sample project included in the article <doc://com.apple.documentation/documentation/AppIntents/adopting-app-intents-to-support-system-experiences> to see lots of examples of using intents within an app or widget.
- Read <doc://com.apple.documentation/documentation/CoreSpotlight/adding-your-app-s-content-to-spotlight-indexes> to see how to use <doc://com.apple.documentation/documentation/CoreSpotlight> to give people access to activities and items within your app directly from the Spotlight interface.
- Learn to use the <doc://com.apple.documentation/documentation/VisualIntelligence> framework on iOS, iPadOS, and now macOS by reading <doc://com.apple.documentation/documentation/VisualIntelligence/integrating-your-app-with-visual-intelligence>. This enables your app to analyze image data from the camera to identify places and objects.

### Foundation Models

The 27 platform releases add powerful new API to the <doc://com.apple.documentation/documentation/FoundationModels> framework. Developers can now use a single, standard interface to connect to all their models – from Apple’s on-device models to the powerful Private Cloud Compute hosted models. Frontier model providers can use the new <doc://com.apple.documentation/documentation/FoundationModels/LanguageModel> protocol to vend a Swift package to bridge their powerful cloud-hosted models to the Foundation Models API. And with <doc://com.apple.documentation/documentation/CoreAI>, Foundation Models API can access your own models, too.

- Read <doc://com.apple.documentation/documentation/FoundationModels/generating-content-and-performing-tasks-with-foundation-models> to get started building with Foundation Models, and create your first <doc://com.apple.documentation/documentation/FoundationModels/Prompt>.
- When your app can benefit from a larger, cloud-based model you can learn about <doc://com.apple.documentation/documentation/FoundationModels/adding-server-side-intelligence-with-private-cloud-compute>. With Private Cloud Compute (PCC) you get a larger token context size, and stronger reasoning for handling more complex tasks. The <doc://com.apple.documentation/documentation/FoundationModels/PrivateCloudComputeLanguageModel> class conforms to <doc://com.apple.documentation/documentation/FoundationModels/LanguageModel> just as other frontier models do.
- Foundation Models now supports image input as well as text, which you can learn to use by reading <doc://com.apple.documentation/documentation/FoundationModels/analyzing-images-with-multimodal-prompting>. The models can help you classify the image, summarize the content, generate accessibility descriptions on the fly, and more. Use an <doc://com.apple.documentation/documentation/FoundationModels/Attachment> to send the image to the model along with your prompt.
- Read <doc://com.apple.documentation/documentation/FoundationModels/analyzing-the-runtime-performance-of-your-foundation-models-app> to learn about optimization techniques that make the AI components of your app perform their best.
- Learn how to measure and improve your prompts by reading <doc://com.apple.documentation/documentation/FoundationModels/evaluating-prompts-to-measure-performance-and-improve-model-responses> and develop a strategy about <doc://com.apple.documentation/documentation/FoundationModels/managing-the-context-window> to optimize token use.

![Screenshot of the Origami sample for Foundation Models on an iPad and iPhone.](images/com.apple.Updates/origami-hero@2x.png)

Explore the Origami sample that demonstrates Foundation Models with Private Cloud Compute or third-party models, shown in the Platform State of the Union by reading <doc://com.apple.documentation/documentation/FoundationModels/origami-crafting-a-dynamic-tutorial-for-apple-intelligence>.

#### Core AI

The <doc://com.apple.documentation/documentation/CoreAI> framework includes a set of tools that help you build, run, and deploy your own AI models within your app. Core AI also vends your custom AI models in a format that Foundation Models can use natively, so once adapted to Core AI, your models can interact with the same Foundation Models code you write when working with Apple’s own built-in models.

- Designed for Apple silicon performance, <doc://com.apple.documentation/documentation/CoreAI/integrating-on-device-ai-models-in-your-app-with-core-ai> details how to easily import third-party or your own models into your app, and achieve great performance.
- Read <doc://com.apple.documentation/documentation/CoreAI/managing-model-specialization-and-caching> to see how best to specialize your AI model, either in advance by <doc://com.apple.documentation/documentation/CoreAI/compiling-core-ai-models-ahead-of-time>, or cached on first use within the app.

#### Evaluations

- The new <doc://com.apple.documentation/documentation/Evaluations> framework makes it easy to write intuitive Swift code to evaluate the behavior of your model, and validate your app’s behavior due to model results.
- Read <doc://com.apple.documentation/documentation/Evaluations/evaluating-language-model-responses> to learn how you can build a strategy to evaluate your use of models within your app. Writing evaluations and creating comprehensive coverage is outlined in the article <doc://com.apple.documentation/documentation/Evaluations/designing-effective-evaluations>.
- Good evaluations require time spent <doc://com.apple.documentation/documentation/Evaluations/designing-evaluation-datasets> as well as <doc://com.apple.documentation/documentation/Evaluations/designing-evaluation-criteria>. Reading <doc://com.apple.documentation/documentation/Evaluations/generating-synthetic-evaluation-datasets> can help you build synthetic data to quickly get even more coverage.

---

### SwiftUI

- Learn to use reorderable containers in your SwiftUI apps by reading  <doc://com.apple.documentation/documentation/SwiftUI/Reordering-items-in-lists-stacks-grids-and-custom-layouts>. See how clean the code can look:

```swift
LazyVStack {
    ForEach(cranes) { crane in
        CraneRow(crane)
    }
    .reorderable()
}
.reorderContainer(
    for: Crane.self
) { difference in
    difference.apply(to: &cranes)
}
```

- Take advantage of the recent improvements in the 27 platform releases when using <doc://com.apple.documentation/documentation/SwiftUI/ContentBuilder> and <doc://com.apple.documentation/documentation/SwiftUI/ViewBuilder>.
- The <doc://com.apple.documentation/documentation/SwiftUI/State()> property wrapper has been upgraded in Xcode 27 to be a macro, making it easier to use while getting great performance.
- The new document infrastructure is implemented within <doc://com.apple.documentation/documentation/SwiftUI/DocumentGroup> and utilizing more powerful URL types. And explore the new <doc://com.apple.documentation/documentation/SwiftUI/WritableDocument> and <doc://com.apple.documentation/documentation/SwiftUI/ReadableDocument> protocols.
- The <doc://com.apple.documentation/documentation/SwiftUI/AsyncImage> type is much faster with improved caching.
- Check out the new <doc://com.apple.documentation/documentation/SwiftUI/Composing-advanced-graphics-effects-with-SwiftUI> sample project.

---

### UIKit

- Use <doc://com.apple.documentation/documentation/UIKit/UICollectionViewCompositionalLayoutSectionProvider> closures as part of automatic observation tracking to automatically invalidate and update compositional layouts when observable objects change.
- Adopt the UIKit scene-based life cycle using the guidance in <doc://com.apple.documentation/documentation/UIKit/transitioning-to-the-uikit-scene-based-life-cycle>. Starting in iOS 27, apps built with the latest SDK must use the scene-based life cycle or they fail to launch.
- Learn more about advanced TextKit formatting by reading <doc://com.apple.documentation/documentation/UIKit/adding-tables-to-attributed-strings>. And take total control of view and layout of text to create your own custom experience by reading <doc://com.apple.documentation/documentation/UIKit/managing-viewport-layout-and-attachment-reuse-in-a-text-view-subclass>.

---

### AppKit

- Create events similar to UIControl events on NSControl with the new <doc://com.apple.documentation/documentation/AppKit/NSControl/Events> type.
- Update views automatically in response to Observable model changes using the guidance in <doc://com.apple.documentation/documentation/AppKit/updating-views-automatically-with-observation-tracking-in-appkit>.
- macOS 27 improves the touch experience when your Mac app is running on an iPad as a Sidecar display. Read <doc://com.apple.documentation/documentation/Technotes/tn3212-adopting-gesture-recognizers-for-sidecar-touch-support> for best practices to ensure your app behaves as expected on a Sidecar display.

---

### SwiftData

- Read the latest article update to help you migrate your Core Data app to use SwiftData with <doc://com.apple.documentation/documentation/CoreData/adopting-swiftdata-for-a-core-data-app>.
- Learn how to use <doc://com.apple.documentation/documentation/SwiftData/Query/sections> with <doc://com.apple.documentation/documentation/swiftdata/resultssectioncollection> and a SwiftData <doc://com.apple.documentation/documentation/SwiftData/Query>.

---

### Privacy and Security

- Developers of sensitive and secure apps can use the <doc://com.apple.documentation/documentation/TrustInsights> framework to request an evaluation from the system to help detect if someone is at risk of a social engineering threat. This information can be used in combination with other factors to enable a developer to help keep their users more protected.

---

### Graphics and Media

- Create immersive games in visionOS with RealityKit and Reality Composer 3. Read <doc://com.apple.documentation/documentation/visionOS/chaparral-village-building-an-immersive-visionos-adventure-game> to create an adventure game with navigation mesh, animation graph, cloth simulation, and baked lighting. Read <doc://com.apple.documentation/documentation/visionOS/designing-no-code-games-in-reality-composer-pro-3> to create a game without code using script graphs.
- Use the <doc://com.apple.documentation/documentation/SpatialPreview> framework to work with 3D spatial content from a macOS app within a connected visionOS device in real time.
- Track generic spatial accessories (purpose-built devices like medical instruments or industrial tooling) and augment them with virtual content in visionOS. Read <doc://com.apple.documentation/documentation/ARKit/preparing-spatial-accessories-for-tracking-in-your-visionos-app> to create a reference file for your accessory. Read <doc://com.apple.documentation/documentation/visionOS/working-with-generic-spatial-accessories> to bundle that accessory file and track the device with ARKit.
- The new <doc://com.apple.documentation/documentation/MusicUnderstanding> framework gives you the power to analyze and fully understand the technical details of audio content with details such as rhythm, pace, loudness, key, and instrument activity.
- Use the new <doc://com.apple.documentation/documentation/NowPlaying> framework to let the system control playback of your media in the standard playback interface across the Lock Screen, in Control Center, on Apple Watch, and in CarPlay. Read <doc://com.apple.documentation/documentation/NowPlaying/publishing-media-sessions> to see how you can take advantage of this framework in your own media app.
- Hardware vendors can use the new <doc://com.apple.documentation/documentation/MediaDevice> framework to create an extension that enables any app to stream to their device using built-in system affordances. Read <doc://com.apple.documentation/documentation/MediaDevice/creating-a-media-device-extension> to see how you can create an extension to stream to your unique hardware.
- The <doc://com.apple.documentation/documentation/AVSystemRouting> framework adds new API to easily send media to all sorts of devices that implement a media device extension. Read <doc://com.apple.documentation/documentation/AVSystemRouting/routing-media-to-third-party-devices> to see how to route media from your own apps.

---

### Health

- Access workout zone data for heart rate and cycling power, and learn about the  <doc://com.apple.documentation/documentation/HealthKit/HKWorkoutZoneGroup> structure by reading <doc://com.apple.documentation/documentation/HealthKit/accessing-workout-zone-data>.
- Read the new article <doc://com.apple.documentation/documentation/HealthKit/recording-and-querying-menopausal-state> to help personalize the experience within your health-related app.

---

### Apple Pay, Passes, and Commerce

- Read the article <doc://com.apple.documentation/documentation/ProximityReader/adding-support-for-tap-to-share-to-your-app> to see how to use the <doc://com.apple.documentation/documentation/ProximityReader> framework to use nearby iPhones to conduct in-person transactions.
- See the new customization features in <doc://com.apple.documentation/documentation/WalletPasses/creating-an-airline-boarding-pass-using-semantic-tags> to make your app’s passes even more useful in the moment. <doc://com.apple.documentation/documentation/WalletPasses/creating-a-pass-with-pass-designer> explains how the Pass Designer tool can help you visualize and design your passes. <doc://com.apple.documentation/documentation/WalletPasses/defining-the-metadata-of-your-wallet-pass> explains how to include additional information with your pass.

---

### Platform services

- With iOS 27, people can easily switch from one iPhone to another. Read about <doc://com.apple.documentation/documentation/CoreTelephony/iphone-quick-switch> and how to follow best practices using the <doc://com.apple.documentation/documentation/CoreTelephony> framework to ensure your app gracefully handles this switch.
- Use the <doc://com.apple.documentation/documentation/CrashReportExtension> framework to perform on-device analysis and produce a report when your app crashes. This crash-handling code will then run out of process, managed by the system. Implement the <doc://com.apple.documentation/documentation/CrashReportExtension/CrashReporterExtension> to create your own custom crash report.
- The new <doc://com.apple.documentation/documentation/DiskImageKit> framework provides a programmatic API for developers to create, open, and manage disk images. It is especially useful within the <doc://com.apple.documentation/documentation/Virtualization> framework as storage for virtual machine archives.
- Use the new compression algorithms, `LZRaven` and `LZMesh` for more efficient and faster results. Read about the <doc://com.apple.documentation/documentation/Compression/compression_algorithm> type to understand the recommended defaults when sharing files among Apple devices. The <doc://com.apple.documentation/documentation/Compression> and <doc://com.apple.documentation/documentation/AppleArchive> frameworks take advantage of these new algorithms.
- The <doc://com.apple.documentation/documentation/MetricKit> framework is significantly upgraded for the 27 platform releases. Read how to <doc://com.apple.documentation/documentation/MetricKit/track-performance-by-app-state-using-metrickit> to get the data you need to understand how your app performs in the real world.
- Learn powerful PencilKit features you can add to your app with the <doc://com.apple.documentation/documentation/PencilKit/building-a-handwriting-recognition-experience-with-pencilkit> sample code project and article. The <doc://com.apple.documentation/documentation/PencilKit/controlling-stroke-rendering-for-animation-and-editing> article dives deep into handling pencil strokes as well.
- The <doc://com.apple.documentation/documentation/DeviceCheck> framework brings App Attest to macOS with additional device information to protect your app from unauthorized modification and fraud.
- Apps using <doc://com.apple.documentation/documentation/EnergyKit> can learn about <doc://com.apple.documentation/documentation/EnergyKit/providing-informative-charging-history-for-electric-vehicles> to the Home app, including activity logs and useful insights.

## Topics

### Release notes

  <doc://com.apple.documentation/documentation/ios-ipados-release-notes>

  <doc://com.apple.documentation/documentation/macos-release-notes>

  <doc://com.apple.documentation/documentation/tvos-release-notes>

  <doc://com.apple.documentation/documentation/watchos-release-notes>

  <doc://com.apple.documentation/documentation/visionos-release-notes>

  <doc://com.apple.documentation/documentation/Xcode-Release-Notes>

  <doc://com.apple.documentation/documentation/safari-release-notes>

### Technology and frameworks

[Accelerate updates](/documentation/Updates/Accelerate)

Learn about important changes to Accelerate.

[Accessibility updates](/documentation/Updates/Accessibility)

Learn about important changes to Accessibility.

[ActivityKit updates](/documentation/Updates/ActivityKit)

Learn about important changes in ActivityKit.

[AdAttributionKit Updates](/documentation/Updates/AdAttributionKit)

Learn about important changes to AdAttributionKit.

[App Clips updates](/documentation/Updates/AppClips)

Learn about important changes in App Clips.

[App Intents updates](/documentation/Updates/AppIntents)

Learn about important changes in App Intents.

[AppKit updates](/documentation/Updates/AppKit)

Learn about important changes to AppKit.

[Apple Intelligence updates](/documentation/Updates/Apple-Intelligence)

Learn about important changes to Apple Intelligence.

[AppleMapsServerAPI Updates](/documentation/Updates/AppleMapsServerAPI)

Learn about important changes to AppleMapsServerAPI.

[Apple Pencil updates](/documentation/Updates/ApplePencil)

Learn about important changes to Apple Pencil.

[ARKit updates](/documentation/Updates/ARKit)

Learn about important changes to ARKit.

[Audio Toolbox updates](/documentation/Updates/AudioToolbox)

Learn about important changes to Audio Toolbox.

[AuthenticationServices updates](/documentation/Updates/AuthenticationServices)

Learn about important changes to AuthenticationServices.

[AVFAudio updates](/documentation/Updates/AVFAudio)

Learn about important changes to AVFAudio.

[AVFoundation updates](/documentation/Updates/AVFoundation)

Learn about important changes to AVFoundation.

[AVKit updates](/documentation/Updates/AVKit)

Learn about important changes to AVKit.

[Background Tasks updates](/documentation/Updates/BackgroundTasks)

Learn about important changes in Background Tasks.

[Bundle Resources updates](/documentation/Updates/BundleResources)

Learn about important changes to Bundle Resources.

[CallKit updates](/documentation/Updates/CallKit)

Learn about important changes to CallKit.

[ContactsUI updates](/documentation/Updates/ContactsUI)

Learn about important changes to ContactsUI.

[Core Location updates](/documentation/Updates/CoreLocation)

Learn about important changes to Core Location.

[Core MIDI updates](/documentation/Updates/CoreMIDI)

Learn about important changes to Core MIDI.

[Core ML updates](/documentation/Updates/CoreML)

Learn about important changes to Core ML.

[Core Motion updates](/documentation/Updates/CoreMotion)

Learn about important changes to Core Motion.

[Core Spotlight updates](/documentation/Updates/CoreSpotlight)

Learn about important changes to Core Spotlight.

[DataDetection updates](/documentation/Updates/DataDetection)

Learn about important changes in DataDetection.

[Default apps updates](/documentation/Updates/DefaultApps)

Learn about the latest changes to enabling your app to be the system default.

[DockKit updates](/documentation/Updates/DockKit)

Learn about important changes to DockKit.

[EnergyKit updates](/documentation/Updates/EnergyKit)

Learn about important changes to EnergyKit.

[File Provider updates](/documentation/Updates/FileProvider)

Learn about important changes to File Provider.

[FinanceKit updates](/documentation/Updates/FinanceKit)

Learn more about changes to FinanceKit.

[Foundation updates](/documentation/Updates/Foundation)

Learn about important changes to Foundation.

[Foundation Models updates](/documentation/Updates/FoundationModels)

Learn about important changes to Foundation Models.

[FSKit updates](/documentation/Updates/FSKit)

Learn about important changes to FSKit.

[Game Controller updates](/documentation/Updates/GameController)

Learn about important changes to Game Controller.

[GameKit updates](/documentation/Updates/GameKit)

Learn about important changes to GameKit.

[Group Activities updates](/documentation/Updates/GroupActivities)

Learn about important changes to Group Activities.

[HealthKit updates](/documentation/Updates/HealthKit)

Learn about important changes to HealthKit.

[Hypervisor updates](/documentation/Updates/Hypervisor)

Learn about important changes to Hypervisor.

[Journaling Suggestions updates](/documentation/Updates/JournalingSuggestions)

Learn about important changes in Journaling Suggestions.

[LightweightCodeRequirements updates](/documentation/Updates/LightweightCodeRequirements)

Learn about important changes to LightweightCodeRequirements.

[LiveCommunicationKit updates](/documentation/Updates/LiveCommunicationKit)

Learn about important changes to LiveCommunicationKit.

[MapKit updates](/documentation/Updates/MapKit)

Learn about important changes to MapKit.

[MapKitJS updates](/documentation/Updates/MapKitJS)

Learn about important changes to MapKitJS.

[Matter updates](/documentation/Updates/Matter)

Learn about important changes to Matter.

[MetricKit updates](/documentation/Updates/MetricKit)

Learn about important changes to MetricKit.

[Network updates](/documentation/Updates/Network)

Learn about important changes to Network.

[Network Extension updates](/documentation/Updates/NetworkExtension)

Learn about important changes to Network Extension.

[PaperKit updates](/documentation/Updates/PaperKit)

Learn about important changes to PaperKit.

[PassKit updates](/documentation/Updates/PassKit)

Learn more about changes to PassKit.

[PencilKit updates](/documentation/Updates/PencilKit)

Learn about important changes to PencilKit.

[PHASE updates](/documentation/Updates/PHASE)

Learn about important changes to PHASE.

[PhotoKit updates](/documentation/Updates/PhotoKit)

Learn about important changes to PhotoKit and PhotosUI.

[ProximityReader updates](/documentation/Updates/ProximityReader)

Learn about important changes to ProximityReader.

[RealityKit updates](/documentation/Updates/RealityKit)

Learn about important changes in RealityKit.

[SafariServices updates](/documentation/Updates/SafariServices)

Learn about important changes in SafariServices.

[ScreenCaptureKit updates](/documentation/Updates/ScreenCaptureKit)

Learn about important changes to ScreenCaptureKit.

[Security updates](/documentation/Updates/Security)

Learn about important changes to Security.

[Sensitive Content Analysis updates](/documentation/Updates/SensitiveContentAnalysis)

Learn about important changes to Sensitive Content Analysis.

[SensorKit updates](/documentation/Updates/SensorKit)

Learn about important changes to SensorKit.

[ShazamKit updates](/documentation/Updates/ShazamKit)

Learn about important changes in ShazamKit.

[SiriKit updates](/documentation/Updates/SiriKit)

Learn about important changes in SiriKit.

[Speech updates](/documentation/Updates/Speech)

Learn about important changes to Speech.

[StoreKit updates](/documentation/Updates/StoreKit)

Learn about important changes in StoreKit.

[Swift updates](/documentation/Updates/Swift)

Learn about important changes to Swift.

[Swift Charts updates](/documentation/Updates/SwiftCharts)

Learn about important changes to Swift Charts.

[SwiftData updates](/documentation/Updates/SwiftData)

Learn about important changes to SwiftData.

[SwiftUI updates](/documentation/Updates/SwiftUI)

Learn about important changes to SwiftUI.

[Symbols updates](/documentation/Updates/Symbols)

Learn about important changes to Symbols.

[TipKit updates](/documentation/Updates/TipKit)

Learn about important changes in TipKit.

[ThreadNetwork updates](/documentation/Updates/ThreadNetwork)

Learn about important changes in ThreadNetwork.

[UIKit updates](/documentation/Updates/UIKit)

Learn about important changes to UIKit.

[User Notifications updates](/documentation/Updates/UserNotifications)

Learn about important changes in User Notifications.

[Video Subscriber Account updates](/documentation/Updates/VideoSubscriberAccount)

Learn about important changes in Video Subscriber Account.

[Virtualization updates](/documentation/Updates/Virtualization)

Learn about important changes to Virtualization.

[Vision updates](/documentation/Updates/Vision)

Learn about important changes in Vision.

[Visual Intelligence updates](/documentation/Updates/VisualIntelligence)

Learn about important changes in Visual Intelligence.

[watchOS updates](/documentation/Updates/watchos)

Learn about important changes to watchOS.

[WeatherKit updates](/documentation/Updates/WeatherKit)

Learn about important changes to WeatherKit.

[WidgetKit updates](/documentation/Updates/WidgetKit)

Learn about important changes in WidgetKit.

[WorkoutKit updates](/documentation/Updates/WorkoutKit)

Learn about important changes to WorkoutKit.

[Xcode updates](/documentation/Updates/Xcode)

Learn about important changes to Xcode.

[XCUIAutomation updates](/documentation/Updates/XCUIAutomation)

Learn about important changes to XCUIAutomation.

[XPC updates](/documentation/Updates/XPC)

Learn about important changes to XPC.

### Past releases

[WWDC25](/documentation/Updates/wwdc2025)

Highlights of new technologies introduced at WWDC25.

[WWDC24](/documentation/Updates/wwdc2024)

Highlights of new technologies introduced at WWDC24.

[WWDC23](/documentation/Updates/wwdc2023)

Highlights of new technologies introduced at WWDC23.

[WWDC22](/documentation/Updates/wwdc2022)

Highlights of new technologies introduced at WWDC22.

[WWDC21](/documentation/Updates/wwdc2021)

Highlights of new technologies introduced at WWDC21.



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)