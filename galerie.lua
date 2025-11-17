--[[ 
Slot 1-13 : Blocs "poubelle" (templates pour comparaison)
Slot 14   : Doit rester vide (utilisé pour détecter liquides/air)
Slot 15   : Seau (bucket)
Slot 16   : Carburant
Coffre : sous la turtle au point de départ
]]--

local ok, tArgs, ignoredFuel, oldprint, fuelAmount, nSlots = true, { ... }, 0, print, nil

-- Paramètres des galeries optimisées
local CHUNK_SIZE              = 16
local TUNNEL_CHUNKS           = 4                 -- 4 chunks de long
local TUNNEL_LENGTH           = CHUNK_SIZE * TUNNEL_CHUNKS -- 64 blocs
local GAP_BETWEEN_TUNNELS     = 2                 -- 2 blocs pleins entre chaque galerie
local TUNNEL_SPACING          = GAP_BETWEEN_TUNNELS + 1 -- distance entre centres = 3
local NUM_TUNNELS             = math.floor(TUNNEL_LENGTH / TUNNEL_SPACING)

-- État pour gérer les couches et reprise
local sideOffset   = 0      -- décalage latéral actuel (par rapport à la première galerie)
local layerDepth   = 0      -- nombre de descente de 4 blocs effectuées
local needReturn   = false  -- demande de retour au coffre (inventaire plein, etc.)
local timeUp       = false  -- le temps de session est écoulé
local savedLayer   = 0      -- couche à laquelle reprendre
local savedOffset  = 0      -- offset latéral auquel reprendre

---------------------------------------------------------------------
-- Initialisation des slots "poubelle"
---------------------------------------------------------------------

for i = 1, 13 do
    if turtle.getItemCount(i) == 0 then
        nSlots = i - 1
        print("You have " .. nSlots .. " stacks of waste blocks, is this correct? Y/N")
        while true do
            local _, char = os.pullEvent("char")
            if char:lower() == "n" then
                error()
            elseif char:lower() == "y" then
                break
            end
        end
        break
    end
end

-- Si tous les slots 1–13 sont remplis, nSlots reste nil : on corrige
if not nSlots then
    nSlots = 13
    print("You have 13 stacks of waste blocks (slots 1–13).")
end

if turtle.getItemCount(15) ~= 1 then
    error("Place a single bucket in slot 15")
end
if turtle.getItemCount(16) == 0 then
    print("Are you sure you wish to continue with no fuel in slot 16? Y/N")
    while true do
        local _, char = os.pullEvent("char")
        if char:lower() == "n" then
            error()
        elseif char:lower() == "y" then
            break
        end
    end
end

---------------------------------------------------------------------
-- Logging
---------------------------------------------------------------------

local function print(text)
    oldprint("[" .. os.time() .. "]" .. text)
    local file = fs.open("turtleLog", "a")
    file.writeLine("[" .. os.time() .. "]" .. text)
    file.close()
end

---------------------------------------------------------------------
-- Gestion des déchets
---------------------------------------------------------------------

function dumpWaste()
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
            if tid == id then
                break
            end
        end
    end
end

function notwaste(func)
    for i = 1, nSlots do
        turtle.select(i)
        if func() then
            return false
        end
    end
    if func == turtle.compare then
        return turtle.detect()
    elseif func == turtle.compareDown then
        return turtle.detectDown()
    elseif func == turtle.compareUp then
        return turtle.detectUp()
    end
end

---------------------------------------------------------------------
-- Détection lava / inventaire / ores (inchangé)
---------------------------------------------------------------------

