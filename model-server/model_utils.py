import os
import shutil
import subprocess
import uuid

from datetime import datetime

def generate_scaled_model(gender, height, weight, texture_name=None, nickname=None):
    base_dir = "/root/model-server"
    base_model_path = os.path.join(base_dir, "base_models", f"{gender}.glb")

    # ==== 更稳健的贴图路径处理 ====
    texture_path = None
    if texture_name and texture_name.strip() != "":
        candidate = os.path.join(base_dir, "base_models", "clothes", texture_name.strip())
        if os.path.exists(candidate):
            texture_path = candidate

    # ==== 针对用户创建目录 & 输出路径 ====
    if not nickname:
        raise RuntimeError("必须提供 nickname")
    timestamp = datetime.now().strftime("%Y-%m-%d-%H-%M-%S")
    # 用户专属模型文件夹
    output_dir = os.path.join(base_dir, "generated_models", f"{nickname}_models")
    os.makedirs(output_dir, exist_ok=True)
    output_glb = os.path.join(output_dir, f"{timestamp}.glb")

    # ==== 构建 Blender 命令 ====
    command = [
        "blender", "--background", "--python", os.path.join(base_dir, "scale_model.py"),
        "--", base_model_path, output_glb, str(height), str(weight)
    ]
    if texture_path:
        command.append(texture_path)

    try:
        subprocess.run(command, check=True)
    except subprocess.CalledProcessError as e:
        raise RuntimeError(f"Blender 执行失败: {e}")

     # 检查GLB文件是否生成成功
    if not os.path.exists(output_glb):
        raise RuntimeError(f"GLB文件生成失败: {output_glb}")

    # 直接返回用户专属子目录下的 URL
    return {
        "glb_url": f"https://yiguiapp.xyz/models/{nickname}_models/{timestamp}.glb"
    }