local RSGCore = exports['rsg-core']:GetCoreObject()
local ClothingCamera = nil
local c_zoom = 2.4
local c_offset = -0.15
local Outfits_tab = {}
local CurrentPrice = 0
local CurentCoords = {}
local playerHeading = nil
local RoomPrompts = GetRandomIntInRange(0, 0xffffff)
local ClothesCache = {}
local OldClothesCache = {}  -- <-- Добавьте эту строку
local PromptsEnabled = false  -- <-- И эту если её нет
local Divider = "<img style='margin-top: 10px;margin-bottom: 10px; margin-left: -10px;'src='nui://rsg-appearance/img/divider_line.png'>"
local image = "<img style='max-height:250px;max-width:250px;float: center;'src='nui://rsg-appearance/img/%s.png'>"

local clothing = require 'data.clothing'
local hashToCache = require 'client.hashtocache'

---@deprecated use inClothingStore state
exports('IsCothingActive', function()
    return LocalPlayer.state.inClothingStore
end)

CreateThread(function()
    for _,v in pairs(RSG.SetDoorState) do
        Citizen.InvokeNative(0xD99229FE93B46286, v.door, 1, 1, 0, 0, 0, 0)
        DoorSystemSetDoorState(v.door, v.state)
    end
end)

function GetDescriptionLayout(value, price)
    local desc = image:format(value.img) .. "<br><br>" .. value.desc .. "<br><br>" .. Divider ..
        "<br><span style='font-family:crock; float:left; font-size: 22px;'>" ..
        RSG.Label.total .. " </span><span style='font-family:crock;float:right; font-size: 22px;'>$" ..
        (price or CurrentPrice) .. "</span><br>" .. Divider
    return desc
end
-- ==========================================
-- СОХРАНЕНИЕ ОДЕЖДЫ ПОСЛЕ СОЗДАНИЯ ПЕРСОНАЖА
-- ==========================================

-- Обработчик завершения создания персонажа
RegisterNetEvent('rsg-appearance:client:saveClothesAfterCreation', function()
    Wait(1000) -- Ждём полной загрузки
    
    local isMale = IsPedMale(PlayerPedId())
    
    -- Получаем текущую одежду после создания персонажа
    if ClothesCache and next(ClothesCache) then
        print('[RSG-Clothing] Saving creation clothes to inventory...')
        
        for category, data in pairs(ClothesCache) do
            if type(data) == "table" and (data.model or 0) > 0 then
                local hash = 0
                local gender = isMale and "male" or "female"
                
                -- Получаем хеш из таблицы одежды
                if clothing[gender] and clothing[gender][category] then
                    local model = data.model
                    local texture = data.texture or 1
                    
                    if clothing[gender][category][model] and 
                       clothing[gender][category][model][texture] then
                        hash = clothing[gender][category][model][texture].hash
                    end
                end
                
                -- Если нашли хеш - сохраняем в инвентарь
                if hash and hash ~= 0 then
                    TriggerServerEvent('rsg-clothing:server:saveToInventory', {
                        category = category,
                        hash = hash,
                        model = data.model,
                        texture = data.texture or 1,
                        isMale = isMale
                    })
                    Wait(100) -- Небольшая задержка между предметами
                    
                    print('[RSG-Clothing] Saved: ' .. category)
                end
            end
        end
        
        -- После сохранения в инвентарь - надеваем все предметы
        Wait(2000)
        TriggerServerEvent('rsg-clothing:server:equipAllAfterCreation')
    end
end)

-- Хук на событие создания персонажа (найдите где оно вызывается)
RegisterNetEvent('rsg-character:client:characterCreated', function()
    TriggerEvent('rsg-appearance:client:saveClothesAfterCreation')
end)

-- Альтернативные события (проверьте какое используется у вас)
RegisterNetEvent('rsg-multicharacter:client:characterCreated', function()
    TriggerEvent('rsg-appearance:client:saveClothesAfterCreation')
end)

RegisterNetEvent('rsg-appearance:client:finishedCreation', function()
    TriggerEvent('rsg-appearance:client:saveClothesAfterCreation')
end)
-- ==========================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==========================================

-- Глубокое копирование таблицы
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

-- Получение списка купленных (изменённых) предметов
function GetPurchasedItems(newCache, oldCache, isMale)
    local purchasedItems = {}
    local gender = isMale and "male" or "female"
    
    if not newCache then return purchasedItems end
    if not oldCache then oldCache = {} end
    
    for category, newData in pairs(newCache) do
        local oldData = oldCache[category]
        local isNew = false
        
        -- Проверяем, изменился ли предмет
        if not oldData then
            -- Категории не было раньше
            isNew = true
        elseif type(newData) == "table" and type(oldData) == "table" then
            -- Сравниваем model и texture
            if (newData.model or 0) ~= (oldData.model or 0) or 
               (newData.texture or 0) ~= (oldData.texture or 0) then
                isNew = true
            end
        elseif newData ~= oldData then
            isNew = true
        end
        
        -- Если предмет новый и не пустой (model > 0)
        if isNew and type(newData) == "table" and (newData.model or 0) > 0 then
            local hash = 0
            
            -- Получаем хеш из таблицы одежды
            if clothing[gender] and clothing[gender][category] then
                local model = newData.model
                local texture = newData.texture or 1
                
                if clothing[gender][category][model] and 
                   clothing[gender][category][model][texture] then
                    hash = clothing[gender][category][model][texture].hash
                end
            end
            
            if hash and hash ~= 0 then
                table.insert(purchasedItems, {
                    category = category,
                    hash = hash,
                    model = newData.model,
                    texture = newData.texture or 1,
                    isMale = isMale
                })
                
                print('[RSG-Clothing] New item detected: ' .. category .. ' | Hash: ' .. hash)
            end
        end
    end
    
    return purchasedItems
end

