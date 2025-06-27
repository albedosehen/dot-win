<#
.SYNOPSIS
    Unit tests for DotWin package management functions.

.DESCRIPTION
    Tests for package and application management functions including
    Install-Packages, Install-Applications, and Install-SystemTools.
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

Describe "Install-Packages" -Tag @('Unit', 'PackageManagement') {
    BeforeEach {
        # Set up package manager mocks
        Set-MockWingetCommand -Command 'list'
        Set-MockWingetCommand -Command 'install' -ExitCode 0
        Set-MockWingetCommand -Command '--version'
        
        # Mock the Winget.ps1 script
        Mock Test-Path { return $true } -ParameterFilter { $Path -like '*Winget.ps1' }
        Mock . { } -ParameterFilter { $_ -like '*Winget.ps1' }
        
        # Mock package configuration loading
        Mock Test-Path { return $true } -ParameterFilter { $Path -like '*Packages.ps1' }
        Mock . { } -ParameterFilter { $_ -like '*Packages.ps1' }
        Mock Get-PackagesByCategory {
            return @(
                @{ Id = 'Git.Git'; Version = '2.40.0' },
                @{ Id = 'Microsoft.VisualStudioCode'; Version = '1.80.0' }
            )
        }
    }

    Context "Basic Package Installation" {
        It "Should install packages from a list" {
            $packages = @('Git.Git', 'Microsoft.VisualStudioCode')
            $result = Install-Packages -PackageList $packages
            
            $result | Should -BeOfType [Array]
            $result.Count | Should -Be 2
            $result[0] | Should -BeOfType [DotWinExecutionResult]
        }

        It "Should install packages with detailed configuration" {
            $packages = @(
                @{ Id = 'Git.Git'; Version = '2.40.0'; AcceptLicense = $true },
                @{ Id = 'Microsoft.VisualStudioCode'; InstallOptions = @{ scope = 'machine' } }
            )
            
            $result = Install-Packages -PackageList $packages
            $result | Should -Not -BeNull
            $result.Count | Should -Be 2
        }

        It "Should use specified package source" {
            $packages = @('Git.Git')
            $result = Install-Packages -PackageList $packages -Source 'winget'
            
            $result[0].ItemName | Should -Be 'Git.Git'
            $result[0].Success | Should -Be $true
        }

        It "Should complete within performance threshold" {
            $testConfig = Get-TestConfig
            $maxTime = $testConfig.Performance.MaxExecutionTimeSeconds['Install-Packages'] ?? 60
            
            Measure-TestPerformance -TestName 'Install-Packages-Basic' -MaxExecutionTimeSeconds $maxTime -ScriptBlock {
                Install-Packages -PackageList @('Git.Git') -WhatIf
            }
        }
    }

    Context "Package Categories" {
        It "Should install packages from Development category" {
            $result = Install-Packages -Category 'Development'
            $result | Should -Not -BeNull
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should validate category parameter" {
            { Install-Packages -Category 'InvalidCategory' } | Should -Throw
        }

        It "Should load packages from category configuration" {
            Install-Packages -Category 'Development'
            
            Assert-MockCalled Get-PackagesByCategory -ParameterFilter {
                $Category -eq 'Development'
            }
        }
    }

    Context "Configuration File Support" {
        BeforeEach {
            $testDir = New-TestDirectory -Name 'PackageTests'
            $configFile = Join-Path $testDir 'packages.json'
            
            $configData = @{
                packages = @(
                    @{ Id = 'Git.Git'; Version = '2.40.0' },
                    @{ Id = 'Microsoft.VisualStudioCode' }
                )
            }
            $configData | ConvertTo-Json | Set-Content -Path $configFile
        }

        AfterEach {
            Remove-TestDirectory -Path $testDir
        }

        It "Should load packages from configuration file" {
            $result = Install-Packages -ConfigurationPath $configFile
            $result | Should -Not -BeNull
            $result.Count | Should -Be 2
        }

        It "Should validate configuration file exists" {
            { Install-Packages -ConfigurationPath 'C:\NonExistent\packages.json' } | Should -Throw
        }
    }

    Context "Package Installation Logic" {
        It "Should skip already installed packages unless forced" {
            # Mock package as already installed
            Mock Test-Path { return $true } -ParameterFilter { $Path -like '*Git*' }
            
            $mockPackage = New-MockWingetPackage -PackageId 'Git.Git' -IsInstalled $true
            Mock New-Object { return $mockPackage } -ParameterFilter { $TypeName -eq 'DotWinWingetPackage' }
            
            $result = Install-Packages -PackageList @('Git.Git')
            $result[0].Message | Should -Match "already installed"
        }

        It "Should install all packages when forced" {
            $mockPackage = New-MockWingetPackage -PackageId 'Git.Git' -IsInstalled $true
            Mock New-Object { return $mockPackage } -ParameterFilter { $TypeName -eq 'DotWinWingetPackage' }
            
            $result = Install-Packages -PackageList @('Git.Git') -Force
            $result[0].Message | Should -Not -Match "already installed"
        }

        It "Should accept licenses automatically when specified" {
            $result = Install-Packages -PackageList @('Git.Git') -AcceptLicenses
            $result[0].Success | Should -Be $true
        }
    }

    Context "Parallel Installation" {
        It "Should install packages in parallel when requested" {
            $packages = @('Git.Git', 'Microsoft.VisualStudioCode', 'Microsoft.WindowsTerminal')
            
            Mock Start-Job {
                return [PSCustomObject]@{
                    Id = 1
                    State = 'Completed'
                }
            }
            
            Mock Receive-Job {
                return [PSCustomObject]@{
                    Success = $true
                    PackageId = 'Git.Git'
                }
            }
            
            Mock Remove-Job { }
            
            $result = Install-Packages -PackageList $packages -Parallel
            $result | Should -Not -BeNull
        }

        It "Should handle parallel installation failures gracefully" {
            Mock Start-Job { throw "Job creation failed" }
            
            $packages = @('Git.Git', 'Microsoft.VisualStudioCode')
            { Install-Packages -PackageList $packages -Parallel } | Should -Throw
        }
    }

    Context "Package Source Support" {
        It "Should support winget source" {
            $result = Install-Packages -PackageList @('Git.Git') -Source 'winget'
            $result[0].Success | Should -Be $true
        }

        It "Should validate package source parameter" {
            { Install-Packages -PackageList @('Git.Git') -Source 'InvalidSource' } | Should -Throw
        }

        It "Should throw for unsupported sources in sequential installation" {
            { Install-Packages -PackageList @('Git.Git') -Source 'chocolatey' } | Should -Throw -ExpectedMessage "*Unsupported package source*"
        }
    }

    Context "Error Handling" {
        It "Should handle package installation failures gracefully" {
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 1 }
            }
            
            $result = Install-Packages -PackageList @('FailingPackage')
            $result[0].Success | Should -Be $false
            $result[0].Message | Should -Match "Error installing package"
        }

        It "Should continue installing other packages after one fails" {
            $packages = @('FailingPackage', 'Git.Git')
            
            # Mock first package to fail, second to succeed
            $script:callCount = 0
            Mock Start-Process {
                $script:callCount++
                if ($script:callCount -eq 1) {
                    return [PSCustomObject]@{ ExitCode = 1 }
                } else {
                    return [PSCustomObject]@{ ExitCode = 0 }
                }
            }
            
            $result = Install-Packages -PackageList $packages
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $false
            $result[1].Success | Should -Be $true
        }

        It "Should handle missing package configuration gracefully" {
            Mock Test-Path { return $false } -ParameterFilter { $Path -like '*Packages.ps1' }
            
            { Install-Packages -Category 'Development' } | Should -Throw -ExpectedMessage "*not found*"
        }
    }

    Context "WhatIf Support" {
        It "Should show what packages would be installed without installing them" {
            $result = Install-Packages -PackageList @('Git.Git') -WhatIf
            $result[0].Message | Should -Match "WhatIf"
            
            # Should not actually call winget install
            Assert-MockCalled Start-Process -Times 0 -ParameterFilter { $FilePath -eq 'winget' }
        }
    }

    Context "Package Configuration Conversion" {
        It "Should convert string package specifications correctly" {
            $packageSpec = 'Git.Git'
            $config = ConvertTo-PackageConfiguration -PackageSpec $packageSpec -Source 'winget'
            
            $config.PackageId | Should -Be 'Git.Git'
            $config.Source | Should -Be 'winget'
        }

        It "Should convert hashtable package specifications correctly" {
            $packageSpec = @{
                Id = 'Git.Git'
                Version = '2.40.0'
                AcceptLicense = $true
            }
            
            $config = ConvertTo-PackageConfiguration -PackageSpec $packageSpec -Source 'winget'
            
            $config.PackageId | Should -Be 'Git.Git'
            $config.Version | Should -Be '2.40.0'
            $config.AcceptLicense | Should -Be $true
        }

        It "Should handle PSCustomObject package specifications" {
            $packageSpec = [PSCustomObject]@{
                PackageId = 'Git.Git'
                Version = '2.40.0'
            }
            
            $config = ConvertTo-PackageConfiguration -PackageSpec $packageSpec -Source 'winget'
            
            $config.PackageId | Should -Be 'Git.Git'
            $config.Version | Should -Be '2.40.0'
        }

        It "Should throw for invalid package specifications" {
            { ConvertTo-PackageConfiguration -PackageSpec 123 -Source 'winget' } | Should -Throw
        }

        It "Should require package ID" {
            { ConvertTo-PackageConfiguration -PackageSpec @{} -Source 'winget' } | Should -Throw -ExpectedMessage "*Package ID is required*"
        }
    }
}

