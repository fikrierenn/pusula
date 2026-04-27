// Build: dotnet publish -c Release -r win-x64 --self-contained false -p:PublishSingleFile=true
// Output: bin\Release\net8.0-windows\win-x64\publish\RaporApp.exe
// Requires: .NET 8 Runtime on target machine
// For fully self-contained (no .NET required, ~60MB):
//   dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:PublishTrimmed=true

using System.Data;
using System.Diagnostics;
using System.Text;
using ClosedXML.Excel;
using Microsoft.Data.SqlClient;

namespace RaporApp;

static class Program
{
    [STAThread]
    static void Main()
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new MainForm());
    }
}

// =====================================================================
// Column metadata — tüm raporlar için hint map
// =====================================================================
enum ColType { Txt, Int, Cur, Dec, Pct }

static class ColumnDefs
{
    private static readonly Dictionary<string, ColType> _map = BuildMap();

    private static Dictionary<string, ColType> BuildMap()
    {
        var m = new Dictionary<string, ColType>(StringComparer.OrdinalIgnoreCase);

        m["Tarih"] = ColType.Txt;
        m["Magaza"] = ColType.Txt;

        foreach (var grp in new[] { "3Al2Ode", "DigerKmp", "Kampanyasiz", "Toplam" })
        {
            m[$"{grp} Fis"] = ColType.Int;
            m[$"{grp} Urun"] = ColType.Int;
            m[$"{grp} Brut"] = ColType.Cur;
            m[$"{grp} Indirim"] = ColType.Cur;
            m[$"{grp} Net"] = ColType.Cur;
            m[$"{grp} Ort Sepet Adet"] = ColType.Dec;
            m[$"{grp} Ort Sepet Tutar"] = ColType.Cur;
            m[$"{grp} Indirim Orani %"] = ColType.Pct;
            m[$"{grp} Satir"] = ColType.Int;
            m[$"{grp} Adet"] = ColType.Dec;
            m[$"{grp} Ort Birim Fiyat"] = ColType.Cur;
        }
        m["3Al2Ode Fis Payi %"] = ColType.Pct;
        m["3Al2Ode Urun Payi %"] = ColType.Pct;
        m["3Al2Ode Ciro Payi %"] = ColType.Pct;
        m["3Al2Ode Satir Payi %"] = ColType.Pct;
        m["3Al2Ode Adet Payi %"] = ColType.Pct;

        foreach (var kat in new[] { "Kitap", "Hazirlik", "Cocuk", "Akademi" })
        {
            m[$"{kat} Adet"] = ColType.Dec;
            m[$"{kat} Brut"] = ColType.Cur;
            m[$"{kat} Indirim"] = ColType.Cur;
            m[$"{kat} Net"] = ColType.Cur;
            m[$"{kat} Ind %"] = ColType.Pct;
            m[$"{kat} Ciro Payi %"] = ColType.Pct;
        }
        m["Toplam Ind %"] = ColType.Pct;

        return m;
    }

    public static ColType Resolve(string colName)
    {
        string clean = colName.TrimEnd();
        if (_map.TryGetValue(clean, out var ct)) return ct;
        string alt = clean.EndsWith('%') ? clean : clean + " %";
        if (_map.TryGetValue(alt, out var ct2)) return ct2;
        return ColType.Cur;
    }

    public static string NumberFormat(ColType ct) => ct switch
    {
        ColType.Int => "#,##0",
        ColType.Cur => "#,##0.00",
        ColType.Dec => "0.00",
        ColType.Pct => "0.0",
        _ => ""
    };
}

// =====================================================================
// Excel writer — DataTable'dan yazar
// =====================================================================
static class ExcelWriter
{
    private static readonly XLColor HeaderBg = XLColor.FromHtml("#D6EAF8");
    private static readonly XLColor ToplamBg = XLColor.FromHtml("#FFF9C4");

