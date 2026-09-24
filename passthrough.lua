-- hypr-passthrough: send your SUPER shortcuts to the remote machine.
--
-- While a remote-desktop / streaming / VM window is focused (and fullscreen,
-- by default), Hyprland switches to an almost-empty submap so every key combo,
-- including SUPER + SPACE, reaches the app instead of your desktop.
--
-- Requires Hyprland's Lua config (0.55+). Works on Omarchy and plain Hyprland.
--
--   require("hypr.passthrough").setup()
--   require("hypr.passthrough").setup({ apps = { "rustdesk" }, when = "focused" })
--
-- https://github.com/yordan-kanchelov/hypr-passthrough

local M = {}

M.defaults = {
  -- Lua patterns matched against the lowercased window class.
  apps = {
    "rustdesk", -- RustDesk
    "moonlight", -- Moonlight (com.moonlight_stream.Moonlight)
    "parsec", -- Parsec
    "remmina", -- Remmina (org.remmina.Remmina)
    "^remote%-viewer$", -- virt-viewer / SPICE
    "^virt%-viewer$",
    "^looking%-glass%-client$", -- Looking Glass
  },

  -- When to pass shortcuts through to a matching window:
  --   "fullscreen" - only while it is fullscreen
  --   "maximized"  - while it is fullscreen or maximized
  --   "focused"    - whenever it has focus
  when = "fullscreen",

  -- Pauses passthrough for the focused window, and resumes it when pressed
  -- again. While paused, your normal bindings (e.g. SUPER + F) work again.
  toggle_key = "SUPER + SHIFT + ESCAPE",

  -- Name of the submap used while passing keys through.
  submap = "passthrough",

  -- Show a short notification when passthrough is paused or resumed.
  notify = true,
}

local config
local paused = {} -- window address -> true

local function matches(window)
  if window == nil or window.class == nil then
    return false
  end

  local class = window.class:lower()
  for _, pattern in ipairs(config.apps) do
    if class:find(pattern) then
      return true
    end
  end

  return false
end

local function state_allows(window)
  local fullscreen = window.fullscreen or 0

  if config.when == "focused" then
    return true
  elseif config.when == "maximized" then
    return fullscreen ~= 0
  end

  return fullscreen == 2
end

local function should_pass(window)
  return matches(window) and state_allows(window) and not paused[window.address]
end

local function notify(text)
  if config.notify then
    hl.notification.create({ text = text, timeout = 2000, icon = "info" })
  end
end

local function sync()
  local current = hl.get_current_submap()
  local want = should_pass(hl.get_active_window())

  -- Only take over from the default submap, so other submaps (resize modes,
  -- etc.) are left alone.
  if want and current == "" then
    hl.dispatch(hl.dsp.submap(config.submap))
  elseif not want and current == config.submap then
    hl.dispatch(hl.dsp.submap("reset"))
  end
end

local function toggle()
  local window = hl.get_active_window()
  if not matches(window) or window.address == nil then
    return
  end

  if paused[window.address] then
    paused[window.address] = nil
    notify("Shortcut passthrough on")
  else
    paused[window.address] = true
    notify("Shortcut passthrough paused")
  end

  sync()
end

function M.setup(options)
  if config then
    return M
  end

  config = {}
  for key, value in pairs(M.defaults) do
    config[key] = value
  end
  for key, value in pairs(options or {}) do
    config[key] = value
  end

  if config.toggle_key then
    local description = { description = "Toggle shortcut passthrough" }

    hl.define_submap(config.submap, function()
      hl.bind(config.toggle_key, toggle, description)
    end)
    hl.bind(config.toggle_key, toggle, description)
  else
    hl.define_submap(config.submap, function() end)
  end

  hl.on("window.active", sync)
  hl.on("window.fullscreen", sync)
  -- Forget paused state here rather than on window.destroy: by then the window
  -- has expired and its address is nil.
  hl.on("window.close", function(window)
    if window and window.address then
      paused[window.address] = nil
    end
    sync()
  end)
  hl.on("config.reloaded", sync)

  return M
end

return M
