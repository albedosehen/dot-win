# Getting Started with DotWin

Welcome! This guide will help you set up DotWin and get your Windows computer configured in just a few minutes.

## What You'll Need

Before we start, make sure you have:

- A Windows 10 or Windows 11 computer
- Internet connection
- About 10 minutes of your time

That's it! Everything else is already on your computer.

## Step 1: Open PowerShell as Administrator

This is the most important step. Here's how:

1. Click the Start button
2. Type "PowerShell"
3. Right-click on "Windows PowerShell"
4. Choose "Run as administrator"
5. Click "Yes" when Windows asks for permission

You'll see a blue window with white text - that's PowerShell!

## Step 2: Download DotWin

Copy and paste this command into PowerShell and press Enter:

```powershell
git clone https://github.com/your-org/DotWin.git
```

Then type this and press Enter:

```powershell
cd DotWin
```

**Don't have Git?** No problem! You can download DotWin as a ZIP file instead:

1. Go to the DotWin website
2. Click "Download ZIP"
3. Extract the files to a folder like `C:\DotWin`
4. In PowerShell, type: `cd C:\DotWin`

## Step 3: Load DotWin

Copy and paste this command:

```powershell
Import-Module .\DotWin.psd1 -Force
```

If you see an error about execution policy, run this first:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

Then try the Import-Module command again.

## Step 4: Check Your System

Let's see what DotWin thinks about your computer:

```powershell
Get-DotWinStatus
```

This will show you information about your system. Don't worry if you don't understand everything - DotWin does!

## Step 5: Get Recommendations

Now let's see what DotWin recommends for your computer:

```powershell
Get-DotWinRecommendations
```

DotWin will analyze your system and suggest improvements. It might recommend:

- Programs to install
- Settings to change
- Drivers to update
- Features to enable

## Step 6: Apply the Recommendations

If the recommendations look good to you, apply them:

```powershell
Invoke-DotWinConfiguration
```

DotWin will now start setting up your system. This might take a few minutes depending on what needs to be done.

## What Just Happened?

DotWin looked at your computer and figured out:

- What kind of hardware you have
- What programs you might need
- How to optimize your settings
- What drivers need updating

Then it automatically configured everything for you!

## Common Tasks

### Install Popular Programs

Want to install common programs like browsers, media players, and utilities?

```powershell
Install-Applications
```

### Set Up for Programming

If you're a developer or want to learn programming:

```powershell
Install-SystemTools -ToolCategory Development
```

This installs things like Git, Visual Studio Code, and other developer tools.

### Clean Up Your Computer

Remove bloatware and unnecessary programs:

```powershell
Remove-Bloatware
```

Turn off tracking and telemetry:

```powershell
Disable-Telemetry
```

### Update Your Drivers

Keep your drivers up to date:

```powershell
Search-ChipsetDriver
```

## Creating Your Own Setup

You can tell DotWin exactly what programs you want. Create a file called `my-programs.json`:

```json
{
  "name": "My Favorite Programs",
  "items": [
    {
      "name": "Essential Programs",
      "type": "Packages",
      "properties": {
        "packages": [
          "firefox",
          "7zip",
          "vlc",
          "discord",
          "spotify"
        ]
      }
    }
  ]
}
```

Then run:

```powershell
Invoke-DotWinConfiguration -ConfigurationPath ".\my-programs.json"
```

## Something Not Working?

### PowerShell Won't Let You Run Commands

Try this:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Can't Import DotWin

Make sure you're in the right folder:

```powershell
cd C:\path\to\DotWin
Import-Module .\DotWin.psd1 -Force
```

### Want to See What DotWin Will Do First

Add `-WhatIf` to any command to see what it would do without actually doing it:

```powershell
Invoke-DotWinConfiguration -WhatIf
```

### Need More Help

Get detailed help for any command:

```powershell
Get-Help Get-DotWinStatus -Full
```

Check if everything is working properly:

```powershell
Test-DotWinEnvironment
```

## Tips for Success

1. **Always run PowerShell as Administrator** - This gives DotWin permission to make system changes
2. **Be patient** - Some operations take a few minutes, especially driver updates
3. **Use `-WhatIf` first** - This shows you what will happen before it happens
4. **Start simple** - Try the basic commands first before creating custom configurations

## What's Next?

Once you've got the basics working:

- Explore the different commands DotWin offers
- Create custom configurations for your specific needs
- Set up automatic updates and maintenance

Remember: DotWin is designed to be safe. It won't break your computer, and most changes can be undone if needed.

## Need More Help?

- Check the main [README](../README.md) for quick examples
- Look at the [Troubleshooting guide](Troubleshooting.md) for solutions to common problems
- Use `Get-Help <command-name>` in PowerShell for detailed help on any command

Happy computing!
