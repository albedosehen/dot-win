function Disable-Telemetry {
    <#
    .SYNOPSIS
        Disables Windows telemetry and privacy-invasive features.

    .DESCRIPTION
        The Disable-Telemetry function provides comprehensive privacy configuration
        for Windows 11, disabling telemetry collection, diagnostic data sharing,
        and other privacy-invasive features while integrating with the DotWin
        configuration management system.

    .PARAMETER Level
        The level of telemetry disabling to apply (Basic, Standard, Aggressive).

    .PARAMETER Category
        Disable telemetry from specific categories (Diagnostic, Advertising, Location, etc.).

    .PARAMETER ConfigurationPath
        Path to a configuration file containing telemetry settings.

    .PARAMETER IncludeServices
        Also disable telemetry-related Windows services.

    .PARAMETER IncludeScheduledTasks
        Disable scheduled tasks related to telemetry collection.

    .PARAMETER IncludeRegistry
        Apply registry modifications to disable telemetry.

    .PARAMETER WhatIf
        Shows what telemetry settings would be changed without actually changing them.

    .PARAMETER Force
        Forces changes even if they might affect system functionality.

    .EXAMPLE
        Disable-Telemetry -Level 'Standard'
        
        Applies standard telemetry disabling settings.

    .EXAMPLE
        Disable-Telemetry -Category 'Advertising' -IncludeServices
        
        Disables advertising-related telemetry and services.

    .EXAMPLE
        Disable-Telemetry -Level 'Aggressive' -IncludeServices -IncludeScheduledTasks -WhatIf
        
        Shows what would happen with aggressive telemetry disabling.

    .OUTPUTS
        DotWinExecutionResult[]
        Returns an array of execution results for each telemetry configuration change.

    .NOTES
        This function requires administrator privileges for most operations.
        Some changes may require a system restart to take effect.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Level')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Level', Position = 0)]
        [ValidateSet('Basic', 'Standard', 'Aggressive')]
        [string]$Level,

        [Parameter(Mandatory = $true, ParameterSetName = 'Category')]
        [ValidateSet('Diagnostic', 'Advertising', 'Location', 'Cortana', 'EdgeTelemetry', 'OfficeTelemtry', 'All')]
        [string]$Category,

        [Parameter(ParameterSetName = 'ConfigFile')]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Configuration file '$_' does not exist."
            }
            return $true
        })]
        [string]$ConfigurationPath,

        [Parameter()]
        [switch]$IncludeServices,

        [Parameter()]
        [switch]$IncludeScheduledTasks,

        [Parameter()]
        [switch]$IncludeRegistry,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-DotWinLog "Starting telemetry disabling process" -Level "Information"
        
        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            throw "Environment validation failed: $($envTest.Issues -join ', ')"
        }

        # Check for administrator privileges
        if (-not $envTest.IsAdministrator) {
            throw "Administrator privileges are required to disable telemetry"
        }

        $results = @()
        $startTime = Get-Date
    }

    process {
        try {
            # Determine telemetry settings to apply based on parameter set
            $telemetrySettings = @()

            switch ($PSCmdlet.ParameterSetName) {
                'Level' {
                    Write-DotWinLog "Loading telemetry settings for level: $Level" -Level "Information"
                    $telemetrySettings = Get-TelemetrySettingsByLevel -Level $Level
                    Write-DotWinLog "Found $($telemetrySettings.Count) telemetry settings for level '$Level'" -Level "Information"
                }
                
                'Category' {
                    Write-DotWinLog "Loading telemetry settings from category: $Category" -Level "Information"
                    $telemetrySettings = Get-TelemetrySettingsByCategory -Category $Category
                    Write-DotWinLog "Found $($telemetrySettings.Count) telemetry settings in category '$Category'" -Level "Information"
                }
                
                'ConfigFile' {
                    Write-DotWinLog "Loading telemetry settings from configuration file: $ConfigurationPath" -Level "Information"
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    $telemetrySettings = $configContent.telemetrySettings
                }
            }

            if ($telemetrySettings.Count -eq 0) {
                Write-DotWinLog "No telemetry settings to apply" -Level "Warning"
                return $results
            }

            Write-DotWinLog "Applying $($telemetrySettings.Count) telemetry configuration changes" -Level "Information"

            # Process each telemetry setting
            foreach ($setting in $telemetrySettings) {
                $settingStartTime = Get-Date
                $result = [DotWinExecutionResult]::new()
                $result.ItemName = $setting.Name
                $result.ItemType = "TelemetryConfiguration"
                
                try {
                    Write-DotWinLog "Processing telemetry setting: $($setting.Name)" -Level "Information"
                    
                    # Create telemetry configuration item
                    $telemetryItem = [DotWinTelemetryConfiguration]::new($setting.Name)
                    $telemetryItem.SettingType = $setting.Type
                    $telemetryItem.RegistryPath = $setting.RegistryPath
                    $telemetryItem.RegistryName = $setting.RegistryName
                    $telemetryItem.RegistryValue = $setting.RegistryValue
                    $telemetryItem.RegistryType = $setting.RegistryType
                    $telemetryItem.ServiceName = $setting.ServiceName
                    $telemetryItem.TaskPath = $setting.TaskPath
                    $telemetryItem.TaskName = $setting.TaskName
                    
                    # Test current state
                    $currentlyDisabled = $telemetryItem.Test()
                    if ($currentlyDisabled -and -not $Force) {
                        $result.Success = $true
                        $result.Message = "Telemetry setting already disabled"
                        Write-DotWinLog "Telemetry setting '$($setting.Name)' already disabled" -Level "Information"
                        continue
                    }
                    
                    # Apply the telemetry configuration
                    if ($PSCmdlet.ShouldProcess($setting.Name, "Disable telemetry setting")) {
                        Write-DotWinLog "Disabling telemetry setting: $($setting.Name)" -Level "Information"
                        
                        # Get current state for comparison
                        $beforeState = $telemetryItem.GetCurrentState()
                        
                        # Apply the configuration
                        $telemetryItem.Apply()
                        
                        # Get new state and record changes
                        $afterState = $telemetryItem.GetCurrentState()
                        $result.Changes = @{
                            Before = $beforeState
                            After = $afterState
                        }
                        
                        $result.Success = $true
                        $result.Message = "Telemetry setting disabled successfully"
                        Write-DotWinLog "Successfully disabled telemetry setting: $($setting.Name)" -Level "Information"
                    } else {
                        $result.Success = $true
                        $result.Message = "Telemetry setting change skipped (WhatIf)"
                        Write-DotWinLog "Telemetry setting change skipped: $($setting.Name) (WhatIf)" -Level "Information"
                    }
                    
                } catch {
                    $result.Success = $false
                    $result.Message = "Error disabling telemetry setting: $($_.Exception.Message)"
                    Write-DotWinLog "Error disabling telemetry setting '$($setting.Name)': $($_.Exception.Message)" -Level "Error"
                } finally {
                    $result.Duration = (Get-Date) - $settingStartTime
                    $results += $result
                }
            }

        } catch {
            Write-DotWinLog "Critical error during telemetry disabling: $($_.Exception.Message)" -Level "Error"
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        Write-DotWinLog "Telemetry disabling completed" -Level "Information"
        Write-DotWinLog "Total settings processed: $($results.Count)" -Level "Information"
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level "Information"
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level "Information"
        
        Write-DotWinLog "Note: Some telemetry changes may require a system restart to take effect" -Level "Information"
        
        return $results
    }
}


