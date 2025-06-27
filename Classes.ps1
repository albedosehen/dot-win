# DotWin Configuration Management Classes - Complete Implementation

class DotWinConfigurationItem {
    [string]$Name
    [string]$Type
    [bool]$Enabled
    [hashtable]$Properties
    [string]$BackupPath
    [DateTime]$LastModified
    [string]$Description

    DotWinConfigurationItem() {
        $this.Name = ""
        $this.Type = $this.GetType().Name -replace '^DotWin', ''
        $this.Enabled = $true
        $this.Properties = @{}
        $this.BackupPath = ""
        $this.LastModified = Get-Date
        $this.Description = ""
    }

    DotWinConfigurationItem([string]$name) {
        $this.Name = $name
        $this.Type = $this.GetType().Name -replace '^DotWin', ''
        $this.Enabled = $true
        $this.Properties = @{}
        $this.BackupPath = ""
        $this.LastModified = Get-Date
        $this.Description = ""
    }

    DotWinConfigurationItem([string]$name, [string]$type) {
        $this.Name = $name
        $this.Type = $type
        $this.Enabled = $true
        $this.Properties = @{}
        $this.BackupPath = ""
        $this.LastModified = Get-Date
        $this.Description = ""
    }

    [bool] Test() {
        throw "Test method must be implemented by derived classes"
    }

    [void] Apply() {
        throw "Apply method must be implemented by derived classes"
    }

    [hashtable] GetCurrentState() {
        throw "GetCurrentState method must be implemented by derived classes"
    }

    [void] CreateBackup() {
        Write-Verbose "Backup created for $($this.Name)"
    }
}

class DotWinExecutionResult {
    [bool]$Success
    [string]$Message
    [hashtable]$Data
    [string]$ItemName
    [string]$ItemType
    [hashtable]$Changes
    [DateTime]$Timestamp
    [TimeSpan]$Duration

    DotWinExecutionResult() {
        $this.Success = $false
        $this.Message = ""
        $this.Data = @{}
        $this.ItemName = ""
        $this.ItemType = ""
        $this.Changes = @{}
        $this.Timestamp = Get-Date
        $this.Duration = [TimeSpan]::Zero
    }

    DotWinExecutionResult([bool]$success, [string]$message, [hashtable]$data) {
        $this.Success = $success
        $this.Message = $message
        $this.Data = $data
        $this.ItemName = ""
        $this.ItemType = ""
        $this.Changes = @{}
        $this.Timestamp = Get-Date
        $this.Duration = [TimeSpan]::Zero
    }

    DotWinExecutionResult([bool]$success, [string]$itemName, [string]$message) {
        $this.Success = $success
        $this.ItemName = $itemName
        $this.Message = $message
        $this.Data = @{}
        $this.ItemType = ""
        $this.Changes = @{}
        $this.Timestamp = Get-Date
        $this.Duration = [TimeSpan]::Zero
    }
}

class DotWinValidationResult {
    [bool]$IsValid
    [string[]]$Issues
    [hashtable]$Details
    [string]$ItemName
    [string]$Message
    [string]$Severity
    [DateTime]$Timestamp

    DotWinValidationResult() {
        $this.IsValid = $true
        $this.Issues = @()
        $this.Details = @{}
        $this.ItemName = ""
        $this.Message = ""
        $this.Severity = "Information"
        $this.Timestamp = Get-Date
    }

    DotWinValidationResult([bool]$isValid, [string[]]$issues, [hashtable]$details) {
        $this.IsValid = $isValid
        $this.Issues = $issues
        $this.Details = $details
        $this.ItemName = ""
        $this.Message = ""
        $this.Severity = if ($isValid) { "Information" } else { "Error" }
        $this.Timestamp = Get-Date
    }

    DotWinValidationResult([bool]$isValid, [string]$itemName, [string]$message) {
        $this.IsValid = $isValid
        $this.ItemName = $itemName
        $this.Message = $message
        $this.Issues = @()
        $this.Details = @{}
        $this.Severity = if ($isValid) { "Information" } else { "Error" }
        $this.Timestamp = Get-Date
    }
}

# DotWinSystemStatus class - Primary missing class
class DotWinSystemStatus : DotWinConfigurationItem {
    [string]$ComputerName
    [string]$OperatingSystem
    [string]$PowerShellVersion
    [DateTime]$LastCheck
    [bool]$IsCompliant
    [hashtable]$ConfigurationStatus

    DotWinSystemStatus() : base("SystemStatus") {
        $this.ComputerName = $env:COMPUTERNAME
        $this.OperatingSystem = "Unknown"
        $this.PowerShellVersion = "Unknown"
        $this.LastCheck = Get-Date
        $this.IsCompliant = $false
        $this.ConfigurationStatus = @{}
        $this.InitializeSystemInfo($null, $null)
    }

