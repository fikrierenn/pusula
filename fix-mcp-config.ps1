# MCP Config Fix Script
# Cowork/Claude Desktop'in sqlserver + portalhub MCP baglantilarini kurar.
# Calistirma: PowerShell'i ACIK olarak calistir, bu dosyaya surukle-birak
# Veya: sag tik -> "Run with PowerShell"
# Veya: fix-mcp-config.bat ile cift tikla (sessiz exit'e karsi guvenli)

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
    mcpServers = [ordered]@{
        atlasops = @{
            command = "dotnet"
            args = @("D:\Dev\AtlasOPS\src\AtlasOps.Mcp\bin\Debug\net10.0\AtlasOps.Mcp.dll")
        }
        sqlserver = @{
            command = "node"
            args = @("D:\Dev\sqlserver-mcp-server\dist\index.js")
            cwd = "D:\Dev\sqlserver-mcp-server"
            env = [ordered]@{
                MSSQL_HOST = "192.168.40.201"
                MSSQL_PORT = "1433"
                MSSQL_USER = "sa"
                MSSQL_PASSWORD = "H33451959*"
                MSSQL_DATABASE = "master"
                ALLOWED_DATABASES = "master,DerinSISBkm,DerinSISBkmCrm,DerinSISBkmWeb,BKMDATA,EncoreMerkez,BKM"
            }
        }
        portalhub = @{
            command = "node"
            args = @("D:\Dev\sqlserver-mcp-server\dist\index.js")
            cwd = "D:\Dev\sqlserver-mcp-server"
            env = [ordered]@{
                MSSQL_HOST = "BT-FIKRI\SQLEXPRESS"
                MSSQL_USER = "sa"
                MSSQL_PASSWORD = "fe9610578+*"
                MSSQL_DATABASE = "PortalHUB"
                ALLOWED_DATABASES = "master,PortalHUB"
            }
        }
    }
    preferences = [ordered]@{
        coworkScheduledTasksEnabled = $true
        ccdScheduledTasksEnabled = $true
        sidebarMode = "task"
        coworkWebSearchEnabled = $true
        keepAwakeEnabled = $true
        coworkOnboardingResumeStep = $null
        chicagoEnabled = $false
        localAgentModeTrustedFolders = @(
            "D:\Dev\sqlserver-mcp-server",
            "D:\Dev\reporthub"
        )
    }
}

# JSON'a dok ve yaz (UTF-8 BOM'suz)
$json = $newConfig | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($configPath, $json, (New-Object System.Text.UTF8Encoding $false))

Write-Host "==> Config guncellendi." -ForegroundColor Green
Write-Host ""
Write-Host "EKLENEN MCP SUNUCULAR:" -ForegroundColor Cyan
Write-Host "  - sqlserver  -> 192.168.40.201 (BKM/ERP)"
Write-Host "  - portalhub  -> BT-FIKRI\SQLEXPRESS (PortalHUB DB)"
Write-Host ""
Write-Host "EKLENEN GUVENILIR KLASORLER:" -ForegroundColor Cyan
Write-Host "  - D:\Dev\sqlserver-mcp-server"
Write-Host "  - D:\Dev\reporthub"
Write-Host ""
Write-Host "SIMDI YAPILACAK:" -ForegroundColor Yellow
Write-Host "  1. (Eger ilk kez calistirilyorsa veya kod degistiyse)" -ForegroundColor Yellow
Write-Host "     cd D:\Dev\sqlserver-mcp-server" -ForegroundColor Yellow
Write-Host "     npm install" -ForegroundColor Yellow
Write-Host "     npm run build" -ForegroundColor Yellow
Write-Host "  2. Sistem tepsisinden Claude Desktop'a sag tikla -> Quit" -ForegroundColor Yellow
Write-Host "  3. Claude Desktop'i tekrar ac" -ForegroundColor Yellow
Write-Host "  4. Cowork moduna don, devam et" -ForegroundColor Yellow
Write-Host ""
Read-Host "Devam etmek icin Enter'a bas"
