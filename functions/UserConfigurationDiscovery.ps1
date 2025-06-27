<#
.SYNOPSIS
    User Configuration Discovery functions for DotWin.

.DESCRIPTION
    This module provides functions for discovering, initializing, and managing user-specific
    configuration directories and files. It supports the DotWin vision of allowing users
    to have arbitrary naming conventions and mixed file formats (.ps1/.jsonc).

.NOTES
    Part of the DotWin Configuration Bridge system.
    All classes must be defined in Classes.ps1 with corresponding tests in tests/Unit/Classes.Tests.ps1.
#>

#Requires -Version 5.1

<#
.SYNOPSIS
    Discovers user configuration directories based on common patterns and conventions.

.DESCRIPTION
    Searches for user configuration directories in standard locations and supports
    various naming conventions. This enables the consumer-focused approach where
    users can organize their configurations however they prefer.

.PARAMETER StartPath
    The starting path to search for user configurations. Defaults to user's home directory.

.PARAMETER SearchDepth
    Maximum depth to search for configuration directories. Defaults to 3.

.PARAMETER IncludeHidden
    Whether to include hidden directories in the search. Defaults to $true.

.PARAMETER ConfigPatterns
    Array of patterns to match configuration directories. Supports wildcards.

.EXAMPLE
    Get-DotWinUserConfigurationPath
    # Searches for user config directories in standard locations

.EXAMPLE
    Get-DotWinUserConfigurationPath -StartPath "C:\Users\John" -ConfigPatterns @("*dotwin*", "*config*")
    # Searches for config directories matching specific patterns

.OUTPUTS
    [PSCustomObject[]] Array of discovered configuration paths with metadata
