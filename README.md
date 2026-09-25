# forsakenium-2

Modular rewrite of Forsakenium. Instead of one giant script, the window is built by
`forsakenium.lua` and every tab loads its own module from `Functions/`.

Only tabs with real logic are included. Tabs that were UI-only have been removed.

## Layout

```
forsakenium.lua          entry point: window, tabs, module loading, unload
Functions/
  player.lua             Player tab      (character: god mode, invisibility, footsteps)
  sprinting.lua          Sprinting tab   (stamina: infinite stamina, legit view, always sprint)
  generators.lua         Generators tab  (auto solve, grid size, puzzle path)
  settings.lua           Settings tab    (theme, interface, controls)
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
