<#
.SYNOPSIS
Runs dependency-free installer and executable documentation regression tests.
.DESCRIPTION
Requires Git and Windows PowerShell 5.1 or PowerShell 7+. Uses temporary fixtures
and SkillsPath; never changes HOME or installs into personal skill directories.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("powershell-skill-tests-" + [guid]::NewGuid().ToString("N"))
$script:passed = 0
$script:failed = 0
$script:skipped = 0

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-Case {
    param([string]$Name, [scriptblock]$Body)
    try {
        & $Body
        $script:passed++
        Write-Host "PASS: $Name"
    }
    catch {
        $script:failed++
        Write-Host "FAIL: $Name -- $($_.Exception.Message)"
    }
}

function New-TestDirectory {
    param([string]$Name)
    $path = Join-Path $testRoot ($Name + "-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $path | Out-Null
    return $path
}

function New-SourceFixture {
    $fixture = New-TestDirectory "source"
    foreach ($relative in @("SKILL.md", "scripts/install.ps1", "agents/openai.yaml", "adapters/github-copilot/AGENTS.md")) {
        $destination = Join-Path $fixture $relative
        $parent = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Copy-Item -LiteralPath (Join-Path $repositoryRoot $relative) -Destination $destination
    }
    return $fixture
}

function Invoke-Installer {
    param([string]$Source, [string[]]$Arguments, [int]$ExpectedExit = 0)
    # Windows PowerShell 5.1 turns redirected native stderr into error records.
    # Capture them without terminating before the actual exit status is checked.
    $ErrorActionPreference = "Continue"
    $output = & $powerShellExecutable -NoLogo -NoProfile -NonInteractive -File (Join-Path $Source "scripts/install.ps1") @Arguments 2>&1 | Out-String
    $status = $LASTEXITCODE
    if ($status -ne $ExpectedExit) {
        throw "Installer exit $status; expected $ExpectedExit. $output"
    }
    return $output
}

function Assert-SameFile {
    param([string]$Actual, [string]$Expected)
    Assert-True (Test-Path -LiteralPath $Actual -PathType Leaf) "Missing file: $Actual"
    Assert-True ((Get-FileHash -LiteralPath $Actual).Hash -eq (Get-FileHash -LiteralPath $Expected).Hash) "File content differs: $Actual"
}

function Assert-Throws {
    param([scriptblock]$Body)
    $threw = $false
    try { & $Body } catch { $threw = $true }
    Assert-True $threw "Expected a terminating failure"
}

try {
    $powerShellExecutable = $null
    foreach ($name in @("powershell.exe", "pwsh.exe", "pwsh")) {
        $candidate = Join-Path $PSHOME $name
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $powerShellExecutable = $candidate
            break
        }
    }
    Assert-True ($null -ne $powerShellExecutable) "Cannot locate the current PowerShell executable"
    $null = Get-Command git -ErrorAction Stop
    New-Item -ItemType Directory -Path $testRoot | Out-Null

    Invoke-Case "All repository PowerShell scripts parse in the current runtime" {
        foreach ($directory in @("scripts", "tests")) {
            foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repositoryRoot $directory) -Filter "*.ps1" -File -Recurse) {
                $tokens = $null
                $parseErrors = $null
                $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
                Assert-True ($parseErrors.Count -eq 0) "Parser errors in $($file.Name): $parseErrors"
            }
        }
    }

    foreach ($target in @("Shared", "Codex", "Gemini", "Claude")) {
        Invoke-Case "$target installs and updates exactly its expected files" {
            $skills = New-TestDirectory "skills [literal] with spaces"
            $destination = Join-Path $skills "windows-powershell-terminal"
            $arguments = @("-Target", $target, "-SkillsPath", $skills)
            $null = Invoke-Installer $repositoryRoot $arguments
            $core = Join-Path $destination "SKILL.md"
            Assert-SameFile $core (Join-Path $repositoryRoot "SKILL.md")
            $hasMetadata = $target -eq "Shared" -or $target -eq "Codex"
            if ($hasMetadata) {
                Assert-SameFile (Join-Path $destination "agents/openai.yaml") (Join-Path $repositoryRoot "agents/openai.yaml")
                Assert-True (@(Get-ChildItem -LiteralPath $destination -File -Recurse -Force).Count -eq 2) "Unexpected installed files"
            }
            else {
                Assert-True (-not (Test-Path -LiteralPath (Join-Path $destination "agents"))) "Portable target received metadata"
                Assert-True (@(Get-ChildItem -LiteralPath $destination -File -Recurse -Force).Count -eq 1) "Unexpected installed files"
            }
            [System.IO.File]::WriteAllText($core, "old installed version")
            $sentinel = Join-Path $destination "keep.txt"
            [System.IO.File]::WriteAllText($sentinel, "unrelated content")
            $null = Invoke-Installer $repositoryRoot $arguments
            Assert-SameFile $core (Join-Path $repositoryRoot "SKILL.md")
            Assert-True ([System.IO.File]::ReadAllText($sentinel) -eq "unrelated content") "Unrelated file changed"
        }

        Invoke-Case "$target rejects a missing core before creating its destination" {
            $source = New-SourceFixture
            Remove-Item -LiteralPath (Join-Path $source "SKILL.md")
            $skills = New-TestDirectory "missing-core"
            $null = Invoke-Installer $source @("-Target", $target, "-SkillsPath", $skills) 1
            Assert-True (@(Get-ChildItem -LiteralPath $skills -Force).Count -eq 0) "Failed preflight wrote files"
        }

        Invoke-Case "$target handles missing metadata according to target requirements" {
            $source = New-SourceFixture
            Remove-Item -LiteralPath (Join-Path $source "agents/openai.yaml")
            $skills = New-TestDirectory "missing-metadata"
            $arguments = @("-Target", $target, "-SkillsPath", $skills)
            if ($target -eq "Shared" -or $target -eq "Codex") {
                $null = Invoke-Installer $source $arguments 1
                Assert-True (@(Get-ChildItem -LiteralPath $skills -Force).Count -eq 0) "Failed preflight created a destination"
                $null = Invoke-Installer $repositoryRoot $arguments
                $core = Join-Path $skills "windows-powershell-terminal/SKILL.md"
                $metadata = Join-Path $skills "windows-powershell-terminal/agents/openai.yaml"
                [System.IO.File]::WriteAllText($core, "installed core to preserve")
                [System.IO.File]::WriteAllText($metadata, "installed metadata to preserve")
                $null = Invoke-Installer $source $arguments 1
                Assert-True ([System.IO.File]::ReadAllText($core) -eq "installed core to preserve") "Failed preflight changed core"
                Assert-True ([System.IO.File]::ReadAllText($metadata) -eq "installed metadata to preserve") "Failed preflight changed metadata"
            }
            else {
                $null = Invoke-Installer $source $arguments
                Assert-SameFile (Join-Path $skills "windows-powershell-terminal/SKILL.md") (Join-Path $source "SKILL.md")
                Assert-True (-not (Test-Path -LiteralPath (Join-Path $skills "windows-powershell-terminal/agents"))) "Unexpected metadata directory"
            }
        }
    }

    foreach ($conflict in @("SKILL.md", "agents", "agents/openai.yaml")) {
        Invoke-Case "Shared rejects destination type conflict at $conflict before changing core" {
            $skills = New-TestDirectory "conflict"
            $destination = Join-Path $skills "windows-powershell-terminal"
            New-Item -ItemType Directory -Path $destination | Out-Null
            $core = Join-Path $destination "SKILL.md"
            $badPath = Join-Path $destination $conflict
            if ($conflict -eq "agents") {
                [System.IO.File]::WriteAllText($badPath, "existing file")
            }
            else {
                New-Item -ItemType Directory -Path $badPath -Force | Out-Null
            }
            if ($conflict -ne "SKILL.md") { [System.IO.File]::WriteAllText($core, "original core") }
            $null = Invoke-Installer $repositoryRoot @("-Target", "Shared", "-SkillsPath", $skills) 1
            if ($conflict -eq "SKILL.md") {
                Assert-True (@(Get-ChildItem -LiteralPath $badPath -Force).Count -eq 0) "Installer copied a nested SKILL.md"
            }
            else {
                Assert-True ([System.IO.File]::ReadAllText($core) -eq "original core") "Core changed before conflict detection"
            }
        }
    }

    Invoke-Case "Copilot installs, preserves identical repeats, and rejects conflicting content" {
        $project = New-TestDirectory "copilot [literal] with spaces"
        $arguments = @("-Target", "Copilot", "-ProjectPath", $project)
        $adapter = Join-Path $project "AGENTS.md"
        $null = Invoke-Installer $repositoryRoot $arguments
        Assert-SameFile $adapter (Join-Path $repositoryRoot "adapters/github-copilot/AGENTS.md")
        $mtime = (Get-Item -LiteralPath $adapter).LastWriteTimeUtc
        $null = Invoke-Installer $repositoryRoot $arguments
        Assert-True ((Get-Item -LiteralPath $adapter).LastWriteTimeUtc -eq $mtime) "Identical repeat rewrote adapter"
        [System.IO.File]::WriteAllText($adapter, "existing instructions")
        $output = Invoke-Installer $repositoryRoot $arguments 1
        Assert-True ($output -match "Manually merge") "Missing conflict explanation"
        Assert-True ([System.IO.File]::ReadAllText($adapter) -eq "existing instructions") "Existing instructions overwritten"
    }

    Invoke-Case "Copilot rejects an AGENTS.md directory without nesting files" {
        $project = New-TestDirectory "copilot-directory"
        $adapter = Join-Path $project "AGENTS.md"
        New-Item -ItemType Directory -Path $adapter | Out-Null
        $null = Invoke-Installer $repositoryRoot @("-Target", "Copilot", "-ProjectPath", $project) 1
        Assert-True (@(Get-ChildItem -LiteralPath $adapter -Force).Count -eq 0) "Nested adapter created"
    }

    Invoke-Case "Copilot rejects SkillsPath before creating an adapter" {
        $project = New-TestDirectory "copilot-invalid-options"
        $null = Invoke-Installer $repositoryRoot @("-Target", "Copilot", "-ProjectPath", $project, "-SkillsPath", $project) 1
        Assert-True (@(Get-ChildItem -LiteralPath $project -Force).Count -eq 0) "Invalid options wrote files"
    }

    # Link creation can require elevation or Developer Mode on Windows.
    $linkProbeRoot = New-TestDirectory "link-probe"
    $linkProbe = Join-Path $linkProbeRoot "link"
    $linkTarget = Join-Path $linkProbeRoot "target"
    [System.IO.File]::WriteAllText($linkTarget, "preserve link target")
    $canCreateLinks = $true
    try { New-Item -ItemType SymbolicLink -Path $linkProbe -Target $linkTarget -ErrorAction Stop | Out-Null }
    catch { $canCreateLinks = $false }
    if ($canCreateLinks) {
        foreach ($linkKind in @("skill directory", "core file", "metadata file", "copilot file", "dangling copilot file")) {
            Invoke-Case "Installer rejects a linked $linkKind" {
                $skills = New-TestDirectory "linked-destination"
                $destination = Join-Path $skills "windows-powershell-terminal"
                $external = New-TestDirectory "link-target"
                if ($linkKind -eq "skill directory") {
                    New-Item -ItemType SymbolicLink -Path $destination -Target $external | Out-Null
                    $arguments = @("-Target", "Shared", "-SkillsPath", $skills)
                }
                elseif ($linkKind -match "copilot") {
                    $link = Join-Path $skills "AGENTS.md"
                    $file = Join-Path $external "keep.txt"
                    [System.IO.File]::WriteAllText($file, "preserve")
                    New-Item -ItemType SymbolicLink -Path $link -Target $file | Out-Null
                    # Create a valid link first for compatibility, then make it dangling.
                    if ($linkKind -eq "dangling copilot file") { Remove-Item -LiteralPath $file }
                    $arguments = @("-Target", "Copilot", "-ProjectPath", $skills)
                }
                else {
                    New-Item -ItemType Directory -Path (Join-Path $destination "agents") -Force | Out-Null
                    $file = Join-Path $external "keep.txt"
                    [System.IO.File]::WriteAllText($file, "preserve")
                    $relative = "SKILL.md"
                    if ($linkKind -eq "metadata file") {
                        $relative = "agents/openai.yaml"
                        [System.IO.File]::WriteAllText((Join-Path $destination "SKILL.md"), "original core")
                    }
                    New-Item -ItemType SymbolicLink -Path (Join-Path $destination $relative) -Target $file | Out-Null
                    $arguments = @("-Target", "Shared", "-SkillsPath", $skills)
                }
                $output = Invoke-Installer $repositoryRoot $arguments 1
                Assert-True ($output -match "symbolic link or reparse point") "Missing link explanation"
                if ($linkKind -eq "skill directory" -or $linkKind -eq "dangling copilot file") {
                    Assert-True (@(Get-ChildItem -LiteralPath $external -Force).Count -eq 0) "Wrote through a link"
                }
                else {
                    Assert-True ([System.IO.File]::ReadAllText($file) -eq "preserve") "Link target changed"
                }
                if ($linkKind -eq "metadata file") {
                    Assert-True ([System.IO.File]::ReadAllText((Join-Path $destination "SKILL.md")) -eq "original core") "Partially updated core"
                }
            }
        }
    }
    else {
        $script:skipped += 5
        Write-Host "SKIP: 5 symbolic-link cases; this host does not permit link creation."
    }

    $skillText = [System.IO.File]::ReadAllText((Join-Path $repositoryRoot "SKILL.md"))
    $blocks = @([regex]::Matches($skillText, '(?ms)^```powershell\r?\n(.*?)^```') | ForEach-Object { $_.Groups[1].Value })
    Invoke-Case "Documented UTF-8 write follows PowerShell location and emits no BOM" {
        $code = @($blocks | Where-Object { $_ -match 'GetUnresolvedProviderPathFromPSPath' -and $_ -match 'WriteAllText' })
        Assert-True ($code.Count -eq 1) "Cannot identify the UTF-8 documentation example"
        $processDirectory = New-TestDirectory "process-directory"
        $shellDirectory = New-TestDirectory "shell-directory"
        $originalDirectory = [System.Environment]::CurrentDirectory
        Push-Location -LiteralPath $shellDirectory
        try {
            [System.Environment]::CurrentDirectory = $processDirectory
            & ([scriptblock]::Create($code[0]))
            Assert-True ([System.IO.File]::ReadAllText((Join-Path $shellDirectory "file.txt")) -eq "text") "Wrote to the wrong directory"
            Assert-True (([System.IO.File]::ReadAllBytes((Join-Path $shellDirectory "file.txt"))).Length -eq 4) "Unexpected encoding or BOM"
            Assert-True (@(Get-ChildItem -LiteralPath $processDirectory -Force).Count -eq 0) "Wrote to process working directory"
        }
        finally {
            [System.Environment]::CurrentDirectory = $originalDirectory
            Pop-Location
        }
    }

    foreach ($scenario in @("ignored", "missing-newline", "negated", "tracked")) {
        Invoke-Case "Documented secret guard handles $scenario .env" {
            $code = @($blocks | Where-Object { $_ -match 'git check-ignore --quiet' })
            Assert-True ($code.Count -eq 1) "Cannot identify the Git ignore documentation example"
            $project = New-TestDirectory "git-ignore"
            $null = & git init --quiet $project
            Assert-True ($LASTEXITCODE -eq 0) "Cannot initialize temporary Git repository"
            $ignore = ".env`n"
            if ($scenario -eq "missing-newline") { $ignore = "dist/.env" }
            if ($scenario -eq "negated") { $ignore = ".env`n!.env`n" }
            [System.IO.File]::WriteAllText((Join-Path $project ".gitignore"), $ignore)
            Push-Location -LiteralPath $project
            try {
                if ($scenario -eq "tracked") {
                    [System.IO.File]::WriteAllText((Join-Path $project ".env"), "PLACEHOLDER_ONLY=example")
                    $null = & git add --force -- .env
                    Assert-True ($LASTEXITCODE -eq 0) "Cannot stage temporary placeholder fixture"
                }
                $guard = [scriptblock]::Create($code[0])
                if ($scenario -eq "ignored") { & $guard }
                else { Assert-Throws $guard }
            }
            finally { Pop-Location }
        }
    }
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host "Results: $script:passed passed; $script:failed failed; $script:skipped skipped. Runtime: $($PSVersionTable.PSVersion)."
if ($script:failed -gt 0) { exit 1 }
# Expected native-command failures must not become the runner's exit status.
exit 0
