import Foundation
import SceneKit
import ModelIO
import UIKit
import GLTFSceneKit

#if canImport(SceneKit.ModelIO)
import SceneKit.ModelIO
#endif

class Model3DLoader {
    // 单例模式
    static let shared = Model3DLoader()
    
    // 模型缓存
    private var modelCache: [String: SCNScene] = [:]
    
    // 私有初始化
    private init() {}
    
    // 加载模型
    func loadModel(from url: URL, completion: @escaping (SCNScene?) -> Void) {
        // 检查缓存
        let cacheKey = url.absoluteString
        if let cachedScene = modelCache[cacheKey] {
            completion(cachedScene)
            return
        }
        
        // 根据文件扩展名选择加载方法
        let fileExtension = url.pathExtension.lowercased()
        
        // 本地文件直接加载
        if url.isFileURL {
            if fileExtension == "glb" {
                // GLB文件需要特殊处理
                loadGLBModel(from: url) { scene in
                    if let scene = scene {
                        self.modelCache[cacheKey] = scene
                    }
                    completion(scene)
                }
            } else {
                // SCN、USDC等其他格式
                do {
                    let scene = try SCNScene(url: url, options: nil)
                    modelCache[cacheKey] = scene
                    completion(scene)
                } catch {
                    print("无法加载3D模型: \(error.localizedDescription)")
                    completion(nil)
                }
            }
            return
        }
        
        // 远程URL需要先下载
        downloadModel(from: url) { localURL in
            guard let localURL = localURL else {
                completion(nil)
                return
            }
            
            let fileExtension = localURL.pathExtension.lowercased()
            if fileExtension == "glb" {
                // GLB文件需要特殊处理
                self.loadGLBModel(from: localURL) { scene in
                    if let scene = scene {
                        self.modelCache[cacheKey] = scene
                    }
                    DispatchQueue.main.async {
                        completion(scene)
                    }
                }
            } else {
                // 其他格式
                do {
                    let scene = try SCNScene(url: localURL, options: nil)
                    DispatchQueue.main.async {
                        self.modelCache[cacheKey] = scene
                        completion(scene)
                    }
                } catch {
                    print("无法加载下载的3D模型: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    // 加载GLB格式模型
    private func loadGLBModel(from url: URL, completion: @escaping (SCNScene?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 检查文件是否存在
            guard FileManager.default.fileExists(atPath: url.path) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            do {
                // 使用 GLTFSceneKit 加载并优化材质
                let sceneSource = GLTFSceneSource(url: url)
                let scene = try sceneSource.scene()
                
                // 优化所有材质以减少渲染错误
                self.optimizeMaterials(in: scene.rootNode)
                
                DispatchQueue.main.async {
                    completion(scene)
                }
            } catch {
                print("❌ 3D模型加载失败: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    // 优化材质以减少渲染错误
    private func optimizeMaterials(in node: SCNNode) {
        // 处理当前节点的材质
        node.geometry?.materials.forEach { material in
            // 使用简单的Blinn光照模型，避免PBR复杂性
            material.lightingModel = .blinn
            
            // 简化材质属性，使用兼容的数据类型
            material.diffuse.wrapS = .repeat
            material.diffuse.wrapT = .repeat
            
            // 移除可能引起转换问题的属性
            material.normal.contents = nil
            material.displacement.contents = nil
            material.roughness.contents = nil
            material.metalness.contents = nil
            material.ambientOcclusion.contents = nil
            
            // 设置基本属性
            material.isDoubleSided = true
            material.transparency = 1.0
            material.transparencyMode = .default
            
            // 确保漫反射使用简单颜色
            if material.diffuse.contents == nil {
                material.diffuse.contents = UIColor.lightGray
            }
            
            // 禁用可能引起问题的特性
            material.writesToDepthBuffer = true
            material.readsFromDepthBuffer = true
        }
        
        // 递归处理子节点
        node.childNodes.forEach { optimizeMaterials(in: $0) }
    }
    
    // 增强材质渲染（保留原方法以备用）
    private func enhanceMaterials(in node: SCNNode) {
        // 处理当前节点的材质
        node.geometry?.materials.forEach { material in
            // 启用PBR渲染
            material.lightingModel = .physicallyBased
            
            // 增强材质属性
            material.roughness.intensity = 0.8
            material.metalness.intensity = 0.1
            
            // 设置双面渲染
            material.isDoubleSided = true
            
            // 增强漫反射
            if material.diffuse.contents == nil {
                material.diffuse.contents = UIColor.white
            }
            
            // 调整透明度
            material.transparency = 1.0
            
            print("🔧 增强材质: lightingModel=\(material.lightingModel.rawValue)")
        }
        
        // 递归处理子节点
        node.childNodes.forEach { enhanceMaterials(in: $0) }
    }
    
    // 递归打印场景结构
    private func printSceneStructure(node: SCNNode, level: Int) {
        let indent = String(repeating: "  ", count: level)
        let nodeName = node.name ?? "unnamed"
        let hasGeometry = node.geometry != nil
        let childCount = node.childNodes.count
        
        print("\(indent)📦 节点: \(nodeName) (几何体: \(hasGeometry ? "✅" : "❌"), 子节点: \(childCount))")
        
        if let geometry = node.geometry {
            print("\(indent)   🔺 几何体类型: \(type(of: geometry))")
            let sources = geometry.sources
            print("\(indent)   📊 数据源数量: \(sources.count)")
        }
        
        // 递归打印子节点
        for child in node.childNodes {
            printSceneStructure(node: child, level: level + 1)
        }
    }
    
    // 调整GLB模型的比例和位置
    private func adjustGLBModel(scene: SCNScene) {
        print("🔧 开始调整GLB模型...")
        
        // 打印场景结构信息
        print("📊 场景根节点子节点数量: \(scene.rootNode.childNodes.count)")
        
        // 查找主模型节点
        var modelNode: SCNNode?
        
        // 首先尝试找到第一个有几何体的节点
        func findGeometryNode(in node: SCNNode) -> SCNNode? {
            if node.geometry != nil {
                return node
            }
            for child in node.childNodes {
                if let found = findGeometryNode(in: child) {
                    return found
                }
            }
            return nil
        }
        
        if let geometryNode = findGeometryNode(in: scene.rootNode) {
            modelNode = geometryNode
            print("✅ 找到几何体节点: \(geometryNode.name ?? "unnamed")")
        } else if let firstChild = scene.rootNode.childNodes.first {
            modelNode = firstChild
            print("⚠️ 使用第一个子节点作为模型节点: \(firstChild.name ?? "unnamed")")
        } else {
            print("❌ 未找到可用的模型节点")
            return
        }
        
        guard let node = modelNode else { return }
        
        // 获取模型的边界框
        let (min, max) = node.boundingBox
        let size = SCNVector3(max.x - min.x, max.y - min.y, max.z - min.z)
        print("📏 模型尺寸: \(size)")
        
        // 应用默认旋转 - 确保模型正面朝前
        node.eulerAngles = SCNVector3(x: -Float.pi / 2, y: 0, z: 0)
        
        // 计算合适的缩放比例
        let maxDimension = Swift.max(size.x, Swift.max(size.y, size.z))
        let targetSize: Float = 4.0 // 目标大小
        let scale = maxDimension > 0 ? targetSize / maxDimension : 1.0
        
        // 应用缩放
        node.scale = SCNVector3(x: scale, y: scale, z: scale)
        print("🔧 应用缩放: \(scale)")
        
        // 调整位置以便正确显示 - 将模型底部对齐到地面
        let adjustedY = -size.y * scale / 2 - 1.0 // 稍微下移一点
        node.position = SCNVector3(x: 0, y: adjustedY, z: 0)
        print("📍 设置位置: \(node.position)")
        
        print("✅ GLB模型调整完成")
    }
    
    // 设置相机
    private func setupCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 1, z: 5)
        
        // 增强相机视角和属性
        cameraNode.camera?.fieldOfView = 45.0
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100
        cameraNode.camera?.automaticallyAdjustsZRange = true
        
        scene.rootNode.addChildNode(cameraNode)
        
        // 设置相机约束，使其始终看向模型中心
        let lookAtConstraint = SCNLookAtConstraint(target: scene.rootNode)
        lookAtConstraint.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAtConstraint]
    }
    
    // 设置光源
    private func setupLighting(in scene: SCNScene) {
        // 环境光 - 适中强度减少阴影区域的黑暗
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light?.type = .ambient
        ambientLightNode.light?.color = UIColor.white
        ambientLightNode.light?.intensity = 200 // 降低到200
        scene.rootNode.addChildNode(ambientLightNode)
        
        // 定向光（主光源）- 适中强度提供清晰的模型照明
        let directionalLightNode = SCNNode()
        directionalLightNode.light = SCNLight()
        directionalLightNode.light?.type = .directional
        directionalLightNode.light?.color = UIColor.white
        directionalLightNode.light?.intensity = 600 // 降低到600
        directionalLightNode.position = SCNVector3(x: 5, y: 5, z: 5)
        directionalLightNode.eulerAngles = SCNVector3(x: -Float.pi/4, y: Float.pi/4, z: 0)
        directionalLightNode.light?.castsShadow = true
        scene.rootNode.addChildNode(directionalLightNode)
        
        // 补光 - 适中强度减少阴影对比度
        let fillLightNode = SCNNode()
        fillLightNode.light = SCNLight()
        fillLightNode.light?.type = .directional
        fillLightNode.light?.color = UIColor(white: 0.9, alpha: 1.0)
        fillLightNode.light?.intensity = 300 // 降低到300
        fillLightNode.position = SCNVector3(x: -3, y: 3, z: 0)
        scene.rootNode.addChildNode(fillLightNode)
        
        // 第二个补光 - 轻微照明减少底部阴影
        let fillLight2Node = SCNNode()
        fillLight2Node.light = SCNLight()
        fillLight2Node.light?.type = .directional
        fillLight2Node.light?.color = UIColor(white: 0.8, alpha: 1.0)
        fillLight2Node.light?.intensity = 200 // 降低到200
        fillLight2Node.position = SCNVector3(x: 0, y: -2, z: 3) // 从下方照明
        scene.rootNode.addChildNode(fillLight2Node)
        
        print("🔆 已设置平衡光照系统: 环境光=200, 主光=600, 补光1=300, 补光2=200")
    }
    
    // 下载远程3D模型文件
    private func downloadModel(from url: URL, completion: @escaping (URL?) -> Void) {
        let task = URLSession.shared.downloadTask(with: url) { localURL, response, error in
            if let error = error {
                print("下载模型时出错: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("无效的服务器响应")
                completion(nil)
                return
            }
            
            guard let localURL = localURL else {
                print("下载文件URL为空")
                completion(nil)
                return
            }
            
            // 将文件移动到应用文档目录下
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)
            
            do {
                // 如果文件已存在，先删除
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                try FileManager.default.moveItem(at: localURL, to: destinationURL)
                completion(destinationURL)
            } catch {
                print("保存下载的文件时出错: \(error.localizedDescription)")
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    // 清除缓存
    func clearCache() {
        modelCache.removeAll()
    }
}

 
