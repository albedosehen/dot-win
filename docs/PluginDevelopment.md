# DotWin Plugin Development Guide

## Overview

DotWin's plugin architecture allows developers to extend the system's functionality by creating custom configuration handlers and recommendation engines. This guide provides comprehensive information on developing, testing, and deploying DotWin plugins.

## Plugin Architecture

### Plugin Types

DotWin supports three main types of plugins:

1. **Configuration Plugins** - Handle custom configuration types
2. **Recommendation Plugins** - Generate intelligent recommendations
3. **Utility Plugins** - Provide additional functionality

### Base Classes

All plugins must inherit from one of these base classes:

- `DotWinPlugin` - Base plugin class
- `DotWinConfigurationPlugin` - For configuration handling plugins
- `DotWinRecommendationPlugin` - For recommendation generation plugins

## Creating a Configuration Plugin

### Basic Structure

```powershell
class MyCustomPlugin : DotWinConfigurationPlugin {
    
    MyCustomPlugin() : base("MyCustomPlugin", "1.0.0") {
        $this.Author = "Your Name"
        $this.Description = "Description of your plugin"
        $this.Category = "Configuration"
        
        # Register configuration type handlers
        $this.RegisterHandler("MyConfigType", {
            param([DotWinConfigurationItem]$Item)
            return $this.HandleMyConfigType($Item)
        })
    }
    
    # Required: Initialize the plugin
    [bool] Initialize() {
        try {
            # Initialization logic here
            return $true
        } catch {
            return $false
        }
    }
    
    # Required: Cleanup when plugin is unloaded
    [void] Cleanup() {
        # Cleanup logic here
    }
    
    # Required: Return plugin capabilities
    [hashtable] GetCapabilities() {
        return @{
            SupportedTypes = $this.SupportedTypes
            Features = @("Feature1", "Feature2")
            RequiredPrivileges = @("Administrator")
            SupportedPlatforms = @("Windows")
        }
    }
    
    # Optional: Validate environment
    [bool] ValidateEnvironment() {
        # Environment validation logic
        return $true
    }
    
    # Custom configuration handler
    [DotWinExecutionResult] HandleMyConfigType([DotWinConfigurationItem]$Item) {
        $result = [DotWinExecutionResult]::new()
        $result.ItemName = $Item.Name
        $result.ItemType = $Item.Type
        
        try {
            # Configuration processing logic here
            $result.Success = $true
            $result.Message = "Configuration applied successfully"
        } catch {
            $result.Success = $false
            $result.Message = $_.Exception.Message
        }
        
        return $result
    }
}
```

### Configuration Handler Implementation

Configuration handlers receive a `DotWinConfigurationItem` and must return a `DotWinExecutionResult`:

```powershell
[DotWinExecutionResult] HandleCustomApplication([DotWinConfigurationItem]$Item) {
    $result = [DotWinExecutionResult]::new()
    $result.ItemName = $Item.Name
    $result.ItemType = $Item.Type
    $startTime = Get-Date
    
    try {
        # Extract properties from the configuration item
        $appName = $Item.Properties["ApplicationName"]
        $downloadUrl = $Item.Properties["DownloadUrl"]
        $installArgs = $Item.Properties["InstallArguments"]
        
        # Validate required properties
        if (-not $appName) {
            throw "ApplicationName property is required"
        }
        
        # Implement your configuration logic
        # ...
        
        $result.Success = $true
        $result.Message = "Successfully processed $appName"
        $result.Changes["Installed"] = $appName
        
    } catch {
        $result.Success = $false
        $result.Message = "Error: $($_.Exception.Message)"
    } finally {
        $result.Duration = (Get-Date) - $startTime
    }
    
    return $result
}
```

## Creating a Recommendation Plugin

### Plugin Structure

