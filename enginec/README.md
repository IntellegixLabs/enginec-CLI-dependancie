# EngineC

A modern programming language compiler toolchain with a Node.js CLI, VS Code extension, and Luau compiler backend. EngineC transpiles `.ec` source files to Lua, providing a type-aware, developer-friendly syntax for Roblox and general Lua development.

---

## 🎯 Overview

EngineC is a complete compiler suite consisting of three main components:

1. **CLI** (`enginec`) — Command-line compiler for transpiling `.ec` → `.lua`
2. **VS Code Extension** — Language support with syntax highlighting, diagnostics, and LSP
3. **Compiler Modules** — Lexer, parser, IR builder, optimizer, and code generator

You can use each component independently, or combine them for a full integrated development experience.

---

## ✨ Features

### Language Support
- **Type System**: `int`, `float`, `double`, `bool`, `string`, `void`, `array`, `object`, `vector`, `maybe`
- **OOP**: Classes, namespaces, static classes, enums, plugins
- **Functions**: Public/private methods, multi-argument signatures
- **Control Flow**: `if/else`, `for`, `while`, `switch/case`, `try/catch`
- **Modern Syntax**: Include directives, type annotations, property declarations
- **Optimization**: IR-based optimizer removes redundant operations

### CLI Features
- ✅ Fast compilation to Lua
- ✅ Detailed error messages with line/column information
- ✅ Generated `.lua` files in the same directory as source
- ✅ Support for including external modules
- ✅ Works on macOS, Linux, and Windows

### VS Code Extension Features
- ✅ Real-time syntax highlighting
- ✅ Live compilation diagnostics (on-save)
- ✅ Go-to-definition support
- ✅ Symbol completion and workspace scanning
- ✅ Integrated language server protocol (LSP)
- ✅ Error squiggles with hover tooltips

---

## 🚀 Quick Start

### Installation Options

Choose based on what you need:

| Use Case | Install | Command |
|----------|---------|---------|
| 🖥️ Terminal only (no editor) | CLI only | `enginec comp file.ec` |
| 📝 VS Code editor only | Extension only | Get syntax highlighting, see errors |
| 🎯 Full experience (Recommended) | CLI + Extension | Both terminal AND VS Code |

### Option 1: Full Installation (CLI + VS Code Extension) ⭐ Recommended

#### macOS/Linux

```bash
# 1. Clone the repo
git clone https://github.com/yourusername/enginec.git
cd enginec

# 2. Install CLI globally
chmod +x cli/enginec
cp cli/enginec ~/.local/bin/
# Or: sudo cp cli/enginec /usr/local/bin/

# 3. Verify CLI works
enginec --help

# 4. Build and install VS Code Extension
cd vscode-extension
npm install
npm run compile
npm run package

# 5. Install .vsix in VS Code
# Open VS Code → Extensions → Install from VSIX → select enginec-*.vsix
```

#### Windows

```batch
REM 1. Clone the repo
git clone https://github.com/yourusername/enginec.git
cd enginec

REM 2. Create CLI wrapper (see cli/enginec.bat)
REM Copy cli/enginec.bat and cli/enginec to a PATH folder
REM For example: C:\EngineC\bin\

REM 3. Add to PATH
REM Right-click This PC → Properties → Advanced system settings
REM Environment Variables → PATH → Add C:\EngineC\bin\

REM 4. Verify CLI works (in new terminal)
enginec --help

REM 5. Build and install VS Code Extension
cd vscode-extension
npm install
npm run compile
npm run package

REM Then open enginec-*.vsix in VS Code: Extensions → Install from VSIX
```

### Option 2: CLI Only (Terminal Users)

```bash
# macOS/Linux
chmod +x cli/enginec
cp cli/enginec ~/.local/bin/  # or /usr/local/bin

# Windows: See cli/enginec.bat for batch wrapper setup

# Then use from terminal:
enginec comp myfile.ec
```

### Option 3: VS Code Extension Only

```bash
# Open VS Code
# Extensions → Install from VSIX → select vscode-extension/enginec-*.vsix

# ⚠️ Note: Extension will show "CLI not found" until you install the CLI (Option 1 or 2)
```

---

## 📖 Usage

### CLI

#### Compile a file

```bash
enginec comp myfile.ec
```

**Output on success:**
```
Compilation successful
/path/to/myfile.lua
```

The generated `.lua` file is created in the same directory as the source file.

**Output on error:**
```
/path/to/myfile.ec:1:5: error: unexpected token near "invalid"
```

#### Example EngineC file (`example.ec`)

```enginec
#include Engine

class PlayerRig
  var health: int = 100
end

public function run()
  var speed: int = 30
  var ratio: float = 0.5
  var enabled: bool = true
  var title: string = "Runner"
  return speed
end
```

