function ConvertTo-DotWinConfiguration {
    <#
    .SYNOPSIS
        Converts system profiles and recommendations into usable DotWin configuration files.

    .DESCRIPTION
        The ConvertTo-DotWinConfiguration function takes a system profile and/or recommendations
        and converts them into a proper DotWin configuration JSON file that can be used with
        Invoke-DotWinConfiguration. This makes it easy to turn system analysis into actionable
        configuration files.

    .PARAMETER SystemProfile
        A DotWinSystemProfiler object containing the system profile data.

    .PARAMETER Recommendations
        An array of DotWinRecommendation objects to convert into configuration items.

    .PARAMETER ConfigurationName
        The name for the generated configuration (default: "Generated Configuration").

    .PARAMETER OutputPath
        Path where the configuration file should be saved. If not specified, returns the configuration object.

    .PARAMETER IncludeMetadata
        Include detailed metadata about the source profile and recommendations in the configuration.

    .PARAMETER Priority
        Only include recommendations with the specified priority levels (High, Medium, Low).

    .PARAMETER Category
        Only include recommendations from the specified categories.

    .PARAMETER Force
        Overwrite existing configuration file if it exists.

    .EXAMPLE
        $profile = Get-DotWinSystemProfile
        $recommendations = Get-DotWinRecommendations -SystemProfile $profile
        ConvertTo-DotWinConfiguration -SystemProfile $profile -Recommendations $recommendations -OutputPath "my-config.json"
        
        Converts a system profile and recommendations into a configuration file.

    .EXAMPLE
        Get-DotWinRecommendations | ConvertTo-DotWinConfiguration -ConfigurationName "Auto Setup" -Priority "High","Medium"
        
        Converts high and medium priority recommendations into a configuration object.

    .EXAMPLE
        $profile = Get-DotWinSystemProfile
        ConvertTo-DotWinConfiguration -SystemProfile $profile -OutputPath "profile-based-config.json" -IncludeMetadata
        
        Creates a configuration based on system profile with detailed metadata.

    .OUTPUTS
        DotWinConfiguration or JSON file
        Returns a DotWinConfiguration object or saves to file if OutputPath is specified.

    .NOTES
        This function bridges the gap between system analysis and actionable configuration.
        It's designed to make configuration generation as simple as possible.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [object]$InputObject,

        [Parameter()]
        [DotWinSystemProfiler]$SystemProfile,

        [Parameter()]
        [array]$Recommendations,

        [Parameter()]
        [string]$ConfigurationName = "Generated Configuration",

        [Parameter()]
        [ValidateScript({
            $directory = Split-Path $_ -Parent
            if ($directory -and -not (Test-Path $directory)) {
                throw "Output directory '$directory' does not exist."
            }
            return $true
        })]
        [string]$OutputPath,

        [Parameter()]
        [switch]$IncludeMetadata,

        [Parameter()]
        [ValidateSet('High', 'Medium', 'Low')]
        [string[]]$Priority,

        [Parameter()]
        [ValidateSet('Hardware', 'Software', 'Performance', 'Security', 'Development', 'User Experience')]
        [string[]]$Category,

        [Parameter()]
        [switch]$Force
    )

    begin {
        Write-DotWinLog "Starting configuration conversion" -Level Information
        $startTime = Get-Date

        # Check if output file exists and Force is not specified
        if ($OutputPath -and (Test-Path $OutputPath) -and -not $Force) {
            throw "Configuration file '$OutputPath' already exists. Use -Force to overwrite."
        }

        # Initialize collections for pipeline input
        $pipelineRecommendations = @()
    }

    process {
        # Handle different types of pipeline input
        if ($InputObject) {
            if ($InputObject -is [array] -and $InputObject.Count -gt 0 -and $InputObject[0].GetType().Name -eq 'DotWinRecommendation') {
                # Array of recommendations from pipeline
                Write-DotWinLog "Received $($InputObject.Count) recommendations from pipeline" -Level Information
                $pipelineRecommendations += $InputObject
                return  # Continue processing in end block
            } elseif ($InputObject.GetType().Name -eq 'DotWinRecommendation') {
                # Single recommendation from pipeline
                $title = if ($InputObject.PSObject.Properties.Name -contains 'Title') { $InputObject.Title } else { "Unknown Recommendation" }
                Write-DotWinLog "Received recommendation from pipeline: $title" -Level Information
                $pipelineRecommendations += $InputObject
                return  # Continue processing in end block
            } elseif ($InputObject.GetType().Name -eq 'DotWinSystemProfiler') {
                # System profile from pipeline
                Write-DotWinLog "Received SystemProfile from pipeline" -Level Information
                $SystemProfile = $InputObject
            }
        }

        # If we have pipeline recommendations, merge them with explicit recommendations
        if ($pipelineRecommendations.Count -gt 0) {
            if ($Recommendations) {
                $Recommendations = $Recommendations + $pipelineRecommendations
            } else {
                $Recommendations = $pipelineRecommendations
            }
        }
        try {
            # Create new configuration object
            Write-DotWinLog "Creating configuration: $ConfigurationName" -Level Information
            $configuration = [DotWinConfiguration]::new($ConfigurationName)
            $configuration.Version = "1.0.0"
            $configuration.Description = "Auto-generated configuration from system profile and recommendations"

            # Add metadata if requested
            if ($IncludeMetadata) {
                $configuration.Metadata["GeneratedAt"] = Get-Date
                $configuration.Metadata["GeneratedBy"] = "ConvertTo-DotWinConfiguration"
                $configuration.Metadata["DotWinVersion"] = (Get-Module DotWin).Version.ToString()
                
                if ($SystemProfile) {
                    $configuration.Metadata["SourceProfile"] = @{
                        ProfileVersion = $SystemProfile.ProfileVersion
                        LastProfiled = $SystemProfile.LastProfiled
                        HardwareCategory = $SystemProfile.Hardware.GetHardwareCategory()
                        UserType = $SystemProfile.Software.GetUserType()
                        TechnicalLevel = $SystemProfile.User.GetTechnicalLevel()
                    }
                }
            }

            # Process recommendations if provided
            if ($Recommendations -and $Recommendations.Count -gt 0) {
                Write-DotWinLog "Processing $($Recommendations.Count) recommendations" -Level Information
                
                # Filter recommendations by priority and category
                $filteredRecommendations = $Recommendations
                
                if ($Priority) {
                    $filteredRecommendations = $filteredRecommendations | Where-Object { $_.Priority -in $Priority }
                    Write-DotWinLog "Filtered by priority: $($Priority -join ', ') - $($filteredRecommendations.Count) recommendations remain" -Level Information
                }
                
                if ($Category) {
                    $filteredRecommendations = $filteredRecommendations | Where-Object { $_.Category -in $Category }
                    Write-DotWinLog "Filtered by category: $($Category -join ', ') - $($filteredRecommendations.Count) recommendations remain" -Level Information
                }

                # Convert recommendations to configuration items
                foreach ($recommendation in $filteredRecommendations) {
                    try {
                        $configItem = $null
                        
                        # Convert based on implementation type
                        if ($recommendation.PSObject.Properties.Name -contains 'Implementation' -and $recommendation.Implementation) {
                            switch ($recommendation.Implementation.Type) {
                                "Package" {
                                    $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Package Configuration" }
                                    $configItem = [DotWinConfigurationItem]::new($title, "Packages")
                                    $configItem.Properties = @{
                                        packages = @($recommendation.Implementation.PackageId)
                                        source = $recommendation.Implementation.Source
                                        acceptLicenses = $true
                                    }
                                }
                                "WindowsFeature" {
                                    $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Windows Feature Configuration" }
                                    $configItem = [DotWinConfigurationItem]::new($title, "WindowsFeatures")
                                    $configItem.Properties = @{
                                        features = @($recommendation.Implementation.FeatureName)
                                        enabled = $recommendation.Implementation.ShouldEnable
                                    }
                                }
                                "Registry" {
                                    $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Registry Configuration" }
                                    $configItem = [DotWinConfigurationItem]::new($title, "RegistryConfiguration")
                                    $configItem.Properties = @{
                                        settings = @($recommendation.Implementation.RegistrySettings)
                                    }
                                }
                                "SystemTools" {
                                    $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "System Tools Configuration" }
                                    $configItem = [DotWinConfigurationItem]::new($title, "SystemTools")
                                    $configItem.Properties = @{
                                        category = if ($recommendation.PSObject.Properties.Name -contains 'Category') { $recommendation.Category } else { "General" }
                                        tools = @($recommendation.Implementation.Tools)
                                    }
                                }
                                default {
                                    # Generic configuration item
                                    $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Generic Configuration" }
                                    $configItem = [DotWinConfigurationItem]::new($title, "Generic")
                                    $configItem.Properties = $recommendation.Implementation
                                }
                            }
                        } else {
                            # Create a basic configuration item if no implementation details
                            $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Basic Configuration" }
                            $configItem = [DotWinConfigurationItem]::new($title, "Generic")
                            $configItem.Properties = @{
                                type = "Basic"
                                source = "Recommendation"
                            }
                        }

                        if ($configItem) {
                            if ($recommendation.PSObject.Properties.Name -contains 'Description') {
                                $configItem.Description = $recommendation.Description
                            } else {
                                $configItem.Description = "Generated from recommendation"
                            }
                            $configItem.Enabled = $true
                            
                            # Add recommendation metadata
                            if ($IncludeMetadata) {
                                $metadata = @{}
                                if ($recommendation.PSObject.Properties.Name -contains 'Priority') {
                                    $metadata.Priority = $recommendation.Priority
                                }
                                if ($recommendation.PSObject.Properties.Name -contains 'Category') {
                                    $metadata.Category = $recommendation.Category
                                }
                                if ($recommendation.PSObject.Properties.Name -contains 'ConfidenceScore') {
                                    $metadata.ConfidenceScore = $recommendation.ConfidenceScore
                                }
                                if ($recommendation.PSObject.Properties.Name -contains 'Prerequisites') {
                                    $metadata.Prerequisites = $recommendation.Prerequisites
                                }
                                $configItem.Properties["RecommendationMetadata"] = $metadata
                            }
                            
                            $configuration.AddItem($configItem)
                            $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Unknown" }
                            Write-DotWinLog "Added configuration item: $title" -Level Verbose
                        }
                    } catch {
                        $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Unknown" }
                        Write-DotWinLog "Failed to convert recommendation '$title': $($_.Exception.Message)" -Level Warning
                    }
                }
            }

            # Add system profile-based configuration items if profile is provided
            if ($SystemProfile) {
                Write-DotWinLog "Adding profile-based configuration items" -Level Information
                
                # Add hardware-specific optimizations
                $hardwareCategory = $SystemProfile.Hardware.GetHardwareCategory()
                switch ($hardwareCategory) {
                    "HighPerformance" {
                        $perfItem = [DotWinConfigurationItem]::new("High Performance Optimizations", "PerformanceSettings")
                        $perfItem.Properties = @{
                            powerPlan = "High Performance"
                            visualEffects = "Performance"
                            enableGameMode = $true
                        }
                        $perfItem.Description = "Optimizations for high-performance systems"
                        $configuration.AddItem($perfItem)
                    }
                    "Workstation" {
                        $workItem = [DotWinConfigurationItem]::new("Workstation Optimizations", "PerformanceSettings")
                        $workItem.Properties = @{
                            powerPlan = "Balanced"
                            enableVirtualization = $true
                            optimizeForWork = $true
                        }
                        $workItem.Description = "Optimizations for workstation use"
                        $configuration.AddItem($workItem)
                    }
                }

                # Add user type-specific tools
                $userType = $SystemProfile.Software.GetUserType()
                switch ($userType) {
                    "Developer" {
                        $devItem = [DotWinConfigurationItem]::new("Developer Tools", "SystemTools")
                        $devItem.Properties = @{
                            category = "Development"
                            tools = @("git", "vscode", "nodejs", "python3")
                            enableDeveloperMode = $true
                        }
                        $devItem.Description = "Essential development tools"
                        $configuration.AddItem($devItem)
                    }
                    "Gamer" {
                        $gameItem = [DotWinConfigurationItem]::new("Gaming Optimizations", "PerformanceSettings")
                        $gameItem.Properties = @{
                            enableGameMode = $true
                            optimizeForGaming = $true
                            disableFullscreenOptimizations = $false
                        }
                        $gameItem.Description = "Gaming performance optimizations"
                        $configuration.AddItem($gameItem)
                    }
                }
            }

            # Save to file if OutputPath is specified
            if ($OutputPath) {
                Write-DotWinLog "Saving configuration to: $OutputPath" -Level Information
                
                # Create the JSON structure that matches the example configurations
                $jsonConfig = @{
                    name = $configuration.Name
                    version = $configuration.Version
                    description = $configuration.Description
                    metadata = @{
                        author = "DotWin Auto-Generator"
                        category = "Auto-Generated"
                        lastUpdated = (Get-Date).ToString("yyyy-MM-dd")
                        generatedBy = "ConvertTo-DotWinConfiguration"
                    }
                    items = @()
                }

                # Add metadata if requested
                if ($IncludeMetadata) {
                    foreach ($key in $configuration.Metadata.Keys) {
                        $jsonConfig.metadata[$key] = $configuration.Metadata[$key]
                    }
                }

                # Convert configuration items to JSON format
                foreach ($item in $configuration.Items) {
                    $jsonItem = @{
                        name = $item.Name
                        type = $item.Type
                        description = if ($item.PSObject.Properties.Name -contains 'Description') { $item.Description } else { "Configuration item" }
                        enabled = $item.Enabled
                        properties = $item.Properties
                    }
                    $jsonConfig.items += $jsonItem
                }

                # Add validation section
                $jsonConfig.validation = @{
                    tests = @()
                }

                # Add post-install instructions
                $jsonConfig.postInstallInstructions = @(
                    "Review the applied configuration",
                    "Restart your computer if required",
                    "Test the configured applications and settings"
                )

                # Convert to JSON and save
                $jsonContent = $jsonConfig | ConvertTo-Json -Depth 10
                Set-Content -Path $OutputPath -Value $jsonContent -Encoding UTF8
                
                Write-DotWinLog "Configuration saved successfully to: $OutputPath" -Level Information
                Write-DotWinLog "Configuration contains $($configuration.Items.Count) items" -Level Information
                
                return $OutputPath
            } else {
                # Return the configuration object
                Write-DotWinLog "Returning configuration object with $($configuration.Items.Count) items" -Level Information
                return $configuration
            }

        } catch {
            Write-DotWinLog "Error during configuration conversion: $($_.Exception.Message)" -Level Error
            throw
        }
    }

    end {
        # Process accumulated pipeline recommendations if any
        if ($pipelineRecommendations.Count -gt 0 -and -not $Recommendations) {
            Write-DotWinLog "Processing $($pipelineRecommendations.Count) recommendations from pipeline in end block" -Level Information
            $Recommendations = $pipelineRecommendations

            # Re-run the main processing logic with accumulated recommendations
            try {
                # Create new configuration object
                Write-DotWinLog "Creating configuration: $ConfigurationName" -Level Information
                $configuration = [DotWinConfiguration]::new($ConfigurationName)

                # Safely set properties
                if ($configuration.PSObject.Properties.Name -contains 'Version') {
                    $configuration.Version = "1.0.0"
                }
                if ($configuration.PSObject.Properties.Name -contains 'Description') {
                    $configuration.Description = "Auto-generated configuration from system profile and recommendations"
                }

                # Add metadata if requested
                if ($IncludeMetadata) {
                    $configuration.Metadata["GeneratedAt"] = Get-Date
                    $configuration.Metadata["GeneratedBy"] = "ConvertTo-DotWinConfiguration"
                    $configuration.Metadata["DotWinVersion"] = (Get-Module DotWin).Version.ToString()

                    if ($SystemProfile) {
                        $configuration.Metadata["SourceProfile"] = @{
                            ProfileVersion = $SystemProfile.ProfileVersion
                            LastProfiled = $SystemProfile.LastProfiled
                            HardwareCategory = $SystemProfile.Hardware.GetHardwareCategory()
                            UserType = $SystemProfile.Software.GetUserType()
                            TechnicalLevel = $SystemProfile.User.GetTechnicalLevel()
                        }
                    }
                }

                # Process recommendations if provided
                if ($Recommendations -and $Recommendations.Count -gt 0) {
                    Write-DotWinLog "Processing $($Recommendations.Count) recommendations" -Level Information

                    # Filter recommendations by priority and category
                    $filteredRecommendations = $Recommendations

                    if ($Priority) {
                        $filteredRecommendations = $filteredRecommendations | Where-Object { $_.Priority -in $Priority }
                        Write-DotWinLog "Filtered by priority: $($Priority -join ', ') - $($filteredRecommendations.Count) recommendations remain" -Level Information
                    }

                    if ($Category) {
                        $filteredRecommendations = $filteredRecommendations | Where-Object { $_.Category -in $Category }
                        Write-DotWinLog "Filtered by category: $($Category -join ', ') - $($filteredRecommendations.Count) recommendations remain" -Level Information
                    }

                    # Convert recommendations to configuration items
                    foreach ($recommendation in $filteredRecommendations) {
                        try {
                            $configItem = $null

                            # Convert based on implementation type
                            if ($recommendation.PSObject.Properties.Name -contains 'Implementation' -and $recommendation.Implementation) {
                                switch ($recommendation.Implementation.Type) {
                                    "Package" {
                                        $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Package Configuration" }
                                        $configItem = [DotWinConfigurationItem]::new($title, "Packages")
                                        $configItem.Properties = @{
                                            packages = @($recommendation.Implementation.PackageId)
                                            source = @($recommendation.Implementation.Source)
                                            acceptLicenses = $true
                                        }
                                    }
                                    "WindowsFeature" {
                                        $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Windows Feature Configuration" }
                                        $configItem = [DotWinConfigurationItem]::new($title, "WindowsFeatures")
                                        $configItem.Properties = @{
                                            features = @($recommendation.Implementation.FeatureName)
                                            enabled = $recommendation.Implementation.ShouldEnable
                                        }
                                    }
                                    "Registry" {
                                        $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Registry Configuration" }
                                        $configItem = [DotWinConfigurationItem]::new($title, "RegistryConfiguration")
                                        $configItem.Properties = @{
                                            settings = @($recommendation.Implementation.RegistrySettings)
                                        }
                                    }
                                    "SystemTools" {
                                        $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "System Tools Configuration" }
                                        $configItem = [DotWinConfigurationItem]::new($title, "SystemTools")
                                        $configItem.Properties = @{
                                            category = if ($recommendation.PSObject.Properties.Name -contains 'Category') { $recommendation.Category } else { "General" }
                                            tools = @($recommendation.Implementation.Tools)
                                        }
                                    }
                                    default {
                                        # Generic configuration item
                                        $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Generic Configuration" }
                                        $configItem = [DotWinConfigurationItem]::new($title, "Generic")
                                        $configItem.Properties = $recommendation.Implementation
                                    }
                                }
                            } else {
                                # Create a basic configuration item if no implementation details
                                $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Basic Configuration" }
                                $configItem = [DotWinConfigurationItem]::new($title, "Generic")
                                $configItem.Properties = @{
                                    type = "Basic"
                                    source = "Recommendation"
                                }
                            }

                            if ($configItem) {
                                if ($recommendation.PSObject.Properties.Name -contains 'Description') {
                                    $configItem.Description = $recommendation.Description
                                } else {
                                    $configItem.Description = "Generated from recommendation"
                                }
                                $configItem.Enabled = $true

                                # Add recommendation metadata
                                if ($IncludeMetadata) {
                                    $metadata = @{}
                                    if ($recommendation.PSObject.Properties.Name -contains 'Priority') {
                                        $metadata.Priority = $recommendation.Priority
                                    }
                                    if ($recommendation.PSObject.Properties.Name -contains 'Category') {
                                        $metadata.Category = $recommendation.Category
                                    }
                                    if ($recommendation.PSObject.Properties.Name -contains 'ConfidenceScore') {
                                        $metadata.ConfidenceScore = $recommendation.ConfidenceScore
                                    }
                                    if ($recommendation.PSObject.Properties.Name -contains 'Prerequisites') {
                                        $metadata.Prerequisites = $recommendation.Prerequisites
                                    }
                                    $configItem.Properties["RecommendationMetadata"] = $metadata
                                }

                                $configuration.AddItem($configItem)
                                $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Unknown" }
                                Write-DotWinLog "Added configuration item: $title" -Level Verbose
                            }
                        } catch {
                            $title = if ($recommendation.PSObject.Properties.Name -contains 'Title') { $recommendation.Title } else { "Unknown" }
                            Write-DotWinLog "Failed to convert recommendation '$title': $($_.Exception.Message)" -Level Warning
                        }
                    }
                }

                # Save to file if OutputPath is specified
                if ($OutputPath) {
                    Write-DotWinLog "Saving configuration to: $OutputPath" -Level Information

                    # Create the JSON structure that matches the example configurations
                    $jsonConfig = @{
                        name = $configuration.Name
                        version = $configuration.Version
                        description = $configuration.Description
                        metadata = @{
                            author = "DotWin Auto-Generator"
                            category = "Auto-Generated"
                            lastUpdated = (Get-Date).ToString("yyyy-MM-dd")
                            generatedBy = "ConvertTo-DotWinConfiguration"
                        }
                        items = @()
                    }

                    # Add metadata if requested
                    if ($IncludeMetadata) {
                        foreach ($key in $configuration.Metadata.Keys) {
                            $jsonConfig.metadata[$key] = $configuration.Metadata[$key]
                        }
                    }

                    # Convert configuration items to JSON format
                    foreach ($item in $configuration.Items) {
                        $jsonItem = @{
                            name = $item.Name
                            type = $item.Type
                            description = if ($item.PSObject.Properties.Name -contains 'Description') { $item.Description } else { "Configuration item" }
                            enabled = $item.Enabled
                            properties = $item.Properties
                        }
                        $jsonConfig.items += $jsonItem
                    }

                    # Add validation section
                    $jsonConfig.validation = @{
                        tests = @()
                    }

                    # Add post-install instructions
                    $jsonConfig.postInstallInstructions = @(
                        "Review the applied configuration",
                        "Restart your computer if required",
                        "Test the configured applications and settings"
                    )

                    # Convert to JSON and save
                    $jsonContent = $jsonConfig | ConvertTo-Json -Depth 10
                    Set-Content -Path $OutputPath -Value $jsonContent -Encoding UTF8

                    Write-DotWinLog "Configuration saved successfully to: $OutputPath" -Level Information
                    Write-DotWinLog "Configuration contains $($configuration.Items.Count) items" -Level Information

                    return $OutputPath
                } else {
                    # Return the configuration object
                    Write-DotWinLog "Returning configuration object with $($configuration.Items.Count) items" -Level Information
                    return $configuration
                }

            } catch {
                Write-DotWinLog "Error during configuration conversion: $($_.Exception.Message)" -Level Error
                throw
            }
        }

        $totalDuration = (Get-Date) - $startTime
        Write-DotWinLog "Configuration conversion completed in $($totalDuration.TotalSeconds) seconds" -Level Information
    }
}