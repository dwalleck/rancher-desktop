# Rancher Desktop K3s Diagnostics Script
# Checks why k3s isn't starting

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Rancher Desktop K3s Diagnostics" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if WSL distro exists
Write-Host "[1] Checking WSL distro..." -ForegroundColor Green
$distros = wsl --list --verbose
if ($distros -match "rancher-desktop") {
    Write-Host "  ✓ rancher-desktop distro found" -ForegroundColor Gray
} else {
    Write-Host "  ✗ rancher-desktop distro NOT found" -ForegroundColor Red
    Write-Host "    Rancher Desktop may not have initialized properly" -ForegroundColor Yellow
    exit 1
}

# Check if distro is running
if ($distros -match "rancher-desktop.*Running") {
    Write-Host "  ✓ rancher-desktop is running" -ForegroundColor Gray
} else {
    Write-Host "  ✗ rancher-desktop is NOT running" -ForegroundColor Red
    Write-Host "    The WSL VM failed to start" -ForegroundColor Yellow
}

Write-Host ""

# Check k3s service status
Write-Host "[2] Checking k3s service status..." -ForegroundColor Green
try {
    $k3sStatus = wsl -d rancher-desktop --exec rc-service k3s status 2>&1
    Write-Host "  k3s service: $k3sStatus" -ForegroundColor Gray
} catch {
    Write-Host "  ✗ Could not check k3s status: $_" -ForegroundColor Red
}

Write-Host ""

# Check if k3s process is running
Write-Host "[3] Checking k3s process..." -ForegroundColor Green
try {
    $k3sProc = wsl -d rancher-desktop --exec pgrep -a k3s 2>&1
    if ($k3sProc) {
        Write-Host "  ✓ k3s process found:" -ForegroundColor Gray
        Write-Host "    $k3sProc" -ForegroundColor DarkGray
    } else {
        Write-Host "  ✗ k3s process NOT running" -ForegroundColor Red
    }
} catch {
    Write-Host "  ✗ Error checking process: $_" -ForegroundColor Red
}

Write-Host ""

# Check k3s logs (last 30 lines)
Write-Host "[4] Recent k3s logs (last 30 lines)..." -ForegroundColor Green
try {
    $logs = wsl -d rancher-desktop --exec tail -30 /var/log/k3s.log 2>&1
    if ($logs) {
        Write-Host $logs -ForegroundColor DarkGray
    } else {
        Write-Host "  ! No k3s logs found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ! Could not read k3s logs: $_" -ForegroundColor Yellow
}

Write-Host ""

# Check for common errors
Write-Host "[5] Checking for common errors..." -ForegroundColor Green
try {
    $errors = wsl -d rancher-desktop --exec grep -i "error\|fail\|fatal" /var/log/k3s.log 2>&1 | Select-Object -Last 10
    if ($errors) {
        Write-Host "  Recent errors found:" -ForegroundColor Yellow
        Write-Host $errors -ForegroundColor Red
    } else {
        Write-Host "  ✓ No obvious errors in logs" -ForegroundColor Gray
    }
} catch {
    Write-Host "  ! Could not search logs: $_" -ForegroundColor Yellow
}

Write-Host ""

# Check kubectl connectivity
Write-Host "[6] Testing kubectl connectivity..." -ForegroundColor Green
try {
    $kubectl = wsl -d rancher-desktop --exec kubectl get nodes 2>&1
    if ($kubectl -match "Ready") {
        Write-Host "  ✓ kubectl can connect to API server!" -ForegroundColor Green
        Write-Host $kubectl -ForegroundColor Gray
    } else {
        Write-Host "  ✗ kubectl cannot connect:" -ForegroundColor Red
        Write-Host $kubectl -ForegroundColor DarkGray
    }
} catch {
    Write-Host "  ✗ kubectl test failed: $_" -ForegroundColor Red
}

Write-Host ""

# Check Rancher Desktop logs
Write-Host "[7] Checking Rancher Desktop background.log..." -ForegroundColor Green
$logPath = "$env:LOCALAPPDATA\rancher-desktop\logs\background.log"
if (Test-Path $logPath) {
    Write-Host "  Log location: $logPath" -ForegroundColor Gray
    Write-Host "  Last 20 lines:" -ForegroundColor Gray
    Get-Content $logPath -Tail 20 | ForEach-Object {
        if ($_ -match "error|fail|fatal") {
            Write-Host "    $_" -ForegroundColor Red
        } else {
            Write-Host "    $_" -ForegroundColor DarkGray
        }
    }
} else {
    Write-Host "  ! Log file not found at $logPath" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Diagnostics Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Common Issues:" -ForegroundColor Yellow
Write-Host "  - Port 6443 conflict: Another k8s cluster using the same port" -ForegroundColor Gray
Write-Host "  - Certificate errors: Check k3s logs for SSL/TLS errors" -ForegroundColor Gray
Write-Host "  - Checksum failure: Cached k3s files may be corrupted" -ForegroundColor Gray
Write-Host "  - Resource limits: Not enough memory/CPU allocated" -ForegroundColor Gray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Check the errors above" -ForegroundColor Gray
Write-Host "  2. Look at background.log for more details" -ForegroundColor Gray
Write-Host "  3. Try: wsl -d rancher-desktop --exec rc-service k3s restart" -ForegroundColor Gray
Write-Host "  4. If all else fails, restart Rancher Desktop completely" -ForegroundColor Gray
