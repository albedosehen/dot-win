function Set-TerminalProfile {
    <#
    .SYNOPSIS
        Configures Windows Terminal profiles with DotWin configuration management.

    .DESCRIPTION
        The Set-TerminalProfile function provides comprehensive Windows Terminal
        configuration, including themes, profiles, keybindings, and settings
        while integrating with the DotWin Configuration Bridge system for
        rich declarative configurations and user overrides.

    .PARAMETER Theme
        Apply a predefined theme from the Configuration Bridge.
        Supports DotWinDark, DotWinLight, Developer, Gaming, and other themes
        defined in the terminal configuration.

    .PARAMETER ConfigurationName
        Use a specific configuration by name from the Configuration Bridge.
        This allows using complete terminal configurations with themes, profiles,
        and keybindings predefined.

    .PARAMETER ConfigurationPath
        Path to a configuration file containing terminal settings.

    .PARAMETER IncludeProfiles
        Configure shell profiles (PowerShell, Command Prompt, WSL, etc.).

    .PARAMETER IncludeKeybindings
        Configure custom keybindings.

    .PARAMETER IncludeSettings
        Configure general terminal settings.

    .PARAMETER WhatIf
        Shows what terminal changes would be made without actually making them.

    .PARAMETER Force
        Forces terminal configuration even if settings already exist.

    .PARAMETER BackupExisting
        Creates a backup of existing terminal settings before making changes.

    .PARAMETER UserConfigPath
        Optional path to user configuration directory for overrides.
        If not specified, will automatically discover user configurations.

    .EXAMPLE
        Set-TerminalProfile -Theme 'DotWinDark' -IncludeProfiles -IncludeKeybindings
        
        Configures Windows Terminal with DotWin dark theme, profiles, and keybindings.

    .EXAMPLE
        Set-TerminalProfile -ConfigurationName 'Developer'

        Applies the complete Developer configuration including theme, profiles, and keybindings.

    .EXAMPLE
        Set-TerminalProfile -ConfigurationPath 'C:\Config\Terminal.json' -BackupExisting
        
        Applies terminal configuration from file with backup of existing settings.

    .EXAMPLE
        Set-TerminalProfile -Theme 'Gaming' -IncludeSettings -WhatIf -UserConfigPath '~/.my-dotwin'
        
        Shows what would happen when applying Gaming theme with user overrides.

    .OUTPUTS
        DotWinExecutionResult[]
        Returns an array of execution results for each terminal configuration operation.

    .NOTES
        This function uses the DotWin Configuration Bridge system for rich configuration
        management with user override support. Terminal profiles are dynamically resolved
        based on installed applications and system configuration.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Theme')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Theme', Position = 0)]
        [ValidateSet('DotWinDark', 'DotWinLight', 'Developer', 'Gaming')]
        [string]$Theme,

        [Parameter(Mandatory = $true, ParameterSetName = 'Configuration', Position = 0)]
        [ValidateSet('DotWinDark', 'DotWinLight', 'Developer', 'Gaming')]
        [string]$ConfigurationName,

        [Parameter(ParameterSetName = 'ConfigFile')]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Configuration file '$_' does not exist."
            }
            return $true
        })]
        [string]$ConfigurationPath,

        [Parameter()]
        [switch]$IncludeProfiles,

        [Parameter()]
        [switch]$IncludeKeybindings,

        [Parameter()]
        [switch]$IncludeSettings,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$BackupExisting,

        [Parameter()]
        [string]$UserConfigPath
    )

    begin {
        Write-DotWinLog "Starting Windows Terminal configuration with Configuration Bridge" -Level "Information"
        
        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            throw "Environment validation failed: $($envTest.Issues -join ', ')"
        }

        # Check if Windows Terminal is installed
        if (-not (Test-WindowsTerminalInstalled)) {
            throw "Windows Terminal is not installed on this system"
        }

        # Initialize Configuration Bridge
        try {
            # Get module configuration path
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
            Write-DotWinLog "Configuration Bridge initialized successfully" -Level "Information"
        }
        catch {
            Write-DotWinLog "Warning: Could not initialize Configuration Bridge, falling back to basic mode: $($_.Exception.Message)" -Level "Warning"
            $configBridge = $null
        }

        $results = @()
        $startTime = Get-Date
    }

    process {
        try {
            # Determine terminal configuration based on parameter set
            $terminalConfig = @{}

            switch ($PSCmdlet.ParameterSetName) {
                'Theme' {
                    Write-DotWinLog "Loading terminal configuration for theme: $Theme" -Level "Information"

                    # Use Configuration Bridge if available, otherwise fall back to module configuration
                    if ($configBridge) {
                        Write-DotWinLog "Using Configuration Bridge for theme: $Theme" -Level "Information"
                        $bridgeConfig = $configBridge.ResolveTerminalConfiguration($Theme)
                        if ($bridgeConfig) {
                            # Build terminal settings from the resolved configuration
                            $terminalConfig = Build-TerminalSettings -Configuration $bridgeConfig -IncludeProfiles:$IncludeProfiles -IncludeKeybindings:$IncludeKeybindings -IncludeSettings:$IncludeSettings
                        } else {
                            Write-DotWinLog "Configuration Bridge did not return configuration for theme: $Theme, falling back to module config" -Level "Warning"
                            $terminalConfig = Get-DotWinTerminalConfiguration -Theme $Theme
                        }
                    } else {
                        Write-DotWinLog "Configuration Bridge not available, using module configuration for theme: $Theme" -Level "Information"
                        $terminalConfig = Get-DotWinTerminalConfiguration -Theme $Theme
                    }
                }
                
                'Configuration' {
                    Write-DotWinLog "Loading terminal configuration by name: $ConfigurationName" -Level "Information"

                    # Use Configuration Bridge for named configurations
                    if ($configBridge) {
                        Write-DotWinLog "Using Configuration Bridge for configuration: $ConfigurationName" -Level "Information"
                        $bridgeConfig = $configBridge.ResolveTerminalConfiguration($ConfigurationName)
                        if ($bridgeConfig) {
                            $terminalConfig = Build-TerminalSettings -Configuration $bridgeConfig -IncludeProfiles:$IncludeProfiles -IncludeKeybindings:$IncludeKeybindings -IncludeSettings:$IncludeSettings
                            $Theme = $ConfigurationName  # Use the configuration name as theme for display
                        } else {
                            throw "Configuration '$ConfigurationName' not found in Configuration Bridge"
                        }
                    } else {
                        Write-DotWinLog "Configuration Bridge not available, falling back to theme configuration for: $ConfigurationName" -Level "Warning"
                        $terminalConfig = Get-DotWinTerminalConfiguration -Theme $ConfigurationName
                        $Theme = $ConfigurationName
                    }
                }

                'ConfigFile' {
                    Write-DotWinLog "Loading terminal configuration from file: $ConfigurationPath" -Level "Information"
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    $terminalConfig = $configContent
                    $Theme = if ($terminalConfig.theme) { $terminalConfig.theme } else { 'Custom' }
                }
            }

            # Get terminal settings path
            $settingsPath = Get-WindowsTerminalSettingsPath
            Write-DotWinLog "Terminal settings path: $settingsPath" -Level "Information"

            # Create terminal configuration item
            $terminalItem = [DotWinWindowsTerminal]::new($Theme)
            $terminalItem.SettingsPath = $settingsPath
            $terminalItem.Configuration = $terminalConfig
            $terminalItem.BackupExisting = $BackupExisting

            # Process terminal configuration
            $terminalStartTime = Get-Date
            $result = [DotWinExecutionResult]::new()
            $result.ItemName = "Windows Terminal ($Theme)"
            $result.ItemType = "WindowsTerminal"

            # Add configuration source information
            $configSource = if ($configBridge) { "ConfigurationBridge" } else { "ModuleOnly" }

            try {
                # Validate that we have a valid configuration
                if (-not $terminalConfig) {
                    throw "No terminal configuration available for theme: $Theme"
                }

                # Test if terminal needs configuration
                $needsConfiguration = -not $terminalItem.Test() -or $Force
                
                if (-not $needsConfiguration) {
                    $result.Success = $true
                    $result.Message = "Windows Terminal already configured"
                    $result.ConfigurationSource = $configSource
                    Write-DotWinLog "Windows Terminal already configured" -Level "Information"
                } else {
                    # Configure the terminal
                    if ($PSCmdlet.ShouldProcess($Theme, "Configure Windows Terminal")) {
                        Write-DotWinLog "Configuring Windows Terminal: $Theme using $configSource" -Level "Information"
                        
                        # Get current state for comparison
                        $beforeState = $terminalItem.GetCurrentState()
                        
                        # Apply the configuration
                        $terminalItem.Apply()
                        
                        # Get new state and record changes
                        $afterState = $terminalItem.GetCurrentState()
                        $result.Changes = @{
                            Before = $beforeState
                            After = $afterState
                        }
                        
                        $result.Success = $true
                        $result.Message = "Windows Terminal configured successfully"
                        $result.ConfigurationSource = $configSource
                        Write-DotWinLog "Successfully configured Windows Terminal: $Theme using $configSource" -Level "Information"
                    } else {
                        $result.Success = $true
                        $result.Message = "Windows Terminal configuration skipped (WhatIf)"
                        $result.ConfigurationSource = $configSource
                        Write-DotWinLog "Windows Terminal configuration skipped: $Theme (WhatIf)" -Level "Information"
                    }
                }
                
            } catch {
                $result.Success = $false
                $result.Message = "Error configuring Windows Terminal: $($_.Exception.Message)"
                $result.ConfigurationSource = $configSource
                Write-DotWinLog "Error configuring Windows Terminal '$Theme': $($_.Exception.Message)" -Level "Error"
            } finally {
                $result.Duration = (Get-Date) - $terminalStartTime
                $results += $result
            }

        } catch {
            Write-DotWinLog "Critical error during Windows Terminal configuration: $($_.Exception.Message)" -Level "Error"
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        Write-DotWinLog "Windows Terminal configuration completed" -Level "Information"
        Write-DotWinLog "Total configurations processed: $($results.Count)" -Level "Information"
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level "Information"
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level "Information"
        
        return $results
    }
}


