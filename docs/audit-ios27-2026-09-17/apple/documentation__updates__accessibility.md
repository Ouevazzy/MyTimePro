<!--
{
  "documentType" : "article",
  "framework" : "Updates",
  "identifier" : "/documentation/Updates/Accessibility",
  "metadataVersion" : "0.1.0",
  "role" : "article",
  "title" : "Accessibility updates"
}
-->

# Accessibility updates

Learn about important changes to Accessibility.

## Overview

Browse notable changes in <doc://com.apple.documentation/documentation/Accessibility>.

## June 2025

- Add [Accessibility Nutrition Labels](doc://com.apple.documentation/documentation/Accessibility) to your App Store product page to indicate which accessibility features your app supports.
- Support Assistive Access in iOS and iPadOS scenes with <doc://com.apple.documentation/documentation/SwiftUI/AssistiveAccess>.
- Use <doc://com.apple.documentation/documentation/Accessibility/AXBrailleTranslator> to translate print text to Braille and Braille to print text according to a given Braille table.
- Use <doc://com.apple.documentation/documentation/Accessibility/AccessibilitySettings/openSettings(for:)> to open the Settings app to new sections of Accessibility settings, including <doc://com.apple.documentation/documentation/Accessibility/AccessibilitySettings/Feature/assistiveTouch>, <doc://com.apple.documentation/documentation/Accessibility/AccessibilitySettings/Feature/assistiveTouchDevices>, and  <doc://com.apple.documentation/documentation/Accessibility/AccessibilitySettings/Feature/dwellControl>.

## June 2024

### General

- Enhance music with tactile feedback for people who are deaf or hard of hearing by playing Apple-generated haptic tracks along with music tracks. Add the <doc://com.apple.documentation/documentation/BundleResources/Information-Property-List/MusicHapticsSupported> `Info.plist` key to notify the system that your app supports the Music Haptics feature. Specify which song is playing using the <doc://com.apple.documentation/documentation/MediaPlayer/MPNowPlayingInfoPropertyInternationalStandardRecordingCode>. Music Haptics uses the International Standard Recording Code (ISRC) to choose the correct Music Haptics track to play at the same time. Observe and respond to the status of the haptic track playback using <doc://com.apple.documentation/documentation/MediaAccessibility/MAMusicHapticsManager>.
- Open the Settings app to a specific section of Accessibility settings using <doc://com.apple.documentation/documentation/Accessibility/AccessibilitySettings/openSettings(for:)>.
- Support people’s preference to reduce the blinking animation of the text insertion indicator for custom cursor implementations. Check the value of the preference with <doc://com.apple.documentation/documentation/Accessibility/AccessibilitySettings/prefersNonBlinkingTextInsertionIndicator>, and observe when people change that preference with <doc://com.apple.documentation/documentation/Accessibility/AccessibilitySettings/prefersNonBlinkingTextInsertionIndicatorDidChangeNotification>.
- Check if a device uses Assistive Access with <doc://com.apple.documentation/documentation/Accessibility/AccessibilitySettings/isAssistiveAccessEnabled> if you need to remove workflows or UI elements that aren’t appropriate in the context of Assistive Access.

### SwiftUI

- Specify that your accessibility element behaves as a tab bar using the <doc://com.apple.documentation/documentation/SwiftUI/AccessibilityTraits/isTabBar> accessibility trait with the <doc://com.apple.documentation/documentation/SwiftUI/View/accessibilityAddTraits(_:)> modifier. In UIKit, use <doc://com.apple.documentation/documentation/UIKit/UIAccessibilityTraits/tabBar>.
- Enhance how you structure accessibility labels by appending custom content using <doc://com.apple.documentation/documentation/SwiftUI/View/accessibilityLabel(content:)>.
- Generate a localized description of a color in a string interpolation by adding `accessibilityName:`, such as `"\(accessibilityName: myColor)"`. Pass that string to any accessibility modifier.

## June 2023

- Provide a great experience for your app in Assistive Access, an accessibility feature that tailors the iOS and iPadOS experience for people with cognitive disabilities. Adopt <doc://com.apple.documentation/documentation/BundleResources/Information-Property-List/UISupportsFullScreenInAssistiveAccess> to allow your app’s UI to expand into all the available space above the Back button in Assistive Access.
- Personalize your app with Personal Voice, a new feature that lets people record and recreate their voice directly on their iOS and macOS devices. Personal voices appear alongside system voices and are available for Live Speech, a type-to-speak feature that lets a person synthesize speech on the fly. Request access to synthesize speech with personal voices using a new request authorization API in <doc://com.apple.documentation/documentation/AVFAudio/AVSpeechSynthesizer>.
- Detect and mitigate sequences of flashing effects in your video content when the Dim Flashing Lights setting is on. If your app performs custom video drawing instead of using AVFoundation APIs, implement this behavior using <doc://com.apple.documentation/documentation/MediaAccessibility/MAFlashingLightsProcessor>.
- Pause animated images in your app when a person turns off the Animated Images setting on their device. Check the value of this setting using <doc://com.apple.documentation/documentation/SwiftUI/EnvironmentValues/accessibilityPlayAnimatedImages>.
- Send announcement, layout change, screen change, and page scroll accessibility notifications with greater ease in multiplatform apps using the new Swift type <doc://com.apple.documentation/documentation/Accessibility/AccessibilityNotification>. Make sure people receive the most important information first by specifying a default, low, or high priority for announcements.
- Enhance custom accessibility elements by specifying the combination of traits and behaviors that best characterizes the element. Add the new trait <doc://com.apple.documentation/documentation/SwiftUI/AccessibilityTraits/isToggle> to controls that toggle on and off, and the new action <doc://com.apple.documentation/documentation/SwiftUI/View/accessibilityZoomAction(_:)> to content that can zoom in and out.
- Configure new direct touch options through <doc://com.apple.documentation/documentation/SwiftUI/View/accessibilityDirectTouch(_:options:)> to provide the best experience for elements that support direct touch interactions in your app. Specify the <doc://com.apple.documentation/documentation/SwiftUI/AccessibilityDirectTouchOptions/silentOnTouch> option to ensure VoiceOver is silent when a person interacts with the direct touch area so your app can provide its own audio feedback. Specify the <doc://com.apple.documentation/documentation/SwiftUI/AccessibilityDirectTouchOptions/requiresActivation> option to make the direct touch area require VoiceOver to activate the element before touch passthrough happens.
- Simplify how you maintain your UIKit accessibility code with block-based setters for accessibility attributes.
- Ensure robust testing of your app’s accessibility experience by performing accessibility audits using <doc://com.apple.documentation/documentation/XCUIAutomation/XCUIApplication>.
- Assign automation elements to expose certain UI elements specifically for the purpose of automation without affecting the accessibility of those elements.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)