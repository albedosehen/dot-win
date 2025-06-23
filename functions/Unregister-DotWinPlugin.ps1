function Unregister-DotWinPlugin {
    <#
    .SYNOPSIS
        Unregisters a DotWin plugin from the plugin manager.

    .DESCRIPTION
        The Unregister-DotWinPlugin function removes a plugin from the DotWin plugin
        manager registry. If the plugin is currently loaded, it will be unloaded first.
        This function provides safe removal with validation to prevent breaking dependencies.

    .PARAMETER Name
        Name of the plugin to unregister.

    .PARAMETER Force
        Force unregistration even if the plugin is in use by other plugins.

    .EXAMPLE
        Unregister-DotWinPlugin -Name "MyCustomPlugin"

        Unregisters the specified plugin from the DotWin system.

    .EXAMPLE
        Unregister-DotWinPlugin -Name "MyCustomPlugin" -Force

        Forcefully unregisters the plugin even if it's required by other plugins.

    .EXAMPLE
        Get-DotWinPlugin -Name "OldPlugin" | Unregister-DotWinPlugin

        Unregisters a plugin using pipeline input.

    .OUTPUTS
        None

    .NOTES
        - Unregistering a plugin that other plugins depend on may cause issues
        - The plugin will be unloaded first if it's currently active
        - Use -Force parameter to override dependency checks
        - This operation cannot be undone without re-registering the plugin
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-DotWinLog "Starting plugin unregistration for: $Name" -Level Information

        if (-not $script:DotWinPluginManager) {
            throw "Plugin manager is not initialized"
        }
    }

    process {
        try {
            if (-not $script:DotWinPluginManager.PluginRegistry.ContainsKey($Name)) {
                Write-Warning "Plugin '$Name' is not registered"
                return
            }

            if ($PSCmdlet.ShouldProcess($Name, "Unregister Plugin")) {
                # Check if plugin is loaded and unload it first
                if ($script:DotWinPluginManager.LoadedPlugins.ContainsKey($Name)) {
                    Write-DotWinLog "Unloading plugin before unregistration: $Name" -Level Information
                    $unloadResult = $script:DotWinPluginManager.UnloadPlugin($Name)
                    
                    if (-not $unloadResult -and -not $Force) {
                        throw "Failed to unload plugin '$Name'. Use -Force to override."
                    }
                }

                # Check for dependencies
                if (-not $Force) {
                    $dependentPlugins = @()
                    foreach ($pluginName in $script:DotWinPluginManager.PluginRegistry.Keys) {
                        $plugin = $script:DotWinPluginManager.PluginRegistry[$pluginName]
                        if ($Name -in $plugin.Dependencies) {
                            $dependentPlugins += $pluginName
                        }
                    }

                    if ($dependentPlugins.Count -gt 0) {
                        throw "Cannot unregister plugin '$Name' because it is required by: $($dependentPlugins -join ', '). Use -Force to override."
                    }
                }

                # Remove from registry
                $script:DotWinPluginManager.PluginRegistry.Remove($Name)
                Write-DotWinLog "Plugin '$Name' unregistered successfully" -Level Information
            }

        } catch {
            Write-DotWinLog "Error unregistering plugin '$Name': $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        Write-DotWinLog "Plugin unregistration completed for: $Name" -Level Information
    }
}