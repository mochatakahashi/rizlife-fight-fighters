# RizLife Fighters

A 2D fighting game about the life and works of José Rizal. Two players fight on one
screen, best of three rounds, and the loser has to answer a Rizal question.

**Fight. Answer. Remember.**

Built with **Godot 4.7** (GDScript, GL Compatibility renderer). The game is laid out on a 480×270 grid and drawn sharp at any window size.

## Run it

1. Install [Godot 4.7](https://godotengine.org/download) (the standard build, not .NET).
2. Open Godot, choose **Import**, and pick this folder's `project.godot`.
3. Press **F5**.

Every character is drawn in code, dressed in their own costume (see **Characters and costumes**). Hand-drawn sprites can replace them later without code changes.

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
- **Mouse:** click buttons, fighters, styles, stages and quiz answers. On the select screen, right-click undoes a pick.
- In menus you can also use the arrow keys and Enter, or a controller.
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
| 1. Prototype: Rizal, one stage | Done, with all 6 stages drawn |
| 2. Core: Lovers and Writer styles, quiz | Done: both styles, LB switching, the quiz after every match |
| 3. Content: four more fighters, stages | Done: all five fighters are playable (Rizal, Ibarra/Simoun, Elias, María Clara, Padre Dámaso) on six stages |
| 4. Polish: art, sound, playtest | Art: dressed, animated characters, lit stages, hit effects, a modern HUD and screen fades. Sound and playtesting are not started. |

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

## Characters, costumes and weapons

Every character is drawn by `scripts/art/character_art.gd` in a costume from `data/looks.json`. Each one fights with something from their story.

| Fighter | Costume (from the sources) | Fights with | Moves |
|---|---|---|---|
| José Rizal | Black suit, white high collar, dark tie, moustache | **His pen.** Writer style holds a quill and fires Quill Flick, swings the *Noli* (counter) and the *Fili* (rush), and *Mi Último Adiós* is a glowing page of verse. Lovers style calls his nine loves. | Writer: Quill Flick, Noli Me Tangere, Fili Rush, Rally, Century Hence, *Mi Último Adiós*. Lovers: one move per love. |
| Ibarra / Simoun | Ibarra: "dressed in deep mourning", "remarkable stature". Simoun: pith helmet, "enormous blue goggles", long white hair, sparse black beard, English fashion | Ibarra: the knife he seized at the banquet (Knife Grab) and a book (his school). Simoun: the lamp bomb from the wedding in *El Fili*. | Knife Grab, Scholar's Stance; Simoun: Lamp Bomb, Gold Shower, Vengeance |
| Elias | Athletic, long unkempt black hair, dark striped shirt, barefoot | **His oar**, the "wide paddle" he steers with in the *Noli* | `QCF + A/B` Oar Sweep (low), `F, F + A/B` River Dash, `QCF x2 + X+Y` Sacrifice (costs him 100 health) |
| María Clara | Piña baro't saya with tapis, pearls in her hair, skin "white as cotton" | Her fan, her locket, her veil and the convent bell | `QCB + X/Y` Veil Counter, `QCF + X` Locket Throw, `QCF x2 + X+Y` Convent Bell (a growing shockwave) |
| Padre Dámaso | Franciscan habit and cord, graying tonsure, "herculean frame", bare feet | His hands (a grappler) and his sermon | `360 + X` Sermon Slam (command grab), `[D] U + A/B` Pulpit Pound (overhead), `QCF x2 + X+Y` Hell Sermon (book raised, fire-and-brimstone shockwave) |

Padre Salvi ("thin, wasted, and pale") and Sisa are drawn too, ready for PvE.

### Rizal's nine loves

In Lovers style each special calls one of them. Rizal steps out, she does the move with her name and where he knew her over her head, and then he steps back in. On the select screen, hover over her face to see a short fact.

| Love | Where | Fact shown in the game | Outfit |
|---|---|---|---|
| Segunda Katigbak | Lipa, Batangas | His first love (c. 1877); already engaged to Manuel Luz | Baro't saya (she is short and rosy-cheeked, from Rizal's *Memorias*) |
| Leonor Valenzuela ("Orang") | Manila | Rizal *reportedly* wrote her notes in invisible ink (textbook only) | Baro't saya |
| Leonor Rivera | Camiling, Tarlac | Signed her letters "Taimis"; often seen as María Clara's model | Baro't saya |
| Consuelo Ortiga y Pérez | Madrid | He wrote her a poem in 1883. Craig gives the title as "A la Señorita C. O. y **R.**" | Bustle dress, lace mantilla |
| O-Sei-San (Usui Seiko) | Tokyo | His guide in 1888; they talked in French | Meiji-era kimono, katana |
| Gertrude Beckett ("Gettie") | London | His landlord's daughter; he carved the sisters' heads (textbook only) | 1880s bustle dress |
| Nelly Boustead | Biarritz | "Had great skill with the foils" (Craig) | Dress, fencing foil |
| Suzanne Jacoby | Brussels | "Petite Suzanne" wrote him longing letters. **Disputed:** she may have been the landladies' niece, Suzanne Thill. | 1890 dress |
| Josephine Bracken | Hong Kong; Dapitan | Brought her blind adoptive father to Rizal in Dapitan (1895) | 1890s blouse with leg-of-mutton sleeves |

