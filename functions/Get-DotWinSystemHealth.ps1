function Get-DotWinSystemHealth {
    <#
    .SYNOPSIS
        Performs comprehensive system health monitoring and diagnostics.

    .DESCRIPTION
        The Get-DotWinSystemHealth function provides detailed system health analysis
        including performance metrics, resource utilization, configuration drift
        detection, and proactive issue identification. It helps maintain system
        reliability and performance over time.

    .PARAMETER IncludePerformanceMetrics
        Include detailed performance metrics in the health report.

    .PARAMETER IncludeConfigurationDrift
        Check for configuration drift from known baselines.

    .PARAMETER IncludeSecurityStatus
        Include security posture assessment.

    .PARAMETER IncludeResourceUtilization
        Monitor system resource utilization patterns.

    .PARAMETER IncludeEventLogAnalysis
        Analyze Windows Event Logs for issues.

    .PARAMETER BaselineProfile
        Path to a baseline system profile for drift detection.

    .PARAMETER AlertThresholds
        Custom alert thresholds for various metrics.

    .PARAMETER ExportReport
        Path to export the health report.

    .PARAMETER MonitoringDuration
        Duration in minutes to monitor dynamic metrics (default: 5).

    .EXAMPLE
        Get-DotWinSystemHealth

        Performs basic system health check.

    .EXAMPLE
        Get-DotWinSystemHealth -IncludePerformanceMetrics -IncludeConfigurationDrift -ExportReport ".\health-report.json"

        Comprehensive health check with performance monitoring and drift detection.

    .EXAMPLE
        Get-DotWinSystemHealth -BaselineProfile ".\baseline.json" -AlertThresholds @{ CPUThreshold = 80; MemoryThreshold = 85 }

        Health check with custom baseline and alert thresholds.

    .OUTPUTS
        PSCustomObject
        Returns comprehensive system health report.

    .NOTES
        This function provides proactive system monitoring capabilities.
        Some checks may require administrator privileges for complete analysis.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [switch]$IncludePerformanceMetrics,

        [Parameter()]
        [switch]$IncludeConfigurationDrift,

        [Parameter()]
        [switch]$IncludeSecurityStatus,

        [Parameter()]
        [switch]$IncludeResourceUtilization,

        [Parameter()]
        [switch]$IncludeEventLogAnalysis,

        [Parameter()]
        [ValidateScript({
            if ($_ -and -not (Test-Path $_)) {
                throw "Baseline profile file '$_' does not exist."
            }
            return $true
        })]
        [string]$BaselineProfile,

        [Parameter()]
        [hashtable]$AlertThresholds = @{
            CPUThreshold = 90
            MemoryThreshold = 90
            DiskThreshold = 85
            EventErrorThreshold = 10
            SecurityScoreThreshold = 70
        },

        [Parameter()]
        [string]$ExportReport,

        [Parameter()]
        [ValidateRange(1, 60)]
        [int]$MonitoringDuration = 5
    )

    begin {
        Write-DotWinLog "Starting comprehensive system health monitoring" -Level "Information"
        $startTime = Get-Date

        # Initialize health report
        $healthReport = [PSCustomObject]@{
            Timestamp = Get-Date
            ComputerName = $env:COMPUTERNAME
            OverallHealth = "Unknown"
            HealthScore = 0
            Alerts = @()
            Warnings = @()
            Recommendations = @()
            SystemInfo = @{}
            PerformanceMetrics = $null
            ConfigurationDrift = $null
            SecurityStatus = $null
            ResourceUtilization = $null
            EventLogAnalysis = $null
            MonitoringDuration = $MonitoringDuration
            GeneratedBy = "DotWin System Health Monitor"
        }
    }

    process {
        try {
            # Basic system information
            Write-DotWinLog "Gathering basic system information" -Level "Information"
            $healthReport.SystemInfo = Get-BasicSystemInfo

            # Performance metrics monitoring
            if ($IncludePerformanceMetrics) {
                Write-DotWinLog "Collecting performance metrics over $MonitoringDuration minutes" -Level "Information"
                $healthReport.PerformanceMetrics = Get-PerformanceMetrics -Duration $MonitoringDuration -AlertThresholds $AlertThresholds
                
                # Add performance alerts
                $perfAlerts = Get-PerformanceAlerts -Metrics $healthReport.PerformanceMetrics -Thresholds $AlertThresholds
                $healthReport.Alerts += $perfAlerts
            }

            # Configuration drift detection
            if ($IncludeConfigurationDrift -and $BaselineProfile) {
                Write-DotWinLog "Analyzing configuration drift from baseline" -Level "Information"
                $healthReport.ConfigurationDrift = Get-ConfigurationDrift -BaselineProfile $BaselineProfile
                
                if ($healthReport.ConfigurationDrift.DriftDetected) {
                    $healthReport.Alerts += "Configuration drift detected from baseline"
                    $healthReport.Recommendations += "Review configuration changes and update baseline if intentional"
                }
            }

            # Security status assessment
            if ($IncludeSecurityStatus) {
                Write-DotWinLog "Assessing security posture" -Level "Information"
                $healthReport.SecurityStatus = Get-SecurityStatus -AlertThresholds $AlertThresholds
                
                if ($healthReport.SecurityStatus.SecurityScore -lt $AlertThresholds.SecurityScoreThreshold) {
                    $healthReport.Alerts += "Security score below threshold: $($healthReport.SecurityStatus.SecurityScore)"
                    $healthReport.Recommendations += "Review and improve security configuration"
                }
            }

            # Resource utilization monitoring
            if ($IncludeResourceUtilization) {
                Write-DotWinLog "Monitoring resource utilization patterns" -Level "Information"
                $healthReport.ResourceUtilization = Get-ResourceUtilization -Duration $MonitoringDuration
                
                $resourceAlerts = Get-ResourceAlerts -Utilization $healthReport.ResourceUtilization -Thresholds $AlertThresholds
                $healthReport.Alerts += $resourceAlerts
            }

            # Event log analysis
            if ($IncludeEventLogAnalysis) {
                Write-DotWinLog "Analyzing Windows Event Logs" -Level "Information"
                $healthReport.EventLogAnalysis = Get-EventLogAnalysis -AlertThresholds $AlertThresholds
                
                if ($healthReport.EventLogAnalysis.CriticalErrors -gt $AlertThresholds.EventErrorThreshold) {
                    $healthReport.Alerts += "High number of critical errors in event logs: $($healthReport.EventLogAnalysis.CriticalErrors)"
                    $healthReport.Recommendations += "Investigate critical errors in system event logs"
                }
            }

            # Calculate overall health score
            $healthReport.HealthScore = Calculate-OverallHealthScore -HealthReport $healthReport
            $healthReport.OverallHealth = Get-HealthStatus -Score $healthReport.HealthScore

            # Generate general recommendations
            $healthReport.Recommendations += Get-GeneralRecommendations -HealthReport $healthReport

        } catch {
            Write-DotWinLog "Error during system health monitoring: $($_.Exception.Message)" -Level "Error"
            $healthReport.OverallHealth = "Error"
            $healthReport.Alerts += "Health monitoring failed: $($_.Exception.Message)"
            throw
        }
    }

    end {
        $healthReport.MonitoringDuration = ((Get-Date) - $startTime).TotalMinutes

        # Export report if requested
        if ($ExportReport) {
            try {
                $healthReport | ConvertTo-Json -Depth 10 | Set-Content -Path $ExportReport -Encoding UTF8
                Write-DotWinLog "Health report exported to: $ExportReport" -Level "Information"
            } catch {
                Write-DotWinLog "Failed to export health report: $($_.Exception.Message)" -Level "Warning"
            }
        }

        Write-DotWinLog "System health monitoring completed" -Level "Information"
        Write-DotWinLog "Overall health: $($healthReport.OverallHealth) (Score: $($healthReport.HealthScore))" -Level "Information"
        Write-DotWinLog "Alerts: $($healthReport.Alerts.Count), Recommendations: $($healthReport.Recommendations.Count)" -Level "Information"

        return $healthReport
    }
}

