<!--
{
  "documentType" : "article",
  "framework" : "Updates",
  "identifier" : "/documentation/Updates/WidgetKit",
  "metadataVersion" : "0.1.0",
  "role" : "article",
  "title" : "WidgetKit updates"
}
-->

# WidgetKit updates

Learn about important changes in WidgetKit.

## Overview

Browse notable changes in <doc://com.apple.documentation/documentation/WidgetKit>.

## June 2025

### General

- Support Liquid Glass by using the <doc://com.apple.documentation/documentation/WidgetKit/WidgetAccentedRenderingMode>.
- Use WidgetKit push notifications to request timeline reloads from the system by registering a <doc://com.apple.documentation/documentation/WidgetKit/WidgetPushHandler>.
- Update your <doc://com.apple.documentation/documentation/WidgetKit/WidgetFamily/systemSmall> widget to make sure it appears correctly in CarPlay.
- Create controls that use <doc://com.apple.documentation/documentation/WidgetKit/ControlWidgetButton> to execute an action and <doc://com.apple.documentation/documentation/WidgetKit/ControlWidgetToggle> to toggle some state in your app in watchOS and macOS.

### Vision Pro

- Widgets are available on Apple Vision Pro. Support <doc://com.apple.documentation/documentation/WidgetKit/WidgetMountingStyle/elevated> and <doc://com.apple.documentation/documentation/WidgetKit/WidgetMountingStyle/recessed> mounting styles, choose <doc://com.apple.documentation/documentation/WidgetKit/WidgetTexture/glass> or <doc://com.apple.documentation/documentation/WidgetKit/WidgetTexture/paper> textures, and specify layouts for each <doc://com.apple.documentation/documentation/WidgetKit/LevelOfDetail> to show more ore less information based on a person’s proximity.

### Apple Watch

- Offer a relevance-based watchOS widget that uses a <doc://com.apple.documentation/documentation/WidgetKit/RelevanceConfiguration>.
- Let people configure your watchOS widget by offering a widget that uses <doc://com.apple.documentation/documentation/WidgetKit/AppIntentConfiguration>.

## June 2024

### General

- Controls allow people to customize and configure Control Center, their Lock Screen, and the Action button with actions from your apps. Take advantage of <doc://com.apple.documentation/documentation/WidgetKit/ControlWidgetButton> to execute an action and <doc://com.apple.documentation/documentation/WidgetKit/ControlWidgetToggle> to toggle some state in your app.
- Accent views of widgets on iOS and iPadOS using <doc://com.apple.documentation/documentation/SwiftUI/View/widgetAccentable(_:)>.

### Apple Watch

- Create interactive widgets on watchOS using a <doc://com.apple.documentation/documentation/SwiftUI/Button> or <doc://com.apple.documentation/documentation/SwiftUI/Toggle> to perform actions without launching your app.
- Use an <doc://com.apple.documentation/documentation/WidgetKit/AccessoryWidgetGroup> container to provide up to three content views, optionally interactive, in a watchOS widget. Style <doc://com.apple.documentation/documentation/WidgetKit/AccessoryWidgetGroup> content views using <doc://com.apple.documentation/documentation/WidgetKit/AccessoryWidgetGroupStyle/circular> or <doc://com.apple.documentation/documentation/WidgetKit/AccessoryWidgetGroupStyle/roundedSquare>.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)