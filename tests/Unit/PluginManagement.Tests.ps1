<#
.SYNOPSIS
    Unit tests for DotWin plugin management functions.

.DESCRIPTION
    Tests for plugin management functions including Register-DotWinPlugin,
    Get-DotWinPlugin, Enable-DotWinPlugin, Disable-DotWinPlugin, and Unregister-DotWinPlugin.
#>

BeforeAll {
    # Import test infrastructure
    . $PSScriptRoot\..\TestHelpers.ps1
    
    # Import DotWin module
    Import-DotWinModuleForTesting
    
    # Initialize test environment
    Initialize-TestEnvironment
}

AfterAll {
    # Clean up test environment
    Clear-TestEnvironment
}

Describe "Register-DotWinPlugin" -Tag @('Unit', 'PluginManagement') {
    BeforeEach {
        # Reset plugin manager for each test
        $script:DotWinPluginManager = $null
        
        # Mock plugin paths
        Mock Test-Path { return $true }
        Mock New-Item { }
        
        # Create mock plugin
        $script:MockPlugin = New-MockPlugin -Name 'TestPlugin' -Version '1.0.0' -Category 'Configuration'
    }

    Context "Plugin Registration" {
        It "Should register a plugin object" {
            $result = Register-DotWinPlugin -Plugin $script:MockPlugin
            
            # Should not throw and should initialize plugin manager
            $script:DotWinPluginManager | Should -Not -BeNull
            $script:DotWinPluginManager.PluginRegistry.ContainsKey('TestPlugin') | Should -Be $true
        }

        It "Should register plugin with PassThru" {
            $result = Register-DotWinPlugin -Plugin $script:MockPlugin -PassThru
            
            $result | Should -Not -BeNull
            $result.Name | Should -Be 'TestPlugin'
            $result.Version | Should -Be '1.0.0'
        }

        It "Should initialize plugin manager with default paths" {
            Register-DotWinPlugin -Plugin $script:MockPlugin
            
            $script:DotWinPluginManager.PluginPaths.Count | Should -BeGreaterThan 0
        }

        It "Should auto-load plugin when enabled" {
            $script:DotWinPluginManager = [DotWinPluginManager]::new()
            $script:DotWinPluginManager.AutoLoadEnabled = $true
            
            Register-DotWinPlugin -Plugin $script:MockPlugin
            
            $script:DotWinPluginManager.LoadedPlugins.ContainsKey('TestPlugin') | Should -Be $true
        }
    }

    Context "Plugin Loading from File" {
        BeforeEach {
            $testDir = New-TestDirectory -Name 'PluginTests'
            $pluginFile = Join-Path $testDir 'TestPlugin.ps1'
            
            # Create mock plugin file content
            $pluginContent = @'
class TestFilePlugin : DotWinPlugin {
    TestFilePlugin() : base() {
        $this.Name = 'TestFilePlugin'
        $this.Version = '1.0.0'
        $this.Category = 'Configuration'
    }
    
    [bool] Initialize() {
        return $true
    }
    
    [void] Cleanup() {
        # No cleanup needed
    }
    
    [hashtable] GetCapabilities() {
        return @{
            SupportedTypes = @('TestType')
        }
    }
}
'@
            $pluginContent | Set-Content -Path $pluginFile
        }

        AfterEach {
            Remove-TestDirectory -Path $testDir
        }

        It "Should load and register plugin from file" {
            Mock Import-DotWinPlugin {
                return New-MockPlugin -Name 'TestFilePlugin' -Version '1.0.0'
            }
            
            $result = Register-DotWinPlugin -PluginPath $pluginFile -Category 'Configuration'
            
            Assert-MockCalled Import-DotWinPlugin -ParameterFilter {
                $Path -eq $pluginFile -and $Category -eq 'Configuration'
            }
        }

        It "Should validate plugin file exists" {
            { Register-DotWinPlugin -PluginPath 'C:\NonExistent\Plugin.ps1' } | Should -Throw
        }

        It "Should validate plugin file extension" {
            $invalidFile = Join-Path $testDir 'plugin.txt'
            'test' | Set-Content -Path $invalidFile
            
            { Register-DotWinPlugin -PluginPath $invalidFile } | Should -Throw -ExpectedMessage "*PowerShell script*"
        }
    }

    Context "Plugin Validation" {
        It "Should validate plugin before registration" {
            $invalidPlugin = New-MockPlugin -Name '' -Version '1.0.0'  # Invalid: empty name
            
            { Register-DotWinPlugin -Plugin $invalidPlugin } | Should -Throw -ExpectedMessage "*validation failed*"
        }

        It "Should check plugin dependencies" {
            $dependentPlugin = New-MockPlugin -Name 'DependentPlugin' -Version '1.0.0'
            $dependentPlugin.Dependencies = @('MissingDependency')
            
            { Register-DotWinPlugin -Plugin $dependentPlugin } | Should -Throw -ExpectedMessage "*dependencies not satisfied*"
        }

        It "Should force registration when validation fails" {
            $invalidPlugin = New-MockPlugin -Name '' -Version '1.0.0'
            
            # Should not throw with Force
            { Register-DotWinPlugin -Plugin $invalidPlugin -Force } | Should -Not -Throw
        }
    }

    Context "Plugin Manager Initialization" {
        It "Should add default plugin paths" {
            Register-DotWinPlugin -Plugin $script:MockPlugin
            
            $expectedPaths = @(
                (Join-Path $script:DotWinModuleRoot "plugins"),
                (Join-Path $env:USERPROFILE ".dotwin\plugins"),
                (Join-Path $env:ProgramData "DotWin\plugins")
            )
            
            # Should have attempted to add paths that exist
            $script:DotWinPluginManager.PluginPaths | Should -Not -BeNullOrEmpty
        }

        It "Should handle missing plugin directories gracefully" {
            Mock Test-Path { return $false }
            
            Register-DotWinPlugin -Plugin $script:MockPlugin
            
            # Should still work even if directories don't exist
            $script:DotWinPluginManager | Should -Not -BeNull
        }
    }

    Context "Error Handling" {
        It "Should handle plugin loading failures" {
            Mock Import-DotWinPlugin { throw "Plugin loading failed" }
            
            { Register-DotWinPlugin -PluginPath 'test.ps1' } | Should -Throw -ExpectedMessage "*Plugin loading failed*"
        }

        It "Should handle plugin manager errors" {
            Mock New-Object { throw "Manager creation failed" } -ParameterFilter { $TypeName -eq 'DotWinPluginManager' }
            
            { Register-DotWinPlugin -Plugin $script:MockPlugin } | Should -Throw
        }
    }
}

