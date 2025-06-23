<#
.SYNOPSIS
    Unit tests for DotWin system configuration functions.

.DESCRIPTION
    Tests for system configuration functions including Enable-Features,
    Remove-Bloatware, and Disable-Telemetry.
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

Describe "Enable-Features" -Tag @('Unit', 'SystemConfiguration') {
    BeforeEach {
        # Mock Windows Features
        Set-MockWindowsFeatures
        
        # Mock Enable-WindowsOptionalFeature
        Mock Enable-WindowsOptionalFeature {
            return [PSCustomObject]@{
                FeatureName = $FeatureName
                State = 'Enabled'
                RestartRequired = 'Possible'
            }
        }
        
        # Mock DISM operations
        Mock Start-Process {
            return [PSCustomObject]@{
                ExitCode = 0
                HasExited = $true
            }
        } -ParameterFilter { $FilePath -eq 'dism.exe' }
        
        # Mock registry operations
        Mock Set-ItemProperty { }
        Mock New-ItemProperty { }
        Mock Test-Path { return $true }
    }

    Context "Windows Optional Features" {
        It "Should enable a single Windows feature" {
            $result = Enable-Features -FeatureName 'Microsoft-Windows-Subsystem-Linux'
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
            
            Assert-MockCalled Enable-WindowsOptionalFeature -ParameterFilter {
                $FeatureName -eq 'Microsoft-Windows-Subsystem-Linux'
            }
        }

        It "Should enable multiple Windows features" {
            $features = @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform')
            $result = Enable-Features -FeatureName $features
            
            $result | Should -BeOfType [Array]
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $true
            $result[1].Success | Should -Be $true
        }

        It "Should handle feature already enabled" {
            Mock Get-WindowsOptionalFeature {
                return [PSCustomObject]@{
                    FeatureName = 'Microsoft-Windows-Subsystem-Linux'
                    State = 'Enabled'
                }
            }
            
            $result = Enable-Features -FeatureName 'Microsoft-Windows-Subsystem-Linux'
            $result.Message | Should -Match "already enabled"
        }

        It "Should force enable features when requested" {
            Mock Get-WindowsOptionalFeature {
                return [PSCustomObject]@{
                    FeatureName = 'Microsoft-Windows-Subsystem-Linux'
                    State = 'Enabled'
                }
            }
            
            $result = Enable-Features -FeatureName 'Microsoft-Windows-Subsystem-Linux' -Force
            
            Assert-MockCalled Enable-WindowsOptionalFeature
        }
    }

    Context "Feature Categories" {
        It "Should enable development features" {
            Mock Get-DevelopmentFeatures {
                return @('Microsoft-Windows-Subsystem-Linux', 'VirtualMachinePlatform', 'Microsoft-Hyper-V-All')
            }
            
            $result = Enable-Features -Category 'Development'
            $result | Should -Not -BeNull
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should enable virtualization features" {
            Mock Get-VirtualizationFeatures {
                return @('VirtualMachinePlatform', 'Microsoft-Hyper-V-All')
            }
            
            $result = Enable-Features -Category 'Virtualization'
            $result | Should -Not -BeNull
        }

        It "Should enable security features" {
            Mock Get-SecurityFeatures {
                return @('Windows-Defender-Default-Definitions', 'BitLocker')
            }
            
            $result = Enable-Features -Category 'Security'
            $result | Should -Not -BeNull
        }

        It "Should validate category parameter" {
            { Enable-Features -Category 'InvalidCategory' } | Should -Throw
        }
    }

    Context "Feature Dependencies" {
        It "Should enable feature dependencies automatically" {
            Mock Get-FeatureDependencies {
                param($FeatureName)
                if ($FeatureName -eq 'Microsoft-Hyper-V-All') {
                    return @('VirtualMachinePlatform')
                }
                return @()
            }
            
            $result = Enable-Features -FeatureName 'Microsoft-Hyper-V-All' -IncludeDependencies
            
            # Should enable both the feature and its dependency
            Assert-MockCalled Enable-WindowsOptionalFeature -Times 2
        }

        It "Should detect circular dependencies" {
            Mock Get-FeatureDependencies {
                param($FeatureName)
                switch ($FeatureName) {
                    'FeatureA' { return @('FeatureB') }
                    'FeatureB' { return @('FeatureA') }
                }
                return @()
            }
            
            { Enable-Features -FeatureName 'FeatureA' -IncludeDependencies } | Should -Throw -ExpectedMessage "*circular dependency*"
        }
    }

    Context "Registry-based Features" {
        It "Should enable registry-based features" {
            $result = Enable-Features -FeatureName 'DeveloperMode' -Type 'Registry'
            $result.Success | Should -Be $true
            
            Assert-MockCalled Set-ItemProperty
        }

        It "Should create registry keys when they don't exist" {
            Mock Test-Path { return $false }
            Mock New-Item { }
            
            $result = Enable-Features -FeatureName 'CustomFeature' -Type 'Registry'
            
            Assert-MockCalled New-Item
            Assert-MockCalled New-ItemProperty
        }
    }

    Context "DISM-based Features" {
        It "Should enable features using DISM when specified" {
            $result = Enable-Features -FeatureName 'IIS-WebServerRole' -Method 'DISM'
            $result.Success | Should -Be $true
            
            Assert-MockCalled Start-Process -ParameterFilter {
                $FilePath -eq 'dism.exe' -and $ArgumentList -contains '/enable-feature'
            }
        }

        It "Should handle DISM failures gracefully" {
            Mock Start-Process {
                return [PSCustomObject]@{
                    ExitCode = 1
                    HasExited = $true
                }
            } -ParameterFilter { $FilePath -eq 'dism.exe' }
            
            $result = Enable-Features -FeatureName 'IIS-WebServerRole' -Method 'DISM'
            $result.Success | Should -Be $false
            $result.Error | Should -Not -BeNullOrEmpty
        }
    }

    Context "Restart Management" {
        It "Should detect when restart is required" {
            Mock Enable-WindowsOptionalFeature {
                return [PSCustomObject]@{
                    FeatureName = 'Microsoft-Hyper-V-All'
                    State = 'Enabled'
                    RestartRequired = 'Required'
                }
            }
            
            $result = Enable-Features -FeatureName 'Microsoft-Hyper-V-All'
            $result.RestartRequired | Should -Be $true
        }

        It "Should schedule restart when requested" {
            Mock Enable-WindowsOptionalFeature {
                return [PSCustomObject]@{
                    RestartRequired = 'Required'
                }
            }
            
            Mock Restart-Computer { }
            
            $result = Enable-Features -FeatureName 'Microsoft-Hyper-V-All' -AutoRestart
            
            Assert-MockCalled Restart-Computer
        }

        It "Should not restart when WhatIf is specified" {
            Mock Restart-Computer { }
            
            $result = Enable-Features -FeatureName 'Microsoft-Hyper-V-All' -AutoRestart -WhatIf
            
            Assert-MockCalled Restart-Computer -Times 0
        }
    }

    Context "Error Handling" {
        It "Should handle feature not found errors" {
            Mock Enable-WindowsOptionalFeature { throw "Feature not found" }
            
            $result = Enable-Features -FeatureName 'NonExistentFeature'
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Feature not found"
        }

        It "Should handle insufficient permissions" {
            Mock Enable-WindowsOptionalFeature { throw "Access denied" }
            
            $result = Enable-Features -FeatureName 'Microsoft-Windows-Subsystem-Linux'
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Access denied"
        }

        It "Should continue with other features after one fails" {
            $script:callCount = 0
            Mock Enable-WindowsOptionalFeature {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    throw "First feature failed"
                }
                return [PSCustomObject]@{ FeatureName = $FeatureName; State = 'Enabled' }
            }
            
            $features = @('FailingFeature', 'WorkingFeature')
            $result = Enable-Features -FeatureName $features
            
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $false
            $result[1].Success | Should -Be $true
        }
    }

    Context "WhatIf Support" {
        It "Should show what features would be enabled without enabling them" {
            $result = Enable-Features -FeatureName 'Microsoft-Windows-Subsystem-Linux' -WhatIf
            $result.WhatIfResult | Should -Not -BeNullOrEmpty
            
            Assert-MockCalled Enable-WindowsOptionalFeature -Times 0
        }
    }
}

