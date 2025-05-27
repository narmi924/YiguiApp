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
    
    // 模型生成服务
    private var modelGenerationService: ModelGenerationService?
    
    init() {
        // 尝试初始化模型生成服务
        do {
            self.modelGenerationService = try ModelGenerationService()
        } catch {
            self.error = "初始化模型生成服务失败: \(error.localizedDescription)"
        }
    }
    
    // 当用户输入身高和体重时，生成模型
    func generateModel(name: String? = nil, height: Int, weight: Int, userId: String?) {
        let modelName = name ?? "我的模型_\(height)cm_\(weight)kg"
        print("🔄 开始生成模型：\(modelName)，身高\(height)cm，体重\(weight)kg")
        isLoading = true
        error = nil
        
        // 确保服务可用
        guard let generationService = modelGenerationService else {
            print("❌ 模型生成服务不可用")
            isLoading = false
            error = "模型生成服务不可用，请重启应用"
            return
        }
        
        // 调用真实的模型生成服务
        generationService.generateAndLoadModel(height: Double(height), weight: Double(weight)) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let modelURL):
                    print("✅ 模型生成成功：\(modelURL.path)")
                    
                    // 创建新模型记录，使用真实的模型URL
                    let model = Model3D(
                        name: modelName,
                        height: height,
                        weight: weight,
                        modelURL: modelURL,
                        thumbnailURL: nil,
                        isCustom: true,
                        userId: userId
                    )
                    
                    self.models.append(model)
                    self.selectedModel = model
                    
                    print("📝 模型已添加到列表，当前模型数量：\(self.models.count)")
                    
                    // 加载真实的模型文件
                    self.loadModel(from: modelURL)
                    
                    // 保存模型数据
                    self.saveModels()
                    
                    // 确保加载状态已正确更新
                    self.isLoading = false
                    
                case .failure(let error):
                    print("❌ 模型生成失败：\(error.localizedDescription)")
                    self.error = "生成模型失败: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
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
        if let userData = UserDefaults.standard.data(forKey: "user"),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            
            print("📊 用户数据: 身高=\(user.height ?? 0), 体重=\(user.weight ?? 0)")
            
            // 验证身高体重数据的有效性
            guard let height = user.height, let weight = user.weight,
                  height > 50 && height < 250,  // 身高范围：50-250cm
                  weight > 20 && weight < 300   // 体重范围：20-300kg
            else {
                print("❌ 用户身高体重数据无效或缺失，无法生成模型")
                self.error = "请先在个人中心设置有效的身高体重信息"
                return
            }
            
            print("✅ 用户身高体重数据有效：身高\(height)cm，体重\(weight)kg")
            
            // 检查是否已经有基于相同身高体重的自定义模型
            let existingModel = models.first { model in
                model.isCustom && model.height == height && model.weight == weight
            }
            
            if existingModel != nil {
                // 如果已经存在相同身高体重的模型，则直接选择它
                selectedModel = existingModel
                print("📋 找到现有模型，直接使用")
            } else {
                // 创建新模型
                print("🔄 开始生成新模型")
                generateModel(height: height, weight: weight, userId: user.id)
            }
        } else {
            print("❌ 无法读取用户数据")
            self.error = "无法读取用户信息，请重新登录"
        }
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
                    let hasValidFile = model.modelURL != nil
                    if !hasValidFile {
                        print("🗑️ 移除无效模型: \(model.name)")
                    }
                    return hasValidFile
                } else {
                    // 对于非自定义模型，保留
                    return true
                }
            }
            
            // 如果有无效模型被移除，更新保存的数据
            if validModels.count != savedModels.count {
                print("🧹 清理了 \(savedModels.count - validModels.count) 个无效模型记录")
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
