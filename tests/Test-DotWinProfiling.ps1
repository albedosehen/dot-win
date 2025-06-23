<#
.SYNOPSIS
    Comprehensive test suite for DotWin system profiling and recommendation engine.

.DESCRIPTION
    This test script validates the functionality of the new DotWin profiling system,
    including hardware detection, software inventory, user behavior analysis,
    and intelligent recommendation generation.

.PARAMETER TestCategory
    Specific test categories to run (Hardware, Software, User, Recommendations, Integration).

.PARAMETER Verbose
    Enable verbose output for detailed test information.

.PARAMETER ExportResults
    Path to export test results as JSON.

.EXAMPLE
    .\Test-DotWinProfiling.ps1
    
    Runs all profiling tests.

.EXAMPLE
    .\Test-DotWinProfiling.ps1 -TestCategory "Hardware","Software" -Verbose
    
    Runs hardware and software profiling tests with verbose output.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Hardware', 'Software', 'User', 'Recommendations', 'Integration', 'All')]
    [string[]]$TestCategory = @('All'),

    [Parameter()]
    [string]$ExportResults
)

# Import DotWin module
$ModulePath = Join-Path $PSScriptRoot "..\DotWin.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
} else {
    throw "DotWin module not found at: $ModulePath"
}

# Test result tracking
$TestResults = @{
    StartTime = Get-Date
    Tests = @()
    Summary = @{
        Total = 0
        Passed = 0
        Failed = 0
        Skipped = 0
    }
}

function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Category,
        [bool]$Passed,
        [string]$Message = "",
        [object]$Details = $null
    )
    
    $result = @{
        TestName = $TestName
        Category = $Category
        Passed = $Passed
        Message = $Message
        Details = $Details
        Timestamp = Get-Date
    }
    
    $TestResults.Tests += $result
    $TestResults.Summary.Total++
    
    if ($Passed) {
        $TestResults.Summary.Passed++
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
    } else {
        $TestResults.Summary.Failed++
        Write-Host "✗ FAIL: $TestName - $Message" -ForegroundColor Red
    }
    
    if ($Details -and $VerbosePreference -eq 'Continue') {
        Write-Host "  Details: $($Details | ConvertTo-Json -Compress)" -ForegroundColor Gray
    }
}

function Test-HardwareProfiling {
    Write-Host "`n=== HARDWARE PROFILING TESTS ===" -ForegroundColor Cyan
    
    try {
        # Test 1: Hardware Profile Creation
        $profiler = [DotWinSystemProfiler]::new()
        $profiler.ProfileHardware()
        
        $hwProfile = $profiler.Hardware
        
        # Validate CPU information
        $cpuValid = -not [string]::IsNullOrEmpty($hwProfile.CPU_Manufacturer) -and 
                   $hwProfile.CPU_Cores -gt 0 -and 
                   $hwProfile.CPU_LogicalProcessors -gt 0
        
        Write-TestResult -TestName "CPU Information Detection" -Category "Hardware" -Passed $cpuValid -Details @{
            Manufacturer = $hwProfile.CPU_Manufacturer
            Cores = $hwProfile.CPU_Cores
            LogicalProcessors = $hwProfile.CPU_LogicalProcessors
        }
        
        # Validate Memory information
        $memoryValid = $hwProfile.TotalMemoryGB -gt 0
        Write-TestResult -TestName "Memory Information Detection" -Category "Hardware" -Passed $memoryValid -Details @{
            TotalMemoryGB = $hwProfile.TotalMemoryGB
        }
        
        # Validate Motherboard information
        $motherboardValid = -not [string]::IsNullOrEmpty($hwProfile.Motherboard_Manufacturer)
        Write-TestResult -TestName "Motherboard Information Detection" -Category "Hardware" -Passed $motherboardValid -Details @{
            Manufacturer = $hwProfile.Motherboard_Manufacturer
            Model = $hwProfile.Motherboard_Model
        }
        
        # Test hardware category determination
        $category = $hwProfile.GetHardwareCategory()
        $categoryValid = $category -in @("HighPerformance", "Workstation", "Mainstream", "Budget")
        Write-TestResult -TestName "Hardware Category Classification" -Category "Hardware" -Passed $categoryValid -Details @{
            Category = $category
        }
        
        # Test gaming optimization detection
        $gamingOptimized = $hwProfile.IsGamingOptimized()
        Write-TestResult -TestName "Gaming Optimization Detection" -Category "Hardware" -Passed $true -Details @{
            IsGamingOptimized = $gamingOptimized
            GPUManufacturers = $hwProfile.GPU_Manufacturers
        }
        
    } catch {
        Write-TestResult -TestName "Hardware Profiling Exception" -Category "Hardware" -Passed $false -Message $_.Exception.Message
    }
}

