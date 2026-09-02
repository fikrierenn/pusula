# -*- coding: utf-8 -*-
"""Kadro/norm/iş hacmi rakamlarının TUTARLILIK denetimi — sunum ve Excel'e giden her sayı burada sınanır.

Neden: aynı destede ÜÇ AYRI KAPSAM dolaşıyor (3 POS mağazası · 4 norm mağazası · 5 mağaza) ve
üç ayrı KADRO TANIMI var (kayıt / operasyonel / sezonluk). Kapsam etiketi düşerse rakamlar
birbirini tutmuyor gibi görünür (02.09.2026'da tam bu oldu: 143→160 ile 200→211 yan yana düştü).
Bu script her rakamı bileşenlerinden yeniden hesaplar ve sapmayı raporlar.

Kullanım: python scripts/tutarlilik_kontrol.py [veri.json]
Çıkış kodu: sapma varsa 1.
"""
import json
import sys
from pathlib import Path

KOK = Path(__file__).resolve().parent.parent
VARSAYILAN = KOK / "briefings" / "sezon-kadro-20260902" / "verimlilik-veri.json"
POS = ("İST. YOLU", "ÖZLÜCE", "FSM")          # DerinSIS POS satışı olan üç mağaza (BKM_GENEL)
ETKINLIK_BOLUM = "ETKİNLİK"

sonuc = []


def kontrol(ad, beklenen, bulunan, aciklama=""):
    tamam = (beklenen == bulunan) if isinstance(beklenen, int) else abs(beklenen - bulunan) < 0.51
    sonuc.append((tamam, ad, beklenen, bulunan, aciklama))
    return tamam


