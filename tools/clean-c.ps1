# C: risksiz silinebilir cache/temp/updater temizligi
$targets = @(
  'C:\Users\fikri.eren\.gemini\antigravity-backup',
  'C:\Users\fikri.eren\AppData\Local\ms-playwright',
  'C:\Users\fikri.eren\AppData\Local\SquirrelTemp',
  'C:\Users\fikri.eren\AppData\Local\cursor-updater',
  'C:\Users\fikri.eren\AppData\Local\canva-updater',
  'C:\Users\fikri.eren\AppData\Local\obsidian-updater',
  'C:\Users\fikri.eren\AppData\Local\lm-studio-updater'
)
$freed = 0.0
foreach ($p in $targets) {
  if (Test-Path $p) {
    $b = (Get-ChildItem $p -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum
    Remove-Item $p -Recurse -Force -EA SilentlyContinue
    $freed += $b
    $gb = [math]::Round($b / 1GB, 2)
    Write-Output "silindi: $gb GB  $p"
  }
}
# Temp: icerik sil, klasor kalsin, kilitli atla
$tmp = 'C:\Users\fikri.eren\AppData\Local\Temp'
$tb = (Get-ChildItem $tmp -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum
Get-ChildItem $tmp -Force -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue
$ta = (Get-ChildItem $tmp -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum
$tFreed = [math]::Round(($tb - $ta) / 1GB, 2)
$tLeft = [math]::Round($ta / 1GB, 2)
Write-Output "Temp: ~$tFreed GB silindi (kilitli kalan $tLeft GB)"
$freed += ($tb - $ta)
$tot = [math]::Round($freed / 1GB, 2)
Write-Output "=== toplam ~$tot GB ==="
$d = Get-PSDrive C
Write-Output ("C: {0:N1} GB bos" -f ($d.Free / 1GB))
