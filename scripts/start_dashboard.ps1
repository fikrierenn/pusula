# BKM Dashboard sunucusunu baslatir + sistem tepsisinde (tray) ikon gosterir.
# Task Scheduler "BKM-Dashboard-Sunucu" (logon) bunu powershell -WindowStyle Hidden ile cagirir.
# Manuel test: powershell -ExecutionPolicy Bypass -File scripts\start_dashboard.ps1
#
# Tray ikonu: cift-tik = paneli ac. Sag-tik menu = Paneli Ac / Yeniden Baslat / Durdur ve Cik.
# Cokerse 5sn sonra otomatik yeniden baslar (5 hizli cokme = durur, balon uyari).
#
# Not: ASPNETCORE_ENVIRONMENT=Development -> prod HSTS http'yi bozmaz (bugun calisan hal).
# .env exe konumundan yukari yuruyup bulunur (Db.LoadEnv) -> working-dir derdi yok.
# DOSYA UTF-8 BOM ile kaydedilmeli (menu Turkce metni icin) - PS 5.1 BOM'suz UTF-8'i bozar.

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Konsol penceresini GIZLE (nasil baslatilirsa baslatilsin gorunmesin; pencere kapatinca tray olmesin).
# ShowWindow(SW_HIDE) — hata olursa SES CIKARMA, sakin devam (gizleme kritik degil, sunucu calismali).
try {
    $sig = '[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow(); [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
    $t = Add-Type -MemberDefinition $sig -Name 'WinHide' -Namespace 'Win32Hide' -PassThru -ErrorAction Stop
    $h = $t::GetConsoleWindow()
    if ($h -ne [IntPtr]::Zero) { [void]$t::ShowWindow($h, 0) }
} catch { }

$dll     = "D:\Dev\pusula\dashboard\bin\Release\net10.0\GmDashboard.dll"
$workDir = "D:\Dev\pusula\dashboard"   # content root: Kestrel cert/bkm.crt + wwwroot goreli yollari
$iconPng = "D:\Dev\pusula\dashboard\wwwroot\icon-192.png"
$panelUrl = "http://localhost:5112"

if (-not (Test-Path $dll)) {
    dotnet build "D:\Dev\pusula\dashboard\GmDashboard.csproj" -c Release | Out-Null
}

$env:ASPNETCORE_ENVIRONMENT = "Development"
$env:ASPNETCORE_URLS = "http://0.0.0.0:5112;https://0.0.0.0:5443"

# --- Durum ---
$script:running   = $true
$script:fastFails = 0
$script:proc      = $null
$script:startAt   = Get-Date

function Start-Dash {
    $script:startAt = Get-Date
    $script:proc = Start-Process -FilePath "dotnet" -ArgumentList "`"$dll`"" `
        -WorkingDirectory $workDir -WindowStyle Hidden -PassThru
}

function Stop-Dash {
    if ($script:proc -and -not $script:proc.HasExited) {
        try { $script:proc.Kill() } catch {}
    }
}

# Release'i yeniden derle + yeniden baslat (kod degisince taze surum - "eski surum" derdini cozer).
# Derleme UI thread'ini ~20sn kilitler (tray manuel aksiyon, kabul). DLL kilidi: once dotnet'i oldur.
function Rebuild-Dash {
    $ni.ShowBalloonTip(3000, "BKM Dashboard", "Derleniyor... (15-30 sn)", [System.Windows.Forms.ToolTipIcon]::Info)
    Stop-Dash
    Start-Sleep -Milliseconds 900   # DLL kilidini birak
    $ok = $true
    try {
        & dotnet build "D:\Dev\pusula\dashboard\GmDashboard.csproj" -c Release 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $ok = $false }
    } catch { $ok = $false }
    $script:fastFails = 0
    $script:running   = $true
    Start-Dash
    if ($ok) {
        $ni.ShowBalloonTip(3000, "BKM Dashboard", "Yeni sürüm derlendi ve başlatıldı.", [System.Windows.Forms.ToolTipIcon]::Info)
    } else {
        $ni.ShowBalloonTip(5000, "BKM Dashboard", "Derleme BAŞARISIZ — eski sürümle başlatıldı.", [System.Windows.Forms.ToolTipIcon]::Warning)
    }
}

# --- Tray ikonu ---
$ni = New-Object System.Windows.Forms.NotifyIcon
try {
    $bmp = New-Object System.Drawing.Bitmap $iconPng
    $ni.Icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
} catch {
    $ni.Icon = [System.Drawing.SystemIcons]::Application
}
$ni.Text = "BKM Dashboard - $panelUrl"
$ni.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miAc = $menu.Items.Add("Paneli Aç")
$miAc.Add_Click({ Start-Process $panelUrl })
$miYeniden = $menu.Items.Add("Yeniden Başlat")
$miYeniden.Add_Click({
    Stop-Dash
    $script:fastFails = 0
    $script:running = $true
    Start-Dash
    $ni.ShowBalloonTip(3000, "BKM Dashboard", "Yeniden başlatıldı.", [System.Windows.Forms.ToolTipIcon]::Info)
})
$miDerle = $menu.Items.Add("Yeniden Derle ve Başlat")
$miDerle.Add_Click({ Rebuild-Dash })
$menu.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator)) | Out-Null
$miCik = $menu.Items.Add("Durdur ve Çık")
$miCik.Add_Click({
    $script:running = $false
    Stop-Dash
    $ni.Visible = $false
    $ni.Dispose()
    [System.Windows.Forms.Application]::Exit()
})
$ni.ContextMenuStrip = $menu
$ni.Add_DoubleClick({ Start-Process $panelUrl })

# --- Izleme/yeniden-baslat dongusu (timer) ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    if (-not $script:running) { return }
    if ($script:proc -and $script:proc.HasExited) {
        $up = ((Get-Date) - $script:startAt).TotalSeconds
        if ($up -lt 15) { $script:fastFails++ } else { $script:fastFails = 0 }
        if ($script:fastFails -ge 5) {
            $script:running = $false
            $ni.ShowBalloonTip(5000, "BKM Dashboard", "Sürekli çöküyor — otomatik yeniden başlatma durduruldu. Sağ-tık > Yeniden Başlat.", [System.Windows.Forms.ToolTipIcon]::Error)
            return
        }
        Start-Dash
    }
})

Start-Dash
$timer.Start()
$ni.ShowBalloonTip(3000, "BKM Dashboard", "Sunucu çalışıyor: $panelUrl", [System.Windows.Forms.ToolTipIcon]::Info)

# Mesaj dongusu (tray canli kalsin). Cik menusu Application.Exit cagirir.
$ctx = New-Object System.Windows.Forms.ApplicationContext
[System.Windows.Forms.Application]::Run($ctx)
