import coremltools as ct

# 模型路径
model_path = "/root/model-server/mlmodels/Chest_Ratio.mlmodel"

# 加载模型
model = ct.models.MLModel(model_path)

# 输入参数（单位：cm, kg）
input_data = {
    "height": 175.0,
    "weight": 70.0
}

# 预测
output = model.predict(input_data)

print("✅ Chest 预测结果:", output)
