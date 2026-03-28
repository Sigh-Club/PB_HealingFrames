# PB: Healing Frames 🧙‍♂️

**Lightweight, Powerful Healing Unit Frames for WoW 3.3.5a**

Inspired by classic grid-based and bar-style healing interfaces, **PB: Healing Frames** provides a clean, modern, and highly configurable solution for healers. Specifically optimized for the 3.3.5a client and compatible with custom class architectures like Project Ascension.

---

## ✨ Key Features

### 🔲 Dual Layout Modes
Choose between a compact **Grid Mode** for large-scale raiding or a classic **Bars Mode** for traditional group management. Each mode is independently configurable for size, scale, and spacing.

### 🎨 Smart Visuals
- **Dynamic Health Colors**: Instant visual feedback with Healthy (Green), Injured (Yellow), and Critical (Red) states.
- **Curable Debuff Highlighting**: Frames change color based on the type of debuff you can personally cleanse (Magic, Curse, Disease, Poison).
- **Incoming Heal Predictions**: Full `HealComm` integration allows you to see incoming heals from yourself and others, preventing over-healing.
- **Aura Indicators**: Four configurable corner positions to track HoTs, shields, and defensive buffs.

### ⚡ Built-in Click-Casting
No need for external addons like Clique.
- **Auto-Bind**: One-click "Smart Bind" scans your spellbook and assigns your most important healing spells to your mouse buttons.
- **Manual Binding**: Easily assign any spell, macro, or target action to Left, Right, Middle, and extra mouse buttons.
- **Modifier Support**: Use Shift, Ctrl, and Alt modifiers to expand your available bindings per unit.

### 🧪 Advanced Setup Tools
- **Test Mode**: Spawn fake raid members with simulated health fluctuation and aura timers to perfect your UI layout before the pull.
- **Spell Scanning**: Intelligent spellbook scanning ensures your newest ranks and custom abilities are always ready to be bound.

---

## 🚀 Getting Started

### Installation
1. Download the repository.
2. Place the folder into your `Interface/AddOns/` directory.
3. Ensure the folder is named exactly **`PB_HealingFrames`**.
4. Restart World of Warcraft.

### Configuration
- Type **`/pb`** or **`/pbhf`** in-game to open the main configuration window.
- First time using it? Click **"Scan Spells"** in the General tab, then go to the Keybinds tab and click **"Auto Bind"** for an instant setup.

---

## ⌨️ Slash Commands

| Command | Action |
| :--- | :--- |
| `/pb` | Open/Close configuration window |
| `/pb scan` | Force a refresh of your known spells |
| `/pb smartbind` | Run the automatic spell binding logic |
| `/pb test [5-40]` | Toggle test mode with a specific number of units |
| `/pb lock` / `/pb unlock` | Toggle frame movement |

---

## 🛠️ Credits & Inspirations
Inspired by the utility of Grid, the aesthetic of VuhDo, and the simplicity of HealBot. Built for healers who want maximum efficiency with minimum bloat.

**MTC: Healing Frames v1.0.0-beta** | *Developed by Sigh-Club*
