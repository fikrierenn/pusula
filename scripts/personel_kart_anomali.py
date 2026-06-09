"""
PERSONEL KARTI ANOMALİ RAPORU (çok sinyalli)
Personel müşteri kartı (DerinCrm.Customer.Group1Id=2) suistimal tespiti.
Sinyaller:
  1. SELF-SCAN: fişi kesen kasiyer = kart sahibi (kendi kartını müşteriye okutuyor)
  2. AYNI GÜN ÇOKLU: tek günde 2+ fiş (personel günde 1 alışveriş yapar; çoklu = farklı müşteriler)
  3. SÜREKLİ: çok sayıda çoklu-gün
  4. ÇOK KASİYER: kart birçok farklı kasiyer elinde (elden ele)
  5. YÜKSEK İNDİRİM: personel indirimi tutarı
  6. BÜYÜK SEPET: ort. fiş tutarı (personel kişisel = küçük; müşteri = büyük)
Çıktı: briefings/personel-kart-anomali.xlsx
Kullanım: python personel_kart_anomali.py [--gun 90]
"""
import sys, os, json, argparse
from pathlib import Path
try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass
import pymssql
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter

R = Path(__file__).resolve().parent.parent
KIRMIZI = "E30622"
NM = "UPPER(LTRIM(RTRIM(us.Name+' '+ISNULL(us.SurName,'')))) COLLATE Turkish_CI_AS = UPPER(LTRIM(RTRIM(c.Name))) COLLATE Turkish_CI_AS"


def cfg():
    e = R / ".env"
    if e.exists():
        for l in e.read_text(encoding="utf-8").splitlines():
            if "=" in l and not l.strip().startswith("#"):
                k, v = l.split("=", 1); os.environ.setdefault(k.strip(), v.strip())
    h = os.environ.get("MSSQL_HOST")
    if h:
        return dict(server=h, user=os.environ.get("MSSQL_USER", "sa"), password=os.environ.get("MSSQL_PASSWORD", ""), database=os.environ.get("MSSQL_DATABASE", "master"))
    return json.loads((R / ".secrets" / "db.json").read_text(encoding="utf-8"))


def get_data(gun):
    c = cfg()
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"], database=c.get("database", "master"), charset="UTF-8", login_timeout=20, timeout=180)
    cur = conn.cursor(as_dict=True)
    cur.execute("""SELECT c.Id, CAST(c.Name AS nvarchar(40)) Personel, CAST(c.PhoneNumber AS nvarchar(15)) Tel,
        COUNT(*) Fis, COUNT(DISTINCT s.UsersId) Kasiyer, COUNT(DISTINCT s.PosId) Kasa,
        COUNT(DISTINCT CAST(s.Date AS date)) Gun,
        CAST(SUM(s.GrossTotal-s.DiscountTotal) AS decimal(18,0)) Ciro,
        CAST(SUM(s.DiscountTotal) AS decimal(18,0)) Indirim,
        SUM(CASE WHEN %s THEN 1 ELSE 0 END) SelfScan
      FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
      JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id=s.CustomersId AND c.Group1Id=2
      JOIN EncoreMerkez.dbo.Users us ON us.Id=s.UsersId
      WHERE s.DocumentsTypeId=1 AND s.Date>=DATEADD(DAY,-%d,CAST(GETDATE() AS date))
      GROUP BY c.Id, CAST(c.Name AS nvarchar(40)), CAST(c.PhoneNumber AS nvarchar(15))
      HAVING COUNT(*)>=3""" % (NM, gun))
    agg = {r["Id"]: r for r in cur.fetchall()}
    cur.execute("""SELECT g.Id, MAX(g.gf) MaxGunFis, SUM(CASE WHEN g.gf>=2 THEN 1 ELSE 0 END) CokluGun
      FROM (SELECT c.Id, CAST(s.Date AS date) gun, COUNT(*) gf
        FROM EncoreMerkez.dbo.Sales s WITH(NOLOCK)
        JOIN DerinCrm.dbo.Customer c WITH(NOLOCK) ON c.Id=s.CustomersId AND c.Group1Id=2
        WHERE s.DocumentsTypeId=1 AND s.Date>=DATEADD(DAY,-%d,CAST(GETDATE() AS date))
        GROUP BY c.Id, CAST(s.Date AS date)) g
      GROUP BY g.Id""" % gun)
    sameday = {r["Id"]: r for r in cur.fetchall()}
    cur.close(); conn.close()
    return agg, sameday


