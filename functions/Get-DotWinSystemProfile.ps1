function Get-DotWinSystemProfile {
    <#
    .SYNOPSIS
        Generates a comprehensive system profile for intelligent configuration recommendations.

    .DESCRIPTION
        The Get-DotWinSystemProfile function performs deep system analysis including hardware
        detection, software inventory, and user behavior analysis. This profile is used by
        the DotWin recommendation engine to provide intelligent configuration suggestions.

    .PARAMETER IncludeHardware
        Include detailed hardware profiling in the system profile.

    .PARAMETER IncludeSoftware
        Include software inventory and package manager analysis.

    .PARAMETER IncludeUser
        Include user behavior and preference analysis.

    .PARAMETER ExportPath
        Optional path to export the profile as JSON for persistence.

    .PARAMETER UseParallel
        Use PowerShell 7+ parallel processing for faster profiling (requires PowerShell 7+).

    .PARAMETER Force
        Force re-profiling even if a recent profile exists.

    .EXAMPLE
        Get-DotWinSystemProfile
        
        Performs complete system profiling with all components.

    .EXAMPLE
        Get-DotWinSystemProfile -IncludeHardware -IncludeSoftware -ExportPath "C:\DotWin\profile.json"
        
        Profiles hardware and software, then exports the results to a JSON file.

    .EXAMPLE
        $profile = Get-DotWinSystemProfile -UseParallel
        $profile.Hardware.GetHardwareCategory()
        
        Performs parallel profiling and gets the hardware category.

    .OUTPUTS
        DotWinSystemProfiler
        Returns a comprehensive system profiler object containing hardware, software, and user profiles.

    .NOTES
        This function requires appropriate permissions for system information gathering.
        Some operations may require administrator privileges for complete profiling.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludeHardware = $true,

        [Parameter()]
        [switch]$IncludeSoftware = $true,

        [Parameter()]
        [switch]$IncludeUser = $true,

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
        [switch]$UseParallel,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-DotWinLog "Starting comprehensive system profiling" -Level "Information"
        $startTime = Get-Date

        # Validate PowerShell version for parallel processing
        if ($UseParallel -and $PSVersionTable.PSVersion.Major -lt 7) {
            Write-DotWinLog "Parallel processing requires PowerShell 7+. Falling back to sequential processing." -Level "Warning"
            $UseParallel = $false
        }

        # Check for existing profile cache (simplified approach)
        $cacheValid = $false
        if (-not $Force) {
            # In a full implementation, you might check for cached profiles
            Write-Verbose "Checking for existing profile cache..."
        }
    }

    process {
        try {
            # Create system profiler instance
            $profiler = [DotWinSystemProfiler]::new()
            
            Write-DotWinLog "Initializing system profiler (Version: $($profiler.ProfileVersion))" -Level "Information"

            if ($UseParallel -and $PSVersionTable.PSVersion.Major -ge 7) {
                Write-DotWinLog "Using PowerShell 7+ parallel processing for enhanced performance" -Level "Information"
                
                try {
                    # Use parallel processing for profiling tasks
                    $profilingTasks = @()

                    if ($IncludeHardware) {
                        $profilingTasks += @{
                            Name = "Hardware"
                            ScriptBlock = {
                                param($profilerInstance)
                                $profilerInstance.ProfileHardware()
                                return $profilerInstance.Hardware
                            }
                        }
                    }

                    if ($IncludeSoftware) {
                        $profilingTasks += @{
                            Name = "Software"
                            ScriptBlock = {
                                param($profilerInstance)
                                $profilerInstance.ProfileSoftware()
                                return $profilerInstance.Software
                            }
                        }
                    }

                    if ($IncludeUser) {
                        $profilingTasks += @{
                            Name = "User"
                            ScriptBlock = {
                                param($profilerInstance)
                                $profilerInstance.ProfileUser()
                                return $profilerInstance.User
                            }
                        }
                    }

                    # Execute profiling tasks in parallel
                    # Note: We need to import the module in each runspace for class access
                    $modulePath = $PSScriptRoot | Split-Path -Parent
                    $results = $profilingTasks | ForEach-Object -Parallel {
                        $task = $_
                        $moduleRoot = $using:modulePath

                        try {
                            # Import the DotWin module in this runspace to access classes
                            $moduleManifest = "$moduleRoot\DotWin.psd1"
                            if (Test-Path $moduleManifest) {
                                Import-Module $moduleManifest -Force -ErrorAction Stop
                            } else {
                                throw "DotWin module manifest not found at: $moduleManifest"
                            }

                            # Verify class is available
                            if (-not ([System.Management.Automation.PSTypeName]'DotWinSystemProfiler').Type) {
                                throw "DotWinSystemProfiler class not available after module import"
                            }

                            # Create profiler instance (now classes should be available)
                            $taskProfiler = [DotWinSystemProfiler]::new()

                            Write-Verbose "Executing parallel task: $($task.Name)"
                            $result = & $task.ScriptBlock $taskProfiler
                            return @{
                                Name = $task.Name
                                Result = $result
                                Success = $true
                                Error = $null
                            }
                        } catch {
                            return @{
                                Name = $task.Name
                                Result = $null
                                Success = $false
                                Error = $_.Exception.Message
                            }
                        }
                    } -ThrottleLimit 3

                    # Check if parallel processing succeeded
                    $parallelSuccess = $true
                    foreach ($result in $results) {
                        if ($result.Success) {
                            switch ($result.Name) {
                                "Hardware" { $profiler.Hardware = $result.Result }
                                "Software" { $profiler.Software = $result.Result }
                                "User" { $profiler.User = $result.Result }
                            }
                            Write-DotWinLog "Parallel $($result.Name) profiling completed successfully" -Level "Information"
                        } else {
                            Write-DotWinLog "Parallel $($result.Name) profiling failed: $($result.Error)" -Level "Error"
                            $parallelSuccess = $false
                        }
                    }

                    # If parallel processing failed, fall back to sequential
                    if (-not $parallelSuccess) {
                        Write-DotWinLog "Parallel processing encountered errors, falling back to sequential processing" -Level "Warning"
                        $UseParallel = $false
                    }

                } catch {
                    Write-DotWinLog "Parallel processing failed: $($_.Exception.Message). Falling back to sequential processing." -Level "Warning"
                    $UseParallel = $false
                }
            }

            # Sequential profiling (either by choice or fallback from failed parallel processing)
            if (-not $UseParallel) {
                Write-DotWinLog "Using sequential processing for system profiling" -Level "Information"
                
                if ($IncludeHardware) {
                    Write-DotWinLog "Profiling hardware components..." -Level "Information"
                    $profiler.ProfileHardware()
                }
                
                if ($IncludeSoftware) {
                    Write-DotWinLog "Profiling software inventory..." -Level "Information"
                    $profiler.ProfileSoftware()
                }
                
                if ($IncludeUser) {
                    Write-DotWinLog "Profiling user behavior and preferences..." -Level "Information"
                    $profiler.ProfileUser()
                }
            }

            # Calculate system metrics
            Write-DotWinLog "Calculating system performance metrics..." -Level "Information"
            $profiler.CalculateSystemMetrics()
            
            # Set profiling timestamp
            $profiler.LastProfiled = Get-Date

            # Export profile if requested
            if ($ExportPath) {
                Write-DotWinLog "Exporting system profile to: $ExportPath" -Level "Information"
                try {
                    $jsonProfile = $profiler.ExportToJson()
                    Set-Content -Path $ExportPath -Value $jsonProfile -Encoding UTF8
                    Write-DotWinLog "System profile exported successfully" -Level "Information"
                } catch {
                    Write-DotWinLog "Failed to export system profile: $($_.Exception.Message)" -Level "Error"
                }
            }

            return $profiler

        } catch {
            Write-DotWinLog "Critical error during system profiling: $($_.Exception.Message)" -Level "Error"
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        Write-DotWinLog "System profiling completed in $($totalDuration.TotalSeconds) seconds" -Level "Information"
        
        # Display profiling summary
        if ($profiler -and $profiler.Hardware -and $profiler.Software -and $profiler.User -and $profiler.SystemMetrics) {
            Write-DotWinLog "=== PROFILING SUMMARY ===" -Level "Information"
            Write-DotWinLog "Hardware Category: $($profiler.Hardware.GetHardwareCategory())" -Level "Information"
            Write-DotWinLog "User Type: $($profiler.Software.GetUserType())" -Level "Information"
            Write-DotWinLog "Technical Level: $($profiler.User.GetTechnicalLevel())" -Level "Information"
            Write-DotWinLog "Performance Score: $($profiler.SystemMetrics.PerformanceScore)" -Level "Information"
            Write-DotWinLog "Optimization Potential: $($profiler.SystemMetrics.OptimizationPotential)%" -Level "Information"
            Write-DotWinLog "Security Score: $($profiler.SystemMetrics.SecurityScore)" -Level "Information"
            Write-DotWinLog "Developer Friendliness: $($profiler.SystemMetrics.DeveloperFriendliness)" -Level "Information"
        }
    }
}
