<#
.SYNOPSIS
    Unit tests for DotWin profile management functions.

.DESCRIPTION
    Tests for profile management functions including Set-PowershellProfile
    and Set-TerminalProfile.
#>

BeforeAll {
    # Import test infrastructure
    . $PSScriptRoot\..\TestHelpers.ps1
    
    # Import DotWin module
    Import-DotWinModuleForTesting
    
    # Initialize test environment
    Initialize-TestEnvironment
}

AfterAll {
    # Clean up test environment
    Clear-TestEnvironment
}

Describe "Set-PowershellProfile" -Tag @('Unit', 'ProfileManagement') {
    BeforeEach {
        # Mock profile paths
        $script:MockProfilePaths = @{
            AllUsersAllHosts = 'C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1'
            AllUsersCurrentHost = 'C:\Windows\System32\WindowsPowerShell\v1.0\Microsoft.PowerShell_profile.ps1'
            CurrentUserAllHosts = 'C:\Users\TestUser\Documents\WindowsPowerShell\profile.ps1'
            CurrentUserCurrentHost = 'C:\Users\TestUser\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
        }
        
        # Mock file operations
        Mock Test-Path { return $false }
        Mock New-Item { return [PSCustomObject]@{ FullName = $Path } }
        Mock Set-Content { }
        Mock Add-Content { }
        Mock Get-Content { return @() }
        Mock Copy-Item { }
        
        # Mock profile configuration loading
        Mock Test-Path { return $true } -ParameterFilter { $Path -like '*Profile.ps1' }
        Mock . { } -ParameterFilter { $_ -like '*Profile.ps1' }
        Mock Get-PowerShellProfileContent {
            return @"
# PowerShell Profile Configuration
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -EditMode Emacs
Import-Module posh-git -ErrorAction SilentlyContinue
"@
        }
    }

    Context "Profile Creation" {
        It "Should create PowerShell profile for current user" {
            $result = Set-PowershellProfile -Scope 'CurrentUser'
            
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
            $result.ProfilePath | Should -Not -BeNullOrEmpty
            
            Assert-MockCalled New-Item
            Assert-MockCalled Set-Content
        }

        It "Should create PowerShell profile for all users" {
            $result = Set-PowershellProfile -Scope 'AllUsers'
            
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
            
            Assert-MockCalled New-Item
        }

        It "Should create profile directory if it doesn't exist" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '*Documents*' }
            
            $result = Set-PowershellProfile -Scope 'CurrentUser'
            
            Assert-MockCalled New-Item -Times 2  # Directory and profile file
        }

        It "Should validate scope parameter" {
            { Set-PowershellProfile -Scope 'InvalidScope' } | Should -Throw
        }
    }

    Context "Profile Content Management" {
        It "Should use predefined profile template" {
            $result = Set-PowershellProfile -Template 'Developer'
            
            $result.Success | Should -Be $true
            Assert-MockCalled Set-Content
        }

        It "Should use custom profile content" {
            $customContent = "# Custom PowerShell Profile`nWrite-Host 'Hello World'"
            $result = Set-PowershellProfile -Content $customContent
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'Hello World'
            }
        }

        It "Should load profile content from file" {
            $testDir = New-TestDirectory -Name 'ProfileTests'
            $profileFile = Join-Path $testDir 'custom-profile.ps1'
            'Write-Host "Custom Profile"' | Set-Content -Path $profileFile
            
            try {
                $result = Set-PowershellProfile -ProfilePath $profileFile
                $result.Success | Should -Be $true
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }

        It "Should validate profile file exists when using ProfilePath" {
            { Set-PowershellProfile -ProfilePath 'C:\NonExistent\profile.ps1' } | Should -Throw
        }
    }

    Context "Profile Templates" {
        It "Should apply Developer template" {
            Mock Get-ProfileTemplate {
                param($Template)
                if ($Template -eq 'Developer') {
                    return @"
# Developer PowerShell Profile
Import-Module posh-git
Set-PSReadLineOption -PredictionSource History
function prompt { "PS Dev> " }
"@
                }
            }
            
            $result = Set-PowershellProfile -Template 'Developer'
            $result.Success | Should -Be $true
        }

        It "Should apply Administrator template" {
            Mock Get-ProfileTemplate {
                param($Template)
                if ($Template -eq 'Administrator') {
                    return @"
# Administrator PowerShell Profile
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Not running as Administrator"
}
"@
                }
            }
            
            $result = Set-PowershellProfile -Template 'Administrator'
            $result.Success | Should -Be $true
        }

        It "Should apply Minimal template" {
            Mock Get-ProfileTemplate {
                param($Template)
                if ($Template -eq 'Minimal') {
                    return "# Minimal PowerShell Profile"
                }
            }
            
            $result = Set-PowershellProfile -Template 'Minimal'
            $result.Success | Should -Be $true
        }

        It "Should validate template parameter" {
            { Set-PowershellProfile -Template 'InvalidTemplate' } | Should -Throw
        }
    }

    Context "Profile Backup and Restore" {
        It "Should backup existing profile before modification" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like '*profile.ps1' }
            Mock Get-Content { return @('# Existing profile content') }
            
            $result = Set-PowershellProfile -BackupExisting
            
            Assert-MockCalled Copy-Item
            $result.BackupPath | Should -Not -BeNullOrEmpty
        }

        It "Should restore profile from backup" {
            $testDir = New-TestDirectory -Name 'ProfileBackup'
            $backupFile = Join-Path $testDir 'profile_backup.ps1'
            '# Backup content' | Set-Content -Path $backupFile
            
            try {
                $result = Restore-PowerShellProfile -BackupPath $backupFile
                $result.Success | Should -Be $true
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }

        It "Should validate backup file exists" {
            { Restore-PowerShellProfile -BackupPath 'C:\NonExistent\backup.ps1' } | Should -Throw
        }
    }

    Context "Profile Modules and Functions" {
        It "Should install required modules" {
            Mock Install-Module { }
            Mock Get-Module { return $null } -ParameterFilter { $Name -eq 'posh-git' }
            
            $result = Set-PowershellProfile -InstallModules @('posh-git', 'PSReadLine')
            
            Assert-MockCalled Install-Module -Times 2
        }

        It "Should skip already installed modules" {
            Mock Get-Module {
                return [PSCustomObject]@{ Name = 'posh-git'; Version = '1.0.0' }
            } -ParameterFilter { $Name -eq 'posh-git' }
            
            $result = Set-PowershellProfile -InstallModules @('posh-git')
            
            Assert-MockCalled Install-Module -Times 0
        }

        It "Should add custom functions to profile" {
            $functions = @{
                'Get-GitStatus' = 'git status'
                'Set-LocationUp' = 'Set-Location ..'
            }
            
            $result = Set-PowershellProfile -CustomFunctions $functions
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'Get-GitStatus' -and $Value -match 'Set-LocationUp'
            }
        }

        It "Should add aliases to profile" {
            $aliases = @{
                'll' = 'Get-ChildItem -Force'
                'gs' = 'git status'
            }
            
            $result = Set-PowershellProfile -Aliases $aliases
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'Set-Alias ll' -and $Value -match 'Set-Alias gs'
            }
        }
    }

    Context "PowerShell Version Compatibility" {
        It "Should create profile for PowerShell 5.1" {
            Mock $PSVersionTable { @{ PSVersion = [Version]'5.1.19041.1' } }
            
            $result = Set-PowershellProfile -PowerShellVersion '5.1'
            $result.Success | Should -Be $true
        }

        It "Should create profile for PowerShell 7+" {
            Mock $PSVersionTable { @{ PSVersion = [Version]'7.3.0' } }
            
            $result = Set-PowershellProfile -PowerShellVersion '7'
            $result.Success | Should -Be $true
        }

        It "Should create cross-compatible profile" {
            $result = Set-PowershellProfile -CrossCompatible
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match '\$PSVersionTable.PSVersion.Major'
            }
        }
    }

    Context "Error Handling" {
        It "Should handle file creation errors gracefully" {
            Mock New-Item { throw "Access denied" }
            
            $result = Set-PowershellProfile
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Access denied"
        }

        It "Should handle module installation errors gracefully" {
            Mock Install-Module { throw "Module not found" }
            
            $result = Set-PowershellProfile -InstallModules @('NonExistentModule')
            $result.Warnings | Should -Contain "Module not found"
        }

        It "Should handle insufficient permissions for AllUsers scope" {
            Mock Test-Path { return $false }
            Mock New-Item { throw "Access denied" }
            
            $result = Set-PowershellProfile -Scope 'AllUsers'
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Access denied"
        }
    }

    Context "WhatIf Support" {
        It "Should show what profile changes would be made without making them" {
            $result = Set-PowershellProfile -Template 'Developer' -WhatIf
            $result.WhatIfResult | Should -Not -BeNullOrEmpty
            
            Assert-MockCalled Set-Content -Times 0
        }
    }
}

