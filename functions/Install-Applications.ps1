function Install-Applications {
    <#
    .SYNOPSIS
        Installs applications with comprehensive configuration management.

    .DESCRIPTION
        The Install-Applications function provides high-level application installation
        capabilities, managing not just the installation but also configuration,
        shortcuts, and post-installation setup tasks.

    .PARAMETER ApplicationList
        Array of application specifications with detailed configuration options.

    .PARAMETER Category
        Install applications from a specific category (Development, Productivity, etc.).

    .PARAMETER ConfigurationPath
        Path to a configuration file containing application definitions.

    .PARAMETER IncludeConfiguration
        Apply post-installation configuration for applications.

    .PARAMETER CreateShortcuts
        Create desktop and start menu shortcuts for installed applications.

    .PARAMETER WhatIf
        Shows what applications would be installed without actually installing them.

    .PARAMETER Force
        Forces installation even if applications appear to be already installed.

    .PARAMETER AcceptLicenses
        Automatically accept all license agreements.

    .EXAMPLE
        Install-Applications -Category 'Development' -IncludeConfiguration

        Installs all development applications with their configurations.

    .EXAMPLE
        $apps = @(
            @{
                Name = 'Visual Studio Code'
                PackageId = 'Microsoft.VisualStudioCode'
                Configuration = @{
                    Extensions = @('ms-python.python', 'ms-vscode.powershell')
                    Settings = @{ 'editor.fontSize' = 14 }
                }
                Shortcuts = @{
                    Desktop = $true
                    StartMenu = $true
                }
            }
        )
        Install-Applications -ApplicationList $apps -IncludeConfiguration

        Installs Visual Studio Code with specific extensions and settings.

    .OUTPUTS
        DotWinExecutionResult[]
        Returns an array of execution results for each application installation.

    .NOTES
        This function requires appropriate permissions for application installation.
        Some applications may require administrator privileges.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ApplicationList')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ApplicationList', Position = 0)]
        [object[]]$ApplicationList,

        [Parameter(Mandatory = $true, ParameterSetName = 'Category')]
        [ValidateSet('Development', 'Productivity', 'Media', 'Gaming', 'Utilities', 'Security', 'Communication')]
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
        [switch]$IncludeConfiguration,

        [Parameter()]
        [switch]$CreateShortcuts,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$AcceptLicenses
    )

    begin {
        # Start master progress bar for application installation process
        $masterProgressId = Start-DotWinProgress -Activity "Installing Applications" -Status "Initializing..." -TotalOperations 4

        try {
            Write-DotWinProgress -ProgressId $masterProgressId -Status "Validating environment..." -PercentComplete 10

            # Validate environment
            $envTest = Test-DotWinEnvironment
            if (-not $envTest.IsValid) {
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Environment validation failed: $($envTest.Issues -join ', ')"
                throw "Environment validation failed: $($envTest.Issues -join ', ')"
            }

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Loading required modules..." -PercentComplete 20

            # Import required modules/scripts
            $wingetPath = Join-Path $script:DotWinAppsPath "Winget.ps1"
            if (Test-Path $wingetPath) {
                . $wingetPath
            } else {
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Winget wrapper not found at: $wingetPath"
                throw "Winget wrapper not found at: $wingetPath"
            }

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Environment validated successfully" -PercentComplete 30
            $results = @()
            $startTime = Get-Date
        } catch {
            if ($masterProgressId) {
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Initialization failed: $($_.Exception.Message)"
            }
            throw
        }
    }

    process {
        try {
            # Determine applications to install based on parameter set
            $applicationsToInstall = @()

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Determining applications to install..." -PercentComplete 40

            switch ($PSCmdlet.ParameterSetName) {
                'ApplicationList' {
                    $applicationsToInstall = $ApplicationList
                    Write-DotWinLog "Processing $($ApplicationList.Count) applications from list" -Level Information -ShowWithProgress
                }

                'Category' {
                    Write-DotWinLog "Loading applications from category: $Category" -Level Information -ShowWithProgress
                    $packagesConfigPath = Join-Path $script:DotWinConfigPath "Packages.ps1"

                    if (Test-Path $packagesConfigPath) {
                        . $packagesConfigPath
                        $applicationsToInstall = Get-ApplicationsByCategory -Category $Category
                        Write-DotWinLog "Found $($applicationsToInstall.Count) applications in category '$Category'" -Level Information -ShowWithProgress
                    } else {
                        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Packages configuration file not found: $packagesConfigPath"
                        throw "Packages configuration file not found: $packagesConfigPath"
                    }
                }

                'ConfigFile' {
                    Write-DotWinLog "Loading applications from configuration file: $ConfigurationPath" -Level Information -ShowWithProgress
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    $applicationsToInstall = $configContent.applications
                }
            }

            if ($applicationsToInstall.Count -eq 0) {
                Write-DotWinLog "No applications to install" -Level Warning -ShowWithProgress
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Completed (no applications)" -Message "No applications to install"
                return $results
            }

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Processing $($applicationsToInstall.Count) applications" -PercentComplete 50 -TotalOperations $applicationsToInstall.Count

            # Process each application with nested progress
            $appIndex = 0
            foreach ($appSpec in $applicationsToInstall) {
                $appIndex++
                $appProgressPercent = [Math]::Round((($appIndex / $applicationsToInstall.Count) * 40) + 50, 0)

                # Create nested progress for individual application
                $appProgressId = Start-DotWinProgress -Activity "Installing: $($appSpec.Name -or $appSpec)" -Status "Initializing..." -ParentId $masterProgressId

                # Update master progress
                Write-DotWinProgress -ProgressId $masterProgressId -Status "Installing application $appIndex of $($applicationsToInstall.Count): $($appSpec.Name -or $appSpec)" -PercentComplete $appProgressPercent -CurrentOperation $appIndex

                $appStartTime = Get-Date
                $result = [DotWinExecutionResult]::new()

                try {
                    Write-DotWinProgress -ProgressId $appProgressId -Status "Parsing application configuration..." -PercentComplete 10

                    # Parse application specification
                    $appConfig = ConvertTo-ApplicationConfiguration -ApplicationSpec $appSpec -AcceptLicenses:$AcceptLicenses

                    $result.ItemName = $appConfig.Name
                    $result.ItemType = "Application"
                    $result.ProgressId = $appProgressId

                    Write-DotWinProgress -ProgressId $appProgressId -Status "Installing package..." -PercentComplete 30

                    # Step 1: Install the base package
                    $packageResult = Install-ApplicationPackage -ApplicationConfig $appConfig -Force:$Force

                    if (-not $packageResult.Success) {
                        throw "Failed to install application package: $($packageResult.Message)"
                    }

                    $result.Changes = @{
                        PackageInstallation = $packageResult.Changes
                    }

                    # Step 2: Apply post-installation configuration
                    if ($IncludeConfiguration -and $appConfig.Configuration) {
                        Write-DotWinProgress -ProgressId $appProgressId -Status "Applying configuration..." -PercentComplete 60

                        $configResult = Set-ApplicationConfiguration -ApplicationConfig $appConfig
                        $result.Changes.Configuration = $configResult.Changes

                        if (-not $configResult.Success) {
                            Write-DotWinLog "Warning: Configuration failed for '$($appConfig.Name)': $($configResult.Message)" -Level Warning -ShowWithProgress
                        }
                    }

                    # Step 3: Create shortcuts if requested
                    if ($CreateShortcuts -and $appConfig.Shortcuts) {
                        Write-DotWinProgress -ProgressId $appProgressId -Status "Creating shortcuts..." -PercentComplete 80

                        $shortcutResult = New-ApplicationShortcuts -ApplicationConfig $appConfig
                        $result.Changes.Shortcuts = $shortcutResult.Changes

                        if (-not $shortcutResult.Success) {
                            Write-DotWinLog "Warning: Shortcut creation failed for '$($appConfig.Name)': $($shortcutResult.Message)" -Level Warning -ShowWithProgress
                        }
                    }

                    $result.Success = $true
                    $result.Message = "Application installed and configured successfully"
                    Write-DotWinProgress -ProgressId $appProgressId -Status "Installation completed successfully" -PercentComplete 100
                    Complete-DotWinProgress -ProgressId $appProgressId -Status "Completed successfully" -Message "Successfully installed and configured application: $($appConfig.Name)"

                } catch {
                    $result.Success = $false
                    $result.Message = "Error installing application: $($_.Exception.Message)"
                    Write-DotWinProgress -ProgressId $appProgressId -Status "Failed" -PercentComplete 100
                    Complete-DotWinProgress -ProgressId $appProgressId -Status "Failed" -Message "Error installing application '$($result.ItemName)': $($_.Exception.Message)"
                } finally {
                    $result.Duration = (Get-Date) - $appStartTime
                    $results += $result
                }
            }

        } catch {
            Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Critical error during application installation: $($_.Exception.Message)"
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count

        # Complete master progress with summary statistics
        $summaryMetrics = @{
            TotalApplications = $results.Count
            SuccessfulApplications = $successCount
            FailedApplications = $failureCount
            TotalDurationSeconds = [Math]::Round($totalDuration.TotalSeconds, 2)
            AverageApplicationDuration = if ($results.Count -gt 0) { [Math]::Round(($results | Measure-Object -Property Duration -Average).Average.TotalSeconds, 2) } else { 0 }
            ConfigurationApplied = ($results | Where-Object { $_.Changes.Configuration }).Count
            ShortcutsCreated = ($results | Where-Object { $_.Changes.Shortcuts }).Count
        }

        $summaryMessage = "Application installation completed: $successCount successful, $failureCount failed (Total: $($results.Count) applications, Duration: $($summaryMetrics.TotalDurationSeconds)s)"

        Write-DotWinProgress -ProgressId $masterProgressId -Status "Finalizing..." -PercentComplete 95
        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Completed" -FinalMetrics $summaryMetrics -Message $summaryMessage

        # Show summary with progress coordination
        Write-DotWinLog "Application installation completed" -Level Information -ShowWithProgress
        Write-DotWinLog "Total applications processed: $($results.Count)" -Level Information -ShowWithProgress
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level Information -ShowWithProgress
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level Information -ShowWithProgress

        # Ensure we always return an array, even for single items
        if ($results -is [array]) {
            return $results
        } else {
            return @($results)
        }
    }
}

