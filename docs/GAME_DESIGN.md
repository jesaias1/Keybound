# Game design

Tiny critters physically run across a giant keyboard, typing words through
movement while the keyboard jams and reopens beneath them.

## Pillars

Move · plan routes · preserve keys · jump over keys · use Escape as a risky
emergency teleport · choose smart starting positions · type · get the team to
Enter · win.

## Core loop

1. **Select.** The target word is shown. Every player steers a cursor across
   the keyboard and locks in a starting key.
2. **Play.** Stepping or landing on a key *presses* it. Pressing your team's
   next letter types it.
3. **Jam.** When the last critter leaves a normal key, it jams for
   `KEY_COOLDOWN` (5 s). A jammed key is a wall to walkers; jump onto one
   and you are out.
4. **Keep moving.** Stand on one normal key for `KEY_STAND_LIMIT` (5 s) and
   it drops you.
5. **Enter.** With the word typed, the whole living team must stand on Enter
   together for `ENTER_HOLD` (5 s). Then it slams and the word is sent.

## Key states

One authoritative enum per key (`KeyState.State`), owned by `KeyLockBoard`:

| State | Meaning |
| --- | --- |
| AVAILABLE | Free to step on. |
| OCCUPIED | One or more critters are standing on it. |
| COOLDOWN | Jammed. Walkers are blocked; landing a jump on it is fatal. |
| SPECIAL | Enter, Escape, Shift, Caps, Unjam, Revive, Space: never jams. |
| DISABLED | Out of play (reserved for future modifiers). |

Any number of critters may share a key. It jams exactly once, when the last
one leaves. Letters, digits, punctuation and the plain keys (Tab, Ctrl, Alt,
Fn, Menu) jam; the special keys do not.

## Pressing and typing

- A press happens on **walking onto** a key, **landing** on it, or **hopping
  in place** on it (that is how double letters are typed).
- Next letter of your word → typed.
- A letter the word still needs *later* → **burned** ("TOO EARLY!"): nothing is
  typed and the key will jam when you leave. This is the game's mistake, and
  it is loud on purpose.
- The right key under the wrong Shift state → "NEEDS SHIFT!" / "RELEASE SHIFT!".
- Anything else is just a footstep (and a future jam).

There is no text buffer to corrupt and nothing to backspace: the keyboard
itself is the punishment.

## Jumping

Space / A. A full jump clears roughly one key; a running jump from a key's far
edge clears two; a tap is a short hop to the neighbour. Keys passed over in
the air are never occupied, pressed, typed or jammed. Only the landing counts.

Jumps commit. Landing on a jammed key, or off the keyboard, takes the critter
out. Walking can never kill: jammed keys and the keyboard's edge are walls. Two forgiveness rules keep that readable: a landing within
`LAND_FORGIVENESS` of a free key is nudged onto it, and a key that jammed
within the last `LOCK_GRACE` (0.3 s, i.e. while you were already in the air)
is still safe. The key under an airborne critter is outlined, red if jammed.

## The stand limit

A critter that stays on the same letter, digit, punctuation or plain key for
`KEY_STAND_LIMIT` is dropped and the key jams. Hopping in place does not
reset the clock; only reaching a different key does. From 40% a rim closes
around the key with a countdown over the critter's head, and the last two
seconds tick and rattle. Special keys (Space, Shift, Caps, Esc, Unjam, Ctrl,
Revive) have no limit, so they are the only places to wait. **Enter obeys the
limit too**, except while the whole living team is on it with the word typed:
then the victory countdown replaces the stand clock. The clock is
paused while every neighbouring key is jammed, so being boxed in is never an
unavoidable death.

## Pushing

Walking into another critter shoves it one key away; coming down on one from
a jump shoves it two. It works on teammates and opponents alike. A shoved
critter leaves its key (which jams) and presses the key it lands on. A push
never kills: if the landing spot is jammed, the critter comes down on the
nearest free key, and nobody is ever thrown off the keyboard. **Enter is
sturdy ground**: a shove there only budges a critter about a third of a key
(a little more from a jump), so it takes several to work someone off it. Both sides get a short
`PUSH_COOLDOWN`.

## Out, and REVIVE

A critter that is out stays out for the round. A living teammate standing on
REVIVE (the former super key) for `REVIVE_HOLD` (5 s) brings every fallen
teammate back on that key. A team of one (solo practice, 1v1) has nobody to
hold REVIVE, so its player serves the same five seconds as a penalty and
returns alone. If a whole team of two or more is out, co-op fails the round and
War hands it to the other team. Enter only needs the players still alive.

## Special keys

- **ESC — warp.** Pressing a charged Escape teleports the presser to a random
  key that is AVAILABLE, unjammed, unoccupied and an ordinary typing key. The
  arrival is a real landing: the key becomes OCCUPIED, jams when left, and
  types if it happens to be the needed letter. Escape then recharges for
  `ESCAPE_COOLDOWN` (10 s) for everyone. If no destination exists it fails
  safely and keeps its charge.
- **UNJAM (Backspace).** Clears every jam on the board, then recharges for
  `UNJAM_COOLDOWN` (20 s). Shared; helps both teams in War.
