<#
.SYNOPSIS
    Core configuration classes for the DotWin PowerShell module.

.DESCRIPTION
    This file contains the foundational classes used to represent and manage
    configuration objects in the DotWin system. These classes provide the
    object hierarchy for declarative configuration management.
#>

# Base configuration item class
class DotWinConfigurationItem {
    [string]$Name
    [string]$Type
    [string]$Description
    [hashtable]$Properties
    [bool]$Enabled
    [datetime]$LastModified

    DotWinConfigurationItem() {
        $this.Properties = @{}
        $this.Enabled = $true
        $this.LastModified = Get-Date
    }

    DotWinConfigurationItem([string]$Name, [string]$Type) {
        $this.Name = $Name
        $this.Type = $Type
        $this.Properties = @{}
        $this.Enabled = $true
        $this.LastModified = Get-Date
    }

    # Virtual method to be overridden by derived classes
    [bool] Test() {
        throw "Test method must be implemented by derived classes"
    }

    # Virtual method to be overridden by derived classes
    [void] Apply() {
        throw "Apply method must be implemented by derived classes"
    }

    # Virtual method to be overridden by derived classes
    [hashtable] GetCurrentState() {
        throw "GetCurrentState method must be implemented by derived classes"
    }
}

# Configuration collection class
class DotWinConfiguration {
    [string]$Name
    [string]$Version
    [string]$Description
    [System.Collections.Generic.List[DotWinConfigurationItem]]$Items
    [hashtable]$Metadata
    [datetime]$Created
    [datetime]$LastModified

    DotWinConfiguration() {
        $this.Items = [System.Collections.Generic.List[DotWinConfigurationItem]]::new()
        $this.Metadata = @{}
        $this.Created = Get-Date
        $this.LastModified = Get-Date
        $this.Version = "1.0.0"
    }

    DotWinConfiguration([string]$Name) {
        $this.Name = $Name
        $this.Items = [System.Collections.Generic.List[DotWinConfigurationItem]]::new()
        $this.Metadata = @{}
        $this.Created = Get-Date
        $this.LastModified = Get-Date
        $this.Version = "1.0.0"
    }

    # Add a configuration item
    [void] AddItem([DotWinConfigurationItem]$Item) {
        if ($null -eq $Item) {
            throw "Configuration item cannot be null"
        }
        $this.Items.Add($Item)
        $this.LastModified = Get-Date
    }

    # Remove a configuration item by name
    [bool] RemoveItem([string]$Name) {
        $item = $this.Items | Where-Object { $_.Name -eq $Name }
        if ($item) {
            $this.Items.Remove($item)
            $this.LastModified = Get-Date
            return $true
        }
        return $false
    }

    # Get a configuration item by name
    [DotWinConfigurationItem] GetItem([string]$Name) {
        return $this.Items | Where-Object { $_.Name -eq $Name }
    }

    # Get all items of a specific type
    [System.Collections.Generic.List[DotWinConfigurationItem]] GetItemsByType([string]$Type) {
        $result = [System.Collections.Generic.List[DotWinConfigurationItem]]::new()
        foreach ($item in $this.Items) {
            if ($item.Type -eq $Type) {
                $result.Add($item)
            }
        }
        return $result
    }

    # Test all configuration items
    [hashtable] TestAll() {
        $results = @{
            TotalItems = $this.Items.Count
            PassedItems = 0
            FailedItems = 0
            Results = @{}
        }

        foreach ($item in $this.Items) {
            if ($item.Enabled) {
                try {
                    $testResult = $item.Test()
                    $results.Results[$item.Name] = @{
                        Status = if ($testResult) { "Pass" } else { "Fail" }
                        Type = $item.Type
                        Error = $null
                    }
                    if ($testResult) {
                        $results.PassedItems++
                    } else {
                        $results.FailedItems++
                    }
                } catch {
                    $results.Results[$item.Name] = @{
                        Status = "Error"
                        Type = $item.Type
                        Error = $_.Exception.Message
                    }
                    $results.FailedItems++
                }
            }
        }

        return $results
    }
}

# Plugin Architecture Classes

# Base plugin interface
class DotWinPlugin {
    [string]$Name
    [string]$Version
    [string]$Author
    [string]$Description
    [string]$Category
    [hashtable]$Metadata
    [string[]]$Dependencies
    [string[]]$SupportedPlatforms
    [bool]$Enabled
    [datetime]$LoadedAt

    DotWinPlugin() {
        $this.Metadata = @{}
        $this.Dependencies = @()
        $this.SupportedPlatforms = @("Windows")
        $this.Enabled = $true
        $this.LoadedAt = Get-Date
    }

    DotWinPlugin([string]$Name, [string]$Version) {
        $this.Name = $Name
        $this.Version = $Version
        $this.Metadata = @{}
        $this.Dependencies = @()
        $this.SupportedPlatforms = @("Windows")
        $this.Enabled = $true
        $this.LoadedAt = Get-Date
    }

    # Virtual methods to be implemented by derived classes
    [bool] Initialize() {
        throw "Initialize method must be implemented by derived plugin classes"
    }

    [void] Cleanup() {
        throw "Cleanup method must be implemented by derived plugin classes"
    }

    [hashtable] GetCapabilities() {
        throw "GetCapabilities method must be implemented by derived plugin classes"
    }

    [bool] ValidateEnvironment() {
        # Default implementation - can be overridden
        return $true
    }
}

# Configuration plugin base class
class DotWinConfigurationPlugin : DotWinPlugin {
    [string[]]$SupportedTypes
    [hashtable]$ConfigurationHandlers

    DotWinConfigurationPlugin() : base() {
        $this.Category = "Configuration"
        $this.SupportedTypes = @()
        $this.ConfigurationHandlers = @{}
    }

    DotWinConfigurationPlugin([string]$Name, [string]$Version) : base($Name, $Version) {
        $this.Category = "Configuration"
        $this.SupportedTypes = @()
        $this.ConfigurationHandlers = @{}
    }

    # Register a configuration type handler
    [void] RegisterHandler([string]$Type, [scriptblock]$Handler) {
        $this.ConfigurationHandlers[$Type] = $Handler
        if ($Type -notin $this.SupportedTypes) {
            $this.SupportedTypes += $Type
        }
    }

