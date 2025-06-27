<#
.SYNOPSIS
    Common test utility functions for DotWin unit tests.

.DESCRIPTION
    This file contains reusable helper functions that simplify test creation
    and provide common testing patterns for DotWin unit tests.
#>

# Import required modules
. $PSScriptRoot\TestConfig.ps1
. $PSScriptRoot\MockData.ps1

function New-MockDotWinSystemProfiler {
    <#
    .SYNOPSIS
        Creates a mock DotWinSystemProfiler object for testing.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$CustomHardware = @{},
        [hashtable]$CustomSoftware = @{},
        [hashtable]$CustomUser = @{},
        [hashtable]$CustomMetrics = @{}
    )
    
    try {
        $mockProfile = Get-MockSystemProfile

        # Create profiler instance with error handling
        $profiler = $null
        try {
            $profiler = [DotWinSystemProfiler]::new()
        } catch {
            # If class instantiation fails, create a mock object instead
            Write-Warning "Failed to create DotWinSystemProfiler, creating mock object: $($_.Exception.Message)"

            # Create a mock object that behaves like DotWinSystemProfiler
            $profiler = New-Object -TypeName PSObject
            $profiler | Add-Member -MemberType NoteProperty -Name 'Hardware' -Value (New-Object -TypeName PSObject)
            $profiler | Add-Member -MemberType NoteProperty -Name 'Software' -Value (New-Object -TypeName PSObject)
            $profiler | Add-Member -MemberType NoteProperty -Name 'User' -Value (New-Object -TypeName PSObject)
            $profiler | Add-Member -MemberType NoteProperty -Name 'SystemMetrics' -Value @{}
            $profiler | Add-Member -MemberType NoteProperty -Name 'LastProfiled' -Value (Get-Date)
            $profiler | Add-Member -MemberType NoteProperty -Name 'ProfileVersion' -Value '1.0.0'

            # Initialize Hardware mock
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'CPU_Manufacturer' -Value ''
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'CPU_Model' -Value ''
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'CPU_Cores' -Value 0
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'CPU_LogicalProcessors' -Value 0
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'TotalMemoryGB' -Value 0.0
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'Motherboard_Manufacturer' -Value ''
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'Motherboard_Model' -Value ''
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'GPU_Manufacturers' -Value @()
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'GPU_Models' -Value @()
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'Storage_Types' -Value @()
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'Storage_TotalGB' -Value 0.0
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'Network_Adapters' -Value @()
            $profiler.Hardware | Add-Member -MemberType NoteProperty -Name 'ProfiledAt' -Value (Get-Date)

            # Add Hardware methods
            $profiler.Hardware | Add-Member -MemberType ScriptMethod -Name 'GetHardwareCategory' -Value {
                if ($this.CPU_Cores -ge 8 -and $this.TotalMemoryGB -ge 16) {
                    if ($this.GPU_Manufacturers -contains "NVIDIA" -or $this.GPU_Manufacturers -contains "AMD") {
                        return "HighPerformance"
                    }
                    return "Workstation"
                } elseif ($this.CPU_Cores -ge 4 -and $this.TotalMemoryGB -ge 8) {
                    return "Mainstream"
                } else {
                    return "Budget"
                }
            }

            $profiler.Hardware | Add-Member -MemberType ScriptMethod -Name 'IsGamingOptimized' -Value {
                return ($this.GPU_Manufacturers -contains "NVIDIA" -or $this.GPU_Manufacturers -contains "AMD") -and $this.CPU_Cores -ge 4 -and $this.TotalMemoryGB -ge 8
            }

            $profiler.Hardware | Add-Member -MemberType ScriptMethod -Name 'SupportsVirtualization' -Value {
                return $this.CPU_Cores -ge 4 -and $this.TotalMemoryGB -ge 16
            }

            # Initialize Software mock
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'InstalledPackages' -Value @{}
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'PowerShellModules' -Value @{}
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'WindowsFeatures' -Value @{}
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'DevelopmentTools' -Value @()
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'ProductivityTools' -Value @()
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'MediaTools' -Value @()
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'GamingTools' -Value @()
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'SecurityTools' -Value @()
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'PackageManagers' -Value @{}
            $profiler.Software | Add-Member -MemberType NoteProperty -Name 'ProfiledAt' -Value (Get-Date)

            # Add Software methods
            $profiler.Software | Add-Member -MemberType ScriptMethod -Name 'GetUserType' -Value {
                $devScore = $this.DevelopmentTools.Count * 2
                $productivityScore = $this.ProductivityTools.Count
                $mediaScore = $this.MediaTools.Count
                $gamingScore = $this.GamingTools.Count

                $maxScore = [Math]::Max([Math]::Max($devScore, $productivityScore), [Math]::Max($mediaScore, $gamingScore))

                if ($maxScore -eq $devScore -and $devScore -gt 0) { return "Developer" }
                elseif ($maxScore -eq $gamingScore -and $gamingScore -gt 0) { return "Gamer" }
                elseif ($maxScore -eq $mediaScore -and $mediaScore -gt 0) { return "Creative" }
                elseif ($maxScore -eq $productivityScore -and $productivityScore -gt 0) { return "Business" }
                else { return "General" }
            }

            # Initialize User mock
            $profiler.User | Add-Member -MemberType NoteProperty -Name 'Username' -Value ''
            $profiler.User | Add-Member -MemberType NoteProperty -Name 'Domain' -Value ''
            $profiler.User | Add-Member -MemberType NoteProperty -Name 'IsAdministrator' -Value $false
            $profiler.User | Add-Member -MemberType NoteProperty -Name 'EnvironmentVariables' -Value @{}
            $profiler.User | Add-Member -MemberType NoteProperty -Name 'RecentApplications' -Value @()
            $profiler.User | Add-Member -MemberType NoteProperty -Name 'PreferredShell' -Value ''
            $profiler.User | Add-Member -MemberType NoteProperty -Name 'ProfiledAt' -Value (Get-Date)

            # Add User methods
            $profiler.User | Add-Member -MemberType ScriptMethod -Name 'GetTechnicalLevel' -Value {
                $advancedIndicators = 0

                if ($this.PreferredShell -eq "PowerShell Core") { $advancedIndicators++ }
                if ($this.EnvironmentVariables.ContainsKey("PATH") -and $this.EnvironmentVariables["PATH"] -like "*Git*") { $advancedIndicators++ }
                if ($this.RecentApplications -contains "Visual Studio Code" -or $this.RecentApplications -contains "Visual Studio") { $advancedIndicators++ }

                if ($advancedIndicators -ge 2) { return "Advanced" }
                elseif ($advancedIndicators -eq 1) { return "Intermediate" }
                else { return "Beginner" }
            }
        }

        # Set hardware profile with safe property access
        if ($profiler.Hardware) {
            $profiler.Hardware.CPU_Manufacturer = if ($CustomHardware.CPU_Manufacturer) { $CustomHardware.CPU_Manufacturer } else { $mockProfile.Hardware.CPU_Manufacturer }
            $profiler.Hardware.CPU_Model = if ($CustomHardware.CPU_Model) { $CustomHardware.CPU_Model } else { $mockProfile.Hardware.CPU_Model }
            $profiler.Hardware.CPU_Cores = if ($CustomHardware.CPU_Cores) { $CustomHardware.CPU_Cores } else { $mockProfile.Hardware.CPU_Cores }
            $profiler.Hardware.CPU_LogicalProcessors = if ($CustomHardware.CPU_LogicalProcessors) { $CustomHardware.CPU_LogicalProcessors } else { $mockProfile.Hardware.CPU_LogicalProcessors }
            $profiler.Hardware.TotalMemoryGB = if ($CustomHardware.TotalMemoryGB) { $CustomHardware.TotalMemoryGB } else { $mockProfile.Hardware.TotalMemoryGB }
            $profiler.Hardware.Motherboard_Manufacturer = if ($CustomHardware.Motherboard_Manufacturer) { $CustomHardware.Motherboard_Manufacturer } else { $mockProfile.Hardware.Motherboard_Manufacturer }
            $profiler.Hardware.Motherboard_Model = if ($CustomHardware.Motherboard_Model) { $CustomHardware.Motherboard_Model } else { $mockProfile.Hardware.Motherboard_Model }
            $profiler.Hardware.GPU_Manufacturers = if ($CustomHardware.GPU_Manufacturers) { $CustomHardware.GPU_Manufacturers } else { $mockProfile.Hardware.GPU_Manufacturers }
            $profiler.Hardware.GPU_Models = if ($CustomHardware.GPU_Models) { $CustomHardware.GPU_Models } else { $mockProfile.Hardware.GPU_Models }
            $profiler.Hardware.Storage_Types = if ($CustomHardware.Storage_Types) { $CustomHardware.Storage_Types } else { $mockProfile.Hardware.Storage_Types }
            $profiler.Hardware.Storage_TotalGB = if ($CustomHardware.Storage_TotalGB) { $CustomHardware.Storage_TotalGB } else { $mockProfile.Hardware.Storage_TotalGB }
            $profiler.Hardware.Network_Adapters = if ($CustomHardware.Network_Adapters) { $CustomHardware.Network_Adapters } else { $mockProfile.Hardware.Network_Adapters }
            $profiler.Hardware.ProfiledAt = Get-Date
        }

        # Set software profile with safe property access
        if ($profiler.Software) {
            $profiler.Software.InstalledPackages = if ($CustomSoftware.InstalledPackages) { $CustomSoftware.InstalledPackages } else { $mockProfile.Software.InstalledPackages }
            $profiler.Software.PowerShellModules = if ($CustomSoftware.PowerShellModules) { $CustomSoftware.PowerShellModules } else { $mockProfile.Software.PowerShellModules }
            $profiler.Software.WindowsFeatures = if ($CustomSoftware.WindowsFeatures) { $CustomSoftware.WindowsFeatures } else { $mockProfile.Software.WindowsFeatures }
            $profiler.Software.DevelopmentTools = if ($CustomSoftware.DevelopmentTools) { $CustomSoftware.DevelopmentTools } else { $mockProfile.Software.DevelopmentTools }
            $profiler.Software.ProductivityTools = if ($CustomSoftware.ProductivityTools) { $CustomSoftware.ProductivityTools } else { $mockProfile.Software.ProductivityTools }
            $profiler.Software.MediaTools = if ($CustomSoftware.MediaTools) { $CustomSoftware.MediaTools } else { $mockProfile.Software.MediaTools }
            $profiler.Software.GamingTools = if ($CustomSoftware.GamingTools) { $CustomSoftware.GamingTools } else { $mockProfile.Software.GamingTools }
            $profiler.Software.SecurityTools = if ($CustomSoftware.SecurityTools) { $CustomSoftware.SecurityTools } else { $mockProfile.Software.SecurityTools }
            $profiler.Software.PackageManagers = if ($CustomSoftware.PackageManagers) { $CustomSoftware.PackageManagers } else { $mockProfile.Software.PackageManagers }
            $profiler.Software.ProfiledAt = Get-Date
        }

        # Set user profile with safe property access
        if ($profiler.User) {
            $profiler.User.Username = if ($CustomUser.Username) { $CustomUser.Username } else { $mockProfile.User.Username }
            $profiler.User.Domain = if ($CustomUser.Domain) { $CustomUser.Domain } else { $mockProfile.User.Domain }
            $profiler.User.IsAdministrator = if ($CustomUser.ContainsKey('IsAdministrator')) { $CustomUser.IsAdministrator } else { $mockProfile.User.IsAdministrator }
            $profiler.User.EnvironmentVariables = if ($CustomUser.EnvironmentVariables) { $CustomUser.EnvironmentVariables } else { $mockProfile.User.EnvironmentVariables }
            $profiler.User.RecentApplications = if ($CustomUser.RecentApplications) { $CustomUser.RecentApplications } else { $mockProfile.User.RecentApplications }
            $profiler.User.PreferredShell = if ($CustomUser.PreferredShell) { $CustomUser.PreferredShell } else { $mockProfile.User.PreferredShell }
            $profiler.User.ProfiledAt = Get-Date
        }

        # Set system metrics
        $profiler.SystemMetrics = if ($CustomMetrics.Count -gt 0) { $CustomMetrics } else { $mockProfile.SystemMetrics }
        $profiler.LastProfiled = Get-Date

        return $profiler
    } catch {
        Write-Error "Failed to create mock DotWinSystemProfiler: $($_.Exception.Message)"
        throw
    }
}

