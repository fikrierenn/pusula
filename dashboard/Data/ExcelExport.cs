using MiniExcelLibs;

namespace GmDashboard.Data;

/// <summary>
/// Genel Excel (.xlsx) üretici (B-125) — tüm sayfalarda TEK kaynak. MiniExcel ile satır-sözlüğünden üretir.
/// Sözlük anahtarları = kolon başlıkları (Türkçe serbest, boşluk olur). ExcelButton bileşeni bunu çağırır.
/// </summary>
public static class ExcelExport
{
    public const string ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";

    /// <summary>Satır listesi (her satır: başlık→değer sözlüğü) → xlsx byte[].</summary>
    public static byte[] Olustur(IEnumerable<IDictionary<string, object?>> satirlar, string sayfaAd = "Rapor")
    {
        var liste = satirlar as ICollection<IDictionary<string, object?>> ?? satirlar.ToList();
        using var ms = new MemoryStream();
        MiniExcel.SaveAs(ms, liste, printHeader: true, sheetName: sayfaAd);
        return ms.ToArray();
    }
}
