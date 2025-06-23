function Test-DotWinConfiguration {
    <#
    .SYNOPSIS
        Tests and validates DotWin configurations without applying changes.

    .DESCRIPTION
        The Test-DotWinConfiguration function performs comprehensive validation
        of DotWin configurations in a dry-run mode. It checks configuration
        syntax, validates dependencies, tests system compatibility, and
        identifies potential issues before actual application.

    .PARAMETER Configuration
        The DotWinConfiguration object to test.

    .PARAMETER ConfigurationPath
        Path to a configuration file to load and test.

    .PARAMETER IncludeSystemValidation
        Perform system-level validation checks.

    .PARAMETER IncludeDependencyCheck
        Check for configuration dependencies and conflicts.

    .PARAMETER IncludePerformanceAnalysis
        Analyze potential performance impact of the configuration.

    .PARAMETER Detailed
        Return detailed validation results for each configuration item.

    .PARAMETER ParallelValidation
        Use parallel processing for validation (PowerShell 7+ only).

    .PARAMETER ValidationTimeout
        Timeout in seconds for individual validation operations (default: 30).

    .EXAMPLE
        Test-DotWinConfiguration -ConfigurationPath ".\config.json"

        Tests a configuration file for validity.

    .EXAMPLE
        $config = [DotWinConfiguration]::new("TestConfig")
        Test-DotWinConfiguration -Configuration $config -Detailed

        Tests a configuration object with detailed results.

    .EXAMPLE
        Test-DotWinConfiguration -ConfigurationPath ".\config.json" -IncludeSystemValidation -IncludeDependencyCheck

        Performs comprehensive validation including system and dependency checks.

    .OUTPUTS
        PSCustomObject
        Returns validation results with overall status and detailed findings.

    .NOTES
        This function is safe to run and makes no system changes.
        It provides comprehensive pre-flight checks for configurations.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Configuration')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Configuration', ValueFromPipeline = $true)]
        [DotWinConfiguration]$Configuration,

        [Parameter(Mandatory = $true, ParameterSetName = 'Path')]
        [ValidateScript({
            if (-not (Test-Path $_)) {
                throw "Configuration file '$_' does not exist."
            }
            return $true
        })]
        [string]$ConfigurationPath,

        [Parameter()]
        [switch]$IncludeSystemValidation,

        [Parameter()]
        [switch]$IncludeDependencyCheck,

        [Parameter()]
        [switch]$IncludePerformanceAnalysis,

        [Parameter()]
        [switch]$Detailed,

        [Parameter()]
        [switch]$ParallelValidation,

        [Parameter()]
        [ValidateRange(5, 300)]
        [int]$ValidationTimeout = 30
    )

    begin {
        Write-DotWinLog "Starting configuration validation" -Level Information
        $startTime = Get-Date

        # Initialize validation results
        $validationResults = [PSCustomObject]@{
            OverallStatus = "Unknown"
            TotalItems = 0
            ValidItems = 0
            InvalidItems = 0
            WarningItems = 0
            ValidationDuration = $null
            SystemCompatible = $null
            DependenciesValid = $null
            PerformanceImpact = $null
            Issues = @()
            ItemResults = @()
            Recommendations = @()
        }

        # Check PowerShell version for parallel processing
        if ($ParallelValidation -and $PSVersionTable.PSVersion.Major -lt 7) {
            Write-DotWinLog "Parallel validation requires PowerShell 7+. Using sequential validation." -Level Warning
            $ParallelValidation = $false
        }
    }

    process {
        try {
            # Load configuration if path provided
            if ($PSCmdlet.ParameterSetName -eq 'Path') {
                Write-DotWinLog "Loading configuration from: $ConfigurationPath" -Level Information
                $Configuration = Import-DotWinConfiguration -Path $ConfigurationPath
            }

            if (-not $Configuration) {
                throw "No valid configuration provided"
            }

            $validationResults.TotalItems = $Configuration.Items.Count
            Write-DotWinLog "Validating configuration '$($Configuration.Name)' with $($Configuration.Items.Count) items" -Level Information

            # Validate configuration structure
            $structureValidation = Test-ConfigurationStructure -Configuration $Configuration
            if (-not $structureValidation.IsValid) {
                $validationResults.Issues += $structureValidation.Issues
                $validationResults.OverallStatus = "Invalid"
                return $validationResults
            }

            # Validate individual configuration items
            if ($ParallelValidation) {
                Write-DotWinLog "Using parallel validation for enhanced performance" -Level Information
                $itemResults = Test-ConfigurationItemsParallel -Configuration $Configuration -Timeout $ValidationTimeout
            } else {
                $itemResults = Test-ConfigurationItemsSequential -Configuration $Configuration -Timeout $ValidationTimeout
            }

            $validationResults.ItemResults = $itemResults
            $validationResults.ValidItems = ($itemResults | Where-Object { $_.Status -eq "Valid" }).Count
            $validationResults.InvalidItems = ($itemResults | Where-Object { $_.Status -eq "Invalid" }).Count
            $validationResults.WarningItems = ($itemResults | Where-Object { $_.Status -eq "Warning" }).Count

            # System validation
            if ($IncludeSystemValidation) {
                Write-DotWinLog "Performing system compatibility validation" -Level Information
                $systemValidation = Test-SystemCompatibility -Configuration $Configuration
                $validationResults.SystemCompatible = $systemValidation.Compatible
                if (-not $systemValidation.Compatible) {
                    $validationResults.Issues += $systemValidation.Issues
                }
            }

            # Dependency validation
            if ($IncludeDependencyCheck) {
                Write-DotWinLog "Checking configuration dependencies" -Level Information
                $dependencyValidation = Test-ConfigurationDependencies -Configuration $Configuration
                $validationResults.DependenciesValid = $dependencyValidation.Valid
                if (-not $dependencyValidation.Valid) {
                    $validationResults.Issues += $dependencyValidation.Issues
                }
            }

            # Performance analysis
            if ($IncludePerformanceAnalysis) {
                Write-DotWinLog "Analyzing performance impact" -Level Information
                $performanceAnalysis = Get-ConfigurationPerformanceImpact -Configuration $Configuration
                $validationResults.PerformanceImpact = $performanceAnalysis
                if ($performanceAnalysis.HighImpactItems -gt 0) {
                    $validationResults.Recommendations += "Consider applying high-impact items separately"
                }
            }

            # Determine overall status
            if ($validationResults.InvalidItems -eq 0 -and 
                ($validationResults.SystemCompatible -ne $false) -and 
                ($validationResults.DependenciesValid -ne $false)) {
                $validationResults.OverallStatus = if ($validationResults.WarningItems -gt 0) { "ValidWithWarnings" } else { "Valid" }
            } else {
                $validationResults.OverallStatus = "Invalid"
            }

            # Generate recommendations
            $validationResults.Recommendations += Get-ValidationRecommendations -ValidationResults $validationResults

        } catch {
            Write-DotWinLog "Critical error during configuration validation: $($_.Exception.Message)" -Level Error
            $validationResults.OverallStatus = "Error"
            $validationResults.Issues += "Validation failed: $($_.Exception.Message)"
            throw
        }
    }

    end {
        $validationResults.ValidationDuration = (Get-Date) - $startTime
        
        Write-DotWinLog "Configuration validation completed in $($validationResults.ValidationDuration.TotalSeconds) seconds" -Level Information
        Write-DotWinLog "Validation status: $($validationResults.OverallStatus)" -Level Information
        Write-DotWinLog "Items - Valid: $($validationResults.ValidItems), Invalid: $($validationResults.InvalidItems), Warnings: $($validationResults.WarningItems)" -Level Information

        return $validationResults
    }
}