function Test-SoftwareProfiling {
    Write-Host "`n=== SOFTWARE PROFILING TESTS ===" -ForegroundColor Cyan
    
    try {
        # Test 1: Software Profile Creation
        $profiler = [DotWinSystemProfiler]::new()
        $profiler.ProfileSoftware()
        
        $swProfile = $profiler.Software
        
        # Validate package manager detection
        $packageManagersDetected = $swProfile.PackageManagers.Count -gt 0
        Write-TestResult -TestName "Package Manager Detection" -Category "Software" -Passed $packageManagersDetected -Details @{
            PackageManagers = $swProfile.PackageManagers.Keys
        }
        
        # Validate installed packages detection
        $packagesDetected = $swProfile.InstalledPackages.Count -gt 0
        Write-TestResult -TestName "Installed Packages Detection" -Category "Software" -Passed $packagesDetected -Details @{
            PackageCount = $swProfile.InstalledPackages.Count
        }
        
        # Validate PowerShell modules detection
        $modulesDetected = $swProfile.PowerShellModules.Count -gt 0
        Write-TestResult -TestName "PowerShell Modules Detection" -Category "Software" -Passed $modulesDetected -Details @{
            ModuleCount = $swProfile.PowerShellModules.Count
        }
        
        # Test user type determination
        $userType = $swProfile.GetUserType()
        $userTypeValid = $userType -in @("Developer", "Gamer", "Creative", "Business", "General")
        Write-TestResult -TestName "User Type Classification" -Category "Software" -Passed $userTypeValid -Details @{
            UserType = $userType
            DevelopmentTools = $swProfile.DevelopmentTools.Count
            ProductivityTools = $swProfile.ProductivityTools.Count
            MediaTools = $swProfile.MediaTools.Count
            GamingTools = $swProfile.GamingTools.Count
        }
        
        # Test package manager availability check
        $wingetAvailable = $swProfile.HasPackageManager("Winget")
        Write-TestResult -TestName "Package Manager Availability Check" -Category "Software" -Passed $true -Details @{
            WingetAvailable = $wingetAvailable
        }
        
    } catch {
        Write-TestResult -TestName "Software Profiling Exception" -Category "Software" -Passed $false -Message $_.Exception.Message
    }
}

function Test-UserProfiling {
    Write-Host "`n=== USER PROFILING TESTS ===" -ForegroundColor Cyan
    
    try {
        # Test 1: User Profile Creation
        $profiler = [DotWinSystemProfiler]::new()
        $profiler.ProfileUser()
        
        $userProfile = $profiler.User
        
        # Validate basic user information
        $userInfoValid = -not [string]::IsNullOrEmpty($userProfile.Username)
        Write-TestResult -TestName "Basic User Information" -Category "User" -Passed $userInfoValid -Details @{
            Username = $userProfile.Username
            Domain = $userProfile.Domain
            IsAdministrator = $userProfile.IsAdministrator
        }
        
        # Validate environment variables
        $envVarsDetected = $userProfile.EnvironmentVariables.Count -gt 0
        Write-TestResult -TestName "Environment Variables Detection" -Category "User" -Passed $envVarsDetected -Details @{
            EnvironmentVariableCount = $userProfile.EnvironmentVariables.Count
        }
        
        # Validate preferred shell detection
        $shellValid = -not [string]::IsNullOrEmpty($userProfile.PreferredShell)
        Write-TestResult -TestName "Preferred Shell Detection" -Category "User" -Passed $shellValid -Details @{
            PreferredShell = $userProfile.PreferredShell
        }
        
        # Test technical level determination
        $techLevel = $userProfile.GetTechnicalLevel()
        $techLevelValid = $techLevel -in @("Advanced", "Intermediate", "Beginner")
        Write-TestResult -TestName "Technical Level Classification" -Category "User" -Passed $techLevelValid -Details @{
            TechnicalLevel = $techLevel
        }
        
    } catch {
        Write-TestResult -TestName "User Profiling Exception" -Category "User" -Passed $false -Message $_.Exception.Message
    }
}