function Install-ApplicationPackage {
    <#
    .SYNOPSIS
        Installs the base package for an application.

    .DESCRIPTION
        Internal function to handle the core package installation for an application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ApplicationConfig,

        [Parameter()]
        [switch]$Force
    )

    try {
        # Create winget package configuration
        $packageItem = [DotWinWingetPackage]::new($ApplicationConfig.PackageId)
        $packageItem.Name = $ApplicationConfig.Name
        $packageItem.Version = $ApplicationConfig.Version
        $packageItem.Source = $ApplicationConfig.Source
        $packageItem.AcceptLicense = $ApplicationConfig.AcceptLicense
        $packageItem.AcceptSourceAgreements = $ApplicationConfig.AcceptSourceAgreements
        $packageItem.InstallOptions = $ApplicationConfig.InstallOptions

        # Test if already installed (unless forced)
        if (-not $Force) {
            $isInstalled = $packageItem.Test()
            if ($isInstalled) {
                return @{
                    Success = $true
                    Message = "Application package already installed"
                    Changes = @{}
                }
            }
        }

        # Get current state for comparison
        $beforeState = $packageItem.GetCurrentState()

        # Install the package
        $packageItem.Apply()

        # Get new state and record changes
        $afterState = $packageItem.GetCurrentState()

        return @{
            Success = $true
            Message = "Application package installed successfully"
            Changes = @{
                Before = $beforeState
                After = $afterState
            }
        }

    } catch {
        return @{
            Success = $false
            Message = "Error installing application package: $($_.Exception.Message)"
            Changes = @{}
        }
    }
}

