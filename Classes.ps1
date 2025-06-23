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

# PowerShell Profile configuration item class
class DotWinPowerShellProfile : DotWinConfigurationItem {
    [string]$ProfilePath
    [hashtable]$Configuration
    [bool]$BackupExisting

    DotWinPowerShellProfile() : base() {
        $this.Type = "PowerShellProfile"
        $this.Configuration = @{}
        $this.BackupExisting = $true
    }

    DotWinPowerShellProfile([string]$ProfileType) : base($ProfileType, "PowerShellProfile") {
        $this.Configuration = @{}
        $this.BackupExisting = $true
    }

    [bool] Test() {
        try {
            # Check if profile exists
            if (-not (Test-Path $this.ProfilePath)) {
                return $false
            }

            # Check if profile contains expected content
            $profileContent = Get-Content -Path $this.ProfilePath -Raw -ErrorAction SilentlyContinue
            if (-not $profileContent) {
                return $false
            }

            # Check for DotWin configuration marker
            if ($profileContent -notmatch "# DotWin PowerShell Profile Configuration") {
                return $false
            }

            return $true
        } catch {
            return $false
        }
    }

    [void] Apply() {
        try {
            # Create backup if requested and profile exists
            if ($this.BackupExisting -and (Test-Path $this.ProfilePath)) {
                $backupPath = "$($this.ProfilePath).backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item -Path $this.ProfilePath -Destination $backupPath -Force
            }

            # Ensure profile directory exists
            $profileDir = Split-Path $this.ProfilePath -Parent
            if (-not (Test-Path $profileDir)) {
                New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
            }

            # Generate basic profile content
            $profileContent = "# DotWin PowerShell Profile Configuration`n"
            $profileContent += "# Generated on $(Get-Date)`n`n"

            # Write profile content
            Set-Content -Path $this.ProfilePath -Value $profileContent -Encoding UTF8 -Force
            $this.LastModified = Get-Date
        } catch {
            throw "Error configuring PowerShell profile '$($this.Name)': $($_.Exception.Message)"
        }
    }

    [hashtable] GetCurrentState() {
        try {
            $state = @{
                ProfileType = $this.Name
                ProfilePath = $this.ProfilePath
                Exists = Test-Path $this.ProfilePath
                Size = 0
                LastModified = $null
                HasDotWinConfiguration = $false
            }

            if ($state.Exists) {
                $profileInfo = Get-Item $this.ProfilePath
                $state.Size = $profileInfo.Length
                $state.LastModified = $profileInfo.LastWriteTime

                $profileContent = Get-Content -Path $this.ProfilePath -Raw -ErrorAction SilentlyContinue
                if ($profileContent) {
                    $state.HasDotWinConfiguration = ($profileContent -match "# DotWin PowerShell Profile Configuration")
                }
            }

            return $state
        } catch {
            return @{
                ProfileType = $this.Name
                ProfilePath = $this.ProfilePath
                Error = $_.Exception.Message
            }
        }
    }
}

# Windows Terminal configuration item class
class DotWinWindowsTerminal : DotWinConfigurationItem {
    [string]$SettingsPath
    [hashtable]$Configuration
    [bool]$BackupExisting

    DotWinWindowsTerminal() : base() {
        $this.Type = "WindowsTerminal"
        $this.Configuration = @{}
        $this.BackupExisting = $true
    }

    DotWinWindowsTerminal([string]$Theme) : base($Theme, "WindowsTerminal") {
        $this.Configuration = @{}
        $this.BackupExisting = $true
    }

    [bool] Test() {
        try {
            # Check if settings file exists
            if (-not (Test-Path $this.SettingsPath)) {
                return $false
            }

            # Check if settings contain expected configuration
            $settingsContent = Get-Content -Path $this.SettingsPath -Raw -ErrorAction SilentlyContinue
            if (-not $settingsContent) {
                return $false
            }

            try {
                $settings = $settingsContent | ConvertFrom-Json
                # Check for proper schema
                if (-not $settings.'$schema' -or $settings.'$schema' -notmatch "ms-terminal-settings") {
                    return $false
                }
                return $true
            } catch {
                return $false
            }
        } catch {
            return $false
        }
    }

    [void] Apply() {
        try {
            # Create backup if requested and settings exist
            if ($this.BackupExisting -and (Test-Path $this.SettingsPath)) {
                $backupPath = "$($this.SettingsPath).backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item -Path $this.SettingsPath -Destination $backupPath -Force
            }

            # Ensure settings directory exists
            $settingsDir = Split-Path $this.SettingsPath -Parent
            if (-not (Test-Path $settingsDir)) {
                New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
            }

            # Create basic settings structure
            $settings = @{
                '$schema' = "https://aka.ms/terminal-profiles-schema"
                'profiles' = @{
                    'defaults' = @{}
                    'list' = @()
                }
            }

            # Write settings
            $settingsJson = $settings | ConvertTo-Json -Depth 20
            Set-Content -Path $this.SettingsPath -Value $settingsJson -Encoding UTF8 -Force
            $this.LastModified = Get-Date
        } catch {
            throw "Error configuring Windows Terminal '$($this.Name)': $($_.Exception.Message)"
        }
    }

