# Turas Docker Manual

Maintained by Duncan Brett, The Research LampPost (Pty) Ltd.

Last updated: 9 April 2026

---

## How It Works

Turas runs inside a Docker container — a self-contained Linux environment with R and all dependencies pre-installed. Users on Windows (or any machine with Docker) run a simple batch file that pulls the latest image from Docker Hub and starts the app in their browser.

**Key components:**

| File | Location | Purpose |
|------|----------|---------|
| `Dockerfile` | Repo root | Recipe for building the container image |
| `.dockerignore` | Repo root | Files excluded from the image |
| `docker-compose.yml` | Repo root | Alternative way to run (not used by end users) |
| `turas.bat` | User's machine | Launcher script for Windows users |

**Ports:**

| Port | Purpose |
|------|---------|
| 3838 | Main Turas launcher |
| 3839–3848 | Module sessions (Tabs, Tracker, etc.) |

**Docker Hub image:** `duncanrbrett/turas:latest`

---

## 1. Pushing Updates to Users

When you have made changes to Turas code and want to deploy them:

### Step 1: Build the image

```bash
cd /Users/duncan/Dev/Turas
docker build --platform linux/amd64 -t turas .
```

**Build times:**
- First build (or after `renv.lock` changes): 30–60 minutes (R packages compiling)
- Subsequent builds (code-only changes): 5–30 seconds (Docker layer caching)

If the build fails, check the error output. Common causes:
- New R package not in `renv.lock` — run `renv::snapshot()` first
- Missing system library — add it to the `apt-get install` block in the Dockerfile

### Step 2: Tag and push to Docker Hub

```bash
docker tag turas:latest duncanrbrett/turas:latest
docker push duncanrbrett/turas:latest
```

This uploads the image to Docker Hub. Users get the update next time they run `turas.bat`.

### Step 3: All-in-one command

For convenience, you can chain all three steps:

```bash
cd /Users/duncan/Dev/Turas && docker build --platform linux/amd64 -t turas . && docker tag turas:latest duncanrbrett/turas:latest && docker push duncanrbrett/turas:latest
```

### When is a rebuild needed?

| Change type | Rebuild needed? | Notes |
|-------------|-----------------|-------|
| R code changes | Yes | `COPY . .` layer rebuilds (fast) |
| New R package added | Yes | `renv.lock` change triggers full package install (slow) |
| Dockerfile changes | Yes | May trigger full or partial rebuild |
| Changes to `turas.bat` | No | That file lives on the user's machine, not in the image |
| Data/project files | No | Mounted at runtime, not baked into image |

---

## 2. Setting Up a New User's Machine

### Prerequisites

The user needs:
- **Windows 10/11 Pro, Enterprise, or Education** (for Hyper-V) — or Windows 10/11 Home with WSL2
- **Docker Desktop for Windows** installed
- At least 8 GB RAM, 10 GB free disk space

### Step 1: Install Docker Desktop

1. Download from https://www.docker.com/products/docker-desktop/
2. Run the installer — accept defaults
3. Restart the computer when prompted
4. Open Docker Desktop and wait for the engine to start (whale icon in system tray goes steady)
5. Docker Desktop must be running whenever the user wants to use Turas

### Step 2: Create the Turas folder

Create a folder at `Documents\Turas` (or wherever you prefer). This is where `turas.bat` will live.

### Step 3: Create turas.bat

Create a file called `turas.bat` in the Turas folder with this content:

```bat
@echo off
REM =====================================================
REM  turas.bat — Launch Turas
REM  Double-click this file whenever you want to use Turas
REM =====================================================

SET IMAGE=duncanrbrett/turas:latest
SET PORT=3838
SET URL=http://localhost:%PORT%

echo.
echo ============================================
echo   Starting Turas. Please wait...
echo ============================================
echo.

echo Checking for updates...
docker pull %IMAGE%

echo Stopping any previous session...
docker stop turas-app >nul 2>&1
docker rm turas-app >nul 2>&1

echo Launching Turas...
docker run -d --name turas-app -p %PORT%:3838 -p 3839-3848:3839-3848 -v "C:\Users\USERNAME\OneDrive\Projects:/data/Projects" %IMAGE%

echo Waiting for Turas to start...
timeout /t 30 /nobreak >nul

echo Opening Turas in your browser...
start %URL%

echo.
echo ============================================
echo   Turas is running!
echo   If your browser didn't open automatically,
echo   go to: http://localhost:3838
echo.
echo   Keep this window open while using Turas.
echo   When you are finished, type STOP and
echo   press Enter to shut Turas down.
echo ============================================
echo.

SET /P ACTION=Type STOP and press Enter when you are done:

docker stop turas-app >nul 2>&1
docker rm turas-app >nul 2>&1

echo.
echo Turas has been stopped. You can close this window.
pause
```

**IMPORTANT:** Replace `USERNAME` in the `-v` volume mount with the user's actual Windows username and adjust the path to point to their project data folder. To find the correct path:

1. Open File Explorer and navigate to their projects folder
2. Right-click the folder, select Properties
3. The "Location" field shows the full path (e.g., `C:\Users\jess\OneDrive\Projects`)

### Step 4: Test it

1. Make sure Docker Desktop is running (whale icon in system tray)
2. Double-click `turas.bat`
3. First run will take 5–10 minutes (downloading the full image)
4. Browser should open to `http://localhost:3838`
5. Click a module (e.g., Tabs), click "Launch New Session"
6. A blue link appears — click it to open the module in a new tab

