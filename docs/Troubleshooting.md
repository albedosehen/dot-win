# DotWin Troubleshooting Guide

This guide helps you diagnose and resolve common issues with DotWin configuration management.

## Quick Diagnostics

### System Health Check

Start with a comprehensive system health check:

```powershell
# Check DotWin environment
Test-DotWinEnvironment

# Get system status
Get-DotWinSystemStatus

# Verify module installation
Get-Module DotWin -ListAvailable

# Check for conflicts
Get-Module DotWin -All
```

### Common Quick Fixes

```powershell
# Refresh module
Remove-Module DotWin -Force
Import-Module DotWin -Force

# Clear cache
Clear-DotWinCache

# Reset configuration
Reset-DotWinConfiguration

# Update module
Update-Module DotWin
```

## Installation Issues

### Module Installation Problems

#### Issue: "Module not found" or "Cannot install module"

**Symptoms:**

- `Install-Module DotWin` fails
- Module not available after installation
- Import errors

**Solutions:**

```powershell
# Check PowerShell Gallery connectivity
Test-NetConnection powershellgallery.com -Port 443

# Install with different scope
Install-Module DotWin -Scope AllUsers -Force

# Manual installation from repository
git clone https://github.com/dotwin/dotwin.git
cd dotwin
Import-Module .\DotWin.psd1 -Force

# Check execution policy
Get-ExecutionPolicy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Issue: "Execution policy restriction"

**Symptoms:**

- Scripts cannot be executed
- "Execution of scripts is disabled" error

**Solutions:**

```powershell
# Check current policy
Get-ExecutionPolicy -List

# Set appropriate policy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Bypass for specific session
PowerShell -ExecutionPolicy Bypass

