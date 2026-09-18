"""
zei32Giris_Cikis_GM_Maz — PDKS Crystal raporunun yeniden üretimi.

Kaynak rapor: vardiya/zei32Giris_Cikis_GM_Maz-2.xls (16.09.2026 · HEYKEL · 44 satır)

KOLON EŞLEMESİ (ölçüldü 18.09.2026 — sorgular/2026-09-18-pdks-zei32-kesif.sql)
    Sicil No        TPerTab.Per_PersNr
    Adı / Soyadı    Per_Vorname / Per_Name
    Grup0..Grup5    Per_Grp0..Per_Grp5
    Tarih           TTagZei.TZe_Datum
    Pdks 1. Giris   TTagLes.TLe_VonZeit   ← ⚠ TTagZei DEĞİL
    Pdks 1. Cikis   TTagLes.TLe_BisZeit   ← ⚠ TTagZei DEĞİL
    Gün Modeli      TTagZei.TZe_TagMod
    Mazeret         TTagZei.TZe_AbwArt    (→ TAbwArt sözlüğü)
    Bürüt Süre      TTagZei.TZe_BruttoZeit

⚠⚠ TTagZei'nin TZe_VonZeit/BisZeit'i PLAN segmentidir, kart okutması değil.
   Fiili giriş/çıkış TTagLes'tedir. (sema: pdks_vardiya_plani.plan_saati_kart_saati_degil)

⚠ "BİREBİR AYNI" SABİT BİR HEDEF DEĞİL — PDKS kayıtları geriye dönük düzeltiliyor.
   Ölçüldü: xls 17.09 07:18'de PersNr 463 için 08:50 diyor, aynı gün 20:23'te
   canlı veri 08:52. Bu script CANLI PDKS'i okur; eski bir çıktıyla farkı
   `--karsilastir` ile gösterir, farkı SIFIRLAMAYA ÇALIŞMAZ.

Kullanım:
    python vardiya/zei32_rapor.py --tarih 16.09.2026 --sube HEYKEL
    python vardiya/zei32_rapor.py --bas 31.08.2026 --bit 16.09.2026          # tüm şubeler
    python vardiya/zei32_rapor.py --tarih 16.09.2026 --sube HEYKEL \
           --karsilastir vardiya/zei32Giris_Cikis_GM_Maz-2.xls
"""

import argparse
import datetime as dt
import io
import re
import sys
from pathlib import Path

import pyodbc
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill

if sys.platform == "win32":
    for _s in (sys.stdout, sys.stderr):
        try:
            _s.reconfigure(encoding="utf-8")
        except Exception:
            pass

REPO = Path(__file__).resolve().parent.parent
PANEL = (r"Driver={ODBC Driver 18 for SQL Server};Server=BT-FIKRI\SQLEXPRESS;"
         r"Database=BkmPanel;Trusted_Connection=yes;TrustServerCertificate=yes;"
         r"Login Timeout=10")

BASLIKLAR = ["Sicil No", "Adı", "Soyadı", "Grup0", "Grup1", "Grup2", "Grup3",
             "Grup4", "Grup5", "Tarih", "Pdks 1. Giris", "Pdks 1. Cikis",
             "Gün Modeli", "Mazeret", "Bürüt Süre"]


def cift_atlama(cn, ic_sql: str):
    """LIVE201 → [PDKS] çift atlama.

    ⚠ TIRNAK: iç sorgu (L2) bir kez, dış sarmal (L1) bir kez daha ikiye katlanır.
      Elle sayma — bu fonksiyon dışında ham OPENQUERY yazma.
    """
    l1 = "SELECT * FROM OPENQUERY([PDKS], '" + ic_sql.replace("'", "''") + "') x"
    sql = "SELECT * FROM OPENQUERY(LIVE201, '" + l1.replace("'", "''") + "') y"
    cur = cn.cursor()
    cur.execute(sql)
    kolonlar = [d[0] for d in cur.description]
    satirlar = cur.fetchall()
    cur.close()
    return kolonlar, satirlar


def tarih_oku(metin: str) -> dt.date:
    """DMY zorunlu (sql-server-conventions: yyyy-MM-dd KULLANMA)."""
    m = re.fullmatch(r"(\d{2})\.(\d{2})\.(\d{4})", metin.strip())
    if not m:
        sys.exit(f"Tarih dd.MM.yyyy olmalı: {metin!r}")
    return dt.date(int(m.group(3)), int(m.group(2)), int(m.group(1)))


def saat_metni(v) -> str:
    if v is None:
        return ""
    if isinstance(v, (dt.datetime, dt.time)):
        return v.strftime("%H:%M:%S")
    return str(v)


