local M = {}

local aerospace = "/opt/homebrew/bin/aerospace"

local function aerospaceWindows()
  local workspaceOutput, workspaceOK = hs.execute(
    aerospace .. " list-workspaces --focused"
  )
  local windowsOutput, windowsOK = hs.execute(
    aerospace .. " list-windows --all --format '%{window-id}|%{workspace}'"
  )

  if not workspaceOK or not windowsOK then
    return {}, {}
  end

  local focusedWorkspace = workspaceOutput:match("([^\r\n]+)")
  local workspaceWindowIds = {}
  local managedWindowIds = {}

  for line in windowsOutput:gmatch("[^\r\n]+") do
    local windowId, workspace = line:match("^(%d+)|(.+)$")
    windowId = tonumber(windowId)
    if windowId then
      managedWindowIds[windowId] = true
      if workspace == focusedWorkspace then
        table.insert(workspaceWindowIds, windowId)
      end
    end
  end

  return workspaceWindowIds, managedWindowIds
end

local function visibleUnmanagedWindowIds(managedWindowIds)
  local windowIds = {}

  -- CGWindowList includes system-owned windows which AeroSpace deliberately
  -- leaves unmanaged (permission prompts, authentication dialogs, and the
  -- like). Using the on-screen list keeps ordinary windows from other
  -- AeroSpace workspaces out of this workspace's cycle.
  for _, windowInfo in ipairs(hs.window.list(false)) do
    local windowId = windowInfo.kCGWindowNumber
    if windowId
      and windowInfo.kCGWindowLayer == 0
      and windowInfo.kCGWindowAlpha > 0
      and not managedWindowIds[windowId]
      and hs.window.get(windowId)
    then
      table.insert(windowIds, windowId)
    end
  end

  -- Window IDs provide a stable order. Front-to-back order changes whenever
  -- one is focused and would otherwise make repeated Alt-Tab bounce between
  -- two dialogs.
  table.sort(windowIds)
  return windowIds
end

function M.cycle(direction)
  direction = direction < 0 and -1 or 1

  local workspaceWindowIds, managedWindowIds = aerospaceWindows()
  local candidateIds = workspaceWindowIds
  for _, windowId in ipairs(visibleUnmanagedWindowIds(managedWindowIds)) do
    table.insert(candidateIds, windowId)
  end

  if #candidateIds == 0 then
    return false
  end

  local focusedWindow = hs.window.focusedWindow()
  local focusedWindowId = focusedWindow and focusedWindow:id() or nil
  local focusedIndex = nil
  for index, windowId in ipairs(candidateIds) do
    if windowId == focusedWindowId then
      focusedIndex = index
      break
    end
  end

  local targetIndex
  if focusedIndex then
    targetIndex = ((focusedIndex - 1 + direction) % #candidateIds) + 1
  elseif direction > 0 then
    targetIndex = 1
  else
    targetIndex = #candidateIds
  end

  local targetWindow = hs.window.get(candidateIds[targetIndex])
  if not targetWindow then
    return false
  end

  targetWindow:focus()
  targetWindow:raise()
  return true
end

return M
