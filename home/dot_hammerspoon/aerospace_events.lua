-- Line-buffered `aerospace subscribe` stream shared by tiling modules.
--
--   local stream = require("aerospace_events").new(
--     { "focus-changed", "window-detected" },
--     function(event) ... end,        -- event is the decoded JSON table
--     { onStart = function() end }    -- optional: resync after (re)start
--   ):start()
--
-- Chunks from the task are buffered so a JSON event split across two reads is
-- never dropped. The subscription restarts 1 s after the process exits.
local M = {}

local aerospace = "/opt/homebrew/bin/aerospace"
local restartDelay = 1

local Stream = {}
Stream.__index = Stream

function M.new(events, onEvent, opts)
  return setmetatable({
    events = events,
    onEvent = onEvent,
    opts = opts or {},
    buffer = "",
    stopped = true,
  }, Stream)
end

function Stream:_dispatch(line)
  local ok, event = pcall(hs.json.decode, line)
  if not ok or type(event) ~= "table" or event._event == nil then
    return
  end
  local cbOk, err = pcall(self.onEvent, event)
  if not cbOk then
    hs.printf("aerospace_events: handler error for %s: %s", tostring(event._event), tostring(err))
  end
end

function Stream:_consume(chunk)
  self.buffer = self.buffer .. chunk
  while true do
    local newline = self.buffer:find("\n", 1, true)
    if not newline then
      return
    end
    local line = self.buffer:sub(1, newline - 1):gsub("\r$", "")
    self.buffer = self.buffer:sub(newline + 1)
    if line ~= "" then
      self:_dispatch(line)
    end
  end
end

function Stream:_scheduleRestart()
  if self.stopped then
    return
  end
  if self.restartTimer then
    self.restartTimer:stop()
  end
  self.restartTimer = hs.timer.doAfter(restartDelay, function()
    self.restartTimer = nil
    self:_spawn()
  end)
end

function Stream:_spawn()
  if self.stopped or (self.task and self.task:isRunning()) then
    return
  end

  local args = { "subscribe" }
  for _, name in ipairs(self.events) do
    table.insert(args, name)
  end
  table.insert(args, "--no-send-initial")

  local task
  task = hs.task.new(aerospace, function()
    -- A superseded task's exit must not touch the current task's state.
    if self.task ~= task then
      return
    end
    self.task = nil
    self.buffer = ""
    self:_scheduleRestart()
  end, function(_, stdout)
    if stdout and stdout ~= "" and self.task == task then
      self:_consume(stdout)
    end
    return true
  end, args)

  self.task = task
  self.buffer = ""
  if not task:start() then
    self.task = nil
    self:_scheduleRestart()
    return
  end

  if self.opts.onStart then
    local ok, err = pcall(self.opts.onStart)
    if not ok then
      hs.printf("aerospace_events: onStart error: %s", tostring(err))
    end
  end
end

function Stream:start()
  self.stopped = false
  self:_spawn()
  return self
end

function Stream:stop()
  self.stopped = true
  if self.restartTimer then
    self.restartTimer:stop()
    self.restartTimer = nil
  end
  local task = self.task
  self.task = nil
  self.buffer = ""
  if task and task:isRunning() then
    task:terminate()
  end
  return self
end

function Stream:isRunning()
  return not self.stopped and self.task ~= nil and self.task:isRunning()
end

return M
