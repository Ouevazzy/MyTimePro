<!--
{
  "documentType" : "article",
  "framework" : "Updates",
  "identifier" : "/documentation/Updates/SwiftUI",
  "metadataVersion" : "0.1.0",
  "role" : "article",
  "title" : "SwiftUI updates"
}
-->

# SwiftUI updates

Learn about important changes to SwiftUI.

## Overview

Browse notable changes in <doc://com.apple.documentation/documentation/SwiftUI>.

## September 2026

### Arrangement views

- Arrange primary and secondary content using an adaptive layout that responds to the environment with <doc://com.apple.documentation/documentation/SwiftUI/ArrangementView>.
- Configure the style of an <doc://com.apple.documentation/documentation/SwiftUI/ArrangementView> using the <doc://com.apple.documentation/documentation/SwiftUI/View/arrangementViewStyle(_:)> modifier.
- Create a custom arrangement style by conforming to <doc://com.apple.documentation/documentation/SwiftUI/ArrangementViewStyle> and implementing <doc://com.apple.documentation/documentation/SwiftUI/ArrangementViewStyle/makeBody(configuration:)>, which provides access to the arrangement’s <doc://com.apple.documentation/documentation/SwiftUI/ArrangementViewStyleConfiguration/primary-swift.property> and <doc://com.apple.documentation/documentation/SwiftUI/ArrangementViewStyleConfiguration/secondary-swift.property> content.
- Place the primary and secondary views of an arrangement view side by side along one or more axes using the <doc://com.apple.documentation/documentation/SwiftUI/ArrangementViewStyle/split> style, and restrict which axes the split arrangement can use with <doc://com.apple.documentation/documentation/SwiftUI/SplitArrangementViewStyle/axes(_:)>.
- Set the preferred or constrained size ratio for a view relative to its related view in a split arrangement using <doc://com.apple.documentation/documentation/SwiftUI/View/splitArrangementLayoutRatio(_:)> or <doc://com.apple.documentation/documentation/SwiftUI/View/splitArrangementLayoutRatio(minHorizontal:idealHorizontal:maxHorizontal:minVertical:idealVertical:maxVertical:)>.
- Set size constraints for a view in a split arrangement using absolute width and height values with <doc://com.apple.documentation/documentation/SwiftUI/View/splitArrangementLayoutSize(minWidth:idealWidth:maxWidth:minHeight:idealHeight:maxHeight:)>, or prefer the view’s own ideal size with <doc://com.apple.documentation/documentation/SwiftUI/View/splitArrangementFixedLayoutSize(horizontal:vertical:)>.
- Read the axis of the current split arrangement from a subview using the <doc://com.apple.documentation/documentation/SwiftUI/EnvironmentValues/splitArrangementAxis> environment value.
- Layer the primary view over the secondary view in z-order using the <doc://com.apple.documentation/documentation/SwiftUI/ArrangementViewStyle/overlay> style, and restrict the axes on which the overlay can transition to a side-by-side layout with <doc://com.apple.documentation/documentation/SwiftUI/OverlayArrangementViewStyle/axes(_:)>. Anchor the overlaid content to a specific vertical or horizontal edge with the <doc://com.apple.documentation/documentation/SwiftUI/View/overlayArrangementEdge(_:)> modifier.
- Read the z-index of a view within an overlay arrangement using the <doc://com.apple.documentation/documentation/SwiftUI/EnvironmentValues/overlayArrangementZIndex> environment value.

### Reserved regions

- Identify and avoid a region of a view reserved by hardware, such as a camera or the hinge, using <doc://com.apple.documentation/documentation/SwiftUI/ReservedRegion>.
- Query the reserved regions that intersect a view using the <doc://com.apple.documentation/documentation/SwiftUI/GeometryProxy/reservedRegions(kind:options:layoutDirectionBehavior:)> method, specifying a <doc://com.apple.documentation/documentation/SwiftUI/ReservedRegion/Kind-swift.struct> such as `.occlusion` or `.division`.
- Include inactive reserved regions in a query using the <doc://com.apple.documentation/documentation/SwiftUI/ReservedRegion/QueryOptions/includeInactive> option.
- Identify a reserved region across coordinate spaces, or track it over time, using its opaque <doc://com.apple.documentation/documentation/SwiftUI/ReservedRegion/ID-swift.struct> identifier.

### Hinge

- Observe changes to the state of the hinge on iPhone Duo using the <doc://com.apple.documentation/documentation/SwiftUI/View/onHingeChange(isEnabled:_:)> modifier, which delivers updates through <doc://com.apple.documentation/documentation/SwiftUI/DeviceHingeContext>.
- Read the hinge’s current angle and status, such as `.closed`, `.partiallyOpen`, or `.fullyOpen`, using <doc://com.apple.documentation/documentation/SwiftUI/DeviceHinge>.

### Scene accessories

- Present content on the outer display of iPhone Duo while the device is open, the app is in the foreground, and a camera capture session is active, using <doc://com.apple.documentation/documentation/SwiftUI/CameraCaptureAccessory>.

### Controls on the vertical axis

- Read the edge where the system places controls on the vertical axis using the <doc://com.apple.documentation/documentation/SwiftUI/EnvironmentValues/toolbarVerticalEdge> environment value, then position custom bars or other UI relative to the system’s placement.
- Opt a view out of showing bar content on the vertical axis, causing bar content to fall back to the standard horizontal top and bottom toolbars, using the <doc://com.apple.documentation/documentation/SwiftUI/View/toolbarVerticalBehavior(_:)> modifier.
- Control whether a toolbar item appears on the vertical or horizontal axis using the <doc://com.apple.documentation/documentation/SwiftUI/ToolbarContent/axisBehavior(_:)> and <doc://com.apple.documentation/documentation/SwiftUI/CustomizableToolbarContent/axisBehavior(_:)> modifiers with a <doc://com.apple.documentation/documentation/SwiftUI/ToolbarItemAxisBehavior> value, such as `.horizontalOnly` or `.verticalPreferred`.
- Manage how bars compress when the system renders different types of bars together and space is constrained using the <doc://com.apple.documentation/documentation/SwiftUI/View/toolbarVerticalCompressionBehavior(_:)> modifier with a <doc://com.apple.documentation/documentation/SwiftUI/ToolbarVerticalCompressionBehavior> value, such as `.prefersToolbarItems` or `.prefersTabBar`.

