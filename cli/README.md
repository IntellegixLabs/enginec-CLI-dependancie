# EngineC CLI

Node.js command-line interface for the EngineC compiler.

## What This Is

The CLI is **NOT** the VS Code extension. This is the **terminal command** for compiling `.ec` files.

- **CLI** (this): Runs in your terminal/command line
- **VS Code Extension** (`.vsix`): Installs in VS Code for syntax highlighting and diagnostics

You can use either one independently, or both together for full functionality.

See [../INSTALLATION_SCENARIOS.md](../INSTALLATION_SCENARIOS.md) to understand what you need.

## Installation

**See [../INSTALL.md](../INSTALL.md) for detailed platform-specific instructions, including:**
- macOS/Linux installation (`~/.local/bin` or `/usr/local/bin`)
- Windows batch wrapper setup
- WSL (Windows Subsystem for Linux) option
- Troubleshooting guide

### Quick Install (macOS/Linux)

```bash
chmod +x enginec
cp enginec ~/.local/bin/enginec
# Add ~/.local/bin to PATH if needed
export PATH="$HOME/.local/bin:$PATH"
enginec --help
```

### Quick Install (Windows)

Create `enginec.bat` in a PATH directory with:
```batch
@echo off
node "%~dp0enginec.js" %*
```

Then copy the enginec script as `enginec.js` in the same directory.

## Usage

### Compile a file

```bash
enginec comp <file.ec>
```

This will:
1. Parse and validate the `.ec` file
2. Perform syntax checks
3. Generate corresponding `.lua` file in the same directory
4. Print `Compilation successful` on success

### Output

On success:
```
Compilation successful
/path/to/generated/file.lua
```

On error:
```
/path/to/file.ec:1:1: error: unexpected token near "..."
```

## Environment Variables

- `ENGINEC_BIN` - Path to the enginec CLI (defaults to `/Users/heylinchoi/.local/bin/enginec`)
- `PATH` - Must include the enginec CLI location

## How It Works

The CLI:
1. Validates EngineC syntax against the language spec
2. Parses the input `.ec` file
3. Converts valid EngineC code to Lua
4. Writes the generated Lua file alongside the source

The generated Lua preserves the semantics of the EngineC source while using standard Lua syntax.
