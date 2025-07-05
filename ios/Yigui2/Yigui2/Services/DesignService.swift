import Foundation
import Combine

// MARK: - 数据模型
struct DesignProject: Codable, Identifiable {
    let id: Int
    let projectName: String
    let modelId: Int?
    let status: String
    let uuidFilename: String?
    let glbUrl: String?
    let thumbnailUrl: String?
    let taskId: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case projectName = "project_name"
        case modelId = "model_id"
        case status
        case uuidFilename = "uuid_filename"
        case glbUrl = "glb_url"
        case thumbnailUrl = "thumbnail_url"
        case taskId = "task_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct Pattern: Codable, Identifiable {
    let id: Int
    let name: String
    let category: String
    let dxfPath: String?
    let thumbnailPath: String?
    let description: String?
    let isSystem: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, description
        case dxfPath = "dxf_path"
        case thumbnailPath = "thumbnail_path"
        case isSystem = "is_system"
    }
}

struct TaskStatus: Codable {
    let taskId: String
    let status: String
    let progress: Int
    let resultUrl: String?
    let errorMessage: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case status, progress
        case resultUrl = "result_url"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateProjectRequest: Codable {
    let projectName: String
    let modelId: Int?
    
    enum CodingKeys: String, CodingKey {
        case projectName = "project_name"
        case modelId = "model_id"
    }
}

struct ApplyPatternRequest: Codable {
    let patternId: Int
    let fabricTexture: String?
    let colorHex: String
    
    enum CodingKeys: String, CodingKey {
        case patternId = "pattern_id"
        case fabricTexture = "fabric_texture"
        case colorHex = "color_hex"
    }
}

// MARK: - 设计服务专用响应模型
struct ApplyPatternResponse: Codable {
    let message: String
    let designPatternId: Int?
    
    enum CodingKeys: String, CodingKey {
        case message
        case designPatternId = "design_pattern_id"
    }
}

struct GeneratePreviewResponse: Codable {
    let message: String
    let taskId: String
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case message
        case taskId = "task_id"
        case status
    }
}

struct PatternCategoriesResponse: Codable {
    let categories: [String]
}

// MARK: - 设计生成请求模型
struct DesignGenerateRequest: Codable {
    let garment_type: String  // shirt, pants, dress
    let fabric_color: [Int]   // RGB 颜色数组
}

// MARK: - 设计生成响应模型
struct DesignGenerateResponse: Codable {
    let success: Bool
    let message: String
    let garment_type: String
    let fabric_color: [Int]
    let file_path: String
    let file_size: Int
    let download_url: String
    let blender_output: String
}

// MARK: - 设计服务
class DesignService: ObservableObject {
    private let networkService = NetworkService.shared
    
    // MARK: - 项目管理
    
