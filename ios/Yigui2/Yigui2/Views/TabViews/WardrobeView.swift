import SwiftUI

struct WardrobeView: View {
    @StateObject private var viewModel = ClothingViewModel()
    @State private var selectedTab = 0
    
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
                    
                    // 分类标签栏
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            Button(action: {
                                viewModel.setFilter(nil)
                                selectedTab = 0
                            }) {
                                Text("全部")
                                    .tabLabelStyle(isSelected: selectedTab == 0)
                            }
                            
                            ForEach(Array(ClothingType.allCases.enumerated()), id: \.element) { index, type in
                                Button(action: {
                                    viewModel.setFilter(type)
                                    selectedTab = index + 1
                                }) {
                                    Text(type.rawValue)
                                        .tabLabelStyle(isSelected: selectedTab == index + 1)
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // 创建添加按钮（实际应用中可从"设计"页面添加到衣柜）
                    
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.themeColor))
                            .scaleEffect(1.5)
                        Spacer()
                    } else if viewModel.filteredClothes.isEmpty {
                        Spacer()
                        VStack {
                            Image(systemName: "tshirt.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                                .padding()
                            
                            Text("暂无服装")
                                .font(.custom("MF DianHei", size: 20))
                                .foregroundColor(.gray)
                            
                            Text("请从设计页面添加服装")
                                .font(.custom("MF DianHei", size: 16))
                                .foregroundColor(.gray)
                                .padding(.top, 5)
                        }
                        Spacer()
                    } else {
                        // 衣物网格展示
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                ForEach(viewModel.filteredClothes) { clothing in
                                    WardrobeItemView(clothing: clothing)
                                        .onTapGesture {
                                            viewModel.selectClothing(clothing)
                                        }
                                }
                            }
                            .padding()
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top)
                .sheet(item: $viewModel.selectedClothing) { clothing in
                    ClothingDetailView(clothing: clothing, viewModel: viewModel)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.loadClothes()
            }
        }
    }
}

// 衣柜项视图
struct WardrobeItemView: View {
    let clothing: Clothing
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(hex: clothing.color ?? "FFFFFF"))
                    .frame(width: 160, height: 160)
                
                // 如果有图片则显示图片，否则显示图标
                if clothing.imageURL != nil {
                    Image(systemName: "photo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: clothingIcon(for: clothing.type))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white)
                }
            }
            
            Text(clothing.name)
                .font(.custom("MF DianHei", size: 16))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .frame(width: 160)
        }
    }
    
    // 根据衣物类型返回不同图标
    func clothingIcon(for type: ClothingType) -> String {
        switch type {
        case .shirt, .tshirt, .blouse:
            return "tshirt.fill"
        case .pants, .jeans:
            return "bag.fill"
        case .skirt, .dress:
            return "person.fill"
        case .jacket, .coat:
            return "tshirt.fill"
        case .other:
            return "circle.grid.hex.fill"
        }
    }
}

// 衣物详情视图
struct ClothingDetailView: View {
    let clothing: Clothing
    @ObservedObject var viewModel: ClothingViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 衣物预览
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(hex: clothing.color ?? "FFFFFF"))
                            .frame(height: 300)
                        
                        // 如果有图片则显示图片，否则显示图标
                        if clothing.imageURL != nil {
                            Image(systemName: "photo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: clothingIcon(for: clothing.type))
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 150)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    
                    // 衣物信息
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("名称:")
                                .font(.custom("MF DianHei", size: 18))
                                .foregroundColor(.textPrimary)
                            
                            Text(clothing.name)
                                .font(.custom("MF DianHei", size: 18))
                                .foregroundColor(.textPrimary)
                        }
                        
                        HStack {
                            Text("类型:")
                                .font(.custom("MF DianHei", size: 18))
                                .foregroundColor(.textPrimary)
                            
                            Text(clothing.type.rawValue)
                                .font(.custom("MF DianHei", size: 18))
                                .foregroundColor(.textPrimary)
                        }
                        
                        if let designData = clothing.designData {
                            HStack {
                                Text("布料:")
                                    .font(.custom("MF DianHei", size: 18))
                                    .foregroundColor(.textPrimary)
                                
                                Text(designData.fabricType)
                                    .font(.custom("MF DianHei", size: 18))
                                    .foregroundColor(.textPrimary)
                            }
                            
                            if let pattern = designData.pattern {
                                HStack {
                                    Text("图案:")
                                        .font(.custom("MF DianHei", size: 18))
                                        .foregroundColor(.textPrimary)
                                    
                                    Text(pattern)
                                        .font(.custom("MF DianHei", size: 18))
                                        .foregroundColor(.textPrimary)
                                }
                            }
                        }
                    }
                    .padding()
                    
                    HStack(spacing: 30) {
                        // 删除按钮
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            Text("删除")
                                .secondaryButtonStyle()
                        }
                        
                        // 穿着按钮（实际应用中连接到3D模型试穿功能）
                        Button(action: {
                            // 试穿功能
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text("试穿")
                                .primaryButtonStyle()
                        }
                    }
                    .padding(.horizontal, 50)
                    
                    Spacer()
                }
                .padding()
                .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                    Button("取消", role: .cancel) { }
                    Button("删除", role: .destructive) {
                        viewModel.removeClothing(clothing)
                        presentationMode.wrappedValue.dismiss()
                    }
                } message: {
                    Text("确定要删除这件衣物吗？")
                }
            }
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // 根据衣物类型返回不同图标
    func clothingIcon(for type: ClothingType) -> String {
        switch type {
        case .shirt, .tshirt, .blouse:
            return "tshirt.fill"
        case .pants, .jeans:
            return "bag.fill"
        case .skirt, .dress:
            return "person.fill"
        case .jacket, .coat:
            return "tshirt.fill"
        case .other:
            return "circle.grid.hex.fill"
        }
    }
}

#Preview {
    WardrobeView()
} 