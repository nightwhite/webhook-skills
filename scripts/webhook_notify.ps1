param(
  [Parameter(Mandatory = $true)]
  [string]$SummaryFile,
  [ValidateSet("success", "error")]
  [string]$Status = "success",
  [string]$Event = "agent.done",
  [string]$Url = "",
  [string]$ConfigPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
  if (-not [string]::IsNullOrWhiteSpace($env:WEBHOOK_SKILLS_CONFIG)) {
    $ConfigPath = $env:WEBHOOK_SKILLS_CONFIG
  } else {
    $ConfigPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\\webhook-url.txt"))
  }
}

if ([string]::IsNullOrWhiteSpace($Url)) {
  if (-not [string]::IsNullOrWhiteSpace($env:WEBHOOK_URL)) {
    $Url = $env:WEBHOOK_URL
  } elseif (Test-Path -Path $ConfigPath) {
    $Url = (Get-Content -Raw -Path $ConfigPath).Trim()
  }
}

if ([string]::IsNullOrWhiteSpace($Url)) {
  throw "没有 webhook url：请先写入 $ConfigPath（或传 -Url 或设置 WEBHOOK_URL）"
}

$Url = $Url.Trim()
if ($Url -notmatch '^https?://') {
  throw "webhook url 必须以 http:// 或 https:// 开头：$Url"
}

# 如果是通过 -Url / WEBHOOK_URL 传进来的，并且本地文件还是空的，就顺手保存一下（下次就不用再传了）
$savedUrl = ""
if (Test-Path -Path $ConfigPath) {
  $savedUrl = (Get-Content -Raw -Path $ConfigPath).Trim()
}
$urlFromInput = $PSBoundParameters.ContainsKey("Url") -or (-not [string]::IsNullOrWhiteSpace($env:WEBHOOK_URL))
if ([string]::IsNullOrWhiteSpace($savedUrl) -and $urlFromInput) {
  $dir = Split-Path -Parent $ConfigPath
  New-Item -Force -ItemType Directory -Path $dir | Out-Null
  Set-Content -NoNewline -Encoding UTF8 -Path $ConfigPath -Value $Url
}

if (-not (Test-Path -Path $SummaryFile)) {
  throw "找不到 summary 文件：$SummaryFile"
}

$provider = "generic"
if ($Url -match 'dingtalk\.com/robot/send') {
  $provider = "dingtalk"
} elseif ($Url -match 'feishu\.cn/open-apis/bot/(v2/)?hook') {
  $provider = "feishu"
} elseif ($Url -match 'day\.app') {
  $provider = "bark"
}

$statusLabel = switch ($Status) {
  "success" { "成功" }
  "error" { "失败" }
  default { $Status }
}

$summaryText = (Get-Content -Raw -Path $SummaryFile).TrimEnd()
$text = "[$statusLabel] $Event`n$summaryText"

if ($provider -eq "feishu") {
  $payload = @{
    msg_type = "text"
    content  = @{ text = $text }
  }
  $payloadJson = $payload | ConvertTo-Json -Compress -Depth 6

  $argsList = @(
    "-fsS",
    "-X", "POST",
    $Url,
    "-H", "Content-Type: application/json; charset=utf-8"
  )
  if (-not [string]::IsNullOrWhiteSpace($env:WEBHOOK_TOKEN)) {
    $argsList += @("-H", "Authorization: Bearer $($env:WEBHOOK_TOKEN)")
  }
  $argsList += @("--data-binary", $payloadJson)
} elseif ($provider -eq "dingtalk") {
  $payload = @{
    msgtype = "text"
    text    = @{ content = $text }
  }
  $payloadJson = $payload | ConvertTo-Json -Compress -Depth 6

  $argsList = @(
    "-fsS",
    "-X", "POST",
    $Url,
    "-H", "Content-Type: application/json; charset=utf-8"
  )
  if (-not [string]::IsNullOrWhiteSpace($env:WEBHOOK_TOKEN)) {
    $argsList += @("-H", "Authorization: Bearer $($env:WEBHOOK_TOKEN)")
  }
  $argsList += @("--data-binary", $payloadJson)
} elseif ($provider -eq "bark") {
  $encoded = [System.Uri]::EscapeDataString($text)

  $base = $Url
  $query = ""
  if ($Url.Contains("?")) {
    $parts = $Url.Split("?", 2)
    $base = $parts[0]
    $query = "?" + $parts[1]
  }
  $base = $base.TrimEnd("/")
  $finalUrl = "$base/$encoded$query"

  $argsList = @("-fsS", $finalUrl)
  if (-not [string]::IsNullOrWhiteSpace($env:WEBHOOK_TOKEN)) {
    $argsList += @("-H", "Authorization: Bearer $($env:WEBHOOK_TOKEN)")
  }
} else {
  # 通用 webhook：发纯文本 + 两个头（event/status）
  $argsList = @(
    "-fsS",
    "-X", "POST",
    $Url,
    "-H", "Content-Type: text/plain; charset=utf-8",
    "-H", "X-Webhook-Event: $Event",
    "-H", "X-Webhook-Status: $Status"
  )
  if (-not [string]::IsNullOrWhiteSpace($env:WEBHOOK_TOKEN)) {
    $argsList += @("-H", "Authorization: Bearer $($env:WEBHOOK_TOKEN)")
  }
  $argsList += @("--data-binary", "@$SummaryFile")
}

& curl.exe @argsList "-o" "NUL"
Write-Output "已发送"
