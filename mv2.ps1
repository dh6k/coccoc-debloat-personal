<# 1. To patch dll in a protected folder like "c:\program files" run this script as Administrator.
   2. If your Windows isn't configured to run ps1 files, you can run it from command prompt like this:
      powershell -ep bypass -noprofile "patch-chrome-mv2.ps1"
#>
param(
    [string]$dll,
    [string]$dir = $pwd,
    [switch]$NoPause
)

function doPatch([string]$path, [string]$pathLabel = '') {
    $dll = $script:dll = if ($path.EndsWith('\')) { Join-Path $path browser.dll } else { $path }
    if (!(Test-Path -literal $dll)) { return }
    $localAppData = [Environment]::GetFolderPath('LocalApplicationData')
    write-host -f yellow "`n$(@($pathLabel, (split-path $dll).Replace($localAppData, '%LocalAppData%')) -join ' ')"

    $script:stream = [IO.File]::Open($dll, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    $reader = [IO.BinaryReader]$stream
    $enc = [Text.Encoding]::GetEncoding(28591)
    $features = @(
        '-ExtensionManifestV2Unsupported'
        '-ExtensionManifestV2Disabled'
        '-ExtensionsManifestV3Only'
        '+AllowLegacyMV2Extensions'
    )

    write-host -f DarkGray "`tREADING browser.dll..."
    [void]$stream.seek(0x3C, 0)
    $coff = $reader.ReadUint32() + 4
    $coffSize = 20
    [void]$stream.seek($coff, 0)
    $bytes = $reader.ReadBytes($coffSize + 2)
    $is64 = [BitConverter]::ToUInt16($bytes, 0) -eq 0x8664
    $isPE32 = [BitConverter]::ToUInt16($bytes, $coffSize) -eq 0x010b
    [void]$stream.seek($coff + $coffSize + 24 + 4 * $isPE32, 0)
    $imageBase = if ($isPE32) { $reader.ReadUInt32() } else { $reader.ReadUInt64() }

    # find sections
    $extraHeaderSize = [BitConverter]::ToUInt16($bytes, 16)
    $numSections = [BitConverter]::ToUInt16($bytes, 2)
    [void]$stream.seek($coff + $coffSize + $extraHeaderSize, 0)
    $sections = @{}
    foreach ($i in 1..$numSections) {
        $sec = $reader.ReadBytes(40)
        $i = $sec.IndexOf([byte]0)
        $name = $enc.GetString($sec, 0, $(if ($i -lt 0) { 8 } else { [math]::min(8, $i) }))
        if ($name -eq '.rdata' -or $name -eq '.data') {
            $sections[$name.substring(1)] = @{
                addr = $imageBase + [uint64][BitConverter]::ToUInt32($sec, 12);
                size = [BitConverter]::ToUInt32($sec, 16);
                filePos = [BitConverter]::ToUInt32($sec, 20);
            }
            if ($sections.count -eq 2) { break }
        }
    }

    # .rdata section
    if (!$sections.rdata) {
        return "Could not find .rdata section"
    }
    [void]$stream.seek($sections.rdata.filePos, 0)
    $cur = 0
    $step = 1MB
    $featArea = 1kB
    $featData = [ordered]@{}
    while ($cur -lt $sections.rdata.size) {
        $bytes = $reader.ReadBytes($step)
        $str = $enc.GetString($bytes)
        foreach ($feat in $features) {
            if ($featData[$feat]) { continue }
            $pos = $str.indexOf($feat.substring(1))
            if ($pos -lt 0) { break }
            $featData[$feat] = $sections.rdata.addr + $cur + $pos
        }
        if ($featData.count -eq $features.length) { break }
        $cur += $step - $featArea
        [void]$stream.seek(-$featArea, [IO.SeekOrigin]::Current)
    }
    if (!$sections.data) {
        return "Could not find .data section"
    }

    # .data section
    [void]$stream.seek($sections.data.filePos, 0)
    $len = $sections.data.size
    $bytes = $reader.ReadBytes($len)
    if ($is64) { $words = [uint64[]]::new($len -shr 3) }
        else { $words = [uint32[]]::new($len -shr 2) }
    [Buffer]::BlockCopy($bytes, 0, $words, 0, $len)
    $bytes = $null
    $copied = $false
    $wordType = $words[0].getType()
    foreach ($feat in $featData.Keys) {
        $needle = $featData[$feat]
        $needle = $needle -as $wordType
        $val = ($feat[0] -eq '+') -as $wordType
        $feat = $feat.substring(1)
        $i = $words.indexOf($needle)
        while ($i -ge 0 -and !($words[$i + 1] -in 0,1)) {
            $i = [Array]::IndexOf($words, $needle, $i + 1)
        }
        if (!++$i) {
            return "Could not find $feat pointer in .data section"
        }
        if ($words[$i] -eq $val) {
            write-host -f darkcyan "`tAlready patched $feat"
            continue
        }
        if (!$copied) {
            $copied = $true
            $stream.close()
            $script:stream = [IO.File]::Open($dll, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
            if (test-path -literal "$dll.BAK") {
                write-host -f darkgray "`tFound an existing backup of the original dll."
            } else {
                write-host -f darkgray "`tBacking up the original dll..."
                [IO.File]::Copy($dll, "$dll.BAK")
            }
        }
        write-host -f cyan "`tPatching $feat..."
        [void]$stream.seek($sections.data.filePos + $i * (4 + 4 * $is64), 0)
        $stream.WriteByte($val)
    }
    write-host -f green "`tDONE."
}

function tryPatch($a, $b) {
    try {
        $err = doPatch $a $b
    } catch {
        $a = ([regex]'\): "(.+)"').match($Error[0]).Groups[1].Value
        if ($a) { $err = $a.Replace($dll, 'browser.dll') } else { $Error[0] }
    }
    if ($stream) {
        $stream.close()
        $script:stream = $null
    }
    if ($err) {
        write-host -f red "`t$err"
        $script:err = $true
    }
    [GC]::Collect()
}

$err = $false
if ($dll) {
    tryPatch $dll
} else {
    $pathsDone = @{}
    tryPatch ((gi -literal $dir).fullName + '\') 'CURRENT DIRECTORY'
    ('HKLM', 'HKCU') | %{
        $hive = $_
        ('', '\Wow6432Node') | %{
            $key = "${hive}:\SOFTWARE$_\Google\Update\Clients"
            gci -ea silentlycontinue $key -r | gp | ?{ $_.CommandLine } | %{
                $path = $_.CommandLine -replace '"(.+?\\\d+\.\d+\.\d+\.\d+\\).+', '$1'
                if (!$pathsDone[$path.toLower()]) {
                    tryPatch $path REGISTRY
                    $pathsDone[$path.toLower()] = $true
                }
            }
        }
    }
}

if ($err) {
    if (-not $NoPause) {
        read-host "Press Enter key to exit"
    }
    exit 1
}

exit 0
