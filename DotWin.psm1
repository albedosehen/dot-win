<#
.SYNOPSIS
    DotWin PowerShell Module - Windows 11 Configuration Management System

.DESCRIPTION
    DotWin is a declarative configuration management system for Windows 11,
    similar to NixOS dotfiles or Terraform. This module provides the core
    functionality for managing system configurations in a reproducible way.

.NOTES
    Created on:   6/9/2025 10:37 PM
    Created by:   Shon Thomas (albedosehen)
    Module Name:  DotWin
#>

#Requires -Version 5.1

# Import configuration classes using multiple approaches to ensure availability across all contexts
try {
    # Force clear any existing class definitions
    if (Get-Command -Name 'Remove-TypeData' -ErrorAction SilentlyContinue) {
        try {
            Remove-TypeData -TypeName 'DotWinExecutionResult' -ErrorAction SilentlyContinue
        } catch { }
    }

    # Method 1: Load in global scope
    $global:ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create(". '$PSScriptRoot\Classes.ps1'"), $null, $null)

    # Method 2: Also load in current module scope
    . "$PSScriptRoot\Classes.ps1"

    # Method 3: Force load using Add-Type equivalent for PowerShell classes
    $classContent = Get-Content "$PSScriptRoot\Classes.ps1" -Raw
    Invoke-Expression $classContent

    # Method 4: Force load in script scope
    $ExecutionContext.InvokeCommand.InvokeScript($false, [scriptblock]::Create($classContent), $null, $null)

    Write-Verbose "DotWin classes loaded successfully using multiple methods"

    # Verify the class was loaded correctly
    try {
        $testResult = [DotWinExecutionResult]::new()
        if (-not ($testResult.PSObject.Properties.Name -contains 'ItemType')) {
            throw "DotWinExecutionResult class missing ItemType property"
        }
        if (-not ($testResult.PSObject.Properties.Name -contains 'Duration')) {
            throw "DotWinExecutionResult class missing Duration property"
        }
        Write-Verbose "DotWin classes validation successful"
    } catch {
        Write-Error "DotWin class validation failed: $($_.Exception.Message)"
        throw
    }
} catch {
    Write-Error "Failed to load DotWin classes: $($_.Exception.Message)"
    throw
}

# Initialize progress system
try {
    $script:ProgressStackManager = [DotWinProgressStackManager]::new()
    Write-Verbose "Progress stack manager initialized successfully"
} catch {
    Write-Warning "Failed to initialize progress stack manager: $($_.Exception.Message)"
    $script:ProgressStackManager = $null
}

# Module variables
$script:DotWinModuleRoot = $PSScriptRoot
$script:DotWinConfigPath = Join-Path $PSScriptRoot "config"
$script:DotWinAppsPath = Join-Path $PSScriptRoot "apps"

# Initialize module logging
$script:DotWinLogLevel = "Information"
$script:DotWinLogPath = $null

# Module initialization
Write-Verbose "Initializing DotWin module..."
Write-Verbose "Module root: $script:DotWinModuleRoot"
Write-Verbose "Config path: $script:DotWinConfigPath"
Write-Verbose "Apps path: $script:DotWinAppsPath"

# Import all public functions
$PublicFunctions = @(
    'Invoke-DotWinConfiguration',
    'Get-DotWinStatus',
    'Install-Packages',
    'Install-Applications',
    'Install-SystemTools',
    'Install-ChipsetDriver',
    'Enable-Features',
    'Disable-Telemetry',
    'Remove-Bloatware',
    'Set-PowershellProfile',
    'Set-TerminalProfile',
    'Get-ChipsetInformation',
    'Search-ChipsetDriver',
    'Get-DotWinSystemProfile',
    'Get-DotWinRecommendations',
    'Invoke-DotWinProfiledConfiguration',
    'Get-DotWinSystemHealth',
    'Test-DotWinConfiguration',
    'Register-DotWinPlugin',
    'Get-DotWinPlugin',
    'Unregister-DotWinPlugin',
    'Enable-DotWinPlugin',
    'Disable-DotWinPlugin',
    'Get-DotWinModuleInfo',
    'Test-DotWinEnvironment',
    'ConvertTo-DotWinConfiguration',
    'Export-DotWinConfiguration',
    'New-DotWinConfigurationTemplate'
)

