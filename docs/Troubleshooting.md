# DotWin Troubleshooting Guide

## Overview

This guide provides solutions to common issues encountered when using DotWin. It covers installation problems, configuration errors, performance issues, and general troubleshooting techniques.

## Quick Diagnostics

### System Health Check

Run these commands to quickly assess your DotWin environment:

```powershell
# Check DotWin environment
Test-DotWinEnvironment

# Verify module status
Get-DotWinStatus -IncludeSystemInfo -IncludeModuleInfo

# Test system profiling
Get-DotWinSystemProfile -IncludeHardware:$false -IncludeSoftware:$false -IncludeUser:$false
```

### Enable Verbose Logging

For detailed troubleshooting information:

```powershell
# Enable verbose output
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

# Run commands with detailed logging
Get-DotWinSystemProfile -Verbose
Get-DotWinRecommendations -Verbose
```

## Common Issues and Solutions

### Installation Issues

#### Issue: Module Import Fails

**Symptoms:**

- Error: "Import-Module: The specified module 'DotWin' was not loaded"
- PowerShell cannot find the module

**Solutions:**

1. **Check Module Path**

   ```powershell
   # Verify module location
   Get-Module -ListAvailable -Name DotWin
   
   # If not found, check current directory
   Test-Path ".\DotWin.psd1"
   
   # Import with full path
   Import-Module "C:\Path\To\DotWin\DotWin.psd1" -Force
   ```

