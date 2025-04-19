# Unreal World Character Reroller

An AutoHotkey script for rerolling Unreal World characters

## Overview

This tool uses memory pattern scanning techniques to dynamically locate and monitor character attributes in Unreal World. It's designed to work across different game versions (verified on 3.71 and 3.86) by locating memory addresses at runtime rather than using hardcoded offsets.

## Features

- **Version-independent**: Uses pattern scanning to work across different game versions
- **Configurable targets**: Set minimum desired values for any attribute
- **Automatic rerolling**: Presses the reroll key and checks attribute values until targets are met
- **Hotkey controls**: Start and stop rerolling with customizable hotkeys
- **Detailed logging**: Keeps a log of all activities and attempts

## Requirements

- [AutoHotkey v2](https://www.autohotkey.com/)
- [Unreal World](https://www.unrealworld.fi/)
- Windows operating system

## Installation

1. Install AutoHotkey v2
2. Download the script
3. Place the script in any folder
4. Run the script with AutoHotkey

## Usage

1. Start Unreal World and navigate to the character creation screen
2. Start the script
3. Activate the Unreal World window
4. Press Ctrl+1 (default) to begin automatic rerolling
5. Press Ctrl+2 (default) to stop rerolling once desired attributes are found

## Configuration

Edit the CONFIG object at the top of the script to customize:

- Target attribute values
- Reroll frequency
- Notification settings
- Hotkeys
- Pattern scanning parameters

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
