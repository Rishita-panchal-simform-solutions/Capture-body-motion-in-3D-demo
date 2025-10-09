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
    
    // MARK: - Single Frame Capture Properties
    var capturedFrame: RecordedFrame?
    
    // MARK: - UI Elements
    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Capture Frame", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        arView.session.delegate = self
        
        // Setup capture button
        setupCaptureButton()
        
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
            
            // No need to capture frames continuously anymore
            // We'll capture only when button is pressed
        }
    }
    
    // MARK: - Single Frame Capture Setup and Actions
    private func setupCaptureButton() {
        view.addSubview(captureButton)
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40)
        ])
    }
    
    @objc private func captureButtonTapped() {
        captureSingleFrame()
    }
    
    private func captureSingleFrame() {
        // Check if running in simulator
        #if targetEnvironment(simulator)
        // Generate test data for simulator
        let testFrame = generateTestFrame()
        capturedFrame = testFrame
        print("📸 Generated test frame for simulator with \(testFrame.jointTransforms.count) joints")
        #else
        // Find the current body anchor
        guard let session = arView.session.currentFrame,
              let bodyAnchor = session.anchors.compactMap({ $0 as? ARBodyAnchor }).first else {
            showAlert(title: "No Body Detected", message: "Please make sure your full body is visible to the camera.")
            return
        }
        
        // Capture the current frame
        let currentTime = CACurrentMediaTime()
        let jointTransforms = captureJointTransforms(from: bodyAnchor)
        
        capturedFrame = RecordedFrame(timestamp: currentTime, jointTransforms: jointTransforms)
        
        print("📸 Captured single frame with \(jointTransforms.count) joints")
        #endif
        
        // Show success feedback
        captureButton.setTitle("Frame Captured!", for: .normal)
        captureButton.backgroundColor = UIColor.systemGreen
        
        // Reset button after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.captureButton.setTitle("Capture Frame", for: .normal)
            self.captureButton.backgroundColor = UIColor.systemBlue
        }
        
        // Navigate to joint details screen
        showJointDetails()
    }
    
    // MARK: - Joint Capture and Analysis
    private func captureJointTransforms(from bodyAnchor: ARBodyAnchor) -> [ARSkeleton.JointName: simd_float4x4] {
        // Capture all available joints from the skeleton
        let allJoints: [ARSkeleton.JointName] = [
            // Core body joints
            .root,
            
            // Head and neck
            .head,
            
            // Arms and hands
            .leftShoulder,
            .leftHand,
            .rightShoulder,
            .rightHand,
            
            // Legs and feet
            .leftFoot,
            .rightFoot
        ]
        
        var jointTransforms: [ARSkeleton.JointName: simd_float4x4] = [:]
        
        for jointName in allJoints {
            let jointTransform = bodyAnchor.skeleton.modelTransform(for: jointName)
            jointTransforms[jointName] = jointTransform
        }
        
        return jointTransforms
    }
    
    private func showJointDetails() {
        guard let frame = capturedFrame else {
            showAlert(title: "No Frame Captured", message: "Please capture a frame first.")
            return
        }
        
        let jointDetailsVC = JointDetailsViewController(capturedFrame: frame)
        jointDetailsVC.modalPresentationStyle = .fullScreen
        present(jointDetailsVC, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Simulator Testing
    #if targetEnvironment(simulator)
    private func generateTestFrame() -> RecordedFrame {
        let currentTime = CACurrentMediaTime()
        var jointTransforms: [ARSkeleton.JointName: simd_float4x4] = [:]
        
        // Create realistic joint positions for a standing pose
        let allJoints: [ARSkeleton.JointName] = [
            .root, .head,
            .leftShoulder, .leftHand, .rightShoulder, .rightHand,
            .leftFoot, .rightFoot
        ]
        
        for joint in allJoints {
            let transform = generateTestTransform(for: joint)
            jointTransforms[joint] = transform
        }
        
        return RecordedFrame(timestamp: currentTime, jointTransforms: jointTransforms)
    }
    
    private func generateTestTransform(for joint: ARSkeleton.JointName) -> simd_float4x4 {
        // Generate realistic positions for different joints
        let position: SIMD3<Float>
        let rotation = simd_quatf(angle: Float.random(in: -0.1...0.1), axis: SIMD3<Float>(0, 1, 0))
        
        switch joint {
        case .root:
            position = SIMD3<Float>(0, 0, 0)
        case .head:
            position = SIMD3<Float>(0, 1.7, 0)
        case .leftShoulder:
            position = SIMD3<Float>(-0.4, 1.4, 0)
        case .rightShoulder:
            position = SIMD3<Float>(0.4, 1.4, 0)
        case .leftHand:
            position = SIMD3<Float>(-0.7, 1.0, 0.2)
        case .rightHand:
            position = SIMD3<Float>(0.7, 1.0, 0.2)
        case .leftFoot:
            position = SIMD3<Float>(-0.15, 0, 0)
        case .rightFoot:
            position = SIMD3<Float>(0.15, 0, 0)
        default:
            position = SIMD3<Float>(0, 0, 0)
        }
        
        // Create transform matrix
        let rotationMatrix = simd_float3x3(rotation)
        return simd_float4x4(
            SIMD4<Float>(rotationMatrix.columns.0, 0),
            SIMD4<Float>(rotationMatrix.columns.1, 0),
            SIMD4<Float>(rotationMatrix.columns.2, 0),
            SIMD4<Float>(position, 1)
        )
    }
    #endif
}
