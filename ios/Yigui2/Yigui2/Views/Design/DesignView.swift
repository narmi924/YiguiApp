import SwiftUI
import SceneKit
import GLTFSceneKit

struct DesignView: View {
    @StateObject private var viewModel = RealDesignViewModel()
    @State private var showingPatternSelection = false
    @State private var showingColorPicker = false
    @State private var showingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var showingProjectList = false
    @State private var showingDeleteConfirmation = false
    @State private var projectToDelete: DesignProject?
    @State private var showingPreviewSheet = false
    @State private var selectedFabric = "cotton"
    @State private var isApplyingPattern = false
    @State private var isGenerating3D = false
    @State private var patternApplied = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部标题
                        headerSection
                        
                        // 主要内容区域 - 现在占满整个屏幕
                        if viewModel.projects.isEmpty {
                            // 欢迎页面
                            welcomeSection
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            // 设计工作台 - 单栏布局
                            VStack(spacing: 30) {
                                // 顶部项目信息栏
                                if let currentProject = viewModel.currentProject {
                                    projectInfoSection(for: currentProject)
                                        .padding(.horizontal, 20)
                                }
                                
                                // 设计工具区域 - 现在占满整个空间
                                designToolsSection
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 20)
                                
                                Spacer()
                            }
                            .padding(.top, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.loadData()
            }
        }
        .sheet(isPresented: $showingPatternSelection) {
            PatternSelectionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $viewModel.selectedColor)
        }
        .sheet(isPresented: $showingNewProjectSheet) {
            NewProjectSheet(
                projectName: $newProjectName,
                existingNames: viewModel.projects.map { $0.projectName },
                onCreate: { name in
                    viewModel.createNewProject(name: name)
                    showingNewProjectSheet = false
                    newProjectName = ""
                }
            )
        }
        .sheet(isPresented: $showingProjectList) {
            ProjectListSheet(viewModel: viewModel, onDelete: { project in
                projectToDelete = project
                showingDeleteConfirmation = true
            })
        }
        .alert("删除设计", isPresented: $showingDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                if let project = projectToDelete {
                    viewModel.deleteProject(project)
                }
            }
        } message: {
            Text("确定要删除这个设计吗？此操作无法撤销。")
        }
        .sheet(isPresented: $showingPreviewSheet) {
            PreviewSheet(
                currentProject: viewModel.currentProject,
                onDismiss: {
                    showingPreviewSheet = false
                }
            )
        }
    }
    
    // MARK: - 页面组件
    
    private var headerSection: some View {
        VStack(spacing: 20) {
            // YigUi标题
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
            
            // 设计工作台标题
            HStack {
                Text("设计工作台")
                    .font(.custom("MF DianHei", size: 24))
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)
            }
        }
        .padding(.bottom, 30)
    }
    
    private var welcomeSection: some View {
        VStack(spacing: 30) {
            // 欢迎区域
            VStack(spacing: 20) {
                Text("开始你的设计之旅")
                    .font(.custom("MF DianHei", size: 28))
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)
                
                Text("创建新设计或打开已有项目")
                    .font(.custom("MF DianHei", size: 16))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 40)
            
            // 操作按钮
            HStack(spacing: 20) {
                Button("新建设计") {
                    showingNewProjectSheet = true
                }
                .primaryButtonStyle()
                
                Button("打开设计") {
                    showingProjectList = true
                }
                .secondaryButtonStyle()
            }
            
            // 项目列表预览
            if !viewModel.projects.isEmpty {
                recentProjectsSection
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var recentProjectsSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("最近的设计")
                    .font(.custom("MF DianHei", size: 18))
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                ForEach(Array(viewModel.projects.prefix(4).enumerated()), id: \.element.id) { index, project in
                    ProjectCard(project: project) {
                        viewModel.selectProject(project)
                    }
                }
            }
        }
        .padding(.top, 30)
    }
    
    private func projectInfoSection(for project: DesignProject) -> some View {
        VStack(spacing: 15) {
            HStack {
                Text(project.projectName)
                    .font(.custom("MF DianHei", size: 24))
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(statusText(project.status))
                    .font(.custom("MF DianHei", size: 14))
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 15) {
                Button("项目") {
                    showingProjectList = true
                }
                .font(.title2)
                
                Button("保存") {
                    // 保存项目
                }
                .font(.title2)
                .disabled(viewModel.isLoading)
                
                Spacer()
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(15)
    }
    
    private var designToolsSection: some View {
        VStack(spacing: 25) {
            // 纸样选择
            DesignToolCard(
                icon: "",
                title: "选择纸样",
                description: viewModel.selectedPattern?.name ?? "未选择"
            ) {
                showingPatternSelection = true
            }
            
            // 颜色选择
            DesignToolCard(
                icon: "",
                title: "选择颜色",
                description: "点击选择颜色",
                color: viewModel.selectedColor
            ) {
                showingColorPicker = true
            }
            
            // 面料选择
            FabricSelectionCard(
                selectedFabric: selectedFabric,
                onSelect: { fabric in
                    selectedFabric = fabric
                }
            )
            
            // 操作按钮区域 - 居中显示
            VStack(spacing: 20) {
                if viewModel.selectedPattern != nil {
                    // 应用裁剪按钮
                    Button(action: {
                        isApplyingPattern = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            viewModel.applySelectedPattern()
                            patternApplied = true
                            isApplyingPattern = false
                        }
                    }) {
                        HStack {
                            if isApplyingPattern {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .foregroundColor(.white)
                            }
                            Text(isApplyingPattern ? "正在应用裁剪..." : (patternApplied ? "裁剪已应用 ✓" : "应用裁剪"))
                        }
                    }
                    .primaryButtonStyle()
                    .disabled(viewModel.isLoading || isApplyingPattern)
                    
                    // 生成3D预览按钮
                    if patternApplied {
                        Button(action: {
                            isGenerating3D = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                viewModel.generate3DPreview()
                                isGenerating3D = false
                            }
                        }) {
                            HStack {
                                if isGenerating3D {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .foregroundColor(.white)
                                }
                                Text(isGenerating3D ? "正在生成3D预览..." : "生成3D预览")
                            }
                        }
                        .secondaryButtonStyle()
                        .disabled(viewModel.isLoading || viewModel.isGenerating || isGenerating3D)
                    }
                }
                
                // 查看3D预览按钮 - 一直显示
                Button("查看3D预览") {
                    showingPreviewSheet = true
                }
                .accentButtonStyle()
            }
            .padding(.horizontal, 40)
            .frame(maxWidth: .infinity)
            
            // 生成进度显示
            if viewModel.isGenerating {
                GenerationProgressCard(
                    progress: viewModel.generationProgress,
                    status: "处理中"
                )
            }
        }
    }
    
    private func statusText(_ status: String) -> String {
        switch status {
        case "draft": return "草稿"
        case "processing": return "处理中"
        case "completed": return "已完成"
        default: return "未知"
        }
    }
}

