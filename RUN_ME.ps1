# Sepet Büyüklüğü Etkisi Dashboard - Excel Oluşturucu
# Kullanım: PowerShell -ExecutionPolicy Bypass -File RUN_ME.ps1

Write-Host "Sepet Büyüklüğü Etkisi Dashboard - Excel Dosyası Oluşturucu" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Green
Write-Host ""

# openpyxl'i yükle
Write-Host "openpyxl kontrol ediliyor..." -ForegroundColor Yellow
$result = python -m pip list 2>&1 | Select-String "openpyxl"

if (-not $result) {
    Write-Host "openpyxl kurulumu yapılıyor..." -ForegroundColor Yellow
    python -m pip install openpyxl -q
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Hata: openpyxl kurulamadı!" -ForegroundColor Red
        exit 1
    }
}

Write-Host "openpyxl hazır." -ForegroundColor Green
Write-Host ""

# Script'i çalıştır
Write-Host "Excel dosyası oluşturuluyor..." -ForegroundColor Yellow
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "generate_excel.py"

python $scriptPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "Hata oluştu!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Başarılı!" -ForegroundColor Green
