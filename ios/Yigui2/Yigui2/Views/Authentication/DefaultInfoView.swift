import SwiftUI
import PhotosUI

struct DefaultInfoView: View {
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 应用标题 - 使用特殊样式，只有U是主题色，确保位置一致
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
                
                // 简化的标题
                Text("完善您的基础信息")
                    .font(.custom("MF DianHei", size: 16))
                    .foregroundColor(.gray)
                    .padding(.bottom, 15)
                
                // 头像选择 - 缩小间距
                ZStack {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        if let avatarImage {
                            avatarImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.themeColor, lineWidth: 2))
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 100, height: 100)
                                .overlay(Circle().stroke(Color.themeColor, lineWidth: 2))
                            
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.gray)
                        }
                    }
                    .onChange(of: selectedItem) { _ in
                        loadImage()
                    }
                    
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color.themeColor)
                        .font(.system(size: 20))
                        .background(Circle().fill(Color.white))
                        .offset(x: 38, y: 38)
                }
                .padding(.bottom, 15)
                .onAppear {
                    loadExistingAvatar()
                }
                
                // 昵称输入 - 缩小间距
                VStack(alignment: .leading, spacing: 8) {
                    Text("昵称")
                        .inputLabelStyle()
                        .padding(.horizontal, 40)
                    
                    TextField("请输入昵称", text: $authViewModel.nickname)
                        .inputFieldStyle()
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 12)
                
                // 性别选择 - 缩小间距
                VStack(alignment: .leading, spacing: 8) {
                    Text("性别")
                        .inputLabelStyle()
                        .padding(.horizontal, 40)
                    
                    HStack(spacing: 15) {
                        // 男性选择按钮
                        Button(action: {
                            authViewModel.gender = "male"
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(authViewModel.gender == "male" ? .white : .textPrimary)
                                Text("男")
                                    .font(.custom("MF DianHei", size: 16))
                                    .foregroundColor(authViewModel.gender == "male" ? .white : .textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(authViewModel.gender == "male" ? Color.themeColor : Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(authViewModel.gender == "male" ? Color.themeColor : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        // 女性选择按钮
                        Button(action: {
                            authViewModel.gender = "female"
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(authViewModel.gender == "female" ? .white : .textPrimary)
                                Text("女")
                                    .font(.custom("MF DianHei", size: 16))
                                    .foregroundColor(authViewModel.gender == "female" ? .white : .textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(authViewModel.gender == "female" ? Color.themeColor : Color.gray.opacity(0.1))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(authViewModel.gender == "female" ? Color.themeColor : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 40)
                }
                .padding(.bottom, 12)
                
                // 身高体重表单 - 缩小间距
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("身高/cm")
                            .inputLabelStyle()
                        
                        TextField("请输入身高", text: $authViewModel.height)
                            .keyboardType(.numberPad)
                            .inputFieldStyle()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("体重/kg")
                            .inputLabelStyle()
                        
                        TextField("请输入体重", text: $authViewModel.weight)
                            .keyboardType(.numberPad)
                            .inputFieldStyle()
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer(minLength: 20)
                
                // 底部按钮区 - 缩小间距
                VStack(spacing: 15) {
                    // 保存并进入应用按钮
                    Button(action: {
                        print("🔄 用户点击'开始使用'，当前性别设置: \(authViewModel.gender)")
                        print("🔄 用户点击'开始使用'，当前昵称设置: '\(authViewModel.nickname)'")
                        print("🔄 用户点击'开始使用'，isNewUser: \(authViewModel.isNewUser)")
                        Task {
                            // 更新用户信息到服务器
                            await authViewModel.updateUserInfo()
                            
                            // 等待信息更新完成后，进入主应用
                            await MainActor.run {
                                appStateManager.rootViewState = .mainApp
                            }
                        }
                    }) {
                        Text("开始使用")
                            .primaryButtonStyle()
                    }
                    .padding(.horizontal, 50)
                    
                    // 跳过按钮
                    Button(action: {
                        print("🔄 用户点击'跳过'，直接进入应用")
                        appStateManager.rootViewState = .mainApp
                    }) {
                        Text("跳过")
                            .font(.custom("MF DianHei", size: 16))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // 确保新用户的信息正确初始化
            if authViewModel.isNewUser {
                print("📝 新用户信息完善页面加载")
                print("📝 当前用户性别: \(authViewModel.gender)（注册时已确定）")
                print("📝 当前用户昵称: '\(authViewModel.nickname)'")
                
                // 如果用户对象已存在，同步用户信息到表单
                if let user = authViewModel.user {
                    print("🔄 同步用户信息到表单")
                    authViewModel.gender = user.gender
                    authViewModel.nickname = user.nickname
                    if let height = user.height {
                        authViewModel.height = "\(height)"
                    }
                    if let weight = user.weight {
                        authViewModel.weight = "\(weight)"
                    }
                }
            }
        }
    }
    
    // 加载现有头像
    private func loadExistingAvatar() {
        if let user = authViewModel.user,
           let avatarURL = user.avatarURL {
            
            let urlString = avatarURL.absoluteString
            if urlString.hasPrefix("data:image") {
                // 解析base64数据
                let base64String = urlString.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                if let data = Data(base64Encoded: base64String),
                   let uiImage = UIImage(data: data) {
                    avatarImage = Image(uiImage: uiImage)
                    print("✅ 加载了现有头像")
                }
            }
        }
    }
    
    // 加载选择的图片
    private func loadImage() {
        Task {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                avatarImage = Image(uiImage: uiImage)
                // 保存头像到用户数据
                authViewModel.updateAvatarImage(uiImage)
            }
        }
    }
}

#Preview {
    DefaultInfoView(appStateManager: AppStateManager(), authViewModel: AuthViewModel())
} 