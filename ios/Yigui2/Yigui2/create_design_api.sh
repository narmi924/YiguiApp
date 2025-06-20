#!/bin/bash

# 创建design_api.py
cat > /root/design-server/design_api.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import uuid
import os
import json
from datetime import datetime

from db import get_db, DesignProject, Pattern, DesignPattern, TaskStatus
from auth_middleware import get_current_user
from task_processor import process_design_generation, process_pattern_application

router = APIRouter()

# Pydantic模型定义
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
    thumbnail_url: Optional[str] = None
    task_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime

class PatternResponse(BaseModel):
    id: int
    name: str
    category: str
    thumbnail_path: Optional[str] = None
    description: Optional[str] = None
    is_system: bool

class ApplyPatternRequest(BaseModel):
    pattern_id: int
    fabric_texture: Optional[str] = None
    color_hex: Optional[str] = "#FFFFFF"
    position_data: Optional[Dict[str, Any]] = None

class TaskStatusResponse(BaseModel):
    task_id: str
    status: str
    progress: int
    result_url: Optional[str] = None
    error_message: Optional[str] = None
    created_at: datetime
    updated_at: datetime

# === 设计项目管理 API ===

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

@router.get("/projects/{project_id}", response_model=DesignProjectResponse)
def get_project_detail(
    project_id: int,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取设计项目详情"""
    project = db.query(DesignProject).filter(
        DesignProject.id == project_id,
        DesignProject.user_id == current_user["user_id"]
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    return project

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
    
    # 删除GLB文件（如果存在）
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

# === 纸样管理 API ===

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

# === 设计应用 API ===

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
    
    # 验证纸样是否存在
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

# === 任务状态 API ===

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

@router.get("/projects/{project_id}/patterns", response_model=List[Dict[str, Any]])
def get_project_patterns(
    project_id: int,
    current_user: Dict[str, Any] = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """获取项目应用的纸样"""
    # 验证项目所有权
    project = db.query(DesignProject).filter(
        DesignProject.id == project_id,
        DesignProject.user_id == current_user["user_id"]
    ).first()
    
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")
    
    # 查询应用的纸样
    patterns = db.query(DesignPattern, Pattern).join(
        Pattern, DesignPattern.pattern_id == Pattern.id
    ).filter(DesignPattern.design_id == project_id).all()
    
    result = []
    for design_pattern, pattern in patterns:
        result.append({
            "design_pattern_id": design_pattern.id,
            "pattern": {
                "id": pattern.id,
                "name": pattern.name,
                "category": pattern.category,
                "thumbnail_path": pattern.thumbnail_path
            },
            "fabric_texture": design_pattern.fabric_texture,
            "color_hex": design_pattern.color_hex,
            "position_data": design_pattern.position_data,
            "created_at": design_pattern.created_at
        })
    
    return result

# === 健康检查 ===

@router.get("/health")
def design_health_check():
    """设计服务健康检查"""
    return {
        "status": "healthy",
        "service": "design-api",
        "timestamp": datetime.utcnow().isoformat()
    }
EOF

echo "Design API created successfully!" 