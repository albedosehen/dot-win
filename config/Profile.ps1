<#
.SYNOPSIS
    Profile configuration definitions for the DotWin PowerShell module.

.DESCRIPTION
    This file contains PowerShell profile configurations and settings,
    providing centralized management for profile customization.
#>

# PowerShell profile configurations
$script:DotWinProfileConfigurations = @{
    'Developer' = @{
        Description = "Developer-focused PowerShell profile"
        ProfileType = "CurrentUser"
        Modules = @(
            @{ Name = "PSReadLine"; MinimumVersion = "2.0.0" },
            @{ Name = "Terminal-Icons"; MinimumVersion = "0.1.0" },
            @{ Name = "posh-git"; MinimumVersion = "1.0.0" },
            @{ Name = "PowerShellGet"; MinimumVersion = "2.0.0" },
            @{ Name = "PSScriptAnalyzer"; MinimumVersion = "1.19.0" },
            @{ Name = "Pester"; MinimumVersion = "5.0.0" }
        )
        Aliases = @{
            ".." = "Set-Location .."
            "..." = "Set-Location ../.."
            "...." = "Set-Location ../../.."
            "ll" = "Get-ChildItem -Force"
            "la" = "Get-ChildItem -Force -Hidden"
            "grep" = "Select-String"
            "which" = "Get-Command"
            "touch" = "New-Item -ItemType File"
            "sudo" = "Start-Process -Verb RunAs"
            "code." = "code ."
            "gst" = "git status"
            "gco" = "git checkout"
            "gcb" = "git checkout -b"
            "gp" = "git push"
            "gl" = "git pull"
            "ga" = "git add"
            "gc" = "git commit"
            "gd" = "git diff"
        }
        Functions = @{
            "Get-DirectorySize" = @"
function Get-DirectorySize {
    param([string]`$Path = ".")
    Get-ChildItem -Path `$Path -Recurse -File | Measure-Object -Property Length -Sum |
        Select-Object @{Name="Size(MB)"; Expression={[math]::Round(`$_.Sum / 1MB, 2)}}
}
"@
            "Test-Administrator" = @"
function Test-Administrator {
    `$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return `$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
"@
            "Get-GitStatus" = @"
function Get-GitStatus {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        git status --porcelain
    }
}
"@
            "Set-LocationUp" = @"
function Set-LocationUp {
    param([int]`$Levels = 1)
    `$path = ".."
    for (`$i = 1; `$i -lt `$Levels; `$i++) {
        `$path = Join-Path `$path ".."
    }
    Set-Location `$path
}
Set-Alias -Name "up" -Value "Set-LocationUp"
"@
            "Find-File" = @"
function Find-File {
    param(
        [string]`$Name,
        [string]`$Path = "."
    )
    Get-ChildItem -Path `$Path -Recurse -Name "*`$Name*" -ErrorAction SilentlyContinue
}
Set-Alias -Name "ff" -Value "Find-File"
"@
        }
        Prompt = @"
function prompt {
    `$location = Get-Location
    `$isAdmin = Test-Administrator
    `$adminIndicator = if (`$isAdmin) { " [ADMIN]" } else { "" }

    # Git status if in a git repository
    `$gitStatus = ""
    if (Get-Command git -ErrorAction SilentlyContinue) {
        `$gitBranch = git branch --show-current 2>`$null
        if (`$gitBranch) {
            `$gitChanges = git status --porcelain 2>`$null
            `$changeIndicator = if (`$gitChanges) { "*" } else { "" }
            `$gitStatus = " (`$gitBranch`$changeIndicator)"
        }
    }

    Write-Host "PS " -NoNewline -ForegroundColor Green
    Write-Host "`$location" -NoNewline -ForegroundColor Blue
    Write-Host "`$gitStatus" -NoNewline -ForegroundColor Yellow
    Write-Host "`$adminIndicator" -NoNewline -ForegroundColor Red
    Write-Host ">" -NoNewline -ForegroundColor Green
    return " "
}
"@
        CustomContent = @(
            "# Developer Profile Configuration",
            "# Set execution policy for current user",
            "if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Undefined') {",
            "    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force",
            "}",
            "",
            "# Set PSReadLine options",
            "if (Get-Module PSReadLine -ListAvailable) {",
            "    Set-PSReadLineOption -PredictionSource History",
            "    Set-PSReadLineOption -PredictionViewStyle ListView",
            "    Set-PSReadLineOption -EditMode Windows",
            "    Set-PSReadLineKeyHandler -Key Tab -Function Complete",
            "    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteChar",
            "}",
            "",
            "# Welcome message",
            "Write-Host 'DotWin Developer Profile Loaded' -ForegroundColor Green"
        )
    }

    'Basic' = @{
        Description = "Basic PowerShell profile with essential features"
        ProfileType = "CurrentUser"
        Modules = @(
            @{ Name = "PSReadLine"; MinimumVersion = "2.0.0" },
            @{ Name = "Terminal-Icons"; MinimumVersion = "0.1.0" }
        )
        Aliases = @{
            "ll" = "Get-ChildItem -Force"
            "la" = "Get-ChildItem -Force -Hidden"
            "grep" = "Select-String"
            "which" = "Get-Command"
            "touch" = "New-Item -ItemType File"
        }
        Functions = @{
            "Test-Administrator" = @"
function Test-Administrator {
    `$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return `$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
"@
        }
        Prompt = @"
function prompt {
    `$location = Get-Location
    `$isAdmin = Test-Administrator
    `$adminIndicator = if (`$isAdmin) { " [ADMIN]" } else { "" }

    Write-Host "PS " -NoNewline -ForegroundColor Green
    Write-Host "`$location" -NoNewline -ForegroundColor Blue
    Write-Host "`$adminIndicator" -NoNewline -ForegroundColor Red
    Write-Host ">" -NoNewline -ForegroundColor Green
    return " "
}
"@
        CustomContent = @(
            "# Basic Profile Configuration",
            "# Set PSReadLine options if available",
            "if (Get-Module PSReadLine -ListAvailable) {",
            "    Set-PSReadLineOption -EditMode Windows",
            "}",
            "",
            "Write-Host 'DotWin Basic Profile Loaded' -ForegroundColor Cyan"
        )
    }

    'PowerUser' = @{
        Description = "Advanced PowerShell profile for power users"
        ProfileType = "CurrentUser"
        Modules = @(
            @{ Name = "PSReadLine"; MinimumVersion = "2.0.0" },
            @{ Name = "Terminal-Icons"; MinimumVersion = "0.1.0" },
            @{ Name = "posh-git"; MinimumVersion = "1.0.0" },
            @{ Name = "PowerShellGet"; MinimumVersion = "2.0.0" },
            @{ Name = "PSScriptAnalyzer"; MinimumVersion = "1.19.0" },
            @{ Name = "ImportExcel"; MinimumVersion = "7.0.0" },
            @{ Name = "Microsoft.PowerShell.SecretManagement"; MinimumVersion = "1.1.0" }
        )
        Aliases = @{
            "ll" = "Get-ChildItem -Force"
            "la" = "Get-ChildItem -Force -Hidden"
            "grep" = "Select-String"
            "which" = "Get-Command"
            "touch" = "New-Item -ItemType File"
            "sudo" = "Start-Process -Verb RunAs"
            "reload" = ". `$PROFILE"
            "edit-profile" = "code `$PROFILE"
            "sysinfo" = "Get-ComputerInfo"
            "processes" = "Get-Process | Sort-Object CPU -Descending | Select-Object -First 10"
            "services" = "Get-Service | Where-Object Status -eq Running"
        }
        Functions = @{
            "Get-DirectorySize" = @"
function Get-DirectorySize {
    param([string]`$Path = ".")
    Get-ChildItem -Path `$Path -Recurse -File | Measure-Object -Property Length -Sum |
        Select-Object @{Name="Size(MB)"; Expression={[math]::Round(`$_.Sum / 1MB, 2)}}
}
"@
            "Test-Administrator" = @"
function Test-Administrator {
    `$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return `$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
"@
            "Get-SystemInfo" = @"
function Get-SystemInfo {
    `$os = Get-CimInstance Win32_OperatingSystem
    `$cpu = Get-CimInstance Win32_Processor
    `$memory = Get-CimInstance Win32_PhysicalMemory | Measure-Object Capacity -Sum

    [PSCustomObject]@{
        ComputerName = `$env:COMPUTERNAME
        OS = `$os.Caption
        Version = `$os.Version
        CPU = `$cpu.Name
        Cores = `$cpu.NumberOfCores
        Memory = [math]::Round(`$memory.Sum / 1GB, 2)
        Uptime = (Get-Date) - `$os.LastBootUpTime
    }
}
"@
            "Get-NetworkInfo" = @"
function Get-NetworkInfo {
    Get-NetAdapter | Where-Object Status -eq Up |
        Select-Object Name, InterfaceDescription, LinkSpeed,
        @{Name="IPAddress"; Expression={(Get-NetIPAddress -InterfaceIndex `$_.InterfaceIndex -AddressFamily IPv4).IPAddress}}
}
"@
            "Test-Port" = @"
function Test-Port {
    param(
        [string]`$ComputerName,
        [int]`$Port,
        [int]`$Timeout = 3000
    )

    try {
        `$tcp = New-Object System.Net.Sockets.TcpClient
        `$connect = `$tcp.BeginConnect(`$ComputerName, `$Port, `$null, `$null)
        `$wait = `$connect.AsyncWaitHandle.WaitOne(`$Timeout, `$false)

        if (`$wait) {
            `$tcp.EndConnect(`$connect)
            `$tcp.Close()
            return `$true
        } else {
            `$tcp.Close()
            return `$false
        }
    } catch {
        return `$false
    }
}
"@
        }
        Prompt = @"
function prompt {
    `$location = Get-Location
    `$isAdmin = Test-Administrator
    `$adminIndicator = if (`$isAdmin) { " [ADMIN]" } else { "" }

    # Git status if in a git repository
    `$gitStatus = ""
    if (Get-Command git -ErrorAction SilentlyContinue) {
        `$gitBranch = git branch --show-current 2>`$null
        if (`$gitBranch) {
            `$gitChanges = git status --porcelain 2>`$null
            `$changeIndicator = if (`$gitChanges) { "*" } else { "" }
            `$gitStatus = " (`$gitBranch`$changeIndicator)"
        }
    }

    # Time indicator
    `$time = Get-Date -Format "HH:mm:ss"

    Write-Host "[`$time] " -NoNewline -ForegroundColor Gray
    Write-Host "PS " -NoNewline -ForegroundColor Green
    Write-Host "`$location" -NoNewline -ForegroundColor Blue
    Write-Host "`$gitStatus" -NoNewline -ForegroundColor Yellow
    Write-Host "`$adminIndicator" -NoNewline -ForegroundColor Red
    Write-Host ">" -NoNewline -ForegroundColor Green
    return " "
}
"@
        CustomContent = @(
            "# Power User Profile Configuration",
            "# Set execution policy",
            "if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Undefined') {",
            "    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force",
            "}",
            "",
            "# Enhanced PSReadLine configuration",
            "if (Get-Module PSReadLine -ListAvailable) {",
            "    Set-PSReadLineOption -PredictionSource HistoryAndPlugin",
            "    Set-PSReadLineOption -PredictionViewStyle ListView",
            "    Set-PSReadLineOption -EditMode Windows",
            "    Set-PSReadLineOption -HistorySearchCursorMovesToEnd",
            "    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete",
            "    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteChar",
            "    Set-PSReadLineKeyHandler -Key Ctrl+w -Function BackwardDeleteWord",
            "    Set-PSReadLineKeyHandler -Key Alt+d -Function DeleteWord",
            "    Set-PSReadLineKeyHandler -Key Ctrl+LeftArrow -Function BackwardWord",
            "    Set-PSReadLineKeyHandler -Key Ctrl+RightArrow -Function ForwardWord",
            "}",
            "",
            "# Custom variables",
            "`$global:DotWinProfileType = 'PowerUser'",
            "`$global:DotWinProfileLoaded = Get-Date",
            "",
            "Write-Host 'DotWin Power User Profile Loaded' -ForegroundColor Magenta"
        )
    }

    'Minimal' = @{
        Description = "Minimal PowerShell profile with basic enhancements"
        ProfileType = "CurrentUser"
        Modules = @(
            @{ Name = "PSReadLine"; MinimumVersion = "2.0.0" }
        )
        Aliases = @{
            "ll" = "Get-ChildItem"
            "which" = "Get-Command"
        }
        Functions = @{}
        Prompt = @"
function prompt {
    `$location = Split-Path -Leaf (Get-Location)
    Write-Host "PS:`$location> " -NoNewline -ForegroundColor Green
    return " "
}
"@
        CustomContent = @(
            "# Minimal Profile Configuration",
            "Write-Host 'DotWin Minimal Profile Loaded' -ForegroundColor Yellow"
        )
    }
}

# Profile templates for different scenarios
$script:DotWinProfileTemplates = @{
    'ISE' = @{
        Description = "Profile optimized for PowerShell ISE"
        Modules = @(
            @{ Name = "ISESteroids"; MinimumVersion = "2.7.0"; Optional = $true }
        )
        CustomContent = @(
            "# ISE-specific configuration",
            "if (`$psISE) {",
            "    `$psISE.Options.FontSize = 12",
            "    `$psISE.Options.FontName = 'Consolas'",
            "    `$psISE.Options.ShowWarningForDuplicateFiles = `$false",
            "}"
        )
    }

    'VSCode' = @{
        Description = "Profile optimized for VS Code PowerShell extension"
        CustomContent = @(
            "# VS Code-specific configuration",
            "if (`$env:TERM_PROGRAM -eq 'vscode') {",
            "    # VS Code specific settings",
            "    `$PSStyle.FileInfo.Directory = `"`e[34;1m`"",
            "}"
        )
    }

    'WindowsTerminal' = @{
        Description = "Profile optimized for Windows Terminal"
        CustomContent = @(
            "# Windows Terminal-specific configuration",
            "if (`$env:WT_SESSION) {",
            "    # Windows Terminal specific settings",
            "    `$PSStyle.FileInfo.Directory = `"`e[94m`"",
            "    `$PSStyle.FileInfo.Executable = `"`e[92m`"",
            "}"
        )
    }
}

function Get-ProfileConfiguration {
    <#
    .SYNOPSIS
        Gets a PowerShell profile configuration by name.

    .DESCRIPTION
        Retrieves a predefined PowerShell profile configuration.

    .PARAMETER ProfileName
        The name of the profile configuration to retrieve.

    .OUTPUTS
        Hashtable containing profile configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Developer', 'Basic', 'PowerUser', 'Minimal')]
        [string]$ProfileName
    )

    if ($script:DotWinProfileConfigurations.ContainsKey($ProfileName)) {
        return $script:DotWinProfileConfigurations[$ProfileName]
    } else {
        Write-Warning "Unknown profile configuration: $ProfileName"
        return $null
    }
}

function Get-ProfileTemplate {
    <#
    .SYNOPSIS
        Gets a PowerShell profile template by name.

    .DESCRIPTION
        Retrieves a predefined PowerShell profile template for specific environments.

    .PARAMETER TemplateName
        The name of the profile template to retrieve.

    .OUTPUTS
        Hashtable containing profile template.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('ISE', 'VSCode', 'WindowsTerminal')]
        [string]$TemplateName
    )

    if ($script:DotWinProfileTemplates.ContainsKey($TemplateName)) {
        return $script:DotWinProfileTemplates[$TemplateName]
    } else {
        Write-Warning "Unknown profile template: $TemplateName"
        return $null
    }
}

