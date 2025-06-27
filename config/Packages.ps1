<#
.SYNOPSIS
    Package definitions and categories for the DotWin PowerShell module.

.DESCRIPTION
    This file contains predefined package lists organized by categories,
    providing a centralized configuration for package management operations.
#>

# Package categories and definitions
$script:DotWinPackageCategories = @{
    'Development' = @{
        Description = "Development tools and environments"
        Packages = @(
            @{
                Id = "Git.Git"
                Name = "Git"
                Description = "Distributed version control system"
                Category = "Development"
                Source = "winget"
                Configuration = @{
                    GlobalConfig = @{
                        "user.name" = $env:USERNAME
                        "core.autocrlf" = "true"
                        "core.editor" = "code --wait"
                        "init.defaultBranch" = "main"
                    }
                }
            },
            @{
                Id = "Microsoft.VisualStudioCode"
                Name = "Visual Studio Code"
                Description = "Code editor redefined and optimized for building and debugging modern web and cloud applications"
                Category = "Development"
                Source = "winget"
                Configuration = @{
                    Extensions = @(
                        "ms-python.python",
                        "ms-vscode.powershell",
                        "ms-dotnettools.csharp",
                        "ms-vscode.vscode-typescript-next",
                        "esbenp.prettier-vscode",
                        "ms-vscode.vscode-json",
                        "redhat.vscode-yaml",
                        "ms-vscode.hexeditor"
                    )
                    Settings = @{
                        "editor.fontSize" = 14
                        "editor.fontFamily" = "Cascadia Code, Consolas, monospace"
                        "editor.tabSize" = 4
                        "editor.insertSpaces" = $true
                        "editor.wordWrap" = "on"
                        "files.autoSave" = "afterDelay"
                        "terminal.integrated.defaultProfile.windows" = "PowerShell"
                    }
                }
                Shortcuts = @{
                    Desktop = $true
                    StartMenu = $true
                }
            },
            @{
                Id = "Microsoft.PowerShell"
                Name = "PowerShell 7"
                Description = "PowerShell for every system"
                Category = "Development"
                Source = "winget"
                Configuration = @{
                    Modules = @(
                        "PSReadLine",
                        "Terminal-Icons",
                        "posh-git",
                        "PowerShellGet"
                    )
                }
            },
            @{
                Id = "Microsoft.WindowsTerminal"
                Name = "Windows Terminal"
                Description = "Modern terminal application for users of command-line tools and shells"
                Category = "Development"
                Source = "winget"
                Configuration = @{
                    Settings = @{
                        theme = "dark"
                        copyOnSelect = $true
                        defaultProfile = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}"
                    }
                }
            },
            @{
                Id = "Microsoft.VisualStudio.2022.Community"
                Name = "Visual Studio Community 2022"
                Description = "Fully-featured IDE for students, open-source and individual developers"
                Category = "Development"
                Source = "winget"
                Optional = $true
            },
            @{
                Id = "Docker.DockerDesktop"
                Name = "Docker Desktop"
                Description = "Application for building and sharing containerized applications"
                Category = "Development"
                Source = "winget"
                Optional = $true
            },
            @{
                Id = "Postman.Postman"
                Name = "Postman"
                Description = "API platform for building and using APIs"
                Category = "Development"
                Source = "winget"
                Optional = $true
            },
            @{
                Id = "JetBrains.IntelliJIDEA.Community"
                Name = "IntelliJ IDEA Community"
                Description = "Java IDE for professional developers"
                Category = "Development"
                Source = "winget"
                Optional = $true
            }
        )
    }
    
    'Productivity' = @{
        Description = "Productivity and office applications"
        Packages = @(
            @{
                Id = "Microsoft.Office"
                Name = "Microsoft Office"
                Description = "Microsoft Office suite"
                Category = "Productivity"
                Source = "winget"
                Optional = $true
            },
            @{
                Id = "Notion.Notion"
                Name = "Notion"
                Description = "All-in-one workspace for notes, tasks, wikis, and databases"
                Category = "Productivity"
                Source = "winget"
            },
            @{
                Id = "Obsidian.Obsidian"
                Name = "Obsidian"
                Description = "Knowledge base that works on top of a local folder of plain text Markdown files"
                Category = "Productivity"
                Source = "winget"
            },
            @{
                Id = "Adobe.Acrobat.Reader.64-bit"
                Name = "Adobe Acrobat Reader"
                Description = "PDF reader and editor"
                Category = "Productivity"
                Source = "winget"
            },
            @{
                Id = "Microsoft.PowerToys"
                Name = "PowerToys"
                Description = "Windows system utilities to maximize productivity"
                Category = "Productivity"
                Source = "winget"
                Configuration = @{
                    Registry = @{
                        "HKCU:\SOFTWARE\Microsoft\PowerToys" = @{
                            "AlwaysOnTop_Enabled" = 1
                            "ColorPicker_Enabled" = 1
                            "FancyZones_Enabled" = 1
                            "PowerRename_Enabled" = 1
                            "Run_Enabled" = 1
                        }
                    }
                }
            },
            @{
                Id = "7zip.7zip"
                Name = "7-Zip"
                Description = "File archiver with a high compression ratio"
                Category = "Productivity"
                Source = "winget"
            }
        )
    }
    
    'Media' = @{
        Description = "Media and entertainment applications"
        Packages = @(
            @{
                Id = "VideoLAN.VLC"
                Name = "VLC Media Player"
                Description = "Free and open source cross-platform multimedia player"
                Category = "Media"
                Source = "winget"
            },
            @{
                Id = "Spotify.Spotify"
                Name = "Spotify"
                Description = "Digital music service"
                Category = "Media"
                Source = "winget"
            },
            @{
                Id = "Audacity.Audacity"
                Name = "Audacity"
                Description = "Free, open source, cross-platform audio software"
                Category = "Media"
                Source = "winget"
                Optional = $true
            },
            @{
                Id = "GIMP.GIMP"
                Name = "GIMP"
                Description = "GNU Image Manipulation Program"
                Category = "Media"
                Source = "winget"
                Optional = $true
            },
            @{
                Id = "OBSProject.OBSStudio"
                Name = "OBS Studio"
                Description = "Free and open source software for video recording and live streaming"
                Category = "Media"
                Source = "winget"
                Optional = $true
            }
        )
    }
    
    'Gaming' = @{
        Description = "Gaming platforms and tools"
        Packages = @(
            @{
                Id = "Valve.Steam"
                Name = "Steam"
                Description = "Digital distribution platform for PC gaming"
                Category = "Gaming"
                Source = "winget"
            },
            @{
                Id = "EpicGames.EpicGamesLauncher"
                Name = "Epic Games Launcher"
                Description = "Digital storefront for PC and Mac"
                Category = "Gaming"
                Source = "winget"
            },
            @{
                Id = "Discord.Discord"
                Name = "Discord"
                Description = "Voice, video and text communication service"
                Category = "Gaming"
                Source = "winget"
            },
            @{
                Id = "Ubisoft.Connect"
                Name = "Ubisoft Connect"
                Description = "Ubisoft's PC gaming platform"
                Category = "Gaming"
                Source = "winget"
                Optional = $true
            }
        )
    }
    
    'Utilities' = @{
        Description = "System utilities and tools"
        Packages = @(
            @{
                Id = "WinDirStat.WinDirStat"
                Name = "WinDirStat"
                Description = "Disk usage statistics viewer and cleanup tool"
                Category = "Utilities"
                Source = "winget"
            },
            @{
                Id = "WinSCP.WinSCP"
                Name = "WinSCP"
                Description = "SFTP, FTP, WebDAV, Amazon S3 and SCP client"
                Category = "Utilities"
                Source = "winget"
            },
            @{
                Id = "PuTTY.PuTTY"
                Name = "PuTTY"
                Description = "SSH and telnet client"
                Category = "Utilities"
                Source = "winget"
            },
            @{
                Id = "Greenshot.Greenshot"
                Name = "Greenshot"
                Description = "Screenshot tool"
                Category = "Utilities"
                Source = "winget"
            },
            @{
                Id = "Microsoft.Sysinternals.ProcessExplorer"
                Name = "Process Explorer"
                Description = "Advanced process and system monitoring tool"
                Category = "Utilities"
                Source = "winget"
            },
            @{
                Id = "Wireshark.Wireshark"
                Name = "Wireshark"
                Description = "Network protocol analyzer"
                Category = "Utilities"
                Source = "winget"
                Optional = $true
            }
        )
    }
    
    'Security' = @{
        Description = "Security and privacy tools"
        Packages = @(
            @{
                Id = "Bitwarden.Bitwarden"
                Name = "Bitwarden"
                Description = "Password manager"
                Category = "Security"
                Source = "winget"
            },
            @{
                Id = "KeePassXCTeam.KeePassXC"
                Name = "KeePassXC"
                Description = "Cross-platform password manager"
                Category = "Security"
                Source = "winget"
                Optional = $true
            },
            @{
                Id = "Malwarebytes.Malwarebytes"
                Name = "Malwarebytes"
                Description = "Anti-malware software"
                Category = "Security"
                Source = "winget"
                Optional = $true
            }
        )
    }
    
    'Communication' = @{
        Description = "Communication and collaboration tools"
        Packages = @(
            @{
                Id = "Microsoft.Teams"
                Name = "Microsoft Teams"
                Description = "Collaboration platform"
                Category = "Communication"
                Source = "winget"
            },
            @{
                Id = "SlackTechnologies.Slack"
                Name = "Slack"
                Description = "Team collaboration hub"
                Category = "Communication"
                Source = "winget"
            },
            @{
                Id = "Zoom.Zoom"
                Name = "Zoom"
                Description = "Video conferencing and web conferencing service"
                Category = "Communication"
                Source = "winget"
            },
            @{
                Id = "Telegram.TelegramDesktop"
                Name = "Telegram Desktop"
                Description = "Messaging app with a focus on speed and security"
                Category = "Communication"
                Source = "winget"
                Optional = $true
            }
        )
    }
}