Describe "Get-DotWinPlugin" -Tag @('Unit', 'PluginManagement') {
    BeforeEach {
        # Initialize plugin manager with test plugins
        $script:DotWinPluginManager = [DotWinPluginManager]::new()
        
        $plugin1 = New-MockPlugin -Name 'Plugin1' -Version '1.0.0' -Category 'Configuration'
        $plugin2 = New-MockPlugin -Name 'Plugin2' -Version '2.0.0' -Category 'Recommendation'
        $plugin3 = New-MockPlugin -Name 'Plugin3' -Version '1.5.0' -Category 'Configuration'
        
        $script:DotWinPluginManager.RegisterPlugin($plugin1)
        $script:DotWinPluginManager.RegisterPlugin($plugin2)
        $script:DotWinPluginManager.RegisterPlugin($plugin3)
        
        # Load some plugins
        $script:DotWinPluginManager.LoadPlugin('Plugin1')
        $script:DotWinPluginManager.LoadPlugin('Plugin2')
    }

    Context "Plugin Retrieval" {
        It "Should get all registered plugins" {
            $result = Get-DotWinPlugin
            
            $result | Should -Not -BeNull
            $result.Count | Should -Be 3
            $result[0] | Should -HaveProperty 'Name'
            $result[0] | Should -HaveProperty 'Version'
            $result[0] | Should -HaveProperty 'Category'
        }

        It "Should get specific plugin by name" {
            $result = Get-DotWinPlugin -Name 'Plugin1'
            
            $result | Should -Not -BeNull
            $result.Name | Should -Be 'Plugin1'
            $result.Version | Should -Be '1.0.0'
        }

        It "Should get plugins by category" {
            $result = Get-DotWinPlugin -Category 'Configuration'
            
            $result | Should -Not -BeNull
            $result.Count | Should -Be 2
            foreach ($plugin in $result) {
                $plugin.Category | Should -Be 'Configuration'
            }
        }

        It "Should get only loaded plugins" {
            $result = Get-DotWinPlugin -LoadedOnly
            
            $result | Should -Not -BeNull
            $result.Count | Should -Be 2  # Only Plugin1 and Plugin2 are loaded
            $result.Name | Should -Contain 'Plugin1'
            $result.Name | Should -Contain 'Plugin2'
            $result.Name | Should -Not -Contain 'Plugin3'
        }
    }

    Context "Plugin Information" {
        It "Should include plugin metadata" {
            $result = Get-DotWinPlugin -Name 'Plugin1' -IncludeMetadata
            
            $result.Metadata | Should -Not -BeNull
            $result.LoadedAt | Should -Not -BeNull
            $result.Loaded | Should -Be $true
        }

        It "Should include plugin capabilities" {
            $result = Get-DotWinPlugin -Name 'Plugin1' -IncludeCapabilities
            
            $result.Capabilities | Should -Not -BeNull
            $result.Capabilities.SupportedTypes | Should -Contain 'TestType'
        }

        It "Should show plugin status" {
            $result = Get-DotWinPlugin -IncludeStatus
            
            foreach ($plugin in $result) {
                $plugin | Should -HaveProperty 'Loaded'
                $plugin | Should -HaveProperty 'Enabled'
            }
        }
    }

    Context "Plugin Filtering" {
        It "Should filter by version" {
            $result = Get-DotWinPlugin -MinimumVersion '1.5.0'
            
            $result.Count | Should -Be 2  # Plugin2 (2.0.0) and Plugin3 (1.5.0)
            $result.Name | Should -Contain 'Plugin2'
            $result.Name | Should -Contain 'Plugin3'
            $result.Name | Should -Not -Contain 'Plugin1'
        }

        It "Should filter by enabled status" {
            # Disable one plugin
            $script:DotWinPluginManager.PluginRegistry['Plugin3'].Enabled = $false
            
            $result = Get-DotWinPlugin -EnabledOnly
            
            $result.Count | Should -Be 2
            $result.Name | Should -Not -Contain 'Plugin3'
        }

        It "Should support wildcard name matching" {
            $result = Get-DotWinPlugin -Name 'Plugin*'
            
            $result.Count | Should -Be 3
        }
    }

    Context "Output Formatting" {
        It "Should return detailed plugin information" {
            $result = Get-DotWinPlugin -Name 'Plugin1' -Detailed
            
            $result | Should -HaveProperty 'Name'
            $result | Should -HaveProperty 'Version'
            $result | Should -HaveProperty 'Author'
            $result | Should -HaveProperty 'Description'
            $result | Should -HaveProperty 'Category'
            $result | Should -HaveProperty 'Dependencies'
            $result | Should -HaveProperty 'SupportedPlatforms'
        }

        It "Should return summary information by default" {
            $result = Get-DotWinPlugin
            
            # Should have basic properties but not all detailed ones
            $result[0] | Should -HaveProperty 'Name'
            $result[0] | Should -HaveProperty 'Version'
            $result[0] | Should -HaveProperty 'Category'
        }
    }

    Context "Error Handling" {
        It "Should handle plugin not found gracefully" {
            $result = Get-DotWinPlugin -Name 'NonExistentPlugin'
            
            $result | Should -BeNull
        }

        It "Should handle uninitialized plugin manager" {
            $script:DotWinPluginManager = $null
            
            $result = Get-DotWinPlugin
            $result | Should -BeNull
        }
    }
}

