<#
.SYNOPSIS
    Windows Terminal configuration definitions for the DotWin PowerShell module.

.DESCRIPTION
    This file contains Windows Terminal configurations, themes, and settings,
    providing centralized management for terminal customization.
#>

# Windows Terminal theme configurations
$script:DotWinTerminalThemes = @{
    'DotWinDark' = @{
        Description = "DotWin custom dark theme"
        ColorScheme = @{
            name = "DotWinDark"
            black = "#1e1e1e"
            red = "#f44747"
            green = "#4ec9b0"
            yellow = "#ffcc02"
            blue = "#569cd6"
            purple = "#c586c0"
            cyan = "#4fc1ff"
            white = "#d4d4d4"
            brightBlack = "#5a5a5a"
            brightRed = "#f44747"
            brightGreen = "#4ec9b0"
            brightYellow = "#ffcc02"
            brightBlue = "#569cd6"
            brightPurple = "#c586c0"
            brightCyan = "#4fc1ff"
            brightWhite = "#ffffff"
            background = "#1e1e1e"
            foreground = "#d4d4d4"
            cursorColor = "#ffffff"
            selectionBackground = "#264f78"
        }
        Settings = @{
            theme = "dark"
            defaultProfile = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
            copyOnSelect = $true
            copyFormatting = $false
            wordDelimiters = " ./\\()\"'-:,.;<>~!@#$%^&*|+=[]{}~?\u2502"
            confirmCloseAllTabs = $true
            startOnUserLogin = $false
            launchMode = "default"
            initialCols = 120
            initialRows = 30
        }
    }
    
    'DotWinLight' = @{
        Description = "DotWin custom light theme"
        ColorScheme = @{
            name = "DotWinLight"
            black = "#000000"
            red = "#cd3131"
            green = "#00bc00"
            yellow = "#949800"
            blue = "#0451a5"
            purple = "#bc05bc"
            cyan = "#0598bc"
            white = "#555555"
            brightBlack = "#666666"
            brightRed = "#cd3131"
            brightGreen = "#14ce14"
            brightYellow = "#b5ba00"
            brightBlue = "#0451a5"
            brightPurple = "#bc05bc"
            brightCyan = "#0598bc"
            brightWhite = "#a5a5a5"
            background = "#ffffff"
            foreground = "#000000"
            cursorColor = "#000000"
            selectionBackground = "#add6ff"
        }
        Settings = @{
            theme = "light"
            defaultProfile = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
            copyOnSelect = $true
            copyFormatting = $false
            wordDelimiters = " ./\\()\"'-:,.;<>~!@#$%^&*|+=[]{}~?\u2502"
            confirmCloseAllTabs = $true
            startOnUserLogin = $false
            launchMode = "default"
            initialCols = 120
            initialRows = 30
        }
    }
    
    'Developer' = @{
        Description = "Developer-focused terminal theme"
        ColorScheme = @{
            name = "Developer"
            black = "#282c34"
            red = "#e06c75"
            green = "#98c379"
            yellow = "#e5c07b"
            blue = "#61afef"
            purple = "#c678dd"
            cyan = "#56b6c2"
            white = "#dcdfe4"
            brightBlack = "#5a6374"
            brightRed = "#e06c75"
            brightGreen = "#98c379"
            brightYellow = "#e5c07b"
            brightBlue = "#61afef"
            brightPurple = "#c678dd"
            brightCyan = "#56b6c2"
            brightWhite = "#dcdfe4"
            background = "#282c34"
            foreground = "#dcdfe4"
            cursorColor = "#ffffff"
            selectionBackground = "#3e4451"
        }
        Settings = @{
            theme = "dark"
            defaultProfile = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"  # PowerShell 7
            copyOnSelect = $true
            copyFormatting = $false
            confirmCloseAllTabs = $true
            startOnUserLogin = $false
            launchMode = "maximized"
            initialCols = 140
            initialRows = 40
        }
    }
    
    'Gaming' = @{
        Description = "Gaming-focused terminal theme with RGB accents"
        ColorScheme = @{
            name = "Gaming"
            black = "#0c0c0c"
            red = "#ff0040"
            green = "#00ff41"
            yellow = "#ffff00"
            blue = "#0080ff"
            purple = "#ff00ff"
            cyan = "#00ffff"
            white = "#ffffff"
            brightBlack = "#808080"
            brightRed = "#ff4080"
            brightGreen = "#40ff80"
            brightYellow = "#ffff80"
            brightBlue = "#4080ff"
            brightPurple = "#ff80ff"
            brightCyan = "#80ffff"
            brightWhite = "#ffffff"
            background = "#000000"
            foreground = "#00ff41"
            cursorColor = "#00ff41"
            selectionBackground = "#333333"
        }
        Settings = @{
            theme = "dark"
            defaultProfile = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
            copyOnSelect = $false
            copyFormatting = $false
            confirmCloseAllTabs = $false
            startOnUserLogin = $false
            launchMode = "fullscreen"
            initialCols = 160
            initialRows = 50
        }
    }
}

