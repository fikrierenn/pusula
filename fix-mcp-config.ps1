# MCP Config Fix Script
# Cowork/Claude Desktop'ın sqlserver MCP bağlantısını düzeltir
# Çalıştırma: PowerShell'i AÇIK olarak çalıştır, bu dosyaya sürükle-bırak
# Veya: sağ tık → "Run with PowerShell"

$ErrorActionPreference = "Stop"

$configPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
$backupPath = Join-Path $env:APPDATA "Claude\claude_desktop_config.OLD.json"

Write-Host "==> Config dosyasi: $configPath" -ForegroundColor Cyan

if (-not (Test-Path $configPath)) {
    Write-Host "HATA: Config dosyasi bulunamadi: $configPath" -ForegroundColor Red
    Read-Host "Devam etmek icin Enter'a bas"
    exit 1
}

# Yedekle
Copy-Item $configPath $backupPath -Force
Write-Host "==> Yedek olusturuldu: $backupPath" -ForegroundColor Green

# Yeni config
$newConfig = @{
    mcpServers = @{
        atlasops = @{
            command = "dotnet"
            args = @("D:\Dev\AtlasOPS\src\AtlasOps.Mcp\bin\Debug\net10.0\AtlasOps.Mcp.dll")
        }
        sqlserver = @{
            command = "node"
            args = @("D:\Dev\sqlserver-mcp-server\dist\index.js")
            cwd = "D:\Dev\sqlserver-mcp-server"
            env = @{
                MSSQL_HOST = "192.168.40.201"
                MSSQL_PORT = "1433"
                MSSQL_USER = "sa"
                MSSQL_PASSWORD = "H33451959*"
                MSSQL_DATABASE = "master"
                ALLOWED_DATABASES = "master,DerinSISBkm,DerinSISBkmCrm,DerinSISBkmWeb,BKMDATA,EncoreMerkez,BKM"
            }
        }
    }
    preferences = @{
        coworkScheduledTasksEnabled = $true
        ccdScheduledTasksEnabled = $true
        sidebarMode = "task"
        coworkWebSearchEnabled = $true
        keepAwakeEnabled = $true
        coworkOnboardingResumeStep = $null
        chicagoEnabled = $false
        localAgentModeTrustedFolders = @("D:\Dev\sqlserver-mcp-server")
    }
}

# JSON'a dok ve yaz (UTF-8 BOM'suz)
$json = $newConfig | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($configPath, $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host "==> Config guncellendi." -ForegroundColor Green
Write-Host ""
Write-Host "SIMDI YAPILACAK:" -ForegroundColor Yellow
Write-Host "  1. Sistem tepsisinden Claude Desktop'a sag tikla -> Quit" -ForegroundColor Yellow
Write-Host "  2. Claude Desktop'i tekrar ac" -ForegroundColor Yellow
Write-Host "  3. Cowork moduna don, devam et" -ForegroundColor Yellow
Write-Host ""
Read-Host "Devam etmek icin Enter'a bas"