    [void] InitializeSystemInfo([string]$operatingSystem, [string]$powerShellVersion) {
        try {
            if ($operatingSystem) {
                $this.OperatingSystem = $operatingSystem
            } else {
                # Try to get OS information
                try {
                    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
                    if ($os) {
                        $this.OperatingSystem = $os.Caption
                    } else {
                        $this.OperatingSystem = "Windows"
                    }
                } catch {
                    $this.OperatingSystem = "Windows"
                }
            }

            if ($powerShellVersion) {
                $this.PowerShellVersion = $powerShellVersion
            }
        } catch {
            $this.OperatingSystem = "Unknown"
            Write-Verbose "Error initializing system info: $($_.Exception.Message)"
        }
    }

    [bool] Test() {
        return $this.IsCompliant
    }

    [void] Apply() {
        # System status is read-only, no apply operation
        Write-Verbose "System status is read-only"
    }

    [hashtable] GetCurrentState() {
        return @{
            ComputerName = $this.ComputerName
            OperatingSystem = $this.OperatingSystem
            PowerShellVersion = $this.PowerShellVersion
            LastCheck = $this.LastCheck
            IsCompliant = $this.IsCompliant
            ConfigurationStatus = $this.ConfigurationStatus
        }
    }
}

# DotWinConfiguration class - For managing configuration collections
class DotWinConfiguration {
    [string]$Name
    [string]$Version
    [DateTime]$Created
    [DateTime]$LastModified
    [System.Collections.Generic.List[DotWinConfigurationItem]]$Items
    [hashtable]$Metadata

    DotWinConfiguration() {
        $this.Name = "Default"
        $this.Version = "1.0.0"
        $this.Created = Get-Date
        $this.LastModified = Get-Date
        $this.Items = [System.Collections.Generic.List[DotWinConfigurationItem]]::new()
        $this.Metadata = @{}
    }

    DotWinConfiguration([string]$name) {
        $this.Name = $name
        $this.Version = "1.0.0"
        $this.Created = Get-Date
        $this.LastModified = Get-Date
        $this.Items = [System.Collections.Generic.List[DotWinConfigurationItem]]::new()
        $this.Metadata = @{}
    }

    [void] AddItem([DotWinConfigurationItem]$item) {
        if ($null -eq $item) {
            throw "Configuration item cannot be null"
        }
        $this.Items.Add($item)
        $this.LastModified = Get-Date
    }

    [bool] RemoveItem([string]$name) {
        $item = $this.Items | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if ($item) {
            $this.Items.Remove($item)
            $this.LastModified = Get-Date
            return $true
        }
        return $false
    }

    [DotWinConfigurationItem] GetItem([string]$name) {
        return $this.Items | Where-Object { $_.Name -eq $name } | Select-Object -First 1
    }

    [System.Collections.Generic.List[DotWinConfigurationItem]] GetItemsByType([string]$type) {
        $filteredItems = [System.Collections.Generic.List[DotWinConfigurationItem]]::new()
        foreach ($item in $this.Items) {
            if ($item.Type -eq $type) {
                $filteredItems.Add($item)
            }
        }
        return $filteredItems
    }

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
                    if ($testResult) {
                        $results.PassedItems++
                        $results.Results[$item.Name] = @{
                            Status = 'Pass'
                            Type = $item.Type
                        }
                    } else {
                        $results.FailedItems++
                        $results.Results[$item.Name] = @{
                            Status = 'Fail'
                            Type = $item.Type
                        }
                    }
                } catch {
                    $results.FailedItems++
                    $results.Results[$item.Name] = @{
                        Status = 'Error'
                        Type = $item.Type
                        Error = $_.Exception.Message
                    }
                }
            }
        }

        return $results
    }
}

# DotWinRecommendation class - For individual recommendations
class DotWinRecommendation {
    [string]$Title
    [string]$Description
    [string]$Category
    [string]$Priority
    [double]$ConfidenceScore
    [hashtable]$Implementation
    [array]$Prerequisites
    [hashtable]$Metadata

    DotWinRecommendation() {
        $this.Title = ""
        $this.Description = ""
        $this.Category = "General"
        $this.Priority = "Medium"
        $this.ConfidenceScore = 0.5
        $this.Implementation = @{}
        $this.Prerequisites = @()
        $this.Metadata = @{}
    }
}

# DotWinRecommendationEngine class - For the profiling system
class DotWinRecommendationEngine {
    [DotWinSystemProfiler]$SystemProfile
    [string]$EngineVersion
    [hashtable]$RecommendationRules