# Profile configurations for different shells
$script:DotWinTerminalProfiles = @{
    'PowerShell' = @{
        guid = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
        name = "PowerShell"
        commandline = "powershell.exe"
        icon = "ms-appx:///ProfileIcons/{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.png"
        startingDirectory = "%USERPROFILE%"
        fontFace = "Cascadia Code"
        fontSize = 12
        cursorShape = "bar"
        useAcrylic = $false
        acrylicOpacity = 0.8
        backgroundImage = $null
        backgroundImageOpacity = 0.3
        backgroundImageStretchMode = "uniformToFill"
        backgroundImageAlignment = "center"
        scrollbarState = "visible"
        snapOnInput = $true
        historySize = 9001
    }
    
    'PowerShell7' = @{
        guid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
        name = "PowerShell 7"
        commandline = "pwsh.exe"
        icon = "ms-appx:///ProfileIcons/{574e775e-4f2a-5b96-ac1e-a2962a402336}.png"
        startingDirectory = "%USERPROFILE%"
        fontFace = "Cascadia Code"
        fontSize = 12
        cursorShape = "bar"
        useAcrylic = $false
        acrylicOpacity = 0.8
        backgroundImage = $null
        backgroundImageOpacity = 0.3
        backgroundImageStretchMode = "uniformToFill"
        backgroundImageAlignment = "center"
        scrollbarState = "visible"
        snapOnInput = $true
        historySize = 9001
    }
    
    'CommandPrompt' = @{
        guid = "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}"
        name = "Command Prompt"
        commandline = "cmd.exe"
        icon = "ms-appx:///ProfileIcons/{0caa0dad-35be-5f56-a8ff-afceeeaa6101}.png"
        startingDirectory = "%USERPROFILE%"
        fontFace = "Consolas"
        fontSize = 12
        cursorShape = "block"
        useAcrylic = $false
        scrollbarState = "visible"
        snapOnInput = $true
        historySize = 9001
    }
    
    'WSL' = @{
        guid = "{2c4de342-38b7-51cf-b940-2309a097f518}"
        name = "Ubuntu"
        commandline = "wsl.exe -d Ubuntu"
        icon = "ms-appx:///ProfileIcons/{9acb9455-ca41-5af7-950f-6bca1bc9722f}.png"
        startingDirectory = "~"
        fontFace = "Cascadia Code"
        fontSize = 12
        cursorShape = "bar"
        useAcrylic = $false
        backgroundImage = $null
        scrollbarState = "visible"
        snapOnInput = $true
        historySize = 9001
        hidden = $false
    }
    
    'GitBash' = @{
        guid = "{2ece5bfe-50ed-5f3a-ab87-5cd4baafed2b}"
        name = "Git Bash"
        commandline = "C:\\Program Files\\Git\\bin\\bash.exe -i -l"
        icon = "C:\\Program Files\\Git\\mingw64\\share\\git\\git-for-windows.ico"
        startingDirectory = "%USERPROFILE%"
        fontFace = "Cascadia Code"
        fontSize = 12
        cursorShape = "bar"
        useAcrylic = $false
        scrollbarState = "visible"
        snapOnInput = $true
        historySize = 9001
        hidden = $false
    }
}

