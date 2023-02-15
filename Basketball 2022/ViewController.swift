//
//  ViewController.swift
//  Basketball 2022
//
//  Created by Vitally Ochnev on 24.06.2022.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    // MARK: - Outlets
    @IBOutlet var sceneView: ARSCNView!
    
    @IBOutlet weak var pointLabel: UILabel!
    
    @IBOutlet weak var lifeLabel: UILabel!
    
    @IBOutlet weak var resetButton: UIButton!
    
    @IBOutlet weak var fireButton: UIButton!
    
    var gameing: Bool = false {
        didSet {
            self.setupTimer()
            self.setupButton()
        }
    }
    
    var point: Int = 0 {
        didSet {
            DispatchQueue.main.async {
                self.pointLabel.text = "POINT:\(self.point)"
            }
            
        }
    }
    
    var life: Int = 0 {
        didSet {
            
            if life <= 0 {
                self.gameOver()
            }
            DispatchQueue.main.async {
                self.lifeLabel.text = "LIFE:\(self.life)"
            }
            
        }
    }
    
    // MARK: - Properties
    let configuration = ARWorldTrackingConfiguration()
    
    var timer: Timer?
    
    var fireTime: Timer?
    
    func gameOver() {
        for node in self.sceneView.scene.rootNode.childNodes {
            node.removeFromParentNode()
        }
        self.gameing = false
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        self.sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        self.sceneView.showsStatistics = true
        
        self.sceneView.scene.physicsWorld.contactDelegate = self
                
        self.setupButton()
        self.setupFireButton()
    }
    
    
    @objc func reset() {
        self.life = 3
        self.point = 0
        self.gameing.toggle()
    }
    
    func setupFireButton() {
        fireButton.addTarget(self, action: #selector(fire), for: .touchDown)
        fireButton.addTarget(self, action: #selector(holdFire), for: .touchUpInside)
    }
    @objc func holdFire() {
        self.fireTime?.invalidate()
    }
    
    @objc func fire() {
        self.fireTime = .scheduledTimer(withTimeInterval: 0.2, repeats: true, block: { _ in
            guard let ballNode = self.getBall() else { return }
            
            // Add basketball to the camera position
            self.sceneView.scene.rootNode.addChildNode(ballNode)
        })
    }
    
    func setupButton() {
        DispatchQueue.main.async {
            self.resetButton.isHidden = self.gameing
            self.resetButton.setTitle("GAMEOVER\n Your Point: \(self.point) \n Restart", for: .normal)
            self.resetButton.addTarget(self, action: #selector(self.reset), for: .touchUpInside)
        }
    }
    
    func setupTimer() {
        
        if self.gameing {
            self.timer = .scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                if let ball = self.getBox() {
                    self.sceneView.scene.rootNode.addChildNode(ball)
                }
            })
        } else {
            self.timer?.invalidate()
        }
        

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Detect vertical planes
        configuration.planeDetection = [.horizontal, .vertical]
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - Methods
    func getBall() -> SCNNode? {
        // Get current frame
        guard let frame = sceneView.session.currentFrame else { return nil }
        
        // Get camera transform
        let cameraTransform = frame.camera.transform
        let matrixCameraTransform = SCNMatrix4(cameraTransform)
        
        // Ball geometry
        let ball = SCNSphere(radius: 0.05)
        ball.firstMaterial?.diffuse.contents = UIImage(named: "basketball")
        
        // Ball node
        let ballNode = SCNNode(geometry: ball)
        
        // Add physics body
        ballNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: ballNode))
        
        // Calculate force for pushing the ball
        let power = Float(100)
        let x = -matrixCameraTransform.m31 * power
        let y = -matrixCameraTransform.m32 * power
        let z = -matrixCameraTransform.m33 * power
        let forceDirection = SCNVector3(x, y, z)
        
        // Apply force
        ballNode.physicsBody?.applyForce(forceDirection, asImpulse: true)
        
        //Assign camera position to ball
        ballNode.simdTransform = cameraTransform
        
        return ballNode
    }
    
    func getBox() -> SCNNode? {
        // 每當添加新的錨點時，我們創建一個新的 boxNode 並將其添加到場景中
        let box = SCNBox(width: 1, height: 1, length: 1, chamferRadius: 0)
        box.firstMaterial?.diffuse.contents = UIImage(named: "head\(Int.random(in: 1...11))")
        let boxNode = SCNNode(geometry: box)

        
        // 創建一個隨機的向量，用於確定 boxNode 的初始位置
        let x = Float.random(in: -10...10)
        let y = Float.random(in: 0...1)
        let z = Float(-50)
        let position = SCNVector3(x, y, z)
        boxNode.position = position
        boxNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: boxNode))
        boxNode.physicsBody?.contactTestBitMask = 1
        
        // 為 boxNode 添加一個向量，使其向鏡頭飛過來
        let direction = SCNVector3(0, 0, -1)
        
        let action = SCNAction.move(to: direction, duration: TimeInterval(Float.random(in: 0...5)))
        boxNode.runAction(action,completionHandler: {
            self.life -= 1
            boxNode.removeFromParentNode()
        })
        return boxNode
    }
    
    // 實現 SCNPhysicsContactDelegate 方法，當 SCNNode 碰撞時調用
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        print(contact)
        self.point += 1
        contact.nodeA.removeFromParentNode()
        contact.nodeB.removeFromParentNode()
    }
    
    func getHoopNode() -> SCNNode {
        let scene = SCNScene(named: "Hoop.scn", inDirectory: "art.scnassets")!
        
        let hoopNode = scene.rootNode.clone()
        
        hoopNode.physicsBody = SCNPhysicsBody(
            type: .static,
            shape: SCNPhysicsShape(node: hoopNode,
            options: [SCNPhysicsShape.Option.type: SCNPhysicsShape.ShapeType.concavePolyhedron]
                )
        )
        
        return hoopNode
    }
    
    func getPlaneNode(for anchor: ARPlaneAnchor) -> SCNNode {
        let extent = anchor.extent
        print(#line, #function, extent)
        let plane = SCNPlane(width: CGFloat(extent.x), height: CGFloat(extent.z))
        plane.firstMaterial?.diffuse.contents = UIColor.green
        
        //Create 25% transparent plane node
        let planeNode = SCNNode(geometry: plane)
        planeNode.opacity = 0.5
        
        // Rotate hoop node
        planeNode.eulerAngles.x -= .pi / 2
        
        return planeNode
        
    }
    
    func updatePlaneNode(_ node: SCNNode, for anchor: ARPlaneAnchor) {
        guard let planeNode = node.childNodes.first, let plane = planeNode.geometry as? SCNPlane else {
            return
        }
        
        // Change plane node center
        planeNode.simdPosition = anchor.center
        
        // Change plane size
        let extent = anchor.extent
        plane.width = CGFloat(extent.x)
        plane.height = CGFloat(extent.z)
    }
    
    // MARK: - ARSCNViewDelegate
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else {
            return
        }
        
        // Update plane node
        updatePlaneNode(node, for: planeAnchor)
    }
    
    // MARK: - Actions
    @IBAction func userTapped(_ sender: UITapGestureRecognizer) {
        guard self.gameing else { return }
        guard let ballNode = getBall() else { return }
        
        // Add basketball to the camera position
        sceneView.scene.rootNode.addChildNode(ballNode)
 
    }
}
