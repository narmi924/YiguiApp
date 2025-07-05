import Foundation
import SwiftUI
import SceneKit

// 模型生成服务错误类型
enum ModelGenerationError: Error, CustomStringConvertible {
    case predictionFailed(String)
    case networkError(String)
    case downloadFailed(String)
    case modelLoadingFailed(String)

    var description: String {
        switch self {
        case .predictionFailed(let message):
            return "预测失败: \(message)"
        case .networkError(let message):
            return "网络错误: \(message)"
        case .downloadFailed(let message):
            return "下载失败: \(message)"
        case .modelLoadingFailed(let message):
            return "模型加载失败: \(message)"
        }
    }
}

// 模型生成请求体
struct ModelGenerationRequest: Codable {
    let height: Double
    let weight: Double
    let chest: Double
    let waist: Double
    let thigh: Double
}

// 模型生成响应体（异步模式）
struct AsyncModelGenerationResponse: Codable {
    let task_id: String
}

// 任务状态响应体
struct TaskStatusResponse: Codable {
    let status: String
    let url: String? // 改为单个URL字符串，而不是多个URL的字典
    let progress: Int? // 可选的进度信息
    let message: String? // 可选的状态消息
}

// 模型生成响应体（保留用于兼容性）
struct ModelGenerationResponse: Codable {
    let glb_url: String
}

// 服务器端点请求体
struct ServerModelRequest: Codable {
    let gender: String
    let height: Double
    let weight: Double
    let age: Int
    let texture: String
    let nickname: String
    let chest_ratio: Double?
    let waist_ratio: Double?
    let thigh_ratio: Double?
}

class ModelGenerationService {
    // 更新为新的服务器域名 - 模型生成接口
    private let serverEndpoint = "https://yiguiapp.xyz/generate"
    // 任务状态查询接口
    private let taskStatusEndpoint = "https://yiguiapp.xyz/task_status"
    
    // 身体形状预测服务
    private let shapePredictorService: BodyShapePredictorService
    
    // 初始化方法
    init() throws {
        self.shapePredictorService = try BodyShapePredictorService()
    }
    
    // 新的异步模型生成方法 - 返回task_id
    func generateModelAsync(height: Double, weight: Double, nickname: String, gender: String = "male", texture: String = "shirt.glb") async throws -> String {
        print("🧠 开始使用CoreML预测身体比例...")
        
        // 1. 调用CoreML服务进行预测
        let prediction = try await shapePredictorService.predict(height: height, weight: weight)
        print("📈 CoreML 预测结果: chest=\(prediction.chest), waist=\(prediction.waist), thigh=\(prediction.thigh)")
        
        // 2. 准备包含新参数的请求数据
        let requestData = ServerModelRequest(
            gender: gender,
            height: height,
            weight: weight,
            age: 25, // 默认年龄
            texture: texture,
            nickname: nickname,
            // 传递CoreML预测出的比例
            chest_ratio: prediction.chest,
            waist_ratio: prediction.waist,
            thigh_ratio: prediction.thigh
        )
        
        print("📤 发送包含CoreML比例的模型生成请求到服务器...")
        
        // 发送POST请求并接收task_id
        let taskId = try await sendAsyncModelGenerationRequest(requestData: requestData)
        
        print("✅ 成功提交模型生成任务，task_id: \(taskId)")
        return taskId
    }
    
