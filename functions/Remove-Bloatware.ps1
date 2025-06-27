function Remove-Bloatware {
    <#
    .SYNOPSIS
        Removes bloatware and unwanted applications from Windows 11.

    .DESCRIPTION
        The Remove-Bloatware function provides a comprehensive system for removing
        unwanted pre-installed applications, services, and features from Windows 11
        while integrating with the DotWin configuration management system.

    .PARAMETER Category
        Remove bloatware from specific categories (Gaming, Social, Productivity, etc.).

    .PARAMETER ApplicationList
        Array of specific application names or package names to remove.

    .PARAMETER ConfigurationPath
        Path to a configuration file containing bloatware definitions.

    .PARAMETER IncludeServices
        Also disable related Windows services for removed applications.

    .PARAMETER IncludeScheduledTasks
        Remove or disable scheduled tasks related to bloatware.

    .PARAMETER WhatIf
        Shows what would be removed without actually removing anything.

    .PARAMETER Force
        Forces removal even if applications appear to be in use.

    .PARAMETER PreserveUserData
        Preserve user data when removing applications (where possible).

    .EXAMPLE
        Remove-Bloatware -Category 'Gaming' -WhatIf
        
        Shows what gaming-related bloatware would be removed.

    .EXAMPLE
        Remove-Bloatware -ApplicationList @('Microsoft.XboxApp', 'Microsoft.ZuneMusic') -IncludeServices
        
        Removes Xbox and Groove Music apps along with related services.

    .EXAMPLE
        Remove-Bloatware -Category 'All' -IncludeServices -IncludeScheduledTasks -Force
        
        Performs comprehensive bloatware removal including services and scheduled tasks.

    .OUTPUTS
        DotWinExecutionResult[]
        Returns an array of execution results for each removal operation.

    .NOTES
        This function requires administrator privileges for most operations.
        Some applications may require special removal procedures.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Category')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Category', Position = 0)]
        [ValidateSet('Gaming', 'Social', 'Productivity', 'Entertainment', 'Communication', 'Shopping', 'News', 'All')]
        [string]$Category,

        [Parameter(Mandatory = $true, ParameterSetName = 'ApplicationList')]
        [string[]]$ApplicationList,

        [Parameter(ParameterSetName = 'ConfigFile')]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Configuration file '$_' does not exist."
            }
            return $true
        })]
        [string]$ConfigurationPath,

        [Parameter()]
        [switch]$IncludeServices,

        [Parameter()]
        [switch]$IncludeScheduledTasks,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PreserveUserData
    )

    begin {
        # Start master progress bar for bloatware removal process
        $masterProgressId = Start-DotWinProgress -Activity "Removing Bloatware" -Status "Initializing..." -TotalOperations 4
        
        try {
            Write-DotWinProgress -ProgressId $masterProgressId -Status "Validating environment..." -PercentComplete 10

            # Validate environment
            $envTest = Test-DotWinEnvironment
            if (-not $envTest.IsValid) {
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Environment validation failed: $($envTest.Issues -join ', ')"
                throw "Environment validation failed: $($envTest.Issues -join ', ')"
            }

            # Check for administrator privileges
            if (-not $envTest.IsAdministrator) {
                Write-DotWinLog "Administrator privileges recommended for complete bloatware removal" -Level Warning -ShowWithProgress
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
            # Determine applications to remove based on parameter set
            $applicationsToRemove = @()

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Determining applications to remove..." -PercentComplete 30

            switch ($PSCmdlet.ParameterSetName) {
                'Category' {
                    Write-DotWinLog "Loading bloatware from category: $Category" -Level Information -ShowWithProgress
                    $applicationsToRemove = Get-BloatwareByCategory -Category $Category
                    Write-DotWinLog "Found $($applicationsToRemove.Count) applications in category '$Category'" -Level Information -ShowWithProgress
                }
                
                'ApplicationList' {
                    $applicationsToRemove = $ApplicationList
                    Write-DotWinLog "Processing $($ApplicationList.Count) applications from list" -Level Information -ShowWithProgress
                }
                
                'ConfigFile' {
                    Write-DotWinLog "Loading bloatware from configuration file: $ConfigurationPath" -Level Information -ShowWithProgress
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    $applicationsToRemove = $configContent.bloatware
                }
            }

            if ($applicationsToRemove.Count -eq 0) {
                Write-DotWinLog "No bloatware applications to remove" -Level Warning -ShowWithProgress
                Complete-DotWinProgress -ProgressId $masterProgressId -Status "Completed (no bloatware)" -Message "No bloatware applications to remove"
                return $results
            }

            Write-DotWinProgress -ProgressId $masterProgressId -Status "Processing $($applicationsToRemove.Count) bloatware applications" -PercentComplete 40 -TotalOperations $applicationsToRemove.Count

            # Process each application with nested progress
            $appIndex = 0
            foreach ($appName in $applicationsToRemove) {
                $appIndex++
                $appProgressPercent = [Math]::Round((($appIndex / $applicationsToRemove.Count) * 50) + 40, 0)

                # Create nested progress for individual application removal
                $appProgressId = Start-DotWinProgress -Activity "Removing: $appName" -Status "Initializing..." -ParentId $masterProgressId

                # Update master progress
                Write-DotWinProgress -ProgressId $masterProgressId -Status "Removing application $appIndex of $($applicationsToRemove.Count): $appName" -PercentComplete $appProgressPercent -CurrentOperation $appIndex

                $appStartTime = Get-Date
                $result = [DotWinExecutionResult]::new()
                $result.ItemName = $appName
                $result.ItemType = "BloatwareRemoval"
                $result.ProgressId = $appProgressId
                
                try {
                    Write-DotWinProgress -ProgressId $appProgressId -Status "Creating removal configuration..." -PercentComplete 20
                    
                    # Create bloatware removal configuration item
                    $removalItem = [DotWinBloatwareRemoval]::new($appName)
                    $removalItem.IncludeServices = $IncludeServices
                    $removalItem.IncludeScheduledTasks = $IncludeScheduledTasks
                    $removalItem.PreserveUserData = $PreserveUserData
                    
                    Write-DotWinProgress -ProgressId $appProgressId -Status "Testing if removal is needed..." -PercentComplete 40

                    # Test if application exists and needs removal
                    $needsRemoval = $removalItem.Test()
                    if (-not $needsRemoval -and -not $Force) {
                        $result.Success = $true
                        $result.Message = "Application not found or already removed"
                        Write-DotWinProgress -ProgressId $appProgressId -Status "Already removed, skipping..." -PercentComplete 100
                        Complete-DotWinProgress -ProgressId $appProgressId -Status "Skipped (already removed)" -Message "Application '$appName' not found or already removed"
                        continue
                    }
                    
                    # Remove the application
                    if ($PSCmdlet.ShouldProcess($appName, "Remove bloatware application")) {
                        Write-DotWinProgress -ProgressId $appProgressId -Status "Removing application..." -PercentComplete 60
                        
                        # Get current state for comparison
                        $beforeState = $removalItem.GetCurrentState()
                        
                        # Apply the removal
                        $removalItem.Apply()
                        
                        # Get new state and record changes
                        $afterState = $removalItem.GetCurrentState()
                        $result.Changes = @{
                            Before = $beforeState
                            After = $afterState
                        }
                        
                        $result.Success = $true
                        $result.Message = "Bloatware application removed successfully"
                        Write-DotWinProgress -ProgressId $appProgressId -Status "Removal completed successfully" -PercentComplete 100
                        Complete-DotWinProgress -ProgressId $appProgressId -Status "Completed successfully" -Message "Successfully removed bloatware application: $appName"
                    } else {
                        $result.Success = $true
                        $result.Message = "Bloatware removal skipped (WhatIf)"
                        Write-DotWinProgress -ProgressId $appProgressId -Status "Skipped (WhatIf mode)" -PercentComplete 100
                        Complete-DotWinProgress -ProgressId $appProgressId -Status "Skipped (WhatIf)" -Message "Bloatware removal skipped: $appName (WhatIf)"
                    }
                    
                } catch {
                    $result.Success = $false
                    $result.Message = "Error removing bloatware application: $($_.Exception.Message)"
                    Write-DotWinProgress -ProgressId $appProgressId -Status "Failed" -PercentComplete 100
                    Complete-DotWinProgress -ProgressId $appProgressId -Status "Failed" -Message "Error removing bloatware application '$appName': $($_.Exception.Message)"
                } finally {
                    $result.Duration = (Get-Date) - $appStartTime
                    $results += $result
                }
            }

        } catch {
            Complete-DotWinProgress -ProgressId $masterProgressId -Status "Failed" -Message "Critical error during bloatware removal: $($_.Exception.Message)"
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        # Calculate detailed removal metrics
        $removedApps = ($results | Where-Object { $_.Success -and $_.Message -notlike "*already removed*" -and $_.Message -notlike "*skipped*" }).Count
        $alreadyRemoved = ($results | Where-Object { $_.Message -like "*already removed*" }).Count
        $servicesIncluded = if ($IncludeServices) { ($results | Where-Object { $_.Changes.Before.Services }).Count } else { 0 }
        $tasksIncluded = if ($IncludeScheduledTasks) { ($results | Where-Object { $_.Changes.Before.ScheduledTasks }).Count } else { 0 }

        # Complete master progress with summary statistics
        $summaryMetrics = @{
            TotalApplications = $results.Count
            SuccessfulRemovals = $successCount
            FailedRemovals = $failureCount
            ActuallyRemoved = $removedApps
            AlreadyRemoved = $alreadyRemoved
            TotalDurationSeconds = [Math]::Round($totalDuration.TotalSeconds, 2)
            AverageRemovalDuration = if ($results.Count -gt 0) { [Math]::Round(($results | Measure-Object -Property Duration -Average).Average.TotalSeconds, 2) } else { 0 }
            ServicesProcessed = $servicesIncluded
            ScheduledTasksProcessed = $tasksIncluded
            Category = $Category
        }

        $summaryMessage = "Bloatware removal completed: $successCount successful, $failureCount failed (Total: $($results.Count) applications, Actually removed: $removedApps, Duration: $($summaryMetrics.TotalDurationSeconds)s)"

        Write-DotWinProgress -ProgressId $masterProgressId -Status "Finalizing..." -PercentComplete 95
        Complete-DotWinProgress -ProgressId $masterProgressId -Status "Completed" -FinalMetrics $summaryMetrics -Message $summaryMessage

        # Show summary with progress coordination
        Write-DotWinLog "Bloatware removal completed" -Level Information -ShowWithProgress
        Write-DotWinLog "Total applications processed: $($results.Count)" -Level Information -ShowWithProgress
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level Information -ShowWithProgress
        Write-DotWinLog "Actually removed: $removedApps, Already removed: $alreadyRemoved" -Level Information -ShowWithProgress
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level Information -ShowWithProgress
        
        # Ensure we always return an array, even for single items
        if ($results -is [array]) {
            return $results
        } else {
            return @($results)
        }
    }
}


function Remove-AppxPackages {
    <#
    .SYNOPSIS
        Removes AppX packages for a specific application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName,
        
        [Parameter()]
        [switch]$PreserveUserData
    )
    
    $results = @()
    
    try {
        # Get all AppX packages for the application
        $packages = Get-AppxPackage -Name "*$ApplicationName*" -AllUsers -ErrorAction SilentlyContinue
        
        foreach ($package in $packages) {
            try {
                Write-DotWinLog "Removing AppX package: $($package.Name)" -Level Verbose
                
                if ($PreserveUserData) {
                    Remove-AppxPackage -Package $package.PackageFullName -PreserveApplicationData
                } else {
                    Remove-AppxPackage -Package $package.PackageFullName -AllUsers
                }
                
                $results += @{
                    Success = $true
                    Type = "AppxPackage"
                    Name = $package.Name
                    Message = "AppX package removed successfully"
                }
                
            } catch {
                $results += @{
                    Success = $false
                    Type = "AppxPackage"
                    Name = $package.Name
                    Message = "Error removing AppX package: $($_.Exception.Message)"
                }
            }
        }
        
    } catch {
        $results += @{
            Success = $false
            Type = "AppxPackage"
            Name = $ApplicationName
            Message = "Error retrieving AppX packages: $($_.Exception.Message)"
        }
    }
    
    return $results
}

