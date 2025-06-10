<#
.SYNOPSIS
    WSL (Windows Subsystem for Linux) configuration for DotWin.

.DESCRIPTION
    This configuration file defines WSL distributions, settings, and management
    functions for the DotWin system. It provides declarative configuration
    for WSL environments and automated setup of Linux distributions.

.NOTES
    Requires Windows 11 or Windows 10 version 2004 and higher.
    WSL feature must be enabled in Windows Features.
#>

# WSL Configuration Class
class DotWinWSLConfiguration : DotWinConfigurationItem {
    [string]$DistributionName
    [string]$Version
    [string]$DefaultUser
    [hashtable]$Settings
    [string[]]$Packages
    [hashtable]$Configuration
    
    DotWinWSLConfiguration() : base() {
        $this.Type = "WSL"
        $this.Settings = @{}
        $this.Packages = @()
        $this.Configuration = @{}
    }
    
    DotWinWSLConfiguration([string]$Name, [string]$DistributionName) : base($Name, "WSL") {
        $this.DistributionName = $DistributionName
        $this.Settings = @{}
        $this.Packages = @()
        $this.Configuration = @{}
    }
    
    [bool] Test() {
        try {
            # Check if WSL is enabled
            $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
            if (-not $wslFeature -or $wslFeature.State -ne "Enabled") {
                Write-Verbose "WSL feature is not enabled"
                return $false
            }
            
            # Check if distribution is installed
            $wslList = wsl --list --quiet 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose "WSL is not properly configured"
                return $false
            }
            
            $distributionExists = $wslList -contains $this.DistributionName
            if (-not $distributionExists) {
                Write-Verbose "Distribution '$($this.DistributionName)' is not installed"
                return $false
            }
            
            # Check if distribution is running
            $wslStatus = wsl --list --verbose 2>$null
            $distributionStatus = $wslStatus | Where-Object { $_ -like "*$($this.DistributionName)*" }
            
            if ($distributionStatus -and $distributionStatus -like "*Running*") {
                Write-Verbose "Distribution '$($this.DistributionName)' is running"
                return $true
            }
            
            Write-Verbose "Distribution '$($this.DistributionName)' exists but is not running"
            return $false
        }
        catch {
            Write-Verbose "WSL test failed: $($_.Exception.Message)"
            return $false
        }
    }
    
    [void] Apply() {
        try {
            Write-Verbose "Applying WSL configuration for '$($this.Name)'"
            
            # Enable WSL feature if not enabled
            $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
            if (-not $wslFeature -or $wslFeature.State -ne "Enabled") {
                Write-Verbose "Enabling WSL feature..."
                Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
            }
            
            # Enable Virtual Machine Platform if not enabled
            $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -ErrorAction SilentlyContinue
            if (-not $vmFeature -or $vmFeature.State -ne "Enabled") {
                Write-Verbose "Enabling Virtual Machine Platform..."
                Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
            }
            
            # Install distribution if not present
            $wslList = wsl --list --quiet 2>$null
            if ($LASTEXITCODE -eq 0 -and $wslList -notcontains $this.DistributionName) {
                Write-Verbose "Installing WSL distribution '$($this.DistributionName)'"
                $this.InstallDistribution()
            }
            
            # Configure distribution settings
            if ($this.Settings.Count -gt 0) {
                $this.ApplyDistributionSettings()
            }
            
            # Install packages if specified
            if ($this.Packages.Count -gt 0) {
                $this.InstallPackages()
            }
            
            # Apply custom configuration
            if ($this.Configuration.Count -gt 0) {
                $this.ApplyCustomConfiguration()
            }
            
            $this.LastModified = Get-Date
        }
        catch {
            throw "Failed to apply WSL configuration: $($_.Exception.Message)"
        }
    }
    
    [hashtable] GetCurrentState() {
        $state = @{
            WSLEnabled = $false
            DistributionInstalled = $false
            DistributionRunning = $false
            Version = "Unknown"
            DefaultUser = "Unknown"
            InstalledPackages = @()
        }
        
        try {
            # Check WSL feature status
            $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -ErrorAction SilentlyContinue
            $state.WSLEnabled = $wslFeature -and $wslFeature.State -eq "Enabled"
            
            if ($state.WSLEnabled) {
                # Check distribution status
                $wslList = wsl --list --quiet 2>$null
                if ($LASTEXITCODE -eq 0) {
                    $state.DistributionInstalled = $wslList -contains $this.DistributionName
                    
                    if ($state.DistributionInstalled) {
                        # Get distribution details
                        $wslStatus = wsl --list --verbose 2>$null
                        $distributionInfo = $wslStatus | Where-Object { $_ -like "*$($this.DistributionName)*" }
                        
                        if ($distributionInfo) {
                            $state.DistributionRunning = $distributionInfo -like "*Running*"
                            
                            # Extract version information
                            if ($distributionInfo -match "(\d+)") {
                                $state.Version = $matches[1]
                            }
                        }
                        
                        # Get default user
                        try {
                            $defaultUser = wsl -d $this.DistributionName whoami 2>$null
                            if ($LASTEXITCODE -eq 0) {
                                $state.DefaultUser = $defaultUser.Trim()
                            }
                        }
                        catch {
                            # Ignore errors getting default user
                        }
                    }
                }
            }
        }
        catch {
            Write-Verbose "Error getting WSL state: $($_.Exception.Message)"
        }
        
        return $state
    }
    
    [void] InstallDistribution() {
        switch ($this.DistributionName.ToLower()) {
            'ubuntu' {
                wsl --install -d Ubuntu
            }
            'ubuntu-20.04' {
                wsl --install -d Ubuntu-20.04
            }
            'ubuntu-22.04' {
                wsl --install -d Ubuntu-22.04
            }
            'debian' {
                wsl --install -d Debian
            }
            'kali-linux' {
                wsl --install -d kali-linux
            }
            'opensuse-leap-15.4' {
                wsl --install -d openSUSE-Leap-15.4
            }
            'alpine' {
                wsl --install -d Alpine
            }
            default {
                throw "Unsupported distribution: $($this.DistributionName)"
            }
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install WSL distribution '$($this.DistributionName)'"
        }
    }
    
    [void] ApplyDistributionSettings() {
        foreach ($setting in $this.Settings.Keys) {
            $value = $this.Settings[$setting]
            
            switch ($setting.ToLower()) {
                'defaultuser' {
                    # Set default user for distribution
                    $configPath = "$env:USERPROFILE\.wslconfig"
                    $configContent = @"
[$($this.DistributionName)]
user=$value
"@
                    Add-Content -Path $configPath -Value $configContent -Force
                }
                
                'memory' {
                    # Set memory limit
                    $configPath = "$env:USERPROFILE\.wslconfig"
                    $configContent = @"
[wsl2]
memory=$value
"@
                    Add-Content -Path $configPath -Value $configContent -Force
                }
                
                'processors' {
                    # Set processor count
                    $configPath = "$env:USERPROFILE\.wslconfig"
                    $configContent = @"
[wsl2]
processors=$value
"@
                    Add-Content -Path $configPath -Value $configContent -Force
                }
            }
        }
    }
    
    [void] InstallPackages() {
        Write-Verbose "Installing packages in WSL distribution '$($this.DistributionName)'"
        
        # Determine package manager based on distribution
        $packageManager = $this.GetPackageManager()
        
        foreach ($package in $this.Packages) {
            Write-Verbose "Installing package: $package"
            
            switch ($packageManager) {
                'apt' {
                    wsl -d $this.DistributionName sudo apt update
                    wsl -d $this.DistributionName sudo apt install -y $package
                }
                'yum' {
                    wsl -d $this.DistributionName sudo yum install -y $package
                }
                'zypper' {
                    wsl -d $this.DistributionName sudo zypper install -y $package
                }
                'apk' {
                    wsl -d $this.DistributionName sudo apk add $package
                }
                default {
                    Write-Warning "Unknown package manager for distribution '$($this.DistributionName)'"
                }
            }
        }
    }
    
    [string] GetPackageManager() {
        $distroLower = $this.DistributionName.ToLower()
        
        if ($distroLower -like "*ubuntu*" -or $distroLower -like "*debian*" -or $distroLower -like "*kali*") {
            return 'apt'
        }
        elseif ($distroLower -like "*centos*" -or $distroLower -like "*rhel*" -or $distroLower -like "*fedora*") {
            return 'yum'
        }
        elseif ($distroLower -like "*opensuse*" -or $distroLower -like "*suse*") {
            return 'zypper'
        }
        elseif ($distroLower -like "*alpine*") {
            return 'apk'
        }
        else {
            return 'unknown'
        }
    }
    
    [void] ApplyCustomConfiguration() {
        foreach ($config in $this.Configuration.Keys) {
            $value = $this.Configuration[$config]
            
            switch ($config.ToLower()) {
                'bashrc' {
                    # Add custom bashrc configuration
                    $bashrcContent = $value -join "`n"
                    wsl -d $this.DistributionName bash -c "echo '$bashrcContent' >> ~/.bashrc"
                }
                
                'profile' {
                    # Add custom profile configuration
                    $profileContent = $value -join "`n"
                    wsl -d $this.DistributionName bash -c "echo '$profileContent' >> ~/.profile"
                }
                
                'gitconfig' {
                    # Configure git settings
                    foreach ($gitSetting in $value.Keys) {
                        $gitValue = $value[$gitSetting]
                        wsl -d $this.DistributionName git config --global $gitSetting "$gitValue"
                    }
                }
            }
        }
    }
}