def mazeret_metni(v) -> str:
    """NG = NORMAL GÜN → kaynak rapor bunu BOŞ bırakır.

    sema codes:PDKS.TAbwArt.Abw_AbwArt — "NG devamsızlık DEĞİL, herkeste var".
    Ölçüldü 18.09: xls'te 44 satırın hiçbirinde 'NG' yok, yalnız YILIZ/DESIZ var.
    """
    m = (v or "").strip()
    return "" if m == "NG" else m


def brut_metni(giris, cikis) -> str:
    """Bürüt Süre = ilk giriş → son çıkış ARALIĞI (saat.dakika).

    ⭐ ÖLÇÜLDÜ 18.09.2026 (Gecoweb 31.08-18.09, 5.601 kişi-gün):
      Türetilmiş adaylar ELENDİ. ErfZeitKo→ErfZeitGe farkı tek günde (16.09
      HEYKEL) 36/36 tutuyordu ama geniş kümede 314 satırda BOŞ kalıyor —
      `ErfZeitKo`/`ErfZeitGe` NULL olabiliyor, `IstZeit` ise dolu:
        PersNr 710 · 07.09 → ErfZeit ikisi de NULL, IstZeit 9.30, kaynak 9.3
        PersNr 189 · 11.09 → ErfZeitGe NULL,        IstZeit 9.16, kaynak 9.16
      ⚠ DERS: tek günde kusursuz tutan türetme, geniş kümede kırıldı. Kolonu
        hesaplamak yerine PDKS'in kendi kolonunu okumak doğrusu.
    8.40 = 8 saat 40 dakika. ONDALIK DEĞİL; 60'a bölmek yanlış sayı üretir.
    """
    if not isinstance(giris, (dt.datetime, dt.time)) or not isinstance(cikis, (dt.datetime, dt.time)):
        return ""
    span = (cikis.hour * 60 + cikis.minute) - (giris.hour * 60 + giris.minute)
    if span < 0:                       # gece vardiyasi, cikis ertesi gun
        span += 24 * 60
    return f"{span // 60}.{span % 60:02d}"


