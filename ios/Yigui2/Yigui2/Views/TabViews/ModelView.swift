import SwiftUI
import SceneKit

struct ModelView: View {
    @StateObject private var viewModel = ModelViewModel()
    @ObservedObject var authViewModel: AuthViewModel
    @State private var showingModelList = false
    @State private var isFirstAppear = true
    @State private var showDeleteConfirmation = false
    @State private var modelToDelete: Model3D? = nil
    
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
                    
                    // 模型展示区域 - 扩大区域
                    if let selectedModel = viewModel.selectedModel {
                        ModelPreviewView(model: selectedModel, viewModel: viewModel)
                            .frame(height: 550) // 增加高度以放大模型展示区域
                            .padding([.horizontal, .top])
                            .overlay(
                                Button(action: {
                                    modelToDelete = selectedModel
                                    showDeleteConfirmation = true
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                }
                                .padding(),
                                alignment: .topTrailing
                            )
                    } else if viewModel.isLoading {
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.themeColor))
                                .scaleEffect(1.5)
                                .padding(.bottom, 20)
                            
                            Text("正在生成模型...")
                                .font(.custom("MF DianHei", size: 20))
                                .foregroundColor(.gray)
                        }
                        .frame(height: 550) // 保持相同高度
                        .padding()
                    } else {
                        VStack {
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .foregroundColor(.gray)
                                .padding()
                            
                            Text("尚未创建模型")
                                .font(.custom("MF DianHei", size: 20))
                                .foregroundColor(.gray)
                            
                            if let error = viewModel.error {
                                Text(error)
                                    .font(.custom("MF DianHei", size: 14))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                    .padding(.top, 10)
                            } else {
                                Text("请先在个人中心设置身高体重")
                                    .font(.custom("MF DianHei", size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.top, 5)
                            }
                        }
                        .frame(height: 550) // 保持相同高度
                        .padding()
                    }
                    
                    Spacer() // 使用Spacer将按钮推到底部
                    
                    // 底部按钮区域 - 移到靠近菜单栏的位置
                    HStack(spacing: 20) {
                        // 重新生成模型按钮
                        Button(action: {
                            viewModel.generateModelFromUserProfile()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.system(size: 16))
                                Text("重新生成")
                            }
                            .primaryButtonStyle()
                        }
                        .frame(maxWidth: .infinity)
                        
                        // 我的模型按钮
                        Button(action: {
                            showingModelList = true
                        }) {
                            HStack {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 16))
                                Text("我的模型")
                            }
                            .primaryButtonStyle()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10) // 确保按钮与菜单栏有适当的间距
                }
                .navigationBarHidden(true)
                .onAppear {
                    if isFirstAppear {
                        viewModel.loadModels()
                        isFirstAppear = false
                    }
                }
                .onReceive(authViewModel.userInfoUpdated) {
                    // 用户信息更新后，重新生成模型
                    viewModel.handleUserInfoUpdate()
                }
            }
            .sheet(isPresented: $showingModelList) {
                ModelListView(viewModel: viewModel)
            }
            .alert("确认删除", isPresented: $showDeleteConfirmation) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    if let model = modelToDelete {
                        // 如果删除的是当前选中的模型，自动选择下一个
                        if viewModel.selectedModel?.id == model.id {
                            if let nextModel = viewModel.models.first(where: { $0.id != model.id }) {
                                viewModel.selectModel(nextModel)
                                // 强制重新加载模型场景
                                viewModel.modelScene = nil
                                viewModel.loadSceneForModel(nextModel)
                            }
                        }
                        viewModel.deleteModel(model)
                    }
                }
            } message: {
                Text("确定要删除这个模型吗？此操作无法撤销。")
            }
        }
    }
}

// 模型预览视图（使用SceneKit来展示3D模型）
struct ModelPreviewView: View {
    let model: Model3D
    @ObservedObject var viewModel: ModelViewModel
    
    // 用于交互状态
    @State private var modelRotation: Float = 0.0 // 改为Float记录Y轴累计旋转
    @State private var modelScale: CGFloat = 0.25 // 默认最小大小
    @State private var previousScale: CGFloat = 0.25
    
    // 控制状态
    @State private var isAutoRotating = false
    @State private var viewMode = "正面"
    
    // 缩放常量
    private let minScale: CGFloat = 0.25    // 最小25%
    private let maxScale: CGFloat = 1.0     // 最大100%
    private let defaultScale: CGFloat = 0.25 // 默认25%
    
