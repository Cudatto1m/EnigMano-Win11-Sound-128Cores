$ErrorActionPreference = "Stop"

function Timestamp { (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") }
function Log($msg) { Write-Host "[ENIGMANO $(Timestamp)] $msg" }
function Fail($msg) { Write-Error "[ENIGMANO-ERROR $(Timestamp)] $msg"; Exit 1 }

# === ASCII BANNER ===
$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
Write-Host @"
----------------------------------------------------
         ENIGMANO INSTANCE $env:INSTANCE_ID BOOTING
----------------------------------------------------
  STATUS    : Initializing deployment sequence
  TIME      : $now
  ARCHITECT : SHAHZAIB-YT
----------------------------------------------------
"@

# === ENVIRONMENT VARIABLES ===
$SECRET_SHAHZAIB = $env:SECRET_SHAHZAIB
$NGROK_SHAHZAIB  = $env:NGROK_SHAHZAIB
$INSTANCE_ID     = [int]$env:INSTANCE_ID
$NEXT_INSTANCE_ID = $INSTANCE_ID + 1
$WORKFLOW_FILE   = "enigmano-Win-11.yml"
$BRANCH          = "main"
$RUNNER_ENV      = $env:RUNNER_ENV

# === TUNNEL SETUP ===
Remove-Item -Force .\ngrok.exe, .\ngrok.zip -ErrorAction SilentlyContinue
Invoke-WebRequest https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip -OutFile ngrok.zip
Expand-Archive ngrok.zip -DestinationPath .
.\ngrok.exe authtoken $NGROK_SHAHZAIB
Log "Secure transport channel initiated"

# === ACCESS ENABLEMENT ===
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "UserAuthentication" -Value 1
$secPass = ConvertTo-SecureString "P@ssw0rd!" -AsPlainText -Force
Set-LocalUser -Name "runneradmin" -Password $secPass
Log "Instance ingress protocols activated"

# === REGION SCAN LOOP ===
$tunnel = $null
$regionList = @("us", "eu", "ap", "au", "sa", "jp", "in")
$regionIndex = 0

# === FIXED REGION ===
$tunnel = $null
$region = "ap"   # đổi sang "jp" nếu muốn Nhật
Log "Using fixed region: $region"

Get-Process ngrok -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath .\ngrok.exe -ArgumentList "tcp --region $region 3389" -WindowStyle Hidden

# ⏳ Chờ lâu hơn để ngrok khởi động
Start-Sleep -Seconds 20

try {
    # Debug: xem log API
    $resp = Invoke-RestMethod -Uri "http://127.0.0.1:4040/api/tunnels"
    Log "Ngrok API response: $($resp | ConvertTo-Json -Depth 3 -Compress)"

    $tunnel = ($resp.tunnels | Where-Object { $_.proto -eq "tcp" }).public_url
    if (-not $tunnel) {
        Fail "Ngrok tunnel creation failed in region $region"
    }
} catch {
    Fail "Ngrok API unreachable: $_"
}
# === SOFTWARE INSTALLATION DEPLOYMENTS ===

try {
    Log "Deploying Env-Personalization... Estimated Time: ~15 Seconds "
    Invoke-WebRequest "https://gitlab.com/Shahzaib-YT/enigmano-windows-11-with-sound/-/raw/main/Env-Personalization.ps1" -OutFile Env-Personalization.ps1
    .\Env-Personalization.ps1
} catch { Fail "Env-Personalization deployment failed: $_" }


try {
    Log "Deploying Brave-Browser... Estimated Time: ~40 Seconds"
    Invoke-WebRequest "https://gitlab.com/Shahzaib-YT/enigmano-windows-11-with-sound/-/raw/main/Brave-Browser.ps1" -OutFile Brave-Browser.ps1
    .\Brave-Browser.ps1
} catch { Fail "Brave-Browser deployment failed: $_" }


try {
    Log "Deploying Browser-Extensions... Estimated Time: ~25 Seconds"
    Invoke-WebRequest "https://gitlab.com/Shahzaib-YT/enigmano-windows-11-with-sound/-/raw/main/Browser-Extensions.ps1" -OutFile Browser-Extensions.ps1
    .\Browser-Extensions.ps1
} catch { Fail "Browser-Extensions deployment failed: $_" }

try {
    Log "Deploying Browser-Env-Setup... Estimated Time: ~55 Seconds"
    Invoke-WebRequest "https://gitlab.com/Shahzaib-YT/enigmano-windows-11-with-sound/-/raw/main/Browser-Env-Setup.ps1" -OutFile Browser-Env-Setup.ps1
    .\Browser-Env-Setup.ps1
} catch { Fail "Browser-Env-Setup deployment failed: $_" }

# === DATA VAULT CREATION ===
try {
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $dataFolderPath = Join-Path $desktopPath "Data"
    if (-not (Test-Path $dataFolderPath)) {
        New-Item -Path $dataFolderPath -ItemType Directory | Out-Null
    } else {
        Log "Data vault already exists at $dataFolderPath"
    }
} catch {
    Fail "Failed to create data vault: $_"
}



$tunnelClean = $tunnel -replace "^tcp://", ""
Write-Host "::notice title=EnigMano Link::Host: $tunnelClean`nUser: runneradmin`nPass: P@ssw0rd!"

# === SECONDARY DEPLOYMENTS ===

try {
    Log "Downloading IDM... Estimated Time: ~20 Seconds"
    Invoke-WebRequest "https://gitlab.com/Shahzaib-YT/enigmano-windows-11-with-sound/-/raw/main/Download_Manager.ps1" -OutFile Download_Manager.ps1
    .\Download_Manager.ps1
} catch { Fail "Download Manager deployment failed: $_" }

try {
    Log "Deploying Cloudflare-WARP... Estimated Time: ~180 Seconds."
    Invoke-WebRequest "https://gitlab.com/Shahzaib-YT/enigmano-windows-11-with-sound/-/raw/main/Cloudflare-WARP.ps1" -OutFile Cloudflare-WARP.ps1
    .\Cloudflare-WARP.ps1
} catch { Fail "Cloudflare-WARP deployment failed: $_" }


# === TIMERS ===
$totalMinutes    = 340
$handoffMinutes  = 330
$shutdownMinutes = 335
$startTime       = Get-Date
$endTime         = $startTime.AddMinutes($totalMinutes)
$handoffTime     = $startTime.AddMinutes($handoffMinutes)
$shutdownTime    = $startTime.AddMinutes($shutdownMinutes)

# === HANDOFF MONITOR (randomized) ===
while ((Get-Date) -lt $handoffTime) {
    $now       = Get-Date
    $elapsed   = [math]::Round(($now - $startTime).TotalMinutes, 1)
    $remaining = [math]::Round(($endTime - $now).TotalMinutes, 1)
    Log "Instance uptime: $elapsed min | Mission window remaining: $remaining min"

    $waitMinutes = Get-Random -Minimum 15 -Maximum 30
    Start-Sleep -Seconds ($waitMinutes * 60)
}

# === DISPATCH NEXT INSTANCE ===
try {
    # Get authenticated user info
    $userInfo = Invoke-RestMethod -Uri "https://api.github.com/user" -Headers @{ Authorization = "Bearer $SECRET_SHAHZAIB" }
    Log "Authenticated controller: $($userInfo.login)"

    # Detect the current repository automatically from GITHUB_REPOSITORY env variable if available
    if ($env:GITHUB_REPOSITORY) {
        $userRepo = $env:GITHUB_REPOSITORY
        Log "Detected repository from environment: $userRepo"
    }
    else {
        Log "Fetching repository list for authenticated user..."
        $repos = Invoke-RestMethod -Uri "https://api.github.com/user/repos?per_page=100" -Headers @{ Authorization = "Bearer $SECRET_SHAHZAIB" }
        $currentRepo = (Get-Location).Path | Split-Path -Leaf
        $userRepo = ($repos | Where-Object { $_.name -eq $currentRepo }).full_name

        if (-not $userRepo) {
            Fail "Repository '$currentRepo' not found in your account."
        }
    }

    # Prepare dispatch payload
    $dispatchPayload = @{
        ref    = $BRANCH
        inputs = @{ INSTANCE = "$NEXT_INSTANCE_ID" }
    } | ConvertTo-Json -Depth 3

    $dispatchURL = "https://api.github.com/repos/$userRepo/actions/workflows/$WORKFLOW_FILE/dispatches"

    # Trigger next instance
    Invoke-RestMethod -Uri $dispatchURL -Headers @{
        Authorization = "Bearer $SECRET_SHAHZAIB"
        Accept        = "application/vnd.github.v3+json"
    } -Method Post -Body $dispatchPayload -ContentType "application/json"

    Log "Next instance deployment triggered for $userRepo (workflow: $WORKFLOW_FILE)"
}
catch {
    Fail "Deployment trigger failed: $_"
}


# === SHUTDOWN MONITOR (randomized log intervals) ===
while ((Get-Date) -lt $shutdownTime) {
    $now       = Get-Date
    $elapsed   = [math]::Round(($now - $startTime).TotalMinutes, 1)
    $remaining = [math]::Round(($endTime - $now).TotalMinutes, 1)
    Log "Final phase status: $elapsed min elapsed | $remaining min until full shutdown"

    $waitMinutes = Get-Random -Minimum 15 -Maximum 30
    Start-Sleep -Seconds ($waitMinutes * 60)
}

# === TERMINATION ===
Log "Decommissioning EnigMano instance $INSTANCE_ID"

if ($RUNNER_ENV -eq "self-hosted") {
    Stop-Computer -Force
} else {
    Log "Termination skipped on hosted environment. Process exit."
    Exit
}
