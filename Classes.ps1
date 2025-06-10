<#
.SYNOPSIS
    Core configuration classes for the DotWin PowerShell module.

.DESCRIPTION
    This file contains the foundational classes used to represent and manage
    configuration objects in the DotWin system. These classes provide the
    object hierarchy for declarative configuration management.
#>

# Base configuration item class
class DotWinConfigurationItem {
    [string]$Name
    [string]$Type
    [string]$Description
    [hashtable]$Properties
    [bool]$Enabled
    [datetime]$LastModified

    DotWinConfigurationItem() {
        $this.Properties = @{}
        $this.Enabled = $true
        $this.LastModified = Get-Date
    }

    DotWinConfigurationItem([string]$Name, [string]$Type) {
        $this.Name = $Name
        $this.Type = $Type
        $this.Properties = @{}
        $this.Enabled = $true
        $this.LastModified = Get-Date
    }

    # Virtual method to be overridden by derived classes
    [bool] Test() {
        throw "Test method must be implemented by derived classes"
    }

    # Virtual method to be overridden by derived classes
    [void] Apply() {
        throw "Apply method must be implemented by derived classes"
    }

    # Virtual method to be overridden by derived classes
    [hashtable] GetCurrentState() {
        throw "GetCurrentState method must be implemented by derived classes"
    }
}

# Configuration collection class
class DotWinConfiguration {
    [string]$Name
    [string]$Version
    [string]$Description
    [System.Collections.Generic.List[DotWinConfigurationItem]]$Items
    [hashtable]$Metadata
    [datetime]$Created
    [datetime]$LastModified

    DotWinConfiguration() {
        $this.Items = [System.Collections.Generic.List[DotWinConfigurationItem]]::new()
        $this.Metadata = @{}
        $this.Created = Get-Date
        $this.LastModified = Get-Date
        $this.Version = "1.0.0"
    }

    DotWinConfiguration([string]$Name) {
        $this.Name = $Name
        $this.Items = [System.Collections.Generic.List[DotWinConfigurationItem]]::new()
        $this.Metadata = @{}
        $this.Created = Get-Date
        $this.LastModified = Get-Date
        $this.Version = "1.0.0"
    }

    # Add a configuration item
    [void] AddItem([DotWinConfigurationItem]$Item) {
        if ($null -eq $Item) {
            throw "Configuration item cannot be null"
        }
        $this.Items.Add($Item)
        $this.LastModified = Get-Date
    }

    # Remove a configuration item by name
    [bool] RemoveItem([string]$Name) {
        $item = $this.Items | Where-Object { $_.Name -eq $Name }
        if ($item) {
            $this.Items.Remove($item)
            $this.LastModified = Get-Date
            return $true
        }
        return $false
    }

    # Get a configuration item by name
    [DotWinConfigurationItem] GetItem([string]$Name) {
        return $this.Items | Where-Object { $_.Name -eq $Name }
    }

    # Get all items of a specific type
    [System.Collections.Generic.List[DotWinConfigurationItem]] GetItemsByType([string]$Type) {
        $result = [System.Collections.Generic.List[DotWinConfigurationItem]]::new()
        foreach ($item in $this.Items) {
            if ($item.Type -eq $Type) {
                $result.Add($item)
            }
        }
        return $result
    }

    # Test all configuration items
    [hashtable] TestAll() {
        $results = @{
            TotalItems = $this.Items.Count
            PassedItems = 0
            FailedItems = 0
            Results = @{}
        }

        foreach ($item in $this.Items) {
            if ($item.Enabled) {
                try {
                    $testResult = $item.Test()
                    $results.Results[$item.Name] = @{
                        Status = if ($testResult) { "Pass" } else { "Fail" }
                        Type = $item.Type
                        Error = $null
                    }
                    if ($testResult) {
                        $results.PassedItems++
                    } else {
                        $results.FailedItems++
                    }
                } catch {
                    $results.Results[$item.Name] = @{
                        Status = "Error"
                        Type = $item.Type
                        Error = $_.Exception.Message
                    }
                    $results.FailedItems++
                }
            }
        }

        return $results
    }
}

# Configuration validation result class
class DotWinValidationResult {
    [bool]$IsValid
    [string]$ItemName
    [string]$ItemType
    [string]$Message
    [string]$Severity
    [datetime]$Timestamp

    DotWinValidationResult() {
        $this.Timestamp = Get-Date
        $this.Severity = "Information"
    }

    DotWinValidationResult([bool]$IsValid, [string]$ItemName, [string]$Message) {
        $this.IsValid = $IsValid
        $this.ItemName = $ItemName
        $this.Message = $Message
        $this.Timestamp = Get-Date
        $this.Severity = if ($IsValid) { "Information" } else { "Error" }
    }
}

# Configuration execution result class
class DotWinExecutionResult {
    [bool]$Success
    [string]$ItemName
    [string]$ItemType
    [string]$Message
    [hashtable]$Changes
    [datetime]$Timestamp
    [timespan]$Duration

    DotWinExecutionResult() {
        $this.Changes = @{}
        $this.Timestamp = Get-Date
    }

    DotWinExecutionResult([bool]$Success, [string]$ItemName, [string]$Message) {
        $this.Success = $Success
        $this.ItemName = $ItemName
        $this.Message = $Message
        $this.Changes = @{}
        $this.Timestamp = Get-Date
    }
}

