# Creating DotWin Plugins - Simple Guide

## What Are Plugins?

Plugins let you add new features to DotWin. Think of them like apps for your phone - they extend what DotWin can do.

You can create plugins to:

- Handle new types of configurations
- Add custom recommendations
- Install specific software your way
- Integrate with other tools

## Do I Need to Know Programming?

Yes, you'll need to know PowerShell scripting. But don't worry - this guide will show you simple examples to get started.

## Types of Plugins

### 1. Configuration Plugins

These handle new types of configurations. For example, if you want DotWin to install a specific program in a special way.

### 2. Recommendation Plugins

These suggest new things based on your system. For example, recommending specific tools for your type of work.

## Creating Your First Plugin

Let's create a simple plugin that installs a custom application.

### Step 1: Create the Plugin File

Create a file called `MyFirstPlugin.ps1`:

```powershell
# MyFirstPlugin.ps1

class MyFirstPlugin : DotWinConfigurationPlugin {
    
    # Constructor - runs when plugin is created
    MyFirstPlugin() : base("MyFirstPlugin", "1.0.0") {
        $this.Author = "Your Name"
        $this.Description = "My first DotWin plugin"
        $this.Category = "Configuration"
        
        # Tell DotWin this plugin handles "MyApp" configurations
        $this.RegisterHandler("MyApp", {
            param([DotWinConfigurationItem]$Item)
            return $this.InstallMyApp($Item)
        })
    }
    
    # Required: Initialize the plugin
    [bool] Initialize() {
        Write-Host "MyFirstPlugin is starting up!" -ForegroundColor Green
        return $true
    }
    
    # Required: Cleanup when plugin is removed
    [void] Cleanup() {
        Write-Host "MyFirstPlugin is shutting down!" -ForegroundColor Yellow
    }
    
    # Required: Tell DotWin what this plugin can do
    [hashtable] GetCapabilities() {
        return @{
            SupportedTypes = @("MyApp")
            Features = @("CustomInstallation")
            RequiredPrivileges = @("Administrator")
            SupportedPlatforms = @("Windows")
        }
    }
    
    # Your custom installation logic
    [DotWinExecutionResult] InstallMyApp([DotWinConfigurationItem]$Item) {
        $result = [DotWinExecutionResult]::new()
        $result.ItemName = $Item.Name
        $result.ItemType = $Item.Type
        
        try {
            # Get the app name from configuration
            $appName = $Item.Properties["AppName"]
            $downloadUrl = $Item.Properties["DownloadUrl"]

            # Check if required properties exist
            if (-not $appName) {
                throw "AppName is required"
            }

            Write-Host "Installing $appName..." -ForegroundColor Yellow

            # Your installation logic here
            # For example:
            # - Download the app
            # - Run the installer
            # - Configure settings

            # Simulate installation
            Start-Sleep -Seconds 2

            $result.Success = $true
            $result.Message = "Successfully installed $appName"
            $result.Changes["Installed"] = $appName

        } catch {
            $result.Success = $false
            $result.Message = "Failed to install: $($_.Exception.Message)"
        }
        
        return $result
    }
}

# Auto-register the plugin when file is loaded
function Register-MyFirstPlugin {
    try {
        $plugin = [MyFirstPlugin]::new()
        Register-DotWinPlugin -Plugin $plugin
        Write-Host "MyFirstPlugin registered successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to register MyFirstPlugin: $($_.Exception.Message)"
    }
}

# Register automatically if script is run directly
if ($MyInvocation.InvocationName -ne '.') {
    Register-MyFirstPlugin
}
```

### Step 2: Register Your Plugin

```powershell
# Load and register your plugin
. .\MyFirstPlugin.ps1

# Check if it's registered
Get-DotWinPlugin -Name "MyFirstPlugin"
```

### Step 3: Create a Configuration That Uses Your Plugin

Create a file called `my-app-config.json`:

```json
{
  "name": "My Custom App Setup",
  "version": "1.0.0",
  "items": [
    {
      "name": "Install My Favorite App",
      "type": "MyApp",
      "properties": {
        "AppName": "My Favorite App",
        "DownloadUrl": "https://example.com/myapp.exe"
      }
    }
  ]
}
```

### Step 4: Test Your Plugin

```powershell
# Test the configuration (preview mode)
Invoke-DotWinConfiguration -ConfigurationPath ".\my-app-config.json" -WhatIf

# Apply the configuration
Invoke-DotWinConfiguration -ConfigurationPath ".\my-app-config.json"
```

## Creating a Recommendation Plugin

Here's a simple plugin that makes recommendations:

```powershell
# MyRecommendationPlugin.ps1

class MyRecommendationPlugin : DotWinRecommendationPlugin {
    
    MyRecommendationPlugin() : base("MyRecommendationPlugin", "1.0.0") {
        $this.Author = "Your Name"
        $this.Description = "Custom recommendations"
        $this.Category = "Recommendation"
    }
    
    [bool] Initialize() {
        return $true
    }

    [void] Cleanup() {
        # Cleanup code
    }

    [hashtable] GetCapabilities() {
        return @{
            Categories = @("Software", "Performance")
            Features = @("CustomRecommendations")
        }
    }

    # Generate recommendations based on system profile
    [DotWinRecommendation[]] GenerateRecommendations([DotWinSystemProfiler]$SystemProfile) {
        $recommendations = @()
        
        # Example: Recommend Notepad++ if no advanced text editor found
        $hasAdvancedEditor = $SystemProfile.Software.InstalledPackages |
            Where-Object { $_.Name -like "*Visual Studio Code*" -or $_.Name -like "*Notepad++*" }

        if (-not $hasAdvancedEditor) {
            $rec = [DotWinRecommendation]::new(
                "Install Advanced Text Editor",
                "Consider installing Notepad++ or Visual Studio Code for better text editing",
                "Software"
            )
            $rec.Priority = "Medium"
            $rec.ConfidenceScore = 0.8
            $recommendations += $rec
        }
        
        # Example: Recommend more RAM for systems with less than 8GB
        if ($SystemProfile.Hardware.Memory_TotalGB -lt 8) {
            $rec = [DotWinRecommendation]::new(
                "Consider RAM Upgrade",
                "Your system has $($SystemProfile.Hardware.Memory_TotalGB)GB RAM. Consider upgrading to 8GB or more for better performance",
                "Hardware"
            )
            $rec.Priority = "High"
            $rec.ConfidenceScore = 0.9
            $recommendations += $rec
        }

        return $recommendations
    }
}
```

## Plugin Best Practices

### 1. Always Handle Errors

```powershell
try {
    # Your plugin logic
    $result.Success = $true
    $result.Message = "Success!"
} catch {
    $result.Success = $false
    $result.Message = "Error: $($_.Exception.Message)"
}
```

### 2. Validate Input

```powershell
# Check if required properties exist
if (-not $Item.Properties["RequiredProperty"]) {
    throw "RequiredProperty is missing"
}

# Validate values
if ($Item.Properties["Number"] -lt 0) {
    throw "Number must be positive"
}
```

### 3. Provide Good Feedback

```powershell
Write-Host "Starting installation..." -ForegroundColor Yellow
Write-Host "Download complete!" -ForegroundColor Green
Write-Host "Installation finished!" -ForegroundColor Green
```

### 4. Use Progress for Long Operations

```powershell
Write-Progress -Activity "Installing App" -Status "Downloading..." -PercentComplete 25
# Download logic
Write-Progress -Activity "Installing App" -Status "Installing..." -PercentComplete 75
# Install logic
Write-Progress -Activity "Installing App" -Completed
```

## Testing Your Plugin

### Basic Testing

```powershell
# Test plugin registration
$plugin = [MyFirstPlugin]::new()
$plugin.Initialize() | Should -Be $true

# Test capabilities
$capabilities = $plugin.GetCapabilities()
$capabilities.SupportedTypes | Should -Contain "MyApp"
```

### Integration Testing

```powershell
# Register plugin
Register-DotWinPlugin -Plugin $plugin

# Test with real configuration
$config = Get-Content ".\test-config.json" | ConvertFrom-Json
$results = Invoke-DotWinConfiguration -Configuration $config -WhatIf
```

## Managing Plugins

### List All Plugins

```powershell
Get-DotWinPlugin
```

### Enable/Disable Plugins

```powershell
Enable-DotWinPlugin -Name "MyFirstPlugin"
Disable-DotWinPlugin -Name "MyFirstPlugin"
```

### Remove Plugins

```powershell
Unregister-DotWinPlugin -Name "MyFirstPlugin"
```

## Common Plugin Ideas

### Software Installation Plugin

- Install software from custom sources
- Configure software after installation
- Handle license keys

### System Configuration Plugin

- Modify registry settings
- Configure Windows features
- Set up environment variables

### Development Environment Plugin

- Install development tools
- Configure IDEs
- Set up project templates

### Security Plugin

- Configure firewall rules
- Install security tools
- Set up VPN connections

## Getting Help

### Debug Your Plugin

```powershell
# Enable detailed logging
$VerbosePreference = "Continue"
$DebugPreference = "Continue"

# Test your plugin
Register-DotWinPlugin -Plugin $plugin -Verbose
```

### Common Issues

**Plugin won't load:**

- Check class inheritance
- Verify constructor syntax
- Make sure all required methods exist

**Handler not called:**

- Check handler registration in constructor
- Verify configuration type matches

**Permission errors:**

- Run PowerShell as Administrator
- Check plugin capabilities

## Example Plugins

Look in the `plugins/` folder for complete examples:

- `ExampleConfigurationPlugin.ps1` - Basic configuration plugin
- See how real plugins are structured

## Contributing Your Plugin

Want to share your plugin with others?

1. Test it thoroughly
2. Add documentation
3. Follow the coding style
4. Submit a pull request

## Next Steps

1. Start with the simple examples above
2. Modify them for your needs
3. Test thoroughly
4. Share with the community

Plugin development lets you customize DotWin exactly how you want it. Start simple and build up to more complex functionality as you learn!
