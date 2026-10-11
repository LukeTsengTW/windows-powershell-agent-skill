---
name: windows-powershell-terminal
description: This skill should be used when writing, reviewing, converting, or executing terminal commands for native Windows PowerShell on Windows, including requests like "convert this Bash command", "use PowerShell syntax", "Windows Terminal command", "run this on Windows", or "fix this PowerShell command". It keeps commands in valid PowerShell syntax and avoids other shell syntax unless the user explicitly says WSL, Git Bash, Linux, macOS, or CMD.
---

# Windows PowerShell Terminal

Use this skill to produce native Windows PowerShell commands. Default to PowerShell when the user mentions Windows, PowerShell, Windows Terminal, VS Code terminal on Windows, an AI coding agent terminal on Windows, or an unspecified Windows terminal.

Follow higher-priority repo instructions first. Do not invent unavailable tools; use this skill only for PowerShell syntax of terminal commands that remain appropriate.

## When To Use

Activate this skill for terminal work involving:

- Windows, PowerShell, Windows Terminal, VS Code terminal, or an AI coding agent terminal on Windows.
- `npm`, Node.js, Python, Git, or other CLI workflows on Windows.
- File operations: create, copy, move, delete, list, read, search, filter, count, compare, parse, or transform.
- Environment variables, command lookup, path changes, process setup, or script execution.

Do not apply PowerShell rules when the user explicitly says WSL, Git Bash, Linux, macOS, or CMD. Use the named shell instead.

The target shell requested by the user may differ from the agent's own execution environment. Preserve the requested PowerShell syntax even when the agent itself runs in Bash, Linux, or another shell. If PowerShell is unavailable in the execution environment, provide or review the command without claiming that it was executed successfully.

## Shell And Version Detection

Infer shell from prompt and wording:

- Windows PowerShell prompts usually look like `PS C:\Workspace>`.
- CMD prompts usually look like `C:\Workspace>`.
- WSL and Git Bash often use `export`, `rm -rf`, `grep`, and forward-slash paths.
- When uncertain on Windows, default to PowerShell syntax.
- When the user says "Windows PowerShell", assume Windows PowerShell 5.1 (`powershell.exe`) unless version info proves otherwise.
- PowerShell 7+ uses `pwsh` and supports newer syntax not available in Windows PowerShell 5.1.

Check version when syntax support matters:

```powershell
$PSVersionTable.PSVersion
```

Use `&&` and `||` only in PowerShell 7+. In Windows PowerShell 5.1, prefer multi-line commands, `;`, or explicit `$LASTEXITCODE` / `$?` checks.

## PowerShell Syntax Rules

Use PowerShell cmdlets and PowerShell environment-variable syntax. Do not emit Bash-only syntax for native PowerShell unless converting or disambiguating.

Common conversions summary; use fenced examples for copyable commands:

| Bash/Linux | PowerShell |
| --- | --- |
| `rm -rf path` | Use inspect-then-delete safe preview below |
| `export VAR=value` | `$env:VAR = "value"` |
| `VAR=value command` | `$env:VAR = "value"; command` when session-level change is acceptable |
| `grep -r "text" .` | `Get-ChildItem -Recurse -File | Select-String -Pattern "text"` |
| `find . -name "*.js"` | `Get-ChildItem -Recurse -File -Filter "*.js"` |
| `cp source dest` | `Copy-Item -Path "source" -Destination "dest"` |
| `mv source dest` | `Move-Item -Path "source" -Destination "dest"` |
| `touch file.txt` | Create if missing; update timestamps when that is intended |
| `cat file.txt` | `Get-Content -Path "file.txt"` |
| `ls` | `Get-ChildItem` |
| `pwd` | `Get-Location` |
| `which tool` | `Get-Command tool` |

Prefer explicit parameters when clarity or safety matters.

Prefer the shortest safe PowerShell command that preserves the user's intent; use longer defensive patterns only when they materially improve correctness, safety, or semantic equivalence.

For `rm -rf`, prefer a safe preview first:

```powershell
if (Test-Path -LiteralPath "path") {
    Get-ChildItem -LiteralPath "path"
    Remove-Item -LiteralPath "path" -Recurse -Force -WhatIf
}
```

Remove `-WhatIf` only after confirming the target is correct and the user clearly intends deletion.

Use this pattern when the environment variable should apply only to one command or one short workflow:

```powershell
$exitCode = 0
$previous = $env:NODE_ENV
try {
    $env:NODE_ENV = "test"
    npm test
    $exitCode = $LASTEXITCODE
}
finally {
    if ($null -eq $previous) {
        Remove-Item Env:\NODE_ENV -ErrorAction SilentlyContinue
    }
    else {
        $env:NODE_ENV = $previous
    }
}

if ($exitCode -ne 0) {
    throw "npm test failed with exit code $exitCode"
}
```

