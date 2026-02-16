# Realistic Animal Names for Farming Simulator 25

**Version: 2.2.0.0** | **Author: TisonK** | **Category: Animals, Gameplay**

A comprehensive mod that allows you to give custom names to your animals with floating name tags displayed above them. Built with performance and multiplayer compatibility in mind.

## 🎯 Features

- **Custom Animal Names**: Give each animal a unique, personalized name
- **Floating Name Tags**: Names appear above animals with distance-based scaling
- **UTF-8 Support**: Full international characters and emoji support 🐄🐷🐔
- **Configurable Settings**: Adjust visibility, distance, height, and font size
- **Keybind Support**: Quick access with customizable keybind (default: K)
- **Per-Savegame Storage**: Each save has its own set of animal names
- **Multiplayer Compatible**: Full network synchronization (v2.2.0 enhanced!)
- **Integrated Settings**: All settings accessible through game's settings menu
- **Performance Optimized**: Smart culling and frame-sliced rendering
- **API Support**: Other mods can read/write animal names

## 🌐 Multiplayer (Enhanced in v2.2.0!)

The mod features **full multiplayer synchronization** with improvements:

- ✅ Names set by any player are visible to all players instantly
- ✅ Server-authoritative save system (no conflicts)
- ✅ Sync confirmation for clients
- ✅ Automatic sync when clients join
- ✅ Timeout protection and error recovery
- ✅ Reduced network traffic

**Note**: Only the server host needs to have the mod installed. Clients will automatically receive the mod data when connecting.

## 📥 Installation

1. Download the mod ZIP file
2. Place it in your FS25 mods folder:
   - Windows: `Documents/My Games/FarmingSimulator2025/mods/`
   - Mac: `~/Library/Application Support/FarmingSimulator2025/mods/`
3. Launch Farming Simulator 25
4. Activate the mod in the mod selection screen

## 🎮 Usage

### Naming Animals

1. Walk close to an animal (within 15 meters by default)
2. Press **K** (or your configured keybind)
3. Enter the desired name in the dialog box (supports UTF-8 characters)
4. Click **Apply** to save the name

### Resetting Names

1. Open the naming dialog for an animal (press K near it)
2. Click **Reset** to remove the custom name

### Adjusting Settings

Access the mod settings through the game's settings menu:

- **Show Animal Names**: Toggle name tag visibility on/off
- **Name Display Distance**: How far away names are visible (5-50m)
- **Name Height Above Animal**: Vertical offset of the name tag (0.5-3.0m)
- **Name Font Size**: Size of the displayed text (0.010-0.030)

### Keybind Customization

1. Go to Settings → Controls → Keybindings
2. Find "Open Animal Naming UI" under the MOD category
3. Assign your preferred key

### ❓ Troubleshooting
**Names not appearing:**
- Check if "Show Animal Names" is enabled in settings
- Ensure you're within the display distance
- Verify the animal has been given a name

**UI not opening:**
- Make sure you're close enough to an animal (within 15m default)
- Check your keybind settings
- Restart the game if issues persist

**Multiplayer sync issues:**
- Ensure all players have the same mod version
- Server host should load the save first
- Rejoin if names don't appear after 10 seconds

### 📜 Changelog
## Version 2.2.0.0
- Enhanced multiplayer sync with timeout protection
- Full UTF-8 support (international characters, emoji)
- UI improvements: character counter, better keyboard navigation
- Added 3 new languages (Hungarian, Dutch, Romanian)
- Performance optimizations
- Bug fixes and stability improvements

## Version 2.1.0.0
Full multiplayer synchronization

Performance optimizations

Memory leak fixes

Version 2.0.0.0
Complete rewrite for FS25

Integrated settings system

Improved UI with proper FS25 styling

### 📄 License
This mod is provided as-is for use in Farming Simulator 25. You are free to modify it for personal use but please credit the original author if sharing modified versions.

### 🙏 Credits
Author: TisonK

**Enjoy naming your animals!** 🐄🐷🐔
