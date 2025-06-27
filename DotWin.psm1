﻿<#
.SYNOPSIS
    DotWin PowerShell Module - Windows 11 Configuration Management System

.DESCRIPTION
    DotWin is a declarative configuration management system for Windows 11,
    similar to NixOS dotfiles or Terraform. This module provides the core
    functionality for managing system configurations in a reproducible way.

.NOTES
    Created on:   6/9/2025 10:37 PM
    Created by:   Shon Thomas (albedosehen)
    Module Name:  DotWin
#>

#Requires -Version 5.1

# Import configuration classes using multiple approaches to ensure availability across all contexts
try {
    # Method 1: Load in global scope
    $global:ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create(". '$PSScriptRoot\Classes.ps1'"), $null, $null)

    # Method 2: Also load in current module scope
    . "$PSScriptRoot\Classes.ps1"

    # Method 3: Force load using Add-Type equivalent for PowerShell classes
    $classContent = Get-Content "$PSScriptRoot\Classes.ps1" -Raw
    Invoke-Expression $classContent

    Write-Verbose "DotWin classes loaded successfully using multiple methods"
} catch {
    Write-Error "Failed to load DotWin classes: $($_.Exception.Message)"
    throw
}

# Module variables
$script:DotWinModuleRoot = $PSScriptRoot
$script:DotWinConfigPath = Join-Path $PSScriptRoot "config"
$script:DotWinAppsPath = Join-Path $PSScriptRoot "apps"

# Initialize module logging
$script:DotWinLogLevel = "Information"
$script:DotWinLogPath = $null

# Module initialization
Write-Verbose "Initializing DotWin module..."
Write-Verbose "Module root: $script:DotWinModuleRoot"
Write-Verbose "Config path: $script:DotWinConfigPath"
Write-Verbose "Apps path: $script:DotWinAppsPath"

# Import all public functions
$PublicFunctions = @(
    'Invoke-DotWinConfiguration',
    'Get-DotWinStatus',
    'Install-Packages',
    'Install-Applications',
    'Install-SystemTools',
    'Install-ChipsetDriver',
    'Enable-Features',
    'Disable-Telemetry',
    'Remove-Bloatware',
    'Set-PowershellProfile',
    'Set-TerminalProfile',
    'Get-ChipsetInformation',
    'Search-ChipsetDriver',
    'Get-DotWinSystemProfile',
    'Get-DotWinRecommendations',
    'Invoke-DotWinProfiledConfiguration',
    'Get-DotWinSystemHealth',
    'Test-DotWinConfiguration',
    'Register-DotWinPlugin',
    'Get-DotWinPlugin',
    'Unregister-DotWinPlugin',
    'Enable-DotWinPlugin',
    'Disable-DotWinPlugin',
    'Test-DotWinEnvironment',
    'Get-DotWinModuleInfo'
)

foreach ($Function in $PublicFunctions) {
    $FunctionPath = Join-Path $PSScriptRoot "functions\$Function.ps1"
    if (Test-Path $FunctionPath) {
        Write-Verbose "Loading function: $Function"
        . $FunctionPath
    } else {
        Write-Warning "Function file not found: $FunctionPath"
    }
}

# Internal helper functions
function Write-DotWinLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",

        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error', 'Verbose')]
        [string]$Level = 'Information'
    )

    if (-not $PSBoundParameters.ContainsKey('Message') -or [string]::IsNullOrWhiteSpace($Message)) {
        return  # Just do nothing if Message is missing or empty
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    switch ($Level) {
        'Information' { Write-Information $logMessage -InformationAction Continue }
        'Warning' { Write-Warning $logMessage }
        'Error' { Write-Error $logMessage }
        'Verbose' { Write-Verbose $logMessage }
    }

    if ($script:DotWinLogPath -and (Test-Path (Split-Path $script:DotWinLogPath -Parent))) {
        Add-Content -Path $script:DotWinLogPath -Value $logMessage
    }
}

function Get-DotWinModuleInfo {
    <#
    .SYNOPSIS
        Gets information about the DotWin module.

    .DESCRIPTION
        Returns metadata about the DotWin module including version,
        paths, and configuration status.
    #>
    [CmdletBinding()]
    param()

    $manifest = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot "DotWin.psd1")

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

function Test-DotWinEnvironment {
    <#
    .SYNOPSIS
        Tests if the current environment is suitable for DotWin operations.

    .DESCRIPTION
        Validates that the current PowerShell session and system environment
        meet the requirements for DotWin configuration management.
    #>
    [CmdletBinding()]
    param()

    $issues = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1 or higher is required"
    }

    # Check if running on Windows
    if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)) {
        $issues += "DotWin is designed for Windows systems"
    }

    # Check if running as administrator (for some operations)
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    return [PSCustomObject]@{
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
        IsAdministrator = $isAdmin
        PowerShellVersion = $PSVersionTable.PSVersion
        OperatingSystem = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            (Get-CimInstance Win32_OperatingSystem).Caption
        } else {
            "Non-Windows"
        }
    }
}

# Export module members
Export-ModuleMember -Function $PublicFunctions
Export-ModuleMember -Variable @()

Write-Verbose "DotWin module initialization complete."
