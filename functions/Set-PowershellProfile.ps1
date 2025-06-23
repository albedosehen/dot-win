function Set-PowershellProfile {
    <#
    .SYNOPSIS
        Configures PowerShell profiles with DotWin configuration management.

    .DESCRIPTION
        The Set-PowershellProfile function provides comprehensive PowerShell profile
        configuration, including module installation, aliases, functions, and
        customizations while integrating with the DotWin configuration management system.

    .PARAMETER ProfileType
        The type of PowerShell profile to configure (CurrentUser, AllUsers, CurrentHost, AllHosts).

    .PARAMETER ConfigurationPath
        Path to a configuration file containing profile settings.

    .PARAMETER IncludeModules
        Install and import specified PowerShell modules.

    .PARAMETER IncludeAliases
        Configure custom aliases in the profile.

    .PARAMETER IncludeFunctions
        Add custom functions to the profile.

    .PARAMETER IncludePrompt
        Configure a custom PowerShell prompt.

    .PARAMETER WhatIf
        Shows what profile changes would be made without actually making them.

    .PARAMETER Force
        Forces profile configuration even if profile already exists.

    .PARAMETER BackupExisting
        Creates a backup of existing profile before making changes.

    .EXAMPLE
        Set-PowershellProfile -ProfileType 'CurrentUser' -IncludeModules -IncludePrompt
        
        Configures the current user PowerShell profile with modules and custom prompt.

    .EXAMPLE
        Set-PowershellProfile -ConfigurationPath 'C:\Config\PowerShellProfile.json' -BackupExisting
        
        Applies profile configuration from file with backup of existing profile.

    .EXAMPLE
        Set-PowershellProfile -ProfileType 'AllUsers' -IncludeModules -IncludeAliases -WhatIf
        
        Shows what would happen when configuring all users profile.

    .OUTPUTS
        DotWinExecutionResult[]
        Returns an array of execution results for each profile configuration operation.

    .NOTES
        This function may require administrator privileges for AllUsers profiles.
        Some modules may require internet connectivity for installation.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'ProfileType')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ProfileType', Position = 0)]
        [ValidateSet('CurrentUser', 'AllUsers', 'CurrentHost', 'AllHosts')]
        [string]$ProfileType,

        [Parameter(ParameterSetName = 'ConfigFile')]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Configuration file '$_' does not exist."
            }
            return $true
        })]
        [string]$ConfigurationPath,

        [Parameter()]
        [switch]$IncludeModules,

        [Parameter()]
        [switch]$IncludeAliases,

        [Parameter()]
        [switch]$IncludeFunctions,

        [Parameter()]
        [switch]$IncludePrompt,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [switch]$BackupExisting
    )

    begin {
        Write-DotWinLog "Starting PowerShell profile configuration" -Level Information
        
        # Validate environment
        $envTest = Test-DotWinEnvironment
        if (-not $envTest.IsValid) {
            throw "Environment validation failed: $($envTest.Issues -join ', ')"
        }

        $results = @()
        $startTime = Get-Date
    }

    process {
        try {
            # Determine profile configuration based on parameter set
            $profileConfig = @{}

            switch ($PSCmdlet.ParameterSetName) {
                'ProfileType' {
                    Write-DotWinLog "Loading profile configuration for type: $ProfileType" -Level Information
                    $profileConfig = Get-PowerShellProfileConfiguration -ProfileType $ProfileType -IncludeModules:$IncludeModules -IncludeAliases:$IncludeAliases -IncludeFunctions:$IncludeFunctions -IncludePrompt:$IncludePrompt
                }
                
                'ConfigFile' {
                    Write-DotWinLog "Loading profile configuration from file: $ConfigurationPath" -Level Information
                    $configContent = Get-Content -Path $ConfigurationPath -Raw | ConvertFrom-Json
                    $profileConfig = $configContent
                    $ProfileType = if ($profileConfig.ProfileType) { $profileConfig.ProfileType } else { 'CurrentUser' }
                }
            }

            # Get profile path
            $profilePath = Get-PowerShellProfilePath -ProfileType $ProfileType
            Write-DotWinLog "Profile path: $profilePath" -Level Information

            # Create profile configuration item
            $profileItem = [DotWinPowerShellProfile]::new($ProfileType)
            $profileItem.ProfilePath = $profilePath
            $profileItem.Configuration = $profileConfig
            $profileItem.BackupExisting = $BackupExisting

            # Process profile configuration
            $profileStartTime = Get-Date
            $result = [DotWinExecutionResult]::new()
            $result.ItemName = "PowerShell Profile ($ProfileType)"
            $result.ItemType = "PowerShellProfile"

            try {
                # Test if profile needs configuration
                $needsConfiguration = -not $profileItem.Test() -or $Force
                
                if (-not $needsConfiguration) {
                    $result.Success = $true
                    $result.Message = "PowerShell profile already configured"
                    Write-DotWinLog "PowerShell profile already configured" -Level Information
                } else {
                    # Configure the profile
                    if ($PSCmdlet.ShouldProcess($ProfileType, "Configure PowerShell profile")) {
                        Write-DotWinLog "Configuring PowerShell profile: $ProfileType" -Level Information
                        
                        # Get current state for comparison
                        $beforeState = $profileItem.GetCurrentState()
                        
                        # Apply the configuration
                        $profileItem.Apply()
                        
                        # Get new state and record changes
                        $afterState = $profileItem.GetCurrentState()
                        $result.Changes = @{
                            Before = $beforeState
                            After = $afterState
                        }
                        
                        $result.Success = $true
                        $result.Message = "PowerShell profile configured successfully"
                        Write-DotWinLog "Successfully configured PowerShell profile: $ProfileType" -Level Information
                    } else {
                        $result.Success = $true
                        $result.Message = "PowerShell profile configuration skipped (WhatIf)"
                        Write-DotWinLog "PowerShell profile configuration skipped: $ProfileType (WhatIf)" -Level Information
                    }
                }
                
            } catch {
                $result.Success = $false
                $result.Message = "Error configuring PowerShell profile: $($_.Exception.Message)"
                Write-DotWinLog "Error configuring PowerShell profile '$ProfileType': $($_.Exception.Message)" -Level Error
            } finally {
                $result.Duration = (Get-Date) - $profileStartTime
                $results += $result
            }

        } catch {
            Write-DotWinLog "Critical error during PowerShell profile configuration: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        $totalDuration = (Get-Date) - $startTime
        $successCount = ($results | Where-Object { $_.Success }).Count
        $failureCount = ($results | Where-Object { -not $_.Success }).Count
        
        Write-DotWinLog "PowerShell profile configuration completed" -Level Information
        Write-DotWinLog "Total profiles processed: $($results.Count)" -Level Information
        Write-DotWinLog "Successful: $successCount, Failed: $failureCount" -Level Information
        Write-DotWinLog "Total duration: $($totalDuration.TotalSeconds) seconds" -Level Information
        
        return $results
    }
}