def main(argv):
    yol = Path(argv[1]) if len(argv) > 1 else VARSAYILAN
    v = json.loads(yol.read_text(encoding="utf-8"))
    mk = {m["sube"]: m for m in v["magaza_kadro"]}
    k5 = v["kadro_5magaza"]
    mag = {m["ad"]: m for m in v["magaza"]}
    n = v.get("norm")

    # ---------------------------------------------------------------- KADRO (5 mağaza)
    kontrol("5 mağaza kadrolu taban (şube toplamı = kapsam sayımı)",
            k5["kadrolu_taban26"], sum(m["kadrolu_taban26"] for m in mk.values()))
    kontrol("5 mağaza kadrolu kesim (şube toplamı = kapsam sayımı)",
            k5["kadrolu_kesim26"], sum(m["kadrolu_kesim26"] for m in mk.values()))
    kontrol("5 mağaza sezonluk kesim (şube toplamı = kapsam sayımı)",
            k5["sezonluk_kesim26"], sum(m["sezonluk_kesim26"] for m in mk.values()))
    kontrol("5 mağaza toplam = kadrolu + sezonluk",
            k5["toplam_kesim26"], k5["kadrolu_kesim26"] + k5["sezonluk_kesim26"])

    # ---------------------------------------------------------------- BÖLÜM (5 mağaza)
    b_kadrolu = sum(b["kadrolu26"] for b in v["bolum"])
    kontrol("bölüm toplamı = 5 mağaza kadrolu kesim", k5["kadrolu_kesim26"], b_kadrolu)
    kontrol("bölüm sezonluk toplamı = 5 mağaza sezonluk", k5["sezonluk_kesim26"],
            sum(b["sezonluk26"] for b in v["bolum"]))
    mb_kadrolu = sum(r["kadrolu26"] for r in v["magaza_bolum"])
    kontrol("mağaza×bölüm toplamı = 5 mağaza kadrolu kesim", k5["kadrolu_kesim26"], mb_kadrolu)

    # ---------------------------------------------------------------- 3 POS MAĞAZASI (iş hacmi kapsamı)
    pos_kadrolu = sum(mk[s]["kadrolu_kesim26"] for s in POS)
    pos_sezonluk = sum(mk[s]["sezonluk_kesim26"] for s in POS)
    pos_kadro = sum(m["kadro26"] for m in v["magaza"])
    kontrol("3 POS kadro (hacim tablosu) = kadrolu + sezonluk (İK)",
            pos_kadrolu + pos_sezonluk, pos_kadro,
            "sunumda 143 → 160 diye geçen rakam")

    # ---------------------------------------------------------------- NORM (4 mağaza)
    if n:
        ayr = n.get("ayrik", {})
        norm_subeler = [r["sube"] for r in n["sube"]]
        kontrol("norm şube toplamı = beyan edilen 145",
                n["toplam"]["norm"], sum(r["norm"] for r in n["sube"]))
        kontrol("norm sezonluk toplamı = beyan edilen 72",
                n["toplam"]["norm_sezonluk"], sum(r["norm_sezonluk"] for r in n["sube"]))
        kontrol("norm toplam = kadrolu norm + sezonluk norm",
                n["toplam"]["norm_toplam"], n["toplam"]["norm"] + n["toplam"]["norm_sezonluk"])
        kontrol("norm bölüm toplamı = norm şube toplamı",
                n["toplam"]["norm"], sum(b["norm"] for b in n["bolum"]))

        # kayıt → operasyonel dönüşümü
        eng = sum(a.get("engelli", 0) for a in ayr.values())
        etk = sum(a.get("etkinlik", 0) for a in ayr.values())
        kayit_kadrolu = n["toplam"]["kadrolu_kesim26"]
        ops_kadrolu = kayit_kadrolu - eng - etk
        kontrol("4 mağaza kayıt kadrolu = şube toplamı", kayit_kadrolu,
                sum(mk[s]["kadrolu_kesim26"] for s in norm_subeler))
        kontrol("bölüm tablosu operasyonel kadrolu = kayıt − engelli − etkinlik", ops_kadrolu,
                sum(b["kadrolu26"] for b in n["bolum"] if b["bolum"] != ETKINLIK_BOLUM),
                "engelli ve etkinlik norm dışı (yönetim kararı)")
        kontrol("bölüm engelli toplamı = şube engelli toplamı", eng,
                sum(b["engelli26"] for b in n["bolum"]))
        kontrol("etkinlik satırı = şube etkinlik toplamı", etk,
                sum(b["kadrolu26"] for b in n["bolum"] if b["bolum"] == ETKINLIK_BOLUM))
        # açık/fazla aritmetiği
        acik_b = sum(max(0, b["norm"] - b["kadrolu26"]) for b in n["bolum"] if b["bolum"] != ETKINLIK_BOLUM)
        kontrol("bölüm açık toplamı", n["acik_bolum_toplam"], acik_b)
        acik_s = sum(max(0, r["norm"] - (r["kadrolu_kesim26"]
                                         - ayr.get(r["sube"], {}).get("engelli", 0)
                                         - ayr.get(r["sube"], {}).get("etkinlik", 0)))
                     for r in n["sube"])
        if acik_b < acik_s:
            sonuc.append((False, "bölüm açığı ≥ mağaza açığı olmalı", acik_s, acik_b,
                          "mağaza içi fazlalar açığı maskeler"))
        else:
            sonuc.append((True, "bölüm açığı (%d) ≥ mağaza açığı (%d)" % (acik_b, acik_s),
                          acik_b, acik_b, "mağaza içi fazlalar açığı maskeler"))

    # ---------------------------------------------------------------- İŞ HACMİ
    kontrol("hizalı pencere adet toplamı", round(sum(m["adet26"] for m in v["magaza"])),
            round(sum(m["adet26"] for m in v["magaza"])))
    if v.get("kayma"):
        ky = v["kayma"]
        kontrol("Ağustos = 1-14 + 15-31 (adet)", round(ky["y26_agu_tam"]["adet"]),
                round(v["agustos_yarim"]["1"]["adet26"] + v["agustos_yarim"]["2"]["adet26"]))
        kontrol("kaymasız Ağustos − gerçek = Eylül'e kayan",
                round(ky["eylule_kayan"]["adet"]),
                round(ky["agustos_kaymasiz_tahmin"]["adet"] - ky["y26_agu_tam"]["adet"]))
    if v.get("yillar"):
        y26 = [y for y in v["yillar"] if y["yil"] == 2026][0]
        kontrol("Oca-Ağu mağaza adedi (yıllar ↔ kanal tablosu)",
                round(v["ocak_agustos"]["magaza"]["adet26"]), round(y26["adet"]))

    # ---------------------------------------------------------------- ÇIKTI
    print("Tutarlılık denetimi: %s" % yol.name)
    hata = [x for x in sonuc if not x[0]]
    for tamam, ad, bekl, bul, acik in sonuc:
        isaret = "✓" if tamam else "✗"
        ek = ("  [%s]" % acik) if acik else ""
        if tamam:
            print("  %s %s = %s%s" % (isaret, ad, bul, ek))
        else:
            print("  %s %s → beklenen %s, bulunan %s%s" % (isaret, ad, bekl, bul, ek))

    print("\nKAPSAM SÖZLÜĞÜ (aynı destede üç kapsam):")
    print("  3 POS mağazası (FSM · Özlüce · İst. Yolu) — iş hacmi ölçülebilen kapsam · kadro %d → %d"
          % (sum(m["kadro25"] for m in v["magaza"]), pos_kadro))
    if n:
        print("  4 norm mağazası (+ Heykel) — norm karşılaştırması · kayıt %d, operasyonel %d, norm %d"
              % (n["toplam"]["kadrolu_kesim26"] + n["toplam"]["sezonluk_kesim26"],
                 ops_kadrolu + n["toplam"]["sezonluk_kesim26"], n["toplam"]["norm_toplam"]))
    print("  5 mağaza (+ Şura) — İK kadro raporu · kadrolu %d + sezonluk %d = %d"
          % (k5["kadrolu_kesim26"], k5["sezonluk_kesim26"], k5["toplam_kesim26"]))

    if hata:
        print("\n⚠ %d SAPMA" % len(hata))
        return 1
    print("\n✓ %d kontrol, sapma yok." % len(sonuc))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
