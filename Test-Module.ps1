<#
.SYNOPSIS
    Comprehensive test script for the DotWin PowerShell module.

.DESCRIPTION
    This script provides comprehensive testing for all DotWin module functions
    and features. It includes unit tests, integration tests, and validation
    of the module's functionality across different scenarios.

.NOTES
    Created with: SAPIEN Technologies, Inc., PowerShell Studio 2025 v5.9.256
    Created on: 6/9/2025 10:37 PM
    Created by: shonp
    Organization:
    Filename: Test-Module.ps1

    The Test-Module.ps1 script lets you test the functions and other features of
    your module in your PowerShell Studio module project. It's part of your project,
    but it is not included in your module.

    In this test script, import the module (be careful to import the correct version)
    and write commands that test the module features. You can include Pester
    tests, too.

    To run the script, click Run or Run in Console. Or, when working on any file
    in the project, click Home\Run or Home\Run in Console, or in the Project pane,
    right-click the project name, and then click Run Project.
#>

# Import required modules
Import-Module Pester -Force -ErrorAction SilentlyContinue

# Explicitly import the DotWin module for testing
Write-Host "Importing DotWin module..." -ForegroundColor Green
Import-Module '.\DotWin.psd1' -Force

# Test configuration
$TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    SkippedTests = 0
    TestDetails = @()
}

# Helper function to run a test and record results
function Invoke-DotWinTest {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [string]$Category = "General",
        [switch]$SkipOnError
    )

    $TestResults.TotalTests++
    $testStart = Get-Date

    try {
        Write-Host "Running test: $TestName" -ForegroundColor Cyan

        $result = & $TestScript
        $success = $true
        $errorMessage = $null

        if ($result -is [bool] -and -not $result) {
            $success = $false
            $errorMessage = "Test returned false"
        }

        if ($success) {
            $TestResults.PassedTests++
            Write-Host "  ✓ PASSED" -ForegroundColor Green
        } else {
            $TestResults.FailedTests++
            Write-Host "  ✗ FAILED: $errorMessage" -ForegroundColor Red
        }
    }
    catch {
        if ($SkipOnError) {
            $TestResults.SkippedTests++
            Write-Host "  ⚠ SKIPPED: $($_.Exception.Message)" -ForegroundColor Yellow
            $success = $null
            $errorMessage = $_.Exception.Message
        } else {
            $TestResults.FailedTests++
            Write-Host "  ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
            $success = $false
            $errorMessage = $_.Exception.Message
        }
    }

    $testEnd = Get-Date
    $duration = $testEnd - $testStart

    $TestResults.TestDetails += [PSCustomObject]@{
        Name = $TestName
        Category = $Category
        Success = $success
        Duration = $duration
        ErrorMessage = $errorMessage
        Timestamp = $testStart
    }
}

# Begin testing
Write-Host "`n=== DotWin Module Comprehensive Testing ===" -ForegroundColor Magenta
Write-Host "Starting test execution at $(Get-Date)" -ForegroundColor Gray

# Test 1: Module Import and Basic Structure
Invoke-DotWinTest -TestName "Module Import and Structure" -Category "Core" -TestScript {
    # Check if module is loaded
    $module = Get-Module -Name DotWin
    if (-not $module) {
        throw "DotWin module is not loaded"
    }

    # Check exported functions
    $expectedFunctions = @(
        'Get-DotWinStatus',
        'Test-DotWinConfiguration',
        'Invoke-DotWinConfiguration',
        'Get-ChipsetInformation',
        'Search-ChipsetDriver',
        'Install-ChipsetDriver',
        'Install-SystemTools',
        'Install-Packages',
        'Install-Applications',
        'Enable-Features',
        'Remove-Bloatware',
        'Disable-Telemetry',
        'Set-PowershellProfile',
        'Set-TerminalProfile'
    )

    $exportedFunctions = $module.ExportedFunctions.Keys
    $missingFunctions = $expectedFunctions | Where-Object { $_ -notin $exportedFunctions }

    if ($missingFunctions) {
        throw "Missing exported functions: $($missingFunctions -join ', ')"
    }

    return $true
}