```powershell
class MyRecommendationPlugin : DotWinRecommendationPlugin {
    
    MyRecommendationPlugin() : base("MyRecommendationPlugin", "1.0.0") {
        $this.Author = "Your Name"
        $this.Description = "Custom recommendation engine"
        $this.Category = "Recommendation"
        
        # Register recommendation rules
        $this.RegisterRule("Performance", "SSDUpgrade", {
            param([DotWinSystemProfiler]$Profile)
            return $this.CheckSSDUpgrade($Profile)
        })
    }
    
    # Required: Generate recommendations
    [DotWinRecommendation[]] GenerateRecommendations([DotWinSystemProfiler]$SystemProfile) {
        $recommendations = @()
        
        # Apply your recommendation rules
        foreach ($category in $this.RecommendationCategories) {
            foreach ($ruleName in $this.RecommendationRules[$category].Keys) {
                $rule = $this.RecommendationRules[$category][$ruleName]
                $recommendation = & $rule $SystemProfile
                if ($recommendation) {
                    $recommendations += $recommendation
                }
            }
        }
        
        return $recommendations
    }
    
    # Custom recommendation rule
    [DotWinRecommendation] CheckSSDUpgrade([DotWinSystemProfiler]$Profile) {
        if ($Profile.Hardware.Storage_Types -notcontains "SSD") {
            $rec = [DotWinRecommendation]::new(
                "Upgrade to SSD Storage",
                "Consider upgrading to SSD for improved performance",
                "Performance"
            )
            $rec.Priority = "High"
            $rec.ConfidenceScore = 0.9
            return $rec
        }
        return $null
    }
}
```

## Plugin Registration and Management

### Registering a Plugin

```powershell
# Method 1: Register plugin object directly
$plugin = [MyCustomPlugin]::new()
Register-DotWinPlugin -Plugin $plugin

# Method 2: Register from file
Register-DotWinPlugin -PluginPath ".\plugins\MyCustomPlugin.ps1" -Category "Configuration"

# Method 3: Auto-registration in plugin file
function Register-MyCustomPlugin {
    try {
        $plugin = [MyCustomPlugin]::new()
        Register-DotWinPlugin -Plugin $plugin
        Write-Host "MyCustomPlugin registered successfully" -ForegroundColor Green
    } catch {
        Write-Error "Failed to register MyCustomPlugin: $($_.Exception.Message)"
    }
}

# Auto-register if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Register-MyCustomPlugin
}
```

### Managing Plugins

```powershell
# List all plugins
Get-DotWinPlugin

# Get specific plugin information
Get-DotWinPlugin -Name "MyCustomPlugin" -IncludeCapabilities

# Enable/disable plugins
Enable-DotWinPlugin -Name "MyCustomPlugin"
Disable-DotWinPlugin -Name "MyCustomPlugin"

# Unregister plugin
Unregister-DotWinPlugin -Name "MyCustomPlugin"
```

## Plugin Development Best Practices

### Error Handling

Always implement comprehensive error handling:

```powershell
[DotWinExecutionResult] HandleConfiguration([DotWinConfigurationItem]$Item) {
    $result = [DotWinExecutionResult]::new()
    $result.ItemName = $Item.Name
    $result.ItemType = $Item.Type
    
    try {
        # Validate input
        if (-not $Item.Properties["RequiredProperty"]) {
            throw "RequiredProperty is missing"
        }
        
        # Process configuration
        # ...
        
        $result.Success = $true
        $result.Message = "Configuration applied successfully"
        
    } catch [System.UnauthorizedAccessException] {
        $result.Success = $false
        $result.Message = "Access denied. Administrator privileges required."
    } catch [System.IO.FileNotFoundException] {
        $result.Success = $false
        $result.Message = "Required file not found: $($_.Exception.Message)"
    } catch {
        $result.Success = $false
        $result.Message = "Unexpected error: $($_.Exception.Message)"
    }
    
    return $result
}
```

### Logging and Debugging

Use the DotWin logging system:

```powershell
# Use Write-DotWinLog for consistent logging
Write-DotWinLog "Processing configuration item: $($Item.Name)" -Level Information
Write-DotWinLog "Warning: Optional property missing" -Level Warning
Write-DotWinLog "Error occurred: $($_.Exception.Message)" -Level Error

# Use Write-Verbose for debug information
Write-Verbose "Detailed processing information"
```

### Configuration Validation

Implement thorough validation:

```powershell
[bool] ValidateConfiguration([DotWinConfigurationItem]$Item) {
    # Check required properties
    $requiredProperties = @("ApplicationName", "DownloadUrl")
    foreach ($prop in $requiredProperties) {
        if (-not $Item.Properties.ContainsKey($prop)) {
            Write-Error "Required property '$prop' is missing"
            return $false
        }
    }
    
    # Validate property values
    if ($Item.Properties["DownloadUrl"] -notmatch "^https?://") {
        Write-Error "DownloadUrl must be a valid HTTP/HTTPS URL"
        return $false
    }
    
    return $true
}
```