    // 定时器
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.themeColor.opacity(0.1))
            
            VStack {
                // 只显示模型名称
                Text(model.name)
                    .font(.custom("MF DianHei", size: 24))
                    .foregroundColor(.textPrimary)
                    .padding(.top)
                
                // SceneKit 3D 模型视图
                GeometryReader { geometry in
                    ZStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color.themeColor))
                                .scaleEffect(1.5)
                        } else {
                            SceneView(
                                scene: viewModel.modelScene,
                                options: [.autoenablesDefaultLighting, .allowsCameraControl]
                            )
                            .gesture(
                                DragGesture()
                                    .onChanged { gesture in
                                        // 拖动时停止自动旋转
                                        isAutoRotating = false
                                        
                                        // 只响应水平方向的拖动，忽略垂直方向
                                        let horizontalDrag = gesture.translation.width
                                        
                                        // 大幅降低灵敏度 - 从0.01改为0.002
                                        let sensitivity: Float = 0.002
                                        let rotationDelta = Float(horizontalDrag) * sensitivity
                                        
                                        // 应用旋转到主模型节点
                                        if let modelNode = viewModel.modelScene?.rootNode.childNodes.first {
                                            modelNode.eulerAngles.y = modelRotation + rotationDelta
                                        }
                                    }
                                    .onEnded { gesture in
                                        // 保存最终旋转值
                                        let horizontalDrag = gesture.translation.width
                                        let sensitivity: Float = 0.002
                                        let rotationDelta = Float(horizontalDrag) * sensitivity
                                        modelRotation += rotationDelta
                                    }
                            )
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = previousScale * value
                                        modelScale = newScale
                                        
                                        // 限制缩放范围
                                        let limitedScale = min(max(modelScale, minScale), maxScale)
                                        
                                        // 应用缩放到主模型节点 - 使用新的缩放系统
                                        if let modelNode = viewModel.modelScene?.rootNode.childNodes.first {
                                            // 将0.25-1.0映射到合适的SceneKit缩放值
                                            let sceneKitScale = Float(limitedScale * 3.0) // 0.75-3.0的范围
                                            modelNode.scale = SCNVector3(x: sceneKitScale, y: sceneKitScale, z: sceneKitScale)
                                        }
                                    }
                                    .onEnded { value in
                                        // 限制缩放范围
                                        let limitedScale = min(max(modelScale, minScale), maxScale)
                                        previousScale = limitedScale
                                        modelScale = limitedScale
                                    }
                            )
                            
                            // 控制按钮层
                            VStack {
                                Spacer()
                                
                                // 视角控制按钮
                                HStack(spacing: 15) {
                                    // 自动旋转按钮
                                    Button(action: {
                                        isAutoRotating.toggle()
                                    }) {
                                        Image(systemName: isAutoRotating ? "pause.circle.fill" : "arrow.clockwise.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }
                                    
                                    // 重置视角按钮
                                    Button(action: {
                                        resetView()
                                    }) {
                                        Image(systemName: "arrow.counterclockwise.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .padding(8)
                                            .background(Color.black.opacity(0.5))
                                            .clipShape(Circle())
                                    }
                                    
                                    // 视角切换菜单
                                    Menu {
                                        Button("正面") { changeViewTo("正面") }
                                        Button("侧面") { changeViewTo("侧面") }
                                        Button("背面") { changeViewTo("背面") }
                                    } label: {
                                        HStack {
                                            Image(systemName: "eye.circle.fill")
                                                .font(.system(size: 24))
                                            Text(viewMode)
                                                .font(.system(size: 14))
                                        }
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .background(Color.black.opacity(0.5))
                                        .clipShape(Capsule())
                                    }
                                }
                                .padding(.bottom, 10)
                            }
                        }
                    }
                    .onReceive(timer) { _ in
                        if isAutoRotating, let modelNode = viewModel.modelScene?.rootNode.childNodes.first {
                            // 简单的连续旋转
                            let rotationSpeed: Float = 0.01
                            
                            // 使用SCNTransaction进行平滑过渡
                            SCNTransaction.begin()
                            SCNTransaction.animationDuration = 0.05
                            
                            // 应用连续旋转
                            modelNode.eulerAngles.y += rotationSpeed
                            
                            SCNTransaction.commit()
                        }
                    }
                }
                
                // 模型信息
                HStack {
                    VStack(alignment: .leading) {
                        Text("身高：\(model.height) cm")
                        Text("体重：\(model.weight) kg")
                    }
                    .font(.custom("MF DianHei", size: 16))
                    .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    // 缩放滑块
                    VStack {
                        Text("缩放")
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(.gray)
                        
                        HStack(spacing: 4) {
                            Button(action: {
                                adjustScale(-2.5) // 增大增量以适配新的范围
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Slider(value: $modelScale, in: minScale...maxScale) { _ in
                                updateModelScale()
                            }
                            .frame(width: 80)
                            
                            Button(action: {
                                adjustScale(2.5) // 增大增量以适配新的范围
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(width: 120)
                }
                .padding()
            }
        }
        .onAppear {
            // 检查是否已加载模型，如果没有则加载
            if viewModel.modelScene == nil {
                // 创建一个加载超时计时器
                let _ = Timer.scheduledTimer(withTimeInterval: 6.0, repeats: false) { _ in
                    if viewModel.isLoading {
                        viewModel.isLoading = false
                        viewModel.error = "生成错误，请重试"
                        // 重置模型场景
                        viewModel.modelScene = nil
                    }
                }
                
                // 开始加载模型
                viewModel.loadSceneForModel(model)
                
                // 延迟应用默认设置，确保模型已加载完成
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.applyDefaultSettings()
                }
            }
        }
    }
    
    // 重置视图到默认状态
    private func resetView() {
        // 重置UI状态
        isAutoRotating = false
        modelRotation = 0.0
        modelScale = defaultScale 
        previousScale = defaultScale
        viewMode = "正面"
        
        // 重新加载原始模型，并应用默认缩放
        viewModel.loadSceneForModel(model)
        
        // 延迟应用默认设置，确保模型已加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.applyDefaultSettings()
        }
    }
    
    // 切换视角
    private func changeViewTo(_ mode: String) {
        viewMode = mode
        isAutoRotating = false
        
        guard let modelNode = viewModel.modelScene?.rootNode.childNodes.first else { return }
        
        // 使用平滑动画切换视角
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.5
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        switch mode {
        case "正面":
            modelRotation = 0.0
            modelNode.eulerAngles.y = 0.0
        case "侧面":
            modelRotation = Float.pi / 2
            modelNode.eulerAngles.y = Float.pi / 2
        case "背面":
            modelRotation = Float.pi
            modelNode.eulerAngles.y = Float.pi
        default:
            break
        }
        
        SCNTransaction.commit()
    }
    
    // 应用默认设置
    private func applyDefaultSettings() {
        guard let modelNode = viewModel.modelScene?.rootNode.childNodes.first else { return }
        
        // 应用默认缩放（75%）
        let sceneKitScale = Float(defaultScale * 3.0) // 对应2.25的SceneKit缩放
        modelNode.scale = SCNVector3(x: sceneKitScale, y: sceneKitScale, z: sceneKitScale)
        
        // 确保模型朝向正面
        modelNode.eulerAngles.y = 0.0
        modelRotation = 0.0
    }
    
    // 调整缩放
    private func adjustScale(_ delta: CGFloat) {
        // delta已经在调用时考虑了合适的大小，这里直接使用
        modelScale = min(max(modelScale + delta * 0.05, minScale), maxScale) // 适当的增量步长
        previousScale = modelScale
        updateModelScale()
    }
    
    // 更新模型的缩放
    private func updateModelScale() {
        if let modelNode = viewModel.modelScene?.rootNode.childNodes.first {
            // 使用新的缩放系统
            let sceneKitScale = Float(modelScale * 3.0)
            modelNode.scale = SCNVector3(x: sceneKitScale, y: sceneKitScale, z: sceneKitScale)
        }
    }
}

