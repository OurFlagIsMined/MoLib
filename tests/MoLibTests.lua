--[[
  MoLib -- (c) 2009-2019 moorea@ymail.com (MooreaTv)
  Covered by the GNU General Public License version 3 (GPLv3)
  NO WARRANTY
  (contact the author if you need a different license)
]] --
--
local libName = "MoLibTests"

_G[libName] = {}
local MLT = _G[libName]

MLT.debug = 9

local ns = {}

-- Simulating a few wow functions we use

_G.DEFAULT_CHAT_FRAME = {
  AddMessage = function(_, msg)
    print(msg)
  end
}

_G.GetAddOnMetadata = function(addon, key)
  return "<a=" .. addon .. ", k=" .. key .. ">"
end

_G.GetServerTime = function()
  return os.time()
end

_G.UnitFullName = function(name)
  MLT:Debug(3, "Inside UnitFullName for %", name)
  return name .. "1", "My'Realm"
end

local f = assert(loadfile("../MoLib.lua"))
f(libName, ns)

MLT:Debug("Debug with default level")
assert(not MLT:MoLibInit(), "first init should return false")
assert(MLT:MoLibInit(), "second init should return true")
assert(MLT:MoLibInit(), "like 2nd one, should be true")

local rnum = math.random()
local randomId = string.format("%.25f", rnum):sub(3)
MLT:Debug("random id %", randomId)
MLT:Debug("RandomId 6 is %", MLT:RandomId(6))

MLT:Debug("Mlt is %", {MLT:GetMyFQN()})

local lru1 = MLT.LRU(3)
local lru2 = MLT.LRU(4)

MLT:Debug("lru2 = %", lru2)

lru1:add("1 abc")
lru1:add("2 def")
lru2:add("1")
lru2:add("2")
lru1:add("3 ghi")
lru1:add("1 abc")
lru1:add("1 abc") -- test already at top addition
lru1:add("4 jkl") -- will evict def and not abc
lru1:add("2 def") -- put back a deleted/dropped one (count should be 1, not 2)
lru2:add("3")
lru2:add("4")
lru2:add("5")
lru2:add("2")
lru2:add("6")
lru2:add("7")
lru2:add("8")

MLT:Debug("lru1 = %", lru1)
MLT:Debug("lru2 = %", lru2)

print("---table1, newest first---")
for v, c in lru1.iterateNewest() do
  MLT:Debug("lru1 newest v=% c=%", v, c)
end
print("---table1, oldest first---")
for v, c in lru1.iterateOldest() do
  MLT:Debug("lru1 newest v=% c=%", v, c)
end
print("---table2, newest first---")
for v, c in lru2.iterateNewest() do
  MLT:Debug("lru2 v=% c=%", v, c)
end
print("---table2, oldest first---")
for v, c in lru2.iterateOldest() do
  MLT:Debug("lru2 v=% c=%", v, c)
end