-- Переменная для хранения старого состояния одежды
OldClothesCache = {}
function OpenClothingMenu()
    MenuData.CloseAll()
    local elements = {}

    for v, k in pairsByKeys(RSG.MenuElements) do
        elements[#elements + 1] = { label = k.label or v, value = v, category = v, desc = image:format(v) .. "<br><br>" .. Divider .. "<br> " .. locale('clothing_menu.category_desc'), }
    end
    
    if not (IsInCharCreation or Skinkosong) then
        local descLayout = GetDescriptionLayout({ img = "menu_icon_tick", desc = locale('clothing_menu.confirm_purhcase') })
        elements[#elements + 1] = { label = RSG.Label.save or "Save", value = "save", desc = descLayout }
    end
    
    MenuData.Open('default', GetCurrentResourceName(), 'clothing_store_menu',
        { title = RSG.Label.clothes, subtext = RSG.Label.options, align = 'top-left', elements = elements, itemHeight = "4vh"},
        function(data, menu)
            if data.current.value ~= "save" then
                OpenCateogry(data.current.value)
            else
                menu.close()
                destory()
                
                local ClothesHash = ConvertCacheToHash(ClothesCache)
                local isMale = IsPedMale(PlayerPedId())
                
                -- Проверяем какие предметы изменились (новые покупки)
                local purchasedItems = GetPurchasedItems(ClothesCache, OldClothesCache, isMale)
                
                -- СОХРАНЯЕМ КУПЛЕННЫЕ ПРЕДМЕТЫ В ИНВЕНТАРЬ
                if purchasedItems and #purchasedItems > 0 then
                    for _, item in ipairs(purchasedItems) do
                        TriggerServerEvent('rsg-clothing:server:saveToInventory', item)
                        Wait(100)
                    end
                    print('[RSG-Clothing] Saved ' .. #purchasedItems .. ' items to inventory')
                end
                
                -- Сохраняем текущую одежду на персонаже
                TriggerServerEvent("rsg-appearance:server:saveOutfit", ClothesHash, isMale)
				-- АВТОМАТИЧЕСКИ НАДЕВАЕМ ВСЕ КУПЛЕННЫЕ ВЕЩИ
				Wait(500)
				TriggerServerEvent('rsg-clothing:server:equipAfterPurchase')
                
                if next(CurentCoords) == nil then
                    CurentCoords = RSG.Zones1[1]
                end
                TeleportAndFade(CurentCoords.quitcoords, true)
                Wait(1000)
                ExecuteCommand('loadskin')
            end
        end, function(data, menu)
            if (IsInCharCreation or Skinkosong) then
                menu.close()
                FirstMenu()
            else
                menu.close()
                destory()
                if next(CurentCoords) == nil then
                    CurentCoords = RSG.Zones1[1]
                end
                TeleportAndFade(CurentCoords.quitcoords, true)
                Wait(1000)
                ExecuteCommand('loadskin')
            end
        end)
end

function OpenCateogry(menu_catagory)
    MenuData.CloseAll()
    local elements = {}
    if IsPedMale(PlayerPedId()) then
        local a = 1
        for v, k in pairsByKeys(RSG.MenuElements[menu_catagory].category) do
            if clothing["male"][k] ~= nil then
                local category = clothing["male"][k]
                if ClothesCache[k] == nil or type(ClothesCache[k]) ~= "table" then
                    ClothesCache[k] = {}
                    ClothesCache[k].model = 0
                    ClothesCache[k].texture = 1
                end
                elements[#elements + 1] = {
                    label = RSG.Price[k] .. "$ " .. RSG.Label[k] or v,
                    value = ClothesCache[k].model or 0,
                    category = k,
                    desc = "",
                    type = "slider",
                    min = 0,
                    max = #category,
                    change_type = "model",
                    id = a
                }
                a = a + 1
                elements[#elements + 1] = {
                    label = RSG.Label.color .. RSG.Label[k] or v,
                    value = ClothesCache[k].texture or 1,
                    category = k,
                    desc = "",
                    type = "slider",
                    min = 1,
                    max = GetMaxTexturesForModel(k, ClothesCache[k].model or 1, true),
                    change_type = "texture",
                    id = a
                }
                a = a + 1
            end
        end
    else
        local a = 1
        for v, k in pairsByKeys(RSG.MenuElements[menu_catagory].category) do
            if clothing["female"][k] ~= nil then
                local category = clothing["female"][k]
                if ClothesCache[k] == nil or type(ClothesCache[k]) ~= "table" then
                    ClothesCache[k] = {}
                    ClothesCache[k].model = 0
                    ClothesCache[k].texture = 0
                end
                elements[#elements + 1] = {
                    label = RSG.Price[k] .. "$ " .. RSG.Label[k] or v,
                    value = ClothesCache[k].model or 0,
                    category = k,
                    desc = "",
                    type = "slider",
                    min = 0,
                    max = #category,
                    change_type = "model",
                    id = a
                }
                a = a + 1
                elements[#elements + 1] = {
                    label = RSG.Label.color .. RSG.Label[k] or v,
                    value = ClothesCache[k].texture or 1,
                    category = k,
                    desc = "",
                    type = "slider",
                    min = 1,
                    max = GetMaxTexturesForModel(k, ClothesCache[k].model or 1, true),
                    change_type = "texture",
                    id = a
                }
                a = a + 1
            end
        end
    end
    MenuData.Open('default', GetCurrentResourceName(), 'clothing_store_menu_category',
        {title = RSG.Label.clothes, subtext = RSG.Label.options, align = 'top-left', elements = elements, itemHeight = "4vh"}, function(data, menu)
    end, function(data, menu)
        menu.close()
        OpenClothingMenu()
    end, function(data, menu)
        MenuUpdateClothes(data, menu)
    end)
end

function MenuUpdateClothes(data, menu)
    if data.current.change_type == "model" then
        if ClothesCache[data.current.category].model ~= data.current.value then
            ClothesCache[data.current.category].texture = 1
            ClothesCache[data.current.category].model = data.current.value
            if data.current.value > 0 then
                menu.setElement(data.current.id + 1, "max", GetMaxTexturesForModel(data.current.category, data.current.value, true))
                menu.setElement(data.current.id + 1, "min", 1)
                menu.setElement(data.current.id + 1, "value", 1)
                menu.refresh()
                Change(data.current.value, data.current.category, data.current.change_type)
            else
                if data.current.category == 'cloaks' then
                    data.current.category = 'ponchos'
                end
                Citizen.InvokeNative(0xD710A5007C2AC539, PlayerPedId(), GetHashKey(data.current.category), 0)
                NativeUpdatePedVariation(PlayerPedId())
                if data.current.category == "pants" or data.current.category == "boots" then
                    NativeSetPedComponentEnabledClothes(PlayerPedId(), exports['rsg-appearance']:GetBodyCurrentComponentHash("BODIES_LOWER"), false, true, true)
                end
                if data.current.category == "shirts_full" then
                    NativeSetPedComponentEnabledClothes(PlayerPedId(), exports['rsg-appearance']:GetBodyCurrentComponentHash("BODIES_UPPER"), false, true, true)
                end
                menu.setElement(data.current.id + 1, "max", 0)
                menu.setElement(data.current.id + 1, "min", 0)
                menu.setElement(data.current.id + 1, "value", 0)
                menu.refresh()
            end
            if not (IsInCharCreation or Skinkosong) then
                local newPrice = CalculatePrice(ConvertCacheToHash(ClothesCache), ConvertCacheToHash(OldClothesCache), IsPedMale(PlayerPedId()))
                if CurrentPrice ~= newPrice then
                    CurrentPrice = newPrice
                end
            end
        end
    end
    if data.current.change_type == "texture" then
        if ClothesCache[data.current.category].texture ~= data.current.value then
            ClothesCache[data.current.category].texture = data.current.value
            Change(data.current.value, data.current.category, data.current.change_type)
        end
    end
end

function ClothingLight()
    while ClothingCamera do
        Wait(0)

        TogglePrompts({ "TURN_LR", "CAM_UD", "ZOOM_IO" }, true)

        if IsControlPressed(2, RSGCore.Shared.Keybinds['D']) then
            local heading = GetEntityHeading(PlayerPedId())
            SetEntityHeading(PlayerPedId(), heading + 2)
        end
        if IsControlPressed(2, RSGCore.Shared.Keybinds['A']) then
            local heading = GetEntityHeading(PlayerPedId())
            SetEntityHeading(PlayerPedId(), heading - 2)
        end
        if IsControlPressed(2, 0x8BDE7443) then
            if c_zoom + 0.25 < 2.5 and c_zoom + 0.25 > 0.7 then
                c_zoom = c_zoom + 0.25
                camera(c_zoom, c_offset)
            end
        end
        if IsControlPressed(2, 0x62800C92) then
            if c_zoom - 0.25 < 2.5 and c_zoom - 0.25 > 0.7 then
                c_zoom = c_zoom - 0.25
                camera(c_zoom, c_offset)
            end
        end
        if IsControlPressed(2, RSGCore.Shared.Keybinds['W']) then
            if c_offset + 0.5 / 7 < 1.2 and c_offset + 0.5 / 7 > -1.0 then
                c_offset = c_offset + 0.5 / 7
                camera(c_zoom, c_offset)
            end
        end
        if IsControlPressed(2, RSGCore.Shared.Keybinds['S']) then
            if c_offset - 0.5 / 7 < 1.2 and c_offset - 0.5 / 7 > -1.0 then
                c_offset = c_offset - 0.5 / 7
                camera(c_zoom, c_offset)
            end
        end
    end
end

function Change(id, category, change_type)
    if IsPedMale(PlayerPedId()) then
        if change_type == "model" then
            NativeSetPedComponentEnabledClothes(PlayerPedId(), clothing["male"][category][id][1].hash, false, true, true)
        else
            local hash = clothing["male"][category][ClothesCache[category].model]

            if not hash then return end

            NativeSetPedComponentEnabledClothes(PlayerPedId(), clothing["male"][category][ClothesCache[category].model][id].hash, false, true, true)
        end
    else
        if change_type == "model" then
            NativeSetPedComponentEnabledClothes(PlayerPedId(), clothing["female"][category][id][1].hash, false, true, true)
        else
            local hash = clothing["female"][category][ClothesCache[category].model]

            if not hash then return end

            NativeSetPedComponentEnabledClothes(PlayerPedId(), clothing["female"][category][ClothesCache[category].model][id].hash, false, true, true)
        end
    end
end

RegisterNetEvent('rsg-appearance:client:ApplyClothes')
AddEventHandler('rsg-appearance:client:ApplyClothes', function(ClothesComponents, Target)
    CreateThread(function()
        local _Target = Target or PlayerPedId()
        if type(ClothesComponents) ~= "table" then
            return
        end
        if next(ClothesComponents) == nil then
            return
        end
        SetEntityAlpha(_Target, 0)
        ClothesCache = ClothesComponents
        for k, v in pairs(ClothesComponents) do
            if v ~= nil and v ~= 0 then
                if type(v) ~= "table" then v = { hash = v} end
                if v.hash and v.hash ~= 0 then
                    NativeSetPedComponentEnabledClothes(_Target, v.hash, false, true, true)
                    if v.palette then
                        NativeSetTextureOutfitTints(_Target,joaat(k),v.palette,v.tint0,v.tint1,v.tint2)
                    end
                else
                    local id = tonumber(v.model)
                    if id and id >= 1 then
                        if IsPedMale(_Target) then
                            if clothing["male"][k] ~= nil then
                                if clothing["male"][k][tonumber(v.model)] ~= nil then
                                    if clothing["male"][k][tonumber(v.model)][tonumber(v.texture)] ~= nil then
                                        NativeSetPedComponentEnabledClothes(_Target, tonumber(clothing["male"][k][tonumber(v.model)][tonumber(v.texture)].hash), false, true, true)
                                    end
                                end
                            end
                        else
                            if clothing["female"][k] ~= nil then
                                if clothing["female"][k][tonumber(v.model)] ~= nil then
                                    if clothing["female"][k][tonumber(v.model)][tonumber(v.texture)] ~= nil then
                                        NativeSetPedComponentEnabledClothes(_Target, tonumber(clothing["female"][k][tonumber(v.model)][tonumber(v.texture)].hash), false, true, true)
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        SetEntityAlpha(_Target, 255)
    end)
end)

function destory()
    OldClothesCache = {}
    SetCamActive(ClothingCamera, false)
    RenderScriptCams(false, true, 500, true, true)
    DisplayHud(true)
    DisplayRadar(true)
    DestroyAllCams(true)
    ClothingCamera = nil
    playerHeading = nil
    Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), true, 0, false) -- ENABLE PLAYER CONTROLS
end

function TeleportAndFade(coords4, resetCoords)
    DoScreenFadeOut(500)
    Wait(1000)
    Citizen.InvokeNative(0x203BEFFDBE12E96A, PlayerPedId(), coords4)
    SetEntityCoordsNoOffset(PlayerPedId(), coords4, true, true, true)
    LocalPlayer.state.inClothingStore = true
    Wait(1500)
    DoScreenFadeIn(1800)
    if resetCoords then
        CurentCoords = {}
        TogglePrompts({ "TURN_LR", "CAM_UD", "ZOOM_IO" }, false)
        LocalPlayer.state.inClothingStore = false
        TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', 0)
    end
end

function camera(zoom, offset)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local zoomOffset = zoom
    local angle

    if playerHeading == nil then
        playerHeading = GetEntityHeading(playerPed)
        angle = playerHeading * math.pi / 180.0
    else
        angle = playerHeading * math.pi / 180.0
    end

    local pos = {
        x = coords.x - (zoomOffset * math.sin(angle)),
        y = coords.y + (zoomOffset * math.cos(angle)),
        z = coords.z + offset
    }

    if not ClothingCamera then
        DestroyAllCams(true)
        ClothingCamera = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z, 300.00, 0.00, 0.00, 50.00, false, 0)

        local pCoords = GetEntityCoords(PlayerPedId())
        PointCamAtCoord(ClothingCamera, pCoords.x, pCoords.y, pCoords.z + offset)

        SetCamActive(ClothingCamera, true)
        RenderScriptCams(true, true, 1000, true, true)
        DisplayRadar(false)
    else
        local ClothingCamera2 = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", pos.x, pos.y, pos.z, 300.00, 0.00, 0.00, 50.00, false, 0)
        SetCamActive(ClothingCamera2, true)
        SetCamActiveWithInterp(ClothingCamera2, ClothingCamera, 750)

        local pCoords = GetEntityCoords(PlayerPedId())
        PointCamAtCoord(ClothingCamera2, pCoords.x, pCoords.y, pCoords.z + offset)

        Wait(150)
        SetCamActive(ClothingCamera, false)
        DestroyCam(ClothingCamera)
        ClothingCamera = ClothingCamera2
    end
