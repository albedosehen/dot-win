function Install-ChipsetDriver {
    <#
    .SYNOPSIS
        Installs chipset and hardware drivers on the system.

    .DESCRIPTION
        The Install-ChipsetDriver function installs drivers for hardware components
        from various sources including Windows Update, local driver packages, and
        manufacturer installers. It integrates with the DotWin configuration system
        to provide automated driver installation with proper error handling and logging.

    .PARAMETER DriverInfo
        Driver information object from Search-ChipsetDriver containing details about
        the driver to install.

    .PARAMETER DriverPath
        Path to a local driver package (.inf file or installer executable).

    .PARAMETER DriverType
        Specifies the type of driver to install. Valid values are:
        'Chipset', 'Network', 'Graphics', 'Audio', 'Storage', 'USB'

    .PARAMETER Source
        Specifies the driver source. Valid values are:
        'WindowsUpdate', 'Local', 'Package'

    .PARAMETER Force
        Forces installation even if a newer driver is already installed.

    .PARAMETER WhatIf
        Shows what would happen if the command runs without actually installing drivers.

    .PARAMETER Restart
        Automatically restart the computer after driver installation if required.

    .EXAMPLE
        Install-ChipsetDriver -DriverType Chipset -Source WindowsUpdate

        Installs chipset drivers from Windows Update.

    .EXAMPLE
        $driverInfo = Search-ChipsetDriver -DriverType Graphics | Where-Object { $_.RecommendedAction -eq 'Update' }
        Install-ChipsetDriver -DriverInfo $driverInfo[0]

        Installs a specific graphics driver found by search.

    .EXAMPLE
        Install-ChipsetDriver -DriverPath "C:\Drivers\chipset.inf" -WhatIf

        Shows what would happen when installing a local driver package.

    .OUTPUTS
        [DotWinExecutionResult] Installation result object with success status and details.

    .NOTES
        Requires administrator privileges.
        Some driver installations may require a system restart.
        Always create a system restore point before installing drivers.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [PSCustomObject]$DriverInfo,

        [Parameter(Mandatory = $false)]
        [ValidateScript({
            if ($_ -and -not (Test-Path $_)) {
                throw "Driver path '$_' does not exist."
            }
            return $true
        })]
        [string]$DriverPath,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Chipset', 'Network', 'Graphics', 'Audio', 'Storage', 'USB')]
        [string]$DriverType,

        [Parameter(Mandatory = $false)]
        [ValidateSet('WindowsUpdate', 'Local', 'Package')]
        [string]$Source,

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$Restart
    )

    begin {
    Write-Verbose "Starting driver installation process..."
    
    # Check for administrator privileges
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        throw "Administrator privileges are required to install drivers. Please run PowerShell as Administrator."
    }
    
    # Helper function to create system restore point
    function New-DriverRestorePoint {
        param(
            [string]$Description = "Before DotWin Driver Installation"
        )
        
        try {
            Write-Verbose "Creating system restore point..."
            
            # Enable system restore if not enabled
            Enable-ComputerRestore -Drive $env:SystemDrive -ErrorAction SilentlyContinue
            
            # Create restore point
            Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS"
            Write-Verbose "System restore point created successfully."
            return $true
        }
        catch {
            Write-Warning "Failed to create system restore point: $($_.Exception.Message)"
            return $false
        }
    }
    
    # Helper function to install driver from Windows Update
    function Install-WindowsUpdateDriver {
        param(
            [PSCustomObject]$Driver
        )
        
        try {
            Write-Verbose "Installing driver from Windows Update: $($Driver.Title)"
            
            if ($PSCmdlet.ShouldProcess($Driver.Title, "Install Windows Update Driver")) {
                # Use Windows Update API
                $updateSession = New-Object -ComObject Microsoft.Update.Session
                $updateSearcher = $updateSession.CreateUpdateSearcher()
                
                # Search for the specific update
                $searchResult = $updateSearcher.Search("UpdateID='$($Driver.UpdateID)'")
                
                if ($searchResult.Updates.Count -gt 0) {
                    $updateToInstall = $searchResult.Updates.Item(0)
                    
                    # Create update collection
                    $updatesToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
                    $updatesToInstall.Add($updateToInstall)
                    
                    # Download the update
                    Write-Verbose "Downloading driver update..."
                    $downloader = $updateSession.CreateUpdateDownloader()
                    $downloader.Updates = $updatesToInstall
                    $downloadResult = $downloader.Download()
                    
                    if ($downloadResult.ResultCode -eq 2) { # Success
                        # Install the update
                        Write-Verbose "Installing driver update..."
                        $installer = $updateSession.CreateUpdateInstaller()
                        $installer.Updates = $updatesToInstall
                        $installResult = $installer.Install()
                        
                        return [PSCustomObject]@{
                            Success = ($installResult.ResultCode -eq 2)
                            ResultCode = $installResult.ResultCode
                            RebootRequired = $installResult.RebootRequired
                            Message = "Windows Update driver installation completed"
                        }
                    } else {
                        throw "Failed to download driver update. Result code: $($downloadResult.ResultCode)"
                    }
                } else {
                    throw "Driver update not found in Windows Update"
                }
            } else {
                return [PSCustomObject]@{
                    Success = $true
                    ResultCode = 0
                    RebootRequired = $false
                    Message = "WhatIf: Would install Windows Update driver"
                }
            }
        }
        catch {
            Write-Error "Failed to install Windows Update driver: $($_.Exception.Message)"
            return [PSCustomObject]@{
                Success = $false
                ResultCode = -1
                RebootRequired = $false
                Message = $_.Exception.Message
            }
        }
    }
    
    # Helper function to install local driver package
    function Install-LocalDriverPackage {
        param(
            [string]$Path
        )
        
        try {
            Write-Verbose "Installing local driver package: $Path"
            
            $fileExtension = [System.IO.Path]::GetExtension($Path).ToLower()
            
            if ($PSCmdlet.ShouldProcess($Path, "Install Local Driver Package")) {
                switch ($fileExtension) {
                    '.inf' {
                        # Install INF driver package
                        Write-Verbose "Installing INF driver package..."
                        $result = pnputil.exe /add-driver $Path /install
                        
                        $success = $LASTEXITCODE -eq 0
                        return [PSCustomObject]@{
                            Success = $success
                            ResultCode = $LASTEXITCODE
                            RebootRequired = $false # INF installations typically don't require reboot
                            Message = if ($success) { "INF driver package installed successfully" } else { "Failed to install INF driver package" }
                            Output = $result -join "`n"
                        }
                    }
                    
                    '.exe' {
                        # Install executable driver package
                        Write-Verbose "Installing executable driver package..."
                        $process = Start-Process -FilePath $Path -ArgumentList "/S", "/silent", "/quiet" -Wait -PassThru -NoNewWindow
                        
                        $success = $process.ExitCode -eq 0
                        return [PSCustomObject]@{
                            Success = $success
                            ResultCode = $process.ExitCode
                            RebootRequired = $true # Executable installations often require reboot
                            Message = if ($success) { "Executable driver package installed successfully" } else { "Failed to install executable driver package" }
                        }
                    }
                    
                    '.msi' {
                        # Install MSI driver package
                        Write-Verbose "Installing MSI driver package..."
                        $process = Start-Process -FilePath "msiexec.exe" -ArgumentList "/i", "`"$Path`"", "/quiet", "/norestart" -Wait -PassThru -NoNewWindow
                        
                        $success = $process.ExitCode -eq 0
                        return [PSCustomObject]@{
                            Success = $success
                            ResultCode = $process.ExitCode
                            RebootRequired = $true # MSI installations often require reboot
                            Message = if ($success) { "MSI driver package installed successfully" } else { "Failed to install MSI driver package" }
                        }
                    }
                    
                    default {
                        throw "Unsupported driver package format: $fileExtension"
                    }
                }
            } else {
                return [PSCustomObject]@{
                    Success = $true
                    ResultCode = 0
                    RebootRequired = $false
                    Message = "WhatIf: Would install local driver package"
                }
            }
        }
        catch {
            Write-Error "Failed to install local driver package: $($_.Exception.Message)"
            return [PSCustomObject]@{
                Success = $false
                ResultCode = -1
                RebootRequired = $false
                Message = $_.Exception.Message
            }
        }
    }
    
    # Helper function to install driver from driver store
    function Install-DriverStorePackage {
        param(
            [string]$PublishedName
        )
        
        try {
            Write-Verbose "Installing driver from driver store: $PublishedName"
            
            if ($PSCmdlet.ShouldProcess($PublishedName, "Install Driver Store Package")) {
                # Use pnputil to install from driver store
                $result = pnputil.exe /install-device $PublishedName
                
                $success = $LASTEXITCODE -eq 0
                return [PSCustomObject]@{
                    Success = $success
                    ResultCode = $LASTEXITCODE
                    RebootRequired = $false
                    Message = if ($success) { "Driver store package installed successfully" } else { "Failed to install driver store package" }
                    Output = $result -join "`n"
                }
            } else {
                return [PSCustomObject]@{
                    Success = $true
                    ResultCode = 0
                    RebootRequired = $false
                    Message = "WhatIf: Would install driver store package"
                }
            }
        }
        catch {
            Write-Error "Failed to install driver store package: $($_.Exception.Message)"
            return [PSCustomObject]@{
                Success = $false
                ResultCode = -1
                RebootRequired = $false
                Message = $_.Exception.Message
            }
        }
    }
}

