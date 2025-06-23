<#
.SYNOPSIS
    Example DotWin Configuration Plugin

.DESCRIPTION
    This is an example configuration plugin that demonstrates how to create
    custom configuration handlers for DotWin. This plugin handles custom
    application installations and registry modifications.

.NOTES
    Plugin Name: ExampleConfigurationPlugin
    Version: 1.0.0
    Author: DotWin Team
    Category: Configuration
#>

# Example Configuration Plugin Class
class ExampleConfigurationPlugin : DotWinConfigurationPlugin {
    
    ExampleConfigurationPlugin() : base("ExampleConfigurationPlugin", "1.0.0") {
        $this.Author = "DotWin Team"
        $this.Description = "Example plugin demonstrating custom configuration handling"
        $this.Category = "Configuration"
        
        # Register supported configuration types
        $this.RegisterHandler("CustomApplication", {
            param([DotWinConfigurationItem]$Item)
            return $this.HandleCustomApplication($Item)
        })
        
        $this.RegisterHandler("RegistryModification", {
            param([DotWinConfigurationItem]$Item)
            return $this.HandleRegistryModification($Item)
        })
        
        $this.RegisterHandler("ServiceConfiguration", {
            param([DotWinConfigurationItem]$Item)
            return $this.HandleServiceConfiguration($Item)
        })
    }
    
    # Initialize the plugin
    [bool] Initialize() {
        try {
            Write-Verbose "Initializing ExampleConfigurationPlugin..."
            
            # Perform any initialization tasks
            $this.Metadata["InitializedAt"] = Get-Date
            $this.Metadata["SupportedTypes"] = $this.SupportedTypes
            
            Write-Verbose "ExampleConfigurationPlugin initialized successfully"
            return $true
        } catch {
            Write-Error "Failed to initialize ExampleConfigurationPlugin: $($_.Exception.Message)"
            return $false
        }
    }
    
    # Cleanup the plugin
    [void] Cleanup() {
        Write-Verbose "Cleaning up ExampleConfigurationPlugin..."
        # Perform any cleanup tasks
        $this.Metadata["CleanedUpAt"] = Get-Date
    }
    
    # Get plugin capabilities
    [hashtable] GetCapabilities() {
        return @{
            SupportedTypes = $this.SupportedTypes
            Features = @(
                "Custom application installation",
                "Registry modification",
                "Service configuration"
            )
            RequiredPrivileges = @("Administrator")
            SupportedPlatforms = @("Windows")
            ConfigurationValidation = $true
            RollbackSupport = $true
        }
    }
    
