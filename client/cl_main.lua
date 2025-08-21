local RSGCore = exports["rsg-core"]:GetCoreObject()
local ox_lib = exports["ox_lib"]
local cfg = Config
local lastJobChange = 0
local lang = cfg.Language or "en"
local L = Locales[lang] or Locales["en"]

local function validateConfig()
    local errors = {}
    
    if not cfg.Interact then
        table.insert(errors, "Missing Config.Interact. Please set it to either 'rsg-target' or 'ox_target'")
    elseif cfg.Interact ~= "rsg-target" and cfg.Interact ~= "ox_target" then
        table.insert(errors, string.format("Invalid Config.Interact: '%s'. Must be 'rsg-target' or 'ox_target'", cfg.Interact))
    end

    if not cfg.Jobs or type(cfg.Jobs) ~= "table" or #cfg.Jobs == 0 then
        table.insert(errors, "Invalid or missing Config.Jobs table")
    else
        for i, job in ipairs(cfg.Jobs) do
            if not job.jobName or type(job.jobName) ~= "string" then
                table.insert(errors, string.format("Job #%d missing or invalid 'jobName'", i))
            end
            if not job.label or type(job.label) ~= "string" then
                table.insert(errors, string.format("Job #%d missing or invalid 'label'", i))
            end
        end
    end

    if not cfg.Ped or not cfg.Ped.model or not cfg.Ped.spawn then
        table.insert(errors, "Invalid or missing NPC configuration")
    end

    if #errors > 0 then
        for _, err in ipairs(errors) do
            print("^1[JobCenter] " .. err .. "^7")
        end
    end
end

validateConfig()

local function t(key, ...)
    local str = L[key] or Locales["en"][key] or key
    return ... and string.format(str, ...) or str
end