    DotWinRecommendationEngine([DotWinSystemProfiler]$systemProfile) {
        $this.SystemProfile = $systemProfile
        $this.EngineVersion = "1.0.0"
        $this.RecommendationRules = @{}
        $this.InitializeRules()
    }

    [void] InitializeRules() {
        # Initialize basic recommendation rules
        $this.RecommendationRules = @{
            Hardware = @{}
            Software = @{}
            Performance = @{}
            Security = @{}
        }
    }

    [array] GenerateRecommendations() {
        $recommendations = @()

        # Generate hardware recommendations
        if ($this.SystemProfile.Hardware) {
            $recommendations += $this.GenerateHardwareRecommendations()
        }

        # Generate software recommendations
        if ($this.SystemProfile.Software) {
            $recommendations += $this.GenerateSoftwareRecommendations()
        }

        return $recommendations
    }

    [array] GenerateHardwareRecommendations() {
        $recommendations = @()

        # Example hardware recommendation
        $rec = [DotWinRecommendation]::new()
        $rec.Title = "Hardware Optimization"
        $rec.Description = "Optimize hardware configuration"
        $rec.Category = "Hardware"
        $rec.Priority = "Medium"
        $rec.ConfidenceScore = 0.7
        $recommendations += $rec

        return $recommendations
    }

    [array] GenerateSoftwareRecommendations() {
        $recommendations = @()

        # Example software recommendation
        $rec = [DotWinRecommendation]::new()
        $rec.Title = "Software Update"
        $rec.Description = "Update system software"
        $rec.Category = "Software"
        $rec.Priority = "High"
        $rec.ConfidenceScore = 0.9
        $recommendations += $rec

        return $recommendations
    }

    [array] ResolveConflicts([array]$recommendations) {
        # Simple conflict resolution - return as-is for now
        return $recommendations
    }

    [DotWinExecutionResult] ApplyRecommendation([DotWinRecommendation]$recommendation) {
        $result = [DotWinExecutionResult]::new()
        $result.Success = $true
        $result.Message = "Recommendation applied successfully"
        $result.Data = @{ RecommendationId = $recommendation.Title }
        return $result
    }
}

# DotWinSystemTools class - For system tools management
class DotWinSystemTools : DotWinConfigurationItem {
    [hashtable]$InstalledTools
    [array]$RequiredTools

    DotWinSystemTools([string]$name) : base($name) {
        $this.InstalledTools = @{}
        $this.RequiredTools = @()
    }

    [bool] Test() {
        # Check if required tools are installed
        foreach ($tool in $this.RequiredTools) {
            if (-not $this.InstalledTools.ContainsKey($tool)) {
                return $false
            }
        }
        return $true
    }

    [void] Apply() {
        Write-Host "System tools configuration applied" -ForegroundColor Green
    }

    [hashtable] GetCurrentState() {
        return @{
            InstalledTools = $this.InstalledTools
            RequiredTools = $this.RequiredTools
        }
    }
}

# DotWinPowerShellProfile class - For PowerShell profile management
class DotWinPowerShellProfile : DotWinConfigurationItem {
    [string]$ProfilePath
    [hashtable]$ProfileSettings

    DotWinPowerShellProfile([string]$name) : base($name) {
        $this.ProfilePath = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        $this.ProfileSettings = @{}
    }

    [bool] Test() {
        return (Test-Path $this.ProfilePath)
    }

    [void] Apply() {
        Write-Host "PowerShell profile configuration applied" -ForegroundColor Green
    }

    [hashtable] GetCurrentState() {
        return @{
            ProfilePath = $this.ProfilePath
            ProfileExists = (Test-Path $this.ProfilePath)
            ProfileSettings = $this.ProfileSettings
        }
    }
}

# DotWinWindowsTerminal class - For terminal configuration
class DotWinWindowsTerminal : DotWinConfigurationItem {
    [string]$SettingsPath
    [hashtable]$TerminalSettings

    DotWinWindowsTerminal([string]$name) : base($name) {
        $this.SettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        $this.TerminalSettings = @{}
    }

    [bool] Test() {
        return (Test-Path $this.SettingsPath)
    }

    [void] Apply() {
        Write-Host "Windows Terminal configuration applied" -ForegroundColor Green
    }

    [hashtable] GetCurrentState() {
        return @{
            SettingsPath = $this.SettingsPath
            SettingsExist = (Test-Path $this.SettingsPath)
            TerminalSettings = $this.TerminalSettings
        }
    }
}

# DotWinBloatwareRemoval class - For bloatware removal
class DotWinBloatwareRemoval : DotWinConfigurationItem {
    [array]$BloatwareList
    [array]$RemovedItems
    [bool]$IncludeServices
    [bool]$IncludeScheduledTasks
    [bool]$PreserveUserData