function New-MockDotWinConfiguration {
    <#
    .SYNOPSIS
        Creates a mock DotWinConfiguration object for testing.
    #>
    [CmdletBinding()]
    param(
        [string]$Name = 'TestConfiguration',
        [object[]]$Items = @()
    )
    
    try {
        $config = $null
        try {
            $config = [DotWinConfiguration]::new($Name)
        } catch {
            # If class instantiation fails, create a mock object
            Write-Warning "Failed to create DotWinConfiguration, creating mock object: $($_.Exception.Message)"

            # Create a mock configuration object
            $config = New-Object -TypeName PSObject
            $config | Add-Member -MemberType NoteProperty -Name 'Name' -Value $Name
            $config | Add-Member -MemberType NoteProperty -Name 'Version' -Value '1.0.0'
            $config | Add-Member -MemberType NoteProperty -Name 'Description' -Value 'Test Configuration'
            $config | Add-Member -MemberType NoteProperty -Name 'Items' -Value @()
            $config | Add-Member -MemberType NoteProperty -Name 'Metadata' -Value @{}
            $config | Add-Member -MemberType NoteProperty -Name 'Created' -Value (Get-Date)
            $config | Add-Member -MemberType NoteProperty -Name 'LastModified' -Value (Get-Date)

            # Add methods
            $config | Add-Member -MemberType ScriptMethod -Name 'AddItem' -Value {
                param($Item)
                $this.Items += $Item
                $this.LastModified = Get-Date
            }

            $config | Add-Member -MemberType ScriptMethod -Name 'RemoveItem' -Value {
                param([string]$Name)
                $item = $this.Items | Where-Object { $_.Name -eq $Name }
                if ($item) {
                    $this.Items = $this.Items | Where-Object { $_.Name -ne $Name }
                    $this.LastModified = Get-Date
                    return $true
                }
                return $false
            }

            $config | Add-Member -MemberType ScriptMethod -Name 'GetItem' -Value {
                param([string]$Name)
                return $this.Items | Where-Object { $_.Name -eq $Name }
            }
        }

        foreach ($item in $Items) {
            $config.AddItem($item)
        }

        return $config
    } catch {
        Write-Error "Failed to create mock DotWinConfiguration: $($_.Exception.Message)"
        throw
    }
}