# Essential packages that should be installed on most systems
$script:DotWinEssentialPackages = @(
    "Git.Git",
    "Microsoft.VisualStudioCode",
    "Microsoft.PowerShell",
    "Microsoft.WindowsTerminal",
    "Microsoft.PowerToys",
    "7zip.7zip",
    "VideoLAN.VLC"
)

# Optional packages that users might want
$script:DotWinOptionalPackages = @(
    "Microsoft.VisualStudio.2022.Community",
    "Docker.DockerDesktop",
    "Postman.Postman",
    "Microsoft.Office",
    "Audacity.Audacity",
    "GIMP.GIMP",
    "OBSProject.OBSStudio",
    "Wireshark.Wireshark",
    "KeePassXCTeam.KeePassXC",
    "Malwarebytes.Malwarebytes",
    "Telegram.TelegramDesktop"
)

function Get-PackagesByCategory {
    <#
    .SYNOPSIS
        Gets packages by category.
    
    .DESCRIPTION
        Retrieves package definitions for a specific category.
    
    .PARAMETER Category
        The category of packages to retrieve.
    
    .OUTPUTS
        Array of package objects for the specified category.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Development', 'Productivity', 'Media', 'Gaming', 'Utilities', 'Security', 'Communication', 'Essential', 'Optional', 'All')]
        [string]$Category
    )
    
    switch ($Category) {
        'Essential' {
            $packages = @()
            foreach ($categoryName in $script:DotWinPackageCategories.Keys) {
                $categoryPackages = $script:DotWinPackageCategories[$categoryName].Packages | Where-Object { $_.Id -in $script:DotWinEssentialPackages }
                $packages += $categoryPackages
            }
            return $packages
        }
        
        'Optional' {
            $packages = @()
            foreach ($categoryName in $script:DotWinPackageCategories.Keys) {
                $categoryPackages = $script:DotWinPackageCategories[$categoryName].Packages | Where-Object { $_.Optional -eq $true -or $_.Id -in $script:DotWinOptionalPackages }
                $packages += $categoryPackages
            }
            return $packages
        }
        
        'All' {
            $packages = @()
            foreach ($categoryName in $script:DotWinPackageCategories.Keys) {
                $packages += $script:DotWinPackageCategories[$categoryName].Packages
            }
            return $packages
        }
        
        default {
            if ($script:DotWinPackageCategories.ContainsKey($Category)) {
                return $script:DotWinPackageCategories[$Category].Packages
            } else {
                Write-Warning "Unknown package category: $Category"
                return @()
            }
        }
    }
}

