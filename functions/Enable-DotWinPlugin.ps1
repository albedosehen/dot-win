function Enable-DotWinPlugin {
    <#
    .SYNOPSIS
        Enables and loads a registered DotWin plugin.

    .DESCRIPTION
        The Enable-DotWinPlugin function loads a registered plugin, making it
        available for use in configuration processing and recommendation generation.
        The plugin must be registered before it can be enabled. This function validates
        plugin compatibility and dependencies before loading.

    .PARAMETER Name
        Name of the plugin to enable.

    .PARAMETER PassThru
        Return the loaded plugin object.

    .EXAMPLE
        Enable-DotWinPlugin -Name "MyCustomPlugin"

        Enables the specified plugin for use in the DotWin system.

    .EXAMPLE
        $plugin = Enable-DotWinPlugin -Name "MyCustomPlugin" -PassThru

        Enables the plugin and returns the plugin object for further use.

    .EXAMPLE
        Get-DotWinPlugin -AvailableOnly | Enable-DotWinPlugin

        Enables all registered but currently unloaded plugins.

    .OUTPUTS
        DotWinPlugin (if PassThru is specified)

    .NOTES
        - The plugin must be registered before it can be enabled
        - Plugin dependencies will be validated before loading
        - If the plugin is already loaded, this function will return successfully
        - Use Get-DotWinPlugin to check plugin status before enabling
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,

        [Parameter()]
        [switch]$PassThru
    )

    begin {
        Write-DotWinLog "Enabling plugin: $Name" -Level "Information"

        if (-not $script:DotWinPluginManager) {
            throw "Plugin manager is not initialized"
        }
    }

    process {
        try {
            if (-not $script:DotWinPluginManager.PluginRegistry.ContainsKey($Name)) {
                throw "Plugin '$Name' is not registered. Register it first using Register-DotWinPlugin."
            }

            if ($script:DotWinPluginManager.LoadedPlugins.ContainsKey($Name)) {
                Write-DotWinLog "Plugin '$Name' is already loaded" -Level "Information"
                
                if ($PassThru) {
                    return $script:DotWinPluginManager.LoadedPlugins[$Name]
                }
                return
            }

            # Validate plugin before loading
            $plugin = $script:DotWinPluginManager.PluginRegistry[$Name]
            
            Write-DotWinLog "Validating plugin compatibility: $Name" -Level "Information"
            if (-not $script:DotWinPluginManager.ValidatePlugin($plugin)) {
                throw "Plugin validation failed for '$Name'. Plugin may not be compatible with current environment."
            }

            Write-DotWinLog "Checking plugin dependencies: $Name" -Level "Information"
            if (-not $script:DotWinPluginManager.CheckDependencies($plugin)) {
                throw "Plugin dependencies not satisfied for '$Name'. Ensure all required plugins are registered and loaded."
            }

            # Load the plugin
            Write-DotWinLog "Loading plugin: $Name" -Level "Information"
            $loadResult = $script:DotWinPluginManager.LoadPlugin($Name)
            
            if ($loadResult) {
                Write-DotWinLog "Plugin '$Name' enabled successfully" -Level "Information"
                
                if ($PassThru) {
                    return $script:DotWinPluginManager.LoadedPlugins[$Name]
                }
            } else {
                throw "Failed to enable plugin '$Name'. Check plugin initialization logic."
            }

        } catch {
            Write-DotWinLog "Error enabling plugin '$Name': $($_.Exception.Message)" -Level "Error"
            throw
        }
    }

    end {
        Write-DotWinLog "Plugin enabling completed for: $Name" -Level "Information"
    }
}
