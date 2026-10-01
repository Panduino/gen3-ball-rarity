local ITEM_BALL_GFX = 92
local SENTINEL_GREAT = 240
local SENTINEL_ULTRA = 241

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

local function findGivenItem(rows, seen, depth)
  if type(rows) ~= "table" or depth > 10 then return nil end
  seen = seen or {}
  if seen[rows] then return nil end
  seen[rows] = true

  for _, row in pairs(rows) do
    if type(row) == "table" then
      local op = row[1] or row.op
      if op == "give_item" then
        return row[2] or row.item
      end
      local found = findGivenItem(row, seen, depth + 1)
      if found ~= nil then return found end
    end
  end

  return nil
end

local function itemFromObject(def)
  local Space = require("src.core.game3.scripting.space")
  local key = def and (def.scriptKey or def.script)
  if type(key) ~= "string" then return nil end

  local resolved = Space.scriptKey and Space.scriptKey(key) or key
  local scripts = Space.bundle and Space.bundle.scripts
  local rows = scripts and scripts[resolved]
  local item = findGivenItem(rows, nil, 0)
  if item ~= nil then return normalizeItem(item) end

  local upper = key:upper()
  local names = {
    "MASTER_BALL", "ULTRA_BALL", "GREAT_BALL", "POKE_BALL",
    "FULL_RESTORE", "MAX_POTION", "HYPER_POTION", "SUPER_POTION",
    "FULL_HEAL", "REVIVE", "MAX_REVIVE", "MAX_ELIXIR", "ELIXIR",
    "MAX_ETHER", "ETHER", "RARE_CANDY", "NUGGET",
    "SUN_STONE", "MOON_STONE", "FIRE_STONE", "THUNDER_STONE",
    "WATER_STONE", "LEAF_STONE"
  }

  for _, name in ipairs(names) do
    if upper:find(name, 1, true) then
      return normalizeItem(name)
    end
  end

  local tm = upper:match("TM_?(%d+)")
  if tm then return normalizeItem("TM" .. tm) end
  local hm = upper:match("HM_?(%d+)")
  if hm then return normalizeItem("HM" .. hm) end

  return nil
end

local function rarityForItem(item)
  if not item then return nil end
  local ItemsData = require("src.core.game3.items_data")
  local id = normalizeItem(item)
  if not id then return nil end

  local name = tostring(ItemsData.displayName(id) or ""):upper()
  local pocket = tostring(ItemsData.pocketOf(id) or ""):upper()
  local fieldUse = tostring(ItemsData.fieldUseKind(id) or ""):lower()

  -- Significant progression and high-value utility items.
  if pocket == "KEY_ITEMS"
      or fieldUse == "tm"
      or fieldUse == "evo"
      or fieldUse == "level"
      or name:find("FOSSIL", 1, true)
      or name == "NUGGET"
      or name == "PEARL"
      or name == "BIG PEARL"
      or name == "STARDUST"
      or name == "STAR PIECE"
      or name == "COMET SHARD"
      or name == "MASTER BALL"
      or name == "ULTRA BALL" then
    return "ultra"
  end

  -- Stronger medicines and PP/status recovery.
  if name == "FULL RESTORE"
      or name == "MAX POTION"
      or name == "HYPER POTION"
      or name == "FULL HEAL"
      or name == "REVIVE"
      or name == "MAX REVIVE"
      or name == "ETHER"
      or name == "MAX ETHER"
      or name == "ELIXIR"
      or name == "MAX ELIXIR"
      or name == "GREAT BALL" then
    return "great"
  end

  return "regular"
end

local function annotateObjects()
  local okO, Objects = pcall(require, "src.core.game3.objects")
  if not okO or type(Objects) ~= "table" then return end

  for _, lid in ipairs(Objects._order or {}) do
    local obj = Objects._byId and Objects._byId[lid]
    local def = obj and obj.def
    if def and tonumber(obj.graphicsId) == ITEM_BALL_GFX then
      local rarity = rarityForItem(itemFromObject(def))
      def._gen3BallRarity = rarity
      obj._gen3BallRarity = rarity
    end
  end
end

return function(mod)
  if not gameIsGen3(mod) then return end

  local Objects = require("src.core.game3.objects")
  local Space = require("src.core.game3.scripting.space")
  local OwSprites = require("src.core.game3.ow_sprites")
  local BagChrome = require("src.ui.game3.bag_chrome")

  if not Objects._gen3BallRarityWrapped then
    local originalLoadMap = Objects.loadMap
    Objects.loadMap = function(...)
      local result = originalLoadMap(...)
      annotateObjects()
      return result
    end
    Objects._gen3BallRarityWrapped = true
  end

  if not Space._gen3BallRarityWrapped then
    local originalResolve = Space.resolveObjectGraphicsId
    Space.resolveObjectGraphicsId = function(obj, neighbor)
      if type(obj) == "table" and obj._gen3BallRarity then
        if obj._gen3BallRarity == "great" then return SENTINEL_GREAT end
        if obj._gen3BallRarity == "ultra" then return SENTINEL_ULTRA end
        return ITEM_BALL_GFX
      end
      return originalResolve(obj, neighbor)
    end
    Space._gen3BallRarityWrapped = true
  end

  if not OwSprites._gen3BallRarityWrapped then
    local originalDraw = OwSprites.draw
    OwSprites.draw = function(graphicsId, px, py, camX, camY, facing, walkPhase, stepFlip, opts)
      local itemId
      if graphicsId == SENTINEL_GREAT then
        itemId = 3
      elseif graphicsId == SENTINEL_ULTRA then
        itemId = 2
      end

      if itemId then
        local img = BagChrome.iconImage(itemId)
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
    OwSprites._gen3BallRarityWrapped = true
  end

  if mod.events then
    mod.events:on("map.entered", function(ev)
      if ev and (ev.mapId == "FR_PALLET_TOWN" or tostring(ev.mapId):find("FR_", 1, true)) then
        annotateObjects()
      end
    end)
  end
end
