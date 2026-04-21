# Waywallen Bazzite Installer

A simple, automated installer for building and installing Waywallen and all its components on immutable systems like Bazzite.

This script handles everything:

* Dependencies (via Fedora 44 distrobox)
* Building all Waywallen components
* Installing to `~/.local`
* KDE wallpaper plugin integration
* Optional Flatpak build/install
* Full uninstall support

---

## ✨ Features

* 🧊 Works with immutable systems (Bazzite, Silverblue, Kinoite)
* 📦 No system pollution — installs to `~/.local`
* 🐳 Uses distrobox for clean build environment
* 🧠 Handles complex dependencies automatically
* 🎨 Installs KDE Plasma wallpaper plugin
* 📦 Optional Flatpak build/install
* 🧹 Includes full uninstall script
* 📝 Logging for debugging

---

## 📥 Installation

### Quick start

```bash
git clone https://github.com/zany130/waywallen-installer.git
cd waywallen-installer
chmod +x install.sh uninstall.sh
./install.sh
```

---

## ⚙️ Usage

### Default (recommended)

```bash
./install.sh
```

* Builds inside Fedora 44 distrobox
* Installs to `~/.local`
* Installs KDE plugin

---

### Flatpak only

```bash
./install.sh --flatpak
```

* Builds and installs Flatpak on host
* Still installs KDE plugin

---

### Native build (no distrobox)

```bash
./install.sh --no-distrobox
```

> ⚠️ Requires all dependencies installed on host

---

### Skip KDE plugin

```bash
./install.sh --no-kde
```

---

### Other options

```bash
./install.sh --help
```

---

## ▶️ Running Waywallen

After install:

```bash
~/.local/bin/waywallen-local
```

---

## 🧹 Uninstall

### Remove native install

```bash
./uninstall.sh
```

---

### Remove Flatpak install

```bash
./uninstall.sh --flatpak
```

---

### Remove everything

```bash
./uninstall.sh --host --flatpak
```

---

### Skip KDE plugin removal

```bash
./uninstall.sh --no-kde
```

---

## 📁 What Gets Installed

### Native (`~/.local`)

* Waywallen daemon
* UI + bridge
* Renderers (mpv, image, etc.)
* Open Wallpaper Engine
* Qt/QML plugins
* KDE wallpaper plugin

---

### Flatpak

* `org.waywallen.waywallen`

---

## 🛠 Requirements

### Host

* `git`
* `curl`
* `distrobox`
* `podman`
* `flatpak` (for Flatpak mode)

### Distrobox (auto-installed)

* Full Fedora 44 build environment
* Qt6, Vulkan, FFmpeg, Rust, etc.

---

## 🧪 Troubleshooting

### Logs

Logs are stored in:

```bash
./logs/
```

Example:

```bash
logs/install-YYYYMMDD-HHMMSS.log
```

---

### Common Issues

#### Missing dependencies

If something fails during build:

```bash
./install.sh --no-clean
```

Check logs for missing `pkg-config` modules.

---

#### Rust / cargo issues

The script automatically configures:

```bash
rustup default stable
```

---

#### Git LFS

Handled automatically, but you can verify:

```bash
git lfs version
```

---

## 📦 Projects Included

This installer builds:

* https://github.com/waywallen/waywallen
* https://github.com/waywallen/waywallen-display
* https://github.com/waywallen/open-wallpaper-engine
* https://github.com/hypengw/org.waywallen.waywallen (Flatpak)

---

## 🤝 Contributing

PRs welcome. This is mainly focused on making Waywallen easy to install on immutable Linux systems.

---


## 💡 Why This Exists

Waywallen is awesome, but installing it manually on Bazzite/Silverblue is painful.

This script automates the entire process so you can just:

```bash
./install.sh
```

and be done.

---

## 🙌 Credits

* Waywallen devs
* Fedora / Bazzite community