function Set-ApplicationConfiguration {
    <#
    .SYNOPSIS
        Applies post-installation configuration for an application.

    .DESCRIPTION
        Internal function to handle application-specific configuration after installation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ApplicationConfig
    )

    $changes = @{}

    try {
        $config = $ApplicationConfig.Configuration

        # Handle Visual Studio Code configuration
        if ($ApplicationConfig.PackageId -like '*VisualStudioCode*') {
            $changes = Set-VSCodeConfiguration -Configuration $config
        }
        # Handle Git configuration
        elseif ($ApplicationConfig.PackageId -like '*Git*') {
            $changes = Set-GitConfiguration -Configuration $config
        }
        # Handle PowerShell configuration
        elseif ($ApplicationConfig.PackageId -like '*PowerShell*') {
            $changes = Set-PowerShellConfiguration -Configuration $config
        }
        # Handle Windows Terminal configuration
        elseif ($ApplicationConfig.PackageId -like '*WindowsTerminal*') {
            $changes = Set-WindowsTerminalConfiguration -Configuration $config
        }
        # Generic configuration handling
        else {
            $changes = Set-GenericApplicationConfiguration -ApplicationConfig $ApplicationConfig
        }

        return @{
            Success = $true
            Message = "Application configuration applied successfully"
            Changes = $changes
        }

    } catch {
        return @{
            Success = $false
            Message = "Error applying application configuration: $($_.Exception.Message)"
            Changes = $changes
        }
    }
}

