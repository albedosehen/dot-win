function Search-ChipsetDriver {
    <#
    .SYNOPSIS
        Searches for available chipset and hardware drivers from various sources.

    .DESCRIPTION
        The Search-ChipsetDriver function searches for drivers for detected hardware
        components from multiple sources including Windows Update, manufacturer websites,
        and local driver stores. It integrates with the DotWin configuration system
        to provide automated driver discovery.

    .PARAMETER HardwareInfo
        Hardware information object from Get-ChipsetInformation. If not provided,
        the function will automatically gather hardware information.

    .PARAMETER DriverType
        Specifies the type of drivers to search for. Valid values are:
        'All', 'Chipset', 'Network', 'Graphics', 'Audio', 'Storage', 'USB'
        Default is 'All'.

    .PARAMETER Source
        Specifies the driver source to search. Valid values are:
        'All', 'WindowsUpdate', 'Manufacturer', 'Local'
        Default is 'All'.

    .PARAMETER IncludeInstalled
        Include currently installed drivers in the search results for comparison.

    .PARAMETER Format
        Specifies the output format. Valid values are 'Object', 'Table', 'List'.
        Default is 'Object'.

    .EXAMPLE
        Search-ChipsetDriver

        Searches for all available drivers from all sources.

    .EXAMPLE
        Search-ChipsetDriver -DriverType Chipset -Source WindowsUpdate

        Searches specifically for chipset drivers from Windows Update.

    .EXAMPLE
        $hwInfo = Get-ChipsetInformation
        Search-ChipsetDriver -HardwareInfo $hwInfo -IncludeInstalled -Format Table

        Searches for drivers using existing hardware information and displays results in table format.

    .OUTPUTS
        [PSCustomObject[]] Array of driver information objects with the following properties:
        - DeviceName: Name of the hardware device
        - DeviceClass: Hardware device class
        - CurrentDriver: Currently installed driver information
        - AvailableDrivers: Array of available driver updates
        - RecommendedAction: Suggested action (Install, Update, None)
        - Source: Driver source (WindowsUpdate, Manufacturer, Local)

    .NOTES
        Requires administrator privileges for some driver operations.
        Internet connection required for Windows Update and manufacturer searches.
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [PSCustomObject]$HardwareInfo,

        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'Chipset', 'Network', 'Graphics', 'Audio', 'Storage', 'USB')]
        [string]$DriverType = 'All',

        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'WindowsUpdate', 'Manufacturer', 'Local')]
        [string]$Source = 'All',

        [Parameter(Mandatory = $false)]
        [switch]$IncludeInstalled,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Object', 'Table', 'List')]
        [string]$Format = 'Object'
    )

    begin {
    Write-Verbose "Starting driver search..."
    
    # Helper function to get Windows Update drivers
    function Search-WindowsUpdateDrivers {
        param(
            [string]$DeviceClass
        )
        
        try {
            Write-Verbose "Searching Windows Update for $DeviceClass drivers..."
            
            # Use Windows Update API through PowerShell
            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()
            
            # Search for driver updates
            $searchCriteria = "IsInstalled=0 and Type='Driver'"
            if ($DeviceClass -and $DeviceClass -ne 'All') {
                $searchCriteria += " and CategoryIDs contains '$DeviceClass'"
            }
            
            $searchResult = $updateSearcher.Search($searchCriteria)
            
            $drivers = @()
            foreach ($update in $searchResult.Updates) {
                $drivers += [PSCustomObject]@{
                    Title = $update.Title
                    Description = $update.Description
                    DriverClass = "Unknown"
                    DriverVersion = "Unknown"
                    DriverDate = $update.LastDeploymentChangeTime
                    Publisher = "Microsoft"
                    Source = "WindowsUpdate"
                    UpdateID = $update.Identity.UpdateID
                    Size = [math]::Round($update.MaxDownloadSize / 1MB, 2)
                }
            }
            
            return $drivers
        }
        catch {
            Write-Warning "Failed to search Windows Update: $($_.Exception.Message)"
            return @()
        }
    }
    
    # Helper function to search local driver store
    function Search-LocalDriverStore {
        param(
            [string]$DeviceClass
        )
        
        try {
            Write-Verbose "Searching local driver store..."
            
            $driverStore = Get-WindowsDriver -Online -All -ErrorAction Stop
            
            $drivers = $driverStore | ForEach-Object {
                [PSCustomObject]@{
                    Title = $_.OriginalFileName
                    Description = "Local driver store"
                    DriverClass = $_.ClassName
                    DriverVersion = $_.Version
                    DriverDate = $_.Date
                    Publisher = $_.ProviderName
                    Source = "Local"
                    PublishedName = $_.PublishedName
                    BootCritical = $_.BootCritical
                }
            }
            
            if ($DeviceClass -and $DeviceClass -ne 'All') {
                $drivers = $drivers | Where-Object { $_.DriverClass -like "*$DeviceClass*" }
            }
            
            return $drivers
        }
        catch {
            Write-Warning "Failed to search local driver store: $($_.Exception.Message)"
            return @()
        }
    }
    
    # Helper function to get manufacturer driver information
    function Search-ManufacturerDrivers {
        param(
            [PSCustomObject]$HardwareInfo
        )
        
        try {
            Write-Verbose "Searching for manufacturer drivers..."
            
            $manufacturerDrivers = @()
            
            # Intel chipset drivers
            if ($HardwareInfo.CPU.Manufacturer -like "*Intel*" -or 
                $HardwareInfo.Motherboard.Manufacturer -like "*Intel*") {
                
                $manufacturerDrivers += [PSCustomObject]@{
                    Title = "Intel Chipset Device Software"
                    Description = "Intel chipset drivers for optimal system performance"
                    DriverClass = "System"
                    DriverVersion = "Latest"
                    DriverDate = Get-Date
                    Publisher = "Intel Corporation"
                    Source = "Manufacturer"
                    DownloadURL = "https://www.intel.com/content/www/us/en/support/detect.html"
                    RecommendedAction = "Visit Intel Driver & Support Assistant"
                }
            }
            
            # AMD chipset drivers
            if ($HardwareInfo.CPU.Manufacturer -like "*AMD*" -or 
                $HardwareInfo.Motherboard.Manufacturer -like "*AMD*") {
                
                $manufacturerDrivers += [PSCustomObject]@{
                    Title = "AMD Chipset Drivers"
                    Description = "AMD chipset drivers for optimal system performance"
                    DriverClass = "System"
                    DriverVersion = "Latest"
                    DriverDate = Get-Date
                    Publisher = "Advanced Micro Devices, Inc."
                    Source = "Manufacturer"
                    DownloadURL = "https://www.amd.com/en/support"
                    RecommendedAction = "Visit AMD Support website"
                }
            }
            
            # NVIDIA graphics drivers
            $nvidiaGPU = $HardwareInfo.Graphics | Where-Object { $_.Manufacturer -like "*NVIDIA*" }
            if ($nvidiaGPU) {
                $manufacturerDrivers += [PSCustomObject]@{
                    Title = "NVIDIA Graphics Drivers"
                    Description = "Latest NVIDIA graphics drivers"
                    DriverClass = "Display"
                    DriverVersion = "Latest"
                    DriverDate = Get-Date
                    Publisher = "NVIDIA Corporation"
                    Source = "Manufacturer"
                    DownloadURL = "https://www.nvidia.com/drivers"
                    RecommendedAction = "Use GeForce Experience or visit NVIDIA website"
                }
            }
            
            # AMD graphics drivers
            $amdGPU = $HardwareInfo.Graphics | Where-Object { $_.Manufacturer -like "*AMD*" -or $_.Name -like "*Radeon*" }
            if ($amdGPU) {
                $manufacturerDrivers += [PSCustomObject]@{
                    Title = "AMD Radeon Graphics Drivers"
                    Description = "Latest AMD Radeon graphics drivers"
                    DriverClass = "Display"
                    DriverVersion = "Latest"
                    DriverDate = Get-Date
                    Publisher = "Advanced Micro Devices, Inc."
                    Source = "Manufacturer"
                    DownloadURL = "https://www.amd.com/en/support"
                    RecommendedAction = "Use AMD Software or visit AMD website"
                }
            }
            
            return $manufacturerDrivers
        }
        catch {
            Write-Warning "Failed to search manufacturer drivers: $($_.Exception.Message)"
            return @()
        }
    }
    
    # Helper function to compare driver versions
    function Compare-DriverVersions {
        param(
            [string]$CurrentVersion,
            [string]$AvailableVersion
        )
        
        try {
            if (-not $CurrentVersion -or $CurrentVersion -eq "Unknown") {
                return "Install"
            }
            
            if (-not $AvailableVersion -or $AvailableVersion -eq "Unknown" -or $AvailableVersion -eq "Latest") {
                return "Check"
            }
            
            $current = [version]$CurrentVersion
            $available = [version]$AvailableVersion
            
            if ($available -gt $current) {
                return "Update"
            } elseif ($available -eq $current) {
                return "Current"
            } else {
                return "Newer"
            }
        }
        catch {
            return "Check"
        }
    }
}

