param(
    [string]$InstallDir = $PSScriptRoot,
    [string]$HfToken    = $env:HF_TOKEN
)

function Log {
    param([string]$Level = "INFO", [string]$Message)
    Write-Host ("{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message)
}

Log "INFO" "=== 1o1 AI by ManjuLAB - Setup Starting ==="
Log "INFO" "Install directory: $InstallDir"

# --- Python check ---
Log "INFO" "Checking Python installation..."
$py = $null
foreach ($cmd in @("python","python3")) {
    try {
        $ver = & $cmd --version 2>&1
        if ($ver -match "Python (\d+)\.(\d+)") {
            if ([int]$Matches[1] -eq 3 -and [int]$Matches[2] -ge 10) {
                $py = $cmd
                Log "INFO" "Found compatible Python: $ver"
                break
            }
        }
    } catch {}
}
if (-not $py) { Log "ERROR" "Python 3.10+ not found. Install from https://python.org"; exit 1 }

# --- Virtual environment ---
$venvPath = Join-Path $InstallDir ".venv"
Log "INFO" "Creating virtual environment at $venvPath..."
& $py -m venv $venvPath
if ($LASTEXITCODE -ne 0) { Log "ERROR" "Failed to create venv"; exit 1 }
Log "INFO" "Virtual environment ready."
$pip   = Join-Path $venvPath "Scripts\pip.exe"
$pyExe = Join-Path $venvPath "Scripts\python.exe"

# --- Torch (cu128 supports Python 3.12 and 3.13) ---
Log "INFO" "Installing torch>=2.6.0 (CUDA 12.8 index, Python 3.13 compatible)..."
& $pip install "torch>=2.6.0" "torchaudio>=2.6.0" --index-url https://download.pytorch.org/whl/cu128 --quiet
if ($LASTEXITCODE -ne 0) {
    Log "WARN" "CUDA 12.8 wheel failed, installing CPU-only from PyPI..."
    & $pip install "torch>=2.6.0" "torchaudio>=2.6.0" --quiet
    if ($LASTEXITCODE -ne 0) { Log "ERROR" "torch install failed. Check internet."; exit 1 }
}
Log "INFO" "torch installed."

# --- Other dependencies ---
$deps = @(
    "transformers>=4.40.0", "huggingface_hub>=0.23.0", "fastapi>=0.111.0",
    "uvicorn[standard]>=0.30.0", "websockets>=12.0", "numpy>=1.26.0",
    "sounddevice>=0.4.7", "scipy>=1.13.0", "python-dotenv>=1.0.0",
    "aiofiles>=23.2.1", "cryptography>=42.0.0"
)
foreach ($dep in $deps) {
    Log "INFO" "Installing $dep..."
    & $pip install $dep --quiet
    if ($LASTEXITCODE -ne 0) { Log "WARN" "Failed to install $dep - continuing." }
}
Log "INFO" "Core dependencies installed."

# --- SSL cert (PEM files for uvicorn) ---
Log "INFO" "Generating self-signed SSL certificate (server.crt / server.key)..."
& $pyExe -c @"
import ipaddress
from cryptography import x509
from cryptography.x509.oid import NameOID, ExtendedKeyUsageOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from datetime import datetime, timedelta, timezone
import os

base = r'$InstallDir'
key_path  = os.path.join(base, 'server.key')
cert_path = os.path.join(base, 'server.crt')

key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
name = x509.Name([
    x509.NameAttribute(NameOID.COMMON_NAME, u'localhost'),
    x509.NameAttribute(NameOID.ORGANIZATION_NAME, u'ManjuLAB'),
])
cert = (x509.CertificateBuilder()
    .subject_name(name).issuer_name(name)
    .public_key(key.public_key())
    .serial_number(x509.random_serial_number())
    .not_valid_before(datetime.now(timezone.utc))
    .not_valid_after(datetime.now(timezone.utc) + timedelta(days=1825))
    .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
    .add_extension(
        x509.KeyUsage(
            digital_signature=True, key_encipherment=True,
            content_commitment=False, data_encipherment=False,
            key_agreement=False, key_cert_sign=False,
            crl_sign=False, encipher_only=False, decipher_only=False,
        ),
        critical=True,
    )
    .add_extension(
        x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]),
        critical=False,
    )
    .add_extension(
        x509.SubjectAlternativeName([
            x509.DNSName(u'localhost'),
            x509.IPAddress(ipaddress.IPv4Address(u'127.0.0.1')),
        ]),
        critical=False,
    )
    .sign(key, hashes.SHA256()))

with open(key_path, 'wb') as f:
    f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
with open(cert_path, 'wb') as f:
    f.write(cert.public_bytes(serialization.Encoding.PEM))
print('SSL cert written: server.crt + server.key')
"@
Log "INFO" "SSL certs generated."

# Trust cert in Windows (for browser to accept wss://localhost)
$certTrusted = $false
try {
    $certObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $InstallDir "server.crt"))
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","LocalMachine")
    $store.Open("ReadWrite"); $store.Add($certObj); $store.Close()
    Log "INFO" "Certificate trusted in LocalMachine\Root (wss:// will work in browsers)."
    $certTrusted = $true
} catch { Log "WARN" "LocalMachine\Root trust failed (requires Admin): $_" }

if (-not $certTrusted) {
    try {
        $certObj = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $InstallDir "server.crt"))
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","CurrentUser")
        $store.Open("ReadWrite"); $store.Add($certObj); $store.Close()
        Log "INFO" "Certificate trusted in CurrentUser\Root."
        $certTrusted = $true
    } catch { Log "WARN" "CurrentUser\Root trust also failed: $_" }
}

if (-not $certTrusted) {
    Log "WARN" "Could not auto-trust cert. Before using the demo, open https://localhost:8998/ in your browser and click 'Advanced' -> 'Proceed to localhost' to trust the certificate."
}

# --- Model weights (optional, requires HuggingFace token) ---
if ($HfToken) {
    Log "INFO" "HF_TOKEN found. Downloading model weights from HuggingFace..."
    & $pyExe -c @"
from huggingface_hub import snapshot_download
import os
snapshot_download(
    repo_id='1o1-ai/1o1-ai',
    local_dir=r'$InstallDir\models\1o1-ai',
    token='$HfToken'
)
print('Model weights downloaded.')
"@
    Log "INFO" "Model weights step complete."
} else {
    Log "WARN" "No HF_TOKEN set - skipping model download."
    Log "WARN" "To download weights later: set HF_TOKEN env var then re-run setup.ps1"
}

# --- Config ---
Log "INFO" "Writing config.json..."
@{
    host         = "localhost"
    port         = 8998
    cert         = "$InstallDir\server.crt"
    key          = "$InstallDir\server.key"
    cors_origins = @("https://yogabrata.com","http://localhost:3000")
    model_path   = "$InstallDir\models\1o1-ai"
} | ConvertTo-Json -Depth 5 | Out-File (Join-Path $InstallDir "config.json") -Encoding utf8
Log "INFO" "config.json written."

Log "INFO" ""
Log "INFO" "=== Setup Complete! ==="
Log "INFO" "Run: .\start-1o1.bat"
Log "INFO" "Then open: https://yogabrata.com/demo.html"
Log "INFO" ""