    # Process a configuration item
    [DotWinExecutionResult] ProcessConfiguration([DotWinConfigurationItem]$Item) {
        if ($Item.Type -notin $this.SupportedTypes) {
            throw "Configuration type '$($Item.Type)' is not supported by this plugin"
        }

        $handler = $this.ConfigurationHandlers[$Item.Type]
        if (-not $handler) {
            throw "No handler registered for configuration type '$($Item.Type)'"
        }

        try {
            $result = & $handler $Item
            return $result
        } catch {
            $errorResult = [DotWinExecutionResult]::new()
            $errorResult.Success = $false
            $errorResult.ItemName = $Item.Name
            $errorResult.ItemType = $Item.Type
            $errorResult.Message = "Plugin execution failed: $($_.Exception.Message)"
            return $errorResult
        }
    }
}

# Recommendation plugin base class
class DotWinRecommendationPlugin : DotWinPlugin {
    [string[]]$RecommendationCategories
    [hashtable]$RecommendationRules

    DotWinRecommendationPlugin() : base() {
        $this.Category = "Recommendation"
        $this.RecommendationCategories = @()
        $this.RecommendationRules = @{}
    }

    DotWinRecommendationPlugin([string]$Name, [string]$Version) : base($Name, $Version) {
        $this.Category = "Recommendation"
        $this.RecommendationCategories = @()
        $this.RecommendationRules = @{}
    }

    # Generate recommendations based on system profile
    [DotWinRecommendation[]] GenerateRecommendations([DotWinSystemProfiler]$SystemProfile) {
        throw "GenerateRecommendations method must be implemented by derived plugin classes"
    }

    # Register a recommendation rule
    [void] RegisterRule([string]$Category, [string]$RuleName, [scriptblock]$Rule) {
        if ($Category -notin $this.RecommendationCategories) {
            $this.RecommendationCategories += $Category
        }

        if (-not $this.RecommendationRules.ContainsKey($Category)) {
            $this.RecommendationRules[$Category] = @{}
        }

        $this.RecommendationRules[$Category][$RuleName] = $Rule
    }
}

# Plugin manager class
class DotWinPluginManager {
    [hashtable]$LoadedPlugins
    [hashtable]$PluginRegistry
    [string[]]$PluginPaths
    [hashtable]$PluginDependencies
    [bool]$AutoLoadEnabled

    DotWinPluginManager() {
        $this.LoadedPlugins = @{}
        $this.PluginRegistry = @{}
        $this.PluginPaths = @()
        $this.PluginDependencies = @{}
        $this.AutoLoadEnabled = $true
    }

    # Add a plugin search path
    [void] AddPluginPath([string]$Path) {
        if (Test-Path $Path) {
            if ($Path -notin $this.PluginPaths) {
                $this.PluginPaths += $Path
            }
        } else {
            throw "Plugin path '$Path' does not exist"
        }
    }

    # Register a plugin
    [void] RegisterPlugin([DotWinPlugin]$Plugin) {
        if (-not $Plugin.Name) {
            throw "Plugin name cannot be empty"
        }

        # Validate plugin
        if (-not $this.ValidatePlugin($Plugin)) {
            throw "Plugin validation failed for '$($Plugin.Name)'"
        }

        # Check dependencies
        if (-not $this.CheckDependencies($Plugin)) {
            throw "Plugin dependencies not satisfied for '$($Plugin.Name)'"
        }

        $this.PluginRegistry[$Plugin.Name] = $Plugin
        Write-Verbose "Plugin '$($Plugin.Name)' registered successfully"
    }

    # Load a plugin
    [bool] LoadPlugin([string]$PluginName) {
        if ($PluginName -in $this.LoadedPlugins.Keys) {
            Write-Verbose "Plugin '$PluginName' is already loaded"
            return $true
        }

        if ($PluginName -notin $this.PluginRegistry.Keys) {
            throw "Plugin '$PluginName' is not registered"
        }

        $plugin = $this.PluginRegistry[$PluginName]

        try {
            # Initialize plugin
            if ($plugin.Initialize()) {
                $this.LoadedPlugins[$PluginName] = $plugin
                Write-Verbose "Plugin '$PluginName' loaded successfully"
                return $true
            } else {
                Write-Error "Plugin '$PluginName' initialization failed"
                return $false
            }
        } catch {
            Write-Error "Error loading plugin '$PluginName': $($_.Exception.Message)"
            return $false
        }
    }

    # Unload a plugin
    [bool] UnloadPlugin([string]$PluginName) {
        if ($PluginName -notin $this.LoadedPlugins.Keys) {
            Write-Verbose "Plugin '$PluginName' is not loaded"
            return $true
        }

        $plugin = $this.LoadedPlugins[$PluginName]

        try {
            $plugin.Cleanup()
            $this.LoadedPlugins.Remove($PluginName)
            Write-Verbose "Plugin '$PluginName' unloaded successfully"
            return $true
        } catch {
            Write-Error "Error unloading plugin '$PluginName': $($_.Exception.Message)"
            return $false
        }
    }

    # Get loaded plugins by category
    [DotWinPlugin[]] GetPluginsByCategory([string]$Category) {
        $plugins = @()
        foreach ($plugin in $this.LoadedPlugins.Values) {
            if ($plugin.Category -eq $Category) {
                $plugins += $plugin
            }
        }
        return $plugins
    }

    # Validate plugin
    [bool] ValidatePlugin([DotWinPlugin]$Plugin) {
        # Check required properties
        if ([string]::IsNullOrEmpty($Plugin.Name) -or
            [string]::IsNullOrEmpty($Plugin.Version)) {
            return $false
        }

        # Check platform compatibility
        $currentPlatform = "Windows"
        if ($currentPlatform -notin $Plugin.SupportedPlatforms) {
            return $false
        }

        # Validate environment
        return $Plugin.ValidateEnvironment()
    }

    # Check plugin dependencies
    [bool] CheckDependencies([DotWinPlugin]$Plugin) {
        foreach ($dependency in $Plugin.Dependencies) {
            if ($dependency -notin $this.LoadedPlugins.Keys -and
                $dependency -notin $this.PluginRegistry.Keys) {
                Write-Warning "Plugin dependency '$dependency' not found for plugin '$($Plugin.Name)'"
                return $false
            }
        }
        return $true
    }

    # Discover plugins in search paths
    [void] DiscoverPlugins() {
        foreach ($path in $this.PluginPaths) {
            $pluginFiles = Get-ChildItem -Path $path -Filter "*.ps1" -Recurse
            foreach ($file in $pluginFiles) {
                try {
                    # Load plugin file and extract plugin classes
                    $content = Get-Content -Path $file.FullName -Raw
                    # This is a simplified approach - in a full implementation,
                    # you would parse the PowerShell AST to find plugin classes
                    Write-Verbose "Discovered potential plugin file: $($file.FullName)"
                } catch {
                    Write-Warning "Error processing plugin file '$($file.FullName)': $($_.Exception.Message)"
                }
            }
        }
    }

