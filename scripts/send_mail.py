"""
BKM Kitap — SMTP mail gönderim servisi.

Kullanım:
    python send_mail.py --to fikrieren@gmail.com fikri.eren@bkmkitap.com \
        --subject "BKM Kitap — Pazartesi Brifingi · 20.04.2026" \
        --html brief.html \
        --text brief.txt

Profil seçimi (16.09.2026): Gmail ve kurumsal hesap AYRI profil, --profil ile seçilir.
    python send_mail.py --profil kurumsal --to ... --subject ... --html ...
Profil verilmezse .secrets/smtp.json'daki "varsayilan" kullanılır.

.secrets/smtp.json (çok profilli biçim):
    {
        "varsayilan": "gmail",
        "profiller": {
            "gmail":    {"user": "...@gmail.com", "app_password": "...",
                         "smtp_host": "smtp.gmail.com",  "smtp_port": 587},
            "kurumsal": {"user": "...@bkmkitap.com", "app_password": "...",
                         "smtp_host": "mail.bkmkitap.com", "smtp_port": 587}
        }
    }

Eski düz biçim (tek hesap) de çalışır — geriye uyumlu.
Gmail App Password: https://myaccount.google.com/apppasswords
"""

import argparse
import json
import smtplib
import ssl
import sys
from email.message import EmailMessage
from email.utils import formataddr, make_msgid
from pathlib import Path

# Windows'ta cp1254 default; UTF-8'e zorla ki Turkce karakter ve
# emoji icermesi muhtemel print/log mesajlari Unicode hatasi vermesin.
if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding="utf-8")
        sys.stderr.reconfigure(encoding="utf-8")
    except Exception:
        pass


REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = REPO_ROOT / ".secrets" / "smtp.json"


def load_config(path: Path, profil: str | None = None) -> dict:
    """SMTP ayarını okur.

    İki biçim desteklenir:
      · ÇOK PROFİLLİ (yeni):  {"varsayilan": "gmail", "profiller": {"gmail": {...},
        "kurumsal": {...}}}  → `--profil` ile seçilir, verilmezse `varsayilan`.
      · DÜZ (eski):           {"user": ..., "app_password": ...}
        Geriye uyumluluk için korunur; `--profil` verilirse hata der.

    Parola ASLA ekrana basılmaz; eksikse yalnız hangi profilde eksik olduğu yazılır.
    """
    if not path.exists():
        sys.exit(f"Config bulunamadı: {path}")
    with path.open("r", encoding="utf-8") as f:
        ham = json.load(f)

    if "profiller" in ham:
        profiller = ham["profiller"]
        ad = profil or ham.get("varsayilan")
        if not ad:
            sys.exit(f"Config'de 'varsayilan' yok ve --profil verilmedi. "
                     f"Mevcut profiller: {', '.join(profiller)}")
        if ad not in profiller:
            sys.exit(f"'{ad}' profili yok. Mevcut: {', '.join(profiller)}")
        cfg = dict(profiller[ad])
        cfg["_profil"] = ad
    else:
        if profil:
            sys.exit(f"Config tek profilli (eski biçim), --profil kullanılamaz: {path}")
        cfg = dict(ham)
        cfg["_profil"] = "(tek)"

    for key in ("user", "app_password"):
        if not cfg.get(key):
            sys.exit(f"'{cfg['_profil']}' profilinde '{key}' eksik → {path}\n"
                     f"Parolayı bu dosyaya elle yazın; script parola sormaz.")
    cfg.setdefault("smtp_host", "smtp.gmail.com")
    cfg.setdefault("smtp_port", 587)
    cfg.setdefault("display_name", cfg["user"])
    return cfg


def build_message(
    sender: str,
    display_name: str,
    recipients: list,
    subject: str,
    html_body: str,
    text_body: str | None,
) -> EmailMessage:
    msg = EmailMessage()
    msg["From"] = formataddr((display_name, sender))
    msg["To"] = ", ".join(recipients)
    msg["Subject"] = subject
    msg["Message-ID"] = make_msgid(domain=sender.split("@")[-1])

    if text_body is None:
        # HTML'i plain text'e indirgeyen minimum bir özet
        text_body = (
            "Bu mail HTML formatındadır. Görüntülemek için HTML destekli bir "
            "istemci kullanın.\n"
        )
    msg.set_content(text_body)
    msg.add_alternative(html_body, subtype="html")
    return msg