function Test-TelemetryRegistrySetting {
    <#
    .SYNOPSIS
        Tests if a registry-based telemetry setting is disabled.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [object]$ExpectedValue
    )
    
    try {
        if (-not (Test-Path $Path)) {
            return $false
        }
        
        $currentValue = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        if (-not $currentValue) {
            return $false
        }
        
        return ($currentValue.$Name -eq $ExpectedValue)
        
    } catch {
        return $false
    }
}

function Set-TelemetryRegistrySetting {
    <#
    .SYNOPSIS
        Sets a registry-based telemetry setting.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [object]$Value,
        
        [Parameter(Mandatory = $true)]
        [string]$Type
    )
    
    try {
        # Ensure registry path exists
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        
        # Set registry value
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        
        Write-DotWinLog "Set registry value: $Path\$Name = $Value" -Level "Verbose"
        
    } catch {
        Write-DotWinLog "Error setting registry value '$Path\$Name': $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Test-TelemetryServiceSetting {
    <#
    .SYNOPSIS
        Tests if a telemetry service is disabled.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            return $true  # Service doesn't exist, consider it "disabled"
        }
        
        return ($service.StartType -eq 'Disabled')
        
    } catch {
        return $false
    }
}

function Set-TelemetryServiceSetting {
    <#
    .SYNOPSIS
        Disables a telemetry service.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if (-not $service) {
            Write-DotWinLog "Service '$ServiceName' not found" -Level "Verbose"
            return
        }
        
        # Stop the service if running
        if ($service.Status -eq 'Running') {
            Stop-Service -Name $ServiceName -Force
            Write-DotWinLog "Stopped service: $ServiceName" -Level "Verbose"
        }
        
        # Disable the service
        Set-Service -Name $ServiceName -StartupType Disabled
        Write-DotWinLog "Disabled service: $ServiceName" -Level "Verbose"
        
    } catch {
        Write-DotWinLog "Error disabling service '$ServiceName': $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Test-TelemetryTaskSetting {
    <#
    .SYNOPSIS
        Tests if a telemetry scheduled task is disabled.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskPath,
        
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )
    
    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) {
            return $true  # Task doesn't exist, consider it "disabled"
        }
        
        return ($task.State -eq 'Disabled')
        
    } catch {
        return $false
    }
}

