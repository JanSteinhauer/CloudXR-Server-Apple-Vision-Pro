# Hand Tracking Activation Guide

This guide explains how to enable and configure hand tracking in your Apple Vision Pro CloudXR application.

## Overview

Hand tracking allows users to interact with virtual content using natural hand gestures without physical controllers. The CloudXR client supports hand tracking for both physical devices and the simulator.

## Prerequisites

- Apple Vision Pro or visionOS Simulator
- CloudXRKit framework integrated
- Xcode 15.0+
- visionOS 1.0+

## Configuration Steps

### 1. Add Required Permissions to Info.plist

Your app must request permission to use hand tracking. Add the following keys to `Info.plist`:

```xml
<key>NSHandsTrackingUsageDescription</key>
<string>This app uses hand tracking to enable interaction with virtual content.</string>
```

**Location:** `My First AVP CloudXR Client/My First AVP CloudXR Client/Info.plist`

This permission key is **required** and must include a description that explains why your app needs hand tracking access. The system will show this message to users when requesting permission.

### 2. Enable Hand Tracking Capability (Optional but Recommended)

While not strictly required for basic hand tracking, adding the hand tracking entitlement ensures your app is properly configured for production:

1. Open your Xcode project
2. Select your target: **My First AVP CloudXR Client**
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Search for and add **Hand Tracking**

This adds the `com.apple.developer.arkit.hand-tracking` entitlement to your app.

### 3. Configure CloudXR Session with Hand Tracking

In your `ContentView.swift`, hand tracking is already configured through the CloudXR session setup:

```swift
// User-facing toggle for enabling/disabling hand tracking
@AppStorage("enableHandTracking") private var enableHandTracking: Bool = true
```

The hand tracking mode is set when configuring the CloudXR session:

```swift
var config = CloudXRKit.Config()

// Enable hand tracking for interaction
#if targetEnvironment(simulator)
config.handTrackingMode = enableHandTracking ? .simulated : .disabled
#else
config.handTrackingMode = enableHandTracking ? .prediction : .disabled
#endif

cxrSession.configure(config: config)
```

**Reference:** `ContentView.swift:98-102`

### 4. Hand Tracking Modes

The CloudXRKit framework supports three hand tracking modes:

- **`.disabled`**: Hand tracking is turned off
- **`.simulated`**: Used in the visionOS Simulator for testing
- **`.prediction`**: Used on physical devices for real-time hand tracking with predictive algorithms

The code automatically selects the appropriate mode based on the environment:
- **Simulator**: Uses `.simulated` mode for testing
- **Physical Device**: Uses `.prediction` mode for production

### 5. User Interface Toggle

A toggle switch is provided in the UI to allow users to enable/disable hand tracking at runtime:

```swift
Toggle("Enable Hand Tracking", isOn: $enableHandTracking)
```

**Reference:** `ContentView.swift:50`

This setting is persisted using `@AppStorage`, so the user's preference is remembered between app launches.

## Testing Hand Tracking

### On visionOS Simulator

1. Run your app in the visionOS Simulator
2. Ensure the "Enable Hand Tracking" toggle is ON
3. Use the simulator's hand gesture controls to test interactions
4. The `.simulated` mode will be automatically used

### On Physical Apple Vision Pro

1. Deploy your app to a physical Apple Vision Pro device
2. Grant hand tracking permissions when prompted
3. Ensure the "Enable Hand Tracking" toggle is ON
4. Use natural hand gestures to interact with virtual content
5. The `.prediction` mode will be automatically used for optimal performance

## Troubleshooting

### Permission Denied

If hand tracking is not working:
1. Check that `NSHandsTrackingUsageDescription` is present in `Info.plist`
2. Verify the user granted hand tracking permission in Settings > Privacy & Security > Hand Structure & Movements
3. Check Xcode console for ARKit authorization errors

### Hand Tracking Not Detected

1. Ensure the "Enable Hand Tracking" toggle is ON in the app UI
2. Verify `config.handTrackingMode` is set to `.prediction` (device) or `.simulated` (simulator)
3. On physical devices, ensure good lighting conditions for hand detection
4. Keep hands within the device's field of view

### Simulator Issues

If hand tracking doesn't work in the simulator:
1. Verify `targetEnvironment(simulator)` conditional is correctly setting `.simulated` mode
2. Use the simulator's hand gesture tools in the toolbar
3. Check that the simulator supports hand tracking features

## Code References

- **Hand Tracking Configuration**: `ContentView.swift:98-102`
- **User Toggle**: `ContentView.swift:23, 50`
- **Permission Description**: `Info.plist:7-8`
- **Connection Setup**: `ContentView.swift:70-111`

## Additional Notes

- Hand tracking data is processed locally on the device for privacy
- The CloudXRKit framework handles the low-level hand tracking integration with ARKit
- Hand tracking works in conjunction with CloudXR streaming for remote rendering scenarios
- Performance may vary based on network conditions when using CloudXR streaming

## Related Features

This app also implements:
- **World Sensing**: For object detection and spatial anchors (`NSWorldSensingUsageDescription`)
- **Object Tracking**: ARKit-based reference object tracking (`ObjectTrackingManager.swift`)
- **Spatial Anchors**: Firebase integration for persisting AR anchor data

## References

- [Apple ARKit Documentation](https://developer.apple.com/documentation/arkit)
- [visionOS Hand Tracking](https://developer.apple.com/documentation/visionos/incorporating-hand-tracking)
- CloudXRKit Framework Documentation
