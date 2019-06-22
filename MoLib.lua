--[[
  MoLib -- (c) 2009-2019 moorea@ymail.com (MooreaTv)
  Covered by the GNU General Public License version 3 (GPLv3)
  NO WARRANTY
  (contact the author if you need a different license)
]] --
--
-- name of the addon embedding us, our empty default anonymous ns (not used)
local addon, ns = ...

-- install into addon's namespace by default
if not _G[addon] then
  -- we may not be the first file loaded in the addon, create its global NS if we are
  _G[addon] = {}
  -- Note that if we do that CreateFrame won't work later, so we shouldn't be loaded first for WhoTracker for instance
end

local ML = _G[addon]

ML.name = addon

function ML.deepmerge(dstTable, dstKey, src)
  if type(src) ~= 'table' then
    if not dstKey then
      error("setting leave object on nil key")
    end
    dstTable[dstKey] = src
    return
  end
  if dstKey then
    if not dstTable[dstKey] then
      dstTable[dstKey] = {}
    end
    dstTable = dstTable[dstKey]
  end
  for k, v in pairs(src) do
    ML.deepmerge(dstTable, k, v)
  end
end

function ML.MoLibInstallInto(namespace, name)
  ML.deepmerge(namespace, nil, ML)
  namespace.name = name
  ML:Print("MoLib aliased into " .. name)
end

-- to force debug from empty state, uncomment: (otherwise "/<addon> debug on" to turn on later
-- and /reload to get it save/start over)
-- ML.debug = 1

function ML:Print(...)
  DEFAULT_CHAT_FRAME:AddMessage(...)
end

-- like format except simpler... just use % to replace a value that will be tostring()'ed
-- string arguments are quoted (ie "Zone") so you can distinguish nil from "nil" etc
-- and works for all types (like boolean), unlike format
function ML.format(fmtstr, firstarg, ...)
  local i = fmtstr:find("%%")
  if not i then
    return fmtstr -- no % in the format string anymore, we're done with literal value returned
  end
  local t = type(firstarg)
  local s
  if t == "string" then -- if the argument is a string, quote it, else tostring it
    s = string.format("%q", firstarg)
  elseif t == "table" then
    local tt = {}
    local seen = {id = 0, t = {}}
    ML.DumpT.table(tt, firstarg, seen)
    s = table.concat(tt, "")
  else
    s = tostring(firstarg)
  end
  -- emit the part of the format string up to %, the processed first argument and recurse with the rest
  return fmtstr:sub(1, i - 1) .. s .. ML.format(fmtstr:sub(i + 1), ...)
end

-- Use: YourAddon:Debug("foo is %, bar is %!", foo, bar)
-- must be called with : (as method, to access state)
-- first argument is optional debug level for more verbose level set to 9
function ML:Debug(level, ...)
  if not self.debug then
    return
  end
  if type(level) == "number" then
    if level > self.debug then
      return
    end
    ML:debugPrint(level, ...)
  else
    -- level was omitted
    ML:debugPrint(1, level, ...)
  end
end

function ML:debugPrint(level, ...)
  ML:Print(string.format("%02d", GetServerTime() % 60) .. " " .. self.name .. " DBG[" .. tostring(level) .. "]: " ..
             ML.format(...), .1, .75, .1)
end

function ML:Error(...)
  ML:Print(self.name .. " Error: " .. ML.format(...), 0.9, .1, .1)
end

function ML:Warning(...)
  ML:Print(self.name .. " Warning: " .. ML.format(...), 0.96, 0.63, 0.26)
end

ML.first = 1
ML.manifestVersion = GetAddOnMetadata(addon, "Version")

-- Returns 1 if already done; must be called with : (as method, to access state)
function ML:MoLibInit()
  if not (self.first == 1) then
    return true
  end
  self.first = 0
  local version = "(" .. addon .. " / " .. self.name .. " " .. ML.manifestVersion .. ")"
  ML:Print("MoLib embeded in " .. version)
  return false -- so caller can continue with 1 time init
end

-- Start of handy poor man's "/dump" --

ML.DumpT = {}
ML.DumpT["string"] = function(into, v)
  table.insert(into, "\"")
  table.insert(into, v)
  table.insert(into, "\"")
end
ML.DumpT["number"] = function(into, v)
  table.insert(into, tostring(v))
end
ML.DumpT["boolean"] = ML.DumpT["number"]

for _, t in next, {"function", "nil", "userdata"} do
  ML.DumpT[t] = function(into, _)
    table.insert(into, t)
  end
end

ML.DumpT["table"] = function(into, t, seen)
  if seen.t[t] then
    table.insert(into, "&" .. tostring(seen.t[t]))
    return
  end
  seen.id = seen.id + 1
  seen.t[t] = seen.id
  table.insert(into, ML.format("t%[", seen.id))
  local sep = ""
  for k, v in pairs(t) do
    table.insert(into, sep)
    sep = ", " -- inserts coma seperator after the first one
    ML.DumpInto(into, k, seen) -- so we get the type/difference betwee [1] and ["1"]
    table.insert(into, " = ")
    ML.DumpInto(into, v, seen)
  end
  table.insert(into, "]")
end

function ML.DumpInto(into, v, seen)
  local type = type(v)
  if ML.DumpT[type] then
    ML.DumpT[type](into, v, seen)
  else
    table.insert(into, "<Unknown Type " .. type .. ">")
  end
end

