# Realistic Animal Names for Farming Simulator 25

**Version: 2.1.0.0** | **Author: TisonK** | **Category: Animals, Gameplay**

A comprehensive mod that allows you to give custom names to your animals with floating name tags displayed above them. Built with performance and multiplayer compatibility in mind.

## 🎯 Features

- **Custom Animal Names**: Give each animal a unique, personalized name
- **Floating Name Tags**: Names appear above animals with distance-based scaling
- **Configurable Settings**: Adjust visibility, distance, height, and font size
- **Keybind Support**: Quick access with customizable keybind (default: K)
- **Per-Savegame Storage**: Each save has its own set of animal names
- **Multiplayer Compatible**: Full network synchronization (NEW in 2.1.0!)
- **Integrated Settings**: All settings accessible through game's settings menu
- **Performance Optimized**: Smart culling and frame-sliced rendering
- **API Support**: Other mods can read/write animal names

## Installation

1. Download the mod ZIP file
2. Place it in your FS25 mods folder:
   - Windows: `Documents/My Games/FarmingSimulator2025/mods/`
   - Mac: `~/Library/Application Support/FarmingSimulator2025/mods/`
3. Launch Farming Simulator 25
4. Activate the mod in the mod selection screen

## Usage

### Naming Animals

1. Walk close to an animal (within 15 meters by default)
2. Press **K** (or your configured keybind)
3. Enter the desired name in the dialog box
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

## File Structure

```
FS25_RealisticAnimalNames/
├── modDesc.xml                   # Mod description and configuration
├── icon.dds                      # Mod icon (512x512)
├── src/
│   └── RealisticAnimalNames.lua  # Main mod script
└── gui/
    └── AnimalNamesDialog.xml     # UI dialog definition
```

## Technical Details

### Settings Storage

- Global settings are stored in the game's settings system
- Animal names are saved per-savegame in: `savegame/realisticAnimalNames.xml`

### Supported Animals

Works with all animal types in FS25:
- Cows
- Pigs
- Chickens
- Sheep
- Horses
- And any future animal types

### Performance

- Optimized rendering only shows names within configured distance
- Distance-based scaling prevents performance issues with many animals
- Minimal impact on frame rate

## Compatibility

- **FS25 Version**: 1.4+
- **Multiplayer**: Yes, fully supported
- **Conflicts**: None known

## Troubleshooting

**Names not appearing:**
- Check if "Show Animal Names" is enabled in settings
- Ensure you're within the display distance
- Verify the animal has been given a name

**UI not opening:**
- Make sure you're close enough to an animal (within 15m default)
- Check your keybind settings
- Restart the game if issues persist

**Names not saving:**
- Ensure the mod has write permissions to your savegame folder
- Check that you clicked "Apply" when setting names

## Credits

- **Author**: YourName
- **Version**: 2.0.0.0
- **Category**: Animals, Gameplay
- **Mod Hub Compatible**: Yes

## Changelog

### Version 2.0.0.0
- Complete rewrite for FS25
- Integrated settings system
- Improved UI with proper FS25 styling
- Distance-based name scaling
- Better performance optimization
- Enhanced multiplayer support
- Proper keybind integration

### Version 1.1.0.0
- Initial FS25 port
- Basic naming functionality
- Simple GUI

## License

This mod is provided as-is for use in Farming Simulator 25. You are free to modify it for personal use but please credit the original author if sharing modified versions.

## Support

For bug reports, feature requests, or general support:
- Check the mod comments on ModHub
- Visit the FS25 modding community forums
- Contact the author

---

**Enjoy naming your animals!** 🐄🐷🐔