# Predefined WSL configurations
$WSLConfigurations = @{
    # Ubuntu Development Environment
    UbuntuDev = [DotWinWSLConfiguration]::new("Ubuntu Development", "Ubuntu")
    
    # Debian Server Environment
    DebianServer = [DotWinWSLConfiguration]::new("Debian Server", "Debian")
    
    # Kali Linux Security Testing
    KaliSecurity = [DotWinWSLConfiguration]::new("Kali Security", "kali-linux")
    
    # Alpine Lightweight Environment
    AlpineLite = [DotWinWSLConfiguration]::new("Alpine Lightweight", "Alpine")
}

# Configure Ubuntu Development Environment
$WSLConfigurations.UbuntuDev.Description = "Ubuntu development environment with common development tools"
$WSLConfigurations.UbuntuDev.Settings = @{
    DefaultUser = "developer"
    Memory = "4GB"
    Processors = "2"
}
$WSLConfigurations.UbuntuDev.Packages = @(
    "build-essential",
    "curl",
    "wget",
    "git",
    "vim",
    "nano",
    "htop",
    "tree",
    "unzip",
    "software-properties-common",
    "apt-transport-https",
    "ca-certificates",
    "gnupg",
    "lsb-release",
    "python3",
    "python3-pip",
    "nodejs",
    "npm"
)
$WSLConfigurations.UbuntuDev.Configuration = @{
    bashrc = @(
        "# Custom aliases",
        "alias ll='ls -alF'",
        "alias la='ls -A'",
        "alias l='ls -CF'",
        "alias grep='grep --color=auto'",
        "alias fgrep='fgrep --color=auto'",
        "alias egrep='egrep --color=auto'",
        "",
        "# Custom prompt",
        "export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '"
    )
    gitconfig = @{
        "user.name" = "Developer"
        "user.email" = "developer@example.com"
        "init.defaultBranch" = "main"
        "core.autocrlf" = "input"
    }
}