function Set-VSCodeConfiguration {
    <#
    .SYNOPSIS
        Configures Visual Studio Code after installation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )

    $changes = @{}

    try {
        # Install extensions
        if ($Configuration.Extensions) {
            $changes.Extensions = @()
            foreach ($extension in $Configuration.Extensions) {
                try {
                    Write-DotWinLog "Installing VS Code extension: $extension" -Level Verbose
                    & code --install-extension $extension --force 2>$null
                    if ($LASTEXITCODE -eq 0) {
                        $changes.Extensions += @{ Extension = $extension; Status = "Installed" }
                    } else {
                        $changes.Extensions += @{ Extension = $extension; Status = "Failed" }
                    }
                } catch {
                    $changes.Extensions += @{ Extension = $extension; Status = "Error"; Message = $_.Exception.Message }
                }
            }
        }

        # Apply settings
        if ($Configuration.Settings) {
            $settingsPath = Join-Path $env:APPDATA "Code\User\settings.json"
            $settingsDir = Split-Path $settingsPath -Parent

            if (-not (Test-Path $settingsDir)) {
                New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
            }

            $existingSettings = @{}
            if (Test-Path $settingsPath) {
                $existingSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
            }

            # Merge settings
            foreach ($setting in $Configuration.Settings.GetEnumerator()) {
                $existingSettings[$setting.Key] = $setting.Value
            }

            $existingSettings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
            $changes.Settings = $Configuration.Settings
        }

        return $changes

    } catch {
        Write-DotWinLog "Error configuring VS Code: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Set-GitConfiguration {
    <#
    .SYNOPSIS
        Configures Git after installation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )

    $changes = @{}

    try {
        # Set global Git configuration
        if ($Configuration.GlobalConfig) {
            $changes.GlobalConfig = @{}
            foreach ($config in $Configuration.GlobalConfig.GetEnumerator()) {
                try {
                    & git config --global $config.Key $config.Value
                    $changes.GlobalConfig[$config.Key] = $config.Value
                } catch {
                    Write-DotWinLog "Error setting Git config '$($config.Key)': $($_.Exception.Message)" -Level Warning
                }
            }
        }

        return $changes

    } catch {
        Write-DotWinLog "Error configuring Git: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Set-PowerShellConfiguration {
    <#
    .SYNOPSIS
        Configures PowerShell after installation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )

    $changes = @{}

    try {
        # Install PowerShell modules
        if ($Configuration.Modules) {
            $changes.Modules = @()
            foreach ($module in $Configuration.Modules) {
                try {
                    Write-DotWinLog "Installing PowerShell module: $module" -Level Verbose
                    Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
                    $changes.Modules += @{ Module = $module; Status = "Installed" }
                } catch {
                    $changes.Modules += @{ Module = $module; Status = "Failed"; Message = $_.Exception.Message }
                }
            }
        }

        return $changes

    } catch {
        Write-DotWinLog "Error configuring PowerShell: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Set-WindowsTerminalConfiguration {
    <#
    .SYNOPSIS
        Configures Windows Terminal after installation.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )

    $changes = @{}

    try {
        # Apply terminal settings
        if ($Configuration.Settings) {
            $settingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

            if (Test-Path $settingsPath) {
                $existingSettings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable

                # Merge settings
                foreach ($setting in $Configuration.Settings.GetEnumerator()) {
                    $existingSettings[$setting.Key] = $setting.Value
                }

                $existingSettings | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
                $changes.Settings = $Configuration.Settings
            }
        }

        return $changes

    } catch {
        Write-DotWinLog "Error configuring Windows Terminal: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Set-GenericApplicationConfiguration {
    <#
    .SYNOPSIS
        Handles generic application configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ApplicationConfig
    )

    $changes = @{}

    try {
        # Handle registry settings
        if ($ApplicationConfig.Configuration.Registry) {
            $changes.Registry = Set-ApplicationRegistrySettings -RegistrySettings $ApplicationConfig.Configuration.Registry
        }

        # Handle file operations
        if ($ApplicationConfig.Configuration.Files) {
            $changes.Files = Set-ApplicationFileSettings -FileSettings $ApplicationConfig.Configuration.Files
        }

        return $changes

    } catch {
        Write-DotWinLog "Error applying generic application configuration: $($_.Exception.Message)" -Level Error
        throw
    }
}

