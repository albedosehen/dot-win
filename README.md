# DotWin

A comprehensive Windows 11 configuration management system for declarative system configuration and dotfiles management, similar to NixOS dotfiles or Terraform.

## Description

DotWin provides a PowerShell-based framework for managing Windows system configurations in a declarative, reproducible manner. It allows you to define your desired system state and automatically apply or validate configurations across multiple machines with advanced hardware management, WSL integration, and comprehensive system tools.

## Features

- **Declarative Configuration**: Define your system state using configuration objects
- **Idempotent Operations**: Safe to run multiple times without side effects
- **Extensible Architecture**: Plugin-based system for different configuration types
- **Hardware Management**: Automated chipset and driver detection, search, and installation
- **WSL Integration**: Complete Windows Subsystem for Linux configuration management
- **System Tools**: Automated installation of essential development and system utilities
- **Comprehensive Testing**: Validate configurations without making changes
- **Rich Status Reporting**: Detailed system and compliance status information
- **Package Management**: Automated software installation via Winget and Chocolatey
- **Profile Management**: PowerShell and Windows Terminal profile configuration

## Getting Started

### Prerequisites

- Windows 11 (or Windows 10 with PowerShell 5.1+)
- PowerShell 5.1 or PowerShell Core 7.x
- Administrator privileges (for some configuration operations)
- Internet connection (for package downloads and driver updates)

### Installation

1. Clone or download the DotWin repository
2. Open PowerShell as Administrator
3. Import the module:

```powershell
Import-Module .\DotWin.psd1
```

### Quick Start

```powershell
# Check system status
Get-DotWinStatus -IncludeSystemInfo -IncludeModuleInfo

# Get hardware information
Get-ChipsetInformation -IncludeDrivers

# Install essential development tools
Install-SystemTools -ToolCategory Development

# Search for driver updates
Search-ChipsetDriver -DriverType All -IncludeInstalled

# Configure WSL with Ubuntu
$wslConfig = $WSLConfigurations.UbuntuDev
Invoke-DotWinConfiguration -Configuration $wslConfig
```

## Core Components

### Classes

- **DotWinConfiguration**: Container for configuration items
- **DotWinConfigurationItem**: Base class for individual configuration items
- **DotWinWSLConfiguration**: Specialized class for WSL distribution management
- **DotWinValidationResult**: Results from configuration testing
- **DotWinExecutionResult**: Results from configuration application
- **DotWinSystemStatus**: System status and compliance information

### Hardware Management Functions

#### Get-ChipsetInformation

Retrieves comprehensive hardware information including motherboard, chipset, CPU, memory, storage, network, and graphics details.

```powershell
# Basic hardware information
$hwInfo = Get-ChipsetInformation

# Detailed information with drivers
$hwInfo = Get-ChipsetInformation -IncludeDrivers -Format Table

# Access specific hardware components
$hwInfo.CPU | Format-Table
$hwInfo.Memory.Modules | Format-Table
```

#### Search-ChipsetDriver

Searches for available drivers from multiple sources including Windows Update, manufacturer websites, and local driver stores.

```powershell
# Search for all available drivers
$drivers = Search-ChipsetDriver

# Search for specific driver types
$graphicsDrivers = Search-ChipsetDriver -DriverType Graphics -Source WindowsUpdate

# Search with hardware information
$hwInfo = Get-ChipsetInformation
$drivers = Search-ChipsetDriver -HardwareInfo $hwInfo -IncludeInstalled
```

#### Install-ChipsetDriver

Installs drivers with support for multiple sources and automatic system restore point creation.

```powershell
# Install drivers from search results
$drivers = Search-ChipsetDriver -DriverType Chipset
$updateDrivers = $drivers | Where-Object { $_.RecommendedAction -eq 'Update' }
Install-ChipsetDriver -DriverInfo $updateDrivers[0]

# Install from local driver package
Install-ChipsetDriver -DriverPath "C:\Drivers\chipset.inf"

# Install with automatic restart
Install-ChipsetDriver -DriverType Graphics -Source WindowsUpdate -Restart
```

