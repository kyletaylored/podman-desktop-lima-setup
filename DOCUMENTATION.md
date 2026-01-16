# Documentation Index

All documentation has been organized in the [`docs/`](docs/) directory.

## Quick Links

### Getting Started
- [**README**](README.md) - Main documentation and setup guide
- [**Quick Reference**](docs/QUICK_REFERENCE.md) - Command cheat sheet
- [**Examples**](docs/EXAMPLES.md) - Usage examples for common scenarios

### Setup & Publishing
- [**Next Steps**](docs/NEXT_STEPS.md) - Publishing checklist for GitHub
- [**GitHub Pages Setup**](docs/GITHUB_PAGES_SETUP.md) - How to deploy to GitHub Pages

### Advanced Topics
- [**Podman Desktop Integration**](docs/PODMAN_DESKTOP_INTEGRATION.md) - How CLI and GUI work together
- [**Lima Customization**](docs/PODMAN_LIMA_CUSTOMIZE.md) - Advanced VM configuration
- [**Lima Setup Reference**](docs/PODMAN_LIMA_SETUP.md) - Official Podman Desktop docs

### Reference Files
- [**Settings Example**](docs/settings.json) - Sample Podman Desktop settings

## File Structure

```
.
├── README.md                  # Main documentation
├── setup-podman-lima.sh       # Setup script
├── docs/                      # All documentation files
│   ├── EXAMPLES.md
│   ├── GITHUB_PAGES_SETUP.md
│   ├── NEXT_STEPS.md
│   ├── PODMAN_DESKTOP_INTEGRATION.md
│   ├── PODMAN_LIMA_CUSTOMIZE.md
│   ├── PODMAN_LIMA_SETUP.md
│   ├── QUICK_REFERENCE.md
│   └── settings.json
├── _config.yml                # Jekyll configuration
└── .github/
    └── workflows/
        └── pages.yml          # GitHub Pages deployment
```
