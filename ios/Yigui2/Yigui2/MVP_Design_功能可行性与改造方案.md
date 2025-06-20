# MVP Design 功能可行性与改造方案

## 1. 现有目录与服务现状

### 端口配置
- **model-server**: 监听端口 8000
  - 主要功能：根据身高体重生成3D人物模型
  - 静态挂载点：`/models` → `/root/model-server/generated_models`
  
- **user-server**: 监听端口 8001
  - 主要功能：用户认证（注册/登录）、用户信息管理
  - 静态挂载点：`/avatars` → `/root/user-server/avatars`

### 数据库表结构
- **users表**：用户基本信息（email, nickname, password, height, weight, gender等）
- **models表**：用户生成的3D模型记录（user_id, filename, glb_url）
- **avatars表**：用户头像记录（user_id, filename, file_path, is_current）

### 技术栈
- 后端：FastAPI + SQLAlchemy + MySQL
- 3D处理：Blender Python API
- 认证：JWT (HS256算法)
- 静态服务：通过Nginx反向代理，域名 yiguiapp.xyz

## 2. 不破坏现有模型功能的改造思路

### 2.1 服务架构选择

**推荐方案：新建独立的 design-server**

理由：
- 保持服务职责单一，便于维护和扩展
- 避免影响现有模型生成服务的稳定性
- 可独立部署和扩容
- 端口建议：8002

### 2.2 Blender脚本策略

**新增 `design_drape.py` 脚本**，而非复用 `scale_model.py`

理由：
- `scale_model.py` 专注于身体缩放逻辑
- 设计功能需要：
  - 服装悬垂模拟（Cloth Physics）
  - 2D纸样到3D服装的转换
  - 材质和纹理的动态应用
  - 服装与人体模型的适配

### 2.3 数据库设计

**新建设计相关表**，保持数据解耦：

```sql
-- 设计项目表
CREATE TABLE design_projects (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    project_name VARCHAR(255) NOT NULL,
    model_id INT, -- 关联到models表，选择哪个人体模型
    status VARCHAR(50) DEFAULT 'draft', -- draft/completed
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (model_id) REFERENCES models(id)
);

-- 2D纸样库表
CREATE TABLE patterns (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100), -- shirt/pants/dress等
    dxf_path VARCHAR(500), -- DXF文件路径
    thumbnail_path VARCHAR(500),
    is_system BOOLEAN DEFAULT TRUE, -- 系统预设还是用户上传
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 设计-纸样关联表
CREATE TABLE design_patterns (
    id INT PRIMARY KEY AUTO_INCREMENT,
    design_id INT NOT NULL,
    pattern_id INT NOT NULL,
    fabric_texture VARCHAR(255), -- 面料纹理
    color_hex VARCHAR(7), -- 颜色代码
    position_data JSON, -- 位置调整数据
    FOREIGN KEY (design_id) REFERENCES design_projects(id),
    FOREIGN KEY (pattern_id) REFERENCES patterns(id)
);
```

## 3. 目录与文件规划（MVP）

```
/root/design-server/
├── main.py              # FastAPI 入口
├── db.py                # 数据库模型定义
├── auth_middleware.py   # JWT认证中间件
├── design_api.py        # 设计相关API
├── pattern_lib/         # 2D纸样库
│   ├── system/          # 系统预设纸样
│   │   ├── shirt/       # 衬衫类
│   │   ├── pants/       # 裤子类
│   │   └── dress/       # 连衣裙类
│   └── user/            # 用户上传纸样
├── fabrics/             # 面料纹理库
│   ├── cotton/
│   ├── denim/
│   └── silk/
├── generated_designs/   # 生成的设计文件
│   └── {nickname}_designs/
├── blender_scripts/     # Blender脚本
│   ├── design_drape.py  # 服装悬垂模拟
│   └── pattern_to_3d.py # 2D转3D
└── log.txt
```

## 4. 接口草案

### 4.1 设计项目管理

```python
# 创建新设计项目
POST /design/projects
Headers: Authorization: Bearer {token}
Body: {
    "project_name": "夏季休闲装",
    "model_id": 123  # 选择的人体模型ID
}
Response: {
    "id": 456,
    "project_name": "夏季休闲装",
    "status": "draft",
    "created_at": "2025-01-18T10:00:00Z"
}

# 获取用户所有设计项目
GET /design/projects
Headers: Authorization: Bearer {token}
Response: [{
    "id": 456,
    "project_name": "夏季休闲装",
    "status": "draft",
    "thumbnail_url": "https://yiguiapp.xyz/designs/...",
    "created_at": "2025-01-18T10:00:00Z"
}]

# 删除设计项目
DELETE /design/projects/{id}
Headers: Authorization: Bearer {token}

# 应用纸样到设计
POST /design/projects/{id}/apply-pattern
Headers: Authorization: Bearer {token}
Body: {
    "pattern_id": 1,
    "fabric_texture": "cotton_white",
    "color_hex": "#FF6B6B"
}

# 生成3D预览
POST /design/projects/{id}/generate-preview
Headers: Authorization: Bearer {token}
Response: {
    "preview_url": "https://yiguiapp.xyz/designs/{nickname}_designs/preview_123.glb"
}
```

