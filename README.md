# Xaiontz Plugins

Internal Cursor plugin marketplace for the Xaiontz team. Developer tools, framework rules, MCP integrations, and agent skills packaged as installable plugins.

## Plugins

| Plugin | Category | Description |
|:-------|:---------|:------------|
| [SME Stack](sme-stack) | Developer Tools | Scaffold and develop Next.js + Drizzle + Auth.js + shadcn applications with multi-area auth (public site, client portal, internal tools) |

## Repository structure

This is a multi-plugin marketplace repository. The root `.cursor-plugin/marketplace.json` lists all plugins, and each plugin lives in its own directory with a dedicated manifest.

```
xaiontz-plugins/
├── .cursor-plugin/
│   └── marketplace.json       # Marketplace manifest (lists all plugins)
├── plugin-name/
│   ├── .cursor-plugin/
│   │   └── plugin.json        # Per-plugin manifest
│   ├── skills/                # Agent skills (SKILL.md with frontmatter)
│   ├── rules/                 # Cursor rules (.mdc files)
│   ├── commands/              # Slash commands
│   ├── README.md
│   ├── CHANGELOG.md
│   └── LICENSE
└── ...
```

## Adding a new plugin

1. Run the **Create Plugin** scaffold skill, or manually create a directory at the repo root.
2. Add a `.cursor-plugin/plugin.json` manifest inside the new directory.
3. Register the plugin in `.cursor-plugin/marketplace.json` under the `plugins` array.
4. Include a `README.md` with installation instructions, component tables, and a typical usage flow.

## Installation

Run the install script from the repo root to copy plugins into Cursor's local plugin directory:

```powershell
# Install all plugins
.\install.ps1

# Install a specific plugin
.\install.ps1 -Plugins sme-stack

# Overwrite existing installs without prompting
.\install.ps1 -Force
```

Restart Cursor after installing to pick up changes.

## License

MIT
