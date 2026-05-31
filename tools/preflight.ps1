# Kultivar pre-flight check.
#
# Run from the project root before tagging a release:
#
#   pwsh ./tools/preflight.ps1
#
# Exits 0 if every check passes; non-zero (number of failed checks)
# otherwise.  Designed to be the single command between "I think
# we're ready" and `git tag v1.0.0 && git push --tags`.
#
# Checks (in order -- fast ones first so a typo trips early):
#
#   1. flutter analyze   -- zero warnings or errors
#   2. flutter test      -- every test passes
#   3. ARB key parity    -- every key in app_en.arb exists in every
#                           other locale
#   4. Placeholder hunt  -- no `<*_PLACEHOLDER>` strings left in
#                           store_metadata/ (reviewer notes, privacy
#                           URL, contact details)
#   5. CHANGELOG sanity  -- [Unreleased] block is non-empty (a
#                           release with no notes usually means we
#                           forgot to roll the header)
#   6. pubspec version   -- bumped vs. the latest git tag (warns,
#                           doesn't fail -- the version may be
#                           intentionally unchanged for a metadata-
#                           only re-publish)
#
# Add new checks at the bottom of the script.  Each check should:
#   * print a one-line header banner
#   * call Write-Fail on failure (increments $exitCode)
#   * call Write-Pass on success
#
# Output uses ASCII only so PowerShell 5.1 (Windows default) renders
# correctly without a UTF-8 BOM.  If you prefer prettier separators,
# save the file as UTF-8 with BOM and switch to box-drawing chars.

$ErrorActionPreference = 'Stop'
$exitCode = 0

function Write-Section($title) {
    Write-Host ""
    Write-Host "=== $title ==============================================" -ForegroundColor Cyan
}

function Write-Pass($msg) {
    Write-Host "  PASS  $msg" -ForegroundColor Green
}

function Write-Fail($msg) {
    Write-Host "  FAIL  $msg" -ForegroundColor Red
    $script:exitCode += 1
}

function Write-Warn($msg) {
    Write-Host "  WARN  $msg" -ForegroundColor Yellow
}

# --- 1. flutter analyze ---------------------------------------------------
Write-Section "1/6  flutter analyze"

$analyzeOutput = & flutter analyze 2>&1 | Out-String
if ($LASTEXITCODE -ne 0 -or $analyzeOutput -notmatch 'No issues found') {
    Write-Fail "flutter analyze reported issues:"
    Write-Host $analyzeOutput
} else {
    Write-Pass "Static analysis clean"
}

# --- 2. flutter test ------------------------------------------------------
Write-Section "2/6  flutter test"

# `--reporter compact` keeps a passing run to a single tail line and
# expands failures inline with a path -- the ideal mode for a script
# that may either pass silently or scream loudly.
$testOutput = & flutter test --reporter compact 2>&1 | Out-String
if ($LASTEXITCODE -ne 0) {
    Write-Fail "flutter test reported failures (see output above)"
    Write-Host $testOutput
} else {
    # Pull the summary line so we report the count too.
    $lastLine = ($testOutput -split "`n" |
        Where-Object { $_ -match 'All tests passed' } |
        Select-Object -Last 1).Trim()
    if ($lastLine) {
        Write-Pass $lastLine
    } else {
        Write-Pass "Test suite green"
    }
}

# --- 3. ARB key parity ----------------------------------------------------
Write-Section "3/6  ARB key parity"

