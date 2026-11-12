import smtplib
import ssl
from email.message import EmailMessage

from . import config


def email_delivery_configured() -> bool:
    return bool(
        config.SMTP_HOST
        and config.SMTP_FROM_EMAIL
        and (not config.SMTP_USERNAME or config.SMTP_PASSWORD)
    )


def send_password_reset_email(recipient: str, token: str) -> None:
    message = EmailMessage()
    message["Subject"] = "Reset your SACCOLens password"
    message["From"] = config.SMTP_FROM_EMAIL
    message["To"] = recipient
    message.set_content(
        "We received a request to reset your SACCOLens password.\n\n"
        f"Enter this one-time reset token in the app:\n{token}\n\n"
        "The token expires in 20 minutes. If you did not request this, "
        "you can ignore this email."
    )

    if config.SMTP_USE_SSL:
        connection = smtplib.SMTP_SSL(
            config.SMTP_HOST,
            config.SMTP_PORT,
            timeout=15,
            context=ssl.create_default_context(),
        )
    else:
        connection = smtplib.SMTP(config.SMTP_HOST, config.SMTP_PORT, timeout=15)

    with connection as server:
        if config.SMTP_STARTTLS and not config.SMTP_USE_SSL:
            server.starttls(context=ssl.create_default_context())
        if config.SMTP_USERNAME:
            server.login(config.SMTP_USERNAME, config.SMTP_PASSWORD)
        server.send_message(message)