// MARK: - 设计工具卡片

struct DesignToolCard: View {
    let icon: String
    let title: String
    let description: String
    var color: Color?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.custom("MF DianHei", size: 16))
                        .foregroundColor(.textPrimary)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if let color = color {
                        Circle()
                            .fill(color)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
                
                Text(description)
                    .font(.custom("MF DianHei", size: 14))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(15)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 项目卡片

struct ProjectCard: View {
    let project: DesignProject
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    Text(statusEmoji(project.status))
                        .font(.caption)
                }
                
                Text(project.projectName)
                    .font(.custom("MF DianHei", size: 16))
                    .foregroundColor(.textPrimary)
                    .lineLimit(1)
                
                Text(formatDate(project.updatedAtDate))
                    .font(.custom("MF DianHei", size: 12))
                    .foregroundColor(.gray)
            }
            .padding(15)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func statusEmoji(_ status: String) -> String {
        switch status {
        case "draft": return "草稿"
        case "processing": return "处理中"
        case "completed": return "完成"
        default: return "未知"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 新建项目表单

struct NewProjectSheet: View {
    @Binding var projectName: String
    let existingNames: [String]
    let onCreate: (String) -> Void
    @Environment(\.presentationMode) var presentationMode
    @State private var showingNameError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 20) {
                    Text("创建新设计")
                        .font(.custom("MF DianHei", size: 24))
                        .foregroundColor(.textPrimary)
                        .fontWeight(.medium)
                }
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("设计名称")
                        .font(.custom("MF DianHei", size: 16))
                        .foregroundColor(.textPrimary)
                    
                    TextField("请输入设计名称", text: $projectName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.custom("MF DianHei", size: 16))
                    
                    if showingNameError {
                        Text(errorMessage)
                            .font(.custom("MF DianHei", size: 14))
                            .foregroundColor(.red)
                    }
                }
                
                HStack(spacing: 20) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .secondaryButtonStyle()
                    
                    Button("创建") {
                        validateAndCreate()
                    }
                    .primaryButtonStyle()
                    .disabled(projectName.isEmpty)
                }
                
                Spacer()
            }
            .padding(30)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func validateAndCreate() {
        // 检查是否为空
        guard !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "设计名称不能为空"
            showingNameError = true
            return
        }
        
        // 检查是否重名
        if existingNames.contains(projectName) {
            errorMessage = "该名称已存在，请选择其他名称"
            showingNameError = true
            return
        }
        
        // 重置错误状态
        showingNameError = false
        
        // 创建项目
        onCreate(projectName)
    }
}

