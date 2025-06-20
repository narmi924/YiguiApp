#!/bin/bash

# 创建task_processor.py
cat > /root/design-server/task_processor.py << 'EOF'
import subprocess
import os
import uuid
import json
import logging
from typing import Dict, Any, List
from datetime import datetime
from sqlalchemy.orm import sessionmaker
from db import engine, DesignProject, Pattern, DesignPattern, TaskStatus

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

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

def process_design_generation(task_id: str, project_id: int, user_nickname: str):
    """处理设计生成任务（异步）"""
    db = SessionLocal()
    
    try:
        # 更新任务状态为处理中
        update_task_status(task_id, "processing", 10)
        
        # 获取项目信息
        project = db.query(DesignProject).filter(DesignProject.id == project_id).first()
        if not project:
            raise Exception("Project not found")
        
        # 获取项目应用的纸样
        patterns = db.query(DesignPattern, Pattern).join(
            Pattern, DesignPattern.pattern_id == Pattern.id
        ).filter(DesignPattern.design_id == project_id).all()
        
        if not patterns:
            raise Exception("No patterns applied to this project")
        
        update_task_status(task_id, "processing", 30)
        
        # 生成唯一文件名
        uuid_filename = str(uuid.uuid4())
        
        # 创建用户设计目录
        user_design_dir = os.path.join("generated_designs", f"{user_nickname}_designs")
        os.makedirs(user_design_dir, exist_ok=True)
        
        # 构建Blender脚本参数
        pattern_data = []
        for design_pattern, pattern in patterns:
            pattern_data.append({
                "pattern_id": pattern.id,
                "name": pattern.name,
                "category": pattern.category,
                "dxf_path": pattern.dxf_path,
                "fabric_texture": design_pattern.fabric_texture,
                "color_hex": design_pattern.color_hex,
                "position_data": design_pattern.position_data
            })
        
        update_task_status(task_id, "processing", 50)
        
        # 准备Blender脚本参数
        script_args = {
            "task_id": task_id,
            "project_id": project_id,
            "model_id": project.model_id,
            "patterns": pattern_data,
            "output_dir": user_design_dir,
            "output_filename": uuid_filename
        }
        
        # 将参数写入临时JSON文件
        args_file = f"/tmp/design_args_{task_id}.json"
        with open(args_file, 'w') as f:
            json.dump(script_args, f, ensure_ascii=False, indent=2)
        
        update_task_status(task_id, "processing", 70)
        
        # 调用Blender进行3D生成（使用进程隔离）
        blender_script = os.path.join("blender_scripts", "design_drape.py")
        blender_cmd = [
            "blender",
            "--background",
            "--python", blender_script,
            "--",
            args_file
        ]
        
        logger.info(f"Executing Blender command: {' '.join(blender_cmd)}")
        
        result = subprocess.run(
            blender_cmd,
            cwd="/root/design-server",
            capture_output=True,
            text=True,
            timeout=300  # 5分钟超时
        )
        
        # 清理临时文件
        if os.path.exists(args_file):
            os.remove(args_file)
        
        if result.returncode != 0:
            error_msg = f"Blender execution failed: {result.stderr}"
            logger.error(error_msg)
            raise Exception(error_msg)
        
        update_task_status(task_id, "processing", 90)
        
        # 检查生成的文件
        output_file = os.path.join(user_design_dir, f"{uuid_filename}.glb")
        if not os.path.exists(output_file):
            raise Exception("Generated GLB file not found")
        
        # 构建文件URL
        glb_url = f"https://yiguiapp.xyz/designs/{user_nickname}_designs/{uuid_filename}.glb"
        
        # 更新项目记录
        project.status = "completed"
        project.uuid_filename = uuid_filename
        project.glb_url = glb_url
        project.updated_at = datetime.utcnow()
        
        db.commit()
        
        # 完成任务
        update_task_status(task_id, "completed", 100, glb_url)
        
        logger.info(f"Design generation completed: {glb_url}")
        
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Design generation failed for task {task_id}: {error_msg}")
        
        # 更新项目状态为失败
        if 'project' in locals():
            project.status = "failed"
            db.commit()
        
        # 更新任务状态为失败
        update_task_status(task_id, "failed", 0, None, error_msg)
        
    finally:
        db.close()

def process_pattern_application(task_id: str, project_id: int, pattern_id: int, fabric_options: Dict[str, Any]):
    """处理纸样应用任务（预留接口）"""
    logger.info(f"Processing pattern application: task_id={task_id}, project_id={project_id}, pattern_id={pattern_id}")
    
    try:
        update_task_status(task_id, "processing", 50)
        
        # 这里可以实现纸样预处理逻辑
        # 例如：验证纸样文件，预计算位置等
        
        update_task_status(task_id, "completed", 100)
        
    except Exception as e:
        error_msg = str(e)
        logger.error(f"Pattern application failed: {error_msg}")
        update_task_status(task_id, "failed", 0, None, error_msg)

def cleanup_old_files(days: int = 7):
    """清理旧的生成文件（定期维护任务）"""
    logger.info(f"Starting cleanup of files older than {days} days")
    
    try:
        designs_dir = "generated_designs"
        if not os.path.exists(designs_dir):
            return
        
        current_time = datetime.now()
        cleaned_count = 0
        
        for user_dir in os.listdir(designs_dir):
            user_path = os.path.join(designs_dir, user_dir)
            if not os.path.isdir(user_path):
                continue
            
            for file_name in os.listdir(user_path):
                file_path = os.path.join(user_path, file_name)
                if os.path.isfile(file_path):
                    # 检查文件修改时间
                    file_mtime = datetime.fromtimestamp(os.path.getmtime(file_path))
                    days_old = (current_time - file_mtime).days
                    
                    if days_old > days:
                        os.remove(file_path)
                        cleaned_count += 1
                        logger.info(f"Deleted old file: {file_path}")
        
        logger.info(f"Cleanup completed: {cleaned_count} files removed")
        
    except Exception as e:
        logger.error(f"Cleanup failed: {str(e)}")

# 工具函数：获取用户模型文件路径
def get_user_model_path(user_nickname: str, model_id: int) -> str:
    """获取用户的3D人体模型文件路径"""
    # 这里需要和model-server协调，获取用户模型文件
    model_dir = "/root/model-server/generated_models"
    user_model_dir = os.path.join(model_dir, f"{user_nickname}_models")
    
    # 查找对应的GLB文件（这里简化处理，实际应该查询数据库）
    if os.path.exists(user_model_dir):
        for file_name in os.listdir(user_model_dir):
            if file_name.endswith('.glb'):
                return os.path.join(user_model_dir, file_name)
    
    # 如果没有找到用户模型，返回默认模型
    return "/root/model-server/base_models/default_human.glb"

# 获取纸样文件路径
def get_pattern_file_path(pattern_id: int) -> str:
    """获取纸样DXF文件的完整路径"""
    db = SessionLocal()
    try:
        pattern = db.query(Pattern).filter(Pattern.id == pattern_id).first()
        if pattern and pattern.dxf_path:
            return os.path.join("pattern_lib", pattern.dxf_path)
        return None
    finally:
        db.close()
EOF

# 创建requirements.txt
cat > /root/design-server/requirements.txt << 'EOF'
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
pymysql==1.1.0
pydantic==2.5.0
python-jose[cryptography]==3.3.0
python-multipart==0.0.6
loguru==0.7.2
dramatiq[redis]==1.15.0
redis==5.0.1
cryptography==41.0.8
EOF

echo "Task processor and requirements created successfully!" 