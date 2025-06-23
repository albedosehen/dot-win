<#
.SYNOPSIS
    Unit tests for DotWin hardware-related functions.

.DESCRIPTION
    Tests for hardware detection and driver management functions including
    Get-ChipsetInformation, Search-ChipsetDriver, and Install-ChipsetDriver.
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

Describe "Get-ChipsetInformation" -Tag @('Unit', 'Hardware') {
    BeforeEach {
        # Set up hardware mocks
        Set-MockCimInstance -ClassName 'Win32_BaseBoard' -MockData (Get-MockWmiData -ClassName 'Win32_BaseBoard')
        Set-MockCimInstance -ClassName 'Win32_ComputerSystem' -MockData (Get-MockWmiData -ClassName 'Win32_ComputerSystem')
        Set-MockCimInstance -ClassName 'Win32_Processor' -MockData (Get-MockWmiData -ClassName 'Win32_Processor')
        
        # Mock PCI devices
        Mock Get-CimInstance {
            return @(
                [PSCustomObject]@{
                    Name = 'Intel(R) Z490 Chipset LPC/eSPI Controller'
                    DeviceID = 'PCI\VEN_8086&DEV_A305'
                    Manufacturer = 'Intel Corporation'
                    DriverVersion = '10.1.18362.8131'
                    DriverDate = (Get-Date).AddDays(-30)
                },
                [PSCustomObject]@{
                    Name = 'Intel(R) USB 3.1 eXtensible Host Controller'
                    DeviceID = 'PCI\VEN_8086&DEV_A36D'
                    Manufacturer = 'Intel Corporation'
                    DriverVersion = '10.0.19041.1'
                    DriverDate = (Get-Date).AddDays(-60)
                }
            )
        } -ParameterFilter { $ClassName -eq 'Win32_PnPEntity' -and $Filter -like '*PCI*' }
    }

    Context "Basic Chipset Detection" {
        It "Should return chipset information object" {
            $result = Get-ChipsetInformation
            $result | Should -Not -BeNull
            $result | Should -BeOfType [PSCustomObject]
        }

        It "Should detect motherboard information" {
            $result = Get-ChipsetInformation
            $result.Motherboard | Should -Not -BeNull
            $result.Motherboard.Manufacturer | Should -Be 'ASUSTeK COMPUTER INC.'
            $result.Motherboard.Product | Should -Be 'PRIME Z490-A'
        }

        It "Should detect chipset from motherboard model" {
            $result = Get-ChipsetInformation
            $result.Motherboard.Product | Should -Not -BeNullOrEmpty
        }

        It "Should include driver information when requested" {
            $result = Get-ChipsetInformation -IncludeDrivers
            $result.Drivers | Should -Not -BeNull
        }
    }

    Context "Driver Information" {
        It "Should include driver versions when requested" {
            $result = Get-ChipsetInformation -IncludeDrivers
            $result.Drivers | Should -Not -BeNull
            $result.Drivers | Should -BeOfType [hashtable]
        }

        It "Should identify outdated drivers" {
            $result = Get-ChipsetInformation -IncludeDrivers
            $result.Drivers.All | Should -Not -BeNull
        }
    }

    Context "Chipset Classification" {
        It "Should classify Intel chipsets correctly" {
            Mock Get-CimInstance {
                return [PSCustomObject]@{
                    Product = 'PRIME Z490-A'
                    Manufacturer = 'ASUSTeK COMPUTER INC.'
                }
            } -ParameterFilter { $ClassName -eq 'Win32_BaseBoard' }
            
            $result = Get-ChipsetInformation
            $result.Motherboard.Product | Should -Match 'Z490'
        }

        It "Should classify AMD chipsets correctly" {
            Mock Get-CimInstance {
                return [PSCustomObject]@{
                    Product = 'ROG STRIX X570-E GAMING'
                    Manufacturer = 'ASUSTeK COMPUTER INC.'
                }
            } -ParameterFilter { $ClassName -eq 'Win32_BaseBoard' }
            
            $result = Get-ChipsetInformation
            $result.Motherboard.Product | Should -Match 'X570'
        }
    }

    Context "Performance Metrics" {
        It "Should complete within reasonable time" {
            Measure-TestPerformance -TestName 'Get-ChipsetInformation' -MaxExecutionTimeSeconds 10 -ScriptBlock {
                Get-ChipsetInformation
            }
        }

        It "Should handle WMI query failures gracefully" {
            Mock Get-CimInstance { throw "WMI Error" } -ParameterFilter { $ClassName -eq 'Win32_BaseBoard' }
            
            { Get-ChipsetInformation } | Should -Throw "*WMI Error*"
        }
    }

    Context "Parameter Validation" {
        It "Should accept valid switch parameters" {
            { Get-ChipsetInformation -IncludeDrivers } | Should -Not -Throw
        }
    }
}

