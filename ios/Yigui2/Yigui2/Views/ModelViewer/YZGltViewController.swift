import UIKit
import SceneKit
import GLTFSceneKit

class YZGltViewController: UIViewController {
    
    private var scnView: SCNView!
    private var modelNode: SCNNode?
    var modelURL: URL? // 添加模型URL属性
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 禁用输入助手，避免布局约束冲突
        if #available(iOS 15.0, *) {
            // 使用新的 API
            if let windowScene = view.window?.windowScene {
                windowScene.windows.forEach { window in
                    window.subviews.forEach { view in
                        if NSStringFromClass(type(of: view)).contains("SystemInputAssistantView") {
                            view.removeFromSuperview()
                        }
                    }
                }
            }
        } else if #available(iOS 13.0, *) {
            let window = UIApplication.shared.windows.first { $0.isKeyWindow }
            window?.subviews.forEach { view in
                if NSStringFromClass(type(of: view)).contains("SystemInputAssistantView") {
                    view.removeFromSuperview()
                }
            }
        }
        
        // 创建 SCNView
        scnView = SCNView(frame: view.bounds)
        scnView.backgroundColor = .systemBackground
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scnView)
        
        // 设置场景
        let scene = SCNScene()
        scnView.scene = scene
        
        // 设置相机
        setupCamera()
        
        // 设置光源
        setupLighting()
        
        // 加载GLB模型
        if let url = modelURL {
            loadGLBModel(from: url)
        }
        
        // 启用用户交互
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
    }
    
    private func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 1, z: 5)
        scnView.scene?.rootNode.addChildNode(cameraNode)
        
        // 设置相机属性
        cameraNode.camera?.fieldOfView = 45.0
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        
        // 添加约束使相机始终看向场景中心
        let lookAtConstraint = SCNLookAtConstraint(target: scnView.scene?.rootNode)
        lookAtConstraint.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAtConstraint]
    }
    
    private func setupLighting() {
        // 环境光
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.white
        ambientLightNode.light?.intensity = 80
        scnView.scene?.rootNode.addChildNode(ambientLightNode)
        
        // 主光源（定向光）
        let directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.color = UIColor.white
        directionalLightNode.light?.intensity = 800
        directionalLightNode.position = SCNVector3(x: 5, y: 5, z: 5)
        directionalLightNode.eulerAngles = SCNVector3(x: -Float.pi/4, y: Float.pi/4, z: 0)
        directionalLightNode.light?.castsShadow = true
        scnView.scene?.rootNode.addChildNode(directionalLightNode)
        
        // 补光
        let fillLightNode = SCNNode()
        fillLightNode.light = SCNLight()
        fillLightNode.light?.type = .directional
        fillLightNode.light?.color = UIColor(white: 0.8, alpha: 1.0)
        fillLightNode.light?.intensity = 400
        fillLightNode.position = SCNVector3(x: -3, y: 3, z: 0)
        scnView.scene?.rootNode.addChildNode(fillLightNode)
    }
    
    private func loadGLBModel(from url: URL) {
        Model3DLoader.shared.loadModel(from: url) { [weak self] scene in
            guard let self = self, let scene = scene else {
                print("加载GLB模型失败")
                return
            }
            
            DispatchQueue.main.async {
                // 直接设置场景，不做任何调整
                self.scnView.scene = scene
                
                // 保存模型节点引用（如果需要）
                if let modelNode = scene.rootNode.childNodes.first {
                    self.modelNode = modelNode
                    print("✅ 模型加载完成，保持原始位置和比例")
                }
            }
        }
    }
} 