<#
.SYNOPSIS
    Centralized mock data definitions for DotWin unit tests.

.DESCRIPTION
    This file contains all mock data used across DotWin unit tests, including
    sample system profiles, package manager outputs, WMI responses, and other
    test data needed for comprehensive testing.
#>

# Mock WMI/CIM Data
$script:MockWmiData = @{
    Win32_Processor = @{
        Manufacturer = 'GenuineIntel'
        Name = 'Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz'
        NumberOfCores = 8
        NumberOfLogicalProcessors = 16
        Architecture = 9  # x64
        MaxClockSpeed = 3800
        CurrentClockSpeed = 3800
    }
    
    Win32_ComputerSystem = @{
        TotalPhysicalMemory = 34359738368  # 32GB in bytes
        Manufacturer = 'ASUS'
        Model = 'System Product Name'
        Domain = 'WORKGROUP'
        UserName = 'TestUser'
        NumberOfProcessors = 1
    }
    
    Win32_BaseBoard = @{
        Manufacturer = 'ASUSTeK COMPUTER INC.'
        Product = 'PRIME Z490-A'
        SerialNumber = 'TestSerial123'
        Version = 'Rev 1.xx'
    }
    
    Win32_VideoController = @(
        @{
            Name = 'NVIDIA GeForce RTX 3080'
            AdapterRAM = 10737418240  # 10GB
            DriverVersion = '31.0.15.1659'
            VideoProcessor = 'GeForce RTX 3080'
        },
        @{
            Name = 'Intel(R) UHD Graphics 630'
            AdapterRAM = 1073741824  # 1GB
            DriverVersion = '27.20.100.8681'
            VideoProcessor = 'Intel(R) UHD Graphics Family'
        }
    )
    
    Win32_DiskDrive = @(
        @{
            Model = 'Samsung SSD 980 PRO 1TB'
            Size = 1000204886016  # ~1TB
            MediaType = 'Fixed hard disk media'
            InterfaceType = 'SCSI'
        },
        @{
            Model = 'Seagate ST2000DM008-2FR102'
            Size = 2000398934016  # ~2TB
            MediaType = 'Fixed hard disk media'
            InterfaceType = 'SCSI'
        }
    )
    
    Win32_NetworkAdapter = @(
        @{
            Name = 'Intel(R) Ethernet Connection (7) I219-V'
            NetEnabled = $true
            AdapterType = 'Ethernet 802.3'
            Speed = 1000000000  # 1Gbps
        },
        @{
            Name = 'Intel(R) Wi-Fi 6 AX200 160MHz'
            NetEnabled = $true
            AdapterType = 'Wireless'
            Speed = 2400000000  # 2.4Gbps
        }
    )
    
    Win32_OperatingSystem = @{
        Caption = 'Microsoft Windows 11 Pro'
        Version = '10.0.22621'
        BuildNumber = '22621'
        OSArchitecture = '64-bit'
        TotalVisibleMemorySize = 33554432  # 32GB in KB
        FreePhysicalMemory = 16777216  # 16GB in KB
        LastBootUpTime = (Get-Date).AddDays(-2)
        InstallDate = (Get-Date).AddMonths(-6)
    }
}

# Mock Package Manager Data
$script:MockPackageData = @{
    Winget = @{
        ListOutput = @"
Name                           Id                           Version      Available Source
-------------------------------------------------------------------------------------------
Git                            Git.Git                      2.50.0       2.51.0    winget
Microsoft Visual Studio Code  Microsoft.VisualStudioCode  1.80.0       1.81.0    winget
Windows Terminal               Microsoft.WindowsTerminal   1.17.0       1.18.0    winget
Google Chrome                  Google.Chrome                114.0.5735   115.0.5790 winget
7-Zip                          7zip.7zip                    23.01        23.01     winget
"@
        
        ShowGitOutput = @"
Found Git [Git.Git]
Version: 2.50.0
Publisher: The Git Development Community
Author: The Git Development Community
Moniker: git
Description: Git is a free and open source distributed version control system designed to handle everything from small to very large projects with speed and efficiency.
Homepage: https://git-scm.com/
License: GPL-2.0-only
License Url: https://raw.githubusercontent.com/git/git/master/COPYING
Copyright: Copyright (C) 2005-2023 The Git Development Community
"@
        
        InstallSuccessExitCode = 0
        InstallFailureExitCode = 1
        
        VersionOutput = 'v1.5.2011'
    }
    
    Chocolatey = @{
        ListOutput = @"
Chocolatey v1.4.0
chocolatey 1.4.0
chocolatey-core.extension 1.3.5.1
chocolatey-dotnetfx.extension 1.0.1
chocolatey-windowsupdate.extension 1.0.4
git 2.40.0
vscode 1.80.0
"@
        
        VersionOutput = 'Chocolatey v1.4.0'
        InstallSuccessExitCode = 0
        InstallFailureExitCode = 1
    }
}