2. **Check Execution Policy**

   ```powershell
   # Check current policy
   Get-ExecutionPolicy
   
   # Set appropriate policy
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Unblock Downloaded Files**

   ```powershell
   # Unblock all DotWin files
   Get-ChildItem -Path ".\DotWin" -Recurse | Unblock-File
   ```

#### Issue: Permission Denied Errors

**Symptoms:**

- Access denied when running DotWin functions
- Registry or system modification failures

**Solutions:**

1. **Run as Administrator**

   ```powershell
   # Check if running as admin
   $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
   $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
   Write-Host "Running as Administrator: $isAdmin"
   
   # If false, restart PowerShell as Administrator
   ```

2. **Check User Account Control (UAC)**

   ```powershell
   # Check UAC status
   Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA
   
   # UAC should be enabled (value = 1) for security
   ```

### Profiling Issues

#### Issue: System Profiling Incomplete or Fails

**Symptoms:**

- Missing hardware information
- Empty software inventory
- Profiling takes too long or hangs

**Solutions:**

1. **Force Complete Re-profiling**

   ```powershell
   # Clear any cached data and force new profile
   $profile = Get-DotWinSystemProfile -Force -IncludeHardware -IncludeSoftware -IncludeUser
   
   # Check profile completeness
   if ($profile.LastProfiled -and $profile.Hardware.CPU_Manufacturer) {
       Write-Host "Profile generated successfully" -ForegroundColor Green
   } else {
       Write-Host "Profile incomplete" -ForegroundColor Red
   }
   ```

2. **Check WMI/CIM Functionality**

   ```powershell
   # Test WMI connectivity
   try {
       $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
       Write-Host "WMI working: $($cpu.Name)" -ForegroundColor Green
   } catch {
       Write-Host "WMI Error: $($_.Exception.Message)" -ForegroundColor Red
       
       # Try alternative approach
       $cpu = Get-WmiObject -Class Win32_Processor
   }
   ```

3. **Sequential vs Parallel Processing**

   ```powershell
   # If parallel processing fails, try sequential
   if ($PSVersionTable.PSVersion.Major -ge 7) {
       # Try parallel first
       try {
           $profile = Get-DotWinSystemProfile -UseParallel
       } catch {
           Write-Warning "Parallel processing failed, trying sequential"
           $profile = Get-DotWinSystemProfile
       }
   } else {
       $profile = Get-DotWinSystemProfile
   }
   ```

#### Issue: Package Manager Detection Fails

**Symptoms:**

- Winget, Chocolatey, or Scoop not detected
- Package inventory empty

**Solutions:**

1. **Verify Package Manager Installation**

   ```powershell
   # Test Winget
   try {
       $wingetVersion = & winget --version
       Write-Host "Winget version: $wingetVersion" -ForegroundColor Green
   } catch {
       Write-Host "Winget not found or not working" -ForegroundColor Red
   }
   
   # Test Chocolatey
   try {
       $chocoVersion = & choco --version
       Write-Host "Chocolatey version: $chocoVersion" -ForegroundColor Green
   } catch {
       Write-Host "Chocolatey not found" -ForegroundColor Red
   }
   ```

2. **Fix PATH Environment Variable**

   ```powershell
   # Check if package managers are in PATH
   $env:PATH -split ';' | Where-Object { $_ -like "*winget*" -or $_ -like "*chocolatey*" }
   
   # Refresh environment variables
   $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
   ```

### Recommendation Engine Issues

#### Issue: No Recommendations Generated

**Symptoms:**

- Empty recommendation list
- All recommendations filtered out

**Solutions:**

1. **Check System Profile Quality**

   ```powershell
   $profile = Get-DotWinSystemProfile
   
   # Verify profile has data
   Write-Host "Hardware profiled: $($null -ne $profile.Hardware.CPU_Manufacturer)"
   Write-Host "Software profiled: $($profile.Software.InstalledPackages.Count -gt 0)"
   Write-Host "User profiled: $(-not [string]::IsNullOrEmpty($profile.User.Username))"
   ```

2. **Lower Recommendation Filters**

   ```powershell
   # Try with broader filters
   $recommendations = Get-DotWinRecommendations -SystemProfile $profile -Priority "High","Medium","Low" -MaxRecommendations 50
   
   # Check if any recommendations exist before filtering
   $engine = [DotWinRecommendationEngine]::new($profile)
   $allRecs = $engine.GenerateRecommendations()
   Write-Host "Total recommendations before filtering: $($allRecs.Count)"
   ```

3. **Include Conflicting Recommendations**

   ```powershell
   # Include conflicts to see all possible recommendations
   $recommendations = Get-DotWinRecommendations -SystemProfile $profile -IncludeConflicts
   ```

#### Issue: Recommendations Not Relevant

**Symptoms:**

- Recommendations don't match system configuration
- Suggestions for wrong hardware/software

**Solutions:**

1. **Update System Profile**

   ```powershell
   # Force fresh profiling
   $profile = Get-DotWinSystemProfile -Force
   
   # Verify profile accuracy
   Write-Host "Detected hardware category: $($profile.Hardware.GetHardwareCategory())"
   Write-Host "Detected user type: $($profile.Software.GetUserType())"
   Write-Host "Technical level: $($profile.User.GetTechnicalLevel())"
   ```

2. **Filter by Category**

   ```powershell
   # Get category-specific recommendations
   $hardwareRecs = Get-DotWinRecommendations -SystemProfile $profile -Category "Hardware"
   $softwareRecs = Get-DotWinRecommendations -SystemProfile $profile -Category "Software"
   ```

### Configuration Application Issues

#### Issue: Configuration Application Fails

**Symptoms:**

- Errors during configuration application
- Partial configuration applied
- System left in inconsistent state

**Solutions:**

1. **Use WhatIf Mode First**

   ```powershell
   # Preview changes before applying
   Invoke-DotWinProfiledConfiguration -ConfigurationPath ".\config.json" -WhatIf
   
   # Check for potential issues
   Test-DotWinConfiguration -ConfigurationPath ".\config.json"
   ```

2. **Enable Backup and Rollback**

   ```powershell
   # Apply with safety measures
   Invoke-DotWinProfiledConfiguration -ConfigurationPath ".\config.json" -BackupConfiguration -RollbackOnFailure
   ```

3. **Apply Incrementally**

   ```powershell
   # Apply one item at a time for troubleshooting
   $config = Get-Content ".\config.json" | ConvertFrom-Json
   foreach ($item in $config.items) {
       try {
           Write-Host "Applying: $($item.name)" -ForegroundColor Yellow
           # Apply individual item
       } catch {
           Write-Host "Failed: $($item.name) - $($_.Exception.Message)" -ForegroundColor Red
       }
   }
   ```

### Performance Issues

#### Issue: Slow Performance

**Symptoms:**

- Long execution times
- System becomes unresponsive
- High CPU/memory usage

**Solutions:**

1. **Use PowerShell 7+ with Parallel Processing**

   ```powershell
   # Check PowerShell version
   $PSVersionTable.PSVersion
   
   # If PowerShell 7+, use parallel processing
   if ($PSVersionTable.PSVersion.Major -ge 7) {
       $profile = Get-DotWinSystemProfile -UseParallel
   }
   ```

2. **Selective Profiling**

   ```powershell
   # Profile only what you need
   $profile = Get-DotWinSystemProfile -IncludeHardware -IncludeSoftware:$false -IncludeUser:$false
   ```

3. **Limit Recommendation Count**

   ```powershell
   # Reduce processing load
   $recommendations = Get-DotWinRecommendations -MaxRecommendations 10
   ```

#### Issue: Memory Usage High

**Symptoms:**

- PowerShell process using excessive memory
- System running out of memory

**Solutions:**

1. **Process in Batches**

   ```powershell
   # Clear variables between operations
   Remove-Variable -Name profile -ErrorAction SilentlyContinue
   [System.GC]::Collect()
   
   # Process in smaller chunks
   $profile = Get-DotWinSystemProfile
   $recommendations = Get-DotWinRecommendations -SystemProfile $profile -MaxRecommendations 5
   ```

2. **Export and Import Profiles**

   ```powershell
   # Export profile to reduce memory usage
   $profile = Get-DotWinSystemProfile -ExportPath ".\profile.json"
   Remove-Variable -Name profile
   
   # Import when needed
   $profileData = Get-Content ".\profile.json" | ConvertFrom-Json
   ```

### Network and Connectivity Issues

#### Issue: Package Downloads Fail

**Symptoms:**

- Winget/Chocolatey downloads timeout
- Network connectivity errors

**Solutions:**

1. **Check Internet Connectivity**

   ```powershell
   # Test basic connectivity
   Test-NetConnection -ComputerName "google.com" -Port 80
   
   # Test package manager endpoints
   Test-NetConnection -ComputerName "winget.azureedge.net" -Port 443
   ```

2. **Configure Proxy Settings**

   ```powershell
   # Set proxy for current session
   $proxy = "http://proxy.company.com:8080"
   [System.Net.WebRequest]::DefaultWebProxy = New-Object System.Net.WebProxy($proxy)
   
   # Configure Winget proxy
   winget settings --proxy $proxy
   ```

3. **Use Alternative Sources**

   ```powershell
   # Try different package sources
   Install-SystemTools -Source Chocolatey  # Instead of Winget
   ```

## Advanced Troubleshooting

### Debug Mode

Enable comprehensive debugging:

```powershell
# Enable all debug output
$VerbosePreference = "Continue"
$DebugPreference = "Continue"
$InformationPreference = "Continue"