function New-ApplicationShortcuts {
    <#
    .SYNOPSIS
        Creates shortcuts for an installed application.

    .DESCRIPTION
        Internal function to create desktop and start menu shortcuts for applications.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ApplicationConfig
    )

    $changes = @{}

    try {
        $shortcuts = $ApplicationConfig.Shortcuts

        # Create desktop shortcut
        if ($shortcuts.Desktop) {
            $desktopPath = [Environment]::GetFolderPath('Desktop')
            $shortcutPath = Join-Path $desktopPath "$($ApplicationConfig.Name).lnk"

            if ($shortcuts.TargetPath) {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $shortcuts.TargetPath
                if ($shortcuts.Arguments) { $shortcut.Arguments = $shortcuts.Arguments }
                if ($shortcuts.WorkingDirectory) { $shortcut.WorkingDirectory = $shortcuts.WorkingDirectory }
                if ($shortcuts.IconLocation) { $shortcut.IconLocation = $shortcuts.IconLocation }
                $shortcut.Save()

                $changes.Desktop = $shortcutPath
            }
        }

        # Create start menu shortcut
        if ($shortcuts.StartMenu) {
            $startMenuPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
            $shortcutPath = Join-Path $startMenuPath "$($ApplicationConfig.Name).lnk"

            if ($shortcuts.TargetPath) {
                $shell = New-Object -ComObject WScript.Shell
                $shortcut = $shell.CreateShortcut($shortcutPath)
                $shortcut.TargetPath = $shortcuts.TargetPath
                if ($shortcuts.Arguments) { $shortcut.Arguments = $shortcuts.Arguments }
                if ($shortcuts.WorkingDirectory) { $shortcut.WorkingDirectory = $shortcuts.WorkingDirectory }
                if ($shortcuts.IconLocation) { $shortcut.IconLocation = $shortcuts.IconLocation }
                $shortcut.Save()

                $changes.StartMenu = $shortcutPath
            }
        }

        return @{
            Success = $true
            Message = "Shortcuts created successfully"
            Changes = $changes
        }

    } catch {
        return @{
            Success = $false
            Message = "Error creating shortcuts: $($_.Exception.Message)"
            Changes = $changes
        }
    }
}