# System status class
class DotWinSystemStatus {
    [string]$ComputerName
    [string]$OperatingSystem
    [string]$PowerShellVersion
    [hashtable]$ConfigurationStatus
    [datetime]$LastCheck
    [bool]$IsCompliant

    DotWinSystemStatus() {
        $this.ComputerName = $env:COMPUTERNAME
        $this.OperatingSystem = "Windows"
        $this.PowerShellVersion = "5.1+"
        $this.ConfigurationStatus = @{}
        $this.LastCheck = Get-Date
        $this.IsCompliant = $false
    }

    # Method to initialize system information (called after construction with external data)
    [void] InitializeSystemInfo([string]$OSCaption, [string]$PSVersion) {
        if ($OSCaption) {
            $this.OperatingSystem = $OSCaption
        } else {
            try {
                $this.OperatingSystem = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
                if (-not $this.OperatingSystem) {
                    $this.OperatingSystem = "Unknown Windows Version"
                }
            } catch {
                $this.OperatingSystem = "Unknown"
            }
        }

        # Winget package configuration class
        class DotWinWingetPackage : DotWinConfigurationItem {
            [string]$PackageId
            [string]$Version
            [string]$Source
            [bool]$AcceptLicense
            [bool]$AcceptSourceAgreements
            [hashtable]$InstallOptions

            DotWinWingetPackage() : base() {
                $this.Type = "WingetPackage"
                $this.Source = "winget"
                $this.AcceptLicense = $false
                $this.AcceptSourceAgreements = $false
                $this.InstallOptions = @{}
            }

            DotWinWingetPackage([string]$PackageId) : base($PackageId, "WingetPackage") {
                $this.PackageId = $PackageId
                $this.Source = "winget"
                $this.AcceptLicense = $false
                $this.AcceptSourceAgreements = $false
                $this.InstallOptions = @{}
            }

            # Test if the package is installed
            [bool] Test() {
                try {
                    $result = & winget list --id $this.PackageId --exact --accept-source-agreements 2>$null
                    if ($LASTEXITCODE -eq 0 -and $result) {
                        # Check if the package appears in the output
                        $packageFound = $result | Where-Object { $_ -match [regex]::Escape($this.PackageId) }
                        return $null -ne $packageFound
                    }
                    return $false
                }
                catch {
                    Write-Verbose "Error testing package '$($this.PackageId)': $($_.Exception.Message)"
                    return $false
                }
            }

            # Install the package
            [void] Apply() {
                try {
                    $arguments = @('install', $this.PackageId, '--silent')

                    if ($this.Version) {
                        $arguments += @('--version', $this.Version)
                    }

                    if ($this.AcceptLicense) {
                        $arguments += '--accept-package-agreements'
                    }

                    if ($this.AcceptSourceAgreements) {
                        $arguments += '--accept-source-agreements'
                    }

                    # Add any custom install options
                    foreach ($option in $this.InstallOptions.GetEnumerator()) {
                        $arguments += "--$($option.Key)"
                        if ($option.Value -ne $true) {
                            $arguments += $option.Value
                        }
                    }

                    Write-Verbose "Installing package '$($this.PackageId)' with arguments: $($arguments -join ' ')"

                    $result = Start-Process -FilePath 'winget' -ArgumentList $arguments -Wait -PassThru -NoNewWindow

                    if ($result.ExitCode -ne 0) {
                        throw "Winget installation failed with exit code: $($result.ExitCode)"
                    }

                    $this.LastModified = Get-Date
                }
                catch {
                    throw "Failed to install package '$($this.PackageId)': $($_.Exception.Message)"
                }
            }

            # Get current state of the package
            [hashtable] GetCurrentState() {
                $state = @{
                    PackageId = $this.PackageId
                    IsInstalled = $this.Test()
                    InstalledVersion = $null
                    AvailableVersion = $null
                    Source = $this.Source
                    LastChecked = Get-Date
                }

                try {
                    # Try to get installed version
                    if ($state.IsInstalled) {
                        $listResult = & winget list --id $this.PackageId --exact --accept-source-agreements 2>$null
                        if ($LASTEXITCODE -eq 0 -and $listResult) {
                            # Parse version from winget list output (this is a simplified approach)
                            $versionLine = $listResult | Where-Object { $_ -match [regex]::Escape($this.PackageId) } | Select-Object -First 1
                            if ($versionLine -and $versionLine -match '\s+(\d+[\.\d]*[\w\-]*)\s+') {
                                $state.InstalledVersion = $matches[1]
                            }
                        }
                    }

                    # Try to get available version
                    $showResult = & winget show --id $this.PackageId --accept-source-agreements 2>$null
                    if ($LASTEXITCODE -eq 0 -and $showResult) {
                        $versionLine = $showResult | Where-Object { $_ -match '^Version:\s+(.+)$' } | Select-Object -First 1
                        if ($versionLine -and $versionLine -match '^Version:\s+(.+)$') {
                            $state.AvailableVersion = $matches[1].Trim()
                        }
                    }
                }
                catch {
                    Write-Verbose "Error getting package state for '$($this.PackageId)': $($_.Exception.Message)"
                }

                return $state
            }
        }

        if ($PSVersion) {
            $this.PowerShellVersion = $PSVersion
        }
    }
}