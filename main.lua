local ITEM_BALL_GFX_FRLG = 92
local ITEM_BALL_GFX_EMERALD = 59

local function currentVersion(mod)
  if mod and mod.game and mod.game.version then return mod.game.version end
  local ok, GameVersion = pcall(require, "src.core.GameVersion")
  return ok and GameVersion.get and GameVersion.get() or nil
end
local CUSTOM_POKE = "gen3ballrarity:poke"
local CUSTOM_MASTER = "gen3ballrarity:master"
local CUSTOM_GREAT = "gen3ballrarity:great"
local CUSTOM_ULTRA = "gen3ballrarity:ultra"

local function gameIsGen3(mod)
  local version = currentVersion(mod)
  return version == "firered" or version == "leafgreen" or version == "emerald"
end

local function normalizeItem(item)
  if item == nil then return nil end
  local ItemsData = require("src.core.game3.items_data")
  return ItemsData.toNumericId(item) or tonumber(item)
end

local function itemKey(name)
  return tostring(name or ""):upper():gsub("[^A-Z0-9]", "")
end

local function findGivenItem(rows, seen, depth)
  if type(rows) ~= "table" or depth > 10 then return nil end
  seen = seen or {}
  if seen[rows] then return nil end
  seen[rows] = true

  for _, row in pairs(rows) do
    if type(row) == "table" then
      local op = row.op or row[1]
      if op == "give_item" or op == "giveitem" or op == "verbosegiveitem" then
        return row[2] or row.item
      end

      -- Ground item-ball scripts store the item in VAR_ITEM_ID (0x8000)
      -- before calling the standard item-obtain script.
      if op == "setorcopyvar" or op == "setvar" or op == "copyvar" then
        local target = row[1] or row.var
        local value = row[2] or row.value
        local itemId = value ~= nil and normalizeItem(value) or nil
        if tonumber(target) == 0x8000 and itemId then
          return itemId
        end
      end

      local found = findGivenItem(row, seen, depth + 1)
      if found ~= nil then return found end
    end
  end

  return nil
end

local function itemFromObject(def)
  local Space = require("src.core.game3.scripting.space")
  if not Space.bundle and Space.ensureBundle then
    pcall(Space.ensureBundle, Space._mod)
  end

  local direct = def and (def.itemId or def.itemID or def.item)
  if direct ~= nil then
    local id = normalizeItem(direct)
    if id then return id end
  end

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
    "POTION", "SUPER_POTION", "HYPER_POTION", "MAX_POTION",
    "FULL_RESTORE", "FULL_HEAL", "REVIVE", "MAX_REVIVE",
    "ANTIDOTE", "BURN_HEAL", "ICE_HEAL", "AWAKENING", "PARLYZ_HEAL",
    "FRESH_WATER", "SODA_POP", "LEMONADE", "MOOMOO_MILK",
    "ENERGYPOWDER", "ENERGY_ROOT", "HEAL_POWDER", "REVIVAL_HERB",
    "ETHER", "MAX_ETHER", "ELIXIR", "MAX_ELIXIR", "PP_UP", "PP_MAX",
    "REPEL", "SUPER_REPEL", "MAX_REPEL", "ESCAPE_ROPE",
    "RARE_CANDY", "NUGGET", "PEARL", "BIG_PEARL", "STARDUST", "STAR_PIECE",
    "BIG_MUSHROOM", "HEART_SCALE", "SACRED_ASH",
    "PROTEIN", "IRON", "CALCIUM", "ZINC", "CARBOS", "HP_UP",
    "FIRE_STONE", "WATER_STONE", "THUNDER_STONE", "LEAF_STONE",
    "MOON_STONE", "SUN_STONE", "DRAGON_SCALE", "KING'S ROCK",
    "GUARD_SPEC", "DIRE_HIT", "X_ATTACK", "X_DEFEND", "X_SPEED",
    "X_ACCURACY", "X_SPECIAL",
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

local function makeSet(names)
  local set = {}
  for _, name in ipairs(names) do
    set[itemKey(name)] = true
  end
  return set
end

local REGULAR_ITEMS = makeSet({
  "POTION", "ANTIDOTE", "BURN HEAL", "ICE HEAL", "AWAKENING", "PARLYZ HEAL",
  "FRESH WATER", "ENERGYPOWDER", "BERRY JUICE",
  "REPEL", "ESCAPE ROPE",
  "X ATTACK", "X DEFEND", "X SPEED", "X ACCURACY", "X SPECIAL",
  "GUARD SPEC.", "DIRE HIT",
  "CHERI BERRY", "CHESTO BERRY", "PECHA BERRY", "RAWST BERRY", "ASPEAR BERRY",
  "LEPPA BERRY", "ORAN BERRY", "PERSIM BERRY", "LUM BERRY", "SITRUS BERRY",
  "RAZZ BERRY", "BLUK BERRY", "NANAB BERRY", "WEPEAR BERRY", "PINAP BERRY",
  "TINY MUSHROOM", "PEARL", "SHOAL SALT", "SHOAL SHELL",
  "RED SHARD", "YELLOW SHARD", "GREEN SHARD", "BLUE SHARD",
})

