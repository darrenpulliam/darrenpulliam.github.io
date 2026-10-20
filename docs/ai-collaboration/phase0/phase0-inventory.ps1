<#
.SYNOPSIS
  CrystalBull Phase 0 read-only inventory.

.DESCRIPTION
  Collects facts about the CrystalBull installation, the AI tooling on this
  machine, and credential placement. It never writes inside the CrystalBull
  directory and never prints secret values, only where they appear to live.

.PARAMETER Root
  CrystalBull production directory. Default C:\CrystalBull\CB_v4.0

.PARAMETER OutDir
  Where the report is written. Default: the user's Desktop.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\phase0-inventory.ps1
#>
[CmdletBinding()]
param(
  [string]$Root   = 'C:\CrystalBull\CB_v4.0',
  [string]$OutDir = [Environment]::GetFolderPath('Desktop')
)

$ErrorActionPreference = 'Continue'
$stamp  = Get-Date -Format 'yyyy-MM-dd_HHmm'
$report = Join-Path $OutDir "cb_v4_inventory_$stamp.md"
$lines  = New-Object System.Collections.Generic.List[string]
function H($t){ $lines.Add(""); $lines.Add("## $t"); $lines.Add("") }
function L($t){ $lines.Add([string]$t) }
function Code($t){ $lines.Add('```'); foreach($x in $t){ $lines.Add([string]$x) }; $lines.Add('```') }
function TryCmd($label, [scriptblock]$sb){
  try { $o = & $sb 2>&1 | Out-String; if([string]::IsNullOrWhiteSpace($o)){ $o = '(no output)' } }
  catch { $o = "ERROR: $($_.Exception.Message)" }
  L "**$label**"; Code ($o.TrimEnd() -split "`r?`n")
}

L "# CrystalBull Phase 0 Inventory"
L ""
L "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm') on $env:COMPUTERNAME as $env:USERNAME"
L "Root: $Root"
L ""
L "Read-only. No files under Root were created or modified."

# ---------------------------------------------------------------- 1. system
H "1. System and tool versions"
TryCmd "OS" { (Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture | Format-List | Out-String) }
TryCmd "CPU / RAM / GPU" {
  $cpu = (Get-CimInstance Win32_Processor).Name
  $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)
  $gpu = (Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name) -join '; '
  "CPU: $cpu`nRAM: $ram GB`nGPU: $gpu"
}
TryCmd "PowerShell" { "$($PSVersionTable.PSVersion)  edition=$($PSVersionTable.PSEdition)  host=$((Get-Process -Id $PID).Path)" }
foreach($tool in 'claude','codex','node','npm','git','python','py','ollama','gh','wsl'){
  TryCmd "where $tool" { $p = (Get-Command $tool -All -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source); if($p){ $p -join "`n" } else { 'not found' } }
}
TryCmd "claude --version" { claude --version }
TryCmd "codex --version"  { codex --version }
TryCmd "node --version"   { node --version }
TryCmd "git --version"    { git --version }
TryCmd "python --version" { python --version }
TryCmd "ollama list"      { ollama list }
TryCmd "wsl --list --verbose" { wsl --list --verbose }
TryCmd "pwsh install source (Store vs MSI)" {
  $p = Get-Command pwsh -All -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
  if(-not $p){ 'pwsh (PowerShell 7) not found' } else { $p | ForEach-Object { if($_ -like '*WindowsApps*'){ "$_  <- Microsoft Store build" } else { "$_  <- MSI/zip build" } } }
}

