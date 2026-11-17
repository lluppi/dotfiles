-- Meeting reminders: Zoom doesn't reliably notify, so read the macOS calendar
-- (via meeting_reminder/MeetingEvents.app, an EventKit helper) and post a
-- notification LEAD seconds before each meeting, with a Join button when the
-- event contains a Zoom/Teams/Meet link.
local M = {}

local LEAD = 5 * 60
local POLL = 30 * 60
local HOURS_AHEAD = 12
local DIR = hs.configdir .. "/meeting_reminder"
local APP = DIR .. "/MeetingEvents.app"
local OUT = os.getenv("TMPDIR") .. "hs_meeting_events.json"

local poller, task
local timers = {} -- key -> hs.timer
local notified = {} -- key -> true, so a re-poll never re-fires
local shown = {} -- live notifications, kept so their callbacks survive GC

local LINK_PATTERNS = {
  "https://[%w%.%-]*zoom%.us/[jwms]y?/[%w%?=&%.%-_/#]+",
  "https://teams%.microsoft%.com/l/meetup%-join/[^%s\"<>]+",
  "https://meet%.google%.com/[%w%-]+",
}

local function findLink(text)
  for _, pat in ipairs(LINK_PATTERNS) do
    local link = text:match(pat)
    if link then
      return link
    end
  end
end

-- Open Zoom links straight in the app instead of bouncing through a browser tab.
local function toNativeUrl(link)
  local host, conf, query = link:match("^https://([%w%.%-]*zoom%.us)/j/(%d+)%??(.*)$")
  if host then
    local url = ("zoommtg://%s/join?action=join&confno=%s"):format(host, conf)
    local pwd = query:match("pwd=([^&#]+)")
    if pwd then
      url = url .. "&pwd=" .. pwd
    end
    return url
  end
  return link
end

local function notify(ev)
  local link = findLink(ev.text or "")
  local mins = math.max(0, math.floor((ev.start - os.time()) / 60 + 0.5))
  local n
  n = hs.notify.new(function()
    if link then
      hs.urlevent.openURL(toNativeUrl(link))
    end
    n:withdraw()
    shown[n] = nil
  end, {
    title = ev.title,
    subTitle = os.date("%H:%M", math.floor(ev.start)) .. (mins > 0 and (" · in " .. mins .. " min") or " · now"),
    informativeText = link and "Click Join to open the meeting" or "No meeting link found",
    hasActionButton = link ~= nil,
    actionButtonTitle = "Join",
    otherButtonTitle = "Dismiss",
    alwaysPresent = true,
    autoWithdraw = false,
    withdrawAfter = 0,
    soundName = "Glass",
  })
  shown[n] = true
  n:send()
end

local function schedule(events)
  local now = os.time()
  local seen = {}
  for _, ev in ipairs(events) do
    local key = ev.id .. "@" .. ev.start
    seen[key] = true
    local fireAt = ev.start - LEAD
    if not notified[key] and not timers[key] and ev.start > now then
      if fireAt <= now then
        notified[key] = true
        notify(ev)
      else
        timers[key] = hs.timer.doAfter(fireAt - now, function()
          timers[key] = nil
          notified[key] = true
          notify(ev)
        end)
      end
    end
  end
  -- Drop timers for meetings that were cancelled or moved.
  for key, t in pairs(timers) do
    if not seen[key] then
      t:stop()
      timers[key] = nil
    end
  end
end

local function poll()
  if task and task:isRunning() then
    return
  end
  task = hs.task.new("/usr/bin/open", function(code)
    task = nil
    local data = hs.json.read(OUT)
    if code ~= 0 or not data then
      hs.printf("meetingReminder: helper failed (exit %s)", tostring(code))
      return
    end
    if data.error then
      hs.printf("meetingReminder: %s", data.error)
      return
    end
    schedule(data.events or {})
  end, { "-g", "-j", "-W", "-n", APP, "--args", OUT, tostring(HOURS_AHEAD) })
  task:start()
end

function M.start()
  poller = hs.timer.doEvery(POLL, poll)
  poll()
  return M
end

function M.stop()
  if poller then
    poller:stop()
    poller = nil
  end
  if task then
    task:terminate()
    task = nil
  end
  for key, t in pairs(timers) do
    t:stop()
    timers[key] = nil
  end
end

M.poll = poll
M.notify = notify -- e.g. meetingReminder.notify({title="test", start=os.time()+300, text="https://zoom.us/j/123"})

return M
