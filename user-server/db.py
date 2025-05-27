from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.orm import Session

# 数据库配置
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

# 会话依赖函数（用于 FastAPI 的 Depends）
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# 用户表模型
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), nullable=False, unique=True)
    password = Column(String(255), nullable=False)
    verification_code = Column(String(10))
    verified = Column(Integer, default=0)
