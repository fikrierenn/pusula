# Formüllü Excel doğrulaması: gerçek Excel'de baştan hesapla (CalculateFull), sayfa başına hata hücresi say,
# hesaplanmış kopyayı <ad>.excel-hesapladi.xlsx olarak kaydet (Python karşılaştırması için).
# Kullanım: powershell -File excel_dogrula.ps1 <dosya.xlsx>
param([Parameter(Mandatory = $true)][string]$Yol)
$Yol = (Resolve-Path $Yol).Path
$Kopya = $Yol -replace '\.xlsx$', '.excel-hesapladi.xlsx'
$x = New-Object -ComObject Excel.Application
$x.Visible = $false; $x.DisplayAlerts = $false
try {
    $wb = $x.Workbooks.Open($Yol)
    $t0 = Get-Date; $x.CalculateFull(); $sure = ((Get-Date) - $t0).TotalSeconds
    $toplamHata = 0
    foreach ($ws in $wb.Worksheets) {
        $formul = 0; $hata = 0
        try { $formul = $ws.UsedRange.SpecialCells(-4123).Count } catch { $formul = 0 }            # xlCellTypeFormulas
        try { $hata = $ws.UsedRange.SpecialCells(-4123, 16).Count } catch { $hata = 0 }           # + xlErrors
        $toplamHata += $hata
        "{0,-22} formul={1,10:N0}  hata={2}" -f $ws.Name, $formul, $hata
        if ($hata -gt 0) { $ws.UsedRange.SpecialCells(-4123, 16).Areas | Select-Object -First 5 | ForEach-Object { "   hata: " + $_.Address(0, 0) + " = " + $_.Cells(1, 1).Text } }
    }
    $oz = $wb.Worksheets.Item(2)   # Özet (ikinci sayfa; PS 5.1 dosyayı ANSI okur, Türkçe ad eşleşmez)
    5..19 | ForEach-Object { $a = $oz.Cells($_, 1).Text; if ($a) { "  {0,-62} {1}" -f $a, $oz.Cells($_, 2).Text } }
    "hesap süresi: {0:N1} sn · toplam hata hücresi: {1}" -f $sure, $toplamHata
    $wb.SaveAs($Kopya, 51); $wb.Close($false)
    "kopya: $Kopya"
} finally {
    $x.Quit(); [System.Runtime.InteropServices.Marshal]::ReleaseComObject($x) | Out-Null
}
