/*
PlaybackViewController for displaying recorded skeleton motion playback.

Abstract:
Displays recorded skeleton animation on a white background with playback controls.
*/

import UIKit
import RealityKit
import ARKit

class PlaybackViewController: UIViewController {
    
    // MARK: - Properties
    private var arView: ARView!
    private let recordedFrames: [RecordedFrame]
    private var currentFrameIndex = 0
    private var displayLink: CADisplayLink?
    private var isPlaying = false
    private var skeletonEntities: [ARSkeleton.JointName: ModelEntity] = [:]
    private var boneEntities: [ModelEntity] = []
    private let playbackAnchor = AnchorEntity()
    
    // MARK: - UI Elements
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("← Back", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor.systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var playPauseButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Play", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor.systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(playPauseButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var replayButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Replay", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor.systemOrange
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(replayButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var progressLabel: UILabel = {
        let label = UILabel()
        label.text = "Frame: 0 / 0"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Initialization
    init(recordedFrames: [RecordedFrame]) {
        self.recordedFrames = recordedFrames
        super.init(nibName: nil, bundle: nil)
        print("PlaybackViewController initialized with \(recordedFrames.count) frames")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        print("PlaybackViewController viewDidLoad with \(recordedFrames.count) frames")
        setupARView()
        setupUI()
        setupSkeleton()
        updateProgressLabel()
        
        // Debug: Print first frame data
        if let firstFrame = recordedFrames.first {
            print("First frame has \(firstFrame.jointTransforms.count) joints:")
            for (joint, transform) in firstFrame.jointTransforms {
                let position = simd_make_float3(transform.columns.3)
                print("  \(joint): position = \(position)")
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopPlayback()
    }
    
    // MARK: - Setup Methods
    private func setupARView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Set white background
        arView.environment.background = .color(.white)
        
        // Disable AR tracking since we're showing recorded data
        arView.automaticallyConfigureSession = false
        
        // Add camera setup for better viewing
        arView.cameraMode = .nonAR
        
        view.addSubview(arView)
        
        // Position the anchor in front of the camera
        playbackAnchor.position = SIMD3<Float>(0, 0, -2) // 2 meters in front
        arView.scene.addAnchor(playbackAnchor)
    }
    
    private func setupUI() {
        view.addSubview(backButton)
        view.addSubview(playPauseButton)
        view.addSubview(replayButton)
        view.addSubview(progressLabel)
        
        NSLayoutConstraint.activate([
            // Back button - top left
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Progress label - top center
            progressLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            progressLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Play/Pause button - bottom center
            playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playPauseButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            
            // Replay button - next to play/pause
            replayButton.centerYAnchor.constraint(equalTo: playPauseButton.centerYAnchor),
            replayButton.leadingAnchor.constraint(equalTo: playPauseButton.trailingAnchor, constant: 20)
        ])
    }
    
    private func setupSkeleton() {
        guard !recordedFrames.isEmpty else { return }
        
        // Get all joints from the first frame to create complete skeleton
        let firstFrame = recordedFrames.first!
        let allJoints = Array(firstFrame.jointTransforms.keys)
        
        // Create joint entities for all recorded joints
        for jointName in allJoints {
            let radius: Float = getJointRadius(for: jointName)
            let mesh = MeshResource.generateSphere(radius: radius)
            
            var material = SimpleMaterial()
            material.baseColor = MaterialColorParameter.color(getJointColor(for: jointName))
            
            let entity = ModelEntity(mesh: mesh, materials: [material])
            skeletonEntities[jointName] = entity
            playbackAnchor.addChild(entity)
        }
        
        // Create bones (lines between joints) for complete skeleton
        createCompleteBoneStructure()
        
        // Set initial positions
        updateSkeletonPose(frame: firstFrame)
        
        print("Complete skeleton setup with \(skeletonEntities.count) joints and \(boneEntities.count) bones")
    }
    
    private func getJointRadius(for joint: ARSkeleton.JointName) -> Float {
        switch joint {
        case .leftHand, .rightHand:
            return 0.05 // Larger for hands (key tracking points)
        case .head:
            return 0.06 // Head
        case .root, .hips:
            return 0.04 // Core joints
        case .leftShoulder1, .rightShoulder1:
            return 0.035 // Shoulders
        case .leftFoot, .rightFoot:
            return 0.04 // Feet
        default:
            return 0.025 // Standard joint size
        }
    }
    
    private func getJointColor(for joint: ARSkeleton.JointName) -> UIColor {
        switch joint {
        case .leftHand:
            return .red // Left hand - red
        case .rightHand:
            return .blue // Right hand - blue
        case .head:
            return .yellow // Head - yellow
        case .root, .hips:
            return .purple // Core - purple
        case .leftShoulder1, .rightShoulder1:
            return .green // Shoulders - green
        case .leftFoot, .rightFoot:
            return .orange // Feet - orange
        case _ where joint.rawValue.contains("left"):
            return .systemRed // Left side joints - red tint
        case _ where joint.rawValue.contains("right"):
            return .systemBlue // Right side joints - blue tint
        default:
            return .gray // All other joints - gray
        }
    }
    }
    
    private func createCompleteBoneStructure() {
        // Define all bone connections for a complete human skeleton
        let boneConnections: [(ARSkeleton.JointName, ARSkeleton.JointName)] = [
            // Spine chain
            (.root, .hips),
            (.hips, .spine1),
            (.spine1, .spine2),
            (.spine2, .spine3),
            (.spine3, .spine4),
            (.spine4, .spine5),
            (.spine5, .spine6),
            (.spine6, .spine7),
            
            // Neck and head
            (.spine7, .neck1),
            (.neck1, .neck2),
            (.neck2, .neck3),
            (.neck3, .neck4),
            (.neck4, .head),
            
            // Left arm chain
            (.spine7, .leftShoulder1),
            (.leftShoulder1, .leftArm),
            (.leftArm, .leftForearm),
            (.leftForearm, .leftHand),
            
            // Right arm chain
            (.spine7, .rightShoulder1),
            (.rightShoulder1, .rightArm),
            (.rightArm, .rightForearm),
            (.rightForearm, .rightHand),
            
            // Left leg chain
            (.hips, .leftUpLeg),
            (.leftUpLeg, .leftLeg),
            (.leftLeg, .leftFoot),
            
            // Right leg chain
            (.hips, .rightUpLeg),
            (.rightUpLeg, .rightLeg),
            (.rightLeg, .rightFoot),
            
            // Left hand fingers
            (.leftHand, .leftHandThumb1),
            (.leftHandThumb1, .leftHandThumb2),
            (.leftHandThumb2, .leftHandThumb3),
            
            (.leftHand, .leftHandIndex1),
            (.leftHandIndex1, .leftHandIndex2),
            (.leftHandIndex2, .leftHandIndex3),
            
            (.leftHand, .leftHandMiddle1),
            (.leftHandMiddle1, .leftHandMiddle2),
            (.leftHandMiddle2, .leftHandMiddle3),
            
            (.leftHand, .leftHandRing1),
            (.leftHandRing1, .leftHandRing2),
            (.leftHandRing2, .leftHandRing3),
            
            (.leftHand, .leftHandLittleFinger1),
            (.leftHandLittleFinger1, .leftHandLittleFinger2),
            (.leftHandLittleFinger2, .leftHandLittleFinger3),
            
            // Right hand fingers
            (.rightHand, .rightHandThumb1),
            (.rightHandThumb1, .rightHandThumb2),
            (.rightHandThumb2, .rightHandThumb3),
            
            (.rightHand, .rightHandIndex1),
            (.rightHandIndex1, .rightHandIndex2),
            (.rightHandIndex2, .rightHandIndex3),
            
            (.rightHand, .rightHandMiddle1),
            (.rightHandMiddle1, .rightHandMiddle2),
            (.rightHandMiddle2, .rightHandMiddle3),
            
            (.rightHand, .rightHandRing1),
            (.rightHandRing1, .rightHandRing2),
            (.rightHandRing2, .rightHandRing3),
            
            (.rightHand, .rightHandLittleFinger1),
            (.rightHandLittleFinger1, .rightHandLittleFinger2),
            (.rightHandLittleFinger2, .rightHandLittleFinger3)
        ]
        
        // Create bone entities for all connections
        for (startJoint, endJoint) in boneConnections {
            // Only create bones if both joints exist in our recorded data
            if recordedFrames.first?.jointTransforms[startJoint] != nil &&
               recordedFrames.first?.jointTransforms[endJoint] != nil {
                
                let boneWidth = getBoneWidth(from: startJoint, to: endJoint)
                let mesh = MeshResource.generateBox(width: boneWidth, height: boneWidth, depth: 0.2)
                let material = SimpleMaterial(color: getBoneColor(from: startJoint, to: endJoint), isMetallic: false)
                let boneEntity = ModelEntity(mesh: mesh, materials: [material])
                
                // Store the connection info in the bone entity for later updates
                boneEntity.name = "\(startJoint.rawValue)-\(endJoint.rawValue)"
                
                boneEntities.append(boneEntity)
                playbackAnchor.addChild(boneEntity)
            }
        }
        
        print("Created \(boneEntities.count) bone entities for complete skeleton")
    }
    
    private func getBoneWidth(from startJoint: ARSkeleton.JointName, to endJoint: ARSkeleton.JointName) -> Float {
        // Major bones are thicker
        if startJoint == .spine7 || endJoint == .spine7 ||
           startJoint == .hips || endJoint == .hips ||
           startJoint.rawValue.contains("UpLeg") || endJoint.rawValue.contains("UpLeg") ||
           startJoint.rawValue.contains("Arm") || endJoint.rawValue.contains("Arm") {
            return 0.03
        }
        // Finger bones are thinner
        else if startJoint.rawValue.contains("Hand") || endJoint.rawValue.contains("Hand") {
            return 0.015
        }
        // Standard bone width
        else {
            return 0.02
        }
    }
    
    private func getBoneColor(from startJoint: ARSkeleton.JointName, to endJoint: ARSkeleton.JointName) -> UIColor {
        // Color bones based on body part
        if startJoint.rawValue.contains("left") || endJoint.rawValue.contains("left") {
            return .systemRed.withAlphaComponent(0.7) // Left side - red tint
        } else if startJoint.rawValue.contains("right") || endJoint.rawValue.contains("right") {
            return .systemBlue.withAlphaComponent(0.7) // Right side - blue tint
        } else {
            return .darkGray.withAlphaComponent(0.8) // Central bones - dark gray
        }
    }
    
    // MARK: - Playback Methods
    private func startPlayback() {
        guard !recordedFrames.isEmpty else { return }
        
        isPlaying = true
        playPauseButton.setTitle("Pause", for: .normal)
        playPauseButton.backgroundColor = UIColor.systemRed
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateFrame))
        displayLink?.preferredFramesPerSecond = 60
        displayLink?.add(to: .current, forMode: .default)
    }
    
    private func stopPlayback() {
        isPlaying = false
        playPauseButton.setTitle("Play", for: .normal)
        playPauseButton.backgroundColor = UIColor.systemGreen
        
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateFrame() {
        guard currentFrameIndex < recordedFrames.count else {
            stopPlayback()
            return
        }
        
        let frame = recordedFrames[currentFrameIndex]
        updateSkeletonPose(frame: frame)
        
        currentFrameIndex += 1
        updateProgressLabel()
        
        // Loop the animation when it reaches the end
        if currentFrameIndex >= recordedFrames.count {
            currentFrameIndex = 0
        }
    }
    
    private func updateSkeletonPose(frame: RecordedFrame) {
        // Update joint positions
        for (jointName, transform) in frame.jointTransforms {
            if let entity = skeletonEntities[jointName] {
                // Scale down the transform since AR coordinates can be large
                let scaledTransform = simd_float4x4(
                    [transform.columns.0.x, transform.columns.0.y, transform.columns.0.z, transform.columns.0.w],
                    [transform.columns.1.x, transform.columns.1.y, transform.columns.1.z, transform.columns.1.w],
                    [transform.columns.2.x, transform.columns.2.y, transform.columns.2.z, transform.columns.2.w],
                    [transform.columns.3.x * 0.5, transform.columns.3.y * 0.5, transform.columns.3.z * 0.5, transform.columns.3.w]
                )
                entity.transform = Transform(matrix: scaledTransform)
            }
        }
        
        // Update all bone positions and orientations based on their joint connections
        for boneEntity in boneEntities {
            if let boneName = boneEntity.name {
                let jointNames = boneName.components(separatedBy: "-")
                if jointNames.count == 2,
                   let startJointName = ARSkeleton.JointName(rawValue: jointNames[0]),
                   let endJointName = ARSkeleton.JointName(rawValue: jointNames[1]),
                   let startTransform = frame.jointTransforms[startJointName],
                   let endTransform = frame.jointTransforms[endJointName] {
                    
                    updateBoneEntity(boneEntity, from: startTransform, to: endTransform)
                }
            }
        }
    }
    
    private func updateBoneEntity(_ boneEntity: ModelEntity, from startTransform: simd_float4x4, to endTransform: simd_float4x4) {
        let startPos = simd_make_float3(startTransform.columns.3) * 0.5
        let endPos = simd_make_float3(endTransform.columns.3) * 0.5
        let midPos = (startPos + endPos) * 0.5
        let direction = endPos - startPos
        let distance = simd_length(direction)
        
        // Position the bone at the midpoint
        boneEntity.position = midPos
        
        // Scale the bone to match the distance between joints
        boneEntity.scale = SIMD3<Float>(1, 1, max(distance / 0.2, 0.1))
        
        // Orient the bone towards the end joint
        if distance > 0.001 { // Avoid division by zero
            let normalizedDirection = normalize(direction)
            
            // Create rotation to align bone with direction
            let forward = SIMD3<Float>(0, 0, 1) // Default bone direction
            let rotationAxis = cross(forward, normalizedDirection)
            let rotationAngle = acos(dot(forward, normalizedDirection))
            
            if simd_length(rotationAxis) > 0.001 {
                let normalizedAxis = normalize(rotationAxis)
                boneEntity.orientation = simd_quatf(angle: rotationAngle, axis: normalizedAxis)
            } else {
                // Handle parallel vectors
                if dot(forward, normalizedDirection) < 0 {
                    boneEntity.orientation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                } else {
                    boneEntity.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
                }
            }
        }
    }
    
    private func updateProgressLabel() {
        progressLabel.text = "Frame: \(currentFrameIndex) / \(recordedFrames.count)"
    }
    
    // MARK: - Button Actions
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func playPauseButtonTapped() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }
    
    @objc private func replayButtonTapped() {
        stopPlayback()
        currentFrameIndex = 0
        updateProgressLabel()
        
        if let firstFrame = recordedFrames.first {
            updateSkeletonPose(frame: firstFrame)
        }
        
        startPlayback()
    }
}