    public static int WriteSheet(IXLWorksheet ws, DataTable dt)
    {
        // Visible kolonları bul (SortKey/IsTotal hariç)
        var visibleCols = new List<DataColumn>();
        foreach (DataColumn dc in dt.Columns)
        {
            if (dc.ColumnName is "SortKey" or "IsTotal") continue;
            visibleCols.Add(dc);
        }

        int colCount = visibleCols.Count;

        // Kolon tipleri
        var colTypes = new ColType[colCount];
        for (int c = 0; c < colCount; c++)
            colTypes[c] = ColumnDefs.Resolve(visibleCols[c].ColumnName);

        // Header
        for (int c = 0; c < colCount; c++)
        {
            var cell = ws.Cell(1, c + 1);
            cell.Value = visibleCols[c].ColumnName;
            cell.Style.Font.Bold = true;
            cell.Style.Fill.BackgroundColor = HeaderBg;
            cell.Style.Alignment.Horizontal = XLAlignmentHorizontalValues.Center;
            cell.Style.Alignment.WrapText = true;
        }
        ws.SheetView.FreezeRows(1);

        // Data rows
        int row = 2;
        foreach (DataRow dr in dt.Rows)
        {
            // TOPLAM tespiti — Magaza kolonu
            string magaza = "";
            if (dt.Columns.Contains("Magaza") && !dr.IsNull("Magaza"))
                magaza = dr["Magaza"]?.ToString() ?? "";
            bool isToplam = magaza.Equals("TOPLAM", StringComparison.OrdinalIgnoreCase) || magaza == "";

            for (int c = 0; c < colCount; c++)
            {
                var cell = ws.Cell(row, c + 1);
                var ct = colTypes[c];
                object val = dr[visibleCols[c]];

                if (val == DBNull.Value || val == null)
                {
                    cell.Value = Blank.Value;
                }
                else if (ct == ColType.Txt)
                {
                    cell.Value = val.ToString() ?? "";
                }
                else
                {
                    cell.Value = Convert.ToDouble(val);
                    string fmt = ColumnDefs.NumberFormat(ct);
                    if (!string.IsNullOrEmpty(fmt))
                        cell.Style.NumberFormat.Format = fmt;
                }

                if (isToplam)
                {
                    cell.Style.Fill.BackgroundColor = ToplamBg;
                    cell.Style.Font.Bold = true;
                }
            }
            row++;
        }

        // Column widths
        for (int c = 0; c < colCount; c++)
            ws.Column(c + 1).Width = c < 2 ? (c == 0 ? 12 : 16) : 14;

        return dt.Rows.Count;
    }
}

// =====================================================================
// Main Form — SQL seç, ekranda gör, Excel'e aktar
// =====================================================================
class MainForm : Form
{
    private const string ConnStr =
        "Server=192.168.40.201;Database=EncoreMerkez;User Id=sa;Password=H33451959*;TrustServerCertificate=true;";

    private static readonly string[] SheetNames = ["Mevcut Ay (Gun Detay)", "Onceki Aylar", "Sheet 3", "Sheet 4"];

    private readonly ComboBox _cmbSqlFile;
    private readonly TabControl _tabs;
    private readonly Button _btnRun;
    private readonly Button _btnExport;
    private readonly Label _lblStatus;

    // Bellekte tutulan result set'ler
    private readonly List<DataTable> _results = new();

    // ComboBox item: gösterim adı + tam path
    private readonly List<(string Display, string FullPath)> _sqlFiles = new();