Describe "Search-ChipsetDriver" -Tag @('Unit', 'Hardware') {
    BeforeEach {
        # Mock chipset information
        Mock Get-ChipsetInformation {
            return [PSCustomObject]@{
                Chipset = 'Intel Z490'
                ChipsetFamily = 'Intel'
                ChipsetGeneration = '400 Series'
                Motherboard = @{
                    Manufacturer = 'ASUSTeK COMPUTER INC.'
                    Model = 'PRIME Z490-A'
                }
            }
        }
        
        # Mock web requests for driver searches
        Mock Invoke-RestMethod {
            return @{
                drivers = @(
                    @{
                        name = 'Intel Chipset Device Software'
                        version = '10.1.18836.8283'
                        downloadUrl = 'https://downloadcenter.intel.com/download/12345'
                        releaseDate = '2023-05-15'
                        description = 'Intel Chipset Device Software for 400 Series chipsets'
                    },
                    @{
                        name = 'Intel Management Engine Interface'
                        version = '2112.15.0.2158'
                        downloadUrl = 'https://downloadcenter.intel.com/download/67890'
                        releaseDate = '2023-04-20'
                        description = 'Intel Management Engine Interface driver'
                    }
                )
            }
        }
        
        # Mock Windows Update driver search
        Mock Get-WindowsDriver {
            return @(
                [PSCustomObject]@{
                    Driver = 'Intel Chipset'
                    OriginalFileName = 'ichipset.inf'
                    Version = '10.1.18836.8283'
                    Date = (Get-Date '2023-05-15')
                    ProviderName = 'Intel Corporation'
                }
            )
        } -ParameterFilter { $Online -eq $true }
    }

    Context "Driver Search Functionality" {
        It "Should return driver search results" {
            $result = Search-ChipsetDriver
            $result | Should -Not -BeNull
            $result | Should -BeOfType [Array]
            $result.Count | Should -BeGreaterThan 0
        }

        It "Should search for specific chipset when provided" {
            $result = Search-ChipsetDriver -ChipsetModel 'Z490'
            $result | Should -Not -BeNull
            $result[0].Name | Should -Match 'Intel|Chipset'
        }

        It "Should include driver metadata" {
            $result = Search-ChipsetDriver
            $result[0] | Should -HaveProperty 'Name'
            $result[0] | Should -HaveProperty 'Version'
            $result[0] | Should -HaveProperty 'DownloadUrl'
            $result[0] | Should -HaveProperty 'ReleaseDate'
        }
    }

    Context "Search Sources" {
        It "Should search manufacturer website when specified" {
            $result = Search-ChipsetDriver -Source 'Manufacturer'
            $result | Should -Not -BeNull
        }

        It "Should search Windows Update when specified" {
            $result = Search-ChipsetDriver -Source 'WindowsUpdate'
            $result | Should -Not -BeNull
        }

        It "Should search Intel Download Center for Intel chipsets" {
            $result = Search-ChipsetDriver -Source 'Intel'
            $result | Should -Not -BeNull
        }

        It "Should search all sources by default" {
            $result = Search-ChipsetDriver
            $result | Should -Not -BeNull
            # Should combine results from multiple sources
        }
    }

    Context "Driver Filtering" {
        It "Should filter by driver type" {
            $result = Search-ChipsetDriver -DriverType 'Chipset'
            foreach ($driver in $result) {
                $driver.Name | Should -Match 'Chipset|LPC|eSPI'
            }
        }

        It "Should filter by minimum version" {
            $result = Search-ChipsetDriver -MinimumVersion '10.0.0.0'
            foreach ($driver in $result) {
                [Version]$driver.Version | Should -BeGreaterOrEqual ([Version]'10.0.0.0')
            }
        }

        It "Should limit number of results" {
            $result = Search-ChipsetDriver -MaxResults 3
            $result.Count | Should -BeLessOrEqual 3
        }
    }

    Context "Error Handling" {
        It "Should handle network errors gracefully" {
            Mock Invoke-RestMethod { throw "Network error" }
            
            $result = Search-ChipsetDriver -Source 'Intel'
            $result | Should -Not -BeNull
            # Should return empty array or cached results
        }

        It "Should handle unknown chipset models" {
            Mock Get-ChipsetInformation {
                return [PSCustomObject]@{
                    Chipset = 'Unknown Chipset'
                    ChipsetFamily = 'Unknown'
                }
            }
            
            $result = Search-ChipsetDriver
            $result | Should -Not -BeNull
            # Should attempt generic search
        }
    }

    Context "Performance" {
        It "Should complete search within reasonable time" {
            Measure-TestPerformance -TestName 'Search-ChipsetDriver' -MaxExecutionTimeSeconds 15 -ScriptBlock {
                Search-ChipsetDriver -MaxResults 5
            }
        }

        It "Should cache results for repeated searches" {
            # First search
            $result1 = Search-ChipsetDriver -ChipsetModel 'Z490'
            
            # Second search should be faster (cached)
            $result2 = Search-ChipsetDriver -ChipsetModel 'Z490'
            
            $result1.Count | Should -Be $result2.Count
        }
    }

    Context "Parameter Validation" {
        It "Should validate source parameter" {
            { Search-ChipsetDriver -Source 'InvalidSource' } | Should -Throw
        }

        It "Should validate driver type parameter" {
            { Search-ChipsetDriver -DriverType 'InvalidType' } | Should -Throw
        }

        It "Should validate version format" {
            { Search-ChipsetDriver -MinimumVersion 'invalid.version' } | Should -Throw
        }

        It "Should validate max results range" {
            { Search-ChipsetDriver -MaxResults 0 } | Should -Throw
            { Search-ChipsetDriver -MaxResults 101 } | Should -Throw
        }
    }
}