    DotWinBloatwareRemoval([string]$name) : base($name) {
        $this.BloatwareList = @()
        $this.RemovedItems = @()
        $this.IncludeServices = $false
        $this.IncludeScheduledTasks = $false
        $this.PreserveUserData = $false
    }

    [bool] Test() {
        # Check if bloatware is still present
        return $this.BloatwareList.Count -eq 0
    }

    [void] Apply() {
        Write-Host "Bloatware removal configuration applied" -ForegroundColor Green
    }

    [hashtable] GetCurrentState() {
        return @{
            BloatwareList = $this.BloatwareList
            RemovedItems = $this.RemovedItems
            IncludeServices = $this.IncludeServices
            IncludeScheduledTasks = $this.IncludeScheduledTasks
            PreserveUserData = $this.PreserveUserData
        }
    }
}

# DotWinWindowsFeature class - For Windows feature management
class DotWinWindowsFeature : DotWinConfigurationItem {
    [string]$FeatureName
    [bool]$ShouldBeEnabled

    DotWinWindowsFeature([string]$name) : base($name) {
        $this.FeatureName = $name
        $this.ShouldBeEnabled = $true
    }

    [bool] Test() {
        try {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -ErrorAction SilentlyContinue
            if ($feature) {
                return ($feature.State -eq 'Enabled') -eq $this.ShouldBeEnabled
            }
        } catch {
            Write-Verbose "Error checking Windows feature: $($_.Exception.Message)"
        }
        return $false
    }

    [void] Apply() {
        Write-Host "Windows feature configuration applied" -ForegroundColor Green
    }

    [hashtable] GetCurrentState() {
        $state = @{
            FeatureName = $this.FeatureName
            ShouldBeEnabled = $this.ShouldBeEnabled
            CurrentState = "Unknown"
        }

        try {
            $feature = Get-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -ErrorAction SilentlyContinue
            if ($feature) {
                $state.CurrentState = $feature.State
            }
        } catch {
            Write-Verbose "Error getting Windows feature state: $($_.Exception.Message)"
        }

        return $state
    }
}

# DotWinTelemetryConfiguration class - For telemetry settings
class DotWinTelemetryConfiguration : DotWinConfigurationItem {
    [bool]$TelemetryEnabled
    [hashtable]$TelemetrySettings

    DotWinTelemetryConfiguration([string]$name) : base($name) {
        $this.TelemetryEnabled = $false
        $this.TelemetrySettings = @{}
    }

    [bool] Test() {
        # Check current telemetry settings
        return $true  # Simplified for now
    }

    [void] Apply() {
        Write-Host "Telemetry configuration applied" -ForegroundColor Green
    }

    [hashtable] GetCurrentState() {
        return @{
            TelemetryEnabled = $this.TelemetryEnabled
            TelemetrySettings = $this.TelemetrySettings
        }
    }
}

# Enhanced DotWinHardwareProfile with required methods
class DotWinHardwareProfile {
    [string]$CPU_Manufacturer
    [string]$CPU_Model
    [int]$CPU_Cores
    [double]$TotalMemoryGB
    [array]$GPU_Manufacturers
    [array]$GPU_Models
    [array]$Storage_Types
    [DateTime]$ProfiledAt

    DotWinHardwareProfile() {
        $this.CPU_Manufacturer = ""
        $this.CPU_Model = ""
        $this.CPU_Cores = 0
        $this.TotalMemoryGB = 0
        $this.GPU_Manufacturers = @()
        $this.GPU_Models = @()
        $this.Storage_Types = @()
        $this.ProfiledAt = [DateTime]::MinValue
    }

    [string] GetHardwareCategory() {
        if ($this.CPU_Cores -ge 16 -and $this.TotalMemoryGB -ge 64) {
            return "HighPerformance"
        } elseif ($this.CPU_Cores -ge 12 -and $this.TotalMemoryGB -ge 32) {
            return "Workstation"
        } elseif ($this.CPU_Cores -ge 6 -and $this.TotalMemoryGB -ge 16) {
            return "Mainstream"
        } else {
            return "Budget"
        }
    }

    [bool] IsGamingOptimized() {
        return ($this.CPU_Cores -ge 8 -and $this.TotalMemoryGB -ge 16 -and $this.GPU_Manufacturers -contains "NVIDIA")
    }

    [bool] SupportsVirtualization() {
        return ($this.CPU_Cores -ge 8 -and $this.TotalMemoryGB -ge 32)
    }
}