def veri_cek(cn, bas: dt.date, bit: dt.date, sube: str | None,
              ayrilanlar: str = "dahil"):
    b8, t8 = bas.strftime("%Y%m%d"), bit.strftime("%Y%m%d")
    sube_suz = ""
    if sube:
        # Per_Grp2 sonda boşlukla gelir → LTRIM/RTRIM (sema: magaza_ayraci)
        if "'" in sube:
            sys.exit("Şube adında kesme işareti desteklenmiyor: " + sube)
        sube_suz = f" AND LTRIM(RTRIM(p.Per_Grp2)) = '{sube}'"

    # İŞTEN ÇIKMIŞ PERSONEL SÜZGECİ
    # ⚠ ÖLÇÜT `Per_ZeitAktiv` DEĞİLDİR. O alan "zaman takibi açık mı" demektir,
    #   "çalışıyor mu" demez — kart basmayan AKTİF personel de 0 taşır (kullanıcı
    #   teyidi 18.09.2026 + Gecoweb "Personel Bilgileri" ekranı: alan adı
    #   "Za.Takip Aktif", ve o ekranda İŞTEN ÇIKIŞ TARİHİ DİYE BİR ALAN YOKTUR;
    #   "ZT A.Bitiş Tarihi" zaman takibinin bittiği tarihtir, istihdamın değil).
    #
    # ⭐ DOĞRU ÖLÇÜT (İK uygulaması, kullanıcı bildirdi 18.09.2026):
    #   çıkışta kart numarası personel numarasıyla AYNI yapılır + takip kapatılır.
    #   `Per_AuswNr = CONVERT(varchar, Per_PersNr)` AND `Per_ZeitAktiv = 0`
    #
    # ÖLÇÜLDÜ (31.08-30.09.2026, 409 kişi / 8.507 satır):
    #   · ölçüte uyan            68 kişi / 1.488 satır
    #       - dönem ÖNCESİ çıkmış  47 kişi / 1.247 satır · okutma SIFIR
    #       - dönem İÇİNDE çıkmış  21 kişi /   241 satır · okutmalar son iş
    #         gününde kesiliyor (31.08 · 03.09 · 06.09 · 13.09 · 16.09 …) —
    #         desen kuralı DOĞRULUYOR, bunlar gerçekten çalışmış günlerdir.
    #   · BEDELİ: DESIZ ("DEVAMSIZ") 2.611 satırın 713'ü (%27,3) çıkmış personel.
    #     Devamsızlık oranı süzgeçsiz okunursa YANLIŞ olur.
    #
    # `haric` davranışı: 0 okutmalı çıkmışlar TAMAMEN düşer; dönem içinde
    # çıkanların yalnız SON OKUTMASINDAN SONRAKİ hayalet günleri düşer.
    ayrilan_suz = ""
    if ayrilanlar == "haric":
        ayrilan_suz = f"""
        AND NOT ( p.Per_ZeitAktiv = 0
              AND LTRIM(RTRIM(ISNULL(p.Per_AuswNr,''))) = CONVERT(varchar, p.Per_PersNr)
              AND s.TMS_Datum > ISNULL(
                    (SELECT MAX(l3.TLe_Datum) FROM TTagLes l3
                     WHERE l3.TLe_PersNr = p.Per_PersNr
                       AND l3.TLe_Datum >= '{b8}' AND l3.TLe_Datum <= '{t8}'
                       AND l3.TLe_VonZeit IS NOT NULL), '17530101') )"""

    ic = f"""
        SELECT  p.Per_PersNr, p.Per_Vorname, p.Per_Name,
                p.Per_Grp0, p.Per_Grp1, p.Per_Grp2, p.Per_Grp3, p.Per_Grp4, p.Per_Grp5,
                s.TMS_Datum, s.TMS_TagMod, s.TMS_LetzteAbwArt,
                l.ilkVon, l.sonBis
        FROM    TTagMoS s
        INNER JOIN TPerTab p ON p.Per_PersNr = s.TMS_PersNr
        LEFT JOIN (
                -- Gunun SAATLI okutma satirlari. Saatsiz satir (mazeret tasiyan bos
                -- satir) DISLANIR: NULL VonZeit siralamada basa gecip gunun girisini
                -- BOSALTIR (olculdu 3316 03.09, 3366 10.09).
                -- ⚠ TLe_BeginnKz = 0 SUZGECI KOYMA: gece vardiyasi -1 tasir
                --   (olculdu 253 · 10-11.09, 22:42 -> 08:26).
                SELECT  TLe_PersNr, TLe_Datum,
                        ilkVon = MIN(TLe_VonZeit),
                        sonBis = MAX(TLe_BisZeit)
                FROM    TTagLes
                WHERE   TLe_Datum >= '{b8}' AND TLe_Datum <= '{t8}'
                    AND TLe_VonZeit IS NOT NULL
                GROUP BY TLe_PersNr, TLe_Datum) l
             ON l.TLe_PersNr = s.TMS_PersNr AND l.TLe_Datum = s.TMS_Datum
        WHERE   s.TMS_Datum >= '{b8}' AND s.TMS_Datum <= '{t8}'{sube_suz}{ayrilan_suz}
    """
    _, satirlar = cift_atlama(cn, ic)
    if not satirlar:
        sys.exit("KOŞAMADI: PDKS boş döndü — okuma gerçekten yok mu, "
                 "yoksa linked server mi düştü? (boş sonuç 'veri yok' demek DEĞİL)")

    cikti = []
    for r in satirlar:
        (persnr, ad, soyad, g0, g1, g2, g3, g4, g5,
         tarih, tagmod, abwart, giris, cikis) = r
        cikti.append([
            int(persnr),
            (ad or "").strip(), (soyad or "").strip(),
            (g0 or "").strip(), (g1 or "").strip(), (g2 or "").strip(),
            (g3 or "").strip(), (g4 or "").strip(), (g5 or "").strip(),
            tarih.date() if isinstance(tarih, dt.datetime) else tarih,
            saat_metni(giris), saat_metni(cikis),
            (tagmod or "").strip(), mazeret_metni(abwart), brut_metni(giris, cikis),
        ])
    cikti.sort(key=lambda x: (x[9], x[5], x[0]))
    return cikti


def excel_yaz(satirlar, yol: Path):
    wb = Workbook()
    ws = wb.active
    ws.title = "Sheet1"
    ws.append(BASLIKLAR)
    for h in ws[1]:
        h.font = Font(bold=True)
        h.fill = PatternFill("solid", fgColor="DDDDDD")
        h.alignment = Alignment(horizontal="center")
    for s in satirlar:
        ws.append(s)
    ws.freeze_panes = "A2"
    for i, g in enumerate([10, 16, 18, 12, 14, 14, 20, 24, 10, 12, 14, 14, 12, 10, 12], 1):
        ws.column_dimensions[ws.cell(row=1, column=i).column_letter].width = g
    yol.parent.mkdir(parents=True, exist_ok=True)
    wb.save(yol)