function Test-ConfigurationStructure {
    <#
    .SYNOPSIS
        Validates the basic structure of a DotWin configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DotWinConfiguration]$Configuration
    )

    $result = [PSCustomObject]@{
        IsValid = $true
        Issues = @()
    }

    try {
        # Check required properties
        if ([string]::IsNullOrEmpty($Configuration.Name)) {
            $result.Issues += "Configuration name is required"
            $result.IsValid = $false
        }

        if ([string]::IsNullOrEmpty($Configuration.Version)) {
            $result.Issues += "Configuration version is required"
            $result.IsValid = $false
        }

        if ($Configuration.Items.Count -eq 0) {
            $result.Issues += "Configuration must contain at least one item"
            $result.IsValid = $false
        }

        # Check for duplicate item names
        $itemNames = $Configuration.Items | ForEach-Object { $_.Name }
        $duplicates = $itemNames | Group-Object | Where-Object { $_.Count -gt 1 }
        if ($duplicates) {
            $result.Issues += "Duplicate item names found: $($duplicates.Name -join ', ')"
            $result.IsValid = $false
        }

        # Validate item structure
        foreach ($item in $Configuration.Items) {
            if ([string]::IsNullOrEmpty($item.Name)) {
                $result.Issues += "Configuration item missing name"
                $result.IsValid = $false
            }

            if ([string]::IsNullOrEmpty($item.Type)) {
                $result.Issues += "Configuration item '$($item.Name)' missing type"
                $result.IsValid = $false
            }
        }

    } catch {
        $result.Issues += "Error validating configuration structure: $($_.Exception.Message)"
        $result.IsValid = $false
    }

    return $result
}

