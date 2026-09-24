# hypr-passthrough

Send your `SUPER` shortcuts to the remote machine instead of your Hyprland desktop.

When a remote-desktop, game-streaming or VM window is fullscreen and focused, Hyprland
switches to an almost-empty submap, so every key combo goes to the app. `SUPER + SPACE`
opens Spotlight on the Mac you're controlling through RustDesk instead of your launcher.
Leave fullscreen or focus another window, and your bindings come back.

Works with Hyprland's Lua config (0.55+), on [Omarchy](https://omarchy.org) or plain Hyprland.

## Install

```bash
curl -fsSL -o ~/.config/hypr/passthrough.lua \
  https://raw.githubusercontent.com/yordan-kanchelov/hypr-passthrough/main/passthrough.lua
```

Then add this line to `~/.config/hypr/hyprland.lua`, after your other bindings:

```lua
require("hypr.passthrough").setup()
```

On plain Hyprland, make sure `~/.config/?.lua` is on `package.path` (Omarchy already
does this), or put the file wherever your config's `require` can find it.

## Usage

| Situation | Shortcuts go to |
| --- | --- |
| Matching app, fullscreen, focused | The app (remote machine) |
| Anything else | Hyprland, as usual |

**`SUPER + SHIFT + ESCAPE`** pauses passthrough for the focused window, so your normal
bindings work again (for example, `SUPER + F` to leave fullscreen). Press it again to resume.

If you ever get stuck: `hyprctl dispatch 'hl.dsp.submap("reset")'`

## Options

```lua
require("hypr.passthrough").setup({
  -- Lua patterns matched against the lowercased window class.
  apps = { "rustdesk", "moonlight", "parsec", "remmina",
           "^remote%-viewer$", "^virt%-viewer$", "^looking%-glass%-client$" },

  -- "fullscreen" | "maximized" (fullscreen or maximized) | "focused" (always)
  when = "fullscreen",

  -- Pause/resume key. Set to false to disable (then only leaving the window
  -- or fullscreen through the app itself restores your bindings).
  toggle_key = "SUPER + SHIFT + ESCAPE",

  submap = "passthrough",
  notify = true,
})
```

Find a window's class with `hyprctl activewindow -j | jq -r .class`.

## Notes

- Passthrough only takes over from the default submap, so your own submaps (resize
  modes, etc.) are left alone.
- Hyprland only stops handling the keys. The app still has to forward them: in RustDesk,
  use the *Map* or *Translate* keyboard mode so `SUPER` arrives as `Cmd` on a Mac.

## License

MIT
