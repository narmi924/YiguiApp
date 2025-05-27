import Foundation
import Combine
import SwiftUI

class ClothingViewModel: ObservableObject {
    @Published var clothes: [Clothing] = []
    @Published var selectedClothing: Clothing?
    @Published var isLoading = false
    @Published var error: String?
    
    // 服装类型过滤
    @Published var selectedType: ClothingType?
    
    var filteredClothes: [Clothing] {
        guard let type = selectedType else {
            return clothes
        }
        return clothes.filter { $0.type == type }
    }
    
    // 加载衣物列表
    func loadClothes() {
        isLoading = true
        
        // 首先从本地存储加载数据
        if let savedClothes = loadSavedClothes() {
            self.clothes = savedClothes
            isLoading = false
            return
        }
        
        // 如果没有本地数据，加载示例衣物
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: DispatchWorkItem(block: {
            // 在实际应用中，这里应该是从服务器加载衣物
            // 为了演示，我们创建一些示例衣物
            let sampleClothes = [
                Clothing(
                    name: "白色T恤",
                    type: .tshirt,
                    imageURL: URL(string: "https://example.com/clothes/white_tshirt.jpg"),
                    color: "FFFFFF"
                ),
                Clothing(
                    name: "黑色T恤",
                    type: .tshirt,
                    imageURL: URL(string: "https://example.com/clothes/black_tshirt.jpg"),
                    color: "000000"
                ),
                Clothing(
                    name: "蓝色牛仔裤",
                    type: .jeans,
                    imageURL: URL(string: "https://example.com/clothes/blue_jeans.jpg"),
                    color: "0000FF"
                ),
                Clothing(
                    name: "红色连衣裙",
                    type: .dress,
                    imageURL: URL(string: "https://example.com/clothes/red_dress.jpg"),
                    color: "FF0000"
                ),
                Clothing(
                    name: "黑色夹克",
                    type: .jacket,
                    imageURL: URL(string: "https://example.com/clothes/black_jacket.jpg"),
                    color: "000000"
                )
            ]
            
            self.clothes = sampleClothes
            self.isLoading = false
            
            // 保存衣物数据
            self.saveClothes()
        }))
    }
    
    // 添加新衣物
    func addClothing(_ clothing: Clothing) {
        clothes.append(clothing)
        saveClothes()
    }
    
    // 删除衣物
    func removeClothing(_ clothing: Clothing) {
        clothes.removeAll { $0.id == clothing.id }
        saveClothes()
    }
    
    // 选择衣物
    func selectClothing(_ clothing: Clothing) {
        self.selectedClothing = clothing
    }
    
    // 设置过滤类型
    func setFilter(_ type: ClothingType?) {
        self.selectedType = type
    }
    
    // 保存衣物数据到本地
    private func saveClothes() {
        if let encodedClothes = try? JSONEncoder().encode(clothes) {
            UserDefaults.standard.set(encodedClothes, forKey: "clothes")
        }
    }
    
    // 从本地加载保存的衣物数据
    private func loadSavedClothes() -> [Clothing]? {
        if let savedClothes = UserDefaults.standard.data(forKey: "clothes"),
           let decodedClothes = try? JSONDecoder().decode([Clothing].self, from: savedClothes) {
            return decodedClothes
        }
        return nil
    }
} 