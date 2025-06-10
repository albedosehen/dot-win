function Test-DotWinConfiguration {
    <#
    .SYNOPSIS
        Tests a DotWin configuration against the current system state.

    .DESCRIPTION
        The Test-DotWinConfiguration function validates a declarative configuration
        against the current Windows system state without making any changes. It reports
        which configuration items are compliant and which need attention.

    .PARAMETER ConfigurationPath
        The path to the configuration file or directory containing configuration files.

    .PARAMETER Configuration
        A DotWinConfiguration object to test directly.

    .PARAMETER IncludeType
        Only test configuration items of the specified types.

    .PARAMETER ExcludeType
        Exclude configuration items of the specified types from testing.

    .PARAMETER Detailed
        Returns detailed information about each configuration item's current state.

    .PARAMETER Parallel
        Test configuration items in parallel where possible (experimental).

    .EXAMPLE
        Test-DotWinConfiguration -ConfigurationPath "C:\DotWin\MyConfig.json"
        
        Tests the configuration from the specified JSON file.

    .EXAMPLE
        Test-DotWinConfiguration -ConfigurationPath "C:\DotWin\Configs" -Detailed
        
        Tests all configurations in the directory and returns detailed state information.

    .EXAMPLE
        $config = New-Object DotWinConfiguration
        Test-DotWinConfiguration -Configuration $config -IncludeType "Registry"
        
        Tests only Registry configuration items from the provided configuration object.

    .OUTPUTS
        DotWinValidationResult[]
        Returns an array of validation results for each configuration item tested.

    .NOTES
        This function is read-only and does not modify the system state.
        It can be run without administrator privileges for most configuration types.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Path')]
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
        [string[]]$IncludeType,

        [Parameter()]
        [string[]]$ExcludeType,

        [Parameter()]
        [switch]$Detailed,

        [Parameter()]
        [switch]$Parallel
    )

    begin {
        Write-DotWinLog "Starting configuration testing" -Level Information
        
        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            Write-Warning "Environment validation issues detected: $($envTest.Issues -join ', ')"
        }

        $results = @()
        $startTime = Get-Date
    }

    process {
        try {
            # Load configuration if path was provided
            if ($PSCmdlet.ParameterSetName -eq 'Path') {
                Write-DotWinLog "Loading configuration from: $ConfigurationPath" -Level Information
                
                if (Test-Path $ConfigurationPath -PathType Container) {
                    # Load all configuration files from directory
                    $configFiles = Get-ChildItem -Path $ConfigurationPath -Filter "*.json" -Recurse
                    if ($configFiles.Count -eq 0) {
                        throw "No configuration files found in directory: $ConfigurationPath"
                    }
                    
                    $Configuration = [DotWinConfiguration]::new("DirectoryConfiguration")
                    foreach ($file in $configFiles) {
                        Write-DotWinLog "Loading configuration file: $($file.FullName)" -Level Verbose
                        # TODO: Implement configuration file parsing in future phases
                        Write-Warning "Configuration file parsing not yet implemented: $($file.FullName)"
                    }
                } else {
                    # Load single configuration file
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    # TODO: Implement configuration object creation from JSON in future phases
                    $Configuration = [DotWinConfiguration]::new("FileConfiguration")
                    Write-Warning "Configuration file parsing not yet implemented. Using empty configuration."
                }
            }

            # Filter configuration items based on include/exclude parameters
            $itemsToTest = $Configuration.Items
            
            if ($IncludeType) {
                $itemsToTest = $itemsToTest | Where-Object { $_.Type -in $IncludeType }
                Write-DotWinLog "Filtered to include types: $($IncludeType -join ', ')" -Level Information
            }
            
            if ($ExcludeType) {
                $itemsToTest = $itemsToTest | Where-Object { $_.Type -notin $ExcludeType }
                Write-DotWinLog "Filtered to exclude types: $($ExcludeType -join ', ')" -Level Information
            }

            Write-DotWinLog "Testing $($itemsToTest.Count) configuration items" -Level Information

            # Test configuration items
            if ($Parallel -and $itemsToTest.Count -gt 1) {
                Write-DotWinLog "Running tests in parallel" -Level Information
                
                # Use PowerShell jobs for parallel execution
                $jobs = @()
                foreach ($item in $itemsToTest) {
                    if ($item.Enabled) {
                        $job = Start-Job -ScriptBlock {
                            param($ItemToTest, $DetailedMode)
                            
                            $result = [DotWinValidationResult]::new()
                            $result.ItemName = $ItemToTest.Name
                            $result.ItemType = $ItemToTest.Type
                            
                            try {
                                $testResult = $ItemToTest.Test()
                                $result.IsValid = $testResult
                                $result.Message = if ($testResult) { 
                                    "Configuration item is compliant" 
                                } else { 
                                    "Configuration item needs attention" 
                                }
                                $result.Severity = if ($testResult) { "Information" } else { "Warning" }
                                
                                if ($DetailedMode) {
                                    $currentState = $ItemToTest.GetCurrentState()
                                    $result.Message += " | Current state: $($currentState | ConvertTo-Json -Compress)"
                                }
                            } catch {
                                $result.IsValid = $false
                                $result.Message = "Error testing configuration: $($_.Exception.Message)"
                                $result.Severity = "Error"
                            }
                            
                            return $result
                        } -ArgumentList $item, $Detailed
                        
                        $jobs += $job
                    }
                }
                
                # Wait for all jobs to complete and collect results
                $results = $jobs | Wait-Job | Receive-Job
                $jobs | Remove-Job
                
            } else {
                # Sequential execution
                foreach ($item in $itemsToTest) {
                    if (-not $item.Enabled) {
                        Write-DotWinLog "Skipping disabled item: $($item.Name)" -Level Verbose
                        continue
                    }

                    $result = [DotWinValidationResult]::new()
                    $result.ItemName = $item.Name
                    $result.ItemType = $item.Type

                    try {
                        Write-DotWinLog "Testing item: $($item.Name) (Type: $($item.Type))" -Level Verbose

                        $testResult = $item.Test()
                        $result.IsValid = $testResult
                        $result.Message = if ($testResult) { 
                            "Configuration item is compliant" 
                        } else { 
                            "Configuration item needs attention" 
                        }
                        $result.Severity = if ($testResult) { "Information" } else { "Warning" }
                        
                        if ($Detailed) {
                            try {
                                $currentState = $item.GetCurrentState()
                                $result.Message += " | Current state: $($currentState | ConvertTo-Json -Compress)"
                            } catch {
                                $result.Message += " | Unable to retrieve current state: $($_.Exception.Message)"
                            }
                        }
                        
                        Write-DotWinLog "Test result for '$($item.Name)': $($result.Message)" -Level Information
                        
                    } catch {
                        $result.IsValid = $false
                        $result.Message = "Error testing configuration: $($_.Exception.Message)"
                        $result.Severity = "Error"
                        Write-DotWinLog "Error testing item '$($item.Name)': $($_.Exception.Message)" -Level Error
                    }
                    
                    $results += $result
                }
            }

        } catch {
            Write-DotWinLog "Critical error during configuration testing: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $compliantCount = ($results | Where-Object { $_.IsValid }).Count
        $nonCompliantCount = ($results | Where-Object { -not $_.IsValid }).Count
        
        Write-DotWinLog "Configuration testing completed" -Level Information
        Write-DotWinLog "Total items tested: $($results.Count)" -Level Information
        Write-DotWinLog "Compliant: $compliantCount, Non-compliant: $nonCompliantCount" -Level Information
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level Information
        
        # Display summary if running interactively
        if ($Host.UI.RawUI.KeyAvailable -eq $false) {
            Write-Host "`nConfiguration Test Summary:" -ForegroundColor Cyan
            Write-Host "  Total Items: $($results.Count)" -ForegroundColor White
            Write-Host "  Compliant: $compliantCount" -ForegroundColor Green
            Write-Host "  Non-Compliant: $nonCompliantCount" -ForegroundColor Yellow
            if ($nonCompliantCount -gt 0) {
                Write-Host "  Errors: $(($results | Where-Object { $_.Severity -eq 'Error' }).Count)" -ForegroundColor Red
            }
        }
        
        return $results
    }
}