# ---------------------------------------------------------------- 2. root
H "2. CrystalBull directory"
if(-not (Test-Path $Root)){ L "**Root does not exist: $Root**" } else {
  TryCmd "Top-level tree" { Get-ChildItem $Root -Force | Sort-Object PSIsContainer -Descending | ForEach-Object { if($_.PSIsContainer){ "[dir]  $($_.Name)" } else { "       $($_.Name)  ($([math]::Round($_.Length/1KB)) KB)" } } }
  TryCmd "Second-level directories" { Get-ChildItem $Root -Directory -Force | ForEach-Object { $d=$_; $sub = Get-ChildItem $d.FullName -Directory -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name; "$($d.Name)/  -> " + (($sub | Select-Object -First 25) -join ', ') } }
  TryCmd "File counts by extension" { Get-ChildItem $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|node_modules|\.venv|venv)\\' } | Group-Object Extension | Sort-Object Count -Descending | Select-Object -First 25 | ForEach-Object { "{0,6}  {1}" -f $_.Count, ($_.Name -replace '^$','(none)') } }
  TryCmd "Total size (excluding .git/venv/caches)" { $s = (Get-ChildItem $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|node_modules|\.venv|venv)\\' } | Measure-Object Length -Sum).Sum; "{0:N1} MB" -f ($s/1MB) }
  TryCmd "Version markers (files named version*/VERSION/CHANGELOG, __version__ strings)" {
    $a = Get-ChildItem $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(version|VERSION|CHANGELOG|RELEASE|README)' } | Select-Object -First 15 | ForEach-Object { $_.FullName.Substring($Root.Length) }
    $b = Get-ChildItem $Root -Recurse -Include *.py,*.toml,*.json,*.ps1 -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|\.venv|venv)\\' } | Select-String -Pattern '__version__\s*=|"version"\s*:|^version\s*=' -List -ErrorAction SilentlyContinue | Select-Object -First 15 | ForEach-Object { "$($_.Path.Substring($Root.Length)):$($_.LineNumber): $($_.Line.Trim())" }
    @($a) + @('---') + @($b)
  }
  TryCmd "Generator / engine counts (heuristic: files or dirs whose name contains generator/engine)" {
    $gen = Get-ChildItem $Root -Recurse -File -Include *.py -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|\.venv|venv)\\' -and ($_.Name -match 'gen' -or $_.DirectoryName -match 'generator') }
    $eng = Get-ChildItem $Root -Recurse -File -Include *.py -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|\.venv|venv)\\' -and ($_.Name -match 'engine' -or $_.DirectoryName -match 'engine') }
    "generator-like .py files: $($gen.Count)`nengine-like .py files:    $($eng.Count)`n`nGenerator dirs: " + ((Get-ChildItem $Root -Recurse -Directory -Force -ErrorAction SilentlyContinue | Where-Object Name -match 'generator' | ForEach-Object { $_.FullName.Substring($Root.Length) + '  (' + (Get-ChildItem $_.FullName -File -Filter *.py | Measure-Object).Count + ' py)' }) -join "`n                ")
  }
  TryCmd "Tests present?" {
    $t = Get-ChildItem $Root -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|\.venv|venv)\\' -and ($_.Name -match '^test_.*\.py$|_test\.py$|^tests?$|pytest\.ini|conftest\.py|pyproject\.toml|tox\.ini') }
    if($t){ $t | Select-Object -First 30 | ForEach-Object { $_.FullName.Substring($Root.Length) } } else { 'No test files, tests/ dir, or pytest config found' }
  }
  TryCmd "Dependency manifests" { Get-ChildItem $Root -Recurse -Force -ErrorAction SilentlyContinue -Include requirements*.txt,pyproject.toml,environment.yml,package.json,Pipfile | Where-Object { $_.FullName -notmatch '\\(\.git|node_modules|\.venv|venv)\\' } | ForEach-Object { $_.FullName.Substring($Root.Length) } }
  TryCmd "Existing AI instruction files (CLAUDE.md, AGENTS.md, .claude/, .codex/, .cursorrules)" { Get-ChildItem $Root -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -in 'CLAUDE.md','AGENTS.md','.claude','.codex','.cursorrules','.mcp.json' } | ForEach-Object { $_.FullName.Substring($Root.Length) } }
  TryCmd "Git status of Root" {
    if(Test-Path (Join-Path $Root '.git')){ Push-Location $Root; try { "IS a git repo`n" + (git remote -v | Out-String) + (git status -sb | Select-Object -First 5 | Out-String) + "commits: " + (git rev-list --count HEAD) + "`nlast: " + (git log -1 --format='%h %ad %s' --date=short) } finally { Pop-Location } } else { 'NOT a git repository' }
  }
  TryCmd "Other .git directories under Root" { Get-ChildItem $Root -Recurse -Directory -Force -Filter .git -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($Root.Length) } }
  TryCmd "Largest files (top 15)" { Get-ChildItem $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 15 | ForEach-Object { "{0,8:N1} MB  {1}" -f ($_.Length/1MB), $_.FullName.Substring($Root.Length) } }
}

# ---------------------------------------------------------------- 3. scheduling
H "3. Scheduled tasks and running processes referencing CrystalBull"
TryCmd "Scheduled tasks" {
  Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
    $t=$_; $acts = ($t.Actions | ForEach-Object { "$($_.Execute) $($_.Arguments)" }) -join ' | '
    if($acts -match 'CrystalBull|CB_v4|daily\.ps1' -or $t.TaskName -match 'Crystal|CB_'){ "$($t.TaskPath)$($t.TaskName)  [$($t.State)]  -> $acts" }
  }
}
TryCmd "Running processes with CrystalBull in command line" { Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'CrystalBull|CB_v4' } | ForEach-Object { "$($_.ProcessId)  $($_.Name)  $($_.CommandLine)" } }