function Get-ApplicationsByCategory {
    <#
    .SYNOPSIS
        Gets applications by category (alias for Get-PackagesByCategory).
    
    .DESCRIPTION
        Retrieves application definitions for a specific category.
        This is an alias for Get-PackagesByCategory to support the Install-Applications function.
    
    .PARAMETER Category
        The category of applications to retrieve.
    
    .OUTPUTS
        Array of application objects for the specified category.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Development', 'Productivity', 'Media', 'Gaming', 'Utilities', 'Security', 'Communication', 'Essential', 'Optional', 'All')]
        [string]$Category
    )
    
    return Get-PackagesByCategory -Category $Category
}

function Get-PackageCategories {
    <#
    .SYNOPSIS
        Gets all available package categories.
    
    .DESCRIPTION
        Retrieves information about all available package categories.
    
    .OUTPUTS
        Hashtable containing category information.
    #>
    [CmdletBinding()]
    param()
    
    $categories = @{}
    foreach ($categoryName in $script:DotWinPackageCategories.Keys) {
        $categories[$categoryName] = @{
            Description = $script:DotWinPackageCategories[$categoryName].Description
            PackageCount = $script:DotWinPackageCategories[$categoryName].Packages.Count
        }
    }
    
    # Add special categories
    $categories['Essential'] = @{
        Description = "Essential packages recommended for most systems"
        PackageCount = $script:DotWinEssentialPackages.Count
    }
    
    $categories['Optional'] = @{
        Description = "Optional packages that users might want"
        PackageCount = $script:DotWinOptionalPackages.Count
    }
    
    return $categories
}

