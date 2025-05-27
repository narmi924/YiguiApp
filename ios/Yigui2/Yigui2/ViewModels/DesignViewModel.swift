import Foundation
import Combine
import SwiftUI

class DesignViewModel: ObservableObject {
    @Published var designs: [Clothing] = []
    @Published var currentDesign: Clothing?
    @Published var isLoading = false
    @Published var error: String?
    
    // 设计相关属性
    @Published var selectedFabricType = "棉"
    @Published var selectedPattern: String?
    @Published var selectedColor = "FFFFFF"
    @Published var customElements: [DesignData.CustomElement] = []
    @Published var selectedSilhouette: String = "标准"
    @Published var selectedTexture: String = "平纹"
    @Published var fabricWeight: String = "中等"
    @Published var stretchability: String = "无弹性"
    @Published var designNotes: String = ""
    @Published var measurementSpecifications: [String: Double] = [:]
    @Published var selectedTechnique: String = "缝制"
    @Published var selectedSeamType: String = "普通接缝"
    @Published var selectedHemType: String = "普通卷边"
    
    // 布料类型
    let fabricTypes = ["棉", "麻", "丝绸", "羊毛", "牛仔", "皮革", "尼龙", "聚酯纤维", "莫代尔", "亚麻", "真丝", "羊绒", "天鹅绒", "府绸", "雪纺", "棉麻混纺", "丝麻混纺"]
    
    // 图案
    let patterns = ["无图案", "条纹", "格子", "波点", "花卉", "几何图形", "动物纹理", "抽象", "刺绣", "印花", "扎染", "水彩", "迷彩"]
    
    // 轮廓
    let silhouettes = ["标准", "修身", "宽松", "A字型", "H型", "X型", "Y型", "O型", "梯形", "鱼尾", "铅笔型", "泡泡型", "蝙蝠袖"]
    
    // 纹理
    let textures = ["平纹", "斜纹", "缎纹", "提花", "绳绒", "起绒", "浮雕", "压纹", "蕾丝", "网眼", "珠光", "磨砂", "亮面", "绉纱"]
    
    // 布料重量
    let fabricWeights = ["轻薄", "中等", "厚重", "超轻", "超厚"]
    
    // 弹性程度
    let stretchLevels = ["无弹性", "微弹", "高弹", "四向弹力", "双向弹力"]
    
    // 制作技术
    let techniques = ["缝制", "编织", "针织", "钩织", "刺绣", "印花", "拼接", "打褶", "镂空", "褶皱工艺", "激光切割", "热压", "粘合"]
    
    // 缝合类型
    let seamTypes = ["普通接缝", "法式接缝", "平缝接缝", "锁边接缝", "包边接缝", "装饰接缝", "暗线接缝", "叠接缝", "滚边接缝"]
    
    // 下摆类型
    let hemTypes = ["普通卷边", "双折边", "包边", "装饰边", "流苏边", "蕾丝边", "色带边", "毛边", "无边"]
    
    // 尺寸标准
    let sizeSpecifications = ["肩宽", "胸围", "腰围", "臀围", "上衣长", "袖长", "裤长", "裙长", "领围", "胸高", "前后胸宽", "裁片数量"]
    
    // 加载设计
    func loadDesigns() {
        isLoading = true
        
        // 首先从本地存储加载数据
        if let savedDesigns = loadSavedDesigns() {
            self.designs = savedDesigns
            isLoading = false
            return
        }
        
        // 如果没有本地数据，创建空列表
        designs = []
        isLoading = false
    }
    
    // 开始新设计
    func startNewDesign(type: ClothingType) {
        // 创建默认尺寸规格
        initializeDefaultMeasurements(for: type)
        
        // 创建新的设计
        let designData = DesignData(
            fabricType: selectedFabricType,
            pattern: selectedPattern,
            customElements: [],
            silhouette: selectedSilhouette,
            texture: selectedTexture,
            fabricWeight: fabricWeight,
            stretchability: stretchability,
            designNotes: "",
            measurementSpecifications: measurementSpecifications,
            technique: selectedTechnique,
            seamType: selectedSeamType,
            hemType: selectedHemType
        )
        
        let newDesign = Clothing(
            name: "新设计_\(Date())",
            type: type,
            imageURL: nil,
            designData: designData,
            color: selectedColor
        )
        
        self.currentDesign = newDesign
    }
    
    // 根据服装类型初始化默认尺寸
    private func initializeDefaultMeasurements(for type: ClothingType) {
        measurementSpecifications = [:]
        
        switch type {
        case .shirt, .tshirt, .blouse:
            measurementSpecifications = [
                "肩宽": 42.0,
                "胸围": 96.0,
                "腰围": 80.0,
                "上衣长": 68.0,
                "袖长": 58.0,
                "领围": 38.0
            ]
        case .pants, .jeans:
            measurementSpecifications = [
                "腰围": 80.0,
                "臀围": 98.0,
                "裤长": 100.0,
                "裆高": 26.0,
                "膝围": 42.0,
                "脚口": 36.0
            ]
        case .skirt:
            measurementSpecifications = [
                "腰围": 68.0,
                "臀围": 96.0,
                "裙长": 60.0
            ]
        case .dress:
            measurementSpecifications = [
                "肩宽": 38.0,
                "胸围": 90.0,
                "腰围": 72.0,
                "臀围": 96.0,
                "裙长": 90.0,
                "袖长": 0.0
            ]
        case .jacket, .coat:
            measurementSpecifications = [
                "肩宽": 44.0,
                "胸围": 100.0,
                "腰围": 88.0,
                "上衣长": 75.0,
                "袖长": 60.0,
                "领围": 40.0
            ]
        case .other:
            measurementSpecifications = [
                "自定义": 0.0
            ]
        }
    }
    