// MARK: - 项目列表

struct ProjectListSheet: View {
    @ObservedObject var viewModel: RealDesignViewModel
    let onDelete: (DesignProject) -> Void
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.projects) { project in
                    ProjectListRow(project: project) {
                        viewModel.selectProject(project)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("删除", role: .destructive) {
                            onDelete(project)
                        }
                    }
                }
            }
            .navigationTitle("我的设计")
            .navigationBarItems(trailing: Button("完成") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

struct ProjectListRow: View {
    let project: DesignProject
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(project.projectName)
                        .font(.custom("MF DianHei", size: 16))
                        .foregroundColor(.textPrimary)
                    
                    Text("更新于 \(formatDate(project.updatedAtDate))")
                        .font(.custom("MF DianHei", size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(statusEmoji(project.status))
                    .font(.title3)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func statusEmoji(_ status: String) -> String {
        switch status {
        case "draft": return "草稿"
        case "processing": return "处理中"
        case "completed": return "完成"
        default: return "未知"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - 面料选择卡片

struct FabricSelectionCard: View {
    let selectedFabric: String
    let onSelect: (String) -> Void
    
    let fabrics = [
        ("cotton", "棉布"),
        ("silk", "丝绸"), 
        ("denim", "牛仔"),
        ("linen", "亚麻"),
        ("wool", "羊毛")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("选择面料")
                    .font(.custom("MF DianHei", size: 16))
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("当前: \(fabricName(selectedFabric))")
                    .font(.custom("MF DianHei", size: 14))
                    .foregroundColor(.gray)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(fabrics, id: \.0) { fabric in
                    Button(fabric.1) {
                        onSelect(fabric.0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedFabric == fabric.0 ? Color.themeColor : Color.gray.opacity(0.1))
                    )
                    .foregroundColor(selectedFabric == fabric.0 ? .white : .textPrimary)
                    .font(.custom("MF DianHei", size: 14))
                }
            }
        }
        .padding(15)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func fabricName(_ fabric: String) -> String {
        switch fabric {
        case "cotton": return "棉布"
        case "silk": return "丝绸"
        case "denim": return "牛仔"
        case "linen": return "亚麻"
        case "wool": return "羊毛"
        default: return fabric
        }
    }
}

// MARK: - 生成进度卡片

struct GenerationProgressCard: View {
    let progress: Int
    let status: String
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("正在生成")
                    .font(.custom("MF DianHei", size: 18))
                    .foregroundColor(.textPrimary)
                    .fontWeight(.medium)
            }
            
            VStack(spacing: 15) {
                ProgressView(value: Double(progress), total: 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .themeColor))
                
                Text("\(progress)% 完成")
                    .font(.custom("MF DianHei", size: 16))
                    .foregroundColor(.textPrimary)
                
                Text(statusText(status))
                    .font(.custom("MF DianHei", size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func statusText(_ status: String) -> String {
        switch status {
        case "pending": return "等待中..."
        case "processing": return "处理中..."
        case "completed": return "完成"
        case "failed": return "失败"
        default: return status
        }
    }
}

// MARK: - 3D模型预览卡片

struct ModelPreviewCard: View {
    let glbUrl: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.gray.opacity(0.1))
            
            VStack(spacing: 15) {
                Text("3D模型预览")
                    .font(.custom("MF DianHei", size: 16))
                    .foregroundColor(.textPrimary)
                
                Text("点击查看完整模型")
                    .font(.custom("MF DianHei", size: 12))
                    .foregroundColor(.gray)
            }
        }
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .onTapGesture {
            // 这里可以打开全屏3D预览
            print("打开3D预览: \(glbUrl)")
        }
    }
}

// MARK: - 3D预览弹窗

struct PreviewSheet: View {
    let currentProject: DesignProject?
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // 顶部标题
                    HStack {
                        Text("3D预览")
                            .font(.custom("MF DianHei", size: 24))
                            .foregroundColor(.textPrimary)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("完成") {
                            onDismiss()
                        }
                        .font(.custom("MF DianHei", size: 16))
                        .foregroundColor(.themeColor)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // 预览区域
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        if let project = currentProject, let glbUrl = project.glbUrl {
                            // 如果有3D模型，显示预览
                            ModelPreviewCard(glbUrl: glbUrl)
                        } else {
                            // 没有内容时显示空白
                            Color.clear
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - ViewModifier扩展

extension View {
    func accentButtonStyle() -> some View {
        self
            .font(.custom("MF DianHei", size: 16))
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 12)
            .background(Color.green)
            .cornerRadius(25)
    }
}

// MARK: - DesignProject扩展

extension DesignProject {
    var updatedAtDate: Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: updatedAt) ?? Date()
    }
}

#Preview {
    DesignView()
} 