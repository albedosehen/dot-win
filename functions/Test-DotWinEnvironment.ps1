function Test-DotWinEnvironment {
    <#
    .SYNOPSIS
        Tests if the current environment is suitable for DotWin operations.

    .DESCRIPTION
        Validates that the current PowerShell session and system environment
        meet the requirements for DotWin configuration management.

    .EXAMPLE
        Test-DotWinEnvironment
        
        Tests the current environment and returns validation results including
        any issues found and administrator status.

    .OUTPUTS
        PSCustomObject
        Returns an object containing validation results, issues, and system information.

    .NOTES
        This function checks:
        - PowerShell version compatibility (5.1 or higher required)
        - Windows operating system requirement
        - Administrator privileges status
    #>
    [CmdletBinding()]
    param()

    $issues = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.1 or higher is required"
    }

    # Check if running on Windows
    if (-not ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5)) {
        $issues += "DotWin is designed for Windows systems"
    }

    # Check if running as administrator (for some operations)
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    return [PSCustomObject]@{
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
        IsAdministrator = $isAdmin
        PowerShellVersion = $PSVersionTable.PSVersion
        OperatingSystem = if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
            (Get-CimInstance Win32_OperatingSystem).Caption
        } else {
            "Non-Windows"
        }
    }
}
