<#
.SYNOPSIS
Installs the Windows PowerShell Agent Skill from this local repository.

.DESCRIPTION
Copies the canonical SKILL.md to a supported local skill directory. Shared and
Codex installations also include OpenAI display metadata; Gemini and Claude
install only the portable SKILL.md. Copilot installs its independent adapter
into a target project. The operation is local, dependency-free, and safe to run
repeatedly. A different existing AGENTS.md is never overwritten or modified
automatically.

.PARAMETER Target
Selects the installation target: Shared, Codex, Gemini, Claude, or Copilot.
Shared and Codex use the shared Agent Skills directory and include OpenAI
metadata. Gemini and Claude install only SKILL.md. Copilot uses the independent
AGENTS.md adapter.

.PARAMETER ProjectPath
Specifies the existing project directory for the Copilot target. This parameter
is required when Target is Copilot and is ignored for other targets.

.EXAMPLE
.\scripts\install.ps1 -Target Shared

.EXAMPLE
powershell.exe -NoProfile -File ".\scripts\install.ps1" -Target Claude

.EXAMPLE
.\scripts\install.ps1 -Target Copilot -ProjectPath "C:\work\my-project"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet("Shared", "Codex", "Gemini", "Claude", "Copilot")]
    [string]$Target = "Shared",

    [Parameter()]
    [string]$ProjectPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

function Assert-FileExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath,

        [Parameter(Mandatory = $true)]
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Leaf)) {
        throw "$Description was not found: $LiteralPath"
    }
}

function New-DirectoryIfMissing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    if (-not (Test-Path -LiteralPath $LiteralPath -PathType Container)) {
        New-Item -ItemType Directory -Path $LiteralPath -Force -ErrorAction Stop | Out-Null
    }
}

function Install-SkillFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Destination,

        [Parameter(Mandatory = $true)]
        [string]$SourceSkill,

        [Parameter(Mandatory = $true)]
        [bool]$IncludeOpenAIMetadata,

        [Parameter()]
        [string]$SourceOpenAIMetadata
    )

    Assert-FileExists -LiteralPath $SourceSkill -Description "Canonical SKILL.md"

    if ($IncludeOpenAIMetadata) {
        if ([string]::IsNullOrWhiteSpace($SourceOpenAIMetadata)) {
            throw "SourceOpenAIMetadata is required when OpenAI metadata is included."
        }

        Assert-FileExists -LiteralPath $SourceOpenAIMetadata -Description "OpenAI display metadata"
    }

    $destinationSkill = Join-Path -Path $Destination -ChildPath "SKILL.md"

    New-DirectoryIfMissing -LiteralPath $Destination
    Copy-Item -LiteralPath $SourceSkill -Destination $destinationSkill -Force -ErrorAction Stop

    if ($IncludeOpenAIMetadata) {
        $destinationAgents = Join-Path -Path $Destination -ChildPath "agents"
        $destinationOpenAIMetadata = Join-Path -Path $destinationAgents -ChildPath "openai.yaml"

        New-DirectoryIfMissing -LiteralPath $destinationAgents
        Copy-Item -LiteralPath $SourceOpenAIMetadata -Destination $destinationOpenAIMetadata -Force -ErrorAction Stop
    }

    Write-Host "Installed Windows PowerShell Agent Skill to: $Destination"
}

try {
    $repositoryRoot = Split-Path -Path $PSScriptRoot -Parent
    $sourceSkill = Join-Path -Path $repositoryRoot -ChildPath "SKILL.md"
    $sourceAgentsDirectory = Join-Path -Path $repositoryRoot -ChildPath "agents"
    $sourceAgentMetadata = Join-Path -Path $sourceAgentsDirectory -ChildPath "openai.yaml"
    $sourceAdaptersDirectory = Join-Path -Path $repositoryRoot -ChildPath "adapters"
    $sourceCopilotDirectory = Join-Path -Path $sourceAdaptersDirectory -ChildPath "github-copilot"
    $sourceCopilotAdapter = Join-Path -Path $sourceCopilotDirectory -ChildPath "AGENTS.md"

    if ($Target -eq "Copilot") {
        Assert-FileExists -LiteralPath $sourceCopilotAdapter -Description "GitHub Copilot adapter"

        if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
            throw "ProjectPath is required when Target is Copilot."
        }

        if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
            throw "ProjectPath is not an existing directory: $ProjectPath"
        }

        $resolvedProjectPath = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
        $destinationAdapter = Join-Path -Path $resolvedProjectPath -ChildPath "AGENTS.md"

        if (Test-Path -LiteralPath $destinationAdapter -PathType Leaf) {
            $sourceHash = (Get-FileHash -LiteralPath $sourceCopilotAdapter -Algorithm SHA256 -ErrorAction Stop).Hash
            $destinationHash = (Get-FileHash -LiteralPath $destinationAdapter -Algorithm SHA256 -ErrorAction Stop).Hash

            if ($sourceHash -eq $destinationHash) {
                Write-Host "GitHub Copilot adapter is already installed at: $destinationAdapter"
            }
            else {
                throw "AGENTS.md already exists at '$destinationAdapter'. It was not overwritten. Manually merge 'adapters\github-copilot\AGENTS.md' into the existing file."
            }
        }
        else {
            Copy-Item -LiteralPath $sourceCopilotAdapter -Destination $destinationAdapter -ErrorAction Stop
            Write-Host "Installed GitHub Copilot adapter to: $destinationAdapter"
        }
    }
    else {
        $skillFolderName = "windows-powershell-terminal"
        $includeOpenAIMetadata = $false

        if (($Target -eq "Shared") -or ($Target -eq "Codex")) {
            $sharedRoot = Join-Path -Path $HOME -ChildPath ".agents"
            $sharedSkills = Join-Path -Path $sharedRoot -ChildPath "skills"
            $destination = Join-Path -Path $sharedSkills -ChildPath $skillFolderName
            $includeOpenAIMetadata = $true
        }
        elseif ($Target -eq "Gemini") {
            $geminiRoot = Join-Path -Path $HOME -ChildPath ".gemini"
            $geminiSkills = Join-Path -Path $geminiRoot -ChildPath "skills"
            $destination = Join-Path -Path $geminiSkills -ChildPath $skillFolderName
        }
        elseif ($Target -eq "Claude") {
            $claudeRoot = Join-Path -Path $HOME -ChildPath ".claude"
            $claudeSkills = Join-Path -Path $claudeRoot -ChildPath "skills"
            $destination = Join-Path -Path $claudeSkills -ChildPath $skillFolderName
        }
        else {
            throw "Unsupported installation target: $Target"
        }

        Install-SkillFiles -Destination $destination -SourceSkill $sourceSkill -IncludeOpenAIMetadata $includeOpenAIMetadata -SourceOpenAIMetadata $sourceAgentMetadata
    }
}
catch {
    Write-Error -Message ("Installation failed: " + $_.Exception.Message)
    exit 1
}