# Mock Registry Data
$script:MockRegistryData = @{
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' = @{
        '{Git_is1}' = @{
            DisplayName = 'Git version 2.40.0'
            DisplayVersion = '2.40.0'
            Publisher = 'The Git Development Community'
            InstallDate = '20230515'
        }
        '{VSCode_is1}' = @{
            DisplayName = 'Microsoft Visual Studio Code'
            DisplayVersion = '1.80.0'
            Publisher = 'Microsoft Corporation'
            InstallDate = '20230520'
        }
    }
    
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RecentDocs' = @{
        '.txt' = @('document1.txt', 'document2.txt')
        '.ps1' = @('script1.ps1', 'script2.ps1')
    }
    
    'HKLM:\SYSTEM\CurrentControlSet\Control\Power' = @{
        CsEnabled = 1
        HibernateEnabled = 1
    }
}

# Mock File System Data
$script:MockFileSystemData = @{
    Files = @{
        'C:\Program Files\Git\bin\git.exe' = @{
            Exists = $true
            Version = '2.40.0'
            LastWriteTime = (Get-Date).AddDays(-30)
        }
        'C:\Users\TestUser\AppData\Local\Programs\Microsoft VS Code\Code.exe' = @{
            Exists = $true
            Version = '1.80.0'
            LastWriteTime = (Get-Date).AddDays(-25)
        }
        'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe' = @{
            Exists = $true
            Version = '5.1.22621.1778'
            LastWriteTime = (Get-Date).AddDays(-100)
        }
    }
    
    Directories = @{
        'C:\Program Files\Git' = $true
        'C:\Users\TestUser\AppData\Local\Programs\Microsoft VS Code' = $true
        'C:\ProgramData\chocolatey' = $false
        'C:\tools' = $false
    }
}

# Mock Windows Features Data
$script:MockWindowsFeaturesData = @(
    @{
        FeatureName = 'Microsoft-Windows-Subsystem-Linux'
        State = 'Enabled'
        RestartRequired = 'Possible'
    },
    @{
        FeatureName = 'VirtualMachinePlatform'
        State = 'Enabled'
        RestartRequired = 'Possible'
    },
    @{
        FeatureName = 'Microsoft-Hyper-V-All'
        State = 'Disabled'
        RestartRequired = 'Possible'
    },
    @{
        FeatureName = 'IIS-WebServerRole'
        State = 'Disabled'
        RestartRequired = 'Possible'
    }
)

# Mock PowerShell Module Data
$script:MockPowerShellModules = @(
    @{
        Name = 'Pester'
        Version = [Version]'5.5.0'
        ModuleBase = 'C:\Program Files\WindowsPowerShell\Modules\Pester\5.5.0'
        Description = 'Pester provides a framework for running BDD style Tests to execute and validate PowerShell commands'
    },
    @{
        Name = 'PSReadLine'
        Version = [Version]'2.2.6'
        ModuleBase = 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.6'
        Description = 'Great command line editing in the PowerShell console host'
    },
    @{
        Name = 'PowerShellGet'
        Version = [Version]'2.2.5'
        ModuleBase = 'C:\Program Files\WindowsPowerShell\Modules\PowerShellGet\2.2.5'
        Description = 'PowerShell module with commands for discovering, installing, updating and publishing the PowerShell artifacts'
    }
)

