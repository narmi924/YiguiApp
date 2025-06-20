import Foundation
import SwiftUI

enum ClothingType: String, Codable, CaseIterable {
    case shirt = "衬衫"
    case tshirt = "T恤"
    case blouse = "女衬衫"
    case pants = "裤子"
    case jeans = "牛仔裤"
    case skirt = "裙子"
    case dress = "连衣裙"
    case jacket = "夹克"
    case coat = "外套"
    case outfit = "套装"
    case other = "其他"
}

struct Clothing: Identifiable, Codable {
    let id: String
    var name: String
    var type: ClothingType
    var imageURL: URL?
    var designData: DesignData?
    var color: String? // 使用十六进制颜色代码
    var created: Date
    var lastModified: Date
    var isFavorite: Bool
    
    init(id: String = UUID().uuidString, name: String, type: ClothingType, imageURL: URL? = nil, designData: DesignData? = nil, color: String? = nil, created: Date = Date(), lastModified: Date = Date(), isFavorite: Bool = false) {
        self.id = id
        self.name = name
        self.type = type
        self.imageURL = imageURL
        self.designData = designData
        self.color = color
        self.created = created
        self.lastModified = lastModified
        self.isFavorite = isFavorite
    }
}

struct DesignData: Codable {
    var fabricType: String
    var pattern: String?
    var customElements: [CustomElement]
    var silhouette: String?
    var texture: String?
    var fabricWeight: String?
    var stretchability: String?
    var designNotes: String?
    var measurementSpecifications: [String: Double]?
    var technique: String?
    var seamType: String?
    var hemType: String?
    
    init(fabricType: String, pattern: String? = nil, customElements: [CustomElement] = [], silhouette: String? = nil, texture: String? = nil, fabricWeight: String? = nil, stretchability: String? = nil, designNotes: String? = nil, measurementSpecifications: [String: Double]? = nil, technique: String? = nil, seamType: String? = nil, hemType: String? = nil) {
        self.fabricType = fabricType
        self.pattern = pattern
        self.customElements = customElements
        self.silhouette = silhouette
        self.texture = texture
        self.fabricWeight = fabricWeight
        self.stretchability = stretchability
        self.designNotes = designNotes
        self.measurementSpecifications = measurementSpecifications
        self.technique = technique
        self.seamType = seamType
        self.hemType = hemType
    }
    
    struct CustomElement: Codable {
        var type: String
        var position: CGPoint
        var size: CGSize
        var rotation: Double
        var color: String?
        var imageURL: URL?
        var layer: Int
        var opacity: Double
        var isLocked: Bool
        
        init(type: String, position: CGPoint, size: CGSize, rotation: Double, color: String? = nil, imageURL: URL? = nil, layer: Int = 0, opacity: Double = 1.0, isLocked: Bool = false) {
            self.type = type
            self.position = position
            self.size = size
            self.rotation = rotation
            self.color = color
            self.imageURL = imageURL
            self.layer = layer
            self.opacity = opacity
            self.isLocked = isLocked
        }
    }
}

// 颜色代码与名称对应
struct ColorPalette {
    static let colors: [String: String] = [
        "000000": "黑色",
        "FFFFFF": "白色",
        "FF0000": "红色",
        "00FF00": "绿色",
        "0000FF": "蓝色",
        "FFFF00": "黄色",
        "FF00FF": "粉红色",
        "00FFFF": "青色",
        "FFA500": "橙色",
        "A52A2A": "棕色",
        "800080": "紫色",
        "808080": "灰色",
        "E8AD70": "浅棕色",
        "DCDCDC": "亮灰色",
        "F5F5F5": "白烟色",
        "F0E68C": "卡其色",
        "E6E6FA": "薰衣草色",
        "F08080": "浅珊瑚色",
        "98FB98": "浅绿色",
        "AFEEEE": "浅绿松石色",
        "D8BFD8": "蓟色",
        "FFDEAD": "纳瓦霍白色",
        "FFE4E1": "雾玫瑰色"
    ]
    
    static func name(for hexCode: String) -> String {
        return colors[hexCode.uppercased()] ?? "自定义色"
    }
} 