Describe "Set-TerminalProfile" -Tag @('Unit', 'ProfileManagement') {
    BeforeEach {
        # Mock Windows Terminal paths
        $script:MockTerminalPaths = @{
            Settings = 'C:\Users\TestUser\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
            Fragments = 'C:\Users\TestUser\AppData\Local\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\fragments'
        }
        
        # Mock file operations
        Mock Test-Path { return $true }
        Mock Get-Content {
            return @'
{
    "$help": "https://aka.ms/terminal-documentation",
    "$schema": "https://aka.ms/terminal-profiles-schema",
    "defaultProfile": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
    "profiles": {
        "defaults": {},
        "list": [
            {
                "commandline": "%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
                "guid": "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}",
                "hidden": false,
                "name": "Windows PowerShell"
            }
        ]
    }
}
'@ -split "`n"
        } -ParameterFilter { $Path -like '*settings.json' }
        
        Mock Set-Content { }
        Mock Copy-Item { }
        Mock New-Item { }
        
        # Mock terminal configuration loading
        Mock Test-Path { return $true } -ParameterFilter { $Path -like '*Terminal.ps1' }
        Mock . { } -ParameterFilter { $_ -like '*Terminal.ps1' }
        Mock Get-TerminalConfiguration {
            return @{
                colorScheme = 'Campbell Powershell'
                fontSize = 12
                fontFace = 'Cascadia Code'
                cursorShape = 'bar'
            }
        }
    }

    Context "Terminal Profile Creation" {
        It "Should configure Windows Terminal settings" {
            $result = Set-TerminalProfile
            
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Path -like '*settings.json'
            }
        }

        It "Should add PowerShell 7 profile" {
            $result = Set-TerminalProfile -AddPowerShell7
            
            $result.Success | Should -Be $true
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'PowerShell 7' -or $Value -match 'pwsh.exe'
            }
        }

        It "Should add WSL profile" {
            $result = Set-TerminalProfile -AddWSL
            
            $result.Success | Should -Be $true
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'wsl.exe' -or $Value -match 'Ubuntu'
            }
        }

        It "Should add Command Prompt profile" {
            $result = Set-TerminalProfile -AddCommandPrompt
            
            $result.Success | Should -Be $true
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'cmd.exe'
            }
        }
    }

    Context "Terminal Themes and Appearance" {
        It "Should apply color scheme" {
            $result = Set-TerminalProfile -ColorScheme 'One Half Dark'
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'One Half Dark'
            }
        }

        It "Should configure font settings" {
            $fontConfig = @{
                Face = 'Cascadia Code'
                Size = 14
                Weight = 'normal'
            }
            
            $result = Set-TerminalProfile -FontConfiguration $fontConfig
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'Cascadia Code' -and $Value -match '"size": 14'
            }
        }

        It "Should apply predefined theme" {
            Mock Get-TerminalTheme {
                param($Theme)
                if ($Theme -eq 'Developer') {
                    return @{
                        colorScheme = 'One Half Dark'
                        fontSize = 12
                        fontFace = 'Cascadia Code PL'
                        cursorShape = 'filledBox'
                        backgroundImage = $null
                    }
                }
            }
            
            $result = Set-TerminalProfile -Theme 'Developer'
            $result.Success | Should -Be $true
        }

        It "Should validate theme parameter" {
            { Set-TerminalProfile -Theme 'InvalidTheme' } | Should -Throw
        }
    }

    Context "Custom Color Schemes" {
        It "Should add custom color scheme" {
            $colorScheme = @{
                name = 'Custom Dark'
                background = '#1e1e1e'
                foreground = '#d4d4d4'
                black = '#000000'
                red = '#cd3131'
                green = '#0dbc79'
                yellow = '#e5e510'
                blue = '#2472c8'
                purple = '#bc3fbc'
                cyan = '#11a8cd'
                white = '#e5e5e5'
            }
            
            $result = Set-TerminalProfile -CustomColorScheme $colorScheme
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'Custom Dark' -and $Value -match '#1e1e1e'
            }
        }

        It "Should import color scheme from file" {
            $testDir = New-TestDirectory -Name 'TerminalTests'
            $schemeFile = Join-Path $testDir 'scheme.json'
            
            $schemeData = @{
                name = 'Imported Scheme'
                background = '#000000'
                foreground = '#ffffff'
            } | ConvertTo-Json
            
            $schemeData | Set-Content -Path $schemeFile
            
            try {
                $result = Set-TerminalProfile -ImportColorScheme $schemeFile
                $result.Success | Should -Be $true
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }
    }

    Context "Profile Customization" {
        It "Should set default profile" {
            $result = Set-TerminalProfile -DefaultProfile 'PowerShell 7'
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match '"defaultProfile":'
            }
        }

        It "Should configure startup behavior" {
            $startupConfig = @{
                launchMode = 'maximized'
                initialCols = 120
                initialRows = 30
            }
            
            $result = Set-TerminalProfile -StartupConfiguration $startupConfig
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'maximized' -and $Value -match '"initialCols": 120'
            }
        }

        It "Should add key bindings" {
            $keyBindings = @(
                @{
                    command = 'copy'
                    keys = 'ctrl+c'
                },
                @{
                    command = 'paste'
                    keys = 'ctrl+v'
                }
            )
            
            $result = Set-TerminalProfile -KeyBindings $keyBindings
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'ctrl\+c' -and $Value -match 'ctrl\+v'
            }
        }
    }

    Context "Background Images and Effects" {
        It "Should set background image" {
            $backgroundConfig = @{
                backgroundImage = 'C:\Images\terminal-bg.jpg'
                backgroundImageOpacity = 0.3
                backgroundImageStretchMode = 'uniformToFill'
            }
            
            $result = Set-TerminalProfile -BackgroundConfiguration $backgroundConfig
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match 'terminal-bg.jpg' -and $Value -match '"backgroundImageOpacity": 0.3'
            }
        }

        It "Should enable acrylic effect" {
            $result = Set-TerminalProfile -EnableAcrylic -AcrylicOpacity 0.8
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match '"useAcrylic": true' -and $Value -match '"acrylicOpacity": 0.8'
            }
        }
    }

    Context "Backup and Restore" {
        It "Should backup existing settings before modification" {
            $result = Set-TerminalProfile -BackupExisting
            
            Assert-MockCalled Copy-Item
            $result.BackupPath | Should -Not -BeNullOrEmpty
        }

        It "Should restore settings from backup" {
            $testDir = New-TestDirectory -Name 'TerminalBackup'
            $backupFile = Join-Path $testDir 'settings_backup.json'
            '{"test": "backup"}' | Set-Content -Path $backupFile
            
            try {
                $result = Restore-TerminalProfile -BackupPath $backupFile
                $result.Success | Should -Be $true
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }
    }

    Context "Terminal Detection" {
        It "Should detect Windows Terminal installation" {
            Mock Test-Path { return $true } -ParameterFilter { $Path -like '*WindowsTerminal*' }
            
            $result = Test-WindowsTerminalInstalled
            $result | Should -Be $true
        }

        It "Should handle Windows Terminal not installed" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '*WindowsTerminal*' }
            
            $result = Set-TerminalProfile
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Windows Terminal not found"
        }

        It "Should suggest Windows Terminal installation" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '*WindowsTerminal*' }
            
            $result = Set-TerminalProfile -InstallIfMissing
            
            # Should attempt to install Windows Terminal
            $result.InstallationAttempted | Should -Be $true
        }
    }

    Context "JSON Validation" {
        It "Should validate JSON syntax before saving" {
            Mock ConvertFrom-Json { throw "Invalid JSON" }
            
            $result = Set-TerminalProfile -ColorScheme 'Test'
            $result.Success | Should -Be $false
            $result.Error | Should -Match "JSON validation failed"
        }

        It "Should preserve existing settings structure" {
            $result = Set-TerminalProfile -ColorScheme 'Campbell'
            
            # Should maintain the original JSON structure
            Assert-MockCalled Set-Content -ParameterFilter {
                $Value -match '\$help' -and $Value -match '\$schema'
            }
        }
    }

    Context "Error Handling" {
        It "Should handle file access errors gracefully" {
            Mock Set-Content { throw "Access denied" }
            
            $result = Set-TerminalProfile
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Access denied"
        }

        It "Should handle corrupted settings file" {
            Mock Get-Content { return 'Invalid JSON content' }
            Mock ConvertFrom-Json { throw "Invalid JSON" }
            
            $result = Set-TerminalProfile -RestoreDefaults
            $result.Success | Should -Be $true  # Should create new default settings
        }
    }

    Context "WhatIf Support" {
        It "Should show what terminal changes would be made without making them" {
            $result = Set-TerminalProfile -Theme 'Developer' -WhatIf
            $result.WhatIfResult | Should -Not -BeNullOrEmpty
            
            Assert-MockCalled Set-Content -Times 0
        }
    }
}

