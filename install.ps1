#
# Moltbot Docker Installer - Windows PowerShell Version
# One-command setup for Moltbot on Docker for Windows
#
# Usage:
#   irm https://raw.githubusercontent.com/phioranex/moltbot-docker/main/install.ps1 | iex
#
# Or with options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/phioranex/moltbot-docker/main/install.ps1))) -NoStart
#

param(
    [string]$InstallDir = "$env:USERPROFILE\moltbot",
    [switch]$NoStart,
    [switch]$SkipOnboard,
    [switch]$PullOnly,
    [switch]$Help
)

# Config
$Image = "ghcr.io/phioranex/moltbot-docker:latest"
$RepoUrl = "https://github.com/phioranex/moltbot-docker"
$ComposeUrl = "https://raw.githubusercontent.com/phioranex/moltbot-docker/main/docker-compose.yml"

# Error handling
$ErrorActionPreference = "Stop"

# Functions
function Write-Banner {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║     __  __       _ _   _           _                         ║" -ForegroundColor Cyan
    Write-Host "║    |  \/  | ___ | | |_| |__   ___ | |_                       ║" -ForegroundColor Cyan
    Write-Host "║    | |\/| |/ _ \| | __| '_ \ / _ \| __|                      ║" -ForegroundColor Cyan
    Write-Host "║    | |  | | (_) | | |_| |_) | (_) | |_                       ║" -ForegroundColor Cyan
    Write-Host "║    |_|  |_|\___/|_|\__|_.__/ \___/ \__|                      ║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "║              Docker Installer by Phioranex                   ║" -ForegroundColor Cyan
    Write-Host "║                                                              ║" -ForegroundColor Cyan
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "▶ $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Test-Command {
    param([string]$Command)
    try {
        Get-Command $Command -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Show help
if ($Help) {
    Write-Host "Moltbot Docker Installer - Windows"
    Write-Host ""
    Write-Host "Usage: install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -InstallDir DIR   Installation directory (default: ~\moltbot)"
    Write-Host "  -NoStart          Don't start the gateway after setup"
    Write-Host "  -SkipOnboard      Skip onboarding wizard"
    Write-Host "  -PullOnly         Only pull the image, don't set up"
    Write-Host "  -Help             Show this help message"
    exit 0
}

# Main script
Write-Banner

Write-Step "Checking prerequisites..."

# Check Docker
if (Test-Command docker) {
    Write-Success "docker found"
} else {
    Write-Error "docker not found"
    Write-Host ""
    Write-Host "Docker is required but not installed." -ForegroundColor Red
    Write-Host "Install Docker Desktop: https://docs.docker.com/desktop/install/windows-install/" -ForegroundColor Yellow
    exit 1
}

# Check Docker Compose
$ComposeCmd = ""
if (docker compose version 2>$null) {
    Write-Success "Docker Compose found (plugin)"
    $ComposeCmd = "docker compose"
} elseif (Test-Command docker-compose) {
    Write-Success "Docker Compose found (standalone)"
    $ComposeCmd = "docker-compose"
} else {
    Write-Error "Docker Compose not found"
    Write-Host ""
    Write-Host "Docker Compose is required but not installed." -ForegroundColor Red
    Write-Host "It usually comes with Docker Desktop." -ForegroundColor Yellow
    exit 1
}

# Check Docker is running
try {
    docker info 2>$null | Out-Null
    Write-Success "Docker is running"
} catch {
    Write-Error "Docker is not running"
    Write-Host ""
    Write-Host "Please start Docker Desktop and try again." -ForegroundColor Red
    exit 1
}

# Pull only mode
if ($PullOnly) {
    Write-Step "Pulling Moltbot image..."
    docker pull $Image
    Write-Success "Image pulled successfully!"
    Write-Host ""
    Write-Host "Done! Run the installer again without -PullOnly to complete setup." -ForegroundColor Green
    exit 0
}

Write-Step "Setting up installation directory..."
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
Set-Location $InstallDir
Write-Success "Created $InstallDir"

Write-Step "Downloading docker-compose.yml..."
Invoke-WebRequest -Uri $ComposeUrl -OutFile "docker-compose.yml"
Write-Success "Downloaded docker-compose.yml"

Write-Step "Creating data directories..."
$ConfigDir = "$env:USERPROFILE\.clawdbot"
$WorkspaceDir = "$env:USERPROFILE\clawd"
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
New-Item -ItemType Directory -Force -Path $WorkspaceDir | Out-Null
Write-Success "Created $ConfigDir (config)"
Write-Success "Created $WorkspaceDir (workspace)"

Write-Step "Pulling Moltbot image..."
docker pull $Image
Write-Success "Image pulled successfully!"

# Onboarding
if (-not $SkipOnboard) {
    Write-Step "Initializing Moltbot configuration..."
    Write-Host "Setting up configuration and workspace..." -ForegroundColor Yellow
    Write-Host ""
    
    # Run setup to initialize config and workspace
    $setupResult = & $ComposeCmd.Split() run -T --rm moltbot-cli setup
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Setup failed"
        Write-Host "Failed to initialize configuration. Please check Docker logs." -ForegroundColor Red
        exit 1
    }
    Write-Success "Configuration initialized"
    
    Write-Step "Running onboarding wizard..."
    Write-Host "This will configure your AI provider and channels." -ForegroundColor Yellow
    Write-Host "Follow the prompts to complete setup." -ForegroundColor Yellow
    Write-Host ""
    
    # Run onboarding
    & $ComposeCmd.Split() run -T --rm moltbot-cli onboard
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Onboarding wizard was skipped or failed"
        Write-Host "You can run it later with: cd $InstallDir && $ComposeCmd run --rm moltbot-cli onboard" -ForegroundColor Yellow
    } else {
        Write-Success "Onboarding complete!"
    }
}

