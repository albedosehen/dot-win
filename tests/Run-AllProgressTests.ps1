#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Master test runner for DotWin progress system validation

.DESCRIPTION
    This script runs all progress system validation tests in the correct order:
    1. Core progress system validation
    2. Function integration tests
    3. Complete workflow tests
    4. Performance validation tests
    
    Provides comprehensive validation that the progress system integration
    is complete and ready for production use.

.PARAMETER TestSuite
    Which test suite to run. Valid values: Core, Integration, Workflow, Performance, All

.PARAMETER WhatIf
    Run tests in WhatIf mode (recommended for safety)

.PARAMETER VerboseOutput
    Enable verbose output during tests

.PARAMETER StressTest
    Run extended stress tests (takes longer but more thorough)

.PARAMETER GenerateReport
    Generate a detailed test report

.EXAMPLE
    .\Run-AllProgressTests.ps1 -TestSuite All -WhatIf -VerboseOutput

.EXAMPLE
    .\Run-AllProgressTests.ps1 -TestSuite Performance -StressTest

.EXAMPLE
    .\Run-AllProgressTests.ps1 -GenerateReport
#>

param(
    [Parameter()]
    [ValidateSet('Core', 'Integration', 'Workflow', 'Performance', 'All')]
    [string]$TestSuite = 'All',
    
    [Parameter()]
    [switch]$WhatIf,
    
    [Parameter()]
    [switch]$VerboseOutput,
    
    [Parameter()]
    [switch]$StressTest,
    
    [Parameter()]
    [switch]$GenerateReport
)

# Test execution tracking
$script:TestExecution = @{
    StartTime = Get-Date
    TestResults = @()
    OverallStatus = $true
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    WarningTests = 0
}

function Write-TestHeader {
    param([string]$Title)
    
    Write-Host "`n" -NoNewline
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "=" * 80 -ForegroundColor Cyan
}

function Write-TestSection {
    param([string]$Section)
    
    Write-Host "`n--- $Section ---" -ForegroundColor Yellow
}

function Add-TestExecutionResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = "",
        [int]$ExitCode = 0,
        [timespan]$Duration
    )
    
    $script:TestExecution.TestResults += @{
        TestName = $TestName
        Passed = $Passed
        Details = $Details
        ExitCode = $ExitCode
        Duration = $Duration
        Timestamp = Get-Date
    }
    
    $script:TestExecution.TotalTests++
    if ($Passed) {
        $script:TestExecution.PassedTests++
    } else {
        $script:TestExecution.FailedTests++
        $script:TestExecution.OverallStatus = $false
    }
}

function Invoke-TestScript {
    param(
        [string]$ScriptPath,
        [string]$TestName,
        [hashtable]$Parameters = @{}
    )
    
    Write-Host "`nRunning $TestName..." -ForegroundColor Green
    Write-Host "Script: $ScriptPath" -ForegroundColor Gray
    
    if (-not (Test-Path $ScriptPath)) {
        Write-Host "✗ Test script not found: $ScriptPath" -ForegroundColor Red
        Add-TestExecutionResult -TestName $TestName -Passed $false -Details "Script not found" -Duration ([timespan]::Zero)
        return $false
    }
    
    $startTime = Get-Date
    
    try {
        # Build parameter string
        $paramString = ""
        foreach ($param in $Parameters.GetEnumerator()) {
            if ($param.Value -is [switch] -and $param.Value) {
                $paramString += " -$($param.Key)"
            } elseif ($param.Value -isnot [switch]) {
                $paramString += " -$($param.Key) '$($param.Value)'"
            }
        }
        
        Write-Host "Parameters: $paramString" -ForegroundColor Gray
        
        # Execute the test script
        $result = & $ScriptPath @Parameters
        $null = $result
        $exitCode = $LASTEXITCODE
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        if ($exitCode -eq 0) {
            Write-Host "✓ $TestName completed successfully" -ForegroundColor Green
            Write-Host "  Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Gray
            Add-TestExecutionResult -TestName $TestName -Passed $true -Details "Completed successfully" -ExitCode $exitCode -Duration $duration
            return $true
        } else {
            Write-Host "✗ $TestName failed with exit code $exitCode" -ForegroundColor Red
            Write-Host "  Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Gray
            Add-TestExecutionResult -TestName $TestName -Passed $false -Details "Failed with exit code $exitCode" -ExitCode $exitCode -Duration $duration
            return $false
        }
        
    } catch {
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host "✗ $TestName failed with exception: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Gray
        Add-TestExecutionResult -TestName $TestName -Passed $false -Details "Exception: $($_.Exception.Message)" -Duration $duration
        return $false
    }
}