process {
    try {
        $startTime = Get-Date
        $installResults = @()
        
        # Create system restore point before installation
        if (-not $WhatIfPreference) {
            $restorePointCreated = New-DriverRestorePoint
            if (-not $restorePointCreated) {
                Write-Warning "Could not create system restore point. Continuing with installation..."
            }
        }
        
        # Determine installation method based on parameters
        if ($DriverInfo) {
            # Install from driver info object
            Write-Verbose "Installing driver from driver info object..."
            
            foreach ($availableDriver in $DriverInfo.AvailableDrivers) {
                $installResult = $null
                
                switch ($availableDriver.Source) {
                    'WindowsUpdate' {
                        $installResult = Install-WindowsUpdateDriver -Driver $availableDriver
                    }
                    
                    'Local' {
                        if ($availableDriver.PublishedName) {
                            $installResult = Install-DriverStorePackage -PublishedName $availableDriver.PublishedName
                        } else {
                            Write-Warning "Local driver does not have published name information"
                            continue
                        }
                    }
                    
                    'Manufacturer' {
                        Write-Warning "Manufacturer drivers require manual download and installation"
                        Write-Information "Please visit: $($availableDriver.DownloadURL)"
                        continue
                    }
                }
                
                if ($installResult) {
                    $installResults += [DotWinExecutionResult]::new(
                        $installResult.Success,
                        $DriverInfo.DeviceName,
                        $installResult.Message
                    )
                    $installResults[-1].ItemType = "Driver"
                    $installResults[-1].Changes["RebootRequired"] = $installResult.RebootRequired
                    $installResults[-1].Changes["ResultCode"] = $installResult.ResultCode
                }
            }
        }
        elseif ($DriverPath) {
            # Install from local driver path
            Write-Verbose "Installing driver from local path: $DriverPath"
            
            $installResult = Install-LocalDriverPackage -Path $DriverPath
            
            $installResults += [DotWinExecutionResult]::new(
                $installResult.Success,
                [System.IO.Path]::GetFileName($DriverPath),
                $installResult.Message
            )
            $installResults[-1].ItemType = "Driver"
            $installResults[-1].Changes["RebootRequired"] = $installResult.RebootRequired
            $installResults[-1].Changes["ResultCode"] = $installResult.ResultCode
        }
        elseif ($DriverType -and $Source) {
            # Search and install drivers of specified type from specified source
            Write-Verbose "Searching and installing $DriverType drivers from $Source..."
            
            $driverSearch = Search-ChipsetDriver -DriverType $DriverType -Source $Source
            $driversToInstall = $driverSearch | Where-Object { 
                $_.RecommendedAction -eq 'Install' -or 
                $_.RecommendedAction -eq 'Update' -or 
                $Force 
            }
            
            foreach ($driver in $driversToInstall) {
                $driverInstall = Install-ChipsetDriver -DriverInfo $driver -WhatIf:$WhatIfPreference
                $installResults += $driverInstall
            }
        }
        else {
            throw "Must specify either DriverInfo, DriverPath, or both DriverType and Source parameters"
        }
        
        # Calculate total duration
        $endTime = Get-Date
        $totalDuration = $endTime - $startTime
        
        # Update duration for all results
        foreach ($result in $installResults) {
            $result.Duration = $totalDuration
        }
        
        # Check if restart is required
        $rebootRequired = $installResults | Where-Object { $_.Changes["RebootRequired"] -eq $true }
        
        if ($rebootRequired -and $Restart -and -not $WhatIfPreference) {
            Write-Warning "Driver installation requires a system restart. Restarting in 30 seconds..."
            Write-Warning "Press Ctrl+C to cancel the restart."
            
            Start-Sleep -Seconds 30
            Restart-Computer -Force
        }
        elseif ($rebootRequired) {
            Write-Warning "Driver installation completed but requires a system restart to take effect."
            Write-Information "Use the -Restart parameter to automatically restart after installation."
        }
        
        return $installResults
    }
    catch {
        $errorResult = [DotWinExecutionResult]::new(
            $false,
            "DriverInstallation",
            "Driver installation failed: $($_.Exception.Message)"
        )
        $errorResult.ItemType = "Driver"
        $errorResult.Duration = (Get-Date) - $startTime
        
        Write-Error $_.Exception.Message
        return $errorResult
    }
}

    end {
        Write-Verbose "Driver installation process completed."
    }
}