function Install-SystemTools {
    <#
    .SYNOPSIS
        Installs essential system tools and utilities for Windows 11 configuration management.

    .DESCRIPTION
        The Install-SystemTools function installs a curated collection of essential
        system tools and utilities that enhance Windows 11 functionality and support
        the DotWin configuration management system. Tools include system monitoring,
        development utilities, and administrative tools.

    .PARAMETER ToolCategory
        Specifies the category of tools to install. Valid values are:
        'All', 'Development', 'System', 'Network', 'Security', 'Productivity'
        Default is 'All'.

    .PARAMETER ToolNames
        Specifies specific tool names to install. Use Get-SystemToolsList to see available tools.

    .PARAMETER Source
        Specifies the installation source. Valid values are:
        'Winget', 'Chocolatey', 'Manual', 'All'
        Default is 'Winget'.

    .PARAMETER Force
        Forces installation even if tools are already installed.

    .PARAMETER WhatIf
        Shows what would happen if the command runs without actually installing tools.

    .PARAMETER SkipVerification
        Skips post-installation verification of tools.

    .EXAMPLE
        Install-SystemTools

        Installs all essential system tools using Winget.

    .EXAMPLE
        Install-SystemTools -ToolCategory Development -Source Winget

        Installs development tools using Winget package manager.

    .EXAMPLE
        Install-SystemTools -ToolNames @('git', 'vscode', 'powershell') -WhatIf

        Shows what would happen when installing specific tools.

    .OUTPUTS
        [DotWinExecutionResult[]] Array of installation results for each tool.

    .NOTES
        Requires administrator privileges for some tool installations.
        Internet connection required for package manager installations.
        Some tools may require system restart after installation.
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('All', 'Development', 'System', 'Network', 'Security', 'Productivity')]
        [string]$ToolCategory = 'All',

        [Parameter(Mandatory = $false)]
        [string[]]$ToolNames,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Winget', 'Chocolatey', 'Manual', 'All')]
        [string]$Source = 'Winget',

        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$SkipVerification
    )

    begin {
    Write-Verbose "Starting system tools installation..."
    
    # Define system tools catalog
    $systemToolsCatalog = @{
        Development = @{
            'git' = @{
                Name = 'Git'
                Description = 'Distributed version control system'
                WingetId = 'Git.Git'
                ChocolateyId = 'git'
                Executable = 'git.exe'
                VerifyCommand = 'git --version'
                Category = 'Development'
                Essential = $true
            }
            'vscode' = @{
                Name = 'Visual Studio Code'
                Description = 'Lightweight code editor'
                WingetId = 'Microsoft.VisualStudioCode'
                ChocolateyId = 'vscode'
                Executable = 'code.exe'
                VerifyCommand = 'code --version'
                Category = 'Development'
                Essential = $true
            }
            'powershell' = @{
                Name = 'PowerShell Core'
                Description = 'Cross-platform PowerShell'
                WingetId = 'Microsoft.PowerShell'
                ChocolateyId = 'powershell-core'
                Executable = 'pwsh.exe'
                VerifyCommand = 'pwsh --version'
                Category = 'Development'
                Essential = $true
            }
            'nodejs' = @{
                Name = 'Node.js'
                Description = 'JavaScript runtime'
                WingetId = 'OpenJS.NodeJS'
                ChocolateyId = 'nodejs'
                Executable = 'node.exe'
                VerifyCommand = 'node --version'
                Category = 'Development'
                Essential = $false
            }
            'python' = @{
                Name = 'Python'
                Description = 'Python programming language'
                WingetId = 'Python.Python.3.12'
                ChocolateyId = 'python'
                Executable = 'python.exe'
                VerifyCommand = 'python --version'
                Category = 'Development'
                Essential = $false
            }
        }
        
        System = @{
            'sysinternals' = @{
                Name = 'Sysinternals Suite'
                Description = 'Microsoft Sysinternals utilities'
                WingetId = 'Microsoft.Sysinternals'
                ChocolateyId = 'sysinternals'
                Executable = 'procexp.exe'
                VerifyCommand = 'where procexp'
                Category = 'System'
                Essential = $true
            }
            'powertoys' = @{
                Name = 'PowerToys'
                Description = 'Windows system utilities'
                WingetId = 'Microsoft.PowerToys'
                ChocolateyId = 'powertoys'
                Executable = 'PowerToys.exe'
                VerifyCommand = 'where PowerToys'
                Category = 'System'
                Essential = $true
            }
            'winrar' = @{
                Name = 'WinRAR'
                Description = 'File archiver'
                WingetId = 'RARLab.WinRAR'
                ChocolateyId = 'winrar'
                Executable = 'winrar.exe'
                VerifyCommand = 'where winrar'
                Category = 'System'
                Essential = $false
            }
            'notepadplusplus' = @{
                Name = 'Notepad++'
                Description = 'Advanced text editor'
                WingetId = 'Notepad++.Notepad++'
                ChocolateyId = 'notepadplusplus'
                Executable = 'notepad++.exe'
                VerifyCommand = 'where notepad++'
                Category = 'System'
                Essential = $true
            }
        }
        
        Network = @{
            'wireshark' = @{
                Name = 'Wireshark'
                Description = 'Network protocol analyzer'
                WingetId = 'WiresharkFoundation.Wireshark'
                ChocolateyId = 'wireshark'
                Executable = 'wireshark.exe'
                VerifyCommand = 'where wireshark'
                Category = 'Network'
                Essential = $false
            }
            'putty' = @{
                Name = 'PuTTY'
                Description = 'SSH and telnet client'
                WingetId = 'PuTTY.PuTTY'
                ChocolateyId = 'putty'
                Executable = 'putty.exe'
                VerifyCommand = 'where putty'
                Category = 'Network'
                Essential = $true
            }
            'curl' = @{
                Name = 'cURL'
                Description = 'Command line tool for transferring data'
                WingetId = 'cURL.cURL'
                ChocolateyId = 'curl'
                Executable = 'curl.exe'
                VerifyCommand = 'curl --version'
                Category = 'Network'
                Essential = $true
            }
        }
        
        Security = @{
            'gpg4win' = @{
                Name = 'Gpg4win'
                Description = 'GNU Privacy Guard for Windows'
                WingetId = 'GnuPG.Gpg4win'
                ChocolateyId = 'gpg4win'
                Executable = 'gpg.exe'
                VerifyCommand = 'gpg --version'
                Category = 'Security'
                Essential = $false
            }
        }
        
        Productivity = @{
            'firefox' = @{
                Name = 'Mozilla Firefox'
                Description = 'Web browser'
                WingetId = 'Mozilla.Firefox'
                ChocolateyId = 'firefox'
                Executable = 'firefox.exe'
                VerifyCommand = 'where firefox'
                Category = 'Productivity'
                Essential = $false
            }
            'vlc' = @{
                Name = 'VLC Media Player'
                Description = 'Multimedia player'
                WingetId = 'VideoLAN.VLC'
                ChocolateyId = 'vlc'
                Executable = 'vlc.exe'
                VerifyCommand = 'where vlc'
                Category = 'Productivity'
                Essential = $false
            }
        }
    }
    
    # Helper function to check if a tool is installed
    function Test-ToolInstalled {
        param(
            [hashtable]$Tool
        )
        
        try {
            if ($Tool.VerifyCommand) {
                $result = Invoke-Expression $Tool.VerifyCommand 2>$null
                return $LASTEXITCODE -eq 0 -and $result
            } else {
                # Fallback to checking if executable exists in PATH
                $executable = Get-Command $Tool.Executable -ErrorAction SilentlyContinue
                return $null -ne $executable
            }
        }
        catch {
            return $false
        }
    }
    
    # Helper function to install tool via Winget
    function Install-ToolViaWinget {
        param(
            [hashtable]$Tool
        )
        
        try {
            Write-Verbose "Installing $($Tool.Name) via Winget..."
            
            if ($PSCmdlet.ShouldProcess($Tool.Name, "Install via Winget")) {
                $arguments = @('install', '--id', $Tool.WingetId, '--silent', '--accept-package-agreements', '--accept-source-agreements')
                
                if ($Force) {
                    $arguments += '--force'
                }
                
                $process = Start-Process -FilePath 'winget' -ArgumentList $arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput 'winget_output.txt' -RedirectStandardError 'winget_error.txt'
                
                $commandOutput = if (Test-Path 'winget_output.txt') { Get-Content 'winget_output.txt' -Raw } else { '' }
                $commandError = if (Test-Path 'winget_error.txt') { Get-Content 'winget_error.txt' -Raw } else { '' }
                
                # Clean up temp files
                Remove-Item 'winget_output.txt', 'winget_error.txt' -ErrorAction SilentlyContinue
                
                $success = $process.ExitCode -eq 0
                
                return [PSCustomObject]@{
                    Success = $success
                    ExitCode = $process.ExitCode
                    Output = $commandOutput
                    Error = $commandError
                    Method = 'Winget'
                }
            } else {
                return [PSCustomObject]@{
                    Success = $true
                    ExitCode = 0
                    Output = "WhatIf: Would install via Winget"
                    Error = ''
                    Method = 'Winget'
                }
            }
        }
        catch {
            return [PSCustomObject]@{
                Success = $false
                ExitCode = -1
                Output = ''
                Error = $_.Exception.Message
                Method = 'Winget'
            }
        }
    }
    
    # Helper function to install tool via Chocolatey
    function Install-ToolViaChocolatey {
        param(
            [hashtable]$Tool
        )
        
        try {
            Write-Verbose "Installing $($Tool.Name) via Chocolatey..."
            
            # Check if Chocolatey is installed
            $chocoCommand = Get-Command 'choco' -ErrorAction SilentlyContinue
            if (-not $chocoCommand) {
                throw "Chocolatey is not installed. Please install Chocolatey first."
            }
            
            if ($PSCmdlet.ShouldProcess($Tool.Name, "Install via Chocolatey")) {
                $arguments = @('install', $Tool.ChocolateyId, '-y')
                
                if ($Force) {
                    $arguments += '--force'
                }
                
                $process = Start-Process -FilePath 'choco' -ArgumentList $arguments -Wait -PassThru -NoNewWindow -RedirectStandardOutput 'choco_output.txt' -RedirectStandardError 'choco_error.txt'
                
                $commandOutput = if (Test-Path 'choco_output.txt') { Get-Content 'choco_output.txt' -Raw } else { '' }
                $commandError = if (Test-Path 'choco_error.txt') { Get-Content 'choco_error.txt' -Raw } else { '' }
                
                # Clean up temp files
                Remove-Item 'choco_output.txt', 'choco_error.txt' -ErrorAction SilentlyContinue
                
                $success = $process.ExitCode -eq 0
                
                return [PSCustomObject]@{
                    Success = $success
                    ExitCode = $process.ExitCode
                    Output = $commandOutput
                    Error = $commandError
                    Method = 'Chocolatey'
                }
            } else {
                return [PSCustomObject]@{
                    Success = $true
                    ExitCode = 0
                    Output = "WhatIf: Would install via Chocolatey"
                    Error = ''
                    Method = 'Chocolatey'
                }
            }
        }
        catch {
            return [PSCustomObject]@{
                Success = $false
                ExitCode = -1
                Output = ''
                Error = $_.Exception.Message
                Method = 'Chocolatey'
            }
        }
    }
}