function Get-PowerShellProfilePath {
    <#
    .SYNOPSIS
        Gets the path for a specific PowerShell profile type.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileType
    )
    
    switch ($ProfileType) {
        'CurrentUser' { return $PROFILE.CurrentUserCurrentHost }
        'AllUsers' { return $PROFILE.AllUsersCurrentHost }
        'CurrentHost' { return $PROFILE.CurrentUserCurrentHost }
        'AllHosts' { return $PROFILE.CurrentUserAllHosts }
        default {
            throw "Unknown profile type: $ProfileType"
        }
    }
}

function Get-PowerShellProfileConfiguration {
    <#
    .SYNOPSIS
        Gets default PowerShell profile configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProfileType,
        
        [Parameter()]
        [switch]$IncludeModules,
        
        [Parameter()]
        [switch]$IncludeAliases,
        
        [Parameter()]
        [switch]$IncludeFunctions,
        
        [Parameter()]
        [switch]$IncludePrompt
    )
    
    $config = @{
        ProfileType = $ProfileType
        Header = "# DotWin PowerShell Profile Configuration"
        Modules = @()
        Aliases = @{}
        Functions = @{}
        Prompt = $null
        CustomContent = @()
    }
    
    if ($IncludeModules) {
        $config.Modules = @(
            @{ Name = "PSReadLine"; MinimumVersion = "2.0.0" },
            @{ Name = "Terminal-Icons"; MinimumVersion = "0.1.0" },
            @{ Name = "posh-git"; MinimumVersion = "1.0.0" }
        )
    }
    
    if ($IncludeAliases) {
        $config.Aliases = @{
            "ll" = "Get-ChildItem -Force"
            "la" = "Get-ChildItem -Force -Hidden"
            "grep" = "Select-String"
            "which" = "Get-Command"
            "touch" = "New-Item -ItemType File"
            "sudo" = "Start-Process -Verb RunAs"
        }
    }
    
    if ($IncludeFunctions) {
        $config.Functions = @{
            "Get-DirectorySize" = @"
function Get-DirectorySize {
    param([string]`$Path = ".")
    Get-ChildItem -Path `$Path -Recurse -File | Measure-Object -Property Length -Sum | 
        Select-Object @{Name="Size(MB)"; Expression={[math]::Round(`$_.Sum / 1MB, 2)}}
}
"@
            "Test-Administrator" = @"
function Test-Administrator {
    `$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return `$currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
"@
        }
    }
    
    if ($IncludePrompt) {
        $config.Prompt = @"
function prompt {
    `$location = Get-Location
    `$isAdmin = Test-Administrator
    `$adminIndicator = if (`$isAdmin) { " [ADMIN]" } else { "" }
    
    Write-Host "PS " -NoNewline -ForegroundColor Green
    Write-Host "`$location" -NoNewline -ForegroundColor Blue
    Write-Host "`$adminIndicator" -NoNewline -ForegroundColor Red
    Write-Host ">" -NoNewline -ForegroundColor Green
    return " "
}
"@
    }
    
    return $config
}

function New-PowerShellProfileContent {
    <#
    .SYNOPSIS
        Creates a new PowerShell profile content from configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Configuration
    )
    
    $content = @()
    
    # Add header
    $content += $Configuration.Header
    $content += "# Generated by DotWin on $(Get-Date)"
    $content += ""
    
    # Add module imports
    if ($Configuration.Modules -and $Configuration.Modules.Count -gt 0) {
        $content += "# Module Imports"
        foreach ($module in $Configuration.Modules) {
            if ($module -is [hashtable]) {
                $content += "Import-Module $($module.Name) -Force -ErrorAction SilentlyContinue"
            } else {
                $content += "Import-Module $module -Force -ErrorAction SilentlyContinue"
            }
        }
        $content += ""
    }
    
    # Add aliases
    if ($Configuration.Aliases -and $Configuration.Aliases.Count -gt 0) {
        $content += "# Custom Aliases"
        foreach ($alias in $Configuration.Aliases.GetEnumerator()) {
            $content += "Set-Alias -Name '$($alias.Key)' -Value '$($alias.Value)' -Force"
        }
        $content += ""
    }
    
    # Add functions
    if ($Configuration.Functions -and $Configuration.Functions.Count -gt 0) {
        $content += "# Custom Functions"
        foreach ($function in $Configuration.Functions.GetEnumerator()) {
            $content += $function.Value
            $content += ""
        }
    }
    
    # Add custom prompt
    if ($Configuration.Prompt) {
        $content += "# Custom Prompt"
        $content += $Configuration.Prompt
        $content += ""
    }
    
    # Add custom content
    if ($Configuration.CustomContent -and $Configuration.CustomContent.Count -gt 0) {
        $content += "# Custom Content"
        $content += $Configuration.CustomContent
        $content += ""
    }
    
    # Add PSReadLine configuration if module is included
    if ($Configuration.Modules | Where-Object { ($_ -is [hashtable] -and $_.Name -eq "PSReadLine") -or ($_ -eq "PSReadLine") }) {
        $content += "# PSReadLine Configuration"
        $content += "Set-PSReadLineOption -PredictionSource History"
        $content += "Set-PSReadLineOption -PredictionViewStyle ListView"
        $content += "Set-PSReadLineOption -EditMode Windows"
        $content += ""
    }
    
    $content += "# End of DotWin PowerShell Profile Configuration"
    
    return ($content -join "`r`n")
}

function Install-PowerShellProfileModules {
    <#
    .SYNOPSIS
        Installs PowerShell modules required by the profile.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$Modules
    )
    
    foreach ($moduleSpec in $Modules) {
        try {
            if ($moduleSpec -is [hashtable]) {
                $moduleName = $moduleSpec.Name
                $minVersion = $moduleSpec.MinimumVersion
            } else {
                $moduleName = $moduleSpec
                $minVersion = $null
            }
            
            Write-DotWinLog "Checking PowerShell module: $moduleName" -Level Verbose
            
            # Check if module is already installed
            $installedModule = Get-Module -Name $moduleName -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
            
            $needsInstall = $false
            if (-not $installedModule) {
                $needsInstall = $true
                Write-DotWinLog "PowerShell module '$moduleName' not found, will install" -Level Verbose
            } elseif ($minVersion -and $installedModule.Version -lt [version]$minVersion) {
                $needsInstall = $true
                Write-DotWinLog "PowerShell module '$moduleName' version $($installedModule.Version) is below minimum $minVersion, will update" -Level Verbose
            }
            
            if ($needsInstall) {
                Write-DotWinLog "Installing PowerShell module: $moduleName" -Level Information
                
                $installParams = @{
                    Name = $moduleName
                    Force = $true
                    AllowClobber = $true
                    Scope = 'CurrentUser'
                    ErrorAction = 'Stop'
                }
                
                if ($minVersion) {
                    $installParams.MinimumVersion = $minVersion
                }
                
                Install-Module @installParams
                Write-DotWinLog "Successfully installed PowerShell module: $moduleName" -Level Information
            } else {
                Write-DotWinLog "PowerShell module '$moduleName' already installed with sufficient version" -Level Verbose
            }
            
        } catch {
            Write-DotWinLog "Error installing PowerShell module '$moduleName': $($_.Exception.Message)" -Level Warning
        }
    }
}

function Get-PowerShellProfileStatus {
    <#
    .SYNOPSIS
        Gets the status of PowerShell profiles on the system.
    
    .DESCRIPTION
        Retrieves information about all PowerShell profile types and their current state.
    
    .OUTPUTS
        Hashtable containing profile status information.
    #>
    [CmdletBinding()]
    param()
    
    try {
        Write-DotWinLog "Retrieving PowerShell profile status" -Level Information
        
        $profileTypes = @('CurrentUser', 'AllUsers', 'CurrentHost', 'AllHosts')
        $status = @{}
        
        foreach ($profileType in $profileTypes) {
            try {
                $profilePath = Get-PowerShellProfilePath -ProfileType $profileType
                $profileInfo = @{
                    Path = $profilePath
                    Exists = Test-Path $profilePath
                    Size = 0
                    LastModified = $null
                    HasDotWinConfiguration = $false
                    Modules = @()
                }
                
                if ($profileInfo.Exists) {
                    $fileInfo = Get-Item $profilePath
                    $profileInfo.Size = $fileInfo.Length
                    $profileInfo.LastModified = $fileInfo.LastWriteTime
                    
                    $content = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
                    if ($content) {
                        $profileInfo.HasDotWinConfiguration = ($content -match "# DotWin PowerShell Profile Configuration")
                        
                        # Extract modules
                        $moduleMatches = [regex]::Matches($content, "Import-Module\s+([^\s\r\n]+)")
                        foreach ($match in $moduleMatches) {
                            $profileInfo.Modules += $match.Groups[1].Value
                        }
                    }
                }
                
                $status[$profileType] = $profileInfo
                
            } catch {
                $status[$profileType] = @{
                    Path = "Unknown"
                    Error = $_.Exception.Message
                }
            }
        }
        
        Write-DotWinLog "Retrieved PowerShell profile status successfully" -Level Information
        return $status
        
    } catch {
        Write-DotWinLog "Error retrieving PowerShell profile status: $($_.Exception.Message)" -Level Error
        throw
    }
}