    # Validate environment
    [bool] ValidateEnvironment() {
        # Check if running on Windows
        if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)) {
            Write-Warning "ExampleConfigurationPlugin requires Windows"
            return $false
        }
        
        # Check PowerShell version
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            Write-Warning "ExampleConfigurationPlugin requires PowerShell 5.1 or higher"
            return $false
        }
        
        return $true
    }
    
    # Handle custom application configuration
    [DotWinExecutionResult] HandleCustomApplication([DotWinConfigurationItem]$Item) {
        $result = [DotWinExecutionResult]::new()
        $result.ItemName = $Item.Name
        $result.ItemType = $Item.Type
        $startTime = Get-Date
        
        try {
            Write-Verbose "Processing custom application: $($Item.Name)"
            
            # Extract configuration properties
            $appName = $Item.Properties["ApplicationName"]
            $downloadUrl = $Item.Properties["DownloadUrl"]
            $installArgs = $Item.Properties["InstallArguments"]
            $validationCommand = $Item.Properties["ValidationCommand"]
            
            if (-not $appName) {
                throw "ApplicationName property is required"
            }
            
            # Check if application is already installed
            if ($validationCommand) {
                try {
                    $validationResult = Invoke-Expression $validationCommand
                    if ($validationResult) {
                        $result.Success = $true
                        $result.Message = "Application '$appName' is already installed"
                        return $result
                    }
                } catch {
                    # Validation failed, proceed with installation
                }
            }
            
            # Download and install application
            if ($downloadUrl) {
                $tempFile = Join-Path $env:TEMP "$appName-installer.exe"
                
                Write-Verbose "Downloading $appName from $downloadUrl"
                Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
                
                Write-Verbose "Installing $appName"
                $installProcess = Start-Process -FilePath $tempFile -ArgumentList $installArgs -Wait -PassThru
                
                if ($installProcess.ExitCode -eq 0) {
                    $result.Success = $true
                    $result.Message = "Successfully installed $appName"
                    $result.Changes["Installed"] = $appName
                } else {
                    throw "Installation failed with exit code: $($installProcess.ExitCode)"
                }
                
                # Cleanup
                Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
            } else {
                throw "DownloadUrl property is required for custom application installation"
            }
            
        } catch {
            $result.Success = $false
            $result.Message = "Error processing custom application '$($Item.Name)': $($_.Exception.Message)"
        } finally {
            $result.Duration = (Get-Date) - $startTime
        }
        
        return $result
    }
    
    # Handle registry modification configuration
    [DotWinExecutionResult] HandleRegistryModification([DotWinConfigurationItem]$Item) {
        $result = [DotWinExecutionResult]::new()
        $result.ItemName = $Item.Name
        $result.ItemType = $Item.Type
        $startTime = Get-Date
        
        try {
            Write-Verbose "Processing registry modification: $($Item.Name)"
            
            # Extract configuration properties
            $registryPath = $Item.Properties["Path"]
            $valueName = $Item.Properties["Name"]
            $valueData = $Item.Properties["Value"]
            $valueType = $Item.Properties["Type"]
            
            if (-not $registryPath -or -not $valueName) {
                throw "Path and Name properties are required"
            }
            
            # Ensure registry path exists
            if (-not (Test-Path $registryPath)) {
                New-Item -Path $registryPath -Force | Out-Null
                $result.Changes["CreatedPath"] = $registryPath
            }
            
            # Get current value for comparison
            $currentValue = $null
            try {
                $currentValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
            } catch {
                # Value doesn't exist
            }
            
            # Set the registry value
            Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type $valueType
            
            $result.Success = $true
            $result.Message = "Successfully set registry value '$valueName' at '$registryPath'"
            $result.Changes["RegistryPath"] = $registryPath
            $result.Changes["ValueName"] = $valueName
            $result.Changes["NewValue"] = $valueData
            $result.Changes["PreviousValue"] = $currentValue
            
        } catch {
            $result.Success = $false
            $result.Message = "Error processing registry modification '$($Item.Name)': $($_.Exception.Message)"
        } finally {
            $result.Duration = (Get-Date) - $startTime
        }
        
        return $result
    }
    
    # Handle service configuration
    [DotWinExecutionResult] HandleServiceConfiguration([DotWinConfigurationItem]$Item) {
        $result = [DotWinExecutionResult]::new()
        $result.ItemName = $Item.Name
        $result.ItemType = $Item.Type
        $startTime = Get-Date
        
        try {
            Write-Verbose "Processing service configuration: $($Item.Name)"
            
            # Extract configuration properties
            $serviceName = $Item.Properties["ServiceName"]
            $startupType = $Item.Properties["StartupType"]
            $serviceState = $Item.Properties["State"]
            
            if (-not $serviceName) {
                throw "ServiceName property is required"
            }
            
            # Check if service exists
            $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
            if (-not $service) {
                throw "Service '$serviceName' not found"
            }
            
            $changes = @{}
            
            # Configure startup type
            if ($startupType) {
                $currentStartupType = (Get-WmiObject -Class Win32_Service -Filter "Name='$serviceName'").StartMode
                if ($currentStartupType -ne $startupType) {
                    Set-Service -Name $serviceName -StartupType $startupType
                    $changes["StartupType"] = @{
                        Previous = $currentStartupType
                        New = $startupType
                    }
                }
            }
            
            # Configure service state
            if ($serviceState) {
                $currentState = $service.Status
                if ($serviceState -eq "Running" -and $currentState -ne "Running") {
                    Start-Service -Name $serviceName
                    $changes["State"] = @{
                        Previous = $currentState
                        New = "Running"
                    }
                } elseif ($serviceState -eq "Stopped" -and $currentState -ne "Stopped") {
                    Stop-Service -Name $serviceName
                    $changes["State"] = @{
                        Previous = $currentState
                        New = "Stopped"
                    }
                }
            }
            
            $result.Success = $true
            $result.Message = "Successfully configured service '$serviceName'"
            $result.Changes = $changes
            
        } catch {
            $result.Success = $false
            $result.Message = "Error processing service configuration '$($Item.Name)': $($_.Exception.Message)"
        } finally {
            $result.Duration = (Get-Date) - $startTime
        }
        
        return $result
    }
}

# Plugin registration helper function
function Register-ExampleConfigurationPlugin {
    <#
    .SYNOPSIS
        Registers the Example Configuration Plugin with DotWin.
    
    .DESCRIPTION
        This function creates and registers an instance of the ExampleConfigurationPlugin
        with the DotWin plugin manager.
    
    .EXAMPLE
        Register-ExampleConfigurationPlugin
        
        Registers the example plugin.
    #>
    
    try {
        $plugin = [ExampleConfigurationPlugin]::new()
        Register-DotWinPlugin -Plugin $plugin
        Write-Host "ExampleConfigurationPlugin registered successfully" -ForegroundColor Green
    } catch {
        Write-Error "Failed to register ExampleConfigurationPlugin: $($_.Exception.Message)"
    }
}

# Auto-register if this script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Register-ExampleConfigurationPlugin
}