local function doNotify(key, ...)
    local args = {...}
    local nType = "success"
    
    if type(args[#args]) == "string" and 
       (args[#args] == "success" or args[#args] == "error" or args[#args] == "info" or args[#args] == "warning") then
        nType = table.remove(args)
    end
    
    local msg = t(key, table.unpack(args))
    
    ox_lib:notify({
        description = msg, 
        type = nType,
        position = 'top',
        duration = 4000
    })
end

local function isJobChangeCooldownActive()
    local now = GetGameTimer()
    local cooldownMs = (cfg.CooldownSeconds or 60) * 1000
    return now < (lastJobChange + cooldownMs)
end

local function getRemainingCooldownSeconds()
    local now = GetGameTimer()
    local cooldownMs = (cfg.CooldownSeconds or 60) * 1000
    return math.ceil((lastJobChange + cooldownMs - now) / 1000)
end

local function setWaypoint(pos, label)
    if pos and pos.x and pos.y and pos.z then
        ClearGpsMultiRoute()
        StartGpsMultiRoute(6, true, true)
        AddPointToGpsMultiRoute(pos.x, pos.y, pos.z)
        SetGpsMultiRouteRender(true)

        doNotify("gps_set", label or "Location", "success")

        Citizen.CreateThread(function()
            local playerPed = PlayerPedId()
            local arrived = false
            while not arrived do
                local coords = GetEntityCoords(playerPed)
                local dist = #(vector3(pos.x, pos.y, pos.z) - coords)
                if dist < 2.0 then 
                    ClearGpsMultiRoute()
                    SetGpsMultiRouteRender(false)
                    arrived = true
                end
                Wait(1000)
            end
        end)
    else
        doNotify("invalid_location", "error")
    end
end

local function createJobCenterNPC()
    if not cfg.Ped or not cfg.Ped.model or not cfg.Ped.spawn then
        return
    end
    
    local x, y, z, h = cfg.Ped.spawn.x, cfg.Ped.spawn.y, cfg.Ped.spawn.z, cfg.Ped.spawn.w or 0.0
    
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return
    end

    local pedHash = GetHashKey(cfg.Ped.model)
    
    if pedHash == 0 then
        return
    end
    
    RequestModel(pedHash)
    local timeoutCounter = 0
    while not HasModelLoaded(pedHash) and timeoutCounter < 100 do 
        Wait(100)
        timeoutCounter = timeoutCounter + 1
    end
    
    if not HasModelLoaded(pedHash) then
        return
    end

    local ped = CreatePed(pedHash, x, y, z, h, false, false)
    
    if not ped or ped == 0 then
        SetModelAsNoLongerNeeded(pedHash)
        return
    end

    local entityWaitCount = 0
    while not DoesEntityExist(ped) and entityWaitCount < 50 do
        Wait(50)
        entityWaitCount = entityWaitCount + 1
    end
    
    if not DoesEntityExist(ped) then
        return
    end

    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true)
    
    if NetworkGetEntityIsNetworked(ped) then
        NetworkSetEntityOnlyExistsForParticipants(ped, false)
    end

    if cfg.Ped.animation and cfg.Ped.animation.scenario then
        Wait(1000) 
        TaskStartScenarioInPlace(ped, cfg.Ped.animation.scenario, 0, true)
    end

    cfg.Ped.npc = ped
    SetModelAsNoLongerNeeded(pedHash)
    
    return ped, pedHash
end

local function createBlip()
    if not cfg.Ped.blip or not cfg.Ped.blip.enabled then
        return
    end

    local b = cfg.Ped.blip
    local x, y, z = cfg.Ped.spawn.x, cfg.Ped.spawn.y, cfg.Ped.spawn.z
    
    if type(x) ~= "number" or type(y) ~= "number" or type(z) ~= "number" then
        return
    end

    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, x, y, z)
    
    if not blip or blip == 0 then
        return
    end

    local sprite = (type(b.sprite) == "number") and b.sprite or -1258576797 
    SetBlipSprite(blip, sprite, true)
    
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, b.text or "Job Center")
   
    if b.scale and type(b.scale) == "number" then
        SetBlipScale(blip, b.scale)
    else
        SetBlipScale(blip, 0.7) 
    end

    return blip
end

local function setupInteraction(pedHash)
    local interactDistance = cfg.InteractDistance or 2.5
    
    if cfg.Interact == "ox_target" then
        exports.ox_target:addModel(pedHash, {
            {
                event = "jobcenter:clientOpenMenu",
                icon = "fa-solid fa-briefcase",
                label = "Job Center",
                distance = interactDistance
            }
        })
    elseif cfg.Interact == "rsg-target" then
        exports["rsg-target"]:AddTargetModel({pedHash}, {
            options = {
                {
                    type = "client",
                    event = "jobcenter:clientOpenMenu",
                    icon = "fa-solid fa-briefcase",
                    label = "Job Center"
                }
            },
            distance = interactDistance
        })
    end
end

-- Function to get licenses for specific job
local function getLicensesForJob(jobName)
    if not cfg.Licenses then return {} end
    
    local licenses = {}
    for _, license in ipairs(cfg.Licenses) do
        if license.jobRequired == jobName then
            table.insert(licenses, license)
        end
    end
    return licenses
end

local function openJobSpecificLicenseMenu(jobName, jobLabel)
    RSGCore.Functions.TriggerCallback("jobcenter:getPlayerJobAndMoney", function(playerJob, playerMoney, playerJobName)
        if playerJobName ~= jobName then
            doNotify("not_correct_job", jobLabel, "error")
            return
        end

        local licenses = getLicensesForJob(jobName)
        if #licenses == 0 then
            doNotify("no_licenses_available", "error")
            return
        end

        local opts = {}
        
        -- Add each license for this job
        for _, license in ipairs(licenses) do
            table.insert(opts, {
                icon = license.icon or "fa-solid fa-certificate",
                title = license.label,
                description = license.description .. " - $" .. license.price,
                arrow = true,
                onSelect = function()
                    if playerMoney >= license.price then
                        -- Confirm purchase dialog
                        local confirmOpts = {
                            {
                                title = "✔ Confirm Purchase",
                                description = "Purchase " .. license.label .. " for $" .. license.price,
                                icon = "fa-solid fa-check",
                                onSelect = function()
                                    TriggerServerEvent("jobcenter:purchaseLicense", license.item, license.price, license.label)
                                end
                            },
                            {
                                title = "✖ Cancel",
                                description = "Go back to license selection",
                                icon = "fa-solid fa-times",
                                onSelect = function()
                                    openJobSpecificLicenseMenu(jobName, jobLabel)
                                end
                            }
                        }
                        
                        ox_lib:registerContext({
                            id = "license_confirm_" .. license.item,
                            title = "✅ Confirm Purchase",
                            menu = "license_menu_" .. jobName,
                            onBack = function() openJobSpecificLicenseMenu(jobName, jobLabel) end,
                            options = confirmOpts
                        })
                        ox_lib:showContext("license_confirm_" .. license.item)
                    else
                        doNotify("insufficient_funds", license.price, "error")
                    end
                end
            })
        end

        ox_lib:registerContext({
            id = "license_menu_" .. jobName,
            title = "📜 " .. " License Shop",
            menu = "job_center_main",
            onBack = openMainMenu,
            options = opts
        })
        ox_lib:showContext("license_menu_" .. jobName)
    end)
end

local function openMainMenu()
    RSGCore.Functions.TriggerCallback("jobcenter:getPlayerJobAndMoney", function(currentJobName, playerMoney, playerJob)
        if not currentJobName then
            currentJobName = "Unemployed"
        end

        local opts = {
            {
                title = "💼 Current Employment",
                description = currentJobName,
                icon = "fa-solid fa-id-badge",
                disabled = true
            }
        }

        -- Check if current job has licenses available
        local hasLicenses = false
        local jobLabel = ""
        
        if cfg.Licenses and playerJob then
            for _, license in ipairs(cfg.Licenses) do
                if license.jobRequired == playerJob then
                    hasLicenses = true
                    break
                end
            end
            
            -- Get job label
            for _, job in ipairs(cfg.Jobs or {}) do
                if job.jobName == playerJob then
                    jobLabel = job.label
                    break
                end
            end
        end
        
        if hasLicenses then
            table.insert(opts, {
                title = "📜 License Shop",
                description = "Purchase licenses for other players",
                icon = "fa-solid fa-certificate",
                arrow = true,
                onSelect = function()
                    openJobSpecificLicenseMenu(playerJob, jobLabel)
                end
            })
        end

        -- Add job options
        for idx, job in ipairs(cfg.Jobs or {}) do
            table.insert(opts, {
                icon = job.icon or "fa-solid fa-briefcase",
                title = job.label,
                description = job.text or "No description available",
                arrow = true,
                onSelect = function()
                    openDetailMenu(idx)
                end
            })
        end

        ox_lib:registerContext({
            id = "job_center_main", 
            title = "Job Center", 
            options = opts
        })
        ox_lib:showContext("job_center_main")
    end)
end

function openDetailMenu(idx)
    local job = cfg.Jobs[idx]
    if not job then
        doNotify("invalid_job_selection", "error")
        return
    end

    local opts = {
        {
            title = "Tutorial", 
            description = job.tutorial or "No tutorial available",
            icon = "fa-solid fa-book",
            disabled = true
        }
    }

    if job.locations and type(job.locations) == "table" then
        for _, loc in ipairs(job.locations) do
            table.insert(opts, {
                icon = "fa-solid fa-map-pin",
                title = "📍 " .. (loc.label or "Location"),
                description = loc.txt or "Set waypoint to this location",
                onSelect = function()
                    setWaypoint(loc.pos, loc.label)
                end
            })
        end
    end

    table.insert(opts, {
        icon = "fa-solid fa-check",
        title = "✅ Accept Job",
        description = "Take on the " .. job.label .. " role",
        onSelect = function()
            if isJobChangeCooldownActive() then
                local waitTime = getRemainingCooldownSeconds()
                doNotify("job_change_wait", waitTime, "error")
                return
            end
            
            lastJobChange = GetGameTimer()
            TriggerServerEvent("jobcenter:serverSetJob", job.jobName)
        end
    })

    ox_lib:registerContext({
        id = "job_center_detail_" .. idx,
        title = "💼 " .. job.label,
        menu = "job_center_main",
        onBack = openMainMenu,
        options = opts
    })
    ox_lib:showContext("job_center_detail_" .. idx)
end

-- Event Handlers
RegisterNetEvent("jobcenter:clientOpenMenu", openMainMenu)

RegisterNetEvent("jobcenter:clientOpenDetail", function(data)
    if data and data.index then
        openDetailMenu(data.index)
    end
end)

RegisterNetEvent("jobcenter:clientNotify", function(key, ...)
    doNotify(key, ...)
end)

RegisterNetEvent("jobcenter:setWaypoint", function(data)
    if data and data.pos and data.label then
        setWaypoint(data.pos, data.label)
    end
end)

RegisterNetEvent("jobcenter:acceptJob", function(data)
    if not data or not data.index then return end
    
    local job = cfg.Jobs[data.index]
    if not job then return end
    
    if isJobChangeCooldownActive() then
        local waitTime = getRemainingCooldownSeconds()
        doNotify("job_change_wait", waitTime, "error")
        return
    end
    
    lastJobChange = GetGameTimer()
    TriggerServerEvent("jobcenter:serverSetJob", job.jobName)
end)

RegisterNetEvent("jobcenter:licensePurchaseSuccess", function(licenseName, price)
    doNotify("license_purchase_success", licenseName, price, "success")
end)

Citizen.CreateThread(function()
    local ped, pedHash = createJobCenterNPC()
    if ped and pedHash then
        createBlip()
        setupInteraction(pedHash)
    end
end)