Describe "Install-Applications" -Tag @('Unit', 'PackageManagement') {
    BeforeEach {
        # Set up application installation mocks
        Set-MockWingetCommand -Command 'install' -ExitCode 0
        
        # Mock application configuration
        Mock Test-Path { return $true } -ParameterFilter { $Path -like '*apps*' }
        Mock Get-ChildItem {
            return @(
                [PSCustomObject]@{ Name = 'Development.ps1'; FullName = 'C:\apps\Development.ps1' },
                [PSCustomObject]@{ Name = 'Productivity.ps1'; FullName = 'C:\apps\Productivity.ps1' }
            )
        } -ParameterFilter { $Path -like '*apps*' }
        
        Mock . { } # Mock script execution
    }

    Context "Application Installation" {
        It "Should install applications from category" {
            Mock Get-ApplicationsByCategory {
                return @(
                    @{ Name = 'Visual Studio Code'; PackageId = 'Microsoft.VisualStudioCode' },
                    @{ Name = 'Git'; PackageId = 'Git.Git' }
                )
            }
            
            $result = Install-Applications -Category 'Development'
            $result | Should -Not -BeNull
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should install specific applications" {
            $applications = @(
                @{ Name = 'Git'; PackageId = 'Git.Git' },
                @{ Name = 'VS Code'; PackageId = 'Microsoft.VisualStudioCode' }
            )
            
            $result = Install-Applications -ApplicationList $applications
            $result | Should -Not -BeNull
            $result.Count | Should -Be 2
        }

        It "Should validate category parameter" {
            { Install-Applications -Category 'InvalidCategory' } | Should -Throw
        }
    }

    Context "Application Configuration" {
        It "Should load application configurations from scripts" {
            Install-Applications -Category 'Development'
            
            # Should have loaded the Development.ps1 script
            Assert-MockCalled . -ParameterFilter { $_ -like '*Development.ps1' }
        }

        It "Should handle missing application category gracefully" {
            Mock Get-ChildItem { return @() } -ParameterFilter { $Path -like '*apps*' }
            
            { Install-Applications -Category 'NonExistent' } | Should -Throw
        }
    }

    Context "Installation Options" {
        It "Should support silent installation" {
            $result = Install-Applications -Category 'Development' -Silent
            $result | Should -Not -BeNull
        }

        It "Should support custom installation parameters" {
            $applications = @(
                @{ 
                    Name = 'Custom App'
                    PackageId = 'Custom.App'
                    InstallParameters = '/VERYSILENT /NORESTART'
                }
            )
            
            $result = Install-Applications -ApplicationList $applications
            $result | Should -Not -BeNull
        }
    }
}

