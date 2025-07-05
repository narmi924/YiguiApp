import Foundation
import Combine
import SwiftUI
import SceneKit

class ModelViewModel: ObservableObject {
    @Published var models: [Model3D] = []
    @Published var selectedModel: Model3D?
    @Published var isLoading = false
    @Published var error: String?
    @Published var modelScene: SCNScene?
    
    // 异步生成相关属性
    @Published var isGenerating = false
    @Published var generationProgress: Int = 0
    @Published var generationStatus: String = ""
    @Published var currentTaskId: String?
    
    // 模型生成服务
    private var modelGenerationService: ModelGenerationService?
    
    // 轮询任务
    private var pollingTask: Task<Void, Never>?
    
    init() {
        // 尝试初始化模型生成服务
        do {
            self.modelGenerationService = try ModelGenerationService()
        } catch {
            self.error = "初始化模型生成服务失败: \(error.localizedDescription)"
        }
        
        // 初始化缓存服务（用于调试路径信息）
        let _ = ModelCacheService.shared
        print("🚀 ModelViewModel初始化完成")
    }
    
    // 当用户输入身高和体重时，生成模型（新的异步版本）
    func generateModel(name: String? = nil, height: Int, weight: Int, userId: String?, nickname: String? = nil) {
        let modelName = name ?? "我的模型_\(height)cm_\(weight)kg"
        print("🔄 开始异步生成模型：\(modelName)，身高\(height)cm，体重\(weight)kg")
        
        // 重置状态
        isGenerating = true
        isLoading = true
        generationProgress = 0
        generationStatus = "正在提交生成任务..."
        error = nil
        currentTaskId = nil
        
        // 确保服务可用
        guard let generationService = modelGenerationService else {
            print("❌ 模型生成服务不可用")
            isGenerating = false
            isLoading = false
            error = "模型生成服务不可用，请重启应用"
            return
        }
        
        // 获取用户昵称和性别
        var userNickname = nickname ?? "defaultuser"
        var userGender = "male"  // 默认性别
        if userNickname == "defaultuser", let userData = UserDefaults.standard.data(forKey: "user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            userNickname = user.nickname
            userGender = user.gender
        } else if let userData = UserDefaults.standard.data(forKey: "user"),
                  let user = try? JSONDecoder().decode(User.self, from: userData) {
            // 即使nickname不是默认值，也要获取用户的性别
            userGender = user.gender
        }
        
        print("🔍 模型生成参数 - 昵称: \(userNickname), 性别: \(userGender)")
        
        // 创建异步任务
        Task {
            do {
                // 第1步：提交生成任务，获取task_id
                let taskId = try await generationService.generateModelAsync(
                    height: Double(height),
                    weight: Double(weight),
                    nickname: userNickname,
                    gender: userGender
                )
                
                await MainActor.run {
                    self.currentTaskId = taskId
                    self.generationProgress = 10
                    self.generationStatus = "任务已提交，开始生成模型..."
                    print("✅ 获得task_id: \(taskId)")
                }
                
                // 第2步：开始轮询任务状态
                try await startPolling(taskId: taskId, nickname: userNickname, modelName: modelName, height: height, weight: weight, userId: userId)
                
            } catch {
                await MainActor.run {
                    print("❌ 模型生成失败：\(error.localizedDescription)")
                    self.error = "生成模型失败: \(error.localizedDescription)"
                    self.isGenerating = false
                    self.isLoading = false
                    self.generationStatus = ""
                }
            }
        }
    }
    
