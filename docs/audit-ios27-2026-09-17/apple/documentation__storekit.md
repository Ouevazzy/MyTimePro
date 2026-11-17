<!--
{
  "availability" : [
    "iOS: 3.0.0 -",
    "iPadOS: 3.0.0 -",
    "macCatalyst: 13.0.0 -",
    "macOS: 10.7.0 -",
    "tvOS: 9.0.0 -",
    "visionOS: 1.0.0 -",
    "watchOS: 6.2.0 -"
  ],
  "documentType" : "symbol",
  "framework" : "StoreKit",
  "identifier" : "/documentation/StoreKit",
  "metadataVersion" : "0.1.0",
  "role" : "Framework",
  "symbol" : {
    "kind" : "Framework",
    "modules" : [
      "StoreKit"
    ],
    "preciseIdentifier" : "StoreKit"
  },
  "title" : "StoreKit"
}
-->

# StoreKit

Support In-App Purchases and interactions with the App Store.

## Overview

Use the StoreKit framework to provide the following features and services for your apps and In-App Purchases:

- In-App Purchase: Offer and promote In-App Purchases for content and services.
- App transaction: Verify a customer’s app purchase with an App Store-signed transaction.
- Messages: Control the display of App Store messages in your app.
- Reviews: Request App Store reviews and ratings from your customers.
- Recommendations : Provide recommendations for third-party content that customers can purchase from the App Store.
- Ad network attribution: Validate advertisement-driven app installations. See <doc://com.apple.documentation/documentation/AdAttributionKit> for app ad campaigns on the App Store and alternative marketplaces.

The StoreKit framework also provides functionality for [External Purchase](/documentation/StoreKit/external-purchase), [External link account](/documentation/StoreKit/external-link-account), [`PaymentMethodBinding`](/documentation/StoreKit/PaymentMethodBinding), and [`StoreDownloaderExtension`](/documentation/StoreKit/StoreDownloaderExtension).

## Topics

### In-App Purchase

[In-App Purchase](/documentation/StoreKit/in-app-purchase)

Offer content and services in your app across Apple platforms using a Swift-based interface.

[Understanding StoreKit workflows](/documentation/StoreKit/understanding-storekit-workflows)

Implement an in-app store with several product types, using StoreKit views.

[Getting started with In-App Purchase using StoreKit views](/documentation/StoreKit/getting-started-with-in-app-purchases-using-storekit-views)

Set up an in-app store using SwiftUI and StoreKit views.

### App transaction

[Supporting business model changes by using the app transaction](/documentation/StoreKit/supporting-business-model-changes-by-using-the-app-transaction)

Access the app transaction to determine when a customer purchased an app and the features to which they’re entitled.

[`struct AppTransaction`](/documentation/StoreKit/AppTransaction)

Information that represents the customer’s purchase of the app, cryptographically signed by the App Store.

### Messages

[`struct Message`](/documentation/StoreKit/Message)

An instance for receiving and displaying App Store messages in your app.

[`struct Reason`](/documentation/StoreKit/Message/Reason-swift.struct)

Reasons for the App Store messages.

[`struct DisplayMessageAction`](/documentation/StoreKit/DisplayMessageAction)

An instance that asks StoreKit to display an App Store message, if appropriate.

### Reviews

[Requesting App Store reviews](/documentation/StoreKit/requesting-app-store-reviews)

Implement best practices for prompting users to review your app in the App Store.

[`struct RequestReviewAction`](/documentation/StoreKit/RequestReviewAction)

An instance that tells StoreKit to request an App Store rating or review, if appropriate.

[`class SKStoreReviewController`](/documentation/StoreKit/SKStoreReviewController)

An object that controls the process of requesting App Store ratings and reviews from customers.

### Recommendations

[Offering media for sale in your app](/documentation/StoreKit/offering-media-for-sale-in-your-app)

Allow users to purchase media in the App Store from within your app.

[`class SKStoreProductViewController`](/documentation/StoreKit/SKStoreProductViewController)

A view controller that provides a page where customers can purchase media from the App Store.

[`class SKOverlay`](/documentation/StoreKit/SKOverlay)

A class that displays an overlay you can use to recommend another app or an App Clip’s corresponding full app.

### Background assets extension

[`@protocol SKDownloaderExtension <BAManagedDownloaderExtension>`](/documentation/StoreKit/SKDownloaderExtension)

An application extension that uses the system implementation to schedule Apple-hosted asset-pack downloads automatically.

[`protocol StoreDownloaderExtension`](/documentation/StoreKit/StoreDownloaderExtension)

An app extension that uses the system implementation to schedule Apple-hosted asset-pack downloads automatically.

### Payment method binding

[`struct PaymentMethodBinding`](/documentation/StoreKit/PaymentMethodBinding)

A binding that makes payment methods available in apps for an Apple Account.

### Ad network attribution

[Ad network attribution](/documentation/StoreKit/ad-network-attribution)

Validate advertisement-driven app installations.

### External Purchase

[External Purchase](/documentation/StoreKit/external-purchase)

Enable qualifying apps to offer external purchases.

### External link account

[External link account](/documentation/StoreKit/external-link-account)

Enable qualifying apps to link to an external website for account creation or management.

### Deprecated

[`class SKCloudServiceSetupViewController`](/documentation/StoreKit/SKCloudServiceSetupViewController)

A view controller that helps people perform setup for a cloud service, like an Apple Music subscription.

[`class SKCloudServiceController`](/documentation/StoreKit/SKCloudServiceController)

An object that determines the current capabilities of a person’s Music library.

### Articles

[Supporting subscription offer codes in your app](/documentation/StoreKit/supporting-subscription-offer-codes-in-your-app)

Provide subscription service for customers who redeem offer codes through the App Store or within your app.

### Structures

[`struct RedeemOption`](/documentation/StoreKit/RedeemOption)

An option that customizes the behavior of an offer code redemption.

## See Also

  <doc://com.apple.documentation/documentation/AppStoreServerAPI>

  <doc://com.apple.documentation/documentation/StoreKitTest>

  <doc://com.apple.documentation/documentation/AppStoreServerNotifications>

  <doc://com.apple.documentation/documentation/AppStoreConnectAPI>

  <doc://com.apple.documentation/documentation/AdvancedCommerceAPI>

  <doc://com.apple.documentation/documentation/AppStoreReceipts>



---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)