end

function Outfits()
    MenuData.CloseAll()
    local Result = lib.callback.await('rsg-appearance:server:getOutfits', false)
    local elements_outfits = {}
    for k, v in pairs(Result) do
        elements_outfits[#elements_outfits + 1] = {
            name = v.name,
            label = '#' .. k .. '. ' .. v.name,
            value = v.clothes,
            desc = RSG.Label.choose
        }
    end
    MenuData.Open('default', GetCurrentResourceName(), 'outfits_menu',
        {title = RSG.Label.clothes, subtext = RSG.Label.choose, align = 'top-left', elements = elements_outfits, itemHeight = "4vh"},
        function(data, menu)
            OutfitsManage(data.current.value, data.current.name)
        end, function(data, menu)
            menu.close()
        end)
end

function OutfitsManage(outfit, id)
    MenuData.CloseAll()
    local elements_outfits_manage = {
        {label = RSG.Label.wear, value = "SetOutfits", desc = RSG.Label.wear_desc},
        {label = RSG.Label.delete, value = "DeleteOutfit", desc = RSG.Label.delete_desc}
    }
    MenuData.Open('default', GetCurrentResourceName(), 'outfits_menu_manage',
        {title = RSG.Label.clothes, subtext = RSG.Label.options, align = 'top-left', elements = elements_outfits_manage, itemHeight = "4vh"}, function(data, menu)
            menu.close()
        if data.current.value == 'SetOutfits' then
            TriggerEvent('rsg-appearance:client:ApplyClothes', outfit, PlayerPedId())
            local ClothesHash = ConvertCacheToHash(outfit)
            TriggerServerEvent('rsg-appearance:server:saveUseOutfit', ClothesHash)
        end
        if data.current.value == 'DeleteOutfit' then
            return TriggerServerEvent('rsg-appearance:server:DeleteOutfit', id)
        end
    end, function(data, menu)
        Outfits()
    end)
