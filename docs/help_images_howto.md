The right structure is in [docs/help_pages.lua](<d:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\AzerothWaypoint\docs\help_pages.lua:1>). To use real images, replace the placeholder-only blocks with texture paths.S

Right now an image block looks like this:

```lua
{
    type = "image",
    align = "CENTER",
    width = 700,
    height = 220,
    placeholder = "Overview screenshot placeholder",
    caption = "Replace with a full addon overview shot later.",
},
```

To make that show a real image, add `texture`:

```lua
{
    type = "image",
    align = "CENTER",
    width = 700,
    height = 220,
    texture = "Interface\\AddOns\\AzerothWaypoint\\media\\help\\overview",
    placeholder = "Overview screenshot placeholder",
    caption = "Overview",
},
```

Same idea for `image_row` items. For example:

```lua
{
    type = "image_row",
    items = {
        {
            width = 330,
            height = 150,
            texture = "Interface\\AddOns\\AzerothWaypoint\\media\\help\\arrow_starlight",
            placeholder = "Starlight arrow screenshot placeholder",
            caption = "Starlight skin",
        },
        {
            width = 330,
            height = 150,
            texture = "Interface\\AddOns\\AzerothWaypoint\\media\\help\\arrow_stealth",
            placeholder = "Stealth arrow screenshot placeholder",
            caption = "Stealth skin",
        },
    },
},
```

A few practical WoW-specific points:

- Use WoW texture paths, not absolute Windows paths.
- Omit the file extension in the Lua path.
- Put the files somewhere like:
  - `media/help/overview.tga`
  - `media/help/arrow_starlight.tga`
  - `media/help/arrow_stealth.tga`
- Then reference them as:
  - `"Interface\\AddOns\\AzerothWaypoint\\media\\help\\overview"`
  - `"Interface\\AddOns\\AzerothWaypoint\\media\\help\\arrow_starlight"`

Best formats:
- `TGA` is the simplest for UI screenshots.
- `BLP` is also fine.

If you need cropping, the renderer also supports `texCoord`:

```lua
{
    type = "image",
    width = 700,
    height = 220,
    texture = "Interface\\AddOns\\AzerothWaypoint\\media\\help\\overview",
    texCoord = { 0, 1, 0, 1 },
    caption = "Overview",
},
```

That is useful if you export one larger atlas-style image and only want part of it shown.

Recommended folder layout:

- [media/help](/abs/path-not-available)
- `overview.tga`
- `arrow_compare.tga` or separate `arrow_starlight.tga` / `arrow_stealth.tga`
- `overlay_overview.tga`
- `overlay_waypoint.tga`
- `overlay_navigator.tga`
- `overlay_pinpoint.tga`
- `overlay_plaque.tga`

So the actual workflow is:

1. Export screenshot art to `media/help/*.tga`
2. Add `texture = "Interface\\AddOns\\AzerothWaypoint\\media\\help\\name"` to the relevant block in [docs/help_pages.lua](<d:\Games\Blizzard\World of Warcraft\_retail_\Interface\AddOns\AzerothWaypoint\docs\help_pages.lua:1>)
3. `/reload`
4. Open `/awp help`