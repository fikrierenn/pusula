"""zei32 parite kapısı — üretilen rapor ile PDKS kaynak çıktısını karşılaştırır.

Çıkış kodu: 0 tam · 1 fark var · 2 koşamadı (boş sonuç yeşil sayılmaz).
"""
import datetime, sys
from pathlib import Path
import openpyxl, xlrd

if sys.platform == "win32":
    for _s in (sys.stdout, sys.stderr):
        try: _s.reconfigure(encoding="utf-8")
        except Exception: pass

KOLON = ["Giriş", "Çıkış", "Gün Modeli", "Mazeret", "Brüt"]

def _dk(v):
    if v is None: return None
    s = str(v).strip()
    if not s or ":" not in s: return None
    p = s.split(":"); return int(p[0]) * 60 + int(p[1])

def _br(v):
    if v is None: return None
    s = str(v).strip()
    if not s: return None
    try: return round(float(s), 2)
    except Exception: return s

def _tx(v): return str(v).strip() if v is not None else ""

def kaynak_oku(yol):
    wb = xlrd.open_workbook(str(yol)); d = {}
    for sn in wb.sheet_names():
        sh = wb.sheet_by_name(sn)
        for r in range(1, sh.nrows):
            pn, t = sh.cell_value(r, 0), sh.cell_value(r, 9)
            if not pn or not isinstance(t, float) or not t: continue
            g = datetime.date(1899, 12, 30) + datetime.timedelta(days=int(t))
            d[(int(pn), g)] = (_dk(sh.cell_value(r, 10)), _dk(sh.cell_value(r, 11)),
                               _tx(sh.cell_value(r, 12)), _tx(sh.cell_value(r, 13)),
                               _br(sh.cell_value(r, 14)))
    return d

def bizim_oku(yol):
    ws = openpyxl.load_workbook(str(yol), data_only=True).active; d = {}
    for r in ws.iter_rows(min_row=2, values_only=True):
        g = r[9].date() if isinstance(r[9], datetime.datetime) else r[9]
        d[(int(r[0]), g)] = (_dk(r[10]), _dk(r[11]), _tx(r[12]), _tx(r[13]), _br(r[14]))
    return d

def main():
    if len(sys.argv) < 3:
        sys.exit("kullanım: zei32_parite.py <kaynak.xls> <bizim.xlsx>")
    kay, biz = kaynak_oku(Path(sys.argv[1])), bizim_oku(Path(sys.argv[2]))
    if not kay or not biz:
        print("KOŞAMADI: taraflardan biri boş — 'fark yok' DEĞİL, ölçemedik."); return 2
    ortak = set(kay) & set(biz)
    if not ortak:
        print("KOŞAMADI: ortak kişi-gün yok."); return 2
    tut = [0] * 5; fark = [[] for _ in range(5)]
    for k in ortak:
        for i in range(5):
            if kay[k][i] == biz[k][i]: tut[i] += 1
            else: fark[i].append((k, kay[k][i], biz[k][i]))
    print(f"ortak kişi-gün: {len(ortak)}   (kaynak {len(kay)} · bizim {len(biz)})")
    print(f"{'kolon':12}{'tutan':>8}{'fark':>7}{'oran':>10}")
    for i in range(5):
        print(f"{KOLON[i]:12}{tut[i]:>8}{len(fark[i]):>7}{tut[i]/len(ortak)*100:>9.2f}%")
    tam = sum(1 for k in ortak if all(kay[k][i] == biz[k][i] for i in range(5)))
    print(f"\n★ BEŞ KOLON BİRDEN: {tam}/{len(ortak)}  ({tam/len(ortak)*100:.2f}%)")
    f = lambda m: f"{m//60:02d}:{m%60:02d}" if isinstance(m, int) else repr(m)
    for i in range(5):
        if fark[i]:
            print(f"\n--- {KOLON[i]} ({len(fark[i])}) ---")
            for k, a, b in sorted(fark[i])[:12]:
                print(f"  {k[0]:>6} {k[1]} kaynak={f(a)} bizim={f(b)}")
    return 0 if tam == len(ortak) else 1

if __name__ == "__main__":
    raise SystemExit(main())
