import Foundation
import CoreML

// 身体比例预测结果结构体
struct BodyShapePrediction {
    let chest: Double
    let waist: Double
    let thigh: Double
}

// 预测时可能出现的错误
enum BodyShapePredictorError: Error, CustomStringConvertible {
    case modelLoadingFailed(String)
    case predictionFailed(String)

    var description: String {
        switch self {
        case .modelLoadingFailed(let reason):
            return "模型加载失败: \(reason)"
        case .predictionFailed(let reason):
            return "预测执行失败: \(reason)"
        }
    }
}

class BodyShapePredictorService {
    // 模型实例
    private var chestModel: MLModel?
    private var waistModel: MLModel?
    private var thighModel: MLModel?
    
    // 初始化方法，加载所有模型
    init() throws {
        do {
            // 直接使用编译好的模型类
            // 这些类是在构建过程中自动生成的
            let chestConfig = MLModelConfiguration()
            let waistConfig = MLModelConfiguration()
            let thighConfig = MLModelConfiguration()
            
            // 加载编译后的模型
            chestModel = try Chest_Ratio(configuration: chestConfig).model
            waistModel = try Waist_Ratio(configuration: waistConfig).model
            thighModel = try Thigh_Ratio(configuration: thighConfig).model
            
            print("✅ CoreML模型加载完成")
            
        } catch {
            print("❌ 加载CoreML模型失败：\(error.localizedDescription)")
            throw BodyShapePredictorError.modelLoadingFailed("加载模型失败: \(error.localizedDescription)")
        }
    }
    
    // 公开的预测方法
    func predict(height: Double, weight: Double) async throws -> BodyShapePrediction {
        // 在后台线程异步执行预测
        return try await Task.detached(priority: .userInitiated) {
            // 确保模型已加载
            guard let chestModel = self.chestModel,
                  let waistModel = self.waistModel,
                  let thighModel = self.thighModel else {
                throw BodyShapePredictorError.modelLoadingFailed("模型未正确加载")
            }
            
            // 初始化默认比例值，以启动迭代
            var estimatedChestRatio = 1.0
            var estimatedWaistRatio = 1.0
            var estimatedThighRatio = 1.0

            // 通过迭代解决模型间的循环依赖问题，3次迭代足以收敛
            for i in 0..<3 {
                print("🔄 开始第 \(i + 1) 轮迭代预测...")
                do {
                    // 1. 预测胸围比例
                    let chestInputFeatures: [String: MLFeatureValue] = [
                        "height_cm": MLFeatureValue(double: height),
                        "weight_kg": MLFeatureValue(double: weight),
                        "waist_ratio": MLFeatureValue(double: estimatedWaistRatio),
                        "thigh_ratio": MLFeatureValue(double: estimatedThighRatio)
                    ]
                    let chestInput = try MLDictionaryFeatureProvider(dictionary: chestInputFeatures)
                    let chestOutput = try chestModel.prediction(from: chestInput)
                    if let newChestRatio = chestOutput.featureValue(for: "chest_ratio")?.doubleValue {
                        estimatedChestRatio = newChestRatio
                    }

                    // 2. 预测腰围比例 (使用上一部预测出的新胸围)
                    let waistInputFeatures: [String: MLFeatureValue] = [
                        "height_cm": MLFeatureValue(double: height),
                        "weight_kg": MLFeatureValue(double: weight),
                        "chest_ratio": MLFeatureValue(double: estimatedChestRatio),
                        "thigh_ratio": MLFeatureValue(double: estimatedThighRatio)
                    ]
                    let waistInput = try MLDictionaryFeatureProvider(dictionary: waistInputFeatures)
                    let waistOutput = try waistModel.prediction(from: waistInput)
                    if let newWaistRatio = waistOutput.featureValue(for: "waist_ratio")?.doubleValue {
                        estimatedWaistRatio = newWaistRatio
                    }

                    // 3. 预测大腿围比例 (使用新的胸围和腰围)
                    let thighInputFeatures: [String: MLFeatureValue] = [
                        "height_cm": MLFeatureValue(double: height),
                        "weight_kg": MLFeatureValue(double: weight),
                        "chest_ratio": MLFeatureValue(double: estimatedChestRatio),
                        "waist_ratio": MLFeatureValue(double: estimatedWaistRatio)
                    ]
                    let thighInput = try MLDictionaryFeatureProvider(dictionary: thighInputFeatures)
                    let thighOutput = try thighModel.prediction(from: thighInput)
                    if let newThighRatio = thighOutput.featureValue(for: "thigh_ratio")?.doubleValue {
                        estimatedThighRatio = newThighRatio
                    }
                    
                    print("    - 第 \(i + 1) 轮结果: Chest=\(String(format: "%.3f", estimatedChestRatio)), Waist=\(String(format: "%.3f", estimatedWaistRatio)), Thigh=\(String(format: "%.3f", estimatedThighRatio))")

                } catch {
                     throw BodyShapePredictorError.predictionFailed("迭代预测失败: \(error.localizedDescription)")
                }
            }
            
            // 返回最终收敛的预测结果
            return BodyShapePrediction(
                chest: estimatedChestRatio,
                waist: estimatedWaistRatio,
                thigh: estimatedThighRatio
            )
        }.value
    }
    
    // 便利方法：一次性创建服务并预测结果
    static func quickPredict(height: Double, weight: Double) async throws -> BodyShapePrediction {
        let service = try BodyShapePredictorService()
        return try await service.predict(height: height, weight: weight)
    }
} 