function Test-WindowsTerminalInstalled {
    <#
    .SYNOPSIS
        Tests if Windows Terminal is installed.
    #>
    [CmdletBinding()]
    param()
    
    try {
        # Check for Windows Terminal package
        $terminalPackage = Get-AppxPackage -Name "Microsoft.WindowsTerminal" -ErrorAction SilentlyContinue
        if ($terminalPackage) {
            return $true
        }
        
        # Check for Windows Terminal Preview
        $terminalPreview = Get-AppxPackage -Name "Microsoft.WindowsTerminalPreview" -ErrorAction SilentlyContinue
        if ($terminalPreview) {
            return $true
        }
        
        return $false
        
    } catch {
        Write-DotWinLog "Error checking Windows Terminal installation: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Get-WindowsTerminalSettingsPath {
    <#
    .SYNOPSIS
        Gets the path to Windows Terminal settings file.
    #>
    [CmdletBinding()]
    param()
    
    # Try Windows Terminal first
    $terminalPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path (Split-Path $terminalPath -Parent)) {
        return $terminalPath
    }
    
    # Try Windows Terminal Preview
    $previewPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    if (Test-Path (Split-Path $previewPath -Parent)) {
        return $previewPath
    }
    
    # Default to regular Windows Terminal path
    return $terminalPath
}

