# Single Frame Body Motion Capture - Implementation Guide

This implementation modifies the original body motion capture app to capture a single frame instead of recording continuous motion, and displays all joint information in a detailed view.

## What Was Changed

### 1. Modified Main View Controller (`ViewController.swift`)

**Before:** 
- Had a "Start/Stop Recording" button that captured multiple frames continuously
- Used `recordedFrames` array to store multiple frame data
- Had complex playback selection logic

**After:**
- Changed to a "Capture Frame" button that captures one single frame
- Uses `capturedFrame` property to store single frame data
- Simplified capture logic for single frame operation

### 2. New Joint Details View Controller (`JointDetailsViewController.swift`)

**Features:**
- Displays captured joint data in a clean table view
- Shows joint name, position (X, Y, Z coordinates), and rotation (converted to Euler angles)
- Custom cell design with proper formatting
- Back button to return to main screen

### 3. Key Changes Made:

#### Capture Process:
```swift
// Old: Continuous recording
var recordedFrames: [RecordedFrame] = []
var isRecording = false

// New: Single frame capture
var capturedFrame: RecordedFrame?
```

#### Button Behavior:
```swift
// Old: Toggle recording on/off
@objc private func recordButtonTapped() {
    if isRecording {
        stopRecording()
    } else {
        startRecording()
    }
}

// New: Capture single frame
@objc private func captureButtonTapped() {
    captureSingleFrame()
}
```

#### Joint Data Processing:
- Captures position from transform matrix: `simd_make_float3(transform.columns.3)`
- Extracts rotation quaternion from transform matrix
- Converts quaternion to Euler angles for better human understanding
- Displays angles in degrees rather than radians

#### SceneKit 3D Visualization:
```swift
// New: SceneKit integration for 3D visualization
@objc private func sceneKitButtonTapped() {
    let recordedFrames = [capturedFrame]
    let sceneKitPlaybackVC = SceneKitPlaybackViewController()
    sceneKitPlaybackVC.setRecordedFrames(recordedFrames)
    present(sceneKitPlaybackVC, animated: true)
}
```

### 4. Supported Joints

The app captures data for these ARKit body joints:
- **Root** - Base/center point of the body
- **Head** - Head position and orientation
- **Left/Right Shoulder** - Shoulder positions
- **Left/Right Hand** - Hand positions
- **Left/Right Foot** - Foot positions

### 5. Simulator Support

Since ARKit body tracking doesn't work in the iOS Simulator, the app includes:
- Automatic test data generation when running in simulator
- Realistic joint positions for testing the UI
- Proper conditional compilation using `#if targetEnvironment(simulator)`

## How to Use

1. **Launch the app** - Point your device camera at a person (full body should be visible)
2. **Wait for body detection** - The app will show a 3D character when body is detected
3. **Tap "Capture Frame"** - This captures the current pose/position
4. **View joint details** - Automatically navigated to detailed view showing all joint data
5. **Review data** - See position coordinates and rotation angles for each joint
6. **View in SceneKit** - Tap "View in SceneKit" button to see 3D visualization
7. **3D Scene Navigation** - Use touch gestures to rotate, zoom, and pan the 3D scene
8. **Go back** - Use the back button to capture another frame

## New SceneKit Visualization Features

### 3D Joint Visualization
- **Colored Spheres** - Each joint type has a unique color:
  - 🔴 Root: Red 
  - 🟡 Head: Yellow
  - 🔵 Shoulders: Blue
  - 🟢 Hands: Green
  - 🟠 Feet: Orange
- **Joint Labels** - Text labels showing joint names above each sphere
- **Robot Model** - Displays the original robot.usdz model alongside joint markers
- **Interactive Camera** - Pan, zoom, and rotate to explore the 3D scene

### SceneKit Integration Flow
1. Capture frame on main screen
2. View detailed joint data in table view
3. Tap "View in SceneKit" for 3D visualization
4. Explore joint positions in 3D space
5. Return to joint details or capture new frame

## Technical Details

### Data Structure:
```swift
struct RecordedFrame {
    let timestamp: TimeInterval
    let jointTransforms: [ARSkeleton.JointName: simd_float4x4]
}
```

### Joint Information Display:
- **Position**: X, Y, Z coordinates in meters
- **Rotation**: Roll, Pitch, Yaw angles in degrees
- **Timestamp**: When the frame was captured

### Error Handling:
- Shows alert if no body is detected when trying to capture
- Fallback to test data in simulator
- Proper error messages for user guidance

## Benefits of This Implementation

1. **Simpler User Experience** - One button press instead of start/stop workflow
2. **Detailed Data Analysis** - All joint information clearly displayed
3. **3D Visualization** - Interactive SceneKit view with color-coded joint markers
4. **Better Performance** - No continuous recording overhead
5. **Educational Value** - Easy to understand joint positions and rotations in both 2D and 3D
6. **Testing Friendly** - Works in simulator with test data
7. **Professional Visualization** - High-quality 3D rendering with proper lighting and camera controls

## Next Steps

This implementation provides a solid foundation that could be extended with:
- Export functionality (save joint data to file)
- Pose comparison features
- Multiple frame capture with swipe navigation
- Real-time joint value updates
- Integration with fitness or motion analysis applications
- Animation playback in SceneKit
- Pose detection and classification
- Motion analysis and biomechanics calculations