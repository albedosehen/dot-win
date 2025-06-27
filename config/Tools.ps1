<#
.SYNOPSIS
    System tools configuration for the DotWin PowerShell module.

.DESCRIPTION
    This file contains system tools definitions and configurations,
    providing centralized management for system utilities and tools.
#>

# System tools categories and definitions
$script:DotWinSystemTools = @{
    'WindowsFeatures' = @{
        Description = "Windows optional features and capabilities"
        Tools = @(
            @{
                Name = "Windows Subsystem for Linux"
                FeatureName = "Microsoft-Windows-Subsystem-Linux"
                Type = "WindowsOptionalFeature"
                Category = "Development"
                Description = "Enables running Linux environments directly on Windows"
                Dependencies = @("VirtualMachinePlatform")
                RequiresRestart = $true
            },
            @{
                Name = "Virtual Machine Platform"
                FeatureName = "VirtualMachinePlatform"
                Type = "WindowsOptionalFeature"
                Category = "Virtualization"
                Description = "Enables platform support for virtual machines"
                RequiresRestart = $true
            },
            @{
                Name = "Hyper-V"
                FeatureName = "Microsoft-Hyper-V-All"
                Type = "WindowsOptionalFeature"
                Category = "Virtualization"
                Description = "Microsoft's hardware virtualization product"
                RequiresRestart = $true
                RequiresAdmin = $true
            },
            @{
                Name = "Windows Sandbox"
                FeatureName = "Containers-DisposableClientVM"
                Type = "WindowsOptionalFeature"
                Category = "Security"
                Description = "Isolated desktop environment for safely running applications"
                Dependencies = @("VirtualMachinePlatform")
                RequiresRestart = $true
            },
            @{
                Name = "IIS Web Server"
                FeatureName = "IIS-WebServerRole"
                Type = "WindowsOptionalFeature"
                Category = "WebServer"
                Description = "Internet Information Services web server"
                RequiresAdmin = $true
                SubFeatures = @(
                    "IIS-WebServer",
                    "IIS-CommonHttpFeatures",
                    "IIS-HttpErrors",
                    "IIS-HttpRedirect",
                    "IIS-ApplicationDevelopment",
                    "IIS-NetFxExtensibility45",
                    "IIS-ASPNET45",
                    "IIS-ISAPIExtensions",
                    "IIS-ISAPIFilter",
                    "IIS-ManagementConsole"
                )
            },
            @{
                Name = "Telnet Client"
                FeatureName = "TelnetClient"
                Type = "WindowsOptionalFeature"
                Category = "Networking"
                Description = "Command-line telnet client"
            },
            @{
                Name = "TFTP Client"
                FeatureName = "TFTP"
                Type = "WindowsOptionalFeature"
                Category = "Networking"
                Description = "Trivial File Transfer Protocol client"
            }
        )
    }
    
    'SystemServices' = @{
        Description = "Windows system services configuration"
        Tools = @(
            @{
                Name = "Windows Search"
                ServiceName = "WSearch"
                Type = "Service"
                Category = "System"
                Description = "Windows Search indexing service"
                RecommendedState = "Running"
                StartupType = "Automatic"
            },
            @{
                Name = "Windows Update"
                ServiceName = "wuauserv"
                Type = "Service"
                Category = "System"
                Description = "Windows Update service"
                RecommendedState = "Running"
                StartupType = "Manual"
            },
            @{
                Name = "Print Spooler"
                ServiceName = "Spooler"
                Type = "Service"
                Category = "System"
                Description = "Print spooler service"
                RecommendedState = "Running"
                StartupType = "Automatic"
                Optional = $true
            },
            @{
                Name = "Fax Service"
                ServiceName = "Fax"
                Type = "Service"
                Category = "System"
                Description = "Windows Fax service"
                RecommendedState = "Stopped"
                StartupType = "Disabled"
                Optional = $true
            },
            @{
                Name = "Remote Registry"
                ServiceName = "RemoteRegistry"
                Type = "Service"
                Category = "Security"
                Description = "Remote registry access service"
                RecommendedState = "Stopped"
                StartupType = "Disabled"
                SecurityRisk = $true
            },
            @{
                Name = "Remote Desktop Services"
                ServiceName = "TermService"
                Type = "Service"
                Category = "Remote"
                Description = "Remote Desktop Services"
                RecommendedState = "Stopped"
                StartupType = "Manual"
                Optional = $true
            }
        )
    }
    
    'RegistryTweaks' = @{
        Description = "Registry-based system optimizations"
        Tools = @(
            @{
                Name = "Disable Fast Startup"
                Type = "Registry"
                Category = "Performance"
                Description = "Disables Windows fast startup feature"
                RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
                RegistryName = "HiberbootEnabled"
                RegistryValue = 0
                RegistryType = "DWORD"
                RequiresAdmin = $true
            },
            @{
                Name = "Show File Extensions"
                Type = "Registry"
                Category = "Explorer"
                Description = "Shows file extensions in Windows Explorer"
                RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                RegistryName = "HideFileExt"
                RegistryValue = 0
                RegistryType = "DWORD"
            },
            @{
                Name = "Show Hidden Files"
                Type = "Registry"
                Category = "Explorer"
                Description = "Shows hidden files and folders in Windows Explorer"
                RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
                RegistryName = "Hidden"
                RegistryValue = 1
                RegistryType = "DWORD"
            },
            @{
                Name = "Disable Sticky Keys"
                Type = "Registry"
                Category = "Accessibility"
                Description = "Disables sticky keys accessibility feature"
                RegistryPath = "HKCU:\Control Panel\Accessibility\StickyKeys"
                RegistryName = "Flags"
                RegistryValue = "506"
                RegistryType = "String"
            },
            @{
                Name = "Disable Mouse Acceleration"
                Type = "Registry"
                Category = "Mouse"
                Description = "Disables mouse pointer acceleration"
                RegistryPath = "HKCU:\Control Panel\Mouse"
                RegistryName = "MouseSpeed"
                RegistryValue = 0
                RegistryType = "DWORD"
            },
            @{
                Name = "Enable Dark Mode"
                Type = "Registry"
                Category = "Appearance"
                Description = "Enables Windows dark mode"
                RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
                RegistryName = "AppsUseLightTheme"
                RegistryValue = 0
                RegistryType = "DWORD"
            },
            @{
                Name = "Disable Windows Defender Real-time Protection"
                Type = "Registry"
                Category = "Security"
                Description = "Disables Windows Defender real-time protection"
                RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection"
                RegistryName = "DisableRealtimeMonitoring"
                RegistryValue = 1
                RegistryType = "DWORD"
                RequiresAdmin = $true
                SecurityRisk = $true
                Optional = $true
            }
        )
    }
    
    'PowerSettings' = @{
        Description = "Power management and performance settings"
        Tools = @(
            @{
                Name = "High Performance Power Plan"
                Type = "PowerScheme"
                Category = "Performance"
                Description = "Sets power plan to high performance"
                PowerSchemeGuid = "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
                RecommendedFor = @("Desktop", "Gaming")
            },
            @{
                Name = "Balanced Power Plan"
                Type = "PowerScheme"
                Category = "Performance"
                Description = "Sets power plan to balanced"
                PowerSchemeGuid = "381b4222-f694-41f0-9685-ff5bb260df2e"
                RecommendedFor = @("Laptop", "General")
            },
            @{
                Name = "Power Saver Plan"
                Type = "PowerScheme"
                Category = "Performance"
                Description = "Sets power plan to power saver"
                PowerSchemeGuid = "a1841308-3541-4fab-bc81-f71556f20b4a"
                RecommendedFor = @("Laptop", "Battery")
            },
            @{
                Name = "Disable USB Selective Suspend"
                Type = "PowerSetting"
                Category = "USB"
                Description = "Disables USB selective suspend to prevent device disconnections"
                PowerSettingGuid = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"
                PowerSubGroupGuid = "2a737441-1930-4402-8d77-b2bebba308a3"
                Value = 0
            },
            @{
                Name = "Disable Hard Disk Sleep"
                Type = "PowerSetting"
                Category = "Storage"
                Description = "Prevents hard disks from sleeping"
                PowerSettingGuid = "6738e2c4-e8a5-4a42-b16a-e040e769756e"
                PowerSubGroupGuid = "0012ee47-9041-4b5d-9b77-535fba8b1442"
                Value = 0
            }
        )
    }
    
    'NetworkSettings' = @{
        Description = "Network configuration and optimization"
        Tools = @(
            @{
                Name = "Disable IPv6"
                Type = "Registry"
                Category = "Network"
                Description = "Disables IPv6 protocol"
                RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
                RegistryName = "DisabledComponents"
                RegistryValue = 255
                RegistryType = "DWORD"
                RequiresAdmin = $true
                Optional = $true
            },
            @{
                Name = "Enable Network Discovery"
                Type = "Registry"
                Category = "Network"
                Description = "Enables network discovery"
                RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Network\NewNetworkWindowOff"
                RegistryName = ""
                RegistryValue = ""
                RegistryType = "String"
                RequiresAdmin = $true
            },
            @{
                Name = "Set DNS Servers (Cloudflare)"
                Type = "NetworkAdapter"
                Category = "Network"
                Description = "Sets DNS servers to Cloudflare (1.1.1.1, 1.0.0.1)"
                PrimaryDNS = "1.1.1.1"
                SecondaryDNS = "1.0.0.1"
                RequiresAdmin = $true
                Optional = $true
            },
            @{
                Name = "Set DNS Servers (Google)"
                Type = "NetworkAdapter"
                Category = "Network"
                Description = "Sets DNS servers to Google (8.8.8.8, 8.8.4.4)"
                PrimaryDNS = "8.8.8.8"
                SecondaryDNS = "8.8.4.4"
                RequiresAdmin = $true
                Optional = $true
            }
        )
    }
}

