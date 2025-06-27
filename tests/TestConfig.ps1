<#
.SYNOPSIS
    Shared test configuration and settings for DotWin unit tests.

.DESCRIPTION
    This file contains common configuration, constants, and settings used across
    all DotWin unit tests. It provides a centralized location for test parameters
    and shared test infrastructure.
#>

# Test Configuration Constants
$script:TestConfig = @{
    # Test execution settings
    TestTimeout = 30  # seconds
    ParallelTestLimit = 4
    MockDataCacheEnabled = $true
    
    # Test categories
    Categories = @{
        Unit = 'Unit'
        Integration = 'Integration'
        Performance = 'Performance'
        Smoke = 'Smoke'
    }
    
    # Mock data settings
    MockData = @{
        SampleSystemProfile = @{
            CPU_Manufacturer = 'Intel'
            CPU_Model = 'Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz'
            CPU_Cores = 8
            CPU_LogicalProcessors = 16
            TotalMemoryGB = 32.0
            Motherboard_Manufacturer = 'ASUS'
            Motherboard_Model = 'PRIME Z490-A'
            GPU_Manufacturers = @('NVIDIA')
            GPU_Models = @('NVIDIA GeForce RTX 3080')
            Storage_Types = @('SSD')
            Storage_TotalGB = 1000.0
        }
        
        SamplePackages = @(
            @{ Id = 'Git.Git'; Version = '2.40.0'; Source = 'winget' },
            @{ Id = 'Microsoft.VisualStudioCode'; Version = '1.80.0'; Source = 'winget' },
            @{ Id = 'Microsoft.WindowsTerminal'; Version = '1.17.0'; Source = 'winget' }
        )
        
        SampleWingetOutput = @{
            List = @"
Name                           Id                           Version      Available Source
-------------------------------------------------------------------------------------------
Git                            Git.Git                      2.40.0       2.41.0    winget
Microsoft Visual Studio Code  Microsoft.VisualStudioCode  1.80.0       1.81.0    winget
Windows Terminal               Microsoft.WindowsTerminal   1.17.0       1.18.0    winget
"@
            Show = @"
Found Git [Git.Git]
Version: 2.40.0
Publisher: The Git Development Community
Description: Git is a free and open source distributed version control system
"@
        }
    }
    
    # Test environment settings
    Environment = @{
        RequiredPowerShellVersion = '5.1'
        SupportedOperatingSystems = @('Windows 10', 'Windows 11', 'Windows Server 2019', 'Windows Server 2022')
        TestDataDirectory = Join-Path $PSScriptRoot 'TestData'
        TempDirectory = Join-Path $env:TEMP 'DotWinTests'
    }
    
    # Performance test thresholds
    Performance = @{
        MaxExecutionTimeSeconds = @{
            'Get-DotWinSystemProfile' = 30
            'Get-DotWinRecommendations' = 15
            'Install-Packages' = 60
            'Test-DotWinConfiguration' = 10
        }
        MaxMemoryUsageMB = 500
    }
    
    # Coverage requirements
    Coverage = @{
        MinimumCodeCoverage = 90
        MinimumFunctionCoverage = 95
        CriticalFunctions = @(
            'Get-DotWinSystemProfile',
            'Get-DotWinRecommendations',
            'Invoke-DotWinConfiguration',
            'Test-DotWinConfiguration'
        )
    }
}

# Test helper functions
function Get-TestConfig {
    <#
    .SYNOPSIS
        Gets the test configuration object.
    #>
    return $script:TestConfig
}

function Get-MockDataPath {
    <#
    .SYNOPSIS
        Gets the path to mock data files.
    #>
    param([string]$FileName)
    
    $mockDataPath = Join-Path $PSScriptRoot 'MockData'
    if ($FileName) {
        return Join-Path $mockDataPath $FileName
    }
    return $mockDataPath
}

function Initialize-TestEnvironment {
    <#
    .SYNOPSIS
        Initializes the test environment for DotWin tests.
    #>
    [CmdletBinding()]
    param()
    
    # Create test directories
    $testDataDir = $script:TestConfig.Environment.TestDataDirectory
    $tempDir = $script:TestConfig.Environment.TempDirectory
    
    if (-not (Test-Path $testDataDir)) {
        New-Item -Path $testDataDir -ItemType Directory -Force | Out-Null
    }
    
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    }
    
    # Set test-specific environment variables
    $env:DOTWIN_TEST_MODE = 'true'
    $env:DOTWIN_TEST_DATA_PATH = $testDataDir
    $env:DOTWIN_TEST_TEMP_PATH = $tempDir
    
    Write-Verbose "Test environment initialized"
    Write-Verbose "Test data directory: $testDataDir"
    Write-Verbose "Temp directory: $tempDir"
}

function Clear-TestEnvironment {
    <#
    .SYNOPSIS
        Cleans up the test environment after tests complete.
    #>
    [CmdletBinding()]
    param()
    
    # Clean up temporary files
    $tempDir = $script:TestConfig.Environment.TempDirectory
    if (Test-Path $tempDir) {
        try {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Warning "Could not clean up temp directory: $tempDir"
        }
    }
    
    # Remove test environment variables
    Remove-Item -Path 'env:DOTWIN_TEST_MODE' -ErrorAction SilentlyContinue
    Remove-Item -Path 'env:DOTWIN_TEST_DATA_PATH' -ErrorAction SilentlyContinue
    Remove-Item -Path 'env:DOTWIN_TEST_TEMP_PATH' -ErrorAction SilentlyContinue
    
    Write-Verbose "Test environment cleaned up"
}

function Assert-TestPrerequisites {
    <#
    .SYNOPSIS
        Validates that test prerequisites are met.
    #>
    [CmdletBinding()]
    param()
    
    $issues = @()
    
    # Check PowerShell version
    $requiredVersion = [Version]$script:TestConfig.Environment.RequiredPowerShellVersion
    if ($PSVersionTable.PSVersion -lt $requiredVersion) {
        $issues += "PowerShell version $requiredVersion or higher is required"
    }
    
    # Check if running on Windows
    if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)) {
        $issues += "Tests must be run on Windows"
    }
    
    # Check for Pester module
    $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pesterModule) {
        $issues += "Pester module is required for testing"
    } elseif ($pesterModule.Version -lt [Version]'5.0.0') {
        $issues += "Pester 5.0 or higher is required"
    }
    
    if ($issues.Count -gt 0) {
        throw "Test prerequisites not met: $($issues -join '; ')"
    }
    
    Write-Verbose "All test prerequisites are met"
}

# Functions are available when dot-sourced - no need to export
# Export-ModuleMember is only used when this file is imported as a module
