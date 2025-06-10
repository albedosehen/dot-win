function Get-DotWinStatus {
    <#
    .SYNOPSIS
        Gets the current status of the DotWin configuration management system.

    .DESCRIPTION
        The Get-DotWinStatus function provides comprehensive information about the
        current state of the DotWin system, including system information, configuration
        compliance status, and module health.

    .PARAMETER ConfigurationPath
        The path to the configuration file or directory to check status against.
        If not provided, returns general system status.

    .PARAMETER IncludeSystemInfo
        Include detailed system information in the status report.

    .PARAMETER IncludeModuleInfo
        Include DotWin module information in the status report.

    .PARAMETER IncludeCompliance
        Include configuration compliance status (requires ConfigurationPath).

    .PARAMETER Format
        The output format for the status report (Object, Json, Table).

    .EXAMPLE
        Get-DotWinStatus
        
        Gets basic DotWin system status.

    .EXAMPLE
        Get-DotWinStatus -ConfigurationPath "C:\DotWin\MyConfig.json" -IncludeCompliance
        
        Gets status including compliance check against the specified configuration.

    .EXAMPLE
        Get-DotWinStatus -IncludeSystemInfo -IncludeModuleInfo -Format Table
        
        Gets comprehensive status information formatted as a table.

    .OUTPUTS
        DotWinSystemStatus
        Returns a system status object containing current state information.

    .NOTES
        This function is read-only and does not modify the system state.
        Some system information may require administrator privileges to retrieve.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateScript({
            if ($_ -and -not (Test-Path $_)) {
                throw "Configuration path '$_' does not exist."
            }
            return $true
        })]
        [string]$ConfigurationPath,

        [Parameter()]
        [switch]$IncludeSystemInfo,

        [Parameter()]
        [switch]$IncludeModuleInfo,

        [Parameter()]
        [switch]$IncludeCompliance,

        [Parameter()]
        [ValidateSet('Object', 'Json', 'Table')]
        [string]$Format = 'Object'
    )

    begin {
        Write-DotWinLog "Retrieving DotWin system status" -Level Information
        $startTime = Get-Date
    }

    process {
        try {
            # Create base status object
            $status = [DotWinSystemStatus]::new()
            
            # Basic system information (always included)
            $status.ComputerName = $env:COMPUTERNAME
            $status.OperatingSystem = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                (Get-CimInstance Win32_OperatingSystem).Caption
            } else {
                "Non-Windows"
            }
            $status.PowerShellVersion = $PSVersionTable.PSVersion.ToString()
            $status.LastCheck = Get-Date

            # Extended system information
            if ($IncludeSystemInfo) {
                Write-DotWinLog "Gathering extended system information" -Level Verbose
                
                try {
                    $systemInfo = @{}
                    
                    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                        # Windows-specific information
                        $os = Get-CimInstance Win32_OperatingSystem
                        $computer = Get-CimInstance Win32_ComputerSystem
                        $processor = Get-CimInstance Win32_Processor | Select-Object -First 1
                        
                        $systemInfo = @{
                            OSVersion = $os.Version
                            OSBuild = $os.BuildNumber
                            OSArchitecture = $os.OSArchitecture
                            TotalMemoryGB = [Math]::Round($computer.TotalPhysicalMemory / 1GB, 2)
                            Manufacturer = $computer.Manufacturer
                            Model = $computer.Model
                            ProcessorName = $processor.Name
                            ProcessorCores = $processor.NumberOfCores
                            ProcessorLogicalProcessors = $processor.NumberOfLogicalProcessors
                            Domain = $computer.Domain
                            Workgroup = $computer.Workgroup
                            LastBootTime = $os.LastBootUpTime
                            Uptime = (Get-Date) - $os.LastBootUpTime
                        }
                        
                        # Check Windows features and capabilities
                        try {
                            $windowsFeatures = Get-WindowsOptionalFeature -Online -ErrorAction SilentlyContinue | 
                                Where-Object { $_.State -eq 'Enabled' } | 
                                Select-Object -ExpandProperty FeatureName -First 10
                            $systemInfo.EnabledWindowsFeatures = $windowsFeatures
                        } catch {
                            Write-DotWinLog "Unable to retrieve Windows features: $($_.Exception.Message)" -Level Verbose
                        }
                    }
                    
                    $status.ConfigurationStatus.SystemInfo = $systemInfo
                } catch {
                    Write-DotWinLog "Error gathering system information: $($_.Exception.Message)" -Level Warning
                    $status.ConfigurationStatus.SystemInfoError = $_.Exception.Message
                }
            }

            # Module information
            if ($IncludeModuleInfo) {
                Write-DotWinLog "Gathering module information" -Level Verbose
                
                try {
                    $moduleInfo = Get-DotWinModuleInfo
                    $status.ConfigurationStatus.ModuleInfo = @{
                        Version = $moduleInfo.Version
                        Author = $moduleInfo.Author
                        Description = $moduleInfo.Description
                        ModuleRoot = $moduleInfo.ModuleRoot
                        ConfigPath = $moduleInfo.ConfigPath
                        AppsPath = $moduleInfo.AppsPath
                        LogLevel = $moduleInfo.LogLevel
                        LogPath = $moduleInfo.LogPath
                    }
                    
                    # Check for available configuration and app files
                    $configFiles = @()
                    $appFiles = @()
                    
                    if (Test-Path $moduleInfo.ConfigPath) {
                        $configFiles = Get-ChildItem -Path $moduleInfo.ConfigPath -Filter "*.ps1" | 
                            Select-Object Name, LastWriteTime
                    }
                    
                    if (Test-Path $moduleInfo.AppsPath) {
                        $appFiles = Get-ChildItem -Path $moduleInfo.AppsPath -Filter "*.ps1" | 
                            Select-Object Name, LastWriteTime
                    }
                    
                    $status.ConfigurationStatus.ModuleInfo.AvailableConfigs = $configFiles
                    $status.ConfigurationStatus.ModuleInfo.AvailableApps = $appFiles
                    
                } catch {
                    Write-DotWinLog "Error gathering module information: $($_.Exception.Message)" -Level Warning
                    $status.ConfigurationStatus.ModuleInfoError = $_.Exception.Message
                }
            }

            # Configuration compliance check
            if ($IncludeCompliance -and $ConfigurationPath) {
                Write-DotWinLog "Checking configuration compliance" -Level Information
                
                try {
                    $complianceResults = Test-DotWinConfiguration -ConfigurationPath $ConfigurationPath
                    
                    $complianceStatus = @{
                        TotalItems = $complianceResults.Count
                        CompliantItems = ($complianceResults | Where-Object { $_.IsValid }).Count
                        NonCompliantItems = ($complianceResults | Where-Object { -not $_.IsValid }).Count
                        ErrorItems = ($complianceResults | Where-Object { $_.Severity -eq 'Error' }).Count
                        LastChecked = Get-Date
                        ConfigurationPath = $ConfigurationPath
                        Results = $complianceResults
                    }
                    
                    $status.ConfigurationStatus.Compliance = $complianceStatus
                    $status.IsCompliant = ($complianceStatus.NonCompliantItems -eq 0 -and $complianceStatus.ErrorItems -eq 0)
                    
                } catch {
                    Write-DotWinLog "Error checking configuration compliance: $($_.Exception.Message)" -Level Error
                    $status.ConfigurationStatus.ComplianceError = $_.Exception.Message
                    $status.IsCompliant = $false
                }
            }

            # Environment validation
            $envTest = Test-DotWinEnvironment
            $status.ConfigurationStatus.Environment = @{
                IsValid = $envTest.IsValid
                Issues = $envTest.Issues
                IsAdministrator = $envTest.IsAdministrator
                PowerShellVersion = $envTest.PowerShellVersion.ToString()
                OperatingSystem = $envTest.OperatingSystem
            }

            # Performance metrics
            $endTime = Get-Date
            $status.ConfigurationStatus.Performance = @{
                StatusCheckDuration = ($endTime - $startTime).TotalMilliseconds
                Timestamp = $endTime
            }

        } catch {
            Write-DotWinLog "Error retrieving system status: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        Write-DotWinLog "System status retrieval completed" -Level Information
        
        # Format output based on requested format
        switch ($Format) {
            'Json' {
                return $status | ConvertTo-Json -Depth 10
            }
            'Table' {
                # Create a simplified table view
                $tableData = [PSCustomObject]@{
                    ComputerName = $status.ComputerName
                    OperatingSystem = $status.OperatingSystem
                    PowerShellVersion = $status.PowerShellVersion
                    IsCompliant = $status.IsCompliant
                    LastCheck = $status.LastCheck
                    IsAdministrator = $status.ConfigurationStatus.Environment.IsAdministrator
                    EnvironmentValid = $status.ConfigurationStatus.Environment.IsValid
                }
                
                if ($status.ConfigurationStatus.Compliance) {
                    $tableData | Add-Member -NotePropertyName 'TotalItems' -NotePropertyValue $status.ConfigurationStatus.Compliance.TotalItems
                    $tableData | Add-Member -NotePropertyName 'CompliantItems' -NotePropertyValue $status.ConfigurationStatus.Compliance.CompliantItems
                    $tableData | Add-Member -NotePropertyName 'NonCompliantItems' -NotePropertyValue $status.ConfigurationStatus.Compliance.NonCompliantItems
                }
                
                return $tableData | Format-Table -AutoSize
            }
            default {
                return $status
            }
        }
    }
}