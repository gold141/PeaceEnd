# PeaceEnd: Unit Expansion & AI Design

## Overview

Expand the game from 2 unit types (infantry + enemy tank) to a full roster of 12+ unit types across both sides, with economy system, AI spawner, air combat layer, and anti-air mechanics.

## Design Philosophy

- **Asymmetric sides:** Enemy has air superiority (jets, helis, drones), Player counters with AA and mortar skill
- **Rock-paper-scissors:** Every unit has clear counters
- **Auto-combat:** All units fight autonomously; player's edge is the mortar + deployment choices
- **Economy-driven:** Both sides earn money, spend on units; AI decides for enemy
- **Dynamic chaos:** Constant flow of units from both edges, explosions, wreckage everywhere

## Economy System

| Parameter | Player | Enemy |
|-----------|--------|-------|
| Starting money | $300 | $400 |
| Income | $15/s | $18/s |
| Kill bonus | 30% of killed unit cost | 30% |

- Money displayed in HUD top-right
- Player spends via action panel buttons (grayed out if insufficient funds)
- Enemy spends via AI spawner logic

## Unit Roster

### Player Side (Left → Right)

| Unit | Cost | HP | Speed | Range | Fire Rate | Damage | Targets | Entry |
|------|------|----|-------|-------|-----------|--------|---------|-------|
| Infantry (RPG) | $100 | 2 | 30 px/s walk | 300px | 3.5s | 1 | Vehicles, tanks | Walk from left |
| Machine Gunner | $80 | 2 | 30 px/s walk | 250px | 0.25s | 0.3 | Infantry, drones | Walk from left |
| Light Vehicle | $200 | 5 | 80 px/s drive | 350px | 1.5s | 1 | All ground | Drive from left |
| Player Tank | $400 | 8 | 20 px/s drive | 500px | 4.0s | 2 | All ground | Drive from left |
| AA Gun | $250 | 4 | 0 (placed) | 450px | 0.4s | 1.5 | Air only | Placed like infantry |
| MANPADS Soldier | $150 | 2 | 30 px/s walk | 400px | 5.0s | 3 | Air only | Walk from left |

### Enemy Side (Right → Left)

| Unit | Cost | HP | Speed | Range | Fire Rate | Damage | Targets | Entry |
|------|------|----|-------|-------|-----------|--------|---------|-------|
| Enemy Infantry | $80 | 2 | 30 px/s walk | 250px | 1.0s | 0.3 | All ground | Walk from right |
| Enemy Tank | $350 | 6 | 20 px/s drive | 500px | 4.0s | 2 | All ground | Drive from right |
| Enemy APC | $250 | 6 | 40 px/s drive | 200px (MG) | 0.5s | 0.3 | Ground | Drive from right, deploys 2 infantry |
| Fighter Jet | $300 | 3 | 300 px/s fly | Bomb drop | 1 pass | 3 (bomb) | Ground (area) | Fly from right |
| Attack Helicopter | $350 | 5 | 60 px/s fly | 350px | 2.0s | 1.5 | All ground | Fly from right |
| Kamikaze Drone | $120 | 1 | 150 px/s fly | Contact | Suicide | 4 | Single target | Fly from right |

### Player Mortar (existing, unchanged)
- Player-controlled, 3 charge levels (500/600/700 power)
- 2.0s reload, manual aim
- This is the player's unique "hero weapon"

## Rock-Paper-Scissors Balance

```
Infantry RPG  ──▶ Tanks, Vehicles (high damage to armor)
Machine Gunner ──▶ Infantry, Drones (rapid fire)
Tank          ──▶ All ground (heavy but slow)
AA Gun        ──▶ Jets, Helis, Drones (dedicated anti-air)
MANPADS       ──▶ Jets, Helis (mobile anti-air)
Light Vehicle ──▶ Infantry (fast, flanking)

Fighter Jet   ──▶ Ground clusters (area bombing)
Helicopter    ──▶ Tanks, Vehicles (rockets from above)
Kamikaze Drone──▶ High-value targets (cheap, devastating if not shot down)
Enemy Infantry──▶ Player infantry (rifle fire)
Enemy APC     ──▶ Infantry delivery (spawns 2 infantry on death or arrival)
Enemy Tank    ──▶ All ground (heavy firepower)
```

### Counter Matrix
- Jets countered by: AA Gun, MANPADS, Machine Gunner (weak)
- Helis countered by: AA Gun, MANPADS, RPG infantry (weak)
- Drones countered by: Machine Gunner (primary), AA Gun
- Tanks countered by: RPG infantry, Player mortar, other tanks
- Infantry countered by: Machine Gunner, Light Vehicle, explosions
- APC countered by: RPG infantry, tanks, mortar
- Light Vehicle countered by: RPG infantry, tanks

## Air Combat Layer

Air units fly at Y=80-200 (above ground level Y=450).