`touch` normally also updates timestamps on existing files. If the user only wants to create a file when missing, use this narrower pattern and do not claim full `touch` equivalence:

```powershell
if (-not (Test-Path -LiteralPath ".\.env")) {
    New-Item -ItemType File -Path ".\.env" | Out-Null
}
```

`New-Item -ItemType File` does not create missing parent directories automatically. For parent-directory-safe creation:

```powershell
$filePath = ".\config\.env"
$parent = Split-Path -Parent $filePath

if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent | Out-Null
}

if (-not (Test-Path -LiteralPath $filePath)) {
    New-Item -ItemType File -Path $filePath | Out-Null
}
```

For an existing file, update timestamps without changing its contents when requested:

```powershell
$item = Get-Item -LiteralPath ".\ready.txt" -ErrorAction Stop
$timestamp = Get-Date
$item.LastWriteTime = $timestamp
$item.LastAccessTime = $timestamp
```

If overwriting or updating timestamps is not intended, do not use destructive alternatives.

## Native Command Arguments

PowerShell parses arguments before passing them to native executables. Be careful with quotes, parentheses, semicolons, ampersands, `$`, `{}`, and backticks when calling tools such as `npm`, `node`, `python`, `git`, `ssh`, `docker`, `az`, or `npx`.

Do not blindly use Bash-style escaping in PowerShell. Prefer simple quotes over excessive backticks or backslashes.

Prefer simple quoted arguments:

```powershell
npm run build
python ".\scripts\tool.py" "--input=.\data file.json"
```

Use the call operator `&` when the executable path is quoted:

```powershell
& "C:\Program Files\nodejs\npm.cmd" install
```

Use `--%` sparingly. It is a Windows-specific fallback for difficult literal arguments to native executables, not a default solution.

