# Configuration Bridge Integration Plan

## Executive Summary

DotWin has successfully implemented the Configuration Bridge pattern for major functions like `Set-TerminalProfile` and `Install-Applications`, achieving significant progress toward the "terraform for Windows" vision. This document provides detailed integration plans for the remaining functions that need Configuration Bridge integration to complete the declarative configuration management system.

## Integration Status Overview

### ✅ **FULLY INTEGRATED FUNCTIONS**

| Function | Status | Configuration Source | User Overrides | Fallback Strategy |
|----------|--------|---------------------|-----------------|-------------------|
| [`Set-TerminalProfile`](../functions/Set-TerminalProfile.ps1) | ✅ Complete | [`config/Terminal.ps1`](../config/Terminal.ps1) | ✅ Yes | ✅ Module config |
| [`Install-Applications`](../functions/Install-Applications.ps1) | ✅ Complete | [`config/Packages.ps1`](../config/Packages.ps1) | ✅ Yes | ✅ Legacy method |

### ❌ **FUNCTIONS REQUIRING INTEGRATION**

| Function | Priority | Issue | Configuration Available |
|----------|----------|-------|------------------------|
| [`Set-PowershellProfile`](../functions/Set-PowershellProfile.ps1) | 🔥 Critical | Hardcoded configs | [`config/Profile.ps1`](../config/Profile.ps1) |
| [`Install-SystemTools`](../functions/Install-SystemTools.ps1) | 🔥 Critical | Massive hardcoded catalog | [`config/Tools.ps1`](../config/Tools.ps1) |
| WSL Management | 📋 Opportunity | No functions exist | [`config/WSL.ps1`](../config/WSL.ps1) |

---

## 1. Set-PowershellProfile Integration Plan

### **Current Issues**

- **Line 116**: Uses hardcoded `Get-PowerShellProfileConfiguration()` instead of Configuration Bridge
- **No User Overrides**: Cannot leverage user-specific profile customizations
- **Bypasses Rich Config**: Ignores the comprehensive [`config/Profile.ps1`](../config/Profile.ps1) with 4 profile types
- **Static Behavior**: No dynamic resolution based on user preferences

### **Integration Implementation**

#### **Phase 1: Add Configuration Bridge Initialization**

```powershell
# ADD AFTER Line 102 (environment validation):
# Initialize Configuration Bridge for profile management
try {
    $moduleConfigPath = Join-Path $PSScriptRoot "..\config"
    if (-not (Test-Path $moduleConfigPath)) {
        $moduleConfigPath = Join-Path (Split-Path $PSScriptRoot -Parent) "config"
    }

    # Discover user configuration path if not provided
    if (-not $UserConfigPath) {
        Write-DotWinLog "Discovering user configuration directories" -Level "Information"
        $userConfigs = Get-DotWinUserConfigurationPath -ErrorAction SilentlyContinue
        if ($userConfigs -and $userConfigs.Count -gt 0) {
            $UserConfigPath = $userConfigs[0].Path  # Use highest priority config
            Write-DotWinLog "Found user configuration at: $UserConfigPath" -Level "Information"
        }
    }

    # Create Configuration Bridge
    $configBridge = New-DotWinConfigurationBridge -ModuleConfigPath $moduleConfigPath -UserConfigPath $UserConfigPath
    Write-DotWinLog "Configuration Bridge initialized successfully for profiles" -Level "Information"
} catch {
    Write-DotWinLog "Warning: Could not initialize Configuration Bridge for profile configuration: $($_.Exception.Message)" -Level "Warning"
    $configBridge = $null
}
```

#### **Phase 2: Replace Configuration Resolution**

```powershell
# REPLACE Line 116:
# OLD:
$profileConfig = Get-PowerShellProfileConfiguration -ProfileType $ProfileType -IncludeModules:$IncludeModules -IncludeAliases:$IncludeAliases -IncludeFunctions:$IncludeFunctions -IncludePrompt:$IncludePrompt

# NEW:
if ($configBridge) {
    Write-DotWinLog "Using Configuration Bridge for profile type: $ProfileType" -Level "Information"
    $profileConfig = Get-DotWinProfileConfiguration -Bridge $configBridge -ProfileType $ProfileType -IncludeModules:$IncludeModules -IncludeAliases:$IncludeAliases -IncludeFunctions:$IncludeFunctions -IncludePrompt:$IncludePrompt
    
    if (-not $profileConfig) {
        Write-DotWinLog "Configuration Bridge did not return profile config for type: $ProfileType, falling back to module config" -Level "Warning"
        $profileConfig = Get-PowerShellProfileConfiguration -ProfileType $ProfileType -IncludeModules:$IncludeModules -IncludeAliases:$IncludeAliases -IncludeFunctions:$IncludeFunctions -IncludePrompt:$IncludePrompt
    }
} else {
    Write-DotWinLog "Configuration Bridge not available, using module configuration for profile type: $ProfileType" -Level "Information"
    $profileConfig = Get-PowerShellProfileConfiguration -ProfileType $ProfileType -IncludeModules:$IncludeModules -IncludeAliases:$IncludeAliases -IncludeFunctions:$IncludeFunctions -IncludePrompt:$IncludePrompt
}
```

#### **Phase 3: Add Missing Configuration Bridge Function**

Add to [`functions/ConfigurationBridge.ps1`](../functions/ConfigurationBridge.ps1):

```powershell
function Get-DotWinProfileConfiguration {
    <#
    .SYNOPSIS
        Resolves PowerShell profile configuration using the Configuration Bridge
    
    .DESCRIPTION
        Uses the DotWinConfigurationBridge to resolve PowerShell profile configurations with user overrides

    .PARAMETER Bridge
        The DotWinConfigurationBridge instance to use

    .PARAMETER ProfileType
        The profile type to resolve (e.g., "Developer", "Basic", "PowerUser", "Minimal")

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
```

#### **Phase 4: Update Configuration Bridge Class**

Add to [`Classes.ps1`](../Classes.ps1) in the `DotWinConfigurationBridge` class:

```powershell
[hashtable] ResolveProfileConfiguration([string]$ProfileType, [bool]$IncludeModules, [bool]$IncludeAliases, [bool]$IncludeFunctions, [bool]$IncludePrompt) {
    $cacheKey = "Profile_${ProfileType}_${IncludeModules}_${IncludeAliases}_${IncludeFunctions}_${IncludePrompt}"
    
    if ($this.CacheEnabled -and $this.ConfigurationCache.ContainsKey($cacheKey)) {
        return $this.ConfigurationCache[$cacheKey]
    }

    try {
        # Load module profile configuration
        $moduleProfileConfig = $this.LoadModuleConfiguration("Profile.ps1")
        
        # Load user profile overrides if available
        $userProfileConfig = $this.LoadUserConfiguration("Profile.ps1")
        
        # Get base profile configuration
        $baseConfig = $null
        if ($moduleProfileConfig -and $moduleProfileConfig.DotWinProfileConfigurations -and $moduleProfileConfig.DotWinProfileConfigurations.ContainsKey($ProfileType)) {
            $baseConfig = $moduleProfileConfig.DotWinProfileConfigurations[$ProfileType].Clone()
        }
        
        if (-not $baseConfig) {
            throw "Profile type '$ProfileType' not found in module configuration"
        }
        
        # Apply user overrides if available
        if ($userProfileConfig -and $userProfileConfig.DotWinProfileConfigurations -and $userProfileConfig.DotWinProfileConfigurations.ContainsKey($ProfileType)) {
            $userOverrides = $userProfileConfig.DotWinProfileConfigurations[$ProfileType]
            $baseConfig = $this.MergeConfigurations($baseConfig, $userOverrides)
        }
        
        # Filter configuration based on includes
        if (-not $IncludeModules -and $baseConfig.ContainsKey("Modules")) {
            $baseConfig.Remove("Modules")
        }
        if (-not $IncludeAliases -and $baseConfig.ContainsKey("Aliases")) {
            $baseConfig.Remove("Aliases")
        }
        if (-not $IncludeFunctions -and $baseConfig.ContainsKey("Functions")) {
            $baseConfig.Remove("Functions")
        }
        if (-not $IncludePrompt -and $baseConfig.ContainsKey("Prompt")) {
            $baseConfig.Remove("Prompt")
        }
        
        # Cache the result
        if ($this.CacheEnabled) {
            $this.ConfigurationCache[$cacheKey] = $baseConfig
        }
        
        return $baseConfig
    } catch {
        throw "Failed to resolve profile configuration for '$ProfileType': $($_.Exception.Message)"
    }
}
```