# Start gateway
if (-not $NoStart) {
    Write-Step "Starting Moltbot gateway..."
    & $ComposeCmd.Split() up -d moltbot-gateway
    
    # Wait for gateway to be ready
    Write-Host "Waiting for gateway to start" -NoNewline
    for ($i = 0; $i -lt 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:18789/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Host ""
                Write-Success "Gateway is running!"
                break
            }
        } catch {
            # Continue waiting
        }
        Write-Host "." -NoNewline
        Start-Sleep -Seconds 1
    }
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:18789/health" -TimeoutSec 1 -ErrorAction SilentlyContinue
        if ($response.StatusCode -ne 200) {
            throw
        }
    } catch {
        Write-Host ""
        Write-Warning "Gateway may still be starting. Check logs with: docker logs moltbot-gateway"
    }
}

# Success message
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "║              🎉 Moltbot installed successfully! 🎉           ║" -ForegroundColor Green
Write-Host "║                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host ""
Write-Host "Quick reference:" -ForegroundColor White
Write-Host "  Dashboard:      http://localhost:18789" -ForegroundColor Cyan
Write-Host "  Config:         $ConfigDir" -ForegroundColor Cyan
Write-Host "  Workspace:      $WorkspaceDir" -ForegroundColor Cyan
Write-Host "  Install dir:    $InstallDir" -ForegroundColor Cyan

Write-Host ""
Write-Host "Useful commands:" -ForegroundColor White
Write-Host "  View logs:      docker logs -f moltbot-gateway" -ForegroundColor Cyan
Write-Host "  Stop:           cd $InstallDir && $ComposeCmd down" -ForegroundColor Cyan
Write-Host "  Start:          cd $InstallDir && $ComposeCmd up -d moltbot-gateway" -ForegroundColor Cyan
Write-Host "  Restart:        cd $InstallDir && $ComposeCmd restart moltbot-gateway" -ForegroundColor Cyan
Write-Host "  CLI:            cd $InstallDir && $ComposeCmd run --rm moltbot-cli <command>" -ForegroundColor Cyan
Write-Host "  Update:         docker pull $Image && cd $InstallDir && $ComposeCmd up -d" -ForegroundColor Cyan

Write-Host ""
Write-Host "Documentation:  https://docs.molt.bot" -ForegroundColor White
Write-Host "Support:        https://discord.com/invite/clawd" -ForegroundColor White
Write-Host "Docker image:   $RepoUrl" -ForegroundColor White

Write-Host ""
Write-Host "Happy automating! 🤖" -ForegroundColor Yellow
Write-Host ""