process {
    try {
        $startTime = Get-Date
        $installResults = @()
        
        # Determine which tools to install
        $toolsToInstall = @()
        
        if ($ToolNames) {
            # Install specific tools by name
            foreach ($toolName in $ToolNames) {
                $found = $false
                foreach ($category in $systemToolsCatalog.Keys) {
                    if ($systemToolsCatalog[$category].ContainsKey($toolName)) {
                        $toolsToInstall += $systemToolsCatalog[$category][$toolName]
                        $found = $true
                        break
                    }
                }
                if (-not $found) {
                    Write-Warning "Tool '$toolName' not found in catalog"
                }
            }
        } else {
            # Install tools by category
            $categoriesToInstall = if ($ToolCategory -eq 'All') { 
                $systemToolsCatalog.Keys 
            } else { 
                @($ToolCategory) 
            }
            
            foreach ($category in $categoriesToInstall) {
                foreach ($toolKey in $systemToolsCatalog[$category].Keys) {
                    $tool = $systemToolsCatalog[$category][$toolKey]
                    
                    # Only install essential tools by default, unless Force is specified
                    if ($tool.Essential -or $Force) {
                        $toolsToInstall += $tool
                    }
                }
            }
        }
        
        Write-Verbose "Found $($toolsToInstall.Count) tools to install"
        
        # Install each tool
        foreach ($tool in $toolsToInstall) {
            Write-Progress -Activity "Installing System Tools" -Status "Installing $($tool.Name)" -PercentComplete (($installResults.Count / $toolsToInstall.Count) * 100)
            
            # Check if tool is already installed
            $isInstalled = Test-ToolInstalled -Tool $tool
            
            if ($isInstalled -and -not $Force) {
                Write-Verbose "$($tool.Name) is already installed, skipping..."
                
                $installResults += [DotWinExecutionResult]::new(
                    $true,
                    $tool.Name,
                    "Tool is already installed"
                )
                $installResults[-1].ItemType = "SystemTool"
                $installResults[-1].Changes["AlreadyInstalled"] = $true
                continue
            }
            
            # Install the tool
            $installResult = $null
            
            switch ($Source) {
                'Winget' {
                    if ($tool.WingetId) {
                        $installResult = Install-ToolViaWinget -Tool $tool
                    } else {
                        Write-Warning "$($tool.Name) does not have a Winget package ID"
                        continue
                    }
                }
                
                'Chocolatey' {
                    if ($tool.ChocolateyId) {
                        $installResult = Install-ToolViaChocolatey -Tool $tool
                    } else {
                        Write-Warning "$($tool.Name) does not have a Chocolatey package ID"
                        continue
                    }
                }
                
                'All' {
                    # Try Winget first, then Chocolatey
                    if ($tool.WingetId) {
                        $installResult = Install-ToolViaWinget -Tool $tool
                    } elseif ($tool.ChocolateyId) {
                        $installResult = Install-ToolViaChocolatey -Tool $tool
                    } else {
                        Write-Warning "$($tool.Name) does not have package manager support"
                        continue
                    }
                }
                
                'Manual' {
                    Write-Warning "Manual installation not implemented for $($tool.Name)"
                    continue
                }
            }
            
            # Create execution result
            $executionResult = [DotWinExecutionResult]::new(
                $installResult.Success,
                $tool.Name,
                $(if ($installResult.Success) { "Tool installed successfully via $($installResult.Method)" } else { "Tool installation failed: $($installResult.Error)" })
            )
            $executionResult.ItemType = "SystemTool"
            $executionResult.Changes["InstallMethod"] = $installResult.Method
            $executionResult.Changes["ExitCode"] = $installResult.ExitCode
            $executionResult.Changes["Category"] = $tool.Category
            
            # Verify installation if not skipped
            if ($installResult.Success -and -not $SkipVerification -and -not $WhatIfPreference) {
                Start-Sleep -Seconds 2 # Give the installation time to complete
                $verificationResult = Test-ToolInstalled -Tool $tool
                $executionResult.Changes["Verified"] = $verificationResult
                
                if (-not $verificationResult) {
                    $executionResult.Success = $false
                    $executionResult.Message += " (Verification failed)"
                }
            }
            
            $installResults += $executionResult
        }
        
        Write-Progress -Activity "Installing System Tools" -Completed
        
        # Calculate total duration
        $endTime = Get-Date
        $totalDuration = $endTime - $startTime
        
        # Update duration for all results
        foreach ($result in $installResults) {
            $result.Duration = $totalDuration
        }
        
        # Summary
        $successCount = ($installResults | Where-Object { $_.Success }).Count
        $failureCount = ($installResults | Where-Object { -not $_.Success }).Count
        
        Write-Information "System tools installation completed: $successCount successful, $failureCount failed"
        
        return $installResults
    }
    catch {
        $errorResult = [DotWinExecutionResult]::new(
            $false,
            "SystemToolsInstallation",
            "System tools installation failed: $($_.Exception.Message)"
        )
        $errorResult.ItemType = "SystemTool"
        $errorResult.Duration = (Get-Date) - $startTime
        
        Write-Error $_.Exception.Message
        return $errorResult
    }
}

    end {
        Write-Verbose "System tools installation process completed."
    }
}