    # Load all registered plugins
    [void] LoadAllPlugins() {
        foreach ($pluginName in $this.PluginRegistry.Keys) {
            if ($pluginName -notin $this.LoadedPlugins.Keys) {
                $this.LoadPlugin($pluginName)
            }
        }
    }

    # Get plugin information
    [hashtable] GetPluginInfo([string]$PluginName) {
        if ($PluginName -notin $this.PluginRegistry.Keys) {
            throw "Plugin '$PluginName' is not registered"
        }

        $plugin = $this.PluginRegistry[$PluginName]
        return @{
            Name = $plugin.Name
            Version = $plugin.Version
            Author = $plugin.Author
            Description = $plugin.Description
            Category = $plugin.Category
            Enabled = $plugin.Enabled
            Loaded = ($PluginName -in $this.LoadedPlugins.Keys)
            Dependencies = $plugin.Dependencies
            SupportedPlatforms = $plugin.SupportedPlatforms
            LoadedAt = $plugin.LoadedAt
            Metadata = $plugin.Metadata
        }
    }
}

# Configuration validation result class
class DotWinValidationResult {
    [bool]$IsValid
    [string]$ItemName
    [string]$ItemType
    [string]$Message
    [string]$Severity
    [datetime]$Timestamp

    DotWinValidationResult() {
        $this.Timestamp = Get-Date
        $this.Severity = "Information"
    }

    DotWinValidationResult([bool]$IsValid, [string]$ItemName, [string]$Message) {
        $this.IsValid = $IsValid
        $this.ItemName = $ItemName
        $this.Message = $Message
        $this.Timestamp = Get-Date
        $this.Severity = if ($IsValid) { "Information" } else { "Error" }
    }
}

# Configuration execution result class
class DotWinExecutionResult {
    [bool]$Success
    [string]$ItemName
    [string]$ItemType
    [string]$Message
    [hashtable]$Changes
    [datetime]$Timestamp
    [timespan]$Duration

    DotWinExecutionResult() {
        $this.Changes = @{}
        $this.Timestamp = Get-Date
    }

    DotWinExecutionResult([bool]$Success, [string]$ItemName, [string]$Message) {
        $this.Success = $Success
        $this.ItemName = $ItemName
        $this.Message = $Message
        $this.Changes = @{}
        $this.Timestamp = Get-Date
    }
}

# System status class
class DotWinSystemStatus {
    [string]$ComputerName
    [string]$OperatingSystem
    [string]$PowerShellVersion
    [hashtable]$ConfigurationStatus
    [datetime]$LastCheck
    [bool]$IsCompliant

    DotWinSystemStatus() {
        $this.ComputerName = $env:COMPUTERNAME
        $this.OperatingSystem = "Windows"
        $this.PowerShellVersion = "5.1+"
        $this.ConfigurationStatus = @{}
        $this.LastCheck = Get-Date
        $this.IsCompliant = $false
    }

    # Method to initialize system information (called after construction with external data)
    [void] InitializeSystemInfo([string]$OSCaption, [string]$PSVersion) {
        if ($OSCaption) {
            $this.OperatingSystem = $OSCaption
        } else {
            try {
                $this.OperatingSystem = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
                if (-not $this.OperatingSystem) {
                    $this.OperatingSystem = "Unknown Windows Version"
                }
            } catch {
                $this.OperatingSystem = "Unknown"
            }
        }

        if ($PSVersion) {
            $this.PowerShellVersion = $PSVersion
        }
    }
}

# Winget package configuration class
class DotWinWingetPackage : DotWinConfigurationItem {
    [string]$PackageId
    [string]$Version
    [string]$Source
    [bool]$AcceptLicense
    [bool]$AcceptSourceAgreements
    [hashtable]$InstallOptions

    DotWinWingetPackage() : base() {
        $this.Type = "WingetPackage"
        $this.Source = "winget"
        $this.AcceptLicense = $false
        $this.AcceptSourceAgreements = $false
        $this.InstallOptions = @{}
    }

    DotWinWingetPackage([string]$PackageId) : base($PackageId, "WingetPackage") {
        $this.PackageId = $PackageId
        $this.Source = "winget"
        $this.AcceptLicense = $false
        $this.AcceptSourceAgreements = $false
        $this.InstallOptions = @{}
    }

    # Test if the package is installed
    [bool] Test() {
        try {
            $result = & winget list --id $this.PackageId --exact --accept-source-agreements 2>$null
            if ($LASTEXITCODE -eq 0 -and $result) {
                # Check if the package appears in the output
                $packageFound = $result | Where-Object { $_ -match [regex]::Escape($this.PackageId) }
                return $null -ne $packageFound
            }
            return $false
        }
        catch {
            Write-Verbose "Error testing package '$($this.PackageId)': $($_.Exception.Message)"
            return $false
        }
    }

    # Install the package
    [void] Apply() {
        try {
            $arguments = @('install', $this.PackageId, '--silent')

            if ($this.Version) {
                $arguments += @('--version', $this.Version)
            }

            if ($this.AcceptLicense) {
                $arguments += '--accept-package-agreements'
            }

            if ($this.AcceptSourceAgreements) {
                $arguments += '--accept-source-agreements'
            }

            # Add any custom install options
            foreach ($option in $this.InstallOptions.GetEnumerator()) {
                $arguments += "--$($option.Key)"
                if ($option.Value -ne $true) {
                    $arguments += $option.Value
                }
            }

            Write-Verbose "Installing package '$($this.PackageId)' with arguments: $($arguments -join ' ')"

            $result = Start-Process -FilePath 'winget' -ArgumentList $arguments -Wait -PassThru -NoNewWindow

            if ($result.ExitCode -ne 0) {
                throw "Winget installation failed with exit code: $($result.ExitCode)"
            }

            $this.LastModified = Get-Date
        }
        catch {
            throw "Failed to install package '$($this.PackageId)': $($_.Exception.Message)"
        }
    }

