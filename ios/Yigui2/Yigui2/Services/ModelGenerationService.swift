import Foundation
import SwiftUI
import SceneKit

// 模型生成服务错误类型
enum ModelGenerationError: Error {
    case predictionFailed(String)
    case networkError(String)
    case downloadFailed(String)
    case modelLoadingFailed(String)
}

// 模型生成请求体
struct ModelGenerationRequest: Codable {
    let height: Double
    let weight: Double
    let chest: Double
    let waist: Double
    let thigh: Double
}

// 模型生成响应体
struct ModelGenerationResponse: Codable {
    let glb_url: String
}

// 服务器端点请求体
struct ServerModelRequest: Codable {
    let gender: String
    let height: Double
    let weight: Double
    let age: Int
}

class ModelGenerationService {
    // 更新为新的服务器域名 - 模型生成接口
    private let serverEndpoint = "https://yiguiapp.xyz/generate"
    
    // 身体形状预测服务
    private let shapePredictorService: BodyShapePredictorService
    
    // 初始化方法
    init() throws {
        self.shapePredictorService = try BodyShapePredictorService()
    }
    
    // 生成并加载模型的完整流程
    func generateAndLoadModel(height: Double, weight: Double, completion: @escaping (Result<URL, ModelGenerationError>) -> Void) {
        // 创建后台任务
        Task {
            do {
                print("🧠 开始使用CoreML预测身体比例...")
                
                // 1. 获取身体比例预测（暂时不需要，服务器端有完整逻辑）
                // let prediction = try await shapePredictorService.predict(height: height, weight: weight)
                // print("📊 预测结果 - 胸围比例: \(prediction.chest), 腰围比例: \(prediction.waist), 大腿比例: \(prediction.thigh)")
                
                // 2. 准备请求数据（使用服务器API格式）
                let requestData = ServerModelRequest(
                    gender: "male",
                    height: height,
                    weight: weight,
                    age: 25 // 默认年龄
                )
                
                print("📤 发送模型生成请求到服务器...")
                
                // 3. 发送POST请求并接收GLB文件URL
                let modelUrl = try await sendModelGenerationRequest(requestData: requestData)
                
                print("✅ 成功生成并下载定制模型")
                
                // 4. 在主线程返回结果
                DispatchQueue.main.async {
                    completion(.success(modelUrl))
                }
            } catch let error as ModelGenerationError {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(.predictionFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    // 发送模型生成请求到服务器
    private func sendModelGenerationRequest(requestData: ServerModelRequest) async throws -> URL {
        // 创建URL对象
        guard let url = URL(string: serverEndpoint) else {
            throw ModelGenerationError.networkError("无效的服务器URL")
        }
        
        // 创建请求对象
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 编码请求数据
        let jsonData = try JSONEncoder().encode(requestData)
        request.httpBody = jsonData
        
        print("📤 发送请求数据: \(String(data: jsonData, encoding: .utf8) ?? "无法编码")")
        
        // 发送请求并等待响应
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ModelGenerationError.networkError("无效的HTTP响应")
            }
            
            print("📥 服务器响应状态码: \(httpResponse.statusCode)")
            
            // 检查状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                throw ModelGenerationError.networkError("服务器返回错误: \(httpResponse.statusCode), 详情: \(errorMessage)")
            }
            
            // 检查响应的Content-Type
            let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
            
            if contentType.contains("application/json") {
                // JSON响应，包含GLB文件URL
                let responseObj = try JSONDecoder().decode(ModelGenerationResponse.self, from: data)
                print("📦 收到GLB文件URL: \(responseObj.glb_url)")
                return try await downloadGLBFile(glbUrl: responseObj.glb_url)
            } else if contentType.contains("application/octet-stream") || contentType.contains("model/gltf-binary") {
                // 直接返回GLB文件数据
                print("📥 收到GLB文件数据，大小: \(data.count) bytes")
                return try await saveGLBData(data)
            } else {
                throw ModelGenerationError.networkError("不支持的响应类型: \(contentType)")
            }
        } catch {
            throw ModelGenerationError.networkError("网络请求失败: \(error.localizedDescription)")
        }
    }
    
    // 保存GLB数据到本地文件
    private func saveGLBData(_ data: Data) async throws -> URL {
        let fileManager = FileManager.default
        
        // 创建文档目录下的Models文件夹
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let modelsDirectory = documentsDirectory.appendingPathComponent("Models")
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        }
        
        // 创建新模型的永久存储路径
        let modelFileName = "CustomModel_\(UUID().uuidString).glb"
        let modelDestination = modelsDirectory.appendingPathComponent(modelFileName)
        
        // 保存GLB数据到文件
        try data.write(to: modelDestination)
        
        print("💾 GLB文件已保存到: \(modelDestination.path)")
        
        return modelDestination
    }
    
    // 直接下载GLB文件
    private func downloadGLBFile(glbUrl: String) async throws -> URL {
        // 确保使用HTTPS链接
        var httpsUrl = glbUrl
        if glbUrl.hasPrefix("http://") {
            httpsUrl = glbUrl.replacingOccurrences(of: "http://", with: "https://")
            print("🔒 转换为HTTPS链接: \(httpsUrl)")
        }
        
        // 创建URL对象
        guard let url = URL(string: httpsUrl) else {
            throw ModelGenerationError.downloadFailed("无效的下载URL")
        }
        
        // 下载GLB文件
        do {
            let (downloadURL, _) = try await URLSession.shared.download(from: url)
            
            // 创建永久存储目录
            let fileManager = FileManager.default
            let documentsDirectory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            
            let modelsDirectory = documentsDirectory.appendingPathComponent("Models")
            if !fileManager.fileExists(atPath: modelsDirectory.path) {
                try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            }
            
            // 创建新模型的永久存储路径
            let modelFileName = "CustomModel_\(UUID().uuidString).glb"
            let modelDestination = modelsDirectory.appendingPathComponent(modelFileName)
            
            // 将下载的文件移动到永久存储位置
            try fileManager.moveItem(at: downloadURL, to: modelDestination)
            
            print("💾 GLB文件已保存到: \(modelDestination.path)")
            
            return modelDestination
        } catch {
            throw ModelGenerationError.downloadFailed("下载GLB文件失败: \(error.localizedDescription)")
        }
    }
} 