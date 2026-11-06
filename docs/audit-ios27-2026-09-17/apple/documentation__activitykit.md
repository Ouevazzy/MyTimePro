<!--
{
  "availability" : [
    "iOS: 16.1.0 -",
    "iPadOS: 16.1.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "ActivityKit",
  "identifier" : "/documentation/ActivityKit",
  "metadataVersion" : "0.1.0",
  "role" : "Framework",
  "symbol" : {
    "kind" : "Framework",
    "modules" : [
      "ActivityKit"
    ],
    "preciseIdentifier" : "ActivityKit"
  },
  "title" : "ActivityKit"
}
-->

# ActivityKit

Share live updates from your app as Live Activities on iPhone, iPad, Apple Watch, and the Mac.

## Overview

With the ActivityKit framework, you can start a Live Activity to share live updates from your app. Live Activities offer a rich, interactive, and highly glanceable way for people to keep track of an event or activity over several hours, especially for apps that push the limit of notifications to provide updated information. For example, a sports app might start a Live Activity that makes live information available at a glance for the duration of a game.

A Live Activity appears in highly visible contexts:

- On iPad and iPhone, it appears on the Lock Screen, in the Dynamic Island, and on the Home Screen.
- On Apple Watch, it appears in the Smart Stack.
- On Mac, it appears in the Menu bar.
- In CarPlay, it appears on the Home Screen.

In addition to viewing real-time information, people perform essential functionality without launching your app using buttons or toggles included in a Live Activity layout or tap the Live Activity to launch the app to a scene that matches the activity’s content.

![Three screenshots of iPhone that show a Live Activity for a delivery app. They show the Live Activity on the Lock Screen, in the leading and trailing presentations in the Dynamic Island, and in the expanded presentation.](images/com.apple.activitykit/live-activity-dynamic-island@2x.png)

In your app, use ActivityKit to configure, start, update, and end the Live Activity, and create the user interface of your Live Activities with a widget extension, <doc://com.apple.documentation/documentation/WidgetKit>, and <doc://com.apple.documentation/documentation/SwiftUI>. By using SwiftUI and WidgetKit, you can share code between widgets and Live Activities or develop them in tandem.

However, Live Activities use a different mechanism to receive updates compared to widgets. Instead of using a timeline mechanism, Live Activities receive updated data from your app with ActivityKit and from your server with ActivityKit push notifications, and you can start Live Activities with ActivityKit push notifications.

> Note: visionOS doesn’t support Live Activities. Requests to start a Live Activity from a compatible iPad or iPhone app fail.

## Topics

### Essentials

  <doc://com.apple.documentation/documentation/WidgetKit/Developing-a-WidgetKit-strategy>

  <doc://com.apple.documentation/documentation/Updates/ActivityKit>

### Starting a Live Activity

[Displaying live data with Live Activities](/documentation/ActivityKit/displaying-live-data-with-live-activities)

Display up-to-date data and offer quick interactions in the Dynamic Island, on the Lock Screen, in CarPlay, and on a paired Mac or Apple Watch.

[Starting and updating Live Activities with ActivityKit push notifications](/documentation/ActivityKit/starting-and-updating-live-activities-with-activitykit-push-notifications)

Use ActivityKit to receive push tokens and to remotely start, update, and end your Live Activity with ActivityKit notifications.

[`class Activity`](/documentation/ActivityKit/Activity)

The object you use to start, update, and end a Live Activity.

  <doc://com.apple.documentation/documentation/WidgetKit/emoji-rangers-supporting-live-activities-interactivity-and-animations>

  <doc://com.apple.documentation/documentation/BundleResources/Information-Property-List/NSSupportsLiveActivities>

  <doc://com.apple.documentation/documentation/BundleResources/Information-Property-List/NSSupportsLiveActivitiesFrequentUpdates>

### User interface

[Creating custom views for Live Activities](/documentation/ActivityKit/creating-custom-views-for-live-activities)

Create reusable custom views and layouts that support each Live Activity presentation.

[Adding accessible descriptions to widgets and Live Activities](/documentation/ActivityKit/adding-accessible-descriptions-to-widgets-and-live-activities)

Describe the interface elements of your widgets and Live Activities to help people understand what they represent.

[Launching your app from a Live Activity](/documentation/ActivityKit/launching-your-app-from-a-live-activity)

Use deep links to enable people to open your app’s scene that matches the data of you Live Activity.

### Widget ecosystem

  <doc://com.apple.documentation/documentation/WidgetKit/Creating-a-Widget-Extension>

  <doc://com.apple.documentation/documentation/WidgetKit/Animating-data-updates-in-widgets-and-live-activities>

  <doc://com.apple.documentation/documentation/WidgetKit/Creating-views-for-widgets-Live-Activities-and-watch-complications>

  <doc://com.apple.documentation/documentation/WidgetKit/Linking-to-specific-app-scenes-from-your-widget-or-Live-Activity>

  <doc://com.apple.documentation/documentation/WidgetKit>



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)