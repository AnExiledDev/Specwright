# Specwright Marketplace

Claude Code plugin marketplace for Specwright workflow automation.

## Installation

```bash
# Add the marketplace
/plugin marketplace add AnExiledDev/Specwright

# Install the plugin
/plugin install specwright
```

## Available Plugins

- **specwright** - Spec-driven development automation with phased implementation, parallel execution, and verification loops.

## Structure

```
specwright-marketplace/
├── .claude-plugin/
│   └── marketplace.json
└── plugins/
    └── specwright/
        ├── .claude-plugin/
        │   └── plugin.json
        ├── commands/
        ├── agents/
        └── skills/
```

## License

MIT - See LICENSE file.
