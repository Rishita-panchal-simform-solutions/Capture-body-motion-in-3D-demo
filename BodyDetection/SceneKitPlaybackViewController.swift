import UIKit
import SceneKit
import ARKit

class SceneKitPlaybackViewController: UIViewController {

    private var sceneView: SCNView!
    private var recordedFrames: [RecordedFrame] = []
    private var robotNode: SCNNode?
    
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
    
    private lazy var infoLabel: UILabel = {
        let label = UILabel()
        label.text = "3D Robot Pose Visualization"
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .black
        label.textAlignment = .center
        label.backgroundColor = UIColor.white.withAlphaComponent(0.8)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupUI()
        loadRobot()
    }
    
    // MARK: - Public Methods
    func setRecordedFrames(_ frames: [RecordedFrame]) {
        self.recordedFrames = frames
        if !frames.isEmpty {
            infoLabel.text = "Showing captured pose with \(frames[0].jointTransforms.count) joints"
        }
    }

    private func setupSceneView() {
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = UIColor.lightGray
        sceneView.allowsCameraControl = true
        view.addSubview(sceneView)

        let scene = SCNScene()
        sceneView.scene = scene
    }
    
    private func setupUI() {
        view.addSubview(backButton)
        view.addSubview(infoLabel)
        
        NSLayoutConstraint.activate([
            // Back button
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Info label
            infoLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 15),
            infoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            infoLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func loadRobot() {
        guard let robotURL = Bundle.main.url(forResource: "robot", withExtension: "usdz", subdirectory: "character") else {
            print("Could not find robot.usdz file")
            return
        }

        do {
            let robotScene = try SCNScene(url: robotURL, options: [
                SCNSceneSource.LoadingOption.preserveOriginalTopology: true,
                SCNSceneSource.LoadingOption.flattenScene: false
            ])

            // Clone the robot scene to avoid modifying the original
            let robotNode = robotScene.rootNode.clone()
            self.robotNode = robotNode

            // Don't modify scale, position, or any transforms - keep original
            sceneView.scene?.rootNode.addChildNode(robotNode)

            // Add basic lighting to see the robot properly
            setupLighting()

            // Position camera to view the robot
            setupCamera()

            print("Robot loaded successfully with original shape preserved")
            
            // Apply captured pose if available
            applyCapturePose()

        } catch {
            print("Error loading robot: \(error)")
        }
    }

    private func setupLighting() {
        guard let scene = sceneView.scene else { return }

        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(white: 0.6, alpha: 1.0)
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)

        // Directional light
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = UIColor(white: 0.8, alpha: 1.0)
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.position = SCNVector3(10, 10, 10)
        scene.rootNode.addChildNode(directionalLightNode)
    }

    private func setupCamera() {
        guard let scene = sceneView.scene else { return }

        // Add a camera if one doesn't exist
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 0, 5) // Adjust distance as needed
        scene.rootNode.addChildNode(cameraNode)
    }
    
    private func applyCapturePose() {
        guard let _ = self.robotNode,
              let capturedFrame = recordedFrames.first else {
            print("No robot node or captured frame available")
            return
        }
        
        print("📝 Applying captured pose with \(capturedFrame.jointTransforms.count) joints")
        
        // For demonstration, we'll add visible markers at joint positions
        // Since the robot model might not have easily mappable joints, 
        // we'll create visual indicators for the captured joint positions
        addJointMarkers(for: capturedFrame)
    }
    
    private func addJointMarkers(for frame: RecordedFrame) {
        // Remove any existing markers
        sceneView.scene?.rootNode.childNodes.forEach { node in
            if node.name?.hasPrefix("joint_marker") == true {
                node.removeFromParentNode()
            }
        }
        
        // Add markers for each joint
        for (jointName, transform) in frame.jointTransforms {
            let position = simd_make_float3(transform.columns.3)
            
            // Create a small sphere to represent the joint
            let sphere = SCNSphere(radius: 0.02)
            sphere.firstMaterial?.diffuse.contents = getJointColor(for: jointName)
            
            let markerNode = SCNNode(geometry: sphere)
            markerNode.position = SCNVector3(position.x, position.y, position.z)
            markerNode.name = "joint_marker_\(jointName.rawValue)"
            
            sceneView.scene?.rootNode.addChildNode(markerNode)
            
            // Add a text label above the joint
            let text = SCNText(string: jointName.rawValue, extrusionDepth: 0.001)
            text.font = UIFont.systemFont(ofSize: 0.02)
            text.firstMaterial?.diffuse.contents = UIColor.black
            
            let textNode = SCNNode(geometry: text)
            textNode.position = SCNVector3(position.x, position.y + 0.05, position.z)
            textNode.scale = SCNVector3(0.5, 0.5, 0.5)
            textNode.name = "joint_label_\(jointName.rawValue)"
            
            sceneView.scene?.rootNode.addChildNode(textNode)
        }
        
        print("✅ Added \(frame.jointTransforms.count) joint markers to scene")
    }
    
    private func getJointColor(for jointName: ARSkeleton.JointName) -> UIColor {
        switch jointName {
        case .root:
            return .red
        case .head:
            return .yellow
        case .leftShoulder, .rightShoulder:
            return .blue
        case .leftHand, .rightHand:
            return .green
        case .leftFoot, .rightFoot:
            return .orange
        default:
            return .purple
        }
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
}
