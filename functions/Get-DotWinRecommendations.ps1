function Get-DotWinRecommendations {
    <#
    .SYNOPSIS
        Generates intelligent configuration recommendations based on system profiling.

    .DESCRIPTION
        The Get-DotWinRecommendations function analyzes system profiles and generates
        intelligent, prioritized recommendations for system optimization, software
        installation, and configuration improvements. Uses both rule-based and
        machine learning approaches for recommendation generation.

    .PARAMETER SystemProfile
        A DotWinSystemProfiler object containing the system profile data.
        If not provided, will generate a new profile automatically.

    .PARAMETER Category
        Filter recommendations by category (Hardware, Software, Performance, Security, etc.).

    .PARAMETER Priority
        Filter recommendations by priority level (High, Medium, Low).

    .PARAMETER MaxRecommendations
        Maximum number of recommendations to return (default: 20).

    .PARAMETER IncludeConflicts
        Include recommendations that may conflict with each other.

    .PARAMETER ExportPath
        Optional path to export recommendations as JSON.

    .PARAMETER ApplyRecommendations
        Automatically apply high-priority, low-risk recommendations.

    .PARAMETER WhatIf
        Show what recommendations would be applied without actually applying them.

    .EXAMPLE
        Get-DotWinRecommendations
        
        Generates recommendations based on current system profile.

    .EXAMPLE
        $profile = Get-DotWinSystemProfile
        Get-DotWinRecommendations -SystemProfile $profile -Category "Hardware","Software" -Priority "High"
        
        Gets high-priority hardware and software recommendations for a specific profile.

    .EXAMPLE
        Get-DotWinRecommendations -ApplyRecommendations -WhatIf
        
        Shows what high-priority recommendations would be applied automatically.

    .OUTPUTS
        DotWinRecommendation[]
        Returns an array of prioritized recommendation objects.

    .NOTES
        This function requires the system to be profiled first. Some recommendations
        may require administrator privileges to implement.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object]$InputObject,

        [Parameter()]
        [DotWinSystemProfiler]$SystemProfile,

        [Parameter()]
        [ValidateSet('Hardware', 'Software', 'Performance', 'Security', 'Development', 'User Experience')]
        [string[]]$Category,

        [Parameter()]
        [ValidateSet('High', 'Medium', 'Low')]
        [string[]]$Priority,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$MaxRecommendations = 20,

        [Parameter()]
        [switch]$IncludeConflicts,

        [Parameter()]
        [ValidateScript({
            $directory = Split-Path $_ -Parent
            if ($directory -and -not (Test-Path $directory)) {
                throw "Export directory '$directory' does not exist."
            }
            return $true
        })]
        [string]$ExportPath,

        [Parameter()]
        [switch]$ApplyRecommendations,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-DotWinLog "Starting intelligent recommendation generation" -Level "Information"
        $startTime = Get-Date

        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            throw "Environment validation failed: $($envTest.Issues -join ', ')"
        }
    }

    process {
        try {
            # Handle pipeline input - check if we received a DotWinSystemStatus object
            if ($InputObject -and $InputObject.GetType().Name -eq 'DotWinSystemStatus') {
                Write-DotWinLog "Received DotWinSystemStatus from pipeline, extracting SystemProfile..." -Level "Information"
                # Extract SystemProfile from the status object if available
                if ($InputObject.ConfigurationStatus -and $InputObject.ConfigurationStatus.SystemProfile) {
                    $SystemProfile = $InputObject.ConfigurationStatus.SystemProfile
                } else {
                    Write-DotWinLog "No SystemProfile found in status object, generating new profile..." -Level "Information"
                    $SystemProfile = Get-DotWinSystemProfile -UseParallel:($PSVersionTable.PSVersion.Major -ge 7)
                }
            } elseif ($InputObject -and $InputObject.GetType().Name -eq 'DotWinSystemProfiler') {
                Write-DotWinLog "Received DotWinSystemProfiler from pipeline" -Level "Information"
                $SystemProfile = $InputObject
            }

            # Generate or use provided system profile
            if (-not $SystemProfile) {
                Write-DotWinLog "No system profile provided, generating new profile..." -Level "Information"
                $SystemProfile = Get-DotWinSystemProfile -UseParallel:($PSVersionTable.PSVersion.Major -ge 7)
            }

            # Validate system profile
            if (-not $SystemProfile -or -not $SystemProfile.LastProfiled) {
                throw "Invalid or incomplete system profile provided"
            }

            Write-DotWinLog "Using system profile from: $($SystemProfile.LastProfiled)" -Level "Information"
            Write-DotWinLog "Profile version: $($SystemProfile.ProfileVersion)" -Level "Information"

            # Initialize recommendation engine
            Write-DotWinLog "Initializing recommendation engine..." -Level "Information"
            try {
                $recommendationEngine = [DotWinRecommendationEngine]::new($SystemProfile)
            } catch {
                # If class instantiation fails, try New-Object for mock testing
                $recommendationEngine = New-Object -TypeName 'DotWinRecommendationEngine' -ArgumentList $SystemProfile
            }

            # Generate recommendations
            Write-DotWinLog "Generating intelligent recommendations..." -Level "Information"
            $allRecommendations = $recommendationEngine.GenerateRecommendations()

            Write-DotWinLog "Generated $($allRecommendations.Count) initial recommendations" -Level "Information"

            # Apply filters
            $filteredRecommendations = $allRecommendations

            if ($Category) {
                $filteredRecommendations = $filteredRecommendations | Where-Object { $_.Category -in $Category }
                Write-DotWinLog "Filtered by category: $($Category -join ', ') - $($filteredRecommendations.Count) recommendations remain" -Level "Information"
            }

            if ($Priority) {
                $filteredRecommendations = $filteredRecommendations | Where-Object { $_.Priority -in $Priority }
                Write-DotWinLog "Filtered by priority: $($Priority -join ', ') - $($filteredRecommendations.Count) recommendations remain" -Level "Information"
            }

            # Remove conflicts unless explicitly requested
            if (-not $IncludeConflicts) {
                $originalCount = $filteredRecommendations.Count
                $filteredRecommendations = $recommendationEngine.ResolveConflicts($filteredRecommendations)
                $conflictsRemoved = $originalCount - $filteredRecommendations.Count
                if ($conflictsRemoved -gt 0) {
                    Write-DotWinLog "Resolved $conflictsRemoved conflicting recommendations" -Level "Information"
                }
            }

            # Limit results
            if ($filteredRecommendations.Count -gt $MaxRecommendations) {
                $filteredRecommendations = $filteredRecommendations | Select-Object -First $MaxRecommendations
                Write-DotWinLog "Limited results to top $MaxRecommendations recommendations" -Level "Information"
            }

            # Add recommendation metadata
            foreach ($rec in $filteredRecommendations) {
                $rec.Metadata["GeneratedAt"] = Get-Date
                $rec.Metadata["ProfileVersion"] = $SystemProfile.ProfileVersion
                $rec.Metadata["EngineVersion"] = $recommendationEngine.EngineVersion
                $rec.Metadata["SystemCategory"] = $SystemProfile.Hardware.GetHardwareCategory()
                $rec.Metadata["UserType"] = $SystemProfile.Software.GetUserType()
                $rec.Metadata["TechnicalLevel"] = $SystemProfile.User.GetTechnicalLevel()
            }

            # Export recommendations if requested
            if ($ExportPath) {
                Write-DotWinLog "Exporting recommendations to: $ExportPath" -Level "Information"
                try {
                    $exportData = @{
                        GeneratedAt = Get-Date
                        SystemProfile = @{
                            LastProfiled = $SystemProfile.LastProfiled
                            ProfileVersion = $SystemProfile.ProfileVersion
                            SystemMetrics = $SystemProfile.SystemMetrics
                            HardwareCategory = $SystemProfile.Hardware.GetHardwareCategory()
                            UserType = $SystemProfile.Software.GetUserType()
                            TechnicalLevel = $SystemProfile.User.GetTechnicalLevel()
                        }
                        Recommendations = $filteredRecommendations
                        Summary = @{
                            TotalRecommendations = $filteredRecommendations.Count
                            HighPriority = ($filteredRecommendations | Where-Object { $_.Priority -eq "High" }).Count
                            MediumPriority = ($filteredRecommendations | Where-Object { $_.Priority -eq "Medium" }).Count
                            LowPriority = ($filteredRecommendations | Where-Object { $_.Priority -eq "Low" }).Count
                            Categories = ($filteredRecommendations | Group-Object Category | ForEach-Object { @{ $_.Name = $_.Count } })
                        }
                    }
                    
                    $jsonRecommendations = $exportData | ConvertTo-Json -Depth 10
                    Set-Content -Path $ExportPath -Value $jsonRecommendations -Encoding UTF8
                    Write-DotWinLog "Recommendations exported successfully" -Level "Information"
                } catch {
                    Write-DotWinLog "Failed to export recommendations: $($_.Exception.Message)" -Level "Error"
                }
            }

            # Apply recommendations if requested
            if ($ApplyRecommendations) {
                Write-DotWinLog "Applying high-priority, low-risk recommendations..." -Level "Information"
                
                # Filter for auto-applicable recommendations
                $autoApplicable = $filteredRecommendations | Where-Object { 
                    $_.Priority -eq "High" -and 
                    $_.ConfidenceScore -ge 0.8 -and
                    $_.Implementation.Type -in @("Package", "Function") -and
                    -not ($_.Prerequisites -and $_.Prerequisites.Count -gt 0)
                }

                Write-DotWinLog "Found $($autoApplicable.Count) auto-applicable recommendations" -Level "Information"

                $applicationResults = @()
                foreach ($rec in $autoApplicable) {
                    if ($PSCmdlet.ShouldProcess($rec.Title, "Apply Recommendation")) {
                        Write-DotWinLog "Applying recommendation: $($rec.Title)" -Level "Information"
                        
                        try {
                            $result = $recommendationEngine.ApplyRecommendation($rec)
                            $applicationResults += $result
                            
                            if ($result.Success) {
                                Write-DotWinLog "Successfully applied: $($rec.Title)" -Level "Information"
                            } else {
                                Write-DotWinLog "Failed to apply: $($rec.Title) - $($result.Message)" -Level "Warning"
                            }
                        } catch {
                            Write-DotWinLog "Error applying recommendation '$($rec.Title)': $($_.Exception.Message)" -Level "Error"
                        }
                    } else {
                        Write-DotWinLog "Skipped applying recommendation: $($rec.Title) (WhatIf)" -Level "Information"
                    }
                }

                # Add application results to metadata
                if ($applicationResults.Count -gt 0) {
                    $successCount = ($applicationResults | Where-Object { $_.Success }).Count
                    $failureCount = ($applicationResults | Where-Object { -not $_.Success }).Count
                    
                    Write-DotWinLog "Recommendation application summary: $successCount successful, $failureCount failed" -Level "Information"
                    
                    # Add summary to first recommendation's metadata for reference
                    if ($filteredRecommendations.Count -gt 0) {
                        $filteredRecommendations[0].Metadata["ApplicationSummary"] = @{
                            Applied = $applicationResults.Count
                            Successful = $successCount
                            Failed = $failureCount
                            Results = $applicationResults
                        }
                    }
                }
            }

            # Ensure we always return an array, even for single items
            if ($filteredRecommendations -is [array]) {
                return $filteredRecommendations
            } else {
                return @($filteredRecommendations)
            }

        } catch {
            Write-DotWinLog "Critical error during recommendation generation: $($_.Exception.Message)" -Level "Error"
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        Write-DotWinLog "Recommendation generation completed in $($totalDuration.TotalSeconds) seconds" -Level "Information"
        
        # Display recommendation summary
        if ($filteredRecommendations) {
            Write-DotWinLog "=== RECOMMENDATION SUMMARY ===" -Level "Information"
            Write-DotWinLog "Total Recommendations: $($filteredRecommendations.Count)" -Level "Information"
            
            $priorityGroups = $filteredRecommendations | Group-Object Priority
            foreach ($group in $priorityGroups) {
                Write-DotWinLog "$($group.Name) Priority: $($group.Count) recommendations" -Level "Information"
            }
            
            $categoryGroups = $filteredRecommendations | Group-Object Category
            foreach ($group in $categoryGroups) {
                Write-DotWinLog "$($group.Name): $($group.Count) recommendations" -Level "Information"
            }
            
            # Show top 3 recommendations
            $topRecommendations = $filteredRecommendations | Select-Object -First 3
            Write-DotWinLog "=== TOP RECOMMENDATIONS ===" -Level "Information"
            foreach ($rec in $topRecommendations) {
                Write-DotWinLog "[$($rec.Priority)] $($rec.Title) - $($rec.Description)" -Level "Information"
            }
        }
    }
}