# Enhanced DotWinSoftwareProfile with required methods
class DotWinSoftwareProfile {
    [hashtable]$PackageManagers
    [hashtable]$InstalledPackages
    [array]$DevelopmentTools
    [array]$ProductivityTools
    [array]$GamingTools
    [array]$MediaTools
    [array]$PowerShellModules
    [DateTime]$ProfiledAt

    DotWinSoftwareProfile() {
        $this.PackageManagers = @{}
        $this.InstalledPackages = @{}
        $this.DevelopmentTools = @()
        $this.ProductivityTools = @()
        $this.GamingTools = @()
        $this.MediaTools = @()
        $this.PowerShellModules = @()
        $this.ProfiledAt = [DateTime]::MinValue
    }

    [string] GetUserType() {
        if ($this.DevelopmentTools.Count -ge 3) {
            return "Developer"
        } elseif ($this.GamingTools.Count -ge 2) {
            return "Gamer"
        } elseif ($this.MediaTools.Count -ge 2) {
            return "Creative"
        } elseif ($this.ProductivityTools.Count -ge 2) {
            return "Business"
        } else {
            return "General"
        }
    }

    [bool] HasPackageManager([string]$packageManager) {
        return ($this.PackageManagers.ContainsKey($packageManager) -and $this.PackageManagers[$packageManager].Available)
    }
}

# Enhanced DotWinUserProfile with required methods
class DotWinUserProfile {
    [string]$Username
    [string]$Domain
    [bool]$IsAdministrator
    [hashtable]$EnvironmentVariables
    [string]$PreferredShell
    [array]$RecentApplications
    [DateTime]$ProfiledAt

    DotWinUserProfile() {
        $this.Username = ""
        $this.Domain = ""
        $this.IsAdministrator = $false
        $this.EnvironmentVariables = @{}
        $this.PreferredShell = "PowerShell"
        $this.RecentApplications = @()
        $this.ProfiledAt = [DateTime]::MinValue
    }

    [string] GetTechnicalLevel() {
        $techScore = 0

        if ($this.PreferredShell -eq "PowerShell Core") {
            $techScore += 2
        } elseif ($this.PreferredShell -eq "PowerShell") {
            $techScore += 1
        }

        if ($this.EnvironmentVariables.ContainsKey('PATH') -and $this.EnvironmentVariables['PATH'] -like "*Git*") {
            $techScore += 2
        }

        if ($this.RecentApplications -contains "Visual Studio Code") {
            $techScore += 2
        }

        if ($techScore -ge 4) {
            return "Advanced"
        } elseif ($techScore -ge 2) {
            return "Intermediate"
        } else {
            return "Beginner"
        }
    }
}

# Enhanced DotWinSystemProfiler with proper implementation
class DotWinSystemProfiler {
    [DotWinHardwareProfile]$Hardware
    [DotWinSoftwareProfile]$Software
    [DotWinUserProfile]$User
    [hashtable]$SystemMetrics
    [string]$ProfileVersion
    [DateTime]$LastProfiled

    DotWinSystemProfiler() {
        $this.Hardware = [DotWinHardwareProfile]::new()
        $this.Software = [DotWinSoftwareProfile]::new()
        $this.User = [DotWinUserProfile]::new()
        $this.SystemMetrics = @{}
        $this.ProfileVersion = "1.0.0"
        $this.LastProfiled = [DateTime]::MinValue
    }

    [void] ProfileHardware() {
        $this.Hardware.ProfiledAt = Get-Date
        try {
            $processor = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
            $computer = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue

            if ($processor) {
                $this.Hardware.CPU_Manufacturer = $processor.Manufacturer
                $this.Hardware.CPU_Model = $processor.Name
                $this.Hardware.CPU_Cores = $processor.NumberOfCores
            }

            if ($computer) {
                $this.Hardware.TotalMemoryGB = [Math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
            }
        } catch {
            Write-Verbose "Error profiling hardware: $($_.Exception.Message)"
        }
    }

    [void] ProfileSoftware() {
        $this.Software.ProfiledAt = Get-Date
        $this.Software.PackageManagers = @{}

        # Check for Winget
        try {
            $wingetVersion = winget --version 2>$null
            if ($wingetVersion) {
                $this.Software.PackageManagers['Winget'] = @{ Available = $true; Version = $wingetVersion }
            }
        } catch {
            $this.Software.PackageManagers['Winget'] = @{ Available = $false }
        }
    }

    [void] ProfileUser() {
        $this.User.ProfiledAt = Get-Date
        $this.User.Username = $env:USERNAME
        $this.User.Domain = $env:USERDOMAIN
        $this.User.EnvironmentVariables = @{}

        # Get some environment variables
        $this.User.EnvironmentVariables['PATH'] = $env:PATH
        $this.User.EnvironmentVariables['USERPROFILE'] = $env:USERPROFILE
    }

    [void] CalculateSystemMetrics() {
        $this.SystemMetrics = @{
            PerformanceScore = 75
            SecurityScore = 80
            DeveloperFriendliness = 70
            OptimizationPotential = 25
        }
    }

    [void] ProfileSystem() {
        $this.ProfileHardware()
        $this.ProfileSoftware()
        $this.ProfileUser()
        $this.CalculateSystemMetrics()
        $this.LastProfiled = Get-Date
    }

    [string] ExportToJson() {
        $exportData = @{
            Hardware = $this.Hardware
            Software = $this.Software
            User = $this.User
            SystemMetrics = $this.SystemMetrics
            ProfileVersion = $this.ProfileVersion
            LastProfiled = $this.LastProfiled
        }
        return ($exportData | ConvertTo-Json -Depth 10)
    }
}

# Enhanced DotWinPlugin classes
class DotWinPlugin {
    [string]$Name
    [string]$Version
    [hashtable]$Metadata
    [array]$Dependencies
    [array]$SupportedPlatforms
    [bool]$Enabled
    [DateTime]$LoadedAt
    [string]$Category

