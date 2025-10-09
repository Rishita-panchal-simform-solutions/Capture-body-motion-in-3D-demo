/*
JointDetailsViewController for displaying captured joint information.

Abstract:
Displays all joint names and their movement values (position, rotation) for a single captured frame.
*/

import UIKit
import ARKit
import simd

class JointDetailsViewController: UIViewController {
    
    // MARK: - Properties
    private let capturedFrame: RecordedFrame
    private var tableView: UITableView!
    private var jointData: [(name: String, position: SIMD3<Float>, rotation: simd_quatf)] = []
    
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
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Joint Movement Data"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var timestampLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .systemGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var sceneKitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("View in SceneKit", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.backgroundColor = UIColor.systemPurple
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        button.addTarget(self, action: #selector(sceneKitButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Initialization
    init(capturedFrame: RecordedFrame) {
        self.capturedFrame = capturedFrame
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        setupUI()
        processJointData()
        setupTableView()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(timestampLabel)
        view.addSubview(sceneKitButton)
        
        // Set timestamp
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        timestampLabel.text = "Captured: \(formatter.string(from: Date(timeIntervalSince1970: capturedFrame.timestamp)))"
        
        NSLayoutConstraint.activate([
            // Back button
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Timestamp
            timestampLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            timestampLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            timestampLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // SceneKit button
            sceneKitButton.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 15),
            sceneKitButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(JointDetailCell.self, forCellReuseIdentifier: "JointDetailCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: sceneKitButton.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Data Processing
    private func processJointData() {
        jointData.removeAll()
        
        for (jointName, transform) in capturedFrame.jointTransforms {
            // Extract position from transform matrix
            let position = simd_make_float3(transform.columns.3)
            
            // Extract rotation quaternion from transform matrix
            let rotationMatrix = simd_float3x3(
                simd_make_float3(transform.columns.0),
                simd_make_float3(transform.columns.1),
                simd_make_float3(transform.columns.2)
            )
            let rotation = simd_quatf(rotationMatrix)
            
            jointData.append((
                name: jointName.rawValue,
                position: position,
                rotation: rotation
            ))
        }
        
        // Sort by joint name for consistent display
        jointData.sort { $0.name < $1.name }
        
        print("📊 Processed \(jointData.count) joints for display")
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func sceneKitButtonTapped() {
        // Create an array with the single captured frame for SceneKit playback
        let recordedFrames = [capturedFrame]
        
        let sceneKitPlaybackVC = SceneKitPlaybackViewController()
        sceneKitPlaybackVC.setRecordedFrames(recordedFrames)
        sceneKitPlaybackVC.modalPresentationStyle = .fullScreen
        
        print("🚀 Presenting SceneKit PlaybackViewController with single frame...")
        present(sceneKitPlaybackVC, animated: true) {
            print("✅ SceneKit PlaybackViewController presented successfully")
        }
    }
}

// MARK: - TableView DataSource and Delegate
extension JointDetailsViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return jointData.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "JointDetailCell", for: indexPath) as! JointDetailCell
        let joint = jointData[indexPath.row]
        cell.configure(with: joint.name, position: joint.position, rotation: joint.rotation)
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Detected Joints (\(jointData.count) total)"
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 120
    }
}

// MARK: - Custom Cell
class JointDetailCell: UITableViewCell {
    
    private let jointNameLabel = UILabel()
    private let positionLabel = UILabel()
    private let rotationLabel = UILabel()
    private let containerView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        selectionStyle = .none
        
        // Container view for better layout
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 8
        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)
        
        // Joint name label
        jointNameLabel.font = UIFont.boldSystemFont(ofSize: 18)
        jointNameLabel.textColor = .label
        jointNameLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(jointNameLabel)
        
        // Position label
        positionLabel.font = UIFont.systemFont(ofSize: 14)
        positionLabel.textColor = .secondaryLabel
        positionLabel.numberOfLines = 0
        positionLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(positionLabel)
        
        // Rotation label
        rotationLabel.font = UIFont.systemFont(ofSize: 14)
        rotationLabel.textColor = .secondaryLabel
        rotationLabel.numberOfLines = 0
        rotationLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(rotationLabel)
        
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Joint name
            jointNameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            jointNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            jointNameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // Position
            positionLabel.topAnchor.constraint(equalTo: jointNameLabel.bottomAnchor, constant: 8),
            positionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            positionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            // Rotation
            rotationLabel.topAnchor.constraint(equalTo: positionLabel.bottomAnchor, constant: 4),
            rotationLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            rotationLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            rotationLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with jointName: String, position: SIMD3<Float>, rotation: simd_quatf) {
        jointNameLabel.text = jointName.capitalized
        
        positionLabel.text = String(format: "Position: X: %.3f, Y: %.3f, Z: %.3f", 
                                   position.x, position.y, position.z)
        
        // Convert quaternion to Euler angles for better understanding
        let eulerAngles = quaternionToEulerAngles(rotation)
        rotationLabel.text = String(format: "Rotation: X: %.1f°, Y: %.1f°, Z: %.1f°", 
                                   eulerAngles.x * 180 / Float.pi,
                                   eulerAngles.y * 180 / Float.pi,
                                   eulerAngles.z * 180 / Float.pi)
    }
    
    private func quaternionToEulerAngles(_ q: simd_quatf) -> SIMD3<Float> {
        // Convert quaternion to Euler angles (in radians)
        let w = q.real
        let x = q.imag.x
        let y = q.imag.y
        let z = q.imag.z
        
        // Roll (x-axis rotation)
        let sinr_cosp = 2 * (w * x + y * z)
        let cosr_cosp = 1 - 2 * (x * x + y * y)
        let roll = atan2(sinr_cosp, cosr_cosp)
        
        // Pitch (y-axis rotation)
        let sinp = 2 * (w * y - z * x)
        let pitch = abs(sinp) >= 1 ? copysign(Float.pi / 2, sinp) : asin(sinp)
        
        // Yaw (z-axis rotation)
        let siny_cosp = 2 * (w * z + x * y)
        let cosy_cosp = 1 - 2 * (y * y + z * z)
        let yaw = atan2(siny_cosp, cosy_cosp)
        
        return SIMD3<Float>(roll, pitch, yaw)
    }
}