- **SHIFT and CAPS LOCK** belong to the whole keyboard and behave like a real
  one, for every player on every team. Shift is held while anyone stands on
  it; Caps Lock toggles each time it is pressed. Letters are capital when
  exactly one of the two is active (Shift on top of Caps Lock gives lowercase
  again). Symbols and digits change only while somebody stands on Shift, so
  "!" and "?" always need a second critter; Caps Lock never makes them. Solo
  practice is never dealt a phrase that needs one. Keycap legends always show
  what a press would type right now, and the target word shows its real case.
- **CTRL — scramble (War).** A team standing on either Ctrl for
  `SCRAMBLE_HOLD` (10 s, drains when left) throws every opponent to a random
  free key, each a different one. Arriving is a real landing. In co-op Ctrl is
  simply a safe key.
- **TAB — dash.** Pressing a charged Tab slides the critter along the whole
  row to its far key in `DASH_TIME`. Nothing passed over is pressed or jammed,
  anyone in the way is bowled out of the row, and the landing is never fatal.
  Shared `DASH_COOLDOWN` (4 s).
- **SPACE.** Never jams: a safe highway along the bottom, and it types " ".
- **ENTER / REVIVE.** Described above. Hold progress drains at `HOLD_DRAIN`×
  when broken rather than resetting.

## Critter perks

| Critter | Perk | Effect |
| --- | --- | --- |
| PIP | Spring Legs | Jump velocity x `PERK_JUMP_BOOST` (1.1). |
| DOT | Patient | Stand limit is `PERK_STAND_LIMIT` (7 s) instead of 5. |
| BUN | Spare Escape | `PERK_SPARE_ESCAPES` (1) Escape per round that ignores the shared recharge. |
| MOSS | Anchored | Cannot be pushed or bowled by a dash (Ctrl still scrambles). |

## Replay

The last `REPLAY_SECONDS` of every round are recorded as the same snapshots
online guests receive, and played back at `REPLAY_SPEED` (half speed) under a
compact result card. Any player can jump to skip it. Online guests see it too.

## Game set-up and add-ons

The host chooses everything in GAME SET-UP (local lobby or the online room);
online, the host's choices are sent to every guest. Choices are saved.

Rules (on by default): critter perks, pushing, replay. Round clock: tight
(x0.75), normal, relaxed (x1.5). War length: first to 2, 3 or 5. Key jam time:
short 3 s, normal 5 s, long 7 s. Stand limit: tight 4 s, normal 5 s, lax 7 s,
or off (DOT's perk adds `PERK_STAND_BONUS` to whatever is chosen).

Add-ons are extras on top of the basic game and are **all off by default**:

| Add-on | What it does |
| --- | --- |
| Golden key | One letter after the first is golden. Typing it adds `GOLDEN_TIME_BONUS` (6 s) in co-op, or cuts that team's Enter hold by `GOLDEN_HOLD_CUT` (1.5 s) in War. |
| Combo | Letters typed within `COMBO_WINDOW` (3 s) chain. Each link past the first cuts the Enter hold by 0.5 s (best chain of the round counts). |
| Power-ups | Every ~9 s a free number-row key lights up for 7 s. Stepping on it grants one of: speed (5 s), push shield (8 s), frozen stand timer (6 s). |
| Row jams | Every 16 s a random row flashes for 2.5 s, then every empty key in it jams. Critters standing there are unharmed. |
| Caps storm | Caps Lock flips by itself every 12 s, with a 2 s warning. |
| Sabotage | War only: UNJAM deletes the other team's last typed letter instead of clearing jams. |

Bonuses never shorten the Enter hold below `MIN_ENTER_HOLD` (2.5 s).

## Start selection

Only letters, digits and punctuation can be chosen, and never a key that any
team's word needs, so nobody spawns on a target letter. Teammates may share a
start key. In War, opponents may not: the first team to lock a key owns it.
Unconfirmed cursors lock in after `SELECT_DURATION`. Spawning types nothing.

## Co-op

The round clock is short: `PHRASE_BASE_TIME` 14 s + 4.5 s per character + 4 s
per capital ("cat" 28 s, "hello world" 64 s). War rounds are 90 s. Any
player can jump to skip a result card. In the local War lobby each player
picks a side with left / right on their own device.

Five rounds, one phrase per tier (short words → spaces → repeats → Shift →
Caps and shifted punctuation). A round fails on the timer or a full wipe.
Stars: sent, clean route (≤1 burn, nobody out), fast.

## Hopkey: WAR

1v1 or 2v2 on one keyboard, on one PC or online (LAN or internet); teams
alternate by join order. Each team gets its
own word. Jams, Escape and Unjam are shared, so routes interfere; presses and
Shift/Caps belong to the presser's team. First team to type its word and hold
Enter for five seconds wins the round; first to `WAR_ROUNDS_TO_WIN` (3) wins.
A round that times out goes to the team further through its word.

Fair words come from `WordMetrics`: per word it measures length, keyboard
travel, average and longest step, repeats, adjacent doubles, re-locks (a
letter needed again while its key would still be jammed), spread, direction
reversals and Shift count, then combines them into a physical score.
`PhraseCatalog.fair_word_pair(rng, difficulty, length)` only pairs words with
equal length, Shift count, doubles and re-locks whose travel and score are
within tolerance.

## Accessibility

Players are identified by number tag, silhouette accessory and belly symbol,
not colour alone. Jammed keys use a padlock, chevrons and a sunk cap as well
as tint. Settings: volumes, rumble, camera shake, reduced motion / flash.
