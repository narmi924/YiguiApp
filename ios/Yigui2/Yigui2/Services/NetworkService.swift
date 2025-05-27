import Foundation
import AuthenticationServices

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
    
    // 更新为新的服务器域名
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
    func emailRegister(email: String, password: String) async throws -> MessageResponse {
        let endpoint = "/register"
        
        let parameters: [String: Any] = [
            "email": email,
            "password": password
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
    
    // MARK: - Apple登录（注释掉，但保留代码）
    
    // Apple登录/注册
    /*
    func appleSignIn(userIdentifier: String, email: String?, fullName: PersonNameComponents?) async throws -> AuthResponse {
        let endpoint = "/apple_signin"
        
        var parameters: [String: Any] = [
            "user_identifier": userIdentifier
        ]
        
        if let email = email {
            parameters["email"] = email
        }
        
        if let fullName = fullName {
            var nameDict: [String: String] = [:]
            if let givenName = fullName.givenName {
                nameDict["given_name"] = givenName
            }
            if let familyName = fullName.familyName {
                nameDict["family_name"] = familyName
            }
            if !nameDict.isEmpty {
                parameters["full_name"] = nameDict
            }
        }
        
        guard let response = try await makePostRequest(to: endpoint, body: parameters, responseType: AuthResponse.self) else {
            throw NetworkError.invalidResponse
        }
        
        return response
    }
    */
    
    // 获取当前用户信息（由于服务器没有此端点，返回基础用户信息）
    func getCurrentUser(token: String) async throws -> UserResponse {
        // 由于服务器没有 /me 端点，我们从token中解析用户信息
        // 或者返回一个基础的用户信息
        let parts = token.components(separatedBy: ".")
        if parts.count == 3, let payloadData = Data(base64Encoded: parts[1]) {
            do {
                let payload = try JSONSerialization.jsonObject(with: payloadData, options: []) as? [String: Any]
                let email = payload?["email"] as? String ?? "user@example.com"
                return UserResponse(
                    email: email,
                    nickname: nil,
                    height: nil,
                    weight: nil,
                    avatarURL: nil
                )
            } catch {
                print("解析token失败: \(error)")
                throw NetworkError.invalidToken
            }
        }
        
        // 返回默认用户信息
        return UserResponse(
            email: "user@example.com",
            nickname: nil,
            height: nil,
            weight: nil,
            avatarURL: nil
        )
    }
    
    // 通用POST请求方法
    private func makePostRequest<T: Decodable>(to endpoint: String, body: [String: Any], token: String? = nil, responseType: T.Type) async throws -> T? {
        return try await performPostRequest(endpoint: endpoint, body: body, token: token, responseType: responseType)
    }
    
    // 通用GET请求方法
    private func makeGetRequest<T: Decodable>(to endpoint: String, token: String? = nil, responseType: T.Type) async throws -> T? {
        return try await performGetRequest(endpoint: endpoint, token: token, responseType: responseType)
    }
    
    // 实际执行POST请求的方法
    private func performPostRequest<T: Decodable>(endpoint: String, body: [String: Any], token: String? = nil, responseType: T.Type) async throws -> T? {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        print("🌐 发送HTTPS请求: \(baseURL + endpoint)")
        
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
            
            print("📡 响应状态码: \(httpResponse.statusCode)")
            
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
    private func performGetRequest<T: Decodable>(endpoint: String, token: String? = nil, responseType: T.Type) async throws -> T? {
        guard let url = URL(string: baseURL + endpoint) else {
            throw NetworkError.invalidURL
        }
        
        print("🌐 发送HTTPS请求: \(baseURL + endpoint)")
        
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
            
            print("📡 响应状态码: \(httpResponse.statusCode)")
            
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
}

struct MessageResponse: Codable {
    let message: String
}

struct ErrorResponse: Codable {
    let message: String
}

// 用于空响应的占位符
struct EmptyResponse: Codable {} 