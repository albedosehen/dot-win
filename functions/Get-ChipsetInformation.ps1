function Get-ChipsetInformation {
    <#
    .SYNOPSIS
        Retrieves detailed chipset and hardware information from the system.

    .DESCRIPTION
        The Get-ChipsetInformation function gathers comprehensive hardware information
        including motherboard, chipset, CPU, and system details. This information is
        used for driver discovery and system configuration management.

    .PARAMETER IncludeDrivers
        Include information about currently installed drivers for detected hardware.

    .PARAMETER Format
        Specifies the output format. Valid values are 'Object', 'Table', 'List'.
        Default is 'Object'.

    .EXAMPLE
        Get-ChipsetInformation

        Returns basic chipset and hardware information as a PowerShell object.

    .EXAMPLE
        Get-ChipsetInformation -IncludeDrivers -Format Table

        Returns detailed hardware information including drivers in table format.

    .EXAMPLE
        $hwInfo = Get-ChipsetInformation -IncludeDrivers
        $hwInfo.Motherboard.Manufacturer

        Gets hardware information and accesses the motherboard manufacturer.

    .OUTPUTS
        [PSCustomObject] Hardware information object with the following properties:
        - System: Computer system information
        - Motherboard: Motherboard details
        - Chipset: Chipset information
        - CPU: Processor details
        - Memory: RAM information
        - Storage: Storage devices
        - Network: Network adapters
        - Graphics: Graphics adapters
        - Drivers: Driver information (if IncludeDrivers is specified)

    .NOTES
        Requires Windows Management Instrumentation (WMI) access.
        Some information may require administrator privileges.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$IncludeDrivers,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Object', 'Table', 'List')]
        [string]$Format = 'Object'
    )

    begin {
    Write-Verbose "Starting chipset information gathering..."
    
    # Helper function to safely get WMI information
    function Get-SafeWmiObject {
        param(
            [string]$ClassName,
            [string]$Property = '*'
        )
        
        try {
            Get-CimInstance -ClassName $ClassName -Property $Property -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to retrieve $ClassName information: $($_.Exception.Message)"
            return $null
        }
    }
    
    # Helper function to get driver information
    function Get-HardwareDrivers {
        param(
            [string]$DeviceClass
        )
        
        try {
            $drivers = Get-CimInstance -ClassName Win32_PnPSignedDriver -ErrorAction Stop
            if ($DeviceClass) {
                $drivers = $drivers | Where-Object { $_.DeviceClass -eq $DeviceClass }
            }
            return $drivers | Select-Object DeviceName, DriverVersion, DriverDate, DriverProvider, DeviceClass
        }
        catch {
            Write-Warning "Failed to retrieve driver information: $($_.Exception.Message)"
            return @()
        }
    }
}

