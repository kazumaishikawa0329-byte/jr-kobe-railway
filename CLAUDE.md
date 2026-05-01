# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Roblox game project for **JR神戸鉄道** (JR Kobe Railway), using [Rojo](https://rojo.space/docs) to sync local `.luau` source files into Roblox Studio. The scripting language is **Luau**.

## Development Workflow

Tool management is handled by **Rokit** (`rokit.toml`). Rojo 7.6.1 is the only managed tool.

**Start the dev environment** (Windows): run `_start.bat` — it launches VSCode, Roblox Studio, a Rojo server, and Claude Code.

**Build the place file:**
```
rojo build -o "project.rbxlx"
```

**Start the live-sync server** (after opening `project.rbxlx` in Roblox Studio):
```
rojo serve
```

There is no lint or test runner configured in this project.

## Source Layout → Roblox Service Mapping

| Local path | Roblox location |
|---|---|
| `src/server/` | `ServerScriptService/Server` |
| `src/client/` | `StarterPlayer/StarterPlayerScripts/Client` |
| `src/shared/` | `ReplicatedStorage/Shared` |

- Server-only logic belongs in `src/server/`.
- Client-only logic belongs in `src/client/`.
- Modules shared between server and client (required via `game.ReplicatedStorage.Shared`) belong in `src/shared/`.

## Key Configuration

- `default.project.json` — defines the Rojo project tree and maps source folders to Roblox services. Edit this to add new service mappings.
- `rokit.toml` — declares tool versions managed by Rokit.
- `project.rbxlx` and `*.rbxlx.lock` are gitignored (built artifacts).