#### Install-SystemTools

Installs essential system tools and utilities from curated catalogs.

```powershell
# Install all essential tools
Install-SystemTools

# Install specific tool categories
Install-SystemTools -ToolCategory Development
Install-SystemTools -ToolCategory System -Source Chocolatey

# Install specific tools
Install-SystemTools -ToolNames @('git', 'vscode', 'powershell')
```

### WSL Management

#### WSL Configuration Classes

Comprehensive WSL distribution management with predefined configurations.

```powershell
# Available predefined configurations
$WSLConfigurations.UbuntuDev      # Ubuntu development environment
$WSLConfigurations.DebianServer   # Debian server environment
$WSLConfigurations.KaliSecurity   # Kali Linux security testing
$WSLConfigurations.AlpineLite     # Alpine lightweight environment

# Create custom WSL configuration
$customWSL = [DotWinWSLConfiguration]::new("MyCustom", "Ubuntu-22.04")
$customWSL.Settings = @{
    DefaultUser = "developer"
    Memory = "8GB"
    Processors = "4"
}
$customWSL.Packages = @("docker.io", "kubectl", "terraform")
```

#### WSL Helper Functions

```powershell
# Check WSL prerequisites
Test-WSLPrerequisites

# Get available distributions
Get-AvailableWSLDistributions

# Test WSL configuration
$wslConfig = $WSLConfigurations.UbuntuDev
$wslConfig.Test()

# Apply WSL configuration
$wslConfig.Apply()
```

### Core Functions

#### Get-DotWinStatus

Comprehensive system status reporting with detailed information.

```powershell
# Basic status
Get-DotWinStatus

# Detailed status with system and module information
Get-DotWinStatus -IncludeSystemInfo -IncludeModuleInfo

# Status formatted as a table
Get-DotWinStatus -IncludeSystemInfo -Format Table
```

#### Test-DotWinConfiguration

Validate configurations without making changes (dry-run mode).

```powershell
# Test a configuration
$config = [DotWinConfiguration]::new("MySystemConfig")
$results = Test-DotWinConfiguration -Configuration $config

# Test with detailed output
$results = Test-DotWinConfiguration -Configuration $config -Detailed
```

#### Invoke-DotWinConfiguration

Apply configurations to the system with comprehensive logging.

```powershell
# Apply configuration
$config = [DotWinConfiguration]::new("MySystemConfig")
$results = Invoke-DotWinConfiguration -Configuration $config

# Apply with force (override existing configurations)
$results = Invoke-DotWinConfiguration -Configuration $config -Force
```

### Package and Application Management

```powershell
# Install packages
Install-Packages -WhatIf  # Preview changes
Install-Packages          # Apply changes

# Install applications
Install-Applications -Category Development

# Enable Windows features
Enable-Features -FeatureNames @("WSL", "Hyper-V")

# Remove bloatware
Remove-Bloatware -WhatIf

# Disable telemetry
Disable-Telemetry
```

### Profile Configuration

```powershell
# Configure PowerShell profile
Set-PowershellProfile -ProfileType AllUsers

# Configure Windows Terminal
Set-TerminalProfile -Theme Dark -FontSize 12
```

## Architecture

DotWin follows a modular, extensible architecture:

