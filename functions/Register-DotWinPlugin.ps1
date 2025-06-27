function Register-DotWinPlugin {
    <#
    .SYNOPSIS
        Registers a DotWin plugin for use in the configuration management system.

    .DESCRIPTION
        The Register-DotWinPlugin function registers a plugin with the DotWin plugin manager,
        making it available for configuration processing and recommendation generation.
        Plugins extend DotWin's functionality by providing custom configuration handlers
        and intelligent recommendations.

    .PARAMETER Plugin
        The plugin object to register. Must inherit from DotWinPlugin base class.

    .PARAMETER PluginPath
        Path to a plugin file (.ps1) to load and register automatically.

    .PARAMETER Category
        Category to assign to the plugin (Configuration, Recommendation, Utility).

    .PARAMETER Force
        Force registration even if plugin validation fails.

    .PARAMETER PassThru
        Return the registered plugin object.

    .EXAMPLE
        Register-DotWinPlugin -Plugin $myPlugin

        Registers a plugin object directly.

    .EXAMPLE
        Register-DotWinPlugin -PluginPath ".\plugins\MyCustomPlugin.ps1" -Category "Configuration"

        Loads and registers a plugin from a file.

    .EXAMPLE
        $plugin = Register-DotWinPlugin -Plugin $myPlugin -PassThru
        
        Registers a plugin and returns the registered object.

    .OUTPUTS
        DotWinPlugin (if PassThru is specified)

    .NOTES
        Plugins must inherit from DotWinPlugin, DotWinConfigurationPlugin, or DotWinRecommendationPlugin.
        The plugin manager validates plugins before registration.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Plugin')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Plugin', ValueFromPipeline = $true)]
        [DotWinPlugin]$Plugin,

        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Plugin file '$_' does not exist."
            }
            if ($_ -notlike "*.ps1") {
                throw "Plugin file must be a PowerShell script (.ps1)."
            }
            return $true
        })]
        [string]$PluginPath,

        [Parameter(ParameterSetName = 'Path')]
        [ValidateSet('Configuration', 'Recommendation', 'Utility')]
        [string]$Category,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Write-DotWinLog "Starting plugin registration" -Level "Information"

        # Initialize plugin manager if not already done
        if (-not $script:DotWinPluginManager) {
            $script:DotWinPluginManager = [DotWinPluginManager]::new()
            
            # Add default plugin paths
            $defaultPluginPaths = @(
                (Join-Path $script:DotWinModuleRoot "plugins"),
                (Join-Path $env:USERPROFILE ".dotwin\plugins"),
                (Join-Path $env:ProgramData "DotWin\plugins")
            )
            
            foreach ($path in $defaultPluginPaths) {
                if (Test-Path $path) {
                    $script:DotWinPluginManager.AddPluginPath($path)
                }
            }
        }
    }

    process {
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Path') {
                Write-DotWinLog "Loading plugin from path: $PluginPath" -Level "Information"
                
                # Load plugin from file
                $Plugin = Import-DotWinPlugin -Path $PluginPath -Category $Category
                
                if (-not $Plugin) {
                    throw "Failed to load plugin from '$PluginPath'"
                }
            }

            # Validate plugin
            if (-not $Force) {
                Write-DotWinLog "Validating plugin: $($Plugin.Name)" -Level "Information"
                
                if (-not $script:DotWinPluginManager.ValidatePlugin($Plugin)) {
                    throw "Plugin validation failed for '$($Plugin.Name)'"
                }
                
                if (-not $script:DotWinPluginManager.CheckDependencies($Plugin)) {
                    throw "Plugin dependencies not satisfied for '$($Plugin.Name)'"
                }
            }

            # Register plugin
            Write-DotWinLog "Registering plugin: $($Plugin.Name) v$($Plugin.Version)" -Level "Information"
            $script:DotWinPluginManager.RegisterPlugin($Plugin)

            # Load plugin if auto-load is enabled
            if ($script:DotWinPluginManager.AutoLoadEnabled) {
                Write-DotWinLog "Auto-loading plugin: $($Plugin.Name)" -Level "Information"
                $loadResult = $script:DotWinPluginManager.LoadPlugin($Plugin.Name)
                
                if ($loadResult) {
                    Write-DotWinLog "Plugin '$($Plugin.Name)' loaded successfully" -Level "Information"
                } else {
                    Write-DotWinLog "Failed to auto-load plugin '$($Plugin.Name)'" -Level "Warning"
                }
            }

            if ($PassThru) {
                return $Plugin
            }

        } catch {
            Write-DotWinLog "Error registering plugin: $($_.Exception.Message)" -Level "Error"
            throw
        }
    }

    end {
        Write-DotWinLog "Plugin registration completed" -Level "Information"
    }
}

function Import-DotWinPlugin {
    <#
    .SYNOPSIS
        Imports a plugin from a PowerShell script file.

    .DESCRIPTION
        Internal function to load and instantiate plugins from PowerShell script files.
        Parses the script to find plugin class definitions and creates instances.

    .PARAMETER Path
        Path to the plugin script file.

    .PARAMETER Category
        Category to assign to the plugin if not specified in the plugin itself.

    .OUTPUTS
        DotWinPlugin
        Returns the loaded plugin instance.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter()]
        [string]$Category
    )

    try {
        Write-Verbose "Importing plugin from: $Path"

        # Read plugin file content
        $content = Get-Content -Path $Path -Raw

        # Create a temporary script block to execute the plugin code
        $scriptBlock = [ScriptBlock]::Create($content)

        # Execute the script block to define classes and functions
        & $scriptBlock

        # Try to find plugin classes in the current session
        # This is a simplified approach - in a full implementation,
        # you would parse the PowerShell AST to find plugin classes
        
        $pluginName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        
        # Look for classes that inherit from DotWinPlugin
        $pluginTypes = @()
        
        # Try common plugin class naming patterns
        $possibleClassNames = @(
            $pluginName,
            "${pluginName}Plugin",
            "DotWin${pluginName}Plugin"
        )
        
        foreach ($className in $possibleClassNames) {
            try {
                $type = $className -as [type]
                if ($type -and $type.BaseType -and 
                    ($type.BaseType.Name -eq 'DotWinPlugin' -or 
                     $type.BaseType.Name -eq 'DotWinConfigurationPlugin' -or 
                     $type.BaseType.Name -eq 'DotWinRecommendationPlugin')) {
                    $pluginTypes += $type
                    break
                }
            } catch {
                # Class not found, continue searching
            }
        }
        
        if ($pluginTypes.Count -eq 0) {
            throw "No valid plugin classes found in '$Path'"
        }
        
        # Create instance of the first found plugin class
        $pluginType = $pluginTypes[0]
        $plugin = $pluginType::new()
        
        # Set default properties if not already set
        if ([string]::IsNullOrEmpty($plugin.Name)) {
            $plugin.Name = $pluginName
        }
        
        if ([string]::IsNullOrEmpty($plugin.Version)) {
            $plugin.Version = "1.0.0"
        }
        
        if ([string]::IsNullOrEmpty($plugin.Category) -and $Category) {
            $plugin.Category = $Category
        }
        
        # Add metadata about the source file
        $plugin.Metadata["SourceFile"] = $Path
        $plugin.Metadata["LoadedAt"] = Get-Date
        
        Write-Verbose "Successfully imported plugin: $($plugin.Name)"
        return $plugin
        
    } catch {
        Write-Error "Error importing plugin from '$Path': $($_.Exception.Message)"
        throw
    }
}