    # Get current state of the package
    [hashtable] GetCurrentState() {
        $state = @{
            PackageId = $this.PackageId
            IsInstalled = $this.Test()
            InstalledVersion = $null
            AvailableVersion = $null
            Source = $this.Source
            LastChecked = Get-Date
        }

        try {
            # Try to get installed version
            if ($state.IsInstalled) {
                $listResult = & winget list --id $this.PackageId --exact --accept-source-agreements 2>$null
                if ($LASTEXITCODE -eq 0 -and $listResult) {
                    # Parse version from winget list output (this is a simplified approach)
                    $versionLine = $listResult | Where-Object { $_ -match [regex]::Escape($this.PackageId) } | Select-Object -First 1
                    if ($versionLine -and $versionLine -match '\s+(\d+[\.\d]*[\w\-]*)\s+') {
                        $state.InstalledVersion = $matches[1]
                    }
                }
            }

            # Try to get available version
            $showResult = & winget show --id $this.PackageId --accept-source-agreements 2>$null
            if ($LASTEXITCODE -eq 0 -and $showResult) {
                $versionLine = $showResult | Where-Object { $_ -match '^Version:\s+(.+)$' } | Select-Object -First 1
                if ($versionLine -and $versionLine -match '^Version:\s+(.+)$') {
                    $state.AvailableVersion = $matches[1].Trim()
                }
            }
        }
        catch {
            Write-Verbose "Error getting package state for '$($this.PackageId)': $($_.Exception.Message)"
        }

        return $state
    }
}

# System profiling classes for intelligent configuration recommendations
class DotWinHardwareProfile {
    [string]$CPU_Manufacturer
    [string]$CPU_Model
    [int]$CPU_Cores
    [int]$CPU_LogicalProcessors
    [string]$CPU_Architecture
    [double]$TotalMemoryGB
    [string]$Motherboard_Manufacturer
    [string]$Motherboard_Model
    [string]$Chipset
    [string[]]$GPU_Manufacturers
    [string[]]$GPU_Models
    [string[]]$Storage_Types
    [double]$Storage_TotalGB
    [string[]]$Network_Adapters
    [hashtable]$RawHardwareData
    [datetime]$ProfiledAt

    DotWinHardwareProfile() {
        $this.GPU_Manufacturers = @()
        $this.GPU_Models = @()
        $this.Storage_Types = @()
        $this.Network_Adapters = @()
        $this.RawHardwareData = @{}
        $this.ProfiledAt = Get-Date
    }

    # Determine hardware category for optimization recommendations
    [string] GetHardwareCategory() {
        if ($this.CPU_Cores -ge 8 -and $this.TotalMemoryGB -ge 16) {
            if ($this.GPU_Manufacturers -contains "NVIDIA" -or $this.GPU_Manufacturers -contains "AMD") {
                return "HighPerformance"
            }
            return "Workstation"
        } elseif ($this.CPU_Cores -ge 4 -and $this.TotalMemoryGB -ge 8) {
            return "Mainstream"
        } else {
            return "Budget"
        }
    }

    # Check if system is optimized for gaming
    [bool] IsGamingOptimized() {
        return ($this.GPU_Manufacturers -contains "NVIDIA" -or $this.GPU_Manufacturers -contains "AMD") -and $this.CPU_Cores -ge 4 -and $this.TotalMemoryGB -ge 8
    }

    # Check if system supports virtualization workloads
    [bool] SupportsVirtualization() {
        return $this.CPU_Cores -ge 4 -and $this.TotalMemoryGB -ge 16
    }
}

class DotWinSoftwareProfile {
    [hashtable]$InstalledPackages
    [hashtable]$PowerShellModules
    [hashtable]$WindowsFeatures
    [hashtable]$Services
    [string[]]$DevelopmentTools
    [string[]]$ProductivityTools
    [string[]]$MediaTools
    [string[]]$GamingTools
    [string[]]$SecurityTools
    [hashtable]$PackageManagers
    [datetime]$ProfiledAt

    DotWinSoftwareProfile() {
        $this.InstalledPackages = @{}
        $this.PowerShellModules = @{}
        $this.WindowsFeatures = @{}
        $this.Services = @{}
        $this.DevelopmentTools = @()
        $this.ProductivityTools = @()
        $this.MediaTools = @()
        $this.GamingTools = @()
        $this.SecurityTools = @()
        $this.PackageManagers = @{}
        $this.ProfiledAt = Get-Date
    }

    # Determine primary user type based on installed software
    [string] GetUserType() {
        $devScore = $this.DevelopmentTools.Count * 2
        $productivityScore = $this.ProductivityTools.Count
        $mediaScore = $this.MediaTools.Count
        $gamingScore = $this.GamingTools.Count

        $maxScore = [Math]::Max([Math]::Max($devScore, $productivityScore), [Math]::Max($mediaScore, $gamingScore))

        if ($maxScore -eq $devScore -and $devScore -gt 0) { return "Developer" }
        elseif ($maxScore -eq $gamingScore -and $gamingScore -gt 0) { return "Gamer" }
        elseif ($maxScore -eq $mediaScore -and $mediaScore -gt 0) { return "Creative" }
        elseif ($maxScore -eq $productivityScore -and $productivityScore -gt 0) { return "Business" }
        else { return "General" }
    }

    # Check if package manager is available
    [bool] HasPackageManager([string]$ManagerName) {
        return $this.PackageManagers.ContainsKey($ManagerName) -and $this.PackageManagers[$ManagerName].Available
    }
}

class DotWinUserProfile {
    [string]$Username
    [string]$Domain
    [bool]$IsAdministrator
    [hashtable]$EnvironmentVariables
    [string[]]$RecentApplications
    [hashtable]$SystemLogs
    [hashtable]$UsagePatterns
    [string]$PreferredShell
    [hashtable]$UserPreferences
    [datetime]$ProfiledAt

    DotWinUserProfile() {
        $this.EnvironmentVariables = @{}
        $this.RecentApplications = @()
        $this.SystemLogs = @{}
        $this.UsagePatterns = @{}
        $this.UserPreferences = @{}
        $this.ProfiledAt = Get-Date
    }

    # Determine user's technical proficiency level
    [string] GetTechnicalLevel() {
        $advancedIndicators = 0

        # Check for advanced tools and configurations
        if ($this.PreferredShell -eq "PowerShell Core") { $advancedIndicators++ }
        if ($this.EnvironmentVariables.ContainsKey("PATH") -and $this.EnvironmentVariables["PATH"] -like "*Git*") { $advancedIndicators++ }
        if ($this.RecentApplications -contains "Visual Studio Code" -or $this.RecentApplications -contains "Visual Studio") { $advancedIndicators++ }

        if ($advancedIndicators -ge 2) { return "Advanced" }
        elseif ($advancedIndicators -eq 1) { return "Intermediate" }
        else { return "Beginner" }
    }
}

class DotWinSystemProfiler {
    [DotWinHardwareProfile]$Hardware
    [DotWinSoftwareProfile]$Software
    [DotWinUserProfile]$User
    [hashtable]$SystemMetrics
    [datetime]$LastProfiled
    [string]$ProfileVersion

