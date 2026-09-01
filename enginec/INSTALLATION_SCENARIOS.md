# EngineC: Installation Scenarios

The EngineC project has **3 separate components** that can be installed independently or together:

## Components Breakdown

| Component | What it is | Where it goes | Required for? |
|-----------|-----------|---------------|---------------|
| **CLI** (`enginec`) | Node.js executable compiler | `~/.local/bin/` or `C:\Program Files\...` | Running `enginec comp <file.ec>` from terminal |
| **VS Code Extension** (`.vsix`) | Editor plugin | VS Code Extensions folder | Syntax highlighting, diagnostics, LSP in VS Code |
| **Compiler Modules** (`*.luau`) | Lexer, Parser, IR Builder, etc. | Bundled with CLI | Internal use by the CLI (automatic) |

---

## Installation Scenarios

### Scenario 1: Full Installation (CLI + VS Code Extension) ⭐ Recommended

**For developers who want everything:**

```bash
# 1. Install the CLI
chmod +x cli/enginec
cp cli/enginec ~/.local/bin/

# 2. Install the VS Code Extension
# Option A: Build from source
cd vscode-extension
npm install
npm run package
# Then open the .vsix file in VS Code → Extensions → Install from VSIX

# Option B: Use pre-built .vsix (if available)
# File → Preferences → Extensions → Install from VSIX → select enginec-*.vsix
```

**What you get:**
- ✅ Terminal: `enginec comp file.ec` works
- ✅ VS Code: Syntax highlighting, real-time diagnostics, error messages
- ✅ Full development experience

---

### Scenario 2: CLI Only

**For terminal-only users (no VS Code editor support):**

```bash
chmod +x cli/enginec
cp cli/enginec ~/.local/bin/
enginec comp myfile.ec
```

**What you get:**
- ✅ Terminal: `enginec comp file.ec` works
- ❌ VS Code: No syntax highlighting or diagnostics (treated as plain text)

---

### Scenario 3: VS Code Extension Only

**For users who want diagnostics in VS Code but don't need CLI:**

```bash
# Open VS Code → Extensions → Install from VSIX → select enginec-*.vsix
```

**What you get:**
- ❌ Terminal: `enginec comp file.ec` won't work (CLI not installed)
- ✅ VS Code: Syntax highlighting, real-time diagnostics
- ⚠️ Warning: Extension will show "EngineC CLI not found" error until you install CLI

**Note:** The extension will try to compile files on-the-fly for diagnostics, but without the CLI installed, it will fail. Install the CLI (Scenario 1 or 2) to get full functionality.

---

## What the .vsix File Contains

The `.vsix` file (Visual Studio Code Extension Package) contains **ONLY**:
- Syntax highlighting grammar
- Language configuration
- Language server protocol (LSP) code
- TypeScript/JavaScript files for the extension

**The .vsix does NOT include:**
- The `enginec` CLI executable
- The Luau compiler modules

---

## What the CLI Contains

The `enginec` CLI executable includes/bundles:
- Node.js script that validates EngineC syntax
- Lua code generator
- File I/O operations
- Error reporting

**The CLI does NOT include:**
- VS Code extension files

---

## Complete Recommendation

For best experience, **do Scenario 1 (Full Installation):**

### macOS/Linux Quick Setup:
```bash
cd enginec/

# Step 1: Install CLI
chmod +x cli/enginec
cp cli/enginec ~/.local/bin/

# Step 2: Install VS Code Extension
cd vscode-extension
npm install
npm run package
# enginec-*.vsix is now in vscode-extension/
# Open in VS Code: Extensions → Install from VSIX → select it
```

### Windows Quick Setup:
```batch
REM Step 1: Create the batch wrapper (see cli/enginec.bat)
REM Copy cli/enginec.bat and cli/enginec to C:\EngineC\bin\
REM Add C:\EngineC\bin\ to PATH

REM Step 2: Build and install the VS Code extension
cd vscode-extension
npm install
npm run package
REM Then open enginec-*.vsix in VS Code via Extensions → Install from VSIX
```

---

## Troubleshooting

**Q: I installed the .vsix but VS Code still shows "EngineC CLI not found"**
- A: You also need to install the CLI. Follow Scenario 1, Step 1.

**Q: I installed the CLI but syntax highlighting doesn't work**
- A: You also need to install the .vsix extension. Follow Scenario 1, Step 2.

**Q: Where do I get the .vsix file?**
- A: Build it from source:
  ```bash
  cd vscode-extension
  npm install
  npm run package
  ```
  The `.vsix` file appears in the `vscode-extension/` folder.

**Q: Can I use this without VS Code?**
- A: Yes! Just install the CLI (Scenario 2). You can compile files from any terminal.

**Q: Do I need the Luau compiler files?**
- A: No, they're bundled into the CLI already. You don't need to do anything special with them.