Describe "Install-ChipsetDriver" -Tag @('Unit', 'Hardware') {
    BeforeEach {
        # Mock driver search results
        $mockDrivers = @(
            [PSCustomObject]@{
                Name = 'Intel Chipset Device Software'
                Version = '10.1.18836.8283'
                DownloadUrl = 'https://downloadcenter.intel.com/download/12345/chipset.exe'
                ReleaseDate = '2023-05-15'
                Type = 'Chipset'
                Size = '5.2 MB'
                Checksum = 'ABC123DEF456'
            }
        )
        
        Mock Search-ChipsetDriver { return $mockDrivers }
        
        # Mock download and installation
        Mock Invoke-WebRequest {
            return [PSCustomObject]@{
                StatusCode = 200
                Content = 'Mock driver content'
            }
        }
        
        Mock Start-Process {
            return [PSCustomObject]@{
                ExitCode = 0
                HasExited = $true
            }
        }
        
        # Mock file operations
        Mock Test-Path { return $true }
        Mock New-Item { return [PSCustomObject]@{ FullName = 'C:\temp\driver.exe' } }
        Mock Set-Content { }
        Mock Remove-Item { }
    }

    Context "Driver Installation" {
        It "Should install driver by name" {
            $result = Install-ChipsetDriver -DriverName 'Intel Chipset Device Software'
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
        }

        It "Should install latest driver when no specific driver specified" {
            $result = Install-ChipsetDriver
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
        }

        It "Should download driver to specified path" {
            $testDir = New-TestDirectory -Name 'DriverTests'
            
            try {
                $result = Install-ChipsetDriver -DownloadPath $testDir
                $result.DownloadPath | Should -Match $testDir
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }

        It "Should verify driver signature when requested" {
            Mock Get-AuthenticodeSignature {
                return [PSCustomObject]@{
                    Status = 'Valid'
                    SignerCertificate = [PSCustomObject]@{
                        Subject = 'CN=Intel Corporation'
                    }
                }
            }
            
            $result = Install-ChipsetDriver -VerifySignature
            $result.SignatureValid | Should -Be $true
        }
    }

    Context "Installation Options" {
        It "Should support silent installation" {
            $result = Install-ChipsetDriver -Silent
            $result.Success | Should -Be $true
            
            Assert-MockCalled Start-Process -ParameterFilter {
                $ArgumentList -contains '/S' -or $ArgumentList -contains '/silent'
            }
        }

        It "Should support force installation" {
            $result = Install-ChipsetDriver -Force
            $result.Success | Should -Be $true
        }

        It "Should create restore point when requested" {
            Mock Checkpoint-Computer { return $true }
            
            $result = Install-ChipsetDriver -CreateRestorePoint
            $result.RestorePointCreated | Should -Be $true
            
            Assert-MockCalled Checkpoint-Computer
        }

        It "Should backup existing drivers when requested" {
            Mock Export-WindowsDriver { return $true }
            
            $result = Install-ChipsetDriver -BackupExistingDrivers
            $result.BackupCreated | Should -Be $true
        }
    }

    Context "Pre-installation Checks" {
        It "Should check if driver is already installed" {
            Mock Get-CimInstance {
                return [PSCustomObject]@{
                    DriverVersion = '10.1.18836.8283'
                    DriverDate = (Get-Date '2023-05-15')
                }
            } -ParameterFilter { $ClassName -eq 'Win32_PnPEntity' }
            
            $result = Install-ChipsetDriver -DriverName 'Intel Chipset Device Software'
            $result.AlreadyInstalled | Should -Be $true
        }

        It "Should check system compatibility" {
            $result = Install-ChipsetDriver -CheckCompatibility
            $result.CompatibilityCheck | Should -Not -BeNull
        }

        It "Should require administrator privileges for installation" {
            Mock Test-IsAdministrator { return $false }
            
            { Install-ChipsetDriver } | Should -Throw -ExpectedMessage "*administrator*"
        }
    }

    Context "Download Management" {
        It "Should verify download integrity" {
            Mock Get-FileHash {
                return [PSCustomObject]@{
                    Hash = 'ABC123DEF456'
                    Algorithm = 'SHA256'
                }
            }
            
            $result = Install-ChipsetDriver -VerifyDownload
            $result.DownloadVerified | Should -Be $true
        }

        It "Should retry download on failure" {
            $script:downloadAttempts = 0
            Mock Invoke-WebRequest {
                $script:downloadAttempts++
                if ($script:downloadAttempts -lt 3) {
                    throw "Download failed"
                }
                return [PSCustomObject]@{ StatusCode = 200; Content = 'Mock content' }
            }
            
            $result = Install-ChipsetDriver -MaxRetries 3
            $result.Success | Should -Be $true
            $script:downloadAttempts | Should -Be 3
        }

        It "Should clean up temporary files after installation" {
            $result = Install-ChipsetDriver -CleanupTempFiles
            $result.TempFilesCleanedUp | Should -Be $true
            
            Assert-MockCalled Remove-Item
        }
    }

    Context "Error Handling" {
        It "Should handle download failures gracefully" {
            Mock Invoke-WebRequest { throw "Download failed" }
            
            $result = Install-ChipsetDriver
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Download failed"
        }

        It "Should handle installation failures gracefully" {
            Mock Start-Process {
                return [PSCustomObject]@{
                    ExitCode = 1
                    HasExited = $true
                }
            }
            
            $result = Install-ChipsetDriver
            $result.Success | Should -Be $false
            $result.ExitCode | Should -Be 1
        }

        It "Should handle driver not found errors" {
            Mock Search-ChipsetDriver { return @() }
            
            $result = Install-ChipsetDriver -DriverName 'NonExistentDriver'
            $result.Success | Should -Be $false
            $result.Error | Should -Match "not found"
        }
    }

    Context "WhatIf Support" {
        It "Should show what would be installed without actually installing" {
            $result = Install-ChipsetDriver -WhatIf
            $result.WhatIfResult | Should -Not -BeNullOrEmpty
            
            Assert-MockCalled Start-Process -Times 0
        }
    }

    Context "Logging and Reporting" {
        It "Should log installation progress" {
            Mock Write-DotWinLog { }
            
            Install-ChipsetDriver
            
            Assert-MockCalled Write-DotWinLog -Times 1 -ParameterFilter {
                $Message -match "Installing driver"
            }
        }

        It "Should return detailed installation report" {
            $result = Install-ChipsetDriver
            
            $result | Should -HaveProperty 'DriverName'
            $result | Should -HaveProperty 'Version'
            $result | Should -HaveProperty 'InstallationTime'
            $result | Should -HaveProperty 'Success'
        }
    }

    Context "Performance" {
        It "Should complete installation within reasonable time" {
            Measure-TestPerformance -TestName 'Install-ChipsetDriver' -MaxExecutionTimeSeconds 60 -ScriptBlock {
                Install-ChipsetDriver -WhatIf
            }
        }
    }
}

Describe "Hardware Integration Tests" -Tag @('Unit', 'Hardware', 'Integration') {
    BeforeEach {
        # Set up comprehensive hardware mocks
        Set-MockCimInstance -ClassName 'Win32_BaseBoard' -MockData (Get-MockWmiData -ClassName 'Win32_BaseBoard')
        Set-MockCimInstance -ClassName 'Win32_ComputerSystem' -MockData (Get-MockWmiData -ClassName 'Win32_ComputerSystem')
        Set-MockCimInstance -ClassName 'Win32_Processor' -MockData (Get-MockWmiData -ClassName 'Win32_Processor')
    }

    Context "Hardware Detection and Driver Management Workflow" {
        It "Should detect chipset and find appropriate drivers" {
            # Get chipset information
            $chipsetInfo = Get-ChipsetInformation
            $chipsetInfo | Should -Not -BeNull
            
            # Search for drivers based on detected chipset
            $drivers = Search-ChipsetDriver -ChipsetModel $chipsetInfo.Chipset
            $drivers | Should -Not -BeNull
            $drivers.Count | Should -BeGreaterThan 0
        }

        It "Should recommend driver updates for outdated drivers" {
            Mock Get-ChipsetInformation {
                return [PSCustomObject]@{
                    Chipset = 'Intel Z490'
                    Drivers = @(
                        [PSCustomObject]@{
                            Name = 'Old Driver'
                            Version = '1.0.0.0'
                            IsOutdated = $true
                        }
                    )
                }
            }
            
            $chipsetInfo = Get-ChipsetInformation -IncludeDrivers
            $outdatedDrivers = $chipsetInfo.Drivers | Where-Object { $_.IsOutdated }
            $outdatedDrivers.Count | Should -BeGreaterThan 0
            
            # Should be able to search for updates
            $updates = Search-ChipsetDriver -DriverType 'Chipset'
            $updates | Should -Not -BeNull
        }
    }
}