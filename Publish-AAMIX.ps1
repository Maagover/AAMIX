#requires -Version 5.1
<#
.SYNOPSIS
Valida y publica una versión estable de AAMIX sin sustituir versiones publicadas.
.DESCRIPTION
PrepareOnly genera el manifiesto y las sumas sin conectarse a GitHub.
La publicación crea un borrador, sube cuatro archivos, comprueba los hashes
informados por GitHub y, sólo entonces, cambia la versión pública Latest.
No incorpora tokens al manifiesto ni al instalador. Usa la sesión de gh auth login.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$Version,
    [Parameter(Mandatory = $true)][string]$GameZip,
    [Parameter(Mandatory = $true)][string]$Installer,
    [Parameter(Mandatory = $true)][string]$ArchiveRoot,
    [string]$DisplayVersion = '',
    [string]$EntryPoint = 'AAMIX.exe',
    [int]$MinimumLauncher = 1,
    [string]$NotesFile = '',
    [string]$OutputDirectory = '',
    [string]$Target = '',
    [string]$GhPath = 'gh',
    [switch]$PrepareOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$stableVersionPattern = '^(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})\.(0|[1-9][0-9]{0,5})$'
if ($Version -notmatch $stableVersionPattern) { throw 'Version debe ser estable y tener tres números, por ejemplo 1.1.0; sin v inicial ni ceros iniciales.' }
if ($Repository -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{0,38}/[A-Za-z0-9][A-Za-z0-9_.-]{0,99}$') { throw 'Repository debe tener el formato USUARIO/REPOSITORIO de github.com.' }
if ($ArchiveRoot -notmatch '^AAMIX[_A-Za-z0-9.-]+$' -or $ArchiveRoot.Length -gt 80 -or $ArchiveRoot.EndsWith('.')) { throw 'ArchiveRoot debe ser el nombre simple de la carpeta raíz del ZIP, por ejemplo AAMIX_v1.0.' }
if ($EntryPoint -cne 'AAMIX.exe') { throw 'La entrada de este instalador debe ser AAMIX.exe.' }
if ($MinimumLauncher -lt 1 -or $MinimumLauncher -gt 1) { throw 'Este publicador corresponde al protocolo de instalador 1; no aumentes MinimumLauncher sin distribuir primero un instalador compatible.' }
if ([string]::IsNullOrWhiteSpace($DisplayVersion)) { $DisplayVersion = $Version }
if ($DisplayVersion.Length -gt 32 -or $DisplayVersion -match '[\r\n\x00-\x1f]') { throw 'DisplayVersion no es válido.' }
if ($Target -and $Target -notmatch '^[A-Za-z0-9][A-Za-z0-9/_.-]{0,199}$') { throw 'Target no es válido.' }

function Existing-File([string]$Path) {
    $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) { throw "No es un archivo: $Path" }
    return $resolved
}
function Sha256([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hash.ComputeHash($stream))).Replace('-', '').ToLowerInvariant() }
    finally { $hash.Dispose(); $stream.Dispose() }
}
function Write-Utf8([string]$Path, [string]$Content) { [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false))) }
function Assert-WindowsExe([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        if ($stream.Length -lt 128 -or $stream.ReadByte() -ne 77 -or $stream.ReadByte() -ne 90) { throw "No parece un ejecutable Windows válido: $Path" }
    } finally { $stream.Dispose() }
}
function Invoke-Gh([string[]]$Arguments) {
    # Argumentos separados: no se evalúan comandos ni se imprime la credencial.
    $result = & $GhPath @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw ("GitHub CLI falló: gh {0}`n{1}" -f ($Arguments -join ' '), ($result -join "`n")) }
    return ($result -join "`n")
}