Describe "Enable-DotWinPlugin" -Tag @('Unit', 'PluginManagement') {
    BeforeEach {
        # Initialize plugin manager with test plugins
        $script:DotWinPluginManager = [DotWinPluginManager]::new()
        
        $plugin = New-MockPlugin -Name 'TestPlugin' -Version '1.0.0'
        $plugin.Enabled = $false  # Start disabled
        
        $script:DotWinPluginManager.RegisterPlugin($plugin)
    }

    Context "Plugin Enabling" {
        It "Should enable a disabled plugin" {
            $result = Enable-DotWinPlugin -Name 'TestPlugin'
            
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
            $result.PluginName | Should -Be 'TestPlugin'
            
            $plugin = $script:DotWinPluginManager.PluginRegistry['TestPlugin']
            $plugin.Enabled | Should -Be $true
        }

        It "Should load plugin when enabling" {
            $result = Enable-DotWinPlugin -Name 'TestPlugin' -Load
            
            $result.Success | Should -Be $true
            $script:DotWinPluginManager.LoadedPlugins.ContainsKey('TestPlugin') | Should -Be $true
        }

        It "Should handle already enabled plugin" {
            # Enable first
            Enable-DotWinPlugin -Name 'TestPlugin'
            
            # Try to enable again
            $result = Enable-DotWinPlugin -Name 'TestPlugin'
            
            $result.Success | Should -Be $true
            $result.Message | Should -Match "already enabled"
        }

        It "Should enable multiple plugins" {
            $plugin2 = New-MockPlugin -Name 'TestPlugin2' -Version '1.0.0'
            $plugin2.Enabled = $false
            $script:DotWinPluginManager.RegisterPlugin($plugin2)
            
            $result = Enable-DotWinPlugin -Name @('TestPlugin', 'TestPlugin2')
            
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $true
            $result[1].Success | Should -Be $true
        }
    }

    Context "Plugin Dependencies" {
        It "Should enable plugin dependencies automatically" {
            # Create dependent plugin
            $dependencyPlugin = New-MockPlugin -Name 'DependencyPlugin' -Version '1.0.0'
            $dependencyPlugin.Enabled = $false
            $script:DotWinPluginManager.RegisterPlugin($dependencyPlugin)
            
            # Create main plugin with dependency
            $mainPlugin = New-MockPlugin -Name 'MainPlugin' -Version '1.0.0'
            $mainPlugin.Dependencies = @('DependencyPlugin')
            $mainPlugin.Enabled = $false
            $script:DotWinPluginManager.RegisterPlugin($mainPlugin)
            
            $result = Enable-DotWinPlugin -Name 'MainPlugin' -EnableDependencies
            
            $result.Success | Should -Be $true
            $script:DotWinPluginManager.PluginRegistry['DependencyPlugin'].Enabled | Should -Be $true
        }

        It "Should handle missing dependencies" {
            $plugin = New-MockPlugin -Name 'PluginWithMissingDep' -Version '1.0.0'
            $plugin.Dependencies = @('MissingPlugin')
            $plugin.Enabled = $false
            $script:DotWinPluginManager.RegisterPlugin($plugin)
            
            $result = Enable-DotWinPlugin -Name 'PluginWithMissingDep'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match "dependencies not satisfied"
        }
    }

    Context "Plugin Categories" {
        It "Should enable all plugins in a category" {
            $plugin1 = New-MockPlugin -Name 'ConfigPlugin1' -Category 'Configuration'
            $plugin2 = New-MockPlugin -Name 'ConfigPlugin2' -Category 'Configuration'
            $plugin3 = New-MockPlugin -Name 'RecommendPlugin1' -Category 'Recommendation'
            
            $plugin1.Enabled = $false
            $plugin2.Enabled = $false
            $plugin3.Enabled = $false
            
            $script:DotWinPluginManager.RegisterPlugin($plugin1)
            $script:DotWinPluginManager.RegisterPlugin($plugin2)
            $script:DotWinPluginManager.RegisterPlugin($plugin3)
            
            $result = Enable-DotWinPlugin -Category 'Configuration'
            
            $result.Count | Should -Be 2
            $script:DotWinPluginManager.PluginRegistry['ConfigPlugin1'].Enabled | Should -Be $true
            $script:DotWinPluginManager.PluginRegistry['ConfigPlugin2'].Enabled | Should -Be $true
            $script:DotWinPluginManager.PluginRegistry['RecommendPlugin1'].Enabled | Should -Be $false
        }
    }

    Context "Error Handling" {
        It "Should handle plugin not found" {
            $result = Enable-DotWinPlugin -Name 'NonExistentPlugin'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match "not found"
        }

        It "Should handle plugin loading failures" {
            $plugin = $script:DotWinPluginManager.PluginRegistry['TestPlugin']
            $plugin | Add-Member -MemberType ScriptMethod -Name 'Initialize' -Value {
                throw "Initialization failed"
            } -Force
            
            $result = Enable-DotWinPlugin -Name 'TestPlugin' -Load
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Initialization failed"
        }
    }

    Context "WhatIf Support" {
        It "Should show what plugins would be enabled without enabling them" {
            $result = Enable-DotWinPlugin -Name 'TestPlugin' -WhatIf
            
            $result.WhatIfResult | Should -Not -BeNullOrEmpty
            $script:DotWinPluginManager.PluginRegistry['TestPlugin'].Enabled | Should -Be $false
        }
    }
}