# Progress system functions (exported for public use)
$ProgressFunctions = @(
    'Write-DotWinProgress',
    'Start-DotWinProgress',
    'Complete-DotWinProgress'
)

foreach ($Function in $PublicFunctions) {
    $FunctionPath = Join-Path $PSScriptRoot "functions\$Function.ps1"
    if (Test-Path $FunctionPath) {
        Write-Verbose "Loading function: $Function"
        . $FunctionPath
    } else {
        Write-Warning "Function file not found: $FunctionPath"
    }
}

# Internal helper functions
function Write-DotWinLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",

        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error', 'Verbose')]
        [string]$Level = 'Information',

        # New parameters for progress coordination
        [Parameter()]
        [switch]$ShowWithProgress,

        [Parameter()]
        [string]$ProgressId
    )

    if (-not $PSBoundParameters.ContainsKey('Message') -or [string]::IsNullOrWhiteSpace($Message)) {
        return  # Just do nothing if Message is missing or empty
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Enhanced logic to coordinate with progress display
    if ($script:ProgressStackManager -and $script:ProgressStackManager.IsProgressActive) {
        if ($Level -in @('Warning', 'Error') -or $ShowWithProgress) {
            $script:ProgressStackManager.ShowMessage($logMessage, $Level)
        } elseif ($VerbosePreference -ne 'SilentlyContinue' -or $DebugPreference -ne 'SilentlyContinue') {
            $script:ProgressStackManager.ShowMessage($logMessage, $Level)
        }
        # Otherwise, message is suppressed during progress display
    } else {
        # Original logging behavior when no progress is active
        switch ($Level) {
            'Information' { Write-Information $logMessage -InformationAction Continue }
            'Warning' { Write-Warning $logMessage }
            'Error' { Write-Error $logMessage }
            'Verbose' { Write-Verbose $logMessage }
        }
    }

    if ($script:DotWinLogPath -and (Test-Path (Split-Path $script:DotWinLogPath -Parent))) {
        Add-Content -Path $script:DotWinLogPath -Value $logMessage
    }
}