# Recommended tool sets for different scenarios
$script:DotWinToolSets = @{
    'Developer' = @{
        Description = "Tools and settings for developers"
        Tools = @(
            "Windows Subsystem for Linux",
            "Virtual Machine Platform",
            "Show File Extensions",
            "Show Hidden Files",
            "High Performance Power Plan",
            "Disable USB Selective Suspend"
        )
    }
    
    'Gamer' = @{
        Description = "Optimizations for gaming"
        Tools = @(
            "High Performance Power Plan",
            "Disable Fast Startup",
            "Disable Mouse Acceleration",
            "Disable USB Selective Suspend",
            "Disable Hard Disk Sleep"
        )
    }
    
    'Privacy' = @{
        Description = "Privacy and security focused settings"
        Tools = @(
            "Remote Registry",
            "Remote Desktop Services",
            "Show File Extensions",
            "Show Hidden Files"
        )
    }
    
    'Performance' = @{
        Description = "Performance optimizations"
        Tools = @(
            "High Performance Power Plan",
            "Disable Fast Startup",
            "Disable USB Selective Suspend",
            "Disable Hard Disk Sleep"
        )
    }
    
    'Basic' = @{
        Description = "Basic system improvements"
        Tools = @(
            "Show File Extensions",
            "Show Hidden Files",
            "Enable Dark Mode",
            "Disable Sticky Keys"
        )
    }
}