function New-MockWingetPackage {
    <#
    .SYNOPSIS
        Creates a mock DotWinWingetPackage for testing.
    #>
    [CmdletBinding()]
    param(
        [string]$PackageId = 'Git.Git',
        [string]$Version = '2.40.0',
        [bool]$IsInstalled = $false
    )
    
    try {
        $package = [DotWinWingetPackage]::new($PackageId)
        $package.Version = $Version
        $package.AcceptLicense = $true
        $package.AcceptSourceAgreements = $true

        # Mock the Test method to return the desired installation status
        $package | Add-Member -MemberType ScriptMethod -Name 'Test' -Value {
            return $IsInstalled
        } -Force

        return $package
    } catch {
        # If class instantiation fails, create a mock object
        Write-Warning "Failed to create DotWinWingetPackage, creating mock object: $($_.Exception.Message)"

        $package = New-Object -TypeName PSObject
        $package | Add-Member -MemberType NoteProperty -Name 'Name' -Value $PackageId
        $package | Add-Member -MemberType NoteProperty -Name 'Type' -Value 'WingetPackage'
        $package | Add-Member -MemberType NoteProperty -Name 'PackageId' -Value $PackageId
        $package | Add-Member -MemberType NoteProperty -Name 'Version' -Value $Version
        $package | Add-Member -MemberType NoteProperty -Name 'Source' -Value 'winget'
        $package | Add-Member -MemberType NoteProperty -Name 'AcceptLicense' -Value $true
        $package | Add-Member -MemberType NoteProperty -Name 'AcceptSourceAgreements' -Value $true
        $package | Add-Member -MemberType NoteProperty -Name 'InstallOptions' -Value @{}
        $package | Add-Member -MemberType NoteProperty -Name 'Enabled' -Value $true
        $package | Add-Member -MemberType NoteProperty -Name 'LastModified' -Value (Get-Date)

        # Mock the Test method to return the desired installation status
        $testValue = $IsInstalled
        $package | Add-Member -MemberType ScriptMethod -Name 'Test' -Value {
            return $testValue
        }.GetNewClosure()

        # Mock the Apply method
        $package | Add-Member -MemberType ScriptMethod -Name 'Apply' -Value {
            Write-Verbose "Mock Apply called for package $($this.PackageId)"
            $this.LastModified = Get-Date
        }

        # Mock the GetCurrentState method
        $package | Add-Member -MemberType ScriptMethod -Name 'GetCurrentState' -Value {
            return @{
                PackageId = $this.PackageId
                IsInstalled = $this.Test()
                InstalledVersion = if ($this.Test()) { $this.Version } else { $null }
                AvailableVersion = $this.Version
                Source = $this.Source
                LastChecked = Get-Date
            }
        }

        return $package
    }
}