# Configure Debian Server Environment
$WSLConfigurations.DebianServer.Description = "Debian server environment for system administration"
$WSLConfigurations.DebianServer.Settings = @{
    DefaultUser = "admin"
    Memory = "2GB"
    Processors = "1"
}
$WSLConfigurations.DebianServer.Packages = @(
    "curl",
    "wget",
    "git",
    "vim",
    "htop",
    "tree",
    "unzip",
    "systemd",
    "cron",
    "rsync",
    "ssh",
    "ufw"
)

# Configure Kali Linux Security Environment
$WSLConfigurations.KaliSecurity.Description = "Kali Linux environment for security testing and penetration testing"
$WSLConfigurations.KaliSecurity.Settings = @{
    DefaultUser = "kali"
    Memory = "4GB"
    Processors = "2"
}
$WSLConfigurations.KaliSecurity.Packages = @(
    "kali-tools-top10",
    "metasploit-framework",
    "nmap",
    "wireshark",
    "burpsuite",
    "sqlmap",
    "nikto",
    "dirb",
    "gobuster",
    "hydra"
)

# Configure Alpine Lightweight Environment
$WSLConfigurations.AlpineLite.Description = "Alpine Linux lightweight environment for containers and minimal setups"
$WSLConfigurations.AlpineLite.Settings = @{
    DefaultUser = "alpine"
    Memory = "1GB"
    Processors = "1"
}
$WSLConfigurations.AlpineLite.Packages = @(
    "curl",
    "wget",
    "git",
    "vim",
    "htop",
    "tree",
    "bash",
    "shadow",
    "sudo"
)