    [hashtable] GetCurrentState() {
        try {
            $state = @{
                ConfiguredTheme = $this.Name
                SettingsPath = $this.SettingsPath
                Exists = Test-Path $this.SettingsPath
                Size = 0
                LastModified = $null
                CurrentTheme = "Unknown"
                ProfileCount = 0
            }

            if ($state.Exists) {
                $settingsInfo = Get-Item $this.SettingsPath
                $state.Size = $settingsInfo.Length
                $state.LastModified = $settingsInfo.LastWriteTime

                try {
                    $settingsContent = Get-Content -Path $this.SettingsPath -Raw
                    $settings = $settingsContent | ConvertFrom-Json
                    $state.CurrentTheme = if ($settings.theme) { $settings.theme } else { "Unknown" }
                    $state.ProfileCount = if ($settings.profiles -and $settings.profiles.list) { $settings.profiles.list.Count } else { 0 }
                } catch {
                    $state.CurrentTheme = "Error parsing settings"
                }
            }

            return $state
        } catch {
            return @{
                ConfiguredTheme = $this.Name
                SettingsPath = $this.SettingsPath
                Error = $_.Exception.Message
            }
        }
    }
}

# Bloatware removal configuration item class
class DotWinBloatwareRemoval : DotWinConfigurationItem {
    [string]$ApplicationName
    [bool]$IncludeServices
    [bool]$IncludeScheduledTasks
    [bool]$PreserveUserData
    [string[]]$RemovalMethods

    DotWinBloatwareRemoval() : base() {
        $this.Type = "BloatwareRemoval"
        $this.IncludeServices = $false
        $this.IncludeScheduledTasks = $false
        $this.PreserveUserData = $true
        $this.RemovalMethods = @('AppxPackage', 'ProvisionedPackage', 'Program')
    }

    DotWinBloatwareRemoval([string]$ApplicationName) : base($ApplicationName, "BloatwareRemoval") {
        $this.ApplicationName = $ApplicationName
        $this.IncludeServices = $false
        $this.IncludeScheduledTasks = $false
        $this.PreserveUserData = $true
        $this.RemovalMethods = @('AppxPackage', 'ProvisionedPackage', 'Program')
    }

    [bool] Test() {
        try {
            # Check if application exists in any form
            $appExists = $false

            # Check AppX packages
            $appxPackages = Get-AppxPackage -Name "*$($this.ApplicationName)*" -AllUsers -ErrorAction SilentlyContinue
            if ($appxPackages) {
                $appExists = $true
            }

            # Check provisioned packages
            $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$($this.ApplicationName)*" }
            if ($provisionedPackages) {
                $appExists = $true
            }

            return $appExists
        } catch {
            return $false
        }
    }

    [void] Apply() {
        try {
            # Remove AppX packages
            if ('AppxPackage' -in $this.RemovalMethods) {
                $appxPackages = Get-AppxPackage -Name "*$($this.ApplicationName)*" -AllUsers -ErrorAction SilentlyContinue
                foreach ($package in $appxPackages) {
                    Remove-AppxPackage -Package $package.PackageFullName -ErrorAction SilentlyContinue
                }
            }

            # Remove provisioned packages
            if ('ProvisionedPackage' -in $this.RemovalMethods) {
                $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$($this.ApplicationName)*" }
                foreach ($package in $provisionedPackages) {
                    Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName -ErrorAction SilentlyContinue
                }
            }

            $this.LastModified = Get-Date
        } catch {
            throw "Error removing application '$($this.ApplicationName)': $($_.Exception.Message)"
        }
    }

    [hashtable] GetCurrentState() {
        try {
            $state = @{
                ApplicationName = $this.ApplicationName
                AppxPackages = @()
                ProvisionedPackages = @()
            }

            # Get AppX packages
            $appxPackages = Get-AppxPackage -Name "*$($this.ApplicationName)*" -AllUsers -ErrorAction SilentlyContinue
            foreach ($package in $appxPackages) {
                $state.AppxPackages += @{
                    Name = $package.Name
                    PackageFullName = $package.PackageFullName
                    Version = $package.Version
                }
            }

            # Get provisioned packages
            $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$($this.ApplicationName)*" }
            foreach ($package in $provisionedPackages) {
                $state.ProvisionedPackages += @{
                    DisplayName = $package.DisplayName
                    PackageName = $package.PackageName
                    Version = $package.Version
                }
            }

            return $state
        } catch {
            return @{
                ApplicationName = $this.ApplicationName
                Error = $_.Exception.Message
            }
        }
    }
}

