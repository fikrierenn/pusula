# -*- coding: utf-8 -*-
"""
"Satis Analizi <tarih>.xlsx" raporunu yeniden uretir (26 kolon, orijinal kolon sirasi).

Kaynak eslemesi TERS MUHENDISLIKLE OLCULDU (08.09.2026) — kanit:
  sorgular/2026-09-08-satis-analizi-excel-denetim.sql  §10
  · Kategori3 / Kategori1 / Yayinevi / Yazar / BarkodAna / SatisFiyat -> bkm.UrunBilgi
    (Kategori1 = KatAna · Yayinevi = mrkAd — FirmaAd DEGIL) : 4/4 birebir
  · IlkGirisTarihi = MIN(irsHrk.ehTrhS) : 4/4 birebir
  · Satis_* = irsHrk, ehMekan 1/4477/4478, ehTip IN (1,3,4,5,100,101), -SUM(ehAdetN)
    : sezon aylarinda 75/75 birebir (EncoreMerkez alternatifi 63/75 ile elendi)
  · MerkezStok = WMS canli raf+giris (depo.stok_adres_palet_vw, adrsAlanTipID IN (0,1))
    ERP defteri (stokSonAltDepo_vw mekan 12) DEGIL — sql-server-conventions.md kurali
  · Stok_FSM/OZLUCE/ISTYOLU = irsHrk kumulatif as-of (SUM ehAdetN, ehTrhS <= kesim)
    canli stokSonAltDepo_vw DEGIL -- view anlik, gecmis tarih uretemez (olculdu: %99,2 vs %98,1)
  · OdakStok = ent.odak_depo_Stok.StokMiktar — ToplamStok'a DAHIL DEGIL (orijinal de oyle)
  · ToplamStok = MagazaStok + MerkezStok · ToplamStokTutar = ToplamStok * SatisFiyat
  · GunlukOrtalamaSatis = Satis_Toplam / 365
  · PENCERE: --bitis = son KAPALI gun. 365 gun dahil (bas = bitis - 364 gun).
    Orijinal 07.09.2026 dosyasinin penceresi OLCULDU: 07.09.2025 - 06.09.2026
    (yani rapor tarihinin BIR GUN ONCESINE kadar). 400 urunluk ornekte:
      07.09.2025-06.09.2026  393/400  %98,2  <- dogru
      08.09.2025-06.09.2026  369/400  %92,2
      08.09.2025-07.09.2026  364/400  %91,0
    ⇒ 07.09.2026 tarihli raporu uretmek icin: --bitis 2026-09-06
  · Evren: Kategori3 12-deger listesi (olculdu: liste disi 59.826 cesidin 0'i raporda)
           + en az bir stok/satis/sezon degeri sifirdan farkli (OdakStok kosul DEGIL)

Kullanim:
  python scripts/satis_analizi_excel.py
  python scripts/satis_analizi_excel.py --bitis 2026-09-07 --sezon-yil 2025
  python scripts/satis_analizi_excel.py --cikti "D:/tmp/rapor.xlsx"

UYARI: stok kolonlari ANLIK. Gecmis bir gunun raporu birebir yeniden uretilemez
(stokSonAltDepo_vw ve WMS gecmis snapshot tutmaz). Sezon aylari gecmis-sabit -> birebir tutar.
"""
import argparse
import datetime as dt
import os
import re
import sys

import pyodbc
import openpyxl
from openpyxl.cell import WriteOnlyCell
from openpyxl.styles import Font

# Kategori3 evreni — OLCULDU (orijinal dosyadan cikarilip UrunBilgi'ye karsi dogrulandi:
# liste disi 59.826 cesidin hicbiri raporda yok).
KATEGORI3 = [
    "Kitap", "Kırtasiye", "Oyuncak", "Çocuk Kitabı", "Hazırlık Kitapları",
    "Akademi", "Hediyelik", "Elektronik", "Dergi", "Spor & Outdoor",
    "Kafe Hammede", "Zkargo",
]