## June 2026

### General

- Build your project in Xcode 27 or later so that the `@State` attribute uses the <doc://com.apple.documentation/documentation/SwiftUI/State()> macro to create a state value in an <doc://com.apple.documentation/documentation/SwiftUI/App>, <doc://com.apple.documentation/documentation/SwiftUI/Scene>, or <doc://com.apple.documentation/documentation/SwiftUI/View>. This change only initializes and stores your property once when it’s a class.
- Build your project in Xcode 27 or later to construct type-agnostic content from closures that you mark with <doc://com.apple.documentation/documentation/SwiftUI/ContentBuilder>, which serves as the unified replacement for type-specific builders like <doc://com.apple.documentation/documentation/SwiftUI/ToolbarContentBuilder> and <doc://com.apple.documentation/documentation/SwiftUI/CommandsBuilder>.
- Add reordering by drag-and-drop in containers such as lists, stacks, grids, or custom layouts with <doc://com.apple.documentation/documentation/SwiftUI/DynamicViewContent/reorderable()> and <doc://com.apple.documentation/documentation/SwiftUI/View/reorderContainer(for:isEnabled:move:)>.
- Add custom swipe actions to views in containers such as scroll views, stacks, grids, or custom layouts using <doc://com.apple.documentation/documentation/SwiftUI/View/swipeActions(edge:allowsFullSwipe:content:onPresentationChanged:)> and <doc://com.apple.documentation/documentation/SwiftUI/View/swipeActionsContainer()>.

### Transitions

- Specify the  <doc://com.apple.documentation/documentation/SwiftUI/NavigationTransition/crossFade> transition to have a sheet appear by fading in over content.

### Images

- Cache images locally that you download with <doc://com.apple.documentation/documentation/SwiftUI/AsyncImage>, using <doc://com.apple.documentation/documentation/SwiftUI/View/asyncImageURLSession(_:)>, <doc://com.apple.documentation/documentation/SwiftUI/AsyncImage/init(request:scale:)>, <doc://com.apple.documentation/documentation/SwiftUI/AsyncImage/init(request:scale:content:placeholder:)>, and <doc://com.apple.documentation/documentation/SwiftUI/AsyncImage/init(request:scale:transaction:content:)>.

### Toolbars

- Use the <doc://com.apple.documentation/documentation/SwiftUI/ToolbarContent/visibilityPriority(_:)> modifier to prioritize important toolbar actions so SwiftUI keeps them visible as space shrinks, moving lower-priority items to the overflow menu first.
- Send secondary toolbar actions, like archive or delete, directly to the overflow menu by wrapping them in a <doc://com.apple.documentation/documentation/SwiftUI/ToolbarOverflowMenu>, keeping your primary toolbar focused on key actions.
- Anchor a toolbar item to the trailing edge of the top bar using the <doc://com.apple.documentation/documentation/SwiftUI/ToolbarItemPlacement/topBarPinnedTrailing> placement so it stays in place even as other items shift or move to the overflow menu.
- Control how toolbars minimize in response to scrolling using the <doc://com.apple.documentation/documentation/SwiftUI/View/toolbarMinimizationBehavior(_:for:)> modifier.

### Documents

- Build document-based apps that read directly from a file URL by conforming your document class to <doc://com.apple.documentation/documentation/SwiftUI/ReadableDocument>, enabling access to large files and integration with URL-based frameworks.
- Add write support to a URL-based document by also conforming to <doc://com.apple.documentation/documentation/SwiftUI/WritableDocument>.
- Implement custom reading and writing logic with <doc://com.apple.documentation/documentation/SwiftUI/DocumentReader> and <doc://com.apple.documentation/documentation/SwiftUI/DocumentWriter>, or use <doc://com.apple.documentation/documentation/SwiftUI/FileWrapperDocumentReader> and <doc://com.apple.documentation/documentation/SwiftUI/FileWrapperDocumentWriter> for simpler file-wrapper-based cases.
- Access the document’s file URL and last modification date, and coordinate additional file access, using <doc://com.apple.documentation/documentation/SwiftUI/URLDocumentConfiguration>.
- Export a <doc://com.apple.documentation/documentation/SwiftUI/WritableDocument> to disk using the <doc://com.apple.documentation/documentation/SwiftUI/View/fileExporter(isPresented:document:contentType:defaultFilename:onCompletion:onCancellation:)> modifier.

### Tab bars

- Set the <doc://com.apple.documentation/documentation/SwiftUI/TabRole/prominent> role on a tab to place the tab in a separate, trailing position of the tab bar.

### Alerts and confirmation dialogs

- Present an alert or confirmation dialog from an optional data item or error object, and use that data to produce the content and title:
  - <doc://com.apple.documentation/documentation/SwiftUI/View/alert(_:item:actions:)>
  - <doc://com.apple.documentation/documentation/SwiftUI/View/alert(error:actions:)>
  - <doc://com.apple.documentation/documentation/SwiftUI/View/alert(_:item:actions:message:)>
  - <doc://com.apple.documentation/documentation/SwiftUI/View/alert(error:actions:message:)>
  - <doc://com.apple.documentation/documentation/SwiftUI/View/confirmationDialog(_:item:titleVisibility:actions:)>
  - <doc://com.apple.documentation/documentation/SwiftUI/View/confirmationDialog(_:item:titleVisibility:actions:message:)>