function Get-BasicSystemInfo {
    <#
    .SYNOPSIS
        Gathers basic system information for health monitoring.
    #>
    [CmdletBinding()]
    param()

    try {
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
        $biosInfo = Get-CimInstance -ClassName Win32_BIOS

        return @{
            OperatingSystem = $osInfo.Caption
            Version = $osInfo.Version
            BuildNumber = $osInfo.BuildNumber
            Architecture = $osInfo.OSArchitecture
            InstallDate = $osInfo.InstallDate
            LastBootUpTime = $osInfo.LastBootUpTime
            Uptime = (Get-Date) - $osInfo.LastBootUpTime
            TotalMemoryGB = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            Manufacturer = $computerInfo.Manufacturer
            Model = $computerInfo.Model
            BIOSVersion = $biosInfo.SMBIOSBIOSVersion
            PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            DotWinVersion = (Get-Module DotWin).Version.ToString()
        }
    } catch {
        Write-Warning "Error gathering basic system info: $($_.Exception.Message)"
        return @{ Error = $_.Exception.Message }
    }
}

function Get-PerformanceMetrics {
    <#
    .SYNOPSIS
        Collects performance metrics over a specified duration.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Duration = 5,
        
        [Parameter()]
        [hashtable]$AlertThresholds
    )

    $metrics = @{
        CPU = @{
            Average = 0
            Peak = 0
            Samples = @()
        }
        Memory = @{
            AverageUsedPercent = 0
            PeakUsedPercent = 0
            TotalGB = 0
            AvailableGB = 0
            Samples = @()
        }
        Disk = @{
            Drives = @()
            HighestUsagePercent = 0
        }
        Network = @{
            Adapters = @()
            TotalBytesReceived = 0
            TotalBytesSent = 0
        }
        Processes = @{
            TopCPUProcesses = @()
            TopMemoryProcesses = @()
            TotalProcesses = 0
        }
    }

    try {
        Write-Verbose "Collecting performance metrics for $Duration minutes"
        
        # Get memory info
        $memInfo = Get-CimInstance -ClassName Win32_ComputerSystem
        $metrics.Memory.TotalGB = [Math]::Round($memInfo.TotalPhysicalMemory / 1GB, 2)

        # Collect samples over the duration
        $sampleInterval = 15  # seconds
        $totalSamples = ($Duration * 60) / $sampleInterval
        
        for ($i = 0; $i -lt $totalSamples; $i++) {
            # CPU usage
            $cpuUsage = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            $metrics.CPU.Samples += $cpuUsage
            
            # Memory usage
            $availableMemory = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1MB
            $usedMemoryPercent = [Math]::Round((($metrics.Memory.TotalGB - $availableMemory) / $metrics.Memory.TotalGB) * 100, 2)
            $metrics.Memory.Samples += $usedMemoryPercent
            
            if ($i -lt ($totalSamples - 1)) {
                Start-Sleep -Seconds $sampleInterval
            }
        }

        # Calculate averages and peaks
        $metrics.CPU.Average = [Math]::Round(($metrics.CPU.Samples | Measure-Object -Average).Average, 2)
        $metrics.CPU.Peak = [Math]::Round(($metrics.CPU.Samples | Measure-Object -Maximum).Maximum, 2)
        
        $metrics.Memory.AverageUsedPercent = [Math]::Round(($metrics.Memory.Samples | Measure-Object -Average).Average, 2)
        $metrics.Memory.PeakUsedPercent = [Math]::Round(($metrics.Memory.Samples | Measure-Object -Maximum).Maximum, 2)
        
        # Current memory info
        $currentAvailableMemory = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1MB
        $metrics.Memory.AvailableGB = [Math]::Round($currentAvailableMemory, 2)

        # Disk usage
        $diskDrives = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
        foreach ($drive in $diskDrives) {
            $usedPercent = [Math]::Round((($drive.Size - $drive.FreeSpace) / $drive.Size) * 100, 2)
            $metrics.Disk.Drives += @{
                Drive = $drive.DeviceID
                TotalGB = [Math]::Round($drive.Size / 1GB, 2)
                FreeGB = [Math]::Round($drive.FreeSpace / 1GB, 2)
                UsedPercent = $usedPercent
            }
            
            if ($usedPercent -gt $metrics.Disk.HighestUsagePercent) {
                $metrics.Disk.HighestUsagePercent = $usedPercent
            }
        }

        # Network adapters
        $networkAdapters = Get-CimInstance -ClassName Win32_PerfRawData_Tcpip_NetworkInterface | 
            Where-Object { $_.Name -notlike "*Loopback*" -and $_.Name -notlike "*Teredo*" }
        
        foreach ($adapter in $networkAdapters) {
            $metrics.Network.Adapters += @{
                Name = $adapter.Name
                BytesReceived = $adapter.BytesReceivedPerSec
                BytesSent = $adapter.BytesSentPerSec
            }
            $metrics.Network.TotalBytesReceived += $adapter.BytesReceivedPerSec
            $metrics.Network.TotalBytesSent += $adapter.BytesSentPerSec
        }

        # Top processes
        $processes = Get-Process | Sort-Object CPU -Descending
        $metrics.Processes.TopCPUProcesses = $processes | Select-Object -First 5 | ForEach-Object {
            @{
                Name = $_.ProcessName
                CPU = [Math]::Round($_.CPU, 2)
                WorkingSet = [Math]::Round($_.WorkingSet / 1MB, 2)
            }
        }
        
        $processes = Get-Process | Sort-Object WorkingSet -Descending
        $metrics.Processes.TopMemoryProcesses = $processes | Select-Object -First 5 | ForEach-Object {
            @{
                Name = $_.ProcessName
                WorkingSetMB = [Math]::Round($_.WorkingSet / 1MB, 2)
                CPU = [Math]::Round($_.CPU, 2)
            }
        }
        
        $metrics.Processes.TotalProcesses = (Get-Process).Count

    } catch {
        Write-Warning "Error collecting performance metrics: $($_.Exception.Message)"
        $metrics["Error"] = $_.Exception.Message
    }

    return $metrics
}

