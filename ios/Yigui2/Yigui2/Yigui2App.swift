//
//  Yigui2App.swift
//  Yigui2
//
//  Created by 依木然 on 2025/5/3.
//

import SwiftUI

// 应用状态管理器
class AppStateManager: ObservableObject {
    @Published var rootViewState: RootViewState = .welcome
}

enum RootViewState {
    case welcome
    case signIn
    case defaultInfo
    case mainApp
}

@main
struct Yigui2App: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appStateManager = AppStateManager()
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch appStateManager.rootViewState {
                case .welcome:
                    WelcomeView(appStateManager: appStateManager)
                case .signIn:
                    SignInView(appStateManager: appStateManager, authViewModel: authViewModel)
                case .defaultInfo:
                    DefaultInfoView(appStateManager: appStateManager, authViewModel: authViewModel)
                case .mainApp:
                    MainTabView(appStateManager: appStateManager, authViewModel: authViewModel)
                }
            }
            .onAppear {
                checkLoginState()
            }
        }
    }
    
    // 检查登录状态
    private func checkLoginState() {
        // 如果已登录，直接跳转到主应用
        if authViewModel.isLoggedIn || UserDefaults.standard.bool(forKey: "isLoggedIn") {
            authViewModel.loadUserState()
            appStateManager.rootViewState = .mainApp
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 创建必要的目录结构
        createDirectoryStructure()
        return true
    }
    
    // 创建必要的目录结构
    private func createDirectoryStructure() {
        let fileManager = FileManager.default
        
        // 获取Documents目录路径
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("无法获取Documents目录")
            return
        }
        
        // 创建模型目录（如果不存在）
        let modelsDirectory = documentsDirectory.appendingPathComponent("Models")
        do {
            if !fileManager.fileExists(atPath: modelsDirectory.path) {
                try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
                print("✅ 创建Models目录: \(modelsDirectory.path)")
            }
        } catch {
            print("❌ 创建Models目录失败: \(error.localizedDescription)")
        }
        
        // 创建贴图目录（如果不存在）
        let textureDirectory = documentsDirectory.appendingPathComponent("Textures")
        do {
            if !fileManager.fileExists(atPath: textureDirectory.path) {
                try fileManager.createDirectory(at: textureDirectory, withIntermediateDirectories: true)
                print("✅ 创建Textures目录: \(textureDirectory.path)")
            }
        } catch {
            print("❌ 创建Textures目录失败: \(error.localizedDescription)")
        }
        
        print("📁 应用目录结构初始化完成")
    }
}