function New-MockPlugin {
    <#
    .SYNOPSIS
        Creates a mock DotWin plugin for testing.
    #>
    [CmdletBinding()]
    param(
        [string]$Name = 'TestPlugin',
        [string]$Version = '1.0.0',
        [string]$Category = 'Configuration'
    )
    
    $plugin = [DotWinPlugin]::new($Name, $Version)
    $plugin.Category = $Category
    $plugin.Author = 'Test Author'
    $plugin.Description = 'A test plugin for unit testing'
    
    # Mock the required methods
    $plugin | Add-Member -MemberType ScriptMethod -Name 'Initialize' -Value {
        return $true
    } -Force
    
    $plugin | Add-Member -MemberType ScriptMethod -Name 'Cleanup' -Value {
        # No cleanup needed for mock
    } -Force
    
    $plugin | Add-Member -MemberType ScriptMethod -Name 'GetCapabilities' -Value {
        return @{
            SupportedTypes = @('TestType')
            Features = @('TestFeature')
        }
    } -Force
    
    return $plugin
}

function Set-MockCimInstance {
    <#
    .SYNOPSIS
        Sets up mocks for Get-CimInstance cmdlet.
    #>
    [CmdletBinding()]
    param(
        [string]$ClassName,
        [object]$MockData
    )
    
    Mock Get-CimInstance {
        return $MockData
    } -ParameterFilter {
        ($args.Count -gt 0 -and $args[0] -eq $ClassName) -or
        ($PSBoundParameters.ContainsKey('ClassName') -and $PSBoundParameters.ClassName -eq $ClassName)
    }
}