function Remove-ProvisionedPackages {
    <#
    .SYNOPSIS
        Removes provisioned AppX packages for a specific application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName
    )
    
    $results = @()
    
    try {
        # Get all provisioned packages for the application
        $packages = Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like "*$ApplicationName*" }
        
        foreach ($package in $packages) {
            try {
                Write-DotWinLog "Removing provisioned package: $($package.DisplayName)" -Level Verbose
                
                Remove-AppxProvisionedPackage -Online -PackageName $package.PackageName
                
                $results += @{
                    Success = $true
                    Type = "ProvisionedPackage"
                    Name = $package.DisplayName
                    Message = "Provisioned package removed successfully"
                }
                
            } catch {
                $results += @{
                    Success = $false
                    Type = "ProvisionedPackage"
                    Name = $package.DisplayName
                    Message = "Error removing provisioned package: $($_.Exception.Message)"
                }
            }
        }
        
    } catch {
        $results += @{
            Success = $false
            Type = "ProvisionedPackage"
            Name = $ApplicationName
            Message = "Error retrieving provisioned packages: $($_.Exception.Message)"
        }
    }
    
    return $results
}

function Remove-InstalledPrograms {
    <#
    .SYNOPSIS
        Removes installed programs for a specific application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName
    )
    
    $results = @()
    
    try {
        # Get all installed programs for the application
        $programs = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "*$ApplicationName*" }
        
        foreach ($program in $programs) {
            try {
                Write-DotWinLog "Uninstalling program: $($program.Name)" -Level Verbose
                
                $uninstallResult = $program.Uninstall()
                
                if ($uninstallResult.ReturnValue -eq 0) {
                    $results += @{
                        Success = $true
                        Type = "InstalledProgram"
                        Name = $program.Name
                        Message = "Program uninstalled successfully"
                    }
                } else {
                    $results += @{
                        Success = $false
                        Type = "InstalledProgram"
                        Name = $program.Name
                        Message = "Program uninstall failed with return code: $($uninstallResult.ReturnValue)"
                    }
                }
                
            } catch {
                $results += @{
                    Success = $false
                    Type = "InstalledProgram"
                    Name = $program.Name
                    Message = "Error uninstalling program: $($_.Exception.Message)"
                }
            }
        }
        
    } catch {
        $results += @{
            Success = $false
            Type = "InstalledProgram"
            Name = $ApplicationName
            Message = "Error retrieving installed programs: $($_.Exception.Message)"
        }
    }
    
    return $results
}