# Create debug log file
Start-Transcript -Path ".\debug.log"

# Run problematic command
Get-DotWinSystemProfile -Verbose

# Stop logging
Stop-Transcript
```

### Registry Debugging

Check for registry-related issues:

```powershell
# Test registry access
try {
    $testKey = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion" -Name "ProgramFilesDir"
    Write-Host "Registry access working" -ForegroundColor Green
} catch {
    Write-Host "Registry access failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Check for corrupted registry
sfc /scannow
```

### WMI/CIM Troubleshooting

Fix WMI-related issues:

```powershell
# Test WMI service
Get-Service -Name "Winmgmt" | Select-Object Name, Status

# Restart WMI service (as Administrator)
Restart-Service -Name "Winmgmt" -Force

# Rebuild WMI repository (if severely corrupted)
# winmgmt /resetrepository
```

### Event Log Analysis

Check Windows Event Logs for errors:

```powershell
# Check for PowerShell errors
Get-WinEvent -LogName "Windows PowerShell" -MaxEvents 50 | Where-Object { $_.LevelDisplayName -eq "Error" }

# Check for system errors
Get-WinEvent -LogName "System" -MaxEvents 50 | Where-Object { $_.LevelDisplayName -eq "Error" }
```

## Frequently Asked Questions (FAQ)

### Q: Why is system profiling taking so long?

**A:** System profiling can be slow due to:

- Large number of installed applications
- Slow WMI queries on older systems
- Network timeouts when checking package managers

**Solutions:**

- Use PowerShell 7+ with `-UseParallel`
- Use selective profiling flags
- Check for WMI issues

### Q: Why are my recommendations not being applied?

**A:** Common reasons include:

- Insufficient privileges
- Package manager not available
- Network connectivity issues
- Conflicting software already installed

**Solutions:**

- Run as Administrator
- Check package manager installation
- Use `-WhatIf` to preview changes
- Review verbose logs

### Q: Can I run DotWin on Windows 10?

**A:** Yes, DotWin supports Windows 10 version 1903+ with PowerShell 5.1+. However, some features work better on Windows 11 and PowerShell 7+.

### Q: How do I create custom configuration templates?

**A:** See the examples in `examples/configurations/` directory. You can create JSON files following the same structure and use them with `Invoke-DotWinConfiguration`.

### Q: Is it safe to run DotWin on production systems?

**A:** Yes, with proper precautions:

- Always use `-WhatIf` first
- Enable `-BackupConfiguration`
- Test on non-production systems first
- Review recommendations before applying

### Q: How do I uninstall or rollback DotWin changes?

**A:** DotWin doesn't modify core system files, but you can:

- Use system restore points
- Restore from backups created with `-BackupConfiguration`
- Manually reverse specific changes
- Use Windows System File Checker: `sfc /scannow`

## Getting Help

### Documentation Resources

- [Getting Started Guide](GettingStarted.md)
- [System Profiling Documentation](SystemProfiling.md)
- [API Reference](APIReference.md)
- Built-in help: `Get-Help <FunctionName> -Full`

### Community Support

- GitHub Issues: Report bugs and request features
- Discussions: Ask questions and share experiences
- Wiki: Community-contributed documentation

### Enterprise Support

For enterprise customers:

- Dedicated support channels
- Priority issue resolution
- Custom configuration assistance
- Training and consultation services

## Reporting Issues

When reporting issues, please include:

1. **System Information**

   ```powershell
   Get-DotWinStatus -IncludeSystemInfo
   $PSVersionTable
   ```

2. **Error Details**
   - Full error message
   - Stack trace if available
   - Steps to reproduce

3. **Environment Details**
   - Windows version
   - PowerShell version
   - DotWin version
   - Network configuration (if relevant)

4. **Log Files**
   - Verbose output
   - Debug logs
   - Windows Event Logs (if relevant)

This information helps us diagnose and resolve issues quickly.