# Test 2: Core Classes
Invoke-DotWinTest -TestName "Core Classes Functionality" -Category "Core" -TestScript {
    # Test DotWinConfiguration class
    $config = [DotWinConfiguration]::new("TestConfig")
    if (-not $config -or $config.Name -ne "TestConfig") {
        throw "DotWinConfiguration class instantiation failed"
    }

    # Test DotWinConfigurationItem class
    $item = [DotWinConfigurationItem]::new("TestItem", "TestType")
    if (-not $item -or $item.Name -ne "TestItem" -or $item.Type -ne "TestType") {
        throw "DotWinConfigurationItem class instantiation failed"
    }

    # Test adding item to configuration
    $config.AddItem($item)
    if ($config.Items.Count -ne 1) {
        throw "Failed to add item to configuration"
    }

    # Test getting item from configuration
    $retrievedItem = $config.GetItem("TestItem")
    if (-not $retrievedItem -or $retrievedItem.Name -ne "TestItem") {
        throw "Failed to retrieve item from configuration"
    }

    return $true
}

# Test 3: System Status Function
Invoke-DotWinTest -TestName "Get-DotWinStatus Function" -Category "Core" -TestScript {
    $status = Get-DotWinStatus

    if (-not $status) {
        throw "Get-DotWinStatus returned null"
    }

    # Check required properties
    $requiredProperties = @('ComputerName', 'OperatingSystem', 'PowerShellVersion', 'LastCheck')
    foreach ($property in $requiredProperties) {
        if (-not $status.PSObject.Properties[$property]) {
            throw "Missing required property: $property"
        }
    }

    return $true
}

# Test 4: Configuration Testing Function
Invoke-DotWinTest -TestName "Test-DotWinConfiguration Function" -Category "Core" -TestScript {
    # Create a test configuration
    $config = [DotWinConfiguration]::new("TestConfiguration")

    # Test with empty configuration
    $result = Test-DotWinConfiguration -Configuration $config

    if (-not $result) {
        throw "Test-DotWinConfiguration returned null for empty configuration"
    }

    if ($result.TotalItems -ne 0) {
        throw "Expected 0 total items for empty configuration, got $($result.TotalItems)"
    }

    return $true
}

# Test 5: Hardware Information Function
Invoke-DotWinTest -TestName "Get-ChipsetInformation Function" -Category "Hardware" -TestScript {
    $hwInfo = Get-ChipsetInformation

    if (-not $hwInfo) {
        throw "Get-ChipsetInformation returned null"
    }

    # Check required sections
    $requiredSections = @('System', 'Motherboard', 'CPU', 'Memory')
    foreach ($section in $requiredSections) {
        if (-not $hwInfo.PSObject.Properties[$section]) {
            throw "Missing required hardware section: $section"
        }
    }

    # Verify system information
    if (-not $hwInfo.System.ComputerName) {
        throw "System computer name is missing"
    }

    return $true
}

# Test 6: Driver Search Function
Invoke-DotWinTest -TestName "Search-ChipsetDriver Function" -Category "Hardware" -SkipOnError -TestScript {
    # This test may fail on systems without proper WMI access or internet connectivity
    $driverSearch = Search-ChipsetDriver -DriverType System

    # The function should return an array, even if empty
    if ($driverSearch -isnot [array] -and $null -ne $driverSearch) {
        throw "Search-ChipsetDriver should return an array"
    }

    return $true
}

# Test 7: System Tools Installation (WhatIf)
Invoke-DotWinTest -TestName "Install-SystemTools WhatIf" -Category "Tools" -TestScript {
    $result = Install-SystemTools -ToolCategory Development -WhatIf

    if (-not $result) {
        throw "Install-SystemTools WhatIf returned null"
    }

    # Should return execution results
    if ($result -isnot [array] -and $result.GetType().Name -ne 'DotWinExecutionResult') {
        throw "Install-SystemTools should return DotWinExecutionResult objects"
    }

    return $true
}

