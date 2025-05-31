from fastapi import FastAPI
from pydantic import BaseModel
from model_utils import generate_scaled_model
from fastapi.staticfiles import StaticFiles

app = FastAPI()

class ModelInput(BaseModel):
    gender: str
    height: float
    weight: float
    age: int
    texture: str = None  # 可选贴图文件名
    nickname: str

@app.post("/generate")
def generate_model(input: ModelInput):
    result = generate_scaled_model(
        input.gender, input.height, input.weight, input.texture,
        input.nickname
    )
    return result

app.mount("/models", StaticFiles(directory="generated_models"), name="models")