### 4.2 纸样管理

```python
# 获取纸样库
GET /design/patterns?category=shirt
Response: [{
    "id": 1,
    "name": "基础衬衫",
    "category": "shirt",
    "thumbnail_url": "..."
}]
```

## 5. 与现有系统的整合 & 影响

### 5.1 JWT认证复用

创建共享的认证中间件：
```python
# design-server/auth_middleware.py
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt

SECRET_KEY = "your_jwt_secret_key"  # 与user-server一致
security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        return payload
    except:
        raise HTTPException(status_code=401, detail="Invalid token")
```

### 5.2 存储策略

- 复用 `/root/model-server/generated_models` 的父目录结构
- 新建 `generated_designs` 目录，按用户nickname分组
- 共享Nginx静态映射配置

### 5.3 Nginx配置更新

```nginx
# 新增设计服务反向代理
location /api/design/ {
    proxy_pass http://localhost:8002/design/;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}

# 新增设计文件静态服务
location /designs/ {
    alias /root/design-server/generated_designs/;
    add_header Access-Control-Allow-Origin *;
}
```

## 6. 下一步工作列表（按优先级）

1. **创建design-server基础架构**（1天）
   - 创建目录结构
   - 复制db.py并添加新表定义
   - 实现JWT认证中间件
   - 编写FastAPI主入口

2. **准备基础纸样库**（2天）
   - 收集或创建基础服装DXF文件
   - 建立分类目录
   - 生成缩略图

3. **开发Blender服装生成脚本**（3-4天）
   - 研究Cloth Physics API
   - 实现2D纸样到3D的基础转换
   - 测试与人体模型的适配

4. **实现核心API**（2天）
   - 设计项目CRUD
   - 纸样应用逻辑
   - 3D预览生成

5. **iOS客户端集成**（2天）
   - 更新网络服务层
   - 创建设计管理UI
   - 实现3D预览展示

6. **测试与优化**（1天）
   - 端到端测试
   - 性能优化
   - 错误处理完善

**总计预估时间：10-12天完成MVP版本**

## 技术风险与缓解

1. **Blender服装物理模拟性能**
   - 风险：计算密集，可能导致生成时间过长
   - 缓解：简化物理参数，使用预计算缓存

2. **2D纸样到3D转换准确性**
   - 风险：初期可能效果不理想
   - 缓解：先从简单款式开始，逐步迭代

3. **存储空间增长**
   - 风险：GLB文件累积占用大量空间
   - 缓解：定期清理，实现文件生命周期管理 

#补充设计建议（增强系统健壮性与可维护性）
为确保 MVP 阶段的设计功能具备长期可扩展性与稳定性，建议采纳以下六项细节要点：

1. 支持任务队列，避免高并发压爆 Blender
在 design-server 中引入轻量级任务队列框架（如 dramatiq 或 celery + Redis），将 Blender 模型生成任务异步执行，前端获得 task_id 后轮询或使用 WebSocket 监听任务状态，避免主线程阻塞与服务失稳。

2. 使用对象存储替代本地磁盘保存模型文件
考虑将生成的 .glb 文件上传至对象存储（如 Cloudflare R2、阿里云 OSS、MinIO 等兼容 S3 的系统），由数据库记录 glb_url。这样可以避免服务器磁盘无限膨胀，方便后续使用 CDN 加速和迁移部署。

3. 模型文件命名统一使用 UUID，避免命名冲突
所有新生成模型文件命名应使用 uuid4() 生成全局唯一文件名，目录仍按 nickname_models/ 分类保存。项目名和时间戳可作为数据库字段存储，避免重复生成时文件被覆盖或误删除。

4. 使用进程隔离执行 Blender，提高健壮性
推荐在 Blender 调用中使用 subprocess.run([...]) 启动 Blender CLI，而非直接在 FastAPI 主进程中 import bpy。这样可避免 Python GIL 卡顿和内存泄漏风险，后续更易容器化扩展。

5. 增加最小监控与日志记录机制
Uvicorn 启动时加 --access-log 开启访问日志，配合 loguru 写入结构化日志。推荐部署 Prometheus Node Exporter 和 Grafana，用于监控 CPU/内存占用，及时发现 Blender 任务堆积等异常。

6. 所有新接口建议统一加版本前缀 /api/v1/design
所有设计相关路由建议统一挂在 /api/v1/design/* 路径下，为未来多版本 API 管理预留空间，防止后续升级破坏旧版本客户端兼容性。