#>
function Get-DotWinUserConfigurationPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$StartPath = $env:USERPROFILE,

        [Parameter(Mandatory = $false)]
        [int]$SearchDepth = 3,

        [Parameter(Mandatory = $false)]
        [bool]$IncludeHidden = $true,

        [Parameter(Mandatory = $false)]
        [string[]]$ConfigPatterns = @(
            "*dotwin*",
            "*config*", 
            "*settings*",
            "*preferences*",
            "*.dotfiles*",
            "*setup*"
        )
    )

    begin {
        Write-DotWinLog -Message "Starting user configuration discovery" -Level "Information"
        Write-DotWinLog -Message "Search parameters: StartPath='$StartPath', Depth=$SearchDepth, IncludeHidden=$IncludeHidden" -Level "Verbose"
        
        $discoveredPaths = @()
        $searchedDirectories = 0
        $startTime = Get-Date
    }

    process {
        try {
            # Validate start path
            if (-not (Test-Path -Path $StartPath -PathType Container)) {
                Write-DotWinLog -Message "Start path does not exist: $StartPath" -Level "Warning"
                return @()
            }

            # Define standard search locations
            $searchLocations = @(
                $StartPath,
                (Join-Path $StartPath "Documents"),
                (Join-Path $StartPath "Desktop"),
                (Join-Path $StartPath ".config"),
                (Join-Path $StartPath "AppData\Roaming"),
                (Join-Path $StartPath "AppData\Local")
            )

            # Add additional common locations if they exist
            $additionalLocations = @(
                $env:APPDATA,
                $env:LOCALAPPDATA,
                (Join-Path $env:USERPROFILE ".dotfiles"),
                (Join-Path $env:USERPROFILE "dotfiles")
            )

            foreach ($location in $additionalLocations) {
                if ($location -and (Test-Path -Path $location -PathType Container)) {
                    $searchLocations += $location
                }
            }

            # Remove duplicates and ensure paths exist
            $searchLocations = $searchLocations | 
                Where-Object { $_ -and (Test-Path -Path $_ -PathType Container) } |
                Sort-Object -Unique

            Write-DotWinLog -Message "Searching in $($searchLocations.Count) locations" -Level "Verbose"

            foreach ($location in $searchLocations) {
                Write-DotWinLog -Message "Searching location: $location" -Level "Verbose"
                
                try {
                    # Get directories matching patterns
                    $directories = Get-ChildItem -Path $location -Directory -Recurse -Depth $SearchDepth -ErrorAction SilentlyContinue
                    
                    if (-not $IncludeHidden) {
                        $directories = $directories | Where-Object { -not $_.Attributes.HasFlag([System.IO.FileAttributes]::Hidden) }
                    }

                    $searchedDirectories += $directories.Count

                    foreach ($pattern in $ConfigPatterns) {
                        $matchingDirs = $directories | Where-Object { $_.Name -like $pattern }
                        
                        foreach ($dir in $matchingDirs) {
                            # Check if directory contains configuration files
                            $configFiles = Get-ChildItem -Path $dir.FullName -File -ErrorAction SilentlyContinue |
                                Where-Object { $_.Extension -in @('.ps1', '.json', '.jsonc', '.yaml', '.yml', '.toml') }

                            if ($configFiles.Count -gt 0) {
                                $discoveredPath = [PSCustomObject]@{
                                    Path = $dir.FullName
                                    Name = $dir.Name
                                    Pattern = $pattern
                                    ConfigFileCount = $configFiles.Count
                                    ConfigFileTypes = ($configFiles | Group-Object Extension | ForEach-Object { $_.Name })
                                    LastModified = $dir.LastWriteTime
                                    Size = (Get-ChildItem -Path $dir.FullName -Recurse -File -ErrorAction SilentlyContinue | 
                                           Measure-Object -Property Length -Sum).Sum
                                    HasPowerShellConfigs = ($configFiles | Where-Object { $_.Extension -eq '.ps1' }).Count -gt 0
                                    HasJsonConfigs = ($configFiles | Where-Object { $_.Extension -in @('.json', '.jsonc') }).Count -gt 0
                                    Priority = Get-ConfigurationPriority -Path $dir.FullName -Pattern $pattern
                                    DiscoveredAt = Get-Date
                                }

                                $discoveredPaths += $discoveredPath
                                Write-DotWinLog -Message "Discovered config directory: $($dir.FullName) (Pattern: $pattern, Files: $($configFiles.Count))" -Level "Information"
                            }
                        }
                    }
                } catch {
                    Write-DotWinLog -Message "Error searching location '$location': $($_.Exception.Message)" -Level "Warning"
                }
            }

            # Sort by priority and last modified
            $discoveredPaths = $discoveredPaths | Sort-Object Priority, LastModified -Descending

            $endTime = Get-Date
            $duration = $endTime - $startTime

            Write-DotWinLog -Message "Discovery completed: Found $($discoveredPaths.Count) configuration directories in $($duration.TotalSeconds) seconds (searched $searchedDirectories directories)" -Level "Information"

            return $discoveredPaths

        } catch {
            Write-DotWinLog -Message "Error during user configuration discovery: $($_.Exception.Message)" -Level "Error"
            Write-DotWinLog -Message "Stack trace: $($_.ScriptStackTrace)" -Level "Verbose"
            throw
        }
    }
}

<#
.SYNOPSIS
    Initializes user configuration directory with template files.

.DESCRIPTION
    Creates a new user configuration directory with template configuration files
    based on the module's default configurations. Supports both PowerShell (.ps1)
    and JSON with comments (.jsonc) formats.

.PARAMETER ConfigurationPath
    Path where the user configuration should be created.

.PARAMETER ConfigurationName
    Name for the configuration set. Used in file headers and metadata.

.PARAMETER TemplateSource
    Source of template configurations. Can be 'Module' (default), 'Minimal', or 'Advanced'.

.PARAMETER FileFormat
    Preferred file format for generated configurations. Can be 'PowerShell', 'JsonC', or 'Mixed'.

.PARAMETER IncludeExamples
    Whether to include example configurations and comments. Defaults to $true.

.PARAMETER Force
    Whether to overwrite existing files. Defaults to $false.

.EXAMPLE
    Initialize-DotWinUserConfiguration -ConfigurationPath "~/.my-dotwin-config"
    # Creates a new user configuration with default templates

