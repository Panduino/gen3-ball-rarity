local ITEM_BALL_GFX = 92
local MASTER_BALL_ID = 1
local NUGGET_ID = 110
local SENTINEL_MASTER = 242

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
  if type(rows) ~= "table" or depth > 10 then return false end
  seen = seen or {}
  if seen[rows] then return false end
  seen[rows] = true

  local changed = false
  for _, row in pairs(rows) do
    if type(row) == "table" then
      local op = row[1] or row.op
      if op == "give_item" then
        local item = normalizeItem(row[2] or row.item)
        if item == NUGGET_ID then
          if row[1] ~= nil then
            row[2] = MASTER_BALL_ID
          else
            row.item = MASTER_BALL_ID
          end
          changed = true
        end
      else
        if replaceNuggets(row, seen, depth + 1) then
          changed = true
        end
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
  local rows = scriptForObject(def)
  if not rows then return false end
  return replaceNuggets(rows, nil, 0)
end

return function(mod)
  if not gameIsGen3(mod) then return end

  local Objects = require("src.core.game3.objects")
  local Space = require("src.core.game3.scripting.space")
  local OwSprites = require("src.core.game3.ow_sprites")
  local BagChrome = require("src.ui.game3.bag_chrome")

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
          obj._gen3NuggetMasterBall = true
          return SENTINEL_MASTER
        end
      end

      return originalResolve(obj, neighbor)
    end
    Space._gen3NuggetMasterBallWrapped = true
  end

  if not OwSprites._gen3NuggetMasterBallWrapped then
    local originalDraw = OwSprites.draw
    OwSprites.draw = function(graphicsId, px, py, camX, camY, facing, walkPhase, stepFlip, opts)
      if graphicsId == SENTINEL_MASTER then
        local img = BagChrome.iconImage(MASTER_BALL_ID)
        if img then
          local scale = 2 / 3
          local w, h = img:getDimensions()
          local sx = px - camX + (16 - w * scale) / 2
          local sy = py - camY + (16 - h * scale)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(img, sx, sy, 0, scale, scale)
          return true
        end
      end

      return originalDraw(graphicsId, px, py, camX, camY, facing, walkPhase, stepFlip, opts)
    end
    OwSprites._gen3NuggetMasterBallWrapped = true
  end
end
