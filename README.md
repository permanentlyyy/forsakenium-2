# forsakenium-2

Modular rewrite of Forsakenium. Instead of one giant script, the window is built by
`forsakenium.lua` and every tab loads its own module from `Functions/`.

All tabs are present. Only the tabs that actually have logic contain controls; tabs
that are still unimplemented exist but are intentionally empty inside.

## Layout

```
forsakenium.lua          entry point: window, tabs, module loading, unload
Functions/
  player.lua             Player        (character: god mode, invisibility, footsteps)
  sprinting.lua          Sprinting     (stamina: infinite stamina, legit view, always sprint)
  generators.lua         Generators    (auto solve, grid size, puzzle path)
  visuals.lua            Visuals       (Killer section only)
  survivors.lua          Survivors     (empty - no logic yet)
  killers.lua            Killers       (empty - no logic yet)
  effects.lua            Effects       (empty - no logic yet)
  animations.lua         Animations    (empty - no logic yet)
  miscellaneous.lua      Miscellaneous (empty - no logic yet)
  settings.lua           Settings      (theme, interface, controls)
```

## Loading

`forsakenium.lua` fetches every module over HTTP from this repo — nothing is loaded
from disk. Run it directly from GitHub:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/permanentlyyy/forsakenium-2/main/forsakenium.lua"))()
```

Each module is read from `raw.githubusercontent.com/permanentlyyy/forsakenium-2/main/Functions/...`,
so pushes to `main` go live on the next run.

## Module contract

Each `Functions/<tab>.lua` returns a table:

```lua
local Module = {}

function Module.Build(Tab, ctx)
    -- Tab  : the WindUI tab object for this module
    -- ctx  : { WindUI, Window, Tabs, Themes, DefaultTheme, Sources, load }
end

function Module.Unload() end

return Module
```

`Build` is pcall'd by the entry point, so a failing tab warns instead of breaking the
whole UI. `Unload` is optional; when present it is called on re-execution / unload.

A module with an empty `Build` produces a tab with no controls inside it, which is how
the unimplemented tabs are kept as placeholders.