function Set-TelemetryTaskSetting {
    <#
    .SYNOPSIS
        Disables a telemetry scheduled task.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TaskPath,
        
        [Parameter(Mandatory = $true)]
        [string]$TaskName
    )
    
    try {
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $task) {
            Write-DotWinLog "Scheduled task '$TaskPath\$TaskName' not found" -Level "Verbose"
            return
        }
        
        # Disable the scheduled task
        Disable-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
        Write-DotWinLog "Disabled scheduled task: $TaskPath\$TaskName" -Level "Verbose"
        
    } catch {
        Write-DotWinLog "Error disabling scheduled task '$TaskPath\$TaskName': $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Get-TelemetrySettingsByLevel {
    <#
    .SYNOPSIS
        Gets telemetry settings by privacy level.
    
    .DESCRIPTION
        Internal function to retrieve predefined telemetry settings by privacy level.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Level
    )
    
    $basicSettings = @(
        @{
            Name = "Disable Diagnostic Data"
            Type = "Registry"
            RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
            RegistryName = "AllowTelemetry"
            RegistryValue = 0
            RegistryType = "DWORD"
        },
        @{
            Name = "Disable Advertising ID"
            Type = "Registry"
            RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
            RegistryName = "Enabled"
            RegistryValue = 0
            RegistryType = "DWORD"
        },
        @{
            Name = "Disable Location Tracking"
            Type = "Registry"
            RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
            RegistryName = "Value"
            RegistryValue = "Deny"
            RegistryType = "String"
        }
    )
    
    $standardSettings = $basicSettings + @(
        @{
            Name = "Disable Connected User Experiences and Telemetry Service"
            Type = "Service"
            ServiceName = "DiagTrack"
        },
        @{
            Name = "Disable Windows Error Reporting Service"
            Type = "Service"
            ServiceName = "WerSvc"
        },
        @{
            Name = "Disable Feedback Notifications"
            Type = "Registry"
            RegistryPath = "HKCU:\SOFTWARE\Microsoft\Siuf\Rules"
            RegistryName = "NumberOfSIUFInPeriod"
            RegistryValue = 0
            RegistryType = "DWORD"
        },
        @{
            Name = "Disable Cortana"
            Type = "Registry"
            RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
            RegistryName = "AllowCortana"
            RegistryValue = 0
            RegistryType = "DWORD"
        }
    )
    
    $aggressiveSettings = $standardSettings + @(
        @{
            Name = "Disable Customer Experience Improvement Program"
            Type = "Registry"
            RegistryPath = "HKLM:\SOFTWARE\Microsoft\SQMClient\Windows"
            RegistryName = "CEIPEnable"
            RegistryValue = 0
            RegistryType = "DWORD"
        },
        @{
            Name = "Disable Application Impact Telemetry"
            Type = "Registry"
            RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"
            RegistryName = "AITEnable"
            RegistryValue = 0
            RegistryType = "DWORD"
        },
        @{
            Name = "Disable Steps Recorder"
            Type = "Registry"
            RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"
            RegistryName = "DisableUAR"
            RegistryValue = 1
            RegistryType = "DWORD"
        },
        @{
            Name = "Disable Inventory Collector"
            Type = "Registry"
            RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat"
            RegistryName = "DisableInventory"
            RegistryValue = 1
            RegistryType = "DWORD"
        },
        @{
            Name = "Disable Microsoft Compatibility Appraiser"
            Type = "ScheduledTask"
            TaskPath = "\Microsoft\Windows\Application Experience\"
            TaskName = "Microsoft Compatibility Appraiser"
        },
        @{
            Name = "Disable Program Data Updater"
            Type = "ScheduledTask"
            TaskPath = "\Microsoft\Windows\Application Experience\"
            TaskName = "ProgramDataUpdater"
        }
    )
    
    switch ($Level) {
        'Basic' { return $basicSettings }
        'Standard' { return $standardSettings }
        'Aggressive' { return $aggressiveSettings }
        default {
            Write-DotWinLog "Unknown telemetry level: $Level" -Level "Warning"
            return @()
        }
    }
}

