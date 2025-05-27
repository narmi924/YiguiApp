import bpy
import sys
import os

# 参数解析
argv = sys.argv
argv = argv[argv.index("--") + 1:]
glb_path = argv[0]
output_path = argv[1]
height = float(argv[2])
weight = float(argv[3])
texture_path = argv[4] if len(argv) > 4 else None

# 基准数值与比率计算（增强感知）
STANDARD_HEIGHT = 170.0
STANDARD_WEIGHT = 60.0
STANDARD_BMI = STANDARD_WEIGHT / ((STANDARD_HEIGHT / 100) ** 2)
bmi = weight / ((height / 100) ** 2)
height_ratio = (height / STANDARD_HEIGHT) ** 1.25
bmi_scale = (bmi / STANDARD_BMI) ** 1.4

# 清空并导入模型
bpy.ops.wm.read_homefile(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb_path)

# 查找骨架与 Mesh
armature = None
meshes = []
for obj in bpy.context.scene.objects:
    if obj.type == 'ARMATURE':
        armature = obj
    elif obj.type == 'MESH':
        meshes.append(obj)
if not armature:
    raise RuntimeError("未找到骨架对象")

# 进入姿态模式，调整骨骼比例
bpy.context.view_layer.objects.active = armature
bpy.ops.object.mode_set(mode='POSE')

# 身高控制：拉长 spine_01 ~ spine_05
for name in ["spine_02","spine_03"]:
    bone = armature.pose.bones.get(name)
    if bone:
        bone.scale[1] = height_ratio ** 0.8

# 腰部宽厚度（BMI）
pelvis = armature.pose.bones.get("pelvis")
if pelvis:
    pelvis.scale[0] = bmi_scale
    pelvis.scale[2] = bmi_scale

# 腿部粗壮度
for name in ["thigh_l", "thigh_r", "calf_l", "calf_r"]:
    bone = armature.pose.bones.get(name)
    if bone:
        bone.scale = [bmi_scale, 1.0, bmi_scale]

# 啤酒肚模拟：增强腹部向前与左右扩张
spine03 = armature.pose.bones.get("spine_03")
if spine03:
    spine03.scale[0] *= bmi_scale * 1.15  # 左右
    spine03.scale[2] *= bmi_scale * 1.25  # 前后

bpy.ops.object.mode_set(mode='OBJECT')

# 替换贴图（如提供）
if texture_path and os.path.exists(texture_path):
    for mat in bpy.data.materials:
        for node in mat.node_tree.nodes:
            if node.type == 'TEX_IMAGE':
                try:
                    node.image = bpy.data.images.load(texture_path, check_existing=True)
                except Exception as e:
                    print(f"贴图加载失败: {e}")

# 烘焙变形并移除骨骼
for mesh in meshes:
    mesh.select_set(True)
armature.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
bpy.ops.object.convert(target='MESH')
bpy.data.objects.remove(armature, do_unlink=True)

# 导出 .glb
os.makedirs(os.path.dirname(output_path), exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=output_path,
    export_format='GLB',
    export_apply=True,
    use_selection=False
)