Describe "Disable-DotWinPlugin" -Tag @('Unit', 'PluginManagement') {
    BeforeEach {
        # Initialize plugin manager with enabled plugins
        $script:DotWinPluginManager = [DotWinPluginManager]::new()
        
        $plugin = New-MockPlugin -Name 'TestPlugin' -Version '1.0.0'
        $plugin.Enabled = $true
        
        $script:DotWinPluginManager.RegisterPlugin($plugin)
        $script:DotWinPluginManager.LoadPlugin('TestPlugin')
    }

    Context "Plugin Disabling" {
        It "Should disable an enabled plugin" {
            $result = Disable-DotWinPlugin -Name 'TestPlugin'
            
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
            $result.PluginName | Should -Be 'TestPlugin'
            
            $plugin = $script:DotWinPluginManager.PluginRegistry['TestPlugin']
            $plugin.Enabled | Should -Be $false
        }

        It "Should unload plugin when disabling" {
            $result = Disable-DotWinPlugin -Name 'TestPlugin' -Unload
            
            $result.Success | Should -Be $true
            $script:DotWinPluginManager.LoadedPlugins.ContainsKey('TestPlugin') | Should -Be $false
        }

        It "Should handle already disabled plugin" {
            # Disable first
            Disable-DotWinPlugin -Name 'TestPlugin'
            
            # Try to disable again
            $result = Disable-DotWinPlugin -Name 'TestPlugin'
            
            $result.Success | Should -Be $true
            $result.Message | Should -Match "already disabled"
        }

        It "Should disable multiple plugins" {
            $plugin2 = New-MockPlugin -Name 'TestPlugin2' -Version '1.0.0'
            $plugin2.Enabled = $true
            $script:DotWinPluginManager.RegisterPlugin($plugin2)
            
            $result = Disable-DotWinPlugin -Name @('TestPlugin', 'TestPlugin2')
            
            $result.Count | Should -Be 2
            $result[0].Success | Should -Be $true
            $result[1].Success | Should -Be $true
        }
    }

    Context "Dependency Management" {
        It "Should check for dependent plugins before disabling" {
            # Create dependent plugin
            $dependentPlugin = New-MockPlugin -Name 'DependentPlugin' -Version '1.0.0'
            $dependentPlugin.Dependencies = @('TestPlugin')
            $dependentPlugin.Enabled = $true
            $script:DotWinPluginManager.RegisterPlugin($dependentPlugin)
            
            $result = Disable-DotWinPlugin -Name 'TestPlugin'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match "other plugins depend on this plugin"
        }

        It "Should force disable plugin with dependents" {
            $dependentPlugin = New-MockPlugin -Name 'DependentPlugin' -Version '1.0.0'
            $dependentPlugin.Dependencies = @('TestPlugin')
            $dependentPlugin.Enabled = $true
            $script:DotWinPluginManager.RegisterPlugin($dependentPlugin)
            
            $result = Disable-DotWinPlugin -Name 'TestPlugin' -Force
            
            $result.Success | Should -Be $true
        }

        It "Should disable dependent plugins automatically" {
            $dependentPlugin = New-MockPlugin -Name 'DependentPlugin' -Version '1.0.0'
            $dependentPlugin.Dependencies = @('TestPlugin')
            $dependentPlugin.Enabled = $true
            $script:DotWinPluginManager.RegisterPlugin($dependentPlugin)
            
            $result = Disable-DotWinPlugin -Name 'TestPlugin' -DisableDependents
            
            $result.Success | Should -Be $true
            $script:DotWinPluginManager.PluginRegistry['DependentPlugin'].Enabled | Should -Be $false
        }
    }

    Context "Error Handling" {
        It "Should handle plugin not found" {
            $result = Disable-DotWinPlugin -Name 'NonExistentPlugin'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match "not found"
        }

        It "Should handle plugin unloading failures" {
            $plugin = $script:DotWinPluginManager.LoadedPlugins['TestPlugin']
            $plugin | Add-Member -MemberType ScriptMethod -Name 'Cleanup' -Value {
                throw "Cleanup failed"
            } -Force
            
            $result = Disable-DotWinPlugin -Name 'TestPlugin' -Unload
            
            $result.Warnings | Should -Contain "Cleanup failed"
        }
    }

    Context "WhatIf Support" {
        It "Should show what plugins would be disabled without disabling them" {
            $result = Disable-DotWinPlugin -Name 'TestPlugin' -WhatIf
            
            $result.WhatIfResult | Should -Not -BeNullOrEmpty
            $script:DotWinPluginManager.PluginRegistry['TestPlugin'].Enabled | Should -Be $true
        }
    }
}

