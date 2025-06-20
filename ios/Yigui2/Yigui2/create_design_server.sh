#!/bin/bash

# 创建main.py
cat > /root/design-server/main.py << 'EOF'
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

# 挂载设计相关API路由，使用版本前缀
app.include_router(design_router, prefix="/api/v1/design", tags=["design"])

# 静态文件服务
app.mount("/designs", StaticFiles(directory="generated_designs"), name="designs")
app.mount("/patterns", StaticFiles(directory="pattern_lib"), name="patterns")
app.mount("/fabrics", StaticFiles(directory="fabrics"), name="fabrics")

@app.get("/")
def read_root():
    return {"message": "Design Server is running", "version": "1.0.0"}

@app.get("/health")
def health_check():
    return {"status": "healthy", "service": "design-server"}

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8002,
        access_log=True,
        log_level="info"
    )
EOF

# 创建db.py
cat > /root/design-server/db.py << 'EOF'
from sqlalchemy import create_engine, Column, Integer, String, DateTime, ForeignKey, Boolean, Text, JSON
from sqlalchemy.orm import sessionmaker, declarative_base, relationship
from sqlalchemy.orm import Session
from datetime import datetime

# 数据库配置（与user-server保持一致）
MYSQL_USER = "yigui_user"
MYSQL_PASS = "777077"
MYSQL_HOST = "localhost"
MYSQL_DB = "yigui"

# 连接字符串
SQLALCHEMY_DATABASE_URL = f"mysql+pymysql://{MYSQL_USER}:{MYSQL_PASS}@{MYSQL_HOST}/{MYSQL_DB}"

# 引擎与会话工厂
engine = create_engine(SQLALCHEMY_DATABASE_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 基类
Base = declarative_base()

# 会话依赖函数
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 设计项目表
class DesignProject(Base):
    __tablename__ = "design_projects"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, nullable=False)
    project_name = Column(String(255), nullable=False)
    model_id = Column(Integer, nullable=True)  # 关联到models表
    status = Column(String(50), default='draft')  # draft/completed/generating
    uuid_filename = Column(String(64), nullable=True)  # UUID文件名
    glb_url = Column(String(500), nullable=True)  # 生成的GLB文件URL
    thumbnail_url = Column(String(500), nullable=True)  # 缩略图URL
    task_id = Column(String(64), nullable=True)  # 异步任务ID
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# 2D纸样库表
class Pattern(Base):
    __tablename__ = "patterns"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    category = Column(String(100), nullable=False)  # shirt/pants/dress等
    dxf_path = Column(String(500), nullable=True)  # DXF文件路径
    thumbnail_path = Column(String(500), nullable=True)
    is_system = Column(Boolean, default=True)  # 系统预设还是用户上传
    description = Column(Text, nullable=True)  # 纸样描述
    created_at = Column(DateTime, default=datetime.utcnow)

# 设计-纸样关联表
class DesignPattern(Base):
    __tablename__ = "design_patterns"

    id = Column(Integer, primary_key=True, index=True)
    design_id = Column(Integer, ForeignKey("design_projects.id"), nullable=False)
    pattern_id = Column(Integer, ForeignKey("patterns.id"), nullable=False)
    fabric_texture = Column(String(255), nullable=True)  # 面料纹理
    color_hex = Column(String(7), nullable=True)  # 颜色代码
    position_data = Column(JSON, nullable=True)  # 位置调整数据
    created_at = Column(DateTime, default=datetime.utcnow)

# 任务状态表（用于异步任务跟踪）
class TaskStatus(Base):
    __tablename__ = "task_status"

    id = Column(Integer, primary_key=True, index=True)
    task_id = Column(String(64), unique=True, nullable=False)
    user_id = Column(Integer, nullable=False)
    task_type = Column(String(50), nullable=False)  # design_generate/pattern_apply等
    status = Column(String(50), default='pending')  # pending/processing/completed/failed
    progress = Column(Integer, default=0)  # 0-100 进度百分比
    result_url = Column(String(500), nullable=True)  # 完成后的结果URL
    error_message = Column(Text, nullable=True)  # 错误信息
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

# 创建表（仅在首次部署时运行）
def create_tables():
    Base.metadata.create_all(bind=engine)

if __name__ == "__main__":
    create_tables()
    print("Design server tables created successfully!")
EOF

# 创建auth_middleware.py
cat > /root/design-server/auth_middleware.py << 'EOF'
from fastapi import HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from typing import Dict, Any

# 与user-server保持一致的JWT配置
SECRET_KEY = "your_jwt_secret_key"
ALGORITHM = "HS256"

security = HTTPBearer()

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> Dict[str, Any]:
    """验证JWT token并返回用户信息"""
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("user_id")
        nickname = payload.get("nickname")
        email = payload.get("email")
        
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        return {
            "user_id": user_id,
            "nickname": nickname,
            "email": email
        }
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_current_user(token_data: Dict[str, Any] = Depends(verify_token)) -> Dict[str, Any]:
    """获取当前用户信息的依赖函数"""
    return token_data
EOF

echo "Design server files created successfully!" 