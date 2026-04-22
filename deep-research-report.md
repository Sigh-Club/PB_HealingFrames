# Mystic Enchants on Area 52 Free Pick and what they imply for next‑gen healing addon engineering

## Environment and constraints that shape every build

Area 52 is a **classless, Free Pick** realm running on a **3.3.5a (Wrath-era) client** but with **The Burning Crusade-style progression**, including a **level 70 cap** and TBC endgame content. This matters for addon engineering because (a) most of the underlying UI and combat API is the WotLK-era addon API and secure execution model, while (b) the realm’s “classless” systems add layers of *non-class* build identity that addons must infer from **spells, auras, and custom enchant states**, not from `UnitClass`.

On Classless/Free Pick realms, players assemble their toolkit using **Ability Essence** and **Talent Essence** currencies (earned as you level), and abilities have per-ability costs (often 1–6). The same public documentation also describes **rarity gem / rarity-token style constraints** for abilities and masteries (to discourage “all legendary” toolkits) and describes that learning one member of a mastery can change costs for related abilities. For addon devs, the important consequence is: **“class” is not the source of truth for role**. The API still returns something in `UnitClass`, but Ascension’s ecosystem has historically required special handling (e.g., community-maintained UI forks note server-side “class name” changes such as “DRUID > HERO” in at least one historical compatibility cycle). Even if that specific mapping has changed since then, it’s a strong signal that **hard-coding class-based assumptions is brittle**.

## How the Mystic Enchant system works from a gameplay perspective

### Confirmed mechanics

Across Ascension’s public documentation, Mystic Enchants (also called “MEs” or “REs”) are described as a **core build-defining system** that can:

- **Change core spells**, **add new spells**, or provide passive/stat-style effects. - Be managed from a dedicated UI tab inside the Character Advancement interface (default keybind `N`) and via Mystic Altars (open-world fixed locations and player-summoned altars). - Be collected via scrolls, reforging, open-world discoveries, and auction-house trading; and be **saved to a permanent collection** using a currency called **Mystic Extracts**. A major redesign made Mystic Enchants **slot-based rather than gear-tied**: all characters have **17 slots** to apply Mystic Enchants “regardless of the gear you wear.” The same redesign explicitly aimed to remove friction related to prestiging and swapping gear, since enchants no longer have to be kept aligned with specific equipment pieces. Public wiki documentation for Mystic Enchants also states clear rarity rules (these are **core for inference and addon logic**):

- **Legendary** enchants are “in most cases” the base of a build; you can have **one active at a time**. - Legendary enchants “often replace your chosen abilities with modified versions,” making the original versions unusable. - **Epic** enchants can transform spells, grant conditional buffs, or grant new spells, and you’re **limited to 3 unique epic enchants**. - **Rare and Uncommon** enchants are smaller benefits; each individual Rare/Uncommon enchant can be used up to **three times** unless stated otherwise in the tooltip. Separately, a long-running official guide (from the earlier gear-based era) also documents the **“stacks up to 3”** rule and the “legendary does not stack” principle. Finally, there is a concept of **loadouts/presets**: a public guide describes “Mystic Enchant presets” stored in slots, with spellbook actions such as “Activate Preset” and “Save Mystic Enchantment Preset …”. Even if the implementation has evolved since the shift to slot-based enchants, it confirms that **“enchant loadout” is an explicit gameplay object** players swap.

### The “spell replacement” concept is not hypothetical

The public sources provide multiple concrete examples of “replacement/override” behaviour:

- “Mass Hysteria” turns **Fear** into an empowered “Fear (Mass Hysteria)” variant, which is functionally a spell replacement. - Multiple “Power Word: Shield revamp” enchants explicitly rewrite the behaviour of **Power Word: Shield** and its supportive talent/enchants, including new threshold/absorb rules, cooldown changes, and procs. - Atonement is explicitly described (in a Legendary list) as a damage-to-heal mechanic tied to **Smite**, **Holy Fire**, and **Penance**, healing allies affected by **Grace**. For heal/support addons, these examples justify a key design assumption:

> The “healer kit” on Area 52 is frequently not just “a list of baseline heals”, but a **baseline spell + enchant-defined rewrite** of that spell’s rule set.

### Visual support

## How Mystic Enchants likely work technically on a 3.3.5a client

This section separates **confirmed** from **inference**. The server is proprietary, so we can only infer implementation strategies consistent with: (1) the 3.3.5a client’s capabilities, (2) how private servers typically implement custom systems, and (3) what is observable through tooltips/combat log/spellbook.

### Confirmed observables relevant to reverse engineering

- Players can show **IDs in tooltips** via an in-game setting (“Interface → Help → Show id in tooltips”). - A community screenshot in that same thread suggests tooltips may show both an “ID” and another identifier (“CharacterAdvancement ID”), implying there may be at least **two distinct IDs** in the ecosystem: a spell/item ID and a “Character Advancement” internal ID. - Mystic Enchants can be **applied/extracted/reforged** via UI flows, and enchants persist in a collection. - Legendary enchants can render a “non-modified spell unusable” by replacing it. These observables constrain the likely technical designs seen by addons.

### Likely implementation patterns

#### Spell replacement via “teach new spell + disable/override old spell”
**Most consistent with**: “Fear transforms into Fear (Mass Hysteria)” and “replaces your chosen abilities with modified versions.” Typical WotLK private-server approaches compatible with what addons observe:

- The enchant grants a passive “marker” aura and the server intercepts casts of the base spell, rewriting them to cast a different spell ID.
- The enchant teaches a separate spell ID (new name / new icon / new tooltip) and removes the original spell from the player spellbook (or makes it unusable) while the enchant is active.

**Addon implication:** “Which spell is actually being cast” must be derived from **combat log events** and/or the current **spellbook list**, not from static class tables.

#### Passive auras + proc scripts (“hidden aura” + server logic)
**Most consistent with**: enchants like Atonement, which trigger healing based on damage spells and an aura condition (“affected by Grace”). Common designs:

- Apply a passive aura on the player (possibly hidden) which registers a proc on certain spell families or explicit spell IDs.
- When an eligible event occurs (damage from specific spells), the server triggers a healing spell on some target set (e.g., allies with Grace).

**Addon implication:** you may never see an explicit “Atonement cast” button press; you’ll see **damage events**, then **heal events** caused by a different spell ID (or the same ID as a triggered effect). This is detectable if you process **COMBAT_LOG_EVENT_UNFILTERED**. #### Slot-based enchants represented as a stable “build-state” object
**Most consistent with**: “17 slots to apply … to you regardless of gear” and presence of presets/loadouts. This suggests the server maintains:

- A per-character list of “active enchants” bound to slots.
- A set of “loadouts/presets” that copy those active enchants.

**Addon implication:** There is likely a discrete “active enchant list” that the client UI can query. Whether *your addon* can query it depends on whether Ascension exposes custom APIs or only the official frames can access it.

### What is still speculation

- Whether Ascension encodes many enchants using `SpellEffectDummy`-style effects, family flags, or script hooks cannot be confirmed from public UI-level docs alone.
- It is unknown how many enchants are expressed as visible `UnitAura` entries vs. fully server-hidden markers. Expect both patterns in the wild.

The practical posture for addon development is therefore:

> Treat Mystic Enchants as **a dynamic rules engine** that may express itself as “new spells”, “replacement casts”, “extra procs”, and “stateful passives”, and build detection logic that can succeed even if you only ever see spellbook/cooldowns/auras/combat log.

## Public identifier landscape and what you can realistically map today

### What is publicly available without DB scraping

The most accessible public sources for Mystic Enchant behaviour are:

- Official Ascension news posts describing specific enchants and their effects (patch/change logs). - The community wiki’s **Rarity rules** and **examples** lists (including a partial legendary list and many named examples). - Community archetype/build pages (example: Tide Mender) that explicitly list a legendary enchant and supporting epics/rares, with a written explanation of the role logic. - In-game tooltips can expose IDs (toggleable), which is the most direct route to spell/enchant IDs for *your addon’s dataset building*. ### A practical “seed mapping” table you can start from

