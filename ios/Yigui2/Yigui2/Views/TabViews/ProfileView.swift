import SwiftUI
import PhotosUI

struct ProfileView: View {
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var showLogoutConfirmation = false
    @State private var showSettings = false
    @State private var showEditProfile = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 10) {
                    // 应用标题 - 使用特殊样式，只有U是主题色
                    HStack(spacing: 0) {
                        Text("Yig")
                            .font(.custom("Epilogue", size: 36))
                            .foregroundColor(.textPrimary)
                        
                        Text("U")
                            .font(.custom("Epilogue", size: 36))
                            .foregroundColor(.themeColor)
                        
                        Text("i")
                            .font(.custom("Epilogue", size: 36))
                            .foregroundColor(.textPrimary)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 3)
                    .padding(.top, 10)
                    
                    // 用户头像
                    ZStack {
                        if let avatarImage {
                            avatarImage
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.themeColor, lineWidth: 2))
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 120, height: 120)
                                .overlay(Circle().stroke(Color.themeColor, lineWidth: 2))
                            
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 20)
                    
                    // 用户信息
                    profileInfoView
                    
                    Spacer()
                    
                    // 功能按钮区
                    VStack(spacing: 15) {
                        // 编辑资料按钮
                        Button(action: {
                            if let user = authViewModel.user {
                                authViewModel.nickname = user.nickname
                                authViewModel.height = user.height != nil ? "\(user.height!)" : ""
                                authViewModel.weight = user.weight != nil ? "\(user.weight!)" : ""
                                showEditProfile = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16))
                                Text("编辑资料")
                                    .font(.custom("MF DianHei", size: 16))
                            }
                            .frame(width: 180)
                            .primaryButtonStyle()
                        }
                        
                        // 设置按钮
                        Button(action: {
                            showSettings = true
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                    .font(.system(size: 16))
                                Text("设置")
                                    .font(.custom("MF DianHei", size: 16))
                            }
                            .frame(width: 180)
                            .primaryButtonStyle()
                        }
                        
                        // 退出登录按钮
                        Button(action: {
                            showLogoutConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 16))
                                Text("退出登录")
                                    .font(.custom("MF DianHei", size: 16))
                            }
                            .frame(width: 180)
                            .secondaryButtonStyle()
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding()
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
                .sheet(isPresented: $showEditProfile) {
                    EditProfileView(authViewModel: authViewModel)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                authViewModel.loadUserState()
            }
        }
    }
    
    // 用户信息视图
    var profileInfoView: some View {
        VStack(spacing: 20) {
            if let user = authViewModel.user {
                HStack {
                    Text("昵称:")
                        .font(.custom("MF DianHei", size: 18))
                        .foregroundColor(.textPrimary)
                        .frame(width: 60, alignment: .leading)
                    
                    Text(user.nickname)
                        .font(.custom("MF DianHei", size: 18))
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                
                HStack {
                    Text("邮箱:")
                        .font(.custom("MF DianHei", size: 18))
                        .foregroundColor(.textPrimary)
                        .frame(width: 60, alignment: .leading)
                    
                    Text(user.email)
                        .font(.custom("MF DianHei", size: 18))
                        .foregroundColor(.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
                
                if let height = user.height {
                    HStack {
                        Text("身高:")
                            .font(.custom("MF DianHei", size: 18))
                            .foregroundColor(.textPrimary)
                            .frame(width: 60, alignment: .leading)
                        
                        Text("\(height) cm")
                            .font(.custom("MF DianHei", size: 18))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                }
                
                if let weight = user.weight {
                    HStack {
                        Text("体重:")
                            .font(.custom("MF DianHei", size: 18))
                            .foregroundColor(.textPrimary)
                            .frame(width: 60, alignment: .leading)
                        
                        Text("\(weight) kg")
                            .font(.custom("MF DianHei", size: 18))
                            .foregroundColor(.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal)
                }
            } else {
                Text("未登录")
                    .font(.custom("MF DianHei", size: 20))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // 加载选择的图片
    private func loadImage() {
        Task {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                avatarImage = Image(uiImage: uiImage)
                // 这里可以添加将头像保存到用户数据的逻辑
                // 未来可以实现上传头像到服务器的功能
            }
        }
    }
}

// 编辑资料视图
struct EditProfileView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var hasUnsavedChanges = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 头像选择
                        ZStack {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                if let avatarImage {
                                    avatarImage
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.themeColor, lineWidth: 2))
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 120, height: 120)
                                        .overlay(Circle().stroke(Color.themeColor, lineWidth: 2))
                                    
                                    Image(systemName: "person.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        .foregroundColor(.gray)
                                }
                            }
                            .onChange(of: selectedItem) { _ in
                                loadImage()
                                hasUnsavedChanges = true
                            }
                            
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color.themeColor)
                                .font(.system(size: 24))
                                .background(Circle().fill(Color.white))
                                .offset(x: 45, y: 45)
                        }
                        .padding(.top, 20)
                        
                        // 编辑表单
                        VStack(alignment: .leading, spacing: 15) {
                            Text("昵称")
                                .inputLabelStyle()
                            
                            TextField("你的昵称", text: $authViewModel.nickname)
                                .inputFieldStyle()
                                .onChange(of: authViewModel.nickname) { _ in
                                    hasUnsavedChanges = true
                                }
                            
                            Text("身高/cm")
                                .inputLabelStyle()
                                .padding(.top, 10)
                            
                            TextField("你的身高", text: $authViewModel.height)
                                .keyboardType(.numberPad)
                                .inputFieldStyle()
                                .onChange(of: authViewModel.height) { _ in
                                    hasUnsavedChanges = true
                                }
                            
                            Text("体重/Kg")
                                .inputLabelStyle()
                                .padding(.top, 10)
                            
                            TextField("你的体重", text: $authViewModel.weight)
                                .keyboardType(.numberPad)
                                .inputFieldStyle()
                                .onChange(of: authViewModel.weight) { _ in
                                    hasUnsavedChanges = true
                                }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        
                        // 保存按钮
                        Button(action: {
                            authViewModel.updateUserInfo()
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("保存")
                                .primaryButtonStyle()
                        }
                        .padding(.horizontal, 50)
                        .padding(.top, 30)
                        
                        Spacer()
                    }
                    .padding()
                }
                .navigationTitle("编辑资料")
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
    
    // 加载选择的图片
    private func loadImage() {
        Task {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                avatarImage = Image(uiImage: uiImage)
                // 这里可以添加将头像保存到用户数据的逻辑
                // 未来可以实现上传头像到服务器的功能
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
