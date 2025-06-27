function Export-DotWinConfiguration {
    <#
    .SYNOPSIS
        Exports the current system state as a reusable DotWin configuration template.

    .DESCRIPTION
        The Export-DotWinConfiguration function captures the current system state including
        installed packages, system settings, and configurations, then exports them as a
        DotWin configuration file. This allows you to recreate your current setup on
        other machines or backup your configuration.

    .PARAMETER OutputPath
        Path where the configuration file should be saved.

    .PARAMETER ConfigurationName
        Name for the exported configuration (default: "Exported System Configuration").

    .PARAMETER IncludePackages
        Include currently installed packages in the export (default: true).

    .PARAMETER IncludeSettings
        Include system settings and registry configurations (default: true).

    .PARAMETER IncludeFeatures
        Include Windows features and optional components (default: true).

    .PARAMETER IncludeUserProfile
        Include user-specific configurations like PowerShell profile, terminal settings (default: true).

    .PARAMETER PackageSource
        Specify which package managers to scan (Winget, Chocolatey, Scoop). Default: all available.

    .PARAMETER ExcludeSystemPackages
        Exclude built-in Windows packages and system components from the export.

    .PARAMETER IncludeMetadata
        Include detailed metadata about the source system in the configuration.

    .PARAMETER Force
        Overwrite existing configuration file if it exists.

    .PARAMETER WhatIf
        Show what would be exported without actually creating the file.

    .EXAMPLE
        Export-DotWinConfiguration -OutputPath "my-system-backup.json"
        
        Exports the complete current system configuration to a file.

    .EXAMPLE
        Export-DotWinConfiguration -OutputPath "dev-setup.json" -ConfigurationName "My Development Setup" -IncludeMetadata
        
        Exports system configuration with a custom name and detailed metadata.

    .EXAMPLE
        Export-DotWinConfiguration -OutputPath "packages-only.json" -IncludePackages -IncludeSettings:$false -IncludeFeatures:$false
        
        Exports only the installed packages, excluding system settings and features.

    .EXAMPLE
        Export-DotWinConfiguration -OutputPath "work-config.json" -PackageSource "Winget" -ExcludeSystemPackages
        
        Exports configuration using only Winget packages, excluding system packages.

    .OUTPUTS
        String
        Returns the path to the created configuration file.

    .NOTES
        This function is perfect for backing up your system configuration or
        creating templates for new machine setups. The exported configuration
        can be used with Invoke-DotWinConfiguration to recreate the setup.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            $directory = Split-Path $_ -Parent
            if ($directory -and -not (Test-Path $directory)) {
                throw "Output directory '$directory' does not exist."
            }
            return $true
        })]
        [string]$OutputPath,

        [Parameter()]
        [string]$ConfigurationName = "Exported System Configuration",

        [Parameter()]
        [switch]$IncludePackages = $false,

        [Parameter()]
        [switch]$IncludeSettings = $false,

        [Parameter()]
        [switch]$IncludeFeatures = $false,

        [Parameter()]
        [switch]$IncludeUserProfile = $false,

        [Parameter()]
        [ValidateSet('Winget', 'Chocolatey', 'Scoop', 'All')]
        [string[]]$PackageSource = @('All'),

        [Parameter()]
        [switch]$ExcludeSystemPackages,

        [Parameter()]
        [switch]$IncludeMetadata,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-DotWinLog "Starting system configuration export" -Level Information
        $startTime = Get-Date

        # Check if output file exists and Force is not specified
        if ((Test-Path $OutputPath) -and -not $Force) {
            throw "Configuration file '$OutputPath' already exists. Use -Force to overwrite."
        }

        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            Write-DotWinLog "Environment validation warnings: $($envTest.Issues -join ', ')" -Level Warning
        }
    }

    process {
        try {
            if ($PSCmdlet.ShouldProcess($OutputPath, "Export system configuration")) {
                
                # Create the configuration structure
                $exportConfig = @{
                    name = $ConfigurationName
                    version = "1.0.0"
                    description = "Exported system configuration from $env:COMPUTERNAME on $(Get-Date -Format 'yyyy-MM-dd')"
                    metadata = @{
                        author = "Export-DotWinConfiguration"
                        category = "System Export"
                        exportedFrom = $env:COMPUTERNAME
                        exportedBy = $env:USERNAME
                        exportedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                        operatingSystem = (Get-CimInstance Win32_OperatingSystem).Caption
                        powerShellVersion = $PSVersionTable.PSVersion.ToString()
                    }
                    items = @()
                }

                # Add detailed metadata if requested
                if ($IncludeMetadata) {
                    Write-DotWinLog "Gathering detailed system metadata" -Level Information
                    
                    try {
                        $systemInfo = Get-CimInstance Win32_ComputerSystem
                        $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
                        
                        $exportConfig.metadata.systemDetails = @{
                            manufacturer = $systemInfo.Manufacturer
                            model = $systemInfo.Model
                            totalMemoryGB = [Math]::Round($systemInfo.TotalPhysicalMemory / 1GB, 2)
                            processor = @{
                                name = $processor.Name
                                cores = $processor.NumberOfCores
                                manufacturer = $processor.Manufacturer
                            }
                        }
                    } catch {
                        Write-DotWinLog "Could not gather detailed system metadata: $($_.Exception.Message)" -Level Warning
                    }
                }

                # Export installed packages
                if ($IncludePackages) {
                    Write-DotWinLog "Exporting installed packages" -Level Information
                    
                    $packageItems = @()
                    
                    # Export Winget packages
                    if ($PackageSource -contains 'All' -or $PackageSource -contains 'Winget') {
                        Write-DotWinLog "Scanning Winget packages" -Level Verbose
                        try {
                            $wingetList = winget list --accept-source-agreements 2>$null | Out-String
                            if ($wingetList -and $wingetList -notlike "*No installed package found*") {
                                $wingetPackages = @()
                                
                                # Parse winget output (simplified parsing)
                                $lines = $wingetList -split "`n" | Where-Object { $_ -match '\S' }
                                foreach ($line in $lines) {
                                    if ($line -match '^([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+(.+)$') {
                                        $packageId = $matches[1].Trim()
                                        
                                        # Skip system packages if requested
                                        if ($ExcludeSystemPackages -and ($packageId -like "Microsoft.*" -or $packageId -like "Windows.*")) {
                                            continue
                                        }
                                        
                                        $wingetPackages += $packageId
                                    }
                                }
                                
                                if ($wingetPackages.Count -gt 0) {
                                    $packageItems += @{
                                        name = "Winget Packages"
                                        type = "Packages"
                                        description = "Packages installed via Windows Package Manager"
                                        enabled = $true
                                        properties = @{
                                            source = "winget"
                                            packages = $wingetPackages
                                            acceptLicenses = $true
                                            acceptSourceAgreements = $true
                                        }
                                    }
                                    Write-DotWinLog "Found $($wingetPackages.Count) Winget packages" -Level Information
                                }
                            }
                        } catch {
                            Write-DotWinLog "Error scanning Winget packages: $($_.Exception.Message)" -Level Warning
                        }
                    }

                    # Export Chocolatey packages
                    if ($PackageSource -contains 'All' -or $PackageSource -contains 'Chocolatey') {
                        Write-DotWinLog "Scanning Chocolatey packages" -Level Verbose
                        try {
                            $chocoList = choco list --local-only 2>$null | Out-String
                            if ($chocoList) {
                                $chocoPackages = @()
                                $lines = $chocoList -split "`n" | Where-Object { $_ -match '\S' -and $_ -notlike "*packages installed*" }
                                
                                foreach ($line in $lines) {
                                    if ($line -match '^([^\s]+)\s+(.+)$') {
                                        $chocoPackages += $matches[1].Trim()
                                    }
                                }
                                
                                if ($chocoPackages.Count -gt 0) {
                                    $packageItems += @{
                                        name = "Chocolatey Packages"
                                        type = "Packages"
                                        description = "Packages installed via Chocolatey"
                                        enabled = $true
                                        properties = @{
                                            source = "chocolatey"
                                            packages = $chocoPackages
                                        }
                                    }
                                    Write-DotWinLog "Found $($chocoPackages.Count) Chocolatey packages" -Level Information
                                }
                            }
                        } catch {
                            Write-DotWinLog "Chocolatey not available or error scanning packages" -Level Verbose
                        }
                    }

                    # Export Scoop packages
                    if ($PackageSource -contains 'All' -or $PackageSource -contains 'Scoop') {
                        Write-DotWinLog "Scanning Scoop packages" -Level Verbose
                        try {
                            $scoopList = scoop list 2>$null | Out-String
                            if ($scoopList) {
                                $scoopPackages = @()
                                $lines = $scoopList -split "`n" | Where-Object { $_ -match '\S' }
                                
                                foreach ($line in $lines) {
                                    if ($line -match '^([^\s]+)\s+(.+)$') {
                                        $scoopPackages += $matches[1].Trim()
                                    }
                                }
                                
                                if ($scoopPackages.Count -gt 0) {
                                    $packageItems += @{
                                        name = "Scoop Packages"
                                        type = "Packages"
                                        description = "Packages installed via Scoop"
                                        enabled = $true
                                        properties = @{
                                            source = "scoop"
                                            packages = $scoopPackages
                                        }
                                    }
                                    Write-DotWinLog "Found $($scoopPackages.Count) Scoop packages" -Level Information
                                }
                            }
                        } catch {
                            Write-DotWinLog "Scoop not available or error scanning packages" -Level Verbose
                        }
                    }

                    $exportConfig.items += $packageItems
                }

                # Export Windows Features
                if ($IncludeFeatures) {
                    Write-DotWinLog "Exporting Windows features" -Level Information
                    
                    try {
                        $enabledFeatures = Get-WindowsOptionalFeature -Online | Where-Object { $_.State -eq 'Enabled' }
                        
                        if ($enabledFeatures) {
                            $featureNames = $enabledFeatures | ForEach-Object { $_.FeatureName }
                            
                            $exportConfig.items += @{
                                name = "Windows Optional Features"
                                type = "WindowsFeatures"
                                description = "Currently enabled Windows optional features"
                                enabled = $true
                                properties = @{
                                    features = $featureNames
                                }
                            }
                            Write-DotWinLog "Found $($featureNames.Count) enabled Windows features" -Level Information
                        }
                    } catch {
                        Write-DotWinLog "Error exporting Windows features: $($_.Exception.Message)" -Level Warning
                    }
                }

                # Export system settings
                if ($IncludeSettings) {
                    Write-DotWinLog "Exporting system settings" -Level Information
                    
                    try {
                        # Export power settings
                        $activePowerScheme = powercfg /getactivescheme 2>$null
                        if ($activePowerScheme) {
                            $powerPlan = "Balanced"  # Default fallback
                            if ($activePowerScheme -like "*High performance*") {
                                $powerPlan = "High Performance"
                            } elseif ($activePowerScheme -like "*Power saver*") {
                                $powerPlan = "Power Saver"
                            }
                            
                            $exportConfig.items += @{
                                name = "Power Settings"
                                type = "PerformanceSettings"
                                description = "Current power and performance settings"
                                enabled = $true
                                properties = @{
                                    powerPlan = $powerPlan
                                }
                            }
                        }

                        # Export some common registry settings
                        $registrySettings = @()
                        
                        # Check UAC setting
                        try {
                            $uacValue = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA" -ErrorAction SilentlyContinue
                            if ($uacValue) {
                                $registrySettings += @{
                                    path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
                                    name = "EnableLUA"
                                    value = $uacValue.EnableLUA
                                    type = "DWORD"
                                    description = "User Account Control setting"
                                }
                            }
                        } catch {
                            Write-DotWinLog "Could not read UAC setting" -Level Verbose
                        }

                        if ($registrySettings.Count -gt 0) {
                            $exportConfig.items += @{
                                name = "Registry Settings"
                                type = "RegistryConfiguration"
                                description = "Current registry configuration settings"
                                enabled = $true
                                properties = @{
                                    settings = $registrySettings
                                }
                            }
                        }
                    } catch {
                        Write-DotWinLog "Error exporting system settings: $($_.Exception.Message)" -Level Warning
                    }
                }

                # Export user profile configurations
                if ($IncludeUserProfile) {
                    Write-DotWinLog "Exporting user profile configurations" -Level Information
                    
                    # Check PowerShell profile
                    $psProfilePath = $PROFILE.CurrentUserCurrentHost
                    if (Test-Path $psProfilePath) {
                        $exportConfig.items += @{
                            name = "PowerShell Profile"
                            type = "PowerShellProfile"
                            description = "Current user PowerShell profile configuration"
                            enabled = $true
                            properties = @{
                                profileType = "CurrentUser"
                                customProfile = $true
                                profilePath = $psProfilePath
                            }
                        }
                        Write-DotWinLog "PowerShell profile found and included" -Level Information
                    }

                    # Check Windows Terminal settings
                    $terminalSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
                    if (Test-Path $terminalSettingsPath) {
                        $exportConfig.items += @{
                            name = "Windows Terminal Configuration"
                            type = "TerminalConfiguration"
                            description = "Current Windows Terminal settings"
                            enabled = $true
                            properties = @{
                                customSettings = $true
                                settingsPath = $terminalSettingsPath
                            }
                        }
                        Write-DotWinLog "Windows Terminal settings found and included" -Level Information
                    }
                }

                # Add validation section
                $exportConfig.validation = @{
                    tests = @()
                }

                # Add post-install instructions
                $exportConfig.postInstallInstructions = @(
                    "Review the imported configuration to ensure it matches your needs",
                    "Some settings may require administrator privileges to apply",
                    "Restart your computer after applying the configuration",
                    "Verify that all applications and features are working correctly"
                )

                # Add prerequisites
                $exportConfig.prerequisites = @(
                    "Windows 10 or Windows 11",
                    "Administrator privileges for system-level changes",
                    "Internet connection for package installation",
                    "Sufficient disk space for applications"
                )

                # Convert to JSON and save
                Write-DotWinLog "Saving configuration to: $OutputPath" -Level Information
                $jsonContent = $exportConfig | ConvertTo-Json -Depth 10
                Set-Content -Path $OutputPath -Value $jsonContent -Encoding UTF8
                
                Write-DotWinLog "Configuration exported successfully" -Level Information
                Write-DotWinLog "Configuration contains $($exportConfig.items.Count) items" -Level Information
                
                return $OutputPath
            } else {
                Write-DotWinLog "Export operation cancelled (WhatIf)" -Level Information
                return $null
            }

        } catch {
            Write-DotWinLog "Error during configuration export: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        Write-DotWinLog "Configuration export completed in $($totalDuration.TotalSeconds) seconds" -Level Information
    }
}