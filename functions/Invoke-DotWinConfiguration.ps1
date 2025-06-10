function Invoke-DotWinConfiguration {
    <#
    .SYNOPSIS
        Applies a DotWin configuration to the current system.

    .DESCRIPTION
        The Invoke-DotWinConfiguration function applies a declarative configuration
        to the current Windows system. It processes configuration items and applies
        changes in a safe, idempotent manner.

    .PARAMETER ConfigurationPath
        The path to the configuration file or directory containing configuration files.

    .PARAMETER Configuration
        A DotWinConfiguration object to apply directly.

    .PARAMETER WhatIf
        Shows what would happen if the configuration were applied without actually making changes.

    .PARAMETER Force
        Forces the application of configuration items even if they appear to be already configured.

    .PARAMETER IncludeType
        Only apply configuration items of the specified types.

    .PARAMETER ExcludeType
        Exclude configuration items of the specified types from application.

    .PARAMETER Parallel
        Apply configuration items in parallel where possible (experimental).

    .EXAMPLE
        Invoke-DotWinConfiguration -ConfigurationPath "C:\DotWin\MyConfig.json"
        
        Applies the configuration from the specified JSON file.

    .EXAMPLE
        Invoke-DotWinConfiguration -ConfigurationPath "C:\DotWin\Configs" -WhatIf
        
        Shows what changes would be made without actually applying them.

    .EXAMPLE
        $config = New-Object DotWinConfiguration
        Invoke-DotWinConfiguration -Configuration $config -IncludeType "Registry","Files"
        
        Applies only Registry and Files configuration items from the provided configuration object.

    .OUTPUTS
        DotWinExecutionResult[]
        Returns an array of execution results for each configuration item processed.

    .NOTES
        This function requires appropriate permissions for the configuration items being applied.
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
        [switch]$Force,

        [Parameter()]
        [string[]]$IncludeType,

        [Parameter()]
        [string[]]$ExcludeType,

        [Parameter()]
        [switch]$Parallel
    )

    begin {
        Write-DotWinLog "Starting configuration application" -Level Information
        
        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            throw "Environment validation failed: $($envTest.Issues -join ', ')"
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
            $itemsToProcess = $Configuration.Items
            
            if ($IncludeType) {
                $itemsToProcess = $itemsToProcess | Where-Object { $_.Type -in $IncludeType }
                Write-DotWinLog "Filtered to include types: $($IncludeType -join ', ')" -Level Information
            }
            
            if ($ExcludeType) {
                $itemsToProcess = $itemsToProcess | Where-Object { $_.Type -notin $ExcludeType }
                Write-DotWinLog "Filtered to exclude types: $($ExcludeType -join ', ')" -Level Information
            }

            Write-DotWinLog "Processing $($itemsToProcess.Count) configuration items" -Level Information

            # Process configuration items
            foreach ($item in $itemsToProcess) {
                if (-not $item.Enabled) {
                    Write-DotWinLog "Skipping disabled item: $($item.Name)" -Level Verbose
                    continue
                }

                $itemStartTime = Get-Date
                $result = [DotWinExecutionResult]::new()
                $result.ItemName = $item.Name
                $result.ItemType = $item.Type

                try {
                    Write-DotWinLog "Processing item: $($item.Name) (Type: $($item.Type))" -Level Information

                    # Test current state unless forced
                    if (-not $Force) {
                        $testResult = $item.Test()
                        if ($testResult) {
                            $result.Success = $true
                            $result.Message = "Item already in desired state"
                            Write-DotWinLog "Item '$($item.Name)' already in desired state" -Level Information
                        }
                    }

                    # Apply configuration if needed
                    if ($Force -or -not $testResult) {
                        if ($PSCmdlet.ShouldProcess($item.Name, "Apply configuration")) {
                            Write-DotWinLog "Applying configuration for item: $($item.Name)" -Level Information
                            
                            # Get current state for comparison
                            $beforeState = $item.GetCurrentState()
                            
                            # Apply the configuration
                            $item.Apply()
                            
                            # Get new state and record changes
                            $afterState = $item.GetCurrentState()
                            $result.Changes = @{
                                Before = $beforeState
                                After = $afterState
                            }
                            
                            $result.Success = $true
                            $result.Message = "Configuration applied successfully"
                            Write-DotWinLog "Successfully applied configuration for item: $($item.Name)" -Level Information
                        } else {
                            $result.Success = $true
                            $result.Message = "Configuration application skipped (WhatIf)"
                            Write-DotWinLog "Configuration application skipped for item: $($item.Name) (WhatIf)" -Level Information
                        }
                    }
                } catch {
                    $result.Success = $false
                    $result.Message = "Error applying configuration: $($_.Exception.Message)"
                    Write-DotWinLog "Error applying configuration for item '$($item.Name)': $($_.Exception.Message)" -Level Error
                    
                    # Continue processing other items unless it's a critical error
                    if ($_.Exception.Message -match "critical|fatal") {
                        throw
                    }
                } finally {
                    $result.Duration = (Get-Date) - $itemStartTime
                    $results += $result
                }
            }

        } catch {
            Write-DotWinLog "Critical error during configuration application: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        Write-DotWinLog "Configuration application completed" -Level Information
        Write-DotWinLog "Total items processed: $($results.Count)" -Level Information
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level Information
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level Information
        
        return $results
    }
}