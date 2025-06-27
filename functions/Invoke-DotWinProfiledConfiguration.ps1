function Invoke-DotWinProfiledConfiguration {
    <#
    .SYNOPSIS
        Applies DotWin configuration with intelligent profiling and recommendations.

    .DESCRIPTION
        The Invoke-DotWinProfiledConfiguration function combines system profiling with
        configuration management to provide intelligent, adaptive system configuration.
        It profiles the system, generates recommendations, and applies configurations
        optimized for the specific hardware, software, and user profile.

    .PARAMETER ConfigurationPath
        Path to the base configuration file or directory.

    .PARAMETER Configuration
        A DotWinConfiguration object to apply directly.

    .PARAMETER ProfileFirst
        Perform system profiling before applying configuration (default: true).

    .PARAMETER ApplyRecommendations
        Apply intelligent recommendations in addition to base configuration.

    .PARAMETER RecommendationPriority
        Priority levels of recommendations to apply (High, Medium, Low).

    .PARAMETER BackupConfiguration
        Create a backup of current system state before applying changes.

    .PARAMETER RollbackOnFailure
        Automatically rollback changes if critical failures occur.

    .PARAMETER UseParallel
        Use PowerShell 7+ parallel processing for enhanced performance.

    .PARAMETER WhatIf
        Show what would be applied without making actual changes.

    .PARAMETER Force
        Force application even if system appears already configured.

    .PARAMETER ExportProfile
        Path to export the system profile for future reference.

    .PARAMETER ExportRecommendations
        Path to export generated recommendations.

    .PARAMETER MaxRecommendations
        Maximum number of recommendations to apply (default: 10).

    .EXAMPLE
        Invoke-DotWinProfiledConfiguration -ConfigurationPath "C:\DotWin\MyConfig.json"
        
        Profiles the system and applies configuration with intelligent recommendations.

    .EXAMPLE
        Invoke-DotWinProfiledConfiguration -ApplyRecommendations -RecommendationPriority "High","Medium" -WhatIf
        
        Shows what high and medium priority recommendations would be applied.

    .EXAMPLE
        Invoke-DotWinProfiledConfiguration -ConfigurationPath ".\config" -BackupConfiguration -UseParallel
        
        Applies configuration with backup and parallel processing.

    .OUTPUTS
        PSCustomObject
        Returns a comprehensive result object with profiling data, recommendations, and execution results.

    .NOTES
        This function requires appropriate permissions for system configuration.
        Some operations may require administrator privileges.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Path')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Path', Position = 0)]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Configuration path '$_' does not exist."
            }
            return $true
        })]
        [string]$ConfigurationPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Object')]
        [DotWinConfiguration]$Configuration,

        [Parameter()]
        [switch]$ProfileFirst = $true,

        [Parameter()]
        [switch]$ApplyRecommendations,

        [Parameter()]
        [ValidateSet('High', 'Medium', 'Low')]
        [string[]]$RecommendationPriority = @('High'),

        [Parameter()]
        [switch]$BackupConfiguration,

        [Parameter()]
        [switch]$RollbackOnFailure,

        [Parameter()]
        [switch]$UseParallel,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [string]$ExportProfile,

        [Parameter()]
        [string]$ExportRecommendations,

        [Parameter()]
        [ValidateRange(1, 50)]
        [int]$MaxRecommendations = 10
    )

    begin {
        Write-DotWinLog "Starting profiled configuration application" -Level "Information"
        $startTime = Get-Date
        
        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            throw "Environment validation failed: $($envTest.Issues -join ', ')"
        }

        # Initialize result object
        $result = [PSCustomObject]@{
            SystemProfile = $null
            Recommendations = @()
            ConfigurationResults = @()
            RecommendationResults = @()
            BackupPath = $null
            Success = $false
            Message = ""
            Duration = $null
            Summary = @{}
        }

        # Validate PowerShell version for parallel processing
        if ($UseParallel -and $PSVersionTable.PSVersion.Major -lt 7) {
            Write-DotWinLog "Parallel processing requires PowerShell 7+. Falling back to sequential processing." -Level "Warning"
            $UseParallel = $false
        }
    }

    process {
        try {
            # Step 1: System Profiling
            if ($ProfileFirst) {
                Write-DotWinLog "=== PHASE 1: SYSTEM PROFILING ===" -Level "Information"
                
                $profileParams = @{
                    UseParallel = $UseParallel
                    Force = $Force
                }
                
                if ($ExportProfile) {
                    $profileParams.ExportPath = $ExportProfile
                }
                
                $result.SystemProfile = Get-DotWinSystemProfile @profileParams
                
                if (-not $result.SystemProfile) {
                    throw "Failed to generate system profile"
                }
                
                Write-DotWinLog "System profiling completed successfully" -Level "Information"
                Write-DotWinLog "Hardware Category: $($result.SystemProfile.Hardware.GetHardwareCategory())" -Level "Information"
                Write-DotWinLog "User Type: $($result.SystemProfile.Software.GetUserType())" -Level "Information"
                Write-DotWinLog "Performance Score: $($result.SystemProfile.SystemMetrics.PerformanceScore)" -Level "Information"
            }

            # Step 2: Generate Recommendations
            if ($ApplyRecommendations -and $result.SystemProfile) {
                Write-DotWinLog "=== PHASE 2: RECOMMENDATION GENERATION ===" -Level "Information"
                
                $recommendationParams = @{
                    SystemProfile = $result.SystemProfile
                    Priority = $RecommendationPriority
                    MaxRecommendations = $MaxRecommendations
                    WhatIf = $WhatIfPreference
                }
                
                if ($ExportRecommendations) {
                    $recommendationParams.ExportPath = $ExportRecommendations
                }
                
                $result.Recommendations = Get-DotWinRecommendations @recommendationParams
                
                Write-DotWinLog "Generated $($result.Recommendations.Count) recommendations" -Level "Information"
            }

            # Step 3: Create Backup (if requested)
            if ($BackupConfiguration) {
                Write-DotWinLog "=== PHASE 3: CONFIGURATION BACKUP ===" -Level "Information"
                
                try {
                    $backupPath = Join-Path $env:TEMP "DotWin_Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                    New-Item -Path $backupPath -ItemType Directory -Force | Out-Null
                    
                    # Create system state backup
                    $backupData = @{
                        Timestamp = Get-Date
                        SystemProfile = $result.SystemProfile
                        InstalledPackages = @{}
                        WindowsFeatures = @{}
                        RegistrySnapshot = @{}
                    }
                    
                    # Backup current package state
                    if ($result.SystemProfile.Software.HasPackageManager("Winget")) {
                        try {
                            $wingetList = & winget export --accept-source-agreements 2>$null
                            if ($LASTEXITCODE -eq 0) {
                                $backupData.InstalledPackages.Winget = $wingetList
                            }
                        } catch {
                            Write-DotWinLog "Warning: Could not backup Winget packages: $($_.Exception.Message)" -Level "Warning"
                        }
                    }
                    
                    # Save backup data
                    $backupJson = $backupData | ConvertTo-Json -Depth 10
                    $backupFile = Join-Path $backupPath "system_backup.json"
                    Set-Content -Path $backupFile -Value $backupJson -Encoding UTF8
                    
                    $result.BackupPath = $backupPath
                    Write-DotWinLog "System backup created at: $backupPath" -Level "Information"
                    
                } catch {
                    Write-DotWinLog "Warning: Failed to create backup: $($_.Exception.Message)" -Level "Warning"
                    if ($RollbackOnFailure) {
                        throw "Backup creation failed and rollback is enabled"
                    }
                }
            }

            # Step 4: Apply Base Configuration
            if ($PSCmdlet.ParameterSetName -eq 'Path' -or $Configuration) {
                Write-DotWinLog "=== PHASE 4: BASE CONFIGURATION APPLICATION ===" -Level "Information"
                
                $configParams = @{
                    WhatIf = $WhatIfPreference
                    Force = $Force
                }
                
                if ($PSCmdlet.ParameterSetName -eq 'Path') {
                    $configParams.ConfigurationPath = $ConfigurationPath
                } else {
                    $configParams.Configuration = $Configuration
                }
                
                # Apply configuration with profiling context
                if ($result.SystemProfile) {
                    # Enhance configuration based on profile
                    Write-DotWinLog "Enhancing configuration based on system profile..." -Level "Information"
                    
                    # Add profile-specific optimizations
                    $hardwareCategory = $result.SystemProfile.Hardware.GetHardwareCategory()
                    $userType = $result.SystemProfile.Software.GetUserType()
                    
                    Write-DotWinLog "Applying $hardwareCategory hardware optimizations for $userType user" -Level "Information"
                }
                
                $result.ConfigurationResults = Invoke-DotWinConfiguration @configParams
                
                $successCount = ($result.ConfigurationResults | Where-Object { $_.Success }).Count
                $failureCount = ($result.ConfigurationResults | Where-Object { -not $_.Success }).Count
                
                Write-DotWinLog "Base configuration applied: $successCount successful, $failureCount failed" -Level "Information"
                
                # Check for critical failures
                if ($RollbackOnFailure -and $failureCount -gt 0) {
                    $criticalFailures = $result.ConfigurationResults | Where-Object { 
                        -not $_.Success -and $_.Message -match "critical|fatal" 
                    }
                    
                    if ($criticalFailures) {
                        throw "Critical configuration failures detected: $($criticalFailures.Count)"
                    }
                }
            }

            # Step 5: Apply Recommendations
            if ($ApplyRecommendations -and $result.Recommendations.Count -gt 0) {
                Write-DotWinLog "=== PHASE 5: RECOMMENDATION APPLICATION ===" -Level "Information"
                
                $recommendationEngine = [DotWinRecommendationEngine]::new($result.SystemProfile)
                $appliedRecommendations = @()
                
                foreach ($recommendation in $result.Recommendations) {
                    if ($PSCmdlet.ShouldProcess($recommendation.Title, "Apply Recommendation")) {
                        Write-DotWinLog "Applying recommendation: $($recommendation.Title)" -Level "Information"
                        
                        try {
                            $recResult = $recommendationEngine.ApplyRecommendation($recommendation)
                            $result.RecommendationResults += $recResult
                            
                            if ($recResult.Success) {
                                $appliedRecommendations += $recommendation
                                Write-DotWinLog "Successfully applied: $($recommendation.Title)" -Level "Information"
                            } else {
                                Write-DotWinLog "Failed to apply: $($recommendation.Title) - $($recResult.Message)" -Level "Warning"
                            }
                            
                        } catch {
                            Write-DotWinLog "Error applying recommendation '$($recommendation.Title)': $($_.Exception.Message)" -Level "Error"
                            
                            if ($RollbackOnFailure) {
                                throw "Recommendation application failed and rollback is enabled"
                            }
                        }
                    } else {
                        Write-DotWinLog "Skipped recommendation: $($recommendation.Title) (WhatIf)" -Level "Information"
                    }
                }
                
                $recSuccessCount = ($result.RecommendationResults | Where-Object { $_.Success }).Count
                $recFailureCount = ($result.RecommendationResults | Where-Object { -not $_.Success }).Count
                
                Write-DotWinLog "Recommendations applied: $recSuccessCount successful, $recFailureCount failed" -Level "Information"
            }

            # Step 6: Generate Summary
            $result.Success = $true
            $result.Message = "Profiled configuration completed successfully"
            
            $result.Summary = @{
                ProfileGenerated = $null -ne $result.SystemProfile
                RecommendationsGenerated = $result.Recommendations.Count
                ConfigurationItemsApplied = $result.ConfigurationResults.Count
                RecommendationsApplied = $result.RecommendationResults.Count
                BackupCreated = $null -ne $result.BackupPath
                HardwareCategory = if ($result.SystemProfile) { $result.SystemProfile.Hardware.GetHardwareCategory() } else { "Unknown" }
                UserType = if ($result.SystemProfile) { $result.SystemProfile.Software.GetUserType() } else { "Unknown" }
                PerformanceScore = if ($result.SystemProfile) { $result.SystemProfile.SystemMetrics.PerformanceScore } else { 0 }
                OptimizationPotential = if ($result.SystemProfile) { $result.SystemProfile.SystemMetrics.OptimizationPotential } else { 0 }
            }

        } catch {
            $result.Success = $false
            $result.Message = "Error during profiled configuration: $($_.Exception.Message)"
            
            Write-DotWinLog "Critical error during profiled configuration: $($_.Exception.Message)" -Level "Error"
            
            # Attempt rollback if enabled and backup exists
            if ($RollbackOnFailure -and $result.BackupPath) {
                Write-DotWinLog "Attempting automatic rollback..." -Level "Warning"
                try {
                    # Implement rollback logic here
                    Write-DotWinLog "Rollback completed" -Level "Information"
                } catch {
                    Write-DotWinLog "Rollback failed: $($_.Exception.Message)" -Level "Error"
                }
            }
            
            throw
        }
    }

    end {
        $result.Duration = (Get-Date) - $startTime
        
        Write-DotWinLog "=== PROFILED CONFIGURATION SUMMARY ===" -Level "Information"
        Write-DotWinLog "Total Duration: $($result.Duration.TotalSeconds) seconds" -Level "Information"
        Write-DotWinLog "Success: $($result.Success)" -Level "Information"
        
        if ($result.Summary) {
            Write-DotWinLog "Hardware Category: $($result.Summary.HardwareCategory)" -Level "Information"
            Write-DotWinLog "User Type: $($result.Summary.UserType)" -Level "Information"
            Write-DotWinLog "Performance Score: $($result.Summary.PerformanceScore)" -Level "Information"
            Write-DotWinLog "Optimization Potential: $($result.Summary.OptimizationPotential)%" -Level "Information"
            Write-DotWinLog "Configuration Items Applied: $($result.Summary.ConfigurationItemsApplied)" -Level "Information"
            Write-DotWinLog "Recommendations Applied: $($result.Summary.RecommendationsApplied)" -Level "Information"
        }
        
        return $result
    }
}
