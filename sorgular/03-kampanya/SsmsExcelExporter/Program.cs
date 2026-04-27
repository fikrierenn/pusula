using System;
using System.Data;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using ClosedXML.Excel;

namespace SsmsExcelExporter;

static class Program
{
    [STAThread]
    static void Main()
    {
        // Tekli çalışma kontrolü
        using var mutex = new System.Threading.Mutex(true, "SsmsExcelExporter_SingleInstance", out bool isNew);
        if (!isNew)
        {
            MessageBox.Show("SsmsExcelExporter zaten calisiyor!\nSystem tray'deki ikona bak.", "Bilgi", MessageBoxButtons.OK, MessageBoxIcon.Information);
            return;
        }

        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new TrayApp());
    }
}

// =========================================================
// System Tray Uygulaması + Global Hotkey
// =========================================================
sealed class TrayApp : ApplicationContext
{
    // Windows API - Global Hotkey
    [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
    [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);

    const int HOTKEY_INSTANT = 9001;  // Ctrl+Shift+E → anında tek sheet
    const int HOTKEY_BUFFER = 9002;   // Ctrl+Shift+W → tamponla (çoklu sheet)
    const uint MOD_CTRL = 0x0002;
    const uint MOD_SHIFT = 0x0004;
    const uint VK_E = 0x45;
    const uint VK_W = 0x57;

    readonly NotifyIcon _tray;
    readonly HotkeyWindow _hkWin;

    // Multi-sheet tampon
    DataTable? _bufferedSheet;
    string? _bufferedName;

    public TrayApp()
    {
        // System tray ikonu
        _tray = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "SSMS Excel Exporter\nCtrl+Shift+E ile Excel olustur",
            Visible = true,
            ContextMenuStrip = BuildMenu()
        };

        _tray.DoubleClick += (_, _) => ShowHelp();

        // Global hotkey kaydet
        _hkWin = new HotkeyWindow(OnHotkeyMessage);
        bool ok1 = RegisterHotKey(_hkWin.Handle, HOTKEY_INSTANT, MOD_CTRL | MOD_SHIFT, VK_E);
        bool ok2 = RegisterHotKey(_hkWin.Handle, HOTKEY_BUFFER, MOD_CTRL | MOD_SHIFT, VK_W);

        if (!ok1 && !ok2)
        {
            _tray.ShowBalloonTip(3000, "Uyari", "Kisayollar kayit edilemedi!\nBaska bir uygulama kullaniyor olabilir.", ToolTipIcon.Warning);
        }
        else
        {
            _tray.ShowBalloonTip(2500, "SSMS Excel Exporter",
                "Ctrl+Shift+E → Aninda Excel\nCtrl+Shift+W → Coklu sayfa tamponu", ToolTipIcon.Info);
        }
    }

    ContextMenuStrip BuildMenu()
    {
        var menu = new ContextMenuStrip();
        menu.Items.Add("Aninda Excel (Ctrl+Shift+E)", null, (_, _) => OnInstant());
        menu.Items.Add("Tampona Ekle (Ctrl+Shift+W)", null, (_, _) => OnBuffer());
        menu.Items.Add("Tamponu Temizle", null, (_, _) => {
            _bufferedSheet = null; _bufferedName = null;
            _tray.ShowBalloonTip(1000, "Tampon", "Temizlendi.", ToolTipIcon.Info);
        });
        menu.Items.Add(new ToolStripSeparator());
        menu.Items.Add("Nasil Kullanilir?", null, (_, _) => ShowHelp());
        menu.Items.Add("Cikis", null, (_, _) => ExitApp());
        return menu;
    }

    void ShowHelp()
    {
        MessageBox.Show(
            "SSMS Excel Exporter\n" +
            "====================\n\n" +
            "TEK RESULT SET:\n" +
            "  1. Grid'de Ctrl+A > Ctrl+C\n" +
            "  2. Ctrl+Shift+E → Excel aninda acilir\n\n" +
            "IKI RESULT SET:\n" +
            "  1. Ilk grid'i kopyala > Ctrl+Shift+W (tampona)\n" +
            "  2. Ikinci grid'i kopyala > Ctrl+Shift+E (Excel ac)\n" +
            "  → 2 sheet'li Excel acilir\n\n" +
            "Otomatik: format, filtre, freeze, renk,\n" +
            "alt toplam, genel toplam.",
            "Yardim", MessageBoxButtons.OK, MessageBoxIcon.Information);
    }

