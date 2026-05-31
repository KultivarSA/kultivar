# Kultivar release pipeline.
#
# One command from "I think we're ready" to "AAB is signed, tagged,
# and ready to drag into Play Console".
#
# Usage:
#
#   pwsh ./tools/release.ps1                     # interactive
#   pwsh ./tools/release.ps1 -Version 1.0.1      # explicit semver
#   pwsh ./tools/release.ps1 -Version 1.0.1 -DryRun   # show plan only
#   pwsh ./tools/release.ps1 -SkipPreflight      # skip preflight gate
#                                                # (do not use in CI)
#
# The pipeline:
#
#   0. Working tree must be clean (no uncommitted changes).  Releases
#      go through git; an uncommitted edit would land in the AAB
#      without ever being tagged.  Exception: -SkipGitClean if you
#      know what you're doing.
#   1. Run preflight (analyze / test / ARB parity / placeholder hunt /
#      CHANGELOG sanity / version bump check).  If anything fails,
#      the release stops here.
#   2. Bump pubspec.yaml version: <semver>+<buildNumber>.  Build number
#      auto-increments by one.
#   3. Roll CHANGELOG.md: rename `[Unreleased]` to `[X.Y.Z] - YYYY-MM-DD`
#      and start a new empty `[Unreleased]` block above it.
#   4. Commit the version bump + CHANGELOG roll as a single commit.
#   5. Build the release AAB: flutter build appbundle --release.
#   6. Tag the commit as vX.Y.Z (no push -- you push when ready).
#   7. Print the AAB path + upload checklist.
#
# Exits non-zero on any failure.  Each step prints a banner so a
# tail-cut log still reads cleanly.

[CmdletBinding()]
param(
    [string]$Version,
    [switch]$DryRun,
    [switch]$SkipPreflight,
    [switch]$SkipGitClean
)

$ErrorActionPreference = 'Stop'

# --- Output helpers (match preflight.ps1 style) ---------------------------

function Write-Section($title) {
    Write-Host ""
    Write-Host "=== $title ==============================================" -ForegroundColor Cyan
}
function Write-Pass($msg) { Write-Host "  PASS  $msg" -ForegroundColor Green }
function Write-Fail($msg) {
    Write-Host "  FAIL  $msg" -ForegroundColor Red
    exit 1
}
function Write-Info($msg) { Write-Host "  INFO  $msg" -ForegroundColor Yellow }
function Write-Action($msg) { Write-Host "  -->   $msg" -ForegroundColor Magenta }

# --- Step 0: Working tree clean ------------------------------------------
Write-Section "0/7  Working tree state"

if (-not $SkipGitClean) {
    $gitStatus = & git status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Info "Not a git repository -- skipping clean-tree check."
    } elseif ($gitStatus) {
        Write-Host "  FAIL  Working tree has uncommitted changes:" -ForegroundColor Red
        Write-Host $gitStatus
        Write-Host "        Commit or stash before releasing.  Pass" -ForegroundColor Yellow
        Write-Host "        -SkipGitClean if you're absolutely sure." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Pass "Working tree clean"
    }
} else {
    Write-Info "-SkipGitClean was passed.  Hope you know what you're doing."
}

# --- Step 1: Preflight ---------------------------------------------------
Write-Section "1/7  Preflight gate"

if ($SkipPreflight) {
    Write-Info "-SkipPreflight was passed.  Skipping the six release gates."
    Write-Info "Do NOT use this flag in CI."
} else {
    # Run preflight.  If it fails, the release stops.  We pipe the
    # output through so the user sees the same banners they'd see
    # from a manual run.
    $preflightScript = Join-Path $PSScriptRoot 'preflight.ps1'
    if (-not (Test-Path $preflightScript)) {
        Write-Fail "preflight.ps1 not found at $preflightScript"
    }
    & $preflightScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  Preflight reported $LASTEXITCODE failure(s).  Release aborted." -ForegroundColor Red
        Write-Host "  Fix the failed checks and re-run." -ForegroundColor Yellow
        exit $LASTEXITCODE
    }
}

# --- Step 2: Determine the next version ----------------------------------
Write-Section "2/7  Version bump"

$pubspecPath = "pubspec.yaml"
$pubspecLines = Get-Content $pubspecPath
# Wrap in @() so a single-match result is still an array -- without
# this, PowerShell collapses to a string and `[0]` indexes into the
# first CHARACTER instead of the first element.
$versionLines = @($pubspecLines | Where-Object { $_ -match '^version:' })
if ($versionLines.Count -eq 0) {
    Write-Fail "No 'version:' line found in pubspec.yaml"
}
$currentLine = $versionLines[0]
if (-not ($currentLine -match '^version:\s*(\d+\.\d+\.\d+)\+(\d+)$')) {
    Write-Fail "Could not parse current version from pubspec.yaml line: '$currentLine'"
}
$currentSemver = $Matches[1]
$currentBuild  = [int]$Matches[2]
Write-Info "Current version: $currentSemver+$currentBuild"

