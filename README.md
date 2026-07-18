# weapon_snatch

FiveM resource — snatch a **small handgun** from a player who is aiming at you (default **50/50** chance).

Supports **ESX** and **QBCore**, with multiple inventory backends.

## Supported stacks

| Framework | Inventory | Status |
|-----------|-----------|--------|
| ESX | ESX loadout (`xPlayer.addWeapon`) | supported |
| ESX | ESX items / esx_inventory style | supported |
| ESX / QB | **ox_inventory** | supported |
| ESX / QB | **qs-inventory** | supported |
| QBCore | **qb-inventory** | supported |

Set manually in `config.lua` or use `auto` detection:

```lua
Config.Framework = 'auto' -- auto | esx | qb
Config.Inventory = 'auto' -- auto | qs | ox | esx | qb
```

## Dependencies

- **ox_lib** (callbacks + optional notify)
- One framework: `es_extended` or `qb-core` / `qbx_core`
- One inventory (auto-detected if running)

Optional:

- `ox_target` — built-in player target (can be disabled)
- `dw_duty` — duty checks when `Config.RequireJob = true`

## Installation

1. Copy `weapon_snatch` into `resources/`
2. Rename `fxmanifest.lua.example` → `fxmanifest.lua`
3. Add to `server.cfg`:

```cfg
ensure ox_lib
ensure ox_target
ensure weapon_snatch
```

3. Configure `config.lua`

> **Note:** If you embed this inside another job script (e.g. policejob), disable the built-in target and use exports instead:

```lua
Config.BuiltinOxTarget = { Enabled = false }
```

## Built-in ox_target

Enabled by default. Turn off when your job script provides its own target/radial menu.

## Exports — custom target / menu

Use these when **not** using built-in ox_target.

### Client

```lua
-- Ready-made option table for ox_target / qb-target / lib.registerContext
local opt = exports.weapon_snatch:GetInteractionExport()
-- opt.canInteract(entity)
-- opt.onSelect({ entity = ped })
-- opt.action(entity) -- qb-target style

exports.weapon_snatch:CanTakeFrom(entity)
exports.weapon_snatch:IsTargetAimingAtMe(entity)
exports.weapon_snatch:AttemptTake(targetServerId)
exports.weapon_snatch:RegisterInteractionHandler(function(entity, targetId)
    -- return true/false to override, nil = default
end)
exports.weapon_snatch:ApplyConfig({ Chance = 0.5 })
```

### Server

```lua
exports.weapon_snatch:RegisterCanAttempt(function(source, targetId)
    return true -- your job / duty check
end)

exports.weapon_snatch:RegisterCustomTakeHandler(function(source, targetId, aiming)
    -- return true/false to fully override snatch logic
end)

exports.weapon_snatch:AttemptTake(source, targetId)
exports.weapon_snatch:ApplyConfig({ MaxDistance = 3.0 })
```

### Example — qb-target

```lua
exports['qb-target']:AddGlobalPlayer({
    options = {
        {
            icon = exports.weapon_snatch:GetInteractionExport().icon,
            label = exports.weapon_snatch:GetInteractionExport().label,
            canInteract = function(entity)
                return exports.weapon_snatch:CanTakeFrom(entity)
            end,
            action = function(entity)
                exports.weapon_snatch:GetInteractionExport().action(entity)
            end,
        },
    },
    distance = 2.5,
})
```

### Example — policejob bridge

```lua
-- server
exports.weapon_snatch:RegisterCanAttempt(function(source)
    return exports.esx_policejob:IsOnDuty(source)
end)

-- client target onSelect
exports.weapon_snatch:AttemptTake(targetServerId)
```

## Configuration

| Option | Default | Description |
|--------|---------|-------------|
| `Chance` | `0.5` | Success probability |
| `MaxDistance` | `2.5` | Max range (meters) |
| `Cooldown` | `8` | Seconds between attempts |
| `RequireTargetAimingAtOfficer` | `true` | Target must aim at snatcher |
| `WeaponPatterns` | pistol, revolver | Allowed handgun names |
| `BuiltinOxTarget.Enabled` | `true` | Built-in ox_target option |
| `Command.Enabled` | `false` | Debug command `/takeweapon [id]` |

## License

MIT — free for GitHub / commercial server use.