```text
DotWin/
├── DotWin.psd1                    # Module manifest
├── DotWin.psm1                    # Main module file
├── Classes.ps1                    # Core configuration classes
├── Test-Module.ps1                # Comprehensive test suite
├── functions/                     # Public API functions
│   ├── Get-DotWinStatus.ps1
│   ├── Test-DotWinConfiguration.ps1
│   ├── Invoke-DotWinConfiguration.ps1
│   ├── Get-ChipsetInformation.ps1      # Hardware detection
│   ├── Search-ChipsetDriver.ps1        # Driver discovery
│   ├── Install-ChipsetDriver.ps1       # Driver installation
│   ├── Install-SystemTools.ps1         # System utilities
│   ├── Install-Packages.ps1            # Package management
│   ├── Install-Applications.ps1        # Application installation
│   ├── Enable-Features.ps1             # Windows features
│   ├── Remove-Bloatware.ps1            # Bloatware removal
│   ├── Disable-Telemetry.ps1           # Privacy configuration
│   ├── Set-PowershellProfile.ps1       # PowerShell profiles
│   └── Set-TerminalProfile.ps1         # Terminal configuration
├── config/                        # Configuration modules
│   ├── Packages.ps1               # Package definitions
│   ├── Tools.ps1                  # Tool configurations
│   ├── Profile.ps1                # Profile settings
│   ├── Terminal.ps1               # Terminal settings
│   └── WSL.ps1                    # WSL configurations
├── apps/                          # Application-specific configurations
│   └── Winget.ps1                 # Winget integration
└── scripts/                       # Utility scripts
    └── legacy-helper.ps1          # Legacy system support
```

## Development Status

### Current Phase: Phase 3 - Advanced Features (COMPLETED)

✅ **Phase 1 - Foundation (Completed):**

- Core module structure and manifest
- Foundational configuration classes
- Public API functions with comprehensive help
- Basic testing and validation framework
- System status reporting
- Module initialization and error handling

✅ **Phase 2 - Core Functionality (Completed):**

- Package management system
- Application installation framework
- Windows feature management
- System configuration (bloatware removal, telemetry)
- Profile management (PowerShell, Terminal)
- Configuration validation and testing

✅ **Phase 3 - Advanced Features (Completed):**

- **Hardware Management**: Complete chipset and driver management system
  - Hardware detection and information gathering
  - Driver search from multiple sources (Windows Update, manufacturers, local)
  - Automated driver installation with restore points
  - System tools installation and management
- **WSL Integration**: Comprehensive Windows Subsystem for Linux support
  - Multiple distribution configurations (Ubuntu, Debian, Kali, Alpine)
  - Automated package installation and configuration
  - Custom environment setup and management
- **Testing Framework**: Comprehensive module testing
  - Unit tests for all functions and classes
  - Integration tests for complete workflows
  - Performance testing and validation
  - Error handling verification
- **Documentation**: Complete user and developer documentation

🚧 **Future Enhancements:**

- GUI management interface
- Configuration templates and profiles
- Advanced validation and rollback capabilities
- Cloud synchronization of configurations
- Enterprise deployment features

## Examples

### Complete System Setup

```powershell
# Import the module
Import-Module .\DotWin.psd1

# Check system status
$status = Get-DotWinStatus -IncludeSystemInfo -IncludeModuleInfo
Write-Host "System: $($status.OperatingSystem) on $($status.ComputerName)"

# Get hardware information
$hardware = Get-ChipsetInformation -IncludeDrivers
Write-Host "CPU: $($hardware.CPU[0].Name)"
Write-Host "Memory: $($hardware.Memory.TotalSlots) slots, $($hardware.System.TotalPhysicalMemory) GB total"

# Search for driver updates
$drivers = Search-ChipsetDriver -IncludeInstalled
$updates = $drivers | Where-Object { $_.RecommendedAction -eq 'Update' }
Write-Host "Found $($updates.Count) driver updates available"

# Install essential development tools
Write-Host "Installing development tools..."
$toolResults = Install-SystemTools -ToolCategory Development
$successful = ($toolResults | Where-Object { $_.Success }).Count
Write-Host "Successfully installed $successful tools"

# Configure WSL Ubuntu development environment
Write-Host "Setting up WSL Ubuntu development environment..."
$wslConfig = $WSLConfigurations.UbuntuDev
if (-not $wslConfig.Test()) {
    $wslConfig.Apply()
    Write-Host "WSL Ubuntu environment configured successfully"
} else {
    Write-Host "WSL Ubuntu environment already configured"
}

# Create and apply system configuration
$config = [DotWinConfiguration]::new("DevelopmentMachine")
$config.Description = "Complete development machine setup"

# Test configuration before applying
$testResults = Test-DotWinConfiguration -Configuration $config
Write-Host "Configuration test results: $($testResults.PassedItems) passed, $($testResults.FailedItems) failed"

# Apply configuration
$applyResults = Invoke-DotWinConfiguration -Configuration $config
Write-Host "Configuration applied successfully"
```

