#Requires -Version 5.1
<#
.SYNOPSIS
    Compila AbasteceApp en release y deja los artefactos listos en la carpeta
    de exportacion del Escritorio.

.DESCRIPTION
    Flutter siempre escribe en la carpeta build del proyecto. Este script
    compila contra la API central de Render y copia el APK (y opcionalmente el
    App Bundle o la version web) a la ruta de exportacion, con nombre versionado,
    copia "latest" y un build-info.json con hashes y la URL usada.

.EXAMPLE
    .\build_release.cmd

.EXAMPLE
    .\tool\build_release.ps1 -Clean -SplitAbi

.EXAMPLE
    .\tool\build_release.ps1 -ApiBaseUrl https://otro-servicio.onrender.com
#>
[CmdletBinding()]
param(
    [string]$ApiBaseUrl = 'https://abasteceapp-1.onrender.com',
    [string]$OutputDir = 'C:\Users\IPS SALUD Y VIDA\Desktop\app renderizada',
    [switch]$Clean,
    [switch]$SplitAbi,
    [switch]$Web,
    [switch]$AppBundle
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step {
    param([string]$Message)
    Write-Host ''
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Flutter {
    param([string[]]$Arguments)
    & $script:FlutterExe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($Arguments -join ' ') fallo con codigo $LASTEXITCODE."
    }
}

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pubspecPath = Join-Path $projectRoot 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspecPath)) {
    throw "No se encontro pubspec.yaml en $projectRoot."
}

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCommand) {
    throw 'Flutter no esta en PATH. Agrega C:\src\flutter\bin o instala Flutter.'
}
$script:FlutterExe = $flutterCommand.Source

$pubspec = Get-Content -LiteralPath $pubspecPath -Raw
$versionMatch = [regex]::Match($pubspec, '(?m)^version:\s*(\S+)\s*$')
$fullVersion = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { '0.0.0' }
$versionName = ($fullVersion -split '\+')[0]
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'

if (-not (Test-Path -LiteralPath $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path

Write-Step "Proyecto: $projectRoot"
Write-Step "API central: $ApiBaseUrl"
Write-Step "Version: $fullVersion"
Write-Step "Salida: $OutputDir"

Push-Location $projectRoot
try {
    if ($Clean) {
        Write-Step 'Limpiando el build anterior'
        Invoke-Flutter @('clean')
    }

    Write-Step 'Descargando dependencias (flutter pub get)'
    Invoke-Flutter @('pub', 'get')

    $apkDir = Join-Path $projectRoot 'build\app\outputs\flutter-apk'
    if (Test-Path -LiteralPath $apkDir) {
        Get-ChildItem -LiteralPath $apkDir -Filter '*.apk' -File |
            Remove-Item -Force
    }

    Write-Step 'Compilando APK release'
    $apkArgs = @(
        'build', 'apk', '--release',
        "--dart-define=API_BASE_URL=$ApiBaseUrl"
    )
    if ($SplitAbi) {
        $apkArgs += '--split-per-abi'
    }
    Invoke-Flutter $apkArgs

    $apks = @(Get-ChildItem -LiteralPath $apkDir -Filter '*.apk' -File -ErrorAction SilentlyContinue)
    if ($apks.Count -eq 0) {
        throw "No se genero ningun APK en $apkDir."
    }

    $exported = New-Object System.Collections.Generic.List[object]
    foreach ($apk in $apks) {
        $suffix = ''
        if ($SplitAbi -and $apk.BaseName -match '^app-(.+)-release$') {
            $suffix = '-' + $Matches[1]
        }
        $targetName = "AbasteceApp-$versionName-$stamp$suffix.apk"
        $target = Join-Path $OutputDir $targetName
        Copy-Item -LiteralPath $apk.FullName -Destination $target -Force
        $hash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        $sizeMb = [math]::Round($apk.Length / 1MB, 2)
        $exported.Add([pscustomobject]@{
            Name   = $targetName
            SizeMB = $sizeMb
            SHA256 = $hash
        })
        Write-Host "    APK: $targetName ($sizeMb MB)" -ForegroundColor Green
    }

    $universal = $apks |
        Where-Object { $_.Name -eq 'app-release.apk' } |
        Select-Object -First 1
    if ($universal) {
        $latest = Join-Path $OutputDir 'AbasteceApp-latest.apk'
        Copy-Item -LiteralPath $universal.FullName -Destination $latest -Force
        Write-Host "    Copia para instalar ya: $latest" -ForegroundColor Green
    }

    if ($AppBundle) {
        Write-Step 'Compilando App Bundle (.aab) para Play Store'
        Invoke-Flutter @(
            'build', 'appbundle', '--release',
            "--dart-define=API_BASE_URL=$ApiBaseUrl"
        )
        $bundleDir = Join-Path $projectRoot 'build\app\outputs\bundle\release'
        $aab = Get-ChildItem -LiteralPath $bundleDir -Filter '*.aab' -File |
            Select-Object -First 1
        if ($aab) {
            $aabTarget = Join-Path $OutputDir "AbasteceApp-$versionName-$stamp.aab"
            Copy-Item -LiteralPath $aab.FullName -Destination $aabTarget -Force
            Write-Host "    AAB: $aabTarget" -ForegroundColor Green
        }
    }

    if ($Web) {
        Write-Step 'Compilando version web contra la API de Render'
        Invoke-Flutter @(
            'build', 'web', '--release',
            "--dart-define=API_BASE_URL=$ApiBaseUrl"
        )
        $webSource = Join-Path $projectRoot 'build\web'
        $webTarget = Join-Path $OutputDir "web-$versionName-$stamp"
        if (Test-Path -LiteralPath $webTarget) {
            Remove-Item -LiteralPath $webTarget -Recurse -Force
        }
        Copy-Item -LiteralPath $webSource -Destination $webTarget -Recurse -Force
        Write-Host "    WEB: $webTarget" -ForegroundColor Green
    }

    $gitCommit = ''
    try {
        $gitCommit = (& git -C $projectRoot rev-parse --short HEAD 2>$null)
    } catch {
        $gitCommit = ''
    }

    $info = [ordered]@{
        app        = 'AbasteceApp'
        version    = $fullVersion
        apiBaseUrl = $ApiBaseUrl
        outputDir  = $OutputDir
        builtAt    = (Get-Date).ToString('o')
        gitCommit  = "$gitCommit".Trim()
        files      = $exported.ToArray()
    }
    $json = $info | ConvertTo-Json -Depth 5
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText(
        (Join-Path $OutputDir 'build-info.json'),
        $json,
        $utf8NoBom
    )

    Write-Step 'Compilacion terminada'
    Write-Host "Archivos listos en: $OutputDir" -ForegroundColor Green
    Get-ChildItem -LiteralPath $OutputDir |
        Select-Object Name, Length, LastWriteTime |
        Format-Table -AutoSize
} finally {
    Pop-Location
}