### Gestures

- Specify the sources of gesture input to recognize, such as direct or indirect touches, pencil, or pointer. The following gestures have initializers that you can use to specify the sources of gesture input: <doc://com.apple.documentation/documentation/SwiftUI/DragGesture>, <doc://com.apple.documentation/documentation/SwiftUI/LongPressGesture>, <doc://com.apple.documentation/documentation/SwiftUI/MagnifyGesture>, <doc://com.apple.documentation/documentation/SwiftUI/RotateGesture>, <doc://com.apple.documentation/documentation/SwiftUI/RotateGesture3D>, <doc://com.apple.documentation/documentation/SwiftUI/SpatialEventGesture>, <doc://com.apple.documentation/documentation/SwiftUI/SpatialTapGesture>, <doc://com.apple.documentation/documentation/SwiftUI/TapGesture>, <doc://com.apple.documentation/documentation/SwiftUI/WindowDragGesture>. For more information see <doc://com.apple.documentation/documentation/SwiftUI/GestureInputKinds>.

## June 2025

### General

- Apply Liquid Glass effects to views using <doc://com.apple.documentation/documentation/SwiftUI/View/glassEffect(_:in:)>.
- Use <doc://com.apple.documentation/documentation/SwiftUI/PrimitiveButtonStyle/glass> with the <doc://com.apple.documentation/documentation/SwiftUI/View/buttonStyle(_:)-66fbx> modifier to apply Liquid Glass to instances of `Button`.
- <doc://com.apple.documentation/documentation/SwiftUI/ToolbarSpacer> creates a visual break between items in toolbars containing Liquid Glass.
- Use <doc://com.apple.documentation/documentation/SwiftUI/View/scrollEdgeEffectStyle(_:for:)> to configure the scroll edge effect style for scroll views.
- <doc://com.apple.documentation/documentation/SwiftUI/View/backgroundExtensionEffect()> duplicates, mirrors, and blurs views placed around edges with available safe areas.
- Set behavior for tab bar minimization with <doc://com.apple.documentation/documentation/SwiftUI/View/tabBarMinimizeBehavior(_:)>.
- Set the <doc://com.apple.documentation/documentation/SwiftUI/TabRole/search> role on a tab to take someone to a search tab and have a search field take the place of the tab bar.
- Adjust the content of accessory views based on the placement in a tab view with <doc://com.apple.documentation/documentation/SwiftUI/TabViewBottomAccessoryPlacement>.
- Connect a <doc://com.apple.documentation/documentation/WebKit/WebView-swift.struct> with a <doc://com.apple.documentation/documentation/WebKit/WebPage> to fully control the browsing experience in your app.
- Drag multiple items using the <doc://com.apple.documentation/documentation/SwiftUI/View/draggable(containerItemID:containerNamespace:)> modifier. Make a view a container for draggable views using the <doc://com.apple.documentation/documentation/SwiftUI/View/dragContainer(for:itemID:in:_:)> modifier.
- Use the <doc://com.apple.documentation/documentation/SwiftUI/Animatable()> macro to have SwiftUI synthesize custom animatable data properties.
- <doc://com.apple.documentation/documentation/SwiftUI/Slider> now supports tick marks. Tick marks appear automatically when initializing a `Slider` with the `step` parameter.
- Use <doc://com.apple.documentation/documentation/SwiftUI/View/windowResizeAnchor(_:)> to set the window anchor point when a window must resize.

### Text

- <doc://com.apple.documentation/documentation/SwiftUI/TextEditor> now supports <doc://com.apple.documentation/documentation/Foundation/AttributedString>.
- Handle text selection with attributed text using <doc://com.apple.documentation/documentation/SwiftUI/AttributedTextSelection>.
- <doc://com.apple.documentation/documentation/SwiftUI/AttributedTextFormattingDefinition> defines how text can be styled in specific contexts.
- Use <doc://com.apple.documentation/documentation/SwiftUI/FindContext> to create a find navigator in views that support text editing.

### Accessibility

- Support Assistive Access in iOS and iPadOS scenes with <doc://com.apple.documentation/documentation/SwiftUI/AssistiveAccess>.

### HDR

- <doc://com.apple.documentation/documentation/SwiftUI/Color/ResolvedHDR> is a set of RGBA values that represent a color that can be shown, including HDR headroom information.

### UIKit and AppKit integration

- Host and present SwiftUI scenes in UIKit with <doc://com.apple.documentation/documentation/SwiftUI/UIHostingSceneDelegate> and in AppKit with <doc://com.apple.documentation/documentation/SwiftUI/NSHostingSceneRepresentation>.
- Incorporate gesture recognizers in SwiftUI views from AppKit with <doc://com.apple.documentation/documentation/SwiftUI/NSGestureRecognizerRepresentable>.

### Immersive spaces

- Manipulate views using common hand gestures with <doc://com.apple.documentation/documentation/SwiftUI/View/manipulable(coordinateSpace:operations:inertia:isEnabled:onChanged:)>.
- Snap volumes to horizontal surfaces and windows to vertical surfaces using <doc://com.apple.documentation/documentation/SwiftUI/SurfaceSnappingInfo>.
- Use <doc://com.apple.documentation/documentation/SwiftUI/RemoteImmersiveSpace> to render stereo content from your Mac app on Apple Vision Pro.
- Use <doc://com.apple.documentation/documentation/SwiftUI/SpatialContainer> to create a layout container that aligns overlapping content in 3D space.
- Depth-based variants of modifiers allow easier volumetric layouts in SwiftUI. For example, <doc://com.apple.documentation/documentation/SwiftUI/View/aspectRatio3D(_:contentMode:)>, <doc://com.apple.documentation/documentation/SwiftUI/View/rotation3DLayout(_:)>, and <doc://com.apple.documentation/documentation/SwiftUI/Layout/depthAlignment(_:)>.

