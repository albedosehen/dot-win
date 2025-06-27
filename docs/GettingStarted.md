# Getting Started with DotWin

Welcome to DotWin! This guide will help you get up and running with declarative Windows configuration management in minutes.

## Prerequisites

Before you begin, ensure you have:

- **Windows 10/11** (version 1903 or later)
- **PowerShell 5.1+** (PowerShell 7+ recommended for best performance)
- **Administrator privileges** for system-level changes
- **Internet connection** for package downloads

### Recommended Setup

- **PowerShell 7+** for parallel processing capabilities
- **Windows Terminal** for enhanced terminal experience
- **Git** for configuration version control

## Installation

### Method 1: PowerShell Gallery (Recommended)

```powershell
# Install DotWin from PowerShell Gallery
Install-Module DotWin -Scope CurrentUser

# Import the module
Import-Module DotWin

# Verify installation
Get-DotWinSystemStatus
```

### Method 2: Manual Installation

```powershell
# Clone the repository
git clone https://github.com/dotwin/dotwin.git
cd dotwin

# Import the module
Import-Module .\DotWin.psd1 -Force

# Verify installation
Get-Command -Module DotWin
```

## Quick Start Examples

### 1. System Profiling and Recommendations

Start by understanding your current system:

```powershell
# Get comprehensive system profile
$profile = Get-DotWinSystemProfile -UseParallel

# View system summary
$profile.Hardware.GetHardwareCategory()
$profile.Software.GetUserType()
$profile.User.GetTechnicalLevel()

# Get intelligent recommendations
$recommendations = Get-DotWinRecommendations -SystemProfile $profile -Priority "High"

# View top recommendations
$recommendations | Select-Object -First 5 | Format-Table Title, Priority, Category
```

### 2. Package Management

Install packages using rich configurations:

```powershell
# Install development tools by category
Install-Packages -Category "Development" -Source "winget"

# Install specific packages with options
$packages = @(
    @{ Id = "Git.Git"; Version = "2.40.0" },
    @{ Id = "Microsoft.VisualStudioCode"; InstallOptions = @{ scope = "machine" } }
)
Install-Packages -PackageList $packages -WhatIf

# View available package categories
Get-DotWinAvailableConfigurations -ConfigType "Packages"
```

### 3. Terminal Configuration

Configure Windows Terminal with rich themes:

```powershell
# Apply a complete terminal theme
Set-TerminalProfile -Theme "SolarizedDark" -IncludeProfiles -IncludeKeybindings

# View available themes
Get-DotWinAvailableConfigurations -ConfigType "Terminal"

# Configure with backup
Set-TerminalProfile -Theme "OneHalfDark" -BackupExisting
```

### 4. Complete System Configuration

Apply comprehensive configurations:

```powershell
# Apply a pre-built development workstation setup
Invoke-DotWinConfiguration -ConfigurationPath "examples/configurations/developer-workstation.json"

# Apply enterprise security baseline
Invoke-DotWinConfiguration -ConfigurationPath "examples/configurations/enterprise-baseline.json" -WhatIf
```

## Understanding DotWin Configurations

### Configuration Types

DotWin supports multiple configuration formats:

#### 1. Rich PowerShell Configurations (Recommended)

Located in `config/*.ps1` files with full PowerShell capabilities:

```powershell
# Example: Using package categories
Install-Packages -Category "Development"

# Example: Using terminal themes
Set-TerminalProfile -Theme "SolarizedDark"
```

#### 2. JSON Configurations

Declarative JSON files for complete system setup:

```json
{
  "name": "My Development Setup",
  "items": [
    {
      "name": "Development Tools",
      "type": "SystemTools",
      "enabled": true,
      "properties": {
        "category": "Development",
        "tools": ["git", "vscode", "docker-desktop"]
      }
    }
  ]
}
```

### Available Rich Configurations

#### Package Categories (`config/Packages.ps1`)

- **Development**: Git, VS Code, Docker, Node.js, Python
- **Productivity**: Office tools, browsers, utilities
- **Media**: Video/audio tools, codecs, players
- **Gaming**: Game platforms, tools, utilities
- **Security**: Antivirus, VPN, security tools

#### Terminal Themes (`config/Terminal.ps1`)

- **SolarizedDark**: Popular dark theme with excellent contrast
- **SolarizedLight**: Light variant of Solarized
- **OneHalfDark**: GitHub's dark theme
- **Campbell**: Windows Terminal default theme
- **Vintage**: Retro terminal appearance