def karsilastir(satirlar, xls_yolu: Path):
    """Kaynak .xls ile satır satır fark. Farkı GİZLEMEZ, sayar ve yazar."""
    import xlrd
    sh = xlrd.open_workbook(str(xls_yolu)).sheet_by_index(0)
    kaynak = {}
    for r in range(1, sh.nrows):
        pn = sh.cell_value(r, 0)
        if not pn:
            continue
        kaynak[int(pn)] = [str(sh.cell_value(r, c)).strip() for c in range(sh.ncols)]

    bizim = {s[0]: s for s in satirlar}
    print(f"\n{'='*70}\nKARŞILAŞTIRMA — kaynak {xls_yolu.name}")
    print(f"  kaynak satır : {len(kaynak)}")
    print(f"  bizim satır  : {len(bizim)}")

    yok_bizde = sorted(set(kaynak) - set(bizim))
    yok_kaynak = sorted(set(bizim) - set(kaynak))
    if yok_bizde:
        print(f"  ⚠ kaynakta VAR bizde YOK : {yok_bizde}")
    if yok_kaynak:
        print(f"  ⚠ bizde VAR kaynakta YOK : {yok_kaynak}")

    kolon_adi = {10: "Giriş", 11: "Çıkış", 12: "Gün Modeli", 13: "Mazeret", 14: "Brüt"}
    fark = 0
    for pn in sorted(set(kaynak) & set(bizim)):
        k, b = kaynak[pn], bizim[pn]
        for idx, ad in kolon_adi.items():
            kv = k[idx] if idx < len(k) else ""
            bv = str(b[idx])
            if kv.rstrip("0").rstrip(".") == bv.rstrip("0").rstrip("."):
                continue
            fark += 1
            print(f"    {pn:>6} {k[1]:<14}{k[2]:<16} {ad:<11} kaynak={kv!r:<12} bizim={bv!r}")
    print(f"\n  hücre farkı: {fark}")
    if fark:
        print("  NOT: PDKS geriye dönük düzeltiliyor — eski çıktıyla fark BEKLENİR.")
        print("       sema: pdks_vardiya_plani.geriye_donuk_duzeltme")
    return fark


def main() -> int:
    ap = argparse.ArgumentParser(description="zei32 PDKS raporu — yeniden üretim")
    ap.add_argument("--tarih", help="tek gün (dd.MM.yyyy)")
    ap.add_argument("--bas", help="başlangıç (dd.MM.yyyy)")
    ap.add_argument("--bit", help="bitiş (dd.MM.yyyy)")
    ap.add_argument("--sube", default=None, help="Per_Grp2 (boş = tüm şubeler)")
    ap.add_argument("--cikti", default=None, help="hedef .xlsx")
    ap.add_argument("--karsilastir", default=None, help="kaynak .xls ile fark raporu")
    ap.add_argument("--ayrilanlar", choices=("dahil", "haric"), default="dahil",
                    help="dahil = PDKS kaynağıyla birebir (varsayılan) · "
                         "haric = pasif VE dönemde hiç okutması olmayan personeli çıkar")
    a = ap.parse_args()

    if a.tarih:
        bas = bit = tarih_oku(a.tarih)
    elif a.bas and a.bit:
        bas, bit = tarih_oku(a.bas), tarih_oku(a.bit)
    else:
        return ap.error("--tarih VEYA --bas ile --bit verilmeli")
    if bit < bas:
        sys.exit("Bitiş başlangıçtan önce olamaz.")

    cn = pyodbc.connect(PANEL)
    cn.timeout = 300
    try:
        satirlar = veri_cek(cn, bas, bit, a.sube, a.ayrilanlar)
    finally:
        cn.close()

    etiket = bas.strftime("%Y%m%d") if bas == bit else f"{bas:%Y%m%d}_{bit:%Y%m%d}"
    ek = "" if a.ayrilanlar == "dahil" else "_AYRILANSIZ"
    ad = f"zei32_{etiket}{'_' + a.sube.replace(' ', '') if a.sube else '_TUMSUBE'}{ek}.xlsx"
    yol = Path(a.cikti) if a.cikti else REPO / "vardiya" / ad
    excel_yaz(satirlar, yol)

    kisi = len({s[0] for s in satirlar})
    gun = len({s[9] for s in satirlar})
    print(f"[OK] {yol}")
    print(f"     {len(satirlar)} satır · {kisi} kişi · {gun} gün"
          f"{' · ' + a.sube if a.sube else ' · tüm şubeler'}")

    if a.karsilastir:
        karsilastir(satirlar, Path(a.karsilastir))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
