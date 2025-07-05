import Foundation
import Combine
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var error: String?
    @Published var isNewUser = false
    
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
    @Published var gender: String = "male"  // 添加性别属性
    @Published var avatarData: Data? // 存储头像数据
    
    // 发布用户信息更新通知
    let userInfoUpdated = PassthroughSubject<Void, Never>()
    
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
                // 注册时使用默认昵称，昵称将在信息完善页面输入
                let defaultNickname = "用户\(Int.random(in: 1000...9999))"
                // 注册时使用默认性别，性别将在信息完善页面选择
                let response = try await networkService.emailRegister(email: email, password: password, nickname: defaultNickname, gender: "male")
                
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
                    // 🚀 清除之前用户的缓存
                    ModelCacheService.shared.clearCache()
                    print("🗑️ 已清除上一个用户的缓存")
                    
                    self.isNewUser = true // 标记为新注册用户
                    self.isLoggedIn = true
                    self.isLoading = false
                    print("✅ 注册并登录成功: \(loginResponse.message)")
                    print("🔄 设置isNewUser = true，用户可以在信息完善页面更新性别和昵称")
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
                    // 🚀 清除之前用户的缓存
                    ModelCacheService.shared.clearCache()
                    print("🗑️ 已清除上一个用户的缓存")
                    
                    self.isNewUser = false // 标记为已存在用户
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
    
    private func validateNickname() -> Bool {
        if nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = "昵称不能为空"
            return false
        }
        
        if nickname.count < 2 {
            error = "昵称长度至少2位"
            return false
        }
        
        if nickname.count > 20 {
            error = "昵称长度不能超过20位"
            return false
        }
        
        return true
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
                if let avatarURLString = userResponse.avatarURL, !avatarURLString.isEmpty {
                    avatarURL = URL(string: avatarURLString)
                    print("🖼️ 从服务器获取头像URL: \(avatarURLString)")
                }
                
                // 优先使用服务器返回的信息，如果为nil则使用本地输入的信息
                let userEmail = userResponse.email.isEmpty ? self.email : userResponse.email
                let userNickname = userResponse.nickname ?? (self.nickname.isEmpty ? "用户\(Int.random(in: 1000...9999))" : self.nickname)
                
                // 对于性别，如果是新用户且本地有设置，优先使用本地设置；否则使用服务器返回的值
                let userGender = (self.isNewUser && !self.gender.isEmpty) ? self.gender : userResponse.gender
                
                self.user = User(
                    email: userEmail,
                    nickname: userNickname,
                    height: userResponse.height,
                    weight: userResponse.weight,
                    avatarURL: avatarURL,
                    gender: userGender
                )
                
                // 同步本地变量
                self.email = userEmail
                self.nickname = userNickname
                self.gender = userGender
                
                // 同步身高体重到字符串变量 - 只有当服务器有数据时才更新，否则保持本地输入的值
                if let height = userResponse.height {
                    self.height = "\(height)"
                } else if self.isNewUser && !self.height.isEmpty {
                    // 新用户且本地有输入值，保持本地值不变
                    print("🔄 保持新用户本地身高输入: \(self.height)")
                }
                
                if let weight = userResponse.weight {
                    self.weight = "\(weight)"
                } else if self.isNewUser && !self.weight.isEmpty {
                    // 新用户且本地有输入值，保持本地值不变
                    print("🔄 保持新用户本地体重输入: \(self.weight)")
                }
                
                // 保存用户状态
                self.saveUserState()
                
                print("📋 用户信息已加载: email=\(userEmail), nickname=\(userNickname), gender=\(userGender), height=\(userResponse.height ?? 0), weight=\(userResponse.weight ?? 0)")
                print("📋 本地字符串变量: height='\(self.height)', weight='\(self.weight)', gender='\(self.gender)'")
                
                // 发送用户信息更新通知
                self.userInfoUpdated.send()
            }
        } catch {
            print("⚠️ 获取用户信息失败: \(error.localizedDescription)")
            // 即使获取用户信息失败，我们也创建一个基础用户对象
            await MainActor.run {
                // 对于新用户，使用本地设置的性别；对于已有用户，使用默认值
                let fallbackGender = self.isNewUser ? self.gender : "male"
                
                self.user = User(
                    email: self.email,
                    nickname: self.nickname.isEmpty ? "用户\(Int.random(in: 1000...9999))" : self.nickname,
                    height: nil,
                    weight: nil,
                    avatarURL: nil,
                    gender: fallbackGender
                )
                self.saveUserState()
                
                print("📋 使用本地信息创建用户对象: email=\(self.email), nickname=\(self.nickname), gender=\(fallbackGender)")
            }
        }
    }
    
    // 更新用户信息
    func updateUserInfo() async {
        guard let currentUser = user else { 
            print("❌ 更新用户信息失败：用户对象为空")
            return 
        }
        
        // 创建用户的本地副本以避免并发访问问题
        var user = currentUser
        guard let token = UserDefaults.standard.string(forKey: "token") else { 
            print("❌ 更新用户信息失败：token为空")
            return 
        }
        
        print("🔄 开始更新用户信息 - isNewUser: \(isNewUser)")
        print("🔄 当前用户信息 - 昵称: \(user.nickname), 性别: \(user.gender)")
        print("🔄 表单数据 - 昵称: '\(nickname)', 性别: '\(gender)', 身高: '\(height)', 体重: '\(weight)'")
        print("🔄 Token: \(token.prefix(50))...")
        
        await MainActor.run {
            self.isLoading = true
            self.error = nil
        }
        
        do {
            // 更新本地用户对象
            if let heightValue = Int(height), heightValue > 0 {
                user.height = heightValue
                print("🔄 设置身高: \(heightValue)")
            } else {
                print("⚠️ 身高无效或为空: '\(height)'")
            }
            
            if let weightValue = Int(weight), weightValue > 0 {
                user.weight = weightValue
                print("🔄 设置体重: \(weightValue)")
            } else {
                print("⚠️ 体重无效或为空: '\(weight)'")
            }
            
            // 对于新注册用户，允许更新性别和昵称；对于已有用户，保持性别不变
            var shouldUpdateGender = false
            var shouldUpdateNickname = false
            
            if isNewUser {
                user.gender = self.gender
                shouldUpdateGender = true
                print("🔄 设置性别: \(self.gender)")
                
                // 对于新用户，如果输入了昵称则更新昵称
                if !self.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    user.nickname = self.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                    shouldUpdateNickname = true
                    print("🔄 设置昵称: \(user.nickname)")
                }
                print("🔄 更新用户信息（新用户）- 昵称: \(user.nickname), 身高: \(user.height ?? 0), 体重: \(user.weight ?? 0), 性别: \(user.gender)")
            } else {
                print("🔄 更新用户信息（已有用户）- 昵称: \(user.nickname), 身高: \(user.height ?? 0), 体重: \(user.weight ?? 0), 性别: \(user.gender)（保持不变）")
            }
            
            // 准备头像数据
            var avatarURL: String? = nil
            if let avatarBase64 = getAvatarBase64String() {
                // 使用data URI格式存储头像
                avatarURL = "data:image/jpeg;base64,\(avatarBase64)"
                print("📸 准备上传头像，Base64长度: \(avatarBase64.count)")
            }
            
            // 准备发送到服务器的参数
            let genderToSend = shouldUpdateGender ? user.gender : nil
            let nicknameToSend = shouldUpdateNickname ? user.nickname : nil
            
            print("📤 发送到服务器的参数:")
            print("   - height: \(user.height ?? 0)")
            print("   - weight: \(user.weight ?? 0)")
            print("   - gender: \(genderToSend ?? "nil")")
            print("   - nickname: \(nicknameToSend ?? "nil")")
            print("   - avatarURL: \(avatarURL != nil ? "有头像数据" : "无头像数据")")
            print("🌐 即将调用 networkService.updateUserInfo")
            
            // 首先更新基本信息（身高、体重、性别、昵称），不包含头像
            print("🔄 第一步：更新基本用户信息")
            let updateResponse = try await networkService.updateUserInfo(
                token: token,
                height: user.height,
                weight: user.weight,
                avatarURL: nil, // 先不上传头像
                gender: isNewUser ? user.gender : nil,
                nickname: isNewUser ? user.nickname : nil
            )
            
            print("✅ 基本信息更新成功: \(updateResponse.message)")
            if let newToken = updateResponse.new_token {
                print("🔄 收到新token: \(newToken.prefix(50))...")
            }
            
            // 如果有头像数据，单独上传头像
            if let avatarURL = avatarURL {
                print("🔄 第二步：上传头像数据")
                do {
                    let currentToken = updateResponse.new_token ?? token
                    let avatarResponse = try await networkService.updateUserInfo(
                        token: currentToken,
                        height: nil,
                        weight: nil,
                        avatarURL: avatarURL,
                        gender: nil,
                        nickname: nil
                    )
                    print("✅ 头像上传成功: \(avatarResponse.message)")
                } catch {
                    print("⚠️ 头像上传失败，但基本信息已保存: \(error.localizedDescription)")
                    // 头像上传失败不影响基本信息的保存
                }
            }
            
            await MainActor.run {
                // 更新本地用户对象
                // 注意：只有在头像真正上传成功时才更新头像URL，这里先不更新
                // if let avatarURLString = avatarURL {
                //     user.avatarURL = URL(string: avatarURLString)
                // }
                
                self.user = user
                
                // 同步本地字符串变量
                if let height = user.height {
                    self.height = "\(height)"
                }
                if let weight = user.weight {
                    self.weight = "\(weight)"
                }
                
                // 确保gender属性与用户对象保持同步
                self.gender = user.gender
                
                self.saveUserState()
                self.isLoading = false
                print("✅ 用户信息更新成功")
                
                // 发送用户信息更新通知
                self.userInfoUpdated.send()
                
                // 如果收到了新token，立即使用新token重新获取用户信息以确保同步
                if updateResponse.new_token != nil {
                    print("🔄 收到新token，但跳过重新获取用户信息以避免覆盖刚更新的数据")
                    // 注释掉重新获取用户信息的逻辑，因为我们刚刚更新了数据，不需要再从服务器获取
                    // Task {
                    //     await self.fetchUserInfo(token: newToken)
                    // }
                } else if self.isNewUser {
                    // 如果是新用户但没有收到新token，也不需要重新获取用户信息
                    print("🔄 新用户信息更新完成，数据已是最新状态")
                    // 注释掉重新获取用户信息的逻辑
                    // Task {
                    //     // 获取最新的token（可能已经被NetworkService更新了）
                    //     let currentToken = UserDefaults.standard.string(forKey: "token") ?? token
                    //     await self.fetchUserInfo(token: currentToken)
                    // }
                }
            }
        } catch {
            await MainActor.run {
                self.error = "更新用户信息失败: \(error.localizedDescription)"
                self.isLoading = false
                
                print("❌ 服务器更新失败: \(error.localizedDescription)")
                print("❌ 错误详情: \(error)")
                
                // 即使服务器更新失败，也更新本地状态
                self.user = user
                
                // 同步本地字符串变量
                if let height = user.height {
                    self.height = "\(height)"
                }
                if let weight = user.weight {
                    self.weight = "\(weight)"
                }
                
                // 确保gender属性与用户对象保持同步
                self.gender = user.gender
                
                self.saveUserState()
                
                // 发送用户信息更新通知（即使服务器更新失败，本地状态已更新）
                self.userInfoUpdated.send()
                
                print("⚠️ 服务器更新失败，但本地状态已更新")
            }
        }
    }
    
    // 退出登录
    func logout() {
        print("🚪 开始退出登录流程")
        
        // 🚀 清除模型缓存
        ModelCacheService.shared.clearCache()
        print("🗑️ 模型缓存已清除")
        
        // 清空用户对象和状态
        user = nil
        isLoggedIn = false
        isNewUser = false
        
        // 清空表单数据
        email = ""
        password = ""
        confirmPassword = ""
        nickname = ""
        verificationCode = ""
        height = ""
        weight = ""
        gender = "male"
        avatarData = nil
        error = nil
        
        // 重置验证码相关状态
        verificationCodeSent = false
        canResendCode = true
        resendCountdown = 0
        
        // 清除持久化数据
        UserDefaults.standard.removeObject(forKey: "user")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        UserDefaults.standard.removeObject(forKey: "token")
        
        print("✅ 退出登录完成，所有数据已清理")
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
                
                // 检查是否是刚注册的新用户（通过检查用户信息是否完整来判断）
                let hasCompleteInfo = decodedUser.height != nil && decodedUser.weight != nil
                self.isNewUser = !hasCompleteInfo // 如果信息不完整，说明是新用户
                
                // 同步身高体重和性别到字符串变量
                if let height = decodedUser.height {
                    self.height = "\(height)"
                }
                if let weight = decodedUser.weight {
                    self.weight = "\(weight)"
                }
                self.gender = decodedUser.gender  // 同步性别
                self.nickname = decodedUser.nickname // 同步昵称
                self.email = decodedUser.email // 同步邮箱
                
    

            } catch {
                print("解析用户数据失败: \(error.localizedDescription)")
                // 清除无效的用户数据
                UserDefaults.standard.removeObject(forKey: "user")
            }
        }
        
        // 如果有token，尝试从服务器刷新用户数据
        if let token = UserDefaults.standard.string(forKey: "token") {
            print("🔄 检测到token，从服务器刷新用户数据")
            
            // 对于新用户，避免立即刷新数据以免覆盖本地设置
            if !self.isNewUser {
                Task {
                    await fetchUserInfo(token: token)
                    
                    await MainActor.run {
                        self.isLoggedIn = true
                        // 重新检查是否是新用户（基于服务器返回的数据）
                        if let user = self.user {
                            let hasCompleteInfo = user.height != nil && user.weight != nil
                            self.isNewUser = !hasCompleteInfo
                            print("📱 服务器数据加载完成: isNewUser=\(self.isNewUser), hasCompleteInfo=\(hasCompleteInfo)")
                        }
                    }
                }
            } else {
                print("🔄 新用户跳过服务器数据刷新，保持本地设置")
                self.isLoggedIn = true
            }
        }
    }
    
    // MARK: - 头像处理
    
    // 更新头像图片
    func updateAvatarImage(_ uiImage: UIImage) {
        // 首先调整图片尺寸到合理大小
        let maxSize: CGFloat = 512 // 最大尺寸512x512
        let resizedImage = resizeImage(uiImage, to: maxSize)
        
        // 压缩图片以便上传，使用更低的压缩质量
        if let imageData = resizedImage.jpegData(compressionQuality: 0.3) {
            self.avatarData = imageData
            
            // 将图片转换为base64字符串用于存储
            let base64String = imageData.base64EncodedString()
            
            // 如果有用户对象，立即更新其头像URL
            if let currentUser = self.user {
                var user = currentUser  // 创建本地副本
                user.avatarURL = URL(string: "data:image/jpeg;base64,\(base64String)")
                self.user = user
                print("✅ 头像已更新，压缩后大小: \(imageData.count) bytes")
                
                // 发送用户信息更新通知
                self.userInfoUpdated.send()
            }
        }
    }
    
    // 调整图片尺寸的辅助函数
    private func resizeImage(_ image: UIImage, to maxSize: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        // 如果原图已经比目标尺寸小，直接返回原图
        if size.width <= maxSize && size.height <= maxSize {
            return image
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    // 获取头像base64字符串
    private func getAvatarBase64String() -> String? {
        guard let avatarData = avatarData else { return nil }
        return avatarData.base64EncodedString()
    }
} 