---

## 2. Install-SystemTools Integration Plan

### Current Issues

- **Lines 82-247**: Massive hardcoded `$systemToolsCatalog` embedded in function
- **Unused Rich Configuration**: [`config/Tools.ps1`](../config/Tools.ps1) contains comprehensive tool definitions but is completely bypassed
- **No User Overrides**: Cannot customize tool selections or configurations per user
- **Function Bloat**: Tool definitions should be external configuration, not code

### Integration Implementation

#### **Phase 1: Replace Hardcoded Catalog**

```powershell
# REPLACE Lines 82-247 hardcoded catalog WITH:
try {
    # Initialize Configuration Bridge if not available
    if (-not $script:DotWinConfigurationBridge) {
        Write-DotWinLog "Initializing Configuration Bridge for system tools" -Level "Verbose" -ShowWithProgress
        
        $moduleConfigPath = Join-Path $PSScriptRoot "..\config"
        $userConfigPath = $null
        
        # Discover user configuration path
        try {
            $discoveredPaths = Get-DotWinUserConfigurationPath -ErrorAction SilentlyContinue
            if ($discoveredPaths -and $discoveredPaths.Count -gt 0) {
                $userConfigPath = $discoveredPaths[0].Path
                Write-DotWinLog "Discovered user configuration path: $userConfigPath" -Level "Information" -ShowWithProgress
            }
        } catch {
            Write-DotWinLog "Error discovering user configuration paths: $($_.Exception.Message)" -Level "Warning" -ShowWithProgress
        }
        
        # Create Configuration Bridge instance
        $script:DotWinConfigurationBridge = New-DotWinConfigurationBridge -ModuleConfigPath $moduleConfigPath -UserConfigPath $userConfigPath
    }

    # Get tools using Configuration Bridge
    Write-DotWinLog "Resolving system tools configuration for category: $ToolCategory" -Level "Verbose" -ShowWithProgress
    $systemToolsConfiguration = Get-DotWinSystemToolsConfiguration -Bridge $script:DotWinConfigurationBridge -Category $ToolCategory

    if ($systemToolsConfiguration -and $systemToolsConfiguration.Count -gt 0) {
        # Convert resolved configuration to the format expected by the existing logic
        $systemToolsCatalog = Convert-SystemToolsConfigurationToCatalog -SystemToolsConfiguration $systemToolsConfiguration -Category $ToolCategory
        Write-DotWinLog "Resolved $($systemToolsCatalog.Count) system tools from Configuration Bridge for category '$ToolCategory'" -Level "Information" -ShowWithProgress
    } else {
        Write-DotWinLog "No system tools configuration found for category '$ToolCategory'" -Level "Warning" -ShowWithProgress
        $systemToolsCatalog = @{}
    }
} catch {
    # Fallback to direct config file access
    Write-DotWinLog "Configuration Bridge failed, falling back to direct config file access: $($_.Exception.Message)" -Level "Warning" -ShowWithProgress

    $toolsConfigPath = Join-Path $script:DotWinConfigPath "Tools.ps1"
    if (Test-Path $toolsConfigPath) {
        . $toolsConfigPath
        
        if ($ToolCategory -eq 'All') {
            $systemToolsCatalog = Get-SystemToolsByCategory -Category 'All'
        } else {
            $systemToolsCatalog = Get-SystemToolsByCategory -Category $ToolCategory
        }
        Write-DotWinLog "Found $($systemToolsCatalog.Count) system tools in category '$ToolCategory' using direct config access" -Level "Information" -ShowWithProgress
    } else {
        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Unable to load system tools configuration for category: $ToolCategory"
        throw "Unable to load system tools configuration for category: $ToolCategory"
    }
}
```

#### **Phase 2: Add Missing Configuration Bridge Functions**

Add to [`functions/ConfigurationBridge.ps1`](../functions/ConfigurationBridge.ps1):

```powershell
function Get-DotWinSystemToolsConfiguration {
    <#
    .SYNOPSIS
        Resolves system tools configuration using the Configuration Bridge
    
    .DESCRIPTION
        Uses the DotWinConfigurationBridge to resolve system tools configurations with user overrides

    .PARAMETER Bridge
        The DotWinConfigurationBridge instance to use

    .PARAMETER Category
        The system tools category to resolve (e.g., "WindowsFeatures", "SystemServices", "All")

    .EXAMPLE
        $toolsConfig = Get-DotWinSystemToolsConfiguration -Bridge $bridge -Category "WindowsFeatures"
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

        return $Bridge.ResolveSystemToolsConfiguration($Category)
    } catch {
        Write-DotWinLog "Failed to resolve system tools configuration for category '$Category': $($_.Exception.Message)" -Level "Error"
        return @{}
    }
}

function Convert-SystemToolsConfigurationToCatalog {
    <#
    .SYNOPSIS
        Converts Configuration Bridge system tools configuration to catalog format
    
    .DESCRIPTION
        Internal helper function that converts the system tools configuration format returned
        by the Configuration Bridge into the catalog format expected by Install-SystemTools

    .PARAMETER SystemToolsConfiguration
        The system tools configuration returned by the Configuration Bridge

    .PARAMETER Category
        The category being processed for logging purposes

    .OUTPUTS
        Hashtable containing system tools in catalog format
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object]$SystemToolsConfiguration,

        [Parameter(Mandatory = $true)]
        [string]$Category
    )

    $catalog = @{}

    try {
        # Handle different possible return formats from Configuration Bridge
        if ($SystemToolsConfiguration -is [hashtable]) {
            # Check if it's category-based structure
            if ($Category -eq 'All') {
                # Return all tools from all categories
                foreach ($categoryName in $SystemToolsConfiguration.Keys) {
                    if ($SystemToolsConfiguration[$categoryName].Tools) {
                        $catalog[$categoryName] = $SystemToolsConfiguration[$categoryName].Tools
                    }
                }
            } elseif ($SystemToolsConfiguration.ContainsKey($Category)) {
                # Return tools for specific category
                if ($SystemToolsConfiguration[$Category].Tools) {
                    $catalog[$Category] = $SystemToolsConfiguration[$Category].Tools
                }
            }
        }

        Write-DotWinLog "Converted system tools configuration to catalog format for category '$Category'" -Level "Verbose" -ShowWithProgress
        return $catalog

    } catch {
        Write-DotWinLog "Error converting system tools configuration to catalog format: $($_.Exception.Message)" -Level "Error" -ShowWithProgress
        return @{}
    }
}
```

#### **Phase 3: Update Configuration Bridge Class**

Add to [`Classes.ps1`](../Classes.ps1) in the `DotWinConfigurationBridge` class:

```powershell
[hashtable] ResolveSystemToolsConfiguration([string]$Category) {
    $cacheKey = "SystemTools_${Category}"
    
    if ($this.CacheEnabled -and $this.ConfigurationCache.ContainsKey($cacheKey)) {
        return $this.ConfigurationCache[$cacheKey]
    }

    try {
        # Load module tools configuration
        $moduleToolsConfig = $this.LoadModuleConfiguration("Tools.ps1")
        
        # Load user tools overrides if available
        $userToolsConfig = $this.LoadUserConfiguration("Tools.ps1")
        
        # Get base tools configuration
        $baseConfig = @{}
        if ($moduleToolsConfig -and $moduleToolsConfig.DotWinSystemTools) {
            if ($Category -eq 'All') {
                $baseConfig = $moduleToolsConfig.DotWinSystemTools.Clone()
            } elseif ($moduleToolsConfig.DotWinSystemTools.ContainsKey($Category)) {
                $baseConfig[$Category] = $moduleToolsConfig.DotWinSystemTools[$Category].Clone()
            }
        }
        
        # Apply user overrides if available
        if ($userToolsConfig -and $userToolsConfig.DotWinSystemTools) {
            if ($Category -eq 'All') {
                foreach ($categoryName in $userToolsConfig.DotWinSystemTools.Keys) {
                    if ($baseConfig.ContainsKey($categoryName)) {
                        $baseConfig[$categoryName] = $this.MergeConfigurations($baseConfig[$categoryName], $userToolsConfig.DotWinSystemTools[$categoryName])
                    } else {
                        $baseConfig[$categoryName] = $userToolsConfig.DotWinSystemTools[$categoryName]
                    }
                }
            } elseif ($userToolsConfig.DotWinSystemTools.ContainsKey($Category)) {
                if ($baseConfig.ContainsKey($Category)) {
                    $baseConfig[$Category] = $this.MergeConfigurations($baseConfig[$Category], $userToolsConfig.DotWinSystemTools[$Category])
                } else {
                    $baseConfig[$Category] = $userToolsConfig.DotWinSystemTools[$Category]
                }
            }
        }
        
        # Cache the result
        if ($this.CacheEnabled) {
            $this.ConfigurationCache[$cacheKey] = $baseConfig
        }
        
        return $baseConfig
    } catch {
        throw "Failed to resolve system tools configuration for '$Category': $($_.Exception.Message)"
    }
}
```

---

## 3. WSL Management Integration Opportunity

### **Current State**

- **Rich Configuration Available**: [`config/WSL.ps1`](../config/WSL.ps1) contains detailed WSL configurations for Ubuntu, Debian, Kali, and Alpine
- **No Management Functions**: No existing functions leverage this configuration
- **Opportunity**: Add WSL management as a new DotWin capability

### **Recommended Implementation**

```powershell
function Install-WSLDistributions {
    <#
    .SYNOPSIS
        Installs and configures WSL distributions using Configuration Bridge
    
    .DESCRIPTION
        Installs WSL distributions with declarative configuration management
    
    .PARAMETER Configuration
        The WSL configuration name to apply (UbuntuDev, DebianServer, KaliSecurity, AlpineLite)
    
    .PARAMETER UserConfigPath
        Optional path to user configuration directory for overrides
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('UbuntuDev', 'DebianServer', 'KaliSecurity', 'AlpineLite')]
        [string]$Configuration,
        
        [Parameter()]
        [string]$UserConfigPath
    )
    
    # Initialize Configuration Bridge
    $moduleConfigPath = Join-Path $PSScriptRoot "..\config"
    if (-not $UserConfigPath) {
        $userConfigs = Get-DotWinUserConfigurationPath -ErrorAction SilentlyContinue
        if ($userConfigs) { $UserConfigPath = $userConfigs[0].Path }
    }
    
    $configBridge = New-DotWinConfigurationBridge -ModuleConfigPath $moduleConfigPath -UserConfigPath $UserConfigPath
    
    # Resolve WSL configuration using Configuration Bridge
    $wslConfig = Get-DotWinWSLConfiguration -Bridge $configBridge -Configuration $Configuration
    
    # Implementation would follow the same pattern as other functions
    # ... install and configure WSL distribution based on resolved config
}
```

---

## Module Integration Requirements

### **Function Exports & Module Manifest Updates**

#### **1. Update Module Manifest (DotWin.psd1)**

Add new Configuration Bridge functions to the exported functions list:

```powershell
# Add to FunctionsToExport array:
'Get-DotWinProfileConfiguration',
'Get-DotWinSystemToolsConfiguration',
'Convert-SystemToolsConfigurationToCatalog'

# If adding WSL management:
'Install-WSLDistributions',
'Get-DotWinWSLConfiguration'
```

#### **2. Update Module Script (DotWin.psm1)**

Ensure new functions are properly exported:

```powershell
# Add explicit exports for new Configuration Bridge functions
Export-ModuleMember -Function 'Get-DotWinProfileConfiguration'
Export-ModuleMember -Function 'Get-DotWinSystemToolsConfiguration'
Export-ModuleMember -Function 'Convert-SystemToolsConfigurationToCatalog'

# WSL functions if implemented
Export-ModuleMember -Function 'Install-WSLDistributions'
Export-ModuleMember -Function 'Get-DotWinWSLConfiguration'

# Error handling and validation functions
Export-ModuleMember -Function 'Test-ProfileConfiguration'
Export-ModuleMember -Function 'Test-SystemToolsConfiguration'
Export-ModuleMember -Function 'Test-ConfigurationBridgeHealth'
Export-ModuleMember -Function 'Backup-ConfigurationState'
Export-ModuleMember -Function 'Restore-ConfigurationState'
```

### **Class Definitions & Structure**

#### **3. Classes.ps1 Updates**

All Configuration Bridge class methods must be added to [`Classes.ps1`](../Classes.ps1):

```powershell
# Add to DotWinConfigurationBridge class:

[hashtable] ResolveProfileConfiguration([string]$ProfileType, [bool]$IncludeModules, [bool]$IncludeAliases, [bool]$IncludeFunctions, [bool]$IncludePrompt) {
    # Implementation as detailed in Phase 4 above
}

[hashtable] ResolveSystemToolsConfiguration([string]$Category) {
    # Implementation as detailed in Phase 3 above
}

# If implementing WSL management:
[hashtable] ResolveWSLConfiguration([string]$Configuration) {
    # WSL-specific resolution logic
}
```

#### **4. Helper Classes (if needed)**

Define any new supporting classes in [`Classes.ps1`](../Classes.ps1):

```powershell
# Configuration validation result class
class DotWinConfigurationValidationResult {
    [bool] $IsValid
    [string[]] $Errors
    [string[]] $Warnings

    DotWinConfigurationValidationResult() {
        $this.IsValid = $true
        $this.Errors = @()
        $this.Warnings = @()
    }
}

# Configuration backup metadata class
class DotWinConfigurationBackup {
    [string] $Timestamp
    [string] $Function
    [hashtable] $Configuration
    [string] $ModuleVersion
    [string] $ComputerName
    [string] $FilePath
}
```

### **File Organization Requirements**

| Component | File Location | Purpose |
|-----------|---------------|---------|
| **New Functions** | [`functions/ConfigurationBridge.ps1`](../functions/ConfigurationBridge.ps1) | Configuration Bridge wrapper functions |
| **Class Methods** | [`Classes.ps1`](../Classes.ps1) | DotWinConfigurationBridge class extensions |
| **Helper Classes** | [`Classes.ps1`](../Classes.ps1) | Supporting validation and backup classes |
| **Function Exports** | [`DotWin.psm1`](../DotWin.psm1) | Module script with explicit exports |
| **Manifest Updates** | [`DotWin.psd1`](../DotWin.psd1) | Module manifest function declarations |
| **Integration Code** | Existing function files | Modified [`Set-PowershellProfile.ps1`](../functions/Set-PowershellProfile.ps1), [`Install-SystemTools.ps1`](../functions/Install-SystemTools.ps1) |

---

## Expected Benefits

### **Immediate Benefits**

- **🎯 Complete Configuration Bridge Coverage**: All major functions use declarative configuration
- **🔧 User Customization**: Users can override any setting without modifying module code
- **📦 Reproducible Environments**: Complete system configurations can be exported/imported
- **🏗️ True "Terraform for Windows"**: Infrastructure-as-code approach for Windows configuration

### **Long-term Benefits**

- **🔄 Version Control Friendly**: All configurations in trackable files
- **🌐 Team Sharing**: Share configuration setups across teams
- **🎨 Modular Design**: Swap entire configuration sets without code changes
- **⚡ Performance**: Configuration caching reduces repeated file I/O

---

## Error Handling & Recovery Strategies

### **1. Configuration Bridge Initialization Failures**

#### **Scenario**: Configuration Bridge Cannot Be Created