function Remove-RelatedServices {
    <#
    .SYNOPSIS
        Removes or disables services related to a specific application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName
    )
    
    $results = @()
    
    try {
        # Get all services related to the application
        $services = Get-Service -Name "*$ApplicationName*" -ErrorAction SilentlyContinue
        
        foreach ($service in $services) {
            try {
                Write-DotWinLog "Stopping and disabling service: $($service.Name)" -Level Verbose
                
                # Stop the service if running
                if ($service.Status -eq 'Running') {
                    Stop-Service -Name $service.Name -Force
                }
                
                # Disable the service
                Set-Service -Name $service.Name -StartupType Disabled
                
                $results += @{
                    Success = $true
                    Type = "Service"
                    Name = $service.Name
                    Message = "Service stopped and disabled successfully"
                }
                
            } catch {
                $results += @{
                    Success = $false
                    Type = "Service"
                    Name = $service.Name
                    Message = "Error stopping/disabling service: $($_.Exception.Message)"
                }
            }
        }
        
    } catch {
        $results += @{
            Success = $false
            Type = "Service"
            Name = $ApplicationName
            Message = "Error retrieving services: $($_.Exception.Message)"
        }
    }
    
    return $results
}

function Remove-RelatedScheduledTasks {
    <#
    .SYNOPSIS
        Removes scheduled tasks related to a specific application.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ApplicationName
    )
    
    $results = @()
    
    try {
        # Get all scheduled tasks related to the application
        $tasks = Get-ScheduledTask -TaskName "*$ApplicationName*" -ErrorAction SilentlyContinue
        
        foreach ($task in $tasks) {
            try {
                Write-DotWinLog "Removing scheduled task: $($task.TaskName)" -Level Verbose
                
                Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
                
                $results += @{
                    Success = $true
                    Type = "ScheduledTask"
                    Name = $task.TaskName
                    Message = "Scheduled task removed successfully"
                }
                
            } catch {
                $results += @{
                    Success = $false
                    Type = "ScheduledTask"
                    Name = $task.TaskName
                    Message = "Error removing scheduled task: $($_.Exception.Message)"
                }
            }
        }
        
    } catch {
        $results += @{
            Success = $false
            Type = "ScheduledTask"
            Name = $ApplicationName
            Message = "Error retrieving scheduled tasks: $($_.Exception.Message)"
        }
    }
    
    return $results
}