function Get-PerformanceAlerts {
    <#
    .SYNOPSIS
        Generates performance-based alerts.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Metrics,
        
        [Parameter()]
        [hashtable]$Thresholds
    )

    $alerts = @()

    if ($Metrics.CPU.Average -gt $Thresholds.CPUThreshold) {
        $alerts += "High CPU usage detected: $($Metrics.CPU.Average)% average"
    }

    if ($Metrics.Memory.AverageUsedPercent -gt $Thresholds.MemoryThreshold) {
        $alerts += "High memory usage detected: $($Metrics.Memory.AverageUsedPercent)% average"
    }

    if ($Metrics.Disk.HighestUsagePercent -gt $Thresholds.DiskThreshold) {
        $alerts += "High disk usage detected: $($Metrics.Disk.HighestUsagePercent)% on one or more drives"
    }

    return $alerts
}

function Get-ConfigurationDrift {
    <#
    .SYNOPSIS
        Detects configuration drift from a baseline profile.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$BaselineProfile
    )

    $driftAnalysis = @{
        DriftDetected = $false
        BaselineDate = $null
        Changes = @()
        Summary = @{}
    }

    try {
        # Load baseline profile
        $baseline = Get-Content -Path $BaselineProfile -Raw | ConvertFrom-Json
        $driftAnalysis.BaselineDate = $baseline.LastProfiled

        # Get current system profile
        $currentProfile = Get-DotWinSystemProfile -IncludeHardware:$false -IncludeSoftware -IncludeUser:$false

        # Compare software packages
        $baselinePackages = $baseline.Software.InstalledPackages
        $currentPackages = $currentProfile.Software.InstalledPackages

        # Check for new packages
        foreach ($packageName in $currentPackages.Keys) {
            if (-not $baselinePackages.ContainsKey($packageName)) {
                $driftAnalysis.Changes += @{
                    Type = "PackageAdded"
                    Item = $packageName
                    Details = $currentPackages[$packageName]
                }
                $driftAnalysis.DriftDetected = $true
            }
        }

        # Check for removed packages
        foreach ($packageName in $baselinePackages.Keys) {
            if (-not $currentPackages.ContainsKey($packageName)) {
                $driftAnalysis.Changes += @{
                    Type = "PackageRemoved"
                    Item = $packageName
                    Details = $baselinePackages[$packageName]
                }
                $driftAnalysis.DriftDetected = $true
            }
        }

        # Generate summary
        $driftAnalysis.Summary = @{
            PackagesAdded = ($driftAnalysis.Changes | Where-Object { $_.Type -eq "PackageAdded" }).Count
            PackagesRemoved = ($driftAnalysis.Changes | Where-Object { $_.Type -eq "PackageRemoved" }).Count
            TotalChanges = $driftAnalysis.Changes.Count
        }

    } catch {
        Write-Warning "Error analyzing configuration drift: $($_.Exception.Message)"
        $driftAnalysis["Error"] = $_.Exception.Message
    }

    return $driftAnalysis
}

