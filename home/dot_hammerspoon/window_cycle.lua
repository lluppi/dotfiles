local M = {}

local aerospace = "/opt/homebrew/bin/aerospace"

local function aerospaceWindows()
  -- One AeroSpace request instead of two: hs.execute is synchronous, so every
  -- extra call stalls the main thread (and every eventtap with it).
  local output, ok = hs.execute(
    aerospace .. [[ eval -- "list-workspaces --focused --format 'focused|%{workspace}' && list-windows --all --format 'win|%{window-id}|%{workspace}'"]]
  )

  if not ok then
    return {}, {}
  end

  local focusedWorkspace = nil
  local windowIds = {}
  local windowWorkspaces = {}

  for line in output:gmatch("[^\r\n]+") do
    if not focusedWorkspace then
      focusedWorkspace = line:match("^focused|(.+)$")
    end

    local windowId, workspace = line:match("^win|(%d+)|(.+)$")
    windowId = tonumber(windowId)
    if windowId then
      table.insert(windowIds, windowId)
      windowWorkspaces[#windowIds] = workspace
    end
  end

  local workspaceWindowIds = {}
  local managedWindowIds = {}

  for index, windowId in ipairs(windowIds) do
    managedWindowIds[windowId] = true
    if windowWorkspaces[index] == focusedWorkspace then
      table.insert(workspaceWindowIds, windowId)
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
