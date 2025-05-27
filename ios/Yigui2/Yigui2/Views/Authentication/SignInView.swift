import SwiftUI
// import AuthenticationServices // 注释掉Apple登录相关导入

struct SignInView: View {
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var authViewModel: AuthViewModel
    @State private var isSignIn = true
    
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 15) {
                    // 应用标题 - 使用特殊样式，只有U是主题色
                    HStack(spacing: 0) {
                        Text("Yig")
                            .font(.custom("Epilogue", size: 48))
                            .foregroundColor(.textPrimary)
                        
                        Text("U")
                            .font(.custom("Epilogue", size: 48))
                            .foregroundColor(.themeColor)
                        
                        Text("i")
                            .font(.custom("Epilogue", size: 48))
                            .foregroundColor(.textPrimary)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 3)
                    .padding(.top, 30)
                    
                    Text("欢迎回来，你的依柜很想你")
                        .font(.custom("MF DianHei", size: 16))
                        .foregroundColor(.textPrimary)
                        .padding(.bottom, 40)
                    
                    // 切换登录/注册说明
                    HStack(spacing: 0) {
                        // 登录说明
                        Button(action: {
                            withAnimation {
                                isSignIn = true
                                authViewModel.clearForm()
                            }
                        }) {
                            Text("登录")
                                .tabLabelStyle(isSelected: isSignIn)
                        }
                        
                        // 注册说明
                        Button(action: {
                            withAnimation {
                                isSignIn = false
                                authViewModel.clearForm()
                            }
                        }) {
                            Text("注册")
                                .tabLabelStyle(isSelected: !isSignIn)
                        }
                    }
                    .frame(width: 200, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.primary, lineWidth: 2)
                    )
                    .padding(.bottom, 30)
                    
                    // 登录或注册表单
                    VStack(spacing: 20) {
                        if isSignIn {
                            loginForm()
                        } else {
                            registerForm()
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // 错误信息
                    if let error = authViewModel.error {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.custom("MF DianHei", size: 14))
                            .padding(.horizontal)
                            .padding(.top, 10)
                    }
                    
                    // 加载状态
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.primary))
                            .scaleEffect(1.5)
                            .padding(.top, 20)
                    }
                    
                    // 开发期间的直接体验按钮
                    Button(action: {
                        skipLogin()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.circle")
                                .foregroundColor(.themeColor)
                            Text("跳过登录，直接体验")
                                .font(.custom("MF DianHei", size: 16))
                                .foregroundColor(.themeColor)
                        }
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.themeColor, lineWidth: 1.5)
                        )
                    }
                    .padding(.horizontal, 50)
                    .padding(.top, 15)
                    
                    Spacer()
                    
                    // 隐私说明
                    VStack(spacing: 5) {
                        Text("使用即表示您同意我们的")
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 5) {
                            Button("用户协议") {
                                // 跳转到用户协议页面
                            }
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(.themeColor)
                            
                            Text("和")
                                .font(.custom("MF DianHei", size: 12))
                                .foregroundColor(.gray)
                            
                            Button("隐私政策") {
                                // 跳转到隐私政策页面
                            }
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(.themeColor)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onReceive(authViewModel.$isLoggedIn) { isLoggedIn in
            if isLoggedIn {
                appStateManager.rootViewState = .defaultInfo
            }
        }
    }
    
    // MARK: - 登录表单
    @ViewBuilder
    private func loginForm() -> some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("邮箱")
                    .inputLabelStyle()
                
                TextField("请输入邮箱", text: $authViewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .inputFieldStyle()
            }
            
            // 密码输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .inputLabelStyle()
                
                SecureField("请输入密码", text: $authViewModel.password)
                    .textContentType(.none)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .inputFieldStyle()
            }
            
            // 登录按钮
            Button(action: {
                authViewModel.emailLogin()
            }) {
                Text("登录")
                    .primaryButtonStyle()
            }
            .disabled(authViewModel.isLoading || authViewModel.email.isEmpty || authViewModel.password.isEmpty)
            .opacity((authViewModel.email.isEmpty || authViewModel.password.isEmpty) ? 0.6 : 1.0)
            .padding(.top, 10)
        }
    }
    
    // MARK: - 注册表单
    @ViewBuilder
    private func registerForm() -> some View {
        VStack(spacing: 16) {
            // 邮箱输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("邮箱")
                    .inputLabelStyle()
                
                TextField("请输入邮箱", text: $authViewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .inputFieldStyle()
            }
            
            // 密码输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("密码")
                    .inputLabelStyle()
                
                SecureField("请输入密码（至少6位）", text: $authViewModel.password)
                    .textContentType(.none)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .inputFieldStyle()
            }
            
            // 确认密码输入框
            VStack(alignment: .leading, spacing: 8) {
                Text("确认密码")
                    .inputLabelStyle()
                
                SecureField("请再次输入密码", text: $authViewModel.confirmPassword)
                    .textContentType(.none)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .inputFieldStyle()
            }
            
            // 昵称输入框（可选）
            VStack(alignment: .leading, spacing: 8) {
                Text("昵称（可选）")
                    .inputLabelStyle()
                
                TextField("请输入昵称", text: $authViewModel.nickname)
                    .inputFieldStyle()
            }
            
            // 发送验证码按钮
            if !authViewModel.verificationCodeSent {
                Button(action: {
                    authViewModel.sendVerificationCode()
                }) {
                    Text("发送验证码")
                        .primaryButtonStyle()
                }
                .disabled(authViewModel.isLoading || !canSendCode())
                .opacity(canSendCode() ? 1.0 : 0.6)
                .padding(.top, 10)
            }
            
            // 验证码输入框
            if authViewModel.verificationCodeSent {
                VStack(alignment: .leading, spacing: 8) {
                    Text("验证码")
                        .inputLabelStyle()
                    
                    HStack {
                        TextField("请输入6位验证码", text: $authViewModel.verificationCode)
                            .keyboardType(.numberPad)
                            .inputFieldStyle()
                            .onChange(of: authViewModel.verificationCode) { newValue in
                                // 限制输入长度为6位
                                if newValue.count > 6 {
                                    authViewModel.verificationCode = String(newValue.prefix(6))
                                }
                            }
                        
                        Button(action: {
                            authViewModel.sendVerificationCode()
                        }) {
                            Text(authViewModel.canResendCode ? "重新发送" : "\(authViewModel.resendCountdown)s")
                                .font(.custom("MF DianHei", size: 14))
                                .foregroundColor(authViewModel.canResendCode ? .themeColor : .gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 25)
                                        .stroke(authViewModel.canResendCode ? Color.themeColor : Color.gray, lineWidth: 1)
                                )
                        }
                        .disabled(!authViewModel.canResendCode || authViewModel.isLoading)
                    }
                }
                
                // 注册按钮
                Button(action: {
                    authViewModel.emailRegister()
                }) {
                    Text("完成注册")
                        .primaryButtonStyle()
                }
                .disabled(authViewModel.isLoading || !canRegister())
                .opacity(canRegister() ? 1.0 : 0.6)
                .padding(.top, 10)
            }
        }
    }
    
    // 检查是否可以发送验证码
    private func canSendCode() -> Bool {
        return !authViewModel.email.isEmpty &&
               !authViewModel.password.isEmpty &&
               !authViewModel.confirmPassword.isEmpty &&
               authViewModel.password == authViewModel.confirmPassword &&
               authViewModel.password.count >= 6
    }
    
    // 检查是否可以注册
    private func canRegister() -> Bool {
        return authViewModel.verificationCodeSent &&
               !authViewModel.verificationCode.isEmpty &&
               authViewModel.verificationCode.count == 6
    }
    
    // 跳过登录，直接体验（开发期间使用）
    private func skipLogin() {
        authViewModel.skipLoginForDevelopment()
        appStateManager.rootViewState = .defaultInfo
    }
    
}

#Preview {
    SignInView(appStateManager: AppStateManager(), authViewModel: AuthViewModel())
} 