The table below lists **confirmed** examples where public sources explicitly tie an enchant to specific spells or behaviours. (IDs are not included here unless a public source provides them; in practice you can fill IDs via tooltip/link parsing in-game.)

| Mystic Enchant (example) | Type of behaviour | Affected spells / conditions | What heal/support addons should track | Evidence |
|---|---|---|---|---|
| Atonement | Damage-to-heal passive | Direct damage with Smite / Holy Fire / Penance heals nearby allies affected by Grace; reduced in PvP; cannot heal caster | Damage events from those spells; Grace aura presence on allies; resulting heals and their source spell IDs | |
| Mass Hysteria | Spell replacement | “Fear spell transforms into Fear (Mass Hysteria)” with additional AoE debuff (Shaken) | Detect replacement spell in spellbook; detect cast events of the transformed spell; debuff tracking | |
| Words of Healing | Legendary build-definer (healing amplify) | Borrowed Time increases crit chance of direct heals; Borrowed Time not consumed by casting; duration reduced instead | Borrowed Time aura tracking; crit-mod window; shield→heal priority changes | |
| Dominant Word: Shield | Threshold augment + CDR | PW:S absorbs 250% below 75% HP; short “additional absorb effect” window; PW:S cooldown reduction; Rapture mana increased | Target HP threshold; PW:S cooldown; short-lived post-cast effect | |
| Earth’s Blessing | Proc/charge system change | Grants 2 charges of Earth Shield; next orb healing increased stacking up to 3; moved to Epic | Earth Shield charges (or equivalent tracking); stack count behaviour; tank buff maintenance | |
| Transcendental Embrace | Trigger expansion | “now also triggers from Healing Wave” (implies a proc previously limited) | Spell event correlation: Healing Wave → proc aura or additional effect | |
| Low Tide | Legendary build-definer (smart spread) | Each cast of Riptide grants +crit chance for Nature healing on that target; crit heals spread Riptide to nearby ally | Riptide uptime; crit events; spread detection via aura application | |

### Base spell IDs: what you can cite publicly vs. what you should extract in-game

You asked for spell IDs and aura IDs. Public WotLK databases can provide base spell IDs, but you will still need **in-game extraction** for Ascension-custom spell IDs and any client-patched spells.

Two examples (from a WotLK spell database) illustrate the principle:

- **Power Word: Shield** (Rank 1) has spell ID **592**. - **Flash Heal** (Rank 7) has spell ID **9472**. Those IDs are enough to demonstrate the workflow. For Ascension-specific IDs (custom spells, transformed spell variants, custom enchant spells), the most reliable pipeline is:

1. Turn on the in-game “Show id in tooltips” option. 2. Use tooltip parsing and/or spell links (and combat log) to harvest IDs into your addon’s local database.

## Healer/support build logic in a classless Mystic Enchant world

### A build is a “healing engine”, not a spec

On Area 52, a “true healer” build usually emerges when a player has:

- A reliable **throughput loop** (direct heals, HoTs, shields, or damage-to-heal).
- A **maintenance package** (key buffs/HoTs/shields that must remain active).
- A **triage toolkit** (fast emergency heals, external cooldowns, dispels).
- A **mana engine** (regen mechanics, proc-based efficiency, or a low-cost loop).

Mystic Enchants often define *which* of those engines is primary.

### Confirmed healer archetype example: Tide Mender

The community “Tide Mender” archetype page is valuable because it explicitly explains a legendary enchant as the central engine:

- **Low Tide** makes **Riptide** the “core healing engine,” adds crit escalation, and spreads Riptide on critical heals. - It lists supporting epics including **Transcendental Embrace** and **Earth’s Blessing**, and rare/uncommon choices such as **Healing Way** and “Focused Chain”. From an addon-design perspective, this implies a specific *healing intent signature*:

- Heavy emphasis on **HoT maintenance** (Riptide uptime across multiple targets).
- Value spikes around **crit events** (because crit propagates the HoT).
- Tank support tied to **Earth Shield** behaviour (charges and orb amplification). A next-gen healing addon should therefore treat this not as “Shaman healer” but as a **Riptide-centric propagation engine** and surface UI cues accordingly (e.g., “Riptide missing” indicators, crit-window cues, Earth Shield charge tracking).

### Confirmed support archetype example: Atonement-style combat healer

Atonement is explicitly described as damage-to-heal tied to **Smite**, **Holy Fire**, and **Penance**, healing allies affected by **Grace**. This is a different archetype with a distinct intent signature:

- The “heal buttons” might be fewer; the build’s throughput is partly measured in **damage GCDs**, not just healing GCDs.
- Triage decisions become: “Which ally should have Grace (or an equivalent maintenance aura) right now?” and “Is it safe to DPS to heal?”

Addon requirements differ heavily from classic Healbot-style logic:

- You cannot recommend “Flash Heal spam” if the main engine is “Smite → heal via Atonement”.
- You need a hybrid model that scores offensive casts as healing throughput given the current aura graph.

### Confirmed shield-centric support: Power Word: Shield ecosystems

Public patch notes document multiple Mystic Enchants and talent interactions built around **Power Word: Shield**, including conditions like “below 75%” threshold amplification and making Borrowed Time behave differently. This supports a third archetype:

- Preventative mitigation and triage tied to **cooldown micro-optimisation** (shield CDR, threshold bonuses).
- Healing throughput strongly influenced by *absorbs* rather than raw effective healing, and by shield-related procs.

Addon design consequences:

- Classic “missing health %” triage isn’t enough; you also need **absorb-state awareness** (even if approximated) and “shield-on-cooldown” logic.
- When threshold conditions are part of the enchant, you need **target HP threshold cues** (e.g., highlight targets below 75% for Dominant Word: Shield). ### A practical spell-function catalogue (for inference), designed for Area 52

Because class is not reliable, you want a spell taxonomy orthogonal to class. The table below is an **engineering-oriented** categorisation (not a complete spell list). You populate it from spellbook scans + combat log discovery over time.

| Category | What defines it | Signals you can detect client-side | Why it matters |
|---|---|---|---|
| Direct heal | Large positive health delta on a friendly target | Combat log `SPELL_HEAL`; tooltip contains “Heals”; cast time > 0 often | Triage / emergency logic |
| Heal-over-time | Periodic heals after an application | `SPELL_AURA_APPLIED` then periodic `SPELL_PERIODIC_HEAL` | Maintenance windows, rolling logic |
| Shield/absorb | Buff that prevents damage rather than healing | `SPELL_AURA_APPLIED` of absorb buff; damage absorbed often not directly reported in WotLK logs unless special handling; tooltip keywords | Preventative logic + “don’t overwrite” rules |
| Cleanse/dispel | Removes debuffs by type | Spell tooltip; `SPELL_DISPEL` events | UI must show dispellable debuffs and route clicks |
| External cooldown | Short-lived defensive buff to others | `SPELL_AURA_APPLIED` meaningful cooldown; long CD | Raid support decisions |
| Smart heal / propagation | Heals or spreads to other allies based on rules (crit, proximity, missing hp) | Aura spread patterns; combat log multi-target correlations | Addon should predict “value per GCD” |
| Damage-to-heal | Healing output depends on doing damage | Damage events cause healing events; requires maintenance aura mapping | Role inference + rotation suggestions |

This taxonomy is the backbone of dynamic role inference and a “toolkit registry” system.

## Addon capability and detection feasibility on Ascension’s 3.3.5a client

### The core rule: addons are client-side; secure execution still applies

Even on a private server, the addon sandbox is still constrained by the **secure execution/taint/combat lockdown** model. Secure action buttons exist to allow protected actions (casting spells, macro execution) via user clicks, but you cannot freely rewire protected behaviours during combat. The practical ceiling for a Healbot-like addon is therefore:

