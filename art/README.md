# Art

The game draws placeholder blocks until real art is here. Art drops in without code changes.

## Fighters: `art/fighters/<id>/frames.tres`

1. In Godot, create a **SpriteFrames** resource and save it as `art/fighters/rizal/frames.tres`
   (use the fighter's `id` from `data/roster.json`).
2. Add animations with these names. Any that are missing fall back to `idle`.

| Animation | When it plays |
|---|---|
| `idle`, `walk_forward`, `walk_back`, `crouch`, `jump` | Moving around |
| `block`, `crouch_block`, `hit`, `knockdown`, `getup`, `ko`, `win` | Reactions |
| `style_switch` | Rizal changing style, Ibarra becoming Simoun |
| `lp` `hp` `lk` `hk`, `c_lp` … `c_hk`, `j_lp` … `j_hk` | Normals (standing, crouching, jumping) |
| Each special's `id`, e.g. `quill_flick`, `segunda`, `knife_grab` | Specials and supers |

Rules that keep sprites lined up:

- Draw every frame **facing right**. The game flips them.
- Use **one canvas size per fighter** (e.g. 96×96), with the **feet at the bottom centre**.
- Use transparent PNGs. Keep the texture filter on Nearest (already the project default).
- The game runs at 480×270. Placeholder fighters are about 70 px tall, and the hitboxes in
  `data/fighters/*.json` are sized for that. If your sprites are taller, scale the hitboxes to match
  (press F1 in a match to see them).
- Match animation lengths to the move's `startup + active + recovery` frames at 60 fps.
  For example, a 4 + 3 + 7 light punch is 14 frames.

Simoun can use Ibarra's file with Simoun-named animations, or later get his own form sprites.

## Stages: `art/stages/<id>.png`

- One 480×270 PNG per stage, named after its id: `calamba`, `manila`, `madrid`, `paris`, `berlin`, `dapitan`.
- The floor line is at **y = 228**. Fighters stand on it.
- Keep the top 45 px and bottom 20 px calm so the HUD stays readable.
