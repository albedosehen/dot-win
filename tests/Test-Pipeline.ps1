#!/usr/bin/env pwsh

# Test script to verify DotWin pipeline functionality
# This script tests the pipeline flow: Get-DotWinStatus -> Get-DotWinRecommendations -> ConvertTo-DotWinConfiguration

Write-Host "Testing DotWin Pipeline Functionality" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green

# Import the DotWin module
try {
    Import-Module .\DotWin.psd1 -Force
    Write-Host "✓ DotWin module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import DotWin module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`nTest 1: Basic pipeline flow" -ForegroundColor Yellow
Write-Host "----------------------------"

try {
    # Test the basic pipeline: Status -> Recommendations -> Configuration
    Write-Host "Testing: Get-DotWinStatus -IncludeSystemInfo | Get-DotWinRecommendations | ConvertTo-DotWinConfiguration"
    
    $result = Get-DotWinStatus -IncludeSystemInfo | Get-DotWinRecommendations | ConvertTo-DotWinConfiguration -ConfigurationName "Pipeline Test Config"
    
    if ($result) {
        Write-Host "✓ Pipeline executed successfully" -ForegroundColor Green
        Write-Host "  Configuration Name: $($result.Name)" -ForegroundColor Cyan
        Write-Host "  Items Count: $($result.Items.Count)" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Pipeline returned null result" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Pipeline test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 2: Individual function tests" -ForegroundColor Yellow
Write-Host "----------------------------------"

try {
    # Test Get-DotWinStatus
    Write-Host "Testing Get-DotWinStatus..."
    $status = Get-DotWinStatus -IncludeSystemInfo
    if ($status) {
        Write-Host "✓ Get-DotWinStatus works" -ForegroundColor Green
        Write-Host "  Computer: $($status.ComputerName)" -ForegroundColor Cyan
        Write-Host "  OS: $($status.OperatingSystem)" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Get-DotWinStatus failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Get-DotWinStatus error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    # Test Get-DotWinRecommendations with explicit profile
    Write-Host "Testing Get-DotWinRecommendations..."
    $systemProfile = Get-DotWinSystemProfile
    $recommendations = Get-DotWinRecommendations -SystemProfile $systemProfile
    if ($recommendations) {
        Write-Host "✓ Get-DotWinRecommendations works" -ForegroundColor Green
        Write-Host "  Recommendations Count: $($recommendations.Count)" -ForegroundColor Cyan
    } else {
        Write-Host "✗ Get-DotWinRecommendations failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Get-DotWinRecommendations error: $($_.Exception.Message)" -ForegroundColor Red
}

try {
    # Test ConvertTo-DotWinConfiguration with recommendations
    Write-Host "Testing ConvertTo-DotWinConfiguration..."
    if ($recommendations) {
        $config = $recommendations | ConvertTo-DotWinConfiguration -ConfigurationName "Test Config"
        if ($config) {
            Write-Host "✓ ConvertTo-DotWinConfiguration works" -ForegroundColor Green
            Write-Host "  Config Items: $($config.Items.Count)" -ForegroundColor Cyan
        } else {
            Write-Host "✗ ConvertTo-DotWinConfiguration failed" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠ Skipping ConvertTo-DotWinConfiguration (no recommendations)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ ConvertTo-DotWinConfiguration error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 3: Pipeline parameter binding" -ForegroundColor Yellow
Write-Host "-----------------------------------"

try {
    # Test parameter binding specifically
    Write-Host "Testing parameter binding with Get-DotWinStatus..."
    $statusWithProfile = Get-DotWinStatus -IncludeSystemInfo
    
    if ($statusWithProfile.ConfigurationStatus.SystemProfile) {
        Write-Host "✓ SystemProfile included in status" -ForegroundColor Green
        
        # Test piping status to recommendations
        $pipelineRecs = $statusWithProfile | Get-DotWinRecommendations
        if ($pipelineRecs) {
            Write-Host "✓ Status -> Recommendations pipeline works" -ForegroundColor Green
            Write-Host "  Pipeline Recommendations: $($pipelineRecs.Count)" -ForegroundColor Cyan
        } else {
            Write-Host "✗ Status -> Recommendations pipeline failed" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠ No SystemProfile in status object" -ForegroundColor Yellow
    }
} catch {
    Write-Host "✗ Parameter binding test error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nTest 4: Export pipeline support" -ForegroundColor Yellow
Write-Host "--------------------------------"

try {
    # Test Export-DotWinConfiguration with pipeline
    Write-Host "Testing Export-DotWinConfiguration pipeline support..."
    $exportPath = "test-export-config.json"
    
    $statusWithProfile | Export-DotWinConfiguration -OutputPath $exportPath -IncludePackages -IncludeSettings -Force
    
    if (Test-Path $exportPath) {
        Write-Host "✓ Export-DotWinConfiguration pipeline works" -ForegroundColor Green
        $exportedConfig = Get-Content $exportPath | ConvertFrom-Json
        Write-Host "  Exported Items: $($exportedConfig.items.Count)" -ForegroundColor Cyan
        
        # Clean up
        Remove-Item $exportPath -ErrorAction SilentlyContinue
    } else {
        Write-Host "✗ Export-DotWinConfiguration pipeline failed" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Export pipeline test error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`nPipeline Testing Complete!" -ForegroundColor Green
Write-Host "=========================" -ForegroundColor Green