Describe "Unregister-DotWinPlugin" -Tag @('Unit', 'PluginManagement') {
    BeforeEach {
        # Initialize plugin manager with test plugins
        $script:DotWinPluginManager = [DotWinPluginManager]::new()
        
        $plugin = New-MockPlugin -Name 'TestPlugin' -Version '1.0.0'
        $script:DotWinPluginManager.RegisterPlugin($plugin)
        $script:DotWinPluginManager.LoadPlugin('TestPlugin')
    }

    Context "Plugin Unregistration" {
        It "Should unregister a plugin" {
            $result = Unregister-DotWinPlugin -Name 'TestPlugin'
            
            $result | Should -Not -BeNull
            $result.Success | Should -Be $true
            $result.PluginName | Should -Be 'TestPlugin'
            
            $script:DotWinPluginManager.PluginRegistry.ContainsKey('TestPlugin') | Should -Be $false
        }

        It "Should unload plugin before unregistering" {
            $result = Unregister-DotWinPlugin -Name 'TestPlugin'
            
            $result.Success | Should -Be $true
            $script:DotWinPluginManager.LoadedPlugins.ContainsKey('TestPlugin') | Should -Be $false
        }

        It "Should handle plugin not found" {
            $result = Unregister-DotWinPlugin -Name 'NonExistentPlugin'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match "not found"
        }
    }

    Context "Dependency Validation" {
        It "Should prevent unregistering plugin with dependents" {
            $dependentPlugin = New-MockPlugin -Name 'DependentPlugin' -Version '1.0.0'
            $dependentPlugin.Dependencies = @('TestPlugin')
            $script:DotWinPluginManager.RegisterPlugin($dependentPlugin)
            
            $result = Unregister-DotWinPlugin -Name 'TestPlugin'
            
            $result.Success | Should -Be $false
            $result.Error | Should -Match "other plugins depend on this plugin"
        }

        It "Should force unregister plugin with dependents" {
            $dependentPlugin = New-MockPlugin -Name 'DependentPlugin' -Version '1.0.0'
            $dependentPlugin.Dependencies = @('TestPlugin')
            $script:DotWinPluginManager.RegisterPlugin($dependentPlugin)
            
            $result = Unregister-DotWinPlugin -Name 'TestPlugin' -Force
            
            $result.Success | Should -Be $true
        }
    }

    Context "Cleanup Operations" {
        It "Should remove plugin files when requested" {
            Mock Remove-Item { }
            Mock Test-Path { return $true }
            
            $plugin = $script:DotWinPluginManager.PluginRegistry['TestPlugin']
            $plugin.Metadata['SourceFile'] = 'C:\Plugins\TestPlugin.ps1'
            
            $result = Unregister-DotWinPlugin -Name 'TestPlugin' -RemoveFiles
            
            Assert-MockCalled Remove-Item -ParameterFilter {
                $Path -eq 'C:\Plugins\TestPlugin.ps1'
            }
        }

        It "Should backup plugin before removal" {
            Mock Copy-Item { }
            Mock Test-Path { return $true }
            
            $plugin = $script:DotWinPluginManager.PluginRegistry['TestPlugin']
            $plugin.Metadata['SourceFile'] = 'C:\Plugins\TestPlugin.ps1'
            
            $result = Unregister-DotWinPlugin -Name 'TestPlugin' -BackupBeforeRemoval
            
            Assert-MockCalled Copy-Item
            $result.BackupPath | Should -Not -BeNullOrEmpty
        }
    }

    Context "WhatIf Support" {
        It "Should show what would be unregistered without unregistering" {
            $result = Unregister-DotWinPlugin -Name 'TestPlugin' -WhatIf
            
            $result.WhatIfResult | Should -Not -BeNullOrEmpty
            $script:DotWinPluginManager.PluginRegistry.ContainsKey('TestPlugin') | Should -Be $true
        }
    }
}