BASLIKLAR = [
    "Kategori3", "stkID", "BarkodAna", "stkAd", "Kategori1", "Yayinevi", "Yazar",
    "SatisFiyat", "ToplamStokTutar", "ToplamStok", "OdakStok", "IlkGirisTarihi",
    "Stok_FSM", "Stok_OZLUCE", "Stok_ISTYOLU", "MagazaStok", "MerkezStok",
    "Satis_FSM", "Satis_OZLUCE", "Satis_ISTYOLU", "Satis_Toplam",
    "GunlukOrtalamaSatis",
]  # + 3 sezon ayi (tarih basligi) + "Sezon Toplami"

SQL = """
SET NOCOUNT ON;

WITH kat AS (
    SELECT u.stkID, u.Kategori3, u.BarkodAna, u.stkAd, u.KatAna AS Kategori1,
           u.mrkAd AS Yayinevi, u.Yazar, u.SatisFiyat
    FROM bkm.UrunBilgi u WITH (NOLOCK)
    WHERE u.Kategori3 IN ({kat_yer})
),
mgz AS (   -- magaza rafi = HAREKET DEFTERINDEN as-of (kumulatif SUM ehAdetN, ehTrhS <= kesim)
    -- NEDEN view DEGIL: stokSonAltDepo_vw ANLIK -- gecmis bir tarih icin YANLIS deger verir,
    -- yani scripti tekrar-uretilebilir yapmaz. Defter as-of hesaplanabilir.
    -- OLCULDU 08.09.2026 (400 urun, kesim 06.09): defter %99,2 · canli view %98,1.
    -- Kalan sapma raporun GUN ORTASI (07.09 12:32) kesilmesinden: rapor degeri
    -- 06.09-sonu ile 07.09-sonu arasinda kaliyor (400/400 FSM, 399/400 OZL, 398/400 IST).
    SELECT h.ehstkID AS stkID,
           SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END) AS Stok_FSM,
           SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END) AS Stok_OZLUCE,
           SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END) AS Stok_ISTYOLU
    FROM dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTrhS < DATEADD(DAY, 1, CONVERT(date, ?))
    GROUP BY h.ehstkID
),
depo AS (  -- merkez depo = WMS hucresel stok, RAF(0)+GIRIS(1); CIKIS(2) haric
    SELECT d.stkID, SUM(d.Stok) AS MerkezStok
    FROM depo.stok_adres_palet_vw d WITH (NOLOCK)
    WHERE d.adrsAlanTipID IN (0, 1)
    GROUP BY d.stkID
),
ilk AS (   -- IlkGirisTarihi = urunun MAGAZAYA ilk GIRISI (ehAdetN>0, mekan 1/4477/4478)
    -- OLCULDU 08.09.2026, 400 urunluk ornek: 399/400 (%99,8). Elenen adaylar:
    --   MIN(ehTrhS) tum hareket        %72,4 (acilis/sayim kaydini yakaliyor, hep daha ERKEN)
    --   MIN giris, tum mekan           %76,5
    --   MIN alis(0,10) + magaza        %41,0
    --   MIN magaza tum hareket         %99,0 (yakin ama satis-onu kayitlarda sapiyor)
    SELECT h.ehstkID AS stkID, MIN(h.ehTrhS) AS IlkGirisTarihi
    FROM dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehAdetN > 0 AND h.ehMekan IN (1, 4477, 4478)
    GROUP BY h.ehstkID
),
sat AS (   -- 365 gunluk magaza satisi (iade netlenmis: 3/5/101 ters isaretli gelir)
    SELECT h.ehstkID AS stkID,
           -SUM(CASE WHEN h.ehMekan = 1    THEN h.ehAdetN ELSE 0 END) AS Satis_FSM,
           -SUM(CASE WHEN h.ehMekan = 4477 THEN h.ehAdetN ELSE 0 END) AS Satis_OZLUCE,
           -SUM(CASE WHEN h.ehMekan = 4478 THEN h.ehAdetN ELSE 0 END) AS Satis_ISTYOLU
    FROM dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= ? AND h.ehTrhS < DATEADD(DAY, 1, CONVERT(date, ?))
    GROUP BY h.ehstkID
),
sezon AS ( -- gecen sezonun uc ayi (gecmis-sabit)
    SELECT h.ehstkID AS stkID,
           -SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < DATEADD(DAY,1,CONVERT(date,?)) THEN h.ehAdetN ELSE 0 END) AS Ay1,
           -SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < DATEADD(DAY,1,CONVERT(date,?)) THEN h.ehAdetN ELSE 0 END) AS Ay2,
           -SUM(CASE WHEN h.ehTrhS >= ? AND h.ehTrhS < DATEADD(DAY,1,CONVERT(date,?)) THEN h.ehAdetN ELSE 0 END) AS Ay3
    FROM dbo.irsHrk h WITH (NOLOCK)
    WHERE h.ehMekan IN (1, 4477, 4478)
      AND h.ehTip IN (1, 3, 4, 5, 100, 101)
      AND h.ehTrhS >= ? AND h.ehTrhS < DATEADD(DAY, 1, CONVERT(date, ?))
    GROUP BY h.ehstkID
),
ham AS (
    SELECT k.Kategori3, k.stkID, k.BarkodAna, k.stkAd, k.Kategori1, k.Yayinevi, k.Yazar,
           k.SatisFiyat,
           CONVERT(int, ISNULL(o.StokMiktar, 0))    AS OdakStok,
           i.IlkGirisTarihi,
           CONVERT(int, ISNULL(m.Stok_FSM, 0))      AS Stok_FSM,
           CONVERT(int, ISNULL(m.Stok_OZLUCE, 0))   AS Stok_OZLUCE,
           CONVERT(int, ISNULL(m.Stok_ISTYOLU, 0))  AS Stok_ISTYOLU,
           CONVERT(int, ISNULL(d.MerkezStok, 0))    AS MerkezStok,
           CONVERT(int, ISNULL(s.Satis_FSM, 0))     AS Satis_FSM,
           CONVERT(int, ISNULL(s.Satis_OZLUCE, 0))  AS Satis_OZLUCE,
           CONVERT(int, ISNULL(s.Satis_ISTYOLU, 0)) AS Satis_ISTYOLU,
           CONVERT(int, ISNULL(z.Ay1, 0))           AS Ay1,
           CONVERT(int, ISNULL(z.Ay2, 0))           AS Ay2,
           CONVERT(int, ISNULL(z.Ay3, 0))           AS Ay3
    FROM kat k
    LEFT JOIN mgz   m ON m.stkID = k.stkID
    LEFT JOIN depo  d ON d.stkID = k.stkID
    LEFT JOIN ent.odak_depo_Stok o WITH (NOLOCK) ON o.stkID = k.stkID
    LEFT JOIN ilk   i ON i.stkID = k.stkID
    LEFT JOIN sat   s ON s.stkID = k.stkID
    LEFT JOIN sezon z ON z.stkID = k.stkID
)
SELECT Kategori3, stkID, BarkodAna, stkAd, Kategori1, Yayinevi, Yazar,
       SatisFiyat,
       CONVERT(decimal(18,2), (Stok_FSM + Stok_OZLUCE + Stok_ISTYOLU + MerkezStok) * SatisFiyat) AS ToplamStokTutar,
       (Stok_FSM + Stok_OZLUCE + Stok_ISTYOLU + MerkezStok) AS ToplamStok,
       OdakStok, IlkGirisTarihi,
       Stok_FSM, Stok_OZLUCE, Stok_ISTYOLU,
       (Stok_FSM + Stok_OZLUCE + Stok_ISTYOLU) AS MagazaStok,
       MerkezStok,
       Satis_FSM, Satis_OZLUCE, Satis_ISTYOLU,
       (Satis_FSM + Satis_OZLUCE + Satis_ISTYOLU) AS Satis_Toplam,
       CONVERT(float, Satis_FSM + Satis_OZLUCE + Satis_ISTYOLU) / 365.0 AS GunlukOrtalamaSatis,
       Ay1, Ay2, Ay3, (Ay1 + Ay2 + Ay3) AS SezonToplam
FROM ham
WHERE Stok_FSM <> 0 OR Stok_OZLUCE <> 0 OR Stok_ISTYOLU <> 0 OR MerkezStok <> 0
   OR Satis_FSM <> 0 OR Satis_OZLUCE <> 0 OR Satis_ISTYOLU <> 0
   OR Ay1 <> 0 OR Ay2 <> 0 OR Ay3 <> 0
-- NOT: OdakStok evren KOSULU DEGIL. Olculdu (08.09.2026): orijinal dosyada yalniz 13 satir
-- 'sadece OdakStok>0' durumunda; kosula eklenince satir 273.515 -> 447.300'e cikiyor
-- (ent.odak_depo_Stok 496.708 stkID tasiyor). OdakStok yalnizca GOSTERILEN kolon.
ORDER BY stkID
"""


