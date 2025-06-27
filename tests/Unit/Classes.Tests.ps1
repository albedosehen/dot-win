<#
.SYNOPSIS
    Unit tests for DotWin classes and object functionality.

.DESCRIPTION
    Tests for all DotWin classes including DotWinConfiguration, DotWinConfigurationItem,
    DotWinSystemProfiler, DotWinPlugin classes, and other core objects.
#>

# BeforeAll block to ensure classes are loaded in Pester execution context
BeforeAll {
    # Import test infrastructure
    $testHelpersPath = Join-Path $PSScriptRoot "..\TestHelpers.ps1"
    if (Test-Path $testHelpersPath) {
        . $testHelpersPath
    }

    # Load classes in the Pester execution context
    $classesPath = Join-Path $PSScriptRoot "..\..\Classes.ps1"
    $resolvedPath = Resolve-Path $classesPath -ErrorAction SilentlyContinue

    if ($resolvedPath) {
        # Load classes using multiple methods to ensure availability
        $classContent = Get-Content $resolvedPath.Path -Raw

        # Method 1: Global scope
        $global:ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create($classContent), $null, $null)

        # Method 2: Current scope
        . $resolvedPath.Path

        # Method 3: Invoke-Expression
        Invoke-Expression $classContent

        # Import DotWin module for testing
        try {
            Import-DotWinModuleForTesting
        } catch {
            Write-Warning "Could not import DotWin module: $($_.Exception.Message)"
        }

        # Initialize test environment
        try {
            Initialize-TestEnvironment
        } catch {
            Write-Warning "Could not initialize test environment: $($_.Exception.Message)"
        }
    } else {
        throw "Classes.ps1 not found at: $classesPath"
    }
}

Describe "DotWinConfigurationItem" -Tag @('Unit', 'Classes') {
    Context "Base Class Functionality" {
        It "Should create configuration item with default constructor" {
            $item = [DotWinConfigurationItem]::new()
            
            $item | Should -Not -BeNullOrEmpty
            $item.Properties | Should -BeOfType [hashtable]
            $item.Enabled | Should -Be $true
            $item.LastModified | Should -BeOfType [DateTime]
        }

        It "Should create configuration item with name and type" {
            $item = [DotWinConfigurationItem]::new('TestItem', 'TestType')
            
            $item.Name | Should -Be 'TestItem'
            $item.Type | Should -Be 'TestType'
            $item.Properties | Should -BeOfType [hashtable]
            $item.Enabled | Should -Be $true
        }

        It "Should throw on virtual method calls" {
            $item = [DotWinConfigurationItem]::new()
            
            { $item.Test() } | Should -Throw "*Test method must be implemented by derived classes*"
            { $item.Apply() } | Should -Throw "*Apply method must be implemented by derived classes*"
            { $item.GetCurrentState() } | Should -Throw "*GetCurrentState method must be implemented by derived classes*"
        }

        It "Should allow property modification" {
            $item = [DotWinConfigurationItem]::new()
            
            $item.Properties['CustomProperty'] = 'CustomValue'
            $item.Properties['CustomProperty'] | Should -Be 'CustomValue'
            
            $item.Description = 'Test Description'
            $item.Description | Should -Be 'Test Description'
        }
    }
}