# Windows Feature configuration item class
class DotWinWindowsFeature : DotWinConfigurationItem {
    [string]$FeatureName
    [bool]$IncludeSubFeatures
    [string]$Source

    DotWinWindowsFeature() : base() {
        $this.Type = "WindowsFeature"
        $this.IncludeSubFeatures = $false
        $this.Source = "WindowsOptionalFeature"
    }

    DotWinWindowsFeature([string]$FeatureName) : base($FeatureName, "WindowsFeature") {
        $this.FeatureName = $FeatureName
        $this.IncludeSubFeatures = $false
        $this.Source = "WindowsOptionalFeature"
    }

    [bool] Test() {
        try {
            # Try Windows Optional Features first
            try {
                $feature = Get-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -ErrorAction Stop
                $isEnabled = ($feature.State -eq 'Enabled')
                return $isEnabled
            } catch {
                # If not found as optional feature, try Windows capabilities
                try {
                    $capability = Get-WindowsCapability -Online -Name "*$($this.FeatureName)*" -ErrorAction Stop | Select-Object -First 1
                    if ($capability) {
                        $isEnabled = ($capability.State -eq 'Installed')
                        $this.Source = "WindowsCapability"
                        return $isEnabled
                    }
                } catch {
                    return $false
                }
            }
            return $false
        } catch {
            return $false
        }
    }

    [void] Apply() {
        try {
            # Enable based on detected source type
            switch ($this.Source) {
                "WindowsOptionalFeature" {
                    Enable-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -All:$this.IncludeSubFeatures -NoRestart
                }
                "WindowsCapability" {
                    $capability = Get-WindowsCapability -Online -Name "*$($this.FeatureName)*" | Select-Object -First 1
                    if ($capability) {
                        Add-WindowsCapability -Online -Name $capability.Name
                    } else {
                        throw "Windows capability not found: $($this.FeatureName)"
                    }
                }
                default {
                    # Auto-detect and try all methods
                    try {
                        Enable-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -All:$this.IncludeSubFeatures -NoRestart
                        $this.Source = "WindowsOptionalFeature"
                    } catch {
                        $capability = Get-WindowsCapability -Online -Name "*$($this.FeatureName)*" | Select-Object -First 1
                        if ($capability) {
                            Add-WindowsCapability -Online -Name $capability.Name
                            $this.Source = "WindowsCapability"
                        } else {
                            throw "Feature not found in any source"
                        }
                    }
                }
            }
            $this.LastModified = Get-Date
        } catch {
            throw "Error enabling Windows feature '$($this.FeatureName)': $($_.Exception.Message)"
        }
    }

    [hashtable] GetCurrentState() {
        try {
            $state = @{
                FeatureName = $this.FeatureName
                Source = $this.Source
                State = "Unknown"
            }

            # Get current state based on source type
            switch ($this.Source) {
                "WindowsOptionalFeature" {
                    $feature = Get-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -ErrorAction SilentlyContinue
                    if ($feature) {
                        $state.State = $feature.State
                        $state.DisplayName = $feature.DisplayName
                    }
                }
                "WindowsCapability" {
                    $capability = Get-WindowsCapability -Online -Name "*$($this.FeatureName)*" -ErrorAction SilentlyContinue | Select-Object -First 1
                    if ($capability) {
                        $state.State = $capability.State
                        $state.DisplayName = $capability.DisplayName
                        $state.Name = $capability.Name
                    }
                }
                default {
                    # Try to detect current state from any source
                    try {
                        $feature = Get-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -ErrorAction Stop
                        $state.State = $feature.State
                        $state.DisplayName = $feature.DisplayName
                        $state.Source = "WindowsOptionalFeature"
                    } catch {
                        try {
                            $capability = Get-WindowsCapability -Online -Name "*$($this.FeatureName)*" -ErrorAction Stop | Select-Object -First 1
                            if ($capability) {
                                $state.State = $capability.State
                                $state.DisplayName = $capability.DisplayName
                                $state.Name = $capability.Name
                                $state.Source = "WindowsCapability"
                            }
                        } catch {
                            $state.State = "NotFound"
                        }
                    }
                }
            }

            return $state
        } catch {
            return @{
                FeatureName = $this.FeatureName
                Source = $this.Source
                State = "Error"
                Error = $_.Exception.Message
            }
        }
    }
}