Describe "Remove-Bloatware" -Tag @('Unit', 'SystemConfiguration') {
    BeforeEach {
        # Mock installed packages
        Mock Get-AppxPackage {
            return @(
                [PSCustomObject]@{
                    Name = 'Microsoft.BingWeather'
                    PackageFullName = 'Microsoft.BingWeather_4.53.33420.0_x64__8wekyb3d8bbwe'
                    Publisher = 'CN=Microsoft Corporation'
                    Version = '4.53.33420.0'
                },
                [PSCustomObject]@{
                    Name = 'Microsoft.XboxApp'
                    PackageFullName = 'Microsoft.XboxApp_48.49.31001.0_x64__8wekyb3d8bbwe'
                    Publisher = 'CN=Microsoft Corporation'
                    Version = '48.49.31001.0'
                },
                [PSCustomObject]@{
                    Name = 'Microsoft.Office.OneNote'
                    PackageFullName = 'Microsoft.Office.OneNote_16001.14326.20994.0_x64__8wekyb3d8bbwe'
                    Publisher = 'CN=Microsoft Corporation'
                    Version = '16001.14326.20994.0'
                }
            )
        }
        
        # Mock package removal
        Mock Remove-AppxPackage { }
        Mock Remove-AppxProvisionedPackage { }
        
        # Mock registry operations for traditional programs
        Mock Get-ItemProperty {
            return @(
                [PSCustomObject]@{
                    DisplayName = 'Candy Crush Saga'
                    UninstallString = 'C:\Program Files\CandyCrush\uninstall.exe'
                    Publisher = 'King'
                },
                [PSCustomObject]@{
                    DisplayName = 'McAfee Security Scan Plus'
                    UninstallString = 'C:\Program Files\McAfee\uninstall.exe'
                    Publisher = 'McAfee'
                }
            )
        } -ParameterFilter { $Path -like '*Uninstall*' }
        
        Mock Start-Process {
            return [PSCustomObject]@{
                ExitCode = 0
                HasExited = $true
            }
        }
    }

    Context "UWP App Removal" {
        It "Should remove specified UWP apps" {
            $apps = @('Microsoft.BingWeather', 'Microsoft.XboxApp')
            $result = Remove-Bloatware -AppNames $apps
            
            $result | Should -Not -BeNull
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $true
            
            Assert-MockCalled Remove-AppxPackage -Times 2
        }

        It "Should remove apps by category" {
            Mock Get-BloatwareByCategory {
                param($Category)
                if ($Category -eq 'Gaming') {
                    return @('Microsoft.XboxApp', 'Microsoft.XboxGameOverlay')
                }
                return @()
            }
            
            $result = Remove-Bloatware -Category 'Gaming'
            $result | Should -Not -BeNull
        }

        It "Should remove provisioned packages when requested" {
            $result = Remove-Bloatware -AppNames @('Microsoft.BingWeather') -RemoveProvisioned
            
            Assert-MockCalled Remove-AppxProvisionedPackage
        }

        It "Should handle app not found gracefully" {
            Mock Get-AppxPackage { return @() }
            
            $result = Remove-Bloatware -AppNames @('NonExistentApp')
            $result[0].Success | Should -Be $true
            $result[0].Message | Should -Match "not found|not installed"
        }
    }

    Context "Traditional Program Removal" {
        It "Should remove traditional programs" {
            $programs = @('Candy Crush Saga', 'McAfee Security Scan Plus')
            $result = Remove-Bloatware -ProgramNames $programs
            
            $result | Should -Not -BeNull
            $result.Count | Should -Be 2
            
            Assert-MockCalled Start-Process -Times 2
        }

        It "Should handle silent uninstallation" {
            $result = Remove-Bloatware -ProgramNames @('Candy Crush Saga') -Silent
            
            Assert-MockCalled Start-Process -ParameterFilter {
                $ArgumentList -contains '/S' -or $ArgumentList -contains '/silent'
            }
        }
    }

    Context "Bloatware Categories" {
        It "Should remove gaming bloatware" {
            Mock Get-BloatwareByCategory {
                return @('Microsoft.XboxApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay')
            }
            
            $result = Remove-Bloatware -Category 'Gaming'
            $result | Should -Not -BeNull
        }

        It "Should remove social media bloatware" {
            Mock Get-BloatwareByCategory {
                return @('Facebook.Facebook', 'Twitter.Twitter', 'Instagram.Instagram')
            }
            
            $result = Remove-Bloatware -Category 'Social'
            $result | Should -Not -BeNull
        }

        It "Should remove productivity trial software" {
            Mock Get-BloatwareByCategory {
                return @('Microsoft.Office.Desktop', 'Adobe.CC.TrialVersion')
            }
            
            $result = Remove-Bloatware -Category 'Trials'
            $result | Should -Not -BeNull
        }

        It "Should validate category parameter" {
            { Remove-Bloatware -Category 'InvalidCategory' } | Should -Throw
        }
    }

    Context "Preset Removal Lists" {
        It "Should use conservative preset" {
            Mock Get-BloatwarePreset {
                param($Preset)
                if ($Preset -eq 'Conservative') {
                    return @('Microsoft.BingWeather', 'Microsoft.GetHelp')
                }
            }
            
            $result = Remove-Bloatware -Preset 'Conservative'
            $result | Should -Not -BeNull
        }

        It "Should use aggressive preset" {
            Mock Get-BloatwarePreset {
                param($Preset)
                if ($Preset -eq 'Aggressive') {
                    return @('Microsoft.XboxApp', 'Microsoft.BingWeather', 'Microsoft.GetHelp', 'Microsoft.Getstarted')
                }
            }
            
            $result = Remove-Bloatware -Preset 'Aggressive'
            $result | Should -Not -BeNull
        }

        It "Should validate preset parameter" {
            { Remove-Bloatware -Preset 'InvalidPreset' } | Should -Throw
        }
    }

    Context "Safety Features" {
        It "Should create restore point before removal" {
            Mock Checkpoint-Computer { return $true }
            
            $result = Remove-Bloatware -AppNames @('Microsoft.BingWeather') -CreateRestorePoint
            
            Assert-MockCalled Checkpoint-Computer
        }

        It "Should backup app data when requested" {
            Mock Export-AppxPackage { return $true }
            
            $result = Remove-Bloatware -AppNames @('Microsoft.BingWeather') -BackupAppData
            
            Assert-MockCalled Export-AppxPackage
        }

        It "Should skip protected apps" {
            Mock Get-ProtectedApps {
                return @('Microsoft.WindowsStore', 'Microsoft.Windows.Cortana')
            }
            
            $result = Remove-Bloatware -AppNames @('Microsoft.WindowsStore', 'Microsoft.BingWeather')
            
            # Should only remove BingWeather, not WindowsStore
            $result.Count | Should -Be 2
            $result[0].Message | Should -Match "protected|skipped"
            $result[1].Success | Should -Be $true
        }
    }

    Context "Error Handling" {
        It "Should handle removal failures gracefully" {
            Mock Remove-AppxPackage { throw "Removal failed" }
            
            $result = Remove-Bloatware -AppNames @('Microsoft.BingWeather')
            $result[0].Success | Should -Be $false
            $result[0].Error | Should -Match "Removal failed"
        }

        It "Should handle insufficient permissions" {
            Mock Remove-AppxPackage { throw "Access denied" }
            
            $result = Remove-Bloatware -AppNames @('Microsoft.BingWeather')
            $result[0].Success | Should -Be $false
            $result[0].Error | Should -Match "Access denied"
        }

        It "Should continue with other apps after one fails" {
            $script:removeCount = 0
            Mock Remove-AppxPackage {
                $script:removeCount++
                if ($script:removeCount -eq 1) {
                    throw "First app failed"
                }
            }
            
            $apps = @('FailingApp', 'WorkingApp')
            $result = Remove-Bloatware -AppNames $apps
            
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $false
            $result[1].Success | Should -Be $true
        }
    }

    Context "WhatIf Support" {
        It "Should show what apps would be removed without removing them" {
            $result = Remove-Bloatware -AppNames @('Microsoft.BingWeather') -WhatIf
            $result[0].WhatIfResult | Should -Not -BeNullOrEmpty
            
            Assert-MockCalled Remove-AppxPackage -Times 0
        }
    }
}

