# Rancher Desktop K3s Cache Population Script
# This script downloads k3s files and caches them locally to bypass certificate issues

param(
    [string]$Version = "v1.33.3+k3s1"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Rancher Desktop K3s Cache Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$baseUrl = "https://github.com/k3s-io/k3s/releases/download/$Version"
$cacheDir = "$env:LOCALAPPDATA\rancher-desktop\cache\k3s\$Version"
$tempDir = "$env:TEMP\rd-k3s-cache"

# Files to download
$files = @(
    "k3s",
    "k3s-airgap-images-amd64.tar.zst",
    "sha256sum-amd64.txt"
)

Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Cache Directory: $cacheDir" -ForegroundColor Yellow
Write-Host ""

# Create temporary directory
Write-Host "[1/5] Creating temporary directory..." -ForegroundColor Green
try {
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-Host "  ✓ Temporary directory created: $tempDir" -ForegroundColor Gray
} catch {
    Write-Host "  ✗ Failed to create temporary directory: $_" -ForegroundColor Red
    exit 1
}

# Temporarily disable certificate validation
Write-Host "[2/5] Configuring certificate validation bypass..." -ForegroundColor Green
$originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
Write-Host "  ✓ Certificate validation temporarily disabled for this session" -ForegroundColor Gray
Write-Host "  ⚠ This is only for downloading k3s files from GitHub" -ForegroundColor Yellow

# Download files
Write-Host "[3/5] Downloading k3s files..." -ForegroundColor Green
$downloadSuccess = $true

# Try to detect PowerShell version and use appropriate method
$psVersion = $PSVersionTable.PSVersion.Major

foreach ($file in $files) {
    $url = "$baseUrl/$file"
    $destination = Join-Path $tempDir $file

    Write-Host "  Downloading: $file" -ForegroundColor Gray

    $downloaded = $false

    # Method 1: Try PowerShell 7+ with -SkipCertificateCheck
    if ($psVersion -ge 7 -and -not $downloaded) {
        try {
            Write-Host "    Trying PowerShell 7+ method..." -ForegroundColor DarkGray
            Invoke-WebRequest -Uri $url -OutFile $destination -SkipCertificateCheck -ErrorAction Stop
            $downloaded = $true
        } catch {
            Write-Host "    PowerShell 7+ method failed: $_" -ForegroundColor DarkGray
        }
    }

    # Method 2: Try curl.exe (built into Windows 10+)
    if (-not $downloaded) {
        try {
            Write-Host "    Trying curl.exe method..." -ForegroundColor DarkGray
            $curlPath = Get-Command curl.exe -ErrorAction SilentlyContinue
            if ($curlPath) {
                # Use curl with -k to skip certificate validation
                & curl.exe -k -L -o $destination $url 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0 -and (Test-Path $destination)) {
                    $downloaded = $true
                } else {
                    Write-Host "    curl.exe failed with exit code: $LASTEXITCODE" -ForegroundColor DarkGray
                }
            } else {
                Write-Host "    curl.exe not found" -ForegroundColor DarkGray
            }
        } catch {
            Write-Host "    curl.exe method failed: $_" -ForegroundColor DarkGray
        }
    }

    # Method 3: Try WebClient (fallback)
    if (-not $downloaded) {
        try {
            Write-Host "    Trying WebClient method..." -ForegroundColor DarkGray
            $webclient = New-Object System.Net.WebClient
            $webclient.DownloadFile($url, $destination)
            $downloaded = $true
        } catch {
            Write-Host "    WebClient method failed: $_" -ForegroundColor DarkGray
        }
    }

    # Method 4: Suggest WSL fallback
    if (-not $downloaded) {
        Write-Host "    ✗ All download methods failed for $file" -ForegroundColor Red
        Write-Host ""
        Write-Host "Alternative: Download via WSL" -ForegroundColor Yellow
        Write-Host "  Run these commands in WSL (Ubuntu, etc.):" -ForegroundColor Gray
        Write-Host "    curl -k -LO `"$url`"" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Then copy files to: $cacheDir" -ForegroundColor Gray
        $downloadSuccess = $false
        break
    } else {
        $fileInfo = Get-Item $destination
        $sizeKB = [math]::Round($fileInfo.Length / 1KB, 2)
        $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)

        if ($sizeMB -gt 1) {
            Write-Host "    ✓ Downloaded successfully ($sizeMB MB)" -ForegroundColor Gray
        } else {
            Write-Host "    ✓ Downloaded successfully ($sizeKB KB)" -ForegroundColor Gray
        }
    }
}

# Re-enable certificate validation
[System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
Write-Host "  ✓ Certificate validation restored" -ForegroundColor Gray

if (-not $downloadSuccess) {
    Write-Host ""
    Write-Host "Download failed. Cleaning up..." -ForegroundColor Red
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Create cache directory
Write-Host "[4/5] Creating cache directory..." -ForegroundColor Green
try {
    if (Test-Path $cacheDir) {
        Write-Host "  ! Cache directory already exists, removing old files..." -ForegroundColor Yellow
        Remove-Item -Path $cacheDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    Write-Host "  ✓ Cache directory created: $cacheDir" -ForegroundColor Gray
} catch {
    Write-Host "  ✗ Failed to create cache directory: $_" -ForegroundColor Red
    Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    exit 1
}

# Move files to cache directory
Write-Host "[5/5] Moving files to cache..." -ForegroundColor Green
try {
    foreach ($file in $files) {
        $source = Join-Path $tempDir $file
        $destination = Join-Path $cacheDir $file
        Move-Item -Path $source -Destination $destination -Force
        Write-Host "  ✓ $file" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ✗ Failed to move files: $_" -ForegroundColor Red
    exit 1
}

# Cleanup temporary directory
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

# Verify files
Write-Host ""
Write-Host "Verifying cached files..." -ForegroundColor Green
$allFilesPresent = $true
foreach ($file in $files) {
    $filePath = Join-Path $cacheDir $file
    if (Test-Path $filePath) {
        $fileInfo = Get-Item $filePath
        $sizeMB = [math]::Round($fileInfo.Length / 1MB, 2)
        Write-Host "  ✓ $file ($sizeMB MB)" -ForegroundColor Gray
    } else {
        Write-Host "  ✗ $file (missing)" -ForegroundColor Red
        $allFilesPresent = $false
    }
}

Write-Host ""
if ($allFilesPresent) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "SUCCESS! K3s files cached successfully." -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Close Rancher Desktop if it's running"
    Write-Host "  2. Start Rancher Desktop"
    Write-Host "  3. It should now start without downloading k3s"
    Write-Host ""
    Write-Host "Cache location: $cacheDir" -ForegroundColor Gray
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "FAILED! Some files are missing." -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}
