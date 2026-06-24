# Windows Task Scheduler'a "BKM-Dashboard-Sunucu" gorevini kaydeder.
# Sen Windows'a GIRIS YAPINCA (logon) dashboard sunucusu arka planda (gizli) ayaga kalkar.
# http://localhost:5112 (LAN'da http://<bu-pc-ip>:5112 -> telefon/diger cihaz).
#
# Logon tetikleyici: sifre SAKLAMAZ, ag/SQL erisimi sorunsuz, ADMIN GEREKMEZ.
# ASCII-only (Windows PowerShell 5.1 UTF-8 BOM'suz Turkce'yi yanlis okur -> parse hatasi).
#
# Kullanim (yonetici PowerShell GEREKMEZ):
#   cd D:\Dev\pusula
#   .\scripts\register-dashboard-task.ps1
#
# Silmek icin:
#   Unregister-ScheduledTask -TaskName "BKM-Dashboard-Sunucu" -Confirm:$false

$taskName = "BKM-Dashboard-Sunucu"
$ps1 = "D:\Dev\pusula\scripts\start_dashboard.ps1"

if (-not (Test-Path $ps1)) {
    Write-Host "HATA: $ps1 bulunamadi" -ForegroundColor Red
    exit 1
}

# Mevcut gorev varsa kaldir (idempotent)
$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Mevcut gorev bulundu, kaldiriliyor..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Aksiyon: powershell gizli pencerede start_dashboard.ps1 calistirir (dotnet de gizli)
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ps1`""

# Tetikleyici: bu kullanici giris yapinca
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME

# Ayarlar: surekli calissin (sure limiti yok), idle'da durmasin
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -StartWhenAvailable -DontStopOnIdleEnd `
    -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

# Mevcut kullanici, en yuksek yetki gerekmez (port 5112 > 1024)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
    -Settings $settings -Principal $principal `
    -Description "BKM yonetim paneli (Blazor) sunucusu - logon'da gizli ayaga kalkar, http://localhost:5112" | Out-Null

Write-Host "OK: '$taskName' kaydedildi (logon tetikleyici)." -ForegroundColor Green
Write-Host "Simdi baslatiliyor (sonraki girise kadar beklemeden)..." -ForegroundColor Cyan
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 10

# Saglik kontrolu
try {
    $r = Invoke-WebRequest -Uri "http://localhost:5112" -UseBasicParsing -TimeoutSec 10 -MaximumRedirection 0 -ErrorAction Stop
    Write-Host "Sunucu AYAKTA: http://localhost:5112 (HTTP $($r.StatusCode))" -ForegroundColor Green
} catch {
    $sc = $_.Exception.Response.StatusCode.value__
    if ($sc) { Write-Host "Sunucu AYAKTA: http://localhost:5112 (HTTP $sc - login yonlendirme)" -ForegroundColor Green }
    else { Write-Host "Henuz cevap yok (ilk acilis yukleme surebilir). 20-30 sn sonra http://localhost:5112 dene." -ForegroundColor Yellow }
}

$ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
      Where-Object { $_.IPAddress -like '192.168.*' } |
      Select-Object -First 1 -ExpandProperty IPAddress
if ($ip) { Write-Host "LAN erisimi (telefon): http://${ip}:5112" -ForegroundColor Cyan }