function ML.Dump(...)
  local seen = {id = 0, t = {}}
  local into = {}
  for i = 1, select("#", ...) do
    if i > 1 then
      table.insert(into, " , ")
    end
    ML.DumpInto(into, select(i, ..., seen))
  end
  return table.concat(into, "")
end
-- End of handy poor man's "/dump" --

function ML:DebugEvCall(level, ...)
  self:Debug(level, "On ev " .. ML.Dump(...))
end

-- Retuns the normalized fully qualified name of the player
function ML:GetMyFQN()
  local p, realm = UnitFullName("player")
  self:Debug(1, "GetMyFQN % , %", p, realm)
  if not realm then
    self:Error("GetMyFQN: Realm not yet available!")
    return p
  end
  return p .. "-" .. realm
end

ML.AlphaNum = {}

-- generate the 62 alpha nums (A-Za-z0-9 but in 1 pass so not in order)
for i = 1, 26 do
  table.insert(ML.AlphaNum, string.format("%c", 64 + i)) -- 'A'-1
  table.insert(ML.AlphaNum, string.format("%c", 64 + 32 + i)) -- 'a'-1
  if i <= 10 then
    table.insert(ML.AlphaNum, string.format("%c", 47 + i)) -- '0'-1
  end
end
ML:Debug("Done generating AlphaNum table, % elems: %", #ML.AlphaNum, ML.AlphaNum)

function ML:RandomId(len)
  local res = {}
  for _ = 1, len do
    table.insert(res, ML.AlphaNum[math.random(1, #ML.AlphaNum)])
  end
  local strRes = table.concat(res)
  self:Debug(8, "Generated % long id from alphabet of % characters: %", len, #ML.AlphaNum, strRes)
  return strRes
end

-- based on http://www.cse.yorku.ca/~oz/hash.html djb2 xor version
-- returns a short printable 1 character hash and long numerical hash
function ML.ShortHash(str)
  local hash = 0
  for i = 1, #str do
    hash = bit.bxor(33 * hash, string.byte(str, i))
  end
  return ML.AlphaNum[1 + math.mod(hash, #ML.AlphaNum)], hash
end

-- add hash key at the end of text
function ML:AddHashKey(text)
  local hashC = ML.ShortHash(text)
  self:Debug(3, "Hashed % adding %", text, hashC)
  return text .. hashC
end

-- checks correctness of hash and returns the pair true, original
-- if correct, false otherwise (do check that first return arg!)
function ML:UnHash(str)
  if type(str) ~= 'string' then
    self:Debug(1, "Passed non string % to UnHash!", str)
    return false
  end
  local lastC = string.sub(str, #str) -- last character is ascii/alphanum so this works
  local begin = string.sub(str, 1, #str - 1)
  local sh, lh = ML.ShortHash(begin)
  self:Debug(3, "Hash of % is % / %, expecting %", begin, sh, lh, lastC)
  return lastC == sh, begin -- hopefully caller does check first value
end

-- Returns an escaped string such as it can be used literally
-- as a string.gsub(haystack, needle, replace) needle (ie escapes %?*-...)
function ML.GsubEsc(str)
  -- escape ( ) . % + - * ? [ ^ $
  local sub, _ = string.gsub(str, "[%(%)%.%%%+%-%*%?%[%^%$%]]", "%%%1")
  return sub
end

function ML.ReplaceAll(haystack, needle, replace, ...)
  -- only need to escape % on replace but a few more won't hurt
  return string.gsub(haystack, ML.GsubEsc(needle), ML.GsubEsc(replace), ...)
end

-- create a new LRU instance with the given maximum capacity
function ML.LRU(capacity)
  local obj = {}
  obj.capacity = capacity
  obj.size = 0
  obj.head = nil -- the double linked list for ordering
  obj.tail = nil -- the tail for eviction
  obj.direct = {} -- the direct access to the element
  -- iterator, most frequent first
  obj.iterate = function()
    local cptr = obj.head
    return function() -- next() function
      if cptr then
        local r = cptr.value
        local c = cptr.count
        cptr = cptr.next
        return r, c
      end
    end
  end
  -- add/record data point in the set
  obj.add = function(self, elem)
    local node = self.direct[elem]
    if node then -- found move it to top
      ML:Debug(9, "looking for %, found %", elem, node.value)
      assert(node.value == elem, "elem not found where expected")
      node.count = node.count + 1
      local p = node.prev
      if not p then -- already at the top, we're done
        return
      end
      local n = node.next
      p.next = n
      node.next = self.head
      self.head = node
      if self.tail == node then
        if n then
          self.tail = n
        else
          self.tail = p
        end
        ML:Debug(9, "Moving exiting to front, setting tail to %", self.tail.value)
      end
      return
    end
    -- new entry, make a new node at the head:
    node = {}
    node.value = elem
    node.count = 1 -- we could also store a timestamp for time based pruning
    node.next = self.head
    if node.next then
      node.next.prev = node
    end
    self.head = node
    self.direct[elem] = node
    if not self.tail then
      self.tail = node
      ML:Debug(9, "Setting tail to %", node.value)
    end
    self.size = self.size + 1
    if self.size > self.capacity then
      -- drop the tail
      local t = self.tail
      ML:Debug(3, "Reaching capacity %, will evict %", self.size, t.value)
      t.prev.next = nil
      self.direct[t.value] = nil
    end
  end
  -- end of methods, return obj
  return obj
end

ML:Debug("Done loading MoLib.lua")
