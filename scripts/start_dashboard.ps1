# BKM Dashboard sunucusunu baslatir (gizli pencere + cokerse yeniden baslat).
# Task Scheduler "BKM-Dashboard-Sunucu" (logon) bunu powershell -WindowStyle Hidden ile cagirir.
# Manuel test: powershell -ExecutionPolicy Bypass -File scripts\start_dashboard.ps1
#
# Not: ASPNETCORE_ENVIRONMENT=Development -> prod HSTS http'yi bozmaz (bugun calisan hal).
# .env exe konumundan yukari yuruyup bulunur (Db.LoadEnv) -> working-dir derdi yok.
# ASCII-only (Windows PowerShell 5.1 UTF-8 BOM'suz Turkce'yi yanlis okur -> parse hatasi).

$ErrorActionPreference = "Stop"
$dll = "D:\Dev\pusula\dashboard\bin\Release\net10.0\GmDashboard.dll"
$workDir = "D:\Dev\pusula\dashboard"   # content root: Kestrel cert/bkm.crt + wwwroot goreli yollari

if (-not (Test-Path $dll)) {
    Write-Host "Release build yok, uretiliyor..."
    dotnet build "D:\Dev\pusula\dashboard\GmDashboard.csproj" -c Release | Out-Null
}

$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:ASPNETCORE_URLS = "http://0.0.0.0:5112;https://0.0.0.0:5443"

# Cokerse 5sn sonra yeniden baslat. Ust uste 5 hizli cokme (port dolu/config) -> dur (spin engeli).
$fastFails = 0
while ($true) {
    $start = Get-Date
    $p = Start-Process -FilePath "dotnet" -ArgumentList "`"$dll`"" `
         -WorkingDirectory $workDir -WindowStyle Hidden -PassThru
    $p.WaitForExit()
    if (((Get-Date) - $start).TotalSeconds -lt 15) { $fastFails++ } else { $fastFails = 0 }
    if ($fastFails -ge 5) { break }
    Start-Sleep -Seconds 5
}