def env_oku():
    yol = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".env")
    env = {}
    with open(yol, encoding="utf-8") as f:
        for ln in f:
            if ln.lstrip().startswith("#"):
                continue
            m = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$", ln)
            if m:
                env[m.group(1)] = m.group(2).strip().strip('"')
    return env


def baglan(env):
    host, port = env["MSSQL_HOST"], env.get("MSSQL_PORT", "1433")
    # ODBC connection-string'e env degeri gomulurken whitelist guard (injection)
    if not re.fullmatch(r"[A-Za-z0-9._\-]+", host) or not re.fullmatch(r"\d+", port):
        sys.exit("Gecersiz MSSQL_HOST/MSSQL_PORT (.env)")
    cn = pyodbc.connect(
        "Driver={ODBC Driver 18 for SQL Server};"
        f"Server={host},{port};Database=DerinSISBkm;"
        f"UID={env['MSSQL_USER']};PWD={env['MSSQL_PASSWORD']};"
        "TrustServerCertificate=yes;Timeout=30",
        timeout=30,
    )
    cn.timeout = 1800  # agir agregalar (irsHrk MIN + 365g pencere)
    return cn


def ay_sinirlari(yil, ay):
    bas = dt.date(yil, ay, 1)
    son = dt.date(yil + (ay == 12), (ay % 12) + 1, 1) - dt.timedelta(days=1)
    return bas, son


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bitis", default=dt.date.today().isoformat(),
                    help="365 gunluk pencerenin son gunu (YYYY-MM-DD). Varsayilan bugun.")
    ap.add_argument("--sezon-yil", type=int, default=2025, help="Sezon yili (Agu-Eki).")
    ap.add_argument("--cikti", default=None, help="Cikti .xlsx yolu.")
    a = ap.parse_args()

    bit = dt.date.fromisoformat(a.bitis)
    bas = bit - dt.timedelta(days=364)          # 365 gun dahil
    aylar = [ay_sinirlari(a.sezon_yil, m) for m in (8, 9, 10)]
    cikti = a.cikti or f"Satis Analizi {bit.strftime('%d.%m.%Y')}.xlsx"

    # Parametre sirasi SQL metnindeki '?' sirasiyla AYNI olmali.
    parm = list(KATEGORI3)                       # kat CTE
    parm += [bit]                                # mgz CTE as-of kesimi
    parm += [bas, bit]                           # sat CTE penceresi
    for ay_bas, ay_son in aylar:                 # sezon CTE ay siniri x3
        parm += [ay_bas, ay_son]
    parm += [aylar[0][0], aylar[2][1]]           # sezon CTE dis WHERE

    sql = SQL.format(kat_yer=", ".join("?" * len(KATEGORI3)))

    env = env_oku()
    print(f"baglaniyor... pencere {bas} .. {bit} · sezon {a.sezon_yil}-08/09/10")
    t0 = dt.datetime.now()
    cn = baglan(env)
    try:
        with cn.cursor() as cur:
            cur.execute(sql, parm)
            satirlar = cur.fetchall()
    finally:
        cn.close()
    print(f"{len(satirlar):,} satir cekildi ({(dt.datetime.now()-t0).seconds}s)")

    wb = openpyxl.Workbook(write_only=True)
    ws = wb.create_sheet("sheet1")
    basliklar = BASLIKLAR + [dt.datetime(ay[0].year, ay[0].month, 1) for ay in aylar]
    basliklar += ["Sezon Toplamı"]
    hucreler = []
    for b in basliklar:
        h = WriteOnlyCell(ws, value=b)
        h.font = Font(bold=True)
        hucreler.append(h)
    ws.append(hucreler)
    for r in satirlar:
        ws.append(list(r))
    wb.save(cikti)
    print(f"yazildi: {cikti}")


if __name__ == "__main__":
    main()
