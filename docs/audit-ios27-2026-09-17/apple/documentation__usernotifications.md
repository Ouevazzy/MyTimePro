<!--
{
  "availability" : [

  ],
  "documentType" : "symbol",
  "framework" : "UserNotifications",
  "identifier" : "/documentation/UserNotifications",
  "metadataVersion" : "0.1.0",
  "role" : "Framework",
  "symbol" : {
    "kind" : "Framework",
    "modules" : [
      "User Notifications"
    ],
    "preciseIdentifier" : "UserNotifications"
  },
  "title" : "User Notifications"
}
-->

# User Notifications

Push user-facing notifications to the user’s device from a server, or generate them locally from your app.

## Overview

User-facing notifications communicate important information to users of your app, regardless of whether your app is running on the user’s device. For example, a sports app can let the user know when their favorite team scores. Notifications can also tell your app to download information and update its interface. Notifications can display an alert, play a sound, or badge the app’s icon.

![A notification interface displayed on the lock screen and on the Home screen of an iOS device.](images/com.apple.usernotifications/media-4182210@2x.png)

You can generate notifications locally from your app or remotely from a server that you manage. For *local notifications*, the app creates the notification content and specifies a condition, like a time or location, that triggers the delivery of the notification. For *remote notifications*, your company’s server generates push notifications, and Apple Push Notification service (APNs) handles the delivery of those notifications to the user’s devices.

Use this framework to do the following:

- Define the types of notifications that your app supports.
- Define any custom actions associated with your notification types.
- Schedule local notifications for delivery.
- Process already delivered notifications.
- Respond to user-selected actions.

The system makes every attempt to deliver local and remote notifications in a timely manner, but delivery isn’t guaranteed. The PushKit framework offers a more timely delivery mechanism for specific types of notifications, such as those VoIP and watchOS complications use. For more information, see <doc://com.apple.documentation/documentation/PushKit>.