# Mock System Profile Data
$script:MockSystemProfile = @{
    Hardware = @{
        CPU_Manufacturer = 'GenuineIntel'
        CPU_Model = 'Intel(R) Core(TM) i7-10700K CPU @ 3.80GHz'
        CPU_Cores = 8
        CPU_LogicalProcessors = 16
        CPU_Architecture = 9
        TotalMemoryGB = 32.0
        Motherboard_Manufacturer = 'ASUSTeK COMPUTER INC.'
        Motherboard_Model = 'PRIME Z490-A'
        Chipset = 'Intel Z490'
        GPU_Manufacturers = @('NVIDIA', 'Intel')
        GPU_Models = @('NVIDIA GeForce RTX 3080', 'Intel(R) UHD Graphics 630')
        Storage_Types = @('SSD', 'HDD')
        Storage_TotalGB = 3000.0
        Network_Adapters = @('Intel(R) Ethernet Connection (7) I219-V', 'Intel(R) Wi-Fi 6 AX200 160MHz')
        ProfiledAt = Get-Date
    }
    
    Software = @{
        InstalledPackages = @{
            'Git.Git' = @{ Version = '2.50.0'; Source = 'Winget' }
            'Microsoft.VisualStudioCode' = @{ Version = '1.80.0'; Source = 'Winget' }
            'Microsoft.WindowsTerminal' = @{ Version = '1.17.0'; Source = 'Winget' }
        }
        PowerShellModules = @{
            'Pester' = @{ Version = '5.5.0'; Path = 'C:\Program Files\WindowsPowerShell\Modules\Pester\5.5.0' }
            'PSReadLine' = @{ Version = '2.2.6'; Path = 'C:\Program Files\WindowsPowerShell\Modules\PSReadLine\2.2.6' }
        }
        WindowsFeatures = @{
            'Microsoft-Windows-Subsystem-Linux' = @{ State = 'Enabled' }
            'VirtualMachinePlatform' = @{ State = 'Enabled' }
            'Microsoft-Hyper-V-All' = @{ State = 'Disabled' }
        }
        DevelopmentTools = @('Git', 'Python', 'Logitech', 'GitHub', 'Docker')
        ProductivityTools = @()
        MediaTools = @()
        GamingTools = @()
        SecurityTools = @()
        PackageManagers = @{
            'Winget' = @{ Available = $true; Version = 'v1.5.2011' }
            'Chocolatey' = @{ Available = $false; Version = $null }
        }
        ProfiledAt = Get-Date
    }
    
    User = @{
        Username = 'TestUser'
        Domain = 'WORKGROUP'
        IsAdministrator = $false
        EnvironmentVariables = @{
            'PATH' = 'C:\Windows\system32;C:\Windows;C:\Program Files\Git\bin'
            'USERPROFILE' = 'C:\Users\TestUser'
            'COMPUTERNAME' = 'TEST-PC'
        }
        RecentApplications = @('Git', 'Visual Studio Code', 'PowerShell')
        PreferredShell = 'PowerShell'
        ProfiledAt = Get-Date
    }
    
    SystemMetrics = @{
        PerformanceScore = 85
        SecurityScore = 70
        DeveloperFriendliness = 80
        OptimizationPotential = 15
        SystemComplexity = 25
    }
}

# Mock Plugin Data
$script:MockPluginData = @{
    SamplePlugin = @{
        Name = 'TestPlugin'
        Version = '1.0.0'
        Author = 'Test Author'
        Description = 'A test plugin for unit testing'
        Category = 'Configuration'
        Enabled = $true
        Dependencies = @()
        SupportedPlatforms = @('Windows')
        Metadata = @{
            SourceFile = 'TestPlugin.ps1'
            LoadedAt = Get-Date
        }
    }
}

# Mock Recommendation Data
$script:MockRecommendationData = @(
    @{
        Id = [System.Guid]::NewGuid().ToString()
        Title = 'Install Essential Developer Tools'
        Description = 'Install Git, Visual Studio Code, and Windows Terminal for development'
        Category = 'Software'
        Priority = 'High'
        ConfidenceScore = 0.9
        Implementation = @{
            Type = 'Package'
            Packages = @('Git.Git', 'Microsoft.VisualStudioCode', 'Microsoft.WindowsTerminal')
        }
        Prerequisites = @()
        CreatedAt = Get-Date
    },
    @{
        Id = [System.Guid]::NewGuid().ToString()
        Title = 'Enable High Performance Power Plan'
        Description = 'Configure Windows to use High Performance power plan for maximum performance'
        Category = 'Hardware'
        Priority = 'Medium'
        ConfidenceScore = 0.8
        Implementation = @{
            Type = 'PowerShell'
            Command = 'powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
        }
        Prerequisites = @('Administrator')
        CreatedAt = Get-Date
    }
)

# Helper functions to get mock data
function Get-MockWmiData {
    param([string]$ClassName)
    return $script:MockWmiData[$ClassName]
}

function Get-MockPackageData {
    param([string]$Manager)
    return $script:MockPackageData[$Manager]
}

function Get-MockRegistryData {
    param([string]$Path)
    return $script:MockRegistryData[$Path]
}

function Get-MockFileSystemData {
    param([string]$Type, [string]$Path)
    if ($Type -eq 'File') {
        return $script:MockFileSystemData.Files[$Path]
    } elseif ($Type -eq 'Directory') {
        return $script:MockFileSystemData.Directories[$Path]
    }
}

function Get-MockSystemProfile {
    return $script:MockSystemProfile
}

function Get-MockRecommendations {
    return $script:MockRecommendationData
}

function Get-MockWindowsFeatures {
    return $script:MockWindowsFeaturesData
}

function Get-MockPowerShellModules {
    return $script:MockPowerShellModules
}

function Get-MockPluginData {
    return $script:MockPluginData
}

# Functions are available when dot-sourced - no need to export
# Export-ModuleMember is only used when this file is imported as a module
