# EngineC VS Code Extension

VS Code language extension and Language Server for EngineC (`.ec`) files.

## What This Is

This extension provides **VS Code editor features only**:
- ✅ Syntax highlighting for `.ec` files
- ✅ Real-time error diagnostics in the editor
- ✅ Go-to-definition support
- ✅ Symbol completion
- ✅ Error messages inline

This extension is **NOT** the CLI. To actually compile files from the terminal, you need the CLI installed separately.

See [../INSTALLATION_SCENARIOS.md](../INSTALLATION_SCENARIOS.md) for the difference.

## Installation

### Build the Extension

```bash
npm install
npm run compile
npm run package
```

This creates `enginec-*.vsix` in this folder.

### Install in VS Code

1. Open VS Code
2. Go to Extensions panel (Cmd+Shift+X or Ctrl+Shift+X)
3. Click "Install from VSIX..."
4. Select the `enginec-*.vsix` file

### Development Mode

To test while developing:

```bash
npm install
npm run compile
# Press F5 to launch the Extension Development Host
```

## Requirements

⚠️ **Important:** This extension requires the `enginec` CLI to be installed and in your PATH.

The extension calls `enginec comp <file>` to get diagnostics. Without the CLI:
- You'll see "EngineC CLI not found" warnings
- Real-time diagnostics won't work

**To install the CLI:** See [../cli/README.md](../cli/README.md) or [../INSTALL.md](../INSTALL.md)

## Features

### Syntax Highlighting

- Keywords: `class`, `public`, `function`, `if`, `else`, `for`, `return`, etc.
- Types: `int`, `float`, `bool`, `string`, `array`, `object`, etc.
- Comments: `//` line comments and `/* */` block comments
- Strings with escape sequences

### Diagnostics

Real-time compilation errors displayed inline:
- Hover over red squiggles to see error messages
- Errors include file, line, and column information

### Language Features (MVP)

- Symbol detection for workspace completion
- Basic type awareness
- File association for `.ec` extension

## Development Notes

- The language server is in `server/src/server.ts`
- Syntax grammar is in `syntaxes/ec.tmLanguage.json` (TextMate format)
- Configuration is in `language-configuration.json`
- Main extension entry point is `src/extension.ts`

### How Diagnostics Work

1. When you save an `.ec` file, the extension runs `enginec comp <file>`
2. The language server parses the compiler output
3. Errors are displayed as red squiggles in the editor

### Adding Features

To add more features:
1. Update `server/src/server.ts` with LSP handlers
2. Compile: `npm run compile`
3. Test in Extension Development Host (F5)
4. Build release: `npm run package`

## Troubleshooting

**"EngineC CLI not found"**
- The extension couldn't find `enginec` in your PATH
- Install the CLI: [../INSTALL.md](../INSTALL.md)
- Ensure `enginec --help` works in your terminal
- Reload VS Code (Cmd+Shift+P → Reload Window)

**No syntax highlighting**
- Grammar file may not be loading
- Try: F1 → "Change Language Mode" → select "EngineC"
- Reload VS Code

**Diagnostics not appearing**
- Ensure CLI is installed and in PATH
- Save the file (Cmd+S)
- Check Output panel (View → Output → EngineC Language Server)

## Quick Start (Full Setup)

```bash
# 1. Install CLI (if not already)
cd ../cli
chmod +x enginec
cp enginec ~/.local/bin/

# 2. Build extension
cd ../vscode-extension
npm install
npm run compile
npm run package

# 3. Install .vsix in VS Code
# Extensions → Install from VSIX → enginec-*.vsix
```

Then create a test file `example.ec` and start editing!