function Get-SystemToolsByCategory {
    <#
    .SYNOPSIS
        Gets system tools by category.
    
    .DESCRIPTION
        Retrieves system tool definitions for a specific category.
    
    .PARAMETER Category
        The category of tools to retrieve.
    
    .OUTPUTS
        Array of tool objects for the specified category.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('WindowsFeatures', 'SystemServices', 'RegistryTweaks', 'PowerSettings', 'NetworkSettings', 'All')]
        [string]$Category
    )
    
    if ($Category -eq 'All') {
        $tools = @()
        foreach ($categoryName in $script:DotWinSystemTools.Keys) {
            $tools += $script:DotWinSystemTools[$categoryName].Tools
        }
        return $tools
    }
    
    if ($script:DotWinSystemTools.ContainsKey($Category)) {
        return $script:DotWinSystemTools[$Category].Tools
    } else {
        Write-Warning "Unknown system tools category: $Category"
        return @()
    }
}

function Get-SystemToolsBySet {
    <#
    .SYNOPSIS
        Gets system tools by predefined set.
    
    .DESCRIPTION
        Retrieves system tool definitions for a specific tool set.
    
    .PARAMETER ToolSet
        The tool set to retrieve.
    
    .OUTPUTS
        Array of tool objects for the specified set.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Developer', 'Gamer', 'Privacy', 'Performance', 'Basic')]
        [string]$ToolSet
    )
    
    if (-not $script:DotWinToolSets.ContainsKey($ToolSet)) {
        Write-Warning "Unknown tool set: $ToolSet"
        return @()
    }
    
    $toolNames = $script:DotWinToolSets[$ToolSet].Tools
    $tools = @()
    
    foreach ($toolName in $toolNames) {
        foreach ($categoryName in $script:DotWinSystemTools.Keys) {
            $tool = $script:DotWinSystemTools[$categoryName].Tools | Where-Object { $_.Name -eq $toolName }
            if ($tool) {
                $tools += $tool
                break
            }
        }
    }
    
    return $tools
}