function check(nLevel)
    if not nLevel then
        nLevel = 1
    elseif nLevel > 200 then
        return
    end
    if not ok then return end

    --check for lava (devant)
    turtle.select(14)
    if turtle.getItemCount(14) == 0 and not turtle.compare() and not turtle.detect() then
        turtle.select(15)
        if turtle.place() then
            print("[check]: Liquid detected!")
            if turtle.refuel() then
                print("[check]: Refueled using lava source!")
                turtle.forward()
                check(nLevel + 1)
                while not turtle.back() do end
                ignoredFuel = ignoredFuel + 2
            else
                print("[check]: Liquid was not lava!")
                turtle.place()
            end
        end
    end
    --check for inventories (devant)
    if turtle.detect() and turtle.suck() then
        while turtle.suck() do end
    end
    --check for ore (devant)
    if notwaste(turtle.compare) then
        print("[check]: Ore Detected!")
        repeat turtle.dig() until turtle.forward()
        print("[check]: Dug ore!")
        check(nLevel + 1)
        while not turtle.back() do end
        ignoredFuel = ignoredFuel + 2
    end
    if not ok then return end

    turtle.turnLeft()
    --check for lava (gauche)
    turtle.select(14)
    if turtle.getItemCount(14) == 0 and not turtle.compare() and not turtle.detect() then
        turtle.select(15)
        if turtle.place() then
            print("[check]: Liquid detected!")
            if turtle.refuel() then
                print("[check]: Refueled using lava source!")
                turtle.forward()
                check(nLevel + 1)
                while not turtle.back() do end
                ignoredFuel = ignoredFuel + 2
            else
                print("[check]: Liquid was not lava!")
                turtle.place()
            end
        end
    end
    --check for inventories (gauche)
    if turtle.detect() and turtle.suck() then
        while turtle.suck() do end
    end
    --check for ore (gauche)
    if notwaste(turtle.compare) then
        print("[check]: Ore Detected!")
        repeat turtle.dig() until turtle.forward()
        print("[check]: Dug ore!")
        check(nLevel + 1)
        while not turtle.back() do end
        ignoredFuel = ignoredFuel + 2
    end
    turtle.turnRight()
    if not ok then return end

    turtle.turnRight()
    --check for lava (droite)
    turtle.select(14)
    if turtle.getItemCount(14) == 0 and not turtle.compare() and not turtle.detect() then
        turtle.select(15)
        if turtle.place() then
            print("[check]: Liquid detected!")
            if turtle.refuel() then
                print("[check]: Refueled using lava source!")
                turtle.forward()
                check(nLevel + 1)
                while not turtle.back() do end
                ignoredFuel = ignoredFuel + 2
            else
                print("[check]: Liquid was not lava!")
                turtle.place()
            end
        end
    end
    --check for inventories (droite)
    if turtle.detect() and turtle.suck() then
        while turtle.suck() do end
    end
    --check for ore (droite)
    if notwaste(turtle.compare) then
        print("[check]: Ore Detected!")
        repeat turtle.dig() until turtle.forward()
        print("[check]: Dug ore!")
        check(nLevel + 1)
        while not turtle.back() do end
        ignoredFuel = ignoredFuel + 2
    end
    turtle.turnLeft()
    if not ok then return end

    --check for lava (haut)
    turtle.select(14)
    if turtle.getItemCount(14) == 0 and not turtle.compareUp() and not turtle.detectUp() then
        turtle.select(15)
        if turtle.placeUp() then
            print("[check]: Liquid detected!")
            if turtle.refuel() then
                print("[check]: Refueled using lava source!")
                turtle.up()
                check(nLevel + 1)
                while not turtle.down() do end
                ignoredFuel = ignoredFuel + 2
            else
                print("[check]: Liquid was not lava!")
                turtle.placeUp()
            end
        end
    end
    --check for inventories (haut)
    if turtle.detectUp() and turtle.suckUp() then
        while turtle.suckUp() do end
    end
    --check for ore (haut)
    if notwaste(turtle.compareUp) then
        print("[check]: Ore Detected!")
        repeat turtle.digUp() until turtle.up()
        print("[check]: Dug ore!")
        check(nLevel + 1)
        while not turtle.down() do end
        ignoredFuel = ignoredFuel + 2
    end
    if not ok then return end

    --check for lava (bas)
    turtle.select(14)
    if turtle.getItemCount(14) == 0 and not turtle.compareDown() and not turtle.detectDown() then
        turtle.select(15)
        if turtle.placeDown() then
            print("[check]: Liquid detected!")
            if turtle.refuel() then
                print("[check]: Refueled using lava source!")
                turtle.down()
                check(nLevel + 1)
                while not turtle.up() do end
                ignoredFuel = ignoredFuel + 2
            else
                print("[check]: Liquid was not lava!")
                turtle.placeDown()
            end
        end
    end
    --check for inventories (bas)
    if turtle.detectDown() and turtle.suckDown() then
        while turtle.suckDown() do end
    end
    --check for ore (bas)
    if notwaste(turtle.compareDown) then
        print("[check]: Ore Detected!")
        repeat turtle.digDown() until turtle.down()
        print("[check]: Dug ore!")
        check(nLevel + 1)
        while not turtle.up() do end
        ignoredFuel = ignoredFuel + 2
    end
