---
editor_options: 
  markdown: 
    wrap: 72
---

# Turas Setup Guide — Jess's Windows Machine

This guide covers the one-time setup required to get Turas working with
the shared Google Drive folder. Once done, you won't need to repeat it.

------------------------------------------------------------------------

## What This Achieves

-   Turas file browsers open directly in the **TurasProjects** folder
-   Config files use short paths like `ClientA/Wave1/data.xlsx` that
    work on both machines
-   Recent projects are remembered between Docker restarts
-   You and Duncan can both run the same config files without editing
    paths

------------------------------------------------------------------------

## Step 1 — Set Up Google Drive Desktop

1.  Download **Google Drive Desktop** from drive.google.com

2.  Install it and sign in to Google (with your account on the family
    plan)

3.  Open Google Drive Desktop settings (system tray icon → gear icon)

4.  Under **Google Drive → Sync options**, set to **Stream files**

5.  In File Explorer, find the `TurasProjects` folder under
    `Google Drive > My Drive`

6.  Right-click `TurasProjects` → **Available offline**

    This makes those files always fully local (no "file not found"
    errors).

------------------------------------------------------------------------

## Step 2 — Find Your TurasProjects Path

1.  In File Explorer, navigate to your `TurasProjects` folder
2.  Click in the address bar at the top — it will show the full path
3.  It will look something like: `G:\My Drive\TurasProjects`
    -   The drive letter (G:, H:, etc.) depends on your machine
    -   Copy this path — you'll need it in the next step

------------------------------------------------------------------------

## Step 3 — Create the `.env` File

1.  Open the Turas folder in File Explorer (where `docker-compose.yml`
    is)

2.  Open the file called `.env.example` in Notepad

3.  Change the last line to your actual path from Step 2, for example:

    ```         
    TURAS_PROJECTS_ROOT=G:/My Drive/TurasProjects
    ```

    **Important:**

    -   Use forward slashes `/` not backslashes `\`
    -   Do NOT put quotes around the path
    -   The drive letter and path must match exactly what you saw in
        Step 2

4.  Save the file as `.env` (not `.env.example`) in the same folder

    -   In Notepad: File → Save As → change the filename to `.env`
    -   If Windows adds `.txt` at the end, rename the file to remove it

------------------------------------------------------------------------

## Step 4 — Update and Restart Docker

Open **PowerShell** or **Command Prompt** in the Turas folder, then run:

``` powershell
docker-compose down
docker-compose up -d
```

Wait about 60 seconds for Turas to start, then open your browser and go
to:

```         
http://localhost:3838
```

------------------------------------------------------------------------

## Step 5 — Verify It's Working

1.  Open Turas at `http://localhost:3838`
2.  Click on any module (e.g., Tabs)
3.  Click **Browse for Project Folder**
4.  The file browser should open **directly in your TurasProjects
    folder**, not in your home directory
5.  Navigate to a project folder, select it, and confirm Turas finds the
    files

If the browser opens in the wrong place, check that your `.env` file has
the correct path (Step 3).

------------------------------------------------------------------------

## Day-to-Day Use

### File Paths in Configs

From now on, paths in config files should be **short relative paths**:

```         
# Good — works on both machines:
data_file: ClientA/Wave1/survey_data.xlsx

# Avoid — only works on one machine:
data_file: G:/My Drive/TurasProjects/ClientA/Wave1/survey_data.xlsx
```

When you browse for a file using the Turas file browser, it will
automatically use the short path format.

### Opening Module Sub-Windows

When you launch a module from the main Turas screen, it opens on a new
port (e.g. `http://localhost:3839`). A clickable link appears in the
launcher — click it to open the module in a new tab.

### Recent Projects

Recent projects are now saved in your `TurasProjects\.turas\` folder.
This means: - They survive Docker restarts - Up to 10 recent projects
are remembered per module - The same recent projects appear in the
launcher and in each module

------------------------------------------------------------------------

## Troubleshooting

### "File browser opens at the wrong place"

Check that your `.env` file exists (not `.env.example`) and that the
path in it matches the Google Drive path exactly.

### "Turas can't find a file I selected"

Make sure the file is in the `TurasProjects` folder. Files outside this
folder are not accessible inside Docker.

### "I see a cloud icon on files instead of a tick"

Google Drive is still downloading the file. Wait for the tick (fully
synced), then try again. If this keeps happening, check that you set
`TurasProjects` to Available Offline (Step 1, point 6).

### "Docker says the path doesn't exist"

-   Open your `.env` file in Notepad and check the path
-   Make sure you used forward slashes `/` not backslashes `\`
-   Check the drive letter matches what you see in File Explorer

------------------------------------------------------------------------

## Project Folder Structure

Organise your work inside `TurasProjects` like this:

```         
TurasProjects/
├── ClientA/
│   ├── Wave1/
│   │   ├── Crosstab_Config.xlsx   ← config file
│   │   └── survey_data.xlsx       ← data file
│   └── Wave2/
├── ClientB/
│   └── Phase1/
└── .turas/                        ← recent projects (auto-created)
```

Each project gets its own folder. Config and data files live together.

------------------------------------------------------------------------

*For any issues, contact Duncan.*
