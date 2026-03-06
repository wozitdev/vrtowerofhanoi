# Tower of Hanoi VR — Godot 4.6

A simple, clean VR Tower of Hanoi puzzle built with Godot 4.6 and OpenXR.

## How to Play

1. **Open** this folder as a Godot 4.6 project (`Project > Import` or double-click `project.godot`)
2. **Run** the project (`F5` or the Play button)
3. Use your **VR controllers** to grab and move discs:
   - **Grip** or **Trigger** to grab the top disc of any peg
   - **Release** to drop — discs automatically snap to the nearest valid peg
4. Move all 5 discs from the **left peg** to the **right peg**
5. Press **R** on keyboard to reset

## Features

- 🎮 **OpenXR VR** — works with Quest, SteamVR, WMR, etc.
- 🧲 **Subtle magnetism** — discs snap to pegs when released nearby
- 🚧 **Boundary system** — invisible walls keep discs on the table
- ✅ **Rule enforcement** — only grab top disc; can't stack on smaller disc
- 🏆 **Win detection** — congratulations + move count vs optimal
- 🖥️ **Desktop fallback** — runs in flat mode if no VR headset detected

## Controls

| Action | VR | Desktop |
|--------|-----|---------|
| Grab disc | Grip / Trigger | Left Click (debug) |
| Release disc | Release grip | Release Click |
| Reset game | — | R key |

## Project Structure

```
project.godot          — Godot project config (OpenXR enabled)
scenes/
  main.tscn            — Root scene (Node3D + main.gd)
scripts/
  main.gd              — Builds entire world programmatically
  disc.gd              — Disc physics, grab/release, snap animation
  peg.gd               — Peg stack tracking, placement rules
  vr_hand.gd           — XR controller input, magnetism on release
  game_manager.gd      — Win detection, move counter, reset
```

## Optimal Solution

The minimum number of moves for 5 discs is **31** (2⁵ − 1).
