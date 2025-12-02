# Rancher Desktop: IT Network Requirements Summary

## Executive Summary

Rancher Desktop is a Kubernetes development tool that fails to start in environments with SSL inspection proxies (like iboss, Zscaler, BlueCoat). The application downloads critical components during startup, and SSL inspection causes certificate validation failures that present as misleading "no network connection" errors.

## Root Cause

Rancher Desktop uses Electron's Chromium network stack, which doesn't trust corporate-reissued SSL certificates even when properly installed in Windows certificate stores. This is an architectural limitation shared by other Electron-based tools (VS Code, GitHub Desktop).

## Required Network Access

Based on [official documentation](https://docs.rancherdesktop.io/getting-started/installation#proxy-environments-important-url-patterns), the following domains require **both URL filtering allowlist AND SSL inspection bypass**:

| Domain | Purpose |
|--------|---------|
| `api.github.com` | Query available K3s Kubernetes releases |
| `github.com` | Download K3s binaries and container images |
| `*.githubusercontent.com` | GitHub raw content / release assets |
| `storage.googleapis.com` | Download kubectl CLI via kuberlr |
| `desktop.version.rancher.io` | Application upgrade checks |
| `docs.rancherdesktop.io` | Documentation and online status verification |

## Recommended IT Configuration

**Application**: `Rancher Desktop.exe` (Windows) / `Rancher Desktop.app` (macOS)

**Configuration Type**: SSL Inspection Bypass (not just URL filtering)

**Scope**: Granular bypass - specific executable + specific domains only

## Security Considerations

- **Minimal scope**: Only affects Rancher Desktop process, not browser or other apps
- **Domain-limited**: Bypass only applies to listed development infrastructure domains
- **Precedent**: Docker Desktop typically requires similar configuration
- **Alternative is worse**: Without bypass, users must disable certificate validation entirely via scripts

## Current Workaround (Without IT Changes)

Users can manually populate the k3s cache using scripts that bypass certificate validation. This requires re-running whenever Rancher Desktop updates its Kubernetes version (approximately monthly).

## Recommendation

Request IT to configure SSL inspection bypass for the domains listed above, scoped to the Rancher Desktop executable. This is a one-time configuration that eliminates ongoing workarounds and is consistent with how similar tools (Docker Desktop) are typically configured in enterprise environments.

---

**Reference**: See `rancher-desktop-certificate-investigation.md` for detailed technical analysis.

**Official Documentation**: https://docs.rancherdesktop.io/getting-started/installation#proxy-environments-important-url-patterns