process {
    try {
        Write-Verbose "Gathering system information..."
        
        # System Information
        $computerSystem = Get-SafeWmiObject -ClassName 'Win32_ComputerSystem'
        $operatingSystem = Get-SafeWmiObject -ClassName 'Win32_OperatingSystem'
        $bios = Get-SafeWmiObject -ClassName 'Win32_BIOS'
        
        # Motherboard Information
        $motherboard = Get-SafeWmiObject -ClassName 'Win32_BaseBoard'
        $systemEnclosure = Get-SafeWmiObject -ClassName 'Win32_SystemEnclosure'
        
        # CPU Information
        $processor = Get-SafeWmiObject -ClassName 'Win32_Processor'
        
        # Memory Information
        $memory = Get-SafeWmiObject -ClassName 'Win32_PhysicalMemory'
        $memoryArray = Get-SafeWmiObject -ClassName 'Win32_PhysicalMemoryArray'
        
        # Storage Information
        $diskDrives = Get-SafeWmiObject -ClassName 'Win32_DiskDrive'
        
        # Network Information
        $networkAdapters = Get-SafeWmiObject -ClassName 'Win32_NetworkAdapter' | 
            Where-Object { $_.PhysicalAdapter -eq $true -and $_.AdapterTypeId -ne $null }
        
        # Graphics Information
        $videoControllers = Get-SafeWmiObject -ClassName 'Win32_VideoController'
        
        # Build the hardware information object
        $hardwareInfo = [PSCustomObject]@{
            System = [PSCustomObject]@{
                ComputerName = $computerSystem.Name
                Manufacturer = $computerSystem.Manufacturer
                Model = $computerSystem.Model
                SystemType = $computerSystem.SystemType
                TotalPhysicalMemory = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
                OperatingSystem = $operatingSystem.Caption
                OSVersion = $operatingSystem.Version
                OSArchitecture = $operatingSystem.OSArchitecture
                LastBootUpTime = $operatingSystem.LastBootUpTime
            }
            
            Motherboard = [PSCustomObject]@{
                Manufacturer = $motherboard.Manufacturer
                Product = $motherboard.Product
                Version = $motherboard.Version
                SerialNumber = $motherboard.SerialNumber
                ChassisTypes = $systemEnclosure.ChassisTypes
            }
            
            BIOS = [PSCustomObject]@{
                Manufacturer = $bios.Manufacturer
                Version = $bios.SMBIOSBIOSVersion
                ReleaseDate = $bios.ReleaseDate
                SerialNumber = $bios.SerialNumber
            }
            
            CPU = $processor | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    Manufacturer = $_.Manufacturer
                    Architecture = $_.Architecture
                    Family = $_.Family
                    Model = $_.Model
                    Stepping = $_.Stepping
                    Cores = $_.NumberOfCores
                    LogicalProcessors = $_.NumberOfLogicalProcessors
                    MaxClockSpeed = $_.MaxClockSpeed
                    CurrentClockSpeed = $_.CurrentClockSpeed
                    L2CacheSize = $_.L2CacheSize
                    L3CacheSize = $_.L3CacheSize
                }
            }
            
            Memory = [PSCustomObject]@{
                TotalSlots = $memoryArray.MemoryDevices
                MaxCapacity = [math]::Round($memoryArray.MaxCapacity / 1KB, 2)
                Modules = $memory | ForEach-Object {
                    [PSCustomObject]@{
                        Capacity = [math]::Round($_.Capacity / 1GB, 2)
                        Speed = $_.Speed
                        Manufacturer = $_.Manufacturer
                        PartNumber = $_.PartNumber
                        DeviceLocator = $_.DeviceLocator
                        MemoryType = $_.MemoryType
                    }
                }
            }
            
            Storage = $diskDrives | ForEach-Object {
                [PSCustomObject]@{
                    Model = $_.Model
                    Manufacturer = $_.Manufacturer
                    Size = [math]::Round($_.Size / 1GB, 2)
                    InterfaceType = $_.InterfaceType
                    MediaType = $_.MediaType
                    SerialNumber = $_.SerialNumber
                }
            }
            
            Network = $networkAdapters | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    Manufacturer = $_.Manufacturer
                    AdapterType = $_.AdapterType
                    MACAddress = $_.MACAddress
                    Speed = $_.Speed
                    NetConnectionStatus = $_.NetConnectionStatus
                }
            }
            
            Graphics = $videoControllers | ForEach-Object {
                [PSCustomObject]@{
                    Name = $_.Name
                    Manufacturer = $_.Manufacturer
                    AdapterRAM = if ($_.AdapterRAM) { [math]::Round($_.AdapterRAM / 1MB, 2) } else { "Unknown" }
                    DriverVersion = $_.DriverVersion
                    DriverDate = $_.DriverDate
                    VideoProcessor = $_.VideoProcessor
                    CurrentHorizontalResolution = $_.CurrentHorizontalResolution
                    CurrentVerticalResolution = $_.CurrentVerticalResolution
                }
            }
        }
        
        # Add driver information if requested
        if ($IncludeDrivers) {
            Write-Verbose "Gathering driver information..."
            $hardwareInfo | Add-Member -MemberType NoteProperty -Name 'Drivers' -Value @{
                System = Get-HardwareDrivers -DeviceClass 'System'
                Network = Get-HardwareDrivers -DeviceClass 'Net'
                Display = Get-HardwareDrivers -DeviceClass 'Display'
                Audio = Get-HardwareDrivers -DeviceClass 'Media'
                Storage = Get-HardwareDrivers -DeviceClass 'DiskDrive'
                USB = Get-HardwareDrivers -DeviceClass 'USB'
                All = Get-HardwareDrivers
            }
        }
        
        # Format output based on requested format
        switch ($Format) {
            'Table' {
                Write-Output "=== SYSTEM INFORMATION ==="
                $hardwareInfo.System | Format-Table -AutoSize
                
                Write-Output "=== MOTHERBOARD INFORMATION ==="
                $hardwareInfo.Motherboard | Format-Table -AutoSize
                
                Write-Output "=== CPU INFORMATION ==="
                $hardwareInfo.CPU | Format-Table -AutoSize
                
                Write-Output "=== MEMORY INFORMATION ==="
                $hardwareInfo.Memory.Modules | Format-Table -AutoSize
                
                if ($IncludeDrivers) {
                    Write-Output "=== DRIVER SUMMARY ==="
                    $hardwareInfo.Drivers.All | Group-Object DeviceClass | 
                        Select-Object Name, Count | Format-Table -AutoSize
                }
            }
            
            'List' {
                $hardwareInfo | Format-List -Property *
            }
            
            default {
                return $hardwareInfo
            }
        }
    }
    catch {
        Write-Error "Failed to gather chipset information: $($_.Exception.Message)"
        throw
    }
}

    end {
        Write-Verbose "Chipset information gathering completed."
    }
}