#### PowerShell Profiles (`config/Profile.ps1`)

- **Developer**: Enhanced profile for developers
- **PowerUser**: Advanced features for power users
- **Basic**: Simple, clean profile for beginners

## Step-by-Step Walkthrough

### Step 1: Initial System Assessment

```powershell
# Check current system status
Get-DotWinSystemStatus

# Perform comprehensive profiling
$profile = Get-DotWinSystemProfile -IncludeHardware -IncludeSoftware -IncludeUser

# Export profile for reference
$profile | Export-Clixml "my-system-profile.xml"
```

### Step 2: Get Recommendations

```powershell
# Get all recommendations
$allRecommendations = Get-DotWinRecommendations -SystemProfile $profile

# Filter by priority
$highPriority = $allRecommendations | Where-Object Priority -eq "High"
$mediumPriority = $allRecommendations | Where-Object Priority -eq "Medium"

# View recommendations by category
$allRecommendations | Group-Object Category | Format-Table Name, Count
```

### Step 3: Apply Basic Configurations

```powershell
# Start with terminal configuration
Set-TerminalProfile -Theme "SolarizedDark" -IncludeProfiles -IncludeKeybindings

# Install essential development tools
Install-Packages -Category "Development" -AcceptLicenses

# Apply PowerShell profile enhancements
Set-PowerShellProfile -ProfileType "Developer"
```

### Step 4: Apply Advanced Configurations

```powershell
# Apply a complete workstation setup
Invoke-DotWinConfiguration -ConfigurationPath "examples/configurations/developer-workstation.json"

# Or create a custom configuration
$customConfig = @{
    name = "My Custom Setup"
    items = @(
        @{
            name = "My Packages"
            type = "Packages"
            properties = @{
                category = "Development"
                packages = @("Git.Git", "Microsoft.VisualStudioCode")
            }
        }
    )
}

Invoke-DotWinConfiguration -Configuration $customConfig
```

### Step 5: Export Your Configuration

```powershell
# Export current system state for backup
Export-DotWinConfiguration -OutputPath "my-system-backup.json" -IncludePackages -IncludeSettings -IncludeMetadata

# Export specific categories
Export-DotWinConfiguration -OutputPath "my-dev-setup.json" -PackageSource "Winget" -ExcludeSystemPackages
```

## Common Workflows

### Development Environment Setup

```powershell
# Complete development environment in one command
Invoke-DotWinConfiguration -ConfigurationPath "examples/configurations/developer-workstation.json"

# Or step by step
Install-Packages -Category "Development"
Set-TerminalProfile -Theme "SolarizedDark" -IncludeProfiles
Set-PowerShellProfile -ProfileType "Developer"
```

### System Optimization

```powershell
# Get optimization recommendations
$optimizations = Get-DotWinRecommendations -Category "Performance" -Priority "High"

# Apply safe optimizations automatically
Get-DotWinRecommendations -ApplyRecommendations -Category "Performance"

# Manual optimization
Set-SystemOptimizations -PowerPlan "High Performance" -VisualEffects "Performance"
```

### Security Hardening

```powershell
# Apply enterprise security baseline
Invoke-DotWinConfiguration -ConfigurationPath "examples/configurations/enterprise-baseline.json"

# Get security recommendations
$securityRecs = Get-DotWinRecommendations -Category "Security" -Priority "High"

# Apply specific security configurations
Set-SecurityConfiguration -EnableDefender -ConfigureFirewall -EnableBitLocker
```

## Configuration Discovery

### Finding Available Configurations

```powershell
# List all available configurations
Get-DotWinAvailableConfigurations

# List package categories
Get-DotWinAvailableConfigurations -ConfigType "Packages"

# List terminal themes
Get-DotWinAvailableConfigurations -ConfigType "Terminal"

# List PowerShell profiles
Get-DotWinAvailableConfigurations -ConfigType "Profile"
```

### Exploring Rich Configurations

```powershell
# View package categories and their contents
. "$env:USERPROFILE\Documents\PowerShell\Modules\DotWin\config\Packages.ps1"
Get-DevelopmentPackages
Get-ProductivityPackages

# View terminal themes
. "$env:USERPROFILE\Documents\PowerShell\Modules\DotWin\config\Terminal.ps1"
Get-SolarizedDarkTheme
Get-CampbellTheme
```

## Validation and Testing

### Configuration Validation

