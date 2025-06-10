function Set-TerminalProfile {
    <#
    .SYNOPSIS
        Configures Windows Terminal profiles with DotWin configuration management.

    .DESCRIPTION
        The Set-TerminalProfile function provides comprehensive Windows Terminal
        configuration, including themes, profiles, keybindings, and settings
        while integrating with the DotWin configuration management system.

    .PARAMETER ConfigurationPath
        Path to a configuration file containing terminal settings.

    .PARAMETER Theme
        Apply a predefined theme (Dark, Light, Campbell, Vintage, etc.).

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

    .EXAMPLE
        Set-TerminalProfile -Theme 'Dark' -IncludeProfiles -IncludeKeybindings
        
        Configures Windows Terminal with dark theme, profiles, and keybindings.

    .EXAMPLE
        Set-TerminalProfile -ConfigurationPath 'C:\Config\Terminal.json' -BackupExisting
        
        Applies terminal configuration from file with backup of existing settings.

    .EXAMPLE
        Set-TerminalProfile -Theme 'Campbell' -IncludeSettings -WhatIf
        
        Shows what would happen when applying Campbell theme and settings.

    .OUTPUTS
        DotWinExecutionResult[]
        Returns an array of execution results for each terminal configuration operation.

    .NOTES
        This function requires Windows Terminal to be installed.
        Some settings may require terminal restart to take effect.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Theme')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Theme', Position = 0)]
        [ValidateSet('Dark', 'Light', 'Campbell', 'Vintage', 'OneHalfDark', 'OneHalfLight', 'SolarizedDark', 'SolarizedLight')]
        [string]$Theme,

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
        [switch]$BackupExisting
    )

    begin {
        Write-DotWinLog "Starting Windows Terminal configuration" -Level Information
        
        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            throw "Environment validation failed: $($envTest.Issues -join ', ')"
        }

        # Check if Windows Terminal is installed
        if (-not (Test-WindowsTerminalInstalled)) {
            throw "Windows Terminal is not installed on this system"
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
                    Write-DotWinLog "Loading terminal configuration for theme: $Theme" -Level Information
                    $terminalConfig = Get-WindowsTerminalConfiguration -Theme $Theme -IncludeProfiles:$IncludeProfiles -IncludeKeybindings:$IncludeKeybindings -IncludeSettings:$IncludeSettings
                }
                
                'ConfigFile' {
                    Write-DotWinLog "Loading terminal configuration from file: $ConfigurationPath" -Level Information
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    $terminalConfig = $configContent
                    $Theme = $terminalConfig.theme ?? 'Dark'
                }
            }

            # Get terminal settings path
            $settingsPath = Get-WindowsTerminalSettingsPath
            Write-DotWinLog "Terminal settings path: $settingsPath" -Level Information

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

            try {
                # Test if terminal needs configuration
                $needsConfiguration = -not $terminalItem.Test() -or $Force
                
                if (-not $needsConfiguration) {
                    $result.Success = $true
                    $result.Message = "Windows Terminal already configured"
                    Write-DotWinLog "Windows Terminal already configured" -Level Information
                } else {
                    # Configure the terminal
                    if ($PSCmdlet.ShouldProcess($Theme, "Configure Windows Terminal")) {
                        Write-DotWinLog "Configuring Windows Terminal: $Theme" -Level Information
                        
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
                        Write-DotWinLog "Successfully configured Windows Terminal: $Theme" -Level Information
                    } else {
                        $result.Success = $true
                        $result.Message = "Windows Terminal configuration skipped (WhatIf)"
                        Write-DotWinLog "Windows Terminal configuration skipped: $Theme (WhatIf)" -Level Information
                    }
                }
                
            } catch {
                $result.Success = $false
                $result.Message = "Error configuring Windows Terminal: $($_.Exception.Message)"
                Write-DotWinLog "Error configuring Windows Terminal '$Theme': $($_.Exception.Message)" -Level Error
            } finally {
                $result.Duration = (Get-Date) - $terminalStartTime
                $results += $result
            }

        } catch {
            Write-DotWinLog "Critical error during Windows Terminal configuration: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        Write-DotWinLog "Windows Terminal configuration completed" -Level Information
        Write-DotWinLog "Total configurations processed: $($results.Count)" -Level Information
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level Information
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level Information
        
        return $results
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
            Write-DotWinLog "Testing Windows Terminal configuration: $($this.Name)" -Level Verbose
            
            # Check if settings file exists
            if (-not (Test-Path $this.SettingsPath)) {
                Write-DotWinLog "Windows Terminal settings file does not exist: $($this.SettingsPath)" -Level Verbose
                return $false
            }
            
            # Check if settings contain expected configuration
            $settingsContent = Get-Content -Path $this.SettingsPath -Raw -ErrorAction SilentlyContinue
            if (-not $settingsContent) {
                return $false
            }
            
            try {
                $settings = $settingsContent | ConvertFrom-Json
                
                # Check for DotWin configuration marker
                if (-not $settings.'$schema' -or $settings.'$schema' -notmatch "ms-terminal-settings") {
                    Write-DotWinLog "Windows Terminal settings missing proper schema" -Level Verbose
                    return $false
                }
                
                # Check if theme is applied
                if ($this.Configuration.theme -and $settings.theme -ne $this.Configuration.theme) {
                    Write-DotWinLog "Windows Terminal theme mismatch: expected $($this.Configuration.theme), found $($settings.theme)" -Level Verbose
                    return $false
                }
                
                return $true
                
            } catch {
                Write-DotWinLog "Error parsing Windows Terminal settings JSON: $($_.Exception.Message)" -Level Verbose
                return $false
            }
            
        } catch {
            Write-DotWinLog "Error testing Windows Terminal configuration '$($this.Name)': $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    [void] Apply() {
        try {
            Write-DotWinLog "Configuring Windows Terminal: $($this.Name)" -Level Information
            
            # Create backup if requested and settings exist
            if ($this.BackupExisting -and (Test-Path $this.SettingsPath)) {
                $backupPath = "$($this.SettingsPath).backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Copy-Item -Path $this.SettingsPath -Destination $backupPath -Force
                Write-DotWinLog "Created terminal settings backup: $backupPath" -Level Information
            }
            
            # Ensure settings directory exists
            $settingsDir = Split-Path $this.SettingsPath -Parent
            if (-not (Test-Path $settingsDir)) {
                New-Item -Path $settingsDir -ItemType Directory -Force | Out-Null
                Write-DotWinLog "Created terminal settings directory: $settingsDir" -Level Verbose
            }
            
            # Load existing settings or create new
            $settings = @{}
            if (Test-Path $this.SettingsPath) {
                try {
                    $existingContent = Get-Content -Path $this.SettingsPath -Raw
                    $settings = $existingContent | ConvertFrom-Json -AsHashtable
                } catch {
                    Write-DotWinLog "Error parsing existing terminal settings, creating new: $($_.Exception.Message)" -Level Warning
                    $settings = @{}
                }
            }
            
            # Apply configuration
            $settings = Merge-WindowsTerminalConfiguration -ExistingSettings $settings -NewConfiguration $this.Configuration
            
            # Write settings
            $settingsJson = $settings | ConvertTo-Json -Depth 20
            Set-Content -Path $this.SettingsPath -Value $settingsJson -Encoding UTF8 -Force
            Write-DotWinLog "Windows Terminal settings written to: $($this.SettingsPath)" -Level Information
            
        } catch {
            Write-DotWinLog "Error configuring Windows Terminal '$($this.Name)': $($_.Exception.Message)" -Level Error
            throw
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
                HasDotWinConfiguration = $false
            }
            
            if ($state.Exists) {
                $settingsInfo = Get-Item $this.SettingsPath
                $state.Size = $settingsInfo.Length
                $state.LastModified = $settingsInfo.LastWriteTime
                
                try {
                    $settingsContent = Get-Content -Path $this.SettingsPath -Raw
                    $settings = $settingsContent | ConvertFrom-Json
                    
                    $state.CurrentTheme = $settings.theme ?? "Unknown"
                    $state.ProfileCount = if ($settings.profiles -and $settings.profiles.list) { $settings.profiles.list.Count } else { 0 }
                    $state.HasDotWinConfiguration = ($settingsContent -match "DotWin")
                    
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
        Write-DotWinLog "Error checking Windows Terminal installation: $($_.Exception.Message)" -Level Error
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

function Get-WindowsTerminalConfiguration {
    <#
    .SYNOPSIS
        Gets default Windows Terminal configuration for a theme.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Theme,
        
        [Parameter()]
        [switch]$IncludeProfiles,
        
        [Parameter()]
        [switch]$IncludeKeybindings,
        
        [Parameter()]
        [switch]$IncludeSettings
    )
    
    $config = @{
        '$schema' = "https://aka.ms/terminal-profiles-schema"
        theme = $Theme
        defaultProfile = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"  # PowerShell
    }
    
    if ($IncludeSettings) {
        $config.copyOnSelect = $true
        $config.copyFormatting = $false
        $config.wordDelimiters = " ./\\()`"'-:,.;<>~!@#$%^&*|+=[]{}~?`u{2502}"
        $config.confirmCloseAllTabs = $true
        $config.startOnUserLogin = $false
        $config.launchMode = "default"
        $config.initialCols = 120
        $config.initialRows = 30
    }
    
    if ($IncludeProfiles) {
        $config.profiles = @{
            defaults = @{
                fontFace = "Cascadia Code"
                fontSize = 12
                cursorShape = "bar"
                colorScheme = $Theme
            }
            list = @(
                @{
                    guid = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
                    name = "PowerShell"
                    commandline = "powershell.exe"
                    icon = "ms-appx:///ProfileIcons/{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.png"
                    colorScheme = $Theme
                },
                @{
                    guid = "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}"
                    name = "Command Prompt"
                    commandline = "cmd.exe"
                    icon = "ms-appx:///ProfileIcons/{0caa0dad-35be-5f56-a8ff-afceeeaa6101}.png"
                    colorScheme = $Theme
                }
            )
        }
        
        # Add PowerShell 7 if available
        $pwsh7Path = Get-Command "pwsh.exe" -ErrorAction SilentlyContinue
        if ($pwsh7Path) {
            $config.profiles.list += @{
                guid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
                name = "PowerShell 7"
                commandline = "pwsh.exe"
                icon = "ms-appx:///ProfileIcons/{574e775e-4f2a-5b96-ac1e-a2962a402336}.png"
                colorScheme = $Theme
            }
        }
    }
    
    if ($IncludeKeybindings) {
        $config.actions = @(
            @{ command = "copy"; keys = "ctrl+c" },
            @{ command = "paste"; keys = "ctrl+v" },
            @{ command = "find"; keys = "ctrl+f" },
            @{ command = "newTab"; keys = "ctrl+t" },
            @{ command = "closeTab"; keys = "ctrl+w" },
            @{ command = "nextTab"; keys = "ctrl+tab" },
            @{ command = "prevTab"; keys = "ctrl+shift+tab" },
            @{ command = @{ action = "splitPane"; split = "horizontal" }; keys = "alt+shift+minus" },
            @{ command = @{ action = "splitPane"; split = "vertical" }; keys = "alt+shift+plus" }
        )
    }
    
    # Add color schemes
    $config.schemes = Get-WindowsTerminalColorSchemes -Theme $Theme
    
    return $config
}

function Get-WindowsTerminalColorSchemes {
    <#
    .SYNOPSIS
        Gets color schemes for Windows Terminal themes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Theme
    )
    
    $schemes = @()
    
    switch ($Theme) {
        'Dark' {
            $schemes += @{
                name = "Dark"
                black = "#0C0C0C"
                red = "#C50F1F"
                green = "#13A10E"
                yellow = "#C19C00"
                blue = "#0037DA"
                purple = "#881798"
                cyan = "#3A96DD"
                white = "#CCCCCC"
                brightBlack = "#767676"
                brightRed = "#E74856"
                brightGreen = "#16C60C"
                brightYellow = "#F9F1A5"
                brightBlue = "#3B78FF"
                brightPurple = "#B4009E"
                brightCyan = "#61D6D6"
                brightWhite = "#F2F2F2"
                background = "#0C0C0C"
                foreground = "#CCCCCC"
                cursorColor = "#FFFFFF"
                selectionBackground = "#FFFFFF"
            }
        }
        
        'Light' {
            $schemes += @{
                name = "Light"
                black = "#0C0C0C"
                red = "#C50F1F"
                green = "#13A10E"
                yellow = "#C19C00"
                blue = "#0037DA"
                purple = "#881798"
                cyan = "#3A96DD"
                white = "#CCCCCC"
                brightBlack = "#767676"
                brightRed = "#E74856"
                brightGreen = "#16C60C"
                brightYellow = "#F9F1A5"
                brightBlue = "#3B78FF"
                brightPurple = "#B4009E"
                brightCyan = "#61D6D6"
                brightWhite = "#F2F2F2"
                background = "#FFFFFF"
                foreground = "#0C0C0C"
                cursorColor = "#0C0C0C"
                selectionBackground = "#0C0C0C"
            }
        }
        
        'Campbell' {
            $schemes += @{
                name = "Campbell"
                black = "#0C0C0C"
                red = "#C50F1F"
                green = "#13A10E"
                yellow = "#C19C00"
                blue = "#0037DA"
                purple = "#881798"
                cyan = "#3A96DD"
                white = "#CCCCCC"
                brightBlack = "#767676"
                brightRed = "#E74856"
                brightGreen = "#16C60C"
                brightYellow = "#F9F1A5"
                brightBlue = "#3B78FF"
                brightPurple = "#B4009E"
                brightCyan = "#61D6D6"
                brightWhite = "#F2F2F2"
                background = "#0C0C0C"
                foreground = "#F2F2F2"
                cursorColor = "#FFFFFF"
                selectionBackground = "#FFFFFF"
            }
        }
        
        'OneHalfDark' {
            $schemes += @{
                name = "OneHalfDark"
                black = "#282C34"
                red = "#E06C75"
                green = "#98C379"
                yellow = "#E5C07B"
                blue = "#61AFEF"
                purple = "#C678DD"
                cyan = "#56B6C2"
                white = "#DCDFE4"
                brightBlack = "#5A6374"
                brightRed = "#E06C75"
                brightGreen = "#98C379"
                brightYellow = "#E5C07B"
                brightBlue = "#61AFEF"
                brightPurple = "#C678DD"
                brightCyan = "#56B6C2"
                brightWhite = "#DCDFE4"
                background = "#282C34"
                foreground = "#DCDFE4"
                cursorColor = "#FFFFFF"
                selectionBackground = "#FFFFFF"
            }
        }
        
        'SolarizedDark' {
            $schemes += @{
                name = "SolarizedDark"
                black = "#002B36"
                red = "#DC322F"
                green = "#859900"
                yellow = "#B58900"
                blue = "#268BD2"
                purple = "#D33682"
                cyan = "#2AA198"
                white = "#EEE8D5"
                brightBlack = "#073642"
                brightRed = "#CB4B16"
                brightGreen = "#586E75"
                brightYellow = "#657B83"
                brightBlue = "#839496"
                brightPurple = "#6C71C4"
                brightCyan = "#93A1A1"
                brightWhite = "#FDF6E3"
                background = "#002B36"
                foreground = "#839496"
                cursorColor = "#FFFFFF"
                selectionBackground = "#FFFFFF"
            }
        }
        
        default {
            # Default to Campbell theme
            $schemes += @{
                name = $Theme
                black = "#0C0C0C"
                red = "#C50F1F"
                green = "#13A10E"
                yellow = "#C19C00"
                blue = "#0037DA"
                purple = "#881798"
                cyan = "#3A96DD"
                white = "#CCCCCC"
                brightBlack = "#767676"
                brightRed = "#E74856"
                brightGreen = "#16C60C"
                brightYellow = "#F9F1A5"
                brightBlue = "#3B78FF"
                brightPurple = "#B4009E"
                brightCyan = "#61D6D6"
                brightWhite = "#F2F2F2"
                background = "#0C0C0C"
                foreground = "#F2F2F2"
                cursorColor = "#FFFFFF"
                selectionBackground = "#FFFFFF"
            }
        }
    }
    
    return $schemes
}

function Merge-WindowsTerminalConfiguration {
    <#
    .SYNOPSIS
        Merges new configuration with existing Windows Terminal settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ExistingSettings,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$NewConfiguration
    )
    
    # Start with existing settings
    $mergedSettings = $ExistingSettings.Clone()
    
    # Apply new configuration
    foreach ($key in $NewConfiguration.Keys) {
        if ($key -eq 'profiles' -and $mergedSettings.ContainsKey('profiles')) {
            # Merge profiles carefully
            if (-not $mergedSettings.profiles) {
                $mergedSettings.profiles = @{}
            }
            
            # Merge defaults
            if ($NewConfiguration.profiles.defaults) {
                if (-not $mergedSettings.profiles.defaults) {
                    $mergedSettings.profiles.defaults = @{}
                }
                foreach ($defaultKey in $NewConfiguration.profiles.defaults.Keys) {
                    $mergedSettings.profiles.defaults[$defaultKey] = $NewConfiguration.profiles.defaults[$defaultKey]
                }
            }
            
            # Merge profile list
            if ($NewConfiguration.profiles.list) {
                if (-not $mergedSettings.profiles.list) {
                    $mergedSettings.profiles.list = @()
                }
                
                foreach ($newProfile in $NewConfiguration.profiles.list) {
                    $existingProfile = $mergedSettings.profiles.list | Where-Object { $_.guid -eq $newProfile.guid }
                    if ($existingProfile) {
                        # Update existing profile
                        foreach ($profileKey in $newProfile.Keys) {
                            $existingProfile[$profileKey] = $newProfile[$profileKey]
                        }
                    } else {
                        # Add new profile
                        $mergedSettings.profiles.list += $newProfile
                    }
                }
            }
        } elseif ($key -eq 'schemes' -and $mergedSettings.ContainsKey('schemes')) {
            # Merge color schemes
            if (-not $mergedSettings.schemes) {
                $mergedSettings.schemes = @()
            }
            
            foreach ($newScheme in $NewConfiguration.schemes) {
                $existingScheme = $mergedSettings.schemes | Where-Object { $_.name -eq $newScheme.name }
                if ($existingScheme) {
                    # Update existing scheme
                    foreach ($schemeKey in $newScheme.Keys) {
                        $existingScheme[$schemeKey] = $newScheme[$schemeKey]
                    }
                } else {
                    # Add new scheme
                    $mergedSettings.schemes += $newScheme
                }
            }
        } elseif ($key -eq 'actions' -and $mergedSettings.ContainsKey('actions')) {
            # Merge actions/keybindings
            if (-not $mergedSettings.actions) {
                $mergedSettings.actions = @()
            }
            
            foreach ($newAction in $NewConfiguration.actions) {
                $existingAction = $mergedSettings.actions | Where-Object { $_.keys -eq $newAction.keys }
                if ($existingAction) {
                    # Update existing action
                    $existingAction.command = $newAction.command
                } else {
                    # Add new action
                    $mergedSettings.actions += $newAction
                }
            }
        } else {
            # Direct assignment for other keys
            $mergedSettings[$key] = $NewConfiguration[$key]
        }
    }
    
    return $mergedSettings
}

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
        Write-DotWinLog "Retrieving Windows Terminal status" -Level Information
        
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
                    
                    $status.Theme = $settings.theme ?? "Unknown"
                    $status.ProfileCount = if ($settings.profiles -and $settings.profiles.list) { $settings.profiles.list.Count } else { 0 }
                    $status.HasCustomConfiguration = ($settingsContent -match "DotWin")
                    
                } catch {
                    $status.Theme = "Error parsing settings"
                }
            }
        }
        
        Write-DotWinLog "Retrieved Windows Terminal status successfully" -Level Information
        return $status
        
    } catch {
        Write-DotWinLog "Error retrieving Windows Terminal status: $($_.Exception.Message)" -Level Error
        throw
    }
}