    public MainForm()
    {
        Text = "BKM Rapor";
        ClientSize = new Size(960, 620);
        MinimumSize = new Size(700, 400);
        StartPosition = FormStartPosition.CenterScreen;

        // ===== Üst panel — SQL seçici + butonlar =====
        var pnlTop = new Panel { Dock = DockStyle.Top, Height = 44 };

        var lblSql = new Label
        {
            Text = "SQL:",
            Location = new Point(8, 13),
            AutoSize = true
        };

        // Butonlar sağda sabit — önce bunları koy
        _btnExport = new Button
        {
            Text = "Excel'e Aktar",
            Size = new Size(120, 28),
            Enabled = false,
            Anchor = AnchorStyles.Top | AnchorStyles.Right
        };
        _btnExport.Click += BtnExport_Click;

        _btnRun = new Button
        {
            Text = "\u25b6 Calistir",
            Size = new Size(100, 28),
            Anchor = AnchorStyles.Top | AnchorStyles.Right
        };
        _btnRun.Click += BtnRun_Click;

        // ComboBox — solda, butonlara kadar uzanır
        _cmbSqlFile = new ComboBox
        {
            DropDownStyle = ComboBoxStyle.DropDownList,
            Location = new Point(42, 10),
            Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right
        };

        pnlTop.Controls.AddRange([lblSql, _cmbSqlFile, _btnRun, _btnExport]);

        // İlk pozisyonları ayarla
        int pw = ClientSize.Width;
        _btnExport.Location = new Point(pw - _btnExport.Width - 8, 8);
        _btnRun.Location = new Point(_btnExport.Left - _btnRun.Width - 6, 8);
        _cmbSqlFile.Width = _btnRun.Left - _cmbSqlFile.Left - 8;

        // Resize'da güncelle (Anchor zaten Right olan butonları taşır, sadece combo genişliğini ayarla)
        pnlTop.Resize += (_, _) =>
        {
            _cmbSqlFile.Width = _btnRun.Left - _cmbSqlFile.Left - 8;
        };

        // ===== Alt durum çubuğu =====
        _lblStatus = new Label
        {
            Text = "SQL dosyasi secip Calistir'a basin.",
            Dock = DockStyle.Bottom,
            Height = 26,
            Padding = new Padding(8, 5, 0, 0),
            ForeColor = Color.Gray,
            BackColor = SystemColors.Control
        };

        // ===== Tab control — ortada =====
        _tabs = new TabControl { Dock = DockStyle.Fill };

        // Ekleme sırası: Dock.Bottom → Dock.Top → Dock.Fill (kalan alan)
        Controls.Add(_tabs);
        Controls.Add(_lblStatus);
        Controls.Add(pnlTop);

        // SQL dosyalarını doldur
        PopulateSqlFiles();
    }

    /// <summary>
    /// EXE'den yukarı doğru ilk .sql dosyası bulunan dizini tespit eder,
    /// oradan recursive tüm .sql'leri listeler.
    /// </summary>
    private void PopulateSqlFiles()
    {
        _sqlFiles.Clear();
        _cmbSqlFile.Items.Clear();

        try
        {
            // EXE'den yukarı doğru ilk .sql içeren dizini bul (max 10 seviye)
            string? dir = AppContext.BaseDirectory;
            string? sorguRoot = null;
            int maxUp = 10;

            while (dir != null && maxUp-- > 0)
            {
                if (Directory.GetFiles(dir, "*.sql", SearchOption.TopDirectoryOnly).Length > 0)
                {
                    sorguRoot = dir;
                    break;
                }
                dir = Path.GetDirectoryName(dir);
            }

            // Bulamadıysa EXE dizinini kullan
            sorguRoot ??= AppContext.BaseDirectory;

            // Bir üst dizinden recursive tara (sorgular/ altındaki tüm alt klasörler)
            string? scanRoot = Path.GetDirectoryName(sorguRoot) ?? sorguRoot;
            var files = Directory.GetFiles(scanRoot, "*.sql", SearchOption.AllDirectories)
                .Where(f => !f.Contains("\\bin\\") && !f.Contains("\\obj\\"))
                .OrderBy(f => f)
                .ToList();

            foreach (var f in files)
            {
                string display = Path.GetRelativePath(scanRoot, f);
                _sqlFiles.Add((display, f));
                _cmbSqlFile.Items.Add(display);
            }
        }
        catch
        {
            // Dizin tarama hatası — sessizce devam et
        }

        // Son öğe: "Diger..." (Browse)
        _sqlFiles.Add(("[ Diger dosya sec... ]", ""));
        _cmbSqlFile.Items.Add("[ Diger dosya sec... ]");

        // Varsayılan seçim: 3al2ode varsa onu seç
        int defaultIdx = _sqlFiles.FindIndex(x => x.FullPath.Contains("3al2ode_performans"));
        _cmbSqlFile.SelectedIndex = defaultIdx >= 0 ? defaultIdx : 0;

        // "Diger..." seçilince Browse aç
        _cmbSqlFile.SelectedIndexChanged += CmbSqlFile_Changed;
    }

