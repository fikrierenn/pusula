"""
Ön-kayıt eki 2 (ENS 21ce5d2) — GRUP BAŞINA yöntem seçimi ve 4478 kabul testi. Mekanik; elle karar yok.
  seçim : geliştirme = mağaza 1 (okul-2026 HARİÇ) + mağaza 4477 tüm sezon-yılları; her grup için ilk1000 WAPE ortalaması en düşük aday.
  kabul : 4478 sezon-yıllarının ÇOĞUNLUĞUNDA grupta v4'ten düşük ilk1000 WAPE VE ortalama |toplam sapma| v4'ten küçük.
Kullanım: python sezon_secim.py secim <ozet.csv ...>
          python sezon_secim.py kabul <secim.json> <4478 ozet.csv ...>
"""
import json
import sys

import pandas as pd

ADAY = ["v4", "v6⊕SES", "v7r⊕v6", "v7p⊕v6", "v8k⊕v6"]          # 13h-ort raporlanır, aday değil
GRUPLAR = ["Kitap", "Kırtasiye / Hediyelik", "Oyuncak / Elektronik", "Diğer"]


def oku(paths):
    d = pd.concat([pd.read_csv(p).assign(kaynak=p) for p in paths], ignore_index=True)
    d = d[(d.katman == "ilk1000") & d.grup.isin(GRUPLAR) & d.yöntem.isin(ADAY)]
    d["sy"] = d.sezon + "-" + d.yıl.astype(str)
    return d


def secim(paths):
    paths = [p for p in paths if not ("m1-okul-2026" in p.replace("\\", "/"))]   # görüldü → geliştirmeden çıkar
    d = oku(paths)
    tab = d.pivot_table(index=["grup", "kaynak"], columns="yöntem", values="WAPE").groupby("grup").mean()
    n = d.groupby("grup").kaynak.nunique()
    sec = {g: tab.loc[g].idxmin() for g in GRUPLAR}
    pd.set_option("display.width", 200)
    print("Geliştirme: ilk1000 WAPE ortalaması (grup × aday), sezon-yıl sayısı:", n.to_dict())
    print(tab[ADAY].round(3).to_string())
    print("SEÇİM:", sec)
    return sec


def kabul(sec, paths):
    d = oku(paths); out = {}
    for g, m in sec.items():
        x = d[d.grup == g].pivot_table(index="sy", columns="yöntem", values=["WAPE", "toplam_sapma%"])
        if m == "v4":
            out[g] = {"seçilen": m, "karar": "v4 (zaten taban)"}; continue
        win = (x["WAPE"][m] < x["WAPE"]["v4"]); bias_m, bias_4 = x["toplam_sapma%"][m].abs().mean(), x["toplam_sapma%"]["v4"].abs().mean()
        ok = win.sum() > len(win) / 2 and bias_m < bias_4
        out[g] = {"seçilen": m, "kazandığı": f"{int(win.sum())}/{len(win)}", "|sapma| aday": round(bias_m, 1), "|sapma| v4": round(bias_4, 1),
                  "karar": f"KABUL → {m}" if ok else "RED → v4 kalır"}
        print(g, out[g]); print(x.round(3).to_string())
    return out


def secim4(paths):
    """Ön-kayıt 4 (ENS de3c2e3 + 677bcf9): adaylar {v4, v9g, v9g⊕SES}; sezon-dışı koruma (ekim/mart): seçilen, o grupta v4'ten >%2 kötüyse → v4."""
    global ADAY
    paths = [p for p in paths if "m1-okul-2026" not in p.replace("\\", "/")]
    ADAY = ["v4", "v9g", "v9g⊕SES", "v6⊕SES", "v6 saf (tanı)"]; ADAY4 = ["v4", "v9g", "v9g⊕SES"]
    d = oku(paths); sez = d[~d.sezon.isin(["ekim", "mart"])]; dis = d[d.sezon.isin(["ekim", "mart"])]
    tab = sez.pivot_table(index=["grup", "kaynak"], columns="yöntem", values="WAPE").groupby("grup").mean()
    tdis = dis.pivot_table(index=["grup", "kaynak"], columns="yöntem", values="WAPE").groupby("grup").mean()
    bias = sez.pivot_table(index=["grup", "kaynak"], columns="yöntem", values="toplam_sapma%").groupby("grup").mean()
    pd.set_option("display.width", 200)
    print("Sezon (geliştirme) ilk1000 WAPE — sezon-yıl:", sez.groupby("grup").kaynak.nunique().to_dict()); print(tab[ADAY].round(3).to_string())
    print("\nSezon toplam sapma % (ortalama)"); print(bias[ADAY].round(0).to_string())
    print("\nSezon-dışı (ekim/mart) ilk1000 WAPE — origin:", dis.groupby("grup").kaynak.nunique().to_dict()); print(tdis[ADAY].round(3).to_string())
    sec = {}
    for g in GRUPLAR:
        m = tab.loc[g, ADAY4].idxmin()
        if m != "v4" and tdis.loc[g, m] > 1.02 * tdis.loc[g, "v4"]: m = "v4 (koruma: sezon-dışı kötü)"
        sec[g] = m
    print("SEÇİM (ön-kayıt 4):", sec)
    return sec


if __name__ == "__main__":
    if sys.argv[1] == "secim5":                      # ön-kayıt 5 (ENS c9ffe3a): Kitap alt grupları, kural = secim4
        GRUPLAR = ["Kitap-Hazırlık", "Kitap-Genel"]
        s = secim4(sys.argv[2:]); json.dump(s, open("sezon_secim5.json", "w", encoding="utf-8"), ensure_ascii=False); sys.exit()
    if sys.argv[1] == "secim4":
        s = secim4(sys.argv[2:]); json.dump(s, open("sezon_secim4.json", "w", encoding="utf-8"), ensure_ascii=False); sys.exit()
    if sys.argv[1] == "secim":
        s = secim(sys.argv[2:]); json.dump(s, open("sezon_secim.json", "w", encoding="utf-8"), ensure_ascii=False)
    else:
        kabul(json.load(open(sys.argv[2], encoding="utf-8")), sys.argv[3:])