    /// 创建新的设计项目
    func createProject(name: String, modelId: Int?) -> AnyPublisher<DesignProject, Error> {
        return Future { promise in
            Task {
                do {
                    print("🌐 开始网络请求创建项目...")
                    let token = UserDefaults.standard.string(forKey: "token") ?? ""
                    print("🔑 Token: \(token.isEmpty ? "空" : "已获取(\(token.prefix(10))...)")")
                    
                    let parameters: [String: Any] = [
                        "project_name": name,
                        "model_id": modelId as Any
                    ]
                    print("📦 请求参数: \(parameters)")
                    
                    if let result = try await self.networkService.makePostRequest(
                        to: "/v1/design/projects",
                        body: parameters,
                        token: token,
                        responseType: DesignProject.self
                    ) {
                        print("🎉 API响应成功: \(result)")
                        promise(.success(result))
                    } else {
                        print("❌ API响应为空")
                        promise(.failure(NetworkError.invalidResponse))
                    }
                } catch {
                    print("💥 网络请求异常: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取用户的所有设计项目
    func getUserProjects() -> AnyPublisher<[DesignProject], Error> {
        return Future { promise in
            Task {
                do {
                    let token = UserDefaults.standard.string(forKey: "token") ?? ""
                    
                    if let result = try await self.networkService.makeGetRequest(
                        to: "/v1/design/projects",
                        token: token,
                        responseType: [DesignProject].self
                    ) {
                        promise(.success(result))
                    } else {
                        promise(.failure(NetworkError.invalidResponse))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取项目详情
    func getProjectDetail(projectId: Int) -> AnyPublisher<DesignProject, Error> {
        return Future { promise in
            Task {
                do {
                    let token = UserDefaults.standard.string(forKey: "token") ?? ""
                    
                    if let result = try await self.networkService.makeGetRequest(
                        to: "/v1/design/projects/\(projectId)",
                        token: token,
                        responseType: DesignProject.self
                    ) {
                        promise(.success(result))
                    } else {
                        promise(.failure(NetworkError.invalidResponse))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 删除项目
    func deleteProject(projectId: Int) -> AnyPublisher<Bool, Error> {
        return Future { promise in
            Task {
                do {
                    let token = UserDefaults.standard.string(forKey: "token") ?? ""
                    
                    let url = URL(string: "https://yiguiapp.xyz/api/v1/design/projects/\(projectId)")!
                    var request = URLRequest(url: url)
                    request.httpMethod = "DELETE"
                    request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    let (_, response) = try await URLSession.shared.data(for: request)
                    
                    if let httpResponse = response as? HTTPURLResponse,
                       httpResponse.statusCode == 200 {
                        promise(.success(true))
                    } else {
                        promise(.failure(NetworkError.invalidResponse))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 纸样管理
    
    /// 获取纸样库
    func getPatterns(category: String? = nil) -> AnyPublisher<[Pattern], Error> {
        return Future { promise in
            Task {
                do {
                    var endpoint = "/v1/design/patterns"
                    if let category = category {
                        endpoint += "?category=\(category)"
                    }
                    
                    if let result = try await self.networkService.makeGetRequest(
                        to: endpoint,
                        responseType: [Pattern].self
                    ) {
                        promise(.success(result))
                    } else {
                        promise(.failure(NetworkError.invalidResponse))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取纸样分类
    func getPatternCategories() -> AnyPublisher<[String], Error> {
        return Future { promise in
            Task {
                do {
                    if let result = try await self.networkService.makeGetRequest(
                        to: "/v1/design/patterns/categories",
                        responseType: PatternCategoriesResponse.self
                    ) {
                        promise(.success(result.categories))
                    } else {
                        promise(.failure(NetworkError.invalidResponse))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    // MARK: - 设计应用
    
    /// 应用纸样到项目
    func applyPatternToProject(
        projectId: Int,
        patternId: Int,
        fabricTexture: String? = "cotton",
        colorHex: String = "#FFFFFF"
    ) -> AnyPublisher<Bool, Error> {
        return Future { promise in
            Task {
                do {
                    let token = UserDefaults.standard.string(forKey: "token") ?? ""
                    
                    let parameters: [String: Any] = [
                        "pattern_id": patternId,
                        "fabric_texture": fabricTexture as Any,
                        "color_hex": colorHex
                    ]
                    
                    if let _ = try await self.networkService.makePostRequest(
                        to: "/v1/design/projects/\(projectId)/apply-pattern",
                        body: parameters,
                        token: token,
                        responseType: ApplyPatternResponse.self
                    ) {
                        promise(.success(true))
                    } else {
                        promise(.failure(NetworkError.invalidResponse))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 生成3D预览
    func generate3DPreview(projectId: Int) -> AnyPublisher<TaskStatus, Error> {
        return Future { promise in
            Task {
                do {
                    let token = UserDefaults.standard.string(forKey: "token") ?? ""
                    
                    if let result = try await self.networkService.makePostRequest(
                        to: "/v1/design/projects/\(projectId)/generate-preview",
                        body: [:],
                        token: token,
                        responseType: GeneratePreviewResponse.self
                    ) {
                        let taskStatus = TaskStatus(
                            taskId: result.taskId,
                            status: result.status,
                            progress: 0,
                            resultUrl: nil,
                            errorMessage: nil,
                            createdAt: "",
                            updatedAt: ""
                        )
                        promise(.success(taskStatus))
                    } else {
                        promise(.failure(NetworkError.invalidResponse))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 获取任务状态
    func getTaskStatus(taskId: String) -> AnyPublisher<TaskStatus, Error> {
        return Future { promise in
            Task {
                do {
                    let token = UserDefaults.standard.string(forKey: "token") ?? ""
                    
                    if let result = try await self.networkService.makeGetRequest(
                        to: "/v1/design/tasks/\(taskId)",
                        token: token,
                        responseType: TaskStatus.self
                    ) {
                        promise(.success(result))
                    } else {
                        promise(.failure(NetworkError.invalidResponse))
                    }
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    /// 轮询任务状态直到完成
    func pollTaskStatus(taskId: String) -> AnyPublisher<TaskStatus, Error> {
        return Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .flatMap { _ in
                self.getTaskStatus(taskId: taskId)
            }
            .first { taskStatus in
                taskStatus.status == "completed" || taskStatus.status == "failed"
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - 设计生成
    
    // 设计服务器的基础URL
    private let designBaseURL = "http://150.109.41.198:8002"
    
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120  // 增加超时时间，因为3D生成需要时间
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }()
    
    // 生成3D服装模型
    func generate3DClothing(garmentType: String, fabricColor: [Int]) async throws -> DesignGenerateResponse {
        let endpoint = "/api/v1/design/generate"
        
        guard let url = URL(string: designBaseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        let request = DesignGenerateRequest(
            garment_type: garmentType,
            fabric_color: fabricColor
        )
        
        print("🎨 开始生成3D服装: 类型=\(garmentType), 颜色=\(fabricColor)")
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await urlSession.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            

            
            if httpResponse.statusCode == 200 {
                let generateResponse = try JSONDecoder().decode(DesignGenerateResponse.self, from: data)
                print("✅ 3D服装生成成功: \(generateResponse.message)")
                print("📁 文件大小: \(generateResponse.file_size) bytes")
                print("🔗 下载链接: \(generateResponse.download_url)")
                return generateResponse
            } else {
                // 处理错误响应
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                print("❌ 设计服务器错误: \(errorMessage)")
                throw NetworkError.serverError("3D生成失败: \(errorMessage)")
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ 3D生成请求失败: \(error.localizedDescription)")
            throw NetworkError.requestFailed(error)
        }
    }
    
    // 下载生成的3D模型文件
    func download3DModel(from downloadURL: String) async throws -> Data {
        guard let url = URL(string: designBaseURL + downloadURL) else {
            throw NetworkError.invalidURL
        }
        
        print("⬇️ 开始下载3D模型: \(url.absoluteString)")
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ 3D模型下载成功，大小: \(data.count) bytes")
                return data
            } else {
                throw NetworkError.serverError("下载失败，状态码: \(httpResponse.statusCode)")
            }
        } catch {
            print("❌ 3D模型下载失败: \(error.localizedDescription)")
            throw NetworkError.requestFailed(error)
        }
    }
    
    // 保存3D模型文件到本地
    func save3DModel(data: Data, filename: String) throws -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        try data.write(to: fileURL)
        print("💾 3D模型已保存到: \(fileURL.path)")
        
        return fileURL
    }
    
    // 检查本地是否已有3D模型文件
    func localModelExists(filename: String) -> Bool {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    // 获取本地3D模型文件URL
    func getLocalModelURL(filename: String) -> URL? {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(filename)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        return nil
    }
    
    // 一步式生成并下载3D服装模型
    func generateAndDownload3DClothing(garmentType: String, fabricColor: [Int]) async throws -> URL {
        // 第一步：生成3D模型
        let generateResponse = try await generate3DClothing(garmentType: garmentType, fabricColor: fabricColor)
        
        // 第二步：下载模型数据
        let modelData = try await download3DModel(from: generateResponse.download_url)
        
        // 第三步：保存到本地
        let filename = "\(garmentType)_\(Date().timeIntervalSince1970).glb"
        let localURL = try save3DModel(data: modelData, filename: filename)
        
        return localURL
    }
} 