# Compare every other locale ARB against app_en.arb.  We ignore
# `@@` metadata keys (locale tag, review notes) and `@key` schema
# annotations -- only real translation entries matter for parity.
$baseArb = 'lib/l10n/app_en.arb'
if (-not (Test-Path $baseArb)) {
    Write-Fail "Base ARB $baseArb not found"
} else {
    $baseJson = Get-Content $baseArb -Raw -Encoding UTF8 | ConvertFrom-Json
    $baseKeys = $baseJson.PSObject.Properties.Name |
        Where-Object { $_ -notmatch '^@' } |
        Sort-Object

    $localeArbs = Get-ChildItem lib/l10n/app_*.arb |
        Where-Object { $_.Name -ne 'app_en.arb' }

    $anyArbMissing = $false
    foreach ($file in $localeArbs) {
        $json = Get-Content $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
        $keys = $json.PSObject.Properties.Name |
            Where-Object { $_ -notmatch '^@' }
        $missing = $baseKeys | Where-Object { $keys -notcontains $_ }
        if ($missing.Count -gt 0) {
            Write-Fail ("{0} missing {1} key(s): {2}" -f `
                $file.Name, $missing.Count, ($missing -join ', '))
            $anyArbMissing = $true
        }
    }
    if (-not $anyArbMissing) {
        Write-Pass ("All {0} locale ARBs cover {1} keys" -f `
            $localeArbs.Count, $baseKeys.Count)
    }
}

# --- 4. Placeholder hunt --------------------------------------------------
Write-Section "4/6  Placeholder hunt"

# `<*_PLACEHOLDER>` is the marker convention used by SR7's
# pre-drafted review notes AND by the legal docs + landing page for
# the CIPC company-registration number.  Any placeholder still in
# any of these surfaces means we would publish "fill in your
# company registration number" as literal copy -- visible to every
# user and grounds for App Review / Play Store concerns.
#
# Scope: scan both store_metadata/ (Apple + Play review surfaces)
# AND the legal docs + landing page (user-facing surfaces).
$placeholderHits = @()
$scanPaths = @()
if (Test-Path 'store_metadata') { $scanPaths += 'store_metadata' }
if (Test-Path 'lib/legal')      { $scanPaths += 'lib/legal' }
if (Test-Path 'docs')           { $scanPaths += 'docs' }

if ($scanPaths.Count -gt 0) {
    # The pattern matches `<X_Y_PLACEHOLDER>` AND extended variants
    # like `<X_Y_PLACEHOLDER -- fill before submission>` -- the
    # actual format used in SR7's drafted notes.
    $placeholderHits = Get-ChildItem -Recurse -File -Path $scanPaths |
        Select-String -Pattern '<[A-Z_]+_PLACEHOLDER[^>]*>' |
        Group-Object Path
}

if ($placeholderHits.Count -gt 0) {
    Write-Fail ("{0} file(s) still contain <*_PLACEHOLDER> markers:" -f $placeholderHits.Count)
    $cwd = (Get-Location).Path + '\'
    foreach ($hit in $placeholderHits) {
        $relPath = $hit.Name.Replace($cwd, '')
        $plural = if ($hit.Count -ne 1) { 's' } else { '' }
        Write-Host ("          {0}  ({1} hit{2})" -f $relPath, $hit.Count, $plural) `
            -ForegroundColor Yellow
    }
    Write-Host "        Replace each placeholder before submission." -ForegroundColor Yellow
} else {
    Write-Pass "No placeholder markers left in store_metadata/"
}

# --- 5. CHANGELOG sanity --------------------------------------------------
Write-Section "5/6  CHANGELOG sanity"

# A release where [Unreleased] is empty usually means someone forgot
# to roll the header to a versioned section, or rolled the header
# and forgot to drop new notes for THIS release.  Either case is
# a yellow flag; we warn, not fail.
$changelog = Get-Content CHANGELOG.md -Raw -Encoding UTF8
$unreleasedMatch = [regex]::Match($changelog, '(?ms)## \[Unreleased\](.*?)(?=^## \[|\z)')
if (-not $unreleasedMatch.Success) {
    Write-Warn "No [Unreleased] section found in CHANGELOG.md"
} else {
    $body = $unreleasedMatch.Groups[1].Value.Trim()
    # Strip common headers that exist even when no entries are present.
    $stripped = $body -replace '(?m)^###\s+\w.*$', '' -replace '\s', ''
    if ($stripped.Length -eq 0) {
        Write-Warn "[Unreleased] section is empty -- did you forget to roll a release header?"
    } else {
        $entryCount = ([regex]::Matches($body, '(?m)^\s*-\s+')).Count
        Write-Pass "[Unreleased] section has $entryCount entry/entries"
    }
}

# --- 6. pubspec.yaml version vs git tag -----------------------------------
Write-Section "6/6  Version bump check"

$pubspecVersion = (Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)' |
    Select-Object -First 1).Matches.Groups[1].Value
if (-not $pubspecVersion) {
    Write-Warn "Could not parse version from pubspec.yaml"
} else {
    # `git describe` writes to stderr when there's no .git dir; in
    # PowerShell 5.1 that gets rendered as a NativeCommandError which
    # bubbles up via $ErrorActionPreference = 'Stop'.  We capture
    # both streams and inspect $LASTEXITCODE manually to keep the
    # check graceful when run on a freshly-cloned working tree.
    $latestTag = $null
    try {
        $latestTag = (& git describe --tags --abbrev=0 2>&1 |
            Where-Object { $_ -is [string] } | Select-Object -First 1)
        if ($LASTEXITCODE -ne 0) { $latestTag = $null }
    } catch {
        $latestTag = $null
    }

    if ([string]::IsNullOrEmpty($latestTag) -or $latestTag -match 'fatal') {
        Write-Pass ("pubspec.yaml = {0} (no git tag history yet -- first release)" -f $pubspecVersion)
    } else {
        # Strip the leading `v` if present so we compare apples to apples.
        $tagStripped = $latestTag -replace '^v', ''
        # pubspec carries `1.0.0+1` (semver + build number); the tag
        # is usually just `1.0.0`.  Compare the part before `+`.
        $pubspecBase = ($pubspecVersion -split '\+')[0]
        if ($pubspecBase -eq $tagStripped) {
            Write-Warn ("pubspec.yaml ({0}) matches latest tag ({1}) -- bump before release" -f `
                $pubspecVersion, $latestTag)
        } else {
            Write-Pass ("pubspec.yaml = {0} (last tag = {1})" -f `
                $pubspecVersion, $latestTag)
        }
    }
}

# --- Summary --------------------------------------------------------------
Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host " ALL CHECKS PASSED -- safe to tag and submit" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Host "==========================================================" -ForegroundColor Red
    Write-Host (" {0} CHECK(S) FAILED -- see above" -f $exitCode) -ForegroundColor Red
    Write-Host "==========================================================" -ForegroundColor Red
}

exit $exitCode