# Keybinding configurations
$script:DotWinTerminalKeybindings = @{
    'Default' = @(
        @{ command = "copy"; keys = "ctrl+c" },
        @{ command = "paste"; keys = "ctrl+v" },
        @{ command = "find"; keys = "ctrl+f" },
        @{ command = "newTab"; keys = "ctrl+t" },
        @{ command = "closeTab"; keys = "ctrl+w" },
        @{ command = "nextTab"; keys = "ctrl+tab" },
        @{ command = "prevTab"; keys = "ctrl+shift+tab" },
        @{ command = @{ action = "splitPane"; split = "horizontal" }; keys = "alt+shift+minus" },
        @{ command = @{ action = "splitPane"; split = "vertical" }; keys = "alt+shift+plus" },
        @{ command = "toggleFullscreen"; keys = "f11" }
    )
    
    'Developer' = @(
        @{ command = "copy"; keys = "ctrl+c" },
        @{ command = "paste"; keys = "ctrl+v" },
        @{ command = "find"; keys = "ctrl+f" },
        @{ command = "newTab"; keys = "ctrl+t" },
        @{ command = "closeTab"; keys = "ctrl+w" },
        @{ command = "nextTab"; keys = "ctrl+tab" },
        @{ command = "prevTab"; keys = "ctrl+shift+tab" },
        @{ command = @{ action = "splitPane"; split = "horizontal" }; keys = "alt+shift+minus" },
        @{ command = @{ action = "splitPane"; split = "vertical" }; keys = "alt+shift+plus" },
        @{ command = "toggleFullscreen"; keys = "f11" },
        @{ command = @{ action = "newTab"; profile = "PowerShell 7" }; keys = "ctrl+shift+1" },
        @{ command = @{ action = "newTab"; profile = "Ubuntu" }; keys = "ctrl+shift+2" },
        @{ command = @{ action = "newTab"; profile = "Git Bash" }; keys = "ctrl+shift+3" },
        @{ command = "duplicateTab"; keys = "ctrl+shift+d" },
        @{ command = @{ action = "moveFocus"; direction = "down" }; keys = "alt+down" },
        @{ command = @{ action = "moveFocus"; direction = "up" }; keys = "alt+up" },
        @{ command = @{ action = "moveFocus"; direction = "left" }; keys = "alt+left" },
        @{ command = @{ action = "moveFocus"; direction = "right" }; keys = "alt+right" }
    )
    
    'Gaming' = @(
        @{ command = "copy"; keys = "ctrl+c" },
        @{ command = "paste"; keys = "ctrl+v" },
        @{ command = "newTab"; keys = "ctrl+t" },
        @{ command = "closeTab"; keys = "ctrl+w" },
        @{ command = "nextTab"; keys = "ctrl+tab" },
        @{ command = "prevTab"; keys = "ctrl+shift+tab" },
        @{ command = "toggleFullscreen"; keys = "f11" },
        @{ command = @{ action = "adjustFontSize"; delta = 1 }; keys = "ctrl+plus" },
        @{ command = @{ action = "adjustFontSize"; delta = -1 }; keys = "ctrl+minus" },
        @{ command = @{ action = "resetFontSize" }; keys = "ctrl+0" }
    )
}

# Complete terminal configurations combining themes, profiles, and keybindings
$script:DotWinTerminalConfigurations = @{
    'DotWinDark' = @{
        Description = "DotWin dark theme configuration"
        Theme = $script:DotWinTerminalThemes['DotWinDark']
        Profiles = @('PowerShell', 'PowerShell7', 'CommandPrompt')
        Keybindings = 'Default'
        DefaultProfile = 'PowerShell7'
    }
    
    'DotWinLight' = @{
        Description = "DotWin light theme configuration"
        Theme = $script:DotWinTerminalThemes['DotWinLight']
        Profiles = @('PowerShell', 'PowerShell7', 'CommandPrompt')
        Keybindings = 'Default'
        DefaultProfile = 'PowerShell7'
    }
    
    'Developer' = @{
        Description = "Developer-focused terminal configuration"
        Theme = $script:DotWinTerminalThemes['Developer']
        Profiles = @('PowerShell7', 'WSL', 'GitBash', 'CommandPrompt')
        Keybindings = 'Developer'
        DefaultProfile = 'PowerShell7'
    }
    
    'Gaming' = @{
        Description = "Gaming-focused terminal configuration"
        Theme = $script:DotWinTerminalThemes['Gaming']
        Profiles = @('PowerShell', 'CommandPrompt')
        Keybindings = 'Gaming'
        DefaultProfile = 'PowerShell'
    }
}