**Flight behaviors:**
- **Fighter Jet:** Flies straight across screen at Y=120, drops bomb at target X, exits opposite side. Single pass.
- **Attack Helicopter:** Flies to combat zone, hovers at Y=150, fires rockets downward. Retreats when damaged.
- **Kamikaze Drone:** Flies toward nearest high-value target (tank > vehicle > infantry), dives into it.

**Anti-air targeting:**
- AA units track nearest air target within range
- Bullets/missiles travel upward to air layer
- Air units can be hit by any projectile that reaches their altitude
- Machine gunners have 20% accuracy vs air (spray and pray)

## AI Spawner (Enemy)

**Decision cycle:** Every 3 seconds, evaluate and potentially spawn.

**Strategy priority:**
1. If no ground presence → spawn infantry or tank
2. If player has many ground units → spawn fighter jet (area bomb)
3. If player has AA → spawn more ground (tanks, APC)
4. If player has no AA → spam air (helis, drones)
5. Mix in kamikaze drones as harassment (cheap, annoying)
6. Every 30s: "wave" — spend 50% of savings at once

**Spawn cooldowns:** 2s between spawns (can't spam instantly)

## Unit Entry Animations

All units enter from their side's screen edge:

- **Walking units (infantry, MG, MANPADS):** Enter at X=-30 (player) or X=1310 (enemy), walk to combat zone
- **Driving units (vehicle, tank, APC):** Enter at X=-60 (player) or X=1340 (enemy), drive to position
- **Flying units (jet, heli, drone):** Enter at X=-50 (player AA missiles) or X=1330 (enemy), at their flight altitude

Units should NOT teleport or appear in the middle of the battlefield.

## New Projectile Types

| Projectile | Speed | Gravity | Drag | Trail | Used By |
|------------|-------|---------|------|-------|---------|
| Bullet (MG) | 900 px/s | 30 | 0.05 | Yellow line, thin | Machine Gunner, APC MG |
| Bomb | 0 (dropped) | 300 | 0.02 | None, just falling circle | Fighter Jet |
| AA Missile | 500 px/s | 0 (guided) | 0 | White smoke trail | AA Gun, MANPADS |
| Helicopter Rocket | 400 px/s | 60 | 0.08 | Gray smoke | Attack Helicopter |
| Rifle Bullet | 800 px/s | 20 | 0.05 | Faint yellow line | Enemy Infantry |

## Procedural Drawing Specs

All units use `_draw()` (no sprite textures):

- **Machine Gunner:** Sandbags + soldier + MG on tripod + muzzle flash
- **Light Vehicle:** Pickup truck body + 4 wheels + mounted gun
- **Player Tank:** Green tank body + turret + barrel (mirror of enemy tank)
- **AA Gun:** Sandbag base + twin barrels rotating upward + ammo box
- **MANPADS:** Soldier kneeling + tube on shoulder + backblast effect
- **Enemy Infantry:** Soldier + rifle + muzzle flash (darker colors than player)
- **Enemy APC:** Larger armored box + 6 wheels + small turret
- **Fighter Jet:** Delta wing silhouette + engine trail + bomb falling
- **Attack Helicopter:** Fuselage + spinning rotor + rocket pods
- **Kamikaze Drone:** Small X-shape + propeller blur + red blink

## HUD Updates

- **Money display:** Top-right, "$300" with gold icon
- **Income indicator:** "+$15/s" smaller text
- **Action panel:** Expand to show all 6 player unit buttons in a row
  - Each button shows: unit icon (mini procedural draw) + cost + hotkey (1-6)
  - Grayed out + cost in red if insufficient funds
  - Hotkeys: Q, W, E, R, T, Y for quick access

## Win/Lose Conditions (stretch goal)

- **Win:** Destroy all enemy units and enemy can't afford more for 15s
- **Lose:** Enemy reaches X=50 (player base area) with ground units
- **Alternative:** Timed survival (survive 5 minutes)

For now: endless mode — just enjoy the chaos.

## File Structure

New files:
```
scripts/game/economy.gd
scripts/game/enemy_ai.gd
scripts/game/machine_gunner.gd
scripts/game/light_vehicle.gd
scripts/game/player_tank.gd
scripts/game/aa_gun.gd
scripts/game/manpads.gd
scripts/game/enemy_infantry.gd
scripts/game/enemy_apc.gd
scripts/game/fighter_jet.gd
scripts/game/attack_helicopter.gd
scripts/game/kamikaze_drone.gd
scripts/game/bullet.gd
scripts/game/bomb.gd
scripts/game/aa_missile.gd
scenes/projectiles/bullet.tscn
scenes/projectiles/bomb.tscn
scenes/projectiles/aa_missile.tscn
```

Modified files:
```
scripts/game/battle_manager.gd (major rework: dynamic unit registration)
scripts/game/infantry.gd (add walk-in, cost integration)
scripts/game/enemy_tank.gd (spawn from right edge, cost integration)
scripts/ui/action_panel.gd (6 buttons, cost display, hotkeys)
scripts/ui/hud.gd (money display)
scenes/game/battle.tscn (remove hardcoded tanks, add economy/AI nodes)
```
