# 自动下载并部署 Godot 4.4-stable 引擎到 godot_engine 目录
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$engineDir = Join-Path $root 'godot_engine'
$url = 'https://github.com/godotengine/godot/releases/download/4.4-stable/Godot_v4.4-stable_win64.exe.zip'
$zip = Join-Path $engineDir 'godot.zip'

New-Item -ItemType Directory -Force -Path $engineDir | Out-Null

Write-Host '[1/3] 开始下载 Godot 4.4-stable (约 50MB)...'
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

Write-Host '[2/3] 下载完成，正在解压...'
Expand-Archive -Path $zip -DestinationPath $engineDir -Force
Remove-Item $zip

Write-Host '[3/3] 部署完成。文件清单:'
Get-ChildItem $engineDir | Format-Table Name, Length -AutoSize
