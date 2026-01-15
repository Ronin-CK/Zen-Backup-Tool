# 🛡️ Zen Browser Backup Tool

A smart, "sanitized" backup utility for [Zen Browser](https://zen-browser.app/) on Linux. 

It solves the common issues of crashing profiles and missing icons when migrating between computers.

---

## ✨ Features

* **🧠 Intelligent Detection:** Automatically detects if you are using **Sine Mod**, standard **CSS themes**, or a **Vanilla** profile and backs up the correct visual files.
* **🧪 Settings Sanitization:** Scans your `prefs.js` and removes absolute file paths (like `/home/user/`) to prevent crashes when restoring to a new computer or username.
* **🔧 Auto-Fixes Icons:** Automatically injects the `svg.context-properties` fix into the backup. This ensures that **Sine Mod icons** and other SVG themes work immediately upon restore—no `about:config` tweaking required.
* **📦 Complete Data:** Backs up History, Bookmarks, Passwords (`key4.db` + `logins.json`), Cookies, Extensions, and Sessions.
---

##  🚀 Installation & Usage
## 🐧 Linux & 🍎 macOS

1.  Clone this repository or download the script:
    ```bash
    git clone https://github.com/Ronin-CK/Zen-Backup-Tool.git
    cd Zen-Backup-Tool
    ```

2.  Make the script executable:
    ```bash
    chmod +x zen-backup.sh
    ```

```bash
./zen-backup.sh
```

Select the profile you want to backup.

The backup will be saved as a compressed .tar.gz file in: ~/Backups/ZenBrowser/

🪟 Windows

1. Download: Clone the repository or download the ZIP file and extract it.

2. Press Windows Key, type PowerShell, right-click it, and Run as Administrator.
3. Enable Script Execution (First Time Only): By default, Windows blocks scripts for security. To allow this tool to run:

    - Press the Windows Key, type PowerShell, and press Enter.

   - Copy and paste the following command and hit Enter:
```bash
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
- Type Y and hit Enter.

4. Now right-clicking your zen-backup.ps1 and Run with PowerShell