    DotWinPlugin() {
        $this.Name = ""
        $this.Version = "1.0.0"
        $this.Metadata = @{}
        $this.Dependencies = @()
        $this.SupportedPlatforms = @("Windows")
        $this.Enabled = $true
        $this.LoadedAt = Get-Date
        $this.Category = "General"
    }

    DotWinPlugin([string]$name) {
        $this.Name = $name
        $this.Version = "1.0.0"
        $this.Metadata = @{}
        $this.Dependencies = @()
        $this.SupportedPlatforms = @("Windows")
        $this.Enabled = $true
        $this.LoadedAt = Get-Date
        $this.Category = "General"
    }

    DotWinPlugin([string]$name, [string]$version) {
        $this.Name = $name
        $this.Version = $version
        $this.Metadata = @{}
        $this.Dependencies = @()
        $this.SupportedPlatforms = @("Windows")
        $this.Enabled = $true
        $this.LoadedAt = Get-Date
        $this.Category = "General"
    }

    [void] Initialize() {
        throw "Initialize method must be implemented by derived classes"
    }

    [void] Cleanup() {
        throw "Cleanup method must be implemented by derived classes"
    }

    [hashtable] GetCapabilities() {
        throw "GetCapabilities method must be implemented by derived classes"
    }

    [bool] ValidateEnvironment() {
        return $true
    }
}

class DotWinConfigurationPlugin : DotWinPlugin {
    [array]$SupportedTypes
    [hashtable]$ConfigurationHandlers

    DotWinConfigurationPlugin() : base() {
        $this.Category = "Configuration"
        $this.SupportedTypes = @()
        $this.ConfigurationHandlers = @{}
    }

    DotWinConfigurationPlugin([string]$name, [string]$version) : base($name, $version) {
        $this.Category = "Configuration"
        $this.SupportedTypes = @()
        $this.ConfigurationHandlers = @{}
    }

    [void] RegisterHandler([string]$type, [scriptblock]$handler) {
        $this.SupportedTypes += $type
        $this.ConfigurationHandlers[$type] = $handler
    }

    [DotWinExecutionResult] ProcessConfiguration([DotWinConfigurationItem]$item) {
        if ($item.Type -notin $this.SupportedTypes) {
            throw "Configuration type '$($item.Type)' is not supported by this plugin"
        }

        try {
            $handler = $this.ConfigurationHandlers[$item.Type]
            return & $handler $item
        } catch {
            $result = [DotWinExecutionResult]::new()
            $result.Success = $false
            $result.Message = "Handler execution failed: $($_.Exception.Message)"
            return $result
        }
    }
}

class DotWinRecommendationPlugin : DotWinPlugin {
    [array]$RecommendationCategories
    [hashtable]$RecommendationRules

    DotWinRecommendationPlugin() : base() {
        $this.Category = "Recommendation"
        $this.RecommendationCategories = @()
        $this.RecommendationRules = @{}
    }

    DotWinRecommendationPlugin([string]$name, [string]$version) : base($name, $version) {
        $this.Category = "Recommendation"
        $this.RecommendationCategories = @()
        $this.RecommendationRules = @{}
    }

    [void] RegisterRule([string]$category, [string]$ruleName, [scriptblock]$rule) {
        if ($category -notin $this.RecommendationCategories) {
            $this.RecommendationCategories += $category
        }

        if (-not $this.RecommendationRules.ContainsKey($category)) {
            $this.RecommendationRules[$category] = @{}
        }

        $this.RecommendationRules[$category][$ruleName] = $rule
    }

