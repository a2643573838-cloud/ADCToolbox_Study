param(
    [string]$UpstreamUrl = "https://github.com/Arcadia-1/ADCToolbox.git",
    [string]$UpstreamBranch = "main"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

$repoRoot = git rev-parse --show-toplevel
Set-Location $repoRoot

$status = git status --porcelain
if ($status) {
    Write-Host "There are uncommitted changes. Commit your work before syncing upstream."
    Write-Host ""
    git status --short
    Write-Host ""
    Write-Host "Common commands:"
    Write-Host "  git add ."
    Write-Host '  git commit -m "Update my study notes"'
    exit 1
}

$upstreamExists = git remote | Where-Object { $_ -eq "upstream" }
if (-not $upstreamExists) {
    Write-Step "Adding upstream"
    git remote add upstream $UpstreamUrl
} else {
    $currentUrl = git remote get-url upstream
    if ($currentUrl -ne $UpstreamUrl) {
        Write-Step "Updating upstream URL"
        git remote set-url upstream $UpstreamUrl
    }
}

Write-Step "Fetching upstream/$UpstreamBranch"
git fetch upstream

Write-Step "Merging upstream/$UpstreamBranch into the current branch"
git merge "upstream/$UpstreamBranch"

Write-Step "Sync complete"
git status --short --branch