    // 添加元素到设计
    func addElement(type: String, position: CGPoint, size: CGSize, rotation: Double, color: String? = nil, imageURL: URL? = nil) {
        let element = DesignData.CustomElement(
            type: type,
            position: position,
            size: size,
            rotation: rotation,
            color: color,
            imageURL: imageURL
        )
        
        customElements.append(element)
        
        // 更新当前设计
        updateCurrentDesign()
    }
    
    // 移除元素
    func removeElement(at index: Int) {
        guard index < customElements.count else { return }
        customElements.remove(at: index)
        
        // 更新当前设计
        updateCurrentDesign()
    }
    
    // 更新当前设计
    private func updateCurrentDesign() {
        guard var design = currentDesign else { return }
        
        let designData = DesignData(
            fabricType: selectedFabricType,
            pattern: selectedPattern,
            customElements: customElements,
            silhouette: selectedSilhouette,
            texture: selectedTexture,
            fabricWeight: fabricWeight,
            stretchability: stretchability,
            designNotes: designNotes,
            measurementSpecifications: measurementSpecifications,
            technique: selectedTechnique,
            seamType: selectedSeamType,
            hemType: selectedHemType
        )
        
        design.designData = designData
        design.color = selectedColor
        
        self.currentDesign = design
    }
    
    // 估算布料用量
    func estimateFabricRequirement() -> Double {
        guard let design = currentDesign, let measurements = design.designData?.measurementSpecifications else { return 0.0 }
        
        var fabricArea: Double = 0.0
        let width: Double = 150.0 // 默认布料宽度150cm
        
        switch design.type {
        case .shirt, .tshirt, .blouse:
            if let chest = measurements["胸围"], let length = measurements["上衣长"] {
                fabricArea = (chest * 0.5 + 10) * (length * 1.1) * 2
            }
        case .pants, .jeans:
            if let waist = measurements["腰围"], let hips = measurements["臀围"], let length = measurements["裤长"] {
                fabricArea = max(waist, hips) * 0.5 * length * 2.2
            }
        case .skirt:
            if let waist = measurements["腰围"], let length = measurements["裙长"] {
                // 简单A型裙
                let hemWidth = waist * 1.5
                fabricArea = (waist + hemWidth) / 2 * length * 2
            }
        case .dress:
            if let chest = measurements["胸围"], let length = measurements["裙长"] {
                fabricArea = (chest * 0.5 + 15) * length * 2.2
            }
        case .jacket, .coat:
            if let chest = measurements["胸围"], let length = measurements["上衣长"] {
                fabricArea = (chest * 0.5 + 20) * length * 2.5
            }
        case .other:
            fabricArea = 200.0 // 默认值
        }
        
        // 转换为米
        return (fabricArea / (width * 100)).rounded(toPlaces: 2)
    }
    
    // 保存当前设计
    func saveCurrentDesign() {
        guard let design = currentDesign else { return }
        
        // 检查是否已存在，如果是则更新
        if let index = designs.firstIndex(where: { $0.id == design.id }) {
            designs[index] = design
        } else {
            designs.append(design)
        }
        
        // 保存设计数据
        saveDesigns()
    }
    
    // 删除设计
    func removeDesign(_ design: Clothing) {
        designs.removeAll { $0.id == design.id }
        saveDesigns()
    }
    
    // 为当前设计生成技术细节
    func generateTechnicalDetails() -> String {
        guard let design = currentDesign else { return "" }
        
        var details = "设计技术规格:\n\n"
        details += "服装类型: \(design.type.rawValue)\n"
        details += "面料: \(design.designData?.fabricType ?? "未指定")\n"
        details += "图案: \(design.designData?.pattern ?? "无图案")\n"
        details += "轮廓: \(design.designData?.silhouette ?? "标准")\n"
        details += "纹理: \(design.designData?.texture ?? "平纹")\n"
        details += "布料重量: \(design.designData?.fabricWeight ?? "中等")\n"
        details += "弹性: \(design.designData?.stretchability ?? "无弹性")\n"
        details += "制作技术: \(design.designData?.technique ?? "缝制")\n"
        details += "接缝类型: \(design.designData?.seamType ?? "普通接缝")\n"
        details += "下摆处理: \(design.designData?.hemType ?? "普通卷边")\n\n"
        
        details += "尺寸规格:\n"
        if let specs = design.designData?.measurementSpecifications {
            for (key, value) in specs {
                details += "\(key): \(value)cm\n"
            }
        }
        
        details += "\n估计布料用量: \(estimateFabricRequirement())米\n"
        
        if let notes = design.designData?.designNotes, !notes.isEmpty {
            details += "\n设计师备注:\n\(notes)"
        }
        
        return details
    }
    
    // 保存设计数据到本地
    private func saveDesigns() {
        if let encodedDesigns = try? JSONEncoder().encode(designs) {
            UserDefaults.standard.set(encodedDesigns, forKey: "designs")
        }
    }
    
    // 从本地加载保存的设计数据
    private func loadSavedDesigns() -> [Clothing]? {
        if let savedDesigns = UserDefaults.standard.data(forKey: "designs"),
           let decodedDesigns = try? JSONDecoder().decode([Clothing].self, from: savedDesigns) {
            return decodedDesigns
        }
        return nil
    }
}

// 四舍五入小数点位数的扩展
extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
} 