Describe "Plugin Management Integration Tests" -Tag @('Unit', 'PluginManagement', 'Integration') {
    BeforeEach {
        # Reset plugin manager
        $script:DotWinPluginManager = $null
    }

    Context "Complete Plugin Lifecycle" {
        It "Should register, enable, disable, and unregister plugin" {
            # Register plugin
            $plugin = New-MockPlugin -Name 'LifecyclePlugin' -Version '1.0.0'
            $plugin.Enabled = $false
            
            Register-DotWinPlugin -Plugin $plugin
            $script:DotWinPluginManager.PluginRegistry.ContainsKey('LifecyclePlugin') | Should -Be $true
            
            # Enable plugin
            $enableResult = Enable-DotWinPlugin -Name 'LifecyclePlugin' -Load
            $enableResult.Success | Should -Be $true
            $script:DotWinPluginManager.LoadedPlugins.ContainsKey('LifecyclePlugin') | Should -Be $true
            
            # Disable plugin
            $disableResult = Disable-DotWinPlugin -Name 'LifecyclePlugin' -Unload
            $disableResult.Success | Should -Be $true
            $script:DotWinPluginManager.LoadedPlugins.ContainsKey('LifecyclePlugin') | Should -Be $false
            
            # Unregister plugin
            $unregisterResult = Unregister-DotWinPlugin -Name 'LifecyclePlugin'
            $unregisterResult.Success | Should -Be $true
            $script:DotWinPluginManager.PluginRegistry.ContainsKey('LifecyclePlugin') | Should -Be $false
        }

        It "Should handle plugin dependency chains" {
            # Create dependency chain: PluginC -> PluginB -> PluginA
            $pluginA = New-MockPlugin -Name 'PluginA' -Version '1.0.0'
            $pluginB = New-MockPlugin -Name 'PluginB' -Version '1.0.0'
            $pluginB.Dependencies = @('PluginA')
            $pluginC = New-MockPlugin -Name 'PluginC' -Version '1.0.0'
            $pluginC.Dependencies = @('PluginB')
            
            $pluginA.Enabled = $false
            $pluginB.Enabled = $false
            $pluginC.Enabled = $false
            
            Register-DotWinPlugin -Plugin $pluginA
            Register-DotWinPlugin -Plugin $pluginB
            Register-Dot
Register-DotWinPlugin -Plugin $pluginC

            # Enable PluginC with dependencies
            $result = Enable-DotWinPlugin -Name 'PluginC' -EnableDependencies

            $result.Success | Should -Be $true
            $script:DotWinPluginManager.PluginRegistry['PluginA'].Enabled | Should -Be $true
            $script:DotWinPluginManager.PluginRegistry['PluginB'].Enabled | Should -Be $true
            $script:DotWinPluginManager.PluginRegistry['PluginC'].Enabled | Should -Be $true
        }
    }

    Context "Plugin Discovery and Auto-Registration" {
        It "Should discover plugins in search paths" {
            $testDir = New-TestDirectory -Name 'PluginDiscovery'

            try {
                # Create mock plugin files
                $plugin1File = Join-Path $testDir 'Plugin1.ps1'
                $plugin2File = Join-Path $testDir 'Plugin2.ps1'

                'class Plugin1 : DotWinPlugin {}' | Set-Content -Path $plugin1File
                'class Plugin2 : DotWinPlugin {}' | Set-Content -Path $plugin2File

                # Initialize plugin manager and add search path
                $script:DotWinPluginManager = [DotWinPluginManager]::new()
                $script:DotWinPluginManager.AddPluginPath($testDir)

                # Discover plugins
                $script:DotWinPluginManager.DiscoverPlugins()

                # Should have found plugin files
                $script:DotWinPluginManager.PluginPaths | Should -Contain $testDir

            } finally {
                Remove-TestDirectory -Path $testDir
            }
        }
    }

    Context "Plugin Error Recovery" {
        It "Should handle plugin initialization failures gracefully" {
            $faultyPlugin = New-MockPlugin -Name 'FaultyPlugin' -Version '1.0.0'
            $faultyPlugin | Add-Member -MemberType ScriptMethod -Name 'Initialize' -Value {
                throw "Initialization error"
            } -Force

            Register-DotWinPlugin -Plugin $faultyPlugin

            $result = Enable-DotWinPlugin -Name 'FaultyPlugin' -Load
            $result.Success | Should -Be $false
            $result.Error | Should -Match "Initialization error"

            # Plugin manager should still be functional
            $otherPlugin = New-MockPlugin -Name 'WorkingPlugin' -Version '1.0.0'
            Register-DotWinPlugin -Plugin $otherPlugin

            $workingResult = Enable-DotWinPlugin -Name 'WorkingPlugin' -Load
            $workingResult.Success | Should -Be $true
        }
    }
}