end

exports('GetClothesComponents', function()
    return {ComponentsClothesMale, ComponentsClothesFemale}
end)

exports('GetClothesCache', function(name)
    return ClothesCache
end)

exports('GetClothesComponentId', function(name)
    return ClothesCache[name]
end)

exports('GetClothesCurrentComponentHash', function(name)
    if ClothesCache[name] == nil then
        return 0
    end
    local hash
    if IsPedMale(PlayerPedId()) then
        if clothing["male"][name] ~= nil then
            hash = clothing["male"][name][hash]
        end
    else
        if clothing["female"][name] ~= nil then
            hash = clothing["female"][name][hash]
        end
    end
    return hash
end)

RegisterNetEvent('rsg-appearance:client:outfits', function()
    Outfits()
end)

local Cloakroom = GetRandomIntInRange(0, 0xffffff)

function OpenCloakroom()
    local str = locale('cloack_room_prompt_button')
    CloakPrompt = PromptRegisterBegin()
    PromptSetControlAction(CloakPrompt, RSG.OpenKey)
    str = CreateVarString(10, 'LITERAL_STRING', str)
    PromptSetText(CloakPrompt, str)
    PromptSetEnabled(CloakPrompt, true)
    PromptSetVisible(CloakPrompt, true)
    PromptSetHoldMode(CloakPrompt, true)
    PromptSetGroup(CloakPrompt, Cloakroom)
    PromptRegisterEnd(CloakPrompt)