Describe "Profile Management Integration Tests" -Tag @('Unit', 'ProfileManagement', 'Integration') {
    BeforeEach {
        # Set up comprehensive profile management mocks
        Mock Test-Path { return $false }
        Mock New-Item { }
        Mock Set-Content { }
        Mock Get-Content { return @() }
    }

    Context "Complete Profile Setup Workflow" {
        It "Should configure both PowerShell and Terminal profiles" {
            # Configure PowerShell profile
            $psResult = Set-PowershellProfile -Template 'Developer'
            $psResult.Success | Should -Be $true
            
            # Configure Terminal profile
            $terminalResult = Set-TerminalProfile -Theme 'Developer' -AddPowerShell7
            $terminalResult.Success | Should -Be $true
        }

        It "Should handle profile conflicts gracefully" {
            # Mock existing profiles
            Mock Test-Path { return $true }
            Mock Get-Content { return @('# Existing profile') }
            
            $result = Set-PowershellProfile -Template 'Developer' -BackupExisting
            $result.Success | Should -Be $true
            $result.BackupPath | Should -Not -BeNullOrEmpty
        }
    }

    Context "Cross-Platform Compatibility" {
        It "Should create compatible profiles for different PowerShell versions" {
            $ps5Result = Set-PowershellProfile -PowerShellVersion '5.1'
            $ps7Result = Set-PowershellProfile -PowerShellVersion '7'
            
            $ps5Result.Success | Should -Be $true
            $ps7Result.Success | Should -Be $true
        }
    }
}