Each look in `looks.json` has a `documented` line separating what the sources say from what is just likely for the period. Have your instructor check the facts, especially the ones marked textbook-only or disputed.

**Sources:**
- Novel descriptions: the *Noli Me Tángere* and *El Filibusterismo* English translations by Charles Derbyshire, on Project Gutenberg ([6737](https://www.gutenberg.org/ebooks/6737), [10676](https://www.gutenberg.org/ebooks/10676)).
- Life details: Austin Craig, *Lineage, Life and Labors of José Rizal* (1913, [Gutenberg 6867](https://www.gutenberg.org/ebooks/6867)), Wikipedia, the Philippine Diary Project (Consuelo), UP (O-Sei-San) and Philstar (the Suzanne correction).
- Several popular details trace back to Zaide's textbook, which is worth checking in print.

### Editing costumes

A look can start from another with `"base"`, and `"alt"` gives player 2 different colours in mirror matches. Parts:
- `top`: `suit`, `camisa`, `baro`, `habit`, `bodice`, `kimono`
- `bottom`: `trousers`, `rolled`, `skirt`, `robe`, `kimono`
- `feet`: `shoes`, `barefoot`, `sandals`, `geta`
- `hair_style`: `side_part`, `wavy`, `short`, `long`, `long_white`, `bun`, `updo`, `japanese`, `tonsure`
- extras: `headwear` (`pith_helmet`, `salakot`, `mantilla`), `eyewear` (`blue_goggles`), `facial_hair`, `neckwear`, `vest`, `frock`, `shirt_stripe`, `hair_pearls`, `boutonniere`, `locket`, `accessory`

A move's `prop` puts a weapon in the hand: `quill`, `book`, `knife`, `lamp`, `oar`, `fan`, `katana`, `foil`, `scalpel`.
Run `godot --path . res://tools/screenshots.tscn` to get `00_costumes.png`, every costume side by side.
## Project layout

```
data/                  Everything you'll tune or write, in JSON
  rules.json           term name, rounds, timers, points
  roster.json          the 5 fighters on the select screen
  stages.json          the 6 stages, their question topics and colours
  looks.json           every character's costume, including Rizal's nine loves
  questions.json       the Rizal question bank
  fighters/            move lists and frame data (common_normals.json + one file per fighter)
scenes/                One scene per screen (they build their UI in code)
scripts/
  autoload/            Game (session state), Leaderboard, QuestionBank, Transition (screen fades)
  art/                 CharacterArt (draws the dressed characters), Gfx (glows, gradients, panels)
  fighter/             Fighter state machine, input buffer, input sources (player, CPU, scripted), projectiles
  fight/               Fight (rounds, hits), HUD, Stage, FightFx (sparks, dust)
  ui/                  Menus, select, quiz, leaderboard
  core/                Colours and UI helpers
art/                   Sprites and stage backdrops go here (see art/README.md)
audio/                 Sound effects and music go here
tests/                 Headless smoke test
tools/                 Input map generator, screenshot tool
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
| `projectile` | `speed`, `vy`, `gravity`, `size`, `offset`, `delay`, `life`, `color`, `shape` (`rect`/`orb`/`heart`/`quill`/`letter`/`ink`/`tear`/`lamp`/`pillar`), `opacity` |
| `counter_window`, `counter_hit` | Counter stance: frames it catches attacks, and the hit it answers with |
| `type: "throw"` | Can't be blocked; grabs grounded opponents |
| `cancel` | This move can be cancelled into a special when it connects |
| `effect` | `slow` (Farewell Tears) |
| `kind: "super"`, `gauge_cost` | Super flash, and how much gauge it uses |
| `heavy` | Overrides used when the heavy button (Y or B) is pressed |
| `assist` | One of Rizal's loves (a look id) steps in and does this move while Rizal steps out |
| `prop` | Something held during the move: `katana`, `foil`, `knife`, `quill`, `fan`, `lamp`, `book` |
| `anim` | Force a body animation, e.g. `uppercut`, `lunge`, `sweep`, `cast` |

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
4. **Physician style** is optional in the proposal and not built yet (a scalpel prop is ready for it).
5. **PvE mode** (story stages, Padre Salvi and Sisa as bosses) is not built yet. `CpuInput` is the
   starting point for boss behaviour.

## Notes for the team

- Hit detection uses rectangles that the Fight node checks in a fixed order each frame. The proposal
  planned Area2D nodes, but their overlaps update a physics frame late, which makes trades and combos
  inconsistent. F1 shows the boxes.
- Before exporting, check that `data/*.json` is included in the build (Project → Export → Resources).