end

CreateThread(function()
    OpenCloakroom()
    while true do
        Wait(5)
        local sleep = true
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        for k, v in pairs(RSG.Cloakroom) do
            local dist = #(coords - v)
            if dist < 2.0 then
                sleep = false
                local PromptGroup = CreateVarString(10, 'LITERAL_STRING', RSG.Cloakroomtext)
                PromptSetActiveGroupThisFrame(Cloakroom, PromptGroup)
                if PromptHasHoldModeCompleted(CloakPrompt) then
                    Outfits()
                    break
                end
            end
        end
        if sleep then
            Wait(1500)
        end
    end
end)

function GenerateMenu()
    TriggerEvent('rsg-horses:client:FleeHorse')
    Wait(0)
    TeleportAndFade(CurentCoords.fittingcoords, false)
    TriggerServerEvent('rsg-appearance:server:SetPlayerBucket', 0, true)
    local ClothesComponents = lib.callback.await('rsg-appearance:server:LoadClothes', false)
    ClothesCache = hashToCache.PopulateClothingCache(ClothesComponents, IsPedMale(PlayerPedId()))
    OldClothesCache = deepcopy(ClothesCache)
    camera(2.4, -0.15)
    CreateThread(ClothingLight)
    OpenClothingMenu()
end

CreateThread(function()
    LocalPlayer.state.inClothingStore = false
    CreateBlips()
    if RegisterPrompts() then
        local room = false

        while true do
            room = GetClosestConsumer()

            if room then
                if not PromptsEnabled then TogglePrompts({ "OPEN_CLOTHING_MENU" }, true) end
                if PromptsEnabled then
                    if IsPromptCompleted("OPEN_CLOTHING_MENU") then
                        Citizen.InvokeNative(0x4D51E59243281D80, PlayerId(), false, 0, true) -- ENABLE PLAYER CONTROLS
                        GenerateMenu()
                    end
                end
            else
                if PromptsEnabled then TogglePrompts({ "OPEN_CLOTHING_MENU" }, false) end
                Wait(250)
            end
            Wait(100)
        end
    end
end)

local playerCoords = nil
GetClosestConsumer = function()
    playerCoords = GetEntityCoords(PlayerPedId())

    for _,data in pairs(RSG.Zones1) do
        if (data.promtcoords and #(playerCoords - data.promtcoords) < 1.0) or (data.epromtcoords and #(playerCoords - data.epromtcoords) < 1.0) then
            CurentCoords = data
            -- CreateModelBook(data.promtcoords)
            return true
        end
    end
    return false
end

RegisterPrompts = function()
    local newTable = {}

    for i=1, #RSG.Prompts do
        local prompt = Citizen.InvokeNative(0x04F97DE45A519419, Citizen.ResultAsInteger())
        Citizen.InvokeNative(0x5DD02A8318420DD7, prompt, CreateVarString(10, "LITERAL_STRING", RSG.Prompts[i].label))
        Citizen.InvokeNative(0xB5352B7494A08258, prompt, RSG.Prompts[i].control or RSGCore.Shared.Keybinds[RSG.Keybind])

        if RSG.Prompts[i].control2  then
            Citizen.InvokeNative(0xB5352B7494A08258, prompt, RSG.Prompts[i].control2)
        end

        Citizen.InvokeNative(0x94073D5CA3F16B7B, prompt, RSG.Prompts[i].time or 1000)

        if RSG.Prompts[i].control  then
            Citizen.InvokeNative(0x2F11D3A254169EA4, prompt, RoomPrompts)
        end

        Citizen.InvokeNative(0xF7AA2696A22AD8B9, prompt)
        Citizen.InvokeNative(0x8A0FB4D03A630D21, prompt, false)
        Citizen.InvokeNative(0x71215ACCFDE075EE, prompt, false)

        table.insert(RSG.CreatedEntries, { type = "PROMPT", handle = prompt })
        newTable[RSG.Prompts[i].id] = prompt
    end

    RSG.Prompts = newTable
    return true
end

TogglePrompts = function(data, state)
    for index,prompt in pairs((data ~= "ALL" and data) or RSG.Prompts) do
        if RSG.Prompts[(data ~= "ALL" and prompt) or index] then
            Citizen.InvokeNative(0x8A0FB4D03A630D21, (data ~= "ALL" and RSG.Prompts[prompt]) or prompt, state)
            Citizen.InvokeNative(0x71215ACCFDE075EE, (data ~= "ALL" and RSG.Prompts[prompt]) or prompt, state)
        end
    end
    local label  = CreateVarString(10, 'LITERAL_STRING', RSG.Label.shop.. ' - ~t6~'..CurrentPrice..'$')
    PromptSetActiveGroupThisFrame(RoomPrompts, label)
    PromptsEnabled = state
end

IsPromptCompleted = function(name)
    if RSG.Prompts[name] then
        return Citizen.InvokeNative(0xE0F65F0640EF0617, RSG.Prompts[name])
    end
    return false
end

-- blips
CreateBlips = function()
    for _, coordsList in pairs(RSG.Zones1) do
        if #coordsList.blipcoords > 0 and coordsList.showblip then
            local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coordsList.blipcoords)
            SetBlipSprite(blip, RSG.BlipSprite, 1)
            SetBlipScale(blip, RSG.BlipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, blip, RSG.BlipName)

            table.insert(RSG.CreatedEntries, { type = "BLIP", handle = blip })
        end
    end
    for _, v in pairs(RSG.Cloakroom) do
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v)
        SetBlipSprite(blip, RSG.BlipSpriteCloakRoom, 1)
        SetBlipScale(blip, RSG.BlipScale)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, RSG.BlipNameCloakRoom)

        table.insert(RSG.CreatedEntries, { type = "BLIP", handle = blip })
    end
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    LocalPlayer.state.inClothingStore = false
    destory()
    for i=1, #RSG.CreatedEntries do
        if RSG.CreatedEntries[i].type == "BLIP" then
            RemoveBlip(RSG.CreatedEntries[i].handle)
        elseif RSG.CreatedEntries[i].type == "PROMPT" then
            Citizen.InvokeNative(0x00EDE88D4D13CF59, RSG.CreatedEntries[i].handle)
            PromptsEnabled = false
        end
    end