function Get-SystemToolCategories {
    <#
    .SYNOPSIS
        Gets all available system tool categories.
    
    .DESCRIPTION
        Retrieves information about all available system tool categories.
    
    .OUTPUTS
        Hashtable containing category information.
    #>
    [CmdletBinding()]
    param()
    
    $categories = @{}
    foreach ($categoryName in $script:DotWinSystemTools.Keys) {
        $categories[$categoryName] = @{
            Description = $script:DotWinSystemTools[$categoryName].Description
            ToolCount = $script:DotWinSystemTools[$categoryName].Tools.Count
        }
    }
    
    return $categories
}

function Get-SystemToolSets {
    <#
    .SYNOPSIS
        Gets all available system tool sets.
    
    .DESCRIPTION
        Retrieves information about all available system tool sets.
    
    .OUTPUTS
        Hashtable containing tool set information.
    #>
    [CmdletBinding()]
    param()
    
    $toolSets = @{}
    foreach ($setName in $script:DotWinToolSets.Keys) {
        $toolSets[$setName] = @{
            Description = $script:DotWinToolSets[$setName].Description
            ToolCount = $script:DotWinToolSets[$setName].Tools.Count
            Tools = $script:DotWinToolSets[$setName].Tools
        }
    }
    
    return $toolSets
}

function Find-SystemTool {
    <#
    .SYNOPSIS
        Finds system tools by name or description.
    
    .DESCRIPTION
        Searches for system tools across all categories by name or description.
    
    .PARAMETER Query
        The search query (tool name or description).
    
    .PARAMETER Exact
        Perform exact match search.
    
    .OUTPUTS
        Array of matching tool objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter()]
        [switch]$Exact
    )
    
    $matchingTools = @()
    
    foreach ($categoryName in $script:DotWinSystemTools.Keys) {
        $categoryTools = $script:DotWinSystemTools[$categoryName].Tools
        
        if ($Exact) {
            $matched = $categoryTools | Where-Object { $_.Name -eq $Query }
        } else {
            $matched = $categoryTools | Where-Object { $_.Name -like "*$Query*" -or $_.Description -like "*$Query*" }
        }
        
        $matchingTools += $matched
    }
    
    return $matchingTools
}

function Get-SystemToolConfiguration {
    <#
    .SYNOPSIS
        Gets configuration for a specific system tool.
    
    .DESCRIPTION
        Retrieves the configuration settings for a specific system tool by name.
    
    .PARAMETER ToolName
        The name of the tool to get configuration for.
    
    .OUTPUTS
        Hashtable containing tool configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ToolName
    )
    
    foreach ($categoryName in $script:DotWinSystemTools.Keys) {
        $tool = $script:DotWinSystemTools[$categoryName].Tools | Where-Object { $_.Name -eq $ToolName }
        if ($tool) {
            return $tool
        }
    }
    
    Write-Warning "System tool not found: $ToolName"
    return $null
}

# Note: These functions are available when this config file is dot-sourced
# No Export-ModuleMember needed as this is a configuration file, not a module