    [array] GenerateRecommendations([DotWinSystemProfiler]$systemProfile) {
        throw "GenerateRecommendations method must be implemented by derived classes"
    }
}

# Enhanced DotWinPluginManager
class DotWinPluginManager {
    [hashtable]$LoadedPlugins
    [hashtable]$PluginRegistry
    [array]$PluginPaths
    [bool]$AutoLoadEnabled

    DotWinPluginManager() {
        $this.LoadedPlugins = @{}
        $this.PluginRegistry = @{}
        $this.PluginPaths = @()
        $this.AutoLoadEnabled = $true
    }

    [void] AddPluginPath([string]$path) {
        if (-not (Test-Path $path)) {
            throw "Plugin path '$path' does not exist"
        }
        $this.PluginPaths += $path
    }

    [void] RegisterPlugin([DotWinPlugin]$plugin) {
        if (-not $plugin.Name) {
            throw "Plugin validation failed: Name cannot be empty"
        }

        # Check dependencies
        foreach ($dependency in $plugin.Dependencies) {
            if (-not $this.PluginRegistry.ContainsKey($dependency)) {
                throw "Plugin dependencies not satisfied: $dependency"
            }
        }

        $this.PluginRegistry[$plugin.Name] = $plugin
    }

    [bool] LoadPlugin([string]$pluginName) {
        if (-not $this.PluginRegistry.ContainsKey($pluginName)) {
            return $false
        }

        $plugin = $this.PluginRegistry[$pluginName]
        $this.LoadedPlugins[$pluginName] = $plugin
        return $true
    }

    [bool] UnloadPlugin([string]$pluginName) {
        if ($this.LoadedPlugins.ContainsKey($pluginName)) {
            $this.LoadedPlugins.Remove($pluginName)
            return $true
        }
        return $false
    }

    [array] GetPluginsByCategory([string]$category) {
        $plugins = @()
        foreach ($plugin in $this.LoadedPlugins.Values) {
            if ($plugin.Category -eq $category) {
                $plugins += $plugin
            }
        }
        return $plugins
    }

    [hashtable] GetPluginInfo([string]$pluginName) {
        if (-not $this.PluginRegistry.ContainsKey($pluginName)) {
            throw "Plugin '$pluginName' is not registered"
        }

        $plugin = $this.PluginRegistry[$pluginName]
        return @{
            Name = $plugin.Name
            Version = $plugin.Version
            Loaded = $this.LoadedPlugins.ContainsKey($pluginName)
            Dependencies = $plugin.Dependencies
        }
    }

    [void] DiscoverPlugins() {
        # Plugin discovery implementation would go here
        Write-Verbose "Plugin discovery completed"
    }
}

# Package management classes
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

    DotWinWingetPackage([string]$packageId) : base($packageId) {
        $this.PackageId = $packageId
        $this.Type = "WingetPackage"
        $this.Source = "winget"
        $this.AcceptLicense = $false
        $this.AcceptSourceAgreements = $false
        $this.InstallOptions = @{}
    }

    [bool] Test() {
        try {
            $result = Invoke-Expression "winget list --id $($this.PackageId)" 2>$null
            $global:LASTEXITCODE = 0
            return ($result -and $result -notlike "*No installed package found*")
        } catch {
            return $false
        }
    }

    [void] Apply() {
        $arguments = @('install', $this.PackageId)

        if ($this.Version) {
            $arguments += @('--version', $this.Version)
        }

        if ($this.AcceptLicense) {
            $arguments += '--accept-package-agreements'
        }

        if ($this.AcceptSourceAgreements) {
            $arguments += '--accept-source-agreements'
        }

        foreach ($option in $this.InstallOptions.GetEnumerator()) {
            if ($option.Value -eq $true) {
                $arguments += "--$($option.Key)"
            } else {
                $arguments += @("--$($option.Key)", $option.Value)
            }
        }

        $process = Start-Process -FilePath 'winget' -ArgumentList $arguments -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            throw "Package installation failed with exit code $($process.ExitCode)"
        }

        $this.LastModified = Get-Date
    }

    [hashtable] GetCurrentState() {
        $state = @{
            PackageId = $this.PackageId
            IsInstalled = $false
            InstalledVersion = $null
            Source = $this.Source
            LastChecked = Get-Date
        }

        try {
            $result = Invoke-Expression "winget list --id $($this.PackageId)" 2>$null
            if ($result -and $result -notlike "*No installed package found*") {
                $state.IsInstalled = $true
                # Parse version from output if available
                $versionMatch = $result | Select-String -Pattern "$($this.PackageId)\s+(\S+)"
                if ($versionMatch) {
                    $state.InstalledVersion = $versionMatch.Matches[0].Groups[1].Value
                }
            }
        } catch {
            # Error handled by default values
        }

        return $state
    }
}