## June 2024

### Volumes

- Specify the alignment of a volume when moved in the world using the <doc://com.apple.documentation/documentation/SwiftUI/Scene/volumeWorldAlignment(_:)> scene modifier.
- Specify the default world scaling behavior of your scene using the <doc://com.apple.documentation/documentation/SwiftUI/Scene/defaultWorldScaling(_:)> scene modifier.
- Adjust the visibilty of a volume’s baseplate using the <doc://com.apple.documentation/documentation/SwiftUI/View/volumeBaseplateVisibility(_:)> view modifier.
- Define a custom action to execute when the viewpoint of a volume changes using the <doc://com.apple.documentation/documentation/SwiftUI/View/onVolumeViewpointChange(updateStrategy:initial:_:)> view modifier.

### Windows

- Change the default initial size and position of a window using the <doc://com.apple.documentation/documentation/SwiftUI/Scene/defaultWindowPlacement(_:)> modifier.
- Change the default behavior for how windows behave when performing a zoom using <doc://com.apple.documentation/documentation/SwiftUI/WindowIdealSize> and provide the placement for the zoomed window with the <doc://com.apple.documentation/documentation/SwiftUI/Scene/windowIdealPlacement(_:)> modifier.
- Create utility windows in SwiftUI using the new <doc://com.apple.documentation/documentation/SwiftUI/UtilityWindow> scene type and toggle the window’s visibility using the <doc://com.apple.documentation/documentation/SwiftUI/WindowVisibilityToggle>.
- Customize the style of a window using the new <doc://com.apple.documentation/documentation/SwiftUI/ContainerBackgroundPlacement/window> container background placement, the <doc://com.apple.documentation/documentation/SwiftUI/View/toolbar(removing:)> view modifier, and the <doc://com.apple.documentation/documentation/SwiftUI/WindowStyle/plain> window style.
- Set the default launch behavior for a scene using the <doc://com.apple.documentation/documentation/SwiftUI/Scene/defaultLaunchBehavior(_:)> modifier.
- Replace one scene with another using the <doc://com.apple.documentation/documentation/SwiftUI/EnvironmentValues/pushWindow> method.

### Immersive spaces

- Add an action to perform when the state of the immersion changes using the <doc://com.apple.documentation/documentation/SwiftUI/View/onImmersionChange(initial:_:)> modifier.
- Apply a custom color or dim a passthrough video in an immersive space using the <doc://com.apple.documentation/documentation/SwiftUI/SurroundingsEffect/colorMultiply(_:)> and <doc://com.apple.documentation/documentation/SwiftUI/SurroundingsEffect/dim(intensity:)> initializers.

### Documents

- Customize the launch experience of document-based applications using <doc://com.apple.documentation/documentation/SwiftUI/DocumentGroupLaunchScene> and <doc://com.apple.documentation/documentation/SwiftUI/NewDocumentButton>.

### Navigation

- Specify the appearance and interaction of <doc://com.apple.documentation/documentation/SwiftUI/TabView> with the <doc://com.apple.documentation/documentation/SwiftUI/View/tabViewStyle(_:)>  modifier using values like <doc://com.apple.documentation/documentation/SwiftUI/TabViewStyle/sidebarAdaptable>, <doc://com.apple.documentation/documentation/SwiftUI/TabViewStyle/tabBarOnly>, and <doc://com.apple.documentation/documentation/SwiftUI/TabViewStyle/grouped>.
- Build hierarchy by nesting tabs as a tab item within <doc://com.apple.documentation/documentation/SwiftUI/TabSection>.
- Enable people to customize a <doc://com.apple.documentation/documentation/SwiftUI/TabView> using the <doc://com.apple.documentation/documentation/SwiftUI/View/tabViewCustomization(_:)> modifier and persist customization state in <doc://com.apple.documentation/documentation/SwiftUI/AppStorage> with <doc://com.apple.documentation/documentation/SwiftUI/TabViewCustomization>.

### Modal presentations

- Use built-in presentation sizes for sheets like <doc://com.apple.documentation/documentation/SwiftUI/PresentationSizing/form> or <doc://com.apple.documentation/documentation/SwiftUI/PresentationSizing/page> with the <doc://com.apple.documentation/documentation/SwiftUI/View/presentationSizing(_:)> modifier or create custom sized sheets using the <doc://com.apple.documentation/documentation/SwiftUI/PresentationSizing> protocol.

### Toolbars

- Specify the display mode of toolbars in macOS using the <doc://com.apple.documentation/documentation/SwiftUI/ToolbarLabelStyle> type.
- Configure the foreground style in the toolbar environment in watchOS using the <doc://com.apple.documentation/documentation/SwiftUI/View/toolbarForegroundStyle(_:for:)> view modifier.
- Anchor ornaments relative to the depth of your volume — in addition to the height and width — using the <doc://com.apple.documentation/documentation/SwiftUI/OrnamentAttachmentAnchor/scene(_:)-1l8wf> method that takes a <doc://com.apple.documentation/documentation/SwiftUI/UnitPoint3D>.

### Views

