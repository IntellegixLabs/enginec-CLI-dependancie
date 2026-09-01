# Installation Guide

## macOS / Linux (Unix)

### Option 1: Global Installation (Recommended)

1. **Download the CLI**
   ```bash
   # Clone the repo or download the enginec file
   cd /tmp
   git clone https://github.com/yourusername/enginec.git
   cd enginec/cli
   ```

2. **Make it executable**
   ```bash
   chmod +x enginec
   ```

3. **Install to system PATH**
   
   Choose one location:
   
   **Option A: Install to `/usr/local/bin/` (requires sudo)**
   ```bash
   sudo mv enginec /usr/local/bin/
   ```
   
   **Option B: Install to `~/.local/bin/` (no sudo needed)**
   ```bash
   mkdir -p ~/.local/bin
   mv enginec ~/.local/bin/
   
   # Add to PATH if not already there
   echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc
   source ~/.zshrc
   ```

4. **Verify installation**
   ```bash
   enginec --help
   ```

### Option 2: Local Project Installation

```bash
# Copy to your project directory
cp cli/enginec ./enginec
chmod +x ./enginec

# Use the local binary
./enginec comp myfile.ec
```

---

## Windows

### Option 1: Using Node.js (Recommended)

Windows doesn't support shebang scripts directly, so we need to use Node.js:

1. **Install Node.js** (if not already installed)
   - Download from [nodejs.org](https://nodejs.org)
   - Use the LTS version
   - Ensure `node` and `npm` are in your PATH

2. **Create the batch wrapper**

   Create a file called `enginec.bat` in a folder that's in your PATH (like `C:\Windows\System32\` or create `C:\EngineC\bin\`):

   ```batch
   @echo off
   node "%~dp0enginec.js" %*
   ```

3. **Create the Node.js wrapper**

   In the same directory, create `enginec.js`:

   ```javascript
   #!/usr/bin/env node
   const { execSync } = require('child_process');
   const fs = require('fs');
   const path = require('path');
   
   // Read the original enginec script
   const scriptPath = __dirname + '/enginec-node.js';
   require(scriptPath);
   ```

   Or simply copy the `enginec` CLI content and save it as `enginec.js` with the Node.js shebang at the top.

4. **Add to PATH**
   - Right-click "This PC" or "My Computer" → Properties
   - Click "Advanced system settings" → "Environment Variables"
   - Under "System variables", find or create `PATH`
   - Click "Edit" and add the directory containing `enginec.bat`
   - Click OK, then restart your terminal

5. **Verify installation**
   ```cmd
   enginec --help
   ```

### Option 2: Using WSL (Windows Subsystem for Linux)

If you prefer a Unix-like environment on Windows:

1. **Install WSL2**
   ```powershell
   wsl --install
   ```

2. **Inside WSL, follow the macOS/Linux instructions above**
   ```bash
   # In WSL terminal:
   mkdir -p ~/.local/bin
   cp enginec ~/.local/bin/
   chmod +x ~/.local/bin/enginec
   export PATH="$HOME/.local/bin:$PATH"
   ```

3. **Use from PowerShell**
   ```powershell
   wsl enginec comp myfile.ec
   ```

### Option 3: Portable Installation (No PATH modification)

Simply use the full path:

```cmd
C:\path\to\enginec.bat comp myfile.ec
```

---

## Troubleshooting

### `enginec: command not found`

**macOS/Linux:**
- Ensure you ran `chmod +x enginec`
- Ensure the installation directory is in your `$PATH`:
  ```bash
  echo $PATH
  ```
- Try the full path: `/usr/local/bin/enginec --help` or `~/.local/bin/enginec --help`

**Windows:**
- Verify `enginec.bat` exists in a PATH directory:
  ```cmd
  where enginec
  ```
- Restart your terminal after adding to PATH
- Ensure Node.js is installed and accessible:
  ```cmd
  node --version
  ```

### `Permission denied` (macOS/Linux)

```bash
chmod +x /path/to/enginec
```

### Windows: "node is not recognized"

Install Node.js from [nodejs.org](https://nodejs.org) and ensure it's added to PATH during installation.

---

## Next Steps

Once installed, you can use the EngineC CLI:

```bash
# Compile a file
enginec comp myfile.ec

# This will generate myfile.lua in the same directory
```

For VS Code extension installation, see [vscode-extension/README.md](../vscode-extension/README.md).
