import Foundation

enum NetworkError: Error {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed(Error)
    case serverError(String)
    case unauthorized
    case invalidToken
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .requestFailed(let error):
            return "请求失败: \(error.localizedDescription)"
        case .invalidResponse:
            return "服务器返回了无效的响应"
        case .decodingFailed(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .serverError(let message):
            return message
        case .unauthorized:
            return "未授权，请重新登录"
        case .invalidToken:
            return "无效的token"
        }
    }
}

// SSL委托类，用于处理证书验证
class SSLPinningDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 对于开发阶段，接受所有证书
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

class NetworkService {
    static let shared = NetworkService()
    
    private let baseURL = "https://yiguiapp.xyz/api"
    
    // 创建自定义URL会话，配置SSL处理
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration, delegate: SSLPinningDelegate(), delegateQueue: nil)
        return session
    }()
    
    private init() {}
    
    // MARK: - 邮箱注册与登录相关接口
    
    // 邮箱注册（第一步：发送验证码）
    func emailRegister(email: String, password: String, nickname: String, gender: String = "male") async throws -> MessageResponse {
        let endpoint = "/register"
        
        let parameters: [String: Any] = [
            "email": email,
            "password": password,
            "nickname": nickname,
            "gender": gender
        ]
        
        guard let response = try await makePostRequest(to: endpoint, body: parameters, responseType: MessageResponse.self) else {
            throw NetworkError.invalidResponse
        }
        
        return response
    }
    
    // 验证邮箱验证码（第二步：验证并完成注册）
    func verifyEmailCode(email: String, code: String) async throws -> MessageResponse {
        let endpoint = "/verify"
        
        let parameters: [String: Any] = [
            "email": email,
            "code": code
        ]
        
        guard let response = try await makePostRequest(to: endpoint, body: parameters, responseType: MessageResponse.self) else {
            throw NetworkError.invalidResponse
        }
        
        return response
    }
    
    // 邮箱登录
    func emailLogin(email: String, password: String) async throws -> AuthResponse {
        let endpoint = "/login"
        
        let parameters: [String: Any] = [
            "email": email,
            "password": password
        ]
        
        guard let response = try await makePostRequest(to: endpoint, body: parameters, responseType: AuthResponse.self) else {
            throw NetworkError.invalidResponse
        }
        
        return response
    }
    
    // 获取当前用户信息（调用服务器的user_info接口）
    func getCurrentUser(token: String) async throws -> UserResponse {
        let endpoint = "/user_info"
        
        // 先尝试从服务器获取用户信息
        do {
            var urlComponents = URLComponents(string: baseURL + endpoint)!
            urlComponents.queryItems = [URLQueryItem(name: "token", value: token)]
            
            guard let url = urlComponents.url else {
                throw NetworkError.invalidURL
            }
            
    
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            print("📡 响应状态码: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                // 解析服务器返回的用户信息
                let serverUserInfo = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
                
                let email = serverUserInfo?["email"] as? String ?? "user@example.com"
                let nickname = serverUserInfo?["nickname"] as? String
                let height = serverUserInfo?["height"] as? Int
                let weight = serverUserInfo?["weight"] as? Int
                let avatarURL = serverUserInfo?["avatar_url"] as? String
                let gender = serverUserInfo?["gender"] as? String ?? "male"
                

                
                return UserResponse(
                    email: email,
                    nickname: nickname,
                    height: height,
                    weight: weight,
                    avatarURL: avatarURL,
                    gender: gender
                )
            } else {
                throw NetworkError.serverError("获取用户信息失败")
            }
        } catch {

            
            // 如果服务器请求失败，回退到从token解析
            let parts = token.components(separatedBy: ".")
            if parts.count == 3 {
                // 确保正确解码base64（可能需要补充填充）
                var payload = parts[1]
                // 添加必要的填充
                while payload.count % 4 != 0 {
                    payload += "="
                }
                
                if let payloadData = Data(base64Encoded: payload) {
                    do {
                        let payloadObject = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any]
                        let email = payloadObject?["email"] as? String ?? "user@example.com"
                        let nickname = payloadObject?["nickname"] as? String
                        let gender = payloadObject?["gender"] as? String ?? "male"
                        
                        print("📋 从token解析用户信息: email=\(email), nickname=\(nickname ?? "nil"), gender=\(gender)")
                        
                        return UserResponse(
                            email: email,
                            nickname: nickname,
                            height: nil,
                            weight: nil,
                            avatarURL: nil,
                            gender: gender
                        )
                    } catch {
                        print("解析token失败: \(error)")
                        throw NetworkError.invalidToken
                    }
                }
            }
            
            print("⚠️ 无法解析token，返回默认用户信息")
            // 返回默认用户信息
            return UserResponse(
                email: "user@example.com",
                nickname: nil,
                height: nil,
                weight: nil,
                avatarURL: nil,
                gender: "male"
            )
        }
    }
    
    // 更新用户信息
    func updateUserInfo(token: String, height: Int?, weight: Int?, avatarURL: String?, gender: String? = nil, nickname: String? = nil) async throws -> UpdateUserInfoResponse {
        let endpoint = "/update_user_info"
        
        var parameters: [String: Any] = [
            "token": token
        ]
        
        if let height = height {
            parameters["height"] = height
        }
        
        if let weight = weight {
            parameters["weight"] = weight
        }
        
        if let avatarURL = avatarURL {
            parameters["avatar_url"] = avatarURL
        }
        
        if let gender = gender {
            parameters["gender"] = gender
        }
        
        if let nickname = nickname {
            parameters["nickname"] = nickname
        }
        
        print("🌐 准备发送用户信息更新请求到: \(baseURL)\(endpoint)")
        print("📤 请求参数:")
        for (key, value) in parameters {
            if key == "avatar_url" {
                print("   - \(key): \(value is String ? "头像数据" : value)")
            } else {
                print("   - \(key): \(value)")
            }
        }
        
        guard let response = try await makePostRequest(to: endpoint, body: parameters, responseType: UpdateUserInfoResponse.self) else {
            throw NetworkError.invalidResponse
        }
        
        print("✅ 用户信息更新请求成功: \(response.message)")
        
        // 如果服务器返回了新token，更新本地存储的token
        if let newToken = response.new_token {
            UserDefaults.standard.set(newToken, forKey: "token")
            print("🔄 收到新token，已更新本地存储")
        }
        
        return response
    }
    
    // MARK: - 公共方法，供其他服务使用
    
    // 通用POST请求方法
    func makePostRequest<T: Decodable>(to endpoint: String, body: [String: Any], token: String? = nil, responseType: T.Type) async throws -> T? {
        return try await performPostRequest(endpoint: endpoint, body: body, token: token, responseType: responseType)
    }
    
    // 通用GET请求方法
    func makeGetRequest<T: Decodable>(to endpoint: String, token: String? = nil, responseType: T.Type) async throws -> T? {
        return try await performGetRequest(endpoint: endpoint, token: token, responseType: responseType)
    }
    
    // 实际执行POST请求的方法
    func performPostRequest<T: Decodable>(endpoint: String, body: [String: Any], token: String? = nil, responseType: T.Type) async throws -> T? {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // 处理HTTP错误
            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized
            } else if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                // 尝试解析服务器返回的错误信息
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                print("❌ 服务器错误详情: \(errorMessage)")
                
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    // 特殊处理邮箱已注册的情况
                    if errorResponse.message.contains("已注册") || errorResponse.message.contains("already") || errorResponse.message.contains("exists") {
                        throw NetworkError.serverError("该邮箱已注册，请直接登录")
                    } else {
                        throw NetworkError.serverError(errorResponse.message)
                    }
                } else {
                    // 检查原始错误信息是否包含已注册相关内容
                    if errorMessage.contains("已注册") || errorMessage.contains("already") || errorMessage.contains("exists") {
                        throw NetworkError.serverError("该邮箱已注册，请直接登录")
                    } else {
                        throw NetworkError.serverError("发送验证码失败：\(errorMessage)")
                    }
                }
            }
            
            // 如果是EmptyResponse类型，直接返回空对象
            if T.self == EmptyResponse.self {
                return EmptyResponse() as? T
            }
            
            // 解析响应
            let decoder = JSONDecoder()
            return try decoder.decode(responseType, from: data)
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ 网络请求失败: \(error.localizedDescription)")
            throw NetworkError.requestFailed(error)
        }
    }
    
    // 实际执行GET请求的方法
    func performGetRequest<T: Decodable>(endpoint: String, token: String? = nil, responseType: T.Type) async throws -> T? {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // 处理HTTP错误
            if httpResponse.statusCode == 401 {
                throw NetworkError.unauthorized
            } else if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
                // 尝试解析服务器返回的错误信息
                let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
                print("❌ 服务器错误详情: \(errorMessage)")
                
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.serverError(errorResponse.message)
                } else {
                    throw NetworkError.serverError("请求失败：\(errorMessage)")
                }
            }
            
            // 解析响应
            let decoder = JSONDecoder()
            return try decoder.decode(responseType, from: data)
        } catch let error as NetworkError {
            throw error
        } catch {
            print("❌ 网络请求失败: \(error.localizedDescription)")
            throw NetworkError.requestFailed(error)
        }
    }
}

// 响应模型
struct AuthResponse: Codable {
    let token: String
    let message: String
}

struct UserResponse: Codable {
    let email: String
    let nickname: String?
    let height: Int?
    let weight: Int?
    let avatarURL: String?
    let gender: String
}

struct MessageResponse: Codable {
    let message: String
}

// 更新用户信息响应模型（支持新token）
struct UpdateUserInfoResponse: Codable {
    let message: String
    let new_token: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case new_token
    }
}

struct ErrorResponse: Codable {
    let message: String
}

// 用于空响应的占位符
struct EmptyResponse: Codable {} 