$zipPath = Existing-File $GameZip
$installerPath = Existing-File $Installer
$zipName = [IO.Path]::GetFileName($zipPath)
if ($zipName -notmatch '^AAMIX[_A-Za-z0-9.-]+\.zip$') { throw 'Usa un nombre ASCII de paquete AAMIX, por ejemplo AAMIX_Windows_v1.1.zip.' }
if ((Get-Item -LiteralPath $zipPath).Length -ge 2GB) { throw 'Cada archivo de una release de GitHub debe ser menor a 2 GiB.' }
Assert-WindowsExe $installerPath
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
try {
    if ($archive.Entries.Count -gt 50000 -or $archive.Entries.Count -lt 1) { throw 'Cantidad de archivos del ZIP fuera del límite admitido.' }
    $seen = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $files = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $entryFound = $false
    [long]$expandedSize = 0
    foreach ($entry in $archive.Entries) {
        $name = $entry.FullName
        if ($name.Length -gt 220 -or $name.Contains('\') -or $name.StartsWith('/') -or $name -match '[:\x00-\x1f]') { throw "Ruta no permitida en el ZIP: $name" }
        $parts = $name.TrimEnd('/').Split('/')
        if ($parts[0] -cne $ArchiveRoot) { throw "El ZIP debe contener solamente la carpeta raíz $ArchiveRoot; se encontró $name" }
        foreach ($part in $parts) {
            if (-not $part -or $part -eq '.' -or $part -eq '..' -or $part.EndsWith('.') -or $part.EndsWith(' ') -or $part -match '[<>"|?*]' -or $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') { throw "Nombre Windows no permitido: $name" }
            if ($part -match '^(?i:\.git|\.env|\.env\.local|credentials\.json|tokens\.json|private-backups|respaldos-cuentas)$') { throw "Posible archivo privado dentro del paquete: $name" }
        }
        if (-not $seen.Add($name.TrimEnd('/'))) { throw "Ruta repetida en el ZIP: $name" }
        $directory = $name.EndsWith('/')
        if (-not $directory) { [void]$files.Add($name) }
        if ($name.TrimEnd('/') -ieq "$ArchiveRoot/.aamix-version.json") { throw 'El paquete incluye metadatos reservados del instalador.' }
        if ((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000 -or ($entry.ExternalAttributes -band 0x400) -ne 0) { throw "No se admiten enlaces simbólicos: $name" }
        if ($entry.Length -gt 1GB -or ($directory -and $entry.Length -ne 0)) { throw "Tamaño no permitido para un archivo: $name" }
        $expandedSize += $entry.Length
        if ($expandedSize -gt 4GB) { throw 'El contenido descomprimido supera 4 GiB.' }
        if ($name -ceq "$ArchiveRoot/$EntryPoint") {
            $stream = $entry.Open()
            try { if ($entry.Length -lt 128 -or $stream.ReadByte() -ne 77 -or $stream.ReadByte() -ne 90) { throw 'AAMIX.exe del ZIP no tiene una cabecera Windows válida.' } } finally { $stream.Dispose() }
            $entryFound = $true
        }
    }
    if ($files.Contains($ArchiveRoot)) { throw 'La carpeta raíz del ZIP no puede ser un archivo.' }
    foreach ($path in $seen) {
        $parent = $path
        while ($parent.LastIndexOf('/') -ge 0) {
            $parent = $parent.Substring(0, $parent.LastIndexOf('/'))
            if ($files.Contains($parent)) { throw "El ZIP confunde archivo con carpeta: $parent" }
        }
    }
    if (-not $entryFound) { throw "No se encontró $ArchiveRoot/$EntryPoint en el ZIP." }
} finally { $archive.Dispose() }

$tag = "v$Version"
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $PSScriptRoot "prepared/$tag" }
$outPath = [IO.Path]::GetFullPath($OutputDirectory)
[void][IO.Directory]::CreateDirectory($outPath)
$manifestPath = Join-Path $outPath 'aamix-update.json'
$fixedInstaller = Join-Path $outPath 'AAMIX_Instalador.exe'
$checksumsPath = Join-Path $outPath 'SHA256SUMS.txt'
$releaseNotesPath = Join-Path $outPath 'NOTAS_DE_VERSION.md'
if ($installerPath -ne $fixedInstaller) { Copy-Item -LiteralPath $installerPath -Destination $fixedInstaller -Force }
$zipHash = Sha256 $zipPath
$manifest = [ordered]@{
    schema = 1
    version = $Version
    display_version = $DisplayVersion
    url = "https://github.com/$Repository/releases/download/$tag/$zipName"
    sha256 = $zipHash
    size = [long](Get-Item -LiteralPath $zipPath).Length
    root = $ArchiveRoot
    entrypoint = $EntryPoint
    minimum_launcher = $MinimumLauncher
}
Write-Utf8 $manifestPath (($manifest | ConvertTo-Json -Depth 4) + "`n")
if ($NotesFile) {
    $notesPath = Existing-File $NotesFile
    if ($notesPath -ne $releaseNotesPath) { Copy-Item -LiteralPath $notesPath -Destination $releaseNotesPath -Force }
} else {
    $notes = @"
AAMIX $DisplayVersion para Windows

Descarga **AAMIX_Instalador.exe**, ábrelo y pulsa **Instalar**. Si ya tienes AAMIX, abre el mismo instalador y pulsa **Actualizar**; después, **Jugar**.

El ZIP completo también está disponible como descarga portátil. Las cuentas y el progreso se conservan al actualizar.
"@
    Write-Utf8 $releaseNotesPath ($notes + "`n")
}
$assetPaths = @($zipPath, $fixedInstaller, $manifestPath, $checksumsPath)
$checksumLines = foreach ($path in @($zipPath, $fixedInstaller, $manifestPath)) { "$(Sha256 $path)  $([IO.Path]::GetFileName($path))" }
Write-Utf8 $checksumsPath (($checksumLines -join "`n") + "`n")
Write-Host "Preparado $tag. Manifiesto: $manifestPath"
Write-Host "ZIP: $zipName | $($manifest.size) bytes | SHA256 $zipHash"
if ($PrepareOnly) { return }

if (-not (Get-Command -Name $GhPath -ErrorAction SilentlyContinue)) { throw 'Instala GitHub CLI o indica -GhPath con la ruta a gh.exe. Los archivos ya quedaron preparados.' }
# Comprobar la interfaz disponible antes de modificar el servidor.
foreach ($command in @('create', 'upload', 'edit')) { [void](Invoke-Gh @('release', $command, '--help')) }
[void](Invoke-Gh @('auth', 'status', '--hostname', 'github.com'))
$repoInfo = (Invoke-Gh @('repo', 'view', $Repository, '--json', 'nameWithOwner,isPrivate')) | ConvertFrom-Json
if ($repoInfo.isPrivate) { throw 'El repositorio de distribución debe ser público para que los jugadores descarguen sin cuenta ni token.' }
$releases = @((Invoke-Gh @('api', "repos/$Repository/releases?per_page=100")) | ConvertFrom-Json)
foreach ($release in $releases) {
    if ($release.tag_name -ceq $tag) { throw "La release $tag ya existe. No se reemplazan versiones. Si quedó un borrador incompleto, revísalo en GitHub; para cambios usa una versión nueva." }
    if (-not $release.draft -and -not $release.prerelease -and $release.tag_name -match '^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$') {
        $remoteVersion = $release.tag_name.Substring(1)
        if ([Version]$Version -le [Version]$remoteVersion) { throw "La versión debe superar $remoteVersion; no se publica una actualización que haga retroceder el juego." }
    }
}
$createArgs = @('release', 'create', $tag, '--repo', $Repository, '--draft', '--latest=false', '--title', "AAMIX $DisplayVersion", '--notes-file', $releaseNotesPath)
if ($Target) { $createArgs += @('--target', $Target) }
[void](Invoke-Gh $createArgs)
Write-Host 'Borrador creado. La versión pública anterior sigue disponible.'
try {
    foreach ($path in $assetPaths) { [void](Invoke-Gh @('release', 'upload', $tag, $path, '--repo', $Repository)) }
    $remote = (Invoke-Gh @('api', "repos/$Repository/releases/tags/$tag")) | ConvertFrom-Json
    if (-not $remote.draft) { throw 'La release dejó de ser un borrador durante la carga; se requiere revisión.' }
    foreach ($path in $assetPaths) {
        $assetName = [IO.Path]::GetFileName($path)
        $matches = @($remote.assets | Where-Object { $_.name -ceq $assetName })
        if ($matches.Count -ne 1 -or $matches[0].state -ne 'uploaded' -or $matches[0].size -ne (Get-Item -LiteralPath $path).Length) { throw "No se confirmó la carga completa de $assetName." }
        $digestProperty = $matches[0].PSObject.Properties['digest']
        if (-not $digestProperty -or $digestProperty.Value -cne "sha256:$(Sha256 $path)") { throw "GitHub no confirmó el hash de $assetName. Se conserva el borrador; no se cambia Latest." }
    }
    [void](Invoke-Gh @('release', 'edit', $tag, '--repo', $Repository, '--draft=false', '--latest'))
    $latest = (Invoke-Gh @('api', "repos/$Repository/releases/latest")) | ConvertFrom-Json
    if ($latest.tag_name -cne $tag) { throw 'La publicación terminó pero Latest no coincide; revisa la release antes de compartirla.' }
    Write-Host "Publicado: https://github.com/$Repository/releases/tag/$tag"
    Write-Host "Enlace para jugadores: https://github.com/$Repository/releases/latest/download/AAMIX_Instalador.exe"
} catch {
    Write-Warning "Publicación incompleta. No se borraron versiones ni archivos. Revisa el borrador $tag en https://github.com/$Repository/releases antes de continuar."
    throw
}
