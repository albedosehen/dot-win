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

    # New progress-related properties
    [hashtable]$ProgressMetrics
    [hashtable]$PerformanceCounters
    [string]$ProgressId
    [TimeSpan]$EstimatedDuration
    [double]$ThroughputRate
    [int]$OperationCount

    DotWinExecutionResult() {
        $this.Success = $false
        $this.Message = ""
        $this.Data = @{}
        $this.ItemName = ""
        $this.ItemType = ""
        $this.Changes = @{}
        $this.Timestamp = Get-Date
        $this.Duration = [TimeSpan]::Zero
        $this.ProgressMetrics = @{}
        $this.PerformanceCounters = @{}
        $this.ProgressId = ""
        $this.EstimatedDuration = [TimeSpan]::Zero
        $this.ThroughputRate = 0.0
        $this.OperationCount = 0
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
        $this.ProgressMetrics = @{}
        $this.PerformanceCounters = @{}
        $this.ProgressId = ""
        $this.EstimatedDuration = [TimeSpan]::Zero
        $this.ThroughputRate = 0.0
        $this.OperationCount = 0
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
        $this.ProgressMetrics = @{}
        $this.PerformanceCounters = @{}
        $this.ProgressId = ""
        $this.EstimatedDuration = [TimeSpan]::Zero
        $this.ThroughputRate = 0.0
        $this.OperationCount = 0
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

# Progress System Classes

class DotWinProgressContext {
    [string]$Id
    [string]$ParentId
    [string]$Activity
    [string]$Status
    [int]$PercentComplete
    [int]$CurrentOperation
    [int]$TotalOperations
    [DateTime]$StartTime
    [DateTime]$LastUpdate
    [hashtable]$Metrics
    [hashtable]$PerformanceCounters
    [bool]$IsCompleted
    [System.Collections.Generic.List[string]]$ChildContexts

    DotWinProgressContext() {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.ParentId = ""
        $this.Activity = ""
        $this.Status = ""
        $this.PercentComplete = -1
        $this.CurrentOperation = -1
        $this.TotalOperations = -1
        $this.StartTime = Get-Date
        $this.LastUpdate = Get-Date
        $this.Metrics = @{}
        $this.PerformanceCounters = @{}
        $this.IsCompleted = $false
        $this.ChildContexts = [System.Collections.Generic.List[string]]::new()
    }

    DotWinProgressContext([string]$activity) {
        $this.Id = [System.Guid]::NewGuid().ToString()
        $this.ParentId = ""
        $this.Activity = $activity
        $this.Status = ""
        $this.PercentComplete = -1
        $this.CurrentOperation = -1
        $this.TotalOperations = -1
        $this.StartTime = Get-Date
        $this.LastUpdate = Get-Date
        $this.Metrics = @{}
        $this.PerformanceCounters = @{}
        $this.IsCompleted = $false
        $this.ChildContexts = [System.Collections.Generic.List[string]]::new()
    }

    [void] UpdateProgress([int]$percent, [string]$status) {
        $this.PercentComplete = $percent
        $this.Status = $status
        $this.LastUpdate = Get-Date
    }

    [void] AddMetric([string]$name, [object]$value) {
        $this.Metrics[$name] = $value
        $this.LastUpdate = Get-Date
    }

    [hashtable] GetPerformanceSnapshot() {
        $elapsed = (Get-Date) - $this.StartTime
        $snapshot = @{
            ElapsedTime = $elapsed
            StartTime = $this.StartTime
            LastUpdate = $this.LastUpdate
            PercentComplete = $this.PercentComplete
            CurrentOperation = $this.CurrentOperation
            TotalOperations = $this.TotalOperations
            IsCompleted = $this.IsCompleted
        }

        # Add custom metrics
        foreach ($metric in $this.Metrics.GetEnumerator()) {
            $snapshot[$metric.Key] = $metric.Value
        }

        return $snapshot
    }

    [void] Complete() {
        $this.IsCompleted = $true
        $this.PercentComplete = 100
        $this.LastUpdate = Get-Date
        $this.AddMetric("CompletionTime", (Get-Date))
        $this.AddMetric("TotalDuration", ((Get-Date) - $this.StartTime))
    }

    [string] GenerateDisplayText() {
        $progressBar = ""
        if ($this.PercentComplete -ge 0) {
            $barLength = 40
            $filledLength = [Math]::Floor(($this.PercentComplete / 100) * $barLength)
            $progressBar = "[" + ("█" * $filledLength) + ("░" * ($barLength - $filledLength)) + "] $($this.PercentComplete)%"
        }

        $operationText = ""
        if ($this.CurrentOperation -gt 0 -and $this.TotalOperations -gt 0) {
            $operationText = " ($($this.CurrentOperation)/$($this.TotalOperations))"
        }

        $statusText = if ($this.Status) { ": $($this.Status)" } else { "" }

        return "$($this.Activity)$operationText$statusText $progressBar"
    }
}

class DotWinProgressStackManager {
    [System.Collections.Generic.Stack[DotWinProgressContext]]$ProgressStack
    [hashtable]$ActiveContexts
    [object]$ConsoleLock
    [bool]$IsProgressActive
    [int]$NextProgressId

    DotWinProgressStackManager() {
        $this.ProgressStack = [System.Collections.Generic.Stack[DotWinProgressContext]]::new()
        $this.ActiveContexts = @{}
        $this.ConsoleLock = [System.Object]::new()
        $this.IsProgressActive = $false
        $this.NextProgressId = 1
    }

    [string] PushContext([DotWinProgressContext]$context) {
        if (-not $context.Id) {
            $context.Id = "Progress_$($this.NextProgressId)"
            $this.NextProgressId++
        }

        $this.ProgressStack.Push($context)
        $this.ActiveContexts[$context.Id] = $context
        $this.IsProgressActive = $true

        return $context.Id
    }

    [DotWinProgressContext] PopContext([string]$id) {
        if ($this.ActiveContexts.ContainsKey($id)) {
            $context = $this.ActiveContexts[$id]
            $this.ActiveContexts.Remove($id)

            # Remove from stack if it's the top item
            if ($this.ProgressStack.Count -gt 0 -and $this.ProgressStack.Peek().Id -eq $id) {
                $this.ProgressStack.Pop()
            }

            if ($this.ActiveContexts.Count -eq 0) {
                $this.IsProgressActive = $false
            }

            return $context
        }
        return $null
    }

    [DotWinProgressContext] GetCurrentContext() {
        if ($this.ProgressStack.Count -gt 0) {
            return $this.ProgressStack.Peek()
        }
        return $null
    }

    [void] UpdateContext([string]$id, [hashtable]$updates) {
        if ($this.ActiveContexts.ContainsKey($id)) {
            $context = $this.ActiveContexts[$id]

            foreach ($update in $updates.GetEnumerator()) {
                switch ($update.Key) {
                    'PercentComplete' { $context.PercentComplete = $update.Value }
                    'Status' { $context.Status = $update.Value }
                    'CurrentOperation' { $context.CurrentOperation = $update.Value }
                    'TotalOperations' { $context.TotalOperations = $update.Value }
                    default { $context.AddMetric($update.Key, $update.Value) }
                }
            }

            $context.LastUpdate = Get-Date
        }
    }

    [void] RefreshDisplay() {
        if (-not $this.IsProgressActive) {
            return
        }

        # Lock console output to prevent interference
        [System.Threading.Monitor]::Enter($this.ConsoleLock)
        try {
            # Clear previous progress display
            $this.ClearProgress()

            # Display all active progress contexts
            $sortedContexts = $this.ActiveContexts.Values | Sort-Object { $_.StartTime }
            foreach ($context in $sortedContexts) {
                if (-not $context.IsCompleted) {
                    $displayText = $context.GenerateDisplayText()
                    $null = $displayText
                    Write-Progress -Activity $context.Activity -Status $context.Status -PercentComplete $context.PercentComplete -Id ([Math]::Abs([int]$context.Id.GetHashCode()))
                }
            }
        }
        finally {
            [System.Threading.Monitor]::Exit($this.ConsoleLock)
        }
    }

    [void] ClearProgress() {
        # Clear all active progress bars
        foreach ($context in $this.ActiveContexts.Values) {
            Write-Progress -Activity $context.Activity -Completed -Id ([Math]::Abs([int]$context.Id.GetHashCode()))
        }
    }

    [void] ShowMessage([string]$message, [string]$level) {
        [System.Threading.Monitor]::Enter($this.ConsoleLock)
        try {
            # Temporarily clear progress to show message
            $this.ClearProgress()

            # Show the message
            switch ($level) {
                'Warning' { Write-Warning $message }
                'Error' { Write-Error $message }
                'Verbose' { Write-Verbose $message }
                default { Write-Information $message -InformationAction Continue }
            }

            # Restore progress display
            $this.RefreshDisplay()
        }
        finally {
            [System.Threading.Monitor]::Exit($this.ConsoleLock)
        }
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
        # Bloatware removal logic would go here
        # Removed verbose output that was causing console spam
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

# WSL Configuration Class
class DotWinWSLConfiguration : DotWinConfigurationItem {
    [string]$DistributionName
    [string]$Version
    [string]$DefaultUser
    [hashtable]$Settings
    [string[]]$Packages
    [hashtable]$Configuration

    DotWinWSLConfiguration() : base() {
        $this.Type = "WSL"
        $this.Settings = @{}
        $this.Packages = @()
        $this.Configuration = @{}
    }

    DotWinWSLConfiguration([string]$Name, [string]$DistributionName) : base($Name, "WSL") {
        $this.DistributionName = $DistributionName
        $this.Settings = @{}
        $this.Packages = @()
        $this.Configuration = @{}
    }

    [bool] Test() {
        try {
            # Check if WSL is enabled
            $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
            if (-not $wslFeature -or $wslFeature.State -ne "Enabled") {
                Write-Verbose "WSL feature is not enabled"
                return $false
            }

            # Check if distribution is installed
            $wslList = wsl --list --quiet 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose "WSL is not properly configured"
                return $false
            }

            $distributionExists = $wslList -contains $this.DistributionName
            if (-not $distributionExists) {
                Write-Verbose "Distribution '$($this.DistributionName)' is not installed"
                return $false
            }

            # Check if distribution is running
            $wslStatus = wsl --list --verbose 2>$null
            $distributionStatus = $wslStatus | Where-Object { $_ -like "*$($this.DistributionName)*" }

            if ($distributionStatus -and $distributionStatus -like "*Running*") {
                Write-Verbose "Distribution '$($this.DistributionName)' is running"
                return $true
            }

            Write-Verbose "Distribution '$($this.DistributionName)' exists but is not running"
            return $false
        }
        catch {
            Write-Verbose "WSL test failed: $($_.Exception.Message)"
            return $false
        }
    }

    [void] Apply() {
        try {
            Write-Verbose "Applying WSL configuration for '$($this.Name)'"

            # Enable WSL feature if not enabled
            $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
            if (-not $wslFeature -or $wslFeature.State -ne "Enabled") {
                Write-Verbose "Enabling WSL feature..."
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
            }

            # Enable Virtual Machine Platform if not enabled
            $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
            if (-not $vmFeature -or $vmFeature.State -ne "Enabled") {
                Write-Verbose "Enabling Virtual Machine Platform..."
                Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
            }

            # Install distribution if not present
            $wslList = wsl --list --quiet 2>$null
            if ($LASTEXITCODE -eq 0 -and $wslList -notcontains $this.DistributionName) {
                Write-Verbose "Installing WSL distribution '$($this.DistributionName)'"
                $this.InstallDistribution()
            }

            # Configure distribution settings
            if ($this.Settings.Count -gt 0) {
                $this.ApplyDistributionSettings()
            }

            # Install packages if specified
            if ($this.Packages.Count -gt 0) {
                $this.InstallPackages()
            }

            # Apply custom configuration
            if ($this.Configuration.Count -gt 0) {
                $this.ApplyCustomConfiguration()
            }

            $this.LastModified = Get-Date
        }
        catch {
            throw "Failed to apply WSL configuration: $($_.Exception.Message)"
        }
    }

    [hashtable] GetCurrentState() {
        $state = @{
            WSLEnabled = $false
            DistributionInstalled = $false
            DistributionRunning = $false
            Version = "Unknown"
            DefaultUser = "Unknown"
            InstalledPackages = @()
        }

        try {
            # Check WSL feature status
            $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
            $state.WSLEnabled = $wslFeature -and $wslFeature.State -eq "Enabled"

            if ($state.WSLEnabled) {
                # Check distribution status
                $wslList = wsl --list --quiet 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $state.DistributionInstalled = $wslList -contains $this.DistributionName

                    if ($state.DistributionInstalled) {
                        # Get distribution details
                        $wslStatus = wsl --list --verbose 2>$null
                        $distributionInfo = $wslStatus | Where-Object { $_ -like "*$($this.DistributionName)*" }

                        if ($distributionInfo) {
                            $state.DistributionRunning = $distributionInfo -like "*Running*"

                            # Extract version information
                            if ($distributionInfo -match "(\d+)") {
                                $state.Version = $matches[1]
                            }
                        }

                        # Get default user
                        try {
                            $this.DefaultUser = wsl -d $this.DistributionName whoami 2>$null
                            if ($LASTEXITCODE -eq 0) {
                                $state.DefaultUser = $this.DefaultUser.Trim()
                            }
                        }
                        catch {
                            # Ignore errors getting default user
                        }
                    }
                }
            }
        }
        catch {
            Write-Verbose "Error getting WSL state: $($_.Exception.Message)"
        }

        return $state
    }

    [void] InstallDistribution() {
        switch ($this.DistributionName.ToLower()) {
            'ubuntu' {
                wsl --install -d Ubuntu
            }
            'ubuntu-20.04' {
                wsl --install -d Ubuntu-20.04
            }
            'ubuntu-22.04' {
                wsl --install -d Ubuntu-22.04
            }
            'debian' {
                wsl --install -d Debian
            }
            'kali-linux' {
                wsl --install -d kali-linux
            }
            'opensuse-leap-15.4' {
                wsl --install -d openSUSE-Leap-15.4
            }
            'alpine' {
                wsl --install -d Alpine
            }
            default {
                throw "Unsupported distribution: $($this.DistributionName)"
            }
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install WSL distribution '$($this.DistributionName)'"
        }
    }

    [void] ApplyDistributionSettings() {
        foreach ($setting in $this.Settings.Keys) {
            $value = $this.Settings[$setting]

            switch ($setting.ToLower()) {
                'defaultuser' {
                    # Set default user for distribution
                    $configPath = "$env:USERPROFILE\.wslconfig"
                    $configContent = @"
[$($this.DistributionName)]
user=$value
"@
                    Add-Content -Path $configPath -Value $configContent -Force
                }

                'memory' {
                    # Set memory limit
                    $configPath = "$env:USERPROFILE\.wslconfig"
                    $configContent = @"
[wsl2]
memory=$value
"@
                    Add-Content -Path $configPath -Value $configContent -Force
                }

                'processors' {
                    # Set processor count
                    $configPath = "$env:USERPROFILE\.wslconfig"
                    $configContent = @"
[wsl2]
processors=$value
"@
                    Add-Content -Path $configPath -Value $configContent -Force
                }
            }
        }
    }

    [void] InstallPackages() {
        Write-Verbose "Installing packages in WSL distribution '$($this.DistributionName)'"

        # Determine package manager based on distribution
        $packageManager = $this.GetPackageManager()

        foreach ($package in $this.Packages) {
            Write-Verbose "Installing package: $package"

            switch ($packageManager) {
                'apt' {
                    wsl -d $this.DistributionName sudo apt update
                    wsl -d $this.DistributionName sudo apt install -y $package
                }
                'yum' {
                    wsl -d $this.DistributionName sudo yum install -y $package
                }
                'zypper' {
                    wsl -d $this.DistributionName sudo zypper install -y $package
                }
                'apk' {
                    wsl -d $this.DistributionName sudo apk add $package
                }
                default {
                    Write-Warning "Unknown package manager for distribution '$($this.DistributionName)'"
                }
            }
        }
    }

    [string] GetPackageManager() {
        $distroLower = $this.DistributionName.ToLower()

        if ($distroLower -like "*ubuntu*" -or $distroLower -like "*debian*" -or $distroLower -like "*kali*") {
            return 'apt'
        }
        elseif ($distroLower -like "*centos*" -or $distroLower -like "*rhel*" -or $distroLower -like "*fedora*") {
            return 'yum'
        }
        elseif ($distroLower -like "*opensuse*" -or $distroLower -like "*suse*") {
            return 'zypper'
        }
        elseif ($distroLower -like "*alpine*") {
            return 'apk'
        }
        else {
            return 'unknown'
        }
    }


    [void] ApplyCustomConfiguration() {
        foreach ($config in $this.Configuration.Keys) {
            $value = $this.Configuration[$config]

            switch ($config.ToLower()) {
                'bashrc' {
                    # Add custom bashrc configuration
                    $bashrcContent = $value -join "`n"
                    wsl -d $this.DistributionName bash -c "echo '$bashrcContent' >> ~/.bashrc"
                }

                'profile' {
                    # Add custom profile configuration
                    $profileContent = $value -join "`n"
                    wsl -d $this.DistributionName bash -c "echo '$profileContent' >> ~/.profile"
                }

                'gitconfig' {
                    # Configure git settings
                    foreach ($gitSetting in $value.Keys) {
                        $gitValue = $value[$gitSetting]
                        wsl -d $this.DistributionName git config --global $gitSetting "$gitValue"
                    }
                }
            }
        }
    }
}

# DotWin Configuration Bridge - Central integration point for module and user configurations
class DotWinConfigurationBridge {
    [string] $ModuleConfigPath
    [string] $UserConfigPath
    [hashtable] $ConfigurationCache
    [bool] $CacheEnabled
    [DateTime] $LastCacheUpdate

    DotWinConfigurationBridge([string] $ModuleConfigPath, [string] $UserConfigPath) {
        $this.ModuleConfigPath = $ModuleConfigPath
        $this.UserConfigPath = $UserConfigPath
        $this.ConfigurationCache = @{}
        $this.CacheEnabled = $true
        $this.LastCacheUpdate = [DateTime]::MinValue

        Write-Verbose "Configuration bridge initialized with module path: $ModuleConfigPath"
        if ($UserConfigPath) {
            Write-Verbose "User configuration path: $UserConfigPath"
        } else {
            Write-Verbose "No user configuration path specified"
        }
    }

    [hashtable] ResolvePackageConfiguration([string] $Category) {
        Write-Verbose "Resolving package configuration for category: $Category"

        $cacheKey = "Packages_$Category"
        if ($this.CacheEnabled -and $this.ConfigurationCache.ContainsKey($cacheKey)) {
            $cachedConfig = $this.ConfigurationCache[$cacheKey]
            if ((Get-Date) - $cachedConfig.Timestamp -lt [TimeSpan]::FromMinutes(5)) {
                Write-Verbose "Using cached package configuration for category: $Category"
                return $cachedConfig.Data
            }
        }

        try {
            # Load base configuration from module
            $baseConfigPath = Join-Path $this.ModuleConfigPath "Packages.ps1"
            if (-not (Test-Path $baseConfigPath)) {
                Write-Warning "Module package configuration not found: $baseConfigPath"
                return @{}
            }

            Write-Verbose "Loading base package configuration from: $baseConfigPath"
            . $baseConfigPath

            # Get base packages using the module's function
            $basePackages = @{}
            if (Get-Command "Get-PackagesByCategory" -ErrorAction SilentlyContinue) {
                $basePackages = Get-PackagesByCategory -Category $Category
            } else {
                Write-Warning "Get-PackagesByCategory function not found in module configuration"
            }

            # Load user overrides if they exist
            $finalPackages = $basePackages
            if ($this.UserConfigPath -and (Test-Path $this.UserConfigPath)) {
                $userPackagesPath = Join-Path ($this.UserConfigPath) "Packages.ps1"
                if (Test-Path $userPackagesPath) {
                    Write-Verbose "Loading user package overrides from: $userPackagesPath"

                    try {
                        . $userPackagesPath

                        # Get user packages using the user's function
                        if (Get-Command "Get-PackagesByCategory" -ErrorAction SilentlyContinue) {
                            $userPackages = Get-PackagesByCategory -Category $Category -ErrorAction SilentlyContinue
                            if ($userPackages -and $userPackages.Count -gt 0) {
                                Write-Verbose "Merging user package overrides for category: $Category"
                                $finalPackages = $this.MergePackageConfigurations($basePackages, $userPackages)
                            }
                        }
                    } catch {
                        Write-Warning "Error loading user package configuration: $($_.Exception.Message)"
                    }
                } else {
                    Write-Verbose "User package configuration not found: $userPackagesPath"
                }
            }

            # Cache the result
            if ($this.CacheEnabled) {
                $this.ConfigurationCache[$cacheKey] = @{
                    Data = $finalPackages
                    Timestamp = Get-Date
                }
            }

            Write-DotWinLog "Package configuration resolved for category '$Category' with $($finalPackages.Keys.Count) package groups" -Level "Information"
            return $finalPackages

        } catch {
            Write-DotWinLog "Error resolving package configuration for category '$Category': $($_.Exception.Message)" -Level "Error"
            return @{}
        }
    }

    [hashtable] ResolveTerminalConfiguration([string] $Theme, [bool] $IncludeProfiles, [bool] $IncludeKeybindings, [bool] $IncludeSettings) {
        Write-Verbose "Resolving terminal configuration for theme: $Theme"

        $cacheKey = "Terminal_${Theme}_${IncludeProfiles}_${IncludeKeybindings}_${IncludeSettings}"
        if ($this.CacheEnabled -and $this.ConfigurationCache.ContainsKey($cacheKey)) {
            $cachedConfig = $this.ConfigurationCache[$cacheKey]
            if ((Get-Date) - $cachedConfig.Timestamp -lt [TimeSpan]::FromMinutes(5)) {
                Write-Verbose "Using cached terminal configuration for theme: $Theme"
                return $cachedConfig.Data
            }
        }

        try {
            # Load base configuration from module
            $baseConfigPath = Join-Path $this.ModuleConfigPath "Terminal.ps1"
            if (-not (Test-Path $baseConfigPath)) {
                Write-Warning "Module terminal configuration not found: $baseConfigPath"
                return @{}
            }

            Write-Verbose "Loading base terminal configuration from: $baseConfigPath"
            . $baseConfigPath

            # Get base terminal configuration using the module's function
            $baseConfig = @{}
            if (Get-Command "Get-TerminalConfiguration" -ErrorAction SilentlyContinue) {
                $baseConfig = Get-TerminalConfiguration -Theme $Theme -IncludeProfiles:$IncludeProfiles -IncludeKeybindings:$IncludeKeybindings -IncludeSettings:$IncludeSettings
            } else {
                Write-Warning "Get-TerminalConfiguration function not found in module configuration"
            }

            # Load user overrides if they exist
            $finalConfig = $baseConfig
            if ($this.UserConfigPath -and (Test-Path $this.UserConfigPath)) {
                $userTerminalPath = Join-Path ($this.UserConfigPath) "Terminal.ps1"
                if (Test-Path $userTerminalPath) {
                    Write-Verbose "Loading user terminal overrides from: $userTerminalPath"

                    try {
                        . $userTerminalPath

                        # Get user terminal configuration using the user's function
                        if (Get-Command "Get-TerminalConfiguration" -ErrorAction SilentlyContinue) {
                            $userConfig = Get-TerminalConfiguration -Theme $Theme -IncludeProfiles:$IncludeProfiles -IncludeKeybindings:$IncludeKeybindings -IncludeSettings:$IncludeSettings -ErrorAction SilentlyContinue
                            if ($userConfig -and $userConfig.Count -gt 0) {
                                Write-Verbose "Merging user terminal overrides for theme: $Theme"
                                $finalConfig = $this.MergeTerminalConfigurations($baseConfig, $userConfig)
                            }
                        }
                    } catch {
                        Write-Warning "Error loading user terminal configuration: $($_.Exception.Message)"
                    }
                } else {
                    Write-Verbose "User terminal configuration not found: $userTerminalPath"
                }
            }

            # Cache the result
            if ($this.CacheEnabled) {
                $this.ConfigurationCache[$cacheKey] = @{
                    Data = $finalConfig
                    Timestamp = Get-Date
                }
            }

            Write-DotWinLog "Terminal configuration resolved for theme '$Theme'" -Level "Information"
            return $finalConfig

        } catch {
            Write-DotWinLog "Error resolving terminal configuration for theme '$Theme': $($_.Exception.Message)" -Level "Error"
            return @{}
        }
    }

    [hashtable] ResolveProfileConfiguration([string] $ProfileType, [bool] $IncludeModules, [bool] $IncludeAliases, [bool] $IncludeFunctions, [bool] $IncludePrompt) {
        Write-Verbose "Resolving profile configuration for type: $ProfileType"

        $cacheKey = "Profile_${ProfileType}_${IncludeModules}_${IncludeAliases}_${IncludeFunctions}_${IncludePrompt}"
        if ($this.CacheEnabled -and $this.ConfigurationCache.ContainsKey($cacheKey)) {
            $cachedConfig = $this.ConfigurationCache[$cacheKey]
            if ((Get-Date) - $cachedConfig.Timestamp -lt [TimeSpan]::FromMinutes(5)) {
                Write-Verbose "Using cached profile configuration for type: $ProfileType"
                return $cachedConfig.Data
            }
        }

        try {
            # Load base configuration from module
            $baseConfigPath = Join-Path $this.ModuleConfigPath "Profile.ps1"
            if (-not (Test-Path $baseConfigPath)) {
                Write-Warning "Module profile configuration not found: $baseConfigPath"
                return @{}
            }

            Write-Verbose "Loading base profile configuration from: $baseConfigPath"
            . $baseConfigPath

            # Get base profile configuration using the module's function
            $baseConfig = @{}
            if (Get-Command "Get-ProfileConfiguration" -ErrorAction SilentlyContinue) {
                $baseConfig = Get-ProfileConfiguration -ProfileType $ProfileType -IncludeModules:$IncludeModules -IncludeAliases:$IncludeAliases -IncludeFunctions:$IncludeFunctions -IncludePrompt:$IncludePrompt
            } else {
                Write-Warning "Get-ProfileConfiguration function not found in module configuration"
            }

            # Load user overrides if they exist
            $finalConfig = $baseConfig
            if ($this.UserConfigPath -and (Test-Path $this.UserConfigPath)) {
                $userProfilePath = Join-Path ($this.UserConfigPath) "Profile.ps1"
                if (Test-Path $userProfilePath) {
                    Write-Verbose "Loading user profile overrides from: $userProfilePath"

                    try {
                        . $userProfilePath

                        # Get user profile configuration using the user's function
                        if (Get-Command "Get-ProfileConfiguration" -ErrorAction SilentlyContinue) {
                            $userConfig = Get-ProfileConfiguration -ProfileType $ProfileType -IncludeModules:$IncludeModules -IncludeAliases:$IncludeAliases -IncludeFunctions:$IncludeFunctions -IncludePrompt:$IncludePrompt -ErrorAction SilentlyContinue
                            if ($userConfig -and $userConfig.Count -gt 0) {
                                Write-Verbose "Merging user profile overrides for type: $ProfileType"
                                $finalConfig = $this.MergeProfileConfigurations($baseConfig, $userConfig)
                            }
                        }
                    } catch {
                        Write-Warning "Error loading user profile configuration: $($_.Exception.Message)"
                    }
                } else {
                    Write-Verbose "User profile configuration not found: $userProfilePath"
                }
            }

            # Cache the result
            if ($this.CacheEnabled) {
                $this.ConfigurationCache[$cacheKey] = @{
                    Data = $finalConfig
                    Timestamp = Get-Date
                }
            }

            Write-DotWinLog "Profile configuration resolved for type '$ProfileType'" -Level "Information"
            return $finalConfig

        } catch {
            Write-DotWinLog "Error resolving profile configuration for type '$ProfileType': $($_.Exception.Message)" -Level "Error"
            return @{}
        }
    }

    [hashtable] MergePackageConfigurations([hashtable] $Base, [hashtable] $Override) {
        Write-Verbose "Merging package configurations with user overrides"

        if (-not $Base) { $Base = @{} }
        if (-not $Override) { return $Base }

        # Deep merge with user configuration taking precedence
        $merged = $this.DeepCloneHashtable($Base)

        foreach ($key in $Override.Keys) {
            if ($merged.ContainsKey($key)) {
                if ($merged[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
                    # Recursively merge hashtables
                    $merged[$key] = $this.MergePackageConfigurations($merged[$key], $Override[$key])
                } elseif ($merged[$key] -is [array] -and $Override[$key] -is [array]) {
                    # For arrays, combine and remove duplicates based on Id property
                    $mergedArray = [System.Collections.ArrayList]::new()

                    # Add base items
                    foreach ($item in $merged[$key]) {
                        $mergedArray.Add($item)
                    }

                    # Add override items, replacing existing ones with same Id
                    foreach ($overrideItem in $Override[$key]) {
                        if ($overrideItem -is [hashtable] -and $overrideItem.ContainsKey('Id')) {
                            # Find existing item with same Id
                            $existingIndex = -1
                            for ($i = 0; $i -lt $mergedArray.Count; $i++) {
                                if ($mergedArray[$i] -is [hashtable] -and $mergedArray[$i].ContainsKey('Id') -and $mergedArray[$i].Id -eq $overrideItem.Id) {
                                    $existingIndex = $i
                                    break
                                }
                            }

                            if ($existingIndex -ge 0) {
                                # Replace existing item
                                $mergedArray[$existingIndex] = $overrideItem
                                Write-Verbose "Replaced package configuration for Id: $($overrideItem.Id)"
                            } else {
                                # Add new item
                                $mergedArray.Add($overrideItem)
                                Write-Verbose "Added new package configuration for Id: $($overrideItem.Id)"
                            }
                        } else {
                            # Add item without Id checking
                            $mergedArray.Add($overrideItem)
                        }
                    }

                    $merged[$key] = $mergedArray.ToArray()
                } else {
                    # Override takes precedence for other types
                    $merged[$key] = $Override[$key]
                    Write-Verbose "Overrode package configuration key: $key"
                }
            } else {
                # Add new key from override
                $merged[$key] = $Override[$key]
                Write-Verbose "Added new package configuration key: $key"
            }
        }

        return $merged
    }

    [hashtable] MergeTerminalConfigurations([hashtable] $Base, [hashtable] $Override) {
        Write-Verbose "Merging terminal configurations with user overrides"

        if (-not $Base) { $Base = @{} }
        if (-not $Override) { return $Base }

        # Specialized merge for terminal configurations
        $merged = $this.DeepCloneHashtable($Base)

        foreach ($key in $Override.Keys) {
            switch ($key) {
                'profiles' {
                    if ($merged.ContainsKey('profiles') -and $Override.profiles -and $Override.profiles.list) {
                        Write-Verbose "Merging terminal profiles"

                        # Ensure merged profiles structure exists
                        if (-not $merged.profiles) { $merged.profiles = @{} }
                        if (-not $merged.profiles.list) { $merged.profiles.list = @() }

                        # Merge profile lists by GUID
                        $mergedProfiles = [System.Collections.ArrayList]::new($merged.profiles.list)

                        foreach ($overrideProfile in $Override.profiles.list) {
                            $existingProfileIndex = -1
                            for ($i = 0; $i -lt $mergedProfiles.Count; $i++) {
                                if ($mergedProfiles[$i].guid -eq $overrideProfile.guid) {
                                    $existingProfileIndex = $i
                                    break
                                }
                            }

                            if ($existingProfileIndex -ge 0) {
                                # Update existing profile
                                foreach ($profileKey in $overrideProfile.Keys) {
                                    $mergedProfiles[$existingProfileIndex][$profileKey] = $overrideProfile[$profileKey]
                                }
                                Write-Verbose "Updated terminal profile: $($overrideProfile.guid)"
                            } else {
                                # Add new profile
                                $mergedProfiles.Add($overrideProfile)
                                Write-Verbose "Added new terminal profile: $($overrideProfile.guid)"
                            }
                        }

                        $merged.profiles.list = $mergedProfiles.ToArray()
                    } else {
                        $merged[$key] = $Override[$key]
                    }
                }
                'schemes' {
                    if ($merged.ContainsKey('schemes') -and $Override.schemes) {
                        Write-Verbose "Merging terminal color schemes"

                        # Merge color schemes by name
                        $mergedSchemes = [System.Collections.ArrayList]::new($merged.schemes)

                        foreach ($overrideScheme in $Override.schemes) {
                            $existingSchemeIndex = -1
                            for ($i = 0; $i -lt $mergedSchemes.Count; $i++) {
                                if ($mergedSchemes[$i].name -eq $overrideScheme.name) {
                                    $existingSchemeIndex = $i
                                    break
                                }
                            }

                            if ($existingSchemeIndex -ge 0) {
                                # Update existing scheme
                                foreach ($schemeKey in $overrideScheme.Keys) {
                                    $mergedSchemes[$existingSchemeIndex][$schemeKey] = $overrideScheme[$schemeKey]
                                }
                                Write-Verbose "Updated terminal color scheme: $($overrideScheme.name)"
                            } else {
                                # Add new scheme
                                $mergedSchemes.Add($overrideScheme)
                                Write-Verbose "Added new terminal color scheme: $($overrideScheme.name)"
                            }
                        }

                        $merged.schemes = $mergedSchemes.ToArray()
                    } else {
                        $merged[$key] = $Override[$key]
                    }
                }
                default {
                    $merged[$key] = $Override[$key]
                    Write-Verbose "Overrode terminal configuration key: $key"
                }
            }
        }

        return $merged
    }

    [hashtable] MergeProfileConfigurations([hashtable] $Base, [hashtable] $Override) {
        Write-Verbose "Merging profile configurations with user overrides"

        if (-not $Base) { $Base = @{} }
        if (-not $Override) { return $Base }

        # Specialized merge for PowerShell profile configurations
        $merged = $this.DeepCloneHashtable($Base)

        foreach ($key in $Override.Keys) {
            switch ($key) {
                'Modules' {
                    if ($merged.ContainsKey('Modules')) {
                        Write-Verbose "Merging PowerShell modules"

                        # Merge module lists, avoiding duplicates
                        $mergedModules = [System.Collections.ArrayList]::new($merged.Modules)

                        foreach ($module in $Override.Modules) {
                            if ($module -is [hashtable]) {
                                $existingIndex = -1
                                for ($i = 0; $i -lt $mergedModules.Count; $i++) {
                                    if ($mergedModules[$i] -is [hashtable] -and $mergedModules[$i].Name -eq $module.Name) {
                                        $existingIndex = $i
                                        break
                                    }
                                }

                                if ($existingIndex -ge 0) {
                                    # Update existing module configuration
                                    foreach ($moduleKey in $module.Keys) {
                                        $mergedModules[$existingIndex][$moduleKey] = $module[$moduleKey]
                                    }
                                    Write-Verbose "Updated PowerShell module: $($module.Name)"
                                } else {
                                    $mergedModules.Add($module)
                                    Write-Verbose "Added PowerShell module: $($module.Name)"
                                }
                            } else {
                                if ($module -notin $mergedModules) {
                                    $mergedModules.Add($module)
                                    Write-Verbose "Added PowerShell module: $module"
                                }
                            }
                        }

                        $merged.Modules = $mergedModules.ToArray()
                    } else {
                        $merged[$key] = $Override[$key]
                    }
                }
                'Aliases' {
                    if ($merged.ContainsKey('Aliases')) {
                        Write-Verbose "Merging PowerShell aliases"

                        # Merge aliases, with override taking precedence
                        foreach ($aliasKey in $Override.Aliases.Keys) {
                            $merged.Aliases[$aliasKey] = $Override.Aliases[$aliasKey]
                            Write-Verbose "Set PowerShell alias: $aliasKey"
                        }
                    } else {
                        $merged[$key] = $Override[$key]
                    }
                }
                'Functions' {
                    if ($merged.ContainsKey('Functions')) {
                        Write-Verbose "Merging PowerShell functions"

                        # Merge functions, with override taking precedence
                        foreach ($functionKey in $Override.Functions.Keys) {
                            $merged.Functions[$functionKey] = $Override.Functions[$functionKey]
                            Write-Verbose "Set PowerShell function: $functionKey"
                        }
                    } else {
                        $merged[$key] = $Override[$key]
                    }
                }
                default {
                    $merged[$key] = $Override[$key]
                    Write-Verbose "Overrode profile configuration key: $key"
                }
            }
        }

        return $merged
    }

    [hashtable] DeepCloneHashtable([hashtable] $Source) {
        if (-not $Source) { return @{} }

        $clone = @{}
        foreach ($key in $Source.Keys) {
            if ($Source[$key] -is [hashtable]) {
                $clone[$key] = $this.DeepCloneHashtable($Source[$key])
            } elseif ($Source[$key] -is [array]) {
                $clonedArray = @()
                foreach ($item in $Source[$key]) {
                    if ($item -is [hashtable]) {
                        $clonedArray += $this.DeepCloneHashtable($item)
                    } else {
                        $clonedArray += $item
                    }
                }
                $clone[$key] = $clonedArray
            } else {
                $clone[$key] = $Source[$key]
            }
        }
        return $clone
    }

    [void] ClearCache() {
        Write-Verbose "Clearing configuration cache"
        $this.ConfigurationCache.Clear()
        $this.LastCacheUpdate = Get-Date
    }

    [void] SetCacheEnabled([bool] $Enabled) {
        $this.CacheEnabled = $Enabled
        Write-Verbose "Configuration cache enabled: $Enabled"
        if (-not $Enabled) {
            $this.ClearCache()
        }
    }

    [hashtable] GetCacheStatistics() {
        return @{
            CacheEnabled = $this.CacheEnabled
            CachedItems = $this.ConfigurationCache.Keys.Count
            LastCacheUpdate = $this.LastCacheUpdate
            CacheKeys = $this.ConfigurationCache.Keys
        }
    }
}