For webpages in Safari version 16.0 and higher, generate remote notifications from a server that you manage using [Push API](https://www.w3.org/TR/push-api/) code that works in Safari and other browsers.

> Note:
> Siri can provide suggestions to users in search, News, Safari, and other apps using on-device information that your app contributes through the Notifications API. Users can change this functionality to allow at any time through Siri and Search settings for your app.

For design guidance, see [Human Interface Guidelines > Notifications](https://developer.apple.com/design/human-interface-guidelines/ios/system-capabilities/notifications/).

## Topics

### Essentials

  <doc://com.apple.documentation/documentation/Updates/UserNotifications>

[Asking permission to use notifications](/documentation/UserNotifications/asking-permission-to-use-notifications)

Request permission to display alerts, play sounds, or badge the app’s icon in response to a notification.

### Notification management

[`class UNUserNotificationCenter`](/documentation/UserNotifications/UNUserNotificationCenter)

The central object for managing notification-related activities for your app or app extension.

[`protocol UNUserNotificationCenterDelegate`](/documentation/UserNotifications/UNUserNotificationCenterDelegate)

An interface for processing incoming notifications and responding to notification actions.

[`class UNNotificationSettings`](/documentation/UserNotifications/UNNotificationSettings)

The object for managing notification-related settings and the authorization status of your app.

### Remote notifications

Generate notifications from your company’s servers, and deliver those notifications using APNs.

[Setting up a remote notification server](/documentation/UserNotifications/setting-up-a-remote-notification-server)

Generate notifications and push them to user devices.

[Sending push notifications using command-line tools](/documentation/UserNotifications/sending-push-notifications-using-command-line-tools)

Use basic macOS command-line tools to send push notifications to Apple Push Notification service (APNs).

[Testing notifications using the Push Notification Console](/documentation/UserNotifications/testing-notifications-using-the-push-notification-console)

Send test notifications and access delivery logs to test your app’s integration with Apple Push Notification service (APNs).

### Notification requests

Create delivery requests for local notifications, and access the content of delivered local and remote notifications.

[Scheduling a notification locally from your app](/documentation/UserNotifications/scheduling-a-notification-locally-from-your-app)

Create and schedule notifications from your app when you want to get the user’s attention.

[`class UNNotificationRequest`](/documentation/UserNotifications/UNNotificationRequest)

A request to schedule a local notification, which includes the content of the notification and the trigger conditions for delivery.

[`class UNNotification`](/documentation/UserNotifications/UNNotification)

The data for a local or remote notification the system delivers to your app.

### Web push notifications

[Sending web push notifications in web apps and browsers](/documentation/UserNotifications/sending-web-push-notifications-in-web-apps-and-browsers)

Update your web server and website to send push notifications that work in Safari, other browsers, and web apps, following cross-browser standards.

### Notification content

Modify and examine the payload of a notification.

[Implementing communication notifications](/documentation/UserNotifications/implementing-communication-notifications)

Configure and display your app’s communication notifications by using intents.

[`protocol UNNotificationContentProviding`](/documentation/UserNotifications/UNNotificationContentProviding)

A protocol the system uses to provide context relevant to user notifications.

[`class UNNotificationActionIcon`](/documentation/UserNotifications/UNNotificationActionIcon)

An icon associated with an action.

[`class UNMutableNotificationContent`](/documentation/UserNotifications/UNMutableNotificationContent)

The editable content for a notification.

[`class UNNotificationContent`](/documentation/UserNotifications/UNNotificationContent)

The uneditable content of a notification.

[`class UNNotificationAttachment`](/documentation/UserNotifications/UNNotificationAttachment)

A media file associated with a notification.

[`class UNNotificationSound`](/documentation/UserNotifications/UNNotificationSound)

The sound played upon delivery of a notification.

[`struct UNNotificationSoundName`](/documentation/UserNotifications/UNNotificationSoundName)

A string providing the name of a sound file.

### Triggers

Define the trigger conditions for delivering notifications. Detect when a remote notification was delivered from APNs.

[`class UNCalendarNotificationTrigger`](/documentation/UserNotifications/UNCalendarNotificationTrigger)

A trigger condition that causes a notification the system delivers at a specific date and time.

[`class UNTimeIntervalNotificationTrigger`](/documentation/UserNotifications/UNTimeIntervalNotificationTrigger)

A trigger condition that causes the system to deliver a notification after the amount of time you specify elapses.

[`class UNLocationNotificationTrigger`](/documentation/UserNotifications/UNLocationNotificationTrigger)

A trigger condition that causes the system to deliver a notification when the user’s device enters or exits a geographic region you specify.

[`class UNPushNotificationTrigger`](/documentation/UserNotifications/UNPushNotificationTrigger)

A trigger condition that indicates Apple Push Notification Service (APNs) has sent the notification.

[`class UNNotificationTrigger`](/documentation/UserNotifications/UNNotificationTrigger)

The common behavior for subclasses that trigger the delivery of a local or remote notification.

### Notification categories and user actions

Define the types of notifications that your app supports, and define how users can respond.

[Declaring your actionable notification types](/documentation/UserNotifications/declaring-your-actionable-notification-types)

Differentiate your notifications and add action buttons to the notification interface.

[`class UNNotificationCategory`](/documentation/UserNotifications/UNNotificationCategory)

A type of notification your app supports and the custom actions that the system displays.

[`class UNNotificationAction`](/documentation/UserNotifications/UNNotificationAction)

A task your app performs in response to a notification that the system delivers.

[`class UNTextInputNotificationAction`](/documentation/UserNotifications/UNTextInputNotificationAction)

An action that accepts user-typed text.

### Notification responses

[Handling notifications and notification-related actions](/documentation/UserNotifications/handling-notifications-and-notification-related-actions)

Respond to user interactions with the system’s notification interfaces, including handling your app’s custom actions.

[`class UNNotificationResponse`](/documentation/UserNotifications/UNNotificationResponse)

The user’s response to an actionable notification.

[`class UNTextInputNotificationResponse`](/documentation/UserNotifications/UNTextInputNotificationResponse)

The user’s response to an actionable notification, including any custom text that the user typed or dictated.

### Notification service app extension

Use a notification service app extension to modify the content of a notification before it’s delivered to your app.

[Modifying content in newly delivered notifications](/documentation/UserNotifications/modifying-content-in-newly-delivered-notifications)

Modify the payload of a remote notification before it’s displayed on the user’s iOS device.

[`class UNNotificationServiceExtension`](/documentation/UserNotifications/UNNotificationServiceExtension)

An object that modifies the content of a remote notification before it’s delivered to the user.

### Entitlements

  <doc://com.apple.documentation/documentation/BundleResources/Entitlements/aps-environment>

  <doc://com.apple.documentation/documentation/BundleResources/Entitlements/com.apple.developer.aps-environment>

### Sample code

[Handling Communication Notifications and Focus Status Updates](/documentation/UserNotifications/handling-communication-notifications-and-focus-status-updates)

Create a richer calling and messaging experience in your app by implementing communication notifications and Focus status updates.

[Implementing Alert Push Notifications](/documentation/UserNotifications/implementing-alert-push-notifications)

Add visible alert notifications to your app by using the UserNotifications framework.

[Implementing Background Push Notifications](/documentation/UserNotifications/implementing-background-push-notifications)

Add background notifications to your app by using the UserNotifications framework.

### Reference

[UserNotifications Constants](/documentation/UserNotifications/usernotifications-constants)

### Classes

[`class UNNotificationAttributedMessageContext`](/documentation/UserNotifications/UNNotificationAttributedMessageContext)

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)