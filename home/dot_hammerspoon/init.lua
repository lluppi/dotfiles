require("hs.ipc")

hs.autoLaunch(true)
hs.dockicon.hide()
hs.accessibilityState(true)

-- Tiling should snap, never ease. Any Hammerspoon-initiated window move or
-- resize is applied instantly.
hs.window.animationDuration = 0

local function stopServices()
  if keyboardShortcutTap then
    keyboardShortcutTap:stop()
    keyboardShortcutTap = nil
  end

  local serviceNames = {
    "lidAwakeLock",
    "microsoftAutoUpdateGuard",
    "systemIndicator",
    "minimizedWindows",
    "workspaceIndicator",
    "masterLayout",
    "tilingFocus",
    "heliumZoom",
    "sioyekF8",
  }
  for _, name in ipairs(serviceNames) do
    local service = rawget(_G, name)
    if service and service.stop then
      local ok, err = pcall(service.stop)
      if not ok then
        hs.printf("Hammerspoon service cleanup failed: %s", err)
      end
    end
  end
end

-- This also makes re-running init.lua directly safe. On a normal reload the
-- previous Lua environment invokes the shutdown callback registered below.
stopServices()

heliumZoom = require("helium_zoom").start()
topmost = require("topmost")

tilingFocus = require("tiling_focus").start()
windowCycle = require("window_cycle")
masterLayout = require("master_layout").start()
workspaceIndicator = require("workspace_indicator").start()
minimizedWindows = require("minimized_windows").start()
systemIndicator = require("system_indicator").start()
microsoftAutoUpdateGuard = require("microsoft_autoupdate_guard").start()
lidAwakeLock = require("lid_awake_lock").start()
sioyekF8 = require("sioyek_f8").start()

-- macOS owns Ctrl+Up (Mission Control) and Ctrl+Down (App Exposé) at the
-- WindowServer level, which is what swallows vim's <C-Up>/<C-Down>.
systemHotkeys = require("system_hotkeys").start()

-- Windows/Linux-style shortcuts: deliver Ctrl+key to the frontmost app as
-- Cmd+key. The synthetic events are posted DIRECTLY to the app rather than
-- into the global event stream, so global hotkey daemons (AeroSpace binds
-- cmd-c to the colour picker, cmd-r to Sol, ...) never intercept them.
-- Terminals are excluded so Ctrl-C stays the interrupt; there,
-- Ctrl+Shift+C/V perform copy/paste instead (Linux terminal style).
local terminalBundleIDs = {
  ["com.apple.Terminal"] = true,
  ["com.googlecode.iterm2"] = true,
  ["com.mitchellh.ghostty"] = true,
  ["net.kovidgoyal.kitty"] = true,
  ["com.github.wez.wezterm"] = true,
  ["org.alacritty"] = true,
  ["dev.warp.Warp-Stable"] = true,
}

-- Keys rewritten to plain Cmd+key in the event stream. Only keys whose Cmd
-- combo is NOT an AeroSpace binding can be listed here — AeroSpace owns
-- cmd-c/r/s/f/t/d/j/o as window-manager actions and would intercept them.
local ctrlToCmdKeyCodes = {}
for _, key in ipairs({ "v", "x", "a", "z", "w", "n", "p", "g", "q" }) do
  ctrlToCmdKeyCodes[hs.keycodes.map[key]] = true
end

-- AeroSpace-colliding keys with universal menu names are invoked through the
-- app's menu instead of a synthetic keystroke (bypasses global hotkeys).
-- Ctrl+t/r/f pass through untouched: Helium already binds ^t/^r/^f natively.
local menuActions = {
  [hs.keycodes.map.c] = { { "Edit", "Copy" }, "Copy" },
  [hs.keycodes.map.s] = { { "File", "Save" }, "Save" },
  [hs.keycodes.map.t] = { { "File", "New Tab" }, "New Tab" },
  [hs.keycodes.map.f] = { { "Edit", "Find in Page\u{2026}" }, "Find\u{2026}" },
  [hs.keycodes.map.r] = { { "View", "Reload This Page" }, "Reload Page" },
  [hs.keycodes.map.d] = { { "Bookmarks", "Bookmark Current Tab\u{2026}" }, "Add Bookmark\u{2026}" },
  [hs.keycodes.map.j] = { { "Tools", "Downloads" }, "Downloads" },
  [hs.keycodes.map.o] = { { "File", "Open File\u{2026}" }, "Open\u{2026}" },
}

local function selectMenu(application, action)
  if application:selectMenuItem(action[1]) then
    return true
  end

  application:selectMenuItem(action[2])
  return true
end

local ctrlShiftToCmdShiftKeyCodes = {}
for _, key in ipairs({ "z", "t", "p", "o" }) do
  ctrlShiftToCmdShiftKeyCodes[hs.keycodes.map[key]] = true
end