# Removed hardcoded configuration functions - now using Configuration Bridge system
# The following functions have been replaced by the Configuration Bridge:
# - Get-WindowsTerminalConfiguration: Replaced by configBridge.ResolveTerminalConfiguration()
# - Get-WindowsTerminalColorSchemes: Handled by terminal configuration in config/Terminal.ps1
# - Merge-WindowsTerminalConfiguration: Handled by Configuration Bridge merging logic

function Get-WindowsTerminalStatus {
    <#
    .SYNOPSIS
        Gets the status of Windows Terminal configuration.
    
    .DESCRIPTION
        Retrieves information about Windows Terminal installation and configuration.
    
    .OUTPUTS
        Hashtable containing terminal status information.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-DotWinLog "Retrieving Windows Terminal status" -Level "Information"
        
        $status = @{
            IsInstalled = Test-WindowsTerminalInstalled
            SettingsPath = $null
            SettingsExists = $false
            Theme = "Unknown"
            ProfileCount = 0
            HasCustomConfiguration = $false
        }
        
        if ($status.IsInstalled) {
            $status.SettingsPath = Get-WindowsTerminalSettingsPath
            $status.SettingsExists = Test-Path $status.SettingsPath
            
            if ($status.SettingsExists) {
                try {
                    $settingsContent = Get-Content -Path $status.SettingsPath -Raw
                    $settings = $settingsContent | ConvertFrom-Json
                    
                    $status.Theme = if ($settings.theme) { $settings.theme } else { "Unknown" }
                    $status.ProfileCount = if ($settings.profiles -and $settings.profiles.list) { $settings.profiles.list.Count } else { 0 }
                    $status.HasCustomConfiguration = ($settingsContent -match "DotWin")
                    
                } catch {
                    $status.Theme = "Error parsing settings"
                }
            }
        }
        
        Write-DotWinLog "Retrieved Windows Terminal status successfully" -Level "Information"
        return $status
        
    } catch {
        Write-DotWinLog "Error retrieving Windows Terminal status: $($_.Exception.Message)" -Level "Error"
        throw
    }
}