### Performance Considerations

- Use async operations where possible (PowerShell 7+)
- Implement caching for expensive operations
- Provide progress feedback for long-running operations

```powershell
# Example with progress reporting
$totalSteps = 5
$currentStep = 0

Write-Progress -Activity "Installing Application" -Status "Downloading..." -PercentComplete (++$currentStep / $totalSteps * 100)
# Download logic

Write-Progress -Activity "Installing Application" -Status "Installing..." -PercentComplete (++$currentStep / $totalSteps * 100)
# Install logic

Write-Progress -Activity "Installing Application" -Completed
```

## Testing Plugins

### Unit Testing

Create comprehensive tests for your plugins:

```powershell
# Test-MyCustomPlugin.ps1
Describe "MyCustomPlugin Tests" {
    BeforeAll {
        # Setup test environment
        $plugin = [MyCustomPlugin]::new()
    }
    
    Context "Plugin Initialization" {
        It "Should initialize successfully" {
            $result = $plugin.Initialize()
            $result | Should -Be $true
        }
        
        It "Should have correct capabilities" {
            $capabilities = $plugin.GetCapabilities()
            $capabilities.SupportedTypes | Should -Contain "MyConfigType"
        }
    }
    
    Context "Configuration Handling" {
        It "Should handle valid configuration" {
            $item = [DotWinConfigurationItem]::new("TestItem", "MyConfigType")
            $item.Properties["RequiredProperty"] = "TestValue"
            
            $result = $plugin.ProcessConfiguration($item)
            $result.Success | Should -Be $true
        }
        
        It "Should fail with invalid configuration" {
            $item = [DotWinConfigurationItem]::new("TestItem", "MyConfigType")
            # Missing required property
            
            $result = $plugin.ProcessConfiguration($item)
            $result.Success | Should -Be $false
        }
    }
}
```

### Integration Testing

Test plugins with the full DotWin system:

```powershell
# Register plugin
Register-DotWinPlugin -Plugin $plugin

# Create test configuration
$config = [DotWinConfiguration]::new("TestConfig")
$item = [DotWinConfigurationItem]::new("TestItem", "MyConfigType")
$item.Properties["RequiredProperty"] = "TestValue"
$config.AddItem($item)

# Test configuration application
$results = Invoke-DotWinConfiguration -Configuration $config -WhatIf
```

## Plugin Packaging and Distribution

### Plugin Structure (Cont.)

Organize your plugin files:

```text
MyCustomPlugin/
├── MyCustomPlugin.ps1          # Main plugin file
├── MyCustomPlugin.psd1         # Plugin manifest (optional)
├── README.md                   # Documentation
├── Tests/
│   └── Test-MyCustomPlugin.ps1 # Unit tests
└── Examples/
    └── example-config.json     # Example configurations
```

### Plugin Manifest

Create a plugin manifest for metadata:

```powershell
# MyCustomPlugin.psd1
@{
    PluginName = 'MyCustomPlugin'
    Version = '1.0.0'
    Author = 'Your Name'
    Description = 'Custom configuration plugin for DotWin'
    Category = 'Configuration'
    
    # Dependencies
    RequiredModules = @()
    RequiredPlugins = @()
    
    # Compatibility
    PowerShellVersion = '5.1'
    SupportedPlatforms = @('Windows')
    
    # Files
    RootModule = 'MyCustomPlugin.ps1'
    FileList = @(
        'MyCustomPlugin.ps1',
        'README.md'
    )
    
    # Metadata
    Tags = @('DotWin', 'Configuration', 'Plugin')
    ProjectUri = 'https://github.com/yourname/MyCustomPlugin'
    LicenseUri = 'https://github.com/yourname/MyCustomPlugin/blob/main/LICENSE'
}
```

## Advanced Plugin Features

### Plugin Dependencies

Specify dependencies in your plugin:

```powershell
MyCustomPlugin() : base("MyCustomPlugin", "1.0.0") {
    $this.Dependencies = @("BaseUtilityPlugin", "NetworkPlugin")
    # ...
}
```