    private void CmbSqlFile_Changed(object? sender, EventArgs e)
    {
        // Son öğe = Browse
        if (_cmbSqlFile.SelectedIndex == _sqlFiles.Count - 1)
        {
            using var dlg = new OpenFileDialog
            {
                Title = "SQL Dosyasi Sec",
                Filter = "SQL Dosyalari (*.sql)|*.sql|Tum Dosyalar (*.*)|*.*",
                InitialDirectory = AppContext.BaseDirectory
            };
            if (dlg.ShowDialog() == DialogResult.OK)
            {
                string display = Path.GetFileName(dlg.FileName);
                // Listeye ekle (Browse'dan önce)
                int insertIdx = _sqlFiles.Count - 1;
                _sqlFiles.Insert(insertIdx, (display + " (eklendi)", dlg.FileName));
                _cmbSqlFile.Items.Insert(insertIdx, display + " (eklendi)");
                _cmbSqlFile.SelectedIndex = insertIdx;
            }
            else
            {
                // İptal → önceki seçime dön
                _cmbSqlFile.SelectedIndex = 0;
            }
        }
    }

    private string GetSelectedSqlPath()
    {
        int idx = _cmbSqlFile.SelectedIndex;
        if (idx < 0 || idx >= _sqlFiles.Count) return "";
        return _sqlFiles[idx].FullPath;
    }

    private void SetStatus(string msg, Color color)
    {
        if (InvokeRequired)
            Invoke(() => SetStatus(msg, color));
        else
        {
            _lblStatus.Text = msg;
            _lblStatus.ForeColor = color;
        }
    }

    private void SetRunEnabled(bool enabled)
    {
        if (InvokeRequired)
            Invoke(() => { _btnRun.Enabled = enabled; });
        else
            _btnRun.Enabled = enabled;
    }