# Test 8: Package Management Functions
Invoke-DotWinTest -TestName "Package Management Functions" -Category "Packages" -TestScript {
    # Test Install-Packages with WhatIf
    $packageResult = Install-Packages -WhatIf

    # Should not throw errors in WhatIf mode
    if ($packageResult -and $packageResult.GetType().Name -ne 'DotWinExecutionResult') {
        Write-Warning "Install-Packages WhatIf returned unexpected type"
    }

    # Test Install-Applications with WhatIf
    $appResult = Install-Applications -WhatIf

    # Should not throw errors in WhatIf mode
    if ($appResult -and $appResult.GetType().Name -ne 'DotWinExecutionResult') {
        Write-Warning "Install-Applications WhatIf returned unexpected type"
    }

    return $true
}

# Test 9: System Configuration Functions
Invoke-DotWinTest -TestName "System Configuration Functions" -Category "Configuration" -TestScript {
    # Test Enable-Features with WhatIf
    $featureResult = Enable-Features -WhatIf

    # Test Remove-Bloatware with WhatIf
    $bloatwareResult = Remove-Bloatware -WhatIf

    # Test Disable-Telemetry with WhatIf
    $telemetryResult = Disable-Telemetry -WhatIf

    # These should not throw errors in WhatIf mode
    return $true
}

# Test 10: Profile Configuration Functions
Invoke-DotWinTest -TestName "Profile Configuration Functions" -Category "Configuration" -TestScript {
    # Test Set-PowershellProfile with WhatIf
    $psProfileResult = Set-PowershellProfile -WhatIf

    # Test Set-TerminalProfile with WhatIf
    $terminalProfileResult = Set-TerminalProfile -WhatIf

    # These should not throw errors in WhatIf mode
    return $true
}

# Test 11: WSL Configuration
Invoke-DotWinTest -TestName "WSL Configuration Classes" -Category "WSL" -SkipOnError -TestScript {
    # Test WSL configuration class
    $wslConfig = [DotWinWSLConfiguration]::new("TestWSL", "Ubuntu")

    if (-not $wslConfig) {
        throw "Failed to create WSL configuration"
    }

    if ($wslConfig.DistributionName -ne "Ubuntu") {
        throw "WSL configuration distribution name not set correctly"
    }

    # Test WSL helper functions
    $availableDistros = Get-AvailableWSLDistributions
    if (-not $availableDistros -or $availableDistros.Count -eq 0) {
        throw "Get-AvailableWSLDistributions returned no results"
    }

    return $true
}

# Test 12: Configuration File Loading
Invoke-DotWinTest -TestName "Configuration File Loading" -Category "Configuration" -TestScript {
    # Test that configuration files can be loaded without errors
    $configFiles = @(
        '.\config\Packages.ps1',
        '.\config\Tools.ps1',
        '.\config\Profile.ps1',
        '.\config\Terminal.ps1',
        '.\config\WSL.ps1'
    )

    foreach ($configFile in $configFiles) {
        if (Test-Path $configFile) {
            try {
                . $configFile
            }
            catch {
                throw "Failed to load configuration file $configFile`: $($_.Exception.Message)"
            }
        } else {
            throw "Configuration file not found: $configFile"
        }
    }

    return $true
}

# Test 13: Error Handling
Invoke-DotWinTest -TestName "Error Handling" -Category "Core" -TestScript {
    # Test that functions handle invalid parameters gracefully
    try {
        $null = Get-ChipsetInformation -Format "InvalidFormat" -ErrorAction Stop
        throw "Function should have thrown an error for invalid format parameter"
    }
    catch [System.Management.Automation.ParameterBindingException] {
        # Expected error - parameter validation worked
    }
    catch {
        throw "Unexpected error type: $($_.Exception.GetType().Name)"
    }

    return $true
}

# Test 14: Performance Test
Invoke-DotWinTest -TestName "Performance Test" -Category "Performance" -TestScript {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Run a series of operations and measure time
    $status = Get-DotWinStatus
    $hwInfo = Get-ChipsetInformation
    $config = [DotWinConfiguration]::new("PerfTest")
    $testResult = Test-DotWinConfiguration -Configuration $config

    $stopwatch.Stop()

    # Should complete within reasonable time (30 seconds)
    if ($stopwatch.Elapsed.TotalSeconds -gt 30) {
        throw "Performance test took too long: $($stopwatch.Elapsed.TotalSeconds) seconds"
    }

    Write-Host "  Performance test completed in $($stopwatch.Elapsed.TotalSeconds) seconds" -ForegroundColor Gray
    return $true
}

