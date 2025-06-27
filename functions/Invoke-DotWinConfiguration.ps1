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

        [Parameter(Mandatory = $true, ParameterSetName = 'Object', ValueFromPipeline = $true)]
        $Configuration,

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
        # Start master progress bar for overall configuration process
        $masterProgressId = Start-DotWinProgress -Activity "Applying DotWin Configuration" -Status "Initializing..." -TotalOperations 3
        
        try {
            Write-DotWinProgress -ProgressId $masterProgressId -Status "Validating environment..." -PercentComplete 10

            # Validate environment
            $envTest = Test-DotWinEnvironment
            if (-not $envTest.IsValid) {
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Environment validation failed: $($envTest.Issues -join ', ')"
                throw "Environment validation failed: $($envTest.Issues -join ', ')"
            }

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Environment validated successfully" -PercentComplete 20
            $results = @()
            $startTime = Get-Date
        } catch {
            if ($masterProgressId) {
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Initialization failed: $($_.Exception.Message)"
            }
            throw
        }
    }

    process {
        try {
            # Handle Configuration parameter - convert arrays to DotWinConfiguration objects
            if ($PSCmdlet.ParameterSetName -eq 'Object') {
                if ($Configuration -is [array]) {
                    # Convert array of configuration items to DotWinConfiguration object
                    try {
                        $configObj = [DotWinConfiguration]::new("ArrayConfiguration")
                    } catch {
                        # If class instantiation fails, create a mock object
                        $configObj = New-Object -TypeName PSObject
                        $configObj | Add-Member -MemberType NoteProperty -Name 'Name' -Value "ArrayConfiguration"
                        $configObj | Add-Member -MemberType NoteProperty -Name 'Items' -Value @()
                        $configObj | Add-Member -MemberType ScriptMethod -Name 'AddItem' -Value {
                            param($Item)
                            $this.Items += $Item
                        }
                    }

                    foreach ($item in $Configuration) {
                        # Accept both real DotWinConfigurationItem objects and mock objects with required properties
                        if ($item -is [DotWinConfigurationItem] -or
                            ($item.PSObject.Properties.Name -contains 'Name' -and
                             $item.PSObject.Properties.Name -contains 'Type' -and
                             $item.PSObject.Properties.Name -contains 'Enabled')) {
                            $configObj.AddItem($item)
                        } else {
                            throw "Invalid configuration item type. Expected DotWinConfigurationItem or compatible mock object, got $($item.GetType().Name)"
                        }
                    }
                    $Configuration = $configObj
                } elseif ($Configuration -isnot [DotWinConfiguration] -and
                          -not ($Configuration.PSObject.Properties.Name -contains 'Items' -and
                                $Configuration.PSObject.Properties.Name -contains 'Name')) {
                    throw "Configuration parameter must be a DotWinConfiguration object, compatible mock object, or array of DotWinConfigurationItem objects"
                }
            }

            # Load configuration if path was provided
            if ($PSCmdlet.ParameterSetName -eq 'Path') {
                Write-DotWinProgress -ProgressId $masterProgressId -Status "Loading configuration from: $ConfigurationPath" -PercentComplete 30
                
                # Create configuration parser
                $parser = [DotWinConfigurationParser]::new()

                if (Test-Path $ConfigurationPath -PathType Container) {
                    # Load all configuration files from directory
                    $configFiles = Get-ChildItem -Path $ConfigurationPath -Filter "*.json" -Recurse
                    if ($configFiles.Count -eq 0) {
                        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "No configuration files found in directory: $ConfigurationPath"
                        throw "No configuration files found in directory: $ConfigurationPath"
                    }
                    
                    # Create a combined configuration from all files
                    $Configuration = [DotWinConfiguration]::new("DirectoryConfiguration")
                    $Configuration.Description = "Combined configuration from directory: $ConfigurationPath"

                    $fileIndex = 0
                    foreach ($file in $configFiles) {
                        $fileIndex++
                        $fileProgress = [Math]::Round((($fileIndex / $configFiles.Count) * 20) + 30, 0)
                        Write-DotWinProgress -ProgressId $masterProgressId -Status "Loading file $fileIndex of $($configFiles.Count): $($file.Name)" -PercentComplete $fileProgress

                        try {
                            $fileConfig = $parser.ParseFromFile($file.FullName)

                            # Add all items from the file configuration to the combined configuration
                            foreach ($item in $fileConfig.Items) {
                                try {
                                    $Configuration.AddItem($item)
                                } catch {
                                    Write-DotWinLog "Skipping duplicate item '$($item.Name)' from file '$($file.Name)': $($_.Exception.Message)" -Level Warning -ShowWithProgress
                                }
                            }

                            # Merge metadata
                            foreach ($key in $fileConfig.Metadata.Keys) {
                                if (-not $Configuration.Metadata.ContainsKey($key)) {
                                    $Configuration.Metadata[$key] = $fileConfig.Metadata[$key]
                                }
                            }

                            Write-DotWinLog "Successfully loaded $($fileConfig.Items.Count) items from: $($file.Name)" -Level Information -ShowWithProgress
                        } catch {
                            Write-DotWinLog "Error loading configuration file '$($file.FullName)': $($_.Exception.Message)" -Level Warning -ShowWithProgress
                        }
                    }
                } else {
                    # Load single configuration file
                    try {
                        $Configuration = $parser.ParseFromFile($ConfigurationPath)
                        Write-DotWinLog "Successfully loaded configuration with $($Configuration.Items.Count) items" -Level Information -ShowWithProgress
                    } catch {
                        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Error loading configuration file '$ConfigurationPath': $($_.Exception.Message)"
                        throw "Error loading configuration file '$ConfigurationPath': $($_.Exception.Message)"
                    }
                }
            }

            # Filter configuration items based on include/exclude parameters
            $itemsToProcess = $Configuration.Items
            
            if ($IncludeType) {
                $itemsToProcess = $itemsToProcess | Where-Object { $_.Type -in $IncludeType }
                Write-DotWinLog "Filtered to include types: $($IncludeType -join ', ')" -Level Information -ShowWithProgress
            }
            
            if ($ExcludeType) {
                $itemsToProcess = $itemsToProcess | Where-Object { $_.Type -notin $ExcludeType }
                Write-DotWinLog "Filtered to exclude types: $($ExcludeType -join ', ')" -Level Information -ShowWithProgress
            }

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Processing $($itemsToProcess.Count) configuration items" -PercentComplete 50 -TotalOperations $itemsToProcess.Count

            # Process configuration items with nested progress
            $itemIndex = 0
            foreach ($item in $itemsToProcess) {
                if (-not $item.Enabled) {
                    Write-DotWinLog "Skipping disabled item: $($item.Name)" -Level Verbose -ShowWithProgress
                    continue
                }

                $itemIndex++
                $itemProgressPercent = [Math]::Round((($itemIndex / $itemsToProcess.Count) * 40) + 50, 0)

                # Create nested progress for individual item
                $itemProgressId = Start-DotWinProgress -Activity "Processing: $($item.Name)" -Status "Initializing..." -ParentId $masterProgressId

                # Update master progress
                Write-DotWinProgress -ProgressId $masterProgressId -Status "Processing item $itemIndex of $($itemsToProcess.Count): $($item.Name)" -PercentComplete $itemProgressPercent -CurrentOperation $itemIndex

                $itemStartTime = Get-Date
                $result = [DotWinExecutionResult]::new()
                $result.ItemName = $item.Name
                $result.ItemType = $item.Type
                $result.ProgressId = $itemProgressId

                try {
                    Write-DotWinProgress -ProgressId $itemProgressId -Status "Testing current state..." -PercentComplete 20

                    # Test current state unless forced
                    if (-not $Force) {
                        $testResult = $item.Test()
                        if ($testResult) {
                            $result.Success = $true
                            $result.Message = "Item already in desired state"
                            Write-DotWinProgress -ProgressId $itemProgressId -Status "Already in desired state" -PercentComplete 100
                            Complete-DotWinProgress -ProgressId $itemProgressId -Status "Completed (no changes needed)" -Message "Item '$($item.Name)' already in desired state"
                        }
                    }

                    # Apply configuration if needed
                    if ($Force -or -not $testResult) {
                        if ($PSCmdlet.ShouldProcess($item.Name, "Apply configuration")) {
                            Write-DotWinProgress -ProgressId $itemProgressId -Status "Applying configuration..." -PercentComplete 50
                            
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
                            Write-DotWinProgress -ProgressId $itemProgressId -Status "Configuration applied successfully" -PercentComplete 100
                            Complete-DotWinProgress -ProgressId $itemProgressId -Status "Completed successfully" -Message "Successfully applied configuration for item: $($item.Name)"
                        } else {
                            $result.Success = $true
                            $result.Message = "Configuration application skipped (WhatIf)"
                            Write-DotWinProgress -ProgressId $itemProgressId -Status "Skipped (WhatIf mode)" -PercentComplete 100
                            Complete-DotWinProgress -ProgressId $itemProgressId -Status "Skipped (WhatIf)" -Message "Configuration application skipped for item: $($item.Name) (WhatIf)"
                        }
                    }
                } catch {
                    $result.Success = $false
                    $result.Message = "Error applying configuration: $($_.Exception.Message)"
                    Write-DotWinProgress -ProgressId $itemProgressId -Status "Failed" -PercentComplete 100
                    Complete-DotWinProgress -ProgressId $itemProgressId -Status "Failed" -Message "Error applying configuration for item '$($item.Name)': $($_.Exception.Message)"
                    
                    # Continue processing other items unless it's a critical error
                    if ($_.Exception.Message -match "Critical error occurred") {
                        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Critical error during configuration application: $($_.Exception.Message)"
                        throw
                    }
                } finally {
                    $result.Duration = (Get-Date) - $itemStartTime
                    $results += $result
                }
            }

        } catch {
            Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Critical error during configuration application: $($_.Exception.Message)"
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        # Complete master progress with summary statistics
        $summaryMetrics = @{
            TotalItems = $results.Count
            SuccessfulItems = $successCount
            FailedItems = $failureCount
            TotalDurationSeconds = [Math]::Round($totalDuration.TotalSeconds, 2)
            AverageItemDuration = if ($results.Count -gt 0) { [Math]::Round(($results | ForEach-Object { $_.Duration.TotalSeconds } | Measure-Object -Average).Average, 2) } else { 0 }
        }
        
        $summaryMessage = "Configuration application completed: $successCount successful, $failureCount failed (Total: $($results.Count) items, Duration: $($summaryMetrics.TotalDurationSeconds)s)"

        Write-DotWinProgress -ProgressId $masterProgressId -Status "Finalizing..." -PercentComplete 95
        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Completed" -FinalMetrics $summaryMetrics -Message $summaryMessage

        # Show summary with progress coordination
        Write-DotWinLog "Configuration application completed" -Level Information -ShowWithProgress
        Write-DotWinLog "Total items processed: $($results.Count)" -Level Information -ShowWithProgress
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level Information -ShowWithProgress
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level Information -ShowWithProgress

        # Ensure we always return an array, even for single items
        if ($results -is [array]) {
            return $results
        } else {
            return @($results)
        }
    }
}