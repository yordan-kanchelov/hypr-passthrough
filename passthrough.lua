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
  -- Required: it is your way out, and Hyprland needs it to create the submap.
  toggle_key = "SUPER + SHIFT + ESCAPE",

  -- Name of the submap used while passing keys through.
  submap = "passthrough",

  -- Show a short notification when passthrough is paused or resumed.
  notify = true,
}

local config
local paused = {} -- window address -> true
-- Lowercased window classes added at runtime (e.g. from the Omarchy bar widget),
-- matched exactly and on top of config.apps.
local extra_classes = {}

local function matches(window)
  if window == nil or window.class == nil then
    return false
  end

  local class = window.class:lower()
  if extra_classes[class] then
    return true
  end

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
    notify("hypr-passthrough on")
  else
    paused[window.address] = true
    notify("hypr-passthrough paused")
  end

  sync()
end

local toggle_binds = {}
local subscriptions = {}

-- Only one copy may be active per Hyprland Lua state. The state is rebuilt on
-- every config reload, so this global is too. It lets the Omarchy plugin, which
-- loads this file with `hyprctl eval`, find and remove a copy it loaded.
function M.setup(options)
  if _G.hypr_passthrough then
    return _G.hypr_passthrough
  end

  config = {}
  for key, value in pairs(M.defaults) do
    config[key] = value
  end
  for key, value in pairs(options or {}) do
    config[key] = value
  end
  assert(type(config.toggle_key) == "string", "hypr-passthrough: toggle_key must be a key combo")

  -- The toggle is bound inside the submap, which also registers the submap
  -- (Hyprland will not enter one without bindings), and again globally.
  local description = { description = "Toggle hypr-passthrough" }
  hl.define_submap(config.submap, function()
    table.insert(toggle_binds, hl.bind(config.toggle_key, toggle, description))
  end)
  table.insert(toggle_binds, hl.bind(config.toggle_key, toggle, description))

  table.insert(subscriptions, hl.on("window.active", sync))
  table.insert(subscriptions, hl.on("window.fullscreen", sync))
  -- Forget paused state here rather than on window.destroy: by then the window
  -- has expired and its address is nil.
  table.insert(
    subscriptions,
    hl.on("window.close", function(window)
      if window and window.address then
        paused[window.address] = nil
      end
      sync()
    end)
  )
  table.insert(subscriptions, hl.on("config.reloaded", sync))

  _G.hypr_passthrough = M
  sync()

  return M
end

-- Replace the runtime list of extra window classes (exact, case-insensitive).
function M.set_extra_apps(classes)
  extra_classes = {}
  for _, class in ipairs(classes or {}) do
    if type(class) == "string" and class ~= "" then
      extra_classes[class:lower()] = true
    end
  end

  if config then
    sync()
  end
end

-- The configured app patterns, one per line, and the submap name (both read by
-- the Omarchy bar widget).
function M.app_patterns()
  return table.concat(config and config.apps or {}, "\n")
end

function M.submap_name()
  return config and config.submap or M.defaults.submap
end

-- Undo setup(): leave the submap and drop the binding and event handlers.
function M.teardown()
  if _G.hypr_passthrough ~= M then
    return
  end

  if hl.get_current_submap() == config.submap then
    hl.dispatch(hl.dsp.submap("reset"))
  end

  -- In Hyprland 0.56, unbinding one of two same-key bindings expires the other
  -- too, and so does a user's own hl.unbind() of the key. Touching an expired
  -- keybind handle in any way but tostring() segfaults the compositor.
  for _, bind in ipairs(toggle_binds) do
    if not tostring(bind):find("(expired)", 1, true) then
      bind:unbind()
    end
  end

  for _, subscription in ipairs(subscriptions) do
    subscription:remove()
  end

  toggle_binds = {}
  subscriptions = {}
  paused = {}
  extra_classes = {}
  config = nil
  _G.hypr_passthrough = nil
end

return M