    // -----------------------------------------------------------------
    // ÇALIŞTIR — SQL oku, DataTable'lara yükle, DataGridView'da göster
    // -----------------------------------------------------------------
    private async void BtnRun_Click(object? sender, EventArgs e)
    {
        string sqlFile = GetSelectedSqlPath();
        if (string.IsNullOrEmpty(sqlFile) || !File.Exists(sqlFile))
        {
            MessageBox.Show("Gecerli bir SQL dosyasi secin.", "Uyari",
                MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }

        SetRunEnabled(false);
        _btnExport.Enabled = false;
        _results.Clear();
        _tabs.TabPages.Clear();

        try
        {
            await Task.Run(() =>
            {
                SetStatus("SQL okunuyor...", Color.Blue);
                string sql = File.ReadAllText(sqlFile, Encoding.UTF8);

                SetStatus("SQL Server'a baglaniliyor...", Color.Blue);
                using var conn = new SqlConnection(ConnStr);
                conn.Open();

                SetStatus("Sorgu calisiyor...", Color.Blue);
                using var adapter = new SqlDataAdapter(sql, conn);
                adapter.SelectCommand!.CommandTimeout = 300;

                var ds = new DataSet();
                adapter.Fill(ds);

                foreach (DataTable dt in ds.Tables)
                    _results.Add(dt);
            });

            if (_results.Count == 0)
            {
                SetStatus("Veri gelmedi.", Color.Red);
                SetRunEnabled(true);
                return;
            }
        }
        catch (Exception ex)
        {
            SetStatus("HATA!", Color.Red);
            MessageBox.Show(ex.Message, "Hata", MessageBoxButtons.OK, MessageBoxIcon.Error);
            SetRunEnabled(true);
            return;
        }

        // DataGridView'ları oluştur
        for (int i = 0; i < _results.Count; i++)
        {
            string tabName = i < SheetNames.Length ? SheetNames[i] : $"Sheet {i + 1}";
            var tab = new TabPage(tabName);

            var dgv = new DataGridView
            {
                Dock = DockStyle.Fill,
                ReadOnly = true,
                AllowUserToAddRows = false,
                AllowUserToDeleteRows = false,
                AutoSizeColumnsMode = DataGridViewAutoSizeColumnsMode.AllCells,
                DataSource = _results[i],
                BackgroundColor = SystemColors.Window,
                BorderStyle = BorderStyle.None
            };

            // SortKey/IsTotal kolonlarını gizle
            dgv.DataBindingComplete += (s, _) =>
            {
                var grid = (DataGridView)s!;
                foreach (DataGridViewColumn col in grid.Columns)
                {
                    if (col.Name is "SortKey" or "IsTotal")
                        col.Visible = false;
                }

                // TOPLAM satırlarını sarı yap
                foreach (DataGridViewRow row in grid.Rows)
                {
                    if (row.IsNewRow) continue;
                    string mag = grid.Columns.Contains("Magaza") ? row.Cells["Magaza"].Value?.ToString() ?? "" : "";
                    if (mag.Equals("TOPLAM", StringComparison.OrdinalIgnoreCase) || mag == "")
                    {
                        row.DefaultCellStyle.BackColor = Color.FromArgb(255, 249, 196);
                        row.DefaultCellStyle.Font = new Font(dgv.Font, FontStyle.Bold);
                    }
                }

                // Sayısal kolonları formatla
                foreach (DataGridViewColumn col in grid.Columns)
                {
                    if (!col.Visible) continue;
                    var ct = ColumnDefs.Resolve(col.HeaderText);
                    if (ct == ColType.Cur)
                        col.DefaultCellStyle.Format = "#,##0.00";
                    else if (ct == ColType.Int)
                        col.DefaultCellStyle.Format = "#,##0";
                    else if (ct == ColType.Dec)
                        col.DefaultCellStyle.Format = "0.00";
                    else if (ct == ColType.Pct)
                        col.DefaultCellStyle.Format = "0.0";

                    if (ct != ColType.Txt)
                        col.DefaultCellStyle.Alignment = DataGridViewContentAlignment.MiddleRight;
                }
            };

            tab.Controls.Add(dgv);
            _tabs.TabPages.Add(tab);
        }

        int totalRows = _results.Sum(dt => dt.Rows.Count);
        SetStatus($"Tamam! {_results.Count} result set, {totalRows} satir.", Color.Green);
        _btnExport.Enabled = true;
        SetRunEnabled(true);
    }

    // -----------------------------------------------------------------
    // EXCEL'E AKTAR — bellekteki DataTable'ları Excel'e yaz
    // -----------------------------------------------------------------
    private async void BtnExport_Click(object? sender, EventArgs e)
    {
        if (_results.Count == 0) return;

        string defaultName = Path.GetFileNameWithoutExtension(GetSelectedSqlPath()) + ".xlsx";

        using var dlg = new SaveFileDialog
        {
            Title = "Excel Olarak Kaydet",
            Filter = "Excel Dosyasi (*.xlsx)|*.xlsx",
            FileName = defaultName,
            InitialDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Desktop)
        };

        if (dlg.ShowDialog() != DialogResult.OK) return;

        string outPath = dlg.FileName;
        _btnExport.Enabled = false;

        try
        {
            int totalRows = 0;

            await Task.Run(() =>
            {
                SetStatus("Excel yaziliyor...", Color.Blue);
                using var wb = new XLWorkbook();

                for (int i = 0; i < _results.Count; i++)
                {
                    string sheetName = i < SheetNames.Length ? SheetNames[i] : $"Sheet {i + 1}";
                    var ws = wb.Worksheets.Add(sheetName);
                    totalRows += ExcelWriter.WriteSheet(ws, _results[i]);
                }

                wb.SaveAs(outPath);
            });

            SetStatus($"Excel kaydedildi! {totalRows} satir.", Color.Green);

            if (File.Exists(outPath))
            {
                Process.Start(new ProcessStartInfo
                {
                    FileName = outPath,
                    UseShellExecute = true
                });
            }
        }
        catch (Exception ex)
        {
            SetStatus("Excel HATA!", Color.Red);
            MessageBox.Show(ex.Message, "Hata", MessageBoxButtons.OK, MessageBoxIcon.Error);
        }
        finally
        {
            _btnExport.Enabled = true;
        }
    }
}
