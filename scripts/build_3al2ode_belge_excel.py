"""
3AL2ÖDE belge listesi -> Excel (belge no · tarih · brüt · 3al2öde ind · diğer ind · net)
Kullanım:
    pip install pymssql openpyxl
    python build_3al2ode_belge_excel.py [mekanID] [baslangic YYYYMMDD] [bitisExcl YYYYMMDD]
    (varsayılan: FSM=1, 20260601, 20260612)

Hesap:  Brüt − 3al2öde İnd − Diğer İnd = Net
        3al2öde İnd = belgenin 3AL2ÖDE(K) kampanya indirimi (SUM -TotalDiscount)
        Diğer İnd   = Sales.DiscountTotal − 3al2öde İnd  (diğer kampanya + manuel)
        Net         = Sales.GrossTotal − Sales.DiscountTotal
İade belgeleri (GTY...) negatif 3al2öde indirimi ile görünür.
"""
import os
import sys
from pathlib import Path
import pymssql
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.worksheet.table import Table, TableStyleInfo

R = Path(__file__).resolve().parent.parent
MEKAN_AD = {1: "FSM", 4477: "Ozluce", 4478: "IstYolu"}


def cfg():
    e = R / ".env"
    if e.exists():
        for l in e.read_text(encoding="utf-8").splitlines():
            if "=" in l and not l.strip().startswith("#"):
                k, v = l.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip())
    return dict(server=os.environ.get("MSSQL_HOST"), user=os.environ.get("MSSQL_USER", "sa"),
                password=os.environ.get("MSSQL_PASSWORD", ""), database=os.environ.get("MSSQL_DATABASE", "master"))


SQL = """
SELECT s.DocumentNo AS Belge,
       CONVERT(varchar, s.Date, 104) AS Tarih,
       CAST(s.GrossTotal AS decimal(18,2)) AS Brut,
       CAST(ISNULL(u.Ind,0) AS decimal(18,2)) AS Uc3al2,
       CAST(s.DiscountTotal - ISNULL(u.Ind,0) AS decimal(18,2)) AS Diger,
       CAST(s.GrossTotal - s.DiscountTotal AS decimal(18,2)) AS Net
FROM EncoreMerkez.dbo.Sales s
JOIN EncoreMerkez.dbo.Pos p ON p.Id = s.PosId
JOIN EncoreMerkez.dbo.Stores st ON st.Id = p.StoreId
JOIN DerinSISBkm.dbo.posMagaza MG ON MG.mekanKod COLLATE Turkish_CI_AS = st.Code COLLATE Turkish_CI_AS
JOIN (
    SELECT spc.SalesId, SUM(-spc.TotalDiscount) AS Ind
    FROM EncoreMerkez.dbo.SalesProductCampaigns spc
    JOIN EncoreMerkez.dbo.SalesProducts sp
        ON sp.SalesId = spc.SalesId AND sp.Sequence = spc.ProductSequence AND sp.IsValid = 1
    WHERE spc.CampaignName = '3AL2ÖDE(K)'
    GROUP BY spc.SalesId
) u ON u.SalesId = s.Id
WHERE MG.mekanID = %d AND s.Date >= %s AND s.Date < %s
  AND s.DocumentsTypeId IN (1,2,6,7,8)   -- iade (3) hariç: iade belgesi indirim sign'ı Diğer'i şişiriyor
ORDER BY s.Date, s.DocumentNo
"""

HEADER_FONT = Font(bold=True, color="FFFFFF", size=11)
HEADER_FILL = PatternFill("solid", fgColor="305496")
HEADER_ALIGN = Alignment(horizontal="center", vertical="center", wrap_text=True)


