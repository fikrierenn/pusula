# Elevated launcher/debug wrapper for mft-usage.ps1
$out = 'D:\Temp\mft-out.txt'
$err = 'D:\Temp\mft-err.txt'
foreach($f in @($out,$err)){ if(Test-Path $f){ Remove-Item $f -Force } }
try {
    & 'D:\Dev\pusula\tools\mft-usage.ps1' -Drive D -Top 30 -Depth 2 *> $out
    'OK' | Out-File $err -Encoding UTF8
} catch {
    $txt = ($_ | Out-String) + "`n--- ScriptStackTrace ---`n" + $_.ScriptStackTrace +
           "`n--- Exception ---`n" + ($_.Exception | Format-List -Force | Out-String)
    $txt | Out-File $err -Encoding UTF8
}