Describe "DotWinWingetPackage" -Tag @('Unit', 'Classes') {
    BeforeEach {
        # Mock winget operations
        Set-MockWingetCommand -Command 'list' -ExitCode 0
        Set-MockWingetCommand -Command 'install' -ExitCode 0
        Set-MockWingetCommand -Command 'show'
    }

    Context "Package Creation and Properties" {
        It "Should create Winget package with default constructor" {
            $package = [DotWinWingetPackage]::new()
            
            $package | Should -Not -BeNullOrEmpty
            $package.Type | Should -Be 'WingetPackage'
            $package.Source | Should -Be 'winget'
            $package.AcceptLicense | Should -Be $false
            $package.AcceptSourceAgreements | Should -Be $false
            $package.InstallOptions | Should -BeOfType [hashtable]
        }

        It "Should create Winget package with package ID" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            
            $package.Name | Should -Be 'Git.Git'
            $package.PackageId | Should -Be 'Git.Git'
            $package.Type | Should -Be 'WingetPackage'
        }

        It "Should allow property configuration" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            
            $package.Version = '2.40.0'
            $package.AcceptLicense = $true
            $package.AcceptSourceAgreements = $true
            $package.InstallOptions['scope'] = 'machine'
            
            $package.Version | Should -Be '2.40.0'
            $package.AcceptLicense | Should -Be $true
            $package.InstallOptions['scope'] | Should -Be 'machine'
        }
    }

    Context "Package Testing" {
        It "Should test if package is installed" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            
            # Mock winget list to show package is installed
            Mock Invoke-Expression {
                $global:LASTEXITCODE = 0
                return @('Git.Git    2.40.0    winget')
            } -ParameterFilter { $Command -like '*winget list*' }
            
            $result = $package.Test()
            $result | Should -Be $true
        }

        It "Should return false if package is not installed" {
            $package = [DotWinWingetPackage]::new('NonExistent.Package')
            
            # Mock winget list to show package is not found
            Mock Invoke-Expression {
                $global:LASTEXITCODE = 0
                return @('No installed package found matching input criteria.')
            } -ParameterFilter { $Command -like '*winget list*' }
            
            $result = $package.Test()
            $result | Should -Be $false
        }

        It "Should handle winget errors gracefully" {
            $package = [DotWinWingetPackage]::new('Error.Package')
            
            # Mock winget to fail
            Mock Invoke-Expression {
                $global:LASTEXITCODE = 1
                throw "Winget error"
            } -ParameterFilter { $Command -like '*winget list*' }
            
            $result = $package.Test()
            $result | Should -Be $false
        }
    }

    Context "Package Installation" {
        It "Should install package with basic options" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }
            
            { $package.Apply() } | Should -Not -Throw
            
            Assert-MockCalled Start-Process -ParameterFilter {
                $FilePath -eq 'winget' -and $ArgumentList -contains 'install' -and $ArgumentList -contains 'Git.Git'
            }
        }

        It "Should include version in installation" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            $package.Version = '2.40.0'
            
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }
            
            $package.Apply()
            
            Assert-MockCalled Start-Process -ParameterFilter {
                $ArgumentList -contains '--version' -and $ArgumentList -contains '2.40.0'
            }
        }

        It "Should include license acceptance" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            $package.AcceptLicense = $true
            $package.AcceptSourceAgreements = $true
            
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }
            
            $package.Apply()
            
            Assert-MockCalled Start-Process -ParameterFilter {
                $ArgumentList -contains '--accept-package-agreements' -and $ArgumentList -contains '--accept-source-agreements'
            }
        }

        It "Should include custom install options" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            $package.InstallOptions['scope'] = 'machine'
            $package.InstallOptions['silent'] = $true
            
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }
            
            $package.Apply()
            
            Assert-MockCalled Start-Process -ParameterFilter {
                $ArgumentList -contains '--scope' -and $ArgumentList -contains 'machine' -and $ArgumentList -contains '--silent'
            }
        }

        It "Should handle installation failures" {
            $package = [DotWinWingetPackage]::new('Failing.Package')
            
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 1 }
            }
            
            { $package.Apply() } | Should -Throw "*installation failed*"
        }

        It "Should update LastModified on successful installation" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            $originalTime = $package.LastModified
            
            Mock Start-Process {
                return [PSCustomObject]@{ ExitCode = 0 }
            }
            
            Start-Sleep -Milliseconds 100
            $package.Apply()
            
            $package.LastModified | Should -BeGreaterThan $originalTime
        }
    }

    Context "Package State Management" {
        It "Should get current package state" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            
            # Mock winget list and show commands
            Mock Invoke-Expression {
                param($Command)
                $global:LASTEXITCODE = 0
                if ($Command -like '*winget list*') {
                    return @('Git.Git    2.40.0    2.41.0    winget')
                } elseif ($Command -like '*winget show*') {
                    return @('Version: 2.41.0')
                }
                return @()
            }
            
            $state = $package.GetCurrentState()
            
            $state | Should -BeOfType [hashtable]
            $state.PackageId | Should -Be 'Git.Git'
            $state.IsInstalled | Should -Be $true
            $state.Source | Should -Be 'winget'
            $state.LastChecked | Should -BeOfType [DateTime]
        }

        It "Should parse installed version from winget output" {
            $package = [DotWinWingetPackage]::new('Git.Git')
            
            Mock Invoke-Expression {
                $global:LASTEXITCODE = 0
                return @('Git                            Git.Git                      2.40.0       2.41.0    winget')
            } -ParameterFilter { $Command -like '*winget list*' }
            
            $state = $package.GetCurrentState()
            $state.InstalledVersion | Should -Be '2.40.0'
        }

        It "Should handle state retrieval errors gracefully" {
            $package = [DotWinWingetPackage]::new('Error.Package')
            
            Mock Invoke-Expression { throw "State error" }
            
            $state = $package.GetCurrentState()
            $state.IsInstalled | Should -Be $false
        }
    }
}