- Create custom container views like <doc://com.apple.documentation/documentation/SwiftUI/Picker>, <doc://com.apple.documentation/documentation/SwiftUI/List>, and <doc://com.apple.documentation/documentation/SwiftUI/TabView> using new <doc://com.apple.documentation/documentation/SwiftUI/Group> and <doc://com.apple.documentation/documentation/SwiftUI/ForEach> initializers, like <doc://com.apple.documentation/documentation/SwiftUI/Group/init(subviews:transform:)> and <doc://com.apple.documentation/documentation/SwiftUI/ForEach/init(subviews:content:)>, respectively.
- Declare a custom container value by defining a key that conforms to the <doc://com.apple.documentation/documentation/SwiftUI/ContainerValueKey> protocol, and set the container value for a view using the <doc://com.apple.documentation/documentation/SwiftUI/View/containerValue(_:_:)> modifier.
- Create <doc://com.apple.documentation/documentation/SwiftUI/EnvironmentValues>, <doc://com.apple.documentation/documentation/SwiftUI/Transaction>, <doc://com.apple.documentation/documentation/SwiftUI/ContainerValues>, and <doc://com.apple.documentation/documentation/SwiftUI/FocusedValues> entries by using the <doc://com.apple.documentation/documentation/SwiftUI/Entry()> macro to the variable declaration.

### Animation

- Customize the transition when pushing a view onto a navigation stack or presenting a view with the <doc://com.apple.documentation/documentation/SwiftUI/View/navigationTransition(_:)> view modifier.
- Add new symbols effects and configurations like <doc://com.apple.documentation/documentation/Symbols/SymbolEffect/wiggle>, <doc://com.apple.documentation/documentation/Symbols/SymbolEffect/rotate>, and <doc://com.apple.documentation/documentation/Symbols/SymbolEffect/breathe> using the <doc://com.apple.documentation/documentation/SwiftUI/View/symbolEffect(_:options:value:)> modifier.

### Text input and output

- Add text suggestions support to any text field using <doc://com.apple.documentation/documentation/SwiftUI/View/textInputSuggestions(_:)> and <doc://com.apple.documentation/documentation/SwiftUI/View/textInputCompletion(_:)> view modifiers.
- Access and modify selected text using a new <doc://com.apple.documentation/documentation/SwiftUI/TextSelection> binding for <doc://com.apple.documentation/documentation/SwiftUI/TextField> and <doc://com.apple.documentation/documentation/SwiftUI/TextEditor>.
- Bind to the focus state of an app’s search field using the <doc://com.apple.documentation/documentation/SwiftUI/View/searchFocused(_:equals:)> view modifier.

### Drawing and graphics

- Precompile shaders at build time using the <doc://com.apple.documentation/documentation/SwiftUI/Shader/compile(as:)> method.
- Create mesh gradients with a grid of points and colors using the new <doc://com.apple.documentation/documentation/SwiftUI/MeshGradient> type.
- Extend SwiftUI Text views with custom rendering effects and interaction behaviors using <doc://com.apple.documentation/documentation/SwiftUI/TextAttribute>, <doc://com.apple.documentation/documentation/SwiftUI/Text/Layout>, and <doc://com.apple.documentation/documentation/SwiftUI/TextRenderer>.
- Create a new <doc://com.apple.documentation/documentation/SwiftUI/Color> by mixing two colors using the <doc://com.apple.documentation/documentation/SwiftUI/Color/mix(with:by:in:)> method.

### Layout

- Enable custom spacing between views in a <doc://com.apple.documentation/documentation/SwiftUI/ZStack> along the depth axis with the <doc://com.apple.documentation/documentation/SwiftUI/ZStack/init(alignment:spacing:content:)> initializer.

### Scrolling

- Scroll to a view, offset, or edge in a scroll view using the <doc://com.apple.documentation/documentation/SwiftUI/View/scrollPosition(_:anchor:)> view modifier and specifying one of the <doc://com.apple.documentation/documentation/SwiftUI/ScrollPosition> values.
- Limit the number of views that can be scrolled by a single interaction using the limit behavior value <doc://com.apple.documentation/documentation/SwiftUI/ViewAlignedScrollTargetBehavior/LimitBehavior/alwaysByFew> or <doc://com.apple.documentation/documentation/SwiftUI/ViewAlignedScrollTargetBehavior/LimitBehavior/alwaysByOne>.
- Add an action to be called when a view crosses a provided threshold using the <doc://com.apple.documentation/documentation/SwiftUI/View/onScrollVisibilityChange(threshold:_:)> modifier.
- Access both the old and new values when a scroll view’s phase changes by using the <doc://com.apple.documentation/documentation/SwiftUI/View/onScrollPhaseChange(_:)-7mica> modifier.

### Gestures

- Conditionally disable a gesture using the `isEnabled` parameter in a modifier like <doc://com.apple.documentation/documentation/SwiftUI/View/gesture(_:isEnabled:)>.
- Create extra drag areas of a window in macOS when you add a <doc://com.apple.documentation/documentation/SwiftUI/WindowDragGesture> gesture.
- Create a hand gesture shortcut for Double Tap in watchOS using the <doc://com.apple.documentation/documentation/SwiftUI/HandGestureShortcut> structure.
- Enable whether gestures can handle events that activate the containing window using the <doc://com.apple.documentation/documentation/SwiftUI/View/allowsWindowActivationEvents(_:)> view modifier.

### Input events

- Create a group of hover effects that activate together using <doc://com.apple.documentation/documentation/SwiftUI/HoverEffectGroup> and apply them to a view using the <doc://com.apple.documentation/documentation/SwiftUI/View/hoverEffect(in:isEnabled:body:)> view modifier.
- Customize the appearance of the system pointer in macOS, iPadOS, and visionOS with new pointer styles using <doc://com.apple.documentation/documentation/SwiftUI/View/pointerStyle(_:)> or the visibility with the <doc://com.apple.documentation/documentation/SwiftUI/View/pointerVisibility(_:)> modifier.
- Access keyboard modifier flags using the <doc://com.apple.documentation/documentation/SwiftUI/View/onModifierKeysChanged(mask:initial:_:)>.
- Replace the primary view with one or more alternative views when pressing a specified set of modifier keys using the <doc://com.apple.documentation/documentation/SwiftUI/View/modifierKeyAlternate(_:_:)> view modifier.
- Enable the hand pointer for custom drawing and markup applications using the <doc://com.apple.documentation/documentation/SwiftUI/View/handPointerBehavior(_:)> modifier.