function Get-SecurityStatus {
    <#
    .SYNOPSIS
        Assesses system security posture.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$AlertThresholds
    )

    $securityStatus = @{
        SecurityScore = 0
        WindowsDefender = @{}
        Firewall = @{}
        Updates = @{}
        UserAccounts = @{}
        Recommendations = @()
    }

    try {
        $score = 0

        # Windows Defender status
        try {
            $defenderStatus = Get-MpComputerStatus -ErrorAction SilentlyContinue
            if ($defenderStatus) {
                $securityStatus.WindowsDefender = @{
                    AntivirusEnabled = $defenderStatus.AntivirusEnabled
                    RealTimeProtectionEnabled = $defenderStatus.RealTimeProtectionEnabled
                    LastQuickScan = $defenderStatus.QuickScanStartTime
                    LastFullScan = $defenderStatus.FullScanStartTime
                }
                
                if ($defenderStatus.AntivirusEnabled) { $score += 25 }
                if ($defenderStatus.RealTimeProtectionEnabled) { $score += 25 }
            }
        } catch {
            $securityStatus.WindowsDefender["Error"] = "Unable to check Windows Defender status"
        }

        # Firewall status
        try {
            $firewallProfiles = Get-NetFirewallProfile
            $securityStatus.Firewall = @{
                DomainEnabled = ($firewallProfiles | Where-Object { $_.Name -eq "Domain" }).Enabled
                PrivateEnabled = ($firewallProfiles | Where-Object { $_.Name -eq "Private" }).Enabled
                PublicEnabled = ($firewallProfiles | Where-Object { $_.Name -eq "Public" }).Enabled
            }
            
            if ($securityStatus.Firewall.DomainEnabled) { $score += 10 }
            if ($securityStatus.Firewall.PrivateEnabled) { $score += 10 }
            if ($securityStatus.Firewall.PublicEnabled) { $score += 10 }
        } catch {
            $securityStatus.Firewall["Error"] = "Unable to check firewall status"
        }

        # Windows Update status
        try {
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            $searchResult = $updateSearcher.Search("IsInstalled=0")
            
            $securityStatus.Updates = @{
                PendingUpdates = $searchResult.Updates.Count
                LastChecked = Get-Date
            }
            
            if ($searchResult.Updates.Count -eq 0) { $score += 20 }
            elseif ($searchResult.Updates.Count -lt 5) { $score += 10 }
        } catch {
            $securityStatus.Updates["Error"] = "Unable to check Windows Update status"
        }

        $securityStatus.SecurityScore = $score

        # Generate recommendations
        if ($securityStatus.WindowsDefender.AntivirusEnabled -eq $false) {
            $securityStatus.Recommendations += "Enable Windows Defender Antivirus"
        }
        
        if ($securityStatus.WindowsDefender.RealTimeProtectionEnabled -eq $false) {
            $securityStatus.Recommendations += "Enable Windows Defender Real-time Protection"
        }
        
        if ($securityStatus.Updates.PendingUpdates -gt 0) {
            $securityStatus.Recommendations += "Install pending Windows updates"
        }

    } catch {
        Write-Warning "Error assessing security status: $($_.Exception.Message)"
        $securityStatus["Error"] = $_.Exception.Message
    }

    return $securityStatus
}