#### Generated Lua output (`example.lua`)

```lua
local PlayerRig = {}
local health = 100
function run()
  local speed = 30
  local ratio = 0.5
  local enabled = true
  local title = "Runner"
  return speed
end
```

### VS Code Extension

1. **Open an `.ec` file** in VS Code
2. **Syntax highlighting** is applied automatically
3. **Save the file** (Cmd+S) to trigger compilation
4. **Errors appear as red squiggles** — hover to see details
5. **Hover diagnostics** show line/column and error message

---

## 📁 Project Structure

```
enginec/
├── README.md                           # This file
├── INSTALL.md                          # Platform-specific installation guide
├── INSTALLATION_SCENARIOS.md           # Detailed scenario breakdown
├── package.json                        # Root workspace config
├── .gitignore
│
├── cli/                                # Command-line compiler
│   ├── enginec                        # Main executable (Node.js script)
│   ├── enginec.bat                    # Windows batch wrapper
│   └── README.md                      # CLI-specific docs
│
├── compiler/                           # Luau compiler modules
│   ├── Lexer.luau                     # Tokenization
│   ├── Parser.luau                    # Syntax tree builder
│   ├── IRBuilder.luau                 # Intermediate representation
│   ├── Optimizer.luau                 # IR optimization passes
│   ├── CodeGen.luau                   # Lua code generation
│   ├── Runtime.luau                   # Runtime semantics
│   ├── Compiler.luau                  # Main compiler pipeline
│   ├── Spec.luau                      # Language specification
│   └── init.luau                      # Module initialization
│
├── vscode-extension/                   # VS Code extension
│   ├── package.json
│   ├── tsconfig.json
│   ├── language-configuration.json    # Editor behavior config
│   ├── src/
│   │   └── extension.ts               # Main extension entry point
│   ├── server/
│   │   └── src/
│   │       └── server.ts              # Language server implementation
│   ├── syntaxes/
│   │   └── ec.tmLanguage.json        # TextMate grammar
│   └── README.md                      # Extension-specific docs
│
└── examples/                           # Sample .ec files
    └── example.ec
```

---

## 🏗️ Architecture

### Compilation Pipeline

```
Source (.ec)
    ↓
┌───────────────────────────────────────────┐
│  Lexer → Parser → IRBuilder → Optimizer   │
│                                            │
│         (Luau Compiler Modules)           │
└───────────────────────────────────────────┘
    ↓
CodeGen
    ↓
Lua Output (.lua)
```

### CLI Execution Flow

```
User Terminal
    ↓
enginec comp <file.ec>
    ↓
Node.js CLI Script
    ├─ Validates EngineC syntax
    ├─ Runs compiler pipeline
    ├─ Generates Lua code
    └─ Writes .lua file
    ↓
Success/Error Output
```

### VS Code Extension Flow

```
User edits .ec file in VS Code
    ↓
Extension detects save event
    ↓
Language Server spawns: enginec comp <file>
    ↓
Parse compiler output for diagnostics
    ↓
Display errors as squiggles in editor
```

---

## 🛠️ Development

### Building the CLI

The CLI is a single Node.js script. No build step required—edit `cli/enginec` directly.

To test changes:
```bash
./cli/enginec comp examples/example.ec
```

### Building the VS Code Extension

```bash
cd vscode-extension

# Install dependencies
npm install

# Compile TypeScript
npm run compile

# Watch for changes (recommended during development)
npm run watch

# Package as .vsix
npm run package

# Run in Extension Development Host (F5 in VS Code)
```

### Testing

```bash
# From vscode-extension directory
npm test
```

Or manually:
1. Open the `vscode-extension` folder in VS Code
2. Press `F5` to launch Extension Development Host
3. Create/open a `.ec` file to test

### Adding Features

#### Add CLI Feature
- Edit `cli/enginec`
- Add validation or transpilation logic
- Test: `./cli/enginec comp test.ec`
- Commit

#### Add VS Code Feature
- Edit `server/src/server.ts` for LSP handlers
- Edit `src/extension.ts` for extension lifecycle
- Run `npm run compile`
- Test with F5 (Extension Development Host)
- Package: `npm run package`

