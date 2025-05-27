import smtplib
from email.mime.text import MIMEText

# 邮箱配置
SMTP_HOST = "smtp.qq.com"
SMTP_PORT = 465
EMAIL_FROM = "2437000215@qq.com"
EMAIL_AUTH_CODE = "wrksmboxygzwdjia"  

def send_email_code(to_email: str, code: str) -> bool:
    subject = "Yigui 注册验证码"
    body = f"您的验证码是：{code}，5分钟内有效，请勿泄露。"

    msg = MIMEText(body, "plain", "utf-8")
    msg["From"] = EMAIL_FROM
    msg["To"] = to_email
    msg["Subject"] = subject

    try:
        server = smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT)
        server.login(EMAIL_FROM, EMAIL_AUTH_CODE)
        server.sendmail(EMAIL_FROM, [to_email], msg.as_string())
        server.quit()
        return True
    except Exception as e:
        print("❌ 邮件发送失败:", e)
        return False
