# -*- coding: utf-8 -*-
"""
Haftalik muhasebe denetim raporu (kapanis-sonrasi mudahale) -> HTML.
Kaynak: bkm.sp_KapanisMudahaleKontrol_v2 (SALT-OKUMA rapor SP'si) — en yeni kapanmis donem.
Yorum: severity/forensic bayraklarindan Turkce ozet (kapanis-sonrasi degisim, gec giris,
       giren=onaylayan, mukerrer, yuvarlak tutar). LLM yok — kural-bazli yorum.
Cikti: raporlar/denetim/muhasebe-denetim.html (sabit) + tarihli kopya.
Zamanlama: register-muhasebe-denetim-task.ps1 (her Pazartesi 08:00, yerel — LAN DB).
Not: ERP'de hicbir yazma yok; SP SELECT-only. pyodbc + ODBC Driver 18 (Turkce varchar dogru).
"""
import os, re, sys, html, datetime, pathlib
import pyodbc

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUTDIR = ROOT / "raporlar" / "denetim"
OUTDIR.mkdir(parents=True, exist_ok=True)

# .env oku (sir runtime'da; literal gomulmez)
ENV = {}
with open(ROOT / ".env", encoding="utf-8") as f:
    for ln in f:
        m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
        if m and not ln.lstrip().startswith("#"):
            ENV[m.group(1)] = m.group(2).strip().strip('"')

host = ENV["MSSQL_HOST"]; port = ENV.get("MSSQL_PORT", "1433")
if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
    sys.exit("Gecersiz host/port (.env)")

cn = pyodbc.connect(
    f"Driver={{ODBC Driver 18 for SQL Server}};Server={host},{port};Database=DerinSISBkm;"
    f"UID={ENV['MSSQL_USER']};PWD={ENV['MSSQL_PASSWORD']};TrustServerCertificate=yes;Timeout=20",
    timeout=20)
cn.timeout = 300

SP = "{CALL bkm.sp_KapanisMudahaleKontrol_v2 (?,?,?,?,?,?,?)}"
# (@Yil,@Ay,@Kaynak,@SadeceGider,@Mod,@GiderKod,@Top) — Yil/Ay NULL = en yeni kapanmis donem


def rows_dicts(cur):
    cols = [d[0] for d in cur.description]
    return [dict(zip(cols, r)) for r in cur.fetchall()]


def tl(v):
    try:
        return f"{float(v):,.0f}".replace(",", ".")
    except Exception:
        return "0"


try:
    with cn.cursor() as cur:
        cur.execute(SP, (None, None, "HEPSI", 1, "OZET", None, 5000))
        ozet = rows_dicts(cur)
    with cn.cursor() as cur:
        cur.execute(SP, (None, None, "HEPSI", 1, "DETAY", None, 5000))
        detay = rows_dicts(cur)
except pyodbc.Error as e:
    # Kapanmis donem yoksa SP RAISERROR firlatir — sessiz degil, rapora yaz.
    msg = str(e)
    (OUTDIR / "muhasebe-denetim.html").write_text(
        f"<html><body><h2>Muhasebe Denetimi</h2><p>Rapor uretilemedi: {html.escape(msg)}</p>"
        f"<p>Olasi sebep: bkm.Fin_AyKapanis'te kapanmis donem yok.</p></body></html>",
        encoding="utf-8")
    sys.exit(f"SP hata: {msg}")
finally:
    cn.close()

donem = ozet[0]["Donem"] if ozet else "—"
tarih = datetime.date.today().strftime("%d.%m.%Y")

# --- Kural-bazli Turkce yorum (bayrak toplamlari) ---
def topla(key): return sum(int(r.get(key) or 0) for r in ozet)
toplam_evrak = topla("EvrakAdet")
sonradan_deg = topla("SonradanDegAdet")
gec_giris    = topla("GecGirisAdet")
giren_onay   = topla("GirenOnayAyniAdet")
mukerrer     = topla("MukerrerAdet")
yuvarlak     = topla("YuvarlakAdet")
toplam_tutar = sum(float(r.get("ToplamTutar") or 0) for r in ozet)