Argument passing is version-sensitive: Windows PowerShell 5.1 uses legacy native argument handling, which can lose empty arguments or embedded quotes. PowerShell 7.3+ introduces `$PSNativeCommandArgumentPassing`; its default is `Windows` on Windows and `Standard` elsewhere. In `Windows` mode, commands such as `cmd.exe` and `.cmd`/`.bat` files still use legacy handling. Check the actual executable and mode before claiming that a JSON string or empty argument survives unchanged. Do not globally change this preference as a quoting workaround; prefer the CLI's supported file or standard-input option for complex payloads. See Microsoft's [native argument passing documentation](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_parsing#passing-arguments-to-native-commands).

Prefer single quotes for literal strings that should not expand variables. Use double quotes when variable expansion is intended. For JSON or multi-line text, prefer here-strings:

```powershell
$json = @'
{
  "name": "example",
  "enabled": true
}
'@
```

The closing here-string marker, such as `'@` or `"@`, must start at the beginning of the line and should not be indented.

For long cmdlet calls with many parameters, prefer splatting to reduce quoting and line-continuation mistakes:

```powershell
$copyArgs = @{
    Path = ".\source file.txt"
    Destination = ".\output folder\"
}

Copy-Item @copyArgs
```

Check CLI availability with `Get-Command` before tools such as `npm`, `node`, `python`, `git`, `docker`, `az`, or `npx`:

```powershell
Get-Command npm -ErrorAction SilentlyContinue
```

For scripts, guard the check:

```powershell
if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw "npm was not found in PATH"
}
```

## Command Chaining

Prefer multi-line commands for readability and lower quoting risk:

```powershell
$env:NODE_ENV = "test"
npm test
```

Use `;` for compact independent commands:

```powershell
Get-Location; Get-ChildItem
```

Use conditional chaining compatible with Windows PowerShell 5.1 when a later command must run only after a successful native executable:

```powershell
npm install
if ($LASTEXITCODE -eq 0) {
    npm test
}
```

Use `$?` mainly to check whether the last PowerShell command succeeded. Use `$LASTEXITCODE` after native executables such as `npm`, `node`, `python`, `git`, `docker`, or `ssh`.

When a failed native executable should stop the workflow, check `$LASTEXITCODE` explicitly:

```powershell
npm install
if ($LASTEXITCODE -ne 0) {
    throw "npm install failed"
}
```

## Error Handling

PowerShell cmdlets can produce non-terminating errors, which report an error but do not stop a script by default. For scripts where failure should stop execution, set:

```powershell
$ErrorActionPreference = "Stop"
```

For individual cmdlets, use `-ErrorAction Stop`:

```powershell
Get-Content -Path ".\file.txt" -ErrorAction Stop
```

For robust scripts that call native executables, explicitly check `$LASTEXITCODE` after each command whose failure should stop the workflow.

## Redirection And Output Files

PowerShell supports `>`, `>>`, and `2>&1`; these are not Bash-only.

Encoding rules:

- Windows PowerShell 5.1: `Out-File`, `>`, and `>>` may write UTF-16LE by default.
- Windows PowerShell 5.1: `-Encoding utf8` writes UTF-8 with BOM.
- Windows PowerShell 5.1: `Set-Content` and `Add-Content` create new or empty files using the system ANSI code page unless `-Encoding` is supplied; `Add-Content` detects and matches an existing BOM when present.
- Windows PowerShell 5.1: `Out-File -Append` and `>>` do not reliably preserve existing file encoding.
- PowerShell 6+: UTF-8 without BOM is the default for text output.
- PowerShell 7.4+: redirecting a native executable's stdout directly to a file with `>` preserves its bytes. This differs from formatting PowerShell objects as text; do not assume every redirected native stream is UTF-8 text or safely round-trip binary data through text cmdlets.
- For BOM-sensitive files in Windows PowerShell 5.1, use the .NET `UTF8Encoding($false)` pattern.

For logs or BOM-tolerant files, prefer explicit encoding. These simple examples are acceptable when BOM is not a problem:

```powershell
"text" | Set-Content -Path ".\file.txt" -Encoding utf8
"text" | Add-Content -Path ".\file.txt" -Encoding utf8
command | Out-File -FilePath ".\log.txt" -Encoding utf8
```

For BOM-sensitive files in Windows PowerShell 5.1, use a .NET UTF-8 without BOM write. Do not overuse this for simple cases:

```powershell
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$path = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(".\file.txt")
[System.IO.File]::WriteAllText($path, "text", $utf8NoBom)
```

This writes or replaces the whole file.
Use only after confirming replacement is intended.
Resolve relative paths through PowerShell before passing them to .NET file APIs. `[System.IO.Path]::GetFullPath()` and relative .NET file paths use the process working directory, which can differ from `Get-Location` after `Set-Location`. Use a filesystem location for the pattern above.

Use `Tee-Object` when the user wants to display output and save it at the same time:

```powershell
command | Tee-Object -FilePath ".\log.txt"
```

In Windows PowerShell 5.1, `Tee-Object -FilePath` has no `-Encoding` parameter and creates UTF-16LE output.

For simple logs where BOM is acceptable, `Out-File -Encoding utf8` is fine. For BOM-sensitive files in Windows PowerShell 5.1, use the .NET UTF-8 without BOM pattern.

Do not use `>` or `>>` for encoding-sensitive files unless the user specifically wants simple redirection.

## Running Scripts

Run scripts in the current directory with `.\`:

```powershell
.\script.ps1
```

Use the call operator `&` for quoted script or executable paths:

```powershell
& ".\scripts\build.ps1"
& "C:\Program Files\nodejs\npm.cmd" install
```

If script execution is blocked, inspect the script and effective policies before choosing a remedy:

```powershell
Get-Item -LiteralPath ".\script.ps1" | Format-List FullName,Length,LastWriteTime
Get-Content -LiteralPath ".\script.ps1"
Get-AuthenticodeSignature -LiteralPath ".\script.ps1"
Get-ExecutionPolicy -List
```

For a trusted downloaded file, remove its downloaded-file block when appropriate:

```powershell
Unblock-File -LiteralPath ".\script.ps1"
```

If the effective policy still prevents an authorized script from running, explain the cause and use a process-scoped policy change only when justified. Do not make `Bypass` the default remedy, change machine-wide policy, or attempt to override organizational Group Policy. `Unblock-File` does not bypass `Restricted` or signature requirements under `AllSigned`.

## Path Rules

Use Windows-style relative paths:

```powershell
.\folder\file.txt
```

Quote paths with spaces or user-provided segments:

```powershell
Set-Location "C:\Program Files\Example"
Copy-Item -Path ".\source file.txt" -Destination ".\output folder\"
```

Inside scripts, prefer `$PSScriptRoot` and `Join-Path` instead of hard-coded paths:

```powershell
$configPath = Join-Path $PSScriptRoot "config.json"
```

Use `-LiteralPath` when a path may contain wildcard characters such as `[`, `]`, `*`, or `?`. `-Path` supports wildcard expansion; `-LiteralPath` treats the path exactly as written:

```powershell
Get-Content -LiteralPath ".\data[old].json"
Remove-Item -LiteralPath ".\backup[old]" -Recurse -Force -WhatIf
```

Do not convert Windows paths to `/mnt/c/...` unless the user explicitly says WSL. Do not use unquoted paths with spaces.

## File Search

Simple search:

```powershell
Get-ChildItem -Recurse -File | Select-String -Pattern "TODO"
```

Project search that filters out common large folders from results:

```powershell
Get-ChildItem -Path "." -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|dist|build)\\' } |
    Select-String -Pattern "TODO"
