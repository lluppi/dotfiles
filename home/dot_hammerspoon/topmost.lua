-- Quick-raise: Super+T pins a window. Pressing Super+T from any other window
-- instantly focuses the pinned window; pressing it while the pinned window is
-- focused returns to the previous window.
--
-- macOS 26 locked down the CGS/SLS private APIs that "always on top" relied on,
-- so persistent floating isn't possible without Apple-signed entitlements.
-- This is the practical alternative.

local M = {}

local pinnedID = nil      -- CGWindowID of the pinned window
local previousID = nil    -- window we came from

function M.toggle()
  local win = hs.window.focusedWindow()
  if not win then return end

  local id = win:id()

  if pinnedID and id == pinnedID then
    -- Already looking at the pinned window → unpin it.
    pinnedID = nil
    previousID = nil
    hs.alert.show("⊘ Unpinned", 0.5)
  elseif pinnedID then
    -- A window is pinned and we're elsewhere → jump to it.
    previousID = id
    local pinned = hs.window.get(pinnedID)
    if pinned then
      pinned:focus()
    else
      -- Pinned window was closed.
      pinnedID = nil
      previousID = nil
      hs.alert.show("⊘ Pinned window closed", 0.5)
    end
  else
    -- Nothing pinned → pin the focused window.
    pinnedID = id
    previousID = nil
    hs.alert.show("📌 Pinned", 0.5)
  end
end

return M
