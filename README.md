# forsakenium-2

Modular rewrite of Forsakenium. Instead of one giant script, the window is built by
`forsakenium.lua` and every tab loads its own module from `Functions/`.

## Layout

```
forsakenium.lua          entry point: window, tabs, module loading, unload
Functions/
  player.lua             Player tab      (character: god mode, invisibility, footsteps)
  sprinting.lua          Sprinting tab   (stamina: infinite stamina, legit view, always sprint)
  generators.lua         Generators tab  (auto solve, grid size, puzzle path)
  visuals.lua            Visuals tab     (killer/survivor ESP, objects, tracers)
  survivors.lua          Survivors tab   (per-survivor sections)
  killers.lua            Killers tab     (per-killer sections)
  effects.lua            Effects tab     (scaffold)
  animations.lua         Animations tab  (animation changer)
  miscellaneous.lua      Miscellaneous tab (lighting, camera, device spoofer, privacy, FOV)
  settings.lua           Settings tab    (theme, interface, controls)
```

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

## Running

Execute `forsakenium.lua` in your executor. It fetches each module from
`raw.githubusercontent.com/permanentlyyy/forsakenium-2/main/Functions/...`, so pushes
to `main` go live on the next run.