### Previews in Xcode

- Write dynamic properties inline in previews using the new <doc://com.apple.documentation/documentation/SwiftUI/Previewable()> macro.
- Inject shared environment objects, model containers, or other dependencies into previews using the <doc://com.apple.documentation/documentation/SwiftUI/PreviewModifier> protocol.

### Accessibility

- Specify that your accessibility element behaves as a tab bar using the <doc://com.apple.documentation/documentation/SwiftUI/AccessibilityTraits/isTabBar> accessibility trait with the <doc://com.apple.documentation/documentation/SwiftUI/View/accessibilityAddTraits(_:)> modifier. In UIKit, use <doc://com.apple.documentation/documentation/UIKit/UIAccessibilityTraits/tabBar>.
- Generate a localized description of a color in a string interpolation by adding `accessibilityName:`, such as `"\(accessibilityName: myColor)"`. Pass that string to any accessibility modifier.

### Framework interoperability

- Reuse existing UIKit gesture recognizer code in SwiftUI. In SwiftUI, create UIKit gesture recognizers using <doc://com.apple.documentation/documentation/SwiftUI/UIGestureRecognizerRepresentable>. In UIKit, refer to SwiftUI gestures by name using <doc://com.apple.documentation/documentation/UIKit/UIGestureRecognizer/name>.
- Share menu content definitions between SwiftUI and AppKit by using the <doc://com.apple.documentation/documentation/SwiftUI/NSHostingMenu> in your AppKit view hierarchy.

---

## June 2023, visionOS

### Scenes

- Create a volume that can display 3D models by applying the <doc://com.apple.documentation/documentation/SwiftUI/WindowStyle/volumetric> window style to an app’s window.
- Make use of a Full Space by opening an <doc://com.apple.documentation/documentation/SwiftUI/ImmersiveSpace> scene. You can use the <doc://com.apple.documentation/documentation/SwiftUI/ImmersionStyle/mixed> immersion style to place objects in a person’s surroundings, or the <doc://com.apple.documentation/documentation/SwiftUI/ImmersionStyle/full> style to completely control the visual experience.
- Display 3D models in a volume or a Full Space using RealityKit entities that you load with that framework’s <doc://com.apple.documentation/documentation/RealityKit/Model3D> or <doc://com.apple.documentation/documentation/RealityKit/RealityView> structure.

### Toolbars and ornaments

- Display a toolbar item in an ornament using the <doc://com.apple.documentation/documentation/SwiftUI/ToolbarItemPlacement/bottomOrnament> toolbar item placement.
- Add an ornament to a window directly using the <doc://com.apple.documentation/documentation/SwiftUI/View/ornament(visibility:attachmentAnchor:contentAlignment:ornament:)> view modifier.

### Drawing and graphics

- Detect view geometry in three dimensions using a <doc://com.apple.documentation/documentation/SwiftUI/GeometryReader3D>.
- Add a 3D visual effect using the <doc://com.apple.documentation/documentation/SwiftUI/View/visualEffect3D(_:)> view modifier.
- Rotate or scale in three dimensions with view modifiers like <doc://com.apple.documentation/documentation/SwiftUI/View/rotation3DEffect(_:anchor:)> and <doc://com.apple.documentation/documentation/SwiftUI/View/scaleEffect(x:y:z:anchor:)>, respectively.
- Convert between display points and physical distances using a <doc://com.apple.documentation/documentation/SwiftUI/PhysicalMetricsConverter>.

### View configuration

- Add a glass background effect to a view using the <doc://com.apple.documentation/documentation/SwiftUI/View/glassBackgroundEffect(displayMode:)> view modifier.
- Dim passthrough when appropriate by applying a <doc://com.apple.documentation/documentation/SwiftUI/View/preferredSurroundingsEffect(_:)> modifier.

### View layout

- Make 3D adjustments to layout with view modifiers like <doc://com.apple.documentation/documentation/SwiftUI/View/offset(z:)>, <doc://com.apple.documentation/documentation/SwiftUI/View/padding3D(_:)-6bex4>, and <doc://com.apple.documentation/documentation/SwiftUI/View/frame(depth:alignment:)>.

### Gestures

- Enable people to rotate objects in three dimensions when you add a <doc://com.apple.documentation/documentation/SwiftUI/RotateGesture3D> gesture.

---

## June 2023

### Scenes

- Close windows by their identifier using the <doc://com.apple.documentation/documentation/SwiftUI/EnvironmentValues/dismissWindow> action stored in the environment.
- Enable people to open a settings window by presenting a <doc://com.apple.documentation/documentation/SwiftUI/SettingsLink> button.

### Navigation

- Control views of a navigation split view or stack using a new overload of the <doc://com.apple.documentation/documentation/SwiftUI/View/navigationDestination(item:destination:)> view modifier.
- Manage column visibility of a navigation split view using new overloads of the view’s initializer, like <doc://com.apple.documentation/documentation/SwiftUI/NavigationSplitView/init(columnVisibility:preferredCompactColumn:sidebar:content:detail:)>.

### Modal presentations

- Use new overloads of the file export, import, and move modifiers, like <doc://com.apple.documentation/documentation/SwiftUI/View/fileExporter(isPresented:document:contentTypes:defaultFilename:onCompletion:onCancellation:)-34bd6>, to access new file management features. For example, you can:
  - Configure a file import or export dialog to open on a default directory, enable only certain file types, display hidden files, and so on.
  - Retain file interface configuration that a person chooses from one presentation to the next.
  - Export types that conform to the <doc://com.apple.documentation/documentation/CoreTransferable/Transferable> protocol.
