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
        } else {
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
        
        // 配置渲染设置以减少错误
        scnView.antialiasingMode = .none  // 禁用抗锯齿以避免转换错误
        scnView.preferredFramesPerSecond = 60
        
        // 禁用连续渲染和一些可能引起问题的功能
        if #available(iOS 13.0, *) {
            scnView.rendersContinuously = false
        }
        
        // 配置渲染选项以减少转换错误
        scnView.isTemporalAntialiasingEnabled = false
        scnView.isJitteringEnabled = false
        scnView.showsStatistics = false  // 禁用统计信息显示
        
        view.addSubview(scnView)
        
        // 设置场景
        let scene = SCNScene()
        scnView.scene = scene
        
        // 设置相机
        setupCamera()
        
        // 加载GLB模型（完全保持原始方式）
        if let url = modelURL {
            loadGLBModel(from: url)
        }
        
        // 启用用户交互和默认光照
        scnView.allowsCameraControl = true
        scnView.autoenablesDefaultLighting = true
        
        // 轻微改善显示效果
        scnView.isJitteringEnabled = false
        if #available(iOS 11.0, *) {
            scnView.debugOptions = []
        }
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
    
    private func loadGLBModel(from url: URL) {
        Model3DLoader.shared.loadModel(from: url) { [weak self] scene in
            guard let self = self, let scene = scene else {
                print("加载GLB模型失败")
                return
            }
            
            DispatchQueue.main.async {
                // 直接设置场景，完全保持原始方式
                self.scnView.scene = scene
                
                // 添加额外光照提高亮度（不影响模型结构）
                self.enhanceSceneLighting()
                
                // 保存模型节点引用
                if let modelNode = scene.rootNode.childNodes.first {
                    self.modelNode = modelNode
                    print("✅ 模型加载完成，完全保持原始结构，已增强光照")
                }
            }
        }
    }
    
    // 增强场景光照，提高整体亮度
    private func enhanceSceneLighting() {
        guard let scene = scnView.scene else { return }
        
        // 添加强环境光来提高整体亮度
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.white
        ambientLightNode.light?.intensity = 300 // 较强的环境光
        scene.rootNode.addChildNode(ambientLightNode)
        
        // 添加主定向光
        let directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.color = UIColor.white
        directionalLightNode.light?.intensity = 800 // 较强的定向光
        directionalLightNode.position = SCNVector3(x: 5, y: 5, z: 5)
        directionalLightNode.eulerAngles = SCNVector3(x: -Float.pi/4, y: Float.pi/4, z: 0)
        directionalLightNode.light?.castsShadow = true
        scene.rootNode.addChildNode(directionalLightNode)
        
        // 添加前方补光
        let frontLightNode = SCNNode()
        frontLightNode.light = SCNLight()
        frontLightNode.light?.type = .directional
        frontLightNode.light?.color = UIColor.white
        frontLightNode.light?.intensity = 600
        frontLightNode.position = SCNVector3(x: 0, y: 2, z: 8)
        frontLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(frontLightNode)
        
        // 添加侧面补光
        let sideLightNode = SCNNode()
        sideLightNode.light = SCNLight()
        sideLightNode.light?.type = .directional
        sideLightNode.light?.color = UIColor(white: 0.9, alpha: 1.0)
        sideLightNode.light?.intensity = 400
        sideLightNode.position = SCNVector3(x: -3, y: 3, z: 0)
        scene.rootNode.addChildNode(sideLightNode)
        
        // 添加背光减少阴影
        let backLightNode = SCNNode()
        backLightNode.light = SCNLight()
        backLightNode.light?.type = .directional
        backLightNode.light?.color = UIColor(white: 0.8, alpha: 1.0)
        backLightNode.light?.intensity = 300
        backLightNode.position = SCNVector3(x: 0, y: 1, z: -5)
        backLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(backLightNode)
        
        print("🔆 已添加增强光照系统，提高整体亮度")
    }
} 