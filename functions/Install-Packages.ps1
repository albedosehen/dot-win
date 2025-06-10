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
        Write-DotWinLog "Starting package installation process" -Level Information
        
        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            throw "Environment validation failed: $($envTest.Issues -join ', ')"
        }

        # Import required modules/scripts
        $wingetPath = Join-Path $script:DotWinAppsPath "Winget.ps1"
        if (Test-Path $wingetPath) {
            . $wingetPath
        } else {
            throw "Winget wrapper not found at: $wingetPath"
        }

        $results = @()
        $startTime = Get-Date
    }

    process {
        try {
            # Determine packages to install based on parameter set
            $packagesToInstall = @()

            switch ($PSCmdlet.ParameterSetName) {
                'PackageList' {
                    $packagesToInstall = $PackageList
                    Write-DotWinLog "Processing $($PackageList.Count) packages from list" -Level Information
                }
                
                'Category' {
                    Write-DotWinLog "Loading packages from category: $Category" -Level Information
                    $packagesConfigPath = Join-Path $script:DotWinConfigPath "Packages.ps1"
                    
                    if (Test-Path $packagesConfigPath) {
                        . $packagesConfigPath
                        $packagesToInstall = Get-PackagesByCategory -Category $Category
                        Write-DotWinLog "Found $($packagesToInstall.Count) packages in category '$Category'" -Level Information
                    } else {
                        throw "Packages configuration file not found: $packagesConfigPath"
                    }
                }
                
                'ConfigFile' {
                    Write-DotWinLog "Loading packages from configuration file: $ConfigurationPath" -Level Information
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    $packagesToInstall = $configContent.packages
                }
            }

            if ($packagesToInstall.Count -eq 0) {
                Write-DotWinLog "No packages to install" -Level Warning
                return $results
            }

            Write-DotWinLog "Installing $($packagesToInstall.Count) packages using source: $Source" -Level Information

            # Process packages
            if ($Parallel -and $packagesToInstall.Count -gt 1) {
                Write-DotWinLog "Installing packages in parallel" -Level Information
                $results = Install-PackagesParallel -Packages $packagesToInstall -Source $Source -Force:$Force -AcceptLicenses:$AcceptLicenses
            } else {
                $results = Install-PackagesSequential -Packages $packagesToInstall -Source $Source -Force:$Force -AcceptLicenses:$AcceptLicenses
            }

        } catch {
            Write-DotWinLog "Critical error during package installation: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        Write-DotWinLog "Package installation completed" -Level Information
        Write-DotWinLog "Total packages processed: $($results.Count)" -Level Information
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level Information
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level Information
        
        return $results
    }
}

function Install-PackagesSequential {
    <#
    .SYNOPSIS
        Installs packages sequentially.
    
    .DESCRIPTION
        Internal function to install packages one by one in sequence.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Packages,
        
        [Parameter(Mandatory = $true)]
        [string]$Source,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$AcceptLicenses
    )
    
    $results = @()
    
    foreach ($packageSpec in $Packages) {
        $packageStartTime = Get-Date
        $result = [DotWinExecutionResult]::new()
        
        try {
            # Parse package specification
            $packageConfig = ConvertTo-PackageConfiguration -PackageSpec $packageSpec -Source $Source -AcceptLicenses:$AcceptLicenses
            
            $result.ItemName = $packageConfig.PackageId
            $result.ItemType = "Package"
            
            Write-DotWinLog "Processing package: $($packageConfig.PackageId)" -Level Information
            
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
                $isInstalled = $packageItem.Test()
                if ($isInstalled) {
                    $result.Success = $true
                    $result.Message = "Package already installed"
                    Write-DotWinLog "Package '$($packageConfig.PackageId)' is already installed" -Level Information
                    continue
                }
            }
            
            # Install the package
            if ($PSCmdlet.ShouldProcess($packageConfig.PackageId, "Install package")) {
                Write-DotWinLog "Installing package: $($packageConfig.PackageId)" -Level Information
                
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
                Write-DotWinLog "Successfully installed package: $($packageConfig.PackageId)" -Level Information
            } else {
                $result.Success = $true
                $result.Message = "Package installation skipped (WhatIf)"
                Write-DotWinLog "Package installation skipped: $($packageConfig.PackageId) (WhatIf)" -Level Information
            }
            
        } catch {
            $result.Success = $false
            $result.Message = "Error installing package: $($_.Exception.Message)"
            Write-DotWinLog "Error installing package '$($result.ItemName)': $($_.Exception.Message)" -Level Error
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
        [object[]]$Packages,
        
        [Parameter(Mandatory = $true)]
        [string]$Source,
        
        [Parameter()]
        [switch]$Force,
        
        [Parameter()]
        [switch]$AcceptLicenses
    )
    
    Write-DotWinLog "Parallel installation is experimental and may not work with all packages" -Level Warning
    
    $jobs = @()
    $results = @()
    
    try {
        # Start installation jobs
        foreach ($packageSpec in $Packages) {
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
            
            Write-DotWinLog "Started installation job for package: $($packageConfig.PackageId)" -Level Verbose
        }
        
        # Wait for jobs to complete and collect results
        foreach ($jobInfo in $jobs) {
            $job = $jobInfo.Job
            $packageId = $jobInfo.PackageId
            $startTime = $jobInfo.StartTime
            
            Write-DotWinLog "Waiting for package installation to complete: $packageId" -Level Verbose
            $jobResult = Receive-Job -Job $job -Wait
            Remove-Job -Job $job
            
            $result = [DotWinExecutionResult]::new()
            $result.ItemName = $packageId
            $result.ItemType = "Package"
            $result.Duration = (Get-Date) - $startTime
            
            if ($jobResult.Success) {
                $result.Success = $true
                $result.Message = "Package installed successfully (parallel)"
                Write-DotWinLog "Successfully installed package: $packageId" -Level Information
            } else {
                $result.Success = $false
                $result.Message = "Error installing package: $($jobResult.Error)"
                Write-DotWinLog "Error installing package '$packageId': $($jobResult.Error)" -Level Error
            }
            
            $results += $result
        }
        
    } catch {
        # Clean up any remaining jobs
        foreach ($jobInfo in $jobs) {
            if ($jobInfo.Job.State -eq 'Running') {
                Stop-Job -Job $jobInfo.Job
                Remove-Job -Job $jobInfo.Job
            }
        }
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
        [object]$PackageSpec,
        
        [Parameter(Mandatory = $true)]
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
        $config.PackageId = $PackageSpec.Id ?? $PackageSpec.PackageId ?? $PackageSpec.Name
        $config.Version = $PackageSpec.Version
        $config.Source = $PackageSpec.Source ?? $Source
        
        if ($PackageSpec.AcceptLicense -ne $null) {
            $config.AcceptLicense = $PackageSpec.AcceptLicense
        }
        
        if ($PackageSpec.AcceptSourceAgreements -ne $null) {
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