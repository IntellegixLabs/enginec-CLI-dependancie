# Publishing EngineC to Package Managers

Your repo is now on GitHub! Here's how to get EngineC installable via package managers.

---

## 🍎 Homebrew (macOS/Linux)

### Step 1: Create Homebrew Tap Repository

```bash
# Create a new GitHub repo called: homebrew-enginec

# Clone it
git clone https://github.com/IntellegixLabs/homebrew-enginec.git
cd homebrew-enginec

# Create folder
mkdir Formula

# Copy the formula file
cp /path/to/Formula_enginec.rb Formula/enginec.rb

# Commit and push
git add .
git commit -m "Add enginec formula"
git push origin main
```

### Step 2: Users Install With

```bash
brew tap IntellegixLabs/homebrew-enginec
brew install enginec
```

---

## 🪟 Scoop (Windows)

### Step 1: Create Scoop Bucket Repository

```bash
# Create a new GitHub repo called: scoop-enginec

# Clone it
git clone https://github.com/IntellegixLabs/scoop-enginec.git
cd scoop-enginec

# Create folder
mkdir bucket

# Copy the manifest
cp /path/to/Scoop_enginec.json bucket/enginec.json

# Commit and push
git add .
git commit -m "Add enginec"
git push origin main
```

### Step 2: Users Install With

```powershell
scoop bucket add enginec https://github.com/IntellegixLabs/scoop-enginec
scoop install enginec
```

---

## 🧪 Chocolatey (Windows)

### Option 1: Community Repository (Easiest for users)

1. Create account at https://chocolatey.org
2. Follow their [package submission guide](https://docs.chocolatey.org/en-us/create/create-packages)
3. Submit package: `choco push enginec.0.0.1.nupkg --key=YOUR_API_KEY`
4. Wait 1-2 weeks for review
5. Once approved, users install: `choco install enginec`

### Option 2: Host Your Own

Create a GitHub repo with the package and host it yourself (more complex).

---

## 📋 Quick Checklist

- [x] GitHub repo created: https://github.com/IntellegixLabs/enginec-CLI-dependancie
- [x] v0.0.1 release tagged
- [x] README, INSTALL, PACKAGE_MANAGERS docs ready
- [ ] Create `homebrew-enginec` repo (optional but recommended)
- [ ] Create `scoop-enginec` repo (optional but recommended)
- [ ] Submit to Chocolatey community (wait 1-2 weeks)

---

## 🚀 Next Steps

### To Enable Homebrew (5 minutes)

```bash
# 1. Create repo https://github.com/IntellegixLabs/homebrew-enginec
# 2. Clone and add Formula/enginec.rb
# 3. Push
# 4. Tell users: brew tap IntellegixLabs/homebrew-enginec && brew install enginec
```

### To Enable Scoop (5 minutes)

```bash
# 1. Create repo https://github.com/IntellegixLabs/scoop-enginec
# 2. Clone and add bucket/enginec.json
# 3. Push
# 4. Tell users: scoop bucket add enginec ... && scoop install enginec
```

### To Enable Chocolatey (1-2 weeks)

```bash
# 1. Create Chocolatey account
# 2. Follow their packaging guide
# 3. Submit package
# 4. Once approved, users: choco install enginec
```

---

## 📝 Files Included

- `Formula_enginec.rb` — Homebrew formula (copy to homebrew-enginec/Formula/enginec.rb)
- `Scoop_enginec.json` — Scoop manifest (copy to scoop-enginec/bucket/enginec.json)

---

Good luck! 🎉