    // 开始轮询任务状态
    private func startPolling(taskId: String, nickname: String, modelName: String, height: Int, weight: Int, userId: String?) async throws {
        // 取消之前的轮询任务
        pollingTask?.cancel()
        
        pollingTask = Task {
            guard let generationService = modelGenerationService else { return }
            
            while !Task.isCancelled {
                do {
                    // 轮询任务状态
                    let taskStatus = try await generationService.pollTaskStatus(nickname: nickname, taskId: taskId)
                    
                    await MainActor.run {
                        // 更新进度
                        if let progress = taskStatus.progress {
                            self.generationProgress = progress
                        } else {
                            // 如果没有明确的进度，根据状态估算
                            switch taskStatus.status.lowercased() {
                            case "pending":
                                self.generationProgress = 15
                            case "processing", "running":
                                self.generationProgress = min(self.generationProgress + 5, 80) // 缓慢增长
                            case "completed":
                                self.generationProgress = 100
                            default:
                                break
                            }
                        }
                        
                        // 更新状态消息
                        if let message = taskStatus.message {
                            self.generationStatus = message
                        } else {
                            switch taskStatus.status.lowercased() {
                            case "pending":
                                self.generationStatus = "任务排队中..."
                            case "processing", "running":
                                self.generationStatus = "正在生成模型... \(self.generationProgress)%"
                            case "completed":
                                self.generationStatus = "生成完成，正在下载模型..."
                            case "failed":
                                self.generationStatus = "生成失败"
                            default:
                                self.generationStatus = "状态: \(taskStatus.status)"
                            }
                        }
                    }
                    
                    // 检查是否完成
                    if taskStatus.status.lowercased() == "completed" {
                        // 处理完成状态
                        try await handleGenerationComplete(taskStatus: taskStatus, modelName: modelName, height: height, weight: weight, userId: userId)
                        break
                    } else if taskStatus.status.lowercased() == "failed" {
                        await MainActor.run {
                            self.error = "模型生成失败: \(taskStatus.message ?? "未知错误")"
                            self.isGenerating = false
                            self.isLoading = false
                            self.generationStatus = ""
                        }
                        break
                    }
                    
                    // 等待2-3秒后继续轮询
                    try await Task.sleep(nanoseconds: 2_500_000_000) // 2.5秒
                    
                } catch {
                    if !Task.isCancelled {
                        await MainActor.run {
                            print("❌ 轮询失败：\(error.localizedDescription)")
                            self.error = "轮询任务状态失败: \(error.localizedDescription)"
                            self.isGenerating = false
                            self.isLoading = false
                            self.generationStatus = ""
                        }
                    }
                    break
                }
            }
        }
    }
    
    // 处理生成完成
    private func handleGenerationComplete(taskStatus: TaskStatusResponse, modelName: String, height: Int, weight: Int, userId: String?) async throws {
        guard let generationService = modelGenerationService else { return }
        
        await MainActor.run {
            self.generationStatus = "生成完成，正在下载模型文件..."
            self.generationProgress = 90
        }
        
        print("🔍 完整的任务状态响应: \(taskStatus)")
        
        // 检查是否有URL
        guard let modelUrl = taskStatus.url, !modelUrl.isEmpty else {
            print("❌ 调试信息：taskStatus.url = \(String(describing: taskStatus.url))")
            
            await MainActor.run {
                // 提供更详细的错误信息
                if taskStatus.url == nil {
                    self.error = "服务器响应格式错误：缺少 'url' 字段。请联系开发者检查服务器端配置。"
                } else {
                    self.error = "服务器返回了空的模型文件URL。请稍后重试。"
                }
                self.isGenerating = false
                self.isLoading = false
                self.generationStatus = ""
                
                // 添加更多调试信息
                print("❌ 任务完成但无法获取模型文件URL")
                print("   - 任务状态: \(taskStatus.status)")
                print("   - URL字段: \(String(describing: taskStatus.url))")
                print("   - 进度: \(String(describing: taskStatus.progress))")
                print("   - 消息: \(String(describing: taskStatus.message))")
            }
            return
        }
        
        print("📦 收到模型URL: \(modelUrl)")
        
        // 验证URL有效性
        guard URL(string: modelUrl) != nil else {
            await MainActor.run {
                self.error = "服务器返回的模型文件URL无效：\(modelUrl)"
                self.isGenerating = false
                self.isLoading = false
                self.generationStatus = ""
            }
            return
        }
        
        do {
            // 下载单个模型文件
            let localModelURL = try await generationService.downloadGLBFile(glbUrl: modelUrl)
            
            await MainActor.run {
                self.generationProgress = 100
                self.generationStatus = "下载完成，正在保存到缓存..."
                
                // 🚀 将下载的模型保存到缓存
                if let userData = UserDefaults.standard.data(forKey: "user"),
                   let user = try? JSONDecoder().decode(User.self, from: userData) {
                    
                    do {
                        let modelData = try Data(contentsOf: localModelURL)
                        ModelCacheService.shared.saveModelToCache(data: modelData, for: user)
                        print("💾 新模型已保存到缓存")
                    } catch {
                        print("⚠️ 保存模型到缓存失败: \(error.localizedDescription)")
                        // 缓存失败不影响正常流程
                    }
                }
                
                self.generationStatus = "正在加载模型..."
                
                // 创建新模型记录
                let model = Model3D(
                    name: modelName,
                    height: height,
                    weight: weight,
                    modelURL: localModelURL,
                    thumbnailURL: nil,
                    isCustom: true,
                    userId: userId
                )
                
                print("📝 模型已添加到列表，当前模型数量：\(self.models.count + 1)")
                
                // 添加到模型列表
                self.models.append(model)
                self.selectedModel = model
                
                // 加载模型文件
                self.loadModel(from: localModelURL)
                
                // 保存模型数据
                self.saveModels()
                
                // 完成生成流程
                self.isGenerating = false
                self.isLoading = false
                self.generationStatus = ""
                
                print("✅ 异步模型生成完成")
            }
        } catch {
            await MainActor.run {
                print("❌ 下载模型文件失败：\(error.localizedDescription)")
                self.error = "下载模型文件失败: \(error.localizedDescription)"
                self.isGenerating = false
                self.isLoading = false
                self.generationStatus = ""
            }
        }
    }
    