function Test-ConfigurationItemsSequential {
    <#
    .SYNOPSIS
        Tests configuration items sequentially.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DotWinConfiguration]$Configuration,
        
        [Parameter()]
        [int]$Timeout = 30
    )

    $results = @()

    foreach ($item in $Configuration.Items) {
        $itemResult = Test-SingleConfigurationItem -Item $item -Timeout $Timeout
        $results += $itemResult
    }

    return $results
}

function Test-ConfigurationItemsParallel {
    <#
    .SYNOPSIS
        Tests configuration items in parallel (PowerShell 7+ only).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DotWinConfiguration]$Configuration,
        
        [Parameter()]
        [int]$Timeout = 30
    )

    if ($PSVersionTable.PSVersion.Major -lt 7) {
        return Test-ConfigurationItemsSequential -Configuration $Configuration -Timeout $Timeout
    }

    try {
        $results = $Configuration.Items | ForEach-Object -Parallel {
            $item = $_
            $timeout = $using:Timeout
            
            # Import required functions in parallel context
            $testFunction = {
                param($Item, $Timeout)
                
                $result = [PSCustomObject]@{
                    ItemName = $Item.Name
                    ItemType = $Item.Type
                    Status = "Unknown"
                    Message = ""
                    Issues = @()
                    ValidationTime = $null
                }
                
                $startTime = Get-Date
                
                try {
                    # Basic item validation
                    if ([string]::IsNullOrEmpty($Item.Name)) {
                        $result.Status = "Invalid"
                        $result.Issues += "Item name is required"
                        return $result
                    }
                    
                    if ([string]::IsNullOrEmpty($Item.Type)) {
                        $result.Status = "Invalid"
                        $result.Issues += "Item type is required"
                        return $result
                    }
                    
                    # Type-specific validation would go here
                    $result.Status = "Valid"
                    $result.Message = "Item validation passed"
                    
                } catch {
                    $result.Status = "Invalid"
                    $result.Message = "Validation error: $($_.Exception.Message)"
                } finally {
                    $result.ValidationTime = (Get-Date) - $startTime
                }
                
                return $result
            }
            
            & $testFunction $item $timeout
            
        } -ThrottleLimit 5
        
        return $results
        
    } catch {
        Write-Warning "Parallel validation failed, falling back to sequential: $($_.Exception.Message)"
        return Test-ConfigurationItemsSequential -Configuration $Configuration -Timeout $Timeout
    }
}

function Test-SingleConfigurationItem {
    <#
    .SYNOPSIS
        Tests a single configuration item.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DotWinConfigurationItem]$Item,
        
        [Parameter()]
        [int]$Timeout = 30
    )

    $result = [PSCustomObject]@{
        ItemName = $Item.Name
        ItemType = $Item.Type
        Status = "Unknown"
        Message = ""
        Issues = @()
        ValidationTime = $null
    }

    $startTime = Get-Date

    try {
        # Timeout handling
        $job = Start-Job -ScriptBlock {
            param($Item)
            
            # Basic validation
            if ([string]::IsNullOrEmpty($Item.Name)) {
                return @{ Status = "Invalid"; Issues = @("Item name is required") }
            }
            
            if ([string]::IsNullOrEmpty($Item.Type)) {
                return @{ Status = "Invalid"; Issues = @("Item type is required") }
            }
            
            # Type-specific validation
            switch ($Item.Type) {
                "WingetPackage" {
                    if (-not $Item.Properties.ContainsKey("PackageId")) {
                        return @{ Status = "Invalid"; Issues = @("PackageId is required for WingetPackage") }
                    }
                }
                "RegistryModification" {
                    if (-not $Item.Properties.ContainsKey("Path") -or -not $Item.Properties.ContainsKey("Name")) {
                        return @{ Status = "Invalid"; Issues = @("Path and Name are required for RegistryModification") }
                    }
                }
                default {
                    # Generic validation
                }
            }
            
            return @{ Status = "Valid"; Issues = @() }
            
        } -ArgumentList $Item

        $jobResult = $job | Wait-Job -Timeout $Timeout | Receive-Job
        $job | Remove-Job -Force

        if ($jobResult) {
            $result.Status = $jobResult.Status
            $result.Issues = $jobResult.Issues
            $result.Message = if ($result.Status -eq "Valid") { "Validation passed" } else { "Validation failed" }
        } else {
            $result.Status = "Invalid"
            $result.Message = "Validation timed out after $Timeout seconds"
            $result.Issues += "Validation timeout"
        }

    } catch {
        $result.Status = "Invalid"
        $result.Message = "Validation error: $($_.Exception.Message)"
        $result.Issues += $_.Exception.Message
    } finally {
        $result.ValidationTime = (Get-Date) - $startTime
    }

    return $result
}

