function Install-Packages {
    <#
    .SYNOPSIS
        Installs packages using various package managers with DotWin configuration management.

    .DESCRIPTION
        The Install-Packages function provides a unified interface for installing packages
        across different package managers (Winget, Chocolatey, etc.) while integrating
        with the DotWin configuration management system.

    .PARAMETER PackageList
        Array of package specifications. Each can be a string (package ID) or hashtable with detailed configuration.

    .PARAMETER Source
        Default package source/manager to use (winget, chocolatey, etc.).

    .PARAMETER ConfigurationPath
        Path to a configuration file containing package definitions.

    .PARAMETER Category
        Install packages from a specific category (Development, Productivity, etc.).

    .PARAMETER WhatIf
        Shows what packages would be installed without actually installing them.

    .PARAMETER Force
        Forces installation even if packages appear to be already installed.

    .PARAMETER AcceptLicenses
        Automatically accept all license agreements.

    .PARAMETER Parallel
        Install packages in parallel where possible (experimental).

    .EXAMPLE
        Install-Packages -PackageList @('Git.Git', 'Microsoft.VisualStudioCode')
        
        Installs Git and Visual Studio Code using the default package manager.

    .EXAMPLE
        Install-Packages -Category 'Development' -Source 'winget'
        
        Installs all packages in the Development category using winget.

    .EXAMPLE
        $packages = @(
            @{ Id = 'Git.Git'; Version = '2.40.0' },
            @{ Id = 'Microsoft.VisualStudioCode'; InstallOptions = @{ scope = 'machine' } }
        )
        Install-Packages -PackageList $packages -WhatIf
        
        Shows what would happen when installing specific package versions with custom options.

    .OUTPUTS
        DotWinExecutionResult[]
        Returns an array of execution results for each package installation.

    .NOTES
        This function requires appropriate permissions for package installation.
        Some packages may require administrator privileges.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'PackageList')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'PackageList', Position = 0)]
        [object[]]$PackageList,

        [Parameter(Mandatory = $true, ParameterSetName = 'Category')]
        [ValidateSet('Development', 'Productivity', 'Media', 'Gaming', 'Utilities', 'Security', 'Communication')]
        [string]$Category,

        [Parameter(ParameterSetName = 'ConfigFile')]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Configuration file '$_' does not exist."
            }
            return $true
        })]
        [string]$ConfigurationPath,

        [Parameter()]
        [ValidateSet('winget', 'chocolatey', 'scoop')]
        [string]$Source = 'winget',

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$AcceptLicenses,

        [Parameter()]
        [switch]$Parallel
    )

    begin {
        # Start master progress bar for package installation process
        $masterProgressId = Start-DotWinProgress -Activity "Installing Packages" -Status "Initializing..." -TotalOperations 4
        
        try {
            Write-DotWinProgress -ProgressId $masterProgressId -Status "Validating environment..." -PercentComplete 10

            # Validate environment
            $envTest = Test-DotWinEnvironment
            if (-not $envTest.IsValid) {
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Environment validation failed: $($envTest.Issues -join ', ')"
                throw "Environment validation failed: $($envTest.Issues -join ', ')"
            }

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Loading required modules..." -PercentComplete 20

            # Import required modules/scripts
            $wingetPath = Join-Path $script:DotWinAppsPath "Winget.ps1"
            if (Test-Path $wingetPath) {
                . $wingetPath
            } else {
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Winget wrapper not found at: $wingetPath"
                throw "Winget wrapper not found at: $wingetPath"
            }

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Environment validated successfully" -PercentComplete 30
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
            # Determine packages to install based on parameter set
            $packagesToInstall = @()

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Determining packages to install..." -PercentComplete 40

            switch ($PSCmdlet.ParameterSetName) {
                'PackageList' {
                    $packagesToInstall = $PackageList
                    Write-DotWinLog "Processing $($PackageList.Count) packages from list" -Level "Information" -ShowWithProgress
                }
                
                'Category' {
                    Write-DotWinLog "Loading packages from category: $Category" -Level "Information" -ShowWithProgress
                    $packagesConfigPath = Join-Path $script:DotWinConfigPath "Packages.ps1"
                    
                    if (Test-Path $packagesConfigPath) {
                        . $packagesConfigPath
                        $packagesToInstall = Get-PackagesByCategory -Category $Category
                        Write-DotWinLog "Found $($packagesToInstall.Count) packages in category '$Category'" -Level "Information" -ShowWithProgress
                    } else {
                        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Packages configuration file not found: $packagesConfigPath"
                        throw "Packages configuration file not found: $packagesConfigPath"
                    }
                }
                
                'ConfigFile' {
                    Write-DotWinLog "Loading packages from configuration file: $ConfigurationPath" -Level "Information" -ShowWithProgress
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    $packagesToInstall = $configContent.packages
                }
            }

            if ($packagesToInstall.Count -eq 0) {
                Write-DotWinLog "No packages to install" -Level "Warning" -ShowWithProgress
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Completed (no packages)" -Message "No packages to install"
                return $results
            }

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Processing $($packagesToInstall.Count) packages using source: $Source" -PercentComplete 50 -TotalOperations $packagesToInstall.Count

            # Process packages with progress tracking
            if ($Parallel -and $packagesToInstall.Count -gt 1) {
                Write-DotWinLog "Installing packages in parallel" -Level "Information" -ShowWithProgress
                $results = Install-PackagesParallel -Packages $packagesToInstall -Source $Source -Force:$Force -AcceptLicenses:$AcceptLicenses -MasterProgressId $masterProgressId
            } else {
                $results = Install-PackagesSequential -Packages $packagesToInstall -Source $Source -Force:$Force -AcceptLicenses:$AcceptLicenses -MasterProgressId $masterProgressId
            }

        } catch {
            Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Critical error during package installation: $($_.Exception.Message)"
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        # Calculate throughput metrics
        $packagesPerSecond = if ($totalDuration.TotalSeconds -gt 0) { [Math]::Round($results.Count / $totalDuration.TotalSeconds, 2) } else { 0 }
        $alreadyInstalled = ($results | Where-Object { $_.Message -like "*already installed*" }).Count
        $actuallyInstalled = ($results | Where-Object { $_.Success -and $_.Message -notlike "*already installed*" -and $_.Message -notlike "*skipped*" }).Count

        # Complete master progress with summary statistics
        $summaryMetrics = @{
            TotalPackages = $results.Count
            SuccessfulInstalls = $successCount
            FailedInstalls = $failureCount
            ActuallyInstalled = $actuallyInstalled
            AlreadyInstalled = $alreadyInstalled
            TotalDurationSeconds = [Math]::Round($totalDuration.TotalSeconds, 2)
            AveragePackageDuration = if ($results.Count -gt 0) { [Math]::Round(($results | ForEach-Object { $_.Duration.TotalSeconds } | Measure-Object -Average).Average, 2) } else { 0 }
            PackagesPerSecond = $packagesPerSecond
            InstallationSource = $Source
            ParallelMode = $Parallel.IsPresent
        }

        $summaryMessage = "Package installation completed: $successCount successful, $failureCount failed (Total: $($results.Count) packages, Actually installed: $actuallyInstalled, Throughput: $packagesPerSecond pkg/s, Duration: $($summaryMetrics.TotalDurationSeconds)s)"

        Write-DotWinProgress -ProgressId $masterProgressId -Status "Finalizing..." -PercentComplete 95
        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Completed" -FinalMetrics $summaryMetrics -Message $summaryMessage

        # Show summary with progress coordination
        Write-DotWinLog "Package installation completed" -Level "Information" -ShowWithProgress
        Write-DotWinLog "Total packages processed: $($results.Count)" -Level "Information" -ShowWithProgress
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level "Information" -ShowWithProgress
        Write-DotWinLog "Actually installed: $actuallyInstalled, Already installed: $alreadyInstalled" -Level "Information" -ShowWithProgress
        Write-DotWinLog "Throughput: $packagesPerSecond packages/second" -Level "Information" -ShowWithProgress
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level "Information" -ShowWithProgress
        
        # Ensure we always return an array, even for single items
        if ($results -is [array]) {
            return $results
        } else {
            return @($results)
        }
    }
}

