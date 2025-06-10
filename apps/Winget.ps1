<#
.SYNOPSIS
    Winget wrapper functionality for the DotWin PowerShell module.

.DESCRIPTION
    This file provides wrapper functions for Windows Package Manager (winget)
    operations, integrating with the DotWin configuration management system.
#>

# Winget package configuration item class
class DotWinWingetPackage : DotWinConfigurationItem {
    [string]$PackageId
    [string]$Source
    [string]$Version
    [hashtable]$InstallOptions
    [bool]$AcceptLicense
    [bool]$AcceptSourceAgreements

    DotWinWingetPackage() : base() {
        $this.Type = "WingetPackage"
        $this.InstallOptions = @{}
        $this.AcceptLicense = $true
        $this.AcceptSourceAgreements = $true
        $this.Source = "winget"
    }

    DotWinWingetPackage([string]$PackageId) : base($PackageId, "WingetPackage") {
        $this.PackageId = $PackageId
        $this.InstallOptions = @{}
        $this.AcceptLicense = $true
        $this.AcceptSourceAgreements = $true
        $this.Source = "winget"
    }

    [bool] Test() {
        try {
            Write-DotWinLog "Testing if package '$($this.PackageId)' is installed" -Level Verbose

            # Check if winget is available
            if (-not (Test-WingetAvailable)) {
                Write-DotWinLog "Winget is not available on this system" -Level Warning
                return $false
            }

            # List installed packages and check if our package is present
            $installedPackages = Get-WingetInstalledPackages
            $package = $installedPackages | Where-Object {
                $_.Id -eq $this.PackageId -or $_.Name -eq $this.PackageId
            }

            if ($package) {
                Write-DotWinLog "Package '$($this.PackageId)' is installed (Version: $($package.Version))" -Level Verbose

                # If specific version is required, check version match
                if ($this.Version -and $package.Version -ne $this.Version) {
                    Write-DotWinLog "Package '$($this.PackageId)' version mismatch. Installed: $($package.Version), Required: $($this.Version)" -Level Verbose
                    return $false
                }

                return $true
            } else {
                Write-DotWinLog "Package '$($this.PackageId)' is not installed" -Level Verbose
                return $false
            }
        } catch {
            Write-DotWinLog "Error testing package '$($this.PackageId)': $($_.Exception.Message)" -Level Error
            return $false
        }
    }

    [void] Apply() {
        try {
            Write-DotWinLog "Installing package '$($this.PackageId)'" -Level Information

            # Check if winget is available
            if (-not (Test-WingetAvailable)) {
                throw "Winget is not available on this system"
            }

            # Build winget install command
            $arguments = @('install', $this.PackageId)

            if ($this.Source) {
                $arguments += @('--source', $this.Source)
            }

            if ($this.Version) {
                $arguments += @('--version', $this.Version)
            }

            if ($this.AcceptLicense) {
                $arguments += '--accept-package-agreements'
            }

            if ($this.AcceptSourceAgreements) {
                $arguments += '--accept-source-agreements'
            }

            # Add silent installation
            $arguments += '--silent'

            # Add custom install options
            foreach ($option in $this.InstallOptions.GetEnumerator()) {
                $arguments += "--$($option.Key)"
                if ($option.Value) {
                    $arguments += $option.Value
                }
            }

            Write-DotWinLog "Executing: winget $($arguments -join ' ')" -Level Verbose

            # Execute winget install
            $result = Start-Process -FilePath 'winget' -ArgumentList $arguments -Wait -PassThru -NoNewWindow

            if ($result.ExitCode -eq 0) {
                Write-DotWinLog "Successfully installed package '$($this.PackageId)'" -Level Information
            } else {
                throw "Winget install failed with exit code: $($result.ExitCode)"
            }

        } catch {
            Write-DotWinLog "Error installing package '$($this.PackageId)': $($_.Exception.Message)" -Level Error
            throw
        }
    }

