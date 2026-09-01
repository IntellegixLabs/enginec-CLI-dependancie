# Publishing EngineC to Package Managers

Make EngineC installable via terminal package managers on macOS, Linux, and Windows.

---

## 📦 macOS & Linux: Homebrew

Homebrew is the most popular package manager for macOS and Linux (via Linuxbrew).

### Setup: Create a Homebrew Formula

1. **Create a new repository for your Homebrew tap** (optional, or use an existing one)

   ```bash
   git clone https://github.com/yourusername/homebrew-enginec
   cd homebrew-enginec
   mkdir Formula
   ```

2. **Create the formula file** `Formula/enginec.rb`

   ```ruby
   class Enginec < Formula
     desc "EngineC compiler - transpile .ec files to Lua"
     homepage "https://github.com/yourusername/enginec"
     url "https://github.com/yourusername/enginec/archive/refs/tags/v0.0.1.tar.gz"
     sha256 "REPLACE_WITH_ACTUAL_SHA256"
     license "MIT"  # or your license
   
     depends_on "node"
   
     def install
       bin.install "cli/enginec"
       chmod 0755, bin/"enginec"
     end
   
     test do
       system bin/"enginec", "--help"
     end
   end
   ```

3. **Get the SHA256 hash of your release**

   ```bash
   # After creating a GitHub release with v0.0.1 tag
   wget https://github.com/yourusername/enginec/archive/refs/tags/v0.0.1.tar.gz -O /tmp/enginec.tar.gz
   sha256sum /tmp/enginec.tar.gz
   ```

   Replace `REPLACE_WITH_ACTUAL_SHA256` with the output.

4. **Push to your tap repository**

   ```bash
   cd homebrew-enginec
   git add Formula/enginec.rb
   git commit -m "Add enginec formula"
   git push origin main
   ```

### Install from Homebrew (Custom Tap)

Users can then install with:

```bash
brew tap yourusername/enginec
brew install enginec
```

### Optional: Submit to Official Homebrew Core

To make it available via `brew install enginec` (without tap), submit to the official Homebrew repository:

1. Fork [Homebrew Core](https://github.com/Homebrew/homebrew-core)
2. Add your formula to `Formula/enginec.rb`
3. Test locally: `brew install --HEAD ./Formula/enginec.rb`
4. Submit a Pull Request to Homebrew Core
5. Wait for review and merge (usually 1-2 weeks)

**Requirements for Homebrew Core:**
- Stable release (GitHub tag/release)
- SHA256 checksum
- Working tests
- Clear documentation

---

## 🪟 Windows: Chocolatey

Chocolatey is the most popular package manager for Windows.

### Setup: Create a Chocolatey Package

1. **Create a package directory**

   ```bash
   mkdir -p enginec-choco/tools
   cd enginec-choco
   ```

2. **Create `enginec.nuspec` (package metadata)**

   ```xml
   <?xml version="1.0" encoding="utf-8"?>
   <package xmlns="http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd">
     <metadata>
       <id>enginec</id>
       <version>0.0.1</version>
       <title>EngineC Compiler</title>
       <authors>Your Name</authors>
       <owners>Your Name</owners>
       <summary>EngineC compiler - transpile .ec files to Lua</summary>
       <description>
         EngineC is a modern compiler toolchain that transpiles .ec source files to Lua.
         Features include a command-line compiler, VS Code extension, and full compiler backend.
         
         Usage: enginec comp myfile.ec
       </description>
       <projectUrl>https://github.com/yourusername/enginec</projectUrl>
       <licenseUrl>https://github.com/yourusername/enginec/blob/main/LICENSE</licenseUrl>
       <requireLicenseAcceptance>false</requireLicenseAcceptance>
       <tags>compiler lua enginec roblox</tags>
       <dependencies>
         <dependency id="nodejs" version="14.0" />
       </dependencies>
     </metadata>
     <files>
       <file src="tools\**" target="tools" />
     </files>
   </package>
   ```

3. **Create `tools/chocolateyinstall.ps1` (installation script)**

   ```powershell
   $toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
   $enginecUrl = "https://github.com/yourusername/enginec/releases/download/v0.0.1/enginec-v0.0.1.zip"
   $enginecPath = Join-Path $toolsDir "enginec"
   
   # Download and extract
   Install-ChocolateyZipPackage -PackageName 'enginec' `
     -Url $enginecUrl `
     -UnzipLocation $toolsDir
   
   # Add to PATH
   Install-ChocolateyPath "$enginecPath\cli" -PathType 'Machine'
   
   # Create batch wrapper if needed
   @"
   @echo off
   node "%~dp0enginec.js" %*
   "@ | Out-File -FilePath "$enginecPath\enginec.bat" -Encoding ASCII
   ```

4. **Create `tools/chocolateyuninstall.ps1` (uninstall script)**

   ```powershell
   # Chocolatey handles PATH cleanup automatically
   # This is optional for additional cleanup
   ```

5. **Test locally**

   ```powershell
   cd enginec-choco
   choco pack
   choco install enginec -source .
   ```

6. **Push to Chocolatey Community Repository**

   ```bash
   # Create account at https://chocolatey.org/login
   # Then:
   choco push enginec.0.0.1.nupkg --key=YOUR_API_KEY
   ```

### Install from Chocolatey

Users can then install with:

```powershell
choco install enginec
```

---

## 🪟 Windows: Scoop

Scoop is an alternative Windows package manager (simpler than Chocolatey).

### Setup: Create a Scoop Manifest

1. **Create a manifest file** `enginec.json`

   ```json
   {
       "version": "0.0.1",
       "description": "EngineC compiler - transpile .ec files to Lua",
       "homepage": "https://github.com/yourusername/enginec",
       "license": "MIT",
       "url": "https://github.com/yourusername/enginec/releases/download/v0.0.1/enginec-v0.0.1.zip",
       "hash": "REPLACE_WITH_SHA256",
       "depends": "nodejs",
       "bin": "cli/enginec.bat",
       "checkver": "github",
       "autoupdate": {
           "url": "https://github.com/yourusername/enginec/releases/download/v$version/enginec-v$version.zip"
       }
   }
   ```

2. **Get SHA256 hash**

   ```bash
   certUtil -hashfile enginec-v0.0.1.zip SHA256
   ```

3. **Create a bucket repository** (Scoop app repository)

   ```bash
   git clone https://github.com/yourusername/scoop-enginec
   cp enginec.json scoop-enginec/bucket/
   git add .
   git commit -m "Add enginec"
   git push
   ```

### Install from Scoop

Users can then install with:

```powershell
scoop bucket add enginec https://github.com/yourusername/scoop-enginec
scoop install enginec
```

---

## 🐧 Linux: APT (Debian/Ubuntu)

For Debian-based Linux distributions.

### Setup: Create a PPA (Personal Package Archive)

1. **Create a Launchpad account** at https://launchpad.net

2. **Create a new PPA**
   - Go to https://launchpad.net/~yourusername/+ppas
   - Click "Create a new PPA"
   - Fill in details

3. **Create Debian package**

   ```bash
   # Create package structure
   mkdir -p enginec-0.0.1/debian
   cd enginec-0.0.1
   
   # Create control file
   cat > debian/control << 'EOF'
   Package: enginec
   Version: 0.0.1
   Section: devel
   Priority: optional
   Architecture: amd64
   Depends: nodejs
   Maintainer: Your Name <your-email@example.com>
   Homepage: https://github.com/yourusername/enginec
   Description: EngineC compiler - transpile .ec files to Lua
    Fast, type-aware compiler for EngineC language.
    Generates Lua output for Roblox and general Lua runtime.
   EOF
   
   # Create changelog
   cat > debian/changelog << 'EOF'
   enginec (0.0.1-1) focal; urgency=medium
   
     * Initial release
   
    -- Your Name <your-email@example.com>  Mon, 01 Sep 2026 00:00:00 +0000
   EOF
   
   # Create rules file
   cat > debian/rules << 'EOF'
   #!/usr/bin/make -f
   
   %:
   	dh $@
   
   override_dh_auto_install:
   	install -D -m 755 cli/enginec $(CURDIR)/debian/enginec/usr/local/bin/enginec
   EOF
   chmod +x debian/rules
   ```

4. **Build and upload**

   ```bash
   debuild -S -sa
   dput ppa:yourusername/enginec ../enginec_0.0.1-1_source.changes
   ```

### Install from PPA

Users can then install with:

```bash
sudo add-apt-repository ppa:yourusername/enginec
sudo apt update
sudo apt install enginec
```

---

## 🐧 Linux: Arch (AUR)

For Arch Linux users via the Arch User Repository.

### Setup: Create AUR Package

1. **Create PKGBUILD file**

   ```bash
   cat > PKGBUILD << 'EOF'
   pkgname=enginec
   pkgver=0.0.1
   pkgrel=1
   pkgdesc="EngineC compiler - transpile .ec files to Lua"
   arch=('x86_64')
   url="https://github.com/yourusername/enginec"
   license=('MIT')
   depends=('nodejs')
   source=("https://github.com/yourusername/enginec/archive/refs/tags/v${pkgver}.tar.gz")
   sha256sums=('REPLACE_WITH_SHA256')
   
   build() {
     cd "$srcdir/enginec-$pkgver"
     # Nothing to build - Node.js script
   }
   
   package() {
     cd "$srcdir/enginec-$pkgver"
     install -D -m 755 cli/enginec "$pkgdir/usr/bin/enginec"
   }
   EOF
   ```

2. **Submit to AUR**
   - Create account at https://aur.archlinux.org
   - Follow their submission process
   - Use `git push` to upload your PKGBUILD

### Install from AUR

Users can then install with:

```bash
yay -S enginec
# or
paru -S enginec
```

---

## 🔧 Recommended Approach

For maximum reach, I recommend this priority:

### Phase 1: MVP (Start here)
- ✅ **Homebrew Tap** — Custom tap (easiest)
  ```bash
  brew tap yourusername/enginec
  brew install enginec
  ```
- ✅ **Chocolatey** — Submit to community (takes 1-2 weeks)
  ```powershell
  choco install enginec
  ```
- ✅ **Scoop** — Custom bucket (easiest)
  ```powershell
  scoop bucket add enginec https://github.com/yourusername/scoop-enginec
  scoop install enginec
  ```

### Phase 2: Expand Reach
- ⭐ **Homebrew Core** — Official repo (requires 1-2 week review)
- ⭐ **AUR** — Arch Linux community (easy)
- ⭐ **PPA** — Debian/Ubuntu (medium effort)

---

## 📋 Preparation Checklist

Before publishing to any package manager:

- [ ] Create GitHub release with version tag (e.g., `v0.0.1`)
- [ ] Attach compiled binaries or source `.zip` to release
- [ ] Include `CHANGELOG.md` documenting changes
- [ ] Add `LICENSE` file to repository
- [ ] Test installation locally on target platform
- [ ] Document installation instructions in `README.md`
- [ ] Create or update `INSTALL.md` with package manager instructions

---

## 🚀 Getting Started: Homebrew + Chocolatey

Here's the quickest path to get EngineC installable:

### Step 1: Create Homebrew Tap (30 min)

```bash
# Create repo
git clone https://github.com/yourusername/homebrew-enginec
cd homebrew-enginec
mkdir Formula

# Create formula (use template above)
cat > Formula/enginec.rb << 'EOF'
# (paste Homebrew formula from above)
EOF

git add Formula/enginec.rb
git commit -m "Initial commit: add enginec formula"
git push
```

### Step 2: Create Chocolatey Package (1 hour)

```bash
# Create directory structure
mkdir -p enginec-choco/tools
cd enginec-choco

# Create package files (use templates above)
# enginec.nuspec
# tools/chocolateyinstall.ps1
# tools/chocolateyuninstall.ps1

# Test
choco pack
choco install enginec -source .
```

### Step 3: Users Can Now Install!

**macOS/Linux:**
```bash
brew tap yourusername/enginec
brew install enginec
```

**Windows:**
```powershell
choco install enginec  # Once approved
# or from local: choco install enginec -source .
```

---

## 🔗 Resources

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Chocolatey Package Documentation](https://docs.chocolatey.org/en-us/create/create-packages)
- [Scoop App Manifest](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifest)
- [AUR Submission Guide](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- [Launchpad PPA Guide](https://help.launchpad.net/Packaging/PPA)

---

## Summary

| Platform | Package Manager | Effort | Reach | Command |
|----------|-----------------|--------|-------|---------|
| macOS/Linux | Homebrew (Tap) | ⭐ Easy | High | `brew tap && brew install` |
| macOS/Linux | Homebrew (Core) | ⭐⭐⭐ Hard | Very High | `brew install` |
| Windows | Chocolatey | ⭐⭐ Medium | Very High | `choco install` |
| Windows | Scoop | ⭐ Easy | High | `scoop install` |
| Linux | AUR | ⭐⭐ Medium | Medium | `yay -S` |
| Debian/Ubuntu | PPA | ⭐⭐ Medium | Medium | `apt install` |

**Recommendation:** Start with Homebrew Tap + Scoop. They're easiest and cover 80% of users. Add Chocolatey once it's approved.