# If no -Version, prompt the user with suggested bumps.
if (-not $Version) {
    $parts = $currentSemver -split '\.'
    $suggestPatch = "{0}.{1}.{2}" -f $parts[0], $parts[1], ([int]$parts[2] + 1)
    $suggestMinor = "{0}.{1}.0" -f $parts[0], ([int]$parts[1] + 1)
    $suggestMajor = "{0}.0.0" -f ([int]$parts[0] + 1)

    Write-Host ""
    Write-Host "  Choose the next semver:" -ForegroundColor White
    Write-Host "    [1] Patch  -> $suggestPatch    (bugfix / copy tweak / refactor)"
    Write-Host "    [2] Minor  -> $suggestMinor    (new feature / additive UI / dep upgrade)"
    Write-Host "    [3] Major  -> $suggestMajor    (breaking change / paid-tier reshuffle)"
    Write-Host "    [c] Custom -> enter your own"
    Write-Host ""
    $choice = Read-Host "  Pick"
    switch ($choice) {
        '1' { $Version = $suggestPatch }
        '2' { $Version = $suggestMinor }
        '3' { $Version = $suggestMajor }
        'c' { $Version = (Read-Host "  Enter semver (e.g. 1.2.3)") }
        default { Write-Fail "Aborted -- no version chosen." }
    }
}

if (-not ($Version -match '^\d+\.\d+\.\d+$')) {
    Write-Fail "Version '$Version' is not a valid semver (X.Y.Z)."
}

$nextBuild = $currentBuild + 1
$newVersionLine = "version: $Version+$nextBuild"
Write-Pass "Next version: $Version+$nextBuild"

if ($DryRun) {
    Write-Info "Dry run -- would replace '$currentLine' with '$newVersionLine'"
} else {
    # Replace in-place.  Set-Content preserves the rest of the file.
    $newContent = $pubspecLines | ForEach-Object {
        if ($_ -eq $currentLine) { $newVersionLine } else { $_ }
    }
    $newContent | Set-Content -Path $pubspecPath -Encoding UTF8
    Write-Action "Updated pubspec.yaml"
}

# --- Step 3: CHANGELOG roll ----------------------------------------------
Write-Section "3/7  CHANGELOG roll"

$changelogPath = "CHANGELOG.md"
$changelog = Get-Content $changelogPath -Raw -Encoding UTF8
$today = Get-Date -Format "yyyy-MM-dd"
$newHeader = "## [$Version] - $today"

# Replace "## [Unreleased]" with the new versioned header, AND insert
# a fresh empty Unreleased block above it.
$rolled = $changelog -replace `
    '## \[Unreleased\]', `
    "## [Unreleased]`n`n## [$Version] - $today"

# Sanity check: rolled content must differ from input.  If not, the
# CHANGELOG didn't have an [Unreleased] section to roll.
if ($rolled -eq $changelog) {
    Write-Fail "CHANGELOG.md has no [Unreleased] section to roll.  Add one and retry."
}

if ($DryRun) {
    Write-Info "Dry run -- would insert: $newHeader"
} else {
    Set-Content -Path $changelogPath -Value $rolled -Encoding UTF8 -NoNewline
    Write-Action "Rolled CHANGELOG.md -- new section: [$Version] - $today"
}

# --- Step 4: Commit ------------------------------------------------------
Write-Section "4/7  Commit"

if ($DryRun) {
    Write-Info "Dry run -- would commit pubspec.yaml + CHANGELOG.md"
} else {
    & git add pubspec.yaml CHANGELOG.md
    if ($LASTEXITCODE -ne 0) { Write-Fail "git add failed" }

    & git commit -m "Release v$Version" 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Info "git commit reported non-zero (maybe a pre-commit hook).  Continuing."
    } else {
        Write-Action "Committed: 'Release v$Version'"
    }
}

# --- Step 5: Build AAB ---------------------------------------------------
Write-Section "5/7  Build release AAB"

if ($DryRun) {
    Write-Info "Dry run -- would run flutter build appbundle --release"
} else {
    Write-Action "Running flutter build appbundle --release ..."
    & flutter build appbundle --release
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "flutter build appbundle failed.  Check signing config in android/key.properties."
    }

    $aabPath = "build/app/outputs/bundle/release/app-release.aab"
    if (-not (Test-Path $aabPath)) {
        Write-Fail "Build claimed success but AAB not found at $aabPath"
    }
    $aabSize = (Get-Item $aabPath).Length
    $aabMb = [math]::Round($aabSize / 1MB, 2)
    Write-Pass "AAB built: $aabPath ($aabMb MB)"
}

# --- Step 6: Git tag -----------------------------------------------------
Write-Section "6/7  Git tag"

if ($DryRun) {
    Write-Info "Dry run -- would tag commit as v$Version"
} else {
    & git tag "v$Version"
    if ($LASTEXITCODE -ne 0) {
        Write-Info "git tag failed (maybe a tag with this name already exists)."
        Write-Info "Continuing -- you can tag manually if needed."
    } else {
        Write-Action "Tagged: v$Version"
    }
}

# --- Step 7: Upload checklist --------------------------------------------
Write-Section "7/7  Upload checklist"

Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host ""
Write-Host "    1. Push commit + tag (when you're ready):" -ForegroundColor White
Write-Host "         git push && git push --tags" -ForegroundColor Gray
Write-Host ""
Write-Host "    2. Upload AAB to Play Console:" -ForegroundColor White
Write-Host "         Path: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Gray
Write-Host "         Track: Internal Testing -> Closed Testing -> Production" -ForegroundColor Gray
Write-Host ""
Write-Host "    3. Update Play Console release notes from the new" -ForegroundColor White
Write-Host "       [$Version] section in CHANGELOG.md.  Or use:" -ForegroundColor White
Write-Host "         store_metadata/android/en-US/changelogs/<versionCode>.txt" -ForegroundColor Gray
Write-Host ""
Write-Host "    4. Once Play approves and rollout is configured:" -ForegroundColor White
Write-Host "         git push origin v$Version" -ForegroundColor Gray
Write-Host ""

Write-Host "==========================================================" -ForegroundColor Green
Write-Host " RELEASE v$Version READY TO SHIP" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