    DotWinSystemProfiler() {
        try {
            $this.Hardware = [DotWinHardwareProfile]::new()
        } catch {
            # Fallback for test contexts where class loading might be problematic
            $this.Hardware = New-Object -TypeName PSObject
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'CPU_Manufacturer' -Value ''
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'CPU_Model' -Value ''
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'CPU_Cores' -Value 0
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'CPU_LogicalProcessors' -Value 0
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'CPU_Architecture' -Value ''
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'TotalMemoryGB' -Value 0.0
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'Motherboard_Manufacturer' -Value ''
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'Motherboard_Model' -Value ''
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'Chipset' -Value ''
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'GPU_Manufacturers' -Value @()
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'GPU_Models' -Value @()
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'Storage_Types' -Value @()
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'Storage_TotalGB' -Value 0.0
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'Network_Adapters' -Value @()
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'RawHardwareData' -Value @{}
            $this.Hardware | Add-Member -MemberType NoteProperty -Name 'ProfiledAt' -Value (Get-Date)

            # Add methods
            $this.Hardware | Add-Member -MemberType ScriptMethod -Name 'GetHardwareCategory' -Value {
                if ($this.CPU_Cores -ge 8 -and $this.TotalMemoryGB -ge 16) {
                    if ($this.GPU_Manufacturers -contains "NVIDIA" -or $this.GPU_Manufacturers -contains "AMD") {
                        return "HighPerformance"
                    }
                    return "Workstation"
                } elseif ($this.CPU_Cores -ge 4 -and $this.TotalMemoryGB -ge 8) {
                    return "Mainstream"
                } else {
                    return "Budget"
                }
            }

            $this.Hardware | Add-Member -MemberType ScriptMethod -Name 'IsGamingOptimized' -Value {
                return ($this.GPU_Manufacturers -contains "NVIDIA" -or $this.GPU_Manufacturers -contains "AMD") -and $this.CPU_Cores -ge 4 -and $this.TotalMemoryGB -ge 8
            }

            $this.Hardware | Add-Member -MemberType ScriptMethod -Name 'SupportsVirtualization' -Value {
                return $this.CPU_Cores -ge 4 -and $this.TotalMemoryGB -ge 16
            }
        }

        try {
            $this.Software = [DotWinSoftwareProfile]::new()
        } catch {
            # Fallback for test contexts
            $this.Software = New-Object -TypeName PSObject
            $this.Software | Add-Member -MemberType NoteProperty -Name 'InstalledPackages' -Value @{}
            $this.Software | Add-Member -MemberType NoteProperty -Name 'PowerShellModules' -Value @{}
            $this.Software | Add-Member -MemberType NoteProperty -Name 'WindowsFeatures' -Value @{}
            $this.Software | Add-Member -MemberType NoteProperty -Name 'Services' -Value @{}
            $this.Software | Add-Member -MemberType NoteProperty -Name 'DevelopmentTools' -Value @()
            $this.Software | Add-Member -MemberType NoteProperty -Name 'ProductivityTools' -Value @()
            $this.Software | Add-Member -MemberType NoteProperty -Name 'MediaTools' -Value @()
            $this.Software | Add-Member -MemberType NoteProperty -Name 'GamingTools' -Value @()
            $this.Software | Add-Member -MemberType NoteProperty -Name 'SecurityTools' -Value @()
            $this.Software | Add-Member -MemberType NoteProperty -Name 'PackageManagers' -Value @{}
            $this.Software | Add-Member -MemberType NoteProperty -Name 'ProfiledAt' -Value (Get-Date)

            # Add methods
            $this.Software | Add-Member -MemberType ScriptMethod -Name 'GetUserType' -Value {
                $devScore = $this.DevelopmentTools.Count * 2
                $productivityScore = $this.ProductivityTools.Count
                $mediaScore = $this.MediaTools.Count
                $gamingScore = $this.GamingTools.Count

                $maxScore = [Math]::Max([Math]::Max($devScore, $productivityScore), [Math]::Max($mediaScore, $gamingScore))

                if ($maxScore -eq $devScore -and $devScore -gt 0) { return "Developer" }
                elseif ($maxScore -eq $gamingScore -and $gamingScore -gt 0) { return "Gamer" }
                elseif ($maxScore -eq $mediaScore -and $mediaScore -gt 0) { return "Creative" }
                elseif ($maxScore -eq $productivityScore -and $productivityScore -gt 0) { return "Business" }
                else { return "General" }
            }

            $this.Software | Add-Member -MemberType ScriptMethod -Name 'HasPackageManager' -Value {
                param([string]$ManagerName)
                return $this.PackageManagers.ContainsKey($ManagerName) -and $this.PackageManagers[$ManagerName].Available
            }
        }

        try {
            $this.User = [DotWinUserProfile]::new()
        } catch {
            # Fallback for test contexts
            $this.User = New-Object -TypeName PSObject
            $this.User | Add-Member -MemberType NoteProperty -Name 'Username' -Value ''
            $this.User | Add-Member -MemberType NoteProperty -Name 'Domain' -Value ''
            $this.User | Add-Member -MemberType NoteProperty -Name 'IsAdministrator' -Value $false
            $this.User | Add-Member -MemberType NoteProperty -Name 'EnvironmentVariables' -Value @{}
            $this.User | Add-Member -MemberType NoteProperty -Name 'RecentApplications' -Value @()
            $this.User | Add-Member -MemberType NoteProperty -Name 'SystemLogs' -Value @{}
            $this.User | Add-Member -MemberType NoteProperty -Name 'UsagePatterns' -Value @{}
            $this.User | Add-Member -MemberType NoteProperty -Name 'PreferredShell' -Value ''
            $this.User | Add-Member -MemberType NoteProperty -Name 'UserPreferences' -Value @{}
            $this.User | Add-Member -MemberType NoteProperty -Name 'ProfiledAt' -Value (Get-Date)

            # Add methods
            $this.User | Add-Member -MemberType ScriptMethod -Name 'GetTechnicalLevel' -Value {
                $advancedIndicators = 0

                # Check for advanced tools and configurations
                if ($this.PreferredShell -eq "PowerShell Core") { $advancedIndicators++ }
                if ($this.EnvironmentVariables.ContainsKey("PATH") -and $this.EnvironmentVariables["PATH"] -like "*Git*") { $advancedIndicators++ }
                if ($this.RecentApplications -contains "Visual Studio Code" -or $this.RecentApplications -contains "Visual Studio") { $advancedIndicators++ }

                if ($advancedIndicators -ge 2) { return "Advanced" }
                elseif ($advancedIndicators -eq 1) { return "Intermediate" }
                else { return "Beginner" }
            }
        }

        $this.SystemMetrics = @{}
        $this.ProfileVersion = "1.0.0"
    }

