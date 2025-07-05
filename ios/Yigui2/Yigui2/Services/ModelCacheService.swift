import Foundation

/// 3D模型本地缓存管理服务
/// 负责GLB模型文件的存储、读取、验证和清理
class ModelCacheService: @unchecked Sendable {
    
    // MARK: - 单例
    static let shared = ModelCacheService()
    private init() {
        // 检查目录是否存在，如果不存在则创建
        do {
            try createCacheDirectoriesIfNeeded()
            migrateOldCacheFormat()
        } catch {
            print("❌ 缓存初始化失败: \(error)")
        }
    }
    
    // MARK: - 常量定义
    private let cacheDirectoryName = "YiguiCache"
    private let modelsSubDirectory = "models"
    
    // UserDefaults键
    private let cachedUserEmailKey = "cachedUserEmail"  // 使用email替代ID作为稳定标识
    private let cachedGenderKey = "cachedGender"
    private let cachedHeightKey = "cachedHeight"
    private let cachedWeightKey = "cachedWeight"
    private let cachedModelFilenameKey = "cachedModelFilename"
    
    // MARK: - 缓存目录管理
    
    /// 获取缓存根目录路径
    private var cacheRootDirectory: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(cacheDirectoryName)
    }
    
    /// 获取模型缓存目录路径
    private var modelsCacheDirectory: URL {
        return cacheRootDirectory.appendingPathComponent(modelsSubDirectory)
    }
    
    /// 创建缓存目录（如果不存在）
    private func createCacheDirectoriesIfNeeded() throws {
        let fileManager = FileManager.default
        
        // 创建根缓存目录
        if !fileManager.fileExists(atPath: cacheRootDirectory.path) {
            try fileManager.createDirectory(at: cacheRootDirectory, withIntermediateDirectories: true)
        }
        
        // 创建模型子目录
        if !fileManager.fileExists(atPath: modelsCacheDirectory.path) {
            try fileManager.createDirectory(at: modelsCacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - 用户信息验证
    
    /// 生成基于用户信息的文件名
    private func generateModelFilename(for user: User) -> String {
        let userEmail = user.email.replacingOccurrences(of: "@", with: "_").replacingOccurrences(of: ".", with: "_")
        let gender = user.gender
        let height = user.height ?? 0
        let weight = user.weight ?? 0
        
        // 创建唯一的文件名，使用email作为标识
        let filename = "model_\(userEmail)_\(gender)_\(height)_\(weight).glb"
        return filename
    }
    
    /// 验证缓存是否对当前用户有效
    private func isCacheValid(for user: User) -> Bool {
        let defaults = UserDefaults.standard
        
        // 获取缓存的用户信息
        guard let cachedUserEmail = defaults.string(forKey: cachedUserEmailKey),
              let cachedGender = defaults.string(forKey: cachedGenderKey),
              let cachedModelFilename = defaults.string(forKey: cachedModelFilenameKey) else {
            return false
        }
        
        let cachedHeight = defaults.double(forKey: cachedHeightKey)
        let cachedWeight = defaults.double(forKey: cachedWeightKey)
        
        // 对比当前用户信息
        let currentHeight = Double(user.height ?? 0)
        let currentWeight = Double(user.weight ?? 0)
        
        let isValid = cachedUserEmail == user.email &&
                     cachedGender == user.gender &&
                     cachedHeight == currentHeight &&
                     cachedWeight == currentWeight
        
        if !isValid {
            return false
        }
        
        // 检查缓存文件是否存在
        let cachedFilePath = modelsCacheDirectory.appendingPathComponent(cachedModelFilename)
        let fileExists = FileManager.default.fileExists(atPath: cachedFilePath.path)
        
        return fileExists
    }
    
    // MARK: - 公共接口
    
    /// 将模型数据保存到缓存
    /// - Parameters:
    ///   - data: GLB模型数据
    ///   - user: 当前用户信息
    func saveModelToCache(data: Data, for user: User) {
        Task {
            do {
                // 在后台线程执行文件操作
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            // 创建缓存目录
                            try self.createCacheDirectoriesIfNeeded()
                            
                            // 生成文件名
                            let filename = self.generateModelFilename(for: user)
                            let filePath = self.modelsCacheDirectory.appendingPathComponent(filename)
                            
                            // 如果已存在旧文件，先删除
                            if FileManager.default.fileExists(atPath: filePath.path) {
                                try FileManager.default.removeItem(at: filePath)
                            }
                            
                            // 写入新文件
                            try data.write(to: filePath)
                            print("💾 模型已保存到缓存: \(self.formatFileSize(data.count))")
                            
                            // 保存元数据到UserDefaults
                            let defaults = UserDefaults.standard
                            defaults.set(user.email, forKey: self.cachedUserEmailKey)
                            defaults.set(user.gender, forKey: self.cachedGenderKey)
                            defaults.set(Double(user.height ?? 0), forKey: self.cachedHeightKey)
                            defaults.set(Double(user.weight ?? 0), forKey: self.cachedWeightKey)
                            defaults.set(filename, forKey: self.cachedModelFilenameKey)
                            
                            continuation.resume()
                            
                        } catch {
                            print("❌ 保存模型缓存失败: \(error.localizedDescription)")
                            continuation.resume(throwing: error)
                        }
                    }
                }
            } catch {
                print("❌ 缓存保存任务失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 从缓存加载模型数据
    /// - Parameter user: 当前用户信息
    /// - Returns: 模型数据，如果缓存无效或不存在则返回nil
    func loadModelDataFromCache(for user: User) -> Data? {
        // 验证缓存是否有效
        guard isCacheValid(for: user) else {
            return nil
        }
        
        // 获取缓存文件名
        guard let cachedModelFilename = UserDefaults.standard.string(forKey: cachedModelFilenameKey) else {
            print("❌ 无法获取缓存文件名")
            return nil
        }
        
        let filePath = modelsCacheDirectory.appendingPathComponent(cachedModelFilename)
        
        do {
            let data = try Data(contentsOf: filePath)
            print("✅ 从缓存加载模型: \(formatFileSize(data.count))")
            return data
        } catch {
            return nil
        }
    }
    
    /// 清除所有缓存
    func clearCache() {
        Task {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        // 删除缓存目录
                        if FileManager.default.fileExists(atPath: self.cacheRootDirectory.path) {
                            try FileManager.default.removeItem(at: self.cacheRootDirectory)
                            print("🗑️ 缓存目录已删除: \(self.cacheRootDirectory.path)")
                        }
                        
                        // 清除UserDefaults中的元数据
                        let defaults = UserDefaults.standard
                        defaults.removeObject(forKey: self.cachedUserEmailKey)
                        defaults.removeObject(forKey: self.cachedGenderKey)
                        defaults.removeObject(forKey: self.cachedHeightKey)
                        defaults.removeObject(forKey: self.cachedWeightKey)
                        defaults.removeObject(forKey: self.cachedModelFilenameKey)
                        
                        print("🗑️ 缓存元数据已清除")
                        
                    } catch {
                        print("❌ 清除缓存失败: \(error.localizedDescription)")
                    }
                    
                    continuation.resume()
                }
            }
        }
    }
    
    /// 获取缓存大小
    /// - Returns: 格式化的缓存大小字符串（例如："15.8 MB"）
    func getCacheSize() -> String {
        guard FileManager.default.fileExists(atPath: cacheRootDirectory.path) else {
            return "0 KB"
        }
        
        do {
            let totalSize = try calculateDirectorySize(at: cacheRootDirectory)
            return formatFileSize(totalSize)
        } catch {
            print("❌ 计算缓存大小失败: \(error.localizedDescription)")
            return "未知"
        }
    }
    
    // MARK: - 辅助方法
    
    /// 计算目录大小
    private func calculateDirectorySize(at url: URL) throws -> Int {
        let fileManager = FileManager.default
        var totalSize = 0
        
        if let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                totalSize += resourceValues.fileSize ?? 0
            }
        }
        
        return totalSize
    }
    
    /// 格式化文件大小
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    

    
    /// 迁移旧缓存格式（从ID改为Email标识）
    private func migrateOldCacheFormat() {
        let defaults = UserDefaults.standard
        
        // 检查是否存在旧的基于ID的缓存
        if defaults.string(forKey: "cachedUserID") != nil {
            // 清除旧的UserDefaults键
            defaults.removeObject(forKey: "cachedUserID")
            
            // 清除旧格式的缓存文件
            Task {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            if FileManager.default.fileExists(atPath: self.modelsCacheDirectory.path) {
                                let files = try FileManager.default.contentsOfDirectory(atPath: self.modelsCacheDirectory.path)
                                for file in files {
                                    let filePath = self.modelsCacheDirectory.appendingPathComponent(file)
                                    try FileManager.default.removeItem(at: filePath)
                                }
                            }
                        } catch {
                            // 静默处理错误
                        }
                        continuation.resume()
                    }
                }
            }
        }
    }
} 