# Core progress functions
function Write-DotWinProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Activity,

        [Parameter()]
        [string]$Status,

        [Parameter()]
        [int]$PercentComplete = -1,

        [Parameter()]
        [int]$CurrentOperation = -1,

        [Parameter()]
        [int]$TotalOperations = -1,

        [Parameter()]
        [string]$ParentId,

        [Parameter()]
        [string]$ProgressId,

        [Parameter()]
        [switch]$Completed,

        [Parameter()]
        [hashtable]$Metrics,

        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$MessageLevel = 'Information',

        [Parameter()]
        [string]$Message,

        [Parameter()]
        [switch]$ShowMetrics,

        [Parameter()]
        [switch]$Force
    )

    # Validate parameters
    if (-not $ProgressId -and -not $Activity) {
        throw "Activity parameter is required when creating a new progress operation"
    }

    if (-not $script:ProgressStackManager) {
        Write-Warning "Progress system not initialized. Falling back to Write-Progress."
        if ($Completed) {
            Write-Progress -Activity $Activity -Completed
        } else {
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
        }
        return $Id
    }

    try {
        if ($Completed -and $ProgressId) {
            # Complete existing progress operation
            $context = $script:ProgressStackManager.PopContext($ProgressId)
            if ($context) {
                $context.Complete()
                if ($Metrics) {
                    foreach ($metric in $Metrics.GetEnumerator()) {
                        $context.AddMetric($metric.Key, $metric.Value)
                    }
                }
                $script:ProgressStackManager.RefreshDisplay()
            }
            return $ProgressId
        }

        if ($ProgressId) {
            # Update existing progress operation
            $updates = @{}
            if ($PSBoundParameters.ContainsKey('PercentComplete')) { $updates['PercentComplete'] = $PercentComplete }
            if ($PSBoundParameters.ContainsKey('Status')) { $updates['Status'] = $Status }
            if ($PSBoundParameters.ContainsKey('CurrentOperation')) { $updates['CurrentOperation'] = $CurrentOperation }
            if ($PSBoundParameters.ContainsKey('TotalOperations')) { $updates['TotalOperations'] = $TotalOperations }

            if ($Metrics) {
                foreach ($metric in $Metrics.GetEnumerator()) {
                    $updates[$metric.Key] = $metric.Value
                }
            }

            $script:ProgressStackManager.UpdateContext($ProgressId, $updates)
            $script:ProgressStackManager.RefreshDisplay()

            if ($Message) {
                Write-DotWinLog -Message $Message -Level $MessageLevel -ShowWithProgress -ProgressId $ProgressId
            }

            return $ProgressId
        } else {
            # Create new progress operation
            [void]($context = [DotWinProgressContext]::new($Activity))

            if ($ParentId) {
                $context.ParentId = $ParentId
            }

            if ($PSBoundParameters.ContainsKey('Status')) { $context.Status = $Status }
            if ($PSBoundParameters.ContainsKey('PercentComplete')) { $context.PercentComplete = $PercentComplete }
            if ($PSBoundParameters.ContainsKey('CurrentOperation')) { $context.CurrentOperation = $CurrentOperation }
            if ($PSBoundParameters.ContainsKey('TotalOperations')) { $context.TotalOperations = $TotalOperations }

            if ($Metrics) {
                foreach ($metric in $Metrics.GetEnumerator()) {
                    $context.AddMetric($metric.Key, $metric.Value)
                }
            }

            [void]($progressId = $script:ProgressStackManager.PushContext($context))
            $script:ProgressStackManager.RefreshDisplay()

            if ($Message) {
                Write-DotWinLog -Message $Message -Level $MessageLevel -ShowWithProgress -ProgressId $progressId
            }

            return $progressId
        }
    } catch {
        Write-Warning "Progress operation failed: $($_.Exception.Message)"
        # Fallback to standard Write-Progress
        if ($Completed) {
            Write-Progress -Activity $Activity -Completed
        } else {
            Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
        }
        return $ProgressId
    }
}

function Start-DotWinProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Activity,

        [Parameter()]
        [string]$Status = "Starting...",

        [Parameter()]
        [string]$ParentId,

        [Parameter()]
        [int]$TotalOperations = -1,

        [Parameter()]
        [hashtable]$InitialMetrics
    )

    $params = @{
        Activity = $Activity
        Status = $Status
    }

    if ($ParentId) { $params['ParentId'] = $ParentId }
    if ($TotalOperations -gt 0) { $params['TotalOperations'] = $TotalOperations }
    if ($InitialMetrics) { $params['Metrics'] = $InitialMetrics }

    return Write-DotWinProgress @params
}

function Complete-DotWinProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProgressId,

        [Parameter()]
        [string]$Status = "Completed",

        [Parameter()]
        [hashtable]$FinalMetrics,

        [Parameter()]
        [string]$Message
    )

    $params = @{
        ProgressId = $ProgressId
        Completed = $true
        Status = $Status
    }

    if ($FinalMetrics) { $params['Metrics'] = $FinalMetrics }
    if ($Message) { $params['Message'] = $Message }

    Write-DotWinProgress @params
}


# Export module members
Export-ModuleMember -Function ($PublicFunctions + $ProgressFunctions)
Export-ModuleMember -Variable @()

Write-Verbose "DotWin module initialization complete."
