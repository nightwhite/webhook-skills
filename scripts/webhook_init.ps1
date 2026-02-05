param(
  [Parameter(Mandatory = $true)]
  [string]$Url,
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

$dir = Split-Path -Parent $ConfigPath
New-Item -Force -ItemType Directory -Path $dir | Out-Null

Set-Content -NoNewline -Encoding UTF8 -Path $ConfigPath -Value $Url

Write-Output "已写入：$ConfigPath"
