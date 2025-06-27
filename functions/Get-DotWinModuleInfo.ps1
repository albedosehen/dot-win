function Get-DotWinModuleInfo {
    <#
    .SYNOPSIS
        Gets information about the DotWin module.

    .DESCRIPTION
        Returns metadata about the DotWin module including version,
        paths, and configuration status.

    .EXAMPLE
        Get-DotWinModuleInfo
        
        Returns detailed information about the DotWin module including version,
        paths, and system information.

    .OUTPUTS
        PSCustomObject
        Returns an object containing module metadata and configuration details.
    #>
    [CmdletBinding()]
    param()

    $manifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot "..\DotWin.psd1")

    return [PSCustomObject]@{
        Name = $manifest.ModuleVersion
        Version = $manifest.ModuleVersion
        Author = $manifest.Author
        Description = $manifest.Description
        ModuleRoot = $script:DotWinModuleRoot
        ConfigPath = $script:DotWinConfigPath
        AppsPath = $script:DotWinAppsPath
        LogLevel = $script:DotWinLogLevel
        LogPath = $script:DotWinLogPath
        PowerShellVersion = $PSVersionTable.PSVersion
        OperatingSystem = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            (Get-CimInstance Win32_OperatingSystem).Caption
        } else {
            "Non-Windows"
        }
    }
}