local GREAT_ITEMS = makeSet({
  "SUPER POTION", "FULL HEAL", "REVIVE",
  "ENERGY ROOT", "HEAL POWDER",
  "SODA POP", "LEMONADE", "MOOMOO MILK",
  "ETHER", "ELIXIR",
  "SUPER REPEL",
  "BIG MUSHROOM", "HEART SCALE", "STARDUST", "STAR PIECE", "BIG PEARL",
  "PROTEIN", "IRON", "CALCIUM", "ZINC", "CARBOS", "HP UP", "PP UP",
  "FIRE STONE", "WATER STONE", "THUNDERSTONE", "LEAF STONE", "MOON STONE",
  "GREAT BALL",
})

local ULTRA_ITEMS = makeSet({
  "FULL RESTORE", "MAX POTION", "HYPER POTION",
  "MAX REVIVE", "REVIVAL HERB", "SACRED ASH",
  "MAX ETHER", "MAX ELIXIR", "PP MAX",
  "MAX REPEL", "RARE CANDY",
  "NUGGET", "ULTRA BALL",
  "SUN STONE", "DRAGON SCALE", "KINGS ROCK",
})

local function rarityForItem(item)
  if not item then return nil end

  local ItemsData = require("src.core.game3.items_data")
  local id = normalizeItem(item)
  if not id then return nil end

  local name = tostring(ItemsData.displayName(id) or ""):upper()
  local key = itemKey(name)

  if key == "MASTERBALL" then
    return "master"
  end

  if ULTRA_ITEMS[key]
      or ItemsData.isTm(id)
      or ItemsData.isHm(id) then
    return "ultra"
  end

  if GREAT_ITEMS[key] then
    return "great"
  end

  if REGULAR_ITEMS[key] then
    return "regular"
  end

  return "regular"
end

local function isGroundItemObject(def)
  if type(def) ~= "table" then return false end
  if tostring(def.service or ""):lower() == "pickup" and def.item ~= nil then return true end
  local gfx = def.graphicsId or def.graphics or def.graphics_id
  local version = currentVersion()
  local itemGfx = version == "emerald" and ITEM_BALL_GFX_EMERALD or ITEM_BALL_GFX_FRLG
  if tonumber(gfx) == itemGfx then return true end
  if tostring(gfx or ""):upper():find("ITEM_BALL", 1, true) then return true end

  -- Hoenn Journey imports Emerald item balls as source-style event objects.
  -- Their runtime graphics id is not guaranteed to be FireRed's 92, but the
  -- ground-pickup scripts consistently identify them as EventScript_Item*.
  local script = tostring(def.scriptKey or def.script or ""):upper()
  return script:find("EVENTSCRIPT_ITEM", 1, true) ~= nil
end

local function annotateObjects()
  local okO, Objects = pcall(require, "src.core.game3.objects")
  if not okO or type(Objects) ~= "table" then return end

  for _, lid in ipairs(Objects._order or {}) do
    local obj = Objects._byId and Objects._byId[lid]
    local def = obj and obj.def
    if def and isGroundItemObject(def) then
      local item = def.item or def.itemId or def.itemID or itemFromObject(def)
      local rarity = rarityForItem(item)
      def._gen3BallRarity = rarity
      obj._gen3BallRarity = rarity
      local gid
      if rarity == "master" then gid = CUSTOM_MASTER
      elseif rarity == "great" then gid = CUSTOM_GREAT
      elseif rarity == "ultra" then gid = CUSTOM_ULTRA
      else gid = CUSTOM_POKE end

      -- Vanilla Kanto item balls must keep their native definition (gfx 92).
      -- Their rarity sprite is supplied by resolveObjectGraphicsId below.
      -- Only Hoenn Journey's imported pickup definitions need to be rewritten,
      -- because its object loader can restore the Emerald graphics id (11046).
      local importedPickup = tostring(def.service or ""):lower() == "pickup"
        or tonumber(def.graphicsId or def.graphics or def.graphics_id) == 11046
      if importedPickup then
        local importedPickup = tostring(def.service or ""):lower() == "pickup"
          or tonumber(def.graphicsId or def.graphics or def.graphics_id) == 11046
        if importedPickup then
          def.graphicsId = gid
          def.graphics = gid
          obj.graphicsId = gid
          obj.gfx = gid
          obj.sprite = nil
        end
      end
    end
  end
end