local firefoxTextInputRoles = {
  AXComboBox = true,
  AXTextArea = true,
  AXTextField = true,
}

local function firefoxTextInputIsFocused(application)
  if application:bundleID() ~= "org.mozilla.firefox" then
    return false
  end

  local focusedElement = hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
  if not focusedElement then
    return false
  end

  return firefoxTextInputRoles[focusedElement:attributeValue("AXRole")] or false
end

local lastFirefoxWheelZoomAt = 0

keyboardShortcutTap = hs.eventtap.new({
  hs.eventtap.event.types.keyDown,
  hs.eventtap.event.types.scrollWheel,
}, function(event)
  local flags = event:getFlags()
  local application = hs.application.frontmostApplication()
  if not application then
    return false
  end

  local function rewrite(modifiers)
    event:setFlags(modifiers)
    return true, { event }
  end

  -- Firefox's macOS Command+wheel action is page scrolling, not zooming.
  -- Convert Ctrl+wheel direction directly into Firefox's Zoom menu commands.
  if event:getType() == hs.eventtap.event.types.scrollWheel then
    if application:bundleID() == "org.mozilla.firefox" and flags.ctrl and not flags.cmd and not flags.alt then
      local delta = event:getProperty(hs.eventtap.event.properties.scrollWheelEventDeltaAxis1)
      if delta == 0 then
        return false
      end

      local now = hs.timer.secondsSinceEpoch()
      if now - lastFirefoxWheelZoomAt >= 0.08 then
        lastFirefoxWheelZoomAt = now
        local command = delta > 0 and "Zoom In" or "Zoom Out"
        application:selectMenuItem({ "View", "Zoom", command })
      end
      return true
    end
    return false
  end

  local keyCode = event:getKeyCode()

  -- Firefox follows macOS's document-scrolling meaning for Home/End. In text
  -- inputs, translate them to line navigation while preserving page behavior.
  if not flags.ctrl and not flags.cmd and not flags.alt and firefoxTextInputIsFocused(application) then
    if keyCode == hs.keycodes.map.home or keyCode == hs.keycodes.map["end"] then
      event:setKeyCode(keyCode == hs.keycodes.map.home and hs.keycodes.map.left or hs.keycodes.map.right)
      local modifiers = { cmd = true }
      if flags.shift then
        modifiers.shift = true
      end
      return rewrite(modifiers)
    end
  end

  if not flags.ctrl or flags.cmd or flags.alt then
    return false
  end

  local inTerminal = terminalBundleIDs[application:bundleID()] or false

  if inTerminal then
    if not flags.shift and keyCode == hs.keycodes.map.left then
      event:setKeyCode(hs.keycodes.map.b)
      event:setFlags({ alt = true })
      return true, { event }
    end

    if not flags.shift and keyCode == hs.keycodes.map.right then
      event:setKeyCode(hs.keycodes.map.f)
      event:setFlags({ alt = true })
      return true, { event }
    end

    if flags.shift and keyCode == hs.keycodes.map.c then
      return selectMenu(application, { { "Edit", "Copy" }, "Copy" })
    end

    if flags.shift and keyCode == hs.keycodes.map.v then
      return selectMenu(application, { { "Edit", "Paste" }, "Paste" })
    end

    return false
  end

  if flags.shift then
    if keyCode == hs.keycodes.map.v then
      return rewrite({ cmd = true, alt = true, shift = true })
    end

    if keyCode == hs.keycodes.map.left or keyCode == hs.keycodes.map.right then
      return rewrite({ alt = true, shift = true })
    end

    if ctrlShiftToCmdShiftKeyCodes[keyCode] then
      return rewrite({ cmd = true, shift = true })
    end

    return false
  end

  -- Word-level navigation/deletion: Ctrl → Option (macOS word modifier)
  if keyCode == hs.keycodes.map.left or keyCode == hs.keycodes.map.right
      or keyCode == hs.keycodes.map.delete or keyCode == hs.keycodes.map.forwarddelete then
    return rewrite({ alt = true })
  end

  if application:bundleID() == "org.mozilla.firefox" and keyCode == hs.keycodes.map["0"] then
    return selectMenu(application, { { "View", "Zoom", "Actual Size" }, "Actual Size" })
  end

  if menuActions[keyCode] then
    return selectMenu(application, menuActions[keyCode])
  end

  -- AeroSpace owns Super+L. Send Ctrl+L straight to the app so the
  -- Windows/Linux-style location shortcut does not lock the screen.
  if keyCode == hs.keycodes.map.l then
    hs.eventtap.keyStroke({ "cmd" }, "l", 0, application)
    return true
  end

  if ctrlToCmdKeyCodes[keyCode] then
    return rewrite({ cmd = true })
  end

  return false
end)

keyboardShortcutTap:start()

hs.shutdownCallback = stopServices

-- Hammerspoon remains available for general automation.