Describe "Install-SystemTools" -Tag @('Unit', 'PackageManagement') {
    BeforeEach {
        # Set up system tools mocks
        Set-MockWingetCommand -Command 'install' -ExitCode 0
        
        # Mock tools configuration
        Mock Test-Path { return $true } -ParameterFilter { $Path -like '*Tools.ps1' }
        Mock . { } -ParameterFilter { $_ -like '*Tools.ps1' }
        
        Mock Get-SystemToolsByCategory {
            return @(
                @{ Name = 'PowerShell 7'; PackageId = 'Microsoft.PowerShell' },
                @{ Name = 'Windows Terminal'; PackageId = 'Microsoft.WindowsTerminal' }
            )
        }
    }

    Context "System Tools Installation" {
        It "Should install system tools from category" {
            $result = Install-SystemTools -Category 'PowerShell'
            $result | Should -Not -BeNull
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should install essential system tools" {
            $result = Install-SystemTools -Essential
            $result | Should -Not -BeNull
        }

        It "Should validate category parameter" {
            { Install-SystemTools -Category 'InvalidCategory' } | Should -Throw
        }
    }

    Context "Tool Categories" {
        It "Should support PowerShell tools category" {
            { Install-SystemTools -Category 'PowerShell' } | Should -Not -Throw
        }

        It "Should support Terminal tools category" {
            { Install-SystemTools -Category 'Terminal' } | Should -Not -Throw
        }

        It "Should support Development tools category" {
            { Install-SystemTools -Category 'Development' } | Should -Not -Throw
        }

        It "Should support System tools category" {
            { Install-SystemTools -Category 'System' } | Should -Not -Throw
        }
    }

    Context "Essential Tools" {
        It "Should install PowerShell 7 as essential tool" {
            Mock Get-EssentialSystemTools {
                return @(
                    @{ Name = 'PowerShell 7'; PackageId = 'Microsoft.PowerShell'; Essential = $true }
                )
            }
            
            $result = Install-SystemTools -Essential
            $result | Should -Not -BeNull
            $result[0].ItemName | Should -Be 'Microsoft.PowerShell'
        }

        It "Should prioritize essential tools installation" {
            $result = Install-SystemTools -Essential -Priority 'High'
            $result | Should -Not -BeNull
        }
    }

    Context "Tool Configuration" {
        It "Should apply post-installation configuration" {
            Mock Invoke-ToolConfiguration { return $true }
            
            $result = Install-SystemTools -Category 'PowerShell' -Configure
            $result | Should -Not -BeNull
        }

        It "Should create desktop shortcuts when requested" {
            $result = Install-SystemTools -Category 'Terminal' -CreateShortcuts
            $result | Should -Not -BeNull
        }
    }
}