    [hashtable] GetCurrentState() {
        try {
            if (-not (Test-WingetAvailable)) {
                return @{
                    IsInstalled = $false
                    Version = $null
                    Source = $null
                    Error = "Winget not available"
                }
            }

            $installedPackages = Get-WingetInstalledPackages
            $package = $installedPackages | Where-Object {
                $_.Id -eq $this.PackageId -or $_.Name -eq $this.PackageId
            }

            if ($package) {
                return @{
                    IsInstalled = $true
                    Version = $package.Version
                    Source = $package.Source
                    Id = $package.Id
                    Name = $package.Name
                }
            } else {
                return @{
                    IsInstalled = $false
                    Version = $null
                    Source = $null
                }
            }
        } catch {
            return @{
                IsInstalled = $false
                Version = $null
                Source = $null
                Error = $_.Exception.Message
            }
        }
    }
}

function Test-WingetAvailable {
    <#
    .SYNOPSIS
        Tests if Windows Package Manager (winget) is available on the system.

    .DESCRIPTION
        Checks if winget command is available and functional.

    .OUTPUTS
        Boolean indicating if winget is available.
    #>
    [CmdletBinding()]
    param()

    try {
        $null = Get-Command 'winget' -ErrorAction Stop

        # Test winget functionality with a simple command
        $result = Start-Process -FilePath 'winget' -ArgumentList @('--version') -Wait -PassThru -NoNewWindow -RedirectStandardOutput 'NUL' -RedirectStandardError 'NUL'

        return ($result.ExitCode -eq 0)
    } catch {
        Write-DotWinLog "Winget is not available: $($_.Exception.Message)" -Level Verbose
        return $false
    }
}

function Get-WingetInstalledPackages {
    <#
    .SYNOPSIS
        Gets a list of packages installed via winget.

    .DESCRIPTION
        Retrieves the list of installed packages from winget and returns them as objects.

    .OUTPUTS
        Array of package objects with Id, Name, Version, and Source properties.
    #>
    [CmdletBinding()]
    param()

    try {
        Write-DotWinLog "Retrieving installed winget packages" -Level Verbose

        # Get installed packages list
        $result = & winget list --accept-source-agreements 2>$null

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to retrieve winget package list"
        }

        # Parse the output (skip header lines)
        $packages = @()
        $lines = $result | Where-Object { $_ -and $_ -notmatch '^-+$' -and $_ -notmatch '^Name\s+Id\s+Version' }

        foreach ($line in $lines) {
            if ($line -match '^\s*(.+?)\s+([^\s]+)\s+([^\s]+)(?:\s+([^\s]+))?\s*$') {
                $packages += [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    Id = $matches[2].Trim()
                    Version = $matches[3].Trim()
                    Source = if ($matches[4]) { $matches[4].Trim() } else { 'winget' }
                }
            }
        }

        Write-DotWinLog "Found $($packages.Count) installed packages" -Level Verbose
        return $packages

    } catch {
        Write-DotWinLog "Error retrieving installed packages: $($_.Exception.Message)" -Level Error
        return @()
    }
}

function Search-WingetPackage {
    <#
    .SYNOPSIS
        Searches for packages in winget repositories.

    .DESCRIPTION
        Searches for packages by name or ID in configured winget sources.

    .PARAMETER Query
        The search query (package name or ID).

    .PARAMETER Source
        The source to search in (optional).

    .PARAMETER Exact
        Perform exact match search.

    .OUTPUTS
        Array of package objects matching the search criteria.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter()]
        [string]$Source,

        [Parameter()]
        [switch]$Exact
    )

    try {
        Write-DotWinLog "Searching for package: $Query" -Level Verbose

        if (-not (Test-WingetAvailable)) {
            throw "Winget is not available on this system"
        }

        # Build search arguments
        $arguments = @('search', $Query, '--accept-source-agreements')

        if ($Source) {
            $arguments += @('--source', $Source)
        }

        if ($Exact) {
            $arguments += '--exact'
        }

        # Execute search
        $result = & winget @arguments 2>$null

        if ($LASTEXITCODE -ne 0) {
            Write-DotWinLog "No packages found for query: $Query" -Level Verbose
            return @()
        }

        # Parse search results
        $packages = @()
        $lines = $result | Where-Object { $_ -and $_ -notmatch '^-+$' -and $_ -notmatch '^Name\s+Id\s+Version' }

        foreach ($line in $lines) {
            if ($line -match '^\s*(.+?)\s+([^\s]+)\s+([^\s]+)(?:\s+([^\s]+))?\s*$') {
                $packages += [PSCustomObject]@{
                    Name = $matches[1].Trim()
                    Id = $matches[2].Trim()
                    Version = $matches[3].Trim()
                    Source = if ($matches[4]) { $matches[4].Trim() } else { 'winget' }
                }
            }
        }

        Write-DotWinLog "Found $($packages.Count) packages matching query: $Query" -Level Verbose
        return $packages

    } catch {
        Write-DotWinLog "Error searching for package '$Query': $($_.Exception.Message)" -Level Error
        throw
    }
}