function Get-ResourceUtilization {
    <#
    .SYNOPSIS
        Monitors resource utilization patterns.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Duration = 5
    )

    $utilization = @{
        CPU = @{
            Pattern = "Unknown"
            Stability = "Unknown"
            Trend = "Unknown"
        }
        Memory = @{
            Pattern = "Unknown"
            Stability = "Unknown"
            Trend = "Unknown"
        }
        Disk = @{
            IOPattern = "Unknown"
            HighestActivity = @{}
        }
    }

    try {
        # This is a simplified implementation
        # In a full version, you would collect more detailed metrics
        
        $cpuSamples = @()
        $memorySamples = @()
        
        for ($i = 0; $i -lt 5; $i++) {
            $cpu = (Get-CimInstance -ClassName Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
            $memory = Get-CimInstance -ClassName Win32_OperatingSystem
            $memoryUsed = [Math]::Round((($memory.TotalVisibleMemorySize - $memory.FreePhysicalMemory) / $memory.TotalVisibleMemorySize) * 100, 2)
            
            $cpuSamples += $cpu
            $memorySamples += $memoryUsed
            
            if ($i -lt 4) { Start-Sleep -Seconds 30 }
        }
        
        # Analyze patterns
        $cpuVariance = ($cpuSamples | Measure-Object -StandardDeviation).StandardDeviation
        $memoryVariance = ($memorySamples | Measure-Object -StandardDeviation).StandardDeviation
        
        $utilization.CPU.Stability = if ($cpuVariance -lt 10) { "Stable" } elseif ($cpuVariance -lt 25) { "Moderate" } else { "Unstable" }
        $utilization.Memory.Stability = if ($memoryVariance -lt 5) { "Stable" } elseif ($memoryVariance -lt 15) { "Moderate" } else { "Unstable" }

    } catch {
        Write-Warning "Error monitoring resource utilization: $($_.Exception.Message)"
        $utilization["Error"] = $_.Exception.Message
    }

    return $utilization
}

