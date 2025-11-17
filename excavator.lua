--[[
Excavation complète d'un volume X × Z × Y
- X : longueur (avant la turtle)
- Z : largeur (sur le côté droit)
- Y : profondeur (vers le bas)

Disposition :
- La turtle démarre à (0,0,0), tournée vers +X (avant).
- Un coffre est placé DIRECTEMENT DERRIÈRE la turtle (direction -X).
- Le volume miné commence sous la turtle (on descend d'un bloc avant de creuser).

Slots :
- 1..14 : loot
- 15    : seau (bucket) pour la lave
- 16    : fuel solide (charbon, etc.)

Usage :
  excavator <X> <Z> <Y> <durée...>
Exemples :
  excavator 16 16 8 1 hour
  excavator 10 5 3 30 minutes
]]--

local oldprint = print
local function print(text)
  oldprint("[" .. os.time() .. "] " .. text)
  local file = fs.open("turtleLog", "a")
  file.writeLine("[" .. os.time() .. "] " .. text)
  file.close()
end

local args = { ... }
local ok        = true
local timeUp    = false
local needReturn = false

-- Dimensions
local sizeX = tonumber(args[1])
local sizeZ = tonumber(args[2])
local sizeY = tonumber(args[3])

if not sizeX or not sizeZ or not sizeY then
  error("Usage: excavator <X> <Z> <Y> <duration...>")
end

-- Args restants pour le timer
local timeArgs = {}
for i = 4, #args do
  table.insert(timeArgs, args[i])
end

---------------------------------------------------------------------
-- Vérification fuel de départ
---------------------------------------------------------------------
if turtle.getItemCount(16) == 0 then
  print("No fuel in slot 16. Continue anyway? (Y/N)")
  while true do
    local _, ch = os.pullEvent("char")
    ch = ch:lower()
    if ch == "n" then error("Aborted: no fuel.") end
    if ch == "y" then break end
  end
end

---------------------------------------------------------------------
-- Coordonnées et orientation
---------------------------------------------------------------------
-- Coordonnées relatives au point de départ (0,0,0)
-- x : avant, z : droite, y : vers le bas
local xPos, yPos, zPos = 0, 0, 0
local dir = 0  -- 0=+x, 1=+z, 2=-x, 3=-z

-- Pour reprise après dépôt
local savedX, savedY, savedZ, savedDir = 0, 0, 0, 0

local function turnLeft()
  turtle.turnLeft()
  dir = (dir + 3) % 4
  os.sleep(0)
end

local function turnRight()
  turtle.turnRight()
  dir = (dir + 1) % 4
  os.sleep(0)
end

local function face(targetDir)
  while dir ~= targetDir do
    local diff = (targetDir - dir) % 4
    if diff == 1 then
      turnRight()
    elseif diff == 3 then
      turnLeft()
    else
      turnRight()
      turnRight()
    end
  end
end

local function forward()
  while turtle.detect() do turtle.dig() end
  while not turtle.forward() do
    turtle.attack()
    turtle.dig()
  end
  if dir == 0 then
    xPos = xPos + 1
  elseif dir == 1 then
    zPos = zPos + 1
  elseif dir == 2 then
    xPos = xPos - 1
  else
    zPos = zPos - 1
  end
  os.sleep(0) -- yield
end

local function up()
  while turtle.detectUp() do turtle.digUp() end
  while not turtle.up() do
    turtle.attackUp()
    turtle.digUp()
  end
  yPos = yPos - 1
  os.sleep(0)
end

local function down()
  while turtle.detectDown() do turtle.digDown() end
  while not turtle.down() do
    turtle.attackDown()
    turtle.digDown()
  end
  yPos = yPos + 1
  os.sleep(0)
end

local function goTo(targetX, targetY, targetZ)
  -- Ajuster Y d'abord
  while yPos < targetY do
    down()
  end
  while yPos > targetY do
    up()
  end

  -- Ajuster X
  if xPos < targetX then
    face(0)
    while xPos < targetX do forward() end
  elseif xPos > targetX then
    face(2)
    while xPos > targetX do forward() end
  end

  -- Ajuster Z
  if zPos < targetZ then
    face(1)
    while zPos < targetZ do forward() end
  elseif zPos > targetZ then
    face(3)
    while zPos > targetZ do forward() end
  end
end

---------------------------------------------------------------------
-- Inventaire & coffre derrière
---------------------------------------------------------------------
local function hasInventorySpace()
  -- slots 1..14 = loot, 15 bucket, 16 fuel
  for i = 1, 14 do
    if turtle.getItemCount(i) == 0 then
      return true
    end
  end
  return false
end

local function dropInventory()
  print("[return]: Dropping inventory into chest behind!")
  face(2) -- regarder -X (coffre derrière)
  for i = 1, 14 do
    turtle.select(i)
    turtle.drop()      -- on drop DANS le coffre derrière
  end
  os.sleep(0)
end

local function savePosition()
  savedX, savedY, savedZ, savedDir = xPos, yPos, zPos, dir
end

local function restorePosition()
  goTo(savedX, savedY, savedZ)
  face(savedDir)
end

local function returnAndMaybeResume()
  print("[return]: Handling return to chest...")

  savePosition()

  -- Retour au point de départ (0,0,0)
  goTo(0, 0, 0)
  face(0)

  -- Déposer l’inventaire
  dropInventory()

  if timeUp or not ok then
    print("[return]: Time is up or script stopped, not resuming mining.")
    needReturn = false
    return
  end

  print(string.format("[return]: Resuming at (%d,%d,%d)", savedX, savedY, savedZ))
  restorePosition()
  needReturn = false
end

---------------------------------------------------------------------
-- Refuel avec lave (seau en slot 15)
---------------------------------------------------------------------
local function tryRefuelFromLavaDirection(placeFunc)
  if turtle.getItemCount(15) == 0 then return false end
  turtle.select(15)
  if placeFunc() then
    -- On a peut-être pris de la lave dans le seau
    if turtle.refuel() then
      print("[fuel]: Refueled using lava!")
      os.sleep(0)
      return true
    else
      -- Pas de lava (eau, autre) -> replacer
      turtle.place()
    end
  end
  return false
end

local function tryRefuelFromLava()
  print("[fuel]: Trying to refuel from lava...")
  -- Essayer devant
  if tryRefuelFromLavaDirection(turtle.place) then return true end
  -- Essayer en dessous
  if tryRefuelFromLavaDirection(turtle.placeDown) then return true end
  -- Essayer au-dessus
  if tryRefuelFromLavaDirection(turtle.placeUp) then return true end
  -- Essayer droite/gauche en se tournant
  face(1)
  if tryRefuelFromLavaDirection(turtle.place) then face(0); return true end
  face(3)
  if tryRefuelFromLavaDirection(turtle.place) then face(0); return true end
  face(0)
  print("[fuel]: No lava source found to refuel.")
  return false
end

---------------------------------------------------------------------
-- Minage de bas niveau
---------------------------------------------------------------------
local function digForward2High()
  forward()
  if turtle.detectUp() then turtle.digUp() end
  os.sleep(0)
end

---------------------------------------------------------------------
-- Excavation d’une couche horizontale (X × Z) à la profondeur actuelle
---------------------------------------------------------------------
local function excavateLayer()
  -- On part de (0,y,0) de la couche, en regardant +x
  face(0)

  for row = 0, sizeZ - 1 do
    for col = 1, sizeX - 1 do
      if not ok then return end
      if needReturn then
        returnAndMaybeResume()
        if timeUp or not ok then return end
      end
      digForward2High()
    end

    if row < sizeZ - 1 then
      if row % 2 == 0 then
        -- On est en x = sizeX - 1
        turnRight()
        digForward2High()
        turnRight()
      else
        -- On est en x = 0
        turnLeft()
        digForward2High()
        turnLeft()
      end
    end
  end

  -- Revenir au coin (0,y,0) de la couche
  goTo(0, yPos, 0)
  face(0)
end

---------------------------------------------------------------------
-- Excavation complète : Y couches successives vers le bas
---------------------------------------------------------------------
local function excavateVolume()
  print(string.format("[main]: Excavating %dx%dx%d", sizeX, sizeZ, sizeY))
  print("[main]: Chest must be behind the turtle at start.")

  for layer = 1, sizeY do
    if not ok then break end
    if needReturn then
      returnAndMaybeResume()
      if timeUp or not ok then break end
    end

    print("[main]: Starting layer " .. layer .. "/" .. sizeY)

    down()          -- descendre dans la nouvelle couche
    excavateLayer() -- creuser X×Z à cette profondeur
  end

  print("[main]: Excavation finished or stopped, returning to chest.")
  goTo(0, 0, 0)
  face(0)
  dropInventory()
end

---------------------------------------------------------------------
-- Gestion fuel / sécurité
---------------------------------------------------------------------
local function isOk()
  while ok do
    local fuel = turtle.getFuelLevel()

    -- Fuel bas -> essayer de refuel
    if fuel ~= "unlimited" and fuel < 200 then
      print("[isOk]: Fuel low (" .. fuel .. ")!")
      if turtle.getItemCount(16) > 0 then
        turtle.select(16)
        if turtle.refuel(1) then
          print("[fuel]: Refueled from slot 16.")
        else
          print("[fuel]: Cannot refuel from slot 16.")
        end
      else
        -- Pas de fuel solide : essayer la lave
        if not tryRefuelFromLava() then
          print("[fuel]: No fuel available, returning and stopping.")
          ok = false
          needReturn = true
        end
      end
    end

    -- Vérifier l'inventaire
    if ok and not hasInventorySpace() then
      print("[isOk]: Inventory full, returning to chest (will resume).")
      needReturn = true
    end

    if ok then
      print("[isOk]: Everything OK.")
      local id = os.startTimer(10)
      while true do
        local _, tid = os.pullEvent("timer")
        if tid == id then break end
      end
    end
  end
end

---------------------------------------------------------------------
-- Gestion du temps (optionnelle)
---------------------------------------------------------------------
local function trackTime()
  if #timeArgs == 0 then
    print("[trackTime]: No duration provided, running without time limit.")
    return
  end

  local sTime = table.concat(timeArgs, " ")
  local nSeconds = 0

  for numStr, period in sTime:gmatch("(%d+)%s+(%a+)s?") do
    local n = tonumber(numStr)
    if n then
      local p = period:lower()
      if p == "second" or p == "seconds" then
        nSeconds = nSeconds + n
      elseif p == "minute" or p == "minutes" then
        nSeconds = nSeconds + n * 60
      elseif p == "hour" or p == "hours" then
        nSeconds = nSeconds + n * 3600
      end
    end
  end

  if nSeconds <= 0 then
    print("[trackTime]: Could not parse duration, running without time limit.")
    return
  end

  print("[trackTime]: Timer started for " .. nSeconds .. " seconds.")
  local id = os.startTimer(nSeconds)
  while ok do
    local _, tid = os.pullEvent("timer")
    if tid == id then
      print("[trackTime]: Time over, returning and stopping.")
      timeUp = true
      ok = false
    end
  end
end

---------------------------------------------------------------------
-- Lancement parallèle
---------------------------------------------------------------------
parallel.waitForAll(trackTime, isOk, excavateVolume)
