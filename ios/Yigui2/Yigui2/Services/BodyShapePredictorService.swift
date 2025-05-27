import Foundation
import CoreML

// 身体比例预测结果结构体
struct BodyShapePrediction {
    let chest: Double
    let waist: Double
    let thigh: Double
}

// 预测时可能出现的错误
enum BodyShapePredictorError: Error {
    case modelLoadingFailed(String)
    case predictionFailed(String)
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
            
            print("✅ 成功加载所有CoreML模型")
            
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
            
            // 准备输入数据
            let inputFeatures: [String: MLFeatureValue] = [
                "height": MLFeatureValue(double: height),
                "weight": MLFeatureValue(double: weight)
            ]
            
            do {
                // 创建输入数据
                let chestInput = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
                let waistInput = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
                let thighInput = try MLDictionaryFeatureProvider(dictionary: inputFeatures)
                
                // 执行预测
                let chestOutput = try chestModel.prediction(from: chestInput)
                let waistOutput = try waistModel.prediction(from: waistInput)
                let thighOutput = try thighModel.prediction(from: thighInput)
                
                // 提取预测结果
                guard let chestRatio = chestOutput.featureValue(for: "chest_ratio")?.doubleValue,
                      let waistRatio = waistOutput.featureValue(for: "waist_ratio")?.doubleValue,
                      let thighRatio = thighOutput.featureValue(for: "thigh_ratio")?.doubleValue else {
                    throw BodyShapePredictorError.predictionFailed("无法获取预测结果")
                }
                
                // 返回预测结果
                return BodyShapePrediction(
                    chest: chestRatio,
                    waist: waistRatio,
                    thigh: thighRatio
                )
            } catch {
                throw BodyShapePredictorError.predictionFailed("预测失败: \(error.localizedDescription)")
            }
        }.value
    }
    
    // 便利方法：一次性创建服务并预测结果
    static func quickPredict(height: Double, weight: Double) async throws -> BodyShapePrediction {
        let service = try BodyShapePredictorService()
        return try await service.predict(height: height, weight: weight)
    }
} 