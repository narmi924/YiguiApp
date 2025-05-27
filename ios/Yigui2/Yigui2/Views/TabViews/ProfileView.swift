import SwiftUI
import PhotosUI

struct ProfileView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var isEditingProfile = false
    @State private var showLogoutConfirmation = false
    
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
                    .padding(.top, 20)
                    
                    // 用户头像
                    ZStack {
                        if isEditingProfile {
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
                            }
                            
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color.themeColor)
                                .font(.system(size: 24))
                                .background(Circle().fill(Color.white))
                                .offset(x: 45, y: 45)
                        } else {
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
                    }
                    .padding(.vertical, 20)
                    
                    // 用户信息
                    if isEditingProfile {
                        editProfileForm
                    } else {
                        profileInfoView
                    }
                    
                    Spacer()
                    
                    // 登出按钮
                    Button(action: {
                        showLogoutConfirmation = true
                    }) {
                        Text("退出登录")
                            .secondaryButtonStyle()
                    }
                    .padding(.horizontal, 50)
                    .padding(.bottom, 30)
                }
                .padding()
                .alert("确认退出", isPresented: $showLogoutConfirmation) {
                    Button("取消", role: .cancel) { }
                    Button("退出", role: .destructive) {
                        authViewModel.logout()
                    }
                } message: {
                    Text("确定要退出登录吗？")
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
                    
                    Text(user.nickname)
                        .font(.custom("MF DianHei", size: 18))
                        .foregroundColor(.textPrimary)
                }
                
                HStack {
                    Text("邮箱:")
                        .font(.custom("MF DianHei", size: 18))
                        .foregroundColor(.textPrimary)
                    
                    Text(user.email)
                        .font(.custom("MF DianHei", size: 18))
                        .foregroundColor(.textPrimary)
                }
                
                if let height = user.height {
                    HStack {
                        Text("身高:")
                            .font(.custom("MF DianHei", size: 18))
                            .foregroundColor(.textPrimary)
                        
                        Text("\(height) cm")
                            .font(.custom("MF DianHei", size: 18))
                            .foregroundColor(.textPrimary)
                    }
                }
                
                if let weight = user.weight {
                    HStack {
                        Text("体重:")
                            .font(.custom("MF DianHei", size: 18))
                            .foregroundColor(.textPrimary)
                        
                        Text("\(weight) kg")
                            .font(.custom("MF DianHei", size: 18))
                            .foregroundColor(.textPrimary)
                    }
                }
                
                Button(action: {
                    isEditingProfile = true
                    authViewModel.nickname = user.nickname
                    authViewModel.height = user.height != nil ? "\(user.height!)" : ""
                    authViewModel.weight = user.weight != nil ? "\(user.weight!)" : ""
                }) {
                    Text("编辑资料")
                        .primaryButtonStyle()
                }
                .padding(.horizontal, 50)
                .padding(.top, 20)
            } else {
                Text("未登录")
                    .font(.custom("MF DianHei", size: 20))
                    .foregroundColor(.gray)
            }
        }
        .padding()
    }
    
    // 编辑资料表单
    var editProfileForm: some View {
        VStack(spacing: 15) {
            VStack(alignment: .leading, spacing: 15) {
                Text("昵称")
                    .inputLabelStyle()
                
                TextField("你的昵称", text: $authViewModel.nickname)
                    .inputFieldStyle()
                
                Text("身高/cm")
                    .inputLabelStyle()
                    .padding(.top, 10)
                
                TextField("你的身高", text: $authViewModel.height)
                    .keyboardType(.numberPad)
                    .inputFieldStyle()
                
                Text("体重/Kg")
                    .inputLabelStyle()
                    .padding(.top, 10)
                
                TextField("你的体重", text: $authViewModel.weight)
                    .keyboardType(.numberPad)
                    .inputFieldStyle()
            }
            .padding(.horizontal)
            
            HStack(spacing: 30) {
                // 取消按钮
                Button(action: {
                    isEditingProfile = false
                }) {
                    Text("取消")
                        .secondaryButtonStyle()
                }
                
                // 保存按钮
                Button(action: {
                    authViewModel.updateUserInfo()
                    isEditingProfile = false
                }) {
                    Text("保存")
                        .primaryButtonStyle()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
        .padding()
    }
    
    // 加载选择的图片
    private func loadImage() {
        Task {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                avatarImage = Image(uiImage: uiImage)
                // 这里可以添加将头像保存到用户数据的逻辑
            }
        }
    }
}

#Preview {
    ProfileView()
} 
