# Intelligence Package

## Overview

The `Intelligence/` directory contains the **data-driven knowledge layer** of PB: Healing Frames.
It bridges the gap between static spell databases and the dynamic, classless environment of
Ascension: Area 52, where any player can learn any spell and Mystic Enchants rewrite ability rules.

## Files

| File | Purpose |
|---|---|
| `Data_Seed.lua` | **Runtime source of truth** — loaded every session. Contains spell IDs, role mappings, aura names, enchant markers, SmartBind priorities, and engine overrides. |
| `Init.lua` | **Defensive fallback bootstrap** — runs if `Data_Seed.lua` fails to load or is missing. Contains an identical copy of all intelligence tables and a `deepCopy` mechanism. |

## Design Rationale: Seed vs. Fallback

### Why Two Copies?

Ascression actively adds new spells, enchants, and IDs. Updates to the addon often ship
**only** as changes to `Data_Seed.lua`. However, because the addon loads at `PLAYER_LOGIN`,
memory corruption or file-missing errors during load are possible on a private server.

The `Init.lua` fallback guarantees the addon never crashes from missing intelligence data.
It is the **last line of defense**, not the preferred runtime source.

### Load Order & Resolution

```
1.  Load Data_Seed.lua  ->  ns.HealingIntel = { ... }
2.  Load Init.lua        ->  copyMissing(ns.HealingIntel, fallbackIntel)
                           -- Adds any keys that Data_Seed missed
                           -- Never overwrites existing (seed wins)
3.  indexRoleTables()    ->  ns.HealingIntel.knownSpellRolesById[spellId]
                           ns.HealingIntel.knownSpellRolesByName[lowerName]
```

### The `copyMissing` Contract

`Init.lua` uses a non-destructive merge:
- **If a key exists from `Data_Seed`**: keep it (seed wins).
- **If a key is absent from `Data_Seed`**: copy from fallback.
- **Nested tables**: deep-checked and merged recursively.

```lua
local function copyMissing(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            copyMissing(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end
```

### The `ns.HealingIntelDefaults` Snapshot

`Init.lua` stores a **deep copy** of the fallback intelligence as `ns.HealingIntelDefaults`.
This is used internally when an intelligence table must be reset to factory defaults.

## Key Data Structures

### `knownSpellRolesById` / `knownSpellRolesByName`

Both tables are populated at load time in `Init.lua:indexRoleTables()`:
- **By ID**: maps numeric `spellId` to role string (e.g., `139 -> "hot"`).
- **By Name**: maps `string.lower(spellName)` to role string.

These are the primary lookup tables for `SpellBook.lua` (tooltip scanning) and `CombatLog.lua` (proc classification).

### `enchantMarkers`

Maps enchant identifiers to observable signals:

```lua
enchantMarkers = {
    [enchantId] = {
        auras = { "PlayerAuraName" },         -- checked by UnitAura("player")
        replaces = { base = "Fear", override = "Fear (Mass Hysteria)" },
        triggersFrom = { "Smite" },           -- for combat-log proc edges
        modifies = { "Power Word: Shield" },
        threshold = { spell = "PW:S", hpPct = 0.75 },
        engineHint = "damage_to_heal",         -- hints BuildState.lua classification
    }
}
```

### `smartBindPriorities` vs. `engineSmartBindOverrides`

- **`smartBindPriorities`**: Default button mapping used when `BuildState` cannot determine an engine.
- **`engineSmartBindOverrides`**: Per-engine mappings that override defaults when a build engine is confidently detected (e.g., Atonement build puts Smite on LeftButton instead of Flash Heal).

## For Contributors

### Adding a New Ascension-Only Spell

1. Check if the spell exists in `Data_Seed.lua`.
2. If not:
   - Add its **ID** to the appropriate `roleSpellIds` table.
   - Add its **name** to the appropriate `roleSpellNames` table.
   - If it should appear on unit frame indicators, add it to `trackedAuras` or `enchantMarkers`.
3. Mirror the same entry in `Init.lua` (as a fallback copy).
4. Run `/pb scan` in-game to trigger a re-index.

### Using the Intel Listener System

Modules can subscribe to intelligence updates (e.g., after a `/pb scan` or aura sampling):

```lua
ns:RegisterIntelListener(function(reason)
    -- Rebuild internal caches when intelligence updates
    MyModule:RebuildCache()
end)
```

This is used by `Auras.lua` to rebuild tracked aura names when new samples are discovered.

## Metadata

- **Intel source** at runtime: `ns.HealingIntel.meta.source` (value = `"seed"` or `"fallback"`).
- **Realm target**: Area 52 Free-Pick (3.3.5a, classless, TBC-capped).
- **Never assume class implies role**: all lookups are by spell ID or spell name, never by `UnitClass`.
