# AHURA

A Godot 4 (v4.6.3) 2D action game inspired by Hollow Knight.

## Controls

| Input | Action |
|---|---|
| A/D or Left/Right | Move |
| Space | Jump |
| Shift | Dash |
| Click / F | Attack |
| F | Run (held) |

## Project Structure

```
scripts/
  player/          -- PlayerController, state machine (7 states)
  enemies/         -- Enemy base class hierarchy (Enemy > GroundEnemy/FlyingEnemy > specific enemies)
  vfx/             -- Blood VFX (procedural particles + spritesheet splash)
  ui/              -- HUD (health display)
scenes/
  entities/        -- player.tscn, enemy .tscn files
  vfx/             -- blood.tscn
  world/           -- map.tscn
assets/
  sprites/         -- player animations, enemy sprites, VFX spritesheets
```

## Features

- CharacterBody2D player with 7-state machine (Idle, Run, Jump, Attack, Dash, Hurt, Dead)
- Variable-height jump with buffer (0.1s) and coyote time (0.08s)
- Dash with horizontal-only movement and cooldown
- Melee attack with hit-stop, camera shake, and slash VFX
- Blood burst VFX (GPUParticles2D procedural circle + spritesheet splash overlay)
- Enemy hierarchy with shared hurtbox/hitbox pattern and take-damage pipeline
- 3 enemy types: Bat (flying), SoulEcho (ground melee, 6-state AI), NightBorne (ground melee)

## Collision Layers

1. Player body
2. Enemy body
3. Player AttackArea
4. Enemy Hurtbox
5. Enemy Hitbox