end

---------------------------------------------------------------------
-- Helpers pour les galeries optimisées
---------------------------------------------------------------------

-- Avancer d'un bloc dans la direction actuelle en dégageant un tunnel de 2 blocs de haut
local function digForward2High()
    -- dégager devant
    while turtle.detect() do turtle.dig() end
    while not turtle.forward() do
        turtle.attack()
        turtle.dig()
    end
    -- dégager au-dessus
    if turtle.detectUp() then turtle.digUp() end
end

-- Creuser une galerie de 2 blocs de haut sur length blocs,
-- puis revenir au point de départ de cette galerie.
local function digTunnel(length)
    local moved = 0
    while moved < length and ok do
        digForward2High()
        moved = moved + 1
        print("[tunnel]: Dug forward (" .. moved .. "/" .. length .. ")!")
        check()
        if not ok then break end
    end

    -- Retour au point de départ de la galerie
    print("[tunnel]: Returning along tunnel!")
    turtle.turnLeft()
    turtle.turnLeft()
    for i = 1, moved do
        while not turtle.forward() do
            turtle.attack()
            turtle.dig()
        end
    end
    turtle.turnLeft()
    turtle.turnLeft()
    print("[tunnel]: Back at tunnel start!")
end

-- Se déplacer latéralement (perpendiculaire aux galeries)
-- toRight = true  → tourner à droite, marcher, re-tourner à gauche
-- toRight = false → tourner à gauche, marcher, re-tourner à droite
local function moveSideways(steps, toRight)
    if steps <= 0 then return end

    if toRight then
        turtle.turnRight()
    else
        turtle.turnLeft()
    end

    for i = 1, steps do
        digForward2High()
    end

    if toRight then
        turtle.turnLeft()
    else
        turtle.turnRight()
    end
end

-- Descendre de 4 blocs pour passer à la couche suivante
local function descendFour()
    print("[layer]: Descending 4 blocks to next layer!")
    for i = 1, 4 do
        while turtle.detectDown() do turtle.digDown() end
        while not turtle.down() do
            turtle.attackDown()
            turtle.digDown()
        end
    end
    layerDepth = layerDepth + 1
end

---------------------------------------------------------------------
-- Retour au coffre + reprise
---------------------------------------------------------------------

local function goUpToSurface()
    print("[return]: Going up to surface!")
    while layerDepth > 0 do
        for i = 1, 4 do
            while turtle.detectUp() do turtle.digUp() end
            while not turtle.up() do
                turtle.attackUp()
                turtle.digUp()
            end
        end
        layerDepth = layerDepth - 1
    end
end

local function dropInventory()
    print("[return]: Dropping inventory into chest below!")
    for i = 5, 14 do
        turtle.select(i)
        turtle.dropDown()
    end
end

local function returnAndMaybeResume()
    print("[return]: Handling return to chest...")

    -- Sauvegarde où reprendre
    savedLayer  = layerDepth
    savedOffset = sideOffset

    -- Revenir à la "colonne" d'origine sur la couche
    if sideOffset > 0 then
        print("[return]: Moving sideways back to origin on this layer!")
        moveSideways(sideOffset, false)
        sideOffset = 0
    end

    -- Remonter à la surface (au-dessus du coffre)
    goUpToSurface()

    -- Déposer l'inventaire
    dropInventory()

    -- Si le temps est écoulé ou si le script est arrêté : on ne reprend pas
    if timeUp or not ok then
        print("[return]: Time is up or script stopped, not resuming mining.")
        needReturn = false
        return
    end

    -- Reprise : redescendre à la couche sauvegardée
    print("[return]: Resuming mining at saved position (layer=" .. savedLayer .. ", offset=" .. savedOffset .. ")")
    for l = 1, savedLayer do
        for i = 1, 4 do
            while turtle.detectDown() do turtle.digDown() end
            while not turtle.down() do
                turtle.attackDown()
                turtle.digDown()
            end
        end
        layerDepth = layerDepth + 1
    end

    -- Revenir au décalage latéral sauvegardé
    if savedOffset > 0 then
        moveSideways(savedOffset, true)
        sideOffset = savedOffset
    end

    needReturn = false