- You can build **secure click-casting frames** (Healbot/VuhDo/Clique style) that cast spells on click.
- You cannot build a bot: no fully automatic target selection and spell casting without user input.

### WeakAuras-style logic on Ascension is not “approximate”; it’s real

The Ascension launcher ecosystem includes a maintained **WeakAuras 3.3.5a backport** (“WeakAuras Ascension”), explicitly installed via the launcher. This confirms that:

- “WeakAuras-style” event-driven displays, triggers, and custom Lua logic are viable on this client.
- Your addon can either integrate with WeakAuras (export triggers / provide aura packs) or implement a parallel internal trigger engine.

### ElvUI-style UI logic is also supported, but may rely on patches

Ascension maintains an ElvUI variant via the launcher, and community history shows that some UI replacements required client patch files for Ascension-specific changes. The implication is:

- A sophisticated raid-frame replacement is feasible.
- You should expect **Ascension-specific quirks** (custom resources, modified UI elements, renamed classes, new events) that require compatibility layers. ### What you can detect reliably on Area 52

You can usually build robust logic using combinations of:

- **Spellbook scanning** (what spells exist, names/ranks/icons, and whether they are usable).
- **Cooldown queries** (whether a spell is available via `GetSpellCooldown`-style calls).
- **Aura scanning** (`UnitAura`) for buffs/debuffs on player and party/raid units.
- **Combat log processing** via `COMBAT_LOG_EVENT_UNFILTERED`, which is explicitly the recommended unfiltered stream for addon use, and contains spell identifiers in its payload depending on the subevent. - **Tooltip parsing**, especially because Ascension can display IDs in tooltips (toggleable). ### What you probably cannot detect (or should treat as unreliable)

- Fully server-hidden variables (e.g., internal enchant-slot metadata) **unless Ascension exposes a custom API**.
- The “true” effect of a spell if Ascension changes server-side coefficients without updating client tooltips (possible on private servers). In those cases, only *observed combat log outcomes* tell the truth.
- Each Mystic Enchant’s precise internal proc rules from the outside, unless you collect enough combat log evidence.

### Can an addon detect spell replacements caused by Mystic Enchants?

**Yes, often**, because replacements tend to show up in at least one of:

- Spellbook: the transformed spell has its own name/ID (e.g., “Fear (Mass Hysteria)”). - Combat log: you’ll see `SPELL_CAST_SUCCESS` / `SPELL_DAMAGE` / `SPELL_HEAL` for the transformed spell rather than the base spell. - Tooltips: you can capture IDs if visible. **No, not always**, if the enchant modifies only server-side proc logic while keeping the same base spell ID and name. In that case, detect by *outcomes* (extra heals, altered cooldown cadence, extra aura applications).

## Addon design blueprint for an intelligent healer/support system

This section is written as a practical engineering interpretation, aimed at a “Healbot‑like” core with “WeakAuras‑like” reasoning and “ElvUI‑like” UI extensibility.

### Architecture overview

A robust design for Area 52 should be **data-driven** and **self-calibrating**.

**Module boundaries**

- **Spell Registry**: Builds a live catalogue of the player’s usable spells (and pet spells if relevant) and their derived metadata.
- **Enchant/Build State**: Tracks build-defining auras, detected replacements, and inferred engines (HoT engine, absorb engine, atonement engine, etc.).
- **Combat Log Learner**: Observes cast→effect relationships (damage leading to healing, procs, spreads), and gradually populates an internal “proc graph.”
- **Role Inference Engine**: Produces a role vector rather than a single label (e.g., `{healer=0.8, support=0.6, dps=0.4}`).
- **UI Layer**: Click-cast frames + indicators + recommendation widgets, respecting secure execution limits.

### Building the Spell Registry

In WotLK-era clients, you typically don’t get spell IDs directly from `GetSpellInfo`, so the reliable method is: **spellbook → spell link → parse ID** (and validate by tooltip if needed).

Pseudocode (Lua-style):

