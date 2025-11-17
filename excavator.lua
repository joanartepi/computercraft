--[[ 
Slot 1-13 : Blocs "poubelle" (templates pour comparaison éventuelle)
Slot 14   : Peut rester vide (utilisé au besoin, pas critique ici)
Slot 15   : Seau (bucket) – pas utilisé par défaut dans cette version
Slot 16   : Carburant
Coffre    : sous la turtle au point de départ
Usage     : excavate <X> <Z> <Y> <durée...>
]]--

local ok          = true
local tArgs       = { ... }
local ignoredFuel = 0
local oldprint    = print
local fuelAmount  = nil
local nSlots      = nil

-- Dimensions de l'excavation
local sizeX = tonumber(tArgs[1]) -- longueur avant
local sizeZ = tonumber(tArgs[2]) -- largeur
local sizeY = tonumber(tArgs[3]) -- profondeur (vers le bas)

if not sizeX or not sizeZ or not sizeY then
    error("Usage: excavate <X> <Z> <Y> <duration...>")
end

-- Arguments restants pour le timer (facultatif)
local timeArgs = {}
for i = 4, #tArgs do
    table.insert(timeArgs, tArgs[i])
end

---------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------
local function print(text)
    oldprint("[" .. os.time() .. "] " .. text)
    local file = fs.open("turtleLog", "a")
    file.writeLine("[" .. os.time() .. "] " .. text)
    file.close()
end

---------------------------------------------------------------------
-- Initialisation des slots "poubelle"
---------------------------------------------------------------------
for i = 1, 13 do
    if turtle.getItemCount(i) == 0 then
        nSlots = i - 1
        print("You have " .. nSlots .. " stacks of waste blocks, is this correct? Y/N")
        while true do
            local _, char = os.pullEvent("char")
            char = char:lower()
            if char == "n" then
                error()
            elseif char == "y" then
                break
            end
        end
        break
    end
end

if not nSlots then
    nSlots = 13
    print("You have 13 stacks of waste blocks (slots 1–13).")
end

if turtle.getItemCount(16) == 0 then
    print("Are you sure you wish to continue with no fuel in slot 16? Y/N")
    while true do
        local _, char = os.pullEvent("char")
        char = char:lower()
        if char == "n" then
            error()
        elseif char == "y" then
            break
        end
    end
end

---------------------------------------------------------------------
-- Coords & déplacements
---------------------------------------------------------------------
-- Coordonnées relatives au point de départ (0,0,0) au-dessus du coffre
-- x : vers l'avant initial, z : vers la droite initiale, y : vers le bas
local xPos, yPos, zPos = 0, 0, 0
local dir = 0  -- 0=+x, 1=+z, 2=-x, 3=-z

local needReturn = false   -- demander un retour coffre (inventaire plein, etc.)
local timeUp     = false   -- temps écoulé (trackTime)
local savedX, savedY, savedZ, savedDir = 0, 0, 0, 0

local function turnLeft()
    turtle.turnLeft()
    dir = (dir + 3) % 4
end

local function turnRight()
    turtle.turnRight()
    dir = (dir + 1) % 4
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
end

local function up()
    while turtle.detectUp() do turtle.digUp() end
    while not turtle.up() do
        turtle.attackUp()
        turtle.digUp()
    end
    yPos = yPos - 1
end

local function down()
    while turtle.detectDown() do turtle.digDown() end
    while not turtle.down() do
        turtle.attackDown()
        turtle.digDown()
    end
    yPos = yPos + 1
end

local function face(targetDir)
    while dir ~= targetDir do
        -- calcul du meilleur sens de rotation
        local diff = (targetDir - dir) % 4
        if diff == 1 then
            turnRight()
        elseif diff == 3 then
            turnLeft()
        else
            -- 2
            turnRight()
            turnRight()
        end
    end
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
        face(0) -- +x
        while xPos < targetX do
            forward()
        end
    elseif xPos > targetX then
        face(2) -- -x
        while xPos > targetX do
            forward()
        end
    end

    -- Ajuster Z
    if zPos < targetZ then
        face(1) -- +z
        while zPos < targetZ do
            forward()
        end
    elseif zPos > targetZ then
        face(3) -- -z
        while zPos > targetZ do
            forward()
        end
    end
end

---------------------------------------------------------------------
-- Gestion des déchets
---------------------------------------------------------------------
local function dumpWaste()
    while ok do
        for i = 1, nSlots do
            local count = turtle.getItemCount(i)
            if count > 1 then
                turtle.select(i)
                turtle.drop(count - 1)
            end
        end
        local id = os.startTimer(10)
        while true do
            local _, tid = os.pullEvent("timer")
            if tid == id then break end
        end
    end
end

---------------------------------------------------------------------
-- Excavation bas niveau
---------------------------------------------------------------------
local function digForward2High()
    forward()
    if turtle.detectUp() then turtle.digUp() end
end

local function dropInventory()
    print("[return]: Dropping inventory into chest below!")
    for i = 5, 16 do
        turtle.select(i)
        turtle.dropDown()
    end
end

local function returnAndMaybeResume()
    print("[return]: Handling return to chest...")

    -- Sauvegarder la position actuelle
    savedX, savedY, savedZ, savedDir = xPos, yPos, zPos, dir

    -- Aller au point de départ (0,0,0)
    goTo(0, 0, 0)
    face(0)

    -- Déposer le contenu dans le coffre sous la turtle
    dropInventory()

    if timeUp or not ok then
        print("[return]: Time is up or script stopped, not resuming mining.")
        needReturn = false
        return
    end

    -- Revenir à la position sauvegardée
    print(string.format("[return]: Resuming mining at (%d,%d,%d)", savedX, savedY, savedZ))
    goTo(savedX, savedY, savedZ)
    face(savedDir)
    needReturn = false
