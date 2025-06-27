<#
.SYNOPSIS
    Unit tests for DotWin validation and health monitoring functions.

.DESCRIPTION
    Tests for validation and health monitoring functions including
    Test-DotWinConfiguration and Get-DotWinSystemHealth.
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

Describe "Test-DotWinConfiguration" -Tag @('Unit', 'ValidationAndHealth') {
    BeforeEach {
        # Create test configuration
        $testConfig = New-MockDotWinConfiguration -Name 'TestConfig'
        $testPackage = New-MockWingetPackage -PackageId 'Git.Git' -IsInstalled $true
        $testConfig.AddItem($testPackage)
        
        # Mock environment validation
        Mock Test-DotWinEnvironment {
            return [PSCustomObject]@{
                IsValid = $true
                Issues = @()
                IsAdministrator = $false
                PowerShellVersion = $PSVersionTable.PSVersion
                OperatingSystem = 'Windows 11'
            }
        }
        
        # Mock file operations
        Mock Test-Path { return $true }
        Mock Get-Content { return '{"test": "configuration"}' }
        Mock ConvertFrom-Json { return [PSCustomObject]@{ test = 'configuration' } }
        Mock Get-ChildItem { return @() }
    }

    Context "Basic Configuration Testing" {
        It "Should test configuration object" {
            $result = Test-DotWinConfiguration -Configuration $testConfig
            
            $result | Should -BeOfType [Array]
            $result[0] | Should -BeOfType [DotWinValidationResult]
            $result[0].ItemName | Should -Be 'Git.Git'
            $result[0].IsValid | Should -Be $true
        }

        It "Should test configuration from file path" {
            $testDir = New-TestDirectory -Name 'ConfigValidation'
            $configFile = Join-Path $testDir 'test.json'
            '{"name": "test"}' | Set-Content -Path $configFile
            
            try {
                # Note: This tests the file loading structure since JSON parsing is TODO
                { Test-DotWinConfiguration -ConfigurationPath $configFile } | Should -Not -Throw
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }

        It "Should test configuration from directory" {
            $testDir = New-TestDirectory -Name 'ConfigDir'
            $configFile = Join-Path $testDir 'config1.json'
            '{"name": "config1"}' | Set-Content -Path $configFile
            
            Mock Get-ChildItem {
                return @([PSCustomObject]@{ FullName = $configFile; Name = 'config1.json' })
            } -ParameterFilter { $Filter -eq '*.json' }
            
            try {
                { Test-DotWinConfiguration -ConfigurationPath $testDir } | Should -Not -Throw
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }

        It "Should complete within performance threshold" {
            $testConfig = Get-TestConfig
            $maxTime = $testConfig.Performance.MaxExecutionTimeSeconds['Test-DotWinConfiguration'] ?? 10
            
            Measure-TestPerformance -TestName 'Test-DotWinConfiguration-Basic' -MaxExecutionTimeSeconds $maxTime -ScriptBlock {
                Test-DotWinConfiguration -Configuration $testConfig
            }
        }
    }

    Context "Configuration Item Testing" {
        It "Should test enabled items only" {
            $disabledPackage = New-MockWingetPackage -PackageId 'Disabled.Package' -IsInstalled $false
            $disabledPackage.Enabled = $false
            $testConfig.AddItem($disabledPackage)
            
            $result = Test-DotWinConfiguration -Configuration $testConfig
            
            # Should only test the enabled package
            $result.Count | Should -Be 1
            $result[0].ItemName | Should -Be 'Git.Git'
        }

        It "Should handle test failures gracefully" {
            $failingPackage = New-MockWingetPackage -PackageId 'Failing.Package'
            $failingPackage | Add-Member -MemberType ScriptMethod -Name 'Test' -Value {
                throw "Test error"
            } -Force
            $testConfig.AddItem($failingPackage)
            
            $result = Test-DotWinConfiguration -Configuration $testConfig
            
            $result.Count | Should -Be 2
            $failingResult = $result | Where-Object { $_.ItemName -eq 'Failing.Package' }
            $failingResult.IsValid | Should -Be $false
            $failingResult.Severity | Should -Be 'Error'
            $failingResult.Message | Should -Match 'Test error'
        }

        It "Should include detailed state information when requested" {
            $result = Test-DotWinConfiguration -Configuration $testConfig -Detailed
            
            $result[0].Message | Should -Match 'Current state:'
        }

        It "Should handle GetCurrentState failures in detailed mode" {
            $package = $testConfig.Items[0]
            $package | Add-Member -MemberType ScriptMethod -Name 'GetCurrentState' -Value {
                throw "State retrieval error"
            } -Force
            
            $result = Test-DotWinConfiguration -Configuration $testConfig -Detailed
            
            $result[0].Message | Should -Match 'Unable to retrieve current state'
        }
    }

    Context "Filtering Options" {
        BeforeEach {
            # Add items of different types
            $registryItem = New-MockWingetPackage -PackageId 'Registry.Item'
            $registryItem.Type = 'Registry'
            $fileItem = New-MockWingetPackage -PackageId 'File.Item'
            $fileItem.Type = 'File'
            
            $testConfig.AddItem($registryItem)
            $testConfig.AddItem($fileItem)
        }

        It "Should filter by included types" {
            $result = Test-DotWinConfiguration -Configuration $testConfig -IncludeType @('WingetPackage')
            
            $result.Count | Should -Be 1
            $result[0].ItemType | Should -Be 'WingetPackage'
        }

        It "Should filter by excluded types" {
            $result = Test-DotWinConfiguration -Configuration $testConfig -ExcludeType @('Registry', 'File')
            
            $result.Count | Should -Be 1
            $result[0].ItemType | Should -Be 'WingetPackage'
        }

        It "Should apply both include and exclude filters" {
            $result = Test-DotWinConfiguration -Configuration $testConfig -IncludeType @('WingetPackage', 'Registry') -ExcludeType @('Registry')
            
            $result.Count | Should -Be 1
            $result[0].ItemType | Should -Be 'WingetPackage'
        }
    }

    Context "Parallel Testing" {
        It "Should run tests in parallel when requested" {
            # Add multiple items for parallel testing
            for ($i = 1; $i -le 5; $i++) {
                $package = New-MockWingetPackage -PackageId "Package$i" -IsInstalled $true
                $testConfig.AddItem($package)
            }
            
            Mock Start-Job {
                return [PSCustomObject]@{
                    Id = 1
                    State = 'Completed'
                }
            }
            
            Mock Receive-Job {
                return [DotWinValidationResult]::new($true, 'TestItem', 'Test passed')
            }
            
            Mock Remove-Job { }
            
            $result = Test-DotWinConfiguration -Configuration $testConfig -Parallel
            
            $result | Should -Not -BeNull
            Assert-MockCalled Start-Job
        }

        It "Should fall back to sequential testing if parallel fails" {
            Mock Start-Job { throw "Job creation failed" }
            
            # Should not throw and should fall back to sequential
            $result = Test-DotWinConfiguration -Configuration $testConfig -Parallel
            $result | Should -Not -BeNull
        }
    }

    Context "Environment Validation" {
        It "Should validate environment before testing" {
            Test-DotWinConfiguration -Configuration $testConfig
            
            Assert-MockCalled Test-DotWinEnvironment
        }

        It "Should warn about environment issues" {
            Mock Test-DotWinEnvironment {
                return [PSCustomObject]@{
                    IsValid = $false
                    Issues = @('PowerShell version too old', 'Not running as administrator')
                    IsAdministrator = $false
                    PowerShellVersion = [Version]'5.0'
                    OperatingSystem = 'Windows 10'
                }
            }
            
            Mock Write-Warning { }
            
            Test-DotWinConfiguration -Configuration $testConfig
            
            Assert-MockCalled Write-Warning -ParameterFilter {
                $Message -match 'Environment validation issues'
            }
        }
    }

    Context "Configuration File Validation" {
        It "Should validate configuration path exists" {
            { Test-DotWinConfiguration -ConfigurationPath 'C:\NonExistent\config.json' } | Should -Throw
        }

        It "Should handle empty configuration directory" {
            $testDir = New-TestDirectory -Name 'EmptyConfigDir'
            
            try {
                { Test-DotWinConfiguration -ConfigurationPath $testDir } | Should -Throw -ExpectedMessage "*No configuration files found*"
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }

        It "Should handle invalid JSON files gracefully" {
            Mock ConvertFrom-Json { throw "Invalid JSON" }
            
            $testDir = New-TestDirectory -Name 'InvalidJson'
            $configFile = Join-Path $testDir 'invalid.json'
            'invalid json content' | Set-Content -Path $configFile
            
            try {
                # Should handle JSON parsing errors gracefully
                { Test-DotWinConfiguration -ConfigurationPath $configFile } | Should -Not -Throw
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }
    }

    Context "Results Summary" {
        It "Should provide comprehensive test summary" {
            # Add mix of passing and failing items
            $passingPackage = New-MockWingetPackage -PackageId 'Passing.Package' -IsInstalled $true
            $failingPackage = New-MockWingetPackage -PackageId 'Failing.Package' -IsInstalled $false
            
            $testConfig.AddItem($passingPackage)
            $testConfig.AddItem($failingPackage)
            
            $result = Test-DotWinConfiguration -Configuration $testConfig
            
            $compliantCount = ($result | Where-Object { $_.IsValid }).Count
            $nonCompliantCount = ($result | Where-Object { -not $_.IsValid }).Count
            
            $compliantCount | Should -Be 2  # Git.Git and Passing.Package
            $nonCompliantCount | Should -Be 1  # Failing.Package
        }

        It "Should display interactive summary when available" {
            Mock $Host.UI.RawUI.KeyAvailable { $false }
            Mock Write-Host { }
            
            Test-DotWinConfiguration -Configuration $testConfig
            
            Assert-MockCalled Write-Host -ParameterFilter {
                $Object -match 'Configuration Test Summary'
            }
        }
    }

    Context "Error Handling" {
        It "Should handle critical errors during testing" {
            Mock Test-DotWinEnvironment { throw "Critical environment error" }
            
            { Test-DotWinConfiguration -Configuration $testConfig } | Should -Throw -ExpectedMessage "*Critical environment error*"
        }

        It "Should handle configuration loading errors" {
            Mock Get-Content { throw "File access denied" }
            
            $testDir = New-TestDirectory -Name 'AccessDenied'
            $configFile = Join-Path $testDir 'config.json'
            'test' | Set-Content -Path $configFile
            
            try {
                { Test-DotWinConfiguration -ConfigurationPath $configFile } | Should -Throw
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }
    }
}

Describe "Get-DotWinSystemHealth" -Tag @('Unit', 'ValidationAndHealth') {
    BeforeEach {
        # Mock system health data
        Set-MockCimInstance -ClassName 'Win32_OperatingSystem' -MockData (Get-MockWmiData -ClassName 'Win32_OperatingSystem')
        Set-MockCimInstance -ClassName 'Win32_ComputerSystem' -MockData (Get-MockWmiData -ClassName 'Win32_ComputerSystem')
        Set-MockCimInstance -ClassName 'Win32_Processor' -MockData (Get-MockWmiData -ClassName 'Win32_Processor')
        
        # Mock performance counters
        Mock Get-Counter {
            return [PSCustomObject]@{
                CounterSamples = @(
                    [PSCustomObject]@{
                        Path = '\Processor(_Total)\% Processor Time'
                        CookedValue = 25.5
                    }
                )
            }
        }
        
        # Mock disk space
        Mock Get-WmiObject {
            return @(
                [PSCustomObject]@{
                    DeviceID = 'C:'
                    Size = 1000000000000  # 1TB
                    FreeSpace = 500000000000  # 500GB
                }
            )
        } -ParameterFilter { $Class -eq 'Win32_LogicalDisk' }
        
        # Mock services
        Mock Get-Service {
            return @(
                [PSCustomObject]@{
                    Name = 'Spooler'
                    Status = 'Running'
                    StartType = 'Automatic'
                },
                [PSCustomObject]@{
                    Name = 'Themes'
                    Status = 'Stopped'
                    StartType = 'Manual'
                }
            )
        }
        
        # Mock event logs
        Mock Get-WinEvent {
            return @(
                [PSCustomObject]@{
                    Id = 1001
                    LevelDisplayName = 'Error'
                    TimeCreated = (Get-Date).AddHours(-1)
                    Message = 'Test error message'
                }
            )
        }
    }

    Context "Basic Health Assessment" {
        It "Should return system health object" {
            $result = Get-DotWinSystemHealth
            
            $result | Should -Not -BeNull
            $result | Should -BeOfType [PSCustomObject]
            $result | Should -HaveProperty 'OverallHealth'
            $result | Should -HaveProperty 'HealthScore'
            $result | Should -HaveProperty 'LastChecked'
        }

        It "Should calculate overall health score" {
            $result = Get-DotWinSystemHealth
            
            $result.HealthScore | Should -BeGreaterOrEqual 0
            $result.HealthScore | Should -BeLessOrEqual 100
        }

        It "Should determine overall health status" {
            $result = Get-DotWinSystemHealth
            
            $result.OverallHealth | Should -BeIn @('Excellent', 'Good', 'Fair', 'Poor', 'Critical')
        }

        It "Should include timestamp" {
            $result = Get-DotWinSystemHealth
            
            $result.LastChecked | Should -BeOfType [DateTime]
            $result.LastChecked | Should -BeGreaterThan (Get-Date).AddMinutes(-1)
        }
    }

    Context "Performance Metrics" {
        It "Should include CPU performance metrics" {
            $result = Get-DotWinSystemHealth -IncludePerformance
            
            $result.Performance | Should -Not -BeNull
            $result.Performance.CPU | Should -Not -BeNull
            $result.Performance.CPU.Usage | Should -BeGreaterOrEqual 0
            $result.Performance.CPU.Usage | Should -BeLessOrEqual 100
        }

        It "Should include memory metrics" {
            $result = Get-DotWinSystemHealth -IncludePerformance
            
            $result.Performance.Memory | Should -Not -BeNull
            $result.Performance.Memory.TotalGB | Should -BeGreaterThan 0
            $result.Performance.Memory.UsedGB | Should -BeGreaterOrEqual 0
            $result.Performance.Memory.AvailableGB | Should -BeGreaterOrEqual 0
            $result.Performance.Memory.UsagePercent | Should -BeGreaterOrEqual 0
            $result.Performance.Memory.UsagePercent | Should -BeLessOrEqual 100
        }

        It "Should include disk metrics" {
            $result = Get-DotWinSystemHealth -IncludePerformance
            
            $result.Performance.Disk | Should -Not -BeNull
            $result.Performance.Disk.Count | Should -BeGreaterThan 0
            $result.Performance.Disk[0] | Should -HaveProperty 'Drive'
            $result.Performance.Disk[0] | Should -HaveProperty 'TotalGB'
            $result.Performance.Disk[0] | Should -HaveProperty 'FreeGB'
            $result.Performance.Disk[0] | Should -HaveProperty 'UsagePercent'
        }

        It "Should handle performance counter errors gracefully" {
            Mock Get-Counter { throw "Performance counter error" }
            
            $result = Get-DotWinSystemHealth -IncludePerformance
            
            $result.Performance.Errors | Should -Contain "Performance counter error"
        }
    }

    Context "Service Health" {
        It "Should check critical services" {
            $result = Get-DotWinSystemHealth -IncludeServices
            
            $result.Services | Should -Not -BeNull
            $result.Services.Critical | Should -Not -BeNull
            $result.Services.Running | Should -BeGreaterOrEqual 0
            $result.Services.Stopped | Should -BeGreaterOrEqual 0
        }

        It "Should identify stopped critical services" {
            Mock Get-Service {
                return @(
                    [PSCustomObject]@{
                        Name = 'Spooler'
                        Status = 'Stopped'  # Critical service stopped
                        StartType = 'Automatic'
                    }
                )
            }
            
            $result = Get-DotWinSystemHealth -IncludeServices
            
            $result.Services.Issues | Should -Not -BeNullOrEmpty
            $result.Services.Issues | Should -Contain "Critical service 'Spooler' is stopped"
        }

        It "Should check custom service list" {
            $customServices = @('Spooler', 'Themes', 'CustomService')
            $result = Get-DotWinSystemHealth -IncludeServices -ServiceList $customServices
            
            $result.Services.Checked | Should -Contain 'Spooler'
            $result.Services.Checked | Should -Contain 'Themes'
        }
    }

    Context "Event Log Analysis" {
        It "Should analyze system event logs" {
            $result = Get-DotWinSystemHealth -IncludeEventLogs
            
            $result.EventLogs | Should -Not -BeNull
            $result.EventLogs.Errors | Should -BeGreaterOrEqual 0
            $result.EventLogs.Warnings | Should -BeGreaterOrEqual 0
            $result.EventLogs.RecentErrors | Should -Not -BeNull
        }

        It "Should filter events by time period" {
            $result = Get-DotWinSystemHealth -IncludeEventLogs -EventLogHours 24
            
            $result.EventLogs.TimeRange | Should -Be '24 hours'
        }

        It "Should handle event log access errors" {
            Mock Get-WinEvent { throw "Access denied to event log" }
            
            $result = Get-DotWinSystemHealth -IncludeEventLogs
            
            $result.EventLogs.Errors | Should -Contain "Access denied to event log"
        }

        It "Should identify critical error patterns" {
            Mock Get-WinEvent {
                return @(
                    [PSCustomObject]@{
                        Id = 41  # Kernel-Power critical error
                        LevelDisplayName = 'Critical'
                        TimeCreated = (Get-Date).AddMinutes(-30)
                        Message = 'The system has rebooted without cleanly shutting down first'
                    }
                )
            }
            
            $result = Get-DotWinSystemHealth -IncludeEventLogs
            
            $result.EventLogs.CriticalIssues | Should -Not -BeNullOrEmpty
        }
    }

    Context "Security Health" {
        It "Should check Windows Defender status" {
            Mock Get-MpComputerStatus {
                return [PSCustomObject]@{
                    AntivirusEnabled = $true
                    RealTimeProtectionEnabled = $true
                    DefinitionsUpToDate = $true
                    QuickScanAge = 1
                    FullScanAge = 7
                }
            }
            
            $result = Get-DotWinSystemHealth -IncludeSecurity
            
            $result.Security | Should -Not -BeNull
            $result.Security.WindowsDefender | Should -Not -BeNull
            $result.Security.WindowsDefender.Enabled | Should -Be $true
        }

        It "Should check Windows Update status" {
            Mock Get-WindowsUpdate {
                return @(
                    [PSCustomObject]@{
                        Title = 'Security Update for Windows'
                        Size = '50MB'
                        Severity = 'Critical'
                    }
                )
            }
            
            $result = Get-DotWinSystemHealth -IncludeSecurity
            
            $result.Security.WindowsUpdate | Should -Not -BeNull
            $result.Security.WindowsUpdate.PendingUpdates | Should -BeGreaterOrEqual 0
        }

        It "Should check firewall status" {
            Mock Get-NetFirewallProfile {
                return @(
                    [PSCustomObject]@{
                        Name = 'Domain'
                        Enabled = $true
                    },
                    [PSCustomObject]@{
                        Name = 'Private'
                        Enabled = $true
                    },
                    [PSCustomObject]@{
                        Name = 'Public'
                        Enabled = $true
                    }
                )
            }
            
            $result = Get-DotWinSystemHealth -IncludeSecurity
            
            $result.Security.Firewall | Should -Not -BeNull
            $result.Security.Firewall.ProfilesEnabled | Should -Be 3
        }
    }

    Context "DotWin-Specific Health" {
        It "Should check DotWin module health" {
            Mock Get-Module {
                return [PSCustomObject]@{
                    Name = 'DotWin'
                    Version = '1.0.0'
                    ModuleBase = 'C:\DotWin'
                }
            }
            
            $result = Get-DotWinSystemHealth -IncludeDotWinHealth
            
            $result.DotWin | Should -Not -BeNull
            $result.DotWin.ModuleLoaded | Should -Be $true
            $result.DotWin.Version | Should -Not -BeNullOrEmpty
        }

        It "Should check plugin health" {
            # Mock plugin manager
            $script:DotWinPluginManager = [DotWinPluginManager]::new()
            $plugin = New-MockPlugin -Name 'TestPlugin' -Version '1.0.0'
            $script:DotWinPluginManager.RegisterPlugin($plugin)
            $script:DotWinPluginManager.LoadPlugin('TestPlugin')
            
            $result = Get-DotWinSystemHealth -IncludeDotWinHealth
            
            $result.DotWin.Plugins | Should -Not -BeNull
            $result.DotWin.Plugins.Total | Should -Be 1
            $result.DotWin.Plugins.Loaded | Should -Be 1
        }

        It "Should check configuration compliance" {
            Mock Test-DotWinConfiguration {
                return @(
                    [PSCustomObject]@{ IsValid = $true; ItemName = 'Item1' },
                    [PSCustomObject]@{ IsValid = $false; ItemName = 'Item2' }
                )
            }
            
            $result = Get-DotWinSystemHealth -IncludeDotWinHealth -ConfigurationPath 'test.json'
            
            $result.DotWin.Configuration | Should -Not -BeNull
            $result.DotWin.Configuration.TotalItems | Should -Be 2
            $result.DotWin.Configuration.CompliantItems | Should -Be 1
            $result.DotWin.Configuration.CompliancePercent | Should -Be 50
        }
    }

    Context "Health Recommendations" {
        It "Should provide health improvement recommendations" {
            # Mock poor health conditions
            Mock Get-Counter {
                return [PSCustomObject]@{
                    CounterSamples = @(
                        [PSCustomObject]@{
                            Path = '\Processor(_Total)\% Processor Time'
                            CookedValue = 95.0  # High CPU usage
                        }
                    )
                }
            }
            
            $result = Get-DotWinSystemHealth -IncludeRecommendations
            
            $result.Recommendations | Should -Not -BeNull
            $result.Recommendations.Count | Should -BeGreaterThan 0
            $result.Recommendations[0] | Should -HaveProperty 'Category'
            $result.Recommendations[0] | Should -HaveProperty 'Issue'
            $result.Recommendations[0] | Should -HaveProperty 'Recommendation'
            $result.Recommendations[0] | Should -HaveProperty 'Priority'
        }

        It "Should prioritize critical recommendations" {
            Mock Get-WmiObject {
                return @(
                    [PSCustomObject]@{
                        DeviceID = 'C:'
                        Size = 1000000000000
                        FreeSpace = 10000000000  # Only 10GB free (1%)
                    }
                )
            } -ParameterFilter { $Class -eq 'Win32_LogicalDisk' }
            
            $result = Get-DotWinSystemHealth -IncludeRecommendations
            
            $criticalRecs = $result.Recommendations | Where-Object { $_.Priority -eq 'Critical' }
            $criticalRecs | Should -Not -BeNullOrEmpty
        }
    }

    Context "Health Monitoring" {
        It "Should support continuous monitoring mode" {
            Mock Start-Job {
                return [PSCustomObject]@{
                    Id = 1
                    State = 'Running'
                }
            }
            
            $result = Start-DotWinHealthMonitoring -IntervalMinutes 5
            
            $result | Should -Not -BeNull
            $result.MonitoringJobId | Should -Be 1
            Assert-MockCalled Start-Job
        }

        It "Should export health data" {
            $testDir = New-TestDirectory -Name 'HealthExport'
            $exportPath = Join-Path $testDir 'health.json'
            
            try {
                $result = Get-DotWinSystemHealth -ExportPath $exportPath
                
                Test-Path $exportPath | Should -Be $true
                $content = Get-Content $exportPath -Raw | ConvertFrom-Json
                $content.OverallHealth | Should -Not -BeNullOrEmpty
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }
    }

    Context "Error Handling" {
        It "Should handle WMI query failures gracefully" {
            Mock Get-CimInstance { throw "WMI service unavailable" }
            
            $result = Get-DotWinSystemHealth
            
            $result.Errors | Should -Contain "WMI service unavailable"
            $result.OverallHealth | Should -Be 'Unknown'
        }

        It "Should handle partial data collection failures" {
            Mock Get-Counter { throw "Performance counter error" }
            # Other mocks should still work
            
            $result = Get-DotWinSystemHealth -IncludePerformance
            
            $result | Should -Not -BeNull
            $result.Performance.Errors | Should -Not -BeNullOrEmpty
            # Should still have other health data
        }

        It "Should handle insufficient permissions gracefully" {
            Mock Get-WinEvent { throw "Access denied" }
            
            $result = Get-DotWinSystemHealth -IncludeEventLogs
            
            $result.EventLogs.Errors | Should -Contain "Access denied"
        }
    }

    Context "Performance" {
        It "Should complete health check within reasonable time" {
            Measure-TestPerformance -TestName 'Get-DotWinSystemHealth-Complete' -MaxExecutionTimeSeconds 30 -ScriptBlock {
                Get-DotWinSystemHealth -IncludePerformance -IncludeServices -IncludeEventLogs
            }
        }

        It "Should support quick health check mode" {
            $result = Get-DotWinSystemHealth -Quick
            
            $result | Should -Not -BeNull
            $result.OverallHealth | Should -Not -BeNullOrEmpty
            # Quick mode should complete faster and include fewer details
        }
    }
}

Describe "Validation and Health Integration Tests" -Tag @('Unit', 'ValidationAndHealth', 'Integration') {
    BeforeEach {
        # Set up comprehensive validation and health mocks
        Set-MockCimInstance -ClassName 'Win32_OperatingSystem' -MockData (Get-MockWmiData -ClassName 'Win32_OperatingSystem')
        Mock Test-DotWinEnvironment { return [PSCustomObject]@{ IsValid = $true; Issues = @() } }
    }

    Context "Configuration Validation and Health Correlation" {
        It "Should correlate configuration compliance with system health" {
            # Create configuration with health-related items
            $config = New-MockDotWinConfiguration -Name 'HealthConfig'
            $healthPackage = New-MockWingetPackage -PackageId 'Microsoft.WindowsDefender' -IsInstalled $true
            $config.AddItem($healthPackage)
            
            # Test configuration
            $configResult = Test-DotWinConfiguration -Configuration $config
            $configResult[0].IsValid | Should -Be $true
            
            # Check system health
            $healthResult = Get-DotWinSystemHealth -IncludeSecurity
            
            # Both should indicate good security posture
            $configResult[0].IsValid | Should -Be $true
            $healthResult.Security | Should -Not -BeNull
        }

        It "Should provide actionable recommendations based on validation failures" {
            # Create configuration with failing items
            $config = New-MockDotWinConfiguration -Name 'FailingConfig'
            $missingPackage = New-MockWingetPackage -PackageId 'Missing.Package' -IsInstalled $false
            $config.AddItem($missingPackage)
            
            $configResult = Test-
$configResult = Test-DotWinConfiguration -Configuration $config
            $configResult[0].IsValid | Should -Be $false

            # Get health recommendations
            $healthResult = Get-DotWinSystemHealth -IncludeRecommendations

            # Should provide recommendations to address the missing package
            $healthResult.Recommendations | Should -Not -BeNullOrEmpty
        }
    }

    Context "End-to-End Validation Workflow" {
        It "Should perform complete system validation and health assessment" {
            # Create comprehensive configuration
            $config = New-MockDotWinConfiguration -Name 'CompleteConfig'
            $packages = @('Git.Git', 'Microsoft.VisualStudioCode', 'Microsoft.WindowsTerminal')

            foreach ($packageId in $packages) {
                $package = New-MockWingetPackage -PackageId $packageId -IsInstalled $true
                $config.AddItem($package)
            }

            # Validate configuration
            $validationResult = Test-DotWinConfiguration -Configuration $config
            $validationResult.Count | Should -Be 3

            # Assess system health
            $healthResult = Get-DotWinSystemHealth -IncludePerformance -IncludeSecurity -IncludeDotWinHealth
            $healthResult.OverallHealth | Should -Not -BeNullOrEmpty

            # Both should indicate a healthy, well-configured system
            $allValid = ($validationResult | Where-Object { -not $_.IsValid }).Count -eq 0
            $allValid | Should -Be $true
        }
    }
}