```

## Environment Variables

Set a variable for the current session only:

```powershell
$env:VAR = "value"
```

Do not print, commit, or write API keys, tokens, or passwords into tracked files. Before writing secrets to a local `.env`, verify Git's effective ignore result from the intended repository:

```powershell
git check-ignore --quiet -- .env
if ($LASTEXITCODE -ne 0) {
    throw "Git did not confirm that .env is ignored. Resolve this before writing secrets."
}
```

An `.env` line found by text search is not sufficient: a later negation or a more specific ignore file can override it, and ignore rules do not protect an already tracked file. Use `git ls-files --error-unmatch -- .env` to diagnose tracking (exit 0 means tracked). If updating `.gitignore` is authorized, preserve its encoding and existing rules, put the new rule on its own line even when the file lacks a trailing newline, then rerun `git check-ignore`. Do not automatically remove files from Git's index; explain tracked-secret exposure and any needed credential rotation separately.

Set a persistent user-level variable only when the user explicitly asks for persistence. New terminals are usually required:

```powershell
[Environment]::SetEnvironmentVariable("VAR", "value", "User")
```

## Safety Rules

For commands that delete, overwrite, clear data, modify system settings, install global packages, or have broad side effects:

- Explain the risk briefly before the command.
- Show an inspect command first, especially before `Remove-Item`.
- Prefer precise, quoted paths.
- Never suggest deleting `C:\`, `C:\Users`, `C:\Windows`, `System32`, the user profile, or broad wildcard paths unless explicitly requested and heavily scoped and explained.
- Do not use `Remove-Item -Recurse -Force` unless the user's intent is clear.
- Avoid destructive commands the user did not request.

Example inspect-then-delete flow:

```powershell
if (Test-Path -LiteralPath ".\dist") {
    Get-ChildItem -LiteralPath ".\dist"
    Remove-Item -LiteralPath ".\dist" -Recurse -Force -WhatIf
}
```

Remove `-WhatIf` only after confirming the target is correct and the user clearly intends deletion.

## Output Format

When giving terminal commands:

- Provide the PowerShell command directly.
- Use fenced code blocks with `powershell`.
- Do not mix Bash and PowerShell in the same command block.
- Mention Bash, WSL, Git Bash, or CMD only when converting or disambiguating.

## Test Examples

Incorrect Bash:

```bash
rm -rf node_modules
```

Correct PowerShell:

```powershell
if (Test-Path -LiteralPath ".\node_modules") {
    Get-ChildItem -LiteralPath ".\node_modules"
    Remove-Item -LiteralPath ".\node_modules" -Recurse -Force -WhatIf
}
```

Remove `-WhatIf` only after confirming the target is correct and the user clearly intends deletion.

Incorrect Bash:

```bash
export OPENROUTER_API_KEY=<your-api-key>
npm run repo-map
```

Correct PowerShell:

```powershell
$env:OPENROUTER_API_KEY = "<key>"
npm run repo-map
```

Use the restore pattern only when the variable should apply temporarily to one command or short workflow.

Incorrect Bash:

```bash
NODE_ENV=test npm test
```

Correct PowerShell:

```powershell
$exitCode = 0
$previous = $env:NODE_ENV
try {
    $env:NODE_ENV = "test"
    npm test
    $exitCode = $LASTEXITCODE
}
finally {
    if ($null -eq $previous) {
        Remove-Item Env:\NODE_ENV -ErrorAction SilentlyContinue
    }
    else {
        $env:NODE_ENV = $previous
    }
}

if ($exitCode -ne 0) {
    throw "npm test failed with exit code $exitCode"
}
```

Incorrect Bash:

```bash
grep -r "TODO" .
```

Correct PowerShell:

```powershell
Get-ChildItem -Recurse -File | Select-String -Pattern "TODO"
```

Incorrect Bash:

```bash
find . -name "*.ps1"
```

Correct PowerShell:

```powershell
Get-ChildItem -Recurse -File -Filter "*.ps1"
```

Incorrect Bash:

```bash
touch .env
cat .env
```

Correct PowerShell:

```powershell
if (-not (Test-Path -LiteralPath ".\.env")) {
    New-Item -ItemType File -Path ".\.env" | Out-Null
}

Get-Item -LiteralPath ".\.env" | Select-Object FullName,Length,LastWriteTime
```
