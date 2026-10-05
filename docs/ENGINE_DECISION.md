# Engine decision

Status: locked for Phase 0/1  
Decision date: 2026-07-29  
Chosen engine: Godot 4.7.1 Standard (GDScript)

## Decision

Use the pinned Godot 4.7.1 Standard. It is
royalty-free under the MIT license, is self-contained on Windows, and provides
the CharacterBody2D, controller, UI, resource, signal, and high-level multiplayer
features needed by this vertical slice. GDScript and Godot's text scene/resource
formats make fast solo iteration and reliable automated repository edits simple.

## Alternatives considered

### Unity 6 LTS

Unity has mature profiling, an extensive asset ecosystem, strong console paths,
and established networking packages. It is materially heavier for this scope:
package/version coordination, longer editor iteration, more generated metadata,
and licensing/business-model exposure add maintenance cost. None of its
advantages is required to prove local occupation, movement, collapsing keys, and
shared phrase rules.

### Godot 4.x

Godot has quick startup/import, capable 3D, straightforward per-device joypad
input, flexible UI, Windows export, no royalties, and no required package stack.
Its smaller ecosystem and less turnkey commercial networking are acceptable
because online play is explicitly out of Phase 1.

## Future networking approach

Use Godot's high-level multiplayer API with ENet for peer transport and a
host-authoritative simulation. The host owns phrase state, occupation completion,
key transitions, repairs, capitalization, score, timers, spawns, and match flow.
Clients send timestamped input intents and receive authoritative snapshots/events.
Local play already routes input through player-device adapters into an
authoritative MatchController rather than letting UI or player scenes edit rules.
The owner authorized browser online implementation on 2026-10-06.

## Limitations

- Windows supports local couch play; browser builds also support online rooms.
- Keyboard/controller mappings may vary by platform and require hardware checks.
- Primitive runtime visuals prioritize readability over production art.
- The 2D support/jump model and controller edge cases require physical group playtesting.
- Export templates are a separate local download.

## Dependencies

No Godot plugins. Native development requires Godot 4.7.1 Standard and export
templates. Browser deployment uses Node >=22, the pinned Convex SDK, Convex Free
and browser-native WebRTC with free STUN. No paid service.