function Get-TerminalConfiguration {
    <#
    .SYNOPSIS
        Gets a Windows Terminal configuration by name.
    
    .DESCRIPTION
        Retrieves a predefined Windows Terminal configuration.
    
    .PARAMETER ConfigurationName
        The name of the terminal configuration to retrieve.
    
    .OUTPUTS
        Hashtable containing terminal configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('DotWinDark', 'DotWinLight', 'Developer', 'Gaming')]
        [string]$ConfigurationName
    )
    
    if ($script:DotWinTerminalConfigurations.ContainsKey($ConfigurationName)) {
        return $script:DotWinTerminalConfigurations[$ConfigurationName]
    } else {
        Write-Warning "Unknown terminal configuration: $ConfigurationName"
        return $null
    }
}

function Get-TerminalTheme {
    <#
    .SYNOPSIS
        Gets a Windows Terminal theme by name.
    
    .DESCRIPTION
        Retrieves a predefined Windows Terminal theme.
    
    .PARAMETER ThemeName
        The name of the theme to retrieve.
    
    .OUTPUTS
        Hashtable containing theme configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('DotWinDark', 'DotWinLight', 'Developer', 'Gaming')]
        [string]$ThemeName
    )
    
    if ($script:DotWinTerminalThemes.ContainsKey($ThemeName)) {
        return $script:DotWinTerminalThemes[$ThemeName]
    } else {
        Write-Warning "Unknown terminal theme: $ThemeName"
        return $null
    }
}

function Get-TerminalProfile {
    <#
    .SYNOPSIS
        Gets a Windows Terminal profile by name.
    
    .DESCRIPTION
        Retrieves a predefined Windows Terminal profile configuration.
    
    .PARAMETER ProfileName
        The name of the profile to retrieve.
    
    .OUTPUTS
        Hashtable containing profile configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('PowerShell', 'PowerShell7', 'CommandPrompt', 'WSL', 'GitBash')]
        [string]$ProfileName
    )
    
    if ($script:DotWinTerminalProfiles.ContainsKey($ProfileName)) {
        return $script:DotWinTerminalProfiles[$ProfileName]
    } else {
        Write-Warning "Unknown terminal profile: $ProfileName"
        return $null
    }
}

function Get-TerminalKeybindings {
    <#
    .SYNOPSIS
        Gets Windows Terminal keybindings by name.
    
    .DESCRIPTION
        Retrieves predefined Windows Terminal keybinding configurations.
    
    .PARAMETER KeybindingName
        The name of the keybinding set to retrieve.
    
    .OUTPUTS
        Array of keybinding objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Default', 'Developer', 'Gaming')]
        [string]$KeybindingName
    )
    
    if ($script:DotWinTerminalKeybindings.ContainsKey($KeybindingName)) {
        return $script:DotWinTerminalKeybindings[$KeybindingName]
    } else {
        Write-Warning "Unknown keybinding configuration: $KeybindingName"
        return @()
    }
}

function Get-AvailableTerminalConfigurations {
    <#
    .SYNOPSIS
        Gets all available Windows Terminal configurations.
    
    .DESCRIPTION
        Retrieves information about all available terminal configurations.
    
    .OUTPUTS
        Hashtable containing configuration information.
    #>
    [CmdletBinding()]
    param()
    
    $configurations = @{}
    foreach ($configName in $script:DotWinTerminalConfigurations.Keys) {
        $config = $script:DotWinTerminalConfigurations[$configName]
        $configurations[$configName] = @{
            Description = $config.Description
            ProfileCount = $config.Profiles.Count
            DefaultProfile = $config.DefaultProfile
            KeybindingSet = $config.Keybindings
            ThemeName = $configName
        }
    }
    
    return $configurations
}

