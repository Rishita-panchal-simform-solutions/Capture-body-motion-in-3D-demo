import UIKit
import SceneKit

class SceneKitPlaybackViewController: UIViewController {

    private var sceneView: SCNView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        loadRobot()
    }

    private func setupSceneView() {
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.backgroundColor = UIColor.white
        sceneView.allowsCameraControl = true
        view.addSubview(sceneView)

        let scene = SCNScene()
        sceneView.scene = scene
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

            // Don't modify scale, position, or any transforms - keep original
            sceneView.scene?.rootNode.addChildNode(robotNode)

            // Add basic lighting to see the robot properly
            setupLighting()

            // Position camera to view the robot
            setupCamera()

            print("Robot loaded successfully with original shape preserved")

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
}
