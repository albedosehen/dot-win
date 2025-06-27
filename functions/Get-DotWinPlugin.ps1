function Get-DotWinPlugin {
    <#
    .SYNOPSIS
        Gets information about registered DotWin plugins.

    .DESCRIPTION
        The Get-DotWinPlugin function retrieves information about plugins that are
        registered with the DotWin plugin manager. It can list all plugins or
        filter by specific criteria such as category, loaded status, or name.

    .PARAMETER Name
        Name of a specific plugin to retrieve.

    .PARAMETER Category
        Filter plugins by category (Configuration, Recommendation, Utility).

    .PARAMETER LoadedOnly
        Return only plugins that are currently loaded.

    .PARAMETER AvailableOnly
        Return only plugins that are registered but not loaded.

    .PARAMETER IncludeCapabilities
        Include plugin capabilities in the output.

    .EXAMPLE
        Get-DotWinPlugin

        Lists all registered plugins.

    .EXAMPLE
        Get-DotWinPlugin -Category "Configuration" -LoadedOnly

        Lists all loaded configuration plugins.

    .EXAMPLE
        Get-DotWinPlugin -Name "MyCustomPlugin" -IncludeCapabilities

        Gets detailed information about a specific plugin including its capabilities.

    .OUTPUTS
        PSCustomObject[]
        Returns plugin information objects.

    .NOTES
        This function requires the plugin manager to be initialized.
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Name,

        [Parameter()]
        [ValidateSet('Configuration', 'Recommendation', 'Utility')]
        [string]$Category,

        [Parameter()]
        [switch]$LoadedOnly,

        [Parameter()]
        [switch]$AvailableOnly,

        [Parameter()]
        [switch]$IncludeCapabilities
    )

    begin {
        Write-DotWinLog "Retrieving plugin information" -Level "Information"

        # Initialize plugin manager if not already done
        if (-not $script:DotWinPluginManager) {
            $script:DotWinPluginManager = [DotWinPluginManager]::new()
        }
    }

    process {
        try {
            $plugins = @()

            if ($Name) {
                # Get specific plugin
                if ($script:DotWinPluginManager.PluginRegistry.ContainsKey($Name)) {
                    $pluginInfo = $script:DotWinPluginManager.GetPluginInfo($Name)
                    $plugins += $pluginInfo
                } else {
                    Write-Warning "Plugin '$Name' is not registered"
                    return
                }
            } else {
                # Get all plugins
                foreach ($pluginName in $script:DotWinPluginManager.PluginRegistry.Keys) {
                    $pluginInfo = $script:DotWinPluginManager.GetPluginInfo($pluginName)
                    $plugins += $pluginInfo
                }
            }

            # Apply filters
            if ($Category) {
                $plugins = $plugins | Where-Object { $_.Category -eq $Category }
            }

            if ($LoadedOnly) {
                $plugins = $plugins | Where-Object { $_.Loaded -eq $true }
            }

            if ($AvailableOnly) {
                $plugins = $plugins | Where-Object { $_.Loaded -eq $false }
            }

            # Add capabilities if requested
            if ($IncludeCapabilities) {
                foreach ($plugin in $plugins) {
                    if ($plugin.Loaded) {
                        try {
                            $pluginInstance = $script:DotWinPluginManager.LoadedPlugins[$plugin.Name]
                            $plugin | Add-Member -NotePropertyName "Capabilities" -NotePropertyValue $pluginInstance.GetCapabilities()
                        } catch {
                            $plugin | Add-Member -NotePropertyName "Capabilities" -NotePropertyValue @{ Error = $_.Exception.Message }
                        }
                    } else {
                        $plugin | Add-Member -NotePropertyName "Capabilities" -NotePropertyValue @{ Status = "Plugin not loaded" }
                    }
                }
            }

            return $plugins

        } catch {
            Write-DotWinLog "Error retrieving plugin information: $($_.Exception.Message)" -Level "Error"
            throw
        }
    }
}
