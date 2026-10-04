import logging
import smtplib
from email.message import EmailMessage

from core.config import get_settings

logger = logging.getLogger(__name__)


def send_password_reset_code_email(
    to_email: str,
    code: str,
    *,
    expire_minutes: int,
) -> None:
    settings = get_settings()
    subject = "마인드리움 비밀번호 재설정 인증번호"
    body = (
        "비밀번호 재설정을 요청하셨습니다.\n\n"
        f"인증번호: {code}\n\n"
        f"인증번호는 {expire_minutes}분 동안만 유효합니다.\n"
        "본인이 요청하지 않았다면 이 메일을 무시해 주세요."
    )

    if not settings.smtp_host:
        logger.warning(
            "[password-reset] SMTP not configured. Reset code for %s: %s",
            to_email,
            code,
        )
        return

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = settings.email_from or settings.smtp_user or "noreply@mindrium.local"
    message["To"] = to_email
    message.set_content(body)

    port = settings.smtp_port or 587
    try:
        with smtplib.SMTP(settings.smtp_host, port, timeout=30) as smtp:
            smtp.ehlo()
            if settings.smtp_user and settings.smtp_password:
                smtp.starttls()
                smtp.ehlo()
                smtp.login(settings.smtp_user, settings.smtp_password)
            smtp.send_message(message)
    except smtplib.SMTPException:
        logger.exception("[password-reset] Failed to send email to %s", to_email)
        raise

    logger.info("[password-reset] Reset code email sent to %s", to_email)
