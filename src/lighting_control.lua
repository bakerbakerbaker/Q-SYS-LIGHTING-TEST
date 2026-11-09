--[[
  Q-SYS Sample Project: Lighting & Shades Panel
  ---------------------------------------------
  Lights are controlled over UDP (ASCII commands) and shades over HTTP GET.
  Both protocols are PLACEHOLDERS: replace the command builders with your
  lighting processor's / shade controller's real protocol.

  Script component controls:
    LightLevel    Knob    (Float, 0..100 %)          Count = 4
    Scene         Button  (Trigger)                   Count = 4
    SceneActive   LED     (Indicator, Boolean)        Count = 4
    ShadeOpen     Button  (Trigger)                   Count = 2
    ShadeClose    Button  (Trigger)                   Count = 2
    ShadeStop     Button  (Trigger)                   Count = 2
    ShadeStatus   Text    (Indicator)                 Count = 2
    LightIP       Text    (Controller)                -- lighting processor IP
    ShadeIP       Text    (Controller)                -- shade controller IP
    Online        LED     (Indicator, Boolean)        -- lighting processor reachable
    Status        Text    (Indicator)
]]

-- ---------- Configuration ----------
local CFG = {
  AreaNames  = { "Front", "Middle", "Back", "Accent" },
  ShadeNames = { "Window A", "Window B" },

  LightPort = 5000,           -- UDP port on the lighting processor
  FadeMs = 1500,              -- default fade time sent with level commands
  SendIntervalSec = 0.1,      -- max rate for fader-driven commands
  HeartbeatSec = 10,          -- how often to ping the processor
  HeartbeatTimeoutSec = 3,    -- reply window before marking Offline
  HttpTimeoutSec = 5,
}

local SCENES = {
  { name = "Full",         levels = { 100, 100, 100, 100 } },
  { name = "Presentation", levels = {  80,  40,   0,  30 } },
  { name = "Video",        levels = {  10,   0,   0,  20 } },
  { name = "Off",          levels = {   0,   0,   0,   0 } },
}

-- ---------- Helpers ----------
local NUM_AREAS = #CFG.AreaNames
local NUM_SHADES = #CFG.ShadeNames

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function setStatus(msg)
  Controls.Status.String = msg
  print("[Lighting] " .. msg)
end

-- ---------- Lighting transport (UDP) ----------
local udp = UdpSocket.New()
udp:Open()

local function sendLight(cmd)
  local ip = Controls.LightIP.String
  if ip == "" then
    setStatus("Set the lighting IP address")
    return false
  end
  udp:Send(ip, CFG.LightPort, cmd .. "\r\n")
  return true
end

-- Command builders: change these to match your processor
local function levelCommand(area, percent, fadeMs)
  return string.format("LVL %d %d %d", area, math.floor(percent + 0.5), fadeMs)
end

local PING_COMMAND = "PING"

-- ---------- Fader throttling ----------
-- A fader sends many events per second. Mark the area "dirty" and flush on a
-- timer so the processor never receives more than ~10 commands/second/area.
local dirty = {}
local flushTimer = Timer.New()
local flushing = false

local function flush()
  local sent = false
  for i = 1, NUM_AREAS do
    if dirty[i] then
      dirty[i] = false
      sendLight(levelCommand(i, Controls.LightLevel[i].Value, 0))
      sent = true
    end
  end
  if not sent then
    flushTimer:Stop()
    flushing = false
  end
end

flushTimer.EventHandler = flush

local function queueLevel(i)
  dirty[i] = true
  if not flushing then
    flushing = true
    flushTimer:Start(CFG.SendIntervalSec)
  end
end

-- ---------- Scenes ----------
local recalling = false

local function clearSceneLeds()
  for s = 1, #SCENES do Controls.SceneActive[s].Boolean = false end
end

local function recallScene(s)
  local scene = SCENES[s]
  recalling = true
  for i = 1, NUM_AREAS do
    local level = clamp(scene.levels[i], 0, 100)
    Controls.LightLevel[i].Value = level
    -- Scenes use the longer fade time and bypass the throttle
    sendLight(levelCommand(i, level, CFG.FadeMs))
    dirty[i] = false
  end
  recalling = false
  clearSceneLeds()
  Controls.SceneActive[s].Boolean = true
  setStatus("Scene: " .. scene.name)
end

for s = 1, #SCENES do
  Controls.Scene[s].EventHandler = function() recallScene(s) end
end

for i = 1, NUM_AREAS do
  Controls.LightLevel[i].EventHandler = function()
    if recalling then return end
    clearSceneLeds()
    queueLevel(i)
  end
end

-- ---------- Shades (HTTP) ----------
local function shadeRequest(id, command, doneText)
  local ip = Controls.ShadeIP.String
  if ip == "" then
    Controls.ShadeStatus[id].String = "No IP"
    return
  end
  Controls.ShadeStatus[id].String = "Moving..."

  local url = string.format("http://%s/shade?id=%d&cmd=%s", ip, id, command)
  HttpClient.Download {
    Url = url,
    Method = "GET",
    Timeout = CFG.HttpTimeoutSec,
    EventHandler = function(tbl, code, data, err, headers)
      if code == 200 then
        Controls.ShadeStatus[id].String = doneText
        setStatus(CFG.ShadeNames[id] .. ": " .. doneText)
      else
        Controls.ShadeStatus[id].String = "Error"
        setStatus(CFG.ShadeNames[id] .. " request failed (" .. tostring(code or err) .. ")")
      end
    end,
  }
end

for id = 1, NUM_SHADES do
  Controls.ShadeOpen[id].EventHandler  = function() shadeRequest(id, "open",  "Open")    end
  Controls.ShadeClose[id].EventHandler = function() shadeRequest(id, "close", "Closed")  end
  Controls.ShadeStop[id].EventHandler  = function() shadeRequest(id, "stop",  "Stopped") end
end

-- ---------- Heartbeat / online indicator ----------
local heartbeatTimer = Timer.New()
local replyTimer = Timer.New()

udp.Data = function(sock, packet)
  -- Any reply from the processor counts as "alive"
  replyTimer:Stop()
  Controls.Online.Boolean = true
end

replyTimer.EventHandler = function()
  replyTimer:Stop()
  Controls.Online.Boolean = false
end

heartbeatTimer.EventHandler = function()
  if Controls.LightIP.String ~= "" then
    sendLight(PING_COMMAND)
    replyTimer:Start(CFG.HeartbeatTimeoutSec)
  end
end

heartbeatTimer:Start(CFG.HeartbeatSec)

-- ---------- Startup ----------
for i = 1, NUM_AREAS do dirty[i] = false end
Controls.Online.Boolean = false
for id = 1, NUM_SHADES do Controls.ShadeStatus[id].String = "--" end
setStatus("Ready")