end

---------------------------------------------------------------------
-- Nouveau main : galeries optimisées + retour/reprise
---------------------------------------------------------------------

function main()
    sideOffset = 0
    layerDepth = 0

    while ok do
        print("[main]: Starting new layer of optimized galleries!")

        -- Une couche : NUM_TUNNELS galeries parallèles, 2 blocs de haut, 64 de long
        for t = 1, NUM_TUNNELS do
            if not ok then break end

            print("[main]: Starting tunnel " .. t .. " / " .. NUM_TUNNELS)
            digTunnel(TUNNEL_LENGTH)

            if needReturn then
                returnAndMaybeResume()
                if not ok or timeUp then
                    return
                end
            end

            -- Se décaler pour le tunnel suivant (espacement de 2 blocs pleins -> centre à 3 blocs)
            if t < NUM_TUNNELS then
                moveSideways(TUNNEL_SPACING, true)
                sideOffset = sideOffset + TUNNEL_SPACING
                print("[main]: Shifted sideways, sideOffset = " .. sideOffset)
            end
        end

        if not ok then break end

        -- Revenir à la "colonne" d'origine sur cette couche
        if sideOffset > 0 then
            print("[main]: Returning to origin column on this layer!")
            moveSideways(sideOffset, false)
            sideOffset = 0
        end

        if needReturn then
            returnAndMaybeResume()
            if not ok or timeUp then
                return
            end
        end

        -- Descendre de 4 blocs pour la prochaine couche
        descendFour()
    end

    -- Fin : s'assurer qu'on remonte déposer ce qu'il reste
    print("[main]: Finishing, returning to chest one last time.")
    needReturn = true
    returnAndMaybeResume()
end

---------------------------------------------------------------------
-- Gestion fuel / sécurité / timer
---------------------------------------------------------------------

function findMaxLevel()
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

function isOk()
    local okLevel = findMaxLevel() / 2 + 10
    while ok do
        local currentLevel = turtle.getFuelLevel()
        if currentLevel < 100 then --check fuel
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

        --make sure turtle can take new items
        local hasSpace = false
        for i = 5, 15 do
            if turtle.getItemCount(i) == 0 then
                hasSpace = true
                break
            end
        end
        if not hasSpace and ok then
            print("[isOk]: Out of space!  Returning to chest, will resume mining!")
            needReturn = true   -- on NE met PAS ok=false ici, pour pouvoir reprendre
        elseif ok then
            print("[isOk]: Everything is OK!")
            local id = os.startTimer(10)
            while true do
                local _, tid = os.pullEvent("timer")
                if tid == id then
                    break
                end
            end
        end
    end
end

function trackTime()
    local sTime = table.concat(tArgs, " ")
    local nSeconds = 0

    for numStr, period in sTime:gmatch("(%d+)%s+(%a+)s?") do
        local i = tonumber(numStr)
        if i then
            if period:lower() == "second" then
                nSeconds = nSeconds + i
            elseif period:lower() == "minute" then
                nSeconds = nSeconds + (i * 60)
            elseif period:lower() == "hour" then
                nSeconds = nSeconds + (i * 3600)
            end
        end
    end

    if nSeconds <= 0 then
        print("[trackTime]: No valid duration provided, running without time limit.")
        return
    end

    print("[trackTime]: Starting timer for " .. nSeconds .. " seconds!")
    local id = os.startTimer(nSeconds)
    while ok do
        local _, tid = os.pullEvent("timer")
        if id == tid then
            print("[trackTime]: End of session reached!  Returning to base and stopping!")
            timeUp = true
            ok = false        -- on stoppe la session (pas de reprise après ce retour)
        end
    end
end

---------------------------------------------------------------------
-- Lancement parallèle
---------------------------------------------------------------------

parallel.waitForAll(trackTime, isOk, main, dumpWaste)

-- Dernier vidage de l'inventaire au coffre
for i = 5, 14 do
    turtle.select(i)
    turtle.dropDown()
end