    # Main profiling method that orchestrates all profiling activities
    [void] ProfileSystem() {
        Write-Verbose "Starting comprehensive system profiling..."
        $this.LastProfiled = Get-Date

        try {
            $this.ProfileHardware()
            $this.ProfileSoftware()
            $this.ProfileUser()
            $this.CalculateSystemMetrics()

            Write-Verbose "System profiling completed successfully"
        } catch {
            Write-Error "Error during system profiling: $($_.Exception.Message)"
            throw
        }
    }

    # Profile hardware components using both PowerShell Core and Windows PowerShell capabilities
    [void] ProfileHardware() {
        Write-Verbose "Profiling hardware components..."

        try {
            # CPU Information
            $processors = Get-CimInstance -ClassName Win32_Processor
            if ($processors) {
                $firstProcessor = $processors[0]
                $this.Hardware.CPU_Manufacturer = $firstProcessor.Manufacturer
                $this.Hardware.CPU_Model = $firstProcessor.Name
                $this.Hardware.CPU_Cores = $firstProcessor.NumberOfCores
                $this.Hardware.CPU_LogicalProcessors = $firstProcessor.NumberOfLogicalProcessors
                $this.Hardware.CPU_Architecture = $firstProcessor.Architecture
            }

            # Memory Information
            $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
            if ($computerSystem) {
                $this.Hardware.TotalMemoryGB = [Math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
            }

            # Motherboard Information
            $motherboard = Get-CimInstance -ClassName Win32_BaseBoard
            if ($motherboard) {
                $this.Hardware.Motherboard_Manufacturer = $motherboard.Manufacturer
                $this.Hardware.Motherboard_Model = $motherboard.Product
            }

            # GPU Information
            $gpus = Get-CimInstance -ClassName Win32_VideoController | Where-Object { $_.Name -notlike "*Basic*" }
            foreach ($gpu in $gpus) {
                if ($gpu.Name -like "*NVIDIA*") {
                    $this.Hardware.GPU_Manufacturers += "NVIDIA"
                } elseif ($gpu.Name -like "*AMD*" -or $gpu.Name -like "*Radeon*") {
                    $this.Hardware.GPU_Manufacturers += "AMD"
                } elseif ($gpu.Name -like "*Intel*") {
                    $this.Hardware.GPU_Manufacturers += "Intel"
                }
                $this.Hardware.GPU_Models += $gpu.Name
            }

            # Storage Information
            $disks = Get-CimInstance -ClassName Win32_DiskDrive
            $totalStorage = 0
            foreach ($disk in $disks) {
                if ($disk.MediaType -like "*SSD*" -or $disk.Model -like "*SSD*") {
                    $this.Hardware.Storage_Types += "SSD"
                } else {
                    $this.Hardware.Storage_Types += "HDD"
                }
                $totalStorage += $disk.Size
            }
            $this.Hardware.Storage_TotalGB = [Math]::Round($totalStorage / 1GB, 2)

            # Network Adapters
            $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true }
            foreach ($adapter in $networkAdapters) {
                $this.Hardware.Network_Adapters += $adapter.Name
            }

            $this.Hardware.ProfiledAt = Get-Date
            Write-Verbose "Hardware profiling completed successfully"

        } catch {
            Write-Error "Error during hardware profiling: $($_.Exception.Message)"
            throw
        }
    }

    # Profile software components and installed applications
    [void] ProfileSoftware() {
        Write-Verbose "Profiling software components..."

        try {
            # Package Managers Detection
            $this.Software.PackageManagers = @{}

            # Check for Winget
            try {
                $wingetVersion = & winget --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $this.Software.PackageManagers["Winget"] = @{
                        Available = $true
                        Version = $wingetVersion
                    }
                }
            } catch {
                $this.Software.PackageManagers["Winget"] = @{ Available = $false }
            }

            # Check for Chocolatey
            try {
                $chocoVersion = & choco --version 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $this.Software.PackageManagers["Chocolatey"] = @{
                        Available = $true
                        Version = $chocoVersion
                    }
                }
            } catch {
                $this.Software.PackageManagers["Chocolatey"] = @{ Available = $false }
            }

            # Installed Packages via Winget
            if ($this.Software.PackageManagers["Winget"].Available) {
                try {
                    $wingetList = & winget list --accept-source-agreements 2>$null
                    if ($LASTEXITCODE -eq 0 -and $wingetList) {
                        foreach ($line in $wingetList) {
                            if ($line -match '^([^\s]+)\s+([^\s]+)') {
                                $this.Software.InstalledPackages[$matches[1]] = @{
                                    Version = $matches[2]
                                    Source = "Winget"
                                }
                            }
                        }
                    }
                } catch {
                    Write-Verbose "Could not enumerate Winget packages: $($_.Exception.Message)"
                }
            }

            # PowerShell Modules
            $availableModules = Get-Module -ListAvailable
            foreach ($module in $availableModules) {
                $this.Software.PowerShellModules[$module.Name] = @{
                    Version = $module.Version.ToString()
                    Path = $module.ModuleBase
                }
            }

            # Windows Features
            try {
                $features = Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue
                foreach ($feature in $features) {
                    $this.Software.WindowsFeatures[$feature.FeatureName] = @{
                        State = $feature.State
                    }
                }
            } catch {
                Write-Verbose "Could not enumerate Windows features: $($_.Exception.Message)"
            }

            # Categorize installed software
            $this.CategorizeInstalledSoftware()

