-- macOS owns Ctrl+Up (Mission Control, symbolic hotkey 32) and Ctrl+Down
-- (Application windows / App Exposé, 33) at the WindowServer level, which is
-- what swallows vim's <C-Up>/<C-Down> paragraph jumps. A session event tap
-- cannot preempt them, so the hotkeys have to be turned off.
--
-- The work lives in ~/.local/bin/macos-free-ctrl-arrows.sh, which is
-- idempotent and no-ops when the hotkeys are already released. Run async so a
-- config reload never blocks on a subprocess.

local M = {}

local SCRIPT = os.getenv("HOME") .. "/.local/bin/macos-free-ctrl-arrows.sh"

function M.ensure()
  local task = hs.task.new(SCRIPT, function(exitCode, stdout, stderr)
    local message = (stdout .. stderr):gsub("%s+$", "")
    if exitCode ~= 0 then
      hs.printf("systemHotkeys: %s failed (%d): %s", SCRIPT, exitCode, message)
    elseif message ~= "" then
      hs.printf("systemHotkeys: %s", message)
    end
  end)
  task:start()
  return task
end

function M.start()
  M.ensure()
  return M
end

return M
