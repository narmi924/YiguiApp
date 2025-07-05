# 服装设计App技术全景深度分析 (READMEforGemini.md)

## 目录
- [一、前端架构深度分析 (Xcode - SwiftUI)](#一前端架构深度分析)
- [二、后端架构深度分析 (yigui-server)](#二后端架构深度分析)
- [三、核心功能实现逻辑](#三核心功能实现逻辑)
- [四、数据流与API接口](#四数据流与api接口)
- [五、技术实现细节](#五技术实现细节)

---

## 一、前端架构深度分析 (Xcode - SwiftUI)

### 1.1 整体架构模式

#### MVVM架构实现
```swift
// 典型的MVVM结构示例
class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoggedIn = false
    private let networkService = NetworkService.shared
    
    func emailLogin() {
        // 业务逻辑处理
        Task {
            let response = try await networkService.emailLogin(email: email, password: password)
            await MainActor.run {
                self.isLoggedIn = true
            }
        }
    }
}
```

**架构特点：**
- **View**: SwiftUI声明式UI，响应式数据绑定
- **ViewModel**: ObservableObject，处理业务逻辑和状态管理
- **Model**: Codable数据结构，支持JSON序列化
- **Service**: 网络服务、本地存储、3D渲染等功能封装

### 1.2 应用入口与状态管理

#### 应用生命周期管理 (`Yigui2App.swift`)
```swift
@main
struct Yigui2App: App {
    @StateObject private var appStateManager = AppStateManager()
    @StateObject private var authViewModel = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch appStateManager.rootViewState {
                case .welcome: WelcomeView(appStateManager: appStateManager)
                case .signIn: SignInView(appStateManager: appStateManager, authViewModel: authViewModel)
                case .defaultInfo: DefaultInfoView(appStateManager: appStateManager, authViewModel: authViewModel)
                case .mainApp: MainTabView(appStateManager: appStateManager, authViewModel: authViewModel)
                }
            }
        }
    }
}
```

**状态管理逻辑：**
1. **welcome**: 首次启动引导页
2. **signIn**: 登录/注册流程
3. **defaultInfo**: 新用户信息补全
4. **mainApp**: 主应用界面

**启动检查机制：**
```swift
private func checkLoginState() {
    if authViewModel.isLoggedIn || UserDefaults.standard.bool(forKey: "isLoggedIn") {
        authViewModel.loadUserState()
        appStateManager.rootViewState = .mainApp
    }
}
```

### 1.3 用户认证系统详细实现

#### 用户数据模型 (`Models/User.swift`)
```swift
struct User: Codable, Identifiable {
    let id: String
    var email: String
    var nickname: string
    var height: Int?
    var weight: Int?
    var avatarURL: URL?
    var gender: String
}
```

#### 认证流程实现 (`ViewModels/AuthViewModel.swift`, 695行)

**1. 邮箱注册流程：**
```swift
func sendVerificationCode() {
    guard validateEmail() && validatePassword() else { return }
    
    Task {
        let response = try await networkService.emailRegister(
            email: email, 
            password: password, 
            nickname: defaultNickname, 
            gender: "male"
        )
        await MainActor.run {
            self.verificationCodeSent = true
            self.startResendCountdown()
        }
    }
}

func emailRegister() {
    Task {
        // 第一步：验证验证码
        let verifyResponse = try await networkService.verifyEmailCode(email: email, code: verificationCode)
        
        // 第二步：自动登录
        let loginResponse = try await networkService.emailLogin(email: email, password: password)
        
        // 第三步：保存token并获取用户信息
        UserDefaults.standard.set(loginResponse.token, forKey: "token")
        await fetchUserInfo(token: loginResponse.token)
        
        await MainActor.run {
            self.isNewUser = true
            self.isLoggedIn = true
        }
    }
}
```

**2. 用户信息更新逻辑：**
```swift
func updateUserInfo() async {
    guard var user = user else { return }
    
    // 构建更新参数
    let heightInt = Int(height.trimmingCharacters(in: .whitespacesAndNewlines))
    let weightInt = Int(weight.trimmingCharacters(in: .whitespacesAndNewlines))
    
    user.height = heightInt
    user.weight = weightInt
    user.gender = gender
    user.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // 调用网络服务更新
    let updateResponse = try await networkService.updateUserInfo(
        token: token,
        height: heightInt,
        weight: weightInt,
        avatarURL: avatarBase64String,
        gender: gender,
        nickname: user.nickname
    )
    
    // 处理新token
    if let newToken = updateResponse.new_token {
        UserDefaults.standard.set(newToken, forKey: "token")
    }
    
    // 更新本地状态
    self.user = user
    self.saveUserState()
    self.userInfoUpdated.send()
}
```

**3. 本地数据持久化：**
```swift
private func saveUserState() {
    if let encodedUser = try? JSONEncoder().encode(user) {
        UserDefaults.standard.set(encodedUser, forKey: "user")
    }
    UserDefaults.standard.set(isLoggedIn, forKey: "isLoggedIn")
}

func loadUserState() {
    if let userData = UserDefaults.standard.data(forKey: "user") {
        let decodedUser = try? JSONDecoder().decode(User.self, from: userData)
        self.user = decodedUser
        self.isLoggedIn = true
        
        // 判断是否为新用户
        let hasCompleteInfo = decodedUser.height != nil && decodedUser.weight != nil
        self.isNewUser = !hasCompleteInfo
    }
}
```

### 1.4 3D模型系统实现

#### 3D模型数据结构 (`Models/Model3D.swift`, 105行)
```swift
struct Model3D: Identifiable, Codable {
    let id: String
    var name: String
    var height: Int
    var weight: Int
    var modelFileName: String? // 只保存文件名
    var thumbnailURL: URL?
    var isCustom: Bool
    var userId: String?
    
    // 动态计算模型文件URL
    var modelURL: URL? {
        guard let fileName = modelFileName else { return nil }
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let modelsDirectory = documentsDirectory?.appendingPathComponent("Models")
        let modelURL = modelsDirectory?.appendingPathComponent(fileName)
        
        return FileManager.default.fileExists(atPath: modelURL?.path ?? "") ? modelURL : nil
    }
}
```

#### 模型管理ViewModel (`ViewModels/ModelViewModel.swift`, 284行)

**1. 模型生成逻辑：**
```swift
func generateModel(name: String? = nil, height: Int, weight: Int, userId: String?, nickname: String? = nil) {
    let modelName = name ?? "我的模型_\(height)cm_\(weight)kg"
    isLoading = true
    
    guard let generationService = modelGenerationService else {
        self.error = "模型生成服务不可用，请重启应用"
        return
    }
    
    // 获取用户性别信息
    var userGender = "male"
    if let userData = UserDefaults.standard.data(forKey: "user"),
       let user = try? JSONDecoder().decode(User.self, from: userData) {
        userGender = user.gender
    }
    
    generationService.generateAndLoadModel(
        height: Double(height),
        weight: Double(weight), 
        nickname: userNickname,
        gender: userGender
    ) { [weak self] result in
        DispatchQueue.main.async {
            switch result {
            case .success(let modelURL):
                let newModel = Model3D(
                    name: modelName,
                    height: height,
                    weight: weight,
                    modelURL: modelURL,
                    isCustom: true,
                    userId: userId
                )
                self?.models.append(newModel)
                self?.selectedModel = newModel
                self?.saveModels()
                self?.loadSceneForModel(newModel)
                
            case .failure(let error):
                self?.error = error.localizedDescription
            }
            self?.isLoading = false
        }
    }
}
```

**2. 模型场景加载：**
```swift
func loadSceneForModel(_ model: Model3D) {
    self.isLoading = true
    
    if let modelURL = model.modelURL {
        loadModel(from: modelURL)
    } else {
        DispatchQueue.main.async {
            self.error = "该模型没有有效的3D文件，请重新生成模型"
            self.isLoading = false
            self.modelScene = nil
        }
    }
}

private func loadModel(from url: URL) {
    do {
        let scene = try SCNScene(url: url, options: nil)
        DispatchQueue.main.async {
            self.modelScene = scene
            self.isLoading = false
            self.error = nil
        }
    } catch {
        DispatchQueue.main.async {
            self.error = "模型加载失败: \(error.localizedDescription)"
            self.isLoading = false
            self.modelScene = nil
        }
    }
}
```

**3. 智能模型管理：**
```swift
func generateModelFromUserProfile() {
    if let userData = UserDefaults.standard.data(forKey: "user"),
       let user = try? JSONDecoder().decode(User.self, from: userData) {
        
        // 验证身高体重数据有效性
        guard let height = user.height, let weight = user.weight,
              height > 50 && height < 250,
              weight > 20 && weight < 300 else {
            self.error = "请先在个人中心设置有效的身高体重信息"
            return
        }
        
        // 删除旧模型，确保每用户只有一个模型
        let userModels = models.filter { $0.isCustom }
        for oldModel in userModels {
            models.removeAll { $0.id == oldModel.id }
        }
        
        // 生成新模型
        generateModel(height: height, weight: weight, userId: user.id, nickname: user.nickname)
    }
}
```

### 1.5 网络服务层实现

#### 网络服务核心 (`Services/NetworkService.swift`, 435行)

**1. HTTPS配置与SSL处理：**
```swift
class NetworkService {
    static let shared = NetworkService()
    private let baseURL = "https://yiguiapp.xyz/api"
    
    private lazy var urlSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration, delegate: SSLPinningDelegate(), delegateQueue: nil)
        return session
    }()
}
```

**2. 通用请求方法：**
```swift
func performPostRequest<T: Decodable>(endpoint: String, body: [String: Any], token: String? = nil, responseType: T.Type) async throws -> T? {
    guard let url = URL(string: baseURL + endpoint) else {
        throw NetworkError.invalidURL
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    if let token = token {
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, response) = try await urlSession.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse else {
        throw NetworkError.invalidResponse
    }
    
    // 错误处理
    if httpResponse.statusCode == 401 {
        throw NetworkError.unauthorized
    } else if httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 {
        let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw NetworkError.serverError(errorResponse.message)
        } else {
            throw NetworkError.serverError("请求失败：\(errorMessage)")
        }
    }
    
    return try JSONDecoder().decode(responseType, from: data)
}
```

### 1.6 服装设计系统核心实现

#### 设计服务层 (`Services/DesignService.swift`, 545行)

**1. 设计项目管理：**
```swift
class DesignService: ObservableObject {
    private let networkService = NetworkService.shared
    
    func createProject(name: String, modelId: Int?) -> AnyPublisher<DesignProject, Error> {
        return Future { promise in
            Task {
                let token = UserDefaults.standard.string(forKey: "token") ?? ""
                let parameters: [String: Any] = [
                    "project_name": name,
                    "model_id": modelId as Any
                ]
                
                if let result = try await self.networkService.makePostRequest(
                    to: "/v1/design/projects",
                    body: parameters,
                    token: token,
                    responseType: DesignProject.self
                ) {
                    promise(.success(result))
                } else {
                    promise(.failure(NetworkError.invalidResponse))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func applyPatternToProject(
        projectId: Int,
        patternId: Int,
        fabricTexture: String? = "cotton",
        colorHex: String = "#FFFFFF"
    ) -> AnyPublisher<Bool, Error> {
        return Future { promise in
            Task {
                let token = UserDefaults.standard.string(forKey: "token") ?? ""
                let parameters: [String: Any] = [
                    "pattern_id": patternId,
                    "fabric_texture": fabricTexture as Any,
                    "color_hex": colorHex
                ]
                
                if let _ = try await self.networkService.makePostRequest(
                    to: "/v1/design/projects/\(projectId)/apply-pattern",
                    body: parameters,
                    token: token,
                    responseType: ApplyPatternResponse.self
                ) {
                    promise(.success(true))
                } else {
                    promise(.failure(NetworkError.invalidResponse))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
```

**2. 异步3D生成与任务轮询：**
```swift
func generate3DPreview(projectId: Int) -> AnyPublisher<TaskStatus, Error> {
    return Future { promise in
        Task {
            let token = UserDefaults.standard.string(forKey: "token") ?? ""
            
            if let result = try await self.networkService.makePostRequest(
                to: "/v1/design/projects/\(projectId)/generate-preview",
                body: [:],
                token: token,
                responseType: GeneratePreviewResponse.self
            ) {
                let taskStatus = TaskStatus(
                    taskId: result.taskId,
                    status: result.status,
                    progress: 0,
                    resultUrl: nil,
                    errorMessage: nil,
                    createdAt: "",
                    updatedAt: ""
                )
                promise(.success(taskStatus))
            }
        }
    }
    .eraseToAnyPublisher()
}

func pollTaskStatus(taskId: String) -> AnyPublisher<TaskStatus, Error> {
    return Timer.publish(every: 2.0, on: .main, in: .common)
        .autoconnect()
        .flatMap { _ in
            self.getTaskStatus(taskId: taskId)
        }
        .first { taskStatus in
            taskStatus.status == "completed" || taskStatus.status == "failed"
        }
        .eraseToAnyPublisher()
}
```

#### 设计ViewModel (`ViewModels/RealDesignViewModel.swift`, 416行)

**1. 设计状态管理：**
```swift
class RealDesignViewModel: ObservableObject {
    @Published var projects: [DesignProject] = []
    @Published var patterns: [Pattern] = []
    @Published var currentProject: DesignProject?
    @Published var selectedPattern: Pattern?
    @Published var selectedColor: Color = .white
    @Published var selectedFabricTexture: String = "cotton"
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 任务状态跟踪
    @Published var currentTask: TaskStatus?
    @Published var generationProgress: Int = 0
    @Published var isGenerating = false
    
    private let designService = DesignService()
    private var cancellables = Set<AnyCancellable>()
    private var taskPollingCancellable: AnyCancellable?
}
```

**2. 设计流程控制：**
```swift
func createNewProject(name: String) {
    isLoading = true
    
    designService.createProject(name: name, modelId: nil)
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            },
            receiveValue: { [weak self] project in
                self?.projects.insert(project, at: 0)
                self?.currentProject = project
            }
        )
        .store(in: &cancellables)
}

func applySelectedPattern() {
    guard let project = currentProject,
          let pattern = selectedPattern else { return }
    
    let colorHex = selectedColor.toHex()
    
    designService.applyPatternToProject(
        projectId: project.id,
        patternId: pattern.id,
        fabricTexture: selectedFabricTexture,
        colorHex: colorHex
    )
    .receive(on: DispatchQueue.main)
    .sink(
        receiveCompletion: { [weak self] completion in
            if case .failure(let error) = completion {
                self?.handleError(error)
            }
        },
        receiveValue: { [weak self] success in
            if success {
                self?.patternApplied = true
            }
        }
    )
    .store(in: &cancellables)
}

func generate3DDesign() {
    guard let project = currentProject else { return }
    
    isGenerating = true
    generationProgress = 0
    
    designService.generate3DPreview(projectId: project.id)
        .flatMap { taskStatus in
            self.currentTask = taskStatus
            return self.designService.pollTaskStatus(taskId: taskStatus.taskId)
        }
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isGenerating = false
                if case .failure(let error) = completion {
                    self?.handleError(error)
                }
            },
            receiveValue: { [weak self] finalStatus in
                self?.currentTask = finalStatus
                if finalStatus.status == "completed", let resultUrl = finalStatus.resultUrl {
                    self?.generated3DModelURL = URL(string: resultUrl)
                    self?.showGenerated3DModel = true
                }
            }
        )
        .store(in: &cancellables)
}
```

### 1.7 3D渲染系统实现

#### GLB文件3D渲染器 (`Views/ModelViewer/YZGltViewController.swift`, 127行)

**1. SceneKit与GLTFSceneKit集成：**
```swift
import UIKit
import SceneKit
import GLTFSceneKit

class YZGltViewController: UIViewController {
    private var sceneView: SCNView!
    private var scene: SCNScene!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneView()
        setupScene()
        setupCamera()
        setupLighting()
    }
    
    private func setupSceneView() {
        sceneView = SCNView(frame: view.bounds)
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        sceneView.allowsCameraControl = true
        sceneView.showsStatistics = false
        sceneView.backgroundColor = UIColor.clear
        
        // 启用抗锯齿和多重采样
        sceneView.antialiasingMode = .multisampling4X
        
        view.addSubview(sceneView)
    }
    
    private func setupLighting() {
        // 环境光
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor.white
        ambientLight.intensity = 300
        
        let ambientLightNode = SCNNode()
        ambientLightNode.light = ambientLight
        scene.rootNode.addChildNode(ambientLightNode)
        
        // 定向光
        let directionalLight = SCNLight()
        directionalLight.type = .directional
        directionalLight.color = UIColor.white
        directionalLight.intensity = 1000
        directionalLight.shadowMode = .deferred
        
        let directionalLightNode = SCNNode()
        directionalLightNode.light = directionalLight
        directionalLightNode.position = SCNVector3(x: 5, y: 10, z: 5)
        directionalLightNode.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(directionalLightNode)
    }
}
```

**2. GLB文件加载与错误处理：**
```swift
func loadGLB(from url: URL) {
    do {
        let asset = try GLTFAsset(url: url)
        let gltfScene = try asset.defaultScene()
        
        // 清除现有模型
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        
        // 添加新模型
        scene.rootNode.addChildNode(gltfScene)
        
        // 设置材质增强
        enhanceMaterials(in: gltfScene)
        
        // 自动调整模型大小和位置
        adjustModelTransform(gltfScene)
        
        sceneView.scene = scene
        
    } catch {
        print("GLB加载失败: \(error.localizedDescription)")
        showErrorAlert(message: "3D模型加载失败，请重试")
    }
}

private func enhanceMaterials(in node: SCNNode) {
    node.geometry?.materials.forEach { material in
        // 启用PBR渲染
        material.lightingModel = .physicallyBased
        
        // 增强材质属性
        material.roughness.intensity = 0.8
        material.metalness.intensity = 0.1
        
        // 设置双面渲染
        material.isDoubleSided = true
    }
    
    // 递归处理子节点
    node.childNodes.forEach { enhanceMaterials(in: $0) }
}

private func adjustModelTransform(_ node: SCNNode) {
    // 计算边界框
    let (min, max) = node.boundingBox
    let size = max - min
    let maxDimension = max(size.x, max(size.y, size.z))
    
    // 自动缩放以适应视口
    let targetSize: Float = 2.0
    let scale = targetSize / maxDimension
    node.scale = SCNVector3(scale, scale, scale)
    
    // 居中显示
    let center = (min + max) * 0.5
    node.position = SCNVector3(-center.x * scale, -center.y * scale, -center.z * scale)
}
```

### 1.8 主要视图层实现

#### 设计工作台界面 (`Views/Design/DesignView.swift`, 795行)

**1. 响应式界面布局：**
```swift
struct DesignView: View {
    @StateObject private var viewModel = RealDesignViewModel()
    @State private var showingPatternSelection = false
    @State private var showingColorPicker = false
    @State private var showingNewProjectSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        
                        if viewModel.projects.isEmpty {
                            welcomeSection
                        } else {
                            VStack(spacing: 30) {
                                if let currentProject = viewModel.currentProject {
                                    projectInfoSection(for: currentProject)
                                }
                                designToolsSection
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingPatternSelection) {
            PatternSelectionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $viewModel.selectedColor)
        }
        .onAppear {
            viewModel.loadData()
        }
    }
}
```

**2. 设计工具面板：**
```swift
private var designToolsSection: some View {
    VStack(spacing: 25) {
        // 纸样选择
        DesignToolButton(
            title: "选择纸样",
            subtitle: viewModel.selectedPattern?.name ?? "未选择",
            icon: "scissors",
            color: .blue
        ) {
            showingPatternSelection = true
        }
        
        // 颜色选择
        DesignToolButton(
            title: "选择颜色",
            subtitle: "当前颜色",
            icon: "paintpalette",
            color: viewModel.selectedColor
        ) {
            showingColorPicker = true
        }
        
        // 面料选择
        FabricSelectionView(selectedFabric: $viewModel.selectedFabricTexture)
        
        // 生成按钮
        Button(action: {
            viewModel.applySelectedPattern()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                viewModel.generate3DDesign()
            }
        }) {
            if viewModel.isGenerating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("生成中...")
                }
            } else {
                Text("生成3D预览")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(viewModel.selectedPattern == nil || viewModel.isGenerating)
    }
}
```

#### 主导航界面 (`MainTabView.swift`)
```swift
struct MainTabView: View {
    @ObservedObject var appStateManager: AppStateManager
    @ObservedObject var authViewModel: AuthViewModel
    
    var body: some View {
        TabView {
            ModelView(authViewModel: authViewModel)
                .tabItem {
                    Image(systemName: "figure.stand")
                    Text("我的模型")
                }
            
            DesignView()
                .tabItem {
                    Image(systemName: "paintbrush")
                    Text("设计")
                }
            
            WardrobeView()
                .tabItem {
                    Image(systemName: "tshirt")
                    Text("衣橱")
                }
            
            ProfileView(authViewModel: authViewModel, appStateManager: appStateManager)
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("我的")
                }
        }
        .accentColor(.themeColor)
    }
}
```

---

## 二、后端架构深度分析 (yigui-server)

### 2.1 微服务架构设计

#### 服务拆分策略
```
yigui-server/
├── user-server/     (端口8001) - 用户认证服务
├── model-server/    (端口8000) - 3D模型生成服务  
└── design-server/   (端口8002) - 服装设计服务
```

**服务职责划分：**
- **user-server**: 用户注册/登录/信息管理/头像上传
- **model-server**: 3D人体模型生成/Blender脚本调用
- **design-server**: 设计项目/纸样库/3D服装生成

#### Nginx反向代理配置 (`nginx_yiguiapp.conf`)
```nginx
server {
    listen 80;
    server_name yiguiapp.xyz;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name yiguiapp.xyz;
    
    # SSL配置
    ssl_certificate /etc/letsencrypt/live/yiguiapp.xyz/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yiguiapp.xyz/privkey.pem;
    
    # 设计服务路由 (优先级最高)
    location /api/v1/design/ {
        proxy_pass http://127.0.0.1:8002/api/v1/design/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 用户服务路由
    location /api/ {
        proxy_pass http://127.0.0.1:8001/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 模型生成服务路由
    location /generate {
        proxy_pass http://127.0.0.1:8000/generate;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # 静态文件服务
    location /models/ {
        alias /root/model-server/generated_models/;
        expires 1d;
        add_header Cache-Control "public, immutable";
    }
}
```

### 2.2 设计服务详细实现 (design-server)

#### FastAPI应用入口 (`main.py`)
```python
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from design_api import router as design_router

app = FastAPI(title="Design Server", version="1.0.0")

# CORS配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 挂载设计相关API路由
app.include_router(design_router, prefix="/api/v1/design", tags=["design"])

# 静态文件服务
app.mount("/designs", StaticFiles(directory="generated_designs"), name="designs")
app.mount("/patterns", StaticFiles(directory="pattern_lib"), name="patterns")
app.mount("/fabrics", StaticFiles(directory="fabrics"), name="fabrics")

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8002, access_log=True, log_level="info")
```

#### 数据库模型定义 (`db.py`)
```python
from sqlalchemy import create_engine, Column, Integer, String, DateTime, ForeignKey, Boolean, Text, JSON
from sqlalchemy.orm import sessionmaker, declarative_base
from datetime import datetime

# MySQL连接配置
MYSQL_USER = "yigui_user"
MYSQL_PASS = "777077"
MYSQL_HOST = "localhost"
MYSQL_DB = "yigui"

SQLALCHEMY_DATABASE_URL = f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASS}@{MYSQL_HOST}/{MYSQL_DB}"

engine = create_engine(SQLALCHEMY_DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# 设计项目表
class DesignProject(Base):
    __tablename__ = "design_projects"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    project_name = Column(String(255), nullable=False)
    model_id = Column(Integer, nullable=True)
    status = Column(String(50), default='draft')  # draft/completed/generating
    uuid_filename = Column(String(64), nullable=True)
    glb_url = Column(String(500), nullable=True)
    thumbnail_url = Column(String(500), nullable=True)
    task_id = Column(String(64), nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# 纸样库表
class Pattern(Base):
    __tablename__ = "patterns"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    category = Column(String(100), nullable=False)  # shirt/pants/dress
    dxf_path = Column(String(500), nullable=True)
    thumbnail_path = Column(String(500), nullable=True)
    is_system = Column(Boolean, default=True)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

# 设计-纸样关联表
class DesignPattern(Base):
    __tablename__ = "design_patterns"
    
    id = Column(Integer, primary_key=True, index=True)
    design_id = Column(Integer, ForeignKey("design_projects.id"), nullable=False)
    pattern_id = Column(Integer, ForeignKey("patterns.id"), nullable=False)
    fabric_texture = Column(String(255), nullable=True)
    color_hex = Column(String(7), nullable=True)
    position_data = Column(JSON, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)

# 异步任务状态表
class TaskStatus(Base):
    __tablename__ = "task_status"
    
    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(String(64), unique=True, nullable=False)
    user_id = Column(Integer, nullable=False)
    task_type = Column(String(50), nullable=False)
    status = Column(String(50), default='pending')  # pending/processing/completed/failed
    progress = Column(Integer, default=0)
    result_url = Column(String(500), nullable=True)
    error_message = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow) 
```

#### API路由实现 (`design_api.py`, 325行)

**1. 设计项目管理API：**
```python
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import uuid

router = APIRouter()

# Pydantic请求/响应模型
class DesignProjectCreate(BaseModel):
    project_name: str
    model_id: Optional[int] = None

class DesignProjectResponse(BaseModel):
    id: int
    project_name: str
    model_id: Optional[int] = None
    status: str
    uuid_filename: Optional[str] = None
    glb_url: Optional[str] = None
    task_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

@router.post("/projects", response_model=DesignProjectResponse)
def create_design_project(
    project: DesignProjectCreate,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """创建新的设计项目"""
    db_project = DesignProject(
        user_id=current_user["user_id"],
        project_name=project.project_name,
        model_id=project.model_id,
        status="draft"
    )
    
    db.add(db_project)
    db.commit()
    db.refresh(db_project)
    
    return db_project

@router.get("/projects", response_model=List[DesignProjectResponse])
def get_user_projects(
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取用户的所有设计项目"""
    projects = db.query(DesignProject).filter(
        DesignProject.user_id == current_user["user_id"]
    ).order_by(DesignProject.updated_at.desc()).all()
    
    return projects

@router.delete("/projects/{project_id}")
def delete_project(
    project_id: int,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """删除设计项目"""
    project = db.query(DesignProject).filter(
        DesignProject.id == project_id,
        DesignProject.user_id == current_user["user_id"]
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # 删除关联的纸样应用记录
    db.query(DesignPattern).filter(DesignPattern.design_id == project_id).delete()
    
    # 删除GLB文件
    if project.glb_url and project.uuid_filename:
        file_path = os.path.join(
            "generated_designs",
            f"{current_user['nickname']}_designs",
            f"{project.uuid_filename}.glb"
        )
        if os.path.exists(file_path):
            os.remove(file_path)
    
    db.delete(project)
    db.commit()
    
    return {"message": "Project deleted successfully"}
```

**2. 纸样管理API：**
```python
@router.get("/patterns", response_model=List[PatternResponse])
def get_patterns(
    category: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """获取纸样库"""
    query = db.query(Pattern)
    
    if category:
        query = query.filter(Pattern.category == category)
    
    patterns = query.filter(Pattern.is_system == True).all()
    return patterns

@router.get("/patterns/categories")
def get_pattern_categories(db: Session = Depends(get_db)):
    """获取所有纸样分类"""
    categories = db.query(Pattern.category).distinct().all()
    return {"categories": [cat[0] for cat in categories]}

@router.post("/projects/{project_id}/apply-pattern")
def apply_pattern_to_project(
    project_id: int,
    pattern_request: ApplyPatternRequest,
    background_tasks: BackgroundTasks,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """应用纸样到设计项目"""
    # 验证项目所有权
    project = db.query(DesignProject).filter(
        DesignProject.id == project_id,
        DesignProject.user_id == current_user["user_id"]
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # 验证纸样存在
    pattern = db.query(Pattern).filter(Pattern.id == pattern_request.pattern_id).first()
    if not pattern:
        raise HTTPException(status_code=404, detail="Pattern not found")
    
    # 记录纸样应用
    design_pattern = DesignPattern(
        design_id=project_id,
        pattern_id=pattern_request.pattern_id,
        fabric_texture=pattern_request.fabric_texture,
        color_hex=pattern_request.color_hex,
        position_data=pattern_request.position_data
    )
    
    db.add(design_pattern)
    db.commit()
    
    return {"message": "Pattern applied successfully", "design_pattern_id": design_pattern.id}
```

**3. 异步3D生成API：**
```python
@router.post("/projects/{project_id}/generate-preview")
def generate_3d_preview(
    project_id: int,
    background_tasks: BackgroundTasks,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """生成3D预览（异步任务）"""
    # 验证项目所有权
    project = db.query(DesignProject).filter(
        DesignProject.id == project_id,
        DesignProject.user_id == current_user["user_id"]
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # 生成任务ID
    task_id = str(uuid.uuid4())
    
    # 创建任务状态记录
    task_status = TaskStatus(
        task_id=task_id,
        user_id=current_user["user_id"],
        task_type="design_generate",
        status="pending"
    )
    
    db.add(task_status)
    
    # 更新项目状态
    project.status = "generating"
    project.task_id = task_id
    
    db.commit()
    
    # 启动后台任务
    background_tasks.add_task(
        process_design_generation,
        task_id=task_id,
        project_id=project_id,
        user_nickname=current_user["nickname"]
    )
    
    return {
        "message": "Generation started",
        "task_id": task_id,
        "status": "pending"
    }

@router.get("/tasks/{task_id}", response_model=TaskStatusResponse)
def get_task_status(
    task_id: str,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取任务状态"""
    task = db.query(TaskStatus).filter(
        TaskStatus.task_id == task_id,
        TaskStatus.user_id == current_user["user_id"]
    ).first()
    
    if not task:
        raise HTTPException(status_code=404, detail="Task not found")
    
    return task
```

#### 异步任务处理器 (`task_processor.py`, 266行)

**1. 任务状态管理：**
```python
import subprocess
import os
import uuid
import json
import logging
from typing import Dict, Any
from datetime import datetime
from sqlalchemy.orm import sessionmaker

def update_task_status(task_id: str, status: str, progress: int = 0, result_url: str = None, error_message: str = None):
    """更新任务状态"""
    db = SessionLocal()
    try:
        task = db.query(TaskStatus).filter(TaskStatus.task_id == task_id).first()
        if task:
            task.status = status
            task.progress = progress
            if result_url:
                task.result_url = result_url
            if error_message:
                task.error_message = error_message
            task.updated_at = datetime.utcnow()
            db.commit()
            logger.info(f"Task {task_id} updated: {status} ({progress}%)")
    except Exception as e:
        logger.error(f"Failed to update task {task_id}: {str(e)}")
        db.rollback()
    finally:
        db.close()
```

**2. 3D服装生成核心处理：**
```python
def process_design_generation(task_id: str, project_id: int, user_nickname: str):
    """处理设计生成任务（异步）"""
    logger.info(f"Starting design generation: task_id={task_id}, project_id={project_id}")
    
    db = SessionLocal()
    try:
        update_task_status(task_id, "processing", 0)
        
        # 获取项目信息
        project_data = collect_project_data(project_id)
        pattern_data = collect_pattern_data(project_id)
        user_model = locate_user_model(user_nickname)
        
        update_task_status(task_id, "processing", 20)
        
        # 准备Blender环境
        setup_blender_environment()
        
        # 执行3D生成
        glb_path = execute_blender_generation(
            project_data, pattern_data, user_model
        )
        
        update_task_status(task_id, "processing", 80)
        
        # 后处理和文件管理
        final_url = process_generated_file(glb_path, user_nickname)
        
        # 更新数据库
        update_project_completion(project_id, final_url)
        
        update_task_status(task_id, "completed", 100, final_url)
        
    except Exception as e:
        update_task_status(task_id, "failed", 0, None, str(e))
        raise

def get_user_model_path(user_nickname: str, model_id: int) -> str:
    """获取用户的3D人体模型文件路径"""
    model_dir = "/root/model-server/generated_models"
    user_model_dir = os.path.join(model_dir, f"{user_nickname}_models")
    
    # 查找对应的GLB文件
    if os.path.exists(user_model_dir):
        for file_name in os.listdir(user_model_dir):
            if file_name.endswith('.glb'):
                return os.path.join(user_model_dir, file_name)
    
    # 如果没有找到用户模型，返回默认模型
    return "/root/model-server/base_models/default_human.glb"
```

#### JWT认证中间件 (`auth_middleware.py`)

**1. JWT解析与验证：**
```python
from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from typing import Dict, Any

SECRET_KEY = "your_jwt_secret_key"  # 与user-server保持一致
ALGORITHM = "HS256"

security = HTTPBearer()

def decode_jwt_token(token: str) -> Dict[str, Any]:
    """解析JWT token"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token has expired"
        )
    except jwt.JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token"
        )

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """获取当前用户信息"""
    token = credentials.credentials
    payload = decode_jwt_token(token)
    
    # 验证必要字段
    if "user_id" not in payload or "nickname" not in payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload"
        )
    
    return {
        "user_id": payload["user_id"],
        "nickname": payload["nickname"],
        "email": payload.get("email", ""),
        "exp": payload.get("exp")
    }
```

### 2.3 Blender脚本集成系统

#### 服装生成脚本结构 (`blender_scripts/design_drape.py`, 推断~200行)

**当前极简实现（问题根源）：**
```python
import bpy
import json
import sys
import os
from mathutils import Vector

def create_basic_shirt(fabric_color=(1, 1, 1, 1)):
    """创建基础衬衫（当前极简实现）"""
    # 清除所有现有对象
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    
    # 创建圆柱体作为衬衫主体
    bpy.ops.mesh.primitive_cylinder_add(
        radius=1.0,
        depth=2.0,
        location=(0, 0, 1)
    )
    
    shirt = bpy.context.active_object
    shirt.name = "Shirt"
    
    # 简单材质设置
    material = bpy.data.materials.new(name="ShirtMaterial")
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs[0].default_value = fabric_color  # Base Color
    
    # 应用材质
    shirt.data.materials.append(material)
    
    return shirt

def main():
    """主处理函数"""
    # 解析命令行参数
    argv = sys.argv
    argv = argv[argv.index("--") + 1:]  # 获取自定义参数
    
    params_file = None
    output_path = None
    user_model = None
    
    for i, arg in enumerate(argv):
        if arg == "--params_file" and i + 1 < len(argv):
            params_file = argv[i + 1]
        elif arg == "--output_path" and i + 1 < len(argv):
            output_path = argv[i + 1]
        elif arg == "--user_model" and i + 1 < len(argv):
            user_model = argv[i + 1]
    
    if not all([params_file, output_path]):
        print("Missing required parameters")
        sys.exit(1)
    
    # 加载设计参数
    with open(params_file, 'r') as f:
        design_params = json.load(f)
    
    # 解析颜色
    color_hex = "#FFFFFF"
    if design_params["patterns"]:
        color_hex = design_params["patterns"][0].get("color_hex", "#FFFFFF")
    
    # 转换颜色格式
    color_rgb = tuple(int(color_hex[i:i+2], 16) / 255.0 for i in (1, 3, 5)) + (1.0,)
    
    # 创建服装（当前仅为极简圆柱体）
    shirt = create_basic_shirt(color_rgb)
    
    # 注意：这里没有加载用户人体模型，没有使用真实纸样，没有物理模拟
    
    # 导出GLB
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format='GLB',
        export_selected=False,
        export_apply=True
    )
    
    print(f"GLB exported to: {output_path}")

if __name__ == "__main__":
    main()
```

**理想的实现架构（待开发）：**
```python
def create_realistic_garment(pattern_data, fabric_params, user_model_path):
    """创建真实服装（理想实现）"""
    # 1. 加载用户人体模型
    bpy.ops.import_scene.gltf(filepath=user_model_path)
    human_model = bpy.context.selected_objects[0]
    
    # 2. 解析DXF纸样文件
    from ezdxf import readfile
    dxf_doc = readfile(pattern_data["dxf_path"])
    pattern_curves = parse_dxf_to_curves(dxf_doc)
    
    # 3. 2D纸样转3D网格
    garment_mesh = pattern_to_3d_mesh(pattern_curves)
    
    # 4. 设置布料物理属性
    setup_cloth_physics(garment_mesh, human_model)
    
    # 5. 应用PBR材质和贴图
    apply_fabric_material(garment_mesh, fabric_params)
    
    # 6. 运行物理模拟
    run_cloth_simulation(frames=120)
    
    # 7. 烘焙模拟结果
    bake_simulation_results(garment_mesh)
    
    return garment_mesh

def setup_cloth_physics(garment_obj, collision_obj):
    """设置布料物理模拟"""
    # 为服装添加布料修改器
    cloth_modifier = garment_obj.modifiers.new(name="Cloth", type='CLOTH')
    cloth_modifier.settings.quality = 12
    cloth_modifier.settings.mass = 0.3
    cloth_modifier.settings.tension_stiffness = 15
    cloth_modifier.settings.compression_stiffness = 15
    cloth_modifier.settings.shear_stiffness = 5
    cloth_modifier.settings.bending_stiffness = 0.5
    
    # 为人体模型添加碰撞检测
    collision_modifier = collision_obj.modifiers.new(name="Collision", type='COLLISION')
    collision_modifier.settings.thickness_outer = 0.02
    collision_modifier.settings.cloth_friction = 5.0
```

### 2.4 用户认证服务 (user-server, 端口8001)

#### 核心认证API实现
```python
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
import jwt
import bcrypt
from datetime import datetime, timedelta

app = FastAPI()

class UserRegisterRequest(BaseModel):
    email: str
    password: str
    nickname: str
    gender: str = "male"

class LoginResponse(BaseModel):
    token: str
    message: str

@app.post("/register")
async def register_user(user_data: UserRegisterRequest):
    """用户注册（发送验证码）"""
    # 检查邮箱是否已存在
    existing_user = db.query(User).filter(User.email == user_data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # 生成6位验证码
    verification_code = generate_verification_code()
    
    # 发送邮件验证码
    send_email_verification(user_data.email, verification_code)
    
    # 临时存储用户信息（Redis或内存）
    temp_user_data = {
        "email": user_data.email,
        "password": bcrypt.hashpw(user_data.password.encode(), bcrypt.gensalt()),
        "nickname": user_data.nickname,
        "gender": user_data.gender,
        "verification_code": verification_code,
        "created_at": datetime.utcnow()
    }
    
    store_temp_user_data(user_data.email, temp_user_data)
    
    return {"message": "Verification code sent to email"}

@app.post("/verify")
async def verify_email(email: str, code: str):
    """验证邮箱验证码"""
    temp_data = get_temp_user_data(email)
    if not temp_data:
        raise HTTPException(status_code=400, detail="Verification session expired")
    
    if temp_data["verification_code"] != code:
        raise HTTPException(status_code=400, detail="Invalid verification code")
    
    # 创建正式用户记录
    new_user = User(
        email=temp_data["email"],
        password_hash=temp_data["password"],
        nickname=temp_data["nickname"],
        gender=temp_data["gender"],
        is_verified=True
    )
    
    db.add(new_user)
    db.commit()
    
    # 清除临时数据
    clear_temp_user_data(email)
    
    return {"message": "Email verified successfully"}

@app.post("/login", response_model=LoginResponse)
async def login_user(email: str, password: str):
    """用户登录"""
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    if not bcrypt.checkpw(password.encode(), user.password_hash):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    
    # 生成JWT token
    token_payload = {
        "user_id": user.id,
        "email": user.email,
        "nickname": user.nickname,
        "exp": datetime.utcnow() + timedelta(days=30)
    }
    
    token = jwt.encode(token_payload, SECRET_KEY, algorithm="HS256")
    
    return LoginResponse(token=token, message="Login successful")

@app.post("/update_user_info")
async def update_user_info(
    height: int,
    weight: int,
    gender: str,
    nickname: str,
    avatar_url: str = None,
    current_user: User = Depends(get_current_user)
):
    """更新用户信息"""
    current_user.height = height
    current_user.weight = weight
    current_user.gender = gender
    current_user.nickname = nickname
    
    if avatar_url:
        current_user.avatar_url = avatar_url
    
    current_user.updated_at = datetime.utcnow()
    
    db.commit()
    
    # 可能需要刷新token
    new_token = None
    if current_user.nickname != nickname:
        new_token_payload = {
            "user_id": current_user.id,
            "email": current_user.email,
            "nickname": nickname,
            "exp": datetime.utcnow() + timedelta(days=30)
        }
        new_token = jwt.encode(new_token_payload, SECRET_KEY, algorithm="HS256")
    
    return {
        "message": "User info updated successfully",
        "new_token": new_token
    }
```

---

## 三、核心功能实现逻辑

### 3.1 完整的设计流程实现

#### 前端设计流程控制
```swift
// 完整设计流程：项目创建 → 纸样选择 → 参数设置 → 3D生成 → 结果展示
func executeCompleteDesignFlow() {
    // 1. 创建设计项目
    createNewProject(name: "我的设计") { [weak self] project in
        self?.currentProject = project
        
        // 2. 加载纸样库
        self?.loadPatterns()
        
        // 3. 等待用户选择纸样和参数
        self?.waitForUserSelection()
    }
}

func waitForUserSelection() {
    // 用户交互：选择纸样、颜色、面料
    // 通过UI绑定自动更新：selectedPattern, selectedColor, selectedFabricTexture
}

func executeDesignGeneration() {
    guard let project = currentProject,
          let pattern = selectedPattern else { return }
    
    // 4. 应用纸样到项目
    applySelectedPattern() { [weak self] success in
        guard success else { return }
        
        // 5. 生成3D预览
        self?.generate3DDesign() { result in
            switch result {
            case .success(let modelURL):
                // 6. 展示结果
                self?.showGenerated3DModel(url: modelURL)
            case .failure(let error):
                self?.handleError(error)
            }
        }
    }
}
```

#### 后端异步任务协调
```python
async def coordinate_design_generation_pipeline(task_id: str, project_id: int, user_nickname: str):
    """协调整个设计生成管线"""
    try:
        # 1. 初始化任务
        update_task_status(task_id, "processing", 0)
        
        # 2. 收集设计数据
        project_data = collect_project_data(project_id)
        pattern_data = collect_pattern_data(project_id)
        user_model = locate_user_model(user_nickname)
        
        update_task_status(task_id, "processing", 20)
        
        # 3. 准备Blender环境
        setup_blender_environment()
        
        # 4. 执行3D生成
        glb_path = execute_blender_generation(
            project_data, pattern_data, user_model
        )
        
        update_task_status(task_id, "processing", 80)
        
        # 5. 后处理和文件管理
        final_url = process_generated_file(glb_path, user_nickname)
        
        # 6. 更新数据库
        update_project_completion(project_id, final_url)
        
        update_task_status(task_id, "completed", 100, final_url)
        
    except Exception as e:
        update_task_status(task_id, "failed", 0, None, str(e))
        raise
```

### 3.2 数据流与状态同步

#### 前端状态管理策略
```swift
// Combine框架实现响应式数据流
class RealDesignViewModel: ObservableObject {
    // 状态发布者
    @Published var projects: [DesignProject] = []
    @Published var isGenerating = false
    @Published var generationProgress: Int = 0
    
    // 数据流管道
    private var cancellables = Set<AnyCancellable>()
    
    func setupDataFlowPipeline() {
        // 项目列表自动刷新
        Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshProjectsIfNeeded()
            }
            .store(in: &cancellables)
        
        // 任务状态实时轮询
        $currentTask
            .compactMap { $0 }
            .flatMap { task in
                self.designService.pollTaskStatus(taskId: task.taskId)
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.handleTaskStatusUpdate(status)
            }
            .store(in: &cancellables)
    }
    
    func handleTaskStatusUpdate(_ status: TaskStatus) {
        self.currentTask = status
        self.generationProgress = status.progress
        
        switch status.status {
        case "completed":
            self.isGenerating = false
            if let resultUrl = status.resultUrl {
                self.generated3DModelURL = URL(string: resultUrl)
                self.showGenerated3DModel = true
            }
        case "failed":
            self.isGenerating = false
            self.errorMessage = status.errorMessage
            self.showError = true
        default:
            break
        }
    }
}
```

### 3.3 错误处理与恢复机制

#### 分层错误处理策略
```swift
// 网络层错误处理
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(String)
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的网络地址"
        case .invalidResponse:
            return "服务器响应异常"
        case .unauthorized:
            return "身份验证失败，请重新登录"
        case .serverError(let message):
            return "服务器错误：\(message)"
        case .networkUnavailable:
            return "网络连接不可用"
        }
    }
}

// 业务层错误处理
class ErrorHandler {
    static func handle(_ error: Error, in context: String) {
        print("❌ Error in \(context): \(error.localizedDescription)")
        
        switch error {
        case NetworkError.unauthorized:
            // 自动重新登录
            AuthViewModel.shared.logout()
            NotificationCenter.default.post(name: .authRequired, object: nil)
            
        case NetworkError.networkUnavailable:
            // 启用离线模式
            OfflineManager.shared.enableOfflineMode()
            
        case let NetworkError.serverError(message) where message.contains("Blender"):
            // Blender特定错误处理
            DesignErrorRecovery.handleBlenderError(message)
            
        default:
            // 通用错误显示
            UserNotificationManager.showError(error.localizedDescription)
        }
    }
}

// 设计生成错误恢复
class DesignErrorRecovery {
    static func handleBlenderError(_ message: String) {
        if message.contains("timeout") {
            // 超时重试
            retryWithIncreasedTimeout()
        } else if message.contains("memory") {
            // 内存不足，降级处理
            generateWithReducedQuality()
        } else {
            // 未知错误，使用备用方案
            generateWithFallbackMethod()
        }
    }
    
    static func retryWithIncreasedTimeout() {
        // 增加Blender脚本超时时间并重试
    }
    
    static func generateWithReducedQuality() {
        // 使用更简单的几何体生成
    }
    
    static func generateWithFallbackMethod() {
        // 使用预定义的模板生成
    }
}
```

---

**总结：** 本文档详细分析了服装设计App的前后端技术实现，从架构模式、核心功能、数据流、错误处理等多个维度展现了项目的技术全貌。前端采用SwiftUI+MVVM响应式架构，后端采用微服务+异步任务处理，整体技术栈现代化且具备良好的扩展性。当前最大的技术债务在于Blender脚本的3D内容生成质量，这直接影响核心的"虚拟试穿"用户体验。
</rewritten_file>