function Get-TelemetrySettingsByCategory {
    <#
    .SYNOPSIS
        Gets telemetry settings by category.
    
    .DESCRIPTION
        Internal function to retrieve telemetry settings by specific category.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category
    )
    
    $categorySettings = @{
        'Diagnostic' = @(
            @{
                Name = "Disable Diagnostic Data"
                Type = "Registry"
                RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
                RegistryName = "AllowTelemetry"
                RegistryValue = 0
                RegistryType = "DWORD"
            },
            @{
                Name = "Disable Connected User Experiences and Telemetry Service"
                Type = "Service"
                ServiceName = "DiagTrack"
            },
            @{
                Name = "Disable Windows Error Reporting Service"
                Type = "Service"
                ServiceName = "WerSvc"
            }
        )
        
        'Advertising' = @(
            @{
                Name = "Disable Advertising ID"
                Type = "Registry"
                RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
                RegistryName = "Enabled"
                RegistryValue = 0
                RegistryType = "DWORD"
            },
            @{
                Name = "Disable Tailored Experiences"
                Type = "Registry"
                RegistryPath = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
                RegistryName = "DisableTailoredExperiencesWithDiagnosticData"
                RegistryValue = 1
                RegistryType = "DWORD"
            }
        )
        
        'Location' = @(
            @{
                Name = "Disable Location Tracking"
                Type = "Registry"
                RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"
                RegistryName = "Value"
                RegistryValue = "Deny"
                RegistryType = "String"
            },
            @{
                Name = "Disable Location Scripting"
                Type = "Registry"
                RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors"
                RegistryName = "DisableLocation"
                RegistryValue = 1
                RegistryType = "DWORD"
            }
        )
        
        'Cortana' = @(
            @{
                Name = "Disable Cortana"
                Type = "Registry"
                RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
                RegistryName = "AllowCortana"
                RegistryValue = 0
                RegistryType = "DWORD"
            },
            @{
                Name = "Disable Cortana on Lock Screen"
                Type = "Registry"
                RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
                RegistryName = "AllowCortanaAboveLock"
                RegistryValue = 0
                RegistryType = "DWORD"
            }
        )
        
        'EdgeTelemetry' = @(
            @{
                Name = "Disable Edge Telemetry"
                Type = "Registry"
                RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
                RegistryName = "MetricsReportingEnabled"
                RegistryValue = 0
                RegistryType = "DWORD"
            },
            @{
                Name = "Disable Edge Usage Data"
                Type = "Registry"
                RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
                RegistryName = "UserFeedbackAllowed"
                RegistryValue = 0
                RegistryType = "DWORD"
            }
        )
        
        'OfficeTelemtry' = @(
            @{
                Name = "Disable Office Telemetry"
                Type = "Registry"
                RegistryPath = "HKCU:\SOFTWARE\Policies\Microsoft\Office\16.0\Common"
                RegistryName = "QMEnable"
                RegistryValue = 0
                RegistryType = "DWORD"
            },
            @{
                Name = "Disable Office Customer Experience Improvement Program"
                Type = "Registry"
                RegistryPath = "HKCU:\SOFTWARE\Policies\Microsoft\Office\16.0\Common"
                RegistryName = "UpdateReliabilityData"
                RegistryValue = 0
                RegistryType = "DWORD"
            }
        )
        
        'All' = @()
    }
    
    # For 'All' category, combine all other categories
    if ($Category -eq 'All') {
        $allSettings = @()
        foreach ($cat in $categorySettings.Keys) {
            if ($cat -ne 'All') {
                $allSettings += $categorySettings[$cat]
            }
        }
        return $allSettings
    }
    
    if ($categorySettings.ContainsKey($Category)) {
        return $categorySettings[$Category]
    } else {
        Write-DotWinLog "Unknown telemetry category: $Category" -Level "Warning"
        return @()
    }
}

