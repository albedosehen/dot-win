function Disable-DotWinPlugin {
    <#
    .SYNOPSIS
        Disables and unloads a DotWin plugin.

    .DESCRIPTION
        The Disable-DotWinPlugin function unloads a plugin, making it unavailable
        for use while keeping it registered for future use. This provides a way to
        temporarily deactivate plugins without removing them from the system entirely.

    .PARAMETER Name
        Name of the plugin to disable.

    .PARAMETER Force
        Force disable even if the plugin is required by other loaded plugins.

    .EXAMPLE
        Disable-DotWinPlugin -Name "MyCustomPlugin"

        Disables the specified plugin, making it unavailable for use.

    .EXAMPLE
        Disable-DotWinPlugin -Name "MyCustomPlugin" -Force

        Forcefully disables the plugin even if other loaded plugins depend on it.

    .EXAMPLE
        Get-DotWinPlugin -LoadedOnly | Disable-DotWinPlugin

        Disables all currently loaded plugins.

    .OUTPUTS
        None

    .NOTES
        - Disabling a plugin that other loaded plugins depend on may cause issues
        - The plugin remains registered and can be re-enabled later
        - Use -Force parameter to override dependency checks
        - Plugin cleanup methods will be called during the disable process
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$Name,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-DotWinLog "Disabling plugin: $Name" -Level "Information"

        if (-not $script:DotWinPluginManager) {
            throw "Plugin manager is not initialized"
        }
    }

    process {
        try {
            if (-not $script:DotWinPluginManager.LoadedPlugins.ContainsKey($Name)) {
                Write-Warning "Plugin '$Name' is not currently loaded"
                return
            }

            if ($PSCmdlet.ShouldProcess($Name, "Disable Plugin")) {
                # Check for dependent plugins
                if (-not $Force) {
                    Write-DotWinLog "Checking for dependent plugins: $Name" -Level "Information"
                    $dependentPlugins = @()
                    foreach ($pluginName in $script:DotWinPluginManager.LoadedPlugins.Keys) {
                        $plugin = $script:DotWinPluginManager.LoadedPlugins[$pluginName]
                        if ($Name -in $plugin.Dependencies) {
                            $dependentPlugins += $pluginName
                        }
                    }

                    if ($dependentPlugins.Count -gt 0) {
                        throw "Cannot disable plugin '$Name' because it is required by loaded plugins: $($dependentPlugins -join ', '). Use -Force to override."
                    }
                }

                # Perform graceful cleanup before unloading
                Write-DotWinLog "Performing cleanup for plugin: $Name" -Level "Information"
                $plugin = $script:DotWinPluginManager.LoadedPlugins[$Name]
                
                try {
                    # Call plugin's cleanup method if available
                    if ($plugin -and [bool]($plugin.PSObject.Methods | Where-Object { $_.Name -eq "Cleanup" })) {
                        $plugin.Cleanup()
                        Write-DotWinLog "Plugin cleanup completed for: $Name" -Level "Information"
                    }
                } catch {
                    Write-DotWinLog "Warning: Plugin cleanup failed for '$Name': $($_.Exception.Message)" -Level "Warning"
                    if (-not $Force) {
                        throw "Plugin cleanup failed. Use -Force to override."
                    }
                }

                # Unload the plugin
                Write-DotWinLog "Unloading plugin: $Name" -Level "Information"
                $unloadResult = $script:DotWinPluginManager.UnloadPlugin($Name)
                
                if ($unloadResult) {
                    Write-DotWinLog "Plugin '$Name' disabled successfully" -Level "Information"
                } else {
                    if ($Force) {
                        Write-DotWinLog "Plugin '$Name' forcefully disabled despite unload issues" -Level "Warning"
                    } else {
                        throw "Failed to disable plugin '$Name'. Use -Force to override."
                    }
                }
            }

        } catch {
            Write-DotWinLog "Error disabling plugin '$Name': $($_.Exception.Message)" -Level "Error"
            throw
        }
    }

    end {
        Write-DotWinLog "Plugin disabling completed for: $Name" -Level "Information"
    }
}