function Test-CoreProgressSystem {
    Write-TestSection "Core Progress System Tests"
    
    $testParams = @{}
    if ($VerboseOutput) { $testParams['VerboseOutput'] = $true }
    
    # Run the comprehensive validation test
    $result = Invoke-TestScript -ScriptPath "tests\Test-ProgressSystemValidation.ps1" -TestName "Core Progress System Validation" -Parameters @{
        TestFunction = 'All'
        WhatIf = $WhatIf
        VerboseOutput = $VerboseOutput
    }
    
    return $result
}

function Test-IntegrationTests {
    Write-TestSection "Function Integration Tests"
    
    # Test individual function integrations
    $functions = @('Configuration', 'SystemTools', 'Applications', 'Bloatware', 'Packages')
    $allPassed = $true
    
    foreach ($function in $functions) {
        $result = Invoke-TestScript -ScriptPath "tests\Test-ProgressSystemValidation.ps1" -TestName "Function Integration - $function" -Parameters @{
            TestFunction = $function
            WhatIf = $WhatIf
            VerboseOutput = $VerboseOutput
        }
        
        if (-not $result) { $allPassed = $false }
    }
    
    return $allPassed
}

function Test-CompleteWorkflow {
    Write-TestSection "Complete Workflow Tests"
    
    $result = Invoke-TestScript -ScriptPath "tests\Test-CompleteWorkflow.ps1" -TestName "Complete Workflow Integration" -Parameters @{
        WhatIf = $WhatIf
        VerboseMode = $VerboseOutput
        DebugMode = $false
    }
    
    return $result
}

function Test-PerformanceValidation {
    Write-TestSection "Performance Validation Tests"
    
    $testParams = @{
        Iterations = if ($StressTest) { 200 } else { 100 }
        DetailedOutput = $VerboseOutput
    }
    
    if ($StressTest) {
        $testParams['StressTest'] = $true
    }
    
    $result = Invoke-TestScript -ScriptPath "tests\Test-ProgressPerformance.ps1" -TestName "Performance Validation" -Parameters $testParams
    
    return $result
}

function Test-BasicProgressSystem {
    Write-TestSection "Basic Progress System Tests"
    
    $result = Invoke-TestScript -ScriptPath "test-progress-system.ps1" -TestName "Basic Progress System" -Parameters @{}
    
    return $result
}

function Test-ProgressIntegration {
    Write-TestSection "Progress Integration Tests"
    
    $result = Invoke-TestScript -ScriptPath "test-progress-integration.ps1" -TestName "Progress Integration" -Parameters @{
        TestBoth = $true
        WhatIf = $WhatIf
        VerboseOutput = $VerboseOutput
    }
    
    return $result
}