```powershell
# Enhanced initialization with multiple fallback levels
function Initialize-ConfigurationBridgeWithFallback {
    [CmdletBinding()]
    param(
        [string]$ModuleConfigPath,
        [string]$UserConfigPath,
        [string]$FunctionName
    )

    $initErrors = @()

    # Attempt 1: Full Configuration Bridge
    try {
        $configBridge = New-DotWinConfigurationBridge -ModuleConfigPath $ModuleConfigPath -UserConfigPath $UserConfigPath
        Write-DotWinLog "Configuration Bridge initialized successfully for $FunctionName" -Level "Information"
        return @{ Bridge = $configBridge; FallbackLevel = "None"; Errors = @() }
    } catch {
        $initErrors += "Full bridge init failed: $($_.Exception.Message)"
        Write-DotWinLog "Failed to initialize full Configuration Bridge: $($_.Exception.Message)" -Level "Warning"
    }

    # Attempt 2: Module-only Configuration Bridge (no user overrides)
    try {
        $configBridge = New-DotWinConfigurationBridge -ModuleConfigPath $ModuleConfigPath
        Write-DotWinLog "Configuration Bridge initialized without user overrides for $FunctionName" -Level "Warning"
        return @{ Bridge = $configBridge; FallbackLevel = "NoUserOverrides"; Errors = $initErrors }
    } catch {
        $initErrors += "Module-only bridge init failed: $($_.Exception.Message)"
        Write-DotWinLog "Failed to initialize module-only Configuration Bridge: $($_.Exception.Message)" -Level "Warning"
    }

    # Attempt 3: Direct config file access verification
    $moduleConfigFile = switch ($FunctionName) {
        "Set-PowershellProfile" { "Profile.ps1" }
        "Install-SystemTools" { "Tools.ps1" }
        default { $null }
    }

    if ($moduleConfigFile) {
        $configFilePath = Join-Path $ModuleConfigPath $moduleConfigFile
        if (Test-Path $configFilePath) {
            Write-DotWinLog "Configuration Bridge unavailable, but config file exists for direct access: $configFilePath" -Level "Information"
            return @{ Bridge = $null; FallbackLevel = "DirectFileAccess"; Errors = $initErrors; ConfigFile = $configFilePath }
        } else {
            $initErrors += "Config file not found: $configFilePath"
        }
    }

    # Complete failure
    $initErrors += "All configuration methods failed"
    Write-DotWinLog "CRITICAL: All configuration initialization methods failed for $FunctionName" -Level "Error"
    return @{ Bridge = $null; FallbackLevel = "HardcodedOnly"; Errors = $initErrors }
}
```

### **2. Configuration Resolution Failures**

#### **Enhanced Resolution with Validation and Recovery**

```powershell
function Resolve-ConfigurationWithValidation {
    [CmdletBinding()]
    param(
        [object]$ConfigBridge,
        [string]$ConfigType,
        [hashtable]$Parameters,
        [scriptblock]$ValidationScript,
        [scriptblock]$FallbackScript
    )

    $resolutionResult = @{
        Configuration = @{}
        Source = "Unknown"
        Warnings = @()
        Errors = @()
        ValidationPassed = $false
    }

    # Primary: Configuration Bridge resolution
    if ($ConfigBridge) {
        try {
            $config = switch ($ConfigType) {
                "Profile" {
                    $ConfigBridge.ResolveProfileConfiguration(
                        $Parameters.ProfileType,
                        $Parameters.IncludeModules,
                        $Parameters.IncludeAliases,
                        $Parameters.IncludeFunctions,
                        $Parameters.IncludePrompt
                    )
                }
                "SystemTools" {
                    $ConfigBridge.ResolveSystemToolsConfiguration($Parameters.Category)
                }
                default { throw "Unknown configuration type: $ConfigType" }
            }

            if ($config -and $config.Count -gt 0) {
                # Validate resolved configuration
                if ($ValidationScript) {
                    $validationResult = & $ValidationScript $config
                    if ($validationResult.IsValid) {
                        $resolutionResult.Configuration = $config
                        $resolutionResult.Source = "ConfigurationBridge"
                        $resolutionResult.ValidationPassed = $true
                        $resolutionResult.Warnings = $validationResult.Warnings
                        return $resolutionResult
                    } else {
                        $resolutionResult.Errors += "Configuration validation failed: $($validationResult.Errors -join '; ')"
                        $resolutionResult.Warnings += "Configuration Bridge returned invalid config, attempting fallback"
                    }
                } else {
                    # No validation required
                    $resolutionResult.Configuration = $config
                    $resolutionResult.Source = "ConfigurationBridge"
                    $resolutionResult.ValidationPassed = $true
                    return $resolutionResult
                }
            } else {
                $resolutionResult.Warnings += "Configuration Bridge returned empty configuration"
            }
        } catch {
            $resolutionResult.Errors += "Configuration Bridge resolution failed: $($_.Exception.Message)"
        }
    }

    # Fallback: Execute fallback script (legacy methods)
    if ($FallbackScript) {
        try {
            Write-DotWinLog "Attempting fallback configuration resolution for $ConfigType" -Level "Warning"
            $fallbackConfig = & $FallbackScript $Parameters

            if ($fallbackConfig) {
                # Validate fallback configuration
                if ($ValidationScript) {
                    $validationResult = & $ValidationScript $fallbackConfig
                    if ($validationResult.IsValid) {
                        $resolutionResult.Configuration = $fallbackConfig
                        $resolutionResult.Source = "FallbackMethod"
                        $resolutionResult.ValidationPassed = $true
                        $resolutionResult.Warnings += $validationResult.Warnings
                        $resolutionResult.Warnings += "Using fallback configuration method"
                        return $resolutionResult
                    } else {
                        $resolutionResult.Errors += "Fallback configuration validation failed: $($validationResult.Errors -join '; ')"
                    }
                } else {
                    $resolutionResult.Configuration = $fallbackConfig
                    $resolutionResult.Source = "FallbackMethod"
                    $resolutionResult.ValidationPassed = $true
                    $resolutionResult.Warnings += "Using fallback configuration method"
                    return $resolutionResult
                }
            } else {
                $resolutionResult.Errors += "Fallback method returned empty configuration"
            }
        } catch {
            $resolutionResult.Errors += "Fallback configuration failed: $($_.Exception.Message)"
        }
    }

    # Complete failure
    $resolutionResult.Errors += "All configuration resolution methods failed"
    return $resolutionResult
}
```

### **3. Configuration Validation Strategies**

#### **Profile Configuration Validator**

```powershell
function Test-ProfileConfiguration {
    [CmdletBinding()]
    param([hashtable]$Configuration)

    $result = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }

    # Required structure validation
    $requiredKeys = @('Name', 'Description')
    foreach ($key in $requiredKeys) {
        if (-not $Configuration.ContainsKey($key) -or [string]::IsNullOrWhiteSpace($Configuration[$key])) {
            $result.Errors += "Missing or empty required key: $key"
            $result.IsValid = $false
        }
    }

    # Modules validation
    if ($Configuration.ContainsKey('Modules') -and $Configuration.Modules) {
        foreach ($module in $Configuration.Modules) {
            if (-not $module.Name) {
                $result.Errors += "Module configuration missing Name property"
                $result.IsValid = $false
            }
            if ($module.MinimumVersion -and -not ($module.MinimumVersion -as [Version])) {
                $result.Warnings += "Invalid version format for module $($module.Name): $($module.MinimumVersion)"
            }
        }
    }

    # Functions validation
    if ($Configuration.ContainsKey('Functions') -and $Configuration.Functions) {
        foreach ($func in $Configuration.Functions) {
            if ([string]::IsNullOrWhiteSpace($func.Name)) {
                $result.Errors += "Function configuration missing Name property"
                $result.IsValid = $false
            }
            if ([string]::IsNullOrWhiteSpace($func.ScriptBlock)) {
                $result.Errors += "Function $($func.Name) missing ScriptBlock"
                $result.IsValid = $false
            }
        }
    }

    # Aliases validation
    if ($Configuration.ContainsKey('Aliases') -and $Configuration.Aliases) {
        foreach ($alias in $Configuration.Aliases) {
            if ([string]::IsNullOrWhiteSpace($alias.Name) -or [string]::IsNullOrWhiteSpace($alias.Value)) {
                $result.Errors += "Alias configuration missing Name or Value property"
                $result.IsValid = $false
            }
        }
    }

    return $result
}
```