Describe "Package Management Integration Tests" -Tag @('Unit', 'PackageManagement', 'Integration') {
    BeforeEach {
        # Set up comprehensive package management mocks
        Set-MockWingetCommand -Command 'list'
        Set-MockWingetCommand -Command 'install' -ExitCode 0
        Set-MockWingetCommand -Command '--version'
        
        # Mock all configuration files
        Mock Test-Path { return $true }
        Mock . { }
        Mock Get-PackagesByCategory { return @(@{ Id = 'Git.Git' }) }
        Mock Get-ApplicationsByCategory { return @(@{ Name = 'Git'; PackageId = 'Git.Git' }) }
        Mock Get-SystemToolsByCategory { return @(@{ Name = 'PowerShell'; PackageId = 'Microsoft.PowerShell' }) }
    }

    Context "Package Management Workflow" {
        It "Should install packages, applications, and system tools in sequence" {
            # Install packages
            $packageResult = Install-Packages -Category 'Development'
            $packageResult | Should -Not -BeNull
            
            # Install applications
            $appResult = Install-Applications -Category 'Development'
            $appResult | Should -Not -BeNull
            
            # Install system tools
            $toolResult = Install-SystemTools -Category 'Development'
            $toolResult | Should -Not -BeNull
        }

        It "Should handle mixed installation results" {
            # Mock some successes and some failures
            $script:installCount = 0
            Mock Start-Process {
                $script:installCount++
                if ($script:installCount % 2 -eq 0) {
                    return [PSCustomObject]@{ ExitCode = 1 }  # Failure
                } else {
                    return [PSCustomObject]@{ ExitCode = 0 }  # Success
                }
            }
            
            $result = Install-Packages -PackageList @('Package1', 'Package2', 'Package3', 'Package4')
            
            $successCount = ($result | Where-Object { $_.Success }).Count
            $failureCount = ($result | Where-Object { -not $_.Success }).Count
            
            $successCount | Should -Be 2
            $failureCount | Should -Be 2
        }
    }

    Context "Package Manager Detection" {
        It "Should detect available package managers" {
            # Test winget detection
            Set-MockWingetCommand -Command '--version' -ExitCode 0
            
            # Should be able to use winget
            $result = Install-Packages -PackageList @('Git.Git') -Source 'winget'
            $result[0].Success | Should -Be $true
        }

        It "Should fall back to alternative package managers" {
            # Mock winget as unavailable
            Set-MockWingetCommand -Command '--version' -ExitCode 1
            
            # Should handle gracefully or suggest alternatives
            { Install-Packages -PackageList @('Git.Git') -Source 'winget' } | Should -Not -Throw
        }
    }
}