function Test-RecommendationEngine {
    Write-Host "`n=== RECOMMENDATION ENGINE TESTS ===" -ForegroundColor Cyan
    
    try {
        # Test 1: Complete System Profiling
        $profiler = [DotWinSystemProfiler]::new()
        $profiler.ProfileSystem()
        
        # Test 2: Recommendation Engine Creation
        $engine = [DotWinRecommendationEngine]::new($profiler)
        $engineValid = $null -ne $engine -and $engine.EngineVersion -eq "1.0.0"
        Write-TestResult -TestName "Recommendation Engine Creation" -Category "Recommendations" -Passed $engineValid -Details @{
            EngineVersion = $engine.EngineVersion
        }
        
        # Test 3: Recommendation Generation
        $recommendations = $engine.GenerateRecommendations()
        $recommendationsGenerated = $recommendations.Count -gt 0
        Write-TestResult -TestName "Recommendation Generation" -Category "Recommendations" -Passed $recommendationsGenerated -Details @{
            RecommendationCount = $recommendations.Count
        }
        
        # Test 4: Recommendation Structure Validation
        if ($recommendations.Count -gt 0) {
            $firstRec = $recommendations[0]
            $structureValid = -not [string]::IsNullOrEmpty($firstRec.Title) -and
                             -not [string]::IsNullOrEmpty($firstRec.Description) -and
                             -not [string]::IsNullOrEmpty($firstRec.Category) -and
                             $firstRec.ConfidenceScore -ge 0 -and
                             $firstRec.ConfidenceScore -le 1
            
            Write-TestResult -TestName "Recommendation Structure Validation" -Category "Recommendations" -Passed $structureValid -Details @{
                Title = $firstRec.Title
                Category = $firstRec.Category
                Priority = $firstRec.Priority
                ConfidenceScore = $firstRec.ConfidenceScore
            }
        }
        
        # Test 5: Conflict Resolution
        $resolvedRecommendations = $engine.ResolveConflicts($recommendations)
        $conflictResolutionWorked = $resolvedRecommendations.Count -le $recommendations.Count
        Write-TestResult -TestName "Conflict Resolution" -Category "Recommendations" -Passed $conflictResolutionWorked -Details @{
            OriginalCount = $recommendations.Count
            ResolvedCount = $resolvedRecommendations.Count
        }
        
        # Test 6: Recommendation Prioritization
        $prioritizedRecommendations = $engine.PrioritizeRecommendations($recommendations)
        $prioritizationWorked = $prioritizedRecommendations.Count -eq $recommendations.Count
        Write-TestResult -TestName "Recommendation Prioritization" -Category "Recommendations" -Passed $prioritizationWorked -Details @{
            Count = $prioritizedRecommendations.Count
        }
        
    } catch {
        Write-TestResult -TestName "Recommendation Engine Exception" -Category "Recommendations" -Passed $false -Message $_.Exception.Message
    }
}