    // 轮询任务状态
    func pollTaskStatus(nickname: String, taskId: String) async throws -> TaskStatusResponse {
        // 构建轮询URL: /task_status/{nickname}/{task_id}
        let pollURL = "\(taskStatusEndpoint)/\(nickname)/\(taskId)"
        
        guard let url = URL(string: pollURL) else {
            throw ModelGenerationError.networkError("无效的轮询URL")
        }
        
        // 创建GET请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        print("📋 轮询任务状态: \(pollURL)")
        
        // 发送请求并等待响应
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ModelGenerationError.networkError("无效的HTTP响应")
            }
            

            
            // 检查状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                throw ModelGenerationError.networkError("轮询失败: \(httpResponse.statusCode), 详情: \(errorMessage)")
            }
            
            // 打印原始响应数据用于调试
            let responseString = String(data: data, encoding: .utf8) ?? "无法解析响应数据"
            print("🔍 服务器原始响应: \(responseString)")
            
            // 解析任务状态响应
            let taskStatusResponse = try JSONDecoder().decode(TaskStatusResponse.self, from: data)
            print("📊 任务状态: \(taskStatusResponse.status)")
            
            // 打印详细的响应信息
            if let url = taskStatusResponse.url {
                print("📦 返回的URL: \(url)")
            } else {
                print("⚠️ 服务器响应中没有url字段")
            }
            
            if let progress = taskStatusResponse.progress {
                print("📈 进度: \(progress)%")
            }
            
            if let message = taskStatusResponse.message {
                print("💬 消息: \(message)")
            }
            
            return taskStatusResponse
        } catch {
            throw ModelGenerationError.networkError("轮询请求失败: \(error.localizedDescription)")
        }
    }
    
    // 发送异步模型生成请求到服务器 - 返回task_id
    private func sendAsyncModelGenerationRequest(requestData: ServerModelRequest) async throws -> String {
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
        
        print("📤 发送异步请求数据: \(String(data: jsonData, encoding: .utf8) ?? "无法编码")")
        
        // 发送请求并等待响应
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // 检查HTTP响应
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ModelGenerationError.networkError("无效的HTTP响应")
            }
            
            // 检查状态码
            guard (200...299).contains(httpResponse.statusCode) else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                throw ModelGenerationError.networkError("服务器返回错误: \(httpResponse.statusCode), 详情: \(errorMessage)")
            }
            
            // 解析包含task_id的响应
            let responseObj = try JSONDecoder().decode(AsyncModelGenerationResponse.self, from: data)
            print("📦 收到task_id: \(responseObj.task_id)")
            return responseObj.task_id
        } catch {
            throw ModelGenerationError.networkError("异步请求失败: \(error.localizedDescription)")
        }
    }
    
    // 生成并加载模型的完整流程
    func generateAndLoadModel(height: Double, weight: Double, nickname: String, gender: String = "male", texture: String = "shirt.glb", completion: @escaping (Result<URL, ModelGenerationError>) -> Void) {
        // 创建后台任务
        Task {
            do {
                print("🧠 开始使用CoreML预测身体比例...")
                
                // 1. 调用CoreML服务进行预测
                let prediction = try await shapePredictorService.predict(height: height, weight: weight)
                print("📈 CoreML 预测结果: chest=\(prediction.chest), waist=\(prediction.waist), thigh=\(prediction.thigh)")
                
                // 2. 准备包含新参数的请求数据
                let requestData = ServerModelRequest(
                    gender: gender,
                    height: height,
                    weight: weight,
                    age: 25, // 默认年龄
                    texture: texture,
                    nickname: nickname,
                    // 传递CoreML预测出的比例
                    chest_ratio: prediction.chest,
                    waist_ratio: prediction.waist,
                    thigh_ratio: prediction.thigh
                )
                
                print("📤 发送包含CoreML比例的模型生成请求到服务器...")
                
                // 发送POST请求并接收GLB文件URL
                let modelUrl = try await sendModelGenerationRequest(requestData: requestData)
                
                print("✅ 成功生成并下载定制模型")
                
                // 在主线程返回结果
                DispatchQueue.main.async {
                    completion(.success(modelUrl))
                }
            } catch let error as ModelGenerationError {
                print("❌ 捕获到 ModelGenerationError: \(error.description)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            } catch let error as BodyShapePredictorError {
                print("❌ 捕获到 BodyShapePredictorError: \(error.description)")
                DispatchQueue.main.async {
                    completion(.failure(.predictionFailed("CoreML 预测失败 - \(error.description)")))
                }
            } catch {
                print("❌ 捕获到未知错误: \(error.localizedDescription)")
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
    func downloadGLBFile(glbUrl: String) async throws -> URL {
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
        
        print("📥 开始下载模型: \(httpsUrl)")
        
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
            
            // 从URL路径中提取文件名，保留昵称前缀
            // 例如：https://yiguiapp.xyz/models/Alice_models/2025-05-27-14-00-00.glb
            // 保存为：Alice_models_2025-05-27-14-00-00.glb
            let urlComponents = url.pathComponents
            let modelFileName: String
            
            if urlComponents.count >= 2 && urlComponents.contains("models") {
                let modelsIndex = urlComponents.firstIndex(of: "models") ?? 0
                
                // 如果URL路径包含{nickname}_models格式的子目录
                if modelsIndex + 1 < urlComponents.count {
                    let folderName = urlComponents[modelsIndex + 1]
                    if folderName.hasSuffix("_models") && urlComponents.count > modelsIndex + 2 {
                        let originalFileName = urlComponents.last ?? "model.glb"
                        modelFileName = "\(folderName)_\(originalFileName)"
                    } else {
                        modelFileName = urlComponents.last ?? "model.glb"
                    }
                } else {
                    modelFileName = urlComponents.last ?? "model.glb"
                }
            } else {
                modelFileName = urlComponents.last ?? "model.glb"
            }
            
            // 创建新模型的永久存储路径
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
