param([string]$PackageRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path)
$ErrorActionPreference = 'Stop'
$packagePath = [System.IO.Path]::GetFullPath($PackageRoot)
$compilerPath = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $compilerPath)) {
    throw 'Se requiere el compilador de .NET Framework 4.x incluido en Windows para recompilar el iniciador.'
}
$sourcePath = Join-Path $PSScriptRoot 'AAMIX.Launcher.cs'
$iconPath = Join-Path $packagePath 'proyecto/assets/aamix_a_white.ico'
$outputPath = Join-Path $packagePath 'AAMIX.exe'
& $compilerPath '/nologo' '/target:winexe' '/platform:anycpu' '/optimize+' '/utf8output' '/reference:System.Windows.Forms.dll' "/win32icon:$iconPath" "/out:$outputPath" $sourcePath
if ($LASTEXITCODE -ne 0) { throw 'No se pudo compilar AAMIX.exe.' }
Get-Item -LiteralPath $outputPath | Select-Object Name,Length
