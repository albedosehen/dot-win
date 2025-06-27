0<#
.SYNOPSIS
    SystemTools configuration type for DotWin module.

.DESCRIPTION
    This class handles the installation and management of development tools
    via package managers like winget, chocolatey, and scoop.
#>

# SystemTools configuration item class
class DotWinSystemTools : DotWinConfigurationItem {
    [string]$Category
    [string]$Source
    [string[]]$Tools
    [bool]$AcceptLicenses
    [hashtable]$InstallOptions

    DotWinSystemTools() : base() {
        $this.Type = "SystemTools"
        $this.Category = "Development"
        $this.Source = "winget"
        $this.Tools = @()
        $this.AcceptLicenses = $false
        $this.InstallOptions = @{}
    }

    DotWinSystemTools([string]$Name) : base($Name, "SystemTools") {
        $this.Category = "Development"
        $this.Source = "winget"
        $this.Tools = @()
        $this.AcceptLicenses = $false
        $this.InstallOptions = @{}
    }

    [bool] Test() {
        try {
            # Initialize properties from configuration if not already set
            $this.InitializeFromProperties()

            if ($this.Tools.Count -eq 0) {
                Write-Verbose "No tools specified for testing"
                return $true
            }

            $allInstalled = $true

            foreach ($tool in $this.Tools) {
                $isInstalled = $this.IsToolInstalled($tool)
                if (-not $isInstalled) {
                    Write-Verbose "Tool '$tool' is not installed"
                    $allInstalled = $false
                }
            }

            return $allInstalled
        } catch {
            Write-Verbose "Error testing SystemTools: $($_.Exception.Message)"
            return $false
        }
    }

    [void] Apply() {
        try {
            # Initialize properties from configuration
            $this.InitializeFromProperties()

            if ($this.Tools.Count -eq 0) {
                Write-Warning "No tools specified for installation"
                return
            }

            Write-Verbose "Installing $($this.Tools.Count) tools using $($this.Source)"

            foreach ($tool in $this.Tools) {
                if (-not $this.IsToolInstalled($tool)) {
                    Write-Verbose "Installing tool: $tool"
                    $this.InstallTool($tool)
                } else {
                    Write-Verbose "Tool '$tool' is already installed"
                }
            }

            $this.LastModified = Get-Date
        } catch {
            throw "Error applying SystemTools configuration '$($this.Name)': $($_.Exception.Message)"
        }
    }

    [hashtable] GetCurrentState() {
        try {
            $this.InitializeFromProperties()

            $state = @{
                Name = $this.Name
                Category = $this.Category
                Source = $this.Source
                TotalTools = $this.Tools.Count
                InstalledTools = @()
                MissingTools = @()
                ToolStatus = @{}
            }

            foreach ($tool in $this.Tools) {
                $isInstalled = $this.IsToolInstalled($tool)
                $state.ToolStatus[$tool] = $isInstalled

                if ($isInstalled) {
                    $state.InstalledTools += $tool
                } else {
                    $state.MissingTools += $tool
                }
            }

            $state.InstalledCount = $state.InstalledTools.Count
            $state.MissingCount = $state.MissingTools.Count
            $state.CompliancePercentage = if ($state.TotalTools -gt 0) {
                [math]::Round(($state.InstalledCount / $state.TotalTools) * 100, 2)
            } else {
                100
            }

            return $state
        } catch {
            return @{
                Name = $this.Name
                Error = $_.Exception.Message
                TotalTools = $this.Tools.Count
                CompliancePercentage = 0
            }
        }
    }

    # Initialize properties from the Properties hashtable
    [void] InitializeFromProperties() {
        if ($this.Properties.ContainsKey("category")) {
            $this.Category = $this.Properties["category"]
        }

        if ($this.Properties.ContainsKey("source")) {
            $this.Source = $this.Properties["source"]
        }

        if ($this.Properties.ContainsKey("tools")) {
            $this.Tools = $this.Properties["tools"]
        }

        if ($this.Properties.ContainsKey("acceptLicenses")) {
            $this.AcceptLicenses = $this.Properties["acceptLicenses"]
        }

        if ($this.Properties.ContainsKey("installOptions")) {
            $this.InstallOptions = $this.Properties["installOptions"]
        }
    }