function Set-MockWingetCommand {
    <#
    .SYNOPSIS
        Sets up mocks for winget command execution.
    #>
    [CmdletBinding()]
    param(
        [string]$Command = 'list',
        [string]$Output = '',
        [int]$ExitCode = 0
    )
    
    $mockPackageData = Get-MockPackageData -Manager 'Winget'
    
    # Ensure mock data is available
    if (-not $mockPackageData) {
        Write-Warning "Mock package data not available for Winget"
        $mockPackageData = @{
            ListOutput = "Git.Git    2.40.0    winget"
            ShowGitOutput = "Version: 2.40.0"
            VersionOutput = "v1.5.2011"
        }
    }

    switch ($Command) {
        'list' {
            $Output = $mockPackageData.ListOutput
        }
        'show' {
            $Output = $mockPackageData.ShowGitOutput
        }
        'install' {
            $Output = 'Successfully installed'
        }
        '--version' {
            $Output = $mockPackageData.VersionOutput
        }
    }
    
    # Mock the winget command execution with comprehensive coverage
    Mock Start-Process {
        return [PSCustomObject]@{
            ExitCode = $ExitCode
        }
    } -ParameterFilter { $FilePath -eq 'winget' }
    
    # Mock direct winget calls using & operator - handle all common patterns
    Mock -CommandName 'winget' -MockWith {
        param([string[]]$ArgumentList)
        $global:LASTEXITCODE = $ExitCode

        # Handle different argument patterns
        if ($ArgumentList -contains '--version') {
            return $mockPackageData.VersionOutput
        } elseif ($ArgumentList -contains 'list') {
            return $mockPackageData.ListOutput -split "`n"
        } elseif ($ArgumentList -contains 'show') {
            return $mockPackageData.ShowGitOutput -split "`n"
        } else {
            return $Output -split "`n"
        }
    }

    # Mock Invoke-Expression for winget calls
    Mock Invoke-Expression {
        param([string]$Command)
        $global:LASTEXITCODE = $ExitCode

        if ($Command -like '*--version*') {
            return $mockPackageData.VersionOutput
        } elseif ($Command -like '*list*') {
            return $mockPackageData.ListOutput -split "`n"
        } elseif ($Command -like '*show*') {
            return $mockPackageData.ShowGitOutput -split "`n"
        } else {
            return $Output -split "`n"
        }
    } -ParameterFilter { $Command -like '*winget*' }

    # Mock Get-Command to make winget appear available
    Mock Get-Command {
        return [PSCustomObject]@{
            Name = 'winget'
            CommandType = 'Application'
            Source = 'C:\Users\TestUser\AppData\Local\Microsoft\WindowsApps\winget.exe'
        }
    } -ParameterFilter { $Name -eq 'winget' }

    # Mock Test-Path for winget executable
    Mock Test-Path {
        return $true
    } -ParameterFilter { $Path -like '*winget*' }
}

