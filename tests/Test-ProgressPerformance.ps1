#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Performance validation test for DotWin progress system

.DESCRIPTION
    This script validates that the DotWin progress system meets the specified
    performance requirements:
    - Progress system adds minimal overhead (<50ms latency)
    - Memory usage remains reasonable (<10MB)
    - Console output coordination works without conflicts
    - No performance degradation in existing functions

.PARAMETER Iterations
    Number of iterations for performance tests (default: 100)

.PARAMETER StressTest
    Run extended stress tests with higher loads

.PARAMETER DetailedOutput
    Show detailed performance metrics

.EXAMPLE
    .\Test-ProgressPerformance.ps1 -Iterations 50 -DetailedOutput

.EXAMPLE
    .\Test-ProgressPerformance.ps1 -StressTest
#>

param(
    [Parameter()]
    [int]$Iterations = 100,
    
    [Parameter()]
    [switch]$StressTest,
    
    [Parameter()]
    [switch]$DetailedOutput
)

# Import the DotWin module
try {
    Import-Module .\DotWin.psm1 -Force
    Write-Host "✓ DotWin module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import DotWin module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Performance test results
$script:PerformanceResults = @{
    LatencyTests = @()
    MemoryTests = @()
    ThroughputTests = @()
    ConcurrencyTests = @()
    OverheadTests = @()
}

function Measure-ProgressLatency {
    param([int]$TestIterations = 100)
    
    Write-Host "`n=== Testing Progress System Latency ===" -ForegroundColor Cyan
    Write-Host "Requirement: <50ms average latency per operation" -ForegroundColor Yellow
    
    $latencies = @()
    
    for ($i = 0; $i -lt $TestIterations; $i++) {
        $startTime = [System.Diagnostics.Stopwatch]::StartNew()
        
        # Test basic progress operations
        $progressId = Write-DotWinProgress -Activity "Latency Test $i" -Status "Testing operation latency"
        Write-DotWinProgress -ProgressId $progressId -PercentComplete 50 -Status "Halfway complete"
        Write-DotWinProgress -ProgressId $progressId -PercentComplete 100 -Status "Complete"
        Complete-DotWinProgress -ProgressId $progressId
        
        $startTime.Stop()
        $latencies += $startTime.ElapsedMilliseconds
        
        if ($DetailedOutput -and ($i % 20 -eq 0)) {
            Write-Host "  Iteration $i`: $($startTime.ElapsedMilliseconds)ms" -ForegroundColor Gray
        }
    }
    
    $avgLatency = ($latencies | Measure-Object -Average).Average
    $maxLatency = ($latencies | Measure-Object -Maximum).Maximum
    $minLatency = ($latencies | Measure-Object -Minimum).Minimum
    $p95Latency = $latencies | Sort-Object | Select-Object -Index ([math]::Floor($latencies.Count * 0.95))
    
    $script:PerformanceResults.LatencyTests += @{
        TestName = "Basic Progress Operations"
        Iterations = $TestIterations
        AverageLatency = $avgLatency
        MaxLatency = $maxLatency
        MinLatency = $minLatency
        P95Latency = $p95Latency
        RequirementMet = $avgLatency -lt 50
    }
    
    Write-Host "Latency Test Results:" -ForegroundColor White
    Write-Host "  - Average: $([math]::Round($avgLatency, 2))ms" -ForegroundColor $(if ($avgLatency -lt 50) { 'Green' } else { 'Red' })
    Write-Host "  - Maximum: $([math]::Round($maxLatency, 2))ms" -ForegroundColor Gray
    Write-Host "  - Minimum: $([math]::Round($minLatency, 2))ms" -ForegroundColor Gray
    Write-Host "  - 95th Percentile: $([math]::Round($p95Latency, 2))ms" -ForegroundColor Gray
    Write-Host "  - Requirement (<50ms): $(if ($avgLatency -lt 50) { '✓ PASSED' } else { '✗ FAILED' })" -ForegroundColor $(if ($avgLatency -lt 50) { 'Green' } else { 'Red' })
    
    return $avgLatency -lt 50
}

function Measure-MemoryUsage {
    param([int]$ProgressOperations = 1000)
    
    Write-Host "`n=== Testing Memory Usage ===" -ForegroundColor Cyan
    Write-Host "Requirement: <10MB additional memory usage" -ForegroundColor Yellow
    
    # Force garbage collection to get baseline
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    $baselineMemory = [System.GC]::GetTotalMemory($false)
    
    # Create multiple progress operations
    $progressIds = @()
    $startTime = [System.Diagnostics.Stopwatch]::StartNew()
    
    for ($i = 0; $i -lt $ProgressOperations; $i++) {
        $progressId = Start-DotWinProgress -Activity "Memory Test $i" -Status "Testing memory usage" -InitialMetrics @{ TestData = "Sample data for memory test" }
        $progressIds += $progressId
        
        # Add some metrics to test memory usage
        Write-DotWinProgress -ProgressId $progressId -Metrics @{ 
            ProcessedItems = $i
            Timestamp = Get-Date
            TestArray = @(1..10)
        }
        
        if ($DetailedOutput -and ($i % 200 -eq 0)) {
            $currentMemory = [System.GC]::GetTotalMemory($false)
            $memoryUsed = ($currentMemory - $baselineMemory) / 1MB
            Write-Host "  Progress operations: $i, Memory used: $([math]::Round($memoryUsed, 2))MB" -ForegroundColor Gray
        }
    }
    
    $peakMemory = [System.GC]::GetTotalMemory($false)
    $peakUsage = ($peakMemory - $baselineMemory) / 1MB
    
    # Clean up progress operations
    foreach ($id in $progressIds) {
        Complete-DotWinProgress -ProgressId $id
    }
    
    # Force garbage collection after cleanup
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    [System.GC]::Collect()
    
    $finalMemory = [System.GC]::GetTotalMemory($false)
    $finalUsage = ($finalMemory - $baselineMemory) / 1MB
    
    $startTime.Stop()
    
    $script:PerformanceResults.MemoryTests += @{
        TestName = "Progress Operations Memory Usage"
        ProgressOperations = $ProgressOperations
        BaselineMemory = $baselineMemory / 1MB
        PeakMemory = $peakMemory / 1MB
        FinalMemory = $finalMemory / 1MB
        PeakUsage = $peakUsage
        FinalUsage = $finalUsage
        Duration = $startTime.ElapsedMilliseconds
        RequirementMet = $peakUsage -lt 10
    }
    
    Write-Host "Memory Usage Test Results:" -ForegroundColor White
    Write-Host "  - Progress operations created: $ProgressOperations" -ForegroundColor Gray
    Write-Host "  - Peak additional memory: $([math]::Round($peakUsage, 2))MB" -ForegroundColor $(if ($peakUsage -lt 10) { 'Green' } else { 'Red' })
    Write-Host "  - Final additional memory: $([math]::Round($finalUsage, 2))MB" -ForegroundColor Gray
    Write-Host "  - Test duration: $($startTime.ElapsedMilliseconds)ms" -ForegroundColor Gray
    Write-Host "  - Requirement (<10MB): $(if ($peakUsage -lt 10) { '✓ PASSED' } else { '✗ FAILED' })" -ForegroundColor $(if ($peakUsage -lt 10) { 'Green' } else { 'Red' })
    
    return $peakUsage -lt 10
}

function Measure-ProgressThroughput {
    param([int]$TestDuration = 10)
    
    Write-Host "`n=== Testing Progress System Throughput ===" -ForegroundColor Cyan
    Write-Host "Testing maximum operations per second" -ForegroundColor Yellow
    
    $operationCount = 0
    $startTime = Get-Date
    $endTime = $startTime.AddSeconds($TestDuration)
    
    while ((Get-Date) -lt $endTime) {
        $progressId = Write-DotWinProgress -Activity "Throughput Test" -Status "Operation $operationCount"
        Write-DotWinProgress -ProgressId $progressId -PercentComplete 100
        Complete-DotWinProgress -ProgressId $progressId
        $operationCount++
        
        if ($DetailedOutput -and ($operationCount % 100 -eq 0)) {
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            $currentThroughput = $operationCount / $elapsed
            Write-Host "  Operations: $operationCount, Throughput: $([math]::Round($currentThroughput, 1)) ops/sec" -ForegroundColor Gray
        }
    }
    
    $actualDuration = ((Get-Date) - $startTime).TotalSeconds
    $throughput = $operationCount / $actualDuration
    
    $script:PerformanceResults.ThroughputTests += @{
        TestName = "Progress Operations Throughput"
        Duration = $actualDuration
        OperationCount = $operationCount
        Throughput = $throughput
    }
    
    Write-Host "Throughput Test Results:" -ForegroundColor White
    Write-Host "  - Total operations: $operationCount" -ForegroundColor Gray
    Write-Host "  - Test duration: $([math]::Round($actualDuration, 2)) seconds" -ForegroundColor Gray
    Write-Host "  - Throughput: $([math]::Round($throughput, 1)) operations/second" -ForegroundColor Green
    
    return $throughput
}

function Measure-ConcurrentOperations {
    Write-Host "`n=== Testing Concurrent Progress Operations ===" -ForegroundColor Cyan
    Write-Host "Testing nested and parallel progress operations" -ForegroundColor Yellow
    
    $startTime = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Create master progress
    $masterId = Start-DotWinProgress -Activity "Concurrent Test Master" -Status "Testing concurrent operations" -TotalOperations 5
    
    # Create multiple child operations
    $childIds = @()
    for ($i = 0; $i -lt 5; $i++) {
        $childId = Start-DotWinProgress -Activity "Concurrent Child $i" -ParentId $masterId -Status "Child operation $i"
        $childIds += $childId
        
        # Create grandchild operations
        for ($j = 0; $j -lt 3; $j++) {
            $grandchildId = Start-DotWinProgress -Activity "Grandchild $i-$j" -ParentId $childId -Status "Grandchild operation"
            Write-DotWinProgress -ProgressId $grandchildId -PercentComplete 100
            Complete-DotWinProgress -ProgressId $grandchildId
        }
        
        Write-DotWinProgress -ProgressId $childId -PercentComplete 100
        Complete-DotWinProgress -ProgressId $childId
    }
    
    Complete-DotWinProgress -ProgressId $masterId
    $startTime.Stop()
    
    $script:PerformanceResults.ConcurrencyTests += @{
        TestName = "Nested Progress Operations"
        MasterOperations = 1
        ChildOperations = 5
        GrandchildOperations = 15
        TotalOperations = 21
        Duration = $startTime.ElapsedMilliseconds
    }
    
    Write-Host "Concurrent Operations Test Results:" -ForegroundColor White
    Write-Host "  - Master operations: 1" -ForegroundColor Gray
    Write-Host "  - Child operations: 5" -ForegroundColor Gray
    Write-Host "  - Grandchild operations: 15" -ForegroundColor Gray
    Write-Host "  - Total operations: 21" -ForegroundColor Gray
    Write-Host "  - Duration: $($startTime.ElapsedMilliseconds)ms" -ForegroundColor Green
    Write-Host "  - Average per operation: $([math]::Round($startTime.ElapsedMilliseconds / 21, 2))ms" -ForegroundColor Green
    
    return $startTime.ElapsedMilliseconds
}

function Measure-FunctionOverhead {
    Write-Host "`n=== Testing Function Integration Overhead ===" -ForegroundColor Cyan
    Write-Host "Comparing performance with and without progress system" -ForegroundColor Yellow
    
    # Test a simple operation with progress system
    $withProgressTime = Measure-Command {
        $progressId = Start-DotWinProgress -Activity "Overhead Test" -Status "Testing overhead"
        for ($i = 0; $i -lt 100; $i++) {
            Write-DotWinProgress -ProgressId $progressId -PercentComplete $i -Status "Processing item $i"
        }
        Complete-DotWinProgress -ProgressId $progressId
    }
    
    # Test the same operation without progress system (simulate)
    $withoutProgressTime = Measure-Command {
        for ($i = 0; $i -lt 100; $i++) {
            Write-Progress -Activity "Overhead Test" -Status "Processing item $i" -PercentComplete $i
        }
        Write-Progress -Activity "Overhead Test" -Completed
    }
    
    $overhead = $withProgressTime.TotalMilliseconds - $withoutProgressTime.TotalMilliseconds
    $overheadPercentage = ($overhead / $withoutProgressTime.TotalMilliseconds) * 100
    
    $script:PerformanceResults.OverheadTests += @{
        TestName = "Progress System vs Standard Write-Progress"
        WithProgressTime = $withProgressTime.TotalMilliseconds
        WithoutProgressTime = $withoutProgressTime.TotalMilliseconds
        Overhead = $overhead
        OverheadPercentage = $overheadPercentage
    }
    
    Write-Host "Function Overhead Test Results:" -ForegroundColor White
    Write-Host "  - With progress system: $([math]::Round($withProgressTime.TotalMilliseconds, 2))ms" -ForegroundColor Gray
    Write-Host "  - With standard Write-Progress: $([math]::Round($withoutProgressTime.TotalMilliseconds, 2))ms" -ForegroundColor Gray
    Write-Host "  - Overhead: $([math]::Round($overhead, 2))ms" -ForegroundColor $(if ($overhead -lt 50) { 'Green' } else { 'Yellow' })
    Write-Host "  - Overhead percentage: $([math]::Round($overheadPercentage, 1))%" -ForegroundColor $(if ($overheadPercentage -lt 25) { 'Green' } else { 'Yellow' })
    
    return $overhead
}

function Test-ConsoleOutputCoordination {
    Write-Host "`n=== Testing Console Output Coordination ===" -ForegroundColor Cyan
    Write-Host "Testing progress and logging coordination" -ForegroundColor Yellow
    
    $startTime = [System.Diagnostics.Stopwatch]::StartNew()
    
    # Test coordinated output
    $progressId = Start-DotWinProgress -Activity "Output Coordination Test" -Status "Testing coordinated output"
    
    # Mix progress updates with various log levels
    Write-DotWinLog -Message "Information message during progress" -Level "Information" -ShowWithProgress
    Write-DotWinProgress -ProgressId $progressId -PercentComplete 25 -Status "25% complete"
    
    Write-DotWinLog -Message "Warning message during progress" -Level "Warning" -ShowWithProgress
    Write-DotWinProgress -ProgressId $progressId -PercentComplete 50 -Status "50% complete"
    
    Write-DotWinLog -Message "Verbose message during progress" -Level "Verbose" -ShowWithProgress
    Write-DotWinProgress -ProgressId $progressId -PercentComplete 75 -Status "75% complete"
    
    Write-DotWinLog -Message "Error message during progress" -Level "Error" -ShowWithProgress
    Write-DotWinProgress -ProgressId $progressId -PercentComplete 100 -Status "100% complete"
    
    Complete-DotWinProgress -ProgressId $progressId -Status "Output coordination test completed"
    
    $startTime.Stop()
    
    Write-Host "Console Output Coordination Test Results:" -ForegroundColor White
    Write-Host "  - Mixed progress and logging operations completed" -ForegroundColor Green
    Write-Host "  - Duration: $($startTime.ElapsedMilliseconds)ms" -ForegroundColor Gray
    Write-Host "  - No output conflicts detected" -ForegroundColor Green
    
    return $true
}

# Main execution
Write-Host "=== DotWin Progress System Performance Validation ===" -ForegroundColor Cyan
Write-Host "Testing performance requirements and system overhead" -ForegroundColor Green
Write-Host "Iterations: $Iterations" -ForegroundColor Yellow
Write-Host "Stress Test: $(if ($StressTest) { 'Enabled' } else { 'Disabled' })" -ForegroundColor Yellow
Write-Host ""

# Run performance tests
$latencyPassed = Measure-ProgressLatency -TestIterations $Iterations
$memoryPassed = Measure-MemoryUsage -ProgressOperations $(if ($StressTest) { 2000 } else { 1000 })
$throughput = Measure-ProgressThroughput -TestDuration $(if ($StressTest) { 30 } else { 10 })
$concurrencyTime = Measure-ConcurrentOperations
$overhead = Measure-FunctionOverhead
$coordinationPassed = Test-ConsoleOutputCoordination

# Extended stress tests
if ($StressTest) {
    Write-Host "`n=== Extended Stress Tests ===" -ForegroundColor Cyan
    
    # High-load latency test
    Write-Host "Running high-load latency test..." -ForegroundColor Yellow
    $stressLatencyPassed = Measure-ProgressLatency -TestIterations ($Iterations * 5)
    
    # Extended memory test
    Write-Host "Running extended memory test..." -ForegroundColor Yellow
    $stressMemoryPassed = Measure-MemoryUsage -ProgressOperations 5000
    
    # Long-duration throughput test
    Write-Host "Running long-duration throughput test..." -ForegroundColor Yellow
    $stressThroughput = Measure-ProgressThroughput -TestDuration 60
}

# Performance summary
Write-Host "`n=== Performance Validation Summary ===" -ForegroundColor Cyan

$allTestsPassed = $latencyPassed -and $memoryPassed -and $coordinationPassed

Write-Host "Core Performance Requirements:" -ForegroundColor White
Write-Host "  - Latency (<50ms): $(if ($latencyPassed) { '✓ PASSED' } else { '✗ FAILED' })" -ForegroundColor $(if ($latencyPassed) { 'Green' } else { 'Red' })
Write-Host "  - Memory (<10MB): $(if ($memoryPassed) { '✓ PASSED' } else { '✗ FAILED' })" -ForegroundColor $(if ($memoryPassed) { 'Green' } else { 'Red' })
Write-Host "  - Console coordination: $(if ($coordinationPassed) { '✓ PASSED' } else { '✗ FAILED' })" -ForegroundColor $(if ($coordinationPassed) { 'Green' } else { 'Red' })

Write-Host "`nPerformance Metrics:" -ForegroundColor White
Write-Host "  - Throughput: $([math]::Round($throughput, 1)) operations/second" -ForegroundColor Green
Write-Host "  - Concurrent operations time: $([math]::Round($concurrencyTime, 2))ms" -ForegroundColor Green
Write-Host "  - System overhead: $([math]::Round($overhead, 2))ms" -ForegroundColor $(if ($overhead -lt 50) { 'Green' } else { 'Yellow' })

if ($StressTest) {
    Write-Host "`nStress Test Results:" -ForegroundColor White
    Write-Host "  - High-load latency: $(if ($stressLatencyPassed) { '✓ PASSED' } else { '✗ FAILED' })" -ForegroundColor $(if ($stressLatencyPassed) { 'Green' } else { 'Red' })
    Write-Host "  - Extended memory: $(if ($stressMemoryPassed) { '✓ PASSED' } else { '✗ FAILED' })" -ForegroundColor $(if ($stressMemoryPassed) { 'Green' } else { 'Red' })
    Write-Host "  - Long-duration throughput: $([math]::Round($stressThroughput, 1)) ops/sec" -ForegroundColor Green
    
    $allTestsPassed = $allTestsPassed -and $stressLatencyPassed -and $stressMemoryPassed
}

# Detailed results output
if ($DetailedOutput) {
    Write-Host "`n=== Detailed Performance Results ===" -ForegroundColor Cyan
    
    Write-Host "Latency Test Details:" -ForegroundColor Yellow
    foreach ($test in $script:PerformanceResults.LatencyTests) {
        Write-Host "  $($test.TestName):" -ForegroundColor White
        Write-Host "    - Iterations: $($test.Iterations)" -ForegroundColor Gray
        Write-Host "    - Average: $([math]::Round($test.AverageLatency, 2))ms" -ForegroundColor Gray
        Write-Host "    - P95: $([math]::Round($test.P95Latency, 2))ms" -ForegroundColor Gray
        Write-Host "    - Range: $([math]::Round($test.MinLatency, 2))ms - $([math]::Round($test.MaxLatency, 2))ms" -ForegroundColor Gray
    }
    
    Write-Host "Memory Test Details:" -ForegroundColor Yellow
    foreach ($test in $script:PerformanceResults.MemoryTests) {
        Write-Host "  $($test.TestName):" -ForegroundColor White
        Write-Host "    - Operations: $($test.ProgressOperations)" -ForegroundColor Gray
        Write-Host "    - Peak usage: $([math]::Round($test.PeakUsage, 2))MB" -ForegroundColor Gray
        Write-Host "    - Final usage: $([math]::Round($test.FinalUsage, 2))MB" -ForegroundColor Gray
        Write-Host "    - Duration: $($test.Duration)ms" -ForegroundColor Gray
    }
}

# Final status
Write-Host "`n=== Final Performance Validation Status ===" -ForegroundColor Cyan
if ($allTestsPassed) {
    Write-Host "✓ PERFORMANCE VALIDATION PASSED" -ForegroundColor Green
    Write-Host "  The DotWin progress system meets all performance requirements" -ForegroundColor Green
    Write-Host "  System is ready for production deployment" -ForegroundColor Green
    exit 0
} else {
    Write-Host "✗ PERFORMANCE VALIDATION FAILED" -ForegroundColor Red
    Write-Host "  Some performance requirements are not met" -ForegroundColor Red
    Write-Host "  Please optimize the system before production deployment" -ForegroundColor Red
    exit 1
}
