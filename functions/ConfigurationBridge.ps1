<#
.SYNOPSIS
    DotWin Configuration Bridge Functions - Functions for working with the Configuration Bridge

.DESCRIPTION
    This module provides functions for creating and working with the DotWinConfigurationBridge class,
    enabling rich configuration consumption by functions with user override support.

.NOTES
    Created on:   6/27/2025
    Created by:   DotWin Implementation Plan Phase 1
    Purpose:      Enable rich configuration consumption by functions with user override support
#>

function New-DotWinConfigurationBridge {
    <#
    .SYNOPSIS
        Creates a new DotWin Configuration Bridge instance
    
    .DESCRIPTION
        Initializes a new DotWinConfigurationBridge object that serves as the central integration
        point between module configurations and user overrides.
    
    .PARAMETER ModuleConfigPath
        Path to the module's configuration directory (typically the config folder)

    .PARAMETER UserConfigPath
        Optional path to the user's configuration directory

    .EXAMPLE
        $bridge = New-DotWinConfigurationBridge -ModuleConfigPath "C:\DotWin\config" -UserConfigPath "C:\Users\John\.dotwin"
        
    .EXAMPLE
        $bridge = New-DotWinConfigurationBridge -ModuleConfigPath $PSScriptRoot\..\config
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleConfigPath,
        
        [Parameter(Mandatory = $false)]
        [string]$UserConfigPath
    )
    
    try {
        # Validate module config path exists
        if (-not (Test-Path $ModuleConfigPath)) {
            throw "Module configuration path does not exist: $ModuleConfigPath"
        }
        
        # Create and return the bridge instance
        $bridge = [DotWinConfigurationBridge]::new($ModuleConfigPath, $UserConfigPath)
        
        Write-DotWinLog "Configuration bridge created successfully" -Level "Information"
        return $bridge
        
    } catch {
        Write-DotWinLog "Failed to create configuration bridge: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Get-DotWinPackageConfiguration {
    <#
    .SYNOPSIS
        Resolves package configuration using the Configuration Bridge
    
    .DESCRIPTION
        Uses the DotWinConfigurationBridge to resolve package configurations with user overrides

    .PARAMETER Bridge
        The DotWinConfigurationBridge instance to use

    .PARAMETER Category
        The package category to resolve (e.g., "Development", "Productivity", "Gaming")

    .EXAMPLE
        $packages = Get-DotWinPackageConfiguration -Bridge $bridge -Category "Development"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [DotWinConfigurationBridge]$Bridge,
        
        [Parameter(Mandatory = $true)]
        [string]$Category
    )

    try {
        # Use module-level bridge if none provided
        if (-not $Bridge) {
            if (-not $script:DotWinConfigurationBridge) {
                throw "No Configuration Bridge provided and module-level bridge is not initialized"
            }
            $Bridge = $script:DotWinConfigurationBridge
        }

        return $Bridge.ResolvePackageConfiguration($Category)
    } catch {
        Write-DotWinLog "Failed to resolve package configuration for category '$Category': $($_.Exception.Message)" -Level "Error"
        return @{}
    }
}

function Get-DotWinTerminalConfiguration {
    <#
    .SYNOPSIS
        Resolves terminal configuration using the Configuration Bridge
    
    .DESCRIPTION
        Uses the DotWinConfigurationBridge to resolve terminal configurations with user overrides

    .PARAMETER Bridge
        The DotWinConfigurationBridge instance to use

    .PARAMETER Theme
        The terminal theme to resolve

    .PARAMETER IncludeProfiles
        Whether to include terminal profiles in the configuration

    .PARAMETER IncludeKeybindings
        Whether to include keybindings in the configuration

    .PARAMETER IncludeSettings
        Whether to include general settings in the configuration

    .EXAMPLE
        $terminalConfig = Get-DotWinTerminalConfiguration -Bridge $bridge -Theme "Dark" -IncludeProfiles -IncludeSettings
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [DotWinConfigurationBridge]$Bridge,
        
        [Parameter(Mandatory = $true)]
        [string]$Theme,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeProfiles,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeKeybindings,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeSettings
    )

    try {
        # Use module-level bridge if none provided
        if (-not $Bridge) {
            if (-not $script:DotWinConfigurationBridge) {
                throw "No Configuration Bridge provided and module-level bridge is not initialized"
            }
            $Bridge = $script:DotWinConfigurationBridge
        }

        return $Bridge.ResolveTerminalConfiguration($Theme, $IncludeProfiles.IsPresent, $IncludeKeybindings.IsPresent, $IncludeSettings.IsPresent)
    } catch {
        Write-DotWinLog "Failed to resolve terminal configuration for theme '$Theme': $($_.Exception.Message)" -Level "Error"
        return @{}
    }
}

