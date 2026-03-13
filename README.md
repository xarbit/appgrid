# AppGrid

A macOS Tahoe-style application grid launcher for KDE Plasma 6.

![KDE Plasma](https://img.shields.io/badge/KDE_Plasma-6.0+-blue)
![License](https://img.shields.io/badge/License-GPL--2.0+-green)

## Features

- **App grid** — All installed applications displayed in a responsive grid layout
- **Category filtering** — Filter apps by category (Development, Graphics, Internet, Multimedia, Office, Games, Education, System, Utilities)
- **Search** — Instant search with list view results, press Enter to launch the top result
- **Centered popup** — Opens centered on screen, not attached to the panel
- **Animations** — macOS-style scale + fade open/close animations
- **Super key support** — Toggle with Super key or panel icon click
- **Configurable icon** — Change the panel icon via right-click → Configure, matching Kicker/Kickoff behavior
- **Theme support** — Follows the user's light/dark Plasma theme
- **Responsive** — Adapts columns and size to different screen resolutions
- **Show Alternatives** — Integrates with Plasma's "Show Alternatives" panel mechanism as a launcher alternative
- **Proper app launching** — Uses KIO::ApplicationLauncherJob, correctly handles terminal apps, D-Bus activation, and field codes

## Dependencies

### Runtime
- plasma-workspace
- kservice
- ki18n
- kio

### Build
- cmake
- extra-cmake-modules
- qt6-base
- qt6-declarative
- libplasma
- kpackage
- kio

## Building

### Arch Linux (recommended)

```bash
makepkg -si
```

### Manual

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build -j$(nproc)
sudo cmake --install build
```

After installing, restart Plasma:

```bash
kquitapp6 plasmashell && kstart plasmashell
```

## Usage

1. Right-click your current application launcher in the panel
2. Select **Show Alternatives**
3. Choose **AppGrid**

Or add it as a new widget: right-click the panel → **Add Widgets** → search for **AppGrid**.

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| Super | Toggle AppGrid |
| Escape | Close |
| Enter | Launch selected search result |
| Arrow keys | Navigate search results |
| Type anywhere | Start searching |

## Configuration

Right-click the AppGrid panel icon → **Configure AppGrid** → **General**:

- **Icon** — Click to choose a custom icon or drag-and-drop an image file (.png, .svg, .svgz, .xpm)

## Project Structure

```
AppGrid/
├── CMakeLists.txt              # Build system
├── PKGBUILD                    # Arch Linux package
├── src/
│   ├── appgridplugin.cpp/h     # Plasma::Applet plugin
│   └── appmodel.cpp/h          # App data model and filter proxy
└── package/
    ├── metadata.json            # KPackage/plugin metadata
    └── contents/
        ├── config/
        │   ├── main.xml         # Configuration schema (kcfg)
        │   └── config.qml       # Configuration model
        └── ui/
            ├── main.qml              # PlasmoidItem entry point
            ├── CompactRepresentation.qml  # Panel icon
            ├── ConfigGeneral.qml     # Icon configuration page
            └── GridWindow.qml        # App grid window
```

## License

GPL-2.0-or-later
