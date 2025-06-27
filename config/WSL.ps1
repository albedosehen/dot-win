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