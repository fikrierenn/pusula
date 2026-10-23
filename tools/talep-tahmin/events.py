"""
Takvim olayları — sezon ve mini sezonlar. Her tarih için `dogrulama` alanı: hesaplanabilir (kural), kaynak (web, URL raporda),
bilgi (Claude'un bilgisi, DOĞRULANMADI) ya da veri (satıştan tespit). Doğrulanmamış tarihler modelde kullanılır ama raporda işaretlenir.
"""
import datetime as dt

D0 = dt.date(2021, 6, 7)


def nth_weekday(y, m, weekday, n):            # weekday: 0=Pzt … 6=Paz
    d = dt.date(y, m, 1); d += dt.timedelta((weekday - d.weekday()) % 7); return d + dt.timedelta(weeks=n - 1)


def last_weekday(y, m, weekday):
    d = dt.date(y, m + 1, 1) - dt.timedelta(1) if m < 12 else dt.date(y, 12, 31)
    return d - dt.timedelta((d.weekday() - weekday) % 7)


def events():
    E = []
    def add(ad, tarih, tur, dog): E.append({"olay": ad, "tarih": tarih, "tur": tur, "dogrulama": dog})
    for y in range(2021, 2027):
        add("Yılbaşı", dt.date(y, 12, 31), "özel gün", "kural")
        add("Sevgililer Günü", dt.date(y, 2, 14), "özel gün", "kural")
        add("Anneler Günü", nth_weekday(y, 5, 6, 2), "özel gün", "kural")
        add("Babalar Günü", nth_weekday(y, 6, 6, 3), "özel gün", "kural")
        add("Öğretmenler Günü", dt.date(y, 11, 24), "özel gün", "kural")
        add("Kasım indirimi (Efsane Cuma)", last_weekday(y, 11, 4) if last_weekday(y, 11, 4).day >= 22 else last_weekday(y, 11, 4), "kampanya", "kural")
        add("23 Nisan", dt.date(y, 4, 23), "resmî tatil", "kural")
        add("29 Ekim", dt.date(y, 10, 29), "resmî tatil", "kural")
    bayram = {  # (tarih, doğrulama)
        "Ramazan Bayramı": [(dt.date(2021, 5, 13), "bilgi"), (dt.date(2022, 5, 2), "bilgi"), (dt.date(2023, 4, 21), "bilgi"),
                            (dt.date(2024, 4, 10), "bilgi"), (dt.date(2025, 3, 30), "kaynak"), (dt.date(2026, 3, 20), "kaynak")],
        "Kurban Bayramı": [(dt.date(2021, 7, 20), "bilgi"), (dt.date(2022, 7, 9), "bilgi"), (dt.date(2023, 6, 28), "kaynak"),
                           (dt.date(2024, 6, 16), "bilgi"), (dt.date(2025, 6, 6), "kaynak"), (dt.date(2026, 5, 27), "kaynak")],
    }
    for ad, lst in bayram.items():
        for d, dog in lst: add(ad, d, "bayram", dog)
    okul = [(dt.date(2021, 9, 6), "kaynak"), (dt.date(2022, 9, 12), "kaynak"), (dt.date(2023, 9, 11), "kaynak"),
            (dt.date(2024, 9, 9), "bilgi"), (dt.date(2025, 9, 8), "bilgi"), (dt.date(2026, 9, 14), "bilgi")]
    for d, dog in okul: add("Okul açılışı", d, "okul", dog)
    karne = [(dt.date(2022, 6, 17), "bilgi"), (dt.date(2023, 6, 16), "kaynak"), (dt.date(2024, 6, 14), "bilgi"),
             (dt.date(2025, 6, 20), "bilgi"), (dt.date(2026, 6, 26), "kaynak")]
    for d, dog in karne: add("Yaz karnesi", d, "okul", dog)
    yariyil = [(dt.date(2022, 1, 24), "bilgi"), (dt.date(2023, 1, 23), "bilgi"), (dt.date(2024, 1, 22), "kaynak"),
               (dt.date(2025, 1, 20), "kaynak"), (dt.date(2026, 1, 19), "bilgi")]
    for d, dog in yariyil: add("Yarıyıl tatili", d, "okul", dog)
    ara = [(dt.date(2023, 11, 13), "bilgi"), (dt.date(2024, 4, 8), "bilgi"), (dt.date(2024, 11, 11), "bilgi"),
           (dt.date(2025, 3, 31), "bilgi"), (dt.date(2025, 11, 10), "bilgi"), (dt.date(2026, 3, 16), "bilgi")]
    for d, dog in ara: add("Ara tatil (MEB)", d, "okul", dog)
    for e in E: e["w"] = (e["tarih"] - D0).days // 7
    return E