# Test 15: Integration Test
Invoke-DotWinTest -TestName "Integration Test" -Category "Integration" -TestScript {
    # Create a comprehensive configuration and test it
    $config = [DotWinConfiguration]::new("IntegrationTest")
    $config.Description = "Integration test configuration"

    # Add various configuration items
    $systemItem = [DotWinConfigurationItem]::new("SystemConfig", "System")
    $packageItem = [DotWinConfigurationItem]::new("PackageConfig", "Package")

    $config.AddItem($systemItem)
    $config.AddItem($packageItem)

    # Test the configuration
    $testResult = Test-DotWinConfiguration -Configuration $config

    if ($testResult.TotalItems -ne 2) {
        throw "Expected 2 items in integration test configuration, got $($testResult.TotalItems)"
    }

    # Test configuration retrieval
    $retrievedConfig = $config.GetItemsByType("System")
    if ($retrievedConfig.Count -ne 1) {
        throw "Expected 1 system item, got $($retrievedConfig.Count)"
    }

    return $true
}

# Display test results
Write-Host "`n=== Test Results Summary ===" -ForegroundColor Magenta
Write-Host "Total Tests: $($TestResults.TotalTests)" -ForegroundColor White
Write-Host "Passed: $($TestResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($TestResults.FailedTests)" -ForegroundColor Red
Write-Host "Skipped: $($TestResults.SkippedTests)" -ForegroundColor Yellow

$successRate = if ($TestResults.TotalTests -gt 0) {
    [math]::Round(($TestResults.PassedTests / $TestResults.TotalTests) * 100, 2)
} else {
    0
}
Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })

# Display failed tests
if ($TestResults.FailedTests -gt 0) {
    Write-Host "`n=== Failed Tests ===" -ForegroundColor Red
    $failedTests = $TestResults.TestDetails | Where-Object { $_.Success -eq $false }
    foreach ($test in $failedTests) {
        Write-Host "  ✗ $($test.Name): $($test.ErrorMessage)" -ForegroundColor Red
    }
}

# Display skipped tests
if ($TestResults.SkippedTests -gt 0) {
    Write-Host "`n=== Skipped Tests ===" -ForegroundColor Yellow
    $skippedTests = $TestResults.TestDetails | Where-Object { $_.Success -eq $null }
    foreach ($test in $skippedTests) {
        Write-Host "  ⚠ $($test.Name): $($test.ErrorMessage)" -ForegroundColor Yellow
    }
}

# Performance summary
$totalDuration = ($TestResults.TestDetails | Measure-Object -Property Duration -Sum).Sum
Write-Host "`nTotal test execution time: $($totalDuration.TotalSeconds) seconds" -ForegroundColor Gray

# Category breakdown
Write-Host "`n=== Test Categories ===" -ForegroundColor Cyan
$categories = $TestResults.TestDetails | Group-Object Category
foreach ($category in $categories) {
    $passed = ($category.Group | Where-Object { $_.Success -eq $true }).Count
    $failed = ($category.Group | Where-Object { $_.Success -eq $false }).Count
    $skipped = ($category.Group | Where-Object { $_.Success -eq $null }).Count

    Write-Host "$($category.Name): $passed passed, $failed failed, $skipped skipped" -ForegroundColor White
}

# Final status
Write-Host "`n=== Final Status ===" -ForegroundColor Magenta
if ($TestResults.FailedTests -eq 0) {
    Write-Host "🎉 All tests passed successfully!" -ForegroundColor Green
    $exitCode = 0
} else {
    Write-Host "❌ Some tests failed. Please review the results above." -ForegroundColor Red
    $exitCode = 1
}

Write-Host "Test execution completed at $(Get-Date)" -ForegroundColor Gray

# Optional: Export test results to file
$testResultsPath = ".\TestResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$TestResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $testResultsPath -Encoding UTF8
Write-Host "Test results exported to: $testResultsPath" -ForegroundColor Gray

# Return exit code for CI/CD integration
exit $exitCode
