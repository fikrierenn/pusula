"""
Min/Max GİRDİ denetimi (sahip: "emin olalım rakamların doğruluğundan"). Excel'deki mavi girdileri, ERP'den BAĞIMSIZ yeni sorgularla karşılaştırır.
Örneklem: mağaza başına 40 ürün — 10 stok 0 + sipariş · 10 stok var + sipariş · 10 en çok satan · 10 rastgele (tohum 7).
  stok          ↔ stokSonAltDepo_vw (aynı kaynak, şimdi) VE irsHrk tüm hareketlerin toplamı (bağımsız ikinci kaynak)
  son 26 hafta  ↔ irsHrk POS satış (100) − POS iade (101), 13.04.2026 – 11.10.2026
  fiyat/maliyet ↔ bkm.UrunBilgi · ODAK ↔ BKMDATA.OdakUrunDurum (barkod zinciri) + ent.odak_depo_Stok
Kullanım: python minmax_girdi_denetim.py <minmax_dizini>
"""
import io
import os
import subprocess
import sys

import numpy as np
import openpyxl
import pandas as pd

D = sys.argv[1]
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
MK = {"FSM": 1, "Özlüce": 4477, "İstYolu": 4478}


def sql(q, **p):
    args = ["sqlcli", "query", "--profile", "erp", "--read-only", "--format", "csv", "--max-rows", "5000", "--timeout", "600"]
    for k, v in p.items(): args += ["--param", f"{k}={v}"]
    r = subprocess.run(args + [q], capture_output=True, text=True, encoding="utf-8", cwd=ROOT)
    if r.returncode != 0: raise RuntimeError(r.stdout[-500:] + r.stderr[-500:])
    lines = r.stdout.splitlines(); i = next(j for j, l in enumerate(lines) if "," in l and not l.startswith("\x1b"))
    return pd.read_csv(io.StringIO("\n".join(lines[i:])))


