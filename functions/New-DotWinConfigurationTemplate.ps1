function New-DotWinConfigurationTemplate {
    <#
    .SYNOPSIS
        Generates pre-built DotWin configuration templates for common scenarios.

    .DESCRIPTION
        The New-DotWinConfigurationTemplate function creates ready-to-use configuration
        templates for common use cases like Developer, Gamer, Enterprise, and Minimal setups.
        These templates provide excellent starting points for users who want to quickly
        set up their systems without manually creating configurations.

    .PARAMETER Template
        The type of template to generate. Available options:
        - Developer: Complete development environment with tools and settings
        - Gamer: Gaming-optimized configuration with performance tweaks
        - Enterprise: Corporate security and compliance configuration
        - Minimal: Basic essential tools and clean system setup
        - Creative: Tools and settings for content creators and designers
        - Student: Educational tools and productivity applications

    .PARAMETER OutputPath
        Path where the template configuration file should be saved.

    .PARAMETER CustomizationLevel
        Level of customization in the template:
        - Basic: Essential items only
        - Standard: Recommended items (default)
        - Complete: All available items for the template type

    .PARAMETER IncludeOptional
        Include optional components that users can enable/disable as needed.

    .PARAMETER Force
        Overwrite existing template file if it exists.

    .PARAMETER ListTemplates
        List all available templates with descriptions.

    .PARAMETER WhatIf
        Show what template would be generated without actually creating the file.

    .EXAMPLE
        New-DotWinConfigurationTemplate -Template Developer -OutputPath "dev-setup.json"
        
        Creates a complete developer configuration template.

    .EXAMPLE
        New-DotWinConfigurationTemplate -Template Gamer -OutputPath "gaming-config.json" -CustomizationLevel Complete
        
        Creates a comprehensive gaming configuration with all optimizations.

    .EXAMPLE
        New-DotWinConfigurationTemplate -Template Enterprise -OutputPath "corp-baseline.json" -IncludeOptional
        
        Creates an enterprise template with optional security components.

    .EXAMPLE
        New-DotWinConfigurationTemplate -ListTemplates
        
        Lists all available templates with descriptions.

    .OUTPUTS
        String
        Returns the path to the created template file, or template information if -ListTemplates is used.

    .NOTES
        These templates are designed to be immediately usable but can also serve as
        starting points for further customization. Each template includes appropriate
        metadata and documentation.
    #>
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Generate')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Generate')]
        [ValidateSet('Developer', 'Gamer', 'Enterprise', 'Minimal', 'Creative', 'Student')]
        [string]$Template,

        [Parameter(Mandatory = $true, ParameterSetName = 'Generate')]
        [ValidateScript({
            $directory = Split-Path $_ -Parent
            if ($directory -and -not (Test-Path $directory)) {
                throw "Output directory '$directory' does not exist."
            }
            return $true
        })]
        [string]$OutputPath,

        [Parameter(ParameterSetName = 'Generate')]
        [ValidateSet('Basic', 'Standard', 'Complete')]
        [string]$CustomizationLevel = 'Standard',

        [Parameter(ParameterSetName = 'Generate')]
        [switch]$IncludeOptional,

        [Parameter(ParameterSetName = 'Generate')]
        [switch]$Force,

        [Parameter(Mandatory = $true, ParameterSetName = 'List')]
        [switch]$ListTemplates
    )

    begin {
        Write-DotWinLog "Starting configuration template generation" -Level "Information"
        $startTime = Get-Date

        # Define available templates
        $availableTemplates = @{
            Developer = @{
                Description = "Complete development environment with modern tools, WSL, and productivity enhancements"
                Category = "Development"
                EstimatedTime = "15-30 minutes"
                RequiredPrivileges = "Administrator"
                TargetAudience = "Software Developers, DevOps Engineers"
            }
            Gamer = @{
                Description = "Gaming-optimized configuration with performance tweaks and gaming tools"
                Category = "Gaming"
                EstimatedTime = "10-20 minutes"
                RequiredPrivileges = "Administrator"
                TargetAudience = "PC Gamers, Enthusiasts"
            }
            Enterprise = @{
                Description = "Corporate security baseline with compliance and management tools"
                Category = "Enterprise"
                EstimatedTime = "20-40 minutes"
                RequiredPrivileges = "Administrator"
                TargetAudience = "IT Administrators, Corporate Users"
            }
            Minimal = @{
                Description = "Essential tools and clean system setup with minimal bloatware"
                Category = "Basic"
                EstimatedTime = "5-10 minutes"
                RequiredPrivileges = "User"
                TargetAudience = "General Users, Minimalists"
            }
            Creative = @{
                Description = "Tools and optimizations for content creators, designers, and artists"
                Category = "Creative"
                EstimatedTime = "15-25 minutes"
                RequiredPrivileges = "Administrator"
                TargetAudience = "Content Creators, Designers, Artists"
            }
            Student = @{
                Description = "Educational tools, productivity apps, and study-focused configuration"
                Category = "Education"
                EstimatedTime = "10-15 minutes"
                RequiredPrivileges = "User"
                TargetAudience = "Students, Educators"
            }
        }

        # Check if output file exists and Force is not specified
        if ($PSCmdlet.ParameterSetName -eq 'Generate' -and (Test-Path $OutputPath) -and -not $Force) {
            throw "Template file '$OutputPath' already exists. Use -Force to overwrite."
        }
    }

    process {
        try {
            # Handle ListTemplates parameter
            if ($ListTemplates) {
                Write-Host "`nAvailable DotWin Configuration Templates:" -ForegroundColor Cyan
                Write-Host "=" * 50 -ForegroundColor Cyan
                
                foreach ($templateName in $availableTemplates.Keys | Sort-Object) {
                    $templateInfo = $availableTemplates[$templateName]
                    Write-Host "`n$templateName Template:" -ForegroundColor Yellow
                    Write-Host "  Description: $($templateInfo.Description)" -ForegroundColor White
                    Write-Host "  Category: $($templateInfo.Category)" -ForegroundColor Gray
                    Write-Host "  Target Audience: $($templateInfo.TargetAudience)" -ForegroundColor Gray
                    Write-Host "  Estimated Time: $($templateInfo.EstimatedTime)" -ForegroundColor Gray
                    Write-Host "  Required Privileges: $($templateInfo.RequiredPrivileges)" -ForegroundColor Gray
                }
                
                Write-Host "`nUsage Examples:" -ForegroundColor Cyan
                Write-Host "  New-DotWinConfigurationTemplate -Template Developer -OutputPath 'dev-setup.json'" -ForegroundColor Green
                Write-Host "  New-DotWinConfigurationTemplate -Template Gamer -OutputPath 'gaming.json' -CustomizationLevel Complete" -ForegroundColor Green
                Write-Host "  New-DotWinConfigurationTemplate -Template Enterprise -OutputPath 'corp.json' -IncludeOptional" -ForegroundColor Green
                
                return $availableTemplates
            }

            if ($PSCmdlet.ShouldProcess($OutputPath, "Generate $Template template")) {
                
                Write-DotWinLog "Generating $Template template with $CustomizationLevel customization level" -Level "Information"
                
                # Get template info
                $templateInfo = $availableTemplates[$Template]
                
                # Create base template structure
                $templateConfig = @{
                    name = "$Template Configuration Template"
                    version = "1.0.0"
                    description = $templateInfo.Description
                    metadata = @{
                        author = "DotWin Template Generator"
                        category = $templateInfo.Category
                        targetAudience = $templateInfo.TargetAudience
                        lastUpdated = (Get-Date).ToString("yyyy-MM-dd")
                        requiredPrivileges = $templateInfo.RequiredPrivileges
                        estimatedTime = $templateInfo.EstimatedTime
                        customizationLevel = $CustomizationLevel
                        templateType = $Template
                        generatedBy = "New-DotWinConfigurationTemplate"
                    }
                    items = @()
                    prerequisites = @()
                    postInstallInstructions = @()
                    validation = @{
                        tests = @()
                    }
                }

                # Generate template-specific configuration
                switch ($Template) {
                    'Developer' {
                        $templateConfig.items += @(
                            @{
                                name = "Essential Development Tools"
                                type = "SystemTools"
                                description = "Core development tools and utilities"
                                enabled = $true
                                properties = @{
                                    category = "Development"
                                    source = "winget"
                                    tools = @("Git.Git", "Microsoft.VisualStudioCode", "Microsoft.PowerShell", "Microsoft.WindowsTerminal")
                                    acceptLicenses = $true
                                }
                            },
                            @{
                                name = "Development Runtimes"
                                type = "Packages"
                                description = "Programming language runtimes and SDKs"
                                enabled = $true
                                properties = @{
                                    source = "winget"
                                    packages = @("OpenJS.NodeJS", "Python.Python.3.12", "GoLang.Go")
                                    acceptLicenses = $true
                                }
                            },
                            @{
                                name = "WSL Development Environment"
                                type = "WSLConfiguration"
                                description = "Windows Subsystem for Linux setup"
                                enabled = $true
                                properties = @{
                                    distribution = "Ubuntu-22.04"
                                    packages = @("build-essential", "curl", "git", "nodejs", "npm", "python3", "python3-pip")
                                }
                            }
                        )

                        if ($CustomizationLevel -eq 'Complete') {
                            $templateConfig.items += @(
                                @{
                                    name = "Advanced Development Tools"
                                    type = "Packages"
                                    description = "Additional development and productivity tools"
                                    enabled = $true
                                    properties = @{
                                        source = "winget"
                                        packages = @("Docker.DockerDesktop", "Postman.Postman", "JetBrains.Toolbox", "GitHub.GitHubDesktop")
                                    }
                                },
                                @{
                                    name = "Development Utilities"
                                    type = "Packages"
                                    description = "Useful utilities for developers"
                                    enabled = $true
                                    properties = @{
                                        source = "winget"
                                        packages = @("Microsoft.PowerToys", "Notepad++.Notepad++", "WinSCP.WinSCP", "PuTTY.PuTTY")
                                    }
                                }
                            )
                        }

                        $templateConfig.prerequisites = @(
                            "Windows 11 or Windows 10 version 1903+",
                            "Administrator privileges",
                            "At least 8GB RAM recommended",
                            "At least 50GB free disk space",
                            "Internet connection"
                        )

                        $templateConfig.postInstallInstructions = @(
                            "Configure Git with your personal information: git config --global user.name 'Your Name'",
                            "Configure Git with your email: git config --global user.email 'your.email@example.com'",
                            "Install VS Code extensions for your preferred languages",
                            "Set up SSH keys for Git repositories",
                            "Configure WSL development environment"
                        )
                    }

                    'Gamer' {
                        $templateConfig.items += @(
                            @{
                                name = "Gaming Performance Optimizations"
                                type = "PerformanceSettings"
                                description = "Optimize system for gaming performance"
                                enabled = $true
                                properties = @{
                                    powerPlan = "High Performance"
                                    enableGameMode = $true
                                    optimizeForGaming = $true
                                    disableFullscreenOptimizations = $false
                                }
                            },
                            @{
                                name = "Gaming Platforms"
                                type = "Packages"
                                description = "Popular gaming platforms and launchers"
                                enabled = $true
                                properties = @{
                                    source = "winget"
                                    packages = @("Valve.Steam", "EpicGames.EpicGamesLauncher", "Discord.Discord")
                                }
                            },
                            @{
                                name = "Gaming Utilities"
                                type = "Packages"
                                description = "Useful gaming utilities and tools"
                                enabled = $true
                                properties = @{
                                    source = "winget"
                                    packages = @("Microsoft.DirectX", "Microsoft.VCRedist.2015+.x64")
                                }
                            }
                        )

                        if ($CustomizationLevel -eq 'Complete') {
                            $templateConfig.items += @(
                                @{
                                    name = "Advanced Gaming Tools"
                                    type = "Packages"
                                    description = "Additional gaming and streaming tools"
                                    enabled = $true
                                    properties = @{
                                        source = "winget"
                                        packages = @("OBSProject.OBSStudio", "Nvidia.GeForceExperience", "AMD.AMDSoftwareAdrenalinEdition")
                                    }
                                },
                                @{
                                    name = "Gaming Hardware Optimization"
                                    type = "RegistryConfiguration"
                                    description = "Registry tweaks for gaming performance"
                                    enabled = $false
                                    properties = @{
                                        settings = @(
                                            @{
                                                path = "HKCU:\System\GameConfigStore"
                                                name = "GameDVR_Enabled"
                                                value = 0
                                                type = "DWORD"
                                                description = "Disable Game DVR for better performance"
                                            }
                                        )
                                    }
                                }
                            )
                        }

                        $templateConfig.prerequisites = @(
                            "Windows 11 or Windows 10",
                            "Dedicated graphics card recommended",
                            "At least 16GB RAM for modern games",
                            "High-speed internet connection",
                            "Sufficient storage space for games"
                        )
                    }

                    'Enterprise' {
                        $templateConfig.items += @(
                            @{
                                name = "Security Baseline"
                                type = "SecurityConfiguration"
                                description = "Enterprise security settings and policies"
                                enabled = $true
                                properties = @{
                                    enableFirewall = $true
                                    enableDefender = $true
                                    enableUAC = $true
                                    securityLevel = "High"
                                }
                            },
                            @{
                                name = "Enterprise Applications"
                                type = "Packages"
                                description = "Standard enterprise productivity applications"
                                enabled = $true
                                properties = @{
                                    source = "winget"
                                    packages = @("Microsoft.Office", "Adobe.Acrobat.Reader.64-bit", "7zip.7zip", "Mozilla.Firefox")
                                }
                            },
                            @{
                                name = "Windows Security Features"
                                type = "WindowsFeatures"
                                description = "Enable enterprise security features"
                                enabled = $true
                                properties = @{
                                    features = @("Windows-Defender", "Windows-Defender-ApplicationGuard")
                                }
                            }
                        )

                        $templateConfig.prerequisites = @(
                            "Windows 11 Pro/Enterprise or Windows 10 Pro/Enterprise",
                            "Domain-joined computer (recommended)",
                            "Administrator privileges",
                            "TPM 2.0 chip (for BitLocker)",
                            "Network connectivity to domain controllers"
                        )
                    }

                    'Minimal' {
                        $templateConfig.items += @(
                            @{
                                name = "Essential Applications"
                                type = "Packages"
                                description = "Basic essential applications"
                                enabled = $true
                                properties = @{
                                    source = "winget"
                                    packages = @("Mozilla.Firefox", "7zip.7zip", "Adobe.Acrobat.Reader.64-bit")
                                }
                            },
                            @{
                                name = "System Cleanup"
                                type = "BloatwareRemoval"
                                description = "Remove unnecessary pre-installed software"
                                enabled = $true
                                properties = @{
                                    removeBuiltinApps = $true
                                    cleanStartMenu = $true
                                }
                            },
                            @{
                                name = "Privacy Settings"
                                type = "TelemetryConfiguration"
                                description = "Disable unnecessary telemetry and tracking"
                                enabled = $true
                                properties = @{
                                    telemetryLevel = "Security"
                                    disableAdvertising = $true
                                }
                            }
                        )

                        $templateConfig.prerequisites = @(
                            "Windows 10 or Windows 11",
                            "Internet connection",
                            "Basic user privileges"
                        )
                    }

                    'Creative' {
                        $templateConfig.items += @(
                            @{
                                name = "Creative Applications"
                                type = "Packages"
                                description = "Essential creative and design tools"
                                enabled = $true
                                properties = @{
                                    source = "winget"
                                    packages = @("Adobe.CreativeCloud", "GIMP.GIMP", "Blender.Blender", "Audacity.Audacity")
                                }
                            },
                            @{
                                name = "Media Codecs and Tools"
                                type = "Packages"
                                description = "Media handling and codec packages"
                                enabled = $true
                                properties = @{
                                    source = "winget"
                                    packages = @("VideoLAN.VLC", "HandBrake.HandBrake", "FFmpeg.FFmpeg")
                                }
                            },
                            @{
                                name = "Creative Performance Settings"
                                type = "PerformanceSettings"
                                description = "Optimize system for creative workloads"
                                enabled = $true
                                properties = @{
                                    powerPlan = "High Performance"
                                    optimizeForCreative = $true
                                    enableHardwareAcceleration = $true
                                }
                            }
                        )

                        $templateConfig.prerequisites = @(
                            "Windows 10 or Windows 11",
                            "Dedicated graphics card recommended",
                            "At least 16GB RAM",
                            "High-resolution display recommended",
                            "Sufficient storage for media files"
                        )
                    }

                    'Student' {
                        $templateConfig.items += @(
                            @{
                                name = "Educational Applications"
                                type = "Packages"
                                description = "Essential applications for students"
                                enabled = $true
                                properties = @{
                                    source = "winget"
                                    packages = @("Microsoft.Office", "Notion.Notion", "Zoom.Zoom", "Anki.Anki")
                                }
                            },
                            @{
                                name = "Productivity Tools"
                                type = "Packages"
                                description = "Tools to enhance productivity and organization"
                                enabled = $true
                                properties = @{
                                    source = "winget"
                                    packages = @("Mozilla.Firefox", "7zip.7zip", "Notepad++.Notepad++")
                                }
                            },
                            @{
                                name = "Study Environment Settings"
                                type = "PerformanceSettings"
                                description = "Optimize system for study and productivity"
                                enabled = $true
                                properties = @{
                                    powerPlan = "Balanced"
                                    enableFocusAssist = $true
                                    optimizeForProductivity = $true
                                }
                            }
                        )

                        $templateConfig.prerequisites = @(
                            "Windows 10 or Windows 11",
                            "Internet connection",
                            "Microsoft account (for Office)",
                            "Sufficient storage for documents and media"
                        )
                    }
                }

                # Add optional components if requested
                if ($IncludeOptional) {
                    Write-DotWinLog "Adding optional components to template" -Level "Information"
                    
                    # Add common optional items that can be enabled/disabled
                    $templateConfig.items += @{
                        name = "Optional: Windows Terminal"
                        type = "Packages"
                        description = "Modern terminal application (optional)"
                        enabled = $false
                        properties = @{
                            source = "winget"
                            packages = @("Microsoft.WindowsTerminal")
                        }
                    }
                    
                    $templateConfig.items += @{
                        name = "Optional: PowerToys"
                        type = "Packages"
                        description = "Microsoft PowerToys utilities (optional)"
                        enabled = $false
                        properties = @{
                            source = "winget"
                            packages = @("Microsoft.PowerToys")
                        }
                    }
                }

                # Add validation tests
                $templateConfig.validation.tests = @(
                    @{
                        name = "Internet Connectivity"
                        command = "Test-NetConnection -ComputerName google.com -Port 80"
                        expectedOutput = "TcpTestSucceeded : True"
                    }
                )

                # Convert to JSON and save
                Write-DotWinLog "Saving template to: $OutputPath" -Level "Information"
                $jsonContent = $templateConfig | ConvertTo-Json -Depth 10
                Set-Content -Path $OutputPath -Value $jsonContent -Encoding UTF8
                
                Write-DotWinLog "$Template template generated successfully" -Level "Information"
                Write-DotWinLog "Template contains $($templateConfig.items.Count) configuration items" -Level "Information"
                Write-DotWinLog "Customization level: $CustomizationLevel" -Level "Information"
                
                return $OutputPath
            } else {
                Write-DotWinLog "Template generation cancelled (WhatIf)" -Level "Information"
                return $null
            }

        } catch {
            Write-DotWinLog "Error during template generation: $($_.Exception.Message)" -Level "Error"
            throw
        }
    }

    end {
        if ($PSCmdlet.ParameterSetName -eq 'Generate') {
            $totalDuration = (Get-Date) - $startTime
            Write-DotWinLog "Template generation completed in $($totalDuration.TotalSeconds) seconds" -Level "Information"
        }
    }
}
