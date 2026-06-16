"""Merkezi pymssql hata sınıflandırma (plan-12 WS-5 — Hermes error_classifier uyarlaması).

Transient (retry-edilebilir: timeout/ağ/bağlantı) vs fatal (syntax/izin — retry anlamsız).
Dağınık inline `except Exception` yerine tek kaynak. C# tarafı: dashboard/Data/SqlErrorClassifier.cs.

Kullanım:
    from _errors import connect_with_retry
    conn = connect_with_retry(lambda: pymssql.connect(server=..., user=..., ...))
"""
import sys
import time

# Transient mesaj kalıpları (DB-bağımsız ağ/timeout sinyalleri — pymssql exception tipi yetmezse).
_TRANSIENT_PATTERNS = (
    "timeout", "timed out", "connection", "network", "transport",
    "server is not found", "unable to connect", "broken pipe",
    "reset by peer", "deadlock", "20009",  # pymssql DB-Lib net error
)

# Fatal mesaj kalıpları — pymssql bunları OperationalError olarak fırlatır AMA retry anlamsız
# (yanlış şifre/izin/yok-db). Tip-kontrolünden ÖNCE bakılır, yoksa auth-fatal transient maskelenir.
_FATAL_PATTERNS = (
    "login failed", "18456",            # yanlış kimlik bilgisi
    "password",                          # şifre hatası
    "cannot open database",              # yanlış/erişilemez db
    "permission", "access denied",       # izin
)


def is_transient(exc):
    """Hata geçici mi (retry-edilebilir). Fatal-mesaj → tip → transient-mesaj önceliğiyle."""
    msg = str(exc).lower()
    if any(p in msg for p in _FATAL_PATTERNS):
        return False  # auth/izin/yok-db — OperationalError olsa bile retry anlamsız
    try:
        import pymssql
        if isinstance(exc, pymssql.ProgrammingError):
            return False  # syntax / logic — retry anlamsız (fatal)
        if isinstance(exc, (pymssql.OperationalError, pymssql.InterfaceError)):
            return True   # bağlantı / timeout — transient
    except ImportError:
        pass
    return any(p in msg for p in _TRANSIENT_PATTERNS)


def connect_with_retry(connect_fn, max_retry=2, base_delay=0.3, log=sys.stderr):
    """connect_fn() çağrısını transient hatada retry et (max_retry + lineer backoff).

    Fatal veya tükenmiş transient → exception PROPAGATE (sessiz DEĞİL — her retry loglanır;
    error-handling.md 'fallback sessiz olmasın').
    """
    attempt = 0
    while True:
        try:
            return connect_fn()
        except Exception as e:
            if attempt >= max_retry or not is_transient(e):
                raise
            delay = base_delay * (attempt + 1)
            print(f"[db] transient baglanti hatasi (deneme {attempt + 1}/{max_retry + 1}): "
                  f"{e} -- {delay:.1f}s sonra retry", file=log)
            time.sleep(delay)
            attempt += 1