Describe "Disable-Telemetry" -Tag @('Unit', 'SystemConfiguration') {
    BeforeEach {
        # Mock registry operations
        Mock Set-ItemProperty { }
        Mock New-ItemProperty { }
        Mock New-Item { }
        Mock Test-Path { return $true }
        
        # Mock service operations
        Mock Get-Service {
            return [PSCustomObject]@{
                Name = 'DiagTrack'
                Status = 'Running'
                StartType = 'Automatic'
            }
        }
        Mock Stop-Service { }
        Mock Set-Service { }
        
        # Mock scheduled task operations
        Mock Get-ScheduledTask {
            return @(
                [PSCustomObject]@{
                    TaskName = 'Microsoft Compatibility Appraiser'
                    State = 'Ready'
                },
                [PSCustomObject]@{
                    TaskName = 'ProgramDataUpdater'
                    State = 'Ready'
                }
            )
        }
        Mock Disable-ScheduledTask { }
        
        # Mock group policy operations
        Mock Start-Process {
            return [PSCustomObject]@{
                ExitCode = 0
                HasExited = $true
            }
        } -ParameterFilter { $FilePath -eq 'lgpo.exe' }
    }

    Context "Basic Telemetry Disabling" {
        It "Should disable Windows telemetry" {
            $result = Disable-Telemetry
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
            
            # Should modify telemetry registry settings
            Assert-MockCalled Set-ItemProperty
        }

        It "Should disable specific telemetry components" {
            $components = @('DiagTrack', 'DataCollection', 'ScheduledTasks')
            $result = Disable-Telemetry -Components $components
            
            $result | Should -Not -BeNull
            $result.Count | Should -Be 3
        }

        It "Should use specified telemetry level" {
            $result = Disable-Telemetry -Level 'Security'
            $result.Success | Should -Be $true
            
            # Should set telemetry level to Security (0)
            Assert-MockCalled Set-ItemProperty -ParameterFilter {
                $Value -eq 0
            }
        }
    }

    Context "Telemetry Components" {
        It "Should disable diagnostic tracking service" {
            $result = Disable-Telemetry -Components @('DiagTrack')
            
            Assert-MockCalled Stop-Service -ParameterFilter { $Name -eq 'DiagTrack' }
            Assert-MockCalled Set-Service -ParameterFilter { $Name -eq 'DiagTrack' -and $StartupType -eq 'Disabled' }
        }

        It "Should disable data collection registry settings" {
            $result = Disable-Telemetry -Components @('DataCollection')
            
            # Should modify multiple registry keys
            Assert-MockCalled Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -like '*DataCollection*'
            }
        }

        It "Should disable telemetry scheduled tasks" {
            $result = Disable-Telemetry -Components @('ScheduledTasks')
            
            Assert-MockCalled Disable-ScheduledTask -Times 2
        }

        It "Should disable Windows Error Reporting" {
            $result = Disable-Telemetry -Components @('ErrorReporting')
            
            Assert-MockCalled Set-ItemProperty -ParameterFilter {
                $Path -like '*Windows Error Reporting*'
            }
        }

        It "Should disable Customer Experience Improvement Program" {
            $result = Disable-Telemetry -Components @('CEIP')
            
            Assert-MockCalled Set-ItemProperty -ParameterFilter {
                $Path -like '*SQMClient*'
            }
        }
    }

    Context "Telemetry Levels" {
        It "Should set Security level (0)" {
            $result = Disable-Telemetry -Level 'Security'
            
            Assert-MockCalled Set-ItemProperty -ParameterFilter {
                $Name -eq 'AllowTelemetry' -and $Value -eq 0
            }
        }

        It "Should set Basic level (1)" {
            $result = Disable-Telemetry -Level 'Basic'
            
            Assert-MockCalled Set-ItemProperty -ParameterFilter {
                $Name -eq 'AllowTelemetry' -and $Value -eq 1
            }
        }

        It "Should set Enhanced level (2)" {
            $result = Disable-Telemetry -Level 'Enhanced'
            
            Assert-MockCalled Set-ItemProperty -ParameterFilter {
                $Name -eq 'AllowTelemetry' -and $Value -eq 2
            }
        }

        It "Should validate telemetry level parameter" {
            { Disable-Telemetry -Level 'InvalidLevel' } | Should -Throw
        }
    }

    Context "Group Policy Integration" {
        It "Should apply group policy settings when requested" {
            $result = Disable-Telemetry -UseGroupPolicy
            
            Assert-MockCalled Start-Process -ParameterFilter {
                $FilePath -eq 'lgpo.exe'
            }
        }

        It "Should handle missing LGPO tool gracefully" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '*lgpo.exe' }
            
            $result = Disable-Telemetry -UseGroupPolicy
            $result.Warning | Should -Match "LGPO tool not found"
        }
    }

    Context "Application Telemetry" {
        It "Should disable Office telemetry" {
            $result = Disable-Telemetry -IncludeOffice
            
            Assert-MockCalled Set-ItemProperty -ParameterFilter {
                $Path -like '*Office*'
            }
        }

        It "Should disable Visual Studio telemetry" {
            $result = Disable-Telemetry -IncludeVisualStudio
            
            Assert-MockCalled Set-ItemProperty -ParameterFilter {
                $Path -like '*VisualStudio*'
            }
        }

        It "Should disable third-party application telemetry" {
            $result = Disable-Telemetry -IncludeThirdParty
            
            # Should modify registry settings for common applications
            Assert-MockCalled Set-ItemProperty -Times 1 -ParameterFilter {
                $Path -like '*Adobe*' -or $Path -like '*Google*'
            }
        }
    }

    Context "Network Telemetry" {
        It "Should block telemetry domains in hosts file" {
            Mock Get-Content {
                return @('127.0.0.1 localhost')
            } -ParameterFilter { $Path -like '*hosts' }
            
            Mock Set-Content { }
            
            $result = Disable-Telemetry -BlockTelemetryDomains
            
            Assert-MockCalled Set-Content -ParameterFilter {
                $Path -like '*hosts'
            }
        }

        It "Should configure firewall rules to block telemetry" {
            Mock New-NetFirewallRule { }
            
            $result = Disable-Telemetry -ConfigureFirewall
            
            Assert-MockCalled New-NetFirewallRule
        }
    }

    Context "Backup and Restore" {
        It "Should backup current telemetry settings" {
            Mock Export-Registry { return $true }
            
            $result = Disable-Telemetry -BackupSettings
            
            Assert-MockCalled Export-Registry
            $result.BackupCreated | Should -Be $true
        }

        It "Should restore telemetry settings from backup" {
            Mock Import-Registry { return $true }
            Mock Test-Path { return $true } -ParameterFilter { $Path -like '*backup*' }
            
            $result = Restore-TelemetrySettings -BackupPath 'C:\backup\telemetry.reg'
            
            Assert-MockCalled Import-Registry
        }
    }

    Context "Error Handling" {
        It "Should handle registry access errors gracefully" {
            Mock Set-ItemProperty { throw "Access denied" }
            
            $result = Disable-Telemetry
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Access denied"
        }

        It "Should handle service control errors gracefully" {
            Mock Stop-Service { throw "Service control error" }
            
            $result = Disable-Telemetry -Components @('DiagTrack')
            $result.Warnings | Should -Contain "Service control error"
        }

        It "Should continue with other components after one fails" {
            $script:componentCount = 0
            Mock Set-ItemProperty {
                $script:componentCount++
                if ($script:componentCount -eq 1) {
                    throw "First component failed"
                }
            }
            
            $result = Disable-Telemetry -Components @('DataCollection', 'ErrorReporting')
            
            # Should have attempted both components
            $result.PartialSuccess | Should -Be $true
        }
    }

    Context "Verification" {
        It "Should verify telemetry settings after disabling" {
            Mock Get-ItemProperty {
                return [PSCustomObject]@{
                    AllowTelemetry = 0
                }
            }
            
            $result = Disable-Telemetry -Verify
            $result.Verified | Should -Be $true
        }

        It "Should report verification failures" {
            Mock Get-ItemProperty {
                return [PSCustomObject]@{
                    AllowTelemetry = 3  # Still enabled
                }
            }
            
            $result = Disable-Telemetry -Verify
            $result.Verified | Should -Be $false
            $result.VerificationErrors | Should -Not -BeNullOrEmpty
        }
    }

    Context "WhatIf Support" {
        It "Should show what telemetry settings would be changed without changing them" {
            $result = Disable-Telemetry -WhatIf
            $result.WhatIfResult | Should -Not -BeNullOrEmpty
            
            Assert-MockCalled Set-ItemProperty -Times 0
        }
    }
}