function Get-TelemetryStatus {
    <#
    .SYNOPSIS
        Gets the current status of Windows telemetry settings.
    
    .DESCRIPTION
        Retrieves comprehensive information about the current state of
        telemetry and privacy settings on the system.
    
    .OUTPUTS
        Hashtable containing telemetry status information.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-DotWinLog "Retrieving telemetry status" -Level "Information"
        
        $status = @{
            DiagnosticData = "Unknown"
            AdvertisingID = "Unknown"
            LocationTracking = "Unknown"
            Cortana = "Unknown"
            Services = @{}
            ScheduledTasks = @{}
        }
        
        # Check diagnostic data setting
        try {
            $diagData = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" -Name "AllowTelemetry" -ErrorAction SilentlyContinue
            if ($diagData) {
                $status.DiagnosticData = switch ($diagData.AllowTelemetry) {
                    0 { "Disabled" }
                    1 { "Basic" }
                    2 { "Enhanced" }
                    3 { "Full" }
                    default { "Unknown" }
                }
            }
        } catch {
            $status.DiagnosticData = "Error"
        }
        
        # Check advertising ID
        try {
            $adId = Get-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" -Name "Enabled" -ErrorAction SilentlyContinue
            if ($adId) {
                $status.AdvertisingID = if ($adId.Enabled -eq 0) { "Disabled" } else { "Enabled" }
            }
        } catch {
            $status.AdvertisingID = "Error"
        }

        # Check location tracking
        try {
            $location = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location" -Name "Value" -ErrorAction SilentlyContinue
            if ($location) {
                $status.LocationTracking = $location.Value
            }
        } catch {
            $status.LocationTracking = "Error"
        }

        # Check Cortana
        try {
            $cortana = Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" -Name "AllowCortana" -ErrorAction SilentlyContinue
            if ($cortana) {
                $status.Cortana = if ($cortana.AllowCortana -eq 0) { "Disabled" } else { "Enabled" }
            }
        } catch {
            $status.Cortana = "Error"
        }

        # Check telemetry services
        $telemetryServices = @('DiagTrack', 'WerSvc', 'dmwappushservice')
        foreach ($serviceName in $telemetryServices) {
            try {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service) {
                    $status.Services[$serviceName] = @{
                        Status = $service.Status
                        StartType = $service.StartType
                    }
                }
            } catch {
                $status.Services[$serviceName] = @{ Status = "Error" }
            }
        }

        # Check telemetry scheduled tasks
        $telemetryTasks = @(
            @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "Microsoft Compatibility Appraiser" },
            @{ Path = "\Microsoft\Windows\Application Experience\"; Name = "ProgramDataUpdater" },
            @{ Path = "\Microsoft\Windows\Autochk\"; Name = "Proxy" },
            @{ Path = "\Microsoft\Windows\Customer Experience Improvement Program\"; Name = "Consolidator" }
        )

        foreach ($taskInfo in $telemetryTasks) {
            try {
                $task = Get-ScheduledTask -TaskPath $taskInfo.Path -TaskName $taskInfo.Name -ErrorAction SilentlyContinue
                if ($task) {
                    $status.ScheduledTasks["$($taskInfo.Path)$($taskInfo.Name)"] = @{
                        State = $task.State
                    }
                }
            } catch {
                $status.ScheduledTasks["$($taskInfo.Path)$($taskInfo.Name)"] = @{ State = "Error" }
            }
        }

        Write-DotWinLog "Retrieved telemetry status successfully" -Level "Information"
        return $status

    } catch {
        Write-DotWinLog "Error retrieving telemetry status: $($_.Exception.Message)" -Level "Error"
        throw
    }
}
