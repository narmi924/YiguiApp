import SwiftUI

struct PatternSelectionView: View {
    @ObservedObject var viewModel: RealDesignViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedCategory: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 标题
                    Text("选择纸样")
                        .font(.custom("MF DianHei", size: 24))
                        .foregroundColor(.textPrimary)
                    
                    // 分类选择
                    if !viewModel.patternCategories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 15) {
                                ForEach(viewModel.patternCategories, id: \.self) { category in
                                    CategoryButton(
                                        title: categoryName(category),
                                        isSelected: selectedCategory == category,
                                        action: {
                                            selectedCategory = category
                                            viewModel.loadPatterns(category: category)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // 纸样列表
                    if viewModel.patterns.isEmpty {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .themeColor))
                            
                            Text("加载纸样中...")
                                .font(.custom("MF DianHei", size: 16))
                                .foregroundColor(.gray)
                                .padding(.top)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 20) {
                                ForEach(viewModel.patterns) { pattern in
                                    PatternCard(
                                        pattern: pattern,
                                        isSelected: viewModel.selectedPattern?.id == pattern.id,
                                        onTap: {
                                            viewModel.selectedPattern = pattern
                                            presentationMode.wrappedValue.dismiss()
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.themeColor)
                }
            }
        }
        .onAppear {
            if selectedCategory == nil && !viewModel.patternCategories.isEmpty {
                selectedCategory = viewModel.patternCategories.first
                viewModel.loadPatterns(category: selectedCategory)
            }
        }
    }
    
    private func categoryName(_ category: String) -> String {
        switch category {
        case "shirt": return "上衣"
        case "pants": return "裤子"
        case "dress": return "连衣裙"
        default: return category
        }
    }
}

struct CategoryButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("MF DianHei", size: 16))
                .foregroundColor(isSelected ? .white : .textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color.themeColor : Color.gray.opacity(0.2))
                )
        }
    }
}

struct PatternCard: View {
    let pattern: Pattern
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 纸样预览图
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: 120)
                    
                    if let thumbnailPath = pattern.thumbnailPath {
                        AsyncImage(url: URL(string: "https://yiguiapp.xyz/patterns/\(thumbnailPath)")) { image in
                            image
                                .resizable()
                                .scaledToFit()
                        } placeholder: {
                            Image(systemName: "rectangle.3.group")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                        .frame(height: 120)
                        .cornerRadius(12)
                    } else {
                        Image(systemName: "rectangle.3.group")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                    
                    // 选择指示器
                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.themeColor)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .padding(.trailing, 8)
                                    .padding(.top, 8)
                            }
                            Spacer()
                        }
                    }
                }
                
                // 纸样信息
                VStack(spacing: 4) {
                    Text(pattern.name)
                        .font(.custom("MF DianHei", size: 16))
                        .foregroundColor(.textPrimary)
                        .lineLimit(1)
                    
                    if let description = pattern.description {
                        Text(description)
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? Color.themeColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(isSelected ? Color.themeColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    PatternSelectionView(viewModel: RealDesignViewModel())
} 