### Current user setup: Jess Taylor

| Setting | Value |
|---------|-------|
| Machine | Windows PC |
| Docker Desktop | Installed |
| `turas.bat` location | `C:\Users\jess\Documents\Turas\turas.bat` |
| Volume mount | `C:\Users\jess\OneDrive\Projects:/data/Projects` |
| Ports | 3838 (launcher), 3839–3848 (modules) |

---

## 3. Updating Turas on Jess's Machine

Jess does not need to do anything special. The update process is:

1. **You** make code changes on your Mac
2. **You** build and push: `docker build ... && docker push ...` (see Section 1)
3. **Jess** double-clicks `turas.bat` — it automatically runs `docker pull` which downloads your latest image
4. Done. She always gets the latest version.

If you need to change `turas.bat` itself (e.g., adding a new volume mount), you'll need to edit the file on her machine directly (remote desktop, Teams screen share, etc.).

---

## 4. General Docker Management

### Checking what's running

```bash
docker ps                    # Show running containers
docker ps -a                 # Show all containers (including stopped)
docker images                # Show downloaded images
```

### Viewing container logs

If something isn't working, check the logs:

```bash
docker logs turas-app        # On user's machine (container name from turas.bat)
docker logs turas             # If using docker-compose
```

### Stopping and removing containers

```bash
docker stop turas-app        # Stop the container
docker rm turas-app          # Remove it
```

### Cleaning up disk space

Docker images accumulate over time. To reclaim space:

```bash
docker system prune          # Remove stopped containers, unused networks, dangling images
docker image prune -a        # Remove ALL unused images (will require re-download)
```

Run `docker system prune` occasionally on both your Mac and user machines. The `-a` flag is more aggressive — only use it if you need significant space back.

### Checking image size

```bash
docker images duncanrbrett/turas
```

The Turas image is large (~3-4 GB) because it includes R, all R packages, Node.js, and system libraries. This is normal for R-based Docker images.

### Docker Desktop updates

Docker Desktop periodically prompts for updates. General guidance:

- **Minor updates** (e.g., 4.37.1 to 4.37.2): Safe to install. These are bug fixes.
- **Major updates** (e.g., 4.37 to 4.38): Usually safe, but wait a week after release in case of issues. Check release notes at https://docs.docker.com/desktop/release-notes/
- **Don't update during active work** — restart is required.
- **Both your Mac and user machines** should run Docker Desktop. Keep them reasonably current (within a few versions of each other).

### Docker Hub authentication

If `docker push` fails with "denied" or "unauthorized":

```bash
docker login
```

Enter your Docker Hub username (`duncanrbrett`) and password/token. You only need to do this once per machine (credentials are cached).

### If a user's container won't start

Troubleshooting steps:

1. **Is Docker Desktop running?** Check for the whale icon in the system tray.
2. **Is the port in use?** Another app might be using port 3838. Check with `netstat -ano | findstr 3838` on Windows.
3. **Check logs:** `docker logs turas-app`
4. **Nuclear option:** Remove everything and start fresh:
   ```bash
   docker stop turas-app
   docker rm turas-app
   docker rmi duncanrbrett/turas:latest
   ```
   Then re-run `turas.bat` (will re-download the full image).

### OneDrive considerations

When mounting OneDrive folders into Docker:

- **Cloud-only files** (cloud icon in Explorer) will be automatically downloaded when Docker reads them. This is normal but can cause a burst of downloads the first time.
- **"Always keep on this device"** — right-click project folders the user actively works with and select this option. Prevents delays when Docker accesses them.
- **Docker only reads** from the mounted volume by default. It does not upload or duplicate files.
- **Sync conflicts** are unlikely but possible if the same file is open in Turas and modified on another device simultaneously.

---

## 5. Architecture Reference

### How the Docker image is built

```
Dockerfile
├── Base: rocker/shiny:4.5.3 (Ubuntu + R 4.5.3)
├── System libraries: libxml2, libcurl, SSL, fonts, etc.
├── Node.js 22 + npm tools: terser, clean-css, etc.
├── renv package restore (slow layer, cached unless renv.lock changes)
├── COPY application code (fast layer)
├── Configure R library paths
└── CMD: Run R directly with Shiny on port 3838
```

### How modules launch in Docker

1. User clicks a module in the launcher (port 3838)
2. Launcher spawns a new `Rscript` process inside the container
3. The module binds to the next available port (3839–3848)
4. A clickable link appears in the launcher UI
5. User clicks the link to open the module in a new browser tab
6. Each module gets its own port, so multiple modules can run simultaneously

### Key files in the image

| Path in container | Purpose |
|-------------------|---------|
| `/srv/shiny-server/turas/` | Application root |
| `/srv/shiny-server/turas/launch_turas.R` | Main entry point |
| `/srv/shiny-server/turas/renv/library/` | R packages |
| `/data/` | Mount point for user data |

---

## 6. Quick Reference

### Deploy an update
```bash
cd /Users/duncan/Dev/Turas && docker build --platform linux/amd64 -t turas . && docker tag turas:latest duncanrbrett/turas:latest && docker push duncanrbrett/turas:latest
```

### Check running containers
```bash
docker ps
```

### View logs
```bash
docker logs turas-app
```

### Clean up disk space
```bash
docker system prune
```

### Login to Docker Hub
```bash
docker login
```
