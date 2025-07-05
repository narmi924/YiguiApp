import Foundation
import Combine
import SwiftUI

class RealDesignViewModel: ObservableObject {
    @Published var projects: [DesignProject] = []
    @Published var patterns: [Pattern] = []
    @Published var patternCategories: [String] = []
    @Published var currentProject: DesignProject?
    @Published var selectedPattern: Pattern?
    @Published var selectedColor: Color = .white
    @Published var selectedFabricTexture: String = "cotton"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // 任务状态跟踪
    @Published var currentTask: TaskStatus?
    @Published var generationProgress: Int = 0
    @Published var isGenerating = false
    
    // 新增：直接3D生成相关
    @Published var generated3DModelURL: URL?
    @Published var showGenerated3DModel = false
    @Published var selectedGarmentType: String = "shirt" // shirt, pants, dress
    
    private let designService = DesignService()
    private var cancellables = Set<AnyCancellable>()
    private var taskPollingCancellable: AnyCancellable?
    
    init() {
        loadData()
    }
    
    // MARK: - 数据加载
    
    func loadData() {
        loadProjects()
        loadPatterns()
        loadPatternCategories()
    }
    
    func loadProjects() {
        isLoading = true
        
        designService.getUserProjects()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] projects in
                    self?.projects = projects
                }
            )
            .store(in: &cancellables)
    }
    
    func loadPatterns(category: String? = nil) {
        designService.getPatterns(category: category)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] patterns in
                    self?.patterns = patterns
                }
            )
            .store(in: &cancellables)
    }
    
    func loadPatternCategories() {
        designService.getPatternCategories()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to load pattern categories: \(error)")
                    }
                },
                receiveValue: { [weak self] categories in
                    self?.patternCategories = categories
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 项目管理
    
    func createNewProject(name: String) {
        print("🚀 开始创建新项目: \(name)")
        
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            print("❌ 项目名称为空")
            handleError(DesignError.invalidProjectName)
            return
        }
        
        isLoading = true
        
        // 检查是否启用Mock模式（用于调试）
        let enableMockMode = UserDefaults.standard.bool(forKey: "enableMockMode")
        
        if enableMockMode {
            print("🎭 使用Mock模式创建项目")
            // 模拟延迟和成功响应
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let mockProject = DesignProject(
                    id: Int.random(in: 1000...9999),
                    projectName: name,
                    modelId: 1,
                    status: "draft",
                    uuidFilename: nil,
                    glbUrl: nil,
                    thumbnailUrl: nil,
                    taskId: nil,
                    createdAt: ISO8601DateFormatter().string(from: Date()),
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )
                print("✅ Mock项目创建成功: \(mockProject.projectName) (ID: \(mockProject.id))")
                self.currentProject = mockProject
                self.projects.append(mockProject)
                self.isLoading = false
                print("📱 当前项目已设置，项目列表已更新")
            }
            return
        }
        
        // 获取用户当前的模型ID（简化处理，使用默认值）
        let modelId = getCurrentUserModelId()
        print("📋 使用模型ID: \(modelId ?? 1)")
        
        designService.createProject(name: name, modelId: modelId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    print("🔄 创建项目完成回调")
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        print("❌ 创建项目失败: \(error.localizedDescription)")
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] project in
                    print("✅ 项目创建成功: \(project.projectName) (ID: \(project.id))")
                    self?.currentProject = project
                    self?.loadProjects() // 重新加载项目列表
                    print("📱 当前项目已设置，项目列表重新加载")
                }
            )
            .store(in: &cancellables)
    }
    
    func selectProject(_ project: DesignProject) {
        currentProject = project
    }
    
    func deleteProject(_ project: DesignProject) {
        designService.deleteProject(projectId: project.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadProjects()
                    if self?.currentProject?.id == project.id {
                        self?.currentProject = nil
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - 纸样应用
    
    func applySelectedPattern() {
        guard let project = currentProject,
              let pattern = selectedPattern else {
            handleError(DesignError.missingData)
            return
        }
        
        isLoading = true
        
        let colorHex = selectedColor.toHex()
        
        designService.applyPatternToProject(
            projectId: project.id,
            patternId: pattern.id,
            fabricTexture: selectedFabricTexture,
            colorHex: colorHex
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            },
            receiveValue: { [weak self] success in
                if success {
                    self?.showMessage("纸样应用成功")
                }
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - 3D生成（原有的项目式生成）
    
    func generate3DPreview() {
        guard let project = currentProject else {
            handleError(DesignError.noProjectSelected)
            return
        }
        
        isGenerating = true
        generationProgress = 0
        
        designService.generate3DPreview(projectId: project.id)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.isGenerating = false
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] taskStatus in
                    self?.currentTask = taskStatus
                    self?.startTaskPolling(taskId: taskStatus.taskId)
                }
            )
            .store(in: &cancellables)
    }
    
    private func startTaskPolling(taskId: String) {
        taskPollingCancellable?.cancel()
        
        taskPollingCancellable = designService.pollTaskStatus(taskId: taskId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isGenerating = false
                    if case .failure(let error) = completion {
                        self?.handleError(error)
                    }
                },
                receiveValue: { [weak self] taskStatus in
                    self?.currentTask = taskStatus
                    self?.generationProgress = taskStatus.progress
                    
                    if taskStatus.status == "completed" {
                        self?.isGenerating = false
                        self?.loadProjects() // 重新加载以获取最新的GLB URL
                        self?.showMessage("3D模型生成完成！")
                    } else if taskStatus.status == "failed" {
                        self?.isGenerating = false
                        self?.handleError(DesignError.generationFailed(taskStatus.errorMessage ?? "未知错误"))
                    }
                }
            )
    }
    
    // MARK: - 新增：直接3D生成
    
    func generateDirect3DClothing() {
        print("🎨 开始直接生成3D服装: 类型=\(selectedGarmentType), 颜色=\(selectedColor)")
        
        isGenerating = true
        generationProgress = 10
        showGenerated3DModel = false
        generated3DModelURL = nil
        
        // 将SwiftUI Color转换为RGB数组
        let fabricColorRGB = selectedColor.toRGB()
        
        Task {
            do {
                // 调用新的设计服务器API
                let modelURL = try await designService.generateAndDownload3DClothing(
                    garmentType: selectedGarmentType,
                    fabricColor: fabricColorRGB
                )
                
                await MainActor.run {
                    self.generated3DModelURL = modelURL
                    self.showGenerated3DModel = true
                    self.isGenerating = false
                    self.generationProgress = 100
                    self.showMessage("3D服装生成成功！")
                    print("✅ 3D模型已生成并保存到: \(modelURL.path)")
                }
            } catch {
                await MainActor.run {
                    self.isGenerating = false
                    self.generationProgress = 0
                    self.handleError(error)
                    print("❌ 3D生成失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - 服装类型选择
    
    func selectGarmentType(_ type: String) {
        selectedGarmentType = type
        print("👔 选择服装类型: \(type)")
    }
    
    var availableGarmentTypes: [(String, String, String)] {
        [
            ("shirt", "衬衫", "👔"),
            ("pants", "裤子", "👖"),
            ("dress", "连衣裙", "👗")
        ]
    }
    
    // MARK: - 颜色和面料
    
    var selectedColorHex: String {
        selectedColor.toHex()
    }
    
    func selectColor(_ color: Color) {
        selectedColor = color
    }
    
    func selectFabricTexture(_ texture: String) {
        selectedFabricTexture = texture
    }
    
    // MARK: - 辅助方法
    
    private func getCurrentUserModelId() -> Int? {
        // 从UserDefaults获取当前用户的模型ID
        // 这里简化处理，可以根据实际需求扩展
        return UserDefaults.standard.object(forKey: "currentModelId") as? Int ?? 1
    }
    
    // MARK: - 错误处理
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    private func showMessage(_ message: String) {
        // 这里可以用通知或其他方式显示成功消息
        print("Success: \(message)")
    }
}

// MARK: - 设计错误
enum DesignError: LocalizedError {
    case missingData
    case noProjectSelected
    case generationFailed(String)
    case invalidProjectName
    
    var errorDescription: String? {
        switch self {
        case .missingData:
            return "缺少必要的数据"
        case .noProjectSelected:
            return "请先选择一个项目"
        case .generationFailed(let message):
            return "生成失败: \(message)"
        case .invalidProjectName:
            return "项目名称不能为空"
        }
    }
}

// MARK: - Color扩展
extension Color {
    func toHex() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let rgb = Int(red * 255) << 16 | Int(green * 255) << 8 | Int(blue * 255)
        return String(format: "#%06x", rgb)
    }
    
    func toRGB() -> [Int] {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return [
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        ]
    }
} 