    // Hotkey mesaj yönlendirici
    void OnHotkeyMessage(int id)
    {
        if (id == HOTKEY_INSTANT) OnInstant();
        else if (id == HOTKEY_BUFFER) OnBuffer();
    }

    // =========================================================
    // Ctrl+Shift+W → Tampona ekle (çoklu sheet için)
    // =========================================================
    void OnBuffer()
    {
        try
        {
            DataTable? data = ReadClipboardTable();
            if (data == null) return;

            _bufferedSheet = data;
            _bufferedName = GuessSheetName(data, "Sayfa1");
            _tray.ShowBalloonTip(2500, "Tampona Alindi",
                $"{data.Rows.Count} satir → {_bufferedName}\n\nSimdi 2. grid'i kopyala + Ctrl+Shift+E",
                ToolTipIcon.Info);
        }
        catch (Exception ex) { _tray.ShowBalloonTip(3000, "Hata", ex.Message, ToolTipIcon.Error); }
    }

    // =========================================================
    // Ctrl+Shift+E → Anında Excel oluştur + aç
    //   Tampon varsa → 2 sheet, yoksa → tek sheet
    // =========================================================
    void OnInstant()
    {
        try
        {
            DataTable? data = ReadClipboardTable();
            if (data == null) return;

            string tempDir = Path.Combine(Path.GetTempPath(), "SsmsExcelExporter");
            Directory.CreateDirectory(tempDir);
            string fileName = $"rapor_{DateTime.Now:yyyyMMdd_HHmmss}.xlsx";
            string path = Path.Combine(tempDir, fileName);

            if (_bufferedSheet != null)
            {
                // Tamponda 1. sheet var → 2 sheet'li Excel
                string sheet2Name = GuessSheetName(data, "Sayfa2");
                ExcelBuilder.CreateMultiSheet(
                    _bufferedSheet, _bufferedName ?? "Sayfa1",
                    data, sheet2Name, path);
                _tray.ShowBalloonTip(1500, "2 Sayfa",
                    $"{_bufferedName}: {_bufferedSheet.Rows.Count} satir\n{sheet2Name}: {data.Rows.Count} satir",
                    ToolTipIcon.Info);
                _bufferedSheet = null;
                _bufferedName = null;
            }
            else
            {
                // Tek sheet
                ExcelBuilder.Create(data, path);
                _tray.ShowBalloonTip(1500, "Tamam", $"{data.Rows.Count} satir → Excel", ToolTipIcon.Info);
            }

            Process.Start(new ProcessStartInfo { FileName = path, UseShellExecute = true });
        }
        catch (Exception ex) { _tray.ShowBalloonTip(3000, "Hata", ex.Message, ToolTipIcon.Error); }
    }

    DataTable? ReadClipboardTable()
    {
        if (!Clipboard.ContainsText())
        {
            _tray.ShowBalloonTip(2000, "Hata", "Clipboard bos!", ToolTipIcon.Warning);
            return null;
        }
        var data = ClipboardParser.Parse(Clipboard.GetText());
        if (data.Rows.Count == 0)
        {
            _tray.ShowBalloonTip(2000, "Hata", "Tablo verisi bulunamadi.", ToolTipIcon.Warning);
            return null;
        }
        return data;
    }

    // Sheet adını veri kolonlarından tahmin et
    static string GuessSheetName(DataTable dt, string fallback)
    {
        // Kolon isimlerinden ipucu
        var cols = string.Join(" ", Enumerable.Range(0, dt.Columns.Count).Select(i => dt.Columns[i].ColumnName));
        if (cols.Contains("FisId") && cols.Contains("UrunKod")) return "Urun Detay";
        if (cols.Contains("FisId") && cols.Contains("FisBrut")) return "Fis Baslik";
        if (cols.Contains("Magaza") && cols.Contains("Brut")) return "Performans";
        if (cols.Contains("Tarih")) return "Gunluk";
        return fallback;
    }

