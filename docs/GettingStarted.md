# Getting Started with DotWin

## Overview

DotWin is an enterprise-grade Windows configuration management system that provides intelligent, adaptive system configuration through advanced profiling and automated recommendations. This guide will help you get started quickly and effectively.

## Installation

### System Requirements

- **Operating System**: Windows 11 (recommended) or Windows 10 version 1903+
- **PowerShell**: 5.1 (minimum) or PowerShell 7+ (recommended for best performance)
- **Memory**: 4GB RAM minimum, 8GB+ recommended
- **Storage**: 1GB free space for module and temporary files
- **Network**: Internet connection for package downloads and driver updates
- **Privileges**: Administrator rights for system-level operations

### Quick Installation

1. **Download DotWin**

   ```powershell
   # Clone from repository
   git clone https://github.com/your-org/DotWin.git
   cd DotWin
   
   # Or download and extract ZIP file
   Invoke-WebRequest -Uri "https://github.com/your-org/DotWin/archive/main.zip" -OutFile "DotWin.zip"
   Expand-Archive -Path "DotWin.zip" -DestinationPath "."
   ```

2. **Import the Module**

   ```powershell
   # Run PowerShell as Administrator
   Import-Module .\DotWin.psd1 -Force
   ```

3. **Verify Installation**

   ```powershell
   # Check module status
   Get-DotWinStatus -IncludeSystemInfo -IncludeModuleInfo
   
   # Test environment
   Test-DotWinEnvironment
   ```

### Advanced Installation Options

#### PowerShell Gallery Installation (Future)

```powershell
# Install from PowerShell Gallery
Install-Module -Name DotWin -Scope CurrentUser
Import-Module DotWin
```

#### Enterprise Deployment

```powershell
# Copy to PowerShell modules directory
$ModulePath = "$env:ProgramFiles\WindowsPowerShell\Modules\DotWin"
Copy-Item -Path ".\DotWin" -Destination $ModulePath -Recurse -Force

# Import for all users
Import-Module DotWin -Force
```

## First Steps

### 1. System Profiling

Start by profiling your system to understand its current state:

```powershell
# Basic system profiling
$profile = Get-DotWinSystemProfile

# View system summary
Write-Host "Hardware Category: $($profile.Hardware.GetHardwareCategory())"
Write-Host "User Type: $($profile.Software.GetUserType())"
Write-Host "Technical Level: $($profile.User.GetTechnicalLevel())"
Write-Host "Performance Score: $($profile.SystemMetrics.PerformanceScore)/100"
```

### 2. Get Recommendations

Generate intelligent recommendations based on your system profile:

```powershell
# Get all recommendations
$recommendations = Get-DotWinRecommendations -SystemProfile $profile

# View top recommendations
$recommendations | Select-Object -First 5 | Format-Table Title, Category, Priority, ConfidenceScore

# Filter by priority
$highPriority = Get-DotWinRecommendations -SystemProfile $profile -Priority "High"
```

### 3. Apply Safe Recommendations

Apply high-confidence, low-risk recommendations automatically:

```powershell
# Preview what would be applied
Get-DotWinRecommendations -ApplyRecommendations -WhatIf

# Apply safe recommendations
Get-DotWinRecommendations -ApplyRecommendations
```

## Common Use Cases

### Developer Setup

Perfect for setting up a development environment:

```powershell
# Profile system for development
$profile = Get-DotWinSystemProfile -UseParallel

# Get development-focused recommendations
$devRecs = Get-DotWinRecommendations -SystemProfile $profile -Category "Development","Software"

# Install essential development tools
Install-SystemTools -ToolCategory Development

# Configure WSL for development
$wslConfig = $WSLConfigurations.UbuntuDev
if (-not $wslConfig.Test()) {
    Write-Host "Setting up WSL Ubuntu development environment..."
    $wslConfig.Apply()
}

# Apply intelligent configuration
Invoke-DotWinProfiledConfiguration -ApplyRecommendations -UseParallel
```

### Gaming System Optimization

Optimize your system for gaming:

```powershell
# Check if system is gaming-optimized
$profile = Get-DotWinSystemProfile
if ($profile.Hardware.IsGamingOptimized()) {
    Write-Host "Gaming hardware detected!" -ForegroundColor Green
    
    # Get gaming-specific recommendations
    $gamingRecs = Get-DotWinRecommendations -SystemProfile $profile | 
        Where-Object { $_.Category -eq "Hardware" -or $_.Title -like "*Gaming*" }
    
    # Update graphics drivers
    Search-ChipsetDriver -DriverType Graphics | 
        Where-Object { $_.RecommendedAction -eq 'Update' } |
        ForEach-Object { Install-ChipsetDriver -DriverInfo $_ }
}
```

### Enterprise Baseline

Apply enterprise security and compliance settings:

```powershell
# Load enterprise configuration
$enterpriseConfig = Get-Content ".\templates\enterprise-baseline.json" | ConvertFrom-Json

# Apply with backup and audit logging
Invoke-DotWinProfiledConfiguration -Configuration $enterpriseConfig -BackupConfiguration -RollbackOnFailure

# Generate compliance report
$complianceReport = @{
    ComputerName = $env:COMPUTERNAME
    Timestamp = Get-Date
    SecurityScore = $profile.SystemMetrics.SecurityScore
    ComplianceStatus = "Compliant"
}
```