#### **System Tools Configuration Validator**

```powershell
function Test-SystemToolsConfiguration {
    [CmdletBinding()]
    param([hashtable]$Configuration)

    $result = @{
        IsValid = $true
        Errors = @()
        Warnings = @()
    }

    # Validate each category
    foreach ($categoryName in $Configuration.Keys) {
        $category = $Configuration[$categoryName]

        # Category structure validation
        if (-not $category.ContainsKey('Tools')) {
            $result.Errors += "Category $categoryName missing Tools collection"
            $result.IsValid = $false
            continue
        }

        # Tools validation
        foreach ($toolName in $category.Tools.Keys) {
            $tool = $category.Tools[$toolName]

            # Required tool properties
            $requiredToolProps = @('Name', 'Type')
            foreach ($prop in $requiredToolProps) {
                if (-not $tool.ContainsKey($prop) -or [string]::IsNullOrWhiteSpace($tool[$prop])) {
                    $result.Errors += "Tool $toolName in category $categoryName missing required property: $prop"
                    $result.IsValid = $false
                }
            }

            # Type-specific validation
            switch ($tool.Type) {
                'WindowsFeature' {
                    if (-not $tool.FeatureName) {
                        $result.Errors += "WindowsFeature tool $toolName missing FeatureName"
                        $result.IsValid = $false
                    }
                }
                'Service' {
                    if (-not $tool.ServiceName) {
                        $result.Errors += "Service tool $toolName missing ServiceName"
                        $result.IsValid = $false
                    }
                }
                'Registry' {
                    if (-not $tool.Path -or -not $tool.Name) {
                        $result.Errors += "Registry tool $toolName missing Path or Name"
                        $result.IsValid = $false
                    }
                }
                default {
                    $result.Warnings += "Unknown tool type '$($tool.Type)' for tool $toolName"
                }
            }
        }
    }

    return $result
}
```

### **4. User Experience & Communication**

#### **Enhanced Error Reporting**

