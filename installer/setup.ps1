param(
    [string]$InstallDir = $PSScriptRoot
)

function Log {
    param([string]$Level = "INFO", [string]$Message)
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$ts] [$Level] $Message"
}

Log "INFO" "=== 1o1 AI by ManjuLAB - Setup Starting ==="
Log "INFO" "Install directory: $InstallDir"

# --- Python check ---
Log "INFO" "Checking Python installation..."
$py = $null
foreach ($cmd in @("python", "python3")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python (\d+)\.(\d+)") {
            $maj = [int]$Matches[1]; $min = [int]$Matches[2]
            if ($maj -eq 3 -and $min -ge 10) {
                $py = $cmd
                Log "INFO" "Found compatible Python: $ver"
                break
            }
        }
    } catch {}
}
if (-not $py) {
    Log "ERROR" "Python 3.10+ not found. Please install from https://python.org"
    exit 1
}

# --- Virtual environment ---
$venvPath = Join-Path $InstallDir ".venv"
Log "INFO" "Creating virtual environment at $venvPath..."
& $py -m venv $venvPath
if ($LASTEXITCODE -ne 0) { Log "ERROR" "Failed to create venv"; exit 1 }
Log "INFO" "Virtual environment ready."

$pip = Join-Path $venvPath "Scripts\pip.exe"

# --- Dependencies ---
Log "INFO" "Installing Python dependencies..."

# Torch - use PyTorch CUDA 12.1 index; works for both CUDA and CPU
Log "INFO" "Installing torch>=2.6.0 (CUDA 12.1 wheel index)..."
& $pip install "torch>=2.6.0" "torchaudio>=2.6.0" --index-url https://download.pytorch.org/whl/cu121 --quiet
if ($LASTEXITCODE -ne 0) {
    Log "WARN" "CUDA wheel failed, falling back to CPU torch..."
    & $pip install "torch>=2.6.0" "torchaudio>=2.6.0" --quiet
}

$deps = @(
    "transformers>=4.40.0",
    "huggingface_hub>=0.23.0",
    "fastapi>=0.111.0",
    "uvicorn[standard]>=0.30.0",
    "websockets>=12.0",
    "numpy>=1.26.0",
    "sounddevice>=0.4.7",
    "scipy>=1.13.0",
    "python-dotenv>=1.0.0",
    "aiofiles>=23.2.1"
)
foreach ($dep in $deps) {
    Log "INFO" "Installing $dep..."
    & $pip install $dep --quiet
    if ($LASTEXITCODE -ne 0) { Log "WARN" "Failed to install $dep - continuing." }
}
Log "INFO" "Core dependencies installed."

# --- Model weights ---
Log "INFO" "Downloading 1o1-ai model weights from HuggingFace..."
$pyExe = Join-Path $venvPath "Scripts\python.exe"
& $pyExe -c @"
from huggingface_hub import snapshot_download
snapshot_download(repo_id='1o1-ai/1o1-ai', local_dir='$($InstallDir -replace "\\","/")/models/1o1-ai', resume_download=True)
print('Model weights downloaded successfully.')
"@
Log "INFO" "Model weights step complete."

# --- SSL cert ---
Log "INFO" "Generating self-signed SSL certificate for wss://localhost:8998..."
$thumb = (New-SelfSignedCertificate `
    -DnsName "localhost" `
    -CertStoreLocation "cert:\LocalMachine\My" `
    -NotAfter (Get-Date).AddYears(5) `
    -FriendlyName "1o1-AI-localhost").Thumbprint
Log "INFO" "SSL certificate generated (stored in LocalMachine\My)."
Log "INFO" "Thumbprint: $thumb"

# Trust the cert
try {
    $cert = Get-Item "cert:\LocalMachine\My\$thumb"
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
    $store.Open("ReadWrite")
    $store.Add($cert)
    $store.Close()
    Log "INFO" "Certificate trusted in LocalMachine\Root."
} catch {
    Log "WARN" "Could not auto-trust certificate: $_"
}

# --- Config ---
Log "INFO" "Writing 1o1-ai config.json..."
$cfg = @{
    host             = "localhost"
    port             = 8998
    ssl_thumbprint   = $thumb
    cors_origins     = @("https://yogabrata.com","https://www.yogabrata.com","http://localhost:3000")
    model_path       = "$InstallDir\models\1o1-ai"
} | ConvertTo-Json -Depth 5
$cfg | Out-File -FilePath (Join-Path $InstallDir "config.json") -Encoding utf8
Log "INFO" "config.json written with CORS origins for yogabrata.com."

Log "INFO" ""
Log "INFO" "=== 1o1 AI Setup Complete! ==="
Log "INFO" ""
Log "INFO" "To start the 1o1 AI server, run: start-1o1.bat"
Log "INFO" "Then open: https://yogabrata.com/demo.html"
Log "INFO" "The demo will connect to wss://localhost:8998 automatically."
Log "INFO" ""
