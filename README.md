# RizLife Fighters

A 2D pixel fighting game about the life and works of José Rizal. Two players fight on one
screen, best of three rounds, and the loser has to answer a Rizal question.

**Fight. Answer. Remember.**

Built with **Godot 4.7** (GDScript, GL Compatibility renderer, 480×270 pixel resolution).

## Run it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, choose **Import**, and pick this folder's `project.godot`.
3. Press **F5**.

All art is placeholder blocks for now, so the game can be played and tuned before the sprites are ready.

## Controls

| Action | P1 keyboard | P2 keyboard (numpad / laptop) | Controller (proposal names) |
|---|---|---|---|
| Move / jump / crouch | W A S D | Arrow keys | D-pad or left stick |
| Light punch | F | Num 4 / K | X |
| Heavy punch | G | Num 5 / L | Y |
| Light kick | V | Num 1 / , | A |
| Heavy kick | B | Num 2 / . | B |
| Switch style / transform | H | Num 6 / ; | LB |
| Pause + move list | Esc | Num Enter / Enter | Start |

- Hold **back** to block. Low attacks need a crouching block; jump-ins need a standing block.
- Controller 1 is P1 and controller 2 is P2.
- In menus, use the arrow keys and Enter, or a controller.
- **F1** shows hitboxes (red) and hurtboxes (green). **F11** toggles fullscreen.
- To change the default controls, edit `tools/generate_input_map.gd` and run
  `godot --headless --path . -s res://tools/generate_input_map.gd`. You can also
  edit them in **Project → Project Settings → Input Map**.

Move inputs use the proposal's notation in text form:
`QCF` = ↓↘→, `QCB` = ↓↙←, `DP` = →↓↘, `[B] F` = hold back then forward, `[D] U` = hold down then up, `D, D` = down twice, `x2` = the motion twice.
Supers are `QCF x2 + X+Y` and need a full gauge.

## What's in the prototype

| Proposal milestone | Status |
|---|---|
| 1. Prototype: Rizal, one stage | Done (all 6 stages drawn as placeholders) |
| 2. Core: Lovers and Writer styles, quiz | Done: both styles, LB switching, the quiz after every match |
| 3. Content: four more fighters, stages | Ibarra/Simoun playable. Elias, María Clara and Padre Dámaso are listed as "soon". |
| 4. Polish: art, sound, playtest | Not started. Sprites and stage art drop in without code changes (see `art/README.md`). |

**Screens:** title → player names → fighter/style select → stage select → fight → Rizal question → leaderboard (rematch, select, or menu).

**Fighting engine:**
- Fixed 60 fps logic.
- Motion inputs (QCF, QCB, DP, charges, down-down, double QCF, 360) with a short input buffer.
- Normals and special cancels.
- Projectiles, counters, throws and invincible anti-airs.
- Blocking, with high/low/overhead rules.
- Hit-stop, combo counter and damage scaling.
- Style gauges (Ink, Heart, Rage), Rizal's style switching, Ibarra's Simoun transformation and supers.
- A simple CPU opponent for solo practice.

**Quiz:** a question from the stage's topic, a 20-second timer, shuffled choices and an explanation after answering.

**Leaderboard:** saved on this computer (`user://leaderboard.json`), with a separate table for each term.

## Project layout

```
data/                  Everything you'll tune or write, in JSON
  rules.json           term name, rounds, timers, points
  roster.json          the 5 fighters on the select screen
  stages.json          the 6 stages, their question topics and placeholder colours
  questions.json       the Rizal question bank
  fighters/            move lists and frame data (common_normals.json + one file per fighter)
scenes/                One scene per screen (they build their UI in code)
scripts/
  autoload/            Game (session state), Leaderboard, QuestionBank
  fighter/             Fighter state machine, input buffer, input sources (player, CPU, scripted), projectiles
  fight/               Fight (rounds, hits), HUD, Stage
  ui/                  Menus, select, quiz, leaderboard
  core/                Colours and UI helpers
art/                   Sprites and stage backdrops go here (see art/README.md)
audio/                 Sound effects and music go here
tests/                 Headless smoke test
tools/                 Input map generator
```

## Adding and tuning moves

Moves live in `data/fighters/<id>.json`, so you can tune them without touching code.
Frame counts are at 60 per second.