```powershell
function Write-ConfigurationError {
    [CmdletBinding()]
    param(
        [string]$FunctionName,
        [array]$Errors,
        [array]$Warnings,
        [string]$FallbackSource,
        [switch]$ShowRecoveryOptions
    )

    # Display error summary
    if ($Errors -and $Errors.Count -gt 0) {
        Write-Host "`n❌ Configuration Issues Detected in $FunctionName" -ForegroundColor Red
        Write-Host "─────────────────────────────────────────────────" -ForegroundColor Red

        foreach ($error in $Errors) {
            Write-Host "  • $error" -ForegroundColor Red
        }
    }

    # Display warnings
    if ($Warnings -and $Warnings.Count -gt 0) {
        Write-Host "`n⚠️  Configuration Warnings in $FunctionName" -ForegroundColor Yellow
        Write-Host "─────────────────────────────────────────────────" -ForegroundColor Yellow

        foreach ($warning in $Warnings) {
            Write-Host "  • $warning" -ForegroundColor Yellow
        }
    }

    # Show current status
    if ($FallbackSource) {
        Write-Host "`n✅ Current Status: Using $FallbackSource" -ForegroundColor Green
    }

    # Show recovery options
    if ($ShowRecoveryOptions) {
        Write-Host "`n🔧 Recovery Options:" -ForegroundColor Cyan
        Write-Host "─────────────────────────────────────────────────" -ForegroundColor Cyan
        Write-Host "  1. Check your user configuration files for syntax errors" -ForegroundColor Cyan
        Write-Host "  2. Verify file permissions in configuration directories" -ForegroundColor Cyan
        Write-Host "  3. Run 'Test-DotWinConfiguration' to validate your setup" -ForegroundColor Cyan
        Write-Host "  4. Use 'Repair-DotWinConfiguration' to reset to defaults" -ForegroundColor Cyan
        Write-Host "  5. Check the DotWin logs: Get-DotWinLog -Recent" -ForegroundColor Cyan
    }
}
```

### **5. Rollback & Recovery Mechanisms**

#### **Configuration Backup & Restore**

```powershell
function Backup-ConfigurationState {
    [CmdletBinding()]
    param(
        [string]$FunctionName,
        [hashtable]$CurrentConfiguration,
        [string]$BackupLocation
    )

    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = Join-Path $BackupLocation "DotWin_${FunctionName}_Backup_${timestamp}.json"

        $backupData = @{
            Timestamp = $timestamp
            Function = $FunctionName
            Configuration = $CurrentConfiguration
            ModuleVersion = (Get-Module DotWin).Version.ToString()
            ComputerName = $env:COMPUTERNAME
        }

        $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupFile -Encoding UTF8
        Write-DotWinLog "Configuration backed up to: $backupFile" -Level "Information"

        return $backupFile
    } catch {
        Write-DotWinLog "Failed to backup configuration: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

function Restore-ConfigurationState {
    [CmdletBinding()]
    param(
        [string]$BackupFile,
        [switch]$WhatIf
    )

    try {
        if (-not (Test-Path $BackupFile)) {
            throw "Backup file not found: $BackupFile"
        }

        $backupData = Get-Content $BackupFile | ConvertFrom-Json

        if ($WhatIf) {
            Write-Host "Would restore configuration for $($backupData.Function) from $($backupData.Timestamp)" -ForegroundColor Yellow
            return
        }

        Write-DotWinLog "Restoring configuration for $($backupData.Function) from backup: $BackupFile" -Level "Information"

        # Implementation would restore the specific configuration
        # This is function-specific logic that would be implemented per function

        Write-DotWinLog "Configuration restored successfully for $($backupData.Function)" -Level "Information"

    } catch {
        Write-DotWinLog "Failed to restore configuration: $($_.Exception.Message)" -Level "Error"
        throw
    }
}
```

### **6. Integration Testing & Validation**

#### **Pre-Integration Health Check**

```powershell
function Test-ConfigurationBridgeHealth {
    [CmdletBinding()]
    param()

    $healthReport = @{
        OverallStatus = "Unknown"
        ModuleConfigHealth = @{}
        UserConfigHealth = @{}
        BridgeHealth = @{}
        Recommendations = @()
    }

    # Test module configuration files
    $configFiles = @("Profile.ps1", "Tools.ps1", "Terminal.ps1", "Packages.ps1", "WSL.ps1")
    $moduleConfigPath = Join-Path $PSScriptRoot "..\config"

    foreach ($configFile in $configFiles) {
        $filePath = Join-Path $moduleConfigPath $configFile
        $healthReport.ModuleConfigHealth[$configFile] = Test-ConfigurationFile -Path $filePath
    }

    # Test user configuration discovery
    try {
        $userPaths = Get-DotWinUserConfigurationPath -ErrorAction SilentlyContinue
        $healthReport.UserConfigHealth["Discovery"] = if ($userPaths) { "Success" } else { "NoUserConfigs" }

        foreach ($userPath in $userPaths) {
            $healthReport.UserConfigHealth[$userPath.Path] = Test-UserConfigurationDirectory -Path $userPath.Path
        }
    } catch {
        $healthReport.UserConfigHealth["Discovery"] = "Failed: $($_.Exception.Message)"
    }

    # Test Configuration Bridge initialization
    try {
        $testBridge = New-DotWinConfigurationBridge -ModuleConfigPath $moduleConfigPath
        $healthReport.BridgeHealth["Initialization"] = "Success"

        # Test basic resolution
        try {
            $testResolution = $testBridge.ResolveTerminalConfiguration("Default")
            $healthReport.BridgeHealth["Resolution"] = if ($testResolution) { "Success" } else { "EmptyResult" }
        } catch {
            $healthReport.BridgeHealth["Resolution"] = "Failed: $($_.Exception.Message)"
        }
    } catch {
        $healthReport.BridgeHealth["Initialization"] = "Failed: $($_.Exception.Message)"
    }

    # Determine overall status and recommendations
    $criticalIssues = 0
    $warnings = 0

    foreach ($fileHealth in $healthReport.ModuleConfigHealth.Values) {
        if ($fileHealth.Status -eq "Failed") { $criticalIssues++ }
        elseif ($fileHealth.Status -eq "Warning") { $warnings++ }
    }

    if ($healthReport.BridgeHealth["Initialization"] -like "Failed*") { $criticalIssues++ }

    $healthReport.OverallStatus = if ($criticalIssues -gt 0) { "Critical" }
                                elseif ($warnings -gt 0) { "Warning" }
                                else { "Healthy" }

    return $healthReport
}
```

## Rollback & Recovery Procedures

### **Pre-Integration Backup Strategy**

#### **1. Automated Backup Before Integration**

```powershell
function Start-IntegrationBackup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Set-PowershellProfile', 'Install-SystemTools', 'All')]
        [string]$Function
    )

    $backupTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupBase = Join-Path $env:TEMP "DotWin_Integration_Backup_$backupTimestamp"
    New-Item -Path $backupBase -ItemType Directory -Force | Out-Null

    $backupManifest = @{
        Timestamp = $backupTimestamp
        Functions = @()
        Files = @{}
        ModuleVersion = (Get-Module DotWin).Version.ToString()
        BackupLocation = $backupBase
    }

    # Backup function files
    $functionsToBackup = switch ($Function) {
        'Set-PowershellProfile' { @('Set-PowershellProfile.ps1') }
        'Install-SystemTools' { @('Install-SystemTools.ps1') }
        'All' { @('Set-PowershellProfile.ps1', 'Install-SystemTools.ps1') }
    }

    foreach ($functionFile in $functionsToBackup) {
        $sourcePath = Join-Path $PSScriptRoot "..\functions\$functionFile"
        $backupPath = Join-Path $backupBase "functions_$functionFile"

        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath $backupPath -Force
            $backupManifest.Files[$functionFile] = $backupPath
            $backupManifest.Functions += $functionFile.Replace('.ps1', '')
        }
    }

    # Backup current module files that will be modified
    $moduleFilesToBackup = @(
        @{ Source = 'DotWin.psm1'; Target = 'DotWin.psm1' },
        @{ Source = 'DotWin.psd1'; Target = 'DotWin.psd1' },
        @{ Source = 'Classes.ps1'; Target = 'Classes.ps1' },
        @{ Source = 'functions\ConfigurationBridge.ps1'; Target = 'ConfigurationBridge.ps1' }
    )

    foreach ($moduleFile in $moduleFilesToBackup) {
        $sourcePath = Join-Path (Split-Path $PSScriptRoot -Parent) $moduleFile.Source
        $backupPath = Join-Path $backupBase "module_$($moduleFile.Target)"

        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath $backupPath -Force
            $backupManifest.Files[$moduleFile.Source] = $backupPath
        }
    }

    # Save backup manifest
    $manifestPath = Join-Path $backupBase "backup_manifest.json"
    $backupManifest | ConvertTo-Json -Depth 5 | Out-File $manifestPath -Encoding UTF8

    Write-Host "`n✅ Integration backup completed successfully" -ForegroundColor Green
    Write-Host "📁 Backup location: $backupBase" -ForegroundColor Cyan
    Write-Host "📋 Backed up functions: $($backupManifest.Functions -join ', ')" -ForegroundColor Cyan
    Write-Host "🕒 Backup timestamp: $backupTimestamp" -ForegroundColor Cyan

    return @{
        BackupLocation = $backupBase
        ManifestPath = $manifestPath
        Timestamp = $backupTimestamp
        Functions = $backupManifest.Functions
    }
}
```

### **Rollback Detection & Triggers**

#### **2. Integration Health Monitor**

```powershell
function Test-IntegrationHealth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Set-PowershellProfile', 'Install-SystemTools', 'All')]
        [string]$Function
    )

    $healthReport = @{
        Function = $Function
        Status = "Unknown"
        Issues = @()
        RollbackRecommended = $false
        TestResults = @{}
    }

    $functionsToTest = switch ($Function) {
        'Set-PowershellProfile' { @('Set-PowershellProfile') }
        'Install-SystemTools' { @('Install-SystemTools') }
        'All' { @('Set-PowershellProfile', 'Install-SystemTools') }
    }

    foreach ($functionName in $functionsToTest) {
        Write-Host "🔍 Testing $functionName integration..." -ForegroundColor Yellow

        try {
            # Test basic function availability
            $command = Get-Command $functionName -ErrorAction Stop
            $healthReport.TestResults["$functionName.CommandAvailable"] = "✅ Pass"

            # Test Configuration Bridge integration
            switch ($functionName) {
                'Set-PowershellProfile' {
                    # Test profile configuration resolution
                    try {
                        $testConfig = Get-DotWinProfileConfiguration -ProfileType "Developer" -ErrorAction Stop
                        $healthReport.TestResults["$functionName.ConfigurationBridge"] = "✅ Pass"
                    } catch {
                        $healthReport.TestResults["$functionName.ConfigurationBridge"] = "❌ Fail: $($_.Exception.Message)"
                        $healthReport.Issues += "Profile configuration resolution failed"
                        $healthReport.RollbackRecommended = $true
                    }
                }
                'Install-SystemTools' {
                    # Test system tools configuration resolution
                    try {
                        $testConfig = Get-DotWinSystemToolsConfiguration -Category "WindowsFeatures" -ErrorAction Stop
                        $healthReport.TestResults["$functionName.ConfigurationBridge"] = "✅ Pass"
                    } catch {
                        $healthReport.TestResults["$functionName.ConfigurationBridge"] = "❌ Fail: $($_.Exception.Message)"
                        $healthReport.Issues += "System tools configuration resolution failed"
                        $healthReport.RollbackRecommended = $true
                    }
                }
            }

            # Test fallback mechanisms
            try {
                # Temporarily disable Configuration Bridge to test fallback
                $originalBridge = $script:DotWinConfigurationBridge
                $script:DotWinConfigurationBridge = $null

                # Attempt function execution with fallback
                $testResult = switch ($functionName) {
                    'Set-PowershellProfile' {
                        & $functionName -ProfileType "Developer" -WhatIf -ErrorAction Stop
                    }
                    'Install-SystemTools' {
                        & $functionName -ToolCategory "WindowsFeatures" -WhatIf -ErrorAction Stop
                    }
                }

                $healthReport.TestResults["$functionName.FallbackMechanism"] = "✅ Pass"

                # Restore Configuration Bridge
                $script:DotWinConfigurationBridge = $originalBridge
            } catch {
                $healthReport.TestResults["$functionName.FallbackMechanism"] = "❌ Fail: $($_.Exception.Message)"
                $healthReport.Issues += "Fallback mechanism failed for $functionName"
                $healthReport.RollbackRecommended = $true

                # Restore Configuration Bridge
                $script:DotWinConfigurationBridge = $originalBridge
            }

        } catch {
            $healthReport.TestResults["$functionName.CommandAvailable"] = "❌ Fail: $($_.Exception.Message)"
            $healthReport.Issues += "Function $functionName not available or corrupted"
            $healthReport.RollbackRecommended = $true
        }
    }

    # Determine overall status
    $failedTests = $healthReport.TestResults.Values | Where-Object { $_ -like "❌*" }
    $healthReport.Status = if ($failedTests.Count -eq 0) { "✅ Healthy" }
                          elseif ($healthReport.RollbackRecommended) { "❌ Critical - Rollback Required" }
                          else { "⚠️ Warning - Monitor" }

    return $healthReport
}
```

### **Step-by-Step Rollback Procedures**

#### **3. Automated Rollback Execution**

```powershell
function Start-IntegrationRollback {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupLocation,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$VerifyAfterRollback = $true
    )

    Write-Host "`n🔄 Starting DotWin Integration Rollback..." -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Yellow

    # Load backup manifest
    $manifestPath = Join-Path $BackupLocation "backup_manifest.json"
    if (-not (Test-Path $manifestPath)) {
        throw "Backup manifest not found: $manifestPath"
    }

    $manifest = Get-Content $manifestPath | ConvertFrom-Json
    Write-Host "📋 Backup manifest loaded: $($manifest.Timestamp)" -ForegroundColor Cyan
    Write-Host "🔧 Functions to rollback: $($manifest.Functions -join ', ')" -ForegroundColor Cyan

    if (-not $Force -and -not $PSCmdlet.ShouldProcess("DotWin Module", "Rollback Integration Changes")) {
        Write-Host "❌ Rollback cancelled by user" -ForegroundColor Red
        return
    }

    $rollbackErrors = @()

    try {
        # Step 1: Restore function files
        Write-Host "`n📂 Step 1: Restoring function files..." -ForegroundColor Blue
        foreach ($functionFile in $manifest.Files.Keys | Where-Object { $_ -like "*.ps1" }) {
            $backupPath = $manifest.Files[$functionFile]
            $targetPath = Join-Path $PSScriptRoot "..\functions\$functionFile"

            try {
                if (Test-Path $backupPath) {
                    Copy-Item $backupPath $targetPath -Force
                    Write-Host "  ✅ Restored: $functionFile" -ForegroundColor Green
                } else {
                    $rollbackErrors += "Backup file not found: $backupPath"
                    Write-Host "  ❌ Missing backup: $functionFile" -ForegroundColor Red
                }
            } catch {
                $rollbackErrors += "Failed to restore $functionFile`: $($_.Exception.Message)"
                Write-Host "  ❌ Error restoring: $functionFile" -ForegroundColor Red
            }
        }

        # Step 2: Restore module files
        Write-Host "`n📦 Step 2: Restoring module files..." -ForegroundColor Blue
        $moduleFiles = @(
            @{ Backup = 'module_DotWin.psm1'; Target = 'DotWin.psm1' },
            @{ Backup = 'module_DotWin.psd1'; Target = 'DotWin.psd1' },
            @{ Backup = 'module_Classes.ps1'; Target = 'Classes.ps1' },
            @{ Backup = 'module_ConfigurationBridge.ps1'; Target = 'functions\ConfigurationBridge.ps1' }
        )

        foreach ($moduleFile in $moduleFiles) {
            $backupPath = Join-Path $BackupLocation $moduleFile.Backup
            $targetPath = Join-Path (Split-Path $PSScriptRoot -Parent) $moduleFile.Target

            try {
                if (Test-Path $backupPath) {
                    Copy-Item $backupPath $targetPath -Force
                    Write-Host "  ✅ Restored: $($moduleFile.Target)" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠️  Backup not found (possibly not modified): $($moduleFile.Target)" -ForegroundColor Yellow
                }
            } catch {
                $rollbackErrors += "Failed to restore $($moduleFile.Target): $($_.Exception.Message)"
                Write-Host "  ❌ Error restoring: $($moduleFile.Target)" -ForegroundColor Red
            }
        }

        # Step 3: Clear Configuration Bridge cache
        Write-Host "`n🧹 Step 3: Clearing Configuration Bridge cache..." -ForegroundColor Blue
        try {
            if ($script:DotWinConfigurationBridge) {
                $script:DotWinConfigurationBridge.ClearCache()
                Write-Host "  ✅ Configuration Bridge cache cleared" -ForegroundColor Green
            }
            $script:DotWinConfigurationBridge = $null
            Write-Host "  ✅ Configuration Bridge instance reset" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  Could not clear Configuration Bridge cache" -ForegroundColor Yellow
        }

        # Step 4: Module reload recommendation
        Write-Host "`n🔄 Step 4: Module reload recommendation..." -ForegroundColor Blue
        Write-Host "  ⚠️  Please restart PowerShell or reimport DotWin module to complete rollback" -ForegroundColor Yellow
        Write-Host "     Import-Module DotWin -Force" -ForegroundColor Cyan

        # Step 5: Verify rollback if requested
        if ($VerifyAfterRollback) {
            Write-Host "`n✅ Step 5: Verifying rollback..." -ForegroundColor Blue
            try {
                foreach ($functionName in $manifest.Functions) {
                    $command = Get-Command $functionName -ErrorAction SilentlyContinue
                    if ($command) {
                        Write-Host "  ✅ Function available: $functionName" -ForegroundColor Green
                    } else {
                        Write-Host "  ❌ Function not available: $functionName" -ForegroundColor Red
                        $rollbackErrors += "Function $functionName not available after rollback"
                    }
                }
            } catch {
                Write-Host "  ⚠️  Could not verify all functions after rollback" -ForegroundColor Yellow
            }
        }

        # Display rollback summary
        Write-Host "`n📊 Rollback Summary:" -ForegroundColor Cyan
        Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Cyan

        if ($rollbackErrors.Count -eq 0) {
            Write-Host "✅ Rollback completed successfully" -ForegroundColor Green
            Write-Host "🕒 Backup timestamp: $($manifest.Timestamp)" -ForegroundColor Green
            Write-Host "📁 Backup preserved at: $BackupLocation" -ForegroundColor Green
        } else {
            Write-Host "⚠️  Rollback completed with $($rollbackErrors.Count) errors:" -ForegroundColor Yellow
            foreach ($error in $rollbackErrors) {
                Write-Host "  • $error" -ForegroundColor Red
            }
            Write-Host "`n🔧 Manual intervention may be required" -ForegroundColor Yellow
        }

        return @{
            Success = ($rollbackErrors.Count -eq 0)
            Errors = $rollbackErrors
            BackupLocation = $BackupLocation
            Timestamp = $manifest.Timestamp
        }

    } catch {
        Write-Host "`n❌ CRITICAL: Rollback failed with exception:" -ForegroundColor Red
        Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`n🆘 Emergency Recovery Required:" -ForegroundColor Red
        Write-Host "   1. Manually restore files from: $BackupLocation" -ForegroundColor Red
        Write-Host "   2. Restart PowerShell session" -ForegroundColor Red
        Write-Host "   3. Verify DotWin module functionality" -ForegroundColor Red
        throw
    }
}
```

### **Emergency Recovery Procedures**

#### **4. Manual Recovery Guide**

```powershell
function Show-EmergencyRecoveryGuide {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BackupLocation
    )

    Write-Host "`n🆘 DotWin Emergency Recovery Guide" -ForegroundColor Red
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Red

    Write-Host "`n📋 If automated rollback fails, follow these steps:" -ForegroundColor Yellow

    Write-Host "`n1️⃣  IMMEDIATE ACTIONS:" -ForegroundColor Cyan
    Write-Host "   • Close all PowerShell sessions using DotWin" -ForegroundColor White
    Write-Host "   • Do not attempt to use DotWin functions" -ForegroundColor White
    Write-Host "   • Locate your backup files" -ForegroundColor White

    if ($BackupLocation) {
        Write-Host "`n📁 Your backup location: $BackupLocation" -ForegroundColor Green
    }

    Write-Host "`n2️⃣  MANUAL FILE RESTORATION:" -ForegroundColor Cyan
    Write-Host "   • Navigate to your DotWin module directory" -ForegroundColor White
    Write-Host "   • Copy the following files from backup:" -ForegroundColor White
    Write-Host "     - functions\Set-PowershellProfile.ps1" -ForegroundColor Gray
    Write-Host "     - functions\Install-SystemTools.ps1" -ForegroundColor Gray
    Write-Host "     - functions\ConfigurationBridge.ps1" -ForegroundColor Gray
    Write-Host "     - Classes.ps1" -ForegroundColor Gray
    Write-Host "     - DotWin.psm1" -ForegroundColor Gray
    Write-Host "     - DotWin.psd1" -ForegroundColor Gray

    Write-Host "`n3️⃣  MODULE RECOVERY:" -ForegroundColor Cyan
    Write-Host "   • Start a new PowerShell session" -ForegroundColor White
    Write-Host "   • Remove any cached module versions:" -ForegroundColor White
    Write-Host "     Remove-Module DotWin -Force -ErrorAction SilentlyContinue" -ForegroundColor Gray
    Write-Host "   • Import the restored module:" -ForegroundColor White
    Write-Host "     Import-Module DotWin -Force" -ForegroundColor Gray

    Write-Host "`n4️⃣  VERIFICATION:" -ForegroundColor Cyan
    Write-Host "   • Test basic DotWin functions:" -ForegroundColor White
    Write-Host "     Get-Command -Module DotWin" -ForegroundColor Gray
    Write-Host "     Set-PowershellProfile -ProfileType Developer -WhatIf" -ForegroundColor Gray
    Write-Host "     Install-SystemTools -ToolCategory WindowsFeatures -WhatIf" -ForegroundColor Gray

    Write-Host "`n5️⃣  PREVENTION:" -ForegroundColor Cyan
    Write-Host "   • Always run Test-IntegrationHealth before modifications" -ForegroundColor White
    Write-Host "   • Keep regular backups of working configurations" -ForegroundColor White
    Write-Host "   • Use -WhatIf parameter to preview changes" -ForegroundColor White

    Write-Host "`n📞 SUPPORT:" -ForegroundColor Magenta
    Write-Host "   If recovery fails, report the issue with:" -ForegroundColor White
    Write-Host "   • Error messages from failed operations" -ForegroundColor White
    Write-Host "   • PowerShell version: $($PSVersionTable.PSVersion)" -ForegroundColor White
    Write-Host "   • Operating system: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor White
    Write-Host "   • Backup timestamp and location" -ForegroundColor White
}
```

### **Post-Rollback Verification**

#### **5. Health Check After Rollback**

```powershell
function Test-PostRollbackHealth {
    [CmdletBinding()]
    param()

    Write-Host "`n🔍 Post-Rollback Health Check" -ForegroundColor Blue
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Blue

    $healthResults = @{
        OverallStatus = "Unknown"
        ModuleStatus = @{}
        FunctionStatus = @{}
        ConfigurationStatus = @{}
        Recommendations = @()
    }

    # Test module loading
    try {
        $module = Get-Module DotWin
        if ($module) {
            $healthResults.ModuleStatus["Loaded"] = "✅ Module is loaded"
            $healthResults.ModuleStatus["Version"] = "✅ Version: $($module.Version)"
        } else {
            $healthResults.ModuleStatus["Loaded"] = "❌ Module not loaded"
            $healthResults.Recommendations += "Import-Module DotWin -Force"
        }
    } catch {
        $healthResults.ModuleStatus["Error"] = "❌ Module check failed: $($_.Exception.Message)"
    }

    # Test core functions
    $coreFunctions = @('Set-PowershellProfile', 'Install-SystemTools', 'Set-TerminalProfile', 'Install-Applications')
    foreach ($functionName in $coreFunctions) {
        try {
            $command = Get-Command $functionName -ErrorAction Stop
            $healthResults.FunctionStatus[$functionName] = "✅ Available"

            # Test WhatIf execution
            try {
                switch ($functionName) {
                    'Set-PowershellProfile' { & $functionName -ProfileType "Developer" -WhatIf -ErrorAction Stop }
                    'Install-SystemTools' { & $functionName -ToolCategory "WindowsFeatures" -WhatIf -ErrorAction Stop }
                    'Set-TerminalProfile' { & $functionName -ProfileName "Default" -WhatIf -ErrorAction Stop }
                    'Install-Applications' { & $functionName -ConfigurationName "Developer" -WhatIf -ErrorAction Stop }
                }
                $healthResults.FunctionStatus["$functionName.Execution"] = "✅ WhatIf test passed"
            } catch {
                $healthResults.FunctionStatus["$functionName.Execution"] = "❌ WhatIf test failed: $($_.Exception.Message)"
                $healthResults.Recommendations += "Investigate $functionName function integrity"
            }
        } catch {
            $healthResults.FunctionStatus[$functionName] = "❌ Not available: $($_.Exception.Message)"
            $healthResults.Recommendations += "Restore $functionName function"
        }
    }

    # Test configuration access
    try {
        $configPath = Join-Path $PSScriptRoot "..\config"
        $configFiles = @('Profile.ps1', 'Tools.ps1', 'Terminal.ps1', 'Packages.ps1')

        foreach ($configFile in $configFiles) {
            $filePath = Join-Path $configPath $configFile
            if (Test-Path $filePath) {
                try {
                    . $filePath
                    $healthResults.ConfigurationStatus[$configFile] = "✅ Loads successfully"
                } catch {
                    $healthResults.ConfigurationStatus[$configFile] = "❌ Load error: $($_.Exception.Message)"
                }
            } else {
                $healthResults.ConfigurationStatus[$configFile] = "❌ File not found"
            }
        }
    } catch {
        $healthResults.ConfigurationStatus["Access"] = "❌ Cannot access configuration files"
    }

    # Determine overall status
    $criticalIssues = ($healthResults.FunctionStatus.Values + $healthResults.ConfigurationStatus.Values + $healthResults.ModuleStatus.Values) |
                     Where-Object { $_ -like "❌*" }

    $healthResults.OverallStatus = if ($criticalIssues.Count -eq 0) { "✅ Healthy" }
                                  elseif ($criticalIssues.Count -le 2) { "⚠️ Minor Issues" }
                                  else { "❌ Critical Issues" }

    # Display results
    Write-Host "`n📊 Health Check Results:" -ForegroundColor Cyan
    Write-Host "Overall Status: $($healthResults.OverallStatus)" -ForegroundColor $(if ($healthResults.OverallStatus -like "✅*") { "Green" } elseif ($healthResults.OverallStatus -like "⚠️*") { "Yellow" } else { "Red" })

    Write-Host "`n🔧 Module Status:" -ForegroundColor Blue
    foreach ($status in $healthResults.ModuleStatus.GetEnumerator()) {
        Write-Host "  $($status.Key): $($status.Value)" -ForegroundColor White
    }

    Write-Host "`n⚡ Function Status:" -ForegroundColor Blue
    foreach ($status in $healthResults.FunctionStatus.GetEnumerator()) {
        $color = if ($status.Value -like "✅*") { "Green" } else { "Red" }
        Write-Host "  $($status.Key): $($status.Value)" -ForegroundColor $color
    }

    Write-Host "`n📝 Configuration Status:" -ForegroundColor Blue
    foreach ($status in $healthResults.ConfigurationStatus.GetEnumerator()) {
        $color = if ($status.Value -like "✅*") { "Green" } else { "Red" }
        Write-Host "  $($status.Key): $($status.Value)" -ForegroundColor $color
    }

    if ($healthResults.Recommendations.Count -gt 0) {
        Write-Host "`n💡 Recommendations:" -ForegroundColor Magenta
        foreach ($recommendation in $healthResults.Recommendations) {
            Write-Host "  • $recommendation" -ForegroundColor Yellow
        }
    }

    return $healthResults
}
```

---

---

## Risk Assessment

### **Low Risk Integrations**

- ✅ `Set-PowershellProfile`: Clear integration path, existing fallback mechanisms
- ✅ `Install-SystemTools`: Well-defined configuration structure

### **Comprehensive Mitigation Strategies**

#### **🛡️ Multi-Level Fallback Protection**

- **Level 1**: Configuration Bridge with user overrides
- **Level 2**: Configuration Bridge module-only (no user overrides)
- **Level 3**: Direct configuration file access
- **Level 4**: Legacy hardcoded methods
- **Level 5**: Safe defaults and user notification

#### **🧪 Validation & Testing Framework**

- **Pre-execution Validation**: Test all configurations before applying
- **Health Checks**: Continuous monitoring of Configuration Bridge status
- **Integration Testing**: Automated tests for each fallback level
- **User Acceptance Testing**: Guide users through validation scenarios

#### **📋 User Communication & Support**

- **Clear Error Messages**: Specific actionable error descriptions
- **Recovery Guidance**: Step-by-step recovery instructions
- **Backup & Restore**: Automatic backups before configuration changes
- **Documentation**: Comprehensive troubleshooting guides

#### **⚡ Performance & Reliability**

- **Graceful Degradation**: Functions continue working even with Configuration Bridge failures
- **Caching Strategy**: Reduce impact of repeated configuration failures
- **Timeout Handling**: Prevent hanging on slow configuration operations
- **Resource Cleanup**: Proper disposal of failed configuration attempts

This comprehensive error handling strategy ensures that Configuration Bridge integration enhances DotWin's reliability rather than introducing new failure points, maintaining the "terraform for Windows" vision while providing enterprise-grade robustness.