function Install-PackagesSequential {
    <#
    .SYNOPSIS
        Installs packages sequentially.
    
    .DESCRIPTION
        Internal function to install packages one by one in sequence.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object[]]$Packages,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('winget', 'chocolatey', 'scoop')]
        [string]$Source,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$AcceptLicenses,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MasterProgressId
    )
    
    $results = @()
    $packageIndex = 0
    
    foreach ($packageSpec in $Packages) {
        $packageIndex++
        $packageProgressPercent = [Math]::Round((($packageIndex / $Packages.Count) * 40) + 50, 0)

        # Create nested progress for individual package
        $packageProgressId = Start-DotWinProgress -Activity "Installing: $($packageSpec.Id -or $packageSpec.PackageId -or $packageSpec)" -Status "Initializing..." -ParentId $MasterProgressId

        # Update master progress
        Write-DotWinProgress -ProgressId $MasterProgressId -Status "Installing package $packageIndex of $($Packages.Count): $($packageSpec.Id -or $packageSpec.PackageId -or $packageSpec)" -PercentComplete $packageProgressPercent -CurrentOperation $packageIndex

        $packageStartTime = Get-Date
        $result = [DotWinExecutionResult]::new()
        
        try {
            Write-DotWinProgress -ProgressId $packageProgressId -Status "Parsing package configuration..." -PercentComplete 10

            # Parse package specification
            $packageConfig = ConvertTo-PackageConfiguration -PackageSpec $packageSpec -Source $Source -AcceptLicenses:$AcceptLicenses
            
            $result.ItemName = $packageConfig.PackageId
            $result.ItemType = "Package"
            $result.ProgressId = $packageProgressId
            
            Write-DotWinProgress -ProgressId $packageProgressId -Status "Creating package configuration..." -PercentComplete 20
            
            # Create appropriate package configuration item
            $packageItem = switch ($Source.ToLower()) {
                'winget' {
                    $item = [DotWinWingetPackage]::new($packageConfig.PackageId)
                    $item.Version = $packageConfig.Version
                    $item.Source = $packageConfig.Source
                    $item.AcceptLicense = $packageConfig.AcceptLicense
                    $item.AcceptSourceAgreements = $packageConfig.AcceptSourceAgreements
                    $item.InstallOptions = $packageConfig.InstallOptions
                    $item
                }
                default {
                    throw "Unsupported package source: $Source"
                }
            }
            
            # Test if package is already installed (unless forced)
            if (-not $Force) {
                Write-DotWinProgress -ProgressId $packageProgressId -Status "Checking if already installed..." -PercentComplete 30
                $isInstalled = $packageItem.Test()
                if ($isInstalled) {
                    $result.Success = $true
                    $result.Message = "Package already installed"
                    Write-DotWinProgress -ProgressId $packageProgressId -Status "Already installed, skipping..." -PercentComplete 100
                    Complete-DotWinProgress -ProgressId $packageProgressId -Status "Skipped (already installed)" -Message "Package '$($packageConfig.PackageId)' is already installed"
                    $result.Duration = (Get-Date) - $packageStartTime
                    $results += $result
                    continue
                }
            }
            
            # Install the package
            if ($PSCmdlet.ShouldProcess($packageConfig.PackageId, "Install package")) {
                Write-DotWinProgress -ProgressId $packageProgressId -Status "Installing package..." -PercentComplete 50
                
                # Get current state for comparison
                $beforeState = $packageItem.GetCurrentState()
                
                # Apply the installation
                $packageItem.Apply()
                
                # Get new state and record changes
                $afterState = $packageItem.GetCurrentState()
                $result.Changes = @{
                    Before = $beforeState
                    After = $afterState
                }
                
                $result.Success = $true
                $result.Message = "Package installed successfully"
                Write-DotWinProgress -ProgressId $packageProgressId -Status "Installation completed successfully" -PercentComplete 100
                Complete-DotWinProgress -ProgressId $packageProgressId -Status "Completed successfully" -Message "Successfully installed package: $($packageConfig.PackageId)"
            } else {
                $result.Success = $true
                $result.Message = "Package installation skipped (WhatIf)"
                Write-DotWinProgress -ProgressId $packageProgressId -Status "Skipped (WhatIf mode)" -PercentComplete 100
                Complete-DotWinProgress -ProgressId $packageProgressId -Status "Skipped (WhatIf)" -Message "Package installation skipped: $($packageConfig.PackageId) (WhatIf)"
            }
            
        } catch {
            $result.Success = $false
            $result.Message = "Error installing package: $($_.Exception.Message)"
            Write-DotWinProgress -ProgressId $packageProgressId -Status "Failed" -PercentComplete 100
            Complete-DotWinProgress -ProgressId $packageProgressId -Status "Failed" -Message "Error installing package '$($result.ItemName)': $($_.Exception.Message)"
        } finally {
            $result.Duration = (Get-Date) - $packageStartTime
            $results += $result
        }
    }
    
    return $results
}