.EXAMPLE
    Initialize-DotWinUserConfiguration -ConfigurationPath "C:\MyConfigs\DotWin" -FileFormat "JsonC" -TemplateSource "Advanced"
    # Creates advanced configuration templates in JSON format

.OUTPUTS
    [PSCustomObject] Information about the created configuration
#>
function Initialize-DotWinUserConfiguration {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigurationPath,

        [Parameter(Mandatory = $false)]
        [string]$ConfigurationName = "My DotWin Configuration",

        [Parameter(Mandatory = $false)]
        [ValidateSet('Module', 'Minimal', 'Advanced')]
        [string]$TemplateSource = 'Module',

        [Parameter(Mandatory = $false)]
        [ValidateSet('PowerShell', 'JsonC', 'Mixed')]
        [string]$FileFormat = 'Mixed',

        [Parameter(Mandatory = $false)]
        [bool]$IncludeExamples = $true,

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-DotWinLog -Message "Initializing user configuration at: $ConfigurationPath" -Level "Information"
        Write-DotWinLog -Message "Parameters: Name='$ConfigurationName', Template='$TemplateSource', Format='$FileFormat'" -Level "Verbose"
        
        $createdFiles = @()
        $startTime = Get-Date
    }

    process {
        try {
            # Resolve and validate path
            $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ConfigurationPath)
            
            if (Test-Path -Path $resolvedPath) {
                if (-not $Force) {
                    Write-DotWinLog -Message "Configuration path already exists: $resolvedPath" -Level "Warning"
                    throw "Configuration directory already exists. Use -Force to overwrite."
                }
                Write-DotWinLog -Message "Overwriting existing configuration (Force specified)" -Level "Warning"
            }

            # Create directory structure
            if ($PSCmdlet.ShouldProcess($resolvedPath, "Create configuration directory")) {
                $null = New-Item -Path $resolvedPath -ItemType Directory -Force
                Write-DotWinLog -Message "Created configuration directory: $resolvedPath" -Level "Information"
            }

            # Get module configuration path for templates
            $moduleConfigPath = Get-ModuleConfigurationPath
            if (-not $moduleConfigPath) {
                throw "Could not locate module configuration path for templates"
            }

            # Define configuration files to create
            $configFiles = Get-ConfigurationFileDefinitions -TemplateSource $TemplateSource -FileFormat $FileFormat

            foreach ($configFile in $configFiles) {
                $targetPath = Join-Path $resolvedPath $configFile.FileName
                
                if ($PSCmdlet.ShouldProcess($targetPath, "Create configuration file")) {
                    $content = New-ConfigurationFileContent -ConfigFile $configFile -ConfigurationName $ConfigurationName -IncludeExamples $IncludeExamples -ModuleConfigPath $moduleConfigPath
                    
                    $content | Set-Content -Path $targetPath -Encoding UTF8
                    $createdFiles += [PSCustomObject]@{
                        Path = $targetPath
                        Type = $configFile.Type
                        Format = $configFile.Format
                        Size = (Get-Item $targetPath).Length
                        CreatedAt = Get-Date
                    }
                    
                    Write-DotWinLog -Message "Created configuration file: $($configFile.FileName) ($($configFile.Type))" -Level "Information"
                }
            }

            # Create README file
            if ($PSCmdlet.ShouldProcess((Join-Path $resolvedPath "README.md"), "Create README file")) {
                $readmeContent = New-ReadmeContent -ConfigurationName $ConfigurationName -CreatedFiles $createdFiles
                $readmePath = Join-Path $resolvedPath "README.md"
                $readmeContent | Set-Content -Path $readmePath -Encoding UTF8
                
                $createdFiles += [PSCustomObject]@{
                    Path = $readmePath
                    Type = "Documentation"
                    Format = "Markdown"
                    Size = (Get-Item $readmePath).Length
                    CreatedAt = Get-Date
                }
            }

            $endTime = Get-Date
            $duration = $endTime - $startTime

            $result = [PSCustomObject]@{
                ConfigurationPath = $resolvedPath
                ConfigurationName = $ConfigurationName
                TemplateSource = $TemplateSource
                FileFormat = $FileFormat
                CreatedFiles = $createdFiles
                TotalFiles = $createdFiles.Count
                TotalSize = ($createdFiles | Measure-Object -Property Size -Sum).Sum
                CreatedAt = $startTime
                Duration = $duration
                Success = $true
            }

            Write-DotWinLog -Message "User configuration initialized successfully: $($createdFiles.Count) files created in $($duration.TotalSeconds) seconds" -Level "Information"
            
            return $result

        } catch {
            Write-DotWinLog -Message "Error initializing user configuration: $($_.Exception.Message)" -Level "Error"
            Write-DotWinLog -Message "Stack trace: $($_.ScriptStackTrace)" -Level "Verbose"
            throw
        }
    }
}

