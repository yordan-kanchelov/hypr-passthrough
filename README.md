# hypr-passthrough

Send your `SUPER` shortcuts to the remote machine instead of your Hyprland desktop.

When a remote-desktop, game-streaming or VM window is fullscreen and focused, Hyprland
switches to an almost-empty submap, so every key combo goes to the app. `SUPER + SPACE`
opens Spotlight on the Mac you're controlling through RustDesk instead of your launcher.
Leave fullscreen or focus another window, and your bindings come back.

Works out of the box with RustDesk, Moonlight, Parsec, Remmina, virt-viewer and Looking
Glass. You can add any other app from the bar.

**`SUPER + SHIFT + ESCAPE`** pauses passthrough for the focused window, so your own
bindings work again. Press it again to resume.

## Requirements

- Hyprland 0.55 or newer, configured with Lua (`hyprland.lua`)
- Omarchy, for the bar widget and one-command install. On plain Hyprland, use the
  [Lua module](#as-a-lua-module).

Nothing else: the plugin only talks to Hyprland through `hyprctl`, which ships with it.

## Install

### As an Omarchy plugin

```bash
omarchy plugin add https://github.com/yordan-kanchelov/hypr-passthrough.git --enable
omarchy restart shell
```

That's it: passthrough is active and the icon is on your bar.

- Use `--enable` rather than running `omarchy plugin enable` right after `add`. The
  shell registers new plugins in the background, so an immediate `enable` can fail
  with "plugin is not known".
- Restart the shell after installing and after each update. It caches plugin code, so
  changes only load on a fresh start:

  ```bash
  omarchy plugin update yordan-kanchelov.passthrough
  omarchy restart shell
  ```

### As a Lua module

Use this on plain Hyprland, or on Omarchy if you want to change the
[options](#options).

1. Download `passthrough.lua` from a fixed commit, not from a branch that can change
   later:
   [passthrough.lua @ 3475edf](https://raw.githubusercontent.com/yordan-kanchelov/hypr-passthrough/3475edf955c3229b3cd730defb4faa3f55354347/passthrough.lua).
   Save it as `~/.config/hypr/passthrough.lua`.
2. Check that the file is intact before Hyprland loads it:

   ```bash
   echo "26a2b80edc8021888e01c511eb92eac6de8ead80ef9b2072eb108ba98f184aeb  $HOME/.config/hypr/passthrough.lua" | sha256sum -c
   ```

   It should print `OK`. If it doesn't, delete the file and download it again.
3. Add this line to `~/.config/hypr/hyprland.lua`, after your other bindings:

   ```lua
   require("hypr.passthrough").setup()
   ```

On plain Hyprland, make sure `~/.config/?.lua` is on `package.path` (Omarchy already
does this), or put the file wherever your config's `require` can find it.

This copy never updates itself. To update, repeat steps 1 and 2 with the commit link
and checksum from the latest version of this README.

If you also have the Omarchy plugin enabled, your `hyprland.lua` copy wins: the plugin
leaves it alone and only adds the apps you manage from the bar.

## Remove

Omarchy plugin:

```bash
omarchy plugin disable yordan-kanchelov.passthrough   # turn it off, keep it installed
omarchy plugin remove yordan-kanchelov.passthrough    # uninstall
```

Disabling or removing the plugin unloads passthrough from Hyprland straight away.
Your app list stays in `~/.config/hypr-passthrough/`; delete that folder too if you
don't plan to reinstall.

Lua module: delete the `require` line from `hyprland.lua` and delete
`~/.config/hypr/passthrough.lua`.

## Usage

| Focused window | Shortcuts go to |
| --- | --- |
| A passthrough app, fullscreen | The app (and the remote machine) |
| A passthrough app, paused with `SUPER + SHIFT + ESCAPE` | Hyprland |
| Anything else | Hyprland |

To leave a fullscreen remote session, press `SUPER + SHIFT + ESCAPE`, then your usual
`SUPER + F`.

If you ever get stuck in the passthrough submap, run this from a terminal or another TTY:

```bash
hyprctl dispatch 'hl.dsp.submap("reset")'
```

## Bar widget

The icon shows a keyboard while idle and a highlighted remote-desktop icon while
shortcuts are being passed through. Click it to manage which apps get passthrough:

- **Open apps**: every app with an open window, focused one first. Click **Add** to
  include it. Apps already covered show **Listed**.
- **Your apps**: the apps you added. Click the cross to remove one.
- **Built in**: the default apps. They are all on; use the switch to turn one off.
  Only the ones installed on your machine, or currently open, are shown.

The icon sits on the right of the bar. To move it:

```bash
omarchy bar move yordan-kanchelov.passthrough --section left
```

### Files

The plugin writes one file, `~/.config/hypr-passthrough/apps.json`, and doesn't touch
your Hyprland or Omarchy config. You can also edit it by hand; changes apply straight
away.

```json
{
  "apps": ["org.example.viewer"],
  "disabled": ["moonlight"]
}
```

- `apps`: extra window classes to pass through (exact match, case-insensitive).
- `disabled`: built-in patterns to turn off, written exactly as in the `apps` default
  under [Options](#options).

These apply on top of a Lua module's `apps` too, while the Omarchy plugin is enabled.

Find a window's class with `hyprctl activewindow -j | jq -r .class`.

## Options

Options are for the [Lua module](#as-a-lua-module); the Omarchy plugin uses the
defaults below. Pass only the ones you want to change:

```lua
require("hypr.passthrough").setup({
  -- Lua patterns matched against the lowercased window class.
  apps = { "rustdesk", "moonlight", "parsec", "remmina",
           "^remote%-viewer$", "^virt%-viewer$", "^looking%-glass%-client$" },

  -- "fullscreen" | "maximized" (fullscreen or maximized) | "focused" (always)
  when = "fullscreen",

  -- Pause/resume key. Required: it is your way out, and Hyprland will not
  -- enter a submap that has no bindings.
  toggle_key = "SUPER + SHIFT + ESCAPE",

  submap = "passthrough",
  notify = true,
})
```

## How it works

- `passthrough.lua` listens for focus and fullscreen changes. When the focused window
  matches, it switches Hyprland to a submap that only binds the pause key; when it
  stops matching, it switches back.
- It only takes over from the default submap, so your own submaps (resize modes, etc.)
  are left alone.
- The Omarchy plugin loads `passthrough.lua` into Hyprland with `hyprctl eval`, loads it
  again after every Hyprland config reload, and unloads it when you disable the plugin.
- To remove a loaded copy without a config reload:
  `hyprctl eval 'hypr_passthrough.teardown()'`

## Tips

- Hyprland only stops handling the keys; the app still has to forward them. In
  RustDesk, use the *Map* or *Translate* keyboard mode so `SUPER` arrives as `Cmd` on
  a Mac.

## License

[MIT](LICENSE)