def main():
    mekan = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    bas = sys.argv[2] if len(sys.argv) > 2 else "20260601"
    bitis = sys.argv[3] if len(sys.argv) > 3 else "20260612"
    ad = MEKAN_AD.get(mekan, str(mekan))

    c = cfg()
    if not c["server"]:
        print("HATA: MSSQL_HOST yok (.env)")
        sys.exit(1)
    conn = pymssql.connect(server=c["server"], user=c["user"], password=c["password"],
                           database=c.get("database", "master"), charset="UTF-8",
                           login_timeout=20, timeout=180)
    cur = conn.cursor()
    cur.execute(SQL, (mekan, bas, bitis))
    rows = cur.fetchall()
    conn.close()
    n = len(rows)
    print(f"{ad} {bas}-{bitis}: {n} belge")

    wb = Workbook()
    ws = wb.active
    ws.title = "Belgeler"
    headers = ["Belge No", "Tarih", "Brüt ₺", "3al2öde İnd ₺", "Diğer İnd ₺", "Net ₺"]
    ws.append(headers)
    for r in rows:
        ws.append([r[0], r[1], float(r[2]), float(r[3]), float(r[4]), float(r[5])])

    # Başlık stili + dondur
    for col in range(1, len(headers) + 1):
        c0 = ws.cell(row=1, column=col)
        c0.font = HEADER_FONT
        c0.fill = HEADER_FILL
        c0.alignment = HEADER_ALIGN
    ws.freeze_panes = "A2"
    ws.row_dimensions[1].height = 28

    # Para format
    for row in ws.iter_rows(min_row=2, min_col=3, max_col=6):
        for cell in row:
            cell.number_format = '#,##0.00'

    last = n + 1
    # Toplam satırı
    tot = last + 1
    ws.cell(row=tot, column=1, value="TOPLAM").font = Font(bold=True)
    for col, letter in [(3, "C"), (4, "D"), (5, "E"), (6, "F")]:
        cc = ws.cell(row=tot, column=col, value=f"=SUM({letter}2:{letter}{last})")
        cc.font = Font(bold=True)
        cc.number_format = '#,##0.00'

    # Oran satırı (brüt'e oran): 3al2öde / Diğer / toplam indirim
    orn = tot + 1
    ws.cell(row=orn, column=1, value="ORAN (brüte)").font = Font(bold=True, italic=True)
    # 3al2öde % ve Diğer % = ilgili indirim / brüt; Net sütununda toplam indirim oranı = (3al2+diğer)/brüt
    for col, formula in [(4, f"=D{tot}/C{tot}"), (5, f"=E{tot}/C{tot}"), (6, f"=(D{tot}+E{tot})/C{tot}")]:
        oc = ws.cell(row=orn, column=col, value=formula)
        oc.font = Font(bold=True, italic=True)
        oc.number_format = '0%'

    tbl = Table(displayName="Belgeler3al2ode", ref=f"A1:F{last}")
    tbl.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
    ws.add_table(tbl)

    widths = {"A": 26, "B": 12, "C": 14, "D": 15, "E": 14, "F": 14}
    for col, w in widths.items():
        ws.column_dimensions[col].width = w

    # Bilgi sheet
    s = wb.create_sheet("Bilgi")
    info = [
        ("Rapor", "3AL2ÖDE geçen belgeler"),
        ("Mağaza", ad),
        ("Dönem", f"{bas} – {bitis} (bitiş hariç)"),
        ("Belge sayısı", n),
        ("", ""),
        ("Brüt", "Sales.GrossTotal (indirimsiz)"),
        ("3al2öde İnd", "Belgenin 3AL2ÖDE(K) kampanya indirimi"),
        ("Diğer İnd", "Sales.DiscountTotal − 3al2öde (diğer kampanya + manuel)"),
        ("Net", "GrossTotal − DiscountTotal (Brüt − 3al2öde − Diğer)"),
        ("İade", "GTY... belge no = iade; 3al2öde İnd negatif görünür"),
    ]
    for r in info:
        s.append(r)
    s.cell(row=1, column=1).font = Font(bold=True)
    s.column_dimensions["A"].width = 16
    s.column_dimensions["B"].width = 60

    out = R / "briefings" / f"3al2ode_belge_{ad}_{bas}_{bitis}.xlsx"
    out.parent.mkdir(parents=True, exist_ok=True)
    wb.save(out)
    print(f"OK -> {out}")


if __name__ == "__main__":
    main()