# ---------------------------------------------------------------- 4. secrets placement (locations only, never values)
H "4. Credential placement (locations only; values are never read or printed)"
if(Test-Path $Root){
  TryCmd "Files that look like secret stores under Root" {
    Get-ChildItem $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|\.venv|venv)\\' -and $_.Name -match '^\.env|secret|credential|token|apikey|api_key|\.pem$|\.key$|config.*\.(json|ini|toml|yaml|yml)$' } | ForEach-Object { "$($_.FullName.Substring($Root.Length))  ($($_.Length) bytes)" }
  }
  TryCmd "Source files that reference key-like variable names (file:line only)" {
    Get-ChildItem $Root -Recurse -Include *.py,*.ps1,*.json,*.toml,*.ini,*.yaml,*.yml -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|\.venv|venv)\\' } | Select-String -Pattern '(?i)(api[_-]?key|secret|password|passwd|token|client_secret|account_?number|refresh_token)\s*[:=]' -ErrorAction SilentlyContinue | Where-Object { $_.Line -notmatch 'os\.environ|getenv|\$env:|Get-Secret|keyring|load_dotenv' } | Select-Object -First 60 | ForEach-Object { "$($_.Path.Substring($Root.Length)):$($_.LineNumber)" }
  }
  TryCmd "How secrets are loaded (env / dotenv / keyring / hardcoded?)" {
    $m = Get-ChildItem $Root -Recurse -Include *.py,*.ps1 -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|\.venv|venv)\\' } | Select-String -Pattern 'os\.environ|getenv|load_dotenv|keyring|Get-Secret|\$env:' -ErrorAction SilentlyContinue
    "env/dotenv/keyring style references: $($m.Count)`n" + (($m | Select-Object -First 20 | ForEach-Object { "$($_.Path.Substring($Root.Length)):$($_.LineNumber)" }) -join "`n")
  }
}
TryCmd "User-level env vars that look like credentials (names only)" { [Environment]::GetEnvironmentVariables('User').Keys | Where-Object { $_ -match '(?i)key|secret|token|pass' } }
TryCmd "Windows Credential Manager entries mentioning broker/crystal (names only)" { cmdkey /list 2>&1 | Select-String -Pattern 'Target:' | Where-Object { $_ -match '(?i)crystal|schwab|fidelity|robinhood|alpaca|ibkr|interactive|td|etrade|tradier|webull|broker' } | ForEach-Object { $_.Line.Trim() } }

# ---------------------------------------------------------------- 5. trading safety
H "5. Live-trading safeguards (heuristic grep)"
if(Test-Path $Root){
  TryCmd "Order placement / live trading references" {
    Get-ChildItem $Root -Recurse -Include *.py,*.ps1 -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|\.venv|venv)\\' } | Select-String -Pattern '(?i)place_order|submit_order|create_order|LIVE_TRADING|PAPER|paper_trading|dry_run|DRY_RUN' -ErrorAction SilentlyContinue | Select-Object -First 60 | ForEach-Object { "$($_.Path.Substring($Root.Length)):$($_.LineNumber): $($_.Line.Trim())" }
  }
  TryCmd "Brokerage SDK imports" {
    Get-ChildItem $Root -Recurse -Include *.py -Force -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\(\.git|__pycache__|\.venv|venv)\\' } | Select-String -Pattern '^(import|from)\s+(alpaca|ib_insync|ibapi|schwab|tda|robin_stocks|tradier|webull|etrade|yfinance|ccxt)' -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() } | Sort-Object -Unique
  }
}

# ---------------------------------------------------------------- 6. AI tool config
H "6. AI tool configuration on this machine (presence only)"
TryCmd "Claude Code user files" { foreach($p in "$env:USERPROFILE\.claude", "$env:USERPROFILE\.claude.json", "$env:USERPROFILE\.claude\settings.json", "$env:USERPROFILE\.claude\plugins"){ "$(if(Test-Path $p){'present'}else{'absent '})  $p" } }
TryCmd "Codex user files" { foreach($p in "$env:USERPROFILE\.codex", "$env:USERPROFILE\.codex\config.toml", "$env:USERPROFILE\.codex\auth.json"){ "$(if(Test-Path $p){'present'}else{'absent '})  $p" } }
TryCmd "Codex config.toml (sandbox/approval lines only)" { $p="$env:USERPROFILE\.codex\config.toml"; if(Test-Path $p){ Get-Content $p | Select-String -Pattern 'sandbox|approval|model|windows' | ForEach-Object { $_.Line } } else { 'absent' } }
TryCmd "ChatGPT desktop app installed?" { Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'OpenAI|ChatGPT' } | ForEach-Object { "$($_.Name)  $($_.Version)" }; Get-ChildItem "$env:LOCALAPPDATA\Programs" -Directory -ErrorAction SilentlyContinue | Where-Object Name -match 'ChatGPT|Codex|Claude' | ForEach-Object { $_.FullName } }

# ---------------------------------------------------------------- write
$lines | Set-Content -Path $report -Encoding UTF8
Write-Host ""
Write-Host "Report written to: $report" -ForegroundColor Green
Write-Host "Review it for anything sensitive before sharing. Only locations and names are recorded, never secret values."