    void ExitApp()
    {
        UnregisterHotKey(_hkWin.Handle, HOTKEY_INSTANT);
        UnregisterHotKey(_hkWin.Handle, HOTKEY_BUFFER);
        _hkWin.DestroyHandle();
        _tray.Visible = false;
        _tray.Dispose();
        Application.Exit();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            UnregisterHotKey(_hkWin.Handle, HOTKEY_INSTANT);
            UnregisterHotKey(_hkWin.Handle, HOTKEY_BUFFER);
            _tray.Dispose();
        }
        base.Dispose(disposing);
    }
}

// =========================================================
// Gizli pencere — hotkey mesajlarını yakalar
// =========================================================
sealed class HotkeyWindow : NativeWindow
{
    const int WM_HOTKEY = 0x0312;
    readonly Action<int> _onHotkey;

    public HotkeyWindow(Action<int> onHotkey)
    {
        _onHotkey = onHotkey;
        CreateHandle(new CreateParams());
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_HOTKEY)
            _onHotkey((int)m.WParam);
        base.WndProc(ref m);
    }
}

// =========================================================
// Clipboard Parser: Tab-separated → DataTable
// =========================================================
static class ClipboardParser
{
    public static DataTable Parse(string raw)
    {
        var dt = new DataTable();
        var lines = raw.Split(new[] { "\r\n", "\n" }, StringSplitOptions.None)
                       .Where(l => !string.IsNullOrWhiteSpace(l))
                       .ToArray();
        if (lines.Length < 2) return dt;

        // İlk satır = başlıklar
        string[] headers = lines[0].Split('\t');
        foreach (var h in headers)
            dt.Columns.Add(h.Trim());

        for (int i = 1; i < lines.Length; i++)
        {
            string[] cells = lines[i].Split('\t');
            var row = dt.NewRow();
            for (int c = 0; c < dt.Columns.Count && c < cells.Length; c++)
                row[c] = cells[c].Trim();
            dt.Rows.Add(row);
        }

        return dt;
    }
}

// =========================================================
// Excel oluşturucu — otomatik format, alt toplam, renk
// =========================================================
static class ExcelBuilder
{
    enum ColType { Text, Int, Decimal, Percent }

    public static void CreateMultiSheet(
        DataTable data1, string name1,
        DataTable data2, string name2,
        string path)
    {
        using var wb = new XLWorkbook();
        BuildSheet(wb, data1, name1);
        BuildSheet(wb, data2, name2);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        wb.SaveAs(path);
    }

    public static void Create(DataTable data, string path)
    {
        using var wb = new XLWorkbook();
        BuildSheet(wb, data, "Rapor");
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        wb.SaveAs(path);
    }

    static void BuildSheet(XLWorkbook wb, DataTable data, string sheetName)
    {
        var ws = wb.AddWorksheet(sheetName);

        var colTypes = DetectColumnTypes(data);
        int colCount = data.Columns.Count;

        // --- Başlıklar ---
        for (int c = 0; c < colCount; c++)
        {
            var cell = ws.Cell(1, c + 1);
            cell.Value = data.Columns[c].ColumnName;
            cell.Style.Font.Bold = true;
            cell.Style.Fill.BackgroundColor = XLColor.FromArgb(0xD6EAF8);
            cell.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
            cell.Style.Border.BottomBorder = XLBorderStyleValues.Thin;
        }

        // --- Gruplama kolonu otomatik tespit ---
        int groupColIdx = AutoDetectGroupColumn(data);

        int row = 2;

        if (groupColIdx >= 0)
        {
            // Gruplu yaz + alt toplamlar
            var groups = data.AsEnumerable()
                .GroupBy(r => r[groupColIdx]?.ToString() ?? "")
                .ToList();

            foreach (var grp in groups)
            {
                int groupStart = row;
                foreach (DataRow dr in grp)
                {
                    WriteDataRow(ws, row, dr, colTypes, colCount);
                    row++;
                }
                WriteSubtotalRow(ws, row, groupStart, row - 1, colTypes, colCount, $"Alt Toplam: {grp.Key}");
                row++;
            }
        }
        else
        {
            // Düz yaz
            foreach (DataRow dr in data.Rows)
            {
                WriteDataRow(ws, row, dr, colTypes, colCount);
                row++;
            }
        }

        // Genel toplam
        WriteGrandTotalRow(ws, row, data, colTypes, colCount);
        row++;

        // Koşullu renkler
        ApplyConditionalColors(ws, colTypes, colCount, row - 1);

        // Freeze + Filtre
        ws.SheetView.FreezeRows(1);
        ws.RangeUsed()?.SetAutoFilter();

        // Sayı formatları
        ApplyNumberFormats(ws, colTypes, colCount, row - 1);

        // Kolon genişlikleri
        ws.Columns().AdjustToContents(1, row, 8, 40);
    }