function Test-SystemCompatibility {
    <#
    .SYNOPSIS
        Tests system compatibility for a configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DotWinConfiguration]$Configuration
    )

    $result = [PSCustomObject]@{
        Compatible = $true
        Issues = @()
        SystemInfo = @{}
    }

    try {
        # Get system information
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $result.SystemInfo["OperatingSystem"] = $osInfo.Caption
        $result.SystemInfo["Version"] = $osInfo.Version
        $result.SystemInfo["Architecture"] = $osInfo.OSArchitecture

        # Check Windows version compatibility
        if ($osInfo.Version -lt "10.0") {
            $result.Compatible = $false
            $result.Issues += "Windows 10 or higher is required"
        }

        # Check PowerShell version
        if ($PSVersionTable.PSVersion.Major -lt 5) {
            $result.Compatible = $false
            $result.Issues += "PowerShell 5.1 or higher is required"
        }

        # Check administrator privileges for items that require them
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        $adminRequiredTypes = @("WindowsFeatures", "RegistryModification", "ServiceConfiguration")
        $requiresAdmin = $Configuration.Items | Where-Object { $_.Type -in $adminRequiredTypes }
        
        if ($requiresAdmin -and -not $isAdmin) {
            $result.Compatible = $false
            $result.Issues += "Administrator privileges required for some configuration items"
        }

    } catch {
        $result.Compatible = $false
        $result.Issues += "Error checking system compatibility: $($_.Exception.Message)"
    }

    return $result
}

function Test-ConfigurationDependencies {
    <#
    .SYNOPSIS
        Tests configuration dependencies and conflicts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DotWinConfiguration]$Configuration
    )

    $result = [PSCustomObject]@{
        Valid = $true
        Issues = @()
        Dependencies = @()
        Conflicts = @()
    }

    try {
        # Check for circular dependencies
        # This is a simplified implementation
        $itemNames = $Configuration.Items | ForEach-Object { $_.Name }
        
        # Check for known conflicts
        $wingetItems = $Configuration.Items | Where-Object { $_.Type -eq "WingetPackage" }
        $chocoItems = $Configuration.Items | Where-Object { $_.Type -eq "ChocolateyPackage" }
        
        # Check for package conflicts (same software from different sources)
        foreach ($wingetItem in $wingetItems) {
            $conflictingChoco = $chocoItems | Where-Object { 
                $_.Properties["PackageName"] -like "*$($wingetItem.Properties["PackageId"])*" 
            }
            if ($conflictingChoco) {
                $result.Valid = $false
                $result.Conflicts += "Package conflict: $($wingetItem.Name) (Winget) vs $($conflictingChoco.Name) (Chocolatey)"
            }
        }

    } catch {
        $result.Valid = $false
        $result.Issues += "Error checking dependencies: $($_.Exception.Message)"
    }

    return $result
}

