# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Rancher Desktop is an Electron-based desktop application for running Kubernetes and container management on Windows, macOS, and Linux. The project is primarily written in TypeScript with Go components for CLI tools and platform-specific helpers.

## Architecture

### Multi-Process Electron Architecture

- **Main Process** (`background.ts`): Manages the application lifecycle, native OS interactions, and spawns/coordinates backend processes
- **Renderer Process** (Vue.js app in `pkg/rancher-desktop/`): User interface built with Vue 3, Vuex for state management
- **Backend Processes**: Platform-specific VM backends for running containers and Kubernetes

### Platform-Specific Backends

The application uses different backend implementations based on the OS (factory pattern in `pkg/rancher-desktop/backend/factory.ts`):

- **Linux/macOS**: `LimaBackend` - Uses Lima VM with QEMU for container runtime
- **Windows**: `WSLBackend` - Uses Windows Subsystem for Linux (WSL2)
- **Mock**: `MockBackend` - Used for testing/screenshots (set `RD_MOCK_BACKEND=1`)

Backend implementations are in:
- `pkg/rancher-desktop/backend/lima.ts` - Lima backend
- `pkg/rancher-desktop/backend/wsl.ts` - WSL backend
- `pkg/rancher-desktop/backend/kube/` - Kubernetes management per backend

### Container Engines

Two container engines are supported:
- **containerd** via `nerdctl` - Default, lightweight
- **dockerd (moby)** - Docker compatibility

Image processing abstracted through:
- `pkg/rancher-desktop/backend/images/imageProcessor.ts` - Base interface
- `pkg/rancher-desktop/backend/images/nerdctlImageProcessor.ts` - containerd implementation
- `pkg/rancher-desktop/backend/images/mobyImageProcessor.ts` - Docker implementation

### Go Components

Go code lives in `src/go/` with separate modules:

- **rdctl** (`src/go/rdctl/`): CLI tool for controlling Rancher Desktop via HTTP API
- **wsl-helper**: Windows-specific WSL integration utilities
- **nerdctl-stub**: Stub for nerdctl on Windows
- **guestagent**: Runs inside the VM for host-guest communication
- **networking**: Network configuration helpers
- **extension-proxy**: Docker extension support

Each Go module has its own `go.mod` and can be tested independently.

## Development Commands

### Setup
```bash
yarn                      # Install dependencies (runs postinstall automatically)
```

### Running Development Build
```bash
yarn dev                  # Run in development mode with hot reload
```

### Building
```bash
yarn build                # Build TypeScript/Vue without packaging
yarn package              # Create distributable packages in dist/
```

### Testing

#### Unit Tests
```bash
yarn test                 # Run all tests (lint + unit tests)
yarn test:unit            # Run all unit tests (Jest + Go tests)
yarn test:unit:jest       # Run Jest tests only
yarn test:unit:rdctl      # Run rdctl Go tests
yarn test:unit:wsl-helper # Run wsl-helper Go tests
yarn test:unit:watch      # Run Jest in watch mode
```

#### E2E Tests
```bash
yarn test:e2e             # Run Playwright e2e tests
```

E2E tests are in `e2e/` and use Playwright. Test failure logs/traces are uploaded as GitHub artifacts.

#### BATS Tests
```bash
cd bats
./bats-core/bin/bats tests/registry/creds.bats  # Run specific test
./bats-core/bin/bats tests/*/                    # Run all tests
```

BATS tests are shell-based integration tests. Must run `git submodule update --init` first. On Windows, run from within WSL.

### Linting
```bash
yarn lint                 # Fix TypeScript, Go, and spelling issues
yarn lint:nofix           # Check without fixing
yarn lint:typescript:fix  # Fix TypeScript/ESLint issues only
yarn lint:go:fix          # Fix Go linting issues only
```

Go linting uses `.golangci.yaml` configuration.

### Running Single Go Test
```bash
cd src/go/rdctl
go test ./...                    # All tests in module
go test -run TestSpecificName    # Specific test
```

## API Architecture

Rancher Desktop exposes an HTTP API for `rdctl` and other tools:

- **API Spec**: `pkg/rancher-desktop/assets/specs/command-api.yaml` (OpenAPI)
- **Server**: `pkg/rancher-desktop/main/commandServer/httpCommandServer.ts`
- **Client**: `src/go/rdctl/` - Go CLI that calls the API

The API is currently v1 but still considered experimental and subject to change.

## Key Directories

```
├── background.ts                    # Main process entry point
├── pkg/rancher-desktop/
│   ├── backend/                     # Backend VM implementations
│   │   ├── factory.ts               # Platform detection and backend creation
│   │   ├── lima.ts, wsl.ts, mock.ts # Backend implementations
│   │   ├── kube/                    # Kubernetes management
│   │   ├── images/                  # Image handling (nerdctl/moby)
│   │   └── containerClient/         # Container client abstractions
│   ├── main/                        # Main process modules
│   │   ├── commandServer/           # HTTP API server (rdctl)
│   │   ├── extensions/              # Docker extension support
│   │   ├── diagnostics/             # Diagnostic data collection
│   │   └── snapshots/               # VM snapshot management
│   ├── pages/                       # Vue pages/views
│   ├── components/                  # Vue components
│   ├── store/                       # Vuex store modules
│   └── utils/                       # Shared utilities
├── src/go/                          # Go components (separate modules)
│   ├── rdctl/                       # CLI tool
│   ├── wsl-helper/                  # WSL integration
│   ├── guestagent/                  # VM guest agent
│   └── nerdctl-stub/                # Windows nerdctl stub
├── e2e/                             # Playwright E2E tests
├── bats/                            # Shell-based integration tests
└── scripts/                         # Build and development scripts
```

## Important Notes

### Path Imports
Use `@pkg/*` alias to import from `pkg/rancher-desktop/*`:
```typescript
import { Settings } from '@pkg/config/settings';
import K8s from '@pkg/backend/k8s';
```

### TypeScript Execution
Scripts in `scripts/` are TypeScript but run via `scripts/ts-wrapper.js`:
```bash
node scripts/ts-wrapper.js scripts/build.ts
```

### Go Module Structure
Go code uses a workspace (`go.work`) with multiple modules. When working on Go code, `cd` into the specific module directory first.

### Windows Line Endings
Must configure git to use LF on Windows:
```bash
git config --global core.autocrlf false
git config --global core.eol lf
```

### Commits Must Be Signed
All commits require `Signed-off-by:` line (DCO). Use `git commit -s`.

### Platform-Specific Code
Check `os.platform()` for platform detection. Common patterns:
- `darwin` = macOS
- `linux` = Linux
- `win32` = Windows

Use backend factory for VM-specific logic rather than platform checks when possible.

### M1 Mac Development
On Apple Silicon Macs, set `M1=1` before running yarn:
```bash
export M1=1
yarn
```

## Testing Guidelines

- E2E test failures: Download `failure-reports.zip` from GitHub Actions for logs and Playwright traces
- Playwright traces can be viewed at https://trace.playwright.dev/
- BATS tests must be run with Rancher Desktop installed or built (`dist/`)
- Set `RD_LOCATION=dist` or `RD_LOCATION=dev` to control which build BATS tests use