# Helper function to get available WSL distributions
function Get-AvailableWSLDistributions {
    <#
    .SYNOPSIS
        Gets a list of available WSL distributions that can be installed.
    
    .DESCRIPTION
        Returns information about WSL distributions available for installation
        through the Windows Store or direct download.
    
    .EXAMPLE
        Get-AvailableWSLDistributions
        
        Returns a list of available WSL distributions.
    #>
    
    return @(
        @{ Name = "Ubuntu"; Description = "Ubuntu Linux distribution"; Recommended = $true },
        @{ Name = "Ubuntu-20.04"; Description = "Ubuntu 20.04 LTS"; Recommended = $true },
        @{ Name = "Ubuntu-22.04"; Description = "Ubuntu 22.04 LTS"; Recommended = $true },
        @{ Name = "Debian"; Description = "Debian GNU/Linux"; Recommended = $true },
        @{ Name = "kali-linux"; Description = "Kali Linux for security testing"; Recommended = $false },
        @{ Name = "openSUSE-Leap-15.4"; Description = "openSUSE Leap 15.4"; Recommended = $false },
        @{ Name = "Alpine"; Description = "Alpine Linux lightweight distribution"; Recommended = $false },
        @{ Name = "CentOS"; Description = "CentOS Linux distribution"; Recommended = $false },
        @{ Name = "Fedora"; Description = "Fedora Linux distribution"; Recommended = $false }
    )
}

# Helper function to check WSL prerequisites
function Test-WSLPrerequisites {
    <#
    .SYNOPSIS
        Tests if the system meets WSL prerequisites.
    
    .DESCRIPTION
        Checks if the system has the necessary features and requirements
        to run WSL distributions.
    
    .EXAMPLE
        Test-WSLPrerequisites
        
        Returns $true if WSL prerequisites are met, $false otherwise.
    #>
    
    try {
        # Check Windows version
        $osVersion = [System.Environment]::OSVersion.Version
        if ($osVersion.Major -lt 10 -or ($osVersion.Major -eq 10 -and $osVersion.Build -lt 19041)) {
            Write-Warning "WSL requires Windows 10 version 2004 (build 19041) or higher"
            return $false
        }
        
        # Check if Hyper-V is available
        $hyperVFeature = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -ErrorAction SilentlyContinue
        if (-not $hyperVFeature) {
            Write-Warning "Hyper-V feature is not available on this system"
            return $false
        }
        
        # Check if virtualization is enabled in BIOS
        $processor = Get-WmiObject -Class Win32_Processor
        if (-not $processor.VirtualizationFirmwareEnabled) {
            Write-Warning "Virtualization is not enabled in BIOS/UEFI"
            return $false
        }
        
        return $true
    }
    catch {
        Write-Warning "Failed to check WSL prerequisites: $($_.Exception.Message)"
        return $false
    }
}

# Note: These configurations and functions are available when this config file is dot-sourced
# No Export-ModuleMember needed as this is a configuration file, not a module