function Set-MockRegistryAccess {
    <#
    .SYNOPSIS
        Sets up mocks for registry access.
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        [hashtable]$Data
    )
    
    Mock Get-ItemProperty {
        return [PSCustomObject]$Data
    } -ParameterFilter { $Path -eq $Path }
    
    Mock Test-Path {
        return $true
    } -ParameterFilter { $Path -eq $Path }
}

function Set-MockFileSystem {
    <#
    .SYNOPSIS
        Sets up mocks for file system operations.
    #>
    [CmdletBinding()]
    param(
        [hashtable]$Files = @{},
        [hashtable]$Directories = @{}
    )
    
    # Mock Test-Path for files
    foreach ($file in $Files.Keys) {
        Mock Test-Path {
            return $Files[$file].Exists
        } -ParameterFilter { $Path -eq $file }
    }
    
    # Mock Test-Path for directories
    foreach ($dir in $Directories.Keys) {
        Mock Test-Path {
            return $Directories[$dir]
        } -ParameterFilter { $Path -eq $dir }
    }
    
    # Mock Get-Content for configuration files
    Mock Get-Content {
        return '{"test": "data"}'
    } -ParameterFilter { $Path -like '*.json' }
}

function Set-MockWindowsFeatures {
    <#
    .SYNOPSIS
        Sets up mocks for Windows features.
    #>
    [CmdletBinding()]
    param()
    
    $mockFeatures = Get-MockWindowsFeatures
    
    Mock Get-WindowsOptionalFeature {
        return $mockFeatures
    }
}

function Set-MockPowerShellModules {
    <#
    .SYNOPSIS
        Sets up mocks for PowerShell modules.
    #>
    [CmdletBinding()]
    param()
    
    $mockModules = Get-MockPowerShellModules
    
    Mock Get-Module {
        return $mockModules
    } -ParameterFilter { $ListAvailable -eq $true }
}