function Get-AvailableProfileConfigurations {
    <#
    .SYNOPSIS
        Gets all available PowerShell profile configurations.

    .DESCRIPTION
        Retrieves information about all available profile configurations.

    .OUTPUTS
        Hashtable containing profile configuration information.
    #>
    [CmdletBinding()]
    param()

    $configurations = @{}
    foreach ($configName in $script:DotWinProfileConfigurations.Keys) {
        $config = $script:DotWinProfileConfigurations[$configName]
        $configurations[$configName] = @{
            Description = $config.Description
            ProfileType = $config.ProfileType
            ModuleCount = if ($config.Modules) { $config.Modules.Count } else { 0 }
            AliasCount = if ($config.Aliases) { $config.Aliases.Count } else { 0 }
            FunctionCount = if ($config.Functions) { $config.Functions.Count } else { 0 }
            HasPrompt = [bool]$config.Prompt
        }
    }

    return $configurations
}

function Get-AvailableProfileTemplates {
    <#
    .SYNOPSIS
        Gets all available PowerShell profile templates.

    .DESCRIPTION
        Retrieves information about all available profile templates.

    .OUTPUTS
        Hashtable containing profile template information.
    #>
    [CmdletBinding()]
    param()

    $templates = @{}
    foreach ($templateName in $script:DotWinProfileTemplates.Keys) {
        $template = $script:DotWinProfileTemplates[$templateName]
        $templates[$templateName] = @{
            Description = $template.Description
            ModuleCount = if ($template.Modules) { $template.Modules.Count } else { 0 }
            HasCustomContent = [bool]$template.CustomContent
        }
    }

    return $templates
}