    // 停止轮询
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isGenerating = false
        generationStatus = ""
        currentTaskId = nil
    }
    
    // 删除模型
    func deleteModel(_ model: Model3D) {
        // 从列表中移除模型
        models.removeAll { $0.id == model.id }
        
        // 如果删除的是当前选中的模型，则重新选择
        if selectedModel?.id == model.id {
            selectedModel = models.first
        }
        
        // 保存更新后的模型列表
        saveModels()
    }
    
    // 从用户个人资料自动生成模型
    func generateModelFromUserProfile() {
        // 防止重复调用
        guard !isGenerating else {
            return
        }
        
        if let userData = UserDefaults.standard.data(forKey: "user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            
            // 验证身高体重数据的有效性
            guard let height = user.height, let weight = user.weight,
                  height > 50 && height < 250,  // 身高范围：50-250cm
                  weight > 20 && weight < 300   // 体重范围：20-300kg
            else {
                self.error = "请先在个人中心设置有效的身高体重信息"
                return
            }
            
            // 首先检查缓存中是否有有效的模型
            if let cachedModelData = ModelCacheService.shared.loadModelDataFromCache(for: user) {
                loadModelFromCachedData(cachedModelData, for: user)
                return
            }
            
            // 设置生成标志，防止重复调用
            isGenerating = true
            
            print("🔄 开始生成新模型")
            
            // 删除用户所有现有的自定义模型（确保每用户只有一个模型，且支持性别变化）
            let userModels = models.filter { $0.isCustom }
            for oldModel in userModels {
                models.removeAll { $0.id == oldModel.id }
            }
            
            // 如果缓存无效，则从网络生成新模型
            generateModel(height: height, weight: weight, userId: user.id, nickname: user.nickname)
        } else {
            // 检查是否是用户已退出登录的情况
            let isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
            if !isLoggedIn {
                // 用户未登录，清空自定义模型
                models.removeAll { $0.isCustom }
                self.error = nil // 不显示错误信息
            } else {
                self.error = "请先在个人中心设置有效的身高体重信息"
            }
        }
    }
    
    // 处理用户信息更新后的模型重新生成
    func handleUserInfoUpdate() {
        // 重新从用户资料生成模型
        generateModelFromUserProfile()
    }
    
    // 加载模型列表
    func loadModels() {
        isLoading = true
        
        // 首先从本地存储加载数据
        if let savedModels = loadSavedModels() {
            // 过滤掉无效的模型（文件不存在的）
            let validModels = savedModels.filter { model in
                if model.isCustom {
                    // 对于自定义模型，检查文件是否存在
                    return model.modelURL != nil
                } else {
                    // 对于非自定义模型，保留
                    return true
                }
            }
            
            // 如果有无效模型被移除，更新保存的数据
            if validModels.count != savedModels.count {
                self.models = validModels
                saveModels() // 保存清理后的数据
            } else {
                self.models = validModels
            }
            
            // 如果列表为空或者没有选中的模型，尝试从用户资料生成
            if self.models.isEmpty || self.selectedModel == nil {
                generateModelFromUserProfile()
            } else if self.selectedModel == nil && !self.models.isEmpty {
                // 如果有模型但没有选中的模型，选择第一个自定义模型
                self.selectedModel = self.models.filter { $0.isCustom }.first
            }
            
            // 为选中的模型加载场景
            if let model = self.selectedModel {
                loadSceneForModel(model)
            }
            
            isLoading = false
            return
        }
        
        // 如果没有本地数据，尝试从用户资料生成模型
        generateModelFromUserProfile()
        
        isLoading = false
    }
    
    // 选择模型
    func selectModel(_ model: Model3D) {
        self.selectedModel = model
        // 直接加载对应的场景
        loadSceneForModel(model)
    }
    
    // 为模型加载对应的场景
    func loadSceneForModel(_ model: Model3D) {
        // 设置正在加载标志
        self.isLoading = true
        
        // 如果有真实模型URL，尝试加载模型
        if let modelURL = model.modelURL {
            loadModel(from: modelURL)
        } else {
            // 如果没有模型URL，显示错误
            DispatchQueue.main.async {
                self.error = "该模型没有有效的3D文件，请重新生成模型"
                self.isLoading = false
                self.modelScene = nil
            }
        }
    }
    
    // 保存模型数据到本地
    private func saveModels() {
        if let encodedModels = try? JSONEncoder().encode(models) {
            UserDefaults.standard.set(encodedModels, forKey: "models")
        }
    }
    
    // 从本地加载保存的模型数据
    private func loadSavedModels() -> [Model3D]? {
        if let savedModels = UserDefaults.standard.data(forKey: "models"),
           let decodedModels = try? JSONDecoder().decode([Model3D].self, from: savedModels) {
            return decodedModels
        }
        return nil
    }
    
    // 从缓存数据加载模型
    private func loadModelFromCachedData(_ data: Data, for user: User) {
        isLoading = true
        error = nil
        
        // 创建临时文件URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFileName = "cached_model_\(UUID().uuidString).glb"
        let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)
        
        do {
            // 将缓存数据写入临时文件
            try data.write(to: tempFileURL)
            
            // 创建模型记录 - 不传入modelURL以避免文件路径问题
            let modelName = "我的模型_\(user.height ?? 0)cm_\(user.weight ?? 0)kg"
            let model = Model3D(
                name: modelName,
                height: user.height ?? 0,
                weight: user.weight ?? 0,
                modelURL: nil,  // 不设置URL，避免文件查找警告
                thumbnailURL: nil,
                isCustom: true,
                userId: user.id
            )
            
            // 添加到模型列表
            models.append(model)
            selectedModel = model
            
            // 直接加载3D场景，不依赖Model3D的文件路径
            loadModel(from: tempFileURL)
            
            // 保存模型数据
            saveModels()
            
            print("✅ 缓存模型加载完成")
            
        } catch {
            print("❌ 处理缓存数据失败: \(error.localizedDescription)")
            self.error = "加载缓存模型失败"
            isLoading = false
        }
    }
    
    // 从URL加载3D模型
    func loadModel(from url: URL) {
        Model3DLoader.shared.loadModel(from: url) { [weak self] scene in
            DispatchQueue.main.async {
                if let scene = scene {
                    self?.modelScene = scene
                } else {
                    // 如果加载失败，显示错误
                    self?.error = "无法加载3D模型文件"
                    self?.modelScene = nil
                }
                // 加载完成，更新标志
                self?.isLoading = false
            }
        }
    }
    
    // 应用身高和体重比例到现有模型
    func applyScaleToModel(height: Int, weight: Int) {
        // 确保有选中的模型且有有效的URL
        if let selectedModel = selectedModel, let modelURL = selectedModel.modelURL {
            // 重新加载模型文件
            loadModel(from: modelURL)
        } else {
            error = "没有有效的3D模型文件可以应用比例"
        }
    }
} 
