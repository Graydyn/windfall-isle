# Gizmo Rarities: Design

**Date:** 2026-09-14
**Status:** Approved by owner (brainstorm session 2026-09-14)
**Parent spec:** docs/design/2026-08-15-windfall-isles-design.md section 3.3 ("Gizmos have rarity tiers and upgrade levels")
**Roadmap item:** Phase A, "Gizmo rarities (spec 3.3)", including the Cargo Net balance rider.

## 0. Scope and intent

Rarity is an acquisition gate, nothing more. Each gizmo has one fixed rarity tier; the Workshop's building level determines which tiers can be crafted. Rarity never modifies stats: power scaling remains the job of upgrade levels (GizmoBase.scaled, +25% per level). No save schema change (stays v8). One plan (Plan 13), standard worktree cadence.

Owner decisions recorded from the brainstorm:

1. Rarity is a static tier per gizmo def (not per-copy quality, not variant defs).
2. The starting inventory shrinks to the common tier only; everything else is craft-to-acquire (the level 0 -> 1 flow shipped in Plan 6).
3. Existing saves are grandfathered: nothing owned is ever revoked. The starter change affects new games only.
4. Cargo Net buff: uses scale with level; relaunch speed stops scaling (level scaling MOVES from speed to uses, it does not stack).

## 1. Data model (gizmos.json)

Every entry in `defs` gains a `"rarity"` string. A new top-level `"rarity_unlocks"` dict maps each rarity to the minimum Workshop level that unlocks crafting it:

```json
"rarity_unlocks": {"common": 1, "uncommon": 2, "rare": 3}
```

Workshop max_level is 3 (buildings.json), so every tier is reachable.

Tier assignment (by current cost and punch):

| Rarity | Workshop Lv | Gizmos |
|---|---|---|
| common | 1 | wind_fan, balloon_cluster, cargo_net, magnet_buoy |
| uncommon | 2 | crystal_prism, lightning_jar, chime_bell |
| rare | 3 | splitter_vane, gyro_damper, piston_kicker |

`starting_inventory` becomes exactly the four commons at 1:

```json
"starting_inventory": {"wind_fan": 1, "balloon_cluster": 1, "cargo_net": 1, "magnet_buoy": 1}
```

JSON discipline as everywhere in the repo: raw values in the file, `int()`/`String()` casts at use sites, no normalization in DataDefs.

## 2. Craft gating (CraftModel)

New static helper on CraftModel:

```
static func rarity_unlocked(island: Dictionary, gizmo_defs: Dictionary, gizmo_id: String) -> bool
```

Reads the def's `rarity`, looks it up in `rarity_unlocks`, and compares against `IslandModel.building_level(island, "workshop")`. Fail-closed authoring guard: a missing or unknown rarity (absent from `rarity_unlocks`) returns false and emits `push_warning` once per call, consistent with the region-authoring guards. Tests asserting the guard declare the expected warning per GUT discipline.

`can_craft` adds `rarity_unlocked` as a new condition alongside the existing slot/duplicate/max-level/afford checks. `start_craft` inherits the gate through its existing `can_craft` call. `complete_craft` is untouched.

The helper is separate from `can_craft` so the workshop UI can distinguish "locked by rarity" from "cannot afford / no free slot" without duplicating the rule.

## 3. Save behavior

No schema bump; the save's `gizmos.owned` dict is untouched by this feature. `starting_inventory` is only consulted when creating a new save, so existing saves keep all eight originals at their current levels. No migration, no merge-grant: a save that owns an uncommon gizmo the player could not currently craft is valid (grandfathered), and its OWNED gizmos remain slottable in runs regardless of Workshop level; rarity gates crafting only.

## 4. Workshop UI (workshop_screen.gd)

The rows loop already iterates all defs. Changes per row:

- Unlocked rarity: row text appends the capitalized rarity name (e.g. `... cost: 2 parts [Common]`). Craft button as today.
- Locked rarity: the row renders with no Craft/Collect/Skip button; the label reads `<Name>  Requires Workshop Lv <N>` and the label's modulate is dimmed (alpha 0.5). Timer rows cannot occur for a locked gizmo in normal play (the gate prevents starting one), but if a running craft timer exists for a now-locked gizmo (hand-edited save), the row falls through to the normal timer rendering so the craft can complete; grandfathering extends to in-flight crafts.

Rarity lock states join the screen's refresh signature so lock/unlock transitions (Workshop upgrade completing) rebuild the rows.

## 5. Cargo Net rebalance (cargo_net.gd)

- `_configure` and `recharge`: `_uses_left = int(defs.get("uses", 1)) * level` (base uses stays 1 in JSON, so effective uses = level; Lv1 = 1, Lv5 = 5).
- `_release`: `redrop_speed` is read raw (`float(defs.get(...))`), no longer wrapped in `scaled()`. Speed is now level-independent.
- The "spent" visual dim keeps its current trigger (uses exhausted).

Rationale (roadmap rider): the net's real value is the incidental second pass through the peg field; more passes per run at higher levels leans into that identity without new aiming logic.

## 6. Testing

TDD per repo discipline. New and changed tests:

- **Defs pinning** (test_gizmo_defs or a new test_gizmo_rarity_defs): every def has a `rarity` present in `rarity_unlocks`; every `rarity_unlocks` level is an int within 1..workshop max_level; `starting_inventory` is exactly the common-tier gizmos at 1 (derived from defs, so a future tier change fails the pin deliberately).
- **CraftModel unit tests**: rarity_unlocked truth table across workshop levels 0-3 for each tier; can_craft blocked by locked rarity even when affordable; unknown/missing rarity fails closed with the declared push_warning; grandfather property (owned level > 0 with locked rarity still cannot CRAFT, and nothing else breaks).
- **Workshop screen tests**: locked row has no buttons and shows the requirement text; unlocked row shows rarity name; hand-edited in-flight craft timer on a locked gizmo still renders collect/skip; lock state changes are caught by the refresh signature.
- **Cargo Net**: unit test that `_uses_left` equals level at configure and after recharge; assert relaunch speed is unscaled (Lv > 1 pod velocity magnitude equals defs value); the standing rule applies: one integration proof driven by REAL contact (existing contact test extended for a Lv2 net catching twice).
- **Run/loadout regression**: existing tests that assume 8 starters must be updated to the new inventory or construct owned dicts explicitly (the Plan 4 note "revisit the hardcoded 8-starter test when the Workshop becomes the faucet" comes due here).

## 7. Out of scope

- New gizmos, new rarity tiers beyond three, and region 3+ recipes (future regions slot into the same fields).
- Rarity-based stat scaling, craft-cost scaling, or merge-rule changes.
- Loadout/setup-phase UI changes: chips render owned gizmos exactly as today (rarity coloring belongs to the art pass).
- Boon pool interactions (tripwire items remain tied to regions 3+ work).
