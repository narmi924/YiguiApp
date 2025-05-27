import os
import shutil

base_dir = "/root/model-server/generated_models"

for item in os.listdir(base_dir):
    path = os.path.join(base_dir, item)
    try:
        if os.path.isfile(path) or os.path.islink(path):
            os.remove(path)
        elif os.path.isdir(path):
            shutil.rmtree(path)
    except Exception as e:
        print(f"无法删除 {path}: {e}")

print("清理完成。")
