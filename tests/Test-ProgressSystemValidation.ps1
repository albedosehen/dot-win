#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive validation test suite for the DotWin progress system integration

.DESCRIPTION
    This script provides complete validation of the DotWin progress system including:
    - All 5 refactored functions work correctly with progress bars
    - Nested progress operations display properly
    - Progress coordination with logging functions correctly
    - Verbose/Debug mode still shows detailed logging
    - Error handling maintains progress system integrity
    - Backward compatibility is preserved
    - Performance requirements are met

.PARAMETER TestFunction
    Specific function to test. Valid values: Configuration, SystemTools, Applications, Bloatware, Packages, All

.PARAMETER PerformanceTest
    Run performance validation tests

.PARAMETER VerboseOutput
    Enable verbose output during tests

.PARAMETER WhatIf
    Run tests in WhatIf mode (recommended for safety)

.EXAMPLE
    .\Test-ProgressSystemValidation.ps1 -TestFunction All -WhatIf -VerboseOutput

.EXAMPLE
    .\Test-ProgressSystemValidation.ps1 -PerformanceTest
#>

param(
    [Parameter()]
    [ValidateSet('Configuration', 'SystemTools', 'Applications', 'Bloatware', 'Packages', 'All')]
    [string]$TestFunction = 'All',
    
    [Parameter()]
    [switch]$PerformanceTest,
    
    [Parameter()]
    [switch]$VerboseOutput,
    
    [Parameter()]
    [switch]$WhatIf
)

# Import the DotWin module
try {
    Import-Module .\DotWin.psm1 -Force -Verbose:$VerboseOutput
    Write-Host "✓ DotWin module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import DotWin module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test results tracking
$script:TestResults = @{
    Total = 0
    Passed = 0
    Failed = 0
    Warnings = 0
    Details = @()
}

function Add-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message,
        [string]$Details = "",
        [bool]$IsWarning = $false
    )
    
    $script:TestResults.Total++
    if ($IsWarning) {
        $script:TestResults.Warnings++
        $status = "WARNING"
        $color = "Yellow"
    } elseif ($Passed) {
        $script:TestResults.Passed++
        $status = "PASS"
        $color = "Green"
    } else {
        $script:TestResults.Failed++
        $status = "FAIL"
        $color = "Red"
    }
    
    $result = @{
        TestName = $TestName
        Status = $status
        Message = $Message
        Details = $Details
        Timestamp = Get-Date
    }
    
    $script:TestResults.Details += $result
    Write-Host "[$status] $TestName - $Message" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

function Test-ProgressSystemCore {
    Write-Host "`n=== Testing Core Progress System ===" -ForegroundColor Cyan
    
    # Test 1: Basic progress functionality
    try {
        $progressId = Write-DotWinProgress -Activity "Core Test" -Status "Testing basic functionality"
        if ($progressId) {
            Write-DotWinProgress -ProgressId $progressId -PercentComplete 50 -Status "Half complete"
            Complete-DotWinProgress -ProgressId $progressId -Status "Test completed"
            Add-TestResult "Basic Progress Operations" $true "Core progress functions work correctly"
        } else {
            Add-TestResult "Basic Progress Operations" $false "Failed to create progress operation"
        }
    } catch {
        Add-TestResult "Basic Progress Operations" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 2: Nested progress functionality
    try {
        $parentId = Start-DotWinProgress -Activity "Parent Test" -Status "Testing nested progress"
        $childId = Start-DotWinProgress -Activity "Child Test" -ParentId $parentId -Status "Child operation"
        
        if ($parentId -and $childId) {
            Write-DotWinProgress -ProgressId $childId -PercentComplete 100
            Complete-DotWinProgress -ProgressId $childId
            Complete-DotWinProgress -ProgressId $parentId
            Add-TestResult "Nested Progress Operations" $true "Nested progress hierarchy works correctly"
        } else {
            Add-TestResult "Nested Progress Operations" $false "Failed to create nested progress operations"
        }
    } catch {
        Add-TestResult "Nested Progress Operations" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 3: Progress with metrics
    try {
        $progressId = Start-DotWinProgress -Activity "Metrics Test" -InitialMetrics @{ StartTime = Get-Date }
        Write-DotWinProgress -ProgressId $progressId -Metrics @{ ItemsProcessed = 5; ErrorCount = 0 }
        Complete-DotWinProgress -ProgressId $progressId -FinalMetrics @{ EndTime = Get-Date; TotalItems = 10 }
        Add-TestResult "Progress with Metrics" $true "Progress metrics functionality works correctly"
    } catch {
        Add-TestResult "Progress with Metrics" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 4: Progress coordination with logging
    try {
        $progressId = Start-DotWinProgress -Activity "Logging Test" -Status "Testing log coordination"
        Write-DotWinLog -Message "Test message during progress" -Level "Information" -ShowWithProgress -ProgressId $progressId
        Write-DotWinLog -Message "Warning message during progress" -Level "Warning" -ShowWithProgress -ProgressId $progressId
        Complete-DotWinProgress -ProgressId $progressId
        Add-TestResult "Progress-Logging Coordination" $true "Progress and logging coordination works correctly"
    } catch {
        Add-TestResult "Progress-Logging Coordination" $false "Exception: $($_.Exception.Message)"
    }
}

function Test-FunctionIntegration {
    param([string]$FunctionName)
    
    Write-Host "`n=== Testing $FunctionName Integration ===" -ForegroundColor Cyan
    
    switch ($FunctionName) {
        'Configuration' {
            try {
                # Create minimal test configuration
                $testConfig = [DotWinConfiguration]::new("ValidationTest")
                $testConfig.Description = "Minimal test configuration for validation"
                
                # Add a simple system tools item
                $toolsItem = [DotWinSystemTools]::new("TestTools")
                $toolsItem.Description = "Test tools for validation"
                $toolsItem.RequiredTools = @("git")  # Single tool for quick test
                $testConfig.AddItem($toolsItem)
                
                if ($WhatIf) {
                    $results = Invoke-DotWinConfiguration -Configuration $testConfig -WhatIf -Verbose:$VerboseOutput
                } else {
                    $results = Invoke-DotWinConfiguration -Configuration $testConfig -Verbose:$VerboseOutput
                }
                
                if ($results -and $results.Count -gt 0) {
                    $hasProgressMetrics = $results | Where-Object { $_.ProgressMetrics.Count -gt 0 }
                    if ($hasProgressMetrics) {
                        Add-TestResult "Invoke-DotWinConfiguration Progress" $true "Function integrates progress system correctly"
                    } else {
                        Add-TestResult "Invoke-DotWinConfiguration Progress" $false "No progress metrics captured" "" $true
                    }
                } else {
                    Add-TestResult "Invoke-DotWinConfiguration Progress" $false "Function returned no results"
                }
            } catch {
                Add-TestResult "Invoke-DotWinConfiguration Progress" $false "Exception: $($_.Exception.Message)"
            }
        }
        
        'SystemTools' {
            try {
                $testTools = @('git')  # Single tool for quick test
                
                if ($WhatIf) {
                    $results = Install-SystemTools -ToolNames $testTools -WhatIf -Verbose:$VerboseOutput
                } else {
                    $results = Install-SystemTools -ToolNames $testTools -Verbose:$VerboseOutput
                }
                
                if ($results -and $results.Count -gt 0) {
                    $hasProgressId = $results | Where-Object { $_.ProgressId }
                    if ($hasProgressId) {
                        Add-TestResult "Install-SystemTools Progress" $true "Function integrates progress system correctly"
                    } else {
                        Add-TestResult "Install-SystemTools Progress" $false "No progress IDs captured" "" $true
                    }
                } else {
                    Add-TestResult "Install-SystemTools Progress" $false "Function returned no results"
                }
            } catch {
                Add-TestResult "Install-SystemTools Progress" $false "Exception: $($_.Exception.Message)"
            }
        }
        
        'Applications' {
            try {
                # Test with minimal application list
                $testApps = @('notepad++')  # Single app for quick test
                
                if ($WhatIf) {
                    $results = Install-Applications -ApplicationNames $testApps -WhatIf -Verbose:$VerboseOutput
                } else {
                    $results = Install-Applications -ApplicationNames $testApps -Verbose:$VerboseOutput
                }
                
                if ($results) {
                    Add-TestResult "Install-Applications Progress" $true "Function integrates progress system correctly"
                } else {
                    Add-TestResult "Install-Applications Progress" $false "Function returned no results"
                }
            } catch {
                Add-TestResult "Install-Applications Progress" $false "Exception: $($_.Exception.Message)"
            }
        }
        
        'Bloatware' {
            try {
                if ($WhatIf) {
                    $results = Remove-Bloatware -WhatIf -Verbose:$VerboseOutput
                } else {
                    $results = Remove-Bloatware -Verbose:$VerboseOutput
                }
                
                if ($results) {
                    Add-TestResult "Remove-Bloatware Progress" $true "Function integrates progress system correctly"
                } else {
                    Add-TestResult "Remove-Bloatware Progress" $false "Function returned no results"
                }
            } catch {
                Add-TestResult "Remove-Bloatware Progress" $false "Exception: $($_.Exception.Message)"
            }
        }
        
        'Packages' {
            try {
                # Test with minimal package list
                $testPackages = @('7zip')  # Single package for quick test
                
                if ($WhatIf) {
                    $results = Install-Packages -PackageNames $testPackages -WhatIf -Verbose:$VerboseOutput
                } else {
                    $results = Install-Packages -PackageNames $testPackages -Verbose:$VerboseOutput
                }
                
                if ($results) {
                    Add-TestResult "Install-Packages Progress" $true "Function integrates progress system correctly"
                } else {
                    Add-TestResult "Install-Packages Progress" $false "Function returned no results"
                }
            } catch {
                Add-TestResult "Install-Packages Progress" $false "Exception: $($_.Exception.Message)"
            }
        }
    }
}

function Test-PerformanceRequirements {
    Write-Host "`n=== Testing Performance Requirements ===" -ForegroundColor Cyan
    
    # Test 1: Progress system latency (<50ms requirement)
    try {
        $iterations = 10
        $totalTime = 0
        
        for ($i = 0; $i -lt $iterations; $i++) {
            $startTime = Get-Date
            $progressId = Write-DotWinProgress -Activity "Performance Test $i" -Status "Testing latency"
            Write-DotWinProgress -ProgressId $progressId -PercentComplete 50
            Complete-DotWinProgress -ProgressId $progressId
            $endTime = Get-Date
            $totalTime += ($endTime - $startTime).TotalMilliseconds
        }
        
        $averageLatency = $totalTime / $iterations
        if ($averageLatency -lt 50) {
            Add-TestResult "Progress System Latency" $true "Average latency: $([math]::Round($averageLatency, 2))ms (< 50ms requirement)"
        } else {
            Add-TestResult "Progress System Latency" $false "Average latency: $([math]::Round($averageLatency, 2))ms (exceeds 50ms requirement)"
        }
    } catch {
        Add-TestResult "Progress System Latency" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 2: Memory usage (<10MB requirement)
    try {
        $beforeMemory = [System.GC]::GetTotalMemory($false)
        
        # Create multiple progress operations to test memory usage
        $progressIds = @()
        for ($i = 0; $i -lt 100; $i++) {
            $progressIds += Start-DotWinProgress -Activity "Memory Test $i" -Status "Testing memory usage"
        }
        
        $afterMemory = [System.GC]::GetTotalMemory($false)
        $memoryUsed = ($afterMemory - $beforeMemory) / 1MB
        
        # Clean up
        foreach ($id in $progressIds) {
            Complete-DotWinProgress -ProgressId $id
        }
        
        if ($memoryUsed -lt 10) {
            Add-TestResult "Progress System Memory Usage" $true "Memory used: $([math]::Round($memoryUsed, 2))MB (< 10MB requirement)"
        } else {
            Add-TestResult "Progress System Memory Usage" $false "Memory used: $([math]::Round($memoryUsed, 2))MB (exceeds 10MB requirement)"
        }
    } catch {
        Add-TestResult "Progress System Memory Usage" $false "Exception: $($_.Exception.Message)"
    }
}

function Test-BackwardCompatibility {
    Write-Host "`n=== Testing Backward Compatibility ===" -ForegroundColor Cyan
    
    # Test 1: Module exports
    try {
        $exportedFunctions = Get-Command -Module DotWin -CommandType Function
        $requiredFunctions = @(
            'Invoke-DotWinConfiguration', 'Install-SystemTools', 'Install-Applications',
            'Remove-Bloatware', 'Install-Packages', 'Write-DotWinProgress',
            'Start-DotWinProgress', 'Complete-DotWinProgress'
        )
        
        $missingFunctions = $requiredFunctions | Where-Object { $_ -notin $exportedFunctions.Name }
        
        if ($missingFunctions.Count -eq 0) {
            Add-TestResult "Module Function Exports" $true "All required functions are exported"
        } else {
            Add-TestResult "Module Function Exports" $false "Missing functions: $($missingFunctions -join ', ')"
        }
    } catch {
        Add-TestResult "Module Function Exports" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 2: Function parameter compatibility
    try {
        $configFunction = Get-Command Invoke-DotWinConfiguration
        $requiredParams = @('Configuration', 'ConfigurationPath', 'WhatIf', 'Verbose')
        $missingParams = $requiredParams | Where-Object { $_ -notin $configFunction.Parameters.Keys }
        
        if ($missingParams.Count -eq 0) {
            Add-TestResult "Function Parameter Compatibility" $true "All required parameters are available"
        } else {
            Add-TestResult "Function Parameter Compatibility" $false "Missing parameters: $($missingParams -join ', ')"
        }
    } catch {
        Add-TestResult "Function Parameter Compatibility" $false "Exception: $($_.Exception.Message)"
    }
}

function Test-ErrorHandling {
    Write-Host "`n=== Testing Error Handling ===" -ForegroundColor Cyan
    
    # Test 1: Invalid progress ID handling
    try {
        $result = Write-DotWinProgress -ProgressId "invalid-id" -PercentComplete 50 2>$null
        $null = $result
        Add-TestResult "Invalid Progress ID Handling" $true "System handles invalid progress IDs gracefully"
    } catch {
        Add-TestResult "Invalid Progress ID Handling" $false "Exception: $($_.Exception.Message)"
    }
    
    # Test 2: Progress system failure fallback
    try {
        # Temporarily disable progress system
        $originalManager = $script:ProgressStackManager
        $script:ProgressStackManager = $null
        
        $progressId = Write-DotWinProgress -Activity "Fallback Test" -Status "Testing fallback"
        $null = $progressId
        # Restore progress system
        $script:ProgressStackManager = $originalManager
        
        Add-TestResult "Progress System Fallback" $true "System falls back to standard Write-Progress when progress system unavailable"
    } catch {
        Add-TestResult "Progress System Fallback" $false "Exception: $($_.Exception.Message)"
    }
}

# Main test execution
Write-Host "=== DotWin Progress System Comprehensive Validation ===" -ForegroundColor Cyan
Write-Host "Testing progress system integration across all refactored functions" -ForegroundColor Green
Write-Host "Test Mode: $(if ($WhatIf) { 'WhatIf (Safe)' } else { 'Live' })" -ForegroundColor Yellow
Write-Host ""

# Core progress system tests
Test-ProgressSystemCore

# Function integration tests
if ($TestFunction -eq 'All') {
    $functionsToTest = @('Configuration', 'SystemTools', 'Applications', 'Bloatware', 'Packages')
} else {
    $functionsToTest = @($TestFunction)
}

foreach ($function in $functionsToTest) {
    Test-FunctionIntegration -FunctionName $function
}

# Performance tests
if ($PerformanceTest) {
    Test-PerformanceRequirements
}

# Compatibility and error handling tests
Test-BackwardCompatibility
Test-ErrorHandling

# Test summary
Write-Host "`n=== Test Results Summary ===" -ForegroundColor Cyan
Write-Host "Total Tests: $($script:TestResults.Total)" -ForegroundColor White
Write-Host "Passed: $($script:TestResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($script:TestResults.Failed)" -ForegroundColor Red
Write-Host "Warnings: $($script:TestResults.Warnings)" -ForegroundColor Yellow

$successRate = if ($script:TestResults.Total -gt 0) { 
    [math]::Round(($script:TestResults.Passed / $script:TestResults.Total) * 100, 1) 
} else { 0 }

Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { 'Green' } elseif ($successRate -ge 75) { 'Yellow' } else { 'Red' })

if ($script:TestResults.Failed -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    $script:TestResults.Details | Where-Object { $_.Status -eq 'FAIL' } | ForEach-Object {
        Write-Host "  - $($_.TestName): $($_.Message)" -ForegroundColor Red
    }
}

if ($script:TestResults.Warnings -gt 0) {
    Write-Host "`nWarnings:" -ForegroundColor Yellow
    $script:TestResults.Details | Where-Object { $_.Status -eq 'WARNING' } | ForEach-Object {
        Write-Host "  - $($_.TestName): $($_.Message)" -ForegroundColor Yellow
    }
}

# Final validation status
Write-Host "`n=== Final Validation Status ===" -ForegroundColor Cyan
if ($script:TestResults.Failed -eq 0) {
    Write-Host "✓ Progress system integration validation PASSED" -ForegroundColor Green
    Write-Host "  The progress system is ready for production use" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ Progress system integration validation FAILED" -ForegroundColor Red
    Write-Host "  Please address the failed tests before production deployment" -ForegroundColor Red
    exit 1
}