function Build-TerminalSettings {
    <#
    .SYNOPSIS
        Builds complete Windows Terminal settings from configuration.
    
    .DESCRIPTION
        Constructs a complete Windows Terminal settings object from a configuration.
    
    .PARAMETER ConfigurationName
        The name of the configuration to build settings for.
    
    .OUTPUTS
        Hashtable containing complete terminal settings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('DotWinDark', 'DotWinLight', 'Developer', 'Gaming')]
        [string]$ConfigurationName
    )
    
    $config = Get-TerminalConfiguration -ConfigurationName $ConfigurationName
    if (-not $config) {
        return $null
    }
    
    # Build complete settings object
    $settings = @{
        '$schema' = "https://aka.ms/terminal-profiles-schema"
    }
    
    # Add theme settings
    foreach ($setting in $config.Theme.Settings.GetEnumerator()) {
        $settings[$setting.Key] = $setting.Value
    }
    
    # Add color schemes
    $settings.schemes = @($config.Theme.ColorScheme)
    
    # Add profiles
    $profileList = @()
    foreach ($profileName in $config.Profiles) {
        $terminalProfile = Get-TerminalProfile -ProfileName $profileName
        if ($terminalProfile) {
            # Set color scheme for profile
            $terminalProfile.colorScheme = $config.Theme.ColorScheme.name
            $profileList += $terminalProfile
        }
    }
    
    $settings.profiles = @{
        defaults = @{
            colorScheme = $config.Theme.ColorScheme.name
        }
        list = $profileList
    }
    
    # Set default profile
    $defaultProfile = Get-TerminalProfile -ProfileName $config.DefaultProfile
    if ($defaultProfile) {
        $settings.defaultProfile = $defaultProfile.guid
    }
    
    # Add keybindings
    $keybindings = Get-TerminalKeybindings -KeybindingName $config.Keybindings
    if ($keybindings) {
        $settings.actions = $keybindings
    }
    
    return $settings
}

function Test-TerminalProfileAvailability {
    <#
    .SYNOPSIS
        Tests if terminal profiles are available on the system.
    
    .DESCRIPTION
        Checks if the required applications for terminal profiles are installed.
    
    .PARAMETER ProfileNames
        Array of profile names to test.
    
    .OUTPUTS
        Hashtable containing availability status for each profile.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$ProfileNames
    )
    
    $availability = @{}
    
    foreach ($profileName in $ProfileNames) {
        $terminalProfile = Get-TerminalProfile -ProfileName $profileName
        if (-not $terminalProfile) {
            $availability[$profileName] = @{
                Available = $false
                Reason = "Profile configuration not found"
            }
            continue
        }
        
        $isAvailable = $true
        $reason = ""
        
        switch ($profileName) {
            'PowerShell' {
                if (-not (Get-Command "powershell.exe" -ErrorAction SilentlyContinue)) {
                    $isAvailable = $false
                    $reason = "PowerShell not found"
                }
            }
            'PowerShell7' {
                if (-not (Get-Command "pwsh.exe" -ErrorAction SilentlyContinue)) {
                    $isAvailable = $false
                    $reason = "PowerShell 7 not installed"
                }
            }
            'CommandPrompt' {
                if (-not (Get-Command "cmd.exe" -ErrorAction SilentlyContinue)) {
                    $isAvailable = $false
                    $reason = "Command Prompt not found"
                }
            }
            'WSL' {
                if (-not (Get-Command "wsl.exe" -ErrorAction SilentlyContinue)) {
                    $isAvailable = $false
                    $reason = "WSL not installed"
                }
            }
            'GitBash' {
                if (-not (Test-Path "C:\Program Files\Git\bin\bash.exe")) {
                    $isAvailable = $false
                    $reason = "Git Bash not installed"
                }
            }
        }
        
        $availability[$profileName] = @{
            Available = $isAvailable
            Reason = $reason
        }
    }
    
    return $availability
}

# Note: These functions are available when this config file is dot-sourced
# No Export-ModuleMember needed as this is a configuration file, not a module