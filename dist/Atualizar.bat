<# :
@echo off
rem ==========================================================================
rem  Atualizar Junk Construction Simulator
rem  Baixa a versao mais recente do GitHub e extrai na pasta
rem  "JunkConstructionSimulator" ao lado deste arquivo.
rem  (Se este .bat estiver DENTRO da pasta do jogo, atualiza a propria pasta.)
rem ==========================================================================
title Atualizar Junk Construction Simulator
set "JCS_DIR=%~dp0"
set "JCS_SELF=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([IO.File]::ReadAllText($env:JCS_SELF))"
echo.
pause
exit /b
#>

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'NynaUwU/Metalworks-JunkContructionSimulator'
$game = 'JunkConstructionSimulator'
$here = $env:JCS_DIR.TrimEnd('\')
# Rodando de dentro da pasta do jogo: atualiza ela mesma.
if ((Split-Path $here -Leaf) -eq $game) { $here = Split-Path $here -Parent }
$folder = Join-Path $here $game
$versionFile = Join-Path $folder 'versao.txt'

try {
    Write-Host 'Procurando a versao mais recente...'
    $rel = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'jcs-atualizador' }
    $asset = $rel.assets | Where-Object { $_.name -like '*-windows.zip' } | Select-Object -First 1
    if (-not $asset) { throw 'O release mais recente nao tem o zip do Windows.' }

    $current = ''
    if (Test-Path -LiteralPath $versionFile) { $current = (Get-Content -LiteralPath $versionFile -Raw).Trim() }
    if ($current -eq $rel.tag_name) {
        Write-Host "Voce ja tem a versao mais recente ($($rel.tag_name))." -ForegroundColor Green
    } else {
        if ($current) { Write-Host "Versao instalada: $current" }
        $mb = [math]::Round($asset.size / 1MB)
        Write-Host "Baixando $($rel.tag_name) ($mb MB)..."
        $zip = Join-Path $env:TEMP $asset.name
        Invoke-WebRequest $asset.browser_download_url -OutFile $zip -UseBasicParsing

        if (Get-Process -Name $game -ErrorAction SilentlyContinue) {
            Write-Host 'O jogo esta aberto. Feche o jogo e aperte Enter para continuar...' -ForegroundColor Yellow
            [void](Read-Host)
        }
        Write-Host 'Extraindo...'
        Expand-Archive -LiteralPath $zip -DestinationPath $here -Force
        Remove-Item -LiteralPath $zip -Force
        Set-Content -LiteralPath $versionFile -Value $rel.tag_name
        Write-Host "Pronto! $($rel.tag_name) em: $folder" -ForegroundColor Green
    }

    $exe = Join-Path $folder "$game.exe"
    if (Test-Path -LiteralPath $exe) {
        $ans = Read-Host 'Abrir o jogo agora? (S/N)'
        if ($ans -match '^[sS]') { Start-Process -FilePath $exe -WorkingDirectory $folder }
    }
} catch {
    Write-Host "Erro: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'Confira a internet. Se o jogo estiver aberto, feche e tente de novo.'
}
