function Enable-Features {
    <#
    .SYNOPSIS
        Enables Windows features with DotWin configuration management.

    .DESCRIPTION
        The Enable-Features function provides a unified interface for enabling
        Windows optional features, capabilities, and roles while integrating
        with the DotWin configuration management system.

    .PARAMETER FeatureList
        Array of Windows feature names to enable.

    .PARAMETER Category
        Enable features from a specific category (Development, Virtualization, etc.).

    .PARAMETER ConfigurationPath
        Path to a configuration file containing feature definitions.

    .PARAMETER IncludeSubFeatures
        Include dependent sub-features when enabling features.

    .PARAMETER WhatIf
        Shows what features would be enabled without actually enabling them.

    .PARAMETER Force
        Forces enabling even if features appear to be already enabled.

    .PARAMETER RestartIfRequired
        Automatically restart the computer if required by feature installation.

    .EXAMPLE
        Enable-Features -FeatureList @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')
        
        Enables WSL and Virtual Machine Platform features.

    .EXAMPLE
        Enable-Features -Category 'Development' -RestartIfRequired
        
        Enables all development-related Windows features and restarts if needed.

    .EXAMPLE
        Enable-Features -FeatureList @('IIS-WebServerRole') -IncludeSubFeatures -WhatIf
        
        Shows what would happen when enabling IIS with all sub-features.

    .OUTPUTS
        DotWinExecutionResult[]
        Returns an array of execution results for each feature operation.

    .NOTES
        This function requires administrator privileges for most Windows features.
        Some features may require a system restart to complete installation.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'FeatureList')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'FeatureList', Position = 0)]
        [string[]]$FeatureList,

        [Parameter(Mandatory = $true, ParameterSetName = 'Category')]
        [ValidateSet('Development', 'Virtualization', 'WebServer', 'RemoteAccess', 'MediaFeatures', 'NetworkFeatures')]
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
        [switch]$IncludeSubFeatures,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$RestartIfRequired
    )

    begin {
        Write-DotWinLog "Starting Windows features enablement process" -Level Information
        
        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            throw "Environment validation failed: $($envTest.Issues -join ', ')"
        }

        # Check for administrator privileges
        if (-not $envTest.IsAdministrator) {
            throw "Administrator privileges are required to enable Windows features"
        }

        $results = @()
        $startTime = Get-Date
        $restartRequired = $false
    }

    process {
        try {
            # Determine features to enable based on parameter set
            $featuresToEnable = @()

            switch ($PSCmdlet.ParameterSetName) {
                'FeatureList' {
                    $featuresToEnable = $FeatureList
                    Write-DotWinLog "Processing $($FeatureList.Count) features from list" -Level Information
                }
                
                'Category' {
                    Write-DotWinLog "Loading features from category: $Category" -Level Information
                    $featuresToEnable = Get-FeaturesByCategory -Category $Category
                    Write-DotWinLog "Found $($featuresToEnable.Count) features in category '$Category'" -Level Information
                }
                
                'ConfigFile' {
                    Write-DotWinLog "Loading features from configuration file: $ConfigurationPath" -Level Information
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    $featuresToEnable = $configContent.features
                }
            }

            if ($featuresToEnable.Count -eq 0) {
                Write-DotWinLog "No features to enable" -Level Warning
                return $results
            }

            Write-DotWinLog "Enabling $($featuresToEnable.Count) Windows features" -Level Information

            # Process each feature
            foreach ($featureName in $featuresToEnable) {
                $featureStartTime = Get-Date
                $result = [DotWinExecutionResult]::new()
                $result.ItemName = $featureName
                $result.ItemType = "WindowsFeature"
                
                try {
                    Write-DotWinLog "Processing Windows feature: $featureName" -Level Information
                    
                    # Create Windows feature configuration item
                    $featureItem = [DotWinWindowsFeature]::new($featureName)
                    $featureItem.IncludeSubFeatures = $IncludeSubFeatures
                    
                    # Test if feature is already enabled (unless forced)
                    if (-not $Force) {
                        $isEnabled = $featureItem.Test()
                        if ($isEnabled) {
                            $result.Success = $true
                            $result.Message = "Windows feature already enabled"
                            Write-DotWinLog "Windows feature '$featureName' is already enabled" -Level Information
                            continue
                        }
                    }
                    
                    # Enable the feature
                    if ($PSCmdlet.ShouldProcess($featureName, "Enable Windows feature")) {
                        Write-DotWinLog "Enabling Windows feature: $featureName" -Level Information
                        
                        # Get current state for comparison
                        $beforeState = $featureItem.GetCurrentState()
                        
                        # Apply the feature enablement
                        $enableResult = $featureItem.Apply()
                        
                        # Check if restart is required
                        if ($enableResult.RestartRequired) {
                            $restartRequired = $true
                            Write-DotWinLog "Feature '$featureName' requires a system restart" -Level Warning
                        }
                        
                        # Get new state and record changes
                        $afterState = $featureItem.GetCurrentState()
                        $result.Changes = @{
                            Before = $beforeState
                            After = $afterState
                            RestartRequired = $enableResult.RestartRequired
                        }
                        
                        $result.Success = $true
                        $result.Message = "Windows feature enabled successfully"
                        Write-DotWinLog "Successfully enabled Windows feature: $featureName" -Level Information
                    } else {
                        $result.Success = $true
                        $result.Message = "Windows feature enablement skipped (WhatIf)"
                        Write-DotWinLog "Windows feature enablement skipped: $featureName (WhatIf)" -Level Information
                    }
                    
                } catch {
                    $result.Success = $false
                    $result.Message = "Error enabling Windows feature: $($_.Exception.Message)"
                    Write-DotWinLog "Error enabling Windows feature '$featureName': $($_.Exception.Message)" -Level Error
                } finally {
                    $result.Duration = (Get-Date) - $featureStartTime
                    $results += $result
                }
            }

        } catch {
            Write-DotWinLog "Critical error during Windows features enablement: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        Write-DotWinLog "Windows features enablement completed" -Level Information
        Write-DotWinLog "Total features processed: $($results.Count)" -Level Information
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level Information
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level Information
        
        # Handle restart if required
        if ($restartRequired) {
            Write-DotWinLog "One or more features require a system restart to complete installation" -Level Warning
            
            if ($RestartIfRequired) {
                Write-DotWinLog "Initiating system restart as requested" -Level Information
                Restart-Computer -Force
            } else {
                Write-DotWinLog "Please restart your computer to complete feature installation" -Level Warning
            }
        }
        
        return $results
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
            Write-DotWinLog "Testing if Windows feature '$($this.FeatureName)' is enabled" -Level Verbose
            
            # Try Windows Optional Features first
            try {
                $feature = Get-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -ErrorAction Stop
                $isEnabled = ($feature.State -eq 'Enabled')
                Write-DotWinLog "Windows optional feature '$($this.FeatureName)' state: $($feature.State)" -Level Verbose
                return $isEnabled
            } catch {
                # If not found as optional feature, try Windows capabilities
                try {
                    $capability = Get-WindowsCapability -Online -Name "*$($this.FeatureName)*" -ErrorAction Stop | Select-Object -First 1
                    if ($capability) {
                        $isEnabled = ($capability.State -eq 'Installed')
                        Write-DotWinLog "Windows capability '$($capability.Name)' state: $($capability.State)" -Level Verbose
                        $this.Source = "WindowsCapability"
                        return $isEnabled
                    }
                } catch {
                    # Try DISM features as last resort
                    try {
                        $dismFeature = Get-WindowsFeature -Name $this.FeatureName -ErrorAction Stop
                        if ($dismFeature) {
                            $isEnabled = ($dismFeature.InstallState -eq 'Installed')
                            Write-DotWinLog "Windows feature '$($this.FeatureName)' install state: $($dismFeature.InstallState)" -Level Verbose
                            $this.Source = "WindowsFeature"
                            return $isEnabled
                        }
                    } catch {
                        Write-DotWinLog "Windows feature '$($this.FeatureName)' not found in any feature source" -Level Warning
                        return $false
                    }
                }
            }
            
            return $false
            
        } catch {
            Write-DotWinLog "Error testing Windows feature '$($this.FeatureName)': $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    [hashtable] Apply() {
        try {
            Write-DotWinLog "Enabling Windows feature '$($this.FeatureName)'" -Level Information
            
            $result = @{
                Success = $false
                RestartRequired = $false
                Message = ""
            }
            
            # Enable based on detected source type
            switch ($this.Source) {
                "WindowsOptionalFeature" {
                    $enableResult = Enable-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -All:$this.IncludeSubFeatures -NoRestart
                    $result.Success = ($enableResult.RestartNeeded -ne $null)  # Success if operation completed
                    $result.RestartRequired = $enableResult.RestartNeeded
                    $result.Message = "Windows optional feature enabled"
                }
                
                "WindowsCapability" {
                    $capability = Get-WindowsCapability -Online -Name "*$($this.FeatureName)*" | Select-Object -First 1
                    if ($capability) {
                        $enableResult = Add-WindowsCapability -Online -Name $capability.Name
                        $result.Success = ($enableResult.RestartNeeded -ne $null)
                        $result.RestartRequired = $enableResult.RestartNeeded
                        $result.Message = "Windows capability enabled"
                    } else {
                        throw "Windows capability not found: $($this.FeatureName)"
                    }
                }
                
                "WindowsFeature" {
                    $enableResult = Install-WindowsFeature -Name $this.FeatureName -IncludeAllSubFeature:$this.IncludeSubFeatures
                    $result.Success = ($enableResult.Success)
                    $result.RestartRequired = ($enableResult.RestartNeeded -eq 'Yes')
                    $result.Message = "Windows feature enabled"
                }
                
                default {
                    # Auto-detect and try all methods
                    try {
                        $enableResult = Enable-WindowsOptionalFeature -Online -FeatureName $this.FeatureName -All:$this.IncludeSubFeatures -NoRestart
                        $result.Success = $true
                        $result.RestartRequired = $enableResult.RestartNeeded
                        $result.Message = "Windows optional feature enabled"
                        $this.Source = "WindowsOptionalFeature"
                    } catch {
                        try {
                            $capability = Get-WindowsCapability -Online -Name "*$($this.FeatureName)*" | Select-Object -First 1
                            if ($capability) {
                                $enableResult = Add-WindowsCapability -Online -Name $capability.Name
                                $result.Success = $true
                                $result.RestartRequired = $enableResult.RestartNeeded
                                $result.Message = "Windows capability enabled"
                                $this.Source = "WindowsCapability"
                            } else {
                                throw "Feature not found in any source"
                            }
                        } catch {
                            throw "Unable to enable Windows feature '$($this.FeatureName)': $($_.Exception.Message)"
                        }
                    }
                }
            }
            
            if ($result.Success) {
                Write-DotWinLog "Successfully enabled Windows feature '$($this.FeatureName)'" -Level Information
                if ($result.RestartRequired) {
                    Write-DotWinLog "Windows feature '$($this.FeatureName)' requires a restart to complete" -Level Warning
                }
            } else {
                throw "Failed to enable Windows feature '$($this.FeatureName)'"
            }
            
            return $result
            
        } catch {
            Write-DotWinLog "Error enabling Windows feature '$($this.FeatureName)': $($_.Exception.Message)" -Level Error
            throw
        }
    }

    [hashtable] GetCurrentState() {
        try {
            $state = @{
                FeatureName = $this.FeatureName
                Source = $this.Source
                State = "Unknown"
                RestartRequired = $false
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
                
                "WindowsFeature" {
                    $feature = Get-WindowsFeature -Name $this.FeatureName -ErrorAction SilentlyContinue
                    if ($feature) {
                        $state.State = $feature.InstallState
                        $state.DisplayName = $feature.DisplayName
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
                            try {
                                $feature = Get-WindowsFeature -Name $this.FeatureName -ErrorAction Stop
                                $state.State = $feature.InstallState
                                $state.DisplayName = $feature.DisplayName
                                $state.Source = "WindowsFeature"
                            } catch {
                                $state.State = "NotFound"
                            }
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

function Get-FeaturesByCategory {
    <#
    .SYNOPSIS
        Gets Windows features by category.
    
    .DESCRIPTION
        Internal function to retrieve predefined lists of Windows features by category.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category
    )
    
    $featureCategories = @{
        'Development' = @(
            'Microsoft-Windows-Subsystem-Linux',
            'VirtualMachinePlatform',
            'Microsoft-Hyper-V-All',
            'Containers',
            'HypervisorPlatform'
        )
        
        'Virtualization' = @(
            'Microsoft-Hyper-V-All',
            'VirtualMachinePlatform',
            'HypervisorPlatform',
            'Containers'
        )
        
        'WebServer' = @(
            'IIS-WebServerRole',
            'IIS-WebServer',
            'IIS-CommonHttpFeatures',
            'IIS-HttpErrors',
            'IIS-HttpRedirect',
            'IIS-ApplicationDevelopment',
            'IIS-NetFxExtensibility45',
            'IIS-ASPNET45',
            'IIS-ISAPIExtensions',
            'IIS-ISAPIFilter',
            'IIS-ManagementConsole'
        )
        
        'RemoteAccess' = @(
            'TelnetClient',
            'TFTP',
            'ServicesForNFS-ClientOnly',
            'ClientForNFS-Infrastructure'
        )
        
        'MediaFeatures' = @(
            'MediaPlayback',
            'WindowsMediaPlayer',
            'MediaFoundation'
        )
        
        'NetworkFeatures' = @(
            'TelnetClient',
            'TFTP',
            'SimpleTCP',
            'SNMP'
        )
    }
    
    if ($featureCategories.ContainsKey($Category)) {
        return $featureCategories[$Category]
    } else {
        Write-DotWinLog "Unknown feature category: $Category" -Level Warning
        return @()
    }
}

function Get-WindowsFeatureStatus {
    <#
    .SYNOPSIS
        Gets the status of Windows features.
    
    .DESCRIPTION
        Retrieves comprehensive status information for Windows features across
        all available feature sources (Optional Features, Capabilities, Server Features).
    
    .PARAMETER FeatureName
        Specific feature name to check (optional).
    
    .OUTPUTS
        Array of feature status objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$FeatureName
    )
    
    $features = @()
    
    try {
        # Get Windows Optional Features
        Write-DotWinLog "Retrieving Windows Optional Features status" -Level Verbose
        $optionalFeatures = if ($FeatureName) {
            Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
        } else {
            Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue
        }
        
        foreach ($feature in $optionalFeatures) {
            $features += [PSCustomObject]@{
                Name = $feature.FeatureName
                DisplayName = $feature.DisplayName
                State = $feature.State
                Source = "WindowsOptionalFeature"
                RestartRequired = $feature.RestartRequired
            }
        }
        
        # Get Windows Capabilities
        Write-DotWinLog "Retrieving Windows Capabilities status" -Level Verbose
        $capabilities = if ($FeatureName) {
            Get-WindowsCapability -Online -Name "*$FeatureName*" -ErrorAction SilentlyContinue
        } else {
            Get-WindowsCapability -Online -ErrorAction SilentlyContinue
        }
        
        foreach ($capability in $capabilities) {
            $features += [PSCustomObject]@{
                Name = $capability.Name
                DisplayName = $capability.DisplayName
                State = $capability.State
                Source = "WindowsCapability"
                RestartRequired = $false
            }
        }
        
        # Get Windows Features (Server roles/features if available)
        if (Get-Command Get-WindowsFeature -ErrorAction SilentlyContinue) {
            Write-DotWinLog "Retrieving Windows Features status" -Level Verbose
            $windowsFeatures = if ($FeatureName) {
                Get-WindowsFeature -Name $FeatureName -ErrorAction SilentlyContinue
            } else {
                Get-WindowsFeature -ErrorAction SilentlyContinue
            }
            
            foreach ($feature in $windowsFeatures) {
                $features += [PSCustomObject]@{
                    Name = $feature.Name
                    DisplayName = $feature.DisplayName
                    State = $feature.InstallState
                    Source = "WindowsFeature"
                    RestartRequired = $false
                }
            }
        }
        
        Write-DotWinLog "Retrieved status for $($features.Count) Windows features" -Level Verbose
        return $features
        
    } catch {
        Write-DotWinLog "Error retrieving Windows features status: $($_.Exception.Message)" -Level Error
        throw
    }
}