function Get-ConfigurationPerformanceImpact {
    <#
    .SYNOPSIS
        Analyzes the performance impact of a configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [DotWinConfiguration]$Configuration
    )

    $analysis = [PSCustomObject]@{
        EstimatedDuration = 0
        HighImpactItems = 0
        MediumImpactItems = 0
        LowImpactItems = 0
        NetworkRequiredItems = 0
        RebootRequiredItems = 0
        ItemAnalysis = @()
    }

    # Performance impact weights (in seconds)
    $impactWeights = @{
        "WingetPackage" = 30
        "ChocolateyPackage" = 45
        "WindowsFeatures" = 60
        "RegistryModification" = 2
        "ServiceConfiguration" = 5
        "CustomApplication" = 120
    }

    foreach ($item in $Configuration.Items) {
        $itemImpact = [PSCustomObject]@{
            Name = $item.Name
            Type = $item.Type
            EstimatedTime = 0
            ImpactLevel = "Low"
            RequiresNetwork = $false
            RequiresReboot = $false
        }

        # Estimate time based on type
        if ($impactWeights.ContainsKey($item.Type)) {
            $itemImpact.EstimatedTime = $impactWeights[$item.Type]
        } else {
            $itemImpact.EstimatedTime = 10  # Default
        }

        # Determine impact level
        if ($itemImpact.EstimatedTime -gt 60) {
            $itemImpact.ImpactLevel = "High"
            $analysis.HighImpactItems++
        } elseif ($itemImpact.EstimatedTime -gt 15) {
            $itemImpact.ImpactLevel = "Medium"
            $analysis.MediumImpactItems++
        } else {
            $analysis.LowImpactItems++
        }

        # Check for network requirements
        if ($item.Type -in @("WingetPackage", "ChocolateyPackage", "CustomApplication")) {
            $itemImpact.RequiresNetwork = $true
            $analysis.NetworkRequiredItems++
        }

        # Check for reboot requirements
        if ($item.Type -in @("WindowsFeatures", "DriverInstallation")) {
            $itemImpact.RequiresReboot = $true
            $analysis.RebootRequiredItems++
        }

        $analysis.EstimatedDuration += $itemImpact.EstimatedTime
        $analysis.ItemAnalysis += $itemImpact
    }

    return $analysis
}

function Get-ValidationRecommendations {
    <#
    .SYNOPSIS
        Generates recommendations based on validation results.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$ValidationResults
    )

    $recommendations = @()

    if ($ValidationResults.InvalidItems -gt 0) {
        $recommendations += "Fix invalid configuration items before applying"
    }

    if ($ValidationResults.WarningItems -gt 0) {
        $recommendations += "Review warning items for potential issues"
    }

    if ($ValidationResults.PerformanceImpact -and $ValidationResults.PerformanceImpact.EstimatedDuration -gt 300) {
        $recommendations += "Consider applying configuration in smaller batches due to long estimated duration"
    }

    if ($ValidationResults.PerformanceImpact -and $ValidationResults.PerformanceImpact.RebootRequiredItems -gt 0) {
        $recommendations += "Plan for system reboot after applying configuration"
    }

    if ($ValidationResults.SystemCompatible -eq $false) {
        $recommendations += "Address system compatibility issues before proceeding"
    }

    if ($ValidationResults.DependenciesValid -eq $false) {
        $recommendations += "Resolve dependency conflicts before applying configuration"
    }

    return $recommendations
}

function Import-DotWinConfiguration {
    <#
    .SYNOPSIS
        Imports a DotWin configuration from a file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $content = Get-Content -Path $Path -Raw | ConvertFrom-Json
        
        $config = [DotWinConfiguration]::new($content.name)
        $config.Version = if ($content.version) { $content.version } else { "1.0.0" }
        $config.Description = if ($content.description) { $content.description } else { "" }
        
        foreach ($itemData in $content.items) {
            $item = [DotWinConfigurationItem]::new($itemData.name, $itemData.type)
            $item.Description = if ($itemData.description) { $itemData.description } else { "" }
            $item.Enabled = if ($itemData.enabled -ne $null) { $itemData.enabled } else { $true }
            
            if ($itemData.properties) {
                # Convert PSCustomObject to hashtable for Properties
                if ($itemData.properties -is [PSCustomObject]) {
                    $hashtable = @{}
                    $itemData.properties.PSObject.Properties | ForEach-Object {
                        $hashtable[$_.Name] = $_.Value
                    }
                    $item.Properties = $hashtable
                } else {
                    $item.Properties = $itemData.properties
                }
            }
            
            $config.AddItem($item)
        }
        
        return $config
        
    } catch {
        throw "Failed to import configuration from '$Path': $($_.Exception.Message)"
    }
}