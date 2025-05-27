import Foundation
import Combine
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var error: String?
    
    // 邮箱登录注册相关属性
    @Published var email = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    @Published var nickname = ""
    @Published var verificationCode = ""
    @Published var isEmailValid = true
    @Published var isPasswordValid = true
    @Published var isConfirmPasswordValid = true
    @Published var verificationCodeSent = false
    @Published var canResendCode = true
    @Published var resendCountdown = 0
    
    // 用户信息
    @Published var height: String = ""
    @Published var weight: String = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let networkService = NetworkService.shared
    
    // MARK: - 邮箱登录注册功能
    
    // 发送邮箱验证码（第一步注册）
    func sendVerificationCode() {
        guard validateEmail() && validatePassword() else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let response = try await networkService.emailRegister(email: email, password: password)
                
                await MainActor.run {
                    self.verificationCodeSent = true
                    self.startResendCountdown()
                    self.isLoading = false
                    print("✅ 验证码发送成功: \(response.message)")
                }
            } catch let networkError as NetworkError {
                await MainActor.run {
                    self.error = networkError.localizedDescription
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "发送验证码失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // 邮箱注册（第二步验证）
    func emailRegister() {
        guard validateRegistrationInput() else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                // 先验证验证码
                let verifyResponse = try await networkService.verifyEmailCode(
                    email: email,
                    code: verificationCode
                )
                
                print("✅ 验证成功: \(verifyResponse.message)")
                
                // 验证成功后直接登录
                let loginResponse = try await networkService.emailLogin(
                    email: email,
                    password: password
                )
                
                // 保存token
                UserDefaults.standard.set(loginResponse.token, forKey: "token")
                
                // 获取用户信息
                await fetchUserInfo(token: loginResponse.token)
                
                // 更新UI状态
                await MainActor.run {
                    self.isLoggedIn = true
                    self.isLoading = false
                    print("✅ 注册并登录成功: \(loginResponse.message)")
                }
            } catch let networkError as NetworkError {
                await MainActor.run {
                    self.error = networkError.localizedDescription
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "注册失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // 邮箱登录
    func emailLogin() {
        guard validateLoginInput() else { return }
        
        isLoading = true
        error = nil
        
        Task {
            do {
                let response = try await networkService.emailLogin(
                    email: email,
                    password: password
                )
                
                // 保存token
                UserDefaults.standard.set(response.token, forKey: "token")
                
                // 获取用户信息
                await fetchUserInfo(token: response.token)
                
                // 更新UI状态
                await MainActor.run {
                    self.isLoggedIn = true
                    self.isLoading = false
                    print("✅ 登录成功: \(response.message)")
                }
            } catch let networkError as NetworkError {
                await MainActor.run {
                    self.error = networkError.localizedDescription
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "登录失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    // MARK: - 输入验证
    
    private func validateEmail() -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        isEmailValid = emailPredicate.evaluate(with: email)
        if !isEmailValid {
            error = "请输入有效的邮箱地址"
        }
        return isEmailValid
    }
    
    private func validatePassword() -> Bool {
        isPasswordValid = password.count >= 6
        if !isPasswordValid {
            error = "密码长度至少6位"
        }
        return isPasswordValid
    }
    
    private func validateConfirmPassword() -> Bool {
        isConfirmPasswordValid = password == confirmPassword
        if !isConfirmPasswordValid {
            error = "两次输入的密码不一致"
        }
        return isConfirmPasswordValid
    }
    
    private func validateLoginInput() -> Bool {
        error = nil
        return validateEmail() && validatePassword()
    }
    
    private func validateRegistrationInput() -> Bool {
        error = nil
        guard validateEmail() && validatePassword() && validateConfirmPassword() else {
            return false
        }
        
        if verificationCode.isEmpty {
            error = "请输入验证码"
            return false
        }
        
        if verificationCode.count != 6 {
            error = "验证码应为6位数字"
            return false
        }
        
        return true
    }
    
    // MARK: - 验证码倒计时
    
    private func startResendCountdown() {
        canResendCode = false
        resendCountdown = 60
        
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            DispatchQueue.main.async {
                self.resendCountdown -= 1
                if self.resendCountdown <= 0 {
                    self.canResendCode = true
                    timer.invalidate()
                }
            }
        }
    }
    
    // 清空表单
    func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        nickname = ""
        verificationCode = ""
        error = nil
        verificationCodeSent = false
        canResendCode = true
        resendCountdown = 0
    }
    

    
    // 获取用户信息
    private func fetchUserInfo(token: String) async {
        do {
            let userResponse = try await networkService.getCurrentUser(token: token)
            
            await MainActor.run {
                // 创建用户对象，使用服务器返回的邮箱和昵称
                var avatarURL: URL? = nil
                if let avatarURLString = userResponse.avatarURL {
                    avatarURL = URL(string: avatarURLString)
                }
                
                // 优先使用服务器返回的信息，如果为nil则使用本地输入的信息
                let userEmail = userResponse.email.isEmpty ? self.email : userResponse.email
                let userNickname = userResponse.nickname ?? (self.nickname.isEmpty ? "用户\(Int.random(in: 1000...9999))" : self.nickname)
                
                self.user = User(
                    email: userEmail,
                    nickname: userNickname,
                    height: userResponse.height,
                    weight: userResponse.weight,
                    avatarURL: avatarURL
                )
                
                // 同步本地变量
                self.email = userEmail
                self.nickname = userNickname
                
                // 保存用户状态
                self.saveUserState()
            }
        } catch {
            print("获取用户信息失败: \(error.localizedDescription)")
            // 即使获取用户信息失败，我们也创建一个基础用户对象
            await MainActor.run {
                self.user = User(
                    email: self.email,
                    nickname: self.nickname.isEmpty ? "用户\(Int.random(in: 1000...9999))" : self.nickname,
                    height: nil,
                    weight: nil,
                    avatarURL: nil
                )
                self.saveUserState()
            }
        }
    }
    
    // 更新用户信息
    func updateUserInfo() {
        guard var user = user else { return }
        
        // 更新昵称
        if !nickname.isEmpty {
            user.nickname = nickname
        }
        
        // 更新身高
        if let heightValue = Int(height), heightValue > 0 {
            user.height = heightValue
        }
        
        // 更新体重
        if let weightValue = Int(weight), weightValue > 0 {
            user.weight = weightValue
        }
        
        self.user = user
        saveUserState()
    }
    
    // 退出登录
    func logout() {
        user = nil
        isLoggedIn = false
        
        // 清除持久化数据
        UserDefaults.standard.removeObject(forKey: "user")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "token")
        UserDefaults.standard.removeObject(forKey: "isDevelopmentMode")
    }
    
    // 保存用户状态
    private func saveUserState() {
        if let encodedUser = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encodedUser, forKey: "user")
        }
        UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
    }
    
    // 加载用户状态
    func loadUserState() {
        // 先从本地加载缓存的用户数据
        if let userData = UserDefaults.standard.data(forKey: "user") {
            do {
                let decodedUser = try JSONDecoder().decode(User.self, from: userData)
                self.user = decodedUser
                self.isLoggedIn = true
            } catch {
                print("解析用户数据失败: \(error.localizedDescription)")
                // 清除无效的用户数据
                UserDefaults.standard.removeObject(forKey: "user")
            }
        }
        
        // 如果有token，尝试从服务器刷新用户数据
        if let token = UserDefaults.standard.string(forKey: "token") {
            Task {
                await fetchUserInfo(token: token)
                
                await MainActor.run {
                    self.isLoggedIn = true
                }
            }
        }
    }
    
    // 跳过登录，直接进入app（开发期间使用）
    func skipLoginForDevelopment() {
        // 创建一个临时用户对象
        let temporaryUser = User(
            email: "developer@local.com",
            nickname: "开发用户",
            height: 170,
            weight: 60,
            avatarURL: nil
        )
        
        self.user = temporaryUser
        self.isLoggedIn = true
        
        // 设置本地标记，表明这是开发模式
        UserDefaults.standard.set(true, forKey: "isDevelopmentMode")
        
        print("🛠️ 开发模式：跳过登录，直接进入app")
    }
} 
