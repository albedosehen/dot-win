# Understanding DotWin System Profiling

## What is System Profiling?

System profiling is how DotWin learns about your computer. Think of it like DotWin asking your computer questions: "What kind of processor do you have?", "What programs are installed?", "How much memory do you have?"

DotWin uses this information to make smart recommendations just for your computer.

## How It Works

When you run `Get-DotWinSystemProfile`, DotWin looks at three main things:

### 1. Your Hardware

- **Processor (CPU)**: Intel or AMD, how many cores, how fast
- **Memory (RAM)**: How much you have (4GB, 8GB, 16GB, etc.)
- **Storage**: Hard drive or SSD, how much space
- **Graphics**: Built-in or dedicated graphics card

### 2. Your Software

- **Programs**: What's installed on your computer
- **Package Managers**: Winget, Chocolatey, Scoop
- **Development Tools**: If you're a programmer
- **Games**: Gaming platforms like Steam

### 3. Your Usage Patterns

- **User Type**: Are you a developer, gamer, or general user?
- **Technical Level**: Beginner, intermediate, or advanced
- **Preferences**: What kind of software you prefer

## Basic Usage

### Get a Simple Profile

```powershell
# Get basic information about your system
$profile = Get-DotWinSystemProfile

# See what type of computer you have
Write-Host "Hardware Type: $($profile.Hardware.GetHardwareCategory())"
Write-Host "User Type: $($profile.Software.GetUserType())"
```

### See Your System Scores

```powershell
# DotWin gives your system scores from 0-100
$metrics = $profile.SystemMetrics

Write-Host "Performance Score: $($metrics.PerformanceScore)/100"
Write-Host "Security Score: $($metrics.SecurityScore)/100"
Write-Host "How Developer-Friendly: $($metrics.DeveloperFriendliness)/100"
```

## What DotWin Looks For

### Hardware Categories

DotWin puts your computer into one of these categories:

- **High Performance**: Gaming or workstation computer (8+ CPU cores, 16+ GB RAM, dedicated graphics)
- **Workstation**: Good for work (8+ CPU cores, 16+ GB RAM, built-in graphics)
- **Mainstream**: Regular computer (4+ CPU cores, 8+ GB RAM)
- **Budget**: Basic computer (less powerful specs)

### User Types

Based on your installed software, DotWin guesses what kind of user you are:

- **Developer**: You have programming tools like Visual Studio Code, Git
- **Gamer**: You have Steam, Discord, gaming software
- **Creative**: You have Photoshop, video editors, design tools
- **Business**: You have Office, productivity software
- **General**: Mix of different software or basic programs

## Advanced Options

### Faster Profiling (PowerShell 7+)

```powershell
# Use parallel processing for faster results
$profile = Get-DotWinSystemProfile -UseParallel
```

### Selective Profiling

```powershell
# Only check hardware (faster)
$profile = Get-DotWinSystemProfile -IncludeHardware -IncludeSoftware:$false

# Only check software
$profile = Get-DotWinSystemProfile -IncludeSoftware -IncludeHardware:$false
```

### Save Your Profile

```powershell
# Save profile to a file for later use
$profile = Get-DotWinSystemProfile -ExportPath "my-computer-profile.json"
```

## Understanding the Scores

### Performance Score (0-100)

This tells you how powerful your computer is:

- **90-100**: Very powerful computer
- **70-89**: Good performance
- **50-69**: Average performance
- **Below 50**: Basic computer

### Security Score (0-100)

This tells you how secure your computer is:

- **90-100**: Very secure
- **70-89**: Pretty secure
- **50-69**: Some security gaps
- **Below 50**: Needs security improvements

### Developer Friendliness (0-100)

This tells you how good your computer is for programming:

- **90-100**: Perfect for development
- **70-89**: Good for programming
- **50-69**: Basic development setup
- **Below 50**: Missing development tools

## Troubleshooting

### Profiling Takes Too Long

```powershell
# Try a simpler profile first
Get-DotWinSystemProfile -IncludeHardware:$false
```

### Missing Information

```powershell
# Force a complete re-scan
$profile = Get-DotWinSystemProfile -Force
```

### Check if Profiling Worked

```powershell
$profile = Get-DotWinSystemProfile

# These should not be empty if profiling worked
Write-Host "CPU found: $($profile.Hardware.CPU_Manufacturer)"
Write-Host "Programs found: $($profile.Software.InstalledPackages.Count)"
```

## Using Profiles for Recommendations

Once you have a profile, you can get smart recommendations:

```powershell
# Get your system profile
$profile = Get-DotWinSystemProfile

# Get recommendations based on your profile
$recommendations = Get-DotWinRecommendations -SystemProfile $profile

# See the top 5 recommendations
$recommendations | Select-Object -First 5 | Format-Table Title, Priority, Category
```

## What DotWin Does With This Information

DotWin uses your profile to:

1. **Recommend Software**: Suggests programs that match your user type
2. **Optimize Settings**: Recommends Windows settings for your hardware
3. **Update Drivers**: Finds the right drivers for your specific hardware
4. **Improve Performance**: Suggests upgrades or optimizations
5. **Enhance Security**: Recommends security tools and settings

## Privacy

Your system profile contains information about your computer but:

- It stays on your computer unless you choose to export it
- DotWin doesn't send this information anywhere
- You can see exactly what information is collected
- You control what gets profiled

## Examples

### For Developers

```powershell
# Get profile and check development setup
$profile = Get-DotWinSystemProfile
if ($profile.Software.GetUserType() -eq "Developer") {
    Write-Host "Development environment detected!"
    Write-Host "Developer Score: $($profile.SystemMetrics.DeveloperFriendliness)/100"
}
```

### For Gamers

```powershell
# Check if system is good for gaming
$profile = Get-DotWinSystemProfile
if ($profile.Hardware.IsGamingOptimized()) {
    Write-Host "Gaming hardware detected!"
    Write-Host "Performance Score: $($profile.SystemMetrics.PerformanceScore)/100"
}
```

### For General Users

```powershell
# Get simple overview
$profile = Get-DotWinSystemProfile
Write-Host "Computer Type: $($profile.Hardware.GetHardwareCategory())"
Write-Host "Overall Performance: $($profile.SystemMetrics.PerformanceScore)/100"
Write-Host "Security Level: $($profile.SystemMetrics.SecurityScore)/100"
```

## Next Steps

After profiling your system:

1. Use `Get-DotWinRecommendations` to see what DotWin suggests
2. Apply safe recommendations with `Invoke-DotWinConfiguration`
3. Re-profile periodically to see improvements

System profiling is the foundation that makes DotWin smart. The better DotWin understands your computer, the better recommendations it can make!