ozet = []
for ad, mk in MK.items():
    ws = openpyxl.load_workbook(f"{D}/2026-10-14-minmax-{ad}.xlsx", read_only=True)["Ürünler"]
    x = pd.DataFrame(list(ws.iter_rows(min_row=2, min_col=1, max_col=16, values_only=True)),
                     columns=["stk", "ad", "grup", "kat", "stok", "yolda", "tah", "sez", "sd", "s26", "fiyat", "sonalis", "odak_stok", "odak_durum", "temin", "onemli"])
    py = pd.read_csv(f"{D}/2026-10-14-minmax-{ad}.python-degerleri.csv")[["stk", "siparis"]]
    x = x.merge(py, on="stk")
    rng = np.random.default_rng(7)
    parts = [x[(x.stok <= 0) & (x.siparis > 0)], x[(x.stok > 0) & (x.siparis > 0)]]
    s = pd.concat([p.sample(min(10, len(p)), random_state=7) for p in parts] + [x.nlargest(10, "s26"), x.sample(10, random_state=7)]).drop_duplicates("stk")
    ids = ",".join(str(int(v)) for v in s.stk)
    v = sql(f"SELECT ehstkID stk, SUM(stok) stok_v FROM stokSonAltDepo_vw WITH (NOLOCK) WHERE ehMekan = {mk} AND ehstkID IN ({ids}) GROUP BY ehstkID")
    h = sql(f"SELECT h.ehstkID stk, SUM(h.ehAdetN) stok_h, "
            f"-SUM(CASE WHEN h.ehTip IN (100,101) AND h.ehTrhS >= CONVERT(date,'2026-04-13',23) AND h.ehTrhS < CONVERT(date,'2026-10-12',23) THEN h.ehAdetN ELSE 0 END) s26_h "
            f"FROM dbo.irsHrk h WITH (NOLOCK) WHERE h.ehMekan = {mk} AND h.ehstkID IN ({ids}) GROUP BY h.ehstkID")
    u = sql(f"SELECT stkID stk, CAST(SatisFiyat AS decimal(12,2)) fiyat_u, CAST(SonAlis AS decimal(12,2)) sonalis_u FROM bkm.UrunBilgi WITH (NOLOCK) WHERE stkID IN ({ids})")
    o = sql(f"SELECT b.urnBrkdStkID stk, MIN(d.saleStatus) odak_durum_u, MAX(ISNULL(s.StokMiktar,0)) odak_stok_u FROM BKMDATA.dbo.OdakUrunDurum d WITH (NOLOCK) "
            f"JOIN BKMDATA.ent.odak_urun_tam t WITH (NOLOCK) ON CAST(t.urun_id AS varchar(30)) COLLATE Turkish_CI_AS = d.ProductCode COLLATE Turkish_CI_AS "
            f"JOIN DerinSISBkm.dbo.urnBrkd b WITH (NOLOCK) ON b.urnBarkod COLLATE Turkish_CI_AS = t.barkod COLLATE Turkish_CI_AS AND b.urnBrkdOnce = 0 "
            f"LEFT JOIN DerinSISBkm.ent.odak_depo_Stok s WITH (NOLOCK) ON s.stkID = b.urnBrkdStkID WHERE b.urnBrkdStkID IN ({ids}) GROUP BY b.urnBrkdStkID")
    m = s.merge(v, on="stk", how="left").merge(h, on="stk", how="left").merge(u, on="stk", how="left").merge(o, on="stk", how="left")
    m[["stok_v", "stok_h", "s26_h", "odak_stok_u", "odak_durum_u"]] = m[["stok_v", "stok_h", "s26_h", "odak_stok_u", "odak_durum_u"]].fillna(0)
    m["stok_v"] = m.stok_v.clip(lower=0)
    kont = {
        "stok = anlık görünüm (şimdi)": (m.stok - m.stok_v).abs() < 0.5,
        "stok = hareket toplamı (bağımsız)": (m.stok - m.stok_h.clip(lower=0)).abs() < 0.5,
        "son 26 hafta satış = irsHrk POS−iade": (m.s26 - m.s26_h).abs() < 0.5,
        "fiyat = ürün kartı": (m.fiyat.fillna(0) - m.fiyat_u.fillna(0)).abs() < 0.01,
        "son alış = ürün kartı": (m.sonalis.fillna(0) - m.sonalis_u.fillna(0)).abs() < 0.01,
        "ODAK durumu": (m.odak_durum.fillna(0) - m.odak_durum_u).abs() < 0.5,
        "ODAK stok": (m.odak_stok.fillna(0) - m.odak_stok_u).abs() < 0.5,
    }
    for k, ok in kont.items():
        ozet.append({"mağaza": ad, "kontrol": k, "örnek": len(m), "tutan": int(ok.sum()), "tutan_%": round(100 * ok.mean(), 1)})
        bad = m[~ok]
        if len(bad):
            cols = {"stok = anlık görünüm (şimdi)": ["stok", "stok_v"], "stok = hareket toplamı (bağımsız)": ["stok", "stok_h"], "son 26 hafta satış = irsHrk POS−iade": ["s26", "s26_h"],
                    "fiyat = ürün kartı": ["fiyat", "fiyat_u"], "son alış = ürün kartı": ["sonalis", "sonalis_u"], "ODAK durumu": ["odak_durum", "odak_durum_u"], "ODAK stok": ["odak_stok", "odak_stok_u"]}[k]
            print(f"  [{ad}] {k} — tutmayan {len(bad)}:", bad[["stk"] + cols].head(5).to_dict("records"))
    m.to_csv(f"{D}/denetim-{ad}.csv", index=False, encoding="utf-8-sig")
pd.set_option("display.width", 200)
print(pd.DataFrame(ozet).pivot_table(index="kontrol", columns="mağaza", values="tutan_%").to_string())
