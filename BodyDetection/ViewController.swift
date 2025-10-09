/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The sample app's main view controller.
*/

import UIKit
import RealityKit
import ARKit
import Combine

// MARK: - Recording Structure
struct RecordedFrame {
    let timestamp: TimeInterval
    let jointTransforms: [ARSkeleton.JointName: simd_float4x4]
}

class ViewController: UIViewController, ARSessionDelegate {

    @IBOutlet var arView: ARView!
    
    // The 3D character to display.
    var character: BodyTrackedEntity?
    let characterOffset: SIMD3<Float> = [-1.0, 0, 0] // Offset the character by one meter to the left
    let characterAnchor = AnchorEntity()
    
    // MARK: - Recording Properties
    var recordedFrames: [RecordedFrame] = []
    var isRecording = false
    var recordingStartTime: TimeInterval = 0
    
    // MARK: - UI Elements
    private lazy var recordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Recording", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.session.delegate = self
        
        // Setup recording button
        setupRecordButton()
        
        // If the iOS device doesn't support body tracking, raise a developer error for
        // this unhandled case.
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }

        // Run a body tracking configration.
        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
        
        arView.scene.addAnchor(characterAnchor)
        
        // Asynchronously load the 3D character.
        var cancellable: AnyCancellable? = nil
        cancellable = Entity.loadBodyTrackedAsync(named: "character/robot").sink(
            receiveCompletion: { completion in
                if case let .failure(error) = completion {
                    print("Error: Unable to load model: \(error.localizedDescription)")
                }
                cancellable?.cancel()
            }, receiveValue: { (character: Entity) in
                if let character = character as? BodyTrackedEntity {
                    // Scale the character to human size
                    character.scale = [1.0, 1.0, 1.0]
                    self.character = character
                    cancellable?.cancel()
                } else {
                    print("Error: Unable to load model as BodyTrackedEntity")
                }
            }
        )
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors {
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            
            // Update the position of the character anchor's position.
            let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            characterAnchor.position = bodyPosition + characterOffset
            // Also copy over the rotation of the body anchor, because the skeleton's pose
            // in the world is relative to the body anchor's rotation.
            characterAnchor.orientation = Transform(matrix: bodyAnchor.transform).rotation
   
            if let character = character, character.parent == nil {
                // Attach the character to its anchor as soon as
                // 1. the body anchor was detected and
                // 2. the character was loaded.
                characterAnchor.addChild(character)
            }
            
            // MARK: - Part 2: Capture skeleton joints frame by frame
            if isRecording {
                captureSkeletonFrame(bodyAnchor: bodyAnchor)
            }
        }
    }
    
    // MARK: - Recording Setup and Actions
    private func setupRecordButton() {
        view.addSubview(recordButton)
        
        NSLayoutConstraint.activate([
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])
    }
    
    @objc private func recordButtonTapped() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        recordingStartTime = CACurrentMediaTime()
        recordedFrames.removeAll()
        
        recordButton.setTitle("Stop Recording", for: .normal)
        recordButton.backgroundColor = UIColor.systemRed
        
        print("🔴 Started recording skeleton data...")
        
        // SIMULATOR TESTING: Add fake data since body tracking doesn't work in simulator
        #if targetEnvironment(simulator)
        print("⚠️ Running in simulator - will generate test data for playback")
        generateTestFrames()
        #endif
    }
    
    private func stopRecording() {
        isRecording = false
        
        recordButton.setTitle("Start Recording", for: .normal)
        recordButton.backgroundColor = UIColor.systemBlue
        
        print("🔴 Stopped recording. Captured \(recordedFrames.count) frames")
        
        // Debug: Print some frame data
        if let firstFrame = recordedFrames.first {
            print("First frame joints: \(firstFrame.jointTransforms.keys)")
            for (joint, transform) in firstFrame.jointTransforms {
                let position = simd_make_float3(transform.columns.3)
                print("  \(joint): \(position)")
            }
        }
        
        // MARK: - Part 3: Transition to playback screen
        print("🔄 Attempting to show playback...")
        showRecordedSkeletonPlayback()
    }
    
        // MARK: - Part 2: Capture skeleton joints
    private func captureSkeletonFrame(bodyAnchor: ARBodyAnchor) {
        let currentTime = CACurrentMediaTime() - recordingStartTime
        
        // Record the basic body joints that are actually available in ARSkeleton.JointName
        let relevantJoints: [ARSkeleton.JointName] = [
            // Core body joints
            .root,
            
            // Arms
            .leftShoulder,
            .leftHand,
            .rightShoulder,
            .rightHand,
            
            // Legs
            .leftFoot,
            .rightFoot,
            
            // Head
            .head
        ]
        
        var jointTransforms: [ARSkeleton.JointName: simd_float4x4] = [:]
        
        for jointName in relevantJoints {
            let jointTransform = bodyAnchor.skeleton.modelTransform(for: jointName)
            jointTransforms[jointName] = jointTransform
        }
        
        let frame = RecordedFrame(timestamp: currentTime, jointTransforms: jointTransforms)
        recordedFrames.append(frame)
        
        // Debug: Print every 30 frames (about twice per second at 60fps)
        if recordedFrames.count % 30 == 0 {
            print("📹 Captured \(recordedFrames.count) frames...")
        }
    }
    
    // MARK: - Part 3: Show playback
    private func showRecordedSkeletonPlayback() {
        print("🎬 showRecordedSkeletonPlayback called with \(recordedFrames.count) frames")
        
        guard !recordedFrames.isEmpty else {
            print("❌ No recorded frames to show playback")
            
            // Show an alert to inform the user
            let alert = UIAlertController(title: "No Recording", 
                                        message: "No skeleton data was recorded. Make sure you are visible to the camera and your full body is detected.", 
                                        preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        
        // Show playback mode selection
        showPlaybackModeSelection()
    }
    
    private func showPlaybackModeSelection() {
        let alert = UIAlertController(title: "Choose Playback Mode", 
                                    message: "Select how you want to view the recorded motion:", 
                                    preferredStyle: .alert)
        
        // RealityKit option - skeleton visualization
        alert.addAction(UIAlertAction(title: "Skeleton View (RealityKit)", style: .default) { _ in
            print("✅ Creating RealityKit PlaybackViewController...")
            let playbackVC = PlaybackViewController(recordedFrames: self.recordedFrames)
            playbackVC.modalPresentationStyle = .fullScreen
            
            print("🚀 Presenting RealityKit PlaybackViewController...")
            self.present(playbackVC, animated: true) {
                print("✅ RealityKit PlaybackViewController presented successfully")
            }
        })
        
        // SceneKit option - robot character animation
        alert.addAction(UIAlertAction(title: "Robot Animation (SceneKit)", style: .default) { _ in
            print("✅ Creating SceneKit PlaybackViewController...")
            let sceneKitPlaybackVC = SceneKitPlaybackViewController()
            sceneKitPlaybackVC.modalPresentationStyle = .fullScreen
            
            print("🚀 Presenting SceneKit PlaybackViewController...")
            self.present(sceneKitPlaybackVC, animated: true) {
                print("✅ SceneKit PlaybackViewController presented successfully")
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Simulator Testing
    #if targetEnvironment(simulator)
    private func generateTestFrames() {
        // Generate test frames for simulator testing
        let frameCount = 120 // 2 seconds at 60fps
        
        for i in 0..<frameCount {
            let timestamp = Double(i) / 60.0 // 60fps
            var jointTransforms: [ARSkeleton.JointName: simd_float4x4] = [:]
            
            // Create animated test poses
            let time = Float(timestamp)
            let waveHeight = sin(time * 2.0) * 0.3
            
            // Root - center position
            jointTransforms[.root] = simd_float4x4(
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, 1, 0],
                [0, waveHeight, 0, 1]
            )
            
            // Left shoulder
            jointTransforms[.leftShoulder] = simd_float4x4(
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, 1, 0],
                [-0.3, waveHeight + 0.3, 0, 1]
            )
            
            // Right shoulder
            jointTransforms[.rightShoulder] = simd_float4x4(
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, 1, 0],
                [0.3, waveHeight + 0.3, 0, 1]
            )
            
            // Left hand - animated up and down
            let leftHandY = waveHeight + 0.1 + sin(time * 3.0) * 0.2
            jointTransforms[.leftHand] = simd_float4x4(
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, 1, 0],
                [-0.5, leftHandY, 0, 1]
            )
            
            // Right hand - animated up and down (opposite phase)
            let rightHandY = waveHeight + 0.1 + sin(time * 3.0 + Float.pi) * 0.2
            jointTransforms[.rightHand] = simd_float4x4(
                [1, 0, 0, 0],
                [0, 1, 0, 0],
                [0, 0, 1, 0],
                [0.5, rightHandY, 0, 1]
            )
            
            let frame = RecordedFrame(timestamp: timestamp, jointTransforms: jointTransforms)
            recordedFrames.append(frame)
        }
        
        print("📱 Generated \(recordedFrames.count) test frames for simulator")
    }
    #endif
}