function Assert-MockCalled {
    <#
    .SYNOPSIS
        Enhanced assertion for mock calls with better error messages.
    #>
    [CmdletBinding()]
    param(
        [string]$CommandName,
        [int]$Times = 1,
        [hashtable]$ParameterFilter = @{},
        [string]$Because = ''
    )
    
    $assertParams = @{
        CommandName = $CommandName
        Times = $Times
    }
    
    if ($ParameterFilter.Count -gt 0) {
        $assertParams.ParameterFilter = $ParameterFilter
    }
    
    try {
        Assert-MockCalled @assertParams
    } catch {
        $errorMessage = "Mock assertion failed for '$CommandName'"
        if ($Because) {
            $errorMessage += " because $Because"
        }
        $errorMessage += ". Expected $Times calls but got different number."
        throw $errorMessage
    }
}

function Measure-TestPerformance {
    <#
    .SYNOPSIS
        Measures test performance and validates against thresholds.
    #>
    [CmdletBinding()]
    param(
        [scriptblock]$ScriptBlock,
        [string]$TestName,
        [int]$MaxExecutionTimeSeconds = 30
    )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    try {
        $result = & $ScriptBlock
        return $result
    } finally {
        $stopwatch.Stop()
        $executionTime = $stopwatch.Elapsed.TotalSeconds
        
        Write-Verbose "Test '$TestName' executed in $executionTime seconds"
        
        if ($executionTime -gt $MaxExecutionTimeSeconds) {
            Write-Warning "Test '$TestName' exceeded performance threshold: ${executionTime}s > ${MaxExecutionTimeSeconds}s"
        }
    }
}

function New-TestDirectory {
    <#
    .SYNOPSIS
        Creates a temporary test directory.
    #>
    [CmdletBinding()]
    param(
        [string]$Name = 'TestDir'
    )
    
    $testConfig = Get-TestConfig
    $tempPath = Join-Path $testConfig.Environment.TempDirectory $Name
    
    if (-not (Test-Path $tempPath)) {
        New-Item -Path $tempPath -ItemType Directory -Force | Out-Null
    }
    
    return $tempPath
}

function Remove-TestDirectory {
    <#
    .SYNOPSIS
        Removes a test directory and all contents.
    #>
    [CmdletBinding()]
    param(
        [string]$Path
    )
    
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Test-DotWinClassAvailability {
    <#
    .SYNOPSIS
        Tests if DotWin classes are available in the current session.
    #>
    [CmdletBinding()]
    param()
    
    $requiredClasses = @(
        'DotWinConfiguration',
        'DotWinConfigurationItem',
        'DotWinSystemProfiler',
        'DotWinPlugin',
        'DotWinWingetPackage',
        'DotWinExecutionResult',
        'DotWinValidationResult'
    )
    
    $missingClasses = @()
    
    foreach ($className in $requiredClasses) {
        try {
            $type = $className -as [type]
            if (-not $type) {
                $missingClasses += $className
            }
        } catch {
            $missingClasses += $className
        }
    }
    
    if ($missingClasses.Count -gt 0) {
        throw "Required DotWin classes not available: $($missingClasses -join ', '). Ensure the DotWin module is properly imported."
    }
    
    return $true
}

function Import-DotWinModuleForTesting {
    <#
    .SYNOPSIS
        Imports the DotWin module for testing with proper error handling.
    #>
    [CmdletBinding()]
    param()
    
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    $moduleManifest = Join-Path $moduleRoot 'DotWin.psd1'
    $classesFile = Join-Path $moduleRoot 'Classes.ps1'
    
    if (-not (Test-Path $moduleManifest)) {
        throw "DotWin module manifest not found at: $moduleManifest"
    }
    
    if (-not (Test-Path $classesFile)) {
        throw "DotWin classes file not found at: $classesFile"
    }

    try {
        # Remove any existing module to ensure clean import
        if (Get-Module DotWin -ErrorAction SilentlyContinue) {
            Remove-Module DotWin -Force
        }

        # Load the classes file using multiple methods to ensure availability in all scopes
        Write-Verbose "Loading DotWin classes from: $classesFile"
        $classContent = Get-Content $classesFile -Raw

        # Method 1: Load in global scope using ExecutionContext
        $global:ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create($classContent), $null, $null)

        # Method 2: Load in current scope
        . $classesFile

        # Method 3: Load using Invoke-Expression in current scope
        Invoke-Expression $classContent

        # Method 4: Load using Add-Type equivalent for PowerShell classes
        $scriptBlock = [scriptblock]::Create($classContent)
        & $scriptBlock

        # Import the module with ScriptsToProcess which should load classes
        Write-Verbose "Importing DotWin module from: $moduleManifest"
        Import-Module $moduleManifest -Force -Global -ErrorAction Stop

        # Verify classes are available in current scope
        try {
            $testStatus = [DotWinSystemStatus]::new()
            $testProfiler = [DotWinSystemProfiler]::new()
            Write-Verbose "✓ Classes verified in current scope"
        } catch {
            Write-Warning "Classes not available in current scope, attempting additional loading..."

            # Additional attempt: Load classes in the caller's scope
            $callerScope = Get-Variable -Scope 1 -ErrorAction SilentlyContinue
            if ($callerScope) {
                Set-Variable -Name 'DotWinClassesLoaded' -Value $classContent -Scope 1
                Invoke-Expression -Command $classContent
            }
        }

        Write-Verbose "DotWin module imported successfully for testing"
    } catch {
        throw "Failed to import DotWin module for testing: $($_.Exception.Message)"
    }
}

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Initializes the test environment with common settings and variables.
    #>
    [CmdletBinding()]
    param()

    try {
        # Set common test variables
        $global:TestEnvironmentInitialized = $true

        # Verify classes are available
        Test-DotWinClassAvailability

        Write-Verbose "Test environment initialized successfully"
    } catch {
        Write-Warning "Failed to initialize test environment: $($_.Exception.Message)"
        throw
    }
}