function Get-ResourceAlerts {
    <#
    .SYNOPSIS
        Generates resource utilization alerts.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$Utilization,
        
        [Parameter()]
        [hashtable]$Thresholds
    )

    $alerts = @()

    if ($Utilization.CPU.Stability -eq "Unstable") {
        $alerts += "Unstable CPU utilization pattern detected"
    }

    if ($Utilization.Memory.Stability -eq "Unstable") {
        $alerts += "Unstable memory utilization pattern detected"
    }

    return $alerts
}

function Get-EventLogAnalysis {
    <#
    .SYNOPSIS
        Analyzes Windows Event Logs for issues.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [hashtable]$AlertThresholds
    )

    $analysis = @{
        CriticalErrors = 0
        Warnings = 0
        RecentErrors = @()
        TopErrorSources = @()
        AnalysisPeriod = "Last 24 hours"
    }

    try {
        $since = (Get-Date).AddHours(-24)
        
        # Get critical errors
        $criticalErrors = Get-WinEvent -FilterHashtable @{
            LogName = 'System', 'Application'
            Level = 1, 2  # Critical and Error
            StartTime = $since
        } -ErrorAction SilentlyContinue
        
        $analysis.CriticalErrors = $criticalErrors.Count
        
        # Get warnings
        $warnings = Get-WinEvent -FilterHashtable @{
            LogName = 'System', 'Application'
            Level = 3  # Warning
            StartTime = $since
        } -ErrorAction SilentlyContinue
        
        $analysis.Warnings = $warnings.Count
        
        # Recent errors (last 10)
        $analysis.RecentErrors = $criticalErrors | Select-Object -First 10 | ForEach-Object {
            @{
                TimeCreated = $_.TimeCreated
                Id = $_.Id
                LevelDisplayName = $_.LevelDisplayName
                ProviderName = $_.ProviderName
                Message = $_.Message.Substring(0, [Math]::Min(200, $_.Message.Length))
            }
        }
        
        # Top error sources
        $analysis.TopErrorSources = $criticalErrors | 
            Group-Object ProviderName | 
            Sort-Object Count -Descending | 
            Select-Object -First 5 | 
            ForEach-Object {
                @{
                    Source = $_.Name
                    Count = $_.Count
                }
            }

    } catch {
        Write-Warning "Error analyzing event logs: $($_.Exception.Message)"
        $analysis["Error"] = $_.Exception.Message
    }

    return $analysis
}