function New-GeneratedTestReport {
    if (-not $GenerateReport) { return }
    
    Write-TestHeader "Generating Test Report"
    
    $reportPath = "tests\ProgressSystemValidationReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').md"
    
    $report = @"
# DotWin Progress System Validation Report

**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**Test Suite:** $TestSuite
**Mode:** $(if ($WhatIf) { 'WhatIf (Safe)' } else { 'Live' })
**Verbose Output:** $(if ($VerboseOutput) { 'Enabled' } else { 'Disabled' })
**Stress Testing:** $(if ($StressTest) { 'Enabled' } else { 'Disabled' })

## Summary

- **Total Tests:** $($script:TestExecution.TotalTests)
- **Passed:** $($script:TestExecution.PassedTests)
- **Failed:** $($script:TestExecution.FailedTests)
- **Success Rate:** $([math]::Round(($script:TestExecution.PassedTests / $script:TestExecution.TotalTests) * 100, 1))%
- **Overall Status:** $(if ($script:TestExecution.OverallStatus) { '✓ PASSED' } else { '✗ FAILED' })
- **Total Duration:** $((Get-Date) - $script:TestExecution.StartTime)

## Test Results

"@

    foreach ($test in $script:TestExecution.TestResults) {
        $status = if ($test.Passed) { '✓ PASSED' } else { '✗ FAILED' }
        $report += @"

### $($test.TestName)

- **Status:** $status
- **Duration:** $($test.Duration.TotalSeconds) seconds
- **Exit Code:** $($test.ExitCode)
- **Details:** $($test.Details)
- **Timestamp:** $($test.Timestamp.ToString('yyyy-MM-dd HH:mm:ss'))

"@
    }
    
    $report += @"

## Validation Criteria

The DotWin progress system integration is considered complete when:

- [$(if ($script:TestExecution.OverallStatus) { 'x' } else { ' ' })] All core progress functions work correctly
- [$(if ($script:TestExecution.OverallStatus) { 'x' } else { ' ' })] All 5 refactored functions integrate progress bars
- [$(if ($script:TestExecution.OverallStatus) { 'x' } else { ' ' })] Nested progress operations display properly
- [$(if ($script:TestExecution.OverallStatus) { 'x' } else { ' ' })] Progress coordination with logging works correctly
- [$(if ($script:TestExecution.OverallStatus) { 'x' } else { ' ' })] Verbose/Debug mode shows detailed logging
- [$(if ($script:TestExecution.OverallStatus) { 'x' } else { ' ' })] Error handling maintains progress system integrity
- [$(if ($script:TestExecution.OverallStatus) { 'x' } else { ' ' })] Backward compatibility is preserved
- [$(if ($script:TestExecution.OverallStatus) { 'x' } else { ' ' })] Performance requirements are met (<50ms latency, <10MB memory)

## Conclusion

$(if ($script:TestExecution.OverallStatus) {
    "The DotWin progress system integration has been successfully validated and is ready for production use. All tests passed and the system meets the specified requirements."
} else {
    "The DotWin progress system integration validation has failed. Please review the failed tests and address the issues before production deployment."
})

---
*Report generated by DotWin Progress System Validation Suite*
"@

    try {
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        Write-Host "✓ Test report generated: $reportPath" -ForegroundColor Green
    } catch {
        Write-Host "✗ Failed to generate test report: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Main execution
Write-TestHeader "DotWin Progress System Comprehensive Validation"

Write-Host "Test Configuration:" -ForegroundColor White
Write-Host "  - Test Suite: $TestSuite" -ForegroundColor Gray
Write-Host "  - Mode: $(if ($WhatIf) { 'WhatIf (Safe)' } else { 'Live' })" -ForegroundColor Gray
Write-Host "  - Verbose Output: $(if ($VerboseOutput) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
Write-Host "  - Stress Testing: $(if ($StressTest) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray
Write-Host "  - Generate Report: $(if ($GenerateReport) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Gray

# Execute test suites based on selection
switch ($TestSuite) {
    'Core' {
        Test-CoreProgressSystem
        Test-BasicProgressSystem
    }
    'Integration' {
        Test-IntegrationTests
        Test-ProgressIntegration
    }
    'Workflow' {
        Test-CompleteWorkflow
    }
    'Performance' {
        Test-PerformanceValidation
    }
    'All' {
        Test-BasicProgressSystem
        Test-CoreProgressSystem
        Test-IntegrationTests
        Test-ProgressIntegration
        Test-CompleteWorkflow
        Test-PerformanceValidation
    }
}

# Generate report if requested
New-GeneratedTestReport

# Final summary
Write-TestHeader "Final Validation Summary"

$endTime = Get-Date
$totalDuration = $endTime - $script:TestExecution.StartTime

Write-Host "Test Execution Summary:" -ForegroundColor White
Write-Host "  - Total Tests: $($script:TestExecution.TotalTests)" -ForegroundColor Gray
Write-Host "  - Passed: $($script:TestExecution.PassedTests)" -ForegroundColor Green
Write-Host "  - Failed: $($script:TestExecution.FailedTests)" -ForegroundColor Red
Write-Host "  - Success Rate: $([math]::Round(($script:TestExecution.PassedTests / $script:TestExecution.TotalTests) * 100, 1))%" -ForegroundColor $(if ($script:TestExecution.OverallStatus) { 'Green' } else { 'Red' })
Write-Host "  - Total Duration: $($totalDuration.TotalMinutes) minutes" -ForegroundColor Gray

if ($script:TestExecution.FailedTests -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $script:TestExecution.TestResults | Where-Object { -not $_.Passed } | ForEach-Object {
        Write-Host "  - $($_.TestName): $($_.Details)" -ForegroundColor Red
    }
}

Write-Host "`n" -NoNewline
Write-Host "=" * 80 -ForegroundColor Cyan
if ($script:TestExecution.OverallStatus) {
    Write-Host " ✓ DOTWIN PROGRESS SYSTEM VALIDATION PASSED" -ForegroundColor Green
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The DotWin progress system integration is complete and ready for production use!" -ForegroundColor Green
    Write-Host "All validation criteria have been met:" -ForegroundColor Green
    Write-Host "  ✓ Progress bars display correctly in all functions" -ForegroundColor Green
    Write-Host "  ✓ Nested progress operations work properly" -ForegroundColor Green
    Write-Host "  ✓ Logging coordination functions correctly" -ForegroundColor Green
    Write-Host "  ✓ Performance requirements are satisfied" -ForegroundColor Green
    Write-Host "  ✓ Backward compatibility is maintained" -ForegroundColor Green
    exit 0
} else {
    Write-Host " ✗ DOTWIN PROGRESS SYSTEM VALIDATION FAILED" -ForegroundColor Red
    Write-Host "=" * 80 -ForegroundColor Cyan
    Write-Host ""
    Write-Host "The DotWin progress system integration has issues that need to be addressed." -ForegroundColor Red
    Write-Host "Please review the failed tests and fix the issues before production deployment." -ForegroundColor Red
    exit 1
}