def send(cfg: dict, msg: EmailMessage) -> None:
    password = cfg["app_password"].replace(" ", "")
    context = ssl.create_default_context()
    with smtplib.SMTP(cfg["smtp_host"], cfg["smtp_port"], timeout=30) as smtp:
        smtp.ehlo()
        smtp.starttls(context=context)
        smtp.ehlo()
        smtp.login(cfg["user"], password)
        smtp.send_message(msg)


def read_file(path: str | None) -> str | None:
    if not path:
        return None
    return Path(path).read_text(encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="BKM Kitap SMTP mail gönderim servisi"
    )
    parser.add_argument(
        "--to",
        nargs="+",
        required=True,
        help="Alıcılar (boşlukla ayrılmış, en az 1)",
    )
    parser.add_argument("--cc", nargs="*", default=[], help="CC alıcılar")
    parser.add_argument("--bcc", nargs="*", default=[], help="BCC alıcılar")
    parser.add_argument("--subject", required=True, help="Mail konusu")
    parser.add_argument(
        "--html",
        required=True,
        help="HTML body dosya yolu (UTF-8)",
    )
    parser.add_argument(
        "--text",
        default=None,
        help="Plain text fallback dosya yolu (opsiyonel)",
    )
    parser.add_argument(
        "--config",
        default=str(DEFAULT_CONFIG),
        help=f"SMTP config JSON yolu (default: {DEFAULT_CONFIG})",
    )
    parser.add_argument(
        "--profil",
        default=None,
        help="SMTP profili: gmail | kurumsal (varsayilan smtp.json'daki 'varsayilan')",
    )
    parser.add_argument(
        "--gorunen-ad",
        default=None,
        help="Gönderen GÖRÜNEN ADI (adres DEĞİŞMEZ). Ör: 'BKM Rapor Botu'. "
             "Profildeki display_name'i yalnız bu çağrı için geçersiz kılar.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Göndermeden önizleme (config + alıcılar ekrana)",
    )
    args = parser.parse_args()

    cfg = load_config(Path(args.config), args.profil)
    html_body = read_file(args.html)
    text_body = read_file(args.text)

    recipients = list(dict.fromkeys(args.to))  # sıra korunarak unique
    cc = list(dict.fromkeys(args.cc))
    bcc = list(dict.fromkeys(args.bcc))

    msg = build_message(
        sender=cfg["user"],
        # ⚠ Yalnız GÖRÜNEN AD değişir; From ADRESİ her zaman kimliği doğrulanmış
        #   hesaptır. Var olmayan bir adresi From'a yazmak (adres sahteciliği)
        #   BİLEREK desteklenmiyor: sunucu reddeder, geçse bile SPF/DKIM düşer
        #   ve mail spam'e gider.
        display_name=args.gorunen_ad or cfg.get("display_name", cfg["user"]),
        recipients=recipients,
        subject=args.subject,
        html_body=html_body,
        text_body=text_body,
    )
    if cc:
        msg["Cc"] = ", ".join(cc)

    all_rcpts = recipients + cc + bcc

    if args.dry_run:
        print(f"[DRY] Profil:  {cfg['_profil']} ({cfg['smtp_host']}:{cfg['smtp_port']})")
        print(f"[DRY] From:    {msg['From']}")
        print(f"[DRY] To:      {msg['To']}")
        if cc:
            print(f"[DRY] Cc:      {msg['Cc']}")
        if bcc:
            print(f"[DRY] Bcc:     {', '.join(bcc)}")
        print(f"[DRY] Subject: {msg['Subject']}")
        print(f"[DRY] HTML bytes: {len(html_body)} / Text bytes: {len(text_body or '')}")
        return 0

    try:
        # send_message Cc'yi otomatik alır, Bcc için explicit to_addrs lazım
        password = cfg["app_password"].replace(" ", "")
        context = ssl.create_default_context()
        with smtplib.SMTP(cfg["smtp_host"], cfg["smtp_port"], timeout=30) as smtp:
            smtp.ehlo()
            smtp.starttls(context=context)
            smtp.ehlo()
            smtp.login(cfg["user"], password)
            smtp.send_message(msg, from_addr=cfg["user"], to_addrs=all_rcpts)
    except smtplib.SMTPAuthenticationError as e:
        sys.exit(
            f"SMTP auth hatası: {e}. App Password'ü kontrol et "
            f"(boşluksuz 16 hane). 2FA aktif olmalı."
        )
    except Exception as e:
        sys.exit(f"Gönderim hatası: {type(e).__name__}: {e}")

    print(f"[OK] Mail gonderildi ({cfg['_profil']} profili): {', '.join(all_rcpts)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