            $this.Software.ProfiledAt = Get-Date
            Write-Verbose "Software profiling completed successfully"

        } catch {
            Write-Error "Error during software profiling: $($_.Exception.Message)"
            throw
        }
    }

    # Profile user behavior and preferences
    [void] ProfileUser() {
        Write-Verbose "Profiling user behavior and preferences..."

        try {
            # Basic user information
            $this.User.Username = $env:USERNAME
            $this.User.Domain = $env:USERDOMAIN

            # Check if running as administrator
            $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
            $this.User.IsAdministrator = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

            # Environment variables
            foreach ($envVar in Get-ChildItem Env:) {
                $this.User.EnvironmentVariables[$envVar.Name] = $envVar.Value
            }

            # Determine preferred shell (simplified approach)
            $this.User.PreferredShell = "PowerShell"

            # Recent applications (simplified approach)
            try {
                $recentApps = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs" -ErrorAction SilentlyContinue
                if ($recentApps) {
                    # This is a simplified implementation
                    $this.User.RecentApplications += "Explorer", "PowerShell"
                }
            } catch {
                Write-Verbose "Could not access recent applications: $($_.Exception.Message)"
            }

            $this.User.ProfiledAt = Get-Date
            Write-Verbose "User profiling completed successfully"

        } catch {
            Write-Error "Error during user profiling: $($_.Exception.Message)"
            throw
        }
    }

    # Calculate comprehensive system metrics
    [void] CalculateSystemMetrics() {
        Write-Verbose "Calculating system performance metrics..."

        try {
            $this.SystemMetrics = @{}

            # Performance Score (0-100)
            $performanceScore = 0
            if ($this.Hardware.CPU_Cores -ge 8) { $performanceScore += 30 }
            elseif ($this.Hardware.CPU_Cores -ge 4) { $performanceScore += 20 }
            else { $performanceScore += 10 }

            if ($this.Hardware.TotalMemoryGB -ge 16) { $performanceScore += 25 }
            elseif ($this.Hardware.TotalMemoryGB -ge 8) { $performanceScore += 15 }
            else { $performanceScore += 5 }

            if ($this.Hardware.Storage_Types -contains "SSD") { $performanceScore += 20 }
            else { $performanceScore += 5 }

            if ($this.Hardware.GPU_Manufacturers -contains "NVIDIA" -or $this.Hardware.GPU_Manufacturers -contains "AMD") {
                $performanceScore += 25
            } else { $performanceScore += 10 }

            $this.SystemMetrics["PerformanceScore"] = [Math]::Min(100, $performanceScore)

            # Security Score (0-100)
            $securityScore = 50  # Base score
            if ($this.User.IsAdministrator) { $securityScore -= 10 }  # Running as admin is less secure
            if ($this.Software.WindowsFeatures.ContainsKey("Windows-Defender-Default-Definitions")) { $securityScore += 20 }
            if ($this.Software.WindowsFeatures.ContainsKey("BitLocker")) { $securityScore += 15 }
            $this.SystemMetrics["SecurityScore"] = [Math]::Max(0, [Math]::Min(100, $securityScore))

            # Developer Friendliness Score (0-100)
            $devScore = 0
            if ($this.Software.DevelopmentTools.Count -gt 0) { $devScore += 30 }
            if ($this.Software.PackageManagers.ContainsKey("Winget") -and $this.Software.PackageManagers["Winget"].Available) { $devScore += 20 }
            if ($this.Software.PackageManagers.ContainsKey("Chocolatey") -and $this.Software.PackageManagers["Chocolatey"].Available) { $devScore += 15 }
            if ($this.User.PreferredShell -eq "PowerShell Core") { $devScore += 15 }
            if ($this.Software.WindowsFeatures.ContainsKey("Microsoft-Windows-Subsystem-Linux")) { $devScore += 20 }
            $this.SystemMetrics["DeveloperFriendliness"] = [Math]::Min(100, $devScore)

            # Optimization Potential (0-100)
            $optimizationPotential = 100 - $this.SystemMetrics["PerformanceScore"]
            $this.SystemMetrics["OptimizationPotential"] = $optimizationPotential

            # System Complexity Score
            $complexityScore = $this.Software.InstalledPackages.Count + $this.Software.PowerShellModules.Count
            $this.SystemMetrics["SystemComplexity"] = $complexityScore

            Write-Verbose "System metrics calculation completed"

        } catch {
            Write-Error "Error calculating system metrics: $($_.Exception.Message)"
            throw
        }
    }

    # Helper method to categorize installed software
    [void] CategorizeInstalledSoftware() {
        $devTools = @("git", "vscode", "visual-studio", "docker", "nodejs", "python", "java", "dotnet")
        $productivityTools = @("office", "teams", "slack", "zoom", "notepad++", "7zip")
        $mediaTools = @("vlc", "spotify", "adobe", "gimp", "obs", "handbrake")
        $gamingTools = @("steam", "discord", "nvidia", "amd", "origin", "epic")
        $securityTools = @("malwarebytes", "bitdefender", "kaspersky", "avast")

        foreach ($package in $this.Software.InstalledPackages.Keys) {
            $packageLower = $package.ToLower()

            foreach ($tool in $devTools) {
                if ($packageLower -like "*$tool*") {
                    $this.Software.DevelopmentTools += $package
                    break
                }
            }

            foreach ($tool in $productivityTools) {
                if ($packageLower -like "*$tool*") {
                    $this.Software.ProductivityTools += $package
                    break
                }
            }

            foreach ($tool in $mediaTools) {
                if ($packageLower -like "*$tool*") {
                    $this.Software.MediaTools += $package
                    break
                }
            }

            foreach ($tool in $gamingTools) {
                if ($packageLower -like "*$tool*") {
                    $this.Software.GamingTools += $package
                    break
                }
            }

            foreach ($tool in $securityTools) {
                if ($packageLower -like "*$tool*") {
                    $this.Software.SecurityTools += $package
                    break
                }
            }
        }
    }

    # Export system profile to JSON
    [string] ExportToJson() {
        $exportData = @{
            ProfileVersion = $this.ProfileVersion
            LastProfiled = $this.LastProfiled
            Hardware = @{
                CPU_Manufacturer = $this.Hardware.CPU_Manufacturer
                CPU_Model = $this.Hardware.CPU_Model
                CPU_Cores = $this.Hardware.CPU_Cores
                CPU_LogicalProcessors = $this.Hardware.CPU_LogicalProcessors
                TotalMemoryGB = $this.Hardware.TotalMemoryGB
                HardwareCategory = $this.Hardware.GetHardwareCategory()
                IsGamingOptimized = $this.Hardware.IsGamingOptimized()
                SupportsVirtualization = $this.Hardware.SupportsVirtualization()
            }
            Software = @{
                UserType = $this.Software.GetUserType()
                PackageManagers = $this.Software.PackageManagers
                DevelopmentToolsCount = $this.Software.DevelopmentTools.Count
                ProductivityToolsCount = $this.Software.ProductivityTools.Count
                InstalledPackagesCount = $this.Software.InstalledPackages.Count
            }
            User = @{
                Username = $this.User.Username
                IsAdministrator = $this.User.IsAdministrator
                TechnicalLevel = $this.User.GetTechnicalLevel()
                PreferredShell = $this.User.PreferredShell
            }
            SystemMetrics = $this.SystemMetrics
        }

        return ($exportData | ConvertTo-Json -Depth 10)
    }
}