function Get-DotWinProfileConfiguration {
    <#
    .SYNOPSIS
        Resolves PowerShell profile configuration using the Configuration Bridge
    
    .DESCRIPTION
        Uses the DotWinConfigurationBridge to resolve PowerShell profile configurations with user overrides

    .PARAMETER Bridge
        The DotWinConfigurationBridge instance to use

    .PARAMETER ProfileType
        The profile type to resolve (e.g., "Developer", "Administrator", "Basic")

    .PARAMETER IncludeModules
        Whether to include PowerShell modules in the configuration

    .PARAMETER IncludeAliases
        Whether to include aliases in the configuration

    .PARAMETER IncludeFunctions
        Whether to include functions in the configuration

    .PARAMETER IncludePrompt
        Whether to include prompt configuration

    .EXAMPLE
        $profileConfig = Get-DotWinProfileConfiguration -Bridge $bridge -ProfileType "Developer" -IncludeModules -IncludeAliases
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [DotWinConfigurationBridge]$Bridge,
        
        [Parameter(Mandatory = $true)]
        [string]$ProfileType,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeModules,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeAliases,
        
        [Parameter(Mandatory = $false)]
        [switch]$IncludeFunctions,

        [Parameter(Mandatory = $false)]
        [switch]$IncludePrompt
    )
    
    try {
        # Use module-level bridge if none provided
        if (-not $Bridge) {
            if (-not $script:DotWinConfigurationBridge) {
                throw "No Configuration Bridge provided and module-level bridge is not initialized"
            }
            $Bridge = $script:DotWinConfigurationBridge
        }

        return $Bridge.ResolveProfileConfiguration($ProfileType, $IncludeModules.IsPresent, $IncludeAliases.IsPresent, $IncludeFunctions.IsPresent, $IncludePrompt.IsPresent)
    } catch {
        Write-DotWinLog "Failed to resolve profile configuration for type '$ProfileType': $($_.Exception.Message)" -Level "Error"
        return @{}
    }
}

function Clear-DotWinConfigurationCache {
    <#
    .SYNOPSIS
        Clears the configuration cache in the Configuration Bridge
    
    .DESCRIPTION
        Forces the Configuration Bridge to reload all configurations on the next request

    .PARAMETER Bridge
        The DotWinConfigurationBridge instance to clear cache for

    .EXAMPLE
        Clear-DotWinConfigurationCache -Bridge $bridge
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [DotWinConfigurationBridge]$Bridge
    )

    try {
        # Use module-level bridge if none provided
        if (-not $Bridge) {
            if (-not $script:DotWinConfigurationBridge) {
                throw "No Configuration Bridge provided and module-level bridge is not initialized"
            }
            $Bridge = $script:DotWinConfigurationBridge
        }

        $Bridge.ClearCache()
        Write-DotWinLog "Configuration cache cleared successfully" -Level "Information"
    } catch {
        Write-DotWinLog "Failed to clear configuration cache: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Set-DotWinConfigurationCacheEnabled {
    <#
    .SYNOPSIS
        Enables or disables configuration caching in the Configuration Bridge
    
    .DESCRIPTION
        Controls whether the Configuration Bridge caches resolved configurations for performance

    .PARAMETER Bridge
        The DotWinConfigurationBridge instance to configure

    .PARAMETER Enabled
        Whether to enable or disable caching

    .EXAMPLE
        Set-DotWinConfigurationCacheEnabled -Bridge $bridge -Enabled $false
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [DotWinConfigurationBridge]$Bridge,

        [Parameter(Mandatory = $true)]
        [bool]$Enabled
    )

    try {
        # Use module-level bridge if none provided
        if (-not $Bridge) {
            if (-not $script:DotWinConfigurationBridge) {
                throw "No Configuration Bridge provided and module-level bridge is not initialized"
            }
            $Bridge = $script:DotWinConfigurationBridge
        }

        $Bridge.SetCacheEnabled($Enabled)
        Write-DotWinLog "Configuration cache enabled set to: $Enabled" -Level "Information"
    } catch {
        Write-DotWinLog "Failed to set configuration cache enabled: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Get-DotWinConfigurationCacheStatistics {
    <#
    .SYNOPSIS
        Gets cache statistics from the Configuration Bridge
    
    .DESCRIPTION
        Returns information about the current state of the configuration cache

    .PARAMETER Bridge
        The DotWinConfigurationBridge instance to get statistics from

    .EXAMPLE
        $stats = Get-DotWinConfigurationCacheStatistics -Bridge $bridge
        Write-Host "Cache has $($stats.CachedItems) items"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [DotWinConfigurationBridge]$Bridge
    )

    try {
        # Use module-level bridge if none provided
        if (-not $Bridge) {
            if (-not $script:DotWinConfigurationBridge) {
                throw "No Configuration Bridge provided and module-level bridge is not initialized"
            }
            $Bridge = $script:DotWinConfigurationBridge
        }

        return $Bridge.GetCacheStatistics()
    } catch {
        Write-DotWinLog "Failed to get configuration cache statistics: $($_.Exception.Message)" -Level "Error"
        return @{}
    }
}
