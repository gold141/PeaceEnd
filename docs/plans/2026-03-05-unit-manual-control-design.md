# Manual Unit Control Design

**Status: IMPLEMENTED** (2026-03-05)

## Overview

Allow the player to take direct control of any player unit by clicking on it when the attack range overlay is visible (hover). The controlled unit retains all its native capabilities — movement speed, fire rate, projectile type, range, spread.

## Trigger

- Player hovers over a player unit — attack range is shown (existing `range_visualizer.gd`)
- Player releases LMB (mouse button up) on a player unit — takes control
- Only works for alive, deployed player units

## Controls When Controlling a Unit

| Action | Input | Behavior |
|--------|-------|----------|
| Aim | Mouse position | Sets target direction/position |
| Fire | LMB click | Fires unit's native projectile (respects fire_interval cooldown) |
| Move left | A key | Moves unit at its walk_speed/drive_speed to the left |
| Move right | D key | Moves unit at its walk_speed/drive_speed to the right |
| Switch unit | LMB on another player unit | Switches control to that unit |
| Exit control | ESC or RMB | Returns to artillery mode |

## Unit-Specific Behavior

### Movement
- **Infantry, Machine Gunner, MANPADS**: move at `walk_speed` (30 px/s)
- **Player Tank**: move at `drive_speed` (20 px/s)
- **Light Vehicle**: move at `drive_speed` (80 px/s)
- **AA Gun**: **STATIONARY** — no movement allowed (A/D ignored)

### Firing (manual_fire_at)
Each unit type calculates its firing differently:

- **Infantry**: rocket at elevation angle toward target, with spread. Uses `rocket_scene`
- **Machine Gunner**: bullet at near-horizontal angle toward target. Uses `bullet` scene, damage=0.3
- **Player Tank**: parabolic shell toward target. Uses `shell` scene with gravity=120, air_drag=0.08
- **Light Vehicle**: bullet at near-horizontal angle. Uses `bullet` scene, damage=1.0
- **AA Gun**: bullet aimed directly at cursor position. Uses `bullet` scene, speed=800
- **MANPADS**: AA missile launched toward cursor (target = cursor as virtual point or nearest air unit). Uses `aa_missile` scene

All units respect their own `fire_interval` — fire_timer must reach 0 before firing again.

## Architecture

### New File: `scripts/game/unit_control.gd`
- Extends `Node2D`
- Added as child of Battle scene
- Manages: selected unit, input handling, visual feedback

### Modified Files (add ~15 lines each)
- `infantry.gd` — add `manually_controlled` flag, `manual_fire_at()`, skip auto-fire when controlled
- `machine_gunner.gd` — same pattern
- `player_tank.gd` — same pattern, parabolic calculation
- `light_vehicle.gd` — same pattern
- `aa_gun.gd` — same pattern, no movement
- `manpads.gd` — same pattern, AA missile toward cursor

### Modified Files (minor)
- `battle_manager.gd` — add UnitControl node, wire signals
- `aiming_system.gd` — `input_blocked` already exists, used when unit is controlled
- `range_visualizer.gd` — expose `hovered_unit` for click detection (already public var)
- `hud.gd` — show controlled unit info (name, HP, reload) instead of artillery info

### Signal Flow
1. `range_visualizer` already tracks `hovered_unit`
2. `unit_control` reads `range_visualizer.hovered_unit` on mouse button up
3. If hovered_unit is player and alive → select it
4. `aiming_system.input_blocked = true`
5. Unit's `manually_controlled = true`
6. `unit_control._process()` handles A/D movement + cursor aiming
7. `unit_control._unhandled_input()` handles LMB fire, ESC/RMB exit

### Visual Feedback
- Green pulsing outline around controlled unit
- Yellow crosshair at mouse position (different from green artillery crosshair)
- HUD shows: unit type name, HP bar, reload bar with unit's fire_interval
- Range visualizer keeps showing the unit's attack range while controlled