// 创建模型表单
struct ModelFormView: View {
    @ObservedObject var viewModel: ModelViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var modelName: String
    @State private var height = ""
    @State private var weight = ""
    
    init(viewModel: ModelViewModel) {
        self.viewModel = viewModel
        // 设置默认模型名称
        let existingModels = viewModel.models.filter { $0.isCustom }
        if existingModels.isEmpty {
            _modelName = State(initialValue: "我的模型")
        } else {
            let count = existingModels.count + 1
            _modelName = State(initialValue: "我的模型\(count)")
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 标题和说明
                    VStack(spacing: 10) {
                        Text("创建3D模型")
                            .font(.custom("MF DianHei", size: 24))
                            .foregroundColor(.textPrimary)
                        
                        Text("请输入模型信息")
                            .font(.custom("MF DianHei", size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top)
                    
                    // 输入表单
                    VStack(alignment: .leading, spacing: 15) {
                        Text("模型名称")
                            .inputLabelStyle()
                        
                        TextField("输入模型名称", text: $modelName)
                            .inputFieldStyle()
                        
                        Text("身高 (cm)")
                            .inputLabelStyle()
                            .padding(.top, 10)
                        
                        TextField("输入身高", text: $height)
                            .keyboardType(.numberPad)
                            .inputFieldStyle()
                        
                        Text("体重 (kg)")
                            .inputLabelStyle()
                            .padding(.top, 10)
                        
                        TextField("输入体重", text: $weight)
                            .keyboardType(.numberPad)
                            .inputFieldStyle()
                    }
                    .padding(.horizontal)
                    
                    // 生成按钮
                    Button(action: {
                        guard let heightValue = Double(height), let weightValue = Double(weight) else { return }
                        
                        // 调用统一的模型生成方法，传入模型名称
                        viewModel.generateModel(name: modelName, height: Int(heightValue), weight: Int(weightValue), userId: nil)
                        
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("正在生成...")
                            }
                            .primaryButtonStyle()
                        } else {
                            Text("生成模型")
                                .primaryButtonStyle()
                        }
                    }
                    .padding(.horizontal, 50)
                    .padding(.top, 20)
                    .disabled(modelName.isEmpty || height.isEmpty || weight.isEmpty || viewModel.isLoading)
                    
                    // 错误信息显示
                    if let error = viewModel.error {
                        Text(error)
                            .font(.custom("MF DianHei", size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .padding(.top, 10)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("取消") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 我的模型列表视图
struct ModelListView: View {
    @ObservedObject var viewModel: ModelViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    if viewModel.models.filter({ $0.isCustom }).isEmpty {
                        VStack {
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray)
                                .padding()
                            
                            Text("暂无模型")
                                .font(.custom("MF DianHei", size: 20))
                                .foregroundColor(.gray)
                            
                            Text("请创建一个新模型")
                                .font(.custom("MF DianHei", size: 16))
                                .foregroundColor(.gray)
                                .padding(.top, 5)
                        }
                        .padding(.top, 50)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
                                ForEach(viewModel.models.filter { $0.isCustom }) { model in
                                    ModelGridItemView(
                                        model: model, 
                                        isSelected: viewModel.selectedModel?.id == model.id,
                                        onSelect: {
                                            viewModel.selectModel(model)
                                            presentationMode.wrappedValue.dismiss()
                                        },
                                        onDelete: {
                                            if viewModel.models.firstIndex(where: { $0.id == model.id }) != nil {
                                                // 如果删除的是当前选中的模型，自动选择下一个
                                                if viewModel.selectedModel?.id == model.id {
                                                    if let nextModel = viewModel.models.first(where: { $0.id != model.id }) {
                                                        viewModel.selectModel(nextModel)
                                                    }
                                                }
                                                viewModel.deleteModel(model)
                                            }
                                        }
                                    )
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("我的模型")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// 模型网格项视图
struct ModelGridItemView: View {
    let model: Model3D
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 15)
                    .fill(isSelected ? Color.themeColor : Color.themeColor.opacity(0.3))
                    .frame(height: 150)
                
                VStack {
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(isSelected ? .white : Color.themeColor)
                    
                    Text(model.name)
                        .font(.custom("MF DianHei", size: 14))
                        .foregroundColor(isSelected ? .white : .textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text("\(model.height)cm")
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                        
                        Text("\(model.weight)kg")
                            .font(.custom("MF DianHei", size: 12))
                            .foregroundColor(isSelected ? .white.opacity(0.8) : .gray)
                    }
                }
                .padding(.vertical, 10)
            }
            .overlay(
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .padding(6)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .padding(8),
                alignment: .topTrailing
            )
        }
        .onTapGesture {
            onSelect()
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("确定要删除这个模型吗？此操作无法撤销。")
        }
    }
}

struct ModelView_Previews: PreviewProvider {
    static var previews: some View {
        ModelView(authViewModel: AuthViewModel())
    }
} 
