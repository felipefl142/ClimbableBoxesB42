# Climbable Boxes

A Project Zomboid mod for Build 42.13+ that lets you climb onto boxes and crates.

Ever wanted to hop on top of a crate to get a better vantage point, or just because you can? Now you can. Face a box, press **G** (or right-click it), and your character will climb up onto it.

## Features

- **Keybind and context menu** — Press G while facing a box, or right-click it and select "Climb onto box"
- **Difficulty modes** — Choose between Full mode (success/struggle/fail based on your character's stats) or Simplified mode (always succeed)
- **Stat-based outcomes** — In Full mode, your fitness, strength, endurance, carry weight, traits, and nearby threats all affect whether you make it up cleanly, struggle, or fail
- **Injury system** — Broken arms, deep wounds, or busted legs will prevent you from climbing (toggleable in sandbox settings)
- **Endurance cost** — Climbing takes effort, with a configurable cost multiplier
- **Multiplayer support** — Works in MP with proper server synchronization
- **Smart box detection** — Automatically recognizes boxes and crates by their properties, no hardcoded sprite lists

## Requirements

- Project Zomboid **Build 42.13+**
- [TchernoLib](https://steamcommunity.com/sharedfiles/filedetails/?id=3389605231)

## Installation

Subscribe on the Steam Workshop (link coming soon), or drop the `Climbable Boxes B42` folder into your Project Zomboid mods directory.

Make sure TchernoLib is also installed and loaded before this mod.

## Sandbox Options

You can tweak these in your sandbox settings under the **ClimbableBoxes** page:

| Option | Default | Description |
|--------|---------|-------------|
| Difficulty Mode | Full | Full = success/struggle/fail based on stats. Simplified = always succeed. |
| Base Success Rate | 90% | Starting success chance before stat modifiers (Full mode only) |
| Endurance Cost Multiplier | 1.0 | How much endurance climbing costs. 0 = free, 1 = normal, 5 = brutal. |
| Enable Health Check | On | Whether injuries to arms, torso, and legs block climbing |

## How It Works

Your character faces a box or crate and initiates a climb. The mod plays a climbing animation and, depending on your difficulty setting:

- **Full mode**: Rolls against your success rate (modified by fitness, strength, encumbrance, fatigue, traits, and combat situation). You might succeed cleanly, struggle through it, or fail entirely.
- **Simplified mode**: You always make it up, no questions asked.

On success, your character is teleported onto the box's tile. Endurance is consumed either way.

## Keybind

The default key is **G**. You can rebind it in the mod options menu in-game.

## Compatibility

The mod detects climbable objects by their game properties (`IsMoveAble` flag + `ContainerType`), not by sprite names. This means it should work with modded boxes and crates that follow standard PZ item conventions.

## License

Feel free to use this as a reference or base for your own PZ mods.