```lua
-- Core registry schema
SpellRegistry = {
 -- [spellID] = {
 -- name = "...",
 -- icon = ...,
 -- bookType = "spell", -- or "pet"
 -- isPassive = false,
 -- castTimeMs = 1500, -- parsed
 -- isHelpful = true, -- inferred
 -- tags = { direct_heal=true, ... },
 -- }
}

local function GetSpellIDFromLink(link)
 if not link then return nil end
 local id = link:match("Hspell:(%d+)")
 return id and tonumber(id) or nil
end

local function ScanSpellbook()
 wipe(SpellRegistry)

 for tab = 1, GetNumSpellTabs() do
 local _, _, offset, numSpells = GetSpellTabInfo(tab)
 for i = 1, numSpells do
 local index = offset + i
 local spellName, spellRank = GetSpellBookItemName(index, BOOKTYPE_SPELL)
 local icon = GetSpellBookItemTexture(index, BOOKTYPE_SPELL)
 local isPassive = IsPassiveSpell(index, BOOKTYPE_SPELL)

 local link = GetSpellLink(index, BOOKTYPE_SPELL)
 local spellID = GetSpellIDFromLink(link)

 if spellID and spellName then
 SpellRegistry[spellID] = SpellRegistry[spellID] or {}
 local s = SpellRegistry[spellID]
 s.name = spellName
 s.rank = spellRank
 s.icon = icon
 s.isPassive = isPassive
 s.bookType = "spell"
 end
 end
 end
end
```

To make this Ascension-grade, you add:

- Tooltip parsing to infer tags (heal vs damage vs cleanse).
- A compatibility layer to recognise **transformed spell names** (e.g., “Fear (X)”, “Blizzard (Hailstorm)”) and mark them as potential enchant-derived overrides. ### Tracking Mystic Enchants without relying on secret server APIs

You should assume you *may not* have a clean API like `GetActiveMysticEnchants()`. Build a multi-signal approach:

**Signal tier 1: explicit enchant spell presence**
- Some legendary enchants are effectively “always-on passives.” If they appear as known passive spells or visible player auras, you can tag them.

**Signal tier 2: transformed spellbook entries**
- If you detect both a base spell and a transformed variant, mark the base spell as “overridden” and prefer the transformed ID for click-casting and cooldown displays.

**Signal tier 3: combat-log-derived proc graph**
- Build edges like: `Smite damage → Atonement heal` when the temporal correlation is strong and repeats. - Build edges like: `Riptide crit heal → aura spread` for Low Tide-like behaviours. ### Role inference that works in a classless environment

Rather than “if priest then healer,” compute a role vector from observed capability.

A workable scoring model:

- Compute a **kit signature** from registry tags:
 - `heal_spells_weight`
 - `dispels_weight`
 - `external_cds_weight`
 - `damage_to_heal_weight` (detected from proc graph)
 - `absorb_weight`
- Compute a **behaviour signature** from combat log over the last N seconds:
 - percentage of GCDs spent on `SPELL_HEAL` or helpful auras
 - percentage of damage events that trigger healing events
 - average healing per cast by spell category

Then infer “intent”:

```lua
-- Returns {healer=0..1, support=0..1, dps=0..1}
local function InferRoleVector(kit, behaviour)
 local healer = clamp01(0.5*kit.heal + 0.3*kit.dispel + 0.2*behaviour.heal_gcd_share)
 local support = clamp01(0.4*kit.externals + 0.3*kit.absorb + 0.3*behaviour.buff_uptime_share)
 local dps = clamp01(0.6*behaviour.damage_gcd_share + 0.4*kit.damage)

 -- Atonement-like builds lift healer even with high dps:
 if behaviour.damage_to_heal_ratio > 0.2 then
 healer = clamp01(healer + 0.2)
 end

 return { healer=healer, support=support, dps=dps }
end
```

This lets your unit frames (ElvUI-style) display an inferred “role badge” without trusting class.

### Smart healing prioritisation under Mystic Enchant variance

Classic Healbot logic often does: “lowest HP → fastest heal.” On Ascension, your addon should instead:

1. Maintain **engine invariants**:
 - If the build’s main throughput depends on maintaining an aura (Riptide, Grace, Earth Shield, etc.), missing-maintenance targets get elevated priority. 2. Apply **cooldown/threshold rules**:
 - e.g., if you detect Dominant Word: Shield style threshold bonuses, prefer shield on targets under that threshold. 3. Choose an action set that respects secure execution:
 - Provide recommendations and highlighting, but actual casts still happen via click or keybind.

A triage score function should include:

- Missing health % and absolute deficit.
- Incoming damage estimate (approximate via recent damage events from combat log).
- Whether the target already has your key HoTs/shields.
- Whether the target is a tank (inferred by threat/stance/mitigation buffs) or is taking the most damage over time.
- Whether applying a maintenance aura enables your engine (e.g., Grace enables damage-to-heal routing). ### Click-casting implementation posture

For a Healbot-like UX you will use secure action buttons. The secure templates are designed specifically to allow protected actions via attributes, but combat lockdown restricts what you can change dynamically. Engineering rule: **Pre-build your click maps out of combat**, and swap by secure state changes when permitted (or queue changes until combat ends).

## What we can realistically build on Ascension with addon APIs similar to Healbot, WeakAuras, and ElvUI

A realistic “next-generation intelligent healing/support addon” for Area 52 can be **meaningfully smarter than classic role-based healer addons**, but it must be built around **inference + discovery**, not static class/spec tables.

What is realistically achievable:

- A Healbot-like click-casting frame system with:
 - Dynamic spell assignment based on **what spells you actually know** (spellbook scan).
 - Robust support for transformed/replaced spells by preferring the spell IDs observed in the spellbook and combat log (e.g., “Fear (Mass Hysteria)” style cases). - Separate “engine modes” (HoT engine, absorb engine, damage-to-heal engine) that are selected by **role vector inference** and updated as enchants/spells change.

- WeakAuras-style logic is fully feasible:
 - Ascension maintains a 3.3.5a WeakAuras backport via its launcher ecosystem, confirming that sophisticated trigger logic, custom Lua, and combat-event-driven displays are normal on this platform. - Your addon can either (a) generate WeakAuras exports for build engines, or (b) include an internal trigger engine using the same event model.

- ElvUI-style UI augmentation is feasible:
 - Ascension maintains an ElvUI fork in its launcher repository, and historically some UI projects required Ascension-specific patches/config to account for the realm’s custom features. - This supports the expectation that a “smart raid frame” addon can coexist with or extend ElvUI rather than replace everything.

- Dynamic role inference is feasible and should outperform class-based role guessing:
 - Area 52’s classless design explicitly frames the character as “mix and match spells and talents from ANY class,” gated by essence and other constraints. - Therefore, “what you cast” and “what you maintain” is the correct signal. Your addon can infer:
 - “True healer” vs. hybrid support vs. DPS-support
 - whether the build is maintenance-driven (HoT/shield) or event-driven (damage-to-heal)
 - It can do so by combining spellbook + aura + combat log signals, using `COMBAT_LOG_EVENT_UNFILTERED` as the primary event stream. What remains fundamentally limited:

- You cannot automate decisions into casts without user input due to secure execution/taint/combat lockdown constraints. Secure action templates enable click-casting, but do not remove the requirement for human action in combat. - You cannot perfectly “see” server-hidden enchant logic unless it expresses itself as:
 - a spell in your spellbook,
 - an aura on a unit,
 - or a combat-log-visible event chain.
- You should expect to maintain an evolving dataset because Ascension actively redesigns how enchantments are structured over time (e.g., large overhauls like slot-based enchants, and seasonal systems that restructure enchant components). The net conclusion for engineering is optimistic:

> A Healbot-class addon that is **build-aware**, **Mystic Enchant‑aware**, and **combat-log‑learning** can be built on Area 52 today, and it can be substantially more helpful than traditional class-based healing addons—provided it treats Mystic Enchants as a dynamic rules layer and continuously learns the player’s actual kit from live data rather than from class assumptions.