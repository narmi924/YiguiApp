import SwiftUI

struct DesignView: View {
    @StateObject private var viewModel = DesignViewModel()
    @State private var showingTypeSelection = false
    @State private var showingColorPicker = false
    @State private var showingPatternPicker = false
    @State private var showingSaveDialog = false
    
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
                    
                    // 内容区域使用ScrollView包装
                    ScrollView {
                        VStack(spacing: 10) {
                            // 设计预览区域
                            if let currentDesign = viewModel.currentDesign {
                                DesignPreviewView(design: currentDesign)
                                    .frame(height: 400)
                                    .padding()
                                    .animation(.easeInOut, value: viewModel.selectedFabricType)
                                    .animation(.easeInOut, value: viewModel.selectedPattern)
                                    .animation(.easeInOut, value: viewModel.selectedColor)
                            } else {
                                VStack {
                                    Image(systemName: "tshirt.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                        .padding()
                                    
                                    Text("创建一个新设计或选择现有设计")
                                        .font(.custom("MF DianHei", size: 20))
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 400)
                                .padding()
                            }
                            
                            // 设计工具栏
                            if viewModel.currentDesign != nil {
                                designToolbar
                            } else {
                                // 创建新设计按钮
                                Button(action: {
                                    showingTypeSelection = true
                                }) {
                                    Text("创建新设计")
                                        .primaryButtonStyle()
                                }
                                .padding(.horizontal, 50)
                            }
                            
                            // 现有设计列表
                            if !viewModel.designs.isEmpty {
                                HStack {
                                    Text("我的设计")
                                        .font(.custom("MF DianHei", size: 20))
                                        .foregroundColor(.textPrimary)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.top)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 15) {
                                        ForEach(viewModel.designs) { design in
                                            DesignItemView(design: design)
                                                .onTapGesture {
                                                    viewModel.currentDesign = design
                                                }
                                        }
                                    }
                                    .padding()
                                }
                            }
                            
                            // 添加底部间距，确保内容可以完全滚动
                            Spacer().frame(height: 50)
                        }
                    }
                }
                .padding(.top)
                .sheet(isPresented: $showingTypeSelection) {
                    ClothingTypeSelectionView(viewModel: viewModel)
                }
                .sheet(isPresented: $showingColorPicker) {
                    ColorPickerView(selectedColor: $viewModel.selectedColor)
                }
                .sheet(isPresented: $showingPatternPicker) {
                    PatternPickerView(viewModel: viewModel)
                }
                .alert("保存设计", isPresented: $showingSaveDialog) {
                    TextField("设计名称", text: .constant("我的设计"))
                    Button("取消", role: .cancel) { }
                    Button("保存") {
                        viewModel.saveCurrentDesign()
                    }
                } message: {
                    Text("请为您的设计命名")
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.loadDesigns()
            }
        }
    }
    
    // 设计工具栏
    var designToolbar: some View {
        VStack(spacing: 15) {
            HStack(spacing: 20) {
                // 布料选择
                Button(action: {
                    // 显示布料选择菜单
                }) {
                    VStack {
                        Image(systemName: "rectangle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color.themeColor)
                        
                        Text("布料")
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(.textPrimary)
                    }
                }
                
                // 颜色选择
                Button(action: {
                    showingColorPicker = true
                }) {
                    VStack {
                        Image(systemName: "paintpalette.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color.themeColor)
                        
                        Text("颜色")
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(.textPrimary)
                    }
                }
                
                // 图案选择
                Button(action: {
                    showingPatternPicker = true
                }) {
                    VStack {
                        Image(systemName: "square.grid.3x3.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundColor(Color.themeColor)
                        
                        Text("图案")
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(.textPrimary)
                    }
                }
            }
            
            HStack(spacing: 30) {
                // 保存按钮
                Button(action: {
                    showingSaveDialog = true
                }) {
                    Text("保存")
                        .secondaryButtonStyle()
                }
                
                // 重新开始
                Button(action: {
                    showingTypeSelection = true
                }) {
                    Text("新设计")
                        .primaryButtonStyle()
                }
            }
            .padding(.horizontal, 50)
        }
        .padding()
    }
}

// 设计预览视图
struct DesignPreviewView: View {
    let design: Clothing
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.themeColor.opacity(0.1))
            
            // 衣物形状基于类型
            clothingShape
                .foregroundColor(Color(hex: design.color ?? "FFFFFF"))
        }
    }
    
    // 根据衣物类型返回不同形状
    var clothingShape: some View {
        Group {
            switch design.type {
            case .shirt, .tshirt, .blouse:
                topShapeView
            case .pants, .jeans:
                bottomShapeView
            case .skirt, .dress:
                dressShapeView
            case .jacket, .coat:
                outerwearShapeView
            case .other:
                accessoriesShapeView
            }
        }
    }
    
    // 各类型衣物的简化形状
    var topShapeView: some View {
        ZStack {
            Path { path in
                // 简化的T恤形状
                path.move(to: CGPoint(x: 100, y: 50))
                path.addLine(to: CGPoint(x: 300, y: 50))
                path.addLine(to: CGPoint(x: 300, y: 70))
                path.addLine(to: CGPoint(x: 350, y: 80))
                path.addLine(to: CGPoint(x: 350, y: 120))
                path.addLine(to: CGPoint(x: 300, y: 130))
                path.addLine(to: CGPoint(x: 300, y: 250))
                path.addLine(to: CGPoint(x: 100, y: 250))
                path.addLine(to: CGPoint(x: 100, y: 130))
                path.addLine(to: CGPoint(x: 50, y: 120))
                path.addLine(to: CGPoint(x: 50, y: 80))
                path.addLine(to: CGPoint(x: 100, y: 70))
                path.closeSubpath()
            }
            
            if let pattern = design.designData?.pattern, pattern != "无图案" {
                // 添加图案
                patternOverlay(pattern: pattern)
            }
        }
    }
    
    // 其他类型衣物的形状（简化实现）
    var bottomShapeView: some View {
        Rectangle().frame(width: 200, height: 250)
    }
    
    var dressShapeView: some View {
        Path { path in
            // 简化的连衣裙形状
            path.move(to: CGPoint(x: 120, y: 50))
            path.addLine(to: CGPoint(x: 280, y: 50))
            path.addLine(to: CGPoint(x: 320, y: 100))
            path.addLine(to: CGPoint(x: 320, y: 350))
            path.addLine(to: CGPoint(x: 80, y: 350))
            path.addLine(to: CGPoint(x: 80, y: 100))
            path.closeSubpath()
        }
    }
    
    var outerwearShapeView: some View {
        Rectangle().frame(width: 220, height: 300)
    }
    
    var accessoriesShapeView: some View {
        Circle().frame(width: 100, height: 100)
    }
    
    // 图案叠层
    func patternOverlay(pattern: String) -> some View {
        Group {
            switch pattern {
            case "条纹":
                stripesPattern
            case "格子":
                checkeredPattern
            case "波点":
                dottedPattern
            case "花卉":
                FloralPattern()
            default:
                EmptyView()
            }
        }
    }
    
    var stripesPattern: some View {
        VStack(spacing: 10) {
            ForEach(0..<10) { _ in
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 5)
            }
        }
    }
    
    var checkeredPattern: some View {
        VStack(spacing: 5) {
            ForEach(0..<8) { row in
                HStack(spacing: 5) {
                    ForEach(0..<8) { col in
                        Rectangle()
                            .fill((row + col) % 2 == 0 ? Color.white.opacity(0.3) : Color.clear)
                            .frame(width: 20, height: 20)
                    }
                }
            }
        }
    }
    
    var dottedPattern: some View {
        ZStack {
            ForEach(0..<30) { _ in
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 10, height: 10)
                    .offset(x: CGFloat.random(in: -100...100), y: CGFloat.random(in: -100...100))
            }
        }
    }
}

