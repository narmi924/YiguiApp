import SwiftUI

// 主要按钮样式
struct PrimaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("MF DianHei", size: 20))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.themeColor)
            .cornerRadius(25)
            .shadow(color: Color.themeColor.opacity(0.4), radius: 5, x: 0, y: 3)
    }
}

// 次要按钮样式
struct SecondaryButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("MF DianHei", size: 20))
            .foregroundColor(.themeColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.themeColor, lineWidth: 2)
            )
    }
}

// 标签样式
struct TabLabelStyle: ViewModifier {
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .font(.custom("MF DianHei", size: 20))
            .foregroundColor(isSelected ? .white : Color.themeColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isSelected ? Color.themeColor : Color.clear)
            .cornerRadius(25)
    }
}

// 输入标签样式
struct InputLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("MF DianHei", size: 16))
            .foregroundColor(.themeColor)
    }
}

// 输入框样式
struct InputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.custom("MF DianHei", size: 16))
            .padding()
            .background(Color.white)
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color.themeColor, lineWidth: 1)
            )
    }
}

// 扩展View以便简单使用这些样式
extension View {
    func primaryButtonStyle() -> some View {
        self.modifier(PrimaryButtonStyle())
    }
    
    func secondaryButtonStyle() -> some View {
        self.modifier(SecondaryButtonStyle())
    }
    
    func tabLabelStyle(isSelected: Bool) -> some View {
        self.modifier(TabLabelStyle(isSelected: isSelected))
    }
    
    func inputLabelStyle() -> some View {
        self.modifier(InputLabelStyle())
    }
    
    func inputFieldStyle() -> some View {
        self.modifier(InputFieldStyle())
    }
} 