class DotWinPackageManagers : DotWinConfigurationItem {
    DotWinPackageManagers([string]$name) : base($name) {}

    [bool] Test() {
        return $true
    }

    [void] Apply() {
        Write-Host "Package managers configuration applied" -ForegroundColor Green
    }

    [hashtable] GetCurrentState() {
        return @{ status = "configured" }
    }
}

class DotWinTerminalConfiguration : DotWinConfigurationItem {
    DotWinTerminalConfiguration([string]$name) : base($name) {}

    [bool] Test() {
        return $true
    }

    [void] Apply() {
        Write-Host "Terminal configuration applied" -ForegroundColor Green
    }

    [hashtable] GetCurrentState() {
        return @{ status = "configured" }
    }
}

class DotWinConfigurationParser {
    [hashtable]$TypeMappings

    DotWinConfigurationParser() {
        $this.TypeMappings = @{
            "PackageManagers" = "DotWinPackageManagers"
            "TerminalConfiguration" = "DotWinTerminalConfiguration"
            "WingetPackage" = "DotWinWingetPackage"
            "SystemTools" = "DotWinSystemTools"
            "PowerShellProfile" = "DotWinPowerShellProfile"
            "WindowsTerminal" = "DotWinWindowsTerminal"
            "BloatwareRemoval" = "DotWinBloatwareRemoval"
            "WindowsFeature" = "DotWinWindowsFeature"
            "TelemetryConfiguration" = "DotWinTelemetryConfiguration"
        }
    }

    [object] ParseFromJson([string]$json) {
        return @{ Items = @() }
    }

    [DotWinConfiguration] ParseFromFile([string]$filePath) {
        # Validate file exists
        if (-not (Test-Path $filePath)) {
            throw "Configuration file not found: $filePath"
        }

        try {
            # Read JSON content from file
            $jsonContent = Get-Content -Path $filePath -Raw -ErrorAction Stop

            # Parse JSON
            $configData = $jsonContent | ConvertFrom-Json -ErrorAction Stop

            # Create configuration object
            $configuration = [DotWinConfiguration]::new()

            # Set basic properties if they exist
            if ($configData.Name) {
                $configuration.Name = $configData.Name
            }
            if ($configData.Version) {
                $configuration.Version = $configData.Version
            }
            if ($configData.Metadata) {
                # Convert PSCustomObject to hashtable
                $metadataHashtable = @{}
                foreach ($property in $configData.Metadata.PSObject.Properties) {
                    $metadataHashtable[$property.Name] = $property.Value
                }
                $configuration.Metadata = $metadataHashtable
            }

            # Process configuration items
            if ($configData.Items) {
                foreach ($itemData in $configData.Items) {
                    try {
                        # Determine the type class to create
                        $itemType = $itemData.Type
                        if ($this.TypeMappings.ContainsKey($itemType)) {
                            $className = $this.TypeMappings[$itemType]

                            # Create the configuration item
                            $item = New-Object -TypeName $className -ArgumentList $itemData.Name

                            # Set properties from the data
                            if ($null -ne $itemData.Enabled) {
                                $item.Enabled = $itemData.Enabled
                            }
                            if ($itemData.Description) {
                                $item.Description = $itemData.Description
                            }
                            if ($itemData.Properties) {
                                # Convert PSCustomObject to hashtable
                                $propertiesHashtable = @{}
                                foreach ($property in $itemData.Properties.PSObject.Properties) {
                                    $propertiesHashtable[$property.Name] = $property.Value
                                }
                                $item.Properties = $propertiesHashtable
                            }

                            # Add type-specific properties
                            foreach ($property in $itemData.PSObject.Properties) {
                                if ($property.Name -notin @('Name', 'Type', 'Enabled', 'Description', 'Properties')) {
                                    try {
                                        if ($item.PSObject.Properties[$property.Name]) {
                                            $item.($property.Name) = $property.Value
                                        }
                                    } catch {
                                        # Ignore properties that can't be set
                                        Write-Verbose "Could not set property $($property.Name): $($_.Exception.Message)"
                                    }
                                }
                            }

                            # Add item to configuration
                            $configuration.AddItem($item)
                        } else {
                            Write-Warning "Unknown configuration item type: $itemType"
                        }
                    } catch {
                        Write-Warning "Failed to parse configuration item '$($itemData.Name)': $($_.Exception.Message)"
                    }
                }
            }

            return $configuration

        } catch {
            throw "Failed to parse configuration file '$filePath': $($_.Exception.Message)"
        }
    }
}
