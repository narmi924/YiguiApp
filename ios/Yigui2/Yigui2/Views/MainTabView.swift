import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 模型标签
            ModelView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("模型")
                }
                .tag(0)
            
            // 设计标签
            DesignView()
                .tabItem {
                    Image(systemName: "pencil")
                    Text("设计")
                }
                .tag(1)
            
            // 衣柜标签
            WardrobeView()
                .tabItem {
                    Image(systemName: "tshirt.fill")
                    Text("衣柜")
                }
                .tag(2)
            
            // 我的标签
            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("我的")
                }
                .tag(3)
        }
        .accentColor(Color.themeColor)
    }
}

// 自定义顶部标签切换
struct TopTabBar: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    var body: some View {
        ZStack {
            // 背景
            RoundedRectangle(cornerRadius: 25)
                .stroke(Color.themeColor, lineWidth: 2)
                .frame(height: 50)
                .background(Color.background)
            
            // 选中标签背景 - 将复杂计算拆分为多个简单步骤
            let tabWidth = UIScreen.main.bounds.width / CGFloat(tabs.count) - 20
            let offsetBase = selectedTab - tabs.count / 2
            let oddEvenAdjustment = tabs.count % 2 == 0 ? 0.5 : 0.0
            let offsetX = CGFloat(Double(offsetBase) + oddEvenAdjustment) * tabWidth
            
            RoundedRectangle(cornerRadius: 25)
                .fill(Color.themeColor)
                .frame(width: tabWidth, height: 50)
                .offset(x: offsetX)
            
            // 标签按钮
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { index in
                    Button(action: {
                        withAnimation {
                            selectedTab = index
                        }
                    }) {
                        Text(tabs[index])
                            .font(.custom("MF DianHei", size: 20))
                            .foregroundColor(selectedTab == index ? .white : Color.themeColor)
                            .frame(width: tabWidth, height: 50)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    MainTabView()
} 
