# ============================================================
#  EnigMano-Instance.ps1 (Fixed Region + No API 4040)
# ============================================================

function Log($msg) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[ENIGMANO-LOG $time] $msg"
}

function Fail($msg) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Error "[ENIGMANO-ERROR $time] $msg"
    exit 1
}

# --- Secrets ---
if (-not $env:NGROK_SHAHZAIB) {
    Fail "Missing secret: NGROK_SHAHZAIB"
}
if (-not $env:SECRET_SHAHZAIB) {
    Fail "Missing secret: SECRET_SHAHZAIB"
}

# --- Download ngrok if missing ---
if (-not (Test-Path ".\ngrok.exe")) {
    Log "Downloading ngrok..."
    Invoke-WebRequest -Uri "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip" -OutFile "ngrok.zip" -UseBasicParsing
    Expand-Archive ngrok.zip -DestinationPath . -Force
    Remove-Item ngrok.zip
    if (!(Test-Path ".\ngrok.exe")) {
        Fail "ngrok.exe not found after download"
    }
}

# --- Authenticate ngrok ---
Log "Authenticating ngrok..."
& .\ngrok.exe authtoken $env:NGROK_SHAHZAIB
if ($LASTEXITCODE -ne 0) {
    Fail "Ngrok authentication failed"
}

# --- Start tunnel (fixed region: ap) ---
$region = "ap"
$tunnel = $null

Log "Starting ngrok in region: $region..."
$ngrokOutput = & .\ngrok.exe tcp --region $region 3389 2>&1

Log "=== Ngrok Output ==="
Write-Host $ngrokOutput

# --- Parse tcp address from log ---
$tunnel = ($ngrokOutput | Select-String -Pattern "tcp://.*").Matches.Value

if ($tunnel) {
    Log "✅ RDP Address: $tunnel"
} else {
    Fail "Ngrok failed to start or no tunnel found"
}

# --- Print Final Info ---
Write-Host "==============================================="
Write-Host " 🎉 EnigMano Deployment Successful!"
Write-Host " 🔑 Connect to RDP: $tunnel"
Write-Host " 🧑 Username: Administrator"
Write-Host " 🔒 Password: $env:SECRET_SHAHZAIB"
Write-Host "==============================================="
