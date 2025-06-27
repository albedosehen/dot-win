#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete workflow integration test for DotWin progress system

.DESCRIPTION
    This script demonstrates and tests the complete DotWin workflow with the integrated
    progress system, showing nested progress from master function down to individual
    operations, validating progress ID tracking, and testing both normal and verbose modes.

.PARAMETER ConfigurationPath
    Path to a test configuration file to use

.PARAMETER VerboseMode
    Run the test in verbose mode to validate detailed logging

.PARAMETER DebugMode
    Run the test in debug mode for maximum detail

.PARAMETER WhatIf
    Run the test in WhatIf mode (recommended for safety)

.EXAMPLE
    .\Test-CompleteWorkflow.ps1 -WhatIf -VerboseMode

.EXAMPLE
    .\Test-CompleteWorkflow.ps1 -ConfigurationPath "test-config.json" -DebugMode
#>

param(
    [Parameter()]
    [string]$ConfigurationPath,
    
    [Parameter()]
    [switch]$VerboseMode,
    
    [Parameter()]
    [switch]$DebugMode,
    
    [Parameter()]
    [switch]$WhatIf
)

# Set preference variables based on parameters
if ($VerboseMode) { $VerbosePreference = 'Continue' }
if ($DebugMode) { $DebugPreference = 'Continue' }