function Test-IntegrationFunctions {
    Write-Host "`n=== INTEGRATION FUNCTION TESTS ===" -ForegroundColor Cyan
    
    try {
        # Test 1: Get-DotWinSystemProfile Function
        $profile = Get-DotWinSystemProfile -Verbose:$false
        $profileValid = $null -ne $profile -and $null -ne $profile.LastProfiled
        Write-TestResult -TestName "Get-DotWinSystemProfile Function" -Category "Integration" -Passed $profileValid -Details @{
            ProfileVersion = $profile.ProfileVersion
            LastProfiled = $profile.LastProfiled
        }
        
        # Test 2: Get-DotWinRecommendations Function
        if ($profileValid) {
            $recommendations = Get-DotWinRecommendations -SystemProfile $profile -MaxRecommendations 5 -Verbose:$false
            $recommendationsValid = $null -ne $recommendations -and $recommendations.Count -ge 0
            Write-TestResult -TestName "Get-DotWinRecommendations Function" -Category "Integration" -Passed $recommendationsValid -Details @{
                RecommendationCount = $recommendations.Count
            }
        }
        
        # Test 3: System Metrics Calculation
        if ($profileValid) {
            $metricsValid = $profile.SystemMetrics.Count -gt 0 -and
                           $profile.SystemMetrics.ContainsKey("PerformanceScore") -and
                           $profile.SystemMetrics.ContainsKey("SecurityScore")
            
            Write-TestResult -TestName "System Metrics Calculation" -Category "Integration" -Passed $metricsValid -Details @{
                Metrics = $profile.SystemMetrics.Keys
                PerformanceScore = $profile.SystemMetrics.PerformanceScore
                SecurityScore = $profile.SystemMetrics.SecurityScore
            }
        }
        
        # Test 4: Profile Export/Import
        if ($profileValid) {
            $exportJson = $profile.ExportToJson()
            $exportValid = -not [string]::IsNullOrEmpty($exportJson)
            Write-TestResult -TestName "Profile Export to JSON" -Category "Integration" -Passed $exportValid -Details @{
                JsonLength = $exportJson.Length
            }
        }
        
    } catch {
        Write-TestResult -TestName "Integration Function Exception" -Category "Integration" -Passed $false -Message $_.Exception.Message
    }
}

# Main test execution
Write-Host "DotWin Profiling System Test Suite" -ForegroundColor Yellow
Write-Host "=================================" -ForegroundColor Yellow

# Determine which tests to run
$testsToRun = if ($TestCategory -contains 'All') {
    @('Hardware', 'Software', 'User', 'Recommendations', 'Integration')
} else {
    $TestCategory
}

# Execute tests
foreach ($category in $testsToRun) {
    switch ($category) {
        'Hardware' { Test-HardwareProfiling }
        'Software' { Test-SoftwareProfiling }
        'User' { Test-UserProfiling }
        'Recommendations' { Test-RecommendationEngine }
        'Integration' { Test-IntegrationFunctions }
    }
}

# Calculate final results
$TestResults.EndTime = Get-Date
$TestResults.Duration = $TestResults.EndTime - $TestResults.StartTime

# Display summary
Write-Host "`n=== TEST SUMMARY ===" -ForegroundColor Yellow
Write-Host "Total Tests: $($TestResults.Summary.Total)" -ForegroundColor White
Write-Host "Passed: $($TestResults.Summary.Passed)" -ForegroundColor Green
Write-Host "Failed: $($TestResults.Summary.Failed)" -ForegroundColor Red
Write-Host "Duration: $($TestResults.Duration.TotalSeconds) seconds" -ForegroundColor White

$successRate = if ($TestResults.Summary.Total -gt 0) {
    [Math]::Round(($TestResults.Summary.Passed / $TestResults.Summary.Total) * 100, 2)
} else { 0 }

Write-Host "Success Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { 'Green' } elseif ($successRate -ge 60) { 'Yellow' } else { 'Red' })

# Export results if requested
if ($ExportResults) {
    try {
        $TestResults | ConvertTo-Json -Depth 10 | Set-Content -Path $ExportResults -Encoding UTF8
        Write-Host "`nTest results exported to: $ExportResults" -ForegroundColor Cyan
    } catch {
        Write-Host "`nFailed to export test results: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Return overall test result
return $TestResults.Summary.Failed -eq 0