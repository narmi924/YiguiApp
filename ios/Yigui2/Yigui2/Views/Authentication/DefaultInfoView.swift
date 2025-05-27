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
                
                Text("完善你的信息")
                    .font(.custom("MF DianHei", size: 32))
                    .foregroundColor(.textPrimary)
                    .padding(.bottom, 10)
                
                Text("别担心，只有你自己才能看到自己的数据")
                    .font(.custom("MF DianHei", size: 16))
                    .foregroundColor(.textPrimary)
                    .padding(.bottom, 20)
                
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
                    }
                    
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(Color.themeColor)
                        .font(.system(size: 24))
                        .background(Circle().fill(Color.white))
                        .offset(x: 45, y: 45)
                }
                .padding(.bottom, 30)
                
                // 表单
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("昵称")
                            .inputLabelStyle()
                        
                        TextField("请输入昵称", text: $authViewModel.nickname)
                            .inputFieldStyle()
                    }
                    
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
                
                Spacer()
                
                // 底部按钮区
                VStack(spacing: 20) {
                    // 保存并进入应用按钮
                    Button(action: {
                        authViewModel.updateUserInfo()
                        appStateManager.rootViewState = .mainApp
                    }) {
                        Text("开始使用")
                            .primaryButtonStyle()
                    }
                    .padding(.horizontal, 50)
                    
                    // 跳过按钮
                    Button(action: {
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
    DefaultInfoView(appStateManager: AppStateManager(), authViewModel: AuthViewModel())
} 