- Specify a dialog severity using the <doc://com.apple.documentation/documentation/SwiftUI/View/dialogSeverity(_:)> view modifier.
- Provide a custom icon for a dialog using the <doc://com.apple.documentation/documentation/SwiftUI/View/dialogIcon(_:)> modifier.
- Enable people to suppress dialogs using one of the dialog suppression modifiers, like <doc://com.apple.documentation/documentation/SwiftUI/View/dialogSuppressionToggle(isSuppressed:)>.

### Toolbars

- Configure the toolbar title display size using the <doc://com.apple.documentation/documentation/SwiftUI/View/toolbarTitleDisplayMode(_:)> modifier.

### Search

- Present search programmatically using a binding to a new `isPresented` parameter available in some searchable view modifiers, like <doc://com.apple.documentation/documentation/SwiftUI/View/searchable(text:isPresented:placement:prompt:)-1hn4y>.
- Create mutable search tokens by providing a binding to the input of the `token` closure in the applicable searchable view modifiers, like <doc://com.apple.documentation/documentation/SwiftUI/View/searchable(text:editableTokens:isPresented:placement:prompt:token:)-2ilmg>.

### Data and storage

- Bridge between SwiftUI environment keys and UIKit traits more easily using the <doc://com.apple.documentation/documentation/SwiftUI/UITraitBridgedEnvironmentKey> protocol.
- Get better performance when you share data throughout your app by using the new <doc://com.apple.documentation/documentation/Observation/Observable()> macro.
- Access both the old and new values of a value that changes when processing the completion closure of the <doc://com.apple.documentation/documentation/SwiftUI/View/onChange(of:initial:_:)-4psgg> view modifier.

### Views

- Display a standard interface when a resource, like search results or a network connection, isn’t available using the <doc://com.apple.documentation/documentation/SwiftUI/ContentUnavailableView> view type.
- Display a standard inspector interface with a platform-appropriate appearance by applying the <doc://com.apple.documentation/documentation/SwiftUI/View/inspector(isPresented:content:)> modifier.

### Animation

- Perform an action when an animation completes by specifying a completion closure to the <doc://com.apple.documentation/documentation/SwiftUI/withAnimation(_:completionCriteria:_:completion:)> view modifier.
- Define custom animation behaviors by creating a type that conforms to the <doc://com.apple.documentation/documentation/SwiftUI/CustomAnimation> protocol.
- Perform animations that progress through predefined phases using the <doc://com.apple.documentation/documentation/SwiftUI/PhaseAnimator> structure, or according to a set of time-based keyframes by using the <doc://com.apple.documentation/documentation/SwiftUI/Keyframes> protocol.
- Specify information about a change in state — for example, to request a particular animation — using custom <doc://com.apple.documentation/documentation/SwiftUI/TransactionKey> instances.
- Design custom animation curves using <doc://com.apple.documentation/documentation/SwiftUI/UnitCurve>.
- Apply streamlined spring parameters, now standardized across all Apple frameworks, using the new <doc://com.apple.documentation/documentation/SwiftUI/Animation/spring(duration:bounce:blendDuration:)> animation. You can also use the <doc://com.apple.documentation/documentation/SwiftUI/Spring> structure as a convenience to represent a spring’s motion.

### Text input and output

- Indicate the language that appears in a specific <doc://com.apple.documentation/documentation/SwiftUI/Text> view so that SwiftUI can help to avoid clipping and collision of text, and perform proper line breaking and hyphenation using the <doc://com.apple.documentation/documentation/SwiftUI/View/typesettingLanguage(_:isEnabled:)-4ldzm> view modifier.
- Scale text semantically, for example by labeling it as having a secondary text scale, using the <doc://com.apple.documentation/documentation/SwiftUI/View/textScale(_:isEnabled:)> modifier.

### Shapes

- Apply more than one <doc://com.apple.documentation/documentation/SwiftUI/Shape/fill(_:style:)-3y2ud> or <doc://com.apple.documentation/documentation/SwiftUI/Shape/stroke(_:style:antialiased:)> modifier to a single <doc://com.apple.documentation/documentation/SwiftUI/Shape>.
- Apply Boolean operations to both shapes and paths, like <doc://com.apple.documentation/documentation/SwiftUI/Shape/intersection(_:eoFill:)> and <doc://com.apple.documentation/documentation/SwiftUI/Shape/union(_:eoFill:)>.
- Use predefined shape styles, like <doc://com.apple.documentation/documentation/SwiftUI/Shape/rect>, to simplify your code.
- Create rounded rectangles with uneven corners using <doc://com.apple.documentation/documentation/SwiftUI/Shape/rect(topLeadingRadius:bottomLeadingRadius:bottomTrailingRadius:topTrailingRadius:style:)>.

### Drawing and graphics

- Create fully customizable, high-performance graphics by drawing with Metal shaders inside a SwiftUI app using a <doc://com.apple.documentation/documentation/SwiftUI/Shader> structure.
- Configure an image with a specific dynamic range by applying the <doc://com.apple.documentation/documentation/SwiftUI/View/allowedDynamicRange(_:)> view modifier.
- Compose effects that you apply to a view based on some aspect of the geometry of the view using the <doc://com.apple.documentation/documentation/SwiftUI/View/visualEffect(_:)> modifier. For example, you can apply a blur that varies depending on the view’s position in the display.

### Layout

- Define custom coordinate spaces using the <doc://com.apple.documentation/documentation/SwiftUI/CoordinateSpaceProtocol> with new <doc://com.apple.documentation/documentation/SwiftUI/GeometryProxy> methods, like <doc://com.apple.documentation/documentation/SwiftUI/GeometryProxy/bounds(of:)> and <doc://com.apple.documentation/documentation/SwiftUI/GeometryProxy/frame(in:)-68tks>, to get the dimensions of containers.
- Create a frame for a view that lays out its content based on characteristics of the container view using <doc://com.apple.documentation/documentation/SwiftUI/View/containerRelativeFrame(_:alignment:)>.
- Set the background of a container view using the <doc://com.apple.documentation/documentation/SwiftUI/View/containerBackground(_:for:)> view modifier.