<#
.SYNOPSIS
    Gets the priority score for a configuration directory.

.DESCRIPTION
    Internal helper function that calculates a priority score for discovered
    configuration directories based on naming patterns and location.

.PARAMETER Path
    The path to evaluate.

.PARAMETER Pattern
    The pattern that matched this path.

.OUTPUTS
    [int] Priority score (higher = more likely to be the desired config)
#>
function Get-ConfigurationPriority {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Pattern
    )

    $priority = 0
    $pathLower = $Path.ToLower()
    $patternLower = $Pattern.ToLower()

    # Higher priority for DotWin-specific patterns
    if ($patternLower -like "*dotwin*") { $priority += 100 }
    
    # Medium priority for generic config patterns
    if ($patternLower -like "*config*") { $priority += 50 }
    if ($patternLower -like "*settings*") { $priority += 40 }
    if ($patternLower -like "*preferences*") { $priority += 30 }
    
    # Higher priority for user profile locations
    if ($pathLower.Contains($env:USERPROFILE.ToLower())) { $priority += 20 }
    
    # Higher priority for .config or .dotfiles directories
    if ($pathLower.Contains(".config") -or $pathLower.Contains(".dotfiles")) { $priority += 15 }
    
    # Lower priority for system locations
    if ($pathLower.Contains("appdata") -or $pathLower.Contains("programdata")) { $priority -= 10 }

    return $priority
}

<#
.SYNOPSIS
    Gets the module's configuration path for template generation.

.DESCRIPTION
    Internal helper function that locates the module's configuration directory
    to use as a source for template generation.

.OUTPUTS
    [string] Path to module configuration directory
#>
function Get-ModuleConfigurationPath {
    [CmdletBinding()]
    param()

    try {
        # Try to get from module context
        $moduleBase = $MyInvocation.MyCommand.Module.ModuleBase
        if ($moduleBase) {
            $configPath = Join-Path $moduleBase "config"
            if (Test-Path -Path $configPath -PathType Container) {
                return $configPath
            }
        }

        # Fallback: relative to script location
        $scriptPath = $PSScriptRoot
        if ($scriptPath) {
            $configPath = Join-Path (Split-Path $scriptPath -Parent) "config"
            if (Test-Path -Path $configPath -PathType Container) {
                return $configPath
            }
        }

        # Last resort: search common locations
        $searchPaths = @(
            ".\config",
            "..\config",
            "..\..\config"
        )

        foreach ($searchPath in $searchPaths) {
            $resolvedPath = Resolve-Path $searchPath -ErrorAction SilentlyContinue
            if ($resolvedPath -and (Test-Path -Path $resolvedPath -PathType Container)) {
                return $resolvedPath.Path
            }
        }

        Write-DotWinLog -Message "Could not locate module configuration path" -Level "Warning"
        return $null

    } catch {
        Write-DotWinLog -Message "Error locating module configuration path: $($_.Exception.Message)" -Level "Warning"
        return $null
    }
}

<#
.SYNOPSIS
    Gets configuration file definitions for template generation.

.DESCRIPTION
    Internal helper function that defines which configuration files to create
    based on template source and file format preferences.

.PARAMETER TemplateSource
    The template source type.

