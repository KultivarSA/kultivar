# Brute-force build watchdog.
#
# Some environments (corporate AV stacks like OpenText + Webroot +
# defender running simultaneously) race Gradle's transform cache
# writes -- every build fails on a different `Could not move
# temporary workspace` error.  The fix would be to add Gradle's
# cache dir to AV exclusions, but on a corporate-managed machine
# that requires an IT ticket.
#
# This script is a pragmatic workaround:
#
#   1. Kill any leftover Java processes (Gradle daemons holding locks)
#   2. Run flutter build
#   3. If the build fails with a transform-cache "could not move"
#      error, parse the failing transform hash from the output,
#      delete just that specific cache directory, and retry
#   4. After ~5-10 retries the full cache populates and the build
#      eventually succeeds
#   5. Detect "no progress" (same hash failing twice in a row) and
#      bail with a clear message
#
# Usage:
#
#   # Default: builds debug APK, no install on device
#   pwsh ./tools/retry-build.ps1
#
#   # Allow more / fewer attempts (default 15)
#   pwsh ./tools/retry-build.ps1 -MaxRetries 25
#
#   # Build release AAB instead of debug APK
#   pwsh ./tools/retry-build.ps1 -Release
#
# After a successful run, install on connected device with:
#
#   flutter install
#
# or push directly via adb:
#
#   adb install -r build/app/outputs/flutter-apk/app-debug.apk

[CmdletBinding()]
param(
    [int]$MaxRetries = 15,
    [switch]$Release
)

$ErrorActionPreference = 'Stop'

# ── Output helpers ────────────────────────────────────────────────
function Write-Section($title) {
    Write-Host ""
    Write-Host "=== $title ==============================================" -ForegroundColor Cyan
}
function Write-Pass($msg) { Write-Host "  PASS  $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "  INFO  $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "  FAIL  $msg" -ForegroundColor Red }

# ── Discover Gradle cache version dynamically ─────────────────────
#
# The transforms directory lives under
# %USERPROFILE%\.gradle\caches\<version>\transforms\ where <version>
# changes when Gradle bumps a major.  We glob for it so the script
# doesn't break on the next bump.
$gradleCacheRoot = "$env:USERPROFILE\.gradle\caches"
if (-not (Test-Path $gradleCacheRoot)) {
    Write-Fail "Gradle cache not found at $gradleCacheRoot -- has the project ever built?"
    exit 1
}

# ── Pick build command ────────────────────────────────────────────
$buildCmd = if ($Release) {
    'build', 'appbundle', '--release', '--dart-define-from-file=env.json'
} else {
    'build', 'apk', '--debug', '--dart-define-from-file=env.json'
}

# ── Retry loop ────────────────────────────────────────────────────
$retryCount = 0
$lastFailedHash = $null

while ($retryCount -lt $MaxRetries) {
    $retryCount++

    Write-Section "Attempt $retryCount / $MaxRetries"

    # Kill any Gradle daemons holding cache locks
    Get-Process java -ErrorAction SilentlyContinue | Stop-Process -Force

    # Run the build.  Tee output so we can both display it live AND
    # inspect it for the failure pattern.
    #
    # Note on $ErrorActionPreference:  PowerShell 5.1 wraps native-command
    # stderr lines into ErrorRecords when 2>&1 is used.  With Stop mode
    # set, the FIRST stderr write (typically a benign Java compiler
    # warning) halts the script before flutter even finishes invoking
    # Gradle.  We relax the preference for the duration of the native
    # call and rely on $LASTEXITCODE (set after the process exits) for
    # success/failure detection.
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & flutter @buildCmd 2>&1 | Tee-Object -Variable buildLog | Out-String
    } finally {
        $ErrorActionPreference = $prevEAP
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Section "BUILD SUCCEEDED on attempt $retryCount"
        Write-Host ""
        Write-Host "  Next steps:" -ForegroundColor White
        if ($Release) {
            Write-Host "    Path to AAB: build/app/outputs/bundle/release/app-release.aab" -ForegroundColor Gray
            Write-Host "    Upload to Play Console -> Internal Testing" -ForegroundColor Gray
        } else {
            Write-Host "    Install on connected device: flutter install" -ForegroundColor Gray
            Write-Host "    Or via adb: adb install -r build/app/outputs/flutter-apk/app-debug.apk" -ForegroundColor Gray
        }
        exit 0
    }

    # Look for the transform-cache failure signature in the output.
    # Pattern: "transforms\<32-hex-hash>-<uuid>" inside the error.
    $hashMatch = [regex]::Match(
        $output,
        'transforms\\([a-f0-9]{32})-[a-f0-9-]+'
    )

    if (-not $hashMatch.Success) {
        # The build failed for some OTHER reason -- maybe a real
        # compile error, maybe a network failure.  Don't retry
        # blindly; surface the failure to the user.
        Write-Section "BUILD FAILED -- not a transform-cache issue"
        Write-Host ""
        Write-Host "  This script only handles the 'Could not move temporary"
        Write-Host "  workspace' AV race.  The current failure is something"
        Write-Host "  else.  See the build output above for the actual error."
        exit 1
    }

    $failedHash = $hashMatch.Groups[1].Value

    # Detect no-progress: same hash failing twice in a row means
    # something is permanently holding the file (not just an AV race
    # that retries can win).  Stop instead of grinding forever.
    if ($failedHash -eq $lastFailedHash) {
        Write-Section "NO PROGRESS -- same transform failing repeatedly"
        Write-Host ""
        Write-Host "  Transform: $failedHash"
        Write-Host ""
        Write-Host "  Likely something has a permanent lock on this cache entry."
        Write-Host "  Try:"
        Write-Host "    1. Reboot Windows (releases every file handle)"
        Write-Host "    2. Re-run this script"
        Write-Host "    3. If it fails again on the same hash -- the AV"
        Write-Host "       is actively blocking writes.  Submit an IT ticket"
        Write-Host "       requesting `$env:USERPROFILE\.gradle\caches` and"
        Write-Host "       this project folder be added to AV exclusions."
        exit 1
    }
    $lastFailedHash = $failedHash

    # Nuke that one transform across all gradle cache versions.
    # The glob handles the version subdirectory automatically.
    $cleared = $false
    Get-ChildItem -Path $gradleCacheRoot -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            $transformPath = Join-Path $_.FullName "transforms"
            if (Test-Path $transformPath) {
                Get-ChildItem -Path $transformPath -Directory -Filter "${failedHash}*" -ErrorAction SilentlyContinue |
                    ForEach-Object {
                        Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
                        $cleared = $true
                    }
            }
        }

    if ($cleared) {
        Write-Info "Cleared failed transform $failedHash -- retrying"
    } else {
        Write-Info "Transform $failedHash not found in cache (already cleared?) -- retrying"
    }
}

Write-Section "MAX RETRIES EXCEEDED"
Write-Host ""
Write-Host "  After $MaxRetries attempts the build is still failing on"
Write-Host "  transform cache races.  The AV is being persistent."
Write-Host ""
Write-Host "  Options:"
Write-Host "    1. Reboot and re-run (often clears stuck handles)"
Write-Host "    2. Run again with -MaxRetries 25 if you saw progress"
Write-Host "    3. Submit an IT ticket for AV exclusions on:"
Write-Host "         - `$env:USERPROFILE\.gradle"
Write-Host "         - $((Get-Location).Path)"
Write-Host "         - java.exe + gradle.exe processes"
Write-Host "    4. Switch to Path A (cloud build via GitHub Actions)"
exit 1
