local ITEM_BALL_GFX = 92
local MASTER_BALL_ID = 1
local NUGGET_ID = 110
local SENTINEL_MASTER = 237

local function gameIsGen3(mod)
  if mod and mod.game and (mod.game.version == "firered" or mod.game.version == "leafgreen") then
    return true
  end
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  if ok and GameVersion.get then
    local version = GameVersion.get()
    return version == "firered" or version == "leafgreen"
  end
  return false
end

local function normalizeItem(item)
  if item == nil then return nil end
  local ItemsData = require("src.core.game3.items_data")
  return ItemsData.toNumericId(item) or tonumber(item)
end

local function replaceNuggets(rows, seen, depth)
  if type(rows) ~= "table" or depth > 20 then return false end
  seen = seen or {}
  if seen[rows] then return false end
  seen[rows] = true

  local changed = false
  for _, row in pairs(rows) do
    if type(row) == "table" then
      local op = row.op or row[1]

      if op == "give_item" or op == "giveitem" or op == "verbosegiveitem" then
        local item = normalizeItem(row[2] or row.item)
        if item == NUGGET_ID then
          if row.op ~= nil then
            if row.item ~= nil then
              row.item = MASTER_BALL_ID
            else
              row[2] = MASTER_BALL_ID
            end
          else
            row[2] = MASTER_BALL_ID
          end
          changed = true
        end

      elseif op == "setorcopyvar" or op == "setvar" or op == "copyvar" then
        local target = row.var or row[1]
        local value = row.value or row[2]
        if tonumber(target) == 0x8000 and normalizeItem(value) == NUGGET_ID then
          if row.value ~= nil then
            row.value = MASTER_BALL_ID
          else
            row[2] = MASTER_BALL_ID
          end
          changed = true
        end
      end

      if replaceNuggets(row, seen, depth + 1) then
        changed = true
      end
    end
  end

  return changed
end

local function scriptForObject(def)
  local Space = require("src.core.game3.scripting.space")
  if not Space.bundle and Space.ensureBundle then
    pcall(Space.ensureBundle, Space._mod)
  end

  local key = def and (def.scriptKey or def.script)
  if type(key) ~= "string" then return nil end

  local resolved = Space.scriptKey and Space.scriptKey(key) or key
  local scripts = Space.bundle and Space.bundle.scripts
  return scripts and scripts[resolved]
end

local function objectContainsNugget(def)
  if type(def) ~= "table" then return false end

  local direct = def.itemId or def.itemID or def.item
  if direct ~= nil and normalizeItem(direct) == NUGGET_ID then
    return true
  end

  local rows = scriptForObject(def)
  if not rows then return false end
  return replaceNuggets(rows, nil, 0)
end

return function(mod)
  if not gameIsGen3(mod) then return end

  local Objects = require("src.core.game3.objects")
  local Space = require("src.core.game3.scripting.space")

  if not Objects._gen3NuggetMasterBallWrapped then
    local originalLoadMap = Objects.loadMap
    Objects.loadMap = function(...)
      local result = originalLoadMap(...)
      return result
    end
    Objects._gen3NuggetMasterBallWrapped = true
  end

  if not Space._gen3NuggetMasterBallWrapped then
    local originalResolve = Space.resolveObjectGraphicsId
    Space.resolveObjectGraphicsId = function(obj, neighbor)
      if type(obj) == "table" then
        if obj._gen3NuggetMasterBall then
          return SENTINEL_MASTER
        end

        local baseGfx = tonumber(obj.graphicsId or obj.graphics)
        if baseGfx == ITEM_BALL_GFX and objectContainsNugget(obj) then
          -- Item balls use def.item when they are collected. Change it before
          -- the runtime object is spawned so the pickup itself gives a Master Ball.
          if obj.item ~= nil then
            obj.item = MASTER_BALL_ID
          elseif obj.itemId ~= nil then
            obj.itemId = MASTER_BALL_ID
          elseif obj.itemID ~= nil then
            obj.itemID = MASTER_BALL_ID
          end
          obj._gen3NuggetMasterBall = true
          return SENTINEL_MASTER
        end
      end

      return originalResolve(obj, neighbor)
    end
    Space._gen3NuggetMasterBallWrapped = true
  end

  -- Graphics 237 is the Master Ball frame registered by the compatible
  -- gen3-ball-rarity mod. Let the normal overworld renderer draw it.
  end
end
