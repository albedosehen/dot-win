# DotWin - Simple Windows Setup Made Easy

DotWin helps you set up your Windows computer automatically. Think of it as a smart assistant that knows how to install programs, configure settings, and optimize your system - all with just a few simple commands.

## What Does DotWin Do?

DotWin takes care of the boring stuff when setting up a Windows computer:

- Installs your favorite programs automatically
- Removes unwanted bloatware
- Sets up development tools if you're a programmer
- Configures Windows settings for better performance
- Updates drivers to keep everything running smoothly

## Quick Start (Just 3 Steps!)

### Step 1: Download DotWin

Open PowerShell as Administrator and run:

```powershell
git clone https://github.com/your-org/DotWin.git
cd DotWin
```

### Step 2: Load DotWin

```powershell
Import-Module .\DotWin.psd1 -Force
```

### Step 3: Let DotWin Set Up Your System

```powershell
# Check what DotWin found about your system
Get-DotWinStatus

# Get smart recommendations for your computer
Get-DotWinRecommendations

# Apply the safe recommendations automatically
Invoke-DotWinConfiguration
```

That's it! DotWin will now set up your system based on what it thinks will work best for you.

## Common Things You Can Do

### Install Popular Programs

```powershell
# Install essential programs everyone needs
Install-Applications

# Install development tools (if you're a programmer)
Install-SystemTools -ToolCategory Development
```

### Clean Up Your System

```powershell
# Remove bloatware and unnecessary programs
Remove-Bloatware

# Turn off telemetry and tracking
Disable-Telemetry
```

### Update Drivers

```powershell
# Find and install driver updates
Search-ChipsetDriver | Install-ChipsetDriver
```

## Adding Your Own Programs

You can tell DotWin what programs you want by creating a simple configuration file. Here's an example:

```json
{
  "name": "My Setup",
  "items": [
    {
      "name": "Essential Programs",
      "type": "Packages",
      "properties": {
        "packages": ["firefox", "7zip", "vlc", "discord"]
      }
    }
  ]
}
```

Save this as `my-setup.json` and run:

```powershell
Invoke-DotWinConfiguration -ConfigurationPath ".\my-setup.json"
```

## Need Help?

If something goes wrong, try these commands:

```powershell
# Check if everything is working
Test-DotWinEnvironment

# Get detailed information about your system
Get-DotWinStatus -IncludeSystemInfo

# See what DotWin can do
Get-Help Get-DotWinStatus
```

## What You Need

- Windows 10 or 11
- PowerShell (already installed on Windows)
- Administrator rights (right-click PowerShell and choose "Run as Administrator")
- Internet connection

## Safety First

DotWin is designed to be safe:

- It won't break your system
- You can see what it will do before it does it (use `-WhatIf`)
- It can back up your settings before making changes
- Most changes can be undone

## More Information

- [Getting Started Guide](docs/GettingStarted.md) - Step-by-step instructions for beginners
- [Troubleshooting](docs/Troubleshooting.md) - Solutions to common problems

---

**DotWin makes Windows setup simple.** No more spending hours installing programs and tweaking settings - let DotWin do the work for you!