.PARAMETER FileFormat
    The preferred file format.

.OUTPUTS
    [PSCustomObject[]] Array of configuration file definitions
#>
function Get-ConfigurationFileDefinitions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$TemplateSource,

        [Parameter(Mandatory = $true)]
        [string]$FileFormat
    )

    $definitions = @()

    # Core configuration files
    $coreFiles = @(
        @{ Type = "Packages"; Name = "Packages"; Description = "Package management configuration" },
        @{ Type = "Terminal"; Name = "Terminal"; Description = "Terminal and shell configuration" },
        @{ Type = "Profile"; Name = "Profile"; Description = "PowerShell profile configuration" }
    )

    # Additional files for Advanced template
    if ($TemplateSource -eq 'Advanced') {
        $coreFiles += @(
            @{ Type = "System"; Name = "System"; Description = "System-level configuration" },
            @{ Type = "Development"; Name = "Development"; Description = "Development environment configuration" },
            @{ Type = "Security"; Name = "Security"; Description = "Security and privacy configuration" }
        )
    }

    foreach ($file in $coreFiles) {
        switch ($FileFormat) {
            'PowerShell' {
                $definitions += [PSCustomObject]@{
                    Type = $file.Type
                    FileName = "$($file.Name).ps1"
                    Format = "PowerShell"
                    Description = $file.Description
                }
            }
            'JsonC' {
                $definitions += [PSCustomObject]@{
                    Type = $file.Type
                    FileName = "$($file.Name).jsonc"
                    Format = "JsonC"
                    Description = $file.Description
                }
            }
            'Mixed' {
                # Create both formats for mixed approach
                $definitions += [PSCustomObject]@{
                    Type = $file.Type
                    FileName = "$($file.Name).ps1"
                    Format = "PowerShell"
                    Description = $file.Description
                }
                $definitions += [PSCustomObject]@{
                    Type = $file.Type
                    FileName = "$($file.Name).jsonc"
                    Format = "JsonC"
                    Description = "$($file.Description) (JSON format)"
                }
            }
        }
    }

    return $definitions
}

<#
.SYNOPSIS
    Generates content for a configuration file.

.DESCRIPTION
    Internal helper function that generates the actual content for configuration
    files based on templates and user preferences.

.PARAMETER ConfigFile
    The configuration file definition.

.PARAMETER ConfigurationName
    The name of the configuration set.

.PARAMETER IncludeExamples
    Whether to include examples.

.PARAMETER ModuleConfigPath
    Path to module configuration templates.

.OUTPUTS
    [string] Generated file content
#>
function New-ConfigurationFileContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ConfigFile,

        [Parameter(Mandatory = $true)]
        [string]$ConfigurationName,

        [Parameter(Mandatory = $true)]
        [bool]$IncludeExamples,

        [Parameter(Mandatory = $false)]
        [string]$ModuleConfigPath
    )

    $content = @()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if ($ConfigFile.Format -eq "PowerShell") {
        # PowerShell format
        $content += "<#"
        $content += ".SYNOPSIS"
        $content += "    $($ConfigFile.Description) for $ConfigurationName"
        $content += ""
        $content += ".DESCRIPTION"
        $content += "    User-specific $($ConfigFile.Type.ToLower()) configuration for DotWin."
        $content += "    This file was generated automatically and can be customized as needed."
        $content += ""
        $content += ".NOTES"
        $content += "    Generated: $timestamp"
        $content += "    Configuration: $ConfigurationName"
        $content += "    Type: $($ConfigFile.Type)"
        $content += "#>"
        $content += ""

        # Add template content based on type
        $content += New-PowerShellTemplateContent -Type $ConfigFile.Type -IncludeExamples $IncludeExamples -ModuleConfigPath $ModuleConfigPath

    } else {
        # JSON with Comments format
        $content += "// $($ConfigFile.Description) for $ConfigurationName"
        $content += "// Generated: $timestamp"
        $content += "// Configuration: $ConfigurationName"
        $content += "// Type: $($ConfigFile.Type)"
        $content += "//"
        $content += "// This file supports JSON with comments (JSONC) format."
        $content += "// You can add comments and customize as needed."
        $content += ""

        # Add JSON template content
        $content += New-JsonTemplateContent -Type $ConfigFile.Type -IncludeExamples $IncludeExamples -ModuleConfigPath $ModuleConfigPath
    }

    return $content -join "`n"
}