    # Check if a tool is installed
    [bool] IsToolInstalled([string]$Tool) {
        switch ($this.Source.ToLower()) {
            "winget" {
                return $this.IsWingetPackageInstalled($Tool)
            }
            "chocolatey" {
                return $this.IsChocolateyPackageInstalled($Tool)
            }
            "scoop" {
                return $this.IsScoopPackageInstalled($Tool)
            }
            default {
                # Try winget first, then chocolatey, then scoop
                return ($this.IsWingetPackageInstalled($Tool) -or
                        $this.IsChocolateyPackageInstalled($Tool) -or
                        $this.IsScoopPackageInstalled($Tool))
            }
        }

        # This should never be reached, but PowerShell requires it
        return $false
    }

    # Install a tool using the specified package manager
    [void] InstallTool([string]$Tool) {
        switch ($this.Source.ToLower()) {
            "winget" {
                $this.InstallWingetPackage($Tool)
            }
            "chocolatey" {
                $this.InstallChocolateyPackage($Tool)
            }
            "scoop" {
                $this.InstallScoopPackage($Tool)
            }
            default {
                # Default to winget
                $this.InstallWingetPackage($Tool)
            }
        }
    }

    # Check if winget package is installed
    [bool] IsWingetPackageInstalled([string]$PackageId) {
        try {
            $result = & winget list --id $PackageId --exact 2>$null
            return ($LASTEXITCODE -eq 0 -and $result -match $PackageId)
        } catch {
            return $false
        }
    }

    # Install winget package
    [void] InstallWingetPackage([string]$PackageId) {
        try {
            $args = @("install", "--id", $PackageId, "--exact")

            if ($this.AcceptLicenses) {
                $args += "--accept-package-agreements"
                $args += "--accept-source-agreements"
            }

            # Add install options
            if ($this.InstallOptions.ContainsKey("scope")) {
                $args += "--scope"
                $args += $this.InstallOptions["scope"]
            }

            if ($this.InstallOptions.ContainsKey("silent") -and $this.InstallOptions["silent"]) {
                $args += "--silent"
            }

            Write-Verbose "Executing: winget $($args -join ' ')"
            $result = & winget @args

            if ($LASTEXITCODE -ne 0) {
                throw "Winget installation failed with exit code $LASTEXITCODE"
            }
        } catch {
            throw "Error installing winget package '$PackageId': $($_.Exception.Message)"
        }
    }

    # Check if chocolatey package is installed
    [bool] IsChocolateyPackageInstalled([string]$PackageName) {
        try {
            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                return $false
            }

            $result = & choco list --local-only $PackageName --exact 2>$null
            return ($LASTEXITCODE -eq 0 -and $result -match $PackageName)
        } catch {
            return $false
        }
    }

    # Install chocolatey package
    [void] InstallChocolateyPackage([string]$PackageName) {
        try {
            if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                throw "Chocolatey is not installed"
            }

            $args = @("install", $PackageName, "-y")

            if ($this.AcceptLicenses) {
                $args += "--accept-license"
            }

            Write-Verbose "Executing: choco $($args -join ' ')"
            $result = & choco @args

            if ($LASTEXITCODE -ne 0) {
                throw "Chocolatey installation failed with exit code $LASTEXITCODE"
            }
        } catch {
            throw "Error installing chocolatey package '$PackageName': $($_.Exception.Message)"
        }
    }

    # Check if scoop package is installed
    [bool] IsScoopPackageInstalled([string]$PackageName) {
        try {
            if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
                return $false
            }

            $result = & scoop list $PackageName 2>$null
            return ($LASTEXITCODE -eq 0 -and $result -match $PackageName)
        } catch {
            return $false
        }
    }

    # Install scoop package
    [void] InstallScoopPackage([string]$PackageName) {
        try {
            if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
                throw "Scoop is not installed"
            }

            Write-Verbose "Executing: scoop install $PackageName"
            $result = & scoop install $PackageName

            if ($LASTEXITCODE -ne 0) {
                throw "Scoop installation failed with exit code $LASTEXITCODE"
            }
        } catch {
            throw "Error installing scoop package '$PackageName': $($_.Exception.Message)"
        }
    }
}