process {
    try {
        # Get hardware information if not provided
        if (-not $HardwareInfo) {
            Write-Verbose "Hardware information not provided, gathering automatically..."
            $HardwareInfo = Get-ChipsetInformation -IncludeDrivers
        }
        
        $driverResults = @()
        
        # Search different sources based on parameters
        $allDrivers = @()
        
        if ($Source -eq 'All' -or $Source -eq 'WindowsUpdate') {
            $allDrivers += Search-WindowsUpdateDrivers -DeviceClass $DriverType
        }
        
        if ($Source -eq 'All' -or $Source -eq 'Local') {
            $allDrivers += Search-LocalDriverStore -DeviceClass $DriverType
        }
        
        if ($Source -eq 'All' -or $Source -eq 'Manufacturer') {
            $allDrivers += Search-ManufacturerDrivers -HardwareInfo $HardwareInfo
        }
        
        # Process hardware devices and match with available drivers
        $deviceClasses = @()
        
        switch ($DriverType) {
            'All' { $deviceClasses = @('System', 'Network', 'Display', 'Audio', 'Storage', 'USB') }
            'Chipset' { $deviceClasses = @('System') }
            'Network' { $deviceClasses = @('Network') }
            'Graphics' { $deviceClasses = @('Display') }
            'Audio' { $deviceClasses = @('Audio') }
            'Storage' { $deviceClasses = @('Storage') }
            'USB' { $deviceClasses = @('USB') }
        }
        
        foreach ($deviceClass in $deviceClasses) {
            # Get current drivers for this device class
            $currentDrivers = @()
            if ($HardwareInfo.Drivers -and $IncludeInstalled) {
                $currentDrivers = $HardwareInfo.Drivers.$deviceClass
            }
            
            # Find available drivers for this device class
            $availableDrivers = $allDrivers | Where-Object { 
                $_.DriverClass -eq $deviceClass -or 
                $_.Title -like "*$deviceClass*" -or
                ($deviceClass -eq 'System' -and $_.Title -like "*Chipset*")
            }
            
            # Create driver result objects
            if ($currentDrivers) {
                foreach ($currentDriver in $currentDrivers) {
                    $matchingAvailable = $availableDrivers | Where-Object { 
                        $_.Title -like "*$($currentDriver.DeviceName)*" -or
                        $_.Description -like "*$($currentDriver.DeviceName)*"
                    }
                    
                    $recommendedAction = "None"
                    if ($matchingAvailable) {
                        $recommendedAction = Compare-DriverVersions -CurrentVersion $currentDriver.DriverVersion -AvailableVersion $matchingAvailable[0].DriverVersion
                    }
                    
                    $driverResults += [PSCustomObject]@{
                        DeviceName = $currentDriver.DeviceName
                        DeviceClass = $currentDriver.DeviceClass
                        CurrentDriver = [PSCustomObject]@{
                            Version = $currentDriver.DriverVersion
                            Date = $currentDriver.DriverDate
                            Provider = $currentDriver.DriverProvider
                        }
                        AvailableDrivers = $matchingAvailable
                        RecommendedAction = $recommendedAction
                        Source = if ($matchingAvailable) { $matchingAvailable[0].Source } else { "None" }
                    }
                }
            } else {
                # No current drivers, show available drivers for this class
                foreach ($availableDriver in $availableDrivers) {
                    $driverResults += [PSCustomObject]@{
                        DeviceName = $availableDriver.Title
                        DeviceClass = $availableDriver.DriverClass
                        CurrentDriver = $null
                        AvailableDrivers = @($availableDriver)
                        RecommendedAction = "Install"
                        Source = $availableDriver.Source
                    }
                }
            }
        }
        
        # Remove duplicates and sort results
        $driverResults = $driverResults | Sort-Object DeviceClass, DeviceName | 
            Group-Object DeviceName | ForEach-Object { $_.Group[0] }
        
        # Format output based on requested format
        switch ($Format) {
            'Table' {
                Write-Output "=== DRIVER SEARCH RESULTS ==="
                $driverResults | Select-Object DeviceName, DeviceClass, RecommendedAction, Source | 
                    Format-Table -AutoSize
                
                $updateCount = ($driverResults | Where-Object { $_.RecommendedAction -eq 'Update' }).Count
                $installCount = ($driverResults | Where-Object { $_.RecommendedAction -eq 'Install' }).Count
                
                Write-Output ""
                Write-Output "Summary: $updateCount updates available, $installCount new drivers found"
            }
            
            'List' {
                $driverResults | Format-List -Property *
            }
            
            default {
                return $driverResults
            }
        }
    }
    catch {
        Write-Error "Failed to search for drivers: $($_.Exception.Message)"
        throw
    }
}

    end {
        Write-Verbose "Driver search completed."
    }
}