function Get-BloatwareByCategory {
    <#
    .SYNOPSIS
        Gets bloatware applications by category.
    
    .DESCRIPTION
        Internal function to retrieve predefined lists of bloatware applications by category.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Category
    )
    
    $bloatwareCategories = @{
        'Gaming' = @(
            'Microsoft.XboxApp',
            'Microsoft.XboxGameOverlay',
            'Microsoft.XboxGamingOverlay',
            'Microsoft.XboxIdentityProvider',
            'Microsoft.XboxSpeechToTextOverlay',
            'Microsoft.Xbox.TCUI',
            'Microsoft.GamingApp'
        )
        
        'Social' = @(
            'Microsoft.SkypeApp',
            'Microsoft.YourPhone',
            'Microsoft.People',
            'Microsoft.MicrosoftSolitaireCollection',
            'Microsoft.BingNews',
            'Microsoft.GetHelp'
        )
        
        'Productivity' = @(
            'Microsoft.Office.OneNote',
            'Microsoft.MicrosoftOfficeHub',
            'Microsoft.Office.Sway',
            'Microsoft.Todos',
            'Microsoft.PowerAutomateDesktop'
        )
        
        'Entertainment' = @(
            'Microsoft.ZuneMusic',
            'Microsoft.ZuneVideo',
            'Microsoft.MixedReality.Portal',
            'Microsoft.Microsoft3DViewer',
            'SpotifyAB.SpotifyMusic',
            'Microsoft.BingWeather'
        )
        
        'Communication' = @(
            'Microsoft.SkypeApp',
            'Microsoft.YourPhone',
            'Microsoft.People',
            'Microsoft.MicrosoftTeams'
        )
        
        'Shopping' = @(
            'Microsoft.MicrosoftShopping',
            'Microsoft.WindowsMaps'
        )
        
        'News' = @(
            'Microsoft.BingNews',
            'Microsoft.BingWeather',
            'Microsoft.BingFinance',
            'Microsoft.BingSports'
        )
        
        'All' = @()
    }
    
    # For 'All' category, combine all other categories
    if ($Category -eq 'All') {
        $allBloatware = @()
        foreach ($cat in $bloatwareCategories.Keys) {
            if ($cat -ne 'All') {
                $allBloatware += $bloatwareCategories[$cat]
            }
        }
        return ($allBloatware | Sort-Object -Unique)
    }
    
    if ($bloatwareCategories.ContainsKey($Category)) {
        return $bloatwareCategories[$Category]
    } else {
        Write-DotWinLog "Unknown bloatware category: $Category" -Level Warning
        return @()
    }
}