#### Update Syntax Grammar
- Edit `syntaxes/ec.tmLanguage.json`
- Use [TextMate grammar syntax](https://macromates.com/manual/en/language_grammars)
- Reload VS Code Extension Development Host to see changes

---

## 📚 Documentation

For detailed information, see:

- **[INSTALL.md](INSTALL.md)** — Platform-specific installation (macOS/Linux/Windows, with troubleshooting)
- **[INSTALLATION_SCENARIOS.md](INSTALLATION_SCENARIOS.md)** — Understand which components you need
- **[cli/README.md](cli/README.md)** — CLI-specific documentation
- **[PACKAGE_MANAGERS.md](PACKAGE_MANAGERS.md)** — Publish to Homebrew, Chocolatey, Scoop, AUR, PPA, etc.
- **[vscode-extension/README.md](vscode-extension/README.md)** — Extension development and usage

---

## ❓ FAQ

### Q: What's the difference between the CLI and the extension?

**CLI** (`enginec`):
- Runs in your terminal
- Compiles `.ec` → `.lua` files
- Used in build scripts or CI/CD

**Extension** (`.vsix`):
- Runs inside VS Code
- Provides syntax highlighting
- Shows live diagnostics in the editor
- Requires CLI to be installed to work

**You need both for the full experience.**

### Q: Can I use just the CLI without VS Code?

**Yes!** Install the CLI only (Option 2). You can compile files from any terminal.

### Q: Can I use the extension without the CLI?

**Technically yes, but it won't be useful.** The extension will show syntax highlighting but no diagnostics. To see errors, you need the CLI installed.

### Q: Where do I put my `.ec` files?

Anywhere! The CLI works with `.ec` files in any directory:

```bash
enginec comp ~/projects/myfile.ec
enginec comp ./src/game/player.ec
enginec comp ../other/module.ec
```

### Q: How do I include external EngineC modules?

Use the `#include` directive:

```enginec
#include Engine
#include MyLibrary
```

The compiler searches the project root and common dependency folders.

### Q: Can I use this for non-Roblox Lua?

**Yes!** EngineC compiles to standard Lua. You can use the generated `.lua` files in any Lua runtime.

### Q: How do I report bugs or request features?

- **Bug report**: Open an issue with reproduction steps
- **Feature request**: Open an issue with use case and motivation
- **Contribution**: See [Contributing](#-contributing) section

### Q: Is EngineC production-ready?

EngineC is actively developed. The compiler and CLI are stable, but features and language syntax may change. Use with caution in production workflows.

### Q: How do I uninstall?

**CLI (macOS/Linux):**
```bash
rm ~/.local/bin/enginec
# or
sudo rm /usr/local/bin/enginec
```

**Extension:**
- VS Code Extensions panel → EngineC → Uninstall

---

## 🐛 Troubleshooting

### CLI not found in terminal

**macOS/Linux:**
```bash
# Verify installation
which enginec

# If empty, check PATH
echo $PATH

# Ensure ~/.local/bin is in PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

**Windows:**
```batch
where enginec

REM If not found, verify enginec.bat is in a PATH directory
REM Then restart your terminal
```

### VS Code: "EngineC CLI not found"

- Install the CLI (see Quick Start, Option 1)
- Ensure `enginec --help` works in your terminal
- Reload VS Code: Cmd+Shift+P → "Reload Window"

### Compilation errors

Check the error message:
```
/path/to/file.ec:1:5: error: unexpected token near "invalid"
```

- **Line number**: 1
- **Column number**: 5
- **Message**: "unexpected token near 'invalid'"

### Generated Lua looks wrong

The transpiler is intentionally simple for the MVP. Complex language constructs may not translate perfectly. Consider:

1. Check if the EngineC syntax is valid
2. Open an issue with a code example
3. Contribute an improved transpiler!

---

## 🤝 Contributing

Contributions are welcome! To contribute:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/my-feature`)
3. **Make your changes** and test thoroughly
4. **Commit with clear messages** (`git commit -m "Add feature: ..."`)
5. **Push to your fork** (`git push origin feature/my-feature`)
6. **Open a Pull Request** with a description

### Areas for contribution:
- 🎨 Improved syntax grammar
- 🚀 Better transpilation logic
- 📖 Documentation improvements
- 🐛 Bug fixes
- ✨ New language features
- 🧪 Additional test cases

---

## 📋 Roadmap

- [ ] Full semantic analysis (type checking)
- [ ] Improved error recovery and diagnostics
- [ ] Debugger integration
- [ ] Package manager
- [ ] Documentation generation
- [ ] Performance profiling tools
- [ ] REPL for interactive testing
- [ ] Cross-platform builds and distribution

---

## 🔗 Links

- **GitHub**: [yourusername/enginec](https://github.com/yourusername/enginec)
- **Issues**: [Report bugs or request features](https://github.com/yourusername/enginec/issues)
- **Discussions**: [Ask questions and discuss](https://github.com/yourusername/enginec/discussions)

---

## 📝 Notes

- EngineC is designed for Roblox development but works with any Lua runtime
- The language and compiler are actively evolving
- Feedback and contributions help shape the project!

---

## Support

- 📧 Email: [your-email@example.com]
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/enginec/discussions)
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/enginec/issues)

---

Made with ❤️ for Roblox and Lua developers.
