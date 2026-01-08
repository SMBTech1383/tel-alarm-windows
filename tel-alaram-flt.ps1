# ==========================
# UTF-8 Output
# ==========================
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

# ==========================
# Telegram Credentials
# ==========================
$token  = "TOKEN_BOT"
$chatId = "TELEGRAM_CHAT_ID"

if (-not $token -or -not $chatId) {
    Write-Error "Telegram credentials are not set in environment variables."
    exit 1
}

# ==========================
# State File (Last Event Record)
# ==========================
$stateFile = "$PSScriptRoot\rdp_last_record.txt"
if (!(Test-Path $stateFile)) {
    "0" | Out-File $stateFile -Encoding ASCII
}

$lastRecord = [int64](Get-Content $stateFile)

# ==========================
# Get Last Failed RDP Event
# ==========================
$event = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id      = 4625
} -MaxEvents 1

if (!$event) { exit }

# Already processed?
if ($event.RecordId -le $lastRecord) {
    exit
}

# Save new RecordId
$event.RecordId | Out-File $stateFile -Encoding ASCII

# ==========================
# Emojis
# ==========================
$fail  = [char]0x274C  # ❌
$userI = [char]0x1F464 # 👤
$ipI   = [char]0x1F310 # 🌐
$timeI = [char]0x23F0  # ⏰
$lock  = [char]0x1F512 # 🔒
$pc    = [char]0x1F5A5 # 🖥

# ==========================
# Tehran Time
# ==========================
$tz = [System.TimeZoneInfo]::FindSystemTimeZoneById("Iran Standard Time")
$tehranTime = [System.TimeZoneInfo]::ConvertTimeFromUtc(
    $event.TimeCreated.ToUniversalTime(), $tz
)

# ==========================
# Extract Event Data
# ==========================
$username  = $event.Properties[5].Value
$ip        = $event.Properties[19].Value
$reason    = $event.Properties[8].Value
$logonType = $event.Properties[10].Value

# ==========================
# Logon Type Resolver
# ==========================
function Get-LogonTypeName {
    param ($type)
    switch ($type) {
        2  { "Local Console" }
        3  { "Network" }
        4  { "Batch Task" }
        5  { "Service" }
        7  { "Unlock" }
        8  { "Network Cleartext" }
        9  { "RunAs" }
        10 { "RDP" }
        11 { "Cached Interactive" }
        default { "Unknown ($type)" }
    }
}

$proto = Get-LogonTypeName $logonType

# ==========================
# Telegram Message
# ==========================
$text = @"
$fail RDP LOGIN FAILED
$pc Host: $env:COMPUTERNAME
$userI User: $username
$lock Reason: $reason
$ipI Protocol: $proto
$ipI IP: $ip
$timeI Time (Tehran): $tehranTime
"@

# ==========================
# Send to Telegram
# ==========================
Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendMessage" `
    -Method POST -Body @{
        chat_id = $chatId
        text    = $text
    }