| Field | Meaning |
|---|---|
| `motion` | `qcf`, `qcb`, `dp`, `qcf2`, `qcb2`, `charge_bf`, `charge_du`, `dd`, `ff`, `360`, or `""` |
| `buttons` | Any of `lp` `hp` `lk` `hk`. `["lp","hp"]` means either one; `["lp+hp"]` means both together |
| `startup` / `active` / `recovery` | Frames before the hit, frames it can hit, frames until you can act again |
| `damage`, `chip` | Damage on hit / on block (specials chip 15% by default) |
| `hitstun`, `blockstun`, `push` | How long the opponent is stuck, and how far they slide |
| `hitbox` | `[x, y, width, height]` from the feet, facing right (negative y is up) |
| `height` | `mid` (default), `low` (block crouching) or `overhead` (block standing) |
| `knockdown`, `launch` | Knocks down, and how high they fly |
| `move_x` | Forward speed while the move is coming out (lunges) |
| `invuln` | `[from, to]` frames where the move can't be hit (anti-airs, supers) |
| `projectile` | `speed`, `vy`, `gravity`, `size`, `offset`, `delay`, `life`, `color`, `shape` (`rect`/`heart`/`orb`), `opacity` |
| `counter_window`, `counter_hit` | Counter stance: frames it catches attacks, and the hit it answers with |
| `type: "throw"` | Can't be blocked; grabs grounded opponents |
| `cancel` | This move can be cancelled into a special when it connects |
| `effect` | `slow` (Farewell Tears) |
| `kind: "super"`, `gauge_cost` | Super flash, and how much gauge it uses |
| `heavy` | Overrides used when the heavy button (Y or B) is pressed |

To add a fighter:
1. Copy `ibarra.json`, give it a new `id`, and write its specials.
2. Set `"playable": true` for that fighter in `roster.json`.

## Writing questions

Add entries to `data/questions.json`:

```json
{ "id": "berlin-003", "stage": "berlin",
  "question": "...", "choices": ["A", "B", "C", "D"], "answer": 2,
  "explain": "One line the player sees after answering.", "source": "Textbook p. 123" }
```

- `answer` counts from 0.
- `stage` must match a stage id, or be `"general"`.
- The 14 sample questions are placeholders. Aim for about 10 per stage, and have your instructor check them.
- The smoke test catches broken entries.

## Tests

```
godot --headless --path . res://tests/smoke_test.tscn
```

The test checks:
- motion reading
- the data files
- projectiles
- hits, blocks and lows
- counters
- style switching and Simoun
- supers
- a full 2-0 match and a time-out
- the leaderboard

It also has a CPU-vs-CPU soak run. It exits with code 0 when everything passes.

To save a screenshot of every screen (useful for slides and progress reports):

```
godot --path . res://tools/screenshots.tscn -- --out=C:/path/to/folder
```

## Open decisions

The proposal leaves these to the team. The code has a placeholder for each one, marked where to change it.

1. **What does answering the Rizal question do?** Right now the answer is recorded and shown on the
   leaderboard ("Quiz 3/4") but is worth 0 points. Set `points.quiz_correct` in `rules.json` once
   you decide, or change `Leaderboard.points()` for something like "a wrong answer costs a point".
2. **Global leaderboard.** The proposal says "global, resets every term". The prototype keeps a
   per-term board on each computer. A shared board needs a small online database (Supabase would work)
   and a way to name players. Use nicknames, not student IDs.
3. **When does a term end?** Change `current_term` in `rules.json`; each term name gets its own table.
4. **Physician style** is optional in the proposal and not built yet.
5. **PvE mode** (story stages, Padre Salvi and Sisa as bosses) is not built yet. `CpuInput` is the
   starting point for boss behaviour.

## Notes for the team

- Hit detection uses rectangles that the Fight node checks in a fixed order each frame. The proposal
  planned Area2D nodes, but their overlaps update a physics frame late, which makes trades and combos
  inconsistent. F1 shows the boxes.
- The default font is used everywhere. A free pixel font (for example one under the SIL Open Font
  License) will look much closer to the sample UI.
- Before exporting, check that `data/*.json` is included in the build (Project → Export → Resources).
