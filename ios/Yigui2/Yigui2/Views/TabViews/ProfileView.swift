import SwiftUI
import PhotosUI

struct ProfileView: View {
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var showLogoutConfirmation = false
    @State private var showSettings = false
    @State private var showEditData = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // 渐变背景
                LinearGradient(
                    gradient: Gradient(colors: [Color.background, Color.themeColor.opacity(0.05)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 25) {
                        // 应用标题
                        HStack(spacing: 0) {
                            Text("Yig")
                                .font(.custom("Epilogue", size: 32))
                                .foregroundColor(.textPrimary)
                            
                            Text("U")
                                .font(.custom("Epilogue", size: 32))
                                .foregroundColor(.themeColor)
                            
                            Text("i")
                                .font(.custom("Epilogue", size: 32))
                                .foregroundColor(.textPrimary)
                        }
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        .padding(.top, 20)
                        
                        // 用户头像区域
                        VStack(spacing: 15) {
                            ZStack {
                                // 头像背景圆环
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.themeColor.opacity(0.3), Color.themeColor]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                                    .frame(width: 130, height: 130)
                                
                                // 头像选择器
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    if let avatarImage {
                                        avatarImage
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 120, height: 120)
                                            .clipShape(Circle())
                                    } else {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.2)]),
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 120, height: 120)
                                        
                                        Image(systemName: "person.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 50, height: 50)
                                            .foregroundColor(.gray.opacity(0.6))
                                    }
                                }
                                .onChange(of: selectedItem) { _ in
                                    loadImage()
                                }
                                
                                // 编辑头像图标
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .medium))
                                    .frame(width: 28, height: 28)
                                    .background(Color.themeColor)
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                                    .offset(x: 40, y: 40)
                            }
                            
                            // 用户昵称
                            if let user = authViewModel.user {
                                Text(user.nickname)
                                    .font(.custom("MF DianHei", size: 22))
                                    .fontWeight(.medium)
                                    .foregroundColor(.textPrimary)
                            }
                        }
                        .padding(.vertical, 10)
                        
                        // 用户信息卡片
                        profileInfoCard
                        
                        // 功能按钮区
                        VStack(spacing: 12) {
                            // 修改数据按钮
                            Button(action: {
                                if let user = authViewModel.user {
                                    authViewModel.height = user.height != nil ? "\(user.height!)" : ""
                                    authViewModel.weight = user.weight != nil ? "\(user.weight!)" : ""
                                    showEditData = true
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "ruler")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.themeColor)
                                    
                                    Text("修改数据")
                                        .font(.custom("MF DianHei", size: 16))
                                        .fontWeight(.medium)
                                        .foregroundColor(.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                                )
                            }
                            
                            // 设置按钮
                            Button(action: {
                                showSettings = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "gear")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.themeColor)
                                    
                                    Text("设置")
                                        .font(.custom("MF DianHei", size: 16))
                                        .fontWeight(.medium)
                                        .foregroundColor(.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                                )
                            }
                            
                            // 退出登录按钮
                            Button(action: {
                                showLogoutConfirmation = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.red)
                                    
                                    Text("退出登录")
                                        .font(.custom("MF DianHei", size: 16))
                                        .fontWeight(.medium)
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white)
                                        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert("确认退出", isPresented: $showLogoutConfirmation) {
                Button("取消", role: .cancel) { }
                Button("退出", role: .destructive) {
                    authViewModel.logout()
                    appStateManager.rootViewState = .signIn
                }
            } message: {
                Text("确定要退出登录吗？")
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showEditData) {
                EditDataView(authViewModel: authViewModel)
            }
            .onAppear {
                // 移除loadUserState调用，避免每次进入"我的"页面都触发模型更新
                // authViewModel.loadUserState()
                loadUserAvatar()
            }
            .onReceive(authViewModel.userInfoUpdated) { _ in
                loadUserAvatar()
            }
        }
    }
    
    // 用户信息卡片
    var profileInfoCard: some View {
        VStack(spacing: 0) {
            if let user = authViewModel.user {
                // 基本信息
                VStack(spacing: 16) {
                    profileInfoRow(icon: "envelope.fill", title: "邮箱", value: user.email)
                    profileInfoRow(icon: "person.fill", title: "性别", value: user.gender == "male" ? "男" : "女")
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
                
                // 分割线
                Divider()
                    .background(Color.gray.opacity(0.2))
                
                // 身体数据
                VStack(spacing: 16) {
                    profileInfoRow(
                        icon: "ruler.fill", 
                        title: "身高", 
                        value: user.height != nil ? "\(user.height!) cm" : "未设置"
                    )
                    profileInfoRow(
                        icon: "scalemass.fill", 
                        title: "体重", 
                        value: user.weight != nil ? "\(user.weight!) kg" : "未设置"
                    )
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 20)
            } else {
                Text("未登录")
                    .font(.custom("MF DianHei", size: 18))
                    .foregroundColor(.gray)
                    .padding(.vertical, 40)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .padding(.horizontal, 20)
    }
    
    // 信息行组件
    func profileInfoRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.themeColor)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.custom("MF DianHei", size: 16))
                .foregroundColor(.gray)
                .frame(width: 50, alignment: .leading)
            
            Text(value)
                .font(.custom("MF DianHei", size: 16))
                .fontWeight(.medium)
                .foregroundColor(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
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
                
                // 更新用户信息到服务器
                Task {
                    await authViewModel.updateUserInfo()
                }
            }
        }
    }
    
    private func loadUserAvatar() {
        if let user = authViewModel.user,
           let avatarURL = user.avatarURL {
            
            let urlString = avatarURL.absoluteString
            print("🔍 尝试加载头像URL: \(urlString)")
            
            if urlString.hasPrefix("data:image") {
                // 处理base64格式的头像
                let base64String = urlString.replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
                if let data = Data(base64Encoded: base64String),
                   let uiImage = UIImage(data: data) {
                    avatarImage = Image(uiImage: uiImage)
                    print("✅ ProfileView加载了base64头像")
                }
            } else if urlString.hasPrefix("http") {
                // 处理服务器URL格式的头像
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: avatarURL)
                        if let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                self.avatarImage = Image(uiImage: uiImage)
                                print("✅ ProfileView加载了服务器头像")
                            }
                        }
                    } catch {
                        print("❌ 加载服务器头像失败: \(error)")
                    }
                }
            }
        }
    }
}