# Telemetry configuration item class
class DotWinTelemetryConfiguration : DotWinConfigurationItem {
    [string]$SettingType
    [string]$RegistryPath
    [string]$RegistryName
    [object]$RegistryValue
    [string]$RegistryType
    [string]$ServiceName
    [string]$TaskPath
    [string]$TaskName

    DotWinTelemetryConfiguration() : base() {
        $this.Type = "TelemetryConfiguration"
        $this.SettingType = "Registry"
        $this.RegistryType = "DWORD"
    }

    DotWinTelemetryConfiguration([string]$Name) : base($Name, "TelemetryConfiguration") {
        $this.SettingType = "Registry"
        $this.RegistryType = "DWORD"
    }

    [bool] Test() {
        try {
            $result = switch ($this.SettingType) {
                'Registry' {
                    if (Test-Path $this.RegistryPath) {
                        $currentValue = Get-ItemProperty -Path $this.RegistryPath -Name $this.RegistryName -ErrorAction SilentlyContinue
                        if ($currentValue) {
                            return ($currentValue.$($this.RegistryName) -eq $this.RegistryValue)
                        }
                    }
                    return $false
                }
                'Service' {
                    $service = Get-Service -Name $this.ServiceName -ErrorAction SilentlyContinue
                    if ($service) {
                        return ($service.StartType -eq 'Disabled')
                    }
                    return $false
                }
                'ScheduledTask' {
                    $task = Get-ScheduledTask -TaskPath $this.TaskPath -TaskName $this.TaskName -ErrorAction SilentlyContinue
                    if ($task) {
                        return ($task.State -eq 'Disabled')
                    }
                    return $false
                }
                default {
                    return $false
                }
            }
            return $result
        } catch {
            return $false
        }
    }

    [void] Apply() {
        try {
            switch ($this.SettingType) {
                'Registry' {
                    if (-not (Test-Path $this.RegistryPath)) {
                        New-Item -Path $this.RegistryPath -Force | Out-Null
                    }
                    Set-ItemProperty -Path $this.RegistryPath -Name $this.RegistryName -Value $this.RegistryValue -Type $this.RegistryType
                }
                'Service' {
                    $service = Get-Service -Name $this.ServiceName -ErrorAction SilentlyContinue
                    if ($service) {
                        Stop-Service -Name $this.ServiceName -Force -ErrorAction SilentlyContinue
                        Set-Service -Name $this.ServiceName -StartupType Disabled
                    }
                }
                'ScheduledTask' {
                    $task = Get-ScheduledTask -TaskPath $this.TaskPath -TaskName $this.TaskName -ErrorAction SilentlyContinue
                    if ($task) {
                        Disable-ScheduledTask -TaskPath $this.TaskPath -TaskName $this.TaskName
                    }
                }
                default {
                    throw "Unknown telemetry setting type: $($this.SettingType)"
                }
            }
            $this.LastModified = Get-Date
        } catch {
            throw "Error applying telemetry setting '$($this.Name)': $($_.Exception.Message)"
        }
    }

    [hashtable] GetCurrentState() {
        try {
            $state = @{
                Name = $this.Name
                SettingType = $this.SettingType
                IsDisabled = $false
            }

            switch ($this.SettingType) {
                'Registry' {
                    $state.RegistryPath = $this.RegistryPath
                    $state.RegistryName = $this.RegistryName
                    $state.ExpectedValue = $this.RegistryValue

                    if (Test-Path $this.RegistryPath) {
                        $currentValue = Get-ItemProperty -Path $this.RegistryPath -Name $this.RegistryName -ErrorAction SilentlyContinue
                        if ($currentValue) {
                            $state.CurrentValue = $currentValue.$($this.RegistryName)
                            $state.IsDisabled = ($state.CurrentValue -eq $this.RegistryValue)
                        }
                    }
                }
                'Service' {
                    $state.ServiceName = $this.ServiceName
                    $service = Get-Service -Name $this.ServiceName -ErrorAction SilentlyContinue
                    if ($service) {
                        $state.ServiceStatus = $service.Status
                        $state.ServiceStartType = $service.StartType
                        $state.IsDisabled = ($service.StartType -eq 'Disabled')
                    }
                }
                'ScheduledTask' {
                    $state.TaskPath = $this.TaskPath
                    $state.TaskName = $this.TaskName
                    $task = Get-ScheduledTask -TaskPath $this.TaskPath -TaskName $this.TaskName -ErrorAction SilentlyContinue
                    if ($task) {
                        $state.TaskState = $task.State
                        $state.IsDisabled = ($task.State -eq 'Disabled')
                    }
                }
            }

            return $state
        } catch {
            return @{
                Name = $this.Name
                SettingType = $this.SettingType
                Error = $_.Exception.Message
            }
        }
    }
}