function Install-WingetPackage {
    <#
    .SYNOPSIS
        Installs a package using winget.

    .DESCRIPTION
        Installs a specified package using Windows Package Manager with configurable options.

    .PARAMETER PackageId
        The package ID to install.

    .PARAMETER Version
        Specific version to install (optional).

    .PARAMETER Source
        The source to install from (optional).

    .PARAMETER AcceptLicense
        Accept package license agreements automatically.

    .PARAMETER AcceptSourceAgreements
        Accept source agreements automatically.

    .PARAMETER InstallOptions
        Additional installation options as a hashtable.

    .OUTPUTS
        Boolean indicating success of installation.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [string]$Source = 'winget',

        [Parameter()]
        [switch]$AcceptLicense,

        [Parameter()]
        [switch]$AcceptSourceAgreements,

        [Parameter()]
        [hashtable]$InstallOptions = @{}
    )

    try {
        if (-not (Test-WingetAvailable)) {
            throw "Winget is not available on this system"
        }

        if ($PSCmdlet.ShouldProcess($PackageId, "Install winget package")) {
            # Create and apply winget package configuration
            $package = [DotWinWingetPackage]::new($PackageId)
            $package.Version = $Version
            $package.Source = $Source
            $package.AcceptLicense = $AcceptLicense
            $package.AcceptSourceAgreements = $AcceptSourceAgreements
            $package.InstallOptions = $InstallOptions

            $package.Apply()
            return $true
        }

        return $false

    } catch {
        Write-DotWinLog "Error installing package '$PackageId': $($_.Exception.Message)" -Level Error
        throw
    }
}

function Uninstall-WingetPackage {
    <#
    .SYNOPSIS
        Uninstalls a package using winget.

    .DESCRIPTION
        Uninstalls a specified package using Windows Package Manager.

    .PARAMETER PackageId
        The package ID to uninstall.

    .PARAMETER Version
        Specific version to uninstall (optional).

    .PARAMETER Source
        The source the package was installed from (optional).

    .OUTPUTS
        Boolean indicating success of uninstallation.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId,

        [Parameter()]
        [string]$Version,

        [Parameter()]
        [string]$Source
    )

    try {
        if (-not (Test-WingetAvailable)) {
            throw "Winget is not available on this system"
        }

        if ($PSCmdlet.ShouldProcess($PackageId, "Uninstall winget package")) {
            Write-DotWinLog "Uninstalling package '$PackageId'" -Level Information

            # Build uninstall arguments
            $arguments = @('uninstall', $PackageId, '--silent')

            if ($Version) {
                $arguments += @('--version', $Version)
            }

            if ($Source) {
                $arguments += @('--source', $Source)
            }

            # Execute uninstall
            $result = Start-Process -FilePath 'winget' -ArgumentList $arguments -Wait -PassThru -NoNewWindow

            if ($result.ExitCode -eq 0) {
                Write-DotWinLog "Successfully uninstalled package '$PackageId'" -Level Information
                return $true
            } else {
                throw "Winget uninstall failed with exit code: $($result.ExitCode)"
            }
        }

        return $false

    } catch {
        Write-DotWinLog "Error uninstalling package '$PackageId': $($_.Exception.Message)" -Level Error
        throw
    }
}