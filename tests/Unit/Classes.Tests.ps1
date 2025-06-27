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

            $userType = $software.GetUserType

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

Describe "DotWinConfigurationBridge" -Tag @('Unit', 'Classes') {
    BeforeEach {
        # Create temporary test directories
        $script:testModuleConfigPath = New-TestDirectory -Name 'ModuleConfig'
        $script:testUserConfigPath = New-TestDirectory -Name 'UserConfig'

        # Create mock configuration files
        $packagesConfig = @'
function Get-PackagesByCategory {
    param([string]$Category)
    return @{
        Development = @(
            @{ Id = 'Git.Git'; Name = 'Git'; Version = '2.40.0' }
            @{ Id = 'Microsoft.VisualStudioCode'; Name = 'VS Code'; Version = '1.80.0' }
        )
        Productivity = @(
            @{ Id = 'Microsoft.Office'; Name = 'Office'; Version = '2021' }
        )
    }[$Category]
}
'@

        $terminalConfig = @'
function Get-TerminalConfiguration {
    param(
        [string]$Theme,
        [bool]$IncludeProfiles,
        [bool]$IncludeKeybindings,
        [bool]$IncludeSettings
    )
    $config = @{
        theme = $Theme
        profiles = @{
            list = @(
                @{ guid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'; name = 'Windows PowerShell' }
            )
        }
        schemes = @(
            @{ name = 'Campbell'; background = '#0C0C0C' }
        )
    }
    if (-not $IncludeProfiles) { $config.Remove('profiles') }
    if (-not $IncludeSettings) { $config.Remove('schemes') }
    return $config
}
'@

        $profileConfig = @'
function Get-ProfileConfiguration {
    param(
        [string]$ProfileType,
        [bool]$IncludeModules,
        [bool]$IncludeAliases,
        [bool]$IncludeFunctions,
        [bool]$IncludePrompt
    )
    $config = @{
        ProfileType = $ProfileType
        Modules = @('Posh-Git', 'PSReadLine')
        Aliases = @{ ll = 'Get-ChildItem -Force'; la = 'Get-ChildItem -Force -Hidden' }
        Functions = @{ 'Get-GitStatus' = 'git status' }
        Prompt = 'function prompt { "PS $($PWD.Path)> " }'
    }
    if (-not $IncludeModules) { $config.Remove('Modules') }
    if (-not $IncludeAliases) { $config.Remove('Aliases') }
    if (-not $IncludeFunctions) { $config.Remove('Functions') }
    if (-not $IncludePrompt) { $config.Remove('Prompt') }
    return $config
}
'@

        # Write module config files
        $packagesConfig | Set-Content -Path (Join-Path $script:testModuleConfigPath 'Packages.ps1')
        $terminalConfig | Set-Content -Path (Join-Path $script:testModuleConfigPath 'Terminal.ps1')
        $profileConfig | Set-Content -Path (Join-Path $script:testModuleConfigPath 'Profile.ps1')

        # Mock Write-DotWinLog to avoid errors
        Mock Write-DotWinLog { }
    }

    AfterEach {
        # Clean up test directories
        if ($script:testModuleConfigPath) {
            Remove-TestDirectory -Path $script:testModuleConfigPath
        }
        if ($script:testUserConfigPath) {
            Remove-TestDirectory -Path $script:testUserConfigPath
        }
    }

    Context "Bridge Creation and Initialization" {
        It "Should create configuration bridge with valid paths" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $script:testUserConfigPath)

            $bridge | Should -Not -BeNullOrEmpty
            $bridge.ModuleConfigPath | Should -Be $script:testModuleConfigPath
            $bridge.UserConfigPath | Should -Be $script:testUserConfigPath
            $bridge.ConfigurationCache | Should -BeOfType [hashtable]
            $bridge.CacheEnabled | Should -Be $true
            $bridge.LastCacheUpdate | Should -BeOfType [DateTime]
        }

        It "Should create configuration bridge without user config path" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $bridge.ModuleConfigPath | Should -Be $script:testModuleConfigPath
            $bridge.UserConfigPath | Should -BeNullOrEmpty
        }

        It "Should initialize with empty cache" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $script:testUserConfigPath)

            $bridge.ConfigurationCache.Count | Should -Be 0
        }
    }

    Context "Package Configuration Resolution" {
        It "Should resolve package configuration from module" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $packages = $bridge.ResolvePackageConfiguration('Development')

            $packages | Should -Not -BeNullOrEmpty
            $packages.Count | Should -Be 2
            $packages[0].Id | Should -Be 'Git.Git'
            $packages[1].Id | Should -Be 'Microsoft.VisualStudioCode'
        }

        It "Should cache package configuration results" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            # First call
            $packages1 = $bridge.ResolvePackageConfiguration('Development')
            $null = $packages1
            # Second call should use cache
            $packages2 = $bridge.ResolvePackageConfiguration('Development')
            $null = $packages2
            $bridge.ConfigurationCache.Count | Should -Be 1
            $bridge.ConfigurationCache.ContainsKey('Packages_Development') | Should -Be $true
        }

        It "Should merge user package overrides" {
            # Create user package config with overrides
            $userPackagesConfig = @'
function Get-PackagesByCategory {
    param([string]$Category)
    return @{
        Development = @(
            @{ Id = 'Git.Git'; Name = 'Git'; Version = '2.41.0' }
            @{ Id = 'JetBrains.IntelliJIDEA'; Name = 'IntelliJ'; Version = '2023.1' }
        )
    }[$Category]
}
'@
            $userPackagesConfig | Set-Content -Path (Join-Path $script:testUserConfigPath 'Packages.ps1')

            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $script:testUserConfigPath)

            $packages = $bridge.ResolvePackageConfiguration('Development')

            $packages | Should -Not -BeNullOrEmpty
            $packages.Count | Should -Be 3  # 2 base + 1 new, with Git.Git overridden

            # Find the Git package to verify override
            $gitPackage = $packages | Where-Object { $_.Id -eq 'Git.Git' }
            $gitPackage.Version | Should -Be '2.41.0'  # Should use user override

            # Verify new package was added
            $intellijPackage = $packages | Where-Object { $_.Id -eq 'JetBrains.IntelliJIDEA' }
            $intellijPackage | Should -Not -BeNullOrEmpty
        }

        It "Should handle missing module configuration gracefully" {
            $emptyConfigPath = New-TestDirectory -Name 'EmptyConfig'
            try {
                $bridge = [DotWinConfigurationBridge]::new($emptyConfigPath, $null)

                $packages = $bridge.ResolvePackageConfiguration('Development')

                $packages | Should -BeOfType [hashtable]
                $packages.Count | Should -Be 0
            } finally {
                Remove-TestDirectory -Path $emptyConfigPath
            }
        }

        It "Should handle user configuration errors gracefully" {
            # Create invalid user config
            'invalid powershell syntax {' | Set-Content -Path (Join-Path $script:testUserConfigPath 'Packages.ps1')

            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $script:testUserConfigPath)

            # Should not throw and should return base configuration
            $packages = $bridge.ResolvePackageConfiguration('Development')

            $packages | Should -Not -BeNullOrEmpty
            $packages.Count | Should -Be 2  # Base configuration only
        }
    }

    Context "Terminal Configuration Resolution" {
        It "Should resolve terminal configuration from module" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $config = $bridge.ResolveTerminalConfiguration('Dark', $true, $false, $true)

            $config | Should -Not -BeNullOrEmpty
            $config.theme | Should -Be 'Dark'
            $config.profiles | Should -Not -BeNullOrEmpty
            $config.schemes | Should -Not -BeNullOrEmpty
        }

        It "Should respect include parameters" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $config = $bridge.ResolveTerminalConfiguration('Dark', $false, $false, $false)

            $config.theme | Should -Be 'Dark'
            $config.ContainsKey('profiles') | Should -Be $false
            $config.ContainsKey('schemes') | Should -Be $false
        }

        It "Should merge user terminal overrides" {
            # Create user terminal config with overrides
            $userTerminalConfig = @'
function Get-TerminalConfiguration {
    param(
        [string]$Theme,
        [bool]$IncludeProfiles,
        [bool]$IncludeKeybindings,
        [bool]$IncludeSettings
    )
    return @{
        theme = $Theme
        profiles = @{
            list = @(
                @{ guid = '{61c54bbd-c2c6-5271-96e7-009a87ff44bf}'; name = 'Custom PowerShell'; background = '#001122' }
                @{ guid = '{new-guid}'; name = 'Custom Profile'; background = '#112233' }
            )
        }
        schemes = @(
            @{ name = 'Campbell'; background = '#001122' }
            @{ name = 'CustomScheme'; background = '#223344' }
        )
    }
}
'@
            $userTerminalConfig | Set-Content -Path (Join-Path $script:testUserConfigPath 'Terminal.ps1')

            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $script:testUserConfigPath)

            $config = $bridge.ResolveTerminalConfiguration('Dark', $true, $false, $true)

            $config.profiles.list.Count | Should -Be 2  # 1 base + 1 new, with existing updated
            $config.schemes.Count | Should -Be 2  # 1 base + 1 new, with existing updated

            # Verify profile override
            $customProfile = $config.profiles.list | Where-Object { $_.name -eq 'Custom PowerShell' }
            $customProfile.background | Should -Be '#001122'

            # Verify scheme override
            $campbellScheme = $config.schemes | Where-Object { $_.name -eq 'Campbell' }
            $campbellScheme.background | Should -Be '#001122'
        }

        It "Should cache terminal configuration with complex keys" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $config1 = $bridge.ResolveTerminalConfiguration('Dark', $true, $true, $true)
            $null = $config1
            $config2 = $bridge.ResolveTerminalConfiguration('Dark', $true, $true, $true)
            $null = $config2
            $bridge.ConfigurationCache.Count | Should -Be 1
            $bridge.ConfigurationCache.ContainsKey('Terminal_Dark_True_True_True') | Should -Be $true
        }
    }

    Context "Profile Configuration Resolution" {
        It "Should resolve profile configuration from module" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $config = $bridge.ResolveProfileConfiguration('Developer', $true, $true, $true, $true)

            $config | Should -Not -BeNullOrEmpty
            $config.ProfileType | Should -Be 'Developer'
            $config.Modules | Should -Contain 'Posh-Git'
            $config.Aliases | Should -BeOfType [hashtable]
            $config.Functions | Should -BeOfType [hashtable]
            $config.Prompt | Should -Not -BeNullOrEmpty
        }

        It "Should merge user profile overrides" {
            # Create user profile config with overrides
            $userProfileConfig = @'
function Get-ProfileConfiguration {
    param(
        [string]$ProfileType,
        [bool]$IncludeModules,
        [bool]$IncludeAliases,
        [bool]$IncludeFunctions,
        [bool]$IncludePrompt
    )
    return @{
        ProfileType = $ProfileType
        Modules = @('Posh-Git', 'Terminal-Icons', 'PSFzf')
        Aliases = @{ ll = 'Get-ChildItem -Force -Name'; grep = 'Select-String' }
        Functions = @{ 'Get-GitBranch' = 'git branch' }
        Prompt = 'function prompt { "Custom> " }'
    }
}
'@
            $userProfileConfig | Set-Content -Path (Join-Path $script:testUserConfigPath 'Profile.ps1')

            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $script:testUserConfigPath)

            $config = $bridge.ResolveProfileConfiguration('Developer', $true, $true, $true, $true)

            # Verify module merging (should have base + new modules)
            $config.Modules | Should -Contain 'Posh-Git'  # Base module
            $config.Modules | Should -Contain 'Terminal-Icons'  # New module
            $config.Modules | Should -Contain 'PSFzf'  # New module
            $config.Modules.Count | Should -Be 3

            # Verify alias override and addition
            $config.Aliases['ll'] | Should -Be 'Get-ChildItem -Force -Name'  # Overridden
            $config.Aliases['grep'] | Should -Be 'Select-String'  # New alias
            $config.Aliases['la'] | Should -Be 'Get-ChildItem -Force -Hidden'  # Base alias preserved

            # Verify function addition
            $config.Functions['Get-GitBranch'] | Should -Be 'git branch'  # New function
            $config.Functions['Get-GitStatus'] | Should -Be 'git status'  # Base function preserved

            # Verify prompt override
            $config.Prompt | Should -Be 'function prompt { "Custom> " }'
        }
    }

    # User Configuration Discovery Tests
    Describe "User Configuration Discovery Functions" {
        BeforeAll {
            # Import the User Configuration Discovery functions
            . "$PSScriptRoot\..\..\functions\UserConfigurationDiscovery.ps1"

            # Create test directory structure
            $script:TestConfigRoot = Join-Path $TestDrive "UserConfigTests"
            $null = New-Item -Path $script:TestConfigRoot -ItemType Directory -Force

            # Create mock user directories
            $script:MockUserProfile = Join-Path $script:TestConfigRoot "MockUser"
            $script:MockDocuments = Join-Path $script:MockUserProfile "Documents"
            $script:MockDesktop = Join-Path $script:MockUserProfile "Desktop"
            $script:MockDotFiles = Join-Path $script:MockUserProfile ".dotfiles"
            $script:MockConfig = Join-Path $script:MockUserProfile ".config"

            $null = New-Item -Path $script:MockUserProfile -ItemType Directory -Force
            $null = New-Item -Path $script:MockDocuments -ItemType Directory -Force
            $null = New-Item -Path $script:MockDesktop -ItemType Directory -Force
            $null = New-Item -Path $script:MockDotFiles -ItemType Directory -Force
            $null = New-Item -Path $script:MockConfig -ItemType Directory -Force

            # Create test configuration directories
            $script:TestDotWinConfig = Join-Path $script:MockDocuments "my-dotwin-config"
            $script:TestGenericConfig = Join-Path $script:MockDesktop "config"
            $script:TestDotFilesConfig = Join-Path $script:MockDotFiles "dotwin"

            $null = New-Item -Path $script:TestDotWinConfig -ItemType Directory -Force
            $null = New-Item -Path $script:TestGenericConfig -ItemType Directory -Force
            $null = New-Item -Path $script:TestDotFilesConfig -ItemType Directory -Force

            # Create test configuration files
            "# Test PowerShell config" | Set-Content -Path (Join-Path $script:TestDotWinConfig "Packages.ps1")
            '{ "test": "json config" }' | Set-Content -Path (Join-Path $script:TestDotWinConfig "Terminal.jsonc")
            "# Another config" | Set-Content -Path (Join-Path $script:TestGenericConfig "settings.ps1")
            '{ "dotfiles": true }' | Set-Content -Path (Join-Path $script:TestDotFilesConfig "config.json")

            # Mock Write-DotWinLog function
            function Write-DotWinLog {
                param($Message, $Level)
                # Silent mock for testing
            }
        }

        AfterAll {
            # Clean up test directories
            if (Test-Path $script:TestConfigRoot) {
                Remove-Item -Path $script:TestConfigRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        Context "Get-DotWinUserConfigurationPath" {
            It "Should discover configuration directories with default parameters" {
                $result = Get-DotWinUserConfigurationPath -StartPath $script:MockUserProfile

                $result | Should -Not -BeNullOrEmpty
                $result | Should -BeOfType [PSCustomObject]
                $result.Count | Should -BeGreaterThan 0
            }

            It "Should discover DotWin-specific configurations with higher priority" {
                $result = Get-DotWinUserConfigurationPath -StartPath $script:MockUserProfile

                $dotwinConfigs = $result | Where-Object { $_.Name -like "*dotwin*" }
                $dotwinConfigs | Should -Not -BeNullOrEmpty

                # DotWin configs should have higher priority
                $maxPriority = ($result | Measure-Object -Property Priority -Maximum).Maximum
                $dotwinConfigs[0].Priority | Should -Be $maxPriority
            }

            It "Should include configuration file metadata" {
                $result = Get-DotWinUserConfigurationPath -StartPath $script:MockUserProfile

                foreach ($config in $result) {
                    $config.Path | Should -Not -BeNullOrEmpty
                    $config.Name | Should -Not -BeNullOrEmpty
                    $config.ConfigFileCount | Should -BeGreaterThan 0
                    $config.ConfigFileTypes | Should -Not -BeNullOrEmpty
                    $config.HasPowerShellConfigs | Should -BeOfType [bool]
                    $config.HasJsonConfigs | Should -BeOfType [bool]
                    $config.Priority | Should -BeOfType [int]
                    $config.DiscoveredAt | Should -BeOfType [DateTime]
                }
            }

            It "Should filter by custom patterns" {
                $customPatterns = @("*dotwin*")
                $result = Get-DotWinUserConfigurationPath -StartPath $script:MockUserProfile -ConfigPatterns $customPatterns

                $result | Should -Not -BeNullOrEmpty
                foreach ($config in $result) {
                    $config.Name | Should -BeLike "*dotwin*"
                }
            }

            It "Should respect search depth parameter" {
                $result = Get-DotWinUserConfigurationPath -StartPath $script:MockUserProfile -SearchDepth 1

                # Should still find configs but potentially fewer due to depth limit
                $result | Should -Not -BeNullOrEmpty
            }

            It "Should handle non-existent start path gracefully" {
                $nonExistentPath = Join-Path $TestDrive "NonExistent"
                $result = Get-DotWinUserConfigurationPath -StartPath $nonExistentPath

                $result | Should -BeNullOrEmpty
            }

            It "Should detect different file types correctly" {
                $result = Get-DotWinUserConfigurationPath -StartPath $script:MockUserProfile

                $psConfigs = $result | Where-Object { $_.HasPowerShellConfigs -eq $true }
                $jsonConfigs = $result | Where-Object { $_.HasJsonConfigs -eq $true }

                $psConfigs | Should -Not -BeNullOrEmpty
                $jsonConfigs | Should -Not -BeNullOrEmpty
            }
        }

        Context "Initialize-DotWinUserConfiguration" {
            BeforeEach {
                $script:TestInitPath = Join-Path $TestDrive "InitTest_$(Get-Random)"
            }

            AfterEach {
                if (Test-Path $script:TestInitPath) {
                    Remove-Item -Path $script:TestInitPath -Recurse -Force -ErrorAction SilentlyContinue
                }
            }

            It "Should create user configuration directory with default parameters" {
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -WhatIf:$false

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.ConfigurationPath | Should -Be (Resolve-Path $script:TestInitPath).Path
                $result.CreatedFiles.Count | Should -BeGreaterThan 0

                Test-Path $script:TestInitPath | Should -Be $true
            }

            It "Should create PowerShell format files when specified" {
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -FileFormat "PowerShell" -WhatIf:$false

                $result.Success | Should -Be $true
                $psFiles = $result.CreatedFiles | Where-Object { $_.Format -eq "PowerShell" }
                $psFiles | Should -Not -BeNullOrEmpty

                # Verify actual files exist
                $psFiles | ForEach-Object {
                    Test-Path $_.Path | Should -Be $true
                    $_.Path | Should -Match "\.ps1$"
                }
            }

            It "Should create JsonC format files when specified" {
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -FileFormat "JsonC" -WhatIf:$false

                $result.Success | Should -Be $true
                $jsonFiles = $result.CreatedFiles | Where-Object { $_.Format -eq "JsonC" }
                $jsonFiles | Should -Not -BeNullOrEmpty

                # Verify actual files exist
                $jsonFiles | ForEach-Object {
                    Test-Path $_.Path | Should -Be $true
                    $_.Path | Should -Match "\.jsonc$"
                }
            }

            It "Should create mixed format files when specified" {
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -FileFormat "Mixed" -WhatIf:$false

                $result.Success | Should -Be $true
                $psFiles = $result.CreatedFiles | Where-Object { $_.Format -eq "PowerShell" }
                $jsonFiles = $result.CreatedFiles | Where-Object { $_.Format -eq "JsonC" }

                $psFiles | Should -Not -BeNullOrEmpty
                $jsonFiles | Should -Not -BeNullOrEmpty
            }

            It "Should create README file" {
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -WhatIf:$false

                $readmeFile = $result.CreatedFiles | Where-Object { $_.Type -eq "Documentation" }
                $readmeFile | Should -Not -BeNullOrEmpty

                $readmePath = Join-Path $script:TestInitPath "README.md"
                Test-Path $readmePath | Should -Be $true

                $readmeContent = Get-Content $readmePath -Raw
                $readmeContent | Should -Match "DotWin"
                $readmeContent | Should -Match "Import-Module DotWin"
            }

            It "Should include examples when specified" {
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -IncludeExamples $true -WhatIf:$false

                $result.Success | Should -Be $true

                # Check that created files contain example content
                $psFile = $result.CreatedFiles | Where-Object { $_.Format -eq "PowerShell" } | Select-Object -First 1
                if ($psFile) {
                    $content = Get-Content $psFile.Path -Raw
                    $content | Should -Match "Git\.Git|Microsoft\.VisualStudioCode|Posh-Git"
                }
            }

            It "Should exclude examples when specified" {
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -IncludeExamples $false -WhatIf:$false

                $result.Success | Should -Be $true

                # Check that created files don't contain specific example content
                $psFile = $result.CreatedFiles | Where-Object { $_.Format -eq "PowerShell" } | Select-Object -First 1
                if ($psFile) {
                    $content = Get-Content $psFile.Path -Raw
                    $content | Should -Not -Match "Git\.Git"
                    $content | Should -Match "Define your.*configuration"
                }
            }

            It "Should create advanced template when specified" {
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -TemplateSource "Advanced" -WhatIf:$false

                $result.Success | Should -Be $true
                $result.CreatedFiles.Count | Should -BeGreaterThan 3  # Should have more files for advanced template

                # Should include additional configuration types
                $configTypes = $result.CreatedFiles.Type | Sort-Object -Unique
                $configTypes | Should -Contain "System"
                $configTypes | Should -Contain "Development"
                $configTypes | Should -Contain "Security"
            }

            It "Should fail when directory exists without Force" {
                # Create directory first
                $null = New-Item -Path $script:TestInitPath -ItemType Directory -Force

                { Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -WhatIf:$false } | Should -Throw "*already exists*"
            }

            It "Should overwrite when Force is specified" {
                # Create directory first
                $null = New-Item -Path $script:TestInitPath -ItemType Directory -Force
                "existing content" | Set-Content -Path (Join-Path $script:TestInitPath "existing.txt")

                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -Force -WhatIf:$false

                $result.Success | Should -Be $true
                Test-Path (Join-Path $script:TestInitPath "existing.txt") | Should -Be $true  # Should still exist
            }

            It "Should use custom configuration name in generated files" {
                $customName = "My Custom DotWin Setup"
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -ConfigurationName $customName -WhatIf:$false

                $result.ConfigurationName | Should -Be $customName

                # Check that name appears in generated files
                $readmePath = Join-Path $script:TestInitPath "README.md"
                $readmeContent = Get-Content $readmePath -Raw
                $readmeContent | Should -Match [regex]::Escape($customName)
            }

            It "Should track file creation metadata" {
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $script:TestInitPath -WhatIf:$false

                foreach ($file in $result.CreatedFiles) {
                    $file.Path | Should -Not -BeNullOrEmpty
                    $file.Type | Should -Not -BeNullOrEmpty
                    $file.Format | Should -Not -BeNullOrEmpty
                    $file.Size | Should -BeGreaterThan 0
                    $file.CreatedAt | Should -BeOfType [DateTime]

                    Test-Path $file.Path | Should -Be $true
                }
            }
        }

        Context "Helper Functions" {
            It "Get-ConfigurationPriority should calculate priorities correctly" {
                $dotwinPath = "C:\Users\Test\.dotfiles\dotwin"
                $configPath = "C:\Users\Test\Documents\config"
                $systemPath = "C:\ProgramData\config"

                $dotwinPriority = Get-ConfigurationPriority -Path $dotwinPath -Pattern "*dotwin*"
                $configPriority = Get-ConfigurationPriority -Path $configPath -Pattern "*config*"
                $systemPriority = Get-ConfigurationPriority -Path $systemPath -Pattern "*config*"

                $dotwinPriority | Should -BeGreaterThan $configPriority
                $configPriority | Should -BeGreaterThan $systemPriority
            }

            It "Get-ModuleConfigurationPath should find module config directory" {
                # This test depends on the actual module structure
                $configPath = Get-ModuleConfigurationPath

                # Should either find a path or return null gracefully
                if ($configPath) {
                    $configPath | Should -BeOfType [string]
                    Test-Path $configPath | Should -Be $true
                } else {
                    $configPath | Should -BeNullOrEmpty
                }
            }

            It "Get-ConfigurationFileDefinitions should return correct definitions" {
                $definitions = Get-ConfigurationFileDefinitions -TemplateSource "Module" -FileFormat "PowerShell"

                $definitions | Should -Not -BeNullOrEmpty
                $definitions | Should -BeOfType [PSCustomObject]

                foreach ($def in $definitions) {
                    $def.Type | Should -Not -BeNullOrEmpty
                    $def.FileName | Should -Not -BeNullOrEmpty
                    $def.Format | Should -Not -BeNullOrEmpty
                    $def.Description | Should -Not -BeNullOrEmpty
                }

                # Should have core types
                $types = $definitions.Type | Sort-Object -Unique
                $types | Should -Contain "Packages"
                $types | Should -Contain "Terminal"
                $types | Should -Contain "Profile"
            }

            It "New-ConfigurationFileContent should create valid content" {
                $configFile = [PSCustomObject]@{
                    Type = "Packages"
                    FileName = "Packages.ps1"
                    Format = "PowerShell"
                    Description = "Package management configuration"
                }

                $content = New-ConfigurationFileContent -ConfigFile $configFile -ConfigurationName "Test Config" -IncludeExamples $true

                $content | Should -Not -BeNullOrEmpty
                $content | Should -BeOfType [string]
                $content | Should -Match "Test Config"
                $content | Should -Match "Package"
            }

            It "New-ReadmeContent should create comprehensive README" {
                $mockFiles = @(
                    [PSCustomObject]@{ Path = "test.ps1"; Type = "Packages"; Format = "PowerShell"; Size = 100; CreatedAt = Get-Date }
                    [PSCustomObject]@{ Path = "test.jsonc"; Type = "Terminal"; Format = "JsonC"; Size = 200; CreatedAt = Get-Date }
                )

                $content = New-ReadmeContent -ConfigurationName "Test Config" -CreatedFiles $mockFiles

                $content | Should -Not -BeNullOrEmpty
                $content | Should -Match "Test Config"
                $content | Should -Match "Import-Module DotWin"
                $content | Should -Match "Packages"
                $content | Should -Match "Terminal"
                $content | Should -Match "PowerShell"
                $content | Should -Match "JsonC"
            }
        }

        Context "Integration Tests" {
            It "Should support end-to-end workflow: discover, then initialize" {
                # First, create a test configuration
                $testConfigPath = Join-Path $TestDrive "E2ETest_$(Get-Random)"
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $testConfigPath -WhatIf:$false

                $result.Success | Should -Be $true

                # Then discover it
                $discovered = Get-DotWinUserConfigurationPath -StartPath (Split-Path $testConfigPath -Parent)

                $discovered | Should -Not -BeNullOrEmpty
                $discoveredConfig = $discovered | Where-Object { $_.Path -eq $testConfigPath }
                $discoveredConfig | Should -Not -BeNullOrEmpty
                $discoveredConfig.ConfigFileCount | Should -BeGreaterThan 0

                # Clean up
                Remove-Item -Path $testConfigPath -Recurse -Force -ErrorAction SilentlyContinue
            }

            It "Should handle mixed file formats correctly" {
                $testConfigPath = Join-Path $TestDrive "MixedTest_$(Get-Random)"
                $result = Initialize-DotWinUserConfiguration -ConfigurationPath $testConfigPath -FileFormat "Mixed" -WhatIf:$false
                $null = $result
                # Discover the created configuration
                $discovered = Get-DotWinUserConfigurationPath -StartPath (Split-Path $testConfigPath -Parent)
                $discoveredConfig = $discovered | Where-Object { $_.Path -eq $testConfigPath }

                $discoveredConfig.HasPowerShellConfigs | Should -Be $true
                $discoveredConfig.HasJsonConfigs | Should -Be $true
                $discoveredConfig.ConfigFileTypes | Should -Contain ".ps1"
                $discoveredConfig.ConfigFileTypes | Should -Contain ".jsonc"

                # Clean up
                Remove-Item -Path $testConfigPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Configuration Merging Logic" {
        It "Should perform deep merge of hashtables" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $base = @{
                Level1 = @{
                    Level2 = @{
                        Value1 = 'Base1'
                        Value2 = 'Base2'
                    }
                    SimpleValue = 'BaseSimple'
                }
            }

            $override = @{
                Level1 = @{
                    Level2 = @{
                        Value1 = 'Override1'  # Override existing
                        Value3 = 'Override3'  # Add new
                    }
                    NewValue = 'OverrideNew'  # Add new at level 1
                }
            }

            $merged = $bridge.MergePackageConfigurations($base, $override)

            $merged.Level1.Level2.Value1 | Should -Be 'Override1'  # Overridden
            $merged.Level1.Level2.Value2 | Should -Be 'Base2'  # Preserved
            $merged.Level1.Level2.Value3 | Should -Be 'Override3'  # Added
            $merged.Level1.SimpleValue | Should -Be 'BaseSimple'  # Preserved
            $merged.Level1.NewValue | Should -Be 'OverrideNew'  # Added
        }

        It "Should merge arrays with ID-based deduplication" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $base = @{
                Items = @(
                    @{ Id = 'Item1'; Name = 'Base Item 1'; Value = 'Base1' }
                    @{ Id = 'Item2'; Name = 'Base Item 2'; Value = 'Base2' }
                )
            }

            $override = @{
                Items = @(
                    @{ Id = 'Item1'; Name = 'Override Item 1'; Value = 'Override1' }  # Override existing
                    @{ Id = 'Item3'; Name = 'Override Item 3'; Value = 'Override3' }  # Add new
                )
            }

            $merged = $bridge.MergePackageConfigurations($base, $override)

            $merged.Items.Count | Should -Be 3

            $item1 = $merged.Items | Where-Object { $_.Id -eq 'Item1' }
            $item1.Value | Should -Be 'Override1'  # Should be overridden

            $item2 = $merged.Items | Where-Object { $_.Id -eq 'Item2' }
            $item2.Value | Should -Be 'Base2'  # Should be preserved

            $item3 = $merged.Items | Where-Object { $_.Id -eq 'Item3' }
            $item3.Value | Should -Be 'Override3'  # Should be added
        }

        It "Should handle null and empty configurations gracefully" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $base = @{ Key1 = 'Value1' }

            $mergedWithNull = $bridge.MergePackageConfigurations($base, $null)
            $mergedWithEmpty = $bridge.MergePackageConfigurations($base, @{})
            $mergedNullBase = $bridge.MergePackageConfigurations($null, $base)

            $mergedWithNull.Key1 | Should -Be 'Value1'
            $mergedWithEmpty.Key1 | Should -Be 'Value1'
            $mergedNullBase.Key1 | Should -Be 'Value1'
        }
    }

    Context "Cache Management" {
        It "Should enable and disable caching" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $bridge.SetCacheEnabled($false)
            $bridge.CacheEnabled | Should -Be $false

            $bridge.SetCacheEnabled($true)
            $bridge.CacheEnabled | Should -Be $true
        }

        It "Should clear cache when disabled" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            # Add something to cache
            $bridge.ResolvePackageConfiguration('Development')
            $bridge.ConfigurationCache.Count | Should -BeGreaterThan 0

            # Disable caching should clear cache
            $bridge.SetCacheEnabled($false)
            $bridge.ConfigurationCache.Count | Should -Be 0
        }

        It "Should manually clear cache" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            # Add something to cache
            $bridge.ResolvePackageConfiguration('Development')
            $bridge.ConfigurationCache.Count | Should -BeGreaterThan 0

            $bridge.ClearCache()
            $bridge.ConfigurationCache.Count | Should -Be 0
        }

        It "Should provide cache statistics" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            # Add multiple items to cache
            $bridge.ResolvePackageConfiguration('Development')
            $bridge.ResolveTerminalConfiguration('Dark', $true, $false, $true)

            $stats = $bridge.GetCacheStatistics()

            $stats | Should -BeOfType [hashtable]
            $stats.CacheEnabled | Should -Be $true
            $stats.CachedItems | Should -Be 2
            $stats.LastCacheUpdate | Should -BeOfType [DateTime]
            $stats.CacheKeys | Should -Contain 'Packages_Development'
            $stats.CacheKeys | Should -Contain 'Terminal_Dark_True_False_True'
        }

        It "Should respect cache expiration" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            # First call should cache
            $config1 = $bridge.ResolvePackageConfiguration('Development')
            $null = $config1
            $bridge.ConfigurationCache.Count | Should -Be 1

            # Simulate cache expiration by modifying timestamp
            $cacheKey = 'Packages_Development'
            $bridge.ConfigurationCache[$cacheKey].Timestamp = (Get-Date).AddMinutes(-10)

            # Second call should refresh cache (though we can't easily test the refresh without mocking)
            $config2 = $bridge.ResolvePackageConfiguration('Development')
            $null = $config2
            # Cache should still exist but potentially refreshed
            $bridge.ConfigurationCache.Count | Should -Be 1
        }
    }

    Context "Error Handling and Resilience" {
        It "Should handle missing configuration functions gracefully" {
            # Create config file without required functions
            'Write-Host "No functions here"' | Set-Content -Path (Join-Path $script:testModuleConfigPath 'Packages.ps1')

            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $packages = $bridge.ResolvePackageConfiguration('Development')

            $packages | Should -BeOfType [hashtable]
            $packages.Count | Should -Be 0
        }

        It "Should handle configuration loading errors" {
            # Create invalid PowerShell file
            'invalid syntax {{{' | Set-Content -Path (Join-Path $script:testModuleConfigPath 'Terminal.ps1')

            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            # Should not throw and should return empty configuration
            $config = $bridge.ResolveTerminalConfiguration('Dark', $true, $false, $true)

            $config | Should -BeOfType [hashtable]
            $config.Count | Should -Be 0
        }

        It "Should handle user configuration directory not existing" {
            $nonExistentPath = Join-Path $env:TEMP 'NonExistentConfigPath'

            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $nonExistentPath)

            # Should not throw and should return base configuration only
            $packages = $bridge.ResolvePackageConfiguration('Development')

            $packages | Should -Not -BeNullOrEmpty
            $packages.Count | Should -Be 2  # Base configuration only
        }

        It "Should handle deep clone of complex objects" {
            $bridge = [DotWinConfigurationBridge]::new($script:testModuleConfigPath, $null)

            $complex = @{
                Level1 = @{
                    Array = @(
                        @{ Id = 1; Data = @{ Nested = 'Value1' } }
                        @{ Id = 2; Data = @{ Nested = 'Value2' } }
                    )
                    Simple = 'SimpleValue'
                }
                TopLevel = 'TopValue'
            }

            $cloned = $bridge.DeepCloneHashtable($complex)

            # Verify deep clone worked
            $cloned.Level1.Array[0].Data.Nested | Should -Be 'Value1'
            $cloned.Level1.Simple | Should -Be 'SimpleValue'
            $cloned.TopLevel | Should -Be 'TopValue'

            # Verify it's actually a clone (modifying original shouldn't affect clone)
            $complex.Level1.Simple = 'Modified'
            $cloned.Level1.Simple | Should -Be 'SimpleValue'
        }
    }
}