### Lists and tables

- Disable selectability of an item in a <doc://com.apple.documentation/documentation/SwiftUI/List> or <doc://com.apple.documentation/documentation/SwiftUI/Table> by applying the <doc://com.apple.documentation/documentation/SwiftUI/View/selectionDisabled(_:)> modifier.
- Collapse or expand a <doc://com.apple.documentation/documentation/SwiftUI/Section> of a list or table using the `isExpanded` binding in the section’s initializer.
- Configure row or section spacing using the <doc://com.apple.documentation/documentation/SwiftUI/View/listRowSpacing(_:)> and <doc://com.apple.documentation/documentation/SwiftUI/View/listSectionSpacing(_:)-5t518> modifiers, respectively.
- Set the prominence of a badge using the <doc://com.apple.documentation/documentation/SwiftUI/View/badgeProminence(_:)> view modifier.
- Configure alternating row backgrounds using the <doc://com.apple.documentation/documentation/SwiftUI/View/alternatingRowBackgrounds(_:)> modifier.
- Customize table column visibility and reordering using the <doc://com.apple.documentation/documentation/SwiftUI/TableColumnCustomization> structure.
- Add hierarchical rows to a table using the <doc://com.apple.documentation/documentation/SwiftUI/DisclosureTableRow> structure, or recursively hierarchical rows using the <doc://com.apple.documentation/documentation/SwiftUI/OutlineGroup> structure.
- Hide table column headers using the <doc://com.apple.documentation/documentation/SwiftUI/View/tableColumnHeaders(_:)> modifier.

### Scrolling

- Read the position of a scroll view using one of the scroll position modifiers, like <doc://com.apple.documentation/documentation/SwiftUI/View/scrollPosition(id:anchor:)>.
- Flash scroll indicators programmatically using a view modifier, like <doc://com.apple.documentation/documentation/SwiftUI/View/scrollIndicatorsFlash(onAppear:)>.
- Clip scroll views in custom ways after disabling default clipping using the <doc://com.apple.documentation/documentation/SwiftUI/View/scrollClipDisabled(_:)> modifier.
- Create paged scroll views, aligned to either page or view boundaries, using the <doc://com.apple.documentation/documentation/SwiftUI/View/scrollTargetBehavior(_:)> view modifier.
- Create custom scroll behaviors using the <doc://com.apple.documentation/documentation/SwiftUI/ScrollTargetBehavior> protocol.
- Control the insets of scrollable views using the <doc://com.apple.documentation/documentation/SwiftUI/View/safeAreaPadding(_:)-5lh9p> and <doc://com.apple.documentation/documentation/SwiftUI/View/contentMargins(_:_:for:)-1lt8b> view modifiers.
- Add effects to views as they scroll on- and offscreen using one of the <doc://com.apple.documentation/documentation/SwiftUI/View/scrollTransition(_:axis:transition:)> modifiers.
- Create a <doc://com.apple.documentation/documentation/SwiftUI/TabView> that supports vertical paging in watchOS by applying the <doc://com.apple.documentation/documentation/SwiftUI/TabViewStyle/verticalPage> tab view style.

### Gestures

- Make smoother transitions between gestures and animations by using a new <doc://com.apple.documentation/documentation/SwiftUI/DragGesture/Value/velocity> property on the values associated with certain gestures and a <doc://com.apple.documentation/documentation/SwiftUI/Transaction/tracksVelocity> property on <doc://com.apple.documentation/documentation/SwiftUI/Transaction>.
- Gain access to more information, including both velocity and position, by migrating to the new <doc://com.apple.documentation/documentation/SwiftUI/MagnifyGesture> and <doc://com.apple.documentation/documentation/SwiftUI/RotateGesture>, which replace the now deprecated `MagnificationGesture` and `RotationGesture`.

### Input events

- Enable a view that’s in focus to react directly to keyboard input by applying one of the <doc://com.apple.documentation/documentation/SwiftUI/View/onKeyPress(_:action:)> view modifiers.
- Enable people to choose from a compact collection of items in a <doc://com.apple.documentation/documentation/SwiftUI/Menu> by styling a <doc://com.apple.documentation/documentation/SwiftUI/Picker> with the <doc://com.apple.documentation/documentation/SwiftUI/PickerStyle/palette> style.
- Provide haptic or audio feedback in response to an event using one of the sensory feedback modifiers, like <doc://com.apple.documentation/documentation/SwiftUI/View/sensoryFeedback(_:trigger:)>.
- Create buttons and toggles that perform an <doc://com.apple.documentation/documentation/AppIntents/AppIntent> in a widget, Live Activity, and other places using new initializers like <doc://com.apple.documentation/documentation/SwiftUI/Button/init(_:intent:)-7urde> and <doc://com.apple.documentation/documentation/SwiftUI/Toggle/init(_:isOn:intent:)-4lsrf>.

### Focus

- Distinguish between views for which focus serves different purposes, such as those that have a primary action like a button and those that take input like a text field, using the new <doc://com.apple.documentation/documentation/SwiftUI/View/focusable(_:interactions:)> view modifier.
- Manage the effect that receiving focus has on a view using the <doc://com.apple.documentation/documentation/SwiftUI/View/focusEffectDisabled(_:)> modifier.

### Previews in Xcode

- Reduce the amount of boilerplate that you need to create Xcode previews by using the new <doc://com.apple.documentation/documentation/SwiftUI/Preview(_:traits:_:body:)> macro.

---

Copyright &copy; 2026 Apple Inc. All rights reserved. | [Terms of Use](https://www.apple.com/legal/internet-services/terms/site.html) | [Privacy Policy](https://www.apple.com/privacy/privacy-policy)