function Install-PackagesParallel {
    <#
    .SYNOPSIS
        Installs packages in parallel.
    
    .DESCRIPTION
        Internal function to install packages in parallel using PowerShell jobs.
        This is experimental and may not work with all package managers.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [object[]]$Packages,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('winget', 'chocolatey', 'scoop')]
        [string]$Source,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$AcceptLicenses,

        [Parameter()]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$MasterProgressId
    )
    
    Write-DotWinLog "Parallel installation is experimental and may not work with all packages" -Level "Warning" -ShowWithProgress
    
    # Create nested progress for parallel operations
    $parallelProgressId = Start-DotWinProgress -Activity "Parallel Package Installation" -Status "Starting parallel jobs..." -ParentId $MasterProgressId

    $jobs = @()
    $results = @()
    
    try {
        Write-DotWinProgress -ProgressId $parallelProgressId -Status "Starting installation jobs..." -PercentComplete 10

        # Start installation jobs
        $jobIndex = 0
        foreach ($packageSpec in $Packages) {
            $jobIndex++
            $packageConfig = ConvertTo-PackageConfiguration -PackageSpec $packageSpec -Source $Source -AcceptLicenses:$AcceptLicenses
            
            $scriptBlock = {
                param($PackageId, $Version, $Source, $AcceptLicense, $AcceptSourceAgreements, $InstallOptions)
                
                try {
                    # Import winget functions (this is a simplified version for parallel execution)
                    if ($Source -eq 'winget') {
                        $arguments = @('install', $PackageId, '--silent')
                        
                        if ($Version) { $arguments += @('--version', $Version) }
                        if ($AcceptLicense) { $arguments += '--accept-package-agreements' }
                        if ($AcceptSourceAgreements) { $arguments += '--accept-source-agreements' }
                        
                        $result = Start-Process -FilePath 'winget' -ArgumentList $arguments -Wait -PassThru -NoNewWindow
                        
                        return @{
                            Success = ($result.ExitCode -eq 0)
                            ExitCode = $result.ExitCode
                            PackageId = $PackageId
                        }
                    }
                } catch {
                    return @{
                        Success = $false
                        Error = $_.Exception.Message
                        PackageId = $PackageId
                    }
                }
            }
            
            $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList @(
                $packageConfig.PackageId,
                $packageConfig.Version,
                $packageConfig.Source,
                $packageConfig.AcceptLicense,
                $packageConfig.AcceptSourceAgreements,
                $packageConfig.InstallOptions
            )
            
            $jobs += @{
                Job = $job
                PackageId = $packageConfig.PackageId
                StartTime = Get-Date
            }
            
            Write-DotWinLog "Started installation job for package: $($packageConfig.PackageId)" -Level "Verbose" -ShowWithProgress
        }
        
        Write-DotWinProgress -ProgressId $parallelProgressId -Status "Waiting for $($jobs.Count) parallel jobs to complete..." -PercentComplete 30

        # Wait for jobs to complete and collect results
        $completedJobs = 0
        foreach ($jobInfo in $jobs) {
            $job = $jobInfo.Job
            $packageId = $jobInfo.PackageId
            $startTime = $jobInfo.StartTime
            
            $completedJobs++
            $jobProgressPercent = [Math]::Round((($completedJobs / $jobs.Count) * 60) + 30, 0)
            Write-DotWinProgress -ProgressId $parallelProgressId -Status "Collecting results from job $completedJobs of $($jobs.Count): $packageId" -PercentComplete $jobProgressPercent

            $jobResult = Receive-Job -Job $job -Wait
            Remove-Job -Job $job
            
            $result = [DotWinExecutionResult]::new()
            $result.ItemName = $packageId
            $result.ItemType = "Package"
            $result.Duration = (Get-Date) - $startTime
            
            if ($jobResult.Success) {
                $result.Success = $true
                $result.Message = "Package installed successfully (parallel)"
                Write-DotWinLog "Successfully installed package: $packageId" -Level "Information" -ShowWithProgress
            } else {
                $result.Success = $false
                $result.Message = "Error installing package: $($jobResult.Error)"
                Write-DotWinLog "Error installing package '$packageId': $($jobResult.Error)" -Level "Error" -ShowWithProgress
            }
            
            $results += $result
        }
        
        Write-DotWinProgress -ProgressId $parallelProgressId -Status "All parallel jobs completed" -PercentComplete 100
        Complete-DotWinProgress -ProgressId $parallelProgressId -Status "Completed" -Message "Parallel package installation completed: $($results.Count) packages processed"

    } catch {
        # Clean up any remaining jobs
        foreach ($jobInfo in $jobs) {
            if ($jobInfo.Job.State -eq 'Running') {
                Stop-Job -Job $jobInfo.Job
                Remove-Job -Job $jobInfo.Job
            }
        }
        Complete-DotWinProgress -ProgressId $parallelProgressId -Status "Failed" -Message "Parallel package installation failed: $($_.Exception.Message)"
        throw
    }
    
    return $results
}