def build(gun):
    agg, sameday = get_data(gun)
    out = []
    for cid, r in agg.items():
        fis = int(r["Fis"]); kas = int(r["Kasiyer"]); ciro = float(r["Ciro"] or 0); ind = float(r["Indirim"] or 0)
        self_ = int(r["SelfScan"]); sd = sameday.get(cid, {})
        maxg = int(sd.get("MaxGunFis") or 1); coklu = int(sd.get("CokluGun") or 0)
        gross = ciro + ind; indp = 100 * ind / gross if gross else 0
        ort = ciro / fis if fis else 0
        # çok-sinyalli skor
        sc = 0; rsn = []
        if self_ >= 3: sc += 3; rsn.append(f"kendi kartını okutuyor ({self_})")
        elif self_ >= 1: sc += 1; rsn.append(f"self-scan ({self_})")
        if maxg >= 4: sc += 3; rsn.append(f"aynı gün {maxg} fiş")
        elif maxg >= 3: sc += 2; rsn.append(f"aynı gün {maxg}")
        if coklu >= 8: sc += 2; rsn.append(f"{coklu} gün çoklu")
        elif coklu >= 4: sc += 1; rsn.append(f"{coklu} gün çoklu")
        if kas >= 8: sc += 2; rsn.append(f"{kas} kasiyer")
        elif kas >= 5: sc += 1; rsn.append(f"{kas} kasiyer")
        if indp >= 30 and ind >= 3000: sc += 1; rsn.append(f"indirim %{indp:.0f}")
        out.append(dict(id=cid, ad=r["Personel"], tel=r["Tel"] or "", fis=fis, self_=self_, maxg=maxg,
                        coklu=coklu, kas=kas, kasa=int(r["Kasa"]), gun=int(r["Gun"]), ciro=round(ciro),
                        ind=round(ind), indp=round(indp, 1), ort=round(ort), skor=sc, neden="; ".join(rsn) or "—"))
    out.sort(key=lambda x: (-x["skor"], -x["self_"], -x["maxg"], -x["kas"]))

    wb = Workbook()
    red = PatternFill("solid", fgColor=KIRMIZI); white = Font(color="FFFFFF", bold=True)
    thin = Border(*[Side(style="thin", color="E2E8F0")] * 4)

    def tl(v): return f"{v:,.0f}".replace(",", ".")

    yuksek = [x for x in out if x["skor"] >= 5]; orta = [x for x in out if 3 <= x["skor"] < 5]
    tInd = sum(x["ind"] for x in out); tSelf = sum(x["self_"] for x in out)

    ws = wb.active; ws.title = "Yönetici Özeti"
    ws["A1"] = "BKM KİTAP — PERSONEL KARTI ANOMALİ RAPORU"; ws["A1"].font = Font(bold=True, size=15, color=KIRMIZI)
    ws["A2"] = f"Son {gun} gün · personel kartı (Group1Id=2) · 6 sinyal: self-scan / aynı-gün-çoklu / sürekli / çok-kasiyer / indirim / sepet"; ws["A2"].font = Font(italic=True, color="64748B")
    kpis = [("Personel Kart", tl(len(out))), ("Yüksek Risk", tl(len(yuksek))), ("Orta Risk", tl(len(orta))),
            ("Toplam Self-Scan Fiş", tl(tSelf)), ("Toplam İndirim", tl(tInd) + " ₺")]
    for i, (k, v) in enumerate(kpis):
        ws.cell(4, 1 + i * 2, k).font = Font(size=9, color="64748B")
        ws.cell(5, 1 + i * 2, v).font = Font(bold=True, size=13, color=KIRMIZI)
    lines = ["", "ANOMALİ SİNYALLERİ (skor)",
             "• KENDİ KARTINI OKUTUYOR (self-scan): fişi kesen kasiyer = kart sahibi → kendi personel kartını müşteri alışverişine okutuyor. EN GÜÇLÜ sinyal.",
             "• AYNI GÜN ÇOKLU: tek günde 2+ fiş. Personel günde 1 kez alışveriş yapar; 3-5 fiş = farklı müşterilere okutuluyor.",
             "• SÜREKLİ ÇOKLU-GÜN: birçok günde çoklu kullanım = alışkanlık.",
             "• ÇOK KASİYER: kart birçok farklı kasiyerde = elden ele dolaşıyor.", "",
             "EN YÜKSEK RİSKLİ KARTLAR"]
    for x in (yuksek + orta)[:14]:
        lines.append(f"• {x['ad']} — {x['fis']} fiş · self {x['self_']} · max gün {x['maxg']} · {x['kas']} kasiyer · indirim {tl(x['ind'])} → {x['neden']}")
    lines += ["", "ÖNERİLER",
              "• Yüksek riskli kartların fiş detayını (kasiyer+gün+saat) incele, kasiyerle görüş.",
              "• POS: personel kartı kesen kasiyer = kart sahibiyse uyarı/blok; günde 1 kullanım limiti.",
              "• Personel indirimi sadece kart sahibi hazır + amir onayıyla.", "",
              "Not: Skor inceleme önceliği verir, kanıt değil. Self-scan + aynı-gün-çoklu birlikteyse güçlü şüphe."]
    rr = 7
    for ln in lines:
        cc = ws.cell(rr, 1, ln)
        if ln in ("ANOMALİ SİNYALLERİ (skor)", "ÖNERİLER", "EN YÜKSEK RİSKLİ KARTLAR"): cc.font = Font(bold=True, size=12, color=KIRMIZI)
        elif ln.startswith("Not:"): cc.font = Font(italic=True, size=9, color="64748B")
        else: cc.font = Font(size=10)
        rr += 1
    ws.column_dimensions["A"].width = 36
    for col in "BCDEFGHIJ": ws.column_dimensions[col].width = 14

    d = wb.create_sheet("Anomali Tablosu")
    hdr = ["Skor", "Personel", "CustomersId", "Fiş", "Self-Scan", "Max Gün Fiş", "Çoklu Gün", "Farklı Kasiyer",
           "Farklı Gün", "Ciro ₺", "İndirim ₺", "İnd %", "Ort Sepet ₺", "Anomali Nedeni"]
    for j, h in enumerate(hdr, 1):
        cc = d.cell(1, j, h); cc.fill = red; cc.font = white; cc.alignment = Alignment(horizontal="center"); cc.border = thin
    for i, x in enumerate(out, 2):
        vals = [x["skor"], x["ad"], x["id"], x["fis"], x["self_"], x["maxg"], x["coklu"], x["kas"], x["gun"],
                x["ciro"], x["ind"], x["indp"], x["ort"], x["neden"]]
        for j, v in enumerate(vals, 1):
            cc = d.cell(i, j, v); cc.border = thin
            if j in (4, 5, 6, 7, 8, 9, 10, 11, 13): cc.number_format = "#,##0"
            if j == 12: cc.number_format = "0.0"
        if x["skor"] >= 5:
            for j in range(1, 15): d.cell(i, j).fill = PatternFill("solid", fgColor="FEE2E2")
            d.cell(i, 1).font = Font(bold=True, color="DC2626")
        elif x["skor"] >= 3:
            d.cell(i, 1).font = Font(bold=True, color="B45309")
        if x["self_"] >= 1: d.cell(i, 5).font = Font(bold=True, color="DC2626")
    for j, w in enumerate([6, 26, 12, 8, 10, 11, 10, 13, 10, 12, 12, 8, 12, 40], 1):
        d.column_dimensions[get_column_letter(j)].width = w
    d.freeze_panes = "B2"

    outp = R / "briefings" / "personel-kart-anomali.xlsx"
    wb.save(outp)
    print(f"Excel: {outp}")
    print(f"  {gun} gün · {len(out)} kart · YÜKSEK {len(yuksek)} · ORTA {len(orta)} · self-scan toplam {tSelf} fiş")
    for x in (yuksek)[:6]:
        print(f"    [{x['skor']}] {x['ad']}: {x['neden']}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--gun", type=int, default=90); a = ap.parse_args()
    build(a.gun)