# Unblock downloaded files
Get-ChildItem -Path "C:\Path\To\DotWin" -Recurse | Unblock-File
```

### Permission Issues

#### Issue: "Access denied" or "Insufficient privileges"

**Symptoms:**

- Cannot modify system settings
- Registry access denied
- Package installation fails

**Solutions:**

```powershell
# Check if running as administrator
([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

# Run as administrator
Start-Process PowerShell -Verb RunAs

# Use UAC elevation for specific commands
Start-Process PowerShell -Verb RunAs -ArgumentList "-Command", "Install-Packages -Category Development"

# Check user account control settings
Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "EnableLUA"
```

## Configuration Issues

### Configuration Loading Problems

#### Issue: "Configuration file not found" or "Invalid configuration"

**Symptoms:**

- Cannot load configuration files
- JSON parsing errors
- Rich config files not recognized

**Solutions:**

```powershell
# Validate configuration file
Test-DotWinConfiguration -ConfigurationPath "config.json"

# Check file path and permissions
Test-Path "config.json"
Get-Acl "config.json"

# Validate JSON syntax
Get-Content "config.json" | ConvertFrom-Json

# Use rich configurations instead
Install-Packages -Category "Development"  # Instead of JSON config
Set-TerminalProfile -Theme "SolarizedDark"  # Instead of JSON config
```

#### Issue: "Rich configuration functions not available"

**Symptoms:**

- `Get-DevelopmentPackages` not found
- Theme functions not available
- Config files not loading

**Solutions:**

```powershell
# Check config file paths
$configPath = Join-Path $PSScriptRoot "config"
Test-Path $configPath

# Manually load config files
. "$PSScriptRoot\config\Packages.ps1"
. "$PSScriptRoot\config\Terminal.ps1"

# Verify functions are available
Get-Command Get-DevelopmentPackages
Get-Command Get-SolarizedDarkTheme

# Check module structure
Get-ChildItem -Path (Get-Module DotWin).ModuleBase -Recurse
```

### Configuration Bridge Issues

#### Issue: "Cannot convert rich config to JSON schema"

**Symptoms:**

- `ConvertTo-DotWinConfiguration` fails
- Rich configs not working with `Invoke-DotWinConfiguration`
- Bridge layer errors

**Solutions:**

```powershell
# Check if bridge functions exist
Get-Command ConvertTo-DotWinConfiguration -ErrorAction SilentlyContinue

# Use direct function calls instead
Install-Packages -Category "Development"  # Direct rich config usage

# Check for class availability
[DotWinConfiguration] -as [type]

# Verify configuration registry
Get-DotWinConfigurationRegistry
```

## Package Management Issues

### Package Installation Problems

#### Issue: "Package manager not found" or "Installation failed"

**Symptoms:**

- Winget, Chocolatey, or Scoop not available
- Package installation timeouts
- Dependency resolution failures

**Solutions:**

```powershell
# Check package manager availability
winget --version
choco --version
scoop --version

# Install missing package managers
# For Winget (usually pre-installed on Windows 11)
Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe

# For Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# For Scoop
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Test package installation manually
winget install Git.Git
choco install git
scoop install git
```

#### Issue: "Package already installed" but not detected

**Symptoms:**

- DotWin reports package as not installed
- Manual installation not recognized
- Duplicate installation attempts

**Solutions:**

```powershell
# Check package detection
Get-InstalledPackages -Source "winget"
Get-InstalledPackages -Source "chocolatey"

# Refresh package cache
winget list --accept-source-agreements
choco list --local-only

# Force package detection refresh
Clear-DotWinPackageCache
Get-InstalledPackages -Force

# Check specific package
Test-PackageInstalled -PackageId "Git.Git" -Source "winget"
```

### Package Source Issues

#### Issue: "Package source not available" or "Source agreements"

**Symptoms:**

- Source agreement prompts
- Package source timeouts
- Repository access issues

**Solutions:**

```powershell
# Accept source agreements
winget list --accept-source-agreements

# Configure package sources
winget source list
winget source reset

# Check network connectivity
Test-NetConnection winget.azureedge.net -Port 443
Test-NetConnection community.chocolatey.org -Port 443

# Use alternative sources
Install-Packages -PackageList @("Git.Git") -Source "chocolatey"
```

## Terminal Configuration Issues

### Windows Terminal Problems

#### Issue: "Windows Terminal not found" or "Configuration failed"

**Symptoms:**

- Terminal configuration fails
- Settings file not found
- Theme application errors

**Solutions:**

```powershell
# Check Windows Terminal installation
Get-AppxPackage -Name "Microsoft.WindowsTerminal*"

# Install Windows Terminal
winget install Microsoft.WindowsTerminal

# Check settings file location
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
Test-Path $settingsPath

# Backup and reset settings
Copy-Item $settingsPath "$settingsPath.backup"
Set-TerminalProfile -Theme "Campbell" -Force

# Manual theme application
$theme = Get-SolarizedDarkTheme
$theme | ConvertTo-Json | Set-Content $settingsPath
```

#### Issue: "Theme not applied" or "Invalid terminal configuration"

**Symptoms:**

- Terminal appearance unchanged
- Color scheme not working
- Profile creation failed

**Solutions:**

```powershell
# Check available themes
Get-DotWinAvailableConfigurations -ConfigType "Terminal"

# Validate theme configuration
$theme = Get-SolarizedDarkTheme
$theme | ConvertTo-Json -Depth 10

# Apply theme manually
Set-TerminalProfile -Theme "SolarizedDark" -Force -Verbose

# Check terminal settings syntax
Get-Content $settingsPath | ConvertFrom-Json

# Reset to default configuration
Remove-Item $settingsPath
Set-TerminalProfile -Theme "Campbell"
```

## System Profiling Issues

### Profiling Performance Problems

#### Issue: "System profiling is slow" or "Profiling hangs"

**Symptoms:**

- `Get-DotWinSystemProfile` takes too long
- Profiling process appears stuck
- High CPU usage during profiling

**Solutions:**

```powershell
# Use parallel processing (PowerShell 7+)
$profile = Get-DotWinSystemProfile -UseParallel

# Profile specific components only
$profile = Get-DotWinSystemProfile -IncludeHardware -IncludeSoftware:$false

# Check for WMI/CIM issues
Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
Get-WmiObject Win32_Processor -ErrorAction SilentlyContinue

# Clear profiling cache
Clear-DotWinProfileCache

# Run with timeout
$job = Start-Job { Get-DotWinSystemProfile }
Wait-Job $job -Timeout 300
Receive-Job $job
```

#### Issue: "Incomplete hardware detection" or "Missing system information"

**Symptoms:**

- Hardware profile incomplete
- Missing CPU/memory information
- Graphics card not detected

**Solutions:**

```powershell
# Check WMI service
Get-Service Winmgmt
Restart-Service Winmgmt

# Run as administrator
Start-Process PowerShell -Verb RunAs -ArgumentList "-Command", "Get-DotWinSystemProfile"

# Check specific hardware components
Get-CimInstance Win32_Processor
Get-CimInstance Win32_PhysicalMemory
Get-CimInstance Win32_VideoController

# Use alternative detection methods
Get-ComputerInfo
systeminfo.exe
```

### Recommendation Engine Issues

#### Issue: "No recommendations generated" or "Recommendation errors"

**Symptoms:**

- Empty recommendation list
- Recommendation engine failures
- ML model not available

**Solutions:**

```powershell
# Check system profile completeness
$profile = Get-DotWinSystemProfile
$profile.Hardware.GetHardwareCategory()
$profile.Software.GetUserType()

# Generate recommendations with debug info
$recommendations = Get-DotWinRecommendations -SystemProfile $profile -Verbose

# Check recommendation engine
[DotWinRecommendationEngine] -as [type]

# Use rule-based recommendations only
$recommendations = Get-DotWinRecommendations -UseRulesOnly

# Check for ML model files
Test-Path "$PSScriptRoot\models\recommendation-model.json"
```

## Network and Connectivity Issues

### Internet Connectivity Problems

#### Issue: "Cannot download packages" or "Network timeouts"

**Symptoms:**

- Package downloads fail
- Repository access timeouts
- SSL/TLS errors

**Solutions:**

```powershell
# Test basic connectivity
Test-NetConnection google.com -Port 443

# Test package repository connectivity
Test-NetConnection winget.azureedge.net -Port 443
Test-NetConnection community.chocolatey.org -Port 443
Test-NetConnection github.com -Port 443

# Check proxy settings
netsh winhttp show proxy
Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"

# Configure proxy for package managers
winget settings --proxy "http://proxy:8080"
choco config set proxy "http://proxy:8080"

# Bypass SSL issues (temporary)
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
```

#### Issue: "Firewall blocking connections" or "Corporate network restrictions"

**Symptoms:**

- Downloads blocked by firewall
- Corporate proxy issues
- Certificate validation errors

**Solutions:**

```powershell
# Check Windows Firewall
Get-NetFirewallProfile
Get-NetFirewallRule -DisplayName "*winget*"

# Add firewall exceptions
New-NetFirewallRule -DisplayName "DotWin Package Downloads" -Direction Outbound -Action Allow -Protocol TCP -RemotePort 443

# Configure for corporate environments
winget settings --network-timeout 300
choco config set commandExecutionTimeoutSeconds 300

# Trust corporate certificates
Import-Certificate -FilePath "corporate-cert.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

## Performance Issues

### Memory and Resource Problems

#### Issue: "High memory usage" or "System slowdown"

**Symptoms:**

- DotWin consuming excessive memory
- System becomes unresponsive
- Long operation times

**Solutions:**

```powershell
# Monitor DotWin memory usage
Get-Process PowerShell | Select-Object ProcessName, WorkingSet, CPU

# Use memory-efficient operations
$profile = Get-DotWinSystemProfile -IncludeHardware:$false  # Reduce profiling scope
Install-Packages -PackageList @("Git.Git") -Parallel:$false  # Disable parallel processing

# Clear caches regularly
Clear-DotWinCache
Clear-DotWinProfileCache
Clear-DotWinPackageCache

# Restart PowerShell session
Remove-Module DotWin -Force
Import-Module DotWin
```

#### Issue: "Slow configuration application" or "Operations timing out"

**Symptoms:**

- Configuration application takes too long
- Operations appear to hang
- Timeout errors

**Solutions:**

```powershell
# Use parallel processing where available
Install-Packages -Category "Development" -Parallel

# Apply configurations in smaller batches
$packages = Get-DevelopmentPackages
$packages.Essential | ForEach-Object { Install-Packages -PackageList @($_) }

# Increase timeout values
$PSDefaultParameterValues['*-DotWin*:TimeoutSeconds'] = 600

# Monitor progress
Install-Packages -Category "Development" -Verbose
```

## Logging and Debugging

### Enable Debug Logging

```powershell
# Enable verbose logging
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

# Run operations with detailed logging
Get-DotWinSystemProfile -Verbose -Debug
Install-Packages -Category "Development" -Verbose -Debug

# View DotWin logs
Get-DotWinLog -Level Debug -Last 100

# Export logs for analysis
Export-DotWinLog -OutputPath "dotwin-debug.log" -IncludeDebug
```

### Debug Information Collection

```powershell
# Collect comprehensive debug information
Export-DotWinDebugInfo -OutputPath "debug-info.zip"

# Manual debug information
$debugInfo = @{
    PowerShellVersion = $PSVersionTable
    ModuleVersion = (Get-Module DotWin).Version
    SystemInfo = Get-ComputerInfo
    EnvironmentTest = Test-DotWinEnvironment
    SystemStatus = Get-DotWinSystemStatus
    InstalledPackages = Get-InstalledPackages
    ErrorLog = $Error | Select-Object -First 10
}

$debugInfo | ConvertTo-Json -Depth 5 | Out-File "debug-info.json"
```

## Error Code Reference

### Common Error Codes

| Error Code | Description | Solution |
|------------|-------------|----------|
| **DW001** | Module not found | Reinstall DotWin module |
| **DW002** | Configuration file invalid | Validate JSON syntax |
| **DW003** | Package manager not available | Install required package manager |
| **DW004** | Insufficient privileges | Run as administrator |
| **DW005** | Network connectivity issue | Check internet connection |
| **DW006** | System profiling failed | Check WMI/CIM services |
| **DW007** | Terminal configuration failed | Verify Windows Terminal installation |
| **DW008** | Rich config function not found | Reload configuration files |
| **DW009** | Class instantiation failed | Check PowerShell version |
| **DW010** | Recommendation engine error | Update system profile |

### Error Handling Examples

```powershell
# Catch and handle specific errors
try {
    Install-Packages -Category "Development"
} catch [DotWinPackageManagerException] {
    Write-Warning "Package manager issue: $($_.Exception.Message)"
    # Fallback to manual installation
} catch [DotWinNetworkException] {
    Write-Warning "Network issue: $($_.Exception.Message)"
    # Retry with different settings
} catch {
    Write-Error "Unexpected error: $($_.Exception.Message)"
    Export-DotWinDebugInfo -OutputPath "error-debug.zip"
}
```

## Getting Help

### Community Support

- **GitHub Issues**: [https://github.com/dotwin/dotwin/issues](https://github.com/dotwin/dotwin/issues)
- **Discussions**: [https://github.com/dotwin/dotwin/discussions](https://github.com/dotwin/dotwin/discussions)
- **Documentation**: [https://dotwin.github.io/docs](https://dotwin.github.io/docs)

### Reporting Issues

When reporting issues, include:

1. **System Information**:

   ```powershell
   Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, TotalPhysicalMemory
   $PSVersionTable
   ```

2. **DotWin Information**:

   ```powershell
   Get-Module DotWin | Select-Object Name, Version, Path
   Test-DotWinEnvironment
   ```

3. **Error Details**:

   ```powershell
   $Error[0] | Format-List * -Force
   Export-DotWinDebugInfo -OutputPath "issue-debug.zip"
   ```

4. **Reproduction Steps**: Clear steps to reproduce the issue

5. **Expected vs Actual Behavior**: What you expected vs what happened

### Emergency Recovery

If DotWin causes system issues:

```powershell
# Remove DotWin module
Remove-Module DotWin -Force
Uninstall-Module DotWin

# Reset Windows Terminal settings
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path "$settingsPath.backup") {
    Copy-Item "$settingsPath.backup" $settingsPath
}

# Reset PowerShell profile
if (Test-Path "$PROFILE.backup") {
    Copy-Item "$PROFILE.backup" $PROFILE
}

# Clear all DotWin data
Remove-Item "$env:APPDATA\DotWin" -Recurse -Force -ErrorAction SilentlyContinue
```

---

This troubleshooting guide covers the most common issues with DotWin. If you encounter problems not covered here, please check the GitHub issues or create a new issue with detailed information about your problem.