### Plugin Communication

Plugins can communicate through the plugin manager:

```powershell
# Get another plugin
$utilityPlugin = $script:DotWinPluginManager.LoadedPlugins["UtilityPlugin"]

# Call plugin methods
$result = $utilityPlugin.SomeUtilityMethod($data)
```

### Validation Configuration

Implement configuration validation:

```powershell
[bool] ValidateConfiguration([DotWinConfigurationItem]$Item) {
    # Implement validation logic
    return $true
}

# Use in handler
[DotWinExecutionResult] HandleConfiguration([DotWinConfigurationItem]$Item) {
    if (-not $this.ValidateConfiguration($Item)) {
        $result = [DotWinExecutionResult]::new()
        $result.Success = $false
        $result.Message = "Configuration validation failed"
        return $result
    }
    
    # Process configuration
    # ...
}
```

### Rollback Support

Implement rollback functionality:

```powershell
[DotWinExecutionResult] HandleConfiguration([DotWinConfigurationItem]$Item) {
    $result = [DotWinExecutionResult]::new()
    $rollbackData = @{}
    
    try {
        # Store current state for rollback
        $rollbackData["PreviousValue"] = Get-CurrentValue()
        
        # Apply configuration
        Set-NewValue($Item.Properties["Value"])
        
        # Store rollback information
        $result.Changes["RollbackData"] = $rollbackData
        $result.Success = $true
        
    } catch {
        # Attempt rollback
        if ($rollbackData["PreviousValue"]) {
            Set-CurrentValue($rollbackData["PreviousValue"])
        }
        
        $result.Success = $false
        $result.Message = $_.Exception.Message
    }
    
    return $result
}
```

## Plugin Security

### Security Best Practices

1. **Validate all inputs** - Never trust configuration data
2. **Use least privilege** - Request only necessary permissions
3. **Sanitize file paths** - Prevent directory traversal attacks
4. **Validate URLs** - Ensure safe download sources
5. **Use secure communication** - HTTPS for downloads

### Input Validation Example

```powershell
[bool] ValidateInput([hashtable]$Properties) {
    # Validate file paths
    if ($Properties.ContainsKey("FilePath")) {
        $path = $Properties["FilePath"]
        if ($path -match '\.\.' -or $path -match '[<>:"|?*]') {
            Write-Error "Invalid file path: $path"
            return $false
        }
    }
    
    # Validate URLs
    if ($Properties.ContainsKey("DownloadUrl")) {
        $url = $Properties["DownloadUrl"]
        if ($url -notmatch '^https://') {
            Write-Error "Only HTTPS URLs are allowed: $url"
            return $false
        }
    }
    
    return $true
}
```

## Troubleshooting Plugin Development

### Common Issues

1. **Plugin not loading** - Check class inheritance and naming
2. **Handler not called** - Verify handler registration
3. **Permission errors** - Ensure adequate privileges
4. **Dependency issues** - Check plugin dependencies

### Debug Techniques

```powershell
# Enable verbose logging
$VerbosePreference = "Continue"

# Add debug output
Write-Debug "Plugin state: $($this | ConvertTo-Json -Depth 2)"

# Use try-catch with detailed error info
try {
    # Plugin logic
} catch {
    Write-Error "Plugin error in $($MyInvocation.MyCommand.Name): $($_.Exception.Message)"
    Write-Debug "Stack trace: $($_.ScriptStackTrace)"
    throw
}
```

## Plugin Examples

See the `plugins/` directory for complete plugin examples:

- `ExampleConfigurationPlugin.ps1` - Configuration handling example
- `ExampleRecommendationPlugin.ps1` - Recommendation generation example

## Contributing Plugins

To contribute plugins to the DotWin project:

1. Follow the coding standards and best practices
2. Include comprehensive tests
3. Provide documentation and examples
4. Submit a pull request with your plugin

## Support

For plugin development support:

- Review existing plugins for examples
- Check the troubleshooting guide
- Submit issues on GitHub
- Join the community discussions

The DotWin plugin architecture provides powerful extensibility while maintaining system security and reliability. Follow this guide to create robust, efficient plugins that enhance the DotWin ecosystem.
