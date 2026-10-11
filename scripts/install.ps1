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

.PARAMETER SkillsPath
Overrides the parent skills directory for Shared, Codex, Gemini, or Claude.
The windows-powershell-terminal subdirectory is created beneath this path.
Use this for custom client locations or isolated testing without changing HOME.
It cannot be combined with the Copilot target, which uses ProjectPath.

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
    [string]$ProjectPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$SkillsPath
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

function Assert-DestinationPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Leaf", "Container")]
        [string]$PathType
    )

    try {
        $item = Get-Item -LiteralPath $LiteralPath -Force -ErrorAction Stop
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        return
    }

    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Destination is a symbolic link or reparse point: $LiteralPath. Choose a regular destination instead."
    }

    $expectDirectory = $PathType -eq "Container"
    if ($item.PSIsContainer -ne $expectDirectory) {
        throw "Destination has the wrong path type (expected $PathType): $LiteralPath"
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

    # Check every installer-owned destination before updating either file.
    # This prevents predictable partial updates; it is not a rollback system.
    Assert-DestinationPath -LiteralPath $Destination -PathType Container
    Assert-DestinationPath -LiteralPath $destinationSkill -PathType Leaf
    if ($IncludeOpenAIMetadata) {
        $destinationAgents = Join-Path -Path $Destination -ChildPath "agents"
        $destinationOpenAIMetadata = Join-Path -Path $destinationAgents -ChildPath "openai.yaml"
        Assert-DestinationPath -LiteralPath $destinationAgents -PathType Container
        Assert-DestinationPath -LiteralPath $destinationOpenAIMetadata -PathType Leaf
    }

    New-DirectoryIfMissing -LiteralPath $Destination
    Copy-Item -LiteralPath $SourceSkill -Destination $destinationSkill -Force -ErrorAction Stop

    if ($IncludeOpenAIMetadata) {
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
        if ($PSBoundParameters.ContainsKey("SkillsPath")) {
            throw "SkillsPath cannot be used with Copilot. Use ProjectPath instead."
        }

        Assert-FileExists -LiteralPath $sourceCopilotAdapter -Description "GitHub Copilot adapter"

        if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
            throw "ProjectPath is required when Target is Copilot."
        }

        if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
            throw "ProjectPath is not an existing directory: $ProjectPath"
        }

        $resolvedProjectPath = (Resolve-Path -LiteralPath $ProjectPath -ErrorAction Stop).Path
        $destinationAdapter = Join-Path -Path $resolvedProjectPath -ChildPath "AGENTS.md"
        Assert-DestinationPath -LiteralPath $destinationAdapter -PathType Leaf

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

        if ($PSBoundParameters.ContainsKey("SkillsPath")) {
            if ([string]::IsNullOrWhiteSpace($SkillsPath)) {
                throw "SkillsPath must not be blank."
            }

            $skillsProvider = $null
            $skillsDrive = $null
            $resolvedSkillsPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
                $SkillsPath, [ref]$skillsProvider, [ref]$skillsDrive)
            if ($skillsProvider.Name -ne "FileSystem") {
                throw "SkillsPath must be a filesystem path."
            }
            $destination = Join-Path -Path $resolvedSkillsPath -ChildPath $skillFolderName
        }

        Install-SkillFiles -Destination $destination -SourceSkill $sourceSkill -IncludeOpenAIMetadata $includeOpenAIMetadata -SourceOpenAIMetadata $sourceAgentMetadata
    }
}
catch {
    Write-Error -Message ("Installation failed: " + $_.Exception.Message) -ErrorAction Continue
    exit 1
}
