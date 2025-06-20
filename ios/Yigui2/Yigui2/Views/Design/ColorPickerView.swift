import SwiftUI

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    @Environment(\.presentationMode) var presentationMode
    
    let colors: [Color] = [
        .white, .black, .red, .green, .blue, .yellow, .purple, .orange,
        .pink, .gray, .brown, .cyan, .mint, .indigo, .teal
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // 标题
                Text("选择颜色")
                    .font(.custom("MF DianHei", size: 24))
                    .foregroundColor(.textPrimary)
                
                // 当前选择的颜色
                VStack(spacing: 15) {
                    Text("当前选择")
                        .font(.custom("MF DianHei", size: 18))
                        .foregroundColor(.textPrimary)
                    
                    Circle()
                        .fill(selectedColor)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                
                // 颜色网格
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                            ColorButton(
                                color: color,
                                isSelected: colorsEqual(selectedColor, color),
                                action: {
                                    selectedColor = color
                                }
                            )
                        }
                    }
                    .padding()
                }
                
                // 确认按钮
                Button("确认选择") {
                    presentationMode.wrappedValue.dismiss()
                }
                .primaryButtonStyle()
                .padding(.horizontal, 50)
                
                Spacer()
            }
            .padding()
            .background(Color.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.themeColor)
                }
            }
        }
    }
    
    private func colorsEqual(_ color1: Color, _ color2: Color) -> Bool {
        // 简化的颜色比较，实际应用中可能需要更精确的比较
        return color1.description == color2.description
    }
}

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                if isSelected {
                    Circle()
                        .stroke(Color.themeColor, lineWidth: 3)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isColorDark(color) ? .white : .black)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func isColorDark(_ color: Color) -> Bool {
        // 简化的深色判断，实际应用中可能需要更精确的算法
        if color == .black || color == .blue || color == .purple || color == .brown {
            return true
        }
        return false
    }
}

#Preview {
    ColorPickerView(selectedColor: .constant(.red))
} 