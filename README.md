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

## 🚀 Installation

1.  Clone this repository or download the script:
    ```bash
    git clone https://github.com/Ronin-CK/Zen-Backup-Tool.git
    cd Zen-Backup-Tool
    ```

2.  Make the script executable:
    ```bash
    chmod +x zen-backup.sh
    ```

---

## 🛠️ Usage

Simply run the script from your terminal:

```bash
./zen-backup.sh
```

Select the profile you want to backup.

The backup will be saved as a compressed .tar.gz file in: ~/Backups/ZenBrowser/
