# 1o1 AI Setup Script - ManjuLAB
# Installs Python, venv, dependencies, model weights, SSL cert
# Configures CORS for yogabrata.com seamless connection
# Author: whizyoga-ai | https://yogabrata.com

param(
    [string]$InstallDir = $PSScriptRoot,
    [switch]$Silent
)

$ErrorActionPreference = 'Stop'
$LogFile = Join-Path $InstallDir 'setup.log'

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogFile -Value $entry
    if (-not $Silent) { Write-Host $entry }
}

function Test-Command {
    param([string]$Cmd)
    return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue)
}

Write-Log '=== 1o1 AI by ManjuLAB - Setup Starting ==='
Write-Log "Install directory: $InstallDir"

# --- Step 1: Check / Install Python 3.10+ ---
Write-Log 'Checking Python installation...'
$pythonCmd = $null
foreach ($cmd in @('python3', 'python')) {
    if (Test-Command $cmd) {
        $ver = & $cmd --version 2>&1
        if ($ver -match 'Python 3\.([1-9][0-9]|[1][0-9])') {
            $pythonCmd = $cmd
            Write-Log "Found compatible Python: $ver"
            break
        }
    }
}

if (-not $pythonCmd) {
    Write-Log 'Python 3.10+ not found. Downloading Python 3.11.9...'
    $pyUrl = 'https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe'
    $pyInstaller = Join-Path $env:TEMP 'python-3.11.9-amd64.exe'
    Invoke-WebRequest -Uri $pyUrl -OutFile $pyInstaller -UseBasicParsing
    Write-Log 'Installing Python 3.11.9 (this may take a minute)...'
    Start-Process -FilePath $pyInstaller -ArgumentList '/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1' -Wait
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $pythonCmd = 'python'
    Write-Log 'Python installed successfully.'
}

# --- Step 2: Create virtual environment ---
$venvDir = Join-Path $InstallDir '.venv'
Write-Log "Creating virtual environment at $venvDir..."
if (-not (Test-Path $venvDir)) {
    & $pythonCmd -m venv $venvDir
}
$pip = Join-Path $venvDir 'Scripts\pip.exe'
$pythonVenv = Join-Path $venvDir 'Scripts\python.exe'
Write-Log 'Virtual environment ready.'

# --- Step 3: Install Python dependencies ---
Write-Log 'Installing Python dependencies...'
& $pip install --upgrade pip --quiet
$reqFile = Join-Path $InstallDir 'requirements.txt'
if (Test-Path $reqFile) {
    & $pip install -r $reqFile --quiet
    Write-Log 'Requirements installed from requirements.txt'
} else {
    # Fallback: install core deps for PersonaPlex / 1o1-ai
    $deps = @(
        'torch==2.3.1', 'torchaudio==2.3.1',
        'transformers>=4.40.0', 'huggingface_hub>=0.23.0',
        'fastapi>=0.111.0', 'uvicorn[standard]>=0.30.0',
        'websockets>=12.0', 'numpy>=1.26.0',
        'sounddevice>=0.4.7', 'scipy>=1.13.0',
        'python-dotenv>=1.0.0', 'aiofiles>=23.2.1'
    )
    foreach ($dep in $deps) {
        Write-Log "Installing $dep..."
        & $pip install $dep --quiet
    }
    Write-Log 'Core dependencies installed.'
}

# --- Step 4: Download model weights from HuggingFace ---
Write-Log 'Downloading 1o1-ai model weights from HuggingFace...'
$modelDir = Join-Path $InstallDir 'models'
if (-not (Test-Path $modelDir)) { New-Item -ItemType Directory -Path $modelDir | Out-Null }
$hfScript = @"
import os, sys
try:
    from huggingface_hub import snapshot_download
    snapshot_download(
        repo_id='kyutai/moshiko-pytorch-bf16',
        local_dir=r'$modelDir',
        ignore_patterns=['*.msgpack', '*.h5'],
        resume_download=True
    )
    print('Model weights downloaded successfully.')