Describe "DotWinConfiguration" -Tag @('Unit', 'Classes') {
    Context "Configuration Creation and Management" {
        It "Should create configuration with default constructor" {
            $config = [DotWinConfiguration]::new()
            
            $config | Should -Not -BeNullOrEmpty
            $config.Items | Should -BeOfType [System.Collections.Generic.List[DotWinConfigurationItem]]
            $config.Metadata | Should -BeOfType [hashtable]
            $config.Created | Should -BeOfType [DateTime]
            $config.LastModified | Should -BeOfType [DateTime]
            $config.Version | Should -Be '1.0.0'
        }

        It "Should create configuration with name" {
            $config = [DotWinConfiguration]::new('TestConfig')
            
            $config.Name | Should -Be 'TestConfig'
            $config.Items.Count | Should -Be 0
        }

        It "Should add configuration items" {
            $config = [DotWinConfiguration]::new('TestConfig')
            $item = [DotWinWingetPackage]::new('Git.Git')
            
            $config.AddItem($item)
            
            $config.Items.Count | Should -Be 1
            $config.Items[0] | Should -Be $item
        }

        It "Should update LastModified when adding items" {
            $config = [DotWinConfiguration]::new('TestConfig')
            $originalTime = $config.LastModified
            
            Start-Sleep -Milliseconds 100
            $item = [DotWinWingetPackage]::new('Git.Git')
            $config.AddItem($item)
            
            $config.LastModified | Should -BeGreaterThan $originalTime
        }

        It "Should throw when adding null item" {
            $config = [DotWinConfiguration]::new('TestConfig')
            
            { $config.AddItem($null) } | Should -Throw "*cannot be null*"
        }
    }

    Context "Item Management" {
        BeforeEach {
            $config = [DotWinConfiguration]::new('TestConfig')
            $item1 = [DotWinWingetPackage]::new('Git.Git')
            $item2 = [DotWinWingetPackage]::new('Microsoft.VisualStudioCode')
            $item2.Type = 'WingetPackage'
            
            $config.AddItem($item1)
            $config.AddItem($item2)
        }

        It "Should remove item by name" {
            $result = $config.RemoveItem('Git.Git')
            
            $result | Should -Be $true
            $config.Items.Count | Should -Be 1
            $config.Items[0].Name | Should -Be 'Microsoft.VisualStudioCode'
        }

        It "Should return false when removing non-existent item" {
            $result = $config.RemoveItem('NonExistent.Package')
            
            $result | Should -Be $false
            $config.Items.Count | Should -Be 2
        }

        It "Should get item by name" {
            $item = $config.GetItem('Git.Git')
            
            $item | Should -Not -BeNullOrEmpty
            $item.Name | Should -Be 'Git.Git'
        }

        It "Should return null for non-existent item" {
            $item = $config.GetItem('NonExistent.Package')
            
            $item | Should -BeNullOrEmpty
        }

        It "Should get items by type" {
            $items = $config.GetItemsByType('WingetPackage')
            
            $items.Count | Should -Be 2
            foreach ($item in $items) {
                $item.Type | Should -Be 'WingetPackage'
            }
        }

        It "Should return empty list for non-existent type" {
            $items = $config.GetItemsByType('NonExistentType')
            
            $items.Count | Should -Be 0
        }
    }

    Context "Configuration Testing" {
        BeforeEach {
            $config = [DotWinConfiguration]::new('TestConfig')
            
            # Add mock items with different test results
            $passingItem = [DotWinWingetPackage]::new('PassingPackage')
            $passingItem | Add-Member -MemberType ScriptMethod -Name 'Test' -Value { return $true } -Force
            
            $failingItem = [DotWinWingetPackage]::new('FailingPackage')
            $failingItem | Add-Member -MemberType ScriptMethod -Name 'Test' -Value { return $false } -Force
            
            $errorItem = [DotWinWingetPackage]::new('ErrorPackage')
            $errorItem | Add-Member -MemberType ScriptMethod -Name 'Test' -Value { throw "Test error" } -Force
            
            $disabledItem = [DotWinWingetPackage]::new('DisabledPackage')
            $disabledItem.Enabled = $false
            $disabledItem | Add-Member -MemberType ScriptMethod -Name 'Test' -Value { return $true } -Force
            
            $config.AddItem($passingItem)
            $config.AddItem($failingItem)
            $config.AddItem($errorItem)
            $config.AddItem($disabledItem)
        }

        It "Should test all enabled configuration items" {
            $results = $config.TestAll()
            
            $results | Should -BeOfType [hashtable]
            $results.TotalItems | Should -Be 4
            $results.PassedItems | Should -Be 1  # Only PassingPackage
            $results.FailedItems | Should -Be 2  # FailingPackage and ErrorPackage
            $results.Results.Count | Should -Be 3  # Disabled item not tested
        }

        It "Should provide detailed test results" {
            $results = $config.TestAll()
            
            $results.Results['PassingPackage'].Status | Should -Be 'Pass'
            $results.Results['FailingPackage'].Status | Should -Be 'Fail'
            $results.Results['ErrorPackage'].Status | Should -Be 'Error'
            $results.Results['ErrorPackage'].Error | Should -Be 'Test error'
            $results.Results.ContainsKey('DisabledPackage') | Should -Be $false
        }

        It "Should include item type in results" {
            $results = $config.TestAll()
            
            foreach ($result in $results.Results.Values) {
                $result.Type | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe "DotWinSystemProfiler" -Tag @('Unit', 'Classes') {
    BeforeEach {
        # Set up comprehensive mocks for system profiling
        Set-MockCimInstance -ClassName 'Win32_Processor' -MockData (Get-MockWmiData -ClassName 'Win32_Processor')
        Set-MockCimInstance -ClassName 'Win32_ComputerSystem' -MockData (Get-MockWmiData -ClassName 'Win32_ComputerSystem')
        Set-MockCimInstance -ClassName 'Win32_BaseBoard' -MockData (Get-MockWmiData -ClassName 'Win32_BaseBoard')
        Set-MockCimInstance -ClassName 'Win32_VideoController' -MockData (Get-MockWmiData -ClassName 'Win32_VideoController')
        Set-MockCimInstance -ClassName 'Win32_DiskDrive' -MockData (Get-MockWmiData -ClassName 'Win32_DiskDrive')
        Set-MockCimInstance -ClassName 'Win32_NetworkAdapter' -MockData (Get-MockWmiData -ClassName 'Win32_NetworkAdapter')
        Set-MockCimInstance -ClassName 'Win32_OperatingSystem' -MockData (Get-MockWmiData -ClassName 'Win32_OperatingSystem')
        
        Set-MockWingetCommand -Command 'list'
        Set-MockWingetCommand -Command '--version'
        Set-MockWindowsFeatures
        Set-MockPowerShellModules
        
        Mock Get-ChildItem {
            return @(
                [PSCustomObject]@{ Name = 'PATH'; Value = 'C:\Windows\system32' },
                [PSCustomObject]@{ Name = 'USERPROFILE'; Value = 'C:\Users\TestUser' }
            )
        } -ParameterFilter { $Path -eq 'Env:' }
    }

    Context "Profiler Creation and Initialization" {
        It "Should create system profiler with default constructor" {
            $profiler = [DotWinSystemProfiler]::new()
            
            $profiler | Should -Not -BeNullOrEmpty
            $profiler.Hardware | Should -BeOfType [DotWinHardwareProfile]
            $profiler.Software | Should -BeOfType [DotWinSoftwareProfile]
            $profiler.User | Should -BeOfType [DotWinUserProfile]
            $profiler.SystemMetrics | Should -BeOfType [hashtable]
            $profiler.ProfileVersion | Should -Be '1.0.0'
        }

        It "Should initialize sub-profiles correctly" {
            $profiler = [DotWinSystemProfiler]::new()
            
            $profiler.Hardware.GPU_Manufacturers | Should -BeOfType [Array]
            $profiler.Hardware.GPU_Models | Should -BeOfType [Array]
            $profiler.Software.InstalledPackages | Should -BeOfType [hashtable]
            $profiler.User.EnvironmentVariables | Should -BeOfType [hashtable]
        }
    }

    Context "Hardware Profiling" {
        It "Should profile hardware components" {
            $profiler = [DotWinSystemProfiler]::new()
            
            $profiler.ProfileHardware()
            
            $profiler.Hardware.CPU_Manufacturer | Should -Be 'GenuineIntel'
            $profiler.Hardware.CPU_Model | Should -Not -BeNullOrEmpty
            $profiler.Hardware.CPU_Cores | Should -BeGreaterThan 0
            $profiler.Hardware.TotalMemoryGB | Should -BeGreaterThan 0
            $profiler.Hardware.ProfiledAt | Should -BeOfType [DateTime]
        }

        It "Should handle hardware profiling errors gracefully" {
            Mock Get-CimInstance { throw "Hardware error" } -ParameterFilter { $ClassName -eq 'Win32_Processor' }
            
            $profiler = [DotWinSystemProfiler]::new()
            
            { $profiler.ProfileHardware() } | Should -Throw "*Hardware error*"
        }
    }

    Context "Software Profiling" {
        It "Should profile software components" {
            $profiler = [DotWinSystemProfiler]::new()
            
            $profiler.ProfileSoftware()
            
            $profiler.Software.PackageManagers | Should -Not -BeNullOrEmpty
            $profiler.Software.PackageManagers.ContainsKey('Winget') | Should -Be $true
            $profiler.Software.PowerShellModules | Should -Not -BeNullOrEmpty
            $profiler.Software.ProfiledAt | Should -BeOfType [DateTime]
        }

        It "Should categorize installed software" {
            $profiler = [DotWinSystemProfiler]::new()
            
            # Mock installed packages with categorizable names
            Mock Invoke-Expression {
                $global:LASTEXITCODE = 0
                return @(
                    'git.git    2.40.0    winget',
                    'Microsoft.VisualStudioCode    1.80.0    winget',
                    'Steam.Steam    1.0.0    winget'
                )
            } -ParameterFilter { $Command -like '*winget list*' }
            
            $profiler.ProfileSoftware()
            
            $profiler.Software.DevelopmentTools | Should -Contain 'git.git'
            $profiler.Software.DevelopmentTools | Should -Contain 'Microsoft.VisualStudioCode'
            $profiler.Software.GamingTools | Should -Contain 'Steam.Steam'
        }
    }

    Context "User Profiling" {
        It "Should profile user information" {
            $profiler = [DotWinSystemProfiler]::new()
            
            $profiler.ProfileUser()
            
            $profiler.User.Username | Should -Be $env:USERNAME
            $profiler.User.Domain | Should -Be $env:USERDOMAIN
            $profiler.User.IsAdministrator | Should -BeOfType [bool]
            $profiler.User.EnvironmentVariables | Should -Not -BeNullOrEmpty
            $profiler.User.ProfiledAt | Should -BeOfType [DateTime]
        }
    }

    Context "System Metrics Calculation" {
        It "Should calculate system metrics" {
            $profiler = [DotWinSystemProfiler]::new()
            $profiler.ProfileHardware()
            $profiler.ProfileSoftware()
            $profiler.ProfileUser()
            
            $profiler.CalculateSystemMetrics()
            
            $profiler.SystemMetrics.PerformanceScore | Should -BeGreaterOrEqual 0
            $profiler.SystemMetrics.PerformanceScore | Should -BeLessOrEqual 100
            $profiler.SystemMetrics.SecurityScore | Should -BeGreaterOrEqual 0
            $profiler.SystemMetrics.SecurityScore | Should -BeLessOrEqual 100
            $profiler.SystemMetrics.DeveloperFriendliness | Should -BeGreaterOrEqual 0
            $profiler.SystemMetrics.DeveloperFriendliness | Should -BeLessOrEqual 100
        }

        It "Should calculate performance score based on hardware" {
            $profiler = [DotWinSystemProfiler]::new()
            
            # Set high-performance hardware
            $profiler.Hardware.CPU_Cores = 16
            $profiler.Hardware.TotalMemoryGB = 64
            $profiler.Hardware.Storage_Types = @('SSD')
            $profiler.Hardware.GPU_Manufacturers = @('NVIDIA')
            
            $profiler.CalculateSystemMetrics()
            
            $profiler.SystemMetrics.PerformanceScore | Should -BeGreaterThan 80
        }
    }

    Context "Profile Export" {
        It "Should export profile to JSON" {
            $profiler = [DotWinSystemProfiler]::new()
            $profiler.ProfileHardware()
            $profiler.ProfileSoftware()
            $profiler.ProfileUser()
            $profiler.CalculateSystemMetrics()
            
            $json = $profiler.ExportToJson()
            
            $json | Should -Not -BeNullOrEmpty
            { $json | ConvertFrom-Json } | Should -Not -Throw
            
            $data = $json | ConvertFrom-Json
            $data.Hardware | Should -Not -BeNullOrEmpty
            $data.Software | Should -Not -BeNullOrEmpty
            $data.User | Should -Not -BeNullOrEmpty
            $data.SystemMetrics | Should -Not -BeNullOrEmpty
        }
    }

    Context "Complete Profiling Workflow" {
        It "Should perform complete system profiling" {
            $profiler = [DotWinSystemProfiler]::new()
            
            $profiler.ProfileSystem()
            
            $profiler.LastProfiled | Should -BeOfType [DateTime]
            $profiler.Hardware.ProfiledAt | Should -BeOfType [DateTime]
            $profiler.Software.ProfiledAt | Should -BeOfType [DateTime]
            $profiler.User.ProfiledAt | Should -BeOfType [DateTime]
            $profiler.SystemMetrics.Count | Should -BeGreaterThan 0
        }

        It "Should handle profiling errors gracefully" {
            Mock Get-CimInstance { throw "Critical profiling error" }
            
            $profiler = [DotWinSystemProfiler]::new()
            
            { $profiler.ProfileSystem() } | Should -Throw "*Critical profiling error*"
        }
    }
}

Describe "DotWinHardwareProfile" -Tag @('Unit', 'Classes') {
    Context "Hardware Classification" {
        It "Should classify high-performance hardware correctly" {
            $hardware = [DotWinHardwareProfile]::new()
            $hardware.CPU_Cores = 16
            $hardware.TotalMemoryGB = 64
            $hardware.GPU_Manufacturers = @('NVIDIA')
            
            $category = $hardware.GetHardwareCategory()
            $category | Should -Be 'HighPerformance'
        }

        It "Should classify workstation hardware correctly" {
            $hardware = [DotWinHardwareProfile]::new()
            $hardware.CPU_Cores = 12
            $hardware.TotalMemoryGB = 32
            $hardware.GPU_Manufacturers = @('Intel')
            
            $category = $hardware.GetHardwareCategory()
            $category | Should -Be 'Workstation'
        }

        It "Should classify mainstream hardware correctly" {
            $hardware = [DotWinHardwareProfile]::new()
            $hardware.CPU_Cores = 6
            $hardware.TotalMemoryGB = 16
            
            $category = $hardware.GetHardwareCategory()
            $category | Should -Be 'Mainstream'
        }

        It "Should classify budget hardware correctly" {
            $hardware = [DotWinHardwareProfile]::new()
            $hardware.CPU_Cores = 2
            $hardware.TotalMemoryGB = 4
            
            $category = $hardware.GetHardwareCategory()
            $category | Should -Be 'Budget'
        }
    }

    Context "Gaming Optimization Detection" {
        It "Should detect gaming-optimized systems" {
            $hardware = [DotWinHardwareProfile]::new()
            $hardware.CPU_Cores = 8
            $hardware.TotalMemoryGB = 16
            $hardware.GPU_Manufacturers = @('NVIDIA')
            
            $isGamingOptimized = $hardware.IsGamingOptimized()
            $isGamingOptimized | Should -Be $true
        }

        It "Should detect non-gaming systems" {
            $hardware = [DotWinHardwareProfile]::new()
            $hardware.CPU_Cores = 2
            $hardware.TotalMemoryGB = 4
            $hardware.GPU_Manufacturers = @('Intel')
            
            $isGamingOptimized = $hardware.IsGamingOptimized()
            $isGamingOptimized | Should -Be $false
        }
    }

    Context "Virtualization Support Detection" {
        It "Should detect virtualization-capable systems" {
            $hardware = [DotWinHardwareProfile]::new()
            $hardware.CPU_Cores = 8
            $hardware.TotalMemoryGB = 32
            
            $supportsVirtualization = $hardware.SupportsVirtualization()
            $supportsVirtualization | Should -Be $true
        }

        It "Should detect systems with insufficient resources for virtualization" {
            $hardware = [DotWinHardwareProfile]::new()
            $hardware.CPU_Cores = 2
            $hardware.TotalMemoryGB = 8
            
            $supportsVirtualization = $hardware.SupportsVirtualization()
            $supportsVirtualization | Should -Be $false
        }
    }
}

Describe "DotWinSoftwareProfile" -Tag @('Unit', 'Classes') {
    Context "User Type Detection" {
        It "Should detect developer user type" {
            $software = [DotWinSoftwareProfile]::new()
            $software.DevelopmentTools = @('Git', 'VisualStudio', 'Docker', 'NodeJS')
            $software.ProductivityTools = @('Office')
            
            $userType = $software.GetUserType()
            $userType | Should -Be 'Developer'
        }

        It "Should detect gamer user type" {
            $software = [DotWinSoftwareProfile]::new()
            $software.GamingTools = @('Steam', 'Discord', 'OBS')
            $software.DevelopmentTools = @()
            
            $userType = $software.GetUserType()
            $userType | Should -Be 'Gamer'
        }

        It "Should detect creative user type" {
            $software = [DotWinSoftwareProfile]::new()
            $software.MediaTools = @('Photoshop', 'Premiere', 'Blender')
            $software.DevelopmentTools = @()
            $software.GamingTools = @()
            
            $userType = $software.GetUserType()
            $userType | Should -Be 'Creative'
        }

        It "Should detect business user type" {
            $software = [DotWinSoftwareProfile]::new()
            $software.ProductivityTools = @('Office', 'Teams', 'Outlook')
            $software.DevelopmentTools = @()
            $software.GamingTools = @()
            $software.MediaTools = @()

            $userType = $software.GetUserType()
            $userType | Should -Be 'Business'
        }

        It "Should default to general user type" {
            $software = [DotWinSoftwareProfile]::new()
            # No tools installed

            $userType = $software.GetUserType()
            $userType | Should -Be 'General'
        }
    }

    Context "Package Manager Detection" {
        It "Should detect available package managers" {
            $software = [DotWinSoftwareProfile]::new()
            $software.PackageManagers['Winget'] = @{ Available = $true; Version = 'v1.5.2011' }
            $software.PackageManagers['Chocolatey'] = @{ Available = $false }

            $hasWinget = $software.HasPackageManager('Winget')
            $hasChocolatey = $software.HasPackageManager('Chocolatey')

            $hasWinget | Should -Be $true
            $hasChocolatey | Should -Be $false
        }
    }
}

Describe "DotWinUserProfile" -Tag @('Unit', 'Classes') {
    Context "Technical Level Assessment" {
        It "Should detect advanced technical level" {
            $user = [DotWinUserProfile]::new()
            $user.PreferredShell = 'PowerShell Core'
            $user.EnvironmentVariables['PATH'] = 'C:\Windows\system32;C:\Program Files\Git\bin'
            $user.RecentApplications = @('Visual Studio Code', 'Git')

            $techLevel = $user.GetTechnicalLevel()
            $techLevel | Should -Be 'Advanced'
        }

        It "Should detect intermediate technical level" {
            $user = [DotWinUserProfile]::new()
            $user.PreferredShell = 'PowerShell'
            $user.RecentApplications = @('Visual Studio Code')

            $techLevel = $user.GetTechnicalLevel()
            $techLevel | Should -Be 'Intermediate'
        }

        It "Should detect beginner technical level" {
            $user = [DotWinUserProfile]::new()
            $user.PreferredShell = 'PowerShell'
            $user.RecentApplications = @('Notepad', 'Calculator')

            $techLevel = $user.GetTechnicalLevel()
            $techLevel | Should -Be 'Beginner'
        }
    }
}

Describe "DotWinPlugin Classes" -Tag @('Unit', 'Classes') {
    Context "Base Plugin Class" {
        It "Should create plugin with default constructor" {
            $plugin = [DotWinPlugin]::new()

            $plugin | Should -Not -BeNullOrEmpty
            $plugin.Metadata | Should -BeOfType [hashtable]
            $plugin.Dependencies | Should -BeOfType [Array]
            $plugin.SupportedPlatforms | Should -Contain 'Windows'
            $plugin.Enabled | Should -Be $true
            $plugin.LoadedAt | Should -BeOfType [DateTime]
        }

        It "Should create plugin with name and version" {
            $plugin = [DotWinPlugin]::new('TestPlugin', '1.0.0')

            $plugin.Name | Should -Be 'TestPlugin'
            $plugin.Version | Should -Be '1.0.0'
        }

        It "Should throw on virtual method calls" {
            $plugin = [DotWinPlugin]::new()

            { $plugin.Initialize() } | Should -Throw "*must be implemented*"
            { $plugin.Cleanup() } | Should -Throw "*must be implemented*"
            { $plugin.GetCapabilities() } | Should -Throw "*must be implemented*"
        }

        It "Should validate environment by default" {
            $plugin = [DotWinPlugin]::new()

            $result = $plugin.ValidateEnvironment()
            $result | Should -Be $true
        }
    }

    Context "Configuration Plugin Class" {
        It "Should create configuration plugin" {
            $plugin = [DotWinConfigurationPlugin]::new()

            $plugin.Category | Should -Be 'Configuration'
            $plugin.SupportedTypes | Should -BeOfType [Array]
            $plugin.ConfigurationHandlers | Should -BeOfType [hashtable]
        }

        It "Should register configuration handlers" {
            $plugin = [DotWinConfigurationPlugin]::new('ConfigPlugin', '1.0.0')
            $handler = { param($item) return [DotWinExecutionResult]::new() }

            $plugin.RegisterHandler('TestType', $handler)

            $plugin.SupportedTypes | Should -Contain 'TestType'
            $plugin.ConfigurationHandlers['TestType'] | Should -Be $handler
        }

        It "Should process configuration items" {
            $plugin = [DotWinConfigurationPlugin]::new('ConfigPlugin', '1.0.0')
            $handler = {
                param($item)
                $result = [DotWinExecutionResult]::new()
                $result.Success = $true
                $result.ItemName = $item.Name
                return $result
            }
            $plugin.RegisterHandler('TestType', $handler)

            $item = [DotWinConfigurationItem]::new('TestItem', 'TestType')
            $result = $plugin.ProcessConfiguration($item)

            $result | Should -BeOfType [DotWinExecutionResult]
            $result.Success | Should -Be $true
            $result.ItemName | Should -Be 'TestItem'
        }

        It "Should handle unsupported configuration types" {
            $plugin = [DotWinConfigurationPlugin]::new('ConfigPlugin', '1.0.0')
            $item = [DotWinConfigurationItem]::new('TestItem', 'UnsupportedType')

            { $plugin.ProcessConfiguration($item) } | Should -Throw "*not supported*"
        }

        It "Should handle handler execution errors" {
            $plugin = [DotWinConfigurationPlugin]::new('ConfigPlugin', '1.0.0')
            $handler = { throw "Handler error" }
            $plugin.RegisterHandler('TestType', $handler)

            $item = [DotWinConfigurationItem]::new('TestItem', 'TestType')
            $result = $plugin.ProcessConfiguration($item)

            $result.Success | Should -Be $false
            $result.Message | Should -Match "Handler error"
        }
    }

    Context "Recommendation Plugin Class" {
        It "Should create recommendation plugin" {
            $plugin = [DotWinRecommendationPlugin]::new()

            $plugin.Category | Should -Be 'Recommendation'
            $plugin.RecommendationCategories | Should -BeOfType [Array]
            $plugin.RecommendationRules | Should -BeOfType [hashtable]
        }

        It "Should register recommendation rules" {
            $plugin = [DotWinRecommendationPlugin]::new('RecommendPlugin', '1.0.0')
            $rule = { param($systemProfile) return @() }

            $plugin.RegisterRule('Performance', 'TestRule', $rule)

            $plugin.RecommendationCategories | Should -Contain 'Performance'
            $plugin.RecommendationRules['Performance']['TestRule'] | Should -Be $rule
        }

        It "Should throw on GenerateRecommendations call" {
            $plugin = [DotWinRecommendationPlugin]::new()
            $systemProfile = [DotWinSystemProfiler]::new()

            { $plugin.GenerateRecommendations($systemProfile) } | Should -Throw "*must be implemented*"
        }
    }
}

Describe "DotWinPluginManager" -Tag @('Unit', 'Classes') {
    Context "Plugin Manager Creation and Configuration" {
        It "Should create plugin manager with default settings" {
            $manager = [DotWinPluginManager]::new()

            $manager | Should -Not -BeNullOrEmpty
            $manager.LoadedPlugins | Should -BeOfType [hashtable]
            $manager.PluginRegistry | Should -BeOfType [hashtable]
            $manager.PluginPaths | Should -BeOfType [Array]
            $manager.AutoLoadEnabled | Should -Be $true
        }

        It "Should add plugin search paths" {
            $manager = [DotWinPluginManager]::new()
            $testDir = New-TestDirectory -Name 'PluginPath'

            try {
                $manager.AddPluginPath($testDir)
                $manager.PluginPaths | Should -Contain $testDir
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }

        It "Should handle non-existent plugin paths" {
            $manager = [DotWinPluginManager]::new()

            { $manager.AddPluginPath('C:\NonExistent\Path') } | Should -Throw "*does not exist*"
        }
    }

    Context "Plugin Registration and Management" {
        BeforeEach {
            $manager = [DotWinPluginManager]::new()
            $plugin = New-MockPlugin -Name 'TestPlugin' -Version '1.0.0'
            $null = $manager, $plugin # PSAnalyzer IsDeclaredVarsMoreThanAssignments cannot see that these two variables are used outside the BeforeEach script block.
        }

        It "Should register valid plugins" {
            $manager.RegisterPlugin($plugin)

            $manager.PluginRegistry.ContainsKey('TestPlugin') | Should -Be $true
        }

        It "Should validate plugins before registration" {
            $invalidPlugin = New-MockPlugin -Name '' -Version '1.0.0'  # Invalid name

            { $manager.RegisterPlugin($invalidPlugin) } | Should -Throw "*validation failed*"
        }

        It "Should check plugin dependencies" {
            $plugin.Dependencies = @('MissingDependency')

            { $manager.RegisterPlugin($plugin) } | Should -Throw "*dependencies not satisfied*"
        }

        It "Should load registered plugins" {
            $manager.RegisterPlugin($plugin)
            $result = $manager.LoadPlugin('TestPlugin')

            $result | Should -Be $true
            $manager.LoadedPlugins.ContainsKey('TestPlugin') | Should -Be $true
        }

        It "Should unload loaded plugins" {
            $manager.RegisterPlugin($plugin)
            $manager.LoadPlugin('TestPlugin')

            $result = $manager.UnloadPlugin('TestPlugin')

            $result | Should -Be $true
            $manager.LoadedPlugins.ContainsKey('TestPlugin') | Should -Be $false
        }

        It "Should get plugins by category" {
            $plugin1 = New-MockPlugin -Name 'Plugin1' -Category 'Configuration'
            $plugin2 = New-MockPlugin -Name 'Plugin2' -Category 'Recommendation'

            $manager.RegisterPlugin($plugin1)
            $manager.RegisterPlugin($plugin2)
            $manager.LoadPlugin('Plugin1')
            $manager.LoadPlugin('Plugin2')

            $configPlugins = $manager.GetPluginsByCategory('Configuration')
            $configPlugins.Count | Should -Be 1
            $configPlugins[0].Name | Should -Be 'Plugin1'
        }
    }

    Context "Plugin Information and Discovery" {
        BeforeEach {
            $manager = [DotWinPluginManager]::new()
            $plugin = New-MockPlugin -Name 'InfoPlugin' -Version '2.0.0'
            $manager.RegisterPlugin($plugin)
        }

        It "Should get plugin information" {
            $info = $manager.GetPluginInfo('InfoPlugin')

            $info | Should -BeOfType [hashtable]
            $info.Name | Should -Be 'InfoPlugin'
            $info.Version | Should -Be '2.0.0'
            $info.Loaded | Should -Be $false
            $info.Dependencies | Should -BeOfType [Array]
        }

        It "Should handle plugin not found in GetPluginInfo" {
            { $manager.GetPluginInfo('NonExistentPlugin') } | Should -Throw "*not registered*"
        }

        It "Should discover plugins in search paths" {
            $testDir = New-TestDirectory -Name 'PluginDiscovery'

            try {
                $pluginFile = Join-Path $testDir 'DiscoveredPlugin.ps1'
                'class DiscoveredPlugin : DotWinPlugin {}' | Set-Content -Path $pluginFile

                $manager.AddPluginPath($testDir)
                $manager.DiscoverPlugins()

                # Should have attempted to discover plugins
                $manager.PluginPaths | Should -Contain $testDir
            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }
    }
}

Describe "Result and Status Classes" -Tag @('Unit', 'Classes') {
    Context "DotWinValidationResult" {
        It "Should create validation result with default constructor" {
            $result = [DotWinValidationResult]::new()

            $result | Should -Not -BeNullOrEmpty
            $result.Timestamp | Should -BeOfType [DateTime]
            $result.Severity | Should -Be 'Information'
        }

        It "Should create validation result with parameters" {
            $result = [DotWinValidationResult]::new($true, 'TestItem', 'Test passed')

            $result.IsValid | Should -Be $true
            $result.ItemName | Should -Be 'TestItem'
            $result.Message | Should -Be 'Test passed'
            $result.Severity | Should -Be 'Information'
        }

        It "Should set severity based on validity" {
            $validResult = [DotWinValidationResult]::new($true, 'ValidItem', 'Valid')
            $invalidResult = [DotWinValidationResult]::new($false, 'InvalidItem', 'Invalid')

            $validResult.Severity | Should -Be 'Information'
            $invalidResult.Severity | Should -Be 'Error'
        }
    }

    Context "DotWinExecutionResult" {
        It "Should create execution result with default constructor" {
            $result = [DotWinExecutionResult]::new()

            $result | Should -Not -BeNullOrEmpty
            $result.Changes | Should -BeOfType [hashtable]
            $result.Timestamp | Should -BeOfType [DateTime]
        }

        It "Should create execution result with parameters" {
            $result = [DotWinExecutionResult]::new($true, 'TestItem', 'Execution successful')

            $result.Success | Should -Be $true
            $result.ItemName | Should -Be 'TestItem'
            $result.Message | Should -Be 'Execution successful'
        }
    }

    Context "DotWinSystemStatus" {
        It "Should create system status with default values" {
            $status = [DotWinSystemStatus]::new()

            $status | Should -Not -BeNullOrEmpty
            $status.ComputerName | Should -Be $env:COMPUTERNAME
            $status.ConfigurationStatus | Should -BeOfType [hashtable]
            $status.LastCheck | Should -BeOfType [DateTime]
            $status.IsCompliant | Should -Be $false
        }

        It "Should initialize system information" {
            $status = [DotWinSystemStatus]::new()

            $status.InitializeSystemInfo('Windows 11 Pro', '7.3.0')

            $status.OperatingSystem | Should -Be 'Windows 11 Pro'
            $status.PowerShellVersion | Should -Be '7.3.0'
        }

        It "Should handle system information errors gracefully" {
            Mock Get-CimInstance { throw "WMI Error" }

            $status = [DotWinSystemStatus]::new()
            $status.InitializeSystemInfo($null, $null)

            $status.OperatingSystem | Should -Be 'Unknown'
        }
    }
}