function Get-InstalledBloatware {
    <#
    .SYNOPSIS
        Gets a list of currently installed bloatware applications.
    
    .DESCRIPTION
        Scans the system for known bloatware applications and returns their current status.
    
    .OUTPUTS
        Array of bloatware application objects with installation status.
    #>
    [CmdletBinding()]
    param()
    
    $bloatware = @()
    
    try {
        Write-DotWinLog "Scanning for installed bloatware applications" -Level Information
        
        # Get all bloatware categories
        $allCategories = @('Gaming', 'Social', 'Productivity', 'Entertainment', 'Communication', 'Shopping', 'News')
        
        foreach ($category in $allCategories) {
            $categoryApps = Get-BloatwareByCategory -Category $category
            
            foreach ($appName in $categoryApps) {
                $appStatus = @{
                    Name = $appName
                    Category = $category
                    AppxPackages = @()
                    ProvisionedPackages = @()
                    InstalledPrograms = @()
                    IsInstalled = $false
                }
                
                # Check AppX packages
                $appxPackages = Get-AppxPackage -Name "*$appName*" -AllUsers -ErrorAction SilentlyContinue
                if ($appxPackages) {
                    $appStatus.AppxPackages = $appxPackages | ForEach-Object { $_.Name }
                    $appStatus.IsInstalled = $true
                }
                
                # Check provisioned packages
                $provisionedPackages = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$appName*" }
                if ($provisionedPackages) {
                    $appStatus.ProvisionedPackages = $provisionedPackages | ForEach-Object { $_.DisplayName }
                    $appStatus.IsInstalled = $true
                }
                
                # Check installed programs
                $installedPrograms = Get-WmiObject -Class Win32_Product -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "*$appName*" }
                if ($installedPrograms) {
                    $appStatus.InstalledPrograms = $installedPrograms | ForEach-Object { $_.Name }
                    $appStatus.IsInstalled = $true
                }
                
                if ($appStatus.IsInstalled) {
                    $bloatware += $appStatus
                }
            }
        }
        
        Write-DotWinLog "Found $($bloatware.Count) installed bloatware applications" -Level Information
        return $bloatware
        
    } catch {
        Write-DotWinLog "Error scanning for bloatware: $($_.Exception.Message)" -Level Error
        throw
    }
}