Describe "System Configuration Integration Tests" -Tag @('Unit', 'SystemConfiguration', 'Integration') {
    BeforeEach {
        # Set up comprehensive system configuration mocks
        Set-MockWindowsFeatures
        Mock Enable-WindowsOptionalFeature { return [PSCustomObject]@{ State = 'Enabled' } }
        Mock Remove-AppxPackage { }
        Mock Set-ItemProperty { }
        Mock Stop-Service { }
        Mock Set-Service { }
    }

    Context "Complete System Configuration Workflow" {
        It "Should enable features, remove bloatware, and disable telemetry in sequence" {
            # Enable development features
            $featureResult = Enable-Features -Category 'Development'
            $featureResult | Should -Not -BeNull
            
            # Remove bloatware
            $bloatwareResult = Remove-Bloatware -Preset 'Conservative'
            $bloatwareResult | Should -Not -BeNull
            
            # Disable telemetry
            $telemetryResult = Disable-Telemetry -Level 'Security'
            $telemetryResult | Should -Not -BeNull
        }

        It "Should handle mixed success/failure scenarios" {
            # Mock some operations to fail
            Mock Enable-WindowsOptionalFeature { throw "Feature failed" }
            Mock Remove-AppxPackage { throw "Removal failed" }
            
            # Should continue despite failures
            $featureResult = Enable-Features -FeatureName 'FailingFeature'
            $featureResult.Success | Should -Be $false

            $bloatwareResult = Remove-Bloatware -AppNames @('FailingApp')
            $bloatwareResult[0].Success | Should -Be $false

            # Telemetry should still work
            $telemetryResult = Disable-Telemetry
            $telemetryResult.Success | Should -Be $true
        }
It "Should handle mixed success/failure scenarios" {
            # Mock some operations to fail
            Mock Enable-WindowsOptionalFeature { throw "Feature failed" }
            Mock Remove-AppxPackage { throw "Removal failed" }

            # Should continue despite failures
            $featureResult = Enable-Features -FeatureName 'FailingFeature'
            $featureResult.Success | Should -Be $false

            $bloatwareResult = Remove-Bloatware -AppNames @('FailingApp')
            $bloatwareResult[0].Success | Should -Be $false

            # Telemetry should still work
            $telemetryResult = Disable-Telemetry
            $telemetryResult.Success | Should -Be $true
        }
    }

    Context "Configuration Validation" {
        It "Should validate system configuration after changes" {
            # Enable features
            Enable-Features -FeatureName 'Microsoft-Windows-Subsystem-Linux'

            # Verify feature is enabled
            Mock Get-WindowsOptionalFeature {
                return [PSCustomObject]@{
                    FeatureName = 'Microsoft-Windows-Subsystem-Linux'
                    State = 'Enabled'
                }
            }

            $verification = Test-SystemConfiguration
            $verification.FeaturesEnabled | Should -Contain 'Microsoft-Windows-Subsystem-Linux'
        }

        It "Should report configuration compliance" {
            # Mock system state
            Mock Get-WindowsOptionalFeature { return @() }
            Mock Get-AppxPackage { return @() }
            Mock Get-ItemProperty { return [PSCustomObject]@{ AllowTelemetry = 0 } }

            $compliance = Get-SystemConfigurationCompliance
            $compliance | Should -Not -BeNull
            $compliance.TelemetryDisabled | Should -Be $true
        }
    }
}