function ConvertTo-PackageConfiguration {
    <#
    .SYNOPSIS
        Converts a package specification to a standardized configuration object.
    
    .DESCRIPTION
        Internal function to normalize package specifications from various formats
        into a consistent configuration object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [object]$PackageSpec,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet('winget', 'chocolatey', 'scoop')]
        [string]$Source,
        
        [Parameter()]
        [switch]$AcceptLicenses
    )
    
    $config = @{
        PackageId = $null
        Version = $null
        Source = $Source
        AcceptLicense = $AcceptLicenses.IsPresent
        AcceptSourceAgreements = $AcceptLicenses.IsPresent
        InstallOptions = @{}
    }
    
    if ($PackageSpec -is [string]) {
        # Simple string package ID
        $config.PackageId = $PackageSpec
    } elseif ($PackageSpec -is [hashtable] -or $PackageSpec -is [PSCustomObject]) {
        # Detailed package configuration
        $config.PackageId = if ($PackageSpec.Id) { $PackageSpec.Id } elseif ($PackageSpec.PackageId) { $PackageSpec.PackageId } else { $PackageSpec.Name }
        $config.Version = $PackageSpec.Version
        $config.Source = if ($PackageSpec.Source) { $PackageSpec.Source } else { $Source }
        
        if ($null -ne $PackageSpec.AcceptLicense) {
            $config.AcceptLicense = $PackageSpec.AcceptLicense
        }
        
        if ($null -ne $PackageSpec.AcceptSourceAgreements) {
            $config.AcceptSourceAgreements = $PackageSpec.AcceptSourceAgreements
        }
        
        if ($PackageSpec.InstallOptions) {
            $config.InstallOptions = $PackageSpec.InstallOptions
        }
    } else {
        throw "Invalid package specification format. Expected string or hashtable/object."
    }
    
    if (-not $config.PackageId) {
        throw "Package ID is required but not specified in package specification."
    }
    
    return $config
}