yorumlar = []
if sonradan_deg: yorumlar.append(f"<b>{sonradan_deg}</b> evrak kapanis tarihinden SONRA degistirilmis (en kritik sinyal).")
if gec_giris:    yorumlar.append(f"<b>{gec_giris}</b> evrak kapanmis doneme gec girilmis.")
if giren_onay:   yorumlar.append(f"<b>{giren_onay}</b> evrakta giren ve onaylayan ayni kisi (gorevler ayriligi ihlali).")
if mukerrer:     yorumlar.append(f"<b>{mukerrer}</b> evrak mukerrer gorunumlu (ayni tutar/gun/gider).")
if yuvarlak:     yorumlar.append(f"<b>{yuvarlak}</b> evrak yuvarlak tutarli (>=1000 ve 1000'in kati).")
if not yorumlar: yorumlar.append("Kapanis-sonrasi mudahale sinyali bulunmadi.")

# En riskli ilk 25 evrak
detay_sorted = sorted(detay, key=lambda r: int(r.get("RiskSkor") or 0), reverse=True)[:25]


def risk_renk(s):
    s = int(s or 0)
    return "#b91c1c" if s >= 300 else "#c2410c" if s >= 200 else "#a16207" if s >= 100 else "#6b7280"


satir_html = ""
for r in detay_sorted:
    satir_html += (
        f"<tr>"
        f"<td style='text-align:right;font-weight:700;color:{risk_renk(r.get('RiskSkor'))}'>{int(r.get('RiskSkor') or 0)}</td>"
        f"<td>{html.escape(str(r.get('Kaynak') or ''))}</td>"
        f"<td>{html.escape(str(r.get('EvrakNo') or ''))}</td>"
        f"<td>{html.escape(str(r.get('BelgeTarihi') or ''))}</td>"
        f"<td>{html.escape(str(r.get('DegisimTarihi') or ''))}</td>"
        f"<td style='text-align:right'>{r.get('GunSonra') or 0}</td>"
        f"<td>{html.escape(str(r.get('Giren') or '—'))}</td>"
        f"<td>{html.escape(str(r.get('Onaylayan') or '—'))}</td>"
        f"<td style='text-align:right'>{tl(r.get('Tutar'))}</td>"
        f"<td>{html.escape(str(r.get('Notu') or ''))}</td>"
        f"</tr>")

doc = f"""<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8">
<style>
body{{font-family:Segoe UI,Arial,sans-serif;color:#1f2937;max-width:1000px;margin:0 auto;padding:16px}}
h2{{color:#b91c1c;margin-bottom:2px}} .alt{{color:#6b7280;font-size:13px;margin-top:0}}
.k{{background:#fef2f2;border:1px solid #fecaca;border-radius:8px;padding:10px 14px;margin:12px 0}}
table{{border-collapse:collapse;width:100%;font-size:12px;margin-top:8px}}
th,td{{border:1px solid #e5e7eb;padding:4px 6px;text-align:left}} th{{background:#f3f4f6}}
</style></head><body>
<h2>BKM Kitap — Haftalik Muhasebe Denetimi</h2>
<p class="alt">Donem: <b>{html.escape(str(donem))}</b> (en yeni kapanmis) · Rapor tarihi: {tarih} · Kaynak: kapanis-sonrasi mudahale kontrolu (CAR+FAT+MHS)</p>

<div class="k">
  <div style="font-weight:700;margin-bottom:6px">Ozet — {toplam_evrak} evrak, {tl(toplam_tutar)} TL hareket kapanis sonrasi dokunulmus</div>
  <ul style="margin:4px 0 0 18px;padding:0">{''.join(f'<li>{y}</li>' for y in yorumlar)}</ul>
</div>

<h3 style="margin-bottom:4px">En Riskli 25 Evrak</h3>
<table>
<thead><tr><th style="text-align:right">Risk</th><th>Kaynak</th><th>Evrak No</th><th>Belge</th><th>Degisim</th>
<th style="text-align:right">Gun</th><th>Giren</th><th>Onaylayan</th><th style="text-align:right">Tutar</th><th>Not</th></tr></thead>
<tbody>{satir_html or '<tr><td colspan=10>Kayit yok</td></tr>'}</tbody>
</table>
<p class="alt" style="margin-top:14px">Risk: severity*100 + gun-sonra + yuvarlak/giren=onaylayan/mukerrer ek puan. Panelden inceleme: /muhasebe</p>
</body></html>"""

out = OUTDIR / "muhasebe-denetim.html"
out.write_text(doc, encoding="utf-8")
(OUTDIR / f"{datetime.date.today():%Y-%m-%d}-muhasebe-denetim.html").write_text(doc, encoding="utf-8")
print(f"OK rapor uretildi: {out} ({toplam_evrak} evrak, {len(detay)} detay)")