    // ---- Otomatik gruplama kolonu ----
    static int AutoDetectGroupColumn(DataTable data)
    {
        // "Magaza", "Tarih", "Grup", "Magaza" gibi kolonları ara
        string[] candidates = { "Magaza", "Tarih", "Grup", "KampanyaTipi", "KTip", "Ay" };
        for (int c = 0; c < data.Columns.Count; c++)
        {
            string name = data.Columns[c].ColumnName;
            foreach (var cand in candidates)
            {
                if (name.Contains(cand, StringComparison.OrdinalIgnoreCase))
                {
                    // En az 2 farklı değer olmalı
                    int distinct = data.AsEnumerable().Select(r => r[c]?.ToString()).Distinct().Count();
                    if (distinct >= 2 && distinct <= data.Rows.Count / 2)
                        return c;
                }
            }
        }
        return -1; // gruplama yok
    }

    // ---- Kolon tipi tespiti ----
    static ColType[] DetectColumnTypes(DataTable data)
    {
        var types = new ColType[data.Columns.Count];
        for (int c = 0; c < data.Columns.Count; c++)
        {
            string name = data.Columns[c].ColumnName;

            if (name.Contains('%') || name.Contains("Oran", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Pay", StringComparison.OrdinalIgnoreCase))
            { types[c] = ColType.Percent; continue; }

            if (name.Contains("Brut", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Net", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Indirim", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Tutar", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Ciro", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Sepet", StringComparison.OrdinalIgnoreCase))
            { types[c] = ColType.Decimal; continue; }

            if (name.Contains("Fis", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Urun", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Adet", StringComparison.OrdinalIgnoreCase) ||
                name.Contains("Sayi", StringComparison.OrdinalIgnoreCase))
            { types[c] = ColType.Int; continue; }

            // Değerlere bakarak tespit
            int numericCount = 0, decimalCount = 0;
            int sampleSize = Math.Min(data.Rows.Count, 20);
            for (int r = 0; r < sampleSize; r++)
            {
                string val = data.Rows[r][c]?.ToString()?.Trim() ?? "";
                if (TryParseNumber(val, out decimal d))
                {
                    numericCount++;
                    if (d != Math.Floor(d)) decimalCount++;
                }
            }

            if (numericCount > sampleSize * 0.7)
                types[c] = decimalCount > 0 ? ColType.Decimal : ColType.Int;
            else
                types[c] = ColType.Text;
        }
        return types;
    }

    static void WriteDataRow(IXLWorksheet ws, int row, DataRow dr, ColType[] colTypes, int colCount)
    {
        for (int c = 0; c < colCount; c++)
        {
            var cell = ws.Cell(row, c + 1);
            string raw = dr[c]?.ToString()?.Trim() ?? "";

            if (colTypes[c] != ColType.Text && TryParseNumber(raw, out decimal num))
                cell.Value = num;
            else
                cell.Value = raw;
        }
    }

    static void WriteSubtotalRow(IXLWorksheet ws, int row, int startRow, int endRow,
        ColType[] colTypes, int colCount, string label)
    {
        ws.Cell(row, 1).Value = label;
        ws.Cell(row, 1).Style.Font.Bold = true;

        for (int c = 1; c < colCount; c++)
        {
            if (colTypes[c] == ColType.Text) continue;
            var cell = ws.Cell(row, c + 1);
            string colLetter = GetColumnLetter(c + 1);

            if (colTypes[c] == ColType.Percent)
                cell.FormulaA1 = $"AVERAGE({colLetter}{startRow}:{colLetter}{endRow})";
            else
                cell.FormulaA1 = $"SUM({colLetter}{startRow}:{colLetter}{endRow})";

            cell.Style.Font.Bold = true;
        }

        var range = ws.Range(row, 1, row, colCount);
        range.Style.Fill.BackgroundColor = XLColor.FromArgb(0xFFF9C4);
        range.Style.Border.TopBorder = XLBorderStyleValues.Thin;
    }

    static void WriteGrandTotalRow(IXLWorksheet ws, int row, DataTable data,
        ColType[] colTypes, int colCount)
    {
        ws.Cell(row, 1).Value = "GENEL TOPLAM";
        ws.Cell(row, 1).Style.Font.Bold = true;

        for (int c = 1; c < colCount; c++)
        {
            if (colTypes[c] == ColType.Text) continue;

            decimal sum = 0; int count = 0;
            foreach (DataRow dr in data.Rows)
            {
                if (TryParseNumber(dr[c]?.ToString() ?? "", out decimal val))
                { sum += val; count++; }
            }

            var cell = ws.Cell(row, c + 1);
            cell.Value = (colTypes[c] == ColType.Percent && count > 0) ? sum / count : sum;
            cell.Style.Font.Bold = true;
        }

        var range = ws.Range(row, 1, row, colCount);
        range.Style.Fill.BackgroundColor = XLColor.FromArgb(0xFFD54F);
        range.Style.Border.TopBorder = XLBorderStyleValues.Double;
        range.Style.Font.Bold = true;
    }

    static void ApplyConditionalColors(IXLWorksheet ws, ColType[] colTypes, int colCount, int lastRow)
    {
        for (int c = 0; c < colCount; c++)
        {
            string name = ws.Cell(1, c + 1).GetString();

            if (name.Contains("Indirim", StringComparison.OrdinalIgnoreCase) && colTypes[c] != ColType.Text)
            {
                for (int r = 2; r <= lastRow; r++)
                {
                    var cell = ws.Cell(r, c + 1);
                    if (cell.TryGetValue(out decimal val) && val > 0)
                        cell.Style.Font.FontColor = XLColor.Red;
                }
            }

            if (colTypes[c] == ColType.Percent)
            {
                for (int r = 2; r <= lastRow; r++)
                {
                    var cell = ws.Cell(r, c + 1);
                    if (cell.TryGetValue(out decimal val))
                    {
                        if (val >= 50) cell.Style.Font.FontColor = XLColor.FromArgb(0x27AE60);
                        else if (val >= 30) cell.Style.Font.FontColor = XLColor.FromArgb(0xF39C12);
                    }
                }
            }
        }
    }

    static void ApplyNumberFormats(IXLWorksheet ws, ColType[] colTypes, int colCount, int lastRow)
    {
        for (int c = 0; c < colCount; c++)
        {
            if (colTypes[c] == ColType.Text) continue;
            string fmt = colTypes[c] switch
            {
                ColType.Int => "#,##0",
                ColType.Decimal => "#,##0.00",
                ColType.Percent => "0.0",
                _ => ""
            };
            if (!string.IsNullOrEmpty(fmt))
                ws.Range(2, c + 1, lastRow, c + 1).Style.NumberFormat.Format = fmt;
        }
    }

    static bool TryParseNumber(string raw, out decimal result)
    {
        result = 0;
        if (string.IsNullOrWhiteSpace(raw)) return false;
        string cleaned = raw.Trim();

        if (cleaned.Contains(',') && cleaned.IndexOf(',') > cleaned.LastIndexOf('.'))
            cleaned = cleaned.Replace(".", "").Replace(",", ".");
        else if (cleaned.Contains('.') && cleaned.IndexOf('.') > cleaned.LastIndexOf(','))
            cleaned = cleaned.Replace(",", "");
        else if (cleaned.Contains(',') && !cleaned.Contains('.'))
            cleaned = cleaned.Replace(",", ".");

        return decimal.TryParse(cleaned, NumberStyles.Any, CultureInfo.InvariantCulture, out result);
    }

    static string GetColumnLetter(int colNum)
    {
        string result = "";
        while (colNum > 0) { colNum--; result = (char)('A' + colNum % 26) + result; colNum /= 26; }
        return result;
    }
}