end)
-- ==========================================
-- СИСТЕМА СОХРАНЕНИЯ ОДЕЖДЫ В ИНВЕНТАРЬ
-- ==========================================

-- Сохранение отдельного предмета одежды в инвентарь
function SaveClothingItemToInventory(category, clothingData)
    if not clothingData then return end
    
    local isMale = IsPedMale(PlayerPedId())
    local gender = isMale and "male" or "female"
    
    -- Получаем хеш одежды
    local hash = 0
    if type(clothingData) == "table" then
        if clothingData.hash then
            hash = clothingData.hash
        elseif clothingData.model and clothingData.texture then
            local clothingTable = clothing[gender][category]
            if clothingTable and clothingTable[clothingData.model] and clothingTable[clothingData.model][clothingData.texture] then
                hash = clothingTable[clothingData.model][clothingData.texture].hash
            end
        end
    else
        hash = clothingData
    end
    
    if hash == 0 then return end
    
    -- Отправляем на сервер для сохранения в инвентарь
    TriggerServerEvent('rsg-clothing:server:saveToInventory', {
        category = category,
        hash = hash,
        model = clothingData.model or 0,
        texture = clothingData.texture or 0,
        isMale = isMale
    })
end

-- Экспорт для применения одежды из инвентаря
exports('ApplyClothingFromInventory', function(clothingData)
    if not clothingData then return false end
    
    local playerPed = PlayerPedId()
    local hash = clothingData.hash or 0
    
    if hash ~= 0 then
        NativeSetPedComponentEnabledClothes(playerPed, hash, false, true, true)
        NativeUpdatePedVariation(playerPed)
        return true
    end
    
    return false
end)

-- Экспорт для снятия одежды
exports('RemoveClothingFromCategory', function(category)
    local playerPed = PlayerPedId()
    
    Citizen.InvokeNative(0xD710A5007C2AC539, playerPed, GetHashKey(category), 0)
    NativeUpdatePedVariation(playerPed)
    
    -- Восстанавливаем тело если нужно
    if category == "pants" or category == "boots" then
        NativeSetPedComponentEnabledClothes(playerPed, exports['rsg-appearance']:GetBodyCurrentComponentHash("BODIES_LOWER"), false, true, true)
    end
    if category == "shirts_full" then
        NativeSetPedComponentEnabledClothes(playerPed, exports['rsg-appearance']:GetBodyCurrentComponentHash("BODIES_UPPER"), false, true, true)
    end
    
    return true
end)
-- ==========================================
-- ЗАГРУЗКА ОДЕЖДЫ ИЗ ИНВЕНТАРЯ (ПРИОРИТЕТ)
-- ==========================================

-- Загрузка одежды из инвентаря вместо базы данных
function LoadClothingFromInventory(callback)
    RSGCore.Functions.TriggerCallback('rsg-clothing:server:getEquippedClothing', function(equippedItems)
        if not equippedItems or not next(equippedItems) then
            print('[RSG-Clothing] No equipped items in inventory')
            if callback then callback(false) end
            return
        end
        
        local playerPed = PlayerPedId()
        local appliedCount = 0
        
        for category, data in pairs(equippedItems) do
            if data.hash and data.hash ~= 0 then
                NativeSetPedComponentEnabledClothes(playerPed, data.hash, false, true, true)
                
                if not ClothesCache then ClothesCache = {} end
                ClothesCache[category] = {
                    hash = data.hash,
                    model = data.model or 0,
                    texture = data.texture or 0
                }
                appliedCount = appliedCount + 1
            end
        end
        
        NativeUpdatePedVariation(playerPed)
        print('[RSG-Clothing] Applied ' .. appliedCount .. ' items from inventory')
        
        if callback then callback(true, appliedCount) end
    end)
end

-- Экспорт для внешнего использования
exports('LoadClothingFromInventory', LoadClothingFromInventory)

-- Переопределяем загрузку скина чтобы использовать инвентарь
RegisterNetEvent('rsg-appearance:client:LoadClothesAfterSkin', function()
    Wait(500)
    LoadClothingFromInventory()
end)
-- ==========================================
-- ОБРАБОТЧИК ЗАКРЫТИЯ ИНВЕНТАРЯ
-- ==========================================

-- При закрытии инвентаря проверяем одежду
RegisterNetEvent('rsg-inventory:client:closeInventory', function()
    Wait(500) -- Ждём синхронизацию
    
    -- Запрашиваем проверку на сервере
    TriggerServerEvent('rsg-inventory:server:SaveInventory')
end)

-- Хук на выбрасывание предмета
RegisterCommand('drop', function()
    Wait(500)
    TriggerServerEvent('rsg-inventory:server:SaveInventory')
end)
-- ==========================================
-- КОМАНДА FIXCHARACTER (ЗАГРУЗКА ИЗ ИНВЕНТАРЯ)
-- ==========================================