function ConvertTo-ApplicationConfiguration {
    <#
    .SYNOPSIS
        Converts an application specification to a standardized configuration object.

    .DESCRIPTION
        Internal function to normalize application specifications from various formats
        into a consistent configuration object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$ApplicationSpec,

        [Parameter()]
        [switch]$AcceptLicenses
    )

    $config = @{
        Name = $null
        PackageId = $null
        Version = $null
        Source = 'winget'
        AcceptLicense = $AcceptLicenses.IsPresent
        AcceptSourceAgreements = $AcceptLicenses.IsPresent
        InstallOptions = @{}
        Configuration = @{}
        Shortcuts = @{}
    }

    if ($ApplicationSpec -is [string]) {
        # Simple string package ID
        $config.PackageId = $ApplicationSpec
        $config.Name = $ApplicationSpec
    } elseif ($ApplicationSpec -is [hashtable] -or $ApplicationSpec -is [PSCustomObject]) {
        # Detailed application configuration
        $config.Name = if ($ApplicationSpec.Name) { $ApplicationSpec.Name } elseif ($ApplicationSpec.PackageId) { $ApplicationSpec.PackageId } else { $ApplicationSpec.Id }
        $config.PackageId = if ($ApplicationSpec.PackageId) { $ApplicationSpec.PackageId } elseif ($ApplicationSpec.Id) { $ApplicationSpec.Id } else { $ApplicationSpec.Name }
        $config.Version = $ApplicationSpec.Version
        $config.Source = if ($ApplicationSpec.Source) { $ApplicationSpec.Source } else { 'winget' }

        if ($null -ne $ApplicationSpec.AcceptLicense ) {
            $config.AcceptLicense = $ApplicationSpec.AcceptLicense
        }

        if ($null -ne $ApplicationSpec.AcceptSourceAgreements) {
            $config.AcceptSourceAgreements = $ApplicationSpec.AcceptSourceAgreements
        }

        if ($ApplicationSpec.InstallOptions) {
            $config.InstallOptions = $ApplicationSpec.InstallOptions
        }

        if ($ApplicationSpec.Configuration) {
            $config.Configuration = $ApplicationSpec.Configuration
        }

        if ($ApplicationSpec.Shortcuts) {
            $config.Shortcuts = $ApplicationSpec.Shortcuts
        }
    } else {
        throw "Invalid application specification format. Expected string or hashtable/object."
    }

    if (-not $config.PackageId) {
        throw "Package ID is required but not specified in application specification."
    }

    if (-not $config.Name) {
        $config.Name = $config.PackageId
    }

    return $config
}

function Set-ApplicationRegistrySettings {
    <#
    .SYNOPSIS
        Applies registry settings for an application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$RegistrySettings
    )

    $changes = @{}

    foreach ($setting in $RegistrySettings.GetEnumerator()) {
        try {
            $keyPath = $setting.Key
            $values = $setting.Value

            # Ensure registry key exists
            if (-not (Test-Path $keyPath)) {
                New-Item -Path $keyPath -Force | Out-Null
            }

            # Set registry values
            foreach ($value in $values.GetEnumerator()) {
                Set-ItemProperty -Path $keyPath -Name $value.Key -Value $value.Value -Force
                $changes["$keyPath\$($value.Key)"] = $value.Value
            }
        } catch {
            Write-DotWinLog "Error setting registry value '$($setting.Key)': $($_.Exception.Message)" -Level Warning
        }
    }

    return $changes
}

function Set-ApplicationFileSettings {
    <#
    .SYNOPSIS
        Applies file settings for an application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$FileSettings
    )

    $changes = @{}

    foreach ($setting in $FileSettings.GetEnumerator()) {
        try {
            $filePath = $setting.Key
            $content = $setting.Value

            # Ensure directory exists
            $directory = Split-Path $filePath -Parent
            if ($directory -and -not (Test-Path $directory)) {
                New-Item -Path $directory -ItemType Directory -Force | Out-Null
            }

            # Write file content
            if ($content -is [string]) {
                Set-Content -Path $filePath -Value $content -Encoding UTF8
            } else {
                $content | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8
            }

            $changes[$filePath] = "Updated"
        } catch {
            Write-DotWinLog "Error setting file '$($setting.Key)': $($_.Exception.Message)" -Level Warning
        }
    }

    return $changes
}