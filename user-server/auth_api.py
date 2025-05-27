from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.orm import Session
from db import get_db, User
from email_utils import send_email_code
import jwt
import random

app = FastAPI()

SECRET_KEY = "your_jwt_secret_key"
ALGORITHM = "HS256"

# 注册模型
class RegisterRequest(BaseModel):
    email: str
    password: str

# 验证模型
class VerifyRequest(BaseModel):
    email: str
    code: str

# 登录模型
class LoginRequest(BaseModel):
    email: str
    password: str

# 通用返回模型
class TokenResponse(BaseModel):
    token: str
    message: str

# 注册接口
@app.post("/register")
def register(request: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter_by(email=request.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="邮箱已注册")

    # 生成 6 位验证码
    code = str(random.randint(100000, 999999))
    success = send_email_code(request.email, code)
    if not success:
        raise HTTPException(status_code=500, detail="验证码发送失败")

    # 插入数据库
    user = User(
        email=request.email,
        password=request.password,
        verification_code=code,
        verified=False
    )
    db.add(user)
    db.commit()
    return {"message": "注册成功，验证码已发送至邮箱"}

# 验证邮箱验证码
@app.post("/verify")
def verify(request: VerifyRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter_by(email=request.email).first()
    if not user:
        raise HTTPException(status_code=404, detail="用户不存在")

    if user.verification_code != request.code:
        raise HTTPException(status_code=400, detail="验证码错误")

    user.verified = True
    db.commit()
    return {"message": "验证成功"}

# 登录接口
@app.post("/login", response_model=TokenResponse)
def login(request: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter_by(email=request.email, password=request.password).first()
    if not user:
        raise HTTPException(status_code=401, detail="邮箱或密码错误")
    if not user.verified:
        raise HTTPException(status_code=403, detail="邮箱未验证")

    token = jwt.encode({"user_id": user.id}, SECRET_KEY, algorithm=ALGORITHM)
    return TokenResponse(token=token, message="登录成功")
