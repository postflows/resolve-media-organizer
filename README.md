# Media Organizer

> Part of [PostFlows](https://github.com/postflows) toolkit for DaVinci Resolve

Organize Media Pool clips into bins by type (Video, Audio, Timeline, Compound, Fusion, etc.) and optionally by keywords. **Lua** script (canonical version).

## What it does

Select media types via checkboxes, choose folders to process (root, selected bin, or custom via dialog). Moves clips into type-based bins under root; optional keyword subfolders and deletion of empty bins. Supports RAW and EXR/sequence handling.

## Requirements

- DaVinci Resolve 18+
- Open project

## Installation

Copy the **`media-organizer.lua`** file to:

- **macOS:** `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/`
- **Windows:** `C:\ProgramData\Blackmagic Design\DaVinci Resolve\Fusion\Scripts\`

Run from **Workspace → Scripts** in Resolve (or from the Fusion page Scripts menu).

## Usage

Run script, check desired media types, set folder scope (Select Folders / root only / selected folder), enable options (keywords, delete empty), click Organize Media.

## License

MIT © PostFlows