RegisterCommand('fixcharacter', function()
    print('[RSG-Clothing] fixcharacter called')
    
    TriggerEvent('ox_lib:notify', {title = 'Персонаж', description = 'Восстановление...', type = 'info'})
    
    -- Шаг 1: Синхронизируем БД с инвентарём ПЕРЕД загрузкой скина
    TriggerServerEvent('rsg-clothing:server:syncInventoryToDatabase')
    
    Wait(500)
    
    -- Шаг 2: Загружаем скин (теперь в БД правильные данные из инвентаря)
    ExecuteCommand('loadskin')
    
    Wait(2500)
    
    -- Шаг 3: Применяем одежду из инвентаря
    LoadClothingFromInventory(function(success, count)
        if success then
            TriggerEvent('ox_lib:notify', {title = 'Одежда', description = 'Восстановлено: ' .. count .. ' предметов', type = 'success'})
        else
            TriggerEvent('ox_lib:notify', {title = 'Одежда', description = 'Нет надетой одежды', type = 'warning'})
        end
    end)
end, false)
-- ==========================================
-- АНИМАЦИИ ДЛЯ ОДЕЖДЫ (RedM) - РАБОЧИЕ
-- ==========================================

-- Используем сценарии вместо анимаций
local ClothingScenarios = {
    ['hats'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['shirts_full'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['rings_rh'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['rings_lh'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['pants'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['boots'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['coats'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['vests'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['gloves'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['gunbelts'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['neckwear'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['masks'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 },
    ['eyewear'] = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 }
}

local defaultScenario = { scenario = 'WORLD_HUMAN_INSPECT', duration = 1000 }

-- Проигрывание анимации через сценарий
function PlayClothingAnimation(category, isEquip, callback)
    local playerPed = PlayerPedId()
    
    local scenarioData = ClothingScenarios[category] or defaultScenario
    local duration = scenarioData.duration
    
    -- Блокируем управление
    FreezeEntityPosition(playerPed, true)
    
    -- Запускаем сценарий
    TaskStartScenarioInPlace(playerPed, GetHashKey(scenarioData.scenario), duration, true, false, false, false)
    
    print('[RSG-Clothing] Playing scenario: ' .. scenarioData.scenario)
    
    -- Ждём
    Wait(duration)
    
    -- Останавливаем и разблокируем
    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)
    
    if callback then callback() end
end

-- ==========================================
-- ЭКИПИРОВКА ОДЕЖДЫ ИЗ ИНВЕНТАРЯ
-- ==========================================

RegisterNetEvent('rsg-clothing:client:equipClothing', function(data)
    local playerPed = PlayerPedId()
    local category = data.category
    local hash = data.hash
    
    print('[RSG-Clothing] Equipping: ' .. category)
    
    CreateThread(function()
        PlayClothingAnimation(category, true, function()
            if hash and hash ~= 0 then
                NativeSetPedComponentEnabledClothes(playerPed, hash, false, true, true)
                NativeUpdatePedVariation(playerPed)
                
                if not ClothesCache then ClothesCache = {} end
                ClothesCache[category] = {
                    hash = hash,
                    model = data.model or 0,
                    texture = data.texture or 0
                }
                
                print('[RSG-Clothing] Applied: ' .. category)
            end
        end)
    end)
end)

-- ==========================================
-- СНЯТИЕ ОДЕЖДЫ (ИСПРАВЛЕННОЕ ДЛЯ ВСЕХ КАТЕГОРИЙ)
-- ==========================================

-- Хеши мета-компонентов для снятия одежды в RedM
local metaPedComponents = {
    ['rings_rh'] = 0x7A6BBD0B,
    ['rings_lh'] = 0xF16A1D23,
    ['hats'] = 0x9925C067,
    ['shirts_full'] = 0x2026C46D,
    ['pants'] = 0x1D4C528A,
    ['boots'] = 0x777EC6EF,
    ['vests'] = 0x485EE834,
    ['coats'] = 0xE06D30CE,
    ['coats_closed'] = 0xE06D30CE,
    ['gloves'] = 0xEABE0032,
    ['neckwear'] = 0x7A96FACA,
    ['neckties'] = 0x7A96FACA,
    ['suspenders'] = 0x877A2CF7,
    ['chaps'] = 0x3107499B,
    ['spurs'] = 0x18729F39,
    ['cloaks'] = 0x3C1A74CD,
    ['ponchos'] = 0xAF14310B,
    ['eyewear'] = 0x5F1BE9EC,
    ['masks'] = 0x7505EF42,
    ['masks_large'] = 0x7505EF42,
    ['bandanas'] = 0xDA0E2C55,
    ['gunbelts'] = 0xF1542D11,
    ['belts'] = 0xA6D134C6,
    ['belt_buckles'] = 0xA6D134C6,
    ['holsters_left'] = 0xF1542D11,
    ['holsters_right'] = 0xF1542D11,
    ['satchels'] = 0x94504D26,
    ['accessories'] = 0x79D7DF96,
    ['badges'] = 0x83839C54,
    ['armor'] = 0x72E6EF74,
    ['skirts'] = 0x1D4C528A,
    ['gauntlets'] = 0x91CE9B20,
    ['loadouts'] = 0x83839C54,
    ['jewelry'] = 0x79D7DF96,
    ['necklaces'] = 0x79D7DF96,
    ['bracelets'] = 0x79D7DF96,
    ['rings_rh'] = 0x79D7DF96,
    ['rings_lh'] = 0x79D7DF96,
    ['earrings'] = 0x79D7DF96,
    ['spats'] = 0x777EC6EF,
    ['bow_ties'] = 0x7A96FACA
}

RegisterNetEvent('rsg-clothing:client:removeClothing', function(category)
    local playerPed = PlayerPedId()
    
    print('[RSG-Clothing] Removing: ' .. category)
    
    CreateThread(function()
        PlayClothingAnimation(category, false, function()
            local removed = false
            
            -- Способ 1: Через мета-компонент (самый надёжный)
            if metaPedComponents[category] then
                Citizen.InvokeNative(0xD710A5007C2AC539, playerPed, metaPedComponents[category], 0)
                removed = true
                print('[RSG-Clothing] Removed via meta hash: ' .. string.format("0x%X", metaPedComponents[category]))
            end
            
            -- Способ 2: Через joaat хеш названия категории
            Citizen.InvokeNative(0xD710A5007C2AC539, playerPed, joaat(category), 0)
            Citizen.InvokeNative(0xD710A5007C2AC539, playerPed, joaat(string.upper(category)), 0)
            
            -- Способ 3: Через GetHashKey
            Citizen.InvokeNative(0xD710A5007C2AC539, playerPed, GetHashKey(category), 0)
            Citizen.InvokeNative(0xD710A5007C2AC539, playerPed, GetHashKey(string.upper(category)), 0)
            
            -- Обновляем вариацию
            NativeUpdatePedVariation(playerPed)
            
            -- Восстанавливаем тело для определённых категорий
            Wait(100)
            
            if category == "pants" or category == "boots" or category == "chaps" or category == "spurs" or category == "spats" then
                local bodyHash = exports['rsg-appearance']:GetBodyCurrentComponentHash("BODIES_LOWER")
                if bodyHash and bodyHash ~= 0 then
                    NativeSetPedComponentEnabledClothes(playerPed, bodyHash, false, true, true)
                end
            end
            
            if category == "shirts_full" or category == "vests" or category == "coats" or category == "coats_closed" or 
               category == "suspenders" or category == "gloves" or category == "neckwear" or category == "neckties" or
               category == "bow_ties" then
                local bodyHash = exports['rsg-appearance']:GetBodyCurrentComponentHash("BODIES_UPPER")
                if bodyHash and bodyHash ~= 0 then
                    NativeSetPedComponentEnabledClothes(playerPed, bodyHash, false, true, true)
                end
            end
            
            -- Финальное обновление
            NativeUpdatePedVariation(playerPed)
            
            -- Очищаем кеш
            if ClothesCache and ClothesCache[category] then
                ClothesCache[category] = nil
            end
            
            print('[RSG-Clothing] Removed complete: ' .. category)
        end)
    end)
end)

-- ==========================================
-- ТЕСТОВАЯ КОМАНДА ДЛЯ СНЯТИЯ ОДЕЖДЫ
-- ==========================================

RegisterCommand('removecat', function(source, args)
    local category = args[1]
    if not category then
        print('Usage: /removecat [category]')
        print('Categories: hats, shirts_full, pants, boots, gloves, neckwear, vests, coats, etc.')
        return
    end
    
    local playerPed = PlayerPedId()
    
    print('=== Testing remove: ' .. category .. ' ===')
    
    -- Через мета-компонент
    if metaPedComponents[category] then
        Citizen.InvokeNative(0xD710A5007C2AC539, playerPed, metaPedComponents[category], 0)
        print('Removed via meta: ' .. string.format("0x%X", metaPedComponents[category]))
    else
        print('No meta hash for: ' .. category)
    end
    
    -- Через joaat
    Citizen.InvokeNative(0xD710A5007C2AC539, playerPed, joaat(category), 0)
    print('Tried joaat: ' .. joaat(category))
    
    -- Через GetHashKey
    Citizen.InvokeNative(0xD710A5007C2AC539, playerPed, GetHashKey(category), 0)
    print('Tried GetHashKey: ' .. GetHashKey(category))
    
    -- Обновляем
    NativeUpdatePedVariation(playerPed)
    
    -- Восстанавливаем тело
    local bodyLower = exports['rsg-appearance']:GetBodyCurrentComponentHash("BODIES_LOWER")
    local bodyUpper = exports['rsg-appearance']:GetBodyCurrentComponentHash("BODIES_UPPER")
    
    if bodyLower and bodyLower ~= 0 then
        NativeSetPedComponentEnabledClothes(playerPed, bodyLower, false, true, true)
    end
    if bodyUpper and bodyUpper ~= 0 then
        NativeSetPedComponentEnabledClothes(playerPed, bodyUpper, false, true, true)
    end
    
    NativeUpdatePedVariation(playerPed)
    
    print('=== Done ===')
end, false)

-- Команда для просмотра всех хешей
RegisterCommand('listcathash', function()
    print('=== Category Hashes ===')
    for cat, hash in pairs(metaPedComponents) do
        print(cat .. ' = ' .. string.format("0x%X", hash))
    end
    print('=======================')
end, false)

-- ==========================================
-- ЗАГРУЗКА ОДЕЖДЫ ПРИ ВХОДЕ (ИЗ ИНВЕНТАРЯ)
-- ==========================================

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    Wait(3000) -- Ждём полную загрузку персонажа
    
    -- Загружаем одежду из инвентаря
    LoadClothingFromInventory(function(success, count)
        if success then
            print('[RSG-Clothing] Loaded ' .. count .. ' clothing items on spawn')
        end
    end)
end)

-- При респавне тоже загружаем из инвентаря
RegisterNetEvent('rsg-appearance:client:ApplyClothesAfterRespawn', function()
    Wait(1000)
    LoadClothingFromInventory()
end)

-- ==========================================
-- ТЕСТОВАЯ КОМАНДА
-- ==========================================

RegisterCommand('testanim', function()
    local playerPed = PlayerPedId()
    print('Testing scenario animation...')
    
    FreezeEntityPosition(playerPed, true)
    TaskStartScenarioInPlace(playerPed, GetHashKey('WORLD_HUMAN_WRITE_NOTEBOOK'), 2000, true, false, false, false)
    
    Wait(2000)
    
    ClearPedTasks(playerPed)
    FreezeEntityPosition(playerPed, false)
    print('Done!')
end)
-- Экспорт для получения текущей одежды
exports('GetCurrentClothingHash', function(category)
    if ClothesCache[category] then
        local isMale = IsPedMale(PlayerPedId())
        local gender = isMale and "male" or "female"
        
        if ClothesCache[category].hash then
            return ClothesCache[category].hash
        end
        
        local model = ClothesCache[category].model
        local texture = ClothesCache[category].texture
        
        if model and texture and model > 0 then
            local clothingTable = clothing[gender][category]
            if clothingTable and clothingTable[model] and clothingTable[model][texture] then
                return clothingTable[model][texture].hash
            end
        end
    end
    return 0
end)

-- Экспорт для получения всего кеша одежды
exports('GetClothesCache', function()
    return ClothesCache
end)