function Clear-TestEnvironment {
    <#
    .SYNOPSIS
        Cleans up the test environment.
    #>
    [CmdletBinding()]
    param()

    try {
        # Remove test variables
        if (Get-Variable -Name 'TestEnvironmentInitialized' -Scope Global -ErrorAction SilentlyContinue) {
            Remove-Variable -Name 'TestEnvironmentInitialized' -Scope Global -Force
        }

        # Remove any test modules
        if (Get-Module -Name 'DotWinTestClasses' -ErrorAction SilentlyContinue) {
            Remove-Module -Name 'DotWinTestClasses' -Force
        }

        Write-Verbose "Test environment cleaned up successfully"
    } catch {
        Write-Warning "Failed to clean up test environment: $($_.Exception.Message)"
    }
}

function Get-MockRecommendations {
    <#
    .SYNOPSIS
        Creates mock recommendations for testing.
    #>
    [CmdletBinding()]
    param()

    try {
        $recommendation = [DotWinRecommendation]::new()
        $recommendation.Title = "Test Recommendation"
        $recommendation.Description = "A test recommendation"
        $recommendation.Category = "Software"
        $recommendation.Priority = "High"
        return @($recommendation)
    } catch {
        # If class instantiation fails, create a mock object
        $recommendation = New-Object -TypeName PSObject
        $recommendation | Add-Member -MemberType NoteProperty -Name 'Title' -Value "Test Recommendation"
        $recommendation | Add-Member -MemberType NoteProperty -Name 'Description' -Value "A test recommendation"
        $recommendation | Add-Member -MemberType NoteProperty -Name 'Category' -Value "Software"
        $recommendation | Add-Member -MemberType NoteProperty -Name 'Priority' -Value "High"
        $recommendation | Add-Member -MemberType NoteProperty -Name 'ConfidenceScore' -Value 0.9
        $recommendation | Add-Member -MemberType NoteProperty -Name 'Implementation' -Value @{ Type = "Package" }
        $recommendation | Add-Member -MemberType NoteProperty -Name 'Prerequisites' -Value @()
        $recommendation | Add-Member -MemberType NoteProperty -Name 'Metadata' -Value @{}
        return @($recommendation)
    }
}

# Functions are available when dot-sourced - no need to export
# Export-ModuleMember is only used when this file is imported as a module