function Find-Package {
    <#
    .SYNOPSIS
        Finds packages by name or ID.
    
    .DESCRIPTION
        Searches for packages across all categories by name or ID.
    
    .PARAMETER Query
        The search query (package name or ID).
    
    .PARAMETER Exact
        Perform exact match search.
    
    .OUTPUTS
        Array of matching package objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Query,
        
        [Parameter()]
        [switch]$Exact
    )
    
    $matchingPackages = @()
    
    foreach ($categoryName in $script:DotWinPackageCategories.Keys) {
        $categoryPackages = $script:DotWinPackageCategories[$categoryName].Packages
        
        if ($Exact) {
            $matched = $categoryPackages | Where-Object { $_.Id -eq $Query -or $_.Name -eq $Query }
        } else {
            $matched = $categoryPackages | Where-Object { $_.Id -like "*$Query*" -or $_.Name -like "*$Query*" -or $_.Description -like "*$Query*" }
        }
        
        $matchingPackages += $matched
    }
    
    return $matchingPackages
}

function Get-PackageConfiguration {
    <#
    .SYNOPSIS
        Gets configuration for a specific package.
    
    .DESCRIPTION
        Retrieves the configuration settings for a specific package by ID.
    
    .PARAMETER PackageId
        The ID of the package to get configuration for.
    
    .OUTPUTS
        Hashtable containing package configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )
    
    foreach ($categoryName in $script:DotWinPackageCategories.Keys) {
        $package = $script:DotWinPackageCategories[$categoryName].Packages | Where-Object { $_.Id -eq $PackageId }
        if ($package) {
            return $package
        }
    }
    
    Write-Warning "Package not found: $PackageId"
    return $null
}

# Note: These functions are available when this config file is dot-sourced
# No Export-ModuleMember needed as this is a configuration file, not a module
