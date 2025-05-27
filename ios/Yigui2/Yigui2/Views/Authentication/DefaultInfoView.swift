import SwiftUI
import PhotosUI

struct DefaultInfoView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var navigateToMainApp = false
    
    var body: some View {
        if navigateToMainApp {
            MainTabView()
        } else {
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
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        ZStack {
                            if let avatarImage {
                                avatarImage
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.primary, lineWidth: 2))
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 100)
                                    .overlay(Circle().stroke(Color.primary, lineWidth: 2))
                                
                                Image(systemName: "person.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 50, height: 50)
                                    .foregroundColor(.gray)
                            }
                            
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(Color.primary)
                                .font(.system(size: 24))
                                .background(Circle().fill(Color.white))
                                .offset(x: 35, y: 35)
                        }
                    }
                    .onChange(of: selectedItem) { _ in
                        loadImage()
                    }
                    .padding(.bottom, 20)
                    
                    // 信息输入表单
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
                    
                    Button(action: {
                        authViewModel.updateUserInfo()
                        navigateToMainApp = true
                    }) {
                        Text("继续")
                            .primaryButtonStyle()
                    }
                    .padding(.horizontal, 50)
                    .padding(.top, 30)
                    
                    Spacer()
                }
                .padding()
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
    DefaultInfoView(authViewModel: AuthViewModel())
} 