function Calculate-OverallHealthScore {
    <#
    .SYNOPSIS
        Calculates overall system health score.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$HealthReport
    )

    $score = 100  # Start with perfect score and deduct for issues

    # Deduct for alerts
    $score -= $HealthReport.Alerts.Count * 10

    # Deduct for warnings
    $score -= $HealthReport.Warnings.Count * 5

    # Performance impact
    if ($HealthReport.PerformanceMetrics) {
        if ($HealthReport.PerformanceMetrics.CPU.Average -gt 80) { $score -= 15 }
        if ($HealthReport.PerformanceMetrics.Memory.AverageUsedPercent -gt 85) { $score -= 15 }
        if ($HealthReport.PerformanceMetrics.Disk.HighestUsagePercent -gt 90) { $score -= 10 }
    }

    # Security impact
    if ($HealthReport.SecurityStatus -and $HealthReport.SecurityStatus.SecurityScore -lt 70) {
        $score -= 20
    }

    # Configuration drift impact
    if ($HealthReport.ConfigurationDrift -and $HealthReport.ConfigurationDrift.DriftDetected) {
        $score -= 10
    }

    # Event log impact
    if ($HealthReport.EventLogAnalysis -and $HealthReport.EventLogAnalysis.CriticalErrors -gt 10) {
        $score -= 15
    }

    return [Math]::Max(0, $score)
}

function Get-HealthStatus {
    <#
    .SYNOPSIS
        Converts health score to status.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]$Score
    )

    if ($Score -ge 90) { return "Excellent" }
    elseif ($Score -ge 75) { return "Good" }
    elseif ($Score -ge 60) { return "Fair" }
    elseif ($Score -ge 40) { return "Poor" }
    else { return "Critical" }
}

function Get-GeneralRecommendations {
    <#
    .SYNOPSIS
        Generates general system recommendations.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$HealthReport
    )

    $recommendations = @()

    if ($HealthReport.HealthScore -lt 60) {
        $recommendations += "System health is below optimal. Review alerts and take corrective action."
    }

    if ($HealthReport.Alerts.Count -gt 5) {
        $recommendations += "Multiple alerts detected. Prioritize addressing critical issues first."
    }

    if ($HealthReport.SystemInfo.Uptime.Days -gt 30) {
        $recommendations += "System has been running for over 30 days. Consider rebooting to apply updates and clear memory."
    }

    return $recommendations
}