# Recommendation Engine Classes
class DotWinRecommendation {
    [string]$Id
    [string]$Title
    [string]$Description
    [string]$Category
    [string]$Priority
    [double]$ConfidenceScore
    [hashtable]$Implementation
    [string[]]$Prerequisites
    [hashtable]$Metadata
    [datetime]$CreatedAt

    DotWinRecommendation() {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.Implementation = @{}
        $this.Prerequisites = @()
        $this.Metadata = @{}
        $this.CreatedAt = Get-Date
        $this.ConfidenceScore = 0.5
    }

    DotWinRecommendation([string]$Title, [string]$Description, [string]$Category) {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.Title = $Title
        $this.Description = $Description
        $this.Category = $Category
        $this.Implementation = @{}
        $this.Prerequisites = @()
        $this.Metadata = @{}
        $this.CreatedAt = Get-Date
        $this.ConfidenceScore = 0.5
    }
}

class DotWinRecommendationEngine {
    [DotWinSystemProfiler]$SystemProfile
    [string]$EngineVersion
    [hashtable]$Rules
    [hashtable]$ConflictMatrix
    [datetime]$LastGenerated

    DotWinRecommendationEngine([DotWinSystemProfiler]$SystemProfile) {
        if ($null -eq $SystemProfile) {
            throw "SystemProfile cannot be null"
        }
        # More lenient validation for mock objects - check if LastProfiled exists and is a valid date
        if ($null -eq $SystemProfile.LastProfiled) {
            throw "Invalid or incomplete system profile provided - LastProfiled is required"
        }
        # Allow mock objects with recent dates or default to current time for very old dates
        if ($SystemProfile.LastProfiled -eq [datetime]::MinValue) {
            Write-Warning "System profile has MinValue LastProfiled, using current time"
            $SystemProfile.LastProfiled = Get-Date
        }
        $this.SystemProfile = $SystemProfile
        $this.EngineVersion = "1.0.0"
        $this.Rules = @{}
        $this.ConflictMatrix = @{}
        $this.InitializeRules()
    }

    # Initialize recommendation rules
    [void] InitializeRules() {
        # Hardware-based recommendations
        $this.Rules["Hardware"] = @{
            "HighPerformanceOptimization" = {
                param($profile)
                $recommendations = @()

                if ($profile.Hardware.GetHardwareCategory() -eq "HighPerformance") {
                    $rec = [DotWinRecommendation]::new(
                        "Enable High Performance Power Plan",
                        "Configure Windows to use High Performance power plan for maximum performance",
                        "Hardware"
                    )
                    $rec.Priority = "High"
                    $rec.ConfidenceScore = 0.9
                    $rec.Implementation = @{
                        Type = "PowerShell"
                        Command = "powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"
                    }
                    $recommendations += $rec
                }

                return $recommendations
            }
        }

        # Software-based recommendations
        $this.Rules["Software"] = @{
            "DeveloperTools" = {
                param($profile)
                $recommendations = @()

                if ($profile.Software.GetUserType() -eq "Developer" -and $profile.Software.DevelopmentTools.Count -lt 3) {
                    $rec = [DotWinRecommendation]::new(
                        "Install Essential Developer Tools",
                        "Install Git, Visual Studio Code, and Windows Terminal for development",
                        "Software"
                    )
                    $rec.Priority = "High"
                    $rec.ConfidenceScore = 0.85
                    $rec.Implementation = @{
                        Type = "Package"
                        Packages = @("Git.Git", "Microsoft.VisualStudioCode", "Microsoft.WindowsTerminal")
                    }
                    $recommendations += $rec
                }

                return $recommendations
            }
        }
    }

    # Generate recommendations based on system profile
    [DotWinRecommendation[]] GenerateRecommendations() {
        $allRecommendations = @()
        $this.LastGenerated = Get-Date

        foreach ($category in $this.Rules.Keys) {
            foreach ($ruleName in $this.Rules[$category].Keys) {
                try {
                    $rule = $this.Rules[$category][$ruleName]
                    $recommendations = & $rule $this.SystemProfile
                    $allRecommendations += $recommendations
                } catch {
                    Write-Warning "Error executing rule '$ruleName': $($_.Exception.Message)"
                }
            }
        }

        return $this.PrioritizeRecommendations($allRecommendations)
    }

    # Prioritize recommendations based on confidence and impact
    [DotWinRecommendation[]] PrioritizeRecommendations([DotWinRecommendation[]]$Recommendations) {
        return $Recommendations | Sort-Object @{
            Expression = {
                switch ($_.Priority) {
                    "High" { 3 }
                    "Medium" { 2 }
                    "Low" { 1 }
                    default { 0 }
                }
            }
            Descending = $true
        }, @{
            Expression = { $_.ConfidenceScore }
            Descending = $true
        }
    }

    # Resolve conflicts between recommendations
    [DotWinRecommendation[]] ResolveConflicts([DotWinRecommendation[]]$Recommendations) {
        # Simple conflict resolution - remove lower priority duplicates
        $resolved = @()
        $seen = @{}

        foreach ($rec in $Recommendations) {
            $key = "$($rec.Category):$($rec.Title)"
            if (-not $seen.ContainsKey($key)) {
                $seen[$key] = $true
                $resolved += $rec
            }
        }

        return $resolved
    }

    # Apply a single recommendation
    [DotWinExecutionResult] ApplyRecommendation([DotWinRecommendation]$Recommendation) {
        $result = [DotWinExecutionResult]::new()
        $result.ItemName = $Recommendation.Title
        $result.ItemType = $Recommendation.Category

        try {
            switch ($Recommendation.Implementation.Type) {
                "PowerShell" {
                    Invoke-Expression $Recommendation.Implementation.Command
                    $result.Success = $true
                    $result.Message = "PowerShell command executed successfully"
                }
                "Package" {
                    foreach ($package in $Recommendation.Implementation.Packages) {
                        & winget install $package --silent --accept-source-agreements
                        if ($LASTEXITCODE -ne 0) {
                            throw "Package installation failed: $package"
                        }
                    }
                    $result.Success = $true
                    $result.Message = "Packages installed successfully"
                }
                default {
                    $result.Success = $false
                    $result.Message = "Unknown implementation type: $($Recommendation.Implementation.Type)"
                }
            }
        } catch {
            $result.Success = $false
            $result.Message = "Error applying recommendation: $($_.Exception.Message)"
        }

        return $result
    }
}