// 修改数据视图（只处理身高体重）
struct EditDataView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 30) {
                    // 标题
                    VStack(spacing: 8) {
                        Text("修改身体数据")
                            .font(.custom("MF DianHei", size: 24))
                            .fontWeight(.bold)
                            .foregroundColor(.textPrimary)
                        
                        Text("请输入准确的身高体重数据")
                            .font(.custom("MF DianHei", size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    // 数据输入卡片
                    VStack(spacing: 25) {
                        // 身高输入
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "ruler.fill")
                                    .foregroundColor(.themeColor)
                                    .font(.system(size: 16))
                                
                                Text("身高")
                                    .font(.custom("MF DianHei", size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(.textPrimary)
                            }
                            
                            HStack {
                                TextField("请输入身高", text: $authViewModel.height)
                                    .keyboardType(.numberPad)
                                    .font(.custom("MF DianHei", size: 18))
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                
                                Text("cm")
                                    .font(.custom("MF DianHei", size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                            }
                        }
                        
                        // 体重输入
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "scalemass.fill")
                                    .foregroundColor(.themeColor)
                                    .font(.system(size: 16))
                                
                                Text("体重")
                                    .font(.custom("MF DianHei", size: 16))
                                    .fontWeight(.medium)
                                    .foregroundColor(.textPrimary)
                            }
                            
                            HStack {
                                TextField("请输入体重", text: $authViewModel.weight)
                                    .keyboardType(.numberPad)
                                    .font(.custom("MF DianHei", size: 18))
                                    .foregroundColor(.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Color.gray.opacity(0.1))
                                    )
                                
                                Text("kg")
                                    .font(.custom("MF DianHei", size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 25)
                    .padding(.vertical, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
                    )
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    // 保存按钮
                    Button(action: {
                        Task {
                            await authViewModel.updateUserInfo()
                            await MainActor.run {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }) {
                        Text("保存数据")
                            .font(.custom("MF DianHei", size: 18))
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.themeColor, Color.themeColor.opacity(0.8)]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color.themeColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("修改数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.themeColor)
                    }
                }
            }
        }
    }
}

// 设置视图
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false
    @State private var language = "简体中文"
    @State private var showClearCacheConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(alignment: .leading, spacing: 0) {
                    List {
                        Section(header: Text("通用设置").font(.custom("MF DianHei", size: 16))) {
                            Toggle("通知", isOn: $notificationsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .themeColor))
                            
                            Toggle("深色模式", isOn: $darkModeEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .themeColor))
                            
                            HStack {
                                Text("语言")
                                Spacer()
                                Text(language)
                                    .foregroundColor(.gray)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                        }
                        
                        Section(header: Text("隐私与安全").font(.custom("MF DianHei", size: 16))) {
                            HStack {
                                Text("隐私政策")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                            
                            HStack {
                                Text("用户协议")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                        }
                        
                        Section(header: Text("关于").font(.custom("MF DianHei", size: 16))) {
                            HStack {
                                Text("版本")
                                Spacer()
                                Text("1.0.0")
                                    .foregroundColor(.gray)
                            }
                            
                            Button(action: {
                                showClearCacheConfirmation = true
                            }) {
                                Text("清除缓存")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
                .navigationTitle("设置")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.themeColor)
                        }
                    }
                }
                .alert("确认清除缓存", isPresented: $showClearCacheConfirmation) {
                    Button("取消", role: .cancel) { }
                    Button("清除", role: .destructive) {
                        // 清除缓存的逻辑
                    }
                } message: {
                    Text("确定要清除所有缓存数据吗？此操作无法撤销。")
                }
            }
        }
    }
}

#Preview {
    ProfileView(appStateManager: AppStateManager(), authViewModel: AuthViewModel())
} 
