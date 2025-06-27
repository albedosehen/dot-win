# DotWin Troubleshooting - Simple Solutions

Having trouble with DotWin? Don't worry! This guide will help you fix the most common problems quickly and easily.

## Quick Health Check

Before diving into specific problems, let's check if DotWin is working properly:

```powershell
# Check if DotWin is working
Test-DotWinEnvironment

# Get basic status
Get-DotWinStatus
```

If these commands work without errors, DotWin is probably fine and the issue is something specific.

## Most Common Problems

### Problem 1: "Can't Import DotWin Module"

**What you see:**

- Error message about module not found
- PowerShell says it can't load DotWin

**Easy fixes:**

1. **Make sure you're in the right folder:**

   ```powershell
   # Check if you're in the DotWin folder
   ls
   # You should see DotWin.psd1 in the list

   # If not, go to the right folder
   cd C:\path\to\DotWin
   ```

2. **Fix the execution policy:**

   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

3. **Try importing again:**

   ```powershell
   Import-Module .\DotWin.psd1 -Force
   ```

### Problem 2: "Access Denied" or "Permission Errors"

**What you see:**

- Errors about not having permission
- Can't make changes to system

**Easy fix:**
You need to run PowerShell as Administrator:

1. Close PowerShell
2. Click Start button
3. Type "PowerShell"
4. Right-click "Windows PowerShell"
5. Choose "Run as administrator"
6. Click "Yes" when Windows asks

### Problem 3: "DotWin Commands Don't Work"

**What you see:**

- Commands like `Get-DotWinStatus` give errors
- PowerShell doesn't recognize DotWin commands

**Easy fixes:**

1. **Make sure DotWin is loaded:**

   ```powershell
   # Check if DotWin is loaded
   Get-Module DotWin

   # If nothing shows up, load it
   Import-Module .\DotWin.psd1 -Force
   ```

2. **Check for typos:**
   - Make sure you're typing commands exactly right
   - PowerShell is case-sensitive sometimes

### Problem 4: "System Profiling Takes Forever"

**What you see:**

- `Get-DotWinSystemProfile` runs for a very long time
- Computer seems stuck

**Easy fixes:**

1. **Be patient first** - It can take 2-5 minutes on slower computers

2. **If it's really stuck, try this:**

   ```powershell
   # Press Ctrl+C to stop it
   # Then try a simpler version
   Get-DotWinSystemProfile -IncludeHardware:$false
   ```

3. **Check your internet connection** - DotWin needs internet to check for updates

### Problem 5: "No Recommendations Generated"

**What you see:**

- `Get-DotWinRecommendations` returns nothing
- Empty list of suggestions

**Easy fixes:**

1. **Make sure you profiled your system first:**

   ```powershell
   # Profile your system
   $profile = Get-DotWinSystemProfile

   # Then get recommendations
   Get-DotWinRecommendations -SystemProfile $profile
   ```

2. **Try getting more recommendations:**

   ```powershell
   Get-DotWinRecommendations -Priority "High","Medium","Low"
   ```

### Problem 6: "Downloads Keep Failing"

**What you see:**

- Programs won't install
- Download errors
- Network timeouts

**Easy fixes:**

1. **Check your internet connection:**

   ```powershell
   # Test if internet is working
   Test-NetConnection google.com
   ```

2. **Try again later** - Sometimes servers are busy

3. **Try a different source:**

   ```powershell
   # If Winget fails, try Chocolatey
   Install-SystemTools -Source Chocolatey
   ```

## When Things Go Really Wrong

### If DotWin Seems Completely Broken

1. **Start fresh:**

   ```powershell
   # Close PowerShell completely
   # Open new PowerShell as Administrator
   # Go to DotWin folder
   cd C:\path\to\DotWin

   # Import DotWin again
   Import-Module .\DotWin.psd1 -Force
   ```

2. **Check if Windows is the problem:**

   ```powershell
   # Run Windows system file checker
   sfc /scannow
   ```

### If Your Computer is Acting Weird After Using DotWin

Don't panic! DotWin is designed to be safe, but if something seems wrong:

1. **Restart your computer** - This fixes many temporary issues

2. **Use System Restore:**
   - Type "Create a restore point" in Start menu
   - Click "System Restore"
   - Choose a restore point from before you used DotWin

3. **Check what DotWin actually changed:**

   ```powershell
   # See what DotWin did (if you used backup)
   Get-DotWinStatus -IncludeSystemInfo
   ```

## Getting More Help

### See What DotWin Will Do Before It Does It

Always use `-WhatIf` to preview changes:

```powershell
# See what would happen without actually doing it
Invoke-DotWinConfiguration -WhatIf
Get-DotWinRecommendations -ApplyRecommendations -WhatIf
```

### Get Detailed Information

If you need to report a problem or get help:

```powershell
# Get detailed system information
Get-DotWinStatus -IncludeSystemInfo

# Check PowerShell version
$PSVersionTable.PSVersion

# Test DotWin environment
Test-DotWinEnvironment
```

### Enable Detailed Logging

If someone is helping you troubleshoot:

```powershell
# Turn on detailed logging
$VerbosePreference = "Continue"

# Run the problem command again
Get-DotWinSystemProfile -Verbose
```

## Frequently Asked Questions

**Q: Is DotWin safe to use?**
A: Yes! DotWin is designed to be safe. It won't break your computer, and most changes can be undone.

**Q: Do I need to be a computer expert to use DotWin?**
A: No! DotWin is designed for everyone. Just follow the simple commands in the guides.

**Q: What if I don't like what DotWin did?**
A: Most changes can be undone. You can also use Windows System Restore to go back to how things were before.

**Q: Why does DotWin need Administrator rights?**
A: To install programs and change system settings, Windows requires Administrator permission. This is normal and safe.

**Q: Can I use DotWin on Windows 10?**
A: Yes! DotWin works on Windows 10 and Windows 11.

**Q: What if a command doesn't work?**
A: Try these steps:

1. Make sure you're running PowerShell as Administrator
2. Check that DotWin is loaded (`Get-Module DotWin`)
3. Make sure you typed the command correctly

## Still Need Help?

If none of these solutions work:

1. **Check the [Getting Started Guide](GettingStarted.md)** - Make sure you followed all the setup steps
2. **Look at the main [README](../README.md)** - It has more examples
3. **Ask for help** - Create an issue on GitHub with:
   - What you were trying to do
   - What error message you got
   - Your Windows version
   - The output of `Get-DotWinStatus`

Remember: DotWin is designed to be helpful and safe. Most problems have simple solutions, and you can always start over if needed!