return function(mod)
  if not gameIsGen3(mod) then return end

  mod.options:define({
    { key = "debug_littleroot", label = "LITTLEROOT TEST ITEMS",
      type = "toggle", default = false },
  })

  local Objects = require("src.core.game3.objects")
  local Space = require("src.core.game3.scripting.space")
  local OwSprites = require("src.core.game3.ow_sprites")

  local ballImage
  local ballQuads

  local function loadBallSheet()
    if ballImage and ballQuads then return true end

    local ok, image = pcall(mod.assets.image, mod.assets, "assets/pokeballs.png")
    if not ok or not image then return false end

    local w, h = image:getDimensions()
    if w ~= 16 or h ~= 64 then
      print(string.format(
        "[gen3-ball-rarity] assets/pokeballs.png must be 16x64, got %dx%d",
        w, h))
      return false
    end

    image:setFilter("nearest", "nearest")
    ballImage = image
    ballQuads = {
      [CUSTOM_POKE] = love.graphics.newQuad(0, 0, 16, 16, w, h),
      [CUSTOM_MASTER] = love.graphics.newQuad(0, 16, 16, 16, w, h),
      [CUSTOM_GREAT] = love.graphics.newQuad(0, 32, 16, 16, w, h),
      [CUSTOM_ULTRA] = love.graphics.newQuad(0, 48, 16, 16, w, h),
    }

    return true
  end

  -- Temporary Emerald-only test pickups. Added to the live map object
  -- definitions before the native object loader runs.
  local function injectDebugPickups(mapId, mapDef)
    if mapId ~= "EM_LITTLEROOT_TOWN"
        or mod.options:get("debug_littleroot") ~= true then return end
    local ev = Space.bundle and Space.bundle.events and Space.bundle.events[mapId]
    local defs = ev and (ev.objects or ev.objectEvents)
      or mapDef and mapDef.objects
    if type(defs) ~= "table" then return end
    local tests = {
      { "POTION", 7, 11 }, { "FULL_HEAL", 8, 11 },
      { "RARE_CANDY", 9, 11 }, { "MASTER_BALL", 10, 11 },
    }
    local used = {}
    for _, def in ipairs(defs) do
      used[tonumber(def.localId or def.index)] = true
    end
    for i, row in ipairs(tests) do
      local id = 220 + i
      if not used[id] then
        defs[#defs + 1] = {
          localId = id, x = row[2], y = row[3],
          graphicsId = ITEM_BALL_GFX_EMERALD,
          graphics = ITEM_BALL_GFX_EMERALD,
          service = "pickup", item = row[1],
          script = "EventScript_Item" .. row[1],
          _gen3BallRarityDebug = true,
        }
      end
    end
  end

  if not Objects._gen3BallRarityWrapped then
    local originalLoadMap = Objects.loadMap
    Objects.loadMap = function(game, mapId, mapDef, ...)
      injectDebugPickups(mapId, mapDef)
      local result = originalLoadMap(game, mapId, mapDef, ...)
      annotateObjects()
      return result
    end
    Objects._gen3BallRarityWrapped = true
  end

  if not Space._gen3BallRarityWrapped then
    local originalResolve = Space.resolveObjectGraphicsId
    Space.resolveObjectGraphicsId = function(obj, neighbor)
      if type(obj) == "table" then
        if isGroundItemObject(obj) then
          local rarity = obj._gen3BallRarity
          if not rarity then
            rarity = rarityForItem(obj.item or obj.itemId or obj.itemID or itemFromObject(obj))
            obj._gen3BallRarity = rarity
          end

          if rarity == "master" then return CUSTOM_MASTER end
          if rarity == "great" then return CUSTOM_GREAT end
          if rarity == "ultra" then return CUSTOM_ULTRA end
          return CUSTOM_POKE
        end
      end
      return originalResolve(obj, neighbor)
    end
    Space._gen3BallRarityWrapped = true
  end

  if not OwSprites._gen3BallRarityWrapped then
    local originalDraw = OwSprites.draw
    OwSprites.draw = function(graphicsId, px, py, camX, camY, facing, walkPhase, stepFlip, opts)
      if not loadBallSheet() then
        return originalDraw(graphicsId, px, py, camX, camY, facing, walkPhase, stepFlip, opts)
      end

      local quad = ballQuads and ballQuads[graphicsId]
      if quad then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(ballImage, quad, px - camX, py - camY)
        return true
      end

      return originalDraw(graphicsId, px, py, camX, camY, facing, walkPhase, stepFlip, opts)
    end
    OwSprites._gen3BallRarityWrapped = true
  end

  loadBallSheet()

  if mod.events then
    -- Hoenn Journey builds its imported Emerald objects during/after map setup.
    -- Re-annotate once they actually exist instead of depending on load order.
    mod.events:on("map.entered", function()
      annotateObjects()
    end)

    mod.events:on("world.npc_spawned", function(ev)
      local obj = ev and ev.runtime
      local def = obj and obj.def
      if def and isGroundItemObject(def) then
        local rarity = rarityForItem(def.item or def.itemId or def.itemID or itemFromObject(def))
        def._gen3BallRarity = rarity
        obj._gen3BallRarity = rarity
        local gid
        if rarity == "master" then gid = CUSTOM_MASTER
        elseif rarity == "great" then gid = CUSTOM_GREAT
        elseif rarity == "ultra" then gid = CUSTOM_ULTRA
        else gid = CUSTOM_POKE end
        def.graphicsId = gid
        def.graphics = gid
        obj.graphicsId = gid
        obj.gfx = gid
        obj.sprite = nil
      end
    end)

    -- Covers Hoenn Journey installs/rebinds that happen after our map-enter
    -- callback. annotateObjects is idempotent and only touches pickup actors.
    mod.events:on("world.stepped", function()
      annotateObjects()
    end)
  end
end
