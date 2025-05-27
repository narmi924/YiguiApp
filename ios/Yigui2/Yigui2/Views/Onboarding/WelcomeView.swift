import SwiftUI

struct WelcomeView: View {
    @ObservedObject var appStateManager: AppStateManager
    @State private var currentPage = 0
    
    // 为Splash页定义动画状态
    @State private var scale: CGFloat = 0.7
    @State private var opacity: Double = 0.0
    @State private var rightCircleOffset: CGFloat = 0
    @State private var initialAnimationCompleted = false
    
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            TabView(selection: $currentPage) {
                // 第一页：原Splash页内容
                splashPage
                    .tag(0)
                
                // 第二页：欢迎页1
                welcomePage1
                    .tag(1)
                
                // 第三页：欢迎页2
                welcomePage2
                    .tag(2)
            }
            .tabViewStyle(PageTabViewStyle())
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .never))
            .edgesIgnoringSafeArea(.all)
            .statusBar(hidden: true)
        }
        .onAppear {
            // 初始页面动画
            withAnimation(.easeIn(duration: 1.2)) {
                self.scale = 1.0
                self.opacity = 1.0
            }
            
            // 2秒后自动滑向第二页
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.8)) {
                    self.rightCircleOffset = -500
                    self.initialAnimationCompleted = true
                    self.currentPage = 1
                }
            }
        }
    }
    
    // Splash页面
    var splashPage: some View {
        ZStack {
            // 右上角的圆环
            ZStack {
                Image("up_circle_1")
                    .resizable()
                    .frame(width: 300, height: 307)
                
                Image("up_circle_2")
                    .resizable()
                    .frame(width: 265, height: 271)
                
                Image("up_circle_3")
                    .resizable()
                    .frame(width: 229.76, height: 234.46)
                
                Image("up_circle_4")
                    .resizable()
                    .frame(width: 194.24, height: 198.62)
                
                Image("up_circle_5")
                    .resizable()
                    .frame(width: 159.17, height: 162.28)
                
                Image("up_circle_6")
                    .resizable()
                    .frame(width: 123.65, height: 126.44)
                
                Image("up_circle_7")
                    .resizable()
                    .frame(width: 89, height: 90)
            }
            .position(x: 460 + rightCircleOffset, y: 120)
            
            // 左下角的圆环
            ZStack {
                Image("up_circle_1")
                    .resizable()
                    .frame(width: 300, height: 307)
                
                Image("up_circle_2")
                    .resizable()
                    .frame(width: 265, height: 271)
                
                Image("up_circle_3")
                    .resizable()
                    .frame(width: 229.76, height: 234.46)
                
                Image("up_circle_4")
                    .resizable()
                    .frame(width: 194.24, height: 198.62)
                
                Image("up_circle_5")
                    .resizable()
                    .frame(width: 159.17, height: 162.28)
                
                Image("up_circle_6")
                    .resizable()
                    .frame(width: 123.65, height: 126.44)
                
                Image("up_circle_7")
                    .resizable()
                    .frame(width: 89, height: 90)
            }
            .position(x: -40, y: 650)
            
            // 文字
            VStack(spacing: 10) {
                // 应用标题 - 使用特殊样式，只有U是主题色
                HStack(spacing: 0) {
                    Text("Yig")
                        .font(.custom("Epilogue", size: 48))
                        .foregroundColor(.textPrimary)
                    
                    Text("U")
                        .font(.custom("Epilogue", size: 48))
                        .foregroundColor(.themeColor)
                    
                    Text("i")
                        .font(.custom("Epilogue", size: 48))
                        .foregroundColor(.textPrimary)
                }
                
                Text("依柜")
                    .font(.custom("MF DianHei", size: 48))
                    .foregroundColor(.textPrimary)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 3)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
    }
    
    // 欢迎页1
    var welcomePage1: some View {
        ZStack {
            // 左上角的圆环
            ZStack {
                Image("up_circle_1")
                    .resizable()
                    .frame(width: 300, height: 307)
                
                Image("up_circle_2")
                    .resizable()
                    .frame(width: 265, height: 271)
                
                Image("up_circle_3")
                    .resizable()
                    .frame(width: 229.76, height: 234.46)
                
                Image("up_circle_4")
                    .resizable()
                    .frame(width: 194.24, height: 198.62)
                
                Image("up_circle_5")
                    .resizable()
                    .frame(width: 159.17, height: 162.28)
                
                Image("up_circle_6")
                    .resizable()
                    .frame(width: 123.65, height: 126.44)
                
                Image("up_circle_7")
                    .resizable()
                    .frame(width: 89, height: 90)
            }
            .position(x: -40, y: 120)
            
            // 图片
            Image("welcome_image_1")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 280)
                .padding(.horizontal)
                .offset(y: 0)
            
            // 文字部分 - 使用绝对定位
            ZStack {
                Text("衣柜")
                    .font(.custom("MF DianHei", size: 34))
                    .foregroundColor(.black)
                    .offset(x: 91.50, y: 265.50)
                
                Text("自定义")
                    .font(.custom("MF DianHei", size: 34))
                    .foregroundColor(.black)
                    .shadow(color: Color(red: 0.91, green: 0.68, blue: 0.44, opacity: 1.00), radius: 8, x: 0, y: 4)
                    .offset(x: 1, y: 223.50)
                
                Text("你的")
                    .font(.custom("MF DianHei", size: 34))
                    .foregroundColor(.black)
                    .offset(x: -90.50, y: 181.50)
                
                Text("依柜")
                    .font(.custom("MF DianHei", size: 48))
                    .foregroundColor(.black)
                    .shadow(color: Color(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.35), radius: 8, x: 0, y: 3)
                    .offset(x: 0, y: -207.5)
                
                Text("欢迎使用")
                    .font(.custom("MF DianHei", size: 34))
                    .foregroundColor(.black)
                    .offset(x: 0, y: -295.5)
            }
            .frame(width: 254, height: 673)
            
            // 只在手动交互时才显示按钮（初始自动动画不显示）
            if initialAnimationCompleted {
                // 按钮
                Button(action: {
                    withAnimation {
                        currentPage = 2
                    }
                }) {
                    Text("下一页")
                        .primaryButtonStyle()
                }
                .padding(.horizontal, 80)
                .offset(x: 0, y: 330)
                .transition(.opacity)
            }
        }
    }
    
    // 欢迎页2
    var welcomePage2: some View {
        ZStack {
            // 左上角的圆环
            ZStack {
                Image("up_circle_1")
                    .resizable()
                    .frame(width: 300, height: 307)
                
                Image("up_circle_2")
                    .resizable()
                    .frame(width: 265, height: 271)
                
                Image("up_circle_3")
                    .resizable()
                    .frame(width: 229.76, height: 234.46)
                
                Image("up_circle_4")
                    .resizable()
                    .frame(width: 194.24, height: 198.62)
                
                Image("up_circle_5")
                    .resizable()
                    .frame(width: 159.17, height: 162.28)
                
                Image("up_circle_6")
                    .resizable()
                    .frame(width: 123.65, height: 126.44)
                
                Image("up_circle_7")
                    .resizable()
                    .frame(width: 89, height: 90)
            }
            .position(x: -40, y: 120)
            
            // 图片
            Image("welcome_image_2")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 280)
                .padding(.horizontal)
                .offset(y: 0)
            
            // 文字部分 - 使用绝对定位
            ZStack {
                Text("任意服装")
                    .font(.custom("MF DianHei", size: 34))
                    .foregroundColor(.black)
                    .offset(x: 91.50, y: 265.50)
                
                Text("3D试穿")
                    .font(.custom("MF DianHei", size: 34))
                    .foregroundColor(.black)
                    .shadow(color: Color(red: 0.91, green: 0.68, blue: 0.44, opacity: 1.00), radius: 8, x: 0, y: 4)
                    .offset(x: 1, y: 223.50)
                
                Text("体验")
                    .font(.custom("MF DianHei", size: 34))
                    .foregroundColor(.black)
                    .offset(x: -90.50, y: 181.50)
                
                Text("依柜")
                    .font(.custom("MF DianHei", size: 48))
                    .foregroundColor(.black)
                    .shadow(color: Color(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.35), radius: 8, x: 0, y: 3)
                    .offset(x: 0, y: -207.5)
                
                Text("欢迎使用")
                    .font(.custom("MF DianHei", size: 34))
                    .foregroundColor(.black)
                    .offset(x: 0, y: -295.5)
            }
            .frame(width: 254, height: 673)
            
            // 按钮
            Button(action: {
                withAnimation(.easeInOut) {
                    appStateManager.rootViewState = .signIn
                }
            }) {
                Text("开始使用")
                    .primaryButtonStyle()
            }
            .padding(.horizontal, 80)
            .offset(y: 330)
        }
    }
}

struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeView(appStateManager: AppStateManager())
    }
} 
