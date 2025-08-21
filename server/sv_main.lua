local RSGCore = exports["rsg-core"]:GetCoreObject()
local webhookURL = Config.WebhookURL or ""
local validJobs, jobLabels = {}, {}

if type(Config.Jobs) == "table" then
    for _, job in ipairs(Config.Jobs) do
        if job.jobName and job.label then
            validJobs[job.jobName] = true
            jobLabels[job.jobName] = job.label
        end
    end
end

local lastRequest = {}

local function sendDiscordLog(oldJob, newJob, userName, charName, playerId)
    if webhookURL == "" then return end
    
    local embed = {
        username = "JobCenter Logger",
        embeds = {
            {
                title = "Player Job Change",
                color = 7506394,
                fields = {
                    {name = "Username", value = userName, inline = false},
                    {name = "Character Name", value = charName, inline = false},
                    {name = "Server ID", value = tostring(playerId), inline = false},
                    {name = "Old Job", value = oldJob, inline = true},
                    {name = "New Job", value = newJob, inline = true}
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }
    
    PerformHttpRequest(
        webhookURL,
        function(err, text, headers)
            if err ~= 204 then
                print("^1[JobCenter] Discord webhook error: " .. tostring(err) .. "^7")
            end
        end,
        "POST",
        json.encode(embed),
        {["Content-Type"] = "application/json"}
    )
end

local function sendLicenseDiscordLog(lawyerName, lawyerChar, licenseName, price, playerId, jobName)
    if webhookURL == "" then return end
    
    local embed = {
        username = "JobCenter License Logger",
        embeds = {
            {
                title = "License Purchase",
                color = 3447003, -- Blue color
                fields = {
                    {name = "Issuer Username", value = lawyerName, inline = false},
                    {name = "Issuer Character", value = lawyerChar, inline = false},
                    {name = "Issuer Job", value = jobLabels[jobName] or jobName, inline = false},
                    {name = "Server ID", value = tostring(playerId), inline = false},
                    {name = "License Purchased", value = licenseName, inline = true},
                    {name = "Price", value = "$" .. tostring(price), inline = true}
                },
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
            }
        }
    }
    
    PerformHttpRequest(
        webhookURL,
        function(err, text, headers)
            if err ~= 204 then
                print("^1[JobCenter] License Discord webhook error: " .. tostring(err) .. "^7")
            end
        end,
        "POST",
        json.encode(embed),
        {["Content-Type"] = "application/json"}
    )
end

RSGCore.Functions.CreateCallback("jobcenter:getPlayerJobAndMoney", function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        cb("Unemployed", 0, "unemployed")
        return
    end
    
    local job = Player.PlayerData.job
    local jobLabel = job and job.label or "Unemployed"
    local jobName = job and job.name or "unemployed"
    local money = Player.PlayerData.money.cash or 0
    
    cb(jobLabel, money, jobName)
end)

-- Original callback for backward compatibility
RSGCore.Functions.CreateCallback("jobcenter:getPlayerJob", function(source, cb)
    local Player = RSGCore.Functions.GetPlayer(source)
    if not Player then
        cb("Unemployed")
        return
    end
    
    local job = Player.PlayerData.job
    local label = job and job.label or "Unemployed"
    cb(label)
end)

RegisterNetEvent("jobcenter:purchaseLicense", function(licenseItem, price, licenseName)
    local src = source
    
    if type(licenseItem) ~= "string" or type(price) ~= "number" or type(licenseName) ~= "string" then
        TriggerClientEvent("jobcenter:clientNotify", src, "invalid_license_data", "error")
        return
    end
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        return
    end
    
    local job = Player.PlayerData.job
    if not job then
        TriggerClientEvent("jobcenter:clientNotify", src, "no_job", "error")
        return
    end
    
    local playerMoney = Player.PlayerData.money.cash or 0
    if playerMoney < price then
        TriggerClientEvent("jobcenter:clientNotify", src, "insufficient_funds", price, "error")
        return
    end
    
    -- Validate license exists and is available for this job
    local validLicense = false
    if Config.Licenses then
        for _, license in ipairs(Config.Licenses) do
            if license.item == licenseItem and 
               license.price == price and 
               license.jobRequired == job.name then
                validLicense = true
                break
            end
        end
    end
    
    if not validLicense then
        TriggerClientEvent("jobcenter:clientNotify", src, "invalid_license", "error")
        return
    end
    
    -- Remove money
    Player.Functions.RemoveMoney("cash", price, "license-purchase")
    
    -- Add the license item
    Player.Functions.AddItem(licenseItem, 1, nil, {
        description = licenseName .. " - Issued by " .. (Player.PlayerData.charinfo.firstname or "Unknown") .. " " .. (Player.PlayerData.charinfo.lastname or "Worker"),
        purchaseDate = os.date("%Y-%m-%d %H:%M:%S")
    })
    
    -- Get player info for logging
    local userName = GetPlayerName(src) or "Unknown"
    local charinfo = Player.PlayerData.charinfo or {}
    local charName = string.format("%s %s", charinfo.firstname or "Unknown", charinfo.lastname or "Player")
    
    -- Notify client of success
    TriggerClientEvent("jobcenter:licensePurchaseSuccess", src, licenseName, price)
    
    -- Log to Discord
    sendLicenseDiscordLog(userName, charName, licenseName, price, src, job.name)
    
    -- Console log
    print(string.format("^2[JobCenter] %s (%s) [%s] purchased %s for $%d^7", 
          charName, userName, jobLabels[job.name] or job.name, licenseName, price))
end)

RegisterNetEvent("jobcenter:serverSetJob", function(jobName)
    local src = source
    
    if type(jobName) ~= "string" or not validJobs[jobName] then
        TriggerClientEvent("jobcenter:clientNotify", src, "invalid_job", jobName, "error")
        return
    end
    
    local now = os.time()
    local cooldown = tonumber(Config.CooldownSeconds) or 60
    if lastRequest[src] and (now - lastRequest[src]) < cooldown then
        local wait = cooldown - (now - lastRequest[src])
        TriggerClientEvent("jobcenter:clientNotify", src, "job_change_wait", wait, "error")
        return
    end
    
    lastRequest[src] = now
    
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then
        return
    end
    
    local userName = GetPlayerName(src) or "Unknown"
    local charinfo = Player.PlayerData.charinfo or {}
    local charName = string.format("%s %s", charinfo.firstname or "Unknown", charinfo.lastname or "Player")
    
    local oldJobKey = Player.PlayerData.job and Player.PlayerData.job.name
    local oldJobLabel = oldJobKey and jobLabels[oldJobKey] or "Unemployed"
    local newJobLabel = jobLabels[jobName] or jobName
    
    Player.Functions.SetJob(jobName, 0)
    
    TriggerClientEvent("jobcenter:clientNotify", src, "job_change_success", newJobLabel, "success")
    
    sendDiscordLog(oldJobLabel, newJobLabel, userName, charName, src)
    
    print(string.format("^2[JobCenter] %s (%s) changed job from %s to %s^7", 
          charName, userName, oldJobLabel, newJobLabel))
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    if lastRequest[src] then
        lastRequest[src] = nil
    end
end)