function Merge-ProfileConfiguration {
    <#
    .SYNOPSIS
        Merges multiple profile configurations.

    .DESCRIPTION
        Combines multiple profile configurations into a single configuration.

    .PARAMETER BaseConfiguration
        The base profile configuration.

    .PARAMETER AdditionalConfigurations
        Additional configurations to merge.

    .OUTPUTS
        Hashtable containing merged profile configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$BaseConfiguration,

        [Parameter(Mandatory = $true)]
        [hashtable[]]$AdditionalConfigurations
    )

    $merged = $BaseConfiguration.Clone()

    foreach ($config in $AdditionalConfigurations) {
        # Merge modules
        if ($config.Modules) {
            if (-not $merged.Modules) { $merged.Modules = @() }
            $merged.Modules += $config.Modules
        }

        # Merge aliases
        if ($config.Aliases) {
            if (-not $merged.Aliases) { $merged.Aliases = @{} }
            foreach ($alias in $config.Aliases.GetEnumerator()) {
                $merged.Aliases[$alias.Key] = $alias.Value
            }
        }

        # Merge functions
        if ($config.Functions) {
            if (-not $merged.Functions) { $merged.Functions = @{} }
            foreach ($function in $config.Functions.GetEnumerator()) {
                $merged.Functions[$function.Key] = $function.Value
            }
        }

        # Merge custom content
        if ($config.CustomContent) {
            if (-not $merged.CustomContent) { $merged.CustomContent = @() }
            $merged.CustomContent += $config.CustomContent
        }

        # Override prompt if specified
        if ($config.Prompt) {
            $merged.Prompt = $config.Prompt
        }
    }

    return $merged
}

# Note: These functions are available when this config file is dot-sourced
# No Export-ModuleMember needed as this is a configuration file, not a module