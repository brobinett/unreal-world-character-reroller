# Unreal World Character Reroller

An AutoHotkey script for rerolling Unreal World characters

## Overview

Automatically reroll Unreal World characters until target attributes are met.

Designed to work across different game versions (verified on 3.71 and 3.86) by using memory pattern scanning to locate memory addresses at runtime rather than using hardcoded offsets.

## Requirements

- [AutoHotkey v2](https://www.autohotkey.com/)
- [Unreal World](https://www.unrealworld.fi/)
- Windows operating system

## Installation

1. Install AutoHotkey v2
2. Download the script
3. Run the script with AutoHotkey

## Usage

0. Edit the CONFIG object at the top of the script to set target attributes
1. Start Unreal World and navigate the character creation flow until you get to the attribute screen
2. Start the script
3. Activate the Unreal World window
4. Press Ctrl+1 (default) to begin rerolling. The script will automatically stop when the target attributes are met. Press Ctrl+2 (default) to stop rerolling.

## Configuration

Edit the CONFIG object at the top of the script to customize:

- Target attribute values
- Reroll frequency
- Hotkeys

Example configuration:

```autohotkey
global CONFIG := {
    GameExecutable: "urw.exe",
    LogFile: A_ScriptDir "\reroller.log",
    RerollFrequency: 20,
    ScanDelay: 10,
    RerollKey: "n",
    StopHotkey: "^2",
    StartHotkey: "^1",
    Pattern: {
        Signature: "0F B6 C2 B9 01 00 00 00 0F 47 C1 B9 03 00 00 00 A2",
        Offset: 17
    },
    Attributes: Map(
        "Strength",     {offset: 0,    target: 13},
        "Agility",      {offset: 1,    target: 13},
        "Dexterity",    {offset: 4,    target: 13},
        "Speed",        {offset: 5,    target: 13},
        "Endurance",    {offset: 7,    target: 13},
        "SmellTaste",   {offset: 8,    target: 13},
        "Eyesight",     {offset: 11,   target: 13},
        "Touch",        {offset: 12,   target: 13},
        "Will",         {offset: 13,   target: 13},
        "Intelligence", {offset: 16,   target: 13},
        "Hearing",      {offset: 17,   target: 13},
        "Height",       {offset: -14,  target: 60},
        "Weight",       {offset: -18,  target: 200}
    )
}
```
## Troubleshooting

If the script fails to find the attribute array, you're probably screwed. Let me know, and maybe I'll add fallback patterns for the scanner to try, or hardcoded fallbacks for different versions of the game.
Please include the logs with any submitted issues. Also a warning, the log file isn't managed in any way, so it might get huge.

## Contributing
Contributions are welcome! Please feel free to submit a PR.