// 花卉图案组件
struct FloralPattern: View {
    var body: some View {
        ZStack {
            ForEach(0..<10) { _ in
                Image(systemName: "leaf.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .foregroundColor(.white.opacity(0.3))
                    .offset(x: CGFloat.random(in: -100...100), y: CGFloat.random(in: -100...100))
            }
        }
    }
}

// 设计项视图
struct DesignItemView: View {
    let design: Clothing
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(hex: design.color ?? "FFFFFF"))
                    .frame(width: 80, height: 80)
                
                Image(systemName: clothingIcon(for: design.type))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
            }
            
            Text(design.name)
                .font(.custom("MF DianHei", size: 12))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .frame(width: 80)
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

// 衣物类型选择视图
struct ClothingTypeSelectionView: View {
    @ObservedObject var viewModel: DesignViewModel
    @Environment(\.presentationMode) var presentationMode
    
    let clothingTypes = ClothingType.allCases
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("选择服装类型")
                        .font(.custom("MF DianHei", size: 24))
                        .foregroundColor(.textPrimary)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(clothingTypes, id: \.self) { type in
                            Button(action: {
                                viewModel.startNewDesign(type: type)
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                VStack {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 15)
                                            .fill(Color.themeColor)
                                            .frame(width: 120, height: 120)
                                        
                                        Image(systemName: clothingIcon(for: type))
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 60)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text(type.rawValue)
                                        .font(.custom("MF DianHei", size: 16))
                                        .foregroundColor(.textPrimary)
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
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

// 颜色选择器视图
struct ColorPickerView: View {
    @Binding var selectedColor: String
    @Environment(\.presentationMode) var presentationMode
    
    let colors = [
        "FFFFFF", // 白色
        "000000", // 黑色
        "FF0000", // 红色
        "00FF00", // 绿色
        "0000FF", // 蓝色
        "FFFF00", // 黄色
        "FF00FF", // 品红
        "00FFFF", // 青色
        "808080", // 灰色
        "800000", // 褐红色
        "808000", // 橄榄色
        "008000", // 暗绿色
        "800080", // 紫色
        "008080", // 蓝绿色
        "000080"  // 海军蓝
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("选择颜色")
                        .font(.custom("MF DianHei", size: 24))
                        .foregroundColor(.textPrimary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 20) {
                        ForEach(colors, id: \.self) { colorHex in
                            Button(action: {
                                selectedColor = colorHex
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: colorHex))
                                        .frame(width: 60, height: 60)
                                        .overlay(Circle().stroke(Color.gray, lineWidth: 1))
                                    
                                    if selectedColor == colorHex {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(isDark(colorHex) ? .white : .black)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    // 判断颜色是否为深色
    func isDark(_ hexColor: String) -> Bool {
        let r, g, b: CGFloat
        let scanner = Scanner(string: hexColor)
        var hexNumber: UInt64 = 0
        
        if scanner.scanHexInt64(&hexNumber) {
            r = CGFloat((hexNumber & 0xff0000) >> 16) / 255
            g = CGFloat((hexNumber & 0x00ff00) >> 8) / 255
            b = CGFloat(hexNumber & 0x0000ff) / 255
            
            let brightness = ((r * 299) + (g * 587) + (b * 114)) / 1000
            return brightness < 0.5
        }
        
        return false
    }
}

// 图案选择器视图
struct PatternPickerView: View {
    @ObservedObject var viewModel: DesignViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("选择图案")
                        .font(.custom("MF DianHei", size: 24))
                        .foregroundColor(.textPrimary)
                    
                    ForEach(viewModel.patterns, id: \.self) { pattern in
                        Button(action: {
                            viewModel.selectedPattern = pattern == "无图案" ? nil : pattern
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                Text(pattern)
                                    .font(.custom("MF DianHei", size: 18))
                                    .foregroundColor(.textPrimary)
                                
                                Spacer()
                                
                                if viewModel.selectedPattern == pattern || (viewModel.selectedPattern == nil && pattern == "无图案") {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.themeColor)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

#Preview {
    DesignView()
} 