end

---------------------------------------------------------------------
-- Excavation d’une couche (2D) sizeX × sizeZ, à la profondeur courante
---------------------------------------------------------------------
local function excavateLayer()
    -- On suppose qu'on se trouve au coin (0,y,z=0) de cette couche et qu'on regarde +x
    face(0)

    for row = 0, sizeZ - 1 do
        -- creuser cette ligne
        for col = 1, sizeX - 1 do
            if needReturn then
                returnAndMaybeResume()
                if timeUp or not ok then return end
            end
            digForward2High()
        end

        -- Aller à la ligne suivante si ce n'était pas la dernière
        if row < sizeZ - 1 then
            if row % 2 == 0 then
                -- on est à x = sizeX - 1, aller à z+1 et revenir dans l'autre sens
                turnRight()
                digForward2High()
                turnRight()
            else
                -- on est à x = 0
                turnLeft()
                digForward2High()
                turnLeft()
            end
        end
    end

    -- Revenir au coin de la couche (x=0,z=0,y inchangé)
    goTo(0, yPos, 0)
    face(0)
end

---------------------------------------------------------------------
-- Excavation complète 3D : sizeX × sizeZ × sizeY
---------------------------------------------------------------------
local function excavateVolume()
    print(string.format("[main]: Excavating volume %dx%dx%d", sizeX, sizeZ, sizeY))

    -- On part de (0,0,0) au-dessus du coffre, on va creuser vers le bas
    for layer = 1, sizeY do
        if needReturn then
            returnAndMaybeResume()
            if timeUp or not ok then return end
        end

        print("[main]: Starting layer " .. layer .. "/" .. sizeY)

        -- descendre d'un bloc pour entrer dans la nouvelle couche
        down()

        -- creuser la couche à cette profondeur
        excavateLayer()

        if timeUp or not ok then
            break
        end
    end

    print("[main]: Excavation loop finished, returning to chest.")
    -- Retour final au coffre
    goTo(0, 0, 0)
    face(0)
    dropInventory()
end

---------------------------------------------------------------------
-- Gestion fuel / sécurité / timer
---------------------------------------------------------------------
local function findMaxLevel()
    local level = turtle.getFuelLevel()
    if turtle.getItemCount(16) > 1 then
        if not fuelAmount then
            turtle.select(16)
            turtle.refuel(1)
            fuelAmount = turtle.getFuelLevel() - level
            print("[findMaxLevel]: Found fuelAmount: " .. fuelAmount)
        end
        local maxLevel = turtle.getItemCount(16) * fuelAmount + turtle.getFuelLevel()
        print("[findMaxLevel]: Found max level: " .. maxLevel .. "!")
        return maxLevel
    else
        print("[findMaxLevel]: Found max level: " .. turtle.getFuelLevel() .. "!")
        return turtle.getFuelLevel()
    end
end

local function isOk()
    local okLevel = findMaxLevel() / 2 + 10
    while ok do
        local currentLevel = turtle.getFuelLevel()

        -- Vérifier le fuel
        if currentLevel < 100 then
            print("[isOk]: Fuel Level Low!")
            if turtle.getItemCount(16) > 0 then
                print("[isOk]: Refueling!")
                turtle.select(16)
                if turtle.refuel(1) then
                    print("[isOk]: Refuel Successful!")
                else
                    print("[isOk]: Refuel Unsuccessful, Initiating return and stop!")
                    ok = false
                    needReturn = true
                end
            else
                print("[isOk]: No fuel in slot 16, Initiating return and stop!")
                ok = false
                needReturn = true
            end
        elseif okLevel - ignoredFuel > findMaxLevel() then
            print("[isOk]: Fuel Reserves Depleted!  Initiating return and stop!")
            ok = false
            needReturn = true
        end

        -- Vérifier l'espace dans l'inventaire
        local hasSpace = false
        for i = 5, 15 do
            if turtle.getItemCount(i) == 0 then
                hasSpace = true
                break
            end
        end

        if not hasSpace and ok then
            print("[isOk]: Out of space! Returning to chest, will resume mining!")
            needReturn = true
        elseif ok then
            print("[isOk]: Everything is OK!")
            local id = os.startTimer(10)
            while true do
                local _, tid = os.pullEvent("timer")
                if tid == id then break end
            end
        end
    end
end

local function trackTime()
    if #timeArgs == 0 then
        print("[trackTime]: No valid duration provided, running without time limit.")
        return
    end

    local sTime = table.concat(timeArgs, " ")
    local nSeconds = 0

    for numStr, period in sTime:gmatch("(%d+)%s+(%a+)s?") do
        local i = tonumber(numStr)
        if i then
            local p = period:lower()
            if p == "second" or p == "seconds" then
                nSeconds = nSeconds + i
            elseif p == "minute" or p == "minutes" then
                nSeconds = nSeconds + (i * 60)
            elseif p == "hour" or p == "hours" then
                nSeconds = nSeconds + (i * 3600)
            end
        end
    end

    if nSeconds <= 0 then
        print("[trackTime]: No valid duration parsed, running without time limit.")
        return
    end

    print("[trackTime]: Starting timer for " .. nSeconds .. " seconds!")
    local id = os.startTimer(nSeconds)
    while ok do
        local _, tid = os.pullEvent("timer")
        if id == tid then
            print("[trackTime]: End of session reached! Returning to base and stopping!")
            timeUp = true
            ok = false
        end
    end
end

---------------------------------------------------------------------
-- Lancement parallèle
---------------------------------------------------------------------
parallel.waitForAll(trackTime, isOk, excavateVolume, dumpWaste)