## Configuration Examples

### Basic Configuration File

Create a simple configuration file:

```json
{
  "name": "Basic Setup",
  "version": "1.0.0",
  "description": "Essential system configuration",
  "items": [
    {
      "name": "Essential Packages",
      "type": "Packages",
      "properties": {
        "packages": ["git", "vscode", "7zip", "firefox"]
      }
    },
    {
      "name": "Windows Features",
      "type": "Features",
      "properties": {
        "features": ["WSL", "Hyper-V"]
      }
    }
  ]
}
```

Apply the configuration:

```powershell
Invoke-DotWinConfiguration -ConfigurationPath ".\basic-setup.json"
```

### Advanced Configuration with Profiling

```powershell
# Create adaptive configuration based on system profile
$profile = Get-DotWinSystemProfile

$adaptiveConfig = [DotWinConfiguration]::new("Adaptive Setup")
$adaptiveConfig.Description = "Configuration adapted for $($profile.Software.GetUserType()) on $($profile.Hardware.GetHardwareCategory()) hardware"

# Add items based on user type
switch ($profile.Software.GetUserType()) {
    "Developer" {
        # Add development tools
        $devTools = [DotWinConfigurationItem]::new("Development Tools", "SystemTools")
        $devTools.Properties = @{ Category = "Development" }
        $adaptiveConfig.AddItem($devTools)
    }
    "Gamer" {
        # Add gaming optimizations
        $gamingOpt = [DotWinConfigurationItem]::new("Gaming Optimization", "Performance")
        $adaptiveConfig.AddItem($gamingOpt)
    }
}

# Apply adaptive configuration
Invoke-DotWinConfiguration -Configuration $adaptiveConfig
```

## Best Practices

### Performance Tips

1. **Use PowerShell 7+** for better performance and parallel processing
2. **Run as Administrator** for complete system access
3. **Use Parallel Processing** on multi-core systems
4. **Cache Profiles** for repeated analysis

```powershell
# Optimal performance setup
if ($PSVersionTable.PSVersion.Major -ge 7) {
    $profile = Get-DotWinSystemProfile -UseParallel -ExportPath ".\cache\profile.json"
} else {
    Write-Warning "Consider upgrading to PowerShell 7+ for better performance"
    $profile = Get-DotWinSystemProfile -ExportPath ".\cache\profile.json"
}
```

### Security Considerations

1. **Always backup** before major changes
2. **Review recommendations** before automatic application
3. **Use WhatIf** to preview changes
4. **Monitor logs** for security events

```powershell
# Secure configuration application
Invoke-DotWinProfiledConfiguration -BackupConfiguration -RollbackOnFailure -WhatIf

# Review before applying
$recommendations = Get-DotWinRecommendations
$recommendations | Where-Object { $_.Category -eq "Security" } | Format-Table
```

### Troubleshooting

#### Common Issues and Solutions

#### Issue: Module import fails

```powershell
# Check execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Unblock files if downloaded
Get-ChildItem -Path ".\DotWin" -Recurse | Unblock-File
```

#### Issue: Profiling incomplete**

```powershell
# Force complete re-profiling
$profile = Get-DotWinSystemProfile -Force -IncludeHardware -IncludeSoftware -IncludeUser

# Check for specific issues
Test-DotWinEnvironment
```

#### Issue: Recommendations not relevant**

```powershell
# Update system profile first
$profile = Get-DotWinSystemProfile -Force

# Filter recommendations by category
$relevantRecs = Get-DotWinRecommendations -SystemProfile $profile -Category "Software","Performance"
```

### Logging and Monitoring

Enable detailed logging for troubleshooting:

```powershell
# Enable verbose output
$VerbosePreference = "Continue"

# Enable debug logging
$DebugPreference = "Continue"

# Run with detailed logging
Get-DotWinSystemProfile -Verbose
Get-DotWinRecommendations -Verbose
```

## Next Steps

After completing the basic setup:

1. **Explore Advanced Features**: Learn about plugin development and cloud sync
2. **Customize Configurations**: Create your own configuration templates
3. **Automate Deployments**: Set up scheduled profiling and updates
4. **Monitor Performance**: Track system optimization over time

### Advanced Topics

- [Plugin Development](PluginDevelopment.md)
- [Enterprise Deployment](EnterpriseDeployment.md)
- [Configuration Templates](ConfigurationTemplates.md)
- [API Reference](APIReference.md)

### Community Resources

- **GitHub Issues**: Report bugs and request features
- **Documentation**: Comprehensive help via `Get-Help <FunctionName> -Full`
- **Examples**: Additional examples in the `examples/` directory

## Support

If you encounter issues:

1. Check the [Troubleshooting Guide](#troubleshooting)
2. Review the verbose logs
3. Search existing GitHub issues
4. Create a new issue with detailed information

Remember: DotWin is designed to be safe and reversible. Always use `-WhatIf` to preview changes and `-BackupConfiguration` for important systems.