except Exception as e:
    print(f'Warning: Could not download model weights automatically: {e}')
    print('You can download manually from https://huggingface.co/kyutai/moshiko-pytorch-bf16')
    sys.exit(0)
"@
& $pythonVenv -c $hfScript
Write-Log 'Model weights step complete.'

# --- Step 5: Generate self-signed SSL cert for localhost:8998 ---
Write-Log 'Generating self-signed SSL certificate for wss://localhost:8998...'
$certDir = Join-Path $InstallDir 'certs'
if (-not (Test-Path $certDir)) { New-Item -ItemType Directory -Path $certDir | Out-Null }
$certPath = Join-Path $certDir 'localhost.crt'
$keyPath = Join-Path $certDir 'localhost.key'

if (-not (Test-Path $certPath)) {
    # Try OpenSSL first
    if (Test-Command 'openssl') {
        $subj = '/CN=localhost/O=ManjuLAB/OU=1o1-ai'
        openssl req -x509 -newkey rsa:2048 -keyout $keyPath -out $certPath -days 3650 -nodes -subj $subj 2>&1 | Out-Null
        Write-Log 'SSL certificate generated via OpenSSL.'
    } else {
        # PowerShell fallback
        $cert = New-SelfSignedCertificate -DnsName 'localhost' -CertStoreLocation 'cert:\LocalMachine\My' -NotAfter (Get-Date).AddYears(10)
        Export-Certificate -Cert $cert -FilePath (Join-Path $certDir 'localhost.cer') | Out-Null
        Write-Log 'SSL certificate generated via PowerShell (stored in LocalMachine\My).'
        Write-Log "Thumbprint: $($cert.Thumbprint)"
        # Save thumbprint for start script
        $cert.Thumbprint | Out-File (Join-Path $certDir 'thumbprint.txt')
    }
} else {
    Write-Log 'SSL certificate already exists, skipping.'
}

# --- Step 6: Write config.json (CORS + backend settings) ---
Write-Log 'Writing 1o1-ai config.json...'
$config = @{
    host = '0.0.0.0'
    port = 8998
    ssl_certfile = $certPath.Replace('\', '/')
    ssl_keyfile = $keyPath.Replace('\', '/')
    allowed_origins = @(
        'https://yogabrata.com',
        'https://www.yogabrata.com',
        'http://localhost:3000',
        'http://127.0.0.1:3000',
        'null'
    )
    model_dir = $modelDir.Replace('\', '/')
    sample_rate = 24000
    audio_format = 'pcm_int16'
    max_sessions = 5
    log_level = 'info'
    manjulab = @{
        brand = '1o1 AI by ManjuLAB'
        frontend_url = 'https://yogabrata.com'
        demo_url = 'https://yogabrata.com/demo.html'
        author = 'whizyoga-ai'
        version = '1.0.0'
    }
} | ConvertTo-Json -Depth 5
$config | Out-File (Join-Path $InstallDir 'config.json') -Encoding UTF8
Write-Log 'config.json written with CORS origins for yogabrata.com.'

# --- Step 7: Trust the self-signed cert in Windows (for local WebSocket) ---
Write-Log 'Attempting to trust localhost SSL certificate in Windows...'
try {
    if (Test-Path $certPath) {
        Import-Certificate -FilePath $certPath -CertStoreLocation 'Cert:\LocalMachine\Root' | Out-Null
        Write-Log 'Certificate trusted in LocalMachine\Root store.'
    }
} catch {
    Write-Log "Certificate trust step skipped (may need admin): $_" 'WARN'
}

Write-Log ''
Write-Log '=== 1o1 AI Setup Complete! ==='
Write-Log ''
Write-Log 'To start the 1o1 AI server, run: start-1o1.bat'
Write-Log 'Then open: https://yogabrata.com/demo.html'
Write-Log 'The demo will connect to wss://localhost:8998 automatically.'
Write-Log ''
