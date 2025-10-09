# Body Motion Capture and Playback in 3D

This iOS app demonstrates body motion capture and playback using ARKit body tracking capabilities. It allows users to record skeleton joint movements and replay them as 3D animations.

## Features Implemented

### ✅ Part 1: Start/Stop Recording Button
- **Recording Button**: A prominently placed Start/Stop Recording button overlayed on the ARView
- **Auto Layout**: The button is centered horizontally and positioned near the bottom of the screen
- **State Management**: Button title and color change dynamically:
  - **Start State**: Blue button with "Start Recording" text
  - **Recording State**: Red button with "Stop Recording" text

### ✅ Part 2: Skeleton Joint Capture
- **Frame-by-Frame Recording**: Captures skeleton joint transforms during each AR frame update
- **Selective Joint Recording**: Records only relevant joints for upper body motion:
  - `.leftHand` and `.rightHand` 
  - `.leftShoulder` and `.rightShoulder`
  - `.root` (torso center)
- **Data Structure**: Uses a structured `RecordedFrame` format:
  ```swift
  struct RecordedFrame {
      let timestamp: TimeInterval
      let jointTransforms: [ARSkeleton.JointName: simd_float4x4]
  }
  ```
- **Efficient Storage**: Stores data in an array `recordedFrames: [RecordedFrame]`

### ✅ Part 3: Playback Transition
- **Automatic Transition**: When user stops recording, automatically transitions to playback screen
- **Data Passing**: Recorded skeleton data is passed to `PlaybackViewController` via dependency injection
- **Full Screen Presentation**: Playback screen presents in full screen mode for immersive experience

### ✅ Part 4: 3D Skeleton Visualization
- **White Background**: RealityKit ARView with clean white background (no camera feed)
- **3D Joint Representation**: Skeleton joints rendered as 3D spheres with different sizes
- **Bone Connections**: Lines connecting joints to visualize skeleton structure
- **60fps Playback**: Smooth animation using CADisplayLink for frame-perfect playback
- **Real-time Animation**: Applies recorded joint transforms to skeleton entities frame by frame

### ✅ Part 5: Enhanced Features
- **Hand Highlighting**: 
  - Left hand: Red sphere (larger size for visibility)
  - Right hand: Blue sphere (larger size for visibility)
  - Other joints: Gray spheres
- **Playback Controls**:
  - **Play/Pause Button**: Toggle animation playback
  - **Replay Button**: Restart animation from beginning
  - **Back Button**: Return to camera/recording screen
- **Progress Display**: Shows current frame number and total frames
- **Smooth Animation**: Automatic looping when animation reaches the end

## Technical Implementation

### Architecture
- **ViewController**: Main camera view with AR body tracking and recording functionality
- **PlaybackViewController**: Dedicated playback screen with 3D skeleton visualization
- **RecordedFrame Structure**: Efficient data structure for storing temporal skeleton data

### AR/RealityKit Integration
- **ARBodyTrackingConfiguration**: Uses ARKit's body tracking for real-time skeleton detection
- **RealityKit Entities**: Creates 3D sphere entities for joints and box entities for bones
- **Transform Application**: Direct application of recorded transform matrices to entities
- **Material System**: Uses SimpleMaterial with MaterialColorParameter for iOS 13+ compatibility

### Performance Optimizations
- **Selective Joint Recording**: Only captures essential joints to minimize data size
- **Efficient Rendering**: Reuses entity instances during playback
- **Frame Rate Control**: Uses CADisplayLink for smooth 60fps animation

## Usage Instructions

1. **Start Recording**:
   - Launch the app on a device with A12 chip or newer
   - Point camera at person to detect body skeleton
   - Tap "Start Recording" button to begin capture
   - Perform desired upper body movements

2. **Stop Recording**:
   - Tap "Stop Recording" button to end capture
   - App automatically transitions to playback screen

3. **Playback Controls**:
   - Tap "Play" to start animation playback
   - Tap "Pause" to pause animation
   - Tap "Replay" to restart from beginning
   - Tap "Back" to return to camera view

## System Requirements

- **iOS Version**: 13.0 or later
- **Device**: iPhone/iPad with A12 chip or newer (required for ARBodyTracking)
- **Frameworks**: ARKit, RealityKit, UIKit

## Technical Notes

- **Joint Name Compatibility**: Uses only joints available in iOS 13+ ARSkeleton.JointName enum
- **Background Execution**: Recording stops automatically when app goes to background
- **Memory Management**: Recorded frames are cleared when starting new recording session
- **Error Handling**: Graceful fallback for unsupported devices

## Future Enhancements

Potential improvements could include:
- Export recorded motion data to external formats
- Multiple recording sessions with save/load functionality
- Advanced filtering and smoothing of motion data
- Support for full body joint recording
- Motion comparison and analysis tools