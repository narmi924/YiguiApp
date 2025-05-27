import Foundation
import SwiftUI

struct Model3D: Identifiable, Codable {
    let id: String
    var name: String
    var height: Int
    var weight: Int
    var modelFileName: String? // 只保存文件名，不保存完整路径
    var thumbnailURL: URL?
    var isCustom: Bool
    var userId: String?
    
    // 计算属性：动态获取正确的模型文件URL
    var modelURL: URL? {
        guard let fileName = modelFileName else { return nil }
        
        let fileManager = FileManager.default
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let modelsDirectory = documentsDirectory.appendingPathComponent("Models")
        let modelURL = modelsDirectory.appendingPathComponent(fileName)
        
        // 检查文件是否存在
        if fileManager.fileExists(atPath: modelURL.path) {
            return modelURL
        } else {
            print("⚠️ 模型文件不存在: \(modelURL.path)")
            return nil
        }
    }
    
    init(id: String = UUID().uuidString, name: String, height: Int, weight: Int, modelURL: URL? = nil, thumbnailURL: URL? = nil, isCustom: Bool = false, userId: String? = nil) {
        self.id = id
        self.name = name
        self.height = height
        self.weight = weight
        self.thumbnailURL = thumbnailURL
        self.isCustom = isCustom
        self.userId = userId
        
        // 从完整URL中提取文件名
        if let url = modelURL {
            self.modelFileName = url.lastPathComponent
        } else {
            self.modelFileName = nil
        }
    }
    
    // 为了兼容旧版本数据，添加自定义解码
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        height = try container.decode(Int.self, forKey: .height)
        weight = try container.decode(Int.self, forKey: .weight)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        isCustom = try container.decode(Bool.self, forKey: .isCustom)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        
        // 尝试解码新的modelFileName字段
        if let fileName = try container.decodeIfPresent(String.self, forKey: .modelFileName) {
            self.modelFileName = fileName
        } else if let oldModelURL = try container.decodeIfPresent(URL.self, forKey: .modelURL) {
            // 兼容旧版本：从旧的modelURL中提取文件名
            self.modelFileName = oldModelURL.lastPathComponent
        } else {
            self.modelFileName = nil
        }
    }
    
    // 自定义编码，只编码必要的字段
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(height, forKey: .height)
        try container.encode(weight, forKey: .weight)
        try container.encodeIfPresent(modelFileName, forKey: .modelFileName)
        try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encodeIfPresent(userId, forKey: .userId)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, height, weight, modelFileName, modelURL, thumbnailURL, isCustom, userId
    }
}

// 用于3D模型的位置和旋转
struct ModelPosition: Codable {
    var position: CGPoint
    var rotation: Double
    var scale: CGFloat
    
    init(position: CGPoint = CGPoint(x: 0, y: 0), rotation: Double = 0, scale: CGFloat = 1.0) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
} 