<#
.SYNOPSIS
    Generates PowerShell template content for a specific configuration type.

.DESCRIPTION
    Internal helper function that creates PowerShell-specific template content.

.PARAMETER Type
    The configuration type.

.PARAMETER IncludeExamples
    Whether to include examples.

.PARAMETER ModuleConfigPath
    Path to module configuration templates.

.OUTPUTS
    [string[]] Array of content lines
#>
function New-PowerShellTemplateContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [bool]$IncludeExamples,

        [Parameter(Mandatory = $false)]
        [string]$ModuleConfigPath
    )

    $content = @()

    switch ($Type) {
        "Packages" {
            $content += "# Package Configuration"
            $content += "# Define packages to install and manage"
            $content += ""
            $content += "function Get-PackagesByCategory {"
            $content += "    param([string]`$Category)"
            $content += "    "
            $content += "    return @{"
            if ($IncludeExamples) {
                $content += "        Development = @("
                $content += "            @{ Id = 'Git.Git'; Name = 'Git'; Version = 'latest' }"
                $content += "            @{ Id = 'Microsoft.VisualStudioCode'; Name = 'VS Code'; Version = 'latest' }"
                $content += "            # Add more development tools here"
                $content += "        )"
                $content += "        Productivity = @("
                $content += "            @{ Id = 'Microsoft.Office'; Name = 'Office'; Version = 'latest' }"
                $content += "            # Add more productivity tools here"
                $content += "        )"
                $content += "        # Add more categories as needed"
            } else {
                $content += "        # Define your package categories here"
                $content += "        # Example: Development = @(@{ Id = 'Git.Git'; Name = 'Git'; Version = 'latest' })"
            }
            $content += "    }[`$Category]"
            $content += "}"
        }

        "Terminal" {
            $content += "# Terminal Configuration"
            $content += "# Define terminal themes, profiles, and settings"
            $content += ""
            $content += "function Get-TerminalConfiguration {"
            $content += "    param("
            $content += "        [string]`$Theme,"
            $content += "        [bool]`$IncludeProfiles,"
            $content += "        [bool]`$IncludeKeybindings,"
            $content += "        [bool]`$IncludeSettings"
            $content += "    )"
            $content += "    "
            $content += "    `$config = @{"
            $content += "        theme = `$Theme"
            if ($IncludeExamples) {
                $content += "        profiles = @{"
                $content += "            list = @("
                $content += "                @{ name = 'PowerShell'; commandline = 'pwsh.exe' }"
                $content += "                @{ name = 'Command Prompt'; commandline = 'cmd.exe' }"
                $content += "                # Add more profiles here"
                $content += "            )"
                $content += "        }"
                $content += "        schemes = @("
                $content += "            @{ name = 'Campbell'; background = '#0C0C0C'; foreground = '#CCCCCC' }"
                $content += "            # Add more color schemes here"
                $content += "        )"
            } else {
                $content += "        # Define your terminal configuration here"
                $content += "        # profiles = @{ list = @() }"
                $content += "        # schemes = @()"
            }
            $content += "    }"
            $content += "    "
            $content += "    return `$config"
            $content += "}"
        }

        "Profile" {
            $content += "# PowerShell Profile Configuration"
            $content += "# Define PowerShell profile settings, modules, aliases, and functions"
            $content += ""
            $content += "function Get-ProfileConfiguration {"
            $content += "    param("
            $content += "        [string]`$ProfileType,"
            $content += "        [bool]`$IncludeModules,"
            $content += "        [bool]`$IncludeAliases,"
            $content += "        [bool]`$IncludeFunctions,"
            $content += "        [bool]`$IncludePrompt"
            $content += "    )"
            $content += "    "
            $content += "    `$config = @{"
            $content += "        ProfileType = `$ProfileType"
            if ($IncludeExamples) {
                $content += "        Modules = @('Posh-Git', 'PSReadLine', 'Terminal-Icons')"
                $content += "        Aliases = @{"
                $content += "            ll = 'Get-ChildItem -Force'"
                $content += "            la = 'Get-ChildItem -Force -Hidden'"
                $content += "            # Add more aliases here"
                $content += "        }"
                $content += "        Functions = @{"
                $content += "            'Get-GitStatus' = 'git status'"
                $content += "            # Add more functions here"
                $content += "        }"
                $content += "        Prompt = 'function prompt { `"PS `$(`$PWD.Path)> `" }'"
            } else {
                $content += "        # Define your profile configuration here"
                $content += "        # Modules = @()"
                $content += "        # Aliases = @{}"
                $content += "        # Functions = @{}"
                $content += "        # Prompt = ''"
            }
            $content += "    }"
            $content += "    "
            $content += "    return `$config"
            $content += "}"
        }

        default {
            $content += "# $Type Configuration"
            $content += "# Define your $($Type.ToLower()) configuration here"
            $content += ""
            $content += "function Get-$($Type)Configuration {"
            $content += "    param()"
            $content += "    "
            $content += "    return @{"
            $content += "        # Add your configuration properties here"
            $content += "    }"
            $content += "}"
        }
    }

    return $content
}

<#
.SYNOPSIS
    Generates JSON template content for a specific configuration type.

.DESCRIPTION
    Internal helper function that creates JSON-specific template content.

.PARAMETER Type
    The configuration type.

.PARAMETER IncludeExamples
    Whether to include examples.

.PARAMETER ModuleConfigPath
    Path to module configuration templates.

.OUTPUTS
    [string[]] Array of content lines
#>
function New-JsonTemplateContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Type,

        [Parameter(Mandatory = $true)]
        [bool]$IncludeExamples,

        [Parameter(Mandatory = $false)]
        [string]$ModuleConfigPath
    )

    $content = @()

    switch ($Type) {
        "Packages" {
            if ($IncludeExamples) {
                $jsonContent = @'
{
  // Package configuration
  // Define packages to install and manage
  "categories": {
    "Development": [
      {
        "id": "Git.Git",
        "name": "Git",
        "version": "latest"
      },
      {
        "id": "Microsoft.VisualStudioCode",
        "name": "VS Code",
        "version": "latest"
      }
      // Add more development tools here
    ],
    "Productivity": [
      {
        "id": "Microsoft.Office",
        "name": "Office",
        "version": "latest"
      }
      // Add more productivity tools here
    ]
    // Add more categories as needed
  }
}
'@
            } else {
                $jsonContent = @'
{
  // Package configuration
  // Define packages to install and manage
  // Example structure:
  // "categories": {
  //   "Development": [
  //     { "id": "Git.Git", "name": "Git", "version": "latest" }
  //   ]
  // }
}
'@
            }
            $content += $jsonContent -split "`n"
        }

        "Terminal" {
            if ($IncludeExamples) {
                $jsonContent = @'
{
  // Terminal configuration
  // Define terminal themes, profiles, and settings
  "profiles": {
    "list": [
      {
        "name": "PowerShell",
        "commandline": "pwsh.exe"
      },
      {
        "name": "Command Prompt",
        "commandline": "cmd.exe"
      }
      // Add more profiles here
    ]
  },
  "schemes": [
    {
      "name": "Campbell",
      "background": "#0C0C0C",
      "foreground": "#CCCCCC"
    }
    // Add more color schemes here
  ]
}
'@
            } else {
                $jsonContent = @'
{
  // Terminal configuration
  // Define terminal themes, profiles, and settings
  // "profiles": { "list": [] },
  // "schemes": []
}
'@
            }
            $content += $jsonContent -split "`n"
        }

        "Profile" {
            if ($IncludeExamples) {
                $jsonContent = @'
{
  // PowerShell profile configuration
  // Define profile settings, modules, aliases, and functions
  "modules": [
    "Posh-Git",
    "PSReadLine",
    "Terminal-Icons"
  ],
  "aliases": {
    "ll": "Get-ChildItem -Force",
    "la": "Get-ChildItem -Force -Hidden"
    // Add more aliases here
  },
  "functions": {
    "Get-GitStatus": "git status"
    // Add more functions here
  },
  "prompt": "function prompt { \"PS $($PWD.Path)> \" }"
}
'@
            } else {
                $jsonContent = @'
{
  // PowerShell profile configuration
  // Define profile settings, modules, aliases, and functions
  // "modules": [],
  // "aliases": {},
  // "functions": {},
  // "prompt": ""
}
'@
            }
            $content += $jsonContent -split "`n"
        }

        default {
            $jsonContent = @"
{
  // $Type configuration
  // Define your $($Type.ToLower()) configuration here
  // Add your configuration properties here
}
"@
            $content += $jsonContent -split "`n"
        }
    }

    return $content
}

<#
.SYNOPSIS
    Generates README content for the user configuration.

.DESCRIPTION
    Internal helper function that creates a README file for the user configuration
    directory with usage instructions and file descriptions.

.PARAMETER ConfigurationName
    The name of the configuration set.

.PARAMETER CreatedFiles
    Array of created files with metadata.

.OUTPUTS
    [string[]] Array of README content lines
#>
function New-ReadmeContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigurationName,

        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$CreatedFiles
    )

    $content = @()
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    $content += "# $ConfigurationName"
    $content += ""
    $content += "This directory contains your personal DotWin configuration files."
    $content += "Generated on: $timestamp"
    $content += ""
    $content += "## Usage"
    $content += ""
    $content += "To use this configuration with DotWin:"
    $content += ""
    $content += "```powershell"
    $content += "Import-Module DotWin"
    $content += "Invoke-DotWinConfiguration -ConfigurationPath `"$((Get-Location).Path)`""
    $content += "```"
    $content += ""
    $content += "## Configuration Files"
    $content += ""

    # Group files by type
    $filesByType = $CreatedFiles | Group-Object Type

    foreach ($typeGroup in $filesByType) {
        if ($typeGroup.Name -ne "Documentation") {
            $content += "### $($typeGroup.Name)"
            $content += ""

            foreach ($file in $typeGroup.Group) {
                $fileName = Split-Path $file.Path -Leaf
                $content += "- **$fileName** ($($file.Format)): Configuration for $($typeGroup.Name.ToLower())"
            }
            $content += ""
        }
    }

    $content += "## Customization"
    $content += ""
    $content += "You can customize these files according to your needs:"
    $content += ""
    $content += "- **PowerShell files (.ps1)**: Full PowerShell scripting capabilities"
    $content += "- **JSON files (.jsonc)**: JSON with comments support"
    $content += "- **Mixed approach**: Use both formats as needed"
    $content += ""
    $content += "## File Formats"
    $content += ""
    $content += "DotWin supports multiple configuration formats:"
    $content += ""
    $content += "- **.ps1**: PowerShell scripts with full scripting capabilities"
    $content += "- **.jsonc**: JSON with comments for declarative configuration"
    $content += "- **.json**: Standard JSON format"
    $content += ""
    $content += "The Configuration Bridge will automatically detect and merge configurations from all supported formats."
    $content += ""
    $content += "## Support"
    $content += ""
    $content += "For more information about DotWin configuration:"
    $content += ""
    $content += "- [DotWin Documentation](https://github.com/your-repo/dotwin)"
    $content += "- [Configuration Examples](https://github.com/your-repo/dotwin/tree/main/examples)"
    $content += "- [Troubleshooting Guide](https://github.com/your-repo/dotwin/blob/main/docs/Troubleshooting.md)"

    return $content -join "`n"
}

# Export functions
Export-ModuleMember -Function @(
    'Get-DotWinUserConfigurationPath',
    'Initialize-DotWinUserConfiguration'
)