### Hardware Management Workflow

```powershell
# Comprehensive hardware analysis and driver management
Write-Host "=== Hardware Analysis and Driver Management ==="

# Step 1: Gather hardware information
Write-Host "Gathering hardware information..."
$hardware = Get-ChipsetInformation -IncludeDrivers -Format Object

# Display summary
Write-Host "`nHardware Summary:"
Write-Host "  Computer: $($hardware.System.Manufacturer) $($hardware.System.Model)"
Write-Host "  CPU: $($hardware.CPU[0].Name) ($($hardware.CPU[0].Cores) cores)"
Write-Host "  Memory: $($hardware.System.TotalPhysicalMemory) GB"
Write-Host "  Graphics: $($hardware.Graphics[0].Name)"

# Step 2: Search for driver updates
Write-Host "`nSearching for driver updates..."
$driverSearch = Search-ChipsetDriver -HardwareInfo $hardware -IncludeInstalled

# Analyze results
$updates = $driverSearch | Where-Object { $_.RecommendedAction -eq 'Update' }
$installs = $driverSearch | Where-Object { $_.RecommendedAction -eq 'Install' }

Write-Host "  Updates available: $($updates.Count)"
Write-Host "  New drivers available: $($installs.Count)"

# Step 3: Install critical updates (with confirmation)
if ($updates.Count -gt 0) {
    Write-Host "`nCritical driver updates found:"
    $updates | ForEach-Object {
        Write-Host "  - $($_.DeviceName) ($($_.DeviceClass))"
    }

    $confirm = Read-Host "Install driver updates? (y/N)"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        foreach ($update in $updates) {
            Write-Host "Installing driver for $($update.DeviceName)..."
            $result = Install-ChipsetDriver -DriverInfo $update
            if ($result.Success) {
                Write-Host "  ✓ Success" -ForegroundColor Green
            } else {
                Write-Host "  ✗ Failed: $($result.Message)" -ForegroundColor Red
            }
        }
    }
}
```

### WSL Development Environment Setup

```powershell
# Complete WSL development environment setup
Write-Host "=== WSL Development Environment Setup ==="

# Check prerequisites
if (-not (Test-WSLPrerequisites)) {
    Write-Error "System does not meet WSL prerequisites"
    return
}

# Show available distributions
$availableDistros = Get-AvailableWSLDistributions
Write-Host "Available WSL distributions:"
$availableDistros | Where-Object { $_.Recommended } | ForEach-Object {
    Write-Host "  - $($_.Name): $($_.Description)"
}

# Configure Ubuntu development environment
$ubuntuDev = $WSLConfigurations.UbuntuDev
Write-Host "`nConfiguring Ubuntu development environment..."
Write-Host "  Distribution: $($ubuntuDev.DistributionName)"
Write-Host "  Packages: $($ubuntuDev.Packages.Count) development packages"
Write-Host "  Settings: $($ubuntuDev.Settings.Keys -join ', ')"

# Test current state
$currentState = $ubuntuDev.GetCurrentState()
Write-Host "`nCurrent WSL state:"
Write-Host "  WSL Enabled: $($currentState.WSLEnabled)"
Write-Host "  Distribution Installed: $($currentState.DistributionInstalled)"
Write-Host "  Distribution Running: $($currentState.DistributionRunning)"

# Apply configuration if needed
if (-not $ubuntuDev.Test()) {
    Write-Host "`nApplying WSL configuration..."
    try {
        $ubuntuDev.Apply()
        Write-Host "WSL Ubuntu development environment configured successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to configure WSL: $($_.Exception.Message)"
    }
} else {
    Write-Host "WSL Ubuntu development environment is already configured." -ForegroundColor Green
}

# Verify installation
Write-Host "`nVerifying WSL installation..."
$finalState = $ubuntuDev.GetCurrentState()
if ($finalState.DistributionInstalled -and $finalState.DistributionRunning) {
    Write-Host "✓ WSL Ubuntu is installed and running" -ForegroundColor Green
    Write-Host "  Default user: $($finalState.DefaultUser)"
    Write-Host "  Version: $($finalState.Version)"
} else {
    Write-Host "✗ WSL Ubuntu setup incomplete" -ForegroundColor Red
}
```

## Testing

The module includes a comprehensive test suite that validates all functionality:

```powershell
# Run the complete test suite
.\Test-Module.ps1

# The test suite includes:
# - Module import and structure validation
# - Core class functionality testing
# - Hardware management function testing
# - WSL configuration testing
# - Package management testing
# - Error handling validation
# - Performance testing
# - Integration testing
```

Test categories:

- **Core**: Basic module functionality and classes
- **Hardware**: Hardware detection and driver management
- **WSL**: Windows Subsystem for Linux features
- **Tools**: System tools installation
- **Packages**: Package and application management
- **Configuration**: System configuration functions
- **Performance**: Performance and timing validation
- **Integration**: End-to-end workflow testing

## Contributing

This project has completed its Phase 3 development with comprehensive advanced features. The module is now production-ready with:

- Complete hardware management capabilities
- Full WSL integration and management
- Comprehensive system tools installation
- Extensive testing framework
- Complete documentation

Future contributions can focus on:

- Additional hardware vendor support
- More WSL distribution configurations
- Enhanced GUI management interface
- Cloud synchronization features
- Enterprise deployment tools

## License

All rights reserved.

## Authors

- Shon Thomas (albedosehen)

## Version History

- **1.0.0** - Foundational framework implementation
  - Core classes and module structure
  - Public API functions
  - Basic testing and validation
  - System status reporting

- **1.1.0** - Core functionality implementation
  - Package management system
  - Application installation framework
  - Windows feature management
  - System configuration capabilities
  - Profile management

- **1.2.0** - Advanced features implementation (Phase 3)
  - **Hardware Management**: Complete chipset and driver management
  - **WSL Integration**: Comprehensive Linux subsystem support
  - **System Tools**: Automated utility installation
  - **Testing Framework**: Comprehensive validation suite
  - **Documentation**: Complete user and developer guides

## Acknowledgments

Inspired by:

- NixOS configuration management
- Terraform infrastructure as code
- PowerShell DSC (Desired State Configuration)
- Ansible automation platform
- Chocolatey package management

## Support

For issues, questions, or contributions, please refer to the comprehensive test suite and documentation provided. The module includes extensive help documentation for all functions accessible via `Get-Help <FunctionName> -Full`.

## Quick Reference

### Essential Commands

```powershell
# System status and information
Get-DotWinStatus -IncludeSystemInfo
Get-ChipsetInformation -IncludeDrivers

# Hardware and driver management
Search-ChipsetDriver -DriverType All
Install-ChipsetDriver -DriverType Chipset -Source WindowsUpdate

# System tools and packages
Install-SystemTools -ToolCategory Development
Install-Packages
Install-Applications

# WSL management
Test-WSLPrerequisites
$WSLConfigurations.UbuntuDev.Apply()

# Configuration management
Test-DotWinConfiguration -Configuration $config
Invoke-DotWinConfiguration -Configuration $config

# Testing and validation
.\Test-Module.ps1
```

DotWin is now a comprehensive, production-ready Windows 11 configuration management system with advanced hardware management, WSL integration, and extensive automation capabilities.