```powershell
# Validate configuration before applying
Test-DotWinConfiguration -ConfigurationPath "my-config.json"

# Test specific configuration types
Test-DotWinConfiguration -ConfigType "Packages" -Category "Development"

# Validate system prerequisites
Test-DotWinEnvironment
```

### Dry Run (WhatIf)

```powershell
# See what would happen without making changes
Invoke-DotWinConfiguration -ConfigurationPath "my-config.json" -WhatIf

# Test package installation
Install-Packages -Category "Development" -WhatIf

# Test terminal configuration
Set-TerminalProfile -Theme "SolarizedDark" -WhatIf
```

## Progress Tracking and Logging

### Monitoring Progress

DotWin provides comprehensive progress tracking:

```powershell
# Progress is automatically displayed during operations
Install-Packages -Category "Development"

# View detailed logs
Get-DotWinLog -Level Information -Last 50

# Export logs for troubleshooting
Export-DotWinLog -OutputPath "dotwin-logs.txt" -IncludeDebug
```

### Understanding Progress Output

```text
[████████████████████████████████████████] 100% | Installing Packages (4/4)
├─ [████████████████████████████████████████] 100% | Git.Git - Completed
├─ [████████████████████████████████████████] 100% | Microsoft.VisualStudioCode - Completed
├─ [████████████████████████████████████████] 100% | Docker.DockerDesktop - Completed
└─ [████████████████████████████████████████] 100% | Node.js - Completed

Package installation completed: 4 successful, 0 failed (Duration: 45.2s)
```

## Troubleshooting Common Issues

### Installation Issues

```powershell
# Check PowerShell execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify module installation
Get-Module DotWin -ListAvailable

# Check for conflicts
Get-Module DotWin -All
```

### Configuration Issues

```powershell
# Validate environment
Test-DotWinEnvironment

# Check configuration syntax
Test-DotWinConfiguration -ConfigurationPath "my-config.json"

# View detailed error information
$Error[0] | Format-List * -Force
```

### Permission Issues

```powershell
# Check if running as administrator
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# Run specific commands with elevation
Start-Process PowerShell -Verb RunAs -ArgumentList "-Command", "Install-Packages -Category Development"
```

## Best Practices

### 1. Configuration Management

- **Version Control**: Store your configurations in Git
- **Backup**: Export configurations before major changes
- **Testing**: Always use `-WhatIf` for new configurations
- **Incremental**: Apply configurations in small, testable chunks

### 2. System Maintenance

- **Regular Profiling**: Run system profiling monthly
- **Update Packages**: Keep packages updated regularly
- **Monitor Recommendations**: Check for new recommendations weekly
- **Backup Configurations**: Export system state before major changes

### 3. Security Considerations

- **Validate Sources**: Only use trusted configuration sources
- **Review Changes**: Always review what will be changed
- **Minimal Privileges**: Run with least necessary privileges
- **Audit Trail**: Keep logs of all system changes

## Next Steps

Now that you're familiar with DotWin basics:

1. **Explore Advanced Features**: Check out the [Architecture Guide](Architecture.md)
2. **Create Custom Configurations**: Learn about [Configuration Reference](ConfigurationReference.md)
3. **Contribute**: See our [Contributing Guide](../CONTRIBUTING.md)
4. **Get Help**: Visit [Troubleshooting](Troubleshooting.md) for common issues

## Quick Reference

### Essential Commands

```powershell
# System assessment
Get-DotWinSystemStatus
Get-DotWinSystemProfile

# Package management
Install-Packages -Category "Development"
Get-InstalledPackages

# Configuration
Invoke-DotWinConfiguration -ConfigurationPath "config.json"
Export-DotWinConfiguration -OutputPath "backup.json"

# Terminal and profiles
Set-TerminalProfile -Theme "SolarizedDark"
Set-PowerShellProfile -ProfileType "Developer"

# Recommendations
Get-DotWinRecommendations -Priority "High"
```

### Configuration Files

```text
DotWin/
├── config/
│   ├── Packages.ps1      # Package categories and definitions
│   ├── Terminal.ps1      # Terminal themes and profiles
│   ├── Profile.ps1       # PowerShell profile templates
│   ├── Tools.ps1         # System tools and optimizations
│   └── WSL.ps1          # WSL configurations
└── examples/
    └── configurations/
        ├── developer-workstation.json
        └── enterprise-baseline.json
```

Welcome to the world of declarative Windows configuration management! 🚀