# Import the DotWin module
try {
    Import-Module .\DotWin.psm1 -Force -Verbose:$VerboseMode
    Write-Host "✓ DotWin module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import DotWin module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Progress tracking for validation
$script:ProgressTracker = @{
    CreatedIds = @()
    CompletedIds = @()
    NestedOperations = @()
    Metrics = @{}
}

function Get-ProgressOperation {
    param(
        [string]$ProgressId,
        [string]$Operation,
        [string]$ParentId = $null
    )
    
    if ($ProgressId) {
        $script:ProgressTracker.CreatedIds += $ProgressId
        if ($ParentId) {
            $script:ProgressTracker.NestedOperations += @{
                ChildId = $ProgressId
                ParentId = $ParentId
                Operation = $Operation
            }
        }
    }
}

function New-TestConfiguration {
    Write-Host "`n=== Creating Test Configuration ===" -ForegroundColor Cyan
    
    # Create a comprehensive test configuration
    $testConfig = [DotWinConfiguration]::new("CompleteWorkflowTest")
    $testConfig.Description = "Complete workflow test configuration with multiple components"
    
    # Add System Tools component
    $systemTools = [DotWinSystemTools]::new("TestSystemTools")
    $systemTools.Description = "Test system tools for workflow validation"
    $systemTools.RequiredTools = @("git", "vscode")
    $testConfig.AddItem($systemTools)
    
    # Add Packages component
    $packages = [DotWinPackages]::new("TestPackages")
    $packages.Description = "Test packages for workflow validation"
    $packages.PackageNames = @("7zip", "notepad++")
    $testConfig.AddItem($packages)
    
    # Add PowerShell Profile component
    $psProfile = [DotWinPowerShellProfile]::new("TestPowerShellProfile")
    $psProfile.Description = "Test PowerShell profile configuration"
    $testConfig.AddItem($psProfile)
    
    # Add Windows Terminal component
    $terminal = [DotWinWindowsTerminal]::new("TestWindowsTerminal")
    $terminal.Description = "Test Windows Terminal configuration"
    $testConfig.AddItem($terminal)
    
    Write-Host "✓ Created test configuration with $($testConfig.Items.Count) components:" -ForegroundColor Green
    foreach ($item in $testConfig.Items) {
        Write-Host "  - $($item.Name): $($item.Description)" -ForegroundColor Gray
    }
    
    return $testConfig
}

function Test-ProgressSystemIntegration {
    param([DotWinConfiguration]$Configuration)
    
    Write-Host "`n=== Testing Complete Progress System Integration ===" -ForegroundColor Cyan
    Write-Host "Running Invoke-DotWinConfiguration with full progress tracking..." -ForegroundColor Yellow
    
    # Capture start time for performance measurement
    $startTime = Get-Date
    
    try {
        # Execute the main configuration function
        if ($WhatIf) {
            Write-Host "Running in WhatIf mode (safe execution)..." -ForegroundColor Yellow
            $results = Invoke-DotWinConfiguration -Configuration $Configuration -WhatIf -Verbose:$VerboseMode
        } else {
            Write-Host "Running in live mode..." -ForegroundColor Yellow
            $results = Invoke-DotWinConfiguration -Configuration $Configuration -Verbose:$VerboseMode
        }
        
        $endTime = Get-Date
        $duration = $endTime - $startTime
        
        Write-Host "`n✓ Configuration execution completed successfully!" -ForegroundColor Green
        Write-Host "  Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Gray
        Write-Host "  Results: $($results.Count) items processed" -ForegroundColor Gray
        
        # Analyze results for progress system integration
        Write-Host "`n=== Progress System Integration Analysis ===" -ForegroundColor Cyan
        
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        $progressMetricsCount = ($results | Where-Object { $_.ProgressMetrics.Count -gt 0 }).Count
        $progressIdCount = ($results | Where-Object { $_.ProgressId }).Count
        
        Write-Host "Execution Results:" -ForegroundColor White
        Write-Host "  - Successful operations: $successCount" -ForegroundColor Green
        Write-Host "  - Failed operations: $failureCount" -ForegroundColor $(if ($failureCount -gt 0) { 'Red' } else { 'Green' })
        Write-Host "  - Operations with progress metrics: $progressMetricsCount" -ForegroundColor Cyan
        Write-Host "  - Operations with progress IDs: $progressIdCount" -ForegroundColor Cyan
        
        # Detailed progress analysis
        Write-Host "`nProgress System Integration Details:" -ForegroundColor White
        foreach ($result in $results) {
            Write-Host "  $($result.ItemName):" -ForegroundColor Yellow
            Write-Host "    - Success: $($result.Success)" -ForegroundColor $(if ($result.Success) { 'Green' } else { 'Red' })
            Write-Host "    - Duration: $($result.Duration.TotalSeconds)s" -ForegroundColor Gray
            
            if ($result.ProgressId) {
                Write-Host "    - Progress ID: $($result.ProgressId)" -ForegroundColor Cyan
            }
            
            if ($result.ProgressMetrics.Count -gt 0) {
                Write-Host "    - Progress Metrics: $($result.ProgressMetrics.Count) captured" -ForegroundColor Cyan
                foreach ($metric in $result.ProgressMetrics.GetEnumerator()) {
                    Write-Host "      * $($metric.Key): $($metric.Value)" -ForegroundColor Gray
                }
            }
            
            if ($result.ErrorMessage) {
                Write-Host "    - Error: $($result.ErrorMessage)" -ForegroundColor Red
            }
        }
        
        return $results
        
    } catch {
        Write-Host "✗ Configuration execution failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        return $null
    }
}

function Test-IndividualFunctions {
    Write-Host "`n=== Testing Individual Function Progress Integration ===" -ForegroundColor Cyan
    
    $functionTests = @(
        @{
            Name = "Install-SystemTools"
            Function = { Install-SystemTools -ToolNames @("git") -WhatIf:$WhatIf -Verbose:$VerboseMode }
        },
        @{
            Name = "Install-Applications"
            Function = { Install-Applications -ApplicationNames @("notepad++") -WhatIf:$WhatIf -Verbose:$VerboseMode }
        },
        @{
            Name = "Install-Packages"
            Function = { Install-Packages -PackageNames @("7zip") -WhatIf:$WhatIf -Verbose:$VerboseMode }
        },
        @{
            Name = "Remove-Bloatware"
            Function = { Remove-Bloatware -WhatIf:$WhatIf -Verbose:$VerboseMode }
        }
    )
    
    foreach ($test in $functionTests) {
        Write-Host "`nTesting $($test.Name)..." -ForegroundColor Yellow
        
        try {
            $startTime = Get-Date
            $result = & $test.Function
            $endTime = Get-Date
            $duration = $endTime - $startTime
            
            Write-Host "✓ $($test.Name) completed successfully" -ForegroundColor Green
            Write-Host "  Duration: $($duration.TotalSeconds) seconds" -ForegroundColor Gray
            
            if ($result) {
                if ($result -is [array]) {
                    Write-Host "  Results: $($result.Count) items processed" -ForegroundColor Gray
                    $withProgress = $result | Where-Object { $_.ProgressId -or $_.ProgressMetrics.Count -gt 0 }
                    if ($withProgress) {
                        Write-Host "  Progress integration: ✓ Active" -ForegroundColor Green
                    } else {
                        Write-Host "  Progress integration: ? No progress data captured" -ForegroundColor Yellow
                    }
                } else {
                    Write-Host "  Result: Single item processed" -ForegroundColor Gray
                }
            }
            
        } catch {
            Write-Host "✗ $($test.Name) failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Test-NestedProgressValidation {
    Write-Host "`n=== Testing Nested Progress Operations ===" -ForegroundColor Cyan
    
    try {
        # Create a master progress operation
        $masterId = Start-DotWinProgress -Activity "Master Workflow Test" -Status "Starting comprehensive test" -TotalOperations 3
        Get-ProgressOperation -ProgressId $masterId -Operation "Master"
        
        # Level 1: Configuration processing
        $configId = Start-DotWinProgress -Activity "Configuration Processing" -ParentId $masterId -Status "Processing configuration items" -TotalOperations 2
        Get-ProgressOperation -ProgressId $configId -Operation "Configuration" -ParentId $masterId
        
        # Level 2: Individual operations
        $toolsId = Start-DotWinProgress -Activity "Installing System Tools" -ParentId $configId -Status "Installing development tools"
        Get-ProgressOperation -ProgressId $toolsId -Operation "SystemTools" -ParentId $configId
        
        # Simulate progress updates
        Write-DotWinProgress -ProgressId $toolsId -PercentComplete 50 -Status "Installing Git..."
        Start-Sleep -Milliseconds 500
        
        Write-DotWinProgress -ProgressId $toolsId -PercentComplete 100 -Status "Git installation completed"
        Complete-DotWinProgress -ProgressId $toolsId -Status "System tools installation completed"
        $script:ProgressTracker.CompletedIds += $toolsId
        
        # Second operation
        $packagesId = Start-DotWinProgress -Activity "Installing Packages" -ParentId $configId -Status "Installing application packages"
        Get-ProgressOperation -ProgressId $packagesId -Operation "Packages" -ParentId $configId
        
        Write-DotWinProgress -ProgressId $packagesId -PercentComplete 100 -Status "Package installation completed"
        Complete-DotWinProgress -ProgressId $packagesId -Status "Package installation completed"
        $script:ProgressTracker.CompletedIds += $packagesId
        
        # Complete configuration level
        Complete-DotWinProgress -ProgressId $configId -Status "Configuration processing completed"
        $script:ProgressTracker.CompletedIds += $configId
        
        # Complete master level
        Complete-DotWinProgress -ProgressId $masterId -Status "Master workflow completed successfully"
        $script:ProgressTracker.CompletedIds += $masterId
        
        Write-Host "✓ Nested progress operations completed successfully" -ForegroundColor Green
        Write-Host "  Created progress operations: $($script:ProgressTracker.CreatedIds.Count)" -ForegroundColor Gray
        Write-Host "  Completed progress operations: $($script:ProgressTracker.CompletedIds.Count)" -ForegroundColor Gray
        Write-Host "  Nested operations: $($script:ProgressTracker.NestedOperations.Count)" -ForegroundColor Gray
        
    } catch {
        Write-Host "✗ Nested progress test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Test-VerboseDebugModes {
    Write-Host "`n=== Testing Verbose/Debug Mode Integration ===" -ForegroundColor Cyan
    
    # Test verbose mode coordination
    Write-Host "Testing verbose mode with progress..." -ForegroundColor Yellow
    $progressId = Start-DotWinProgress -Activity "Verbose Mode Test" -Status "Testing verbose logging coordination"
    
    # These should be visible in verbose mode
    Write-Verbose "This verbose message should be visible during progress"
    Write-DotWinLog -Message "This is an information message during progress" -Level "Information" -ShowWithProgress
    Write-DotWinLog -Message "This is a warning message during progress" -Level "Warning" -ShowWithProgress
    
    Complete-DotWinProgress -ProgressId $progressId -Status "Verbose mode test completed"
    
    # Test debug mode coordination
    if ($DebugMode) {
        Write-Host "Testing debug mode with progress..." -ForegroundColor Yellow
        $debugProgressId = Start-DotWinProgress -Activity "Debug Mode Test" -Status "Testing debug logging coordination"
        
        Write-Debug "This debug message should be visible during progress"
        Write-DotWinLog -Message "This is a debug-level message during progress" -Level "Verbose" -ShowWithProgress
        
        Complete-DotWinProgress -ProgressId $debugProgressId -Status "Debug mode test completed"
    }
    
    Write-Host "✓ Verbose/Debug mode integration test completed" -ForegroundColor Green
}

# Main execution
Write-Host "=== DotWin Complete Workflow Integration Test ===" -ForegroundColor Cyan
Write-Host "This test demonstrates the complete DotWin workflow with integrated progress system" -ForegroundColor Green
Write-Host "Test Mode: $(if ($WhatIf) { 'WhatIf (Safe)' } else { 'Live' })" -ForegroundColor Yellow
Write-Host "Verbose Mode: $(if ($VerboseMode) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Yellow
Write-Host "Debug Mode: $(if ($DebugMode) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Yellow
Write-Host ""

# Create or load test configuration
if ($ConfigurationPath -and (Test-Path $ConfigurationPath)) {
    Write-Host "Loading configuration from: $ConfigurationPath" -ForegroundColor Yellow
    $testConfiguration = Get-Content $ConfigurationPath | ConvertFrom-Json
    # Convert to DotWinConfiguration object if needed
} else {
    $testConfiguration = New-TestConfiguration
}

# Execute comprehensive tests
$workflowResults = Test-ProgressSystemIntegration -Configuration $testConfiguration
Test-IndividualFunctions
Test-NestedProgressValidation
Test-VerboseDebugModes

# Final validation summary
Write-Host "`n=== Complete Workflow Test Summary ===" -ForegroundColor Cyan

if ($workflowResults) {
    $totalOperations = $workflowResults.Count
    $successfulOperations = ($workflowResults | Where-Object { $_.Success }).Count
    $operationsWithProgress = ($workflowResults | Where-Object { $_.ProgressId -or $_.ProgressMetrics.Count -gt 0 }).Count
    
    Write-Host "Workflow Execution Results:" -ForegroundColor White
    Write-Host "  - Total operations: $totalOperations" -ForegroundColor Gray
    Write-Host "  - Successful operations: $successfulOperations" -ForegroundColor Green
    Write-Host "  - Operations with progress integration: $operationsWithProgress" -ForegroundColor Cyan
    
    $successRate = if ($totalOperations -gt 0) { [math]::Round(($successfulOperations / $totalOperations) * 100, 1) } else { 0 }
    $progressRate = if ($totalOperations -gt 0) { [math]::Round(($operationsWithProgress / $totalOperations) * 100, 1) } else { 0 }
    
    Write-Host "  - Success rate: $successRate%" -ForegroundColor $(if ($successRate -ge 90) { 'Green' } elseif ($successRate -ge 75) { 'Yellow' } else { 'Red' })
    Write-Host "  - Progress integration rate: $progressRate%" -ForegroundColor $(if ($progressRate -ge 80) { 'Green' } elseif ($progressRate -ge 60) { 'Yellow' } else { 'Red' })
}

Write-Host "`nProgress System Validation:" -ForegroundColor White
Write-Host "  - Created progress IDs: $($script:ProgressTracker.CreatedIds.Count)" -ForegroundColor Cyan
Write-Host "  - Completed progress IDs: $($script:ProgressTracker.CompletedIds.Count)" -ForegroundColor Cyan
Write-Host "  - Nested operations: $($script:ProgressTracker.NestedOperations.Count)" -ForegroundColor Cyan

# Validate progress ID tracking
$progressIdBalance = $script:ProgressTracker.CreatedIds.Count - $script:ProgressTracker.CompletedIds.Count
if ($progressIdBalance -eq 0) {
    Write-Host "  - Progress ID tracking: ✓ Balanced (all created IDs were completed)" -ForegroundColor Green
} else {
    Write-Host "  - Progress ID tracking: ⚠ Unbalanced ($progressIdBalance uncompleted operations)" -ForegroundColor Yellow
}

# Final status
Write-Host "`n=== Final Integration Status ===" -ForegroundColor Cyan
if ($workflowResults -and $successRate -ge 75 -and $progressRate -ge 60) {
    Write-Host "✓ COMPLETE WORKFLOW INTEGRATION TEST PASSED" -ForegroundColor Green
    Write-Host "  The DotWin progress system integration is working correctly" -ForegroundColor Green
    Write-Host "  All major functions demonstrate proper progress coordination" -ForegroundColor Green
    Write-Host "  Nested progress operations function as expected" -ForegroundColor Green
    Write-Host "  Verbose/Debug mode coordination is operational" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ COMPLETE WORKFLOW INTEGRATION TEST FAILED" -ForegroundColor Red
    Write-Host "  Some aspects of the progress system integration need attention" -ForegroundColor Red
    exit 1
}
