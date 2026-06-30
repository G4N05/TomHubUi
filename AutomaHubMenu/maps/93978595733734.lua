return function(AutomaHub, services)
    local Players          = services.Players
    local ReplicatedStorage = services.ReplicatedStorage
    local CollectionService = services.CollectionService
    local RunService       = services.RunService
    local UserInputService = services.UserInputService
    local Teams            = services.Teams
    local VirtualInputManager = services.VirtualInputManager
    local Workspace        = services.Workspace
    local LocalPlayer      = services.LocalPlayer

    AutomaHub:addTab({ id = "Survivor", icon = "shield", fallback = "S" })
    AutomaHub:addTab({ id = "Player",  icon = "user",   fallback = "P" })
    AutomaHub:addTab({ id = "Visual",  icon = "eye",    fallback = "V" })
    AutomaHub:addTab({ id = "Aim",     icon = "crosshair", fallback = "A" })

    -- daftarin pengecek in-match buat UICore (nentuin mouse pas GUI ditutup:
    -- in-match -> LockCenter, lobby -> Default). Metode sama kayak source.
    if getgenv then
        getgenv().AutomaHubMatchChecker = function()
            local team = LocalPlayer.Team
            return team ~= nil and (team.Name == "Killer" or team.Name == "Survivors")
        end
    end

    local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local Humanoid = Character:WaitForChild("Humanoid")
    local RootPart = Character:WaitForChild("HumanoidRootPart")

    local Remotes = ReplicatedStorage:WaitForChild("Remotes")
    local daggerFolder = Remotes:WaitForChild("Items"):WaitForChild("Parrying Dagger")
    local parryResult = daggerFolder:WaitForChild("parryResult")
    local DamagevizEvent = Remotes:WaitForChild("Killers"):WaitForChild("Damageviz")
    local SlowAttack = Remotes:WaitForChild("Killers"):FindFirstChild("SlowAttack")
    local KillerTeam = Teams:FindFirstChild("Killer")

    local killerDistance = 999
    local killerRoot = nil
    local killerFilterCache = { Character }

    LocalPlayer.CharacterAdded:Connect(function(newChar)
        Character = newChar
        Humanoid = newChar:WaitForChild("Humanoid")
        RootPart = newChar:WaitForChild("HumanoidRootPart")
    end)

    RunService.Heartbeat:Connect(function()
        if not RootPart or not RootPart.Parent then return end
        local nearest = 9999
        local nearestRoot = nil
        table.clear(killerFilterCache)
        table.insert(killerFilterCache, Character)
        if KillerTeam then
            for _, plr in ipairs(KillerTeam:GetPlayers()) do
                local kChar = plr.Character
                if kChar then
                    table.insert(killerFilterCache, kChar)
                    local kRoot = kChar:FindFirstChild("HumanoidRootPart")
                    if kRoot then
                        local d = (RootPart.Position - kRoot.Position).Magnitude
                        if d < nearest then nearest = d; nearestRoot = kRoot end
                    end
                end
            end
        end
        killerDistance = nearest
        killerRoot = nearestRoot
    end)

    local function hasLineOfSight()
        if not RootPart or not RootPart.Parent or not killerRoot then return false end
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.IgnoreWater = true
        rayParams.FilterDescendantsInstances = killerFilterCache
        local result = Workspace:Raycast(RootPart.Position, killerRoot.Position - RootPart.Position, rayParams)
        if result then return false end
        return true
    end

    local animHandlers = {}
    local killerAnimConnections = {}
    local function fireAnim(plr, idRaw, animId)
        for _, h in ipairs(animHandlers) do pcall(h, plr, idRaw, animId) end
    end
    local function hookKillerAnimators()
        for _, c in ipairs(killerAnimConnections) do c:Disconnect() end
        table.clear(killerAnimConnections)
        if KillerTeam then
            for _, plr in ipairs(KillerTeam:GetPlayers()) do
                local function hook(char)
                    local hum = char:WaitForChild("Humanoid", 5)
                    if hum then
                        local animator = hum:WaitForChild("Animator", 5)
                        if animator then
                            table.insert(killerAnimConnections, animator.AnimationPlayed:Connect(function(anim)
                                local id = anim.Animation and anim.Animation.AnimationId
                                local animId = id and tostring(id):match("%d+") or ""
                                fireAnim(plr, id, animId)
                            end))
                        end
                    end
                end
                if plr.Character then task.spawn(hook, plr.Character) end
                table.insert(killerAnimConnections, plr.CharacterAdded:Connect(hook))
            end
        end
    end

    local silentSupported = (getrawmetatable ~= nil) and (getnamecallmethod ~= nil) and (newcclosure ~= nil)
    local namecallHandlers = {}
    local rawCall = nil
    local function installNamecallHook()
        if not silentSupported then return end
        local mt = getrawmetatable(game)
        if setreadonly then pcall(setreadonly, mt, false) end
        if getgenv and getgenv().__tomaAimOrig then
            pcall(function() mt.__namecall = getgenv().__tomaAimOrig end)
        end
        local oldNamecall = mt.__namecall
        if getgenv then getgenv().__tomaAimOrig = oldNamecall end
        rawCall = function(self, ...) return oldNamecall(self, ...) end
        local hookFn = function(self, ...)
            if typeof(self) == "Instance" then
                local method = getnamecallmethod()
                for _, h in ipairs(namecallHandlers) do
                    local ok, res = h(self, method, ...)
                    if ok then return res end
                end
            end
            return oldNamecall(self, ...)
        end
        mt.__namecall = newcclosure and newcclosure(hookFn) or hookFn
    end

    local ctx = {
        tabs = { Combat = "Survivor", Player = "Player", Visual = "Visual", Aim = "Aim" },
        AutomaHub = AutomaHub,
        Players = Players, ReplicatedStorage = ReplicatedStorage,
        CollectionService = CollectionService, RunService = RunService,
        UserInputService = UserInputService, Teams = Teams,
        VirtualInputManager = VirtualInputManager, Workspace = Workspace,
        LocalPlayer = LocalPlayer,
        Remotes = Remotes, parryResult = parryResult,
        DamagevizEvent = DamagevizEvent, SlowAttack = SlowAttack, KillerTeam = KillerTeam,
        getCharacter = function() return Character end,
        getHumanoid = function() return Humanoid end,
        getRootPart = function() return RootPart end,
        getKillerRoot = function() return killerRoot end,
        getKillerDistance = function() return killerDistance end,
        hasLineOfSight = hasLineOfSight,
        silentSupported = silentSupported,
        onKillerAnim = function(fn) table.insert(animHandlers, fn) end,
        onNamecall = function(fn) table.insert(namecallHandlers, fn) end,
        callOriginal = function(self, ...) return rawCall(self, ...) end,
    }

    local __VD_MODULES = {}

    __VD_MODULES["Combat/AutoParry.lua"] = (function()
return function(ctx)
    local CollectionService = ctx.CollectionService
    local UserInputService = ctx.UserInputService
    local VirtualInputManager = ctx.VirtualInputManager
    local RunService = ctx.RunService
    local LocalPlayer = ctx.LocalPlayer
    local parryResult = ctx.parryResult
    local DamagevizEvent = ctx.DamagevizEvent
    local SlowAttack = ctx.SlowAttack
    local AutomaHub = ctx.AutomaHub
    local tabId = ctx.tabs.Combat

    local isOnCooldown, isResolving, isSilenced, isAutoParrying = false, false, false, false
    local autoParryEnabled = false
    local parryDistance = 9
    local ATTACK_ANIM_IDS = {
        ["117042998468241"]=true,["129784271201071"]=true,["113255068724446"]=true,
        ["118907603246885"]=true,["122812055447896"]=true,["110355011987939"]=true,
        ["135002183282873"]=true,["105374834496520"]=true,["138720291317243"]=true,
        ["115244153053858"]=true,["106871536134254"]=true,
    }
    local lastPrePress, rearmCooldown, postParryCooldown, lastAutoPress = 0, 0.08, 0.25, 0
    local facingDotThreshold = 0.1

    local function canParry()
        if isOnCooldown or isSilenced or LocalPlayer:GetAttribute("IsDead") then return false end
        local Character = ctx.getCharacter()
        local RootPart = ctx.getRootPart()
        if not Character or not Character.Parent or Character:GetAttribute("IsCarried") or Character:GetAttribute("IsHooked") then return false end
        if CollectionService:HasTag(RootPart, "doing action") then return false end
        return true
    end

    local function cleanupStaleActionTag()
        local RootPart = ctx.getRootPart()
        if not RootPart or not RootPart.Parent then return end
        if CollectionService:HasTag(RootPart, "doing action") then
            local char = LocalPlayer.Character
            if char then
                local checkInt = char:FindFirstChild("CheckInterractable")
                if not checkInt or not checkInt:GetAttribute("isRepairing") then
                    CollectionService:RemoveTag(RootPart, "doing action")
                    if RootPart.Anchored then RootPart.Anchored = false end
                    isResolving, isOnCooldown = false, false
                end
            end
        end
    end

    local function isKillerFacing()
        local killerRoot = ctx.getKillerRoot()
        local RootPart = ctx.getRootPart()
        if not killerRoot or not killerRoot.Parent or not RootPart or not RootPart.Parent then return true end
        local dot = killerRoot.CFrame.LookVector:Dot((RootPart.Position - killerRoot.Position).Unit)
        return dot >= facingDotThreshold
    end

    local function doParryPress()
        isAutoParrying = true
        lastAutoPress = os.clock()
        lastPrePress = os.clock()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 1, true, game, 1)
        task.delay(0.05, function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 1, false, game, 1)
            isAutoParrying = false
        end)
    end

    local function attemptParry(maxRange)
        if not autoParryEnabled or ctx.getKillerDistance() > maxRange or not canParry() then return end
        if (os.clock() - lastPrePress) < rearmCooldown then return end
        if not ctx.hasLineOfSight() then return end
        if not isKillerFacing() then return end
        doParryPress()
    end

    local function triggerParry() attemptParry(parryDistance) end

    DamagevizEvent.OnClientEvent:Connect(triggerParry)
    if SlowAttack then SlowAttack.OnClientEvent:Connect(triggerParry) end
    ctx.onKillerAnim(function(plr, idRaw, animId)
        if ATTACK_ANIM_IDS[animId] then triggerParry() end
    end)
    parryResult.OnClientEvent:Connect(function(success, cd)
        isResolving = false
        if success then
            isOnCooldown = true
            task.delay(postParryCooldown, function() isOnCooldown = false end)
        end
    end)
    UserInputService.InputBegan:Connect(function(input, gp)
        if not gp and input.UserInputType == Enum.UserInputType.MouseButton2 then
            if isAutoParrying or (os.clock() - lastAutoPress) < 0.2 then return end
            if canParry() then isResolving = true end
        end
    end)
    CollectionService:GetInstanceAddedSignal("Silenced"):Connect(function(i) if i == ctx.getCharacter() then isSilenced = true end end)
    CollectionService:GetInstanceRemovedSignal("Silenced"):Connect(function(i) if i == ctx.getCharacter() then isSilenced = false end end)
    LocalPlayer.CharacterAdded:Connect(function() isOnCooldown, isResolving, isSilenced = false, false, false end)
    RunService.Heartbeat:Connect(function()
        local RootPart = ctx.getRootPart()
        if RootPart and CollectionService:HasTag(RootPart, "doing action") then cleanupStaleActionTag() end
    end)

    ctx.parry = {
        isEnabled = function() return autoParryEnabled end,
        canParry = canParry,
        doParryPress = doParryPress,
    }

    AutomaHub:addItem(tabId, { t="toggle", name="Auto Parry", default=false, onChange=function(state) autoParryEnabled = state end })
    AutomaHub:addItem(tabId, { t="slider", name="Parry Distance", min=5, max=50, default=9, onChange=function(value) if value and value >= 5 then parryDistance = value end end })
end
    end)()

    __VD_MODULES["Combat/AutoParryDashHidden.lua"] = (function()
return function(ctx)
    if not ctx.parry then warn("[AutomaHub] Dash Parry butuh AutoParry duluan.") return end
    local AutomaHub = ctx.AutomaHub
    local tabId = ctx.tabs.Combat
    local DASH_WINDUP_ID = "98163597193511"
    local dashDistance = 30
    local dashParryDelay = 0.775
    local dashFacingDotMin = math.cos(math.rad(10))
    local dashRecheckFacing = true
    local dashRetriggerGuard = 1.4
    local dashPending = false
    local lastDashSchedule = -999

    local function dashFacingInfo(kr)
        local RootPart = ctx.getRootPart()
        if not kr or not kr.Parent or not RootPart or not RootPart.Parent then return 999, false end
        local toPlayer = RootPart.Position - kr.Position
        local dist = toPlayer.Magnitude
        if dist < 0.01 then return dist, true end
        local dot = math.clamp(kr.CFrame.LookVector:Dot(toPlayer.Unit), -1, 1)
        return dist, (dot >= dashFacingDotMin)
    end

    local function fireDashParry(getKr)
        dashPending = false
        if not ctx.parry.isEnabled() then return end
        local kr = getKr()
        local dist, facingOk = dashFacingInfo(kr)
        if dist > dashDistance then return end
        if dashRecheckFacing and not facingOk then return end
        if not ctx.parry.canParry() then return end
        if not ctx.hasLineOfSight() then return end
        ctx.parry.doParryPress()
    end

    local function scheduleDashParry(plr, kr)
        if not ctx.parry.isEnabled() or dashPending or (os.clock() - lastDashSchedule) < dashRetriggerGuard then return end
        local dist, facingOk = dashFacingInfo(kr)
        if dist > dashDistance or not facingOk then return end
        dashPending = true
        lastDashSchedule = os.clock()
        task.delay(dashParryDelay, function()
            fireDashParry(function() return plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") end)
        end)
    end

    ctx.onKillerAnim(function(plr, idRaw, animId)
        if idRaw and tostring(idRaw):find(DASH_WINDUP_ID) then
            scheduleDashParry(plr, plr.Character and plr.Character:FindFirstChild("HumanoidRootPart"))
        end
    end)

    AutomaHub:addItem(tabId, { t="slider", name="Dash Parry Distance", min=5, max=60, default=30, onChange=function(value) if value and value >= 5 then dashDistance = value end end })
end
    end)()

    __VD_MODULES["Combat/AutoDogdeAbbys.lua"] = (function()
return function(ctx)
    local VirtualInputManager = ctx.VirtualInputManager
    local AutomaHub = ctx.AutomaHub
    local tabId = ctx.tabs.Combat
    local autoDodgeEnabled = false
    local dodgeDistance = 25
    local crouchHoldTime = 1.0
    local dodgeTriggerDelay = 0.1
    local dodgeSkillWindow = 2.0
    local dodgeCheckInterval = 0.1
    local ABYSS_SKILL_ID = "80411309607666"
    local isDodging = false
    local dodgeSkillPending = false

    local function doCrouch()
        if isDodging then return end
        isDodging = true
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.LeftControl, false, game)
        task.delay(crouchHoldTime, function()
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.LeftControl, false, game)
            isDodging = false
        end)
    end

    local function triggerDodge()
        if not autoDodgeEnabled or isDodging then return end
        if ctx.getKillerDistance() <= dodgeDistance and ctx.hasLineOfSight() then
            task.delay(dodgeTriggerDelay, function()
                if not isDodging and not dodgeSkillPending and ctx.getKillerDistance() <= dodgeDistance and ctx.hasLineOfSight() then
                    doCrouch()
                end
            end)
            return
        end
        if dodgeSkillPending then return end
        dodgeSkillPending = true
        task.spawn(function()
            local elapsed = 0
            while elapsed < dodgeSkillWindow do
                task.wait(dodgeCheckInterval)
                elapsed = elapsed + dodgeCheckInterval
                if not autoDodgeEnabled or isDodging then break end
                if ctx.getKillerDistance() <= dodgeDistance and ctx.hasLineOfSight() then
                    task.delay(dodgeTriggerDelay, function()
                        if not isDodging and not dodgeSkillPending and ctx.getKillerDistance() <= dodgeDistance and ctx.hasLineOfSight() then
                            doCrouch()
                        end
                    end)
                    break
                end
            end
            dodgeSkillPending = false
        end)
    end

    ctx.onKillerAnim(function(plr, idRaw, animId)
        if idRaw and tostring(idRaw):find(ABYSS_SKILL_ID) then triggerDodge() end
    end)

    AutomaHub:addItem(tabId, { t="toggle", name="Auto Dodge Abysswalker", default=false, onChange=function(state) autoDodgeEnabled = state end })
    AutomaHub:addItem(tabId, { t="slider", name="Dodge Distance", min=5, max=60, default=25, onChange=function(value) if value and value >= 5 then dodgeDistance = value end end })
end
    end)()

    __VD_MODULES["Combat/SkillCheck.lua"] = (function()
return function(ctx)
    local RunService = ctx.RunService
    local VirtualInputManager = ctx.VirtualInputManager
    local LocalPlayer = ctx.LocalPlayer
    local AutomaHub = ctx.AutomaHub
    local tabId = ctx.tabs.Combat
    local autoSkillCheckEnabled = false
    local scFireLow, scFireHigh, scRetrySec = 104, 150, 0.35
    local scPressed, scLastGoal, scPressedAt = false, nil, 0
    local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
    local SkillCheckFrame, SkillCheckLine, SkillCheckGoal = nil, nil, nil

    local function resolveSkillCheckRefs()
        local gui = PlayerGui:FindFirstChild("SkillCheckPromptGui")
        local check = gui and gui:FindFirstChild("Check")
        if not check then SkillCheckFrame, SkillCheckLine, SkillCheckGoal = nil, nil, nil return false end
        SkillCheckFrame = check
        SkillCheckLine = check:FindFirstChild("Line")
        SkillCheckGoal = check:FindFirstChild("Goal")
        return (SkillCheckLine ~= nil and SkillCheckGoal ~= nil)
    end
    resolveSkillCheckRefs()

    RunService.Heartbeat:Connect(function()
        if not autoSkillCheckEnabled then return end
        if not SkillCheckFrame or not SkillCheckFrame.Parent or not SkillCheckLine or not SkillCheckGoal then resolveSkillCheckRefs() end
        if SkillCheckFrame and SkillCheckFrame.Parent and SkillCheckFrame.Visible then
            local goal = SkillCheckGoal.Rotation % 360
            local line = SkillCheckLine.Rotation % 360
            local diff = (line - goal) % 360
            if scLastGoal == nil or math.abs(goal - scLastGoal) > 0.5 then scLastGoal = goal scPressed = false end
            if scPressed and (os.clock() - scPressedAt) > scRetrySec then scPressed = false end
            if not scPressed and diff >= scFireLow and diff <= scFireHigh then
                scPressed = true
                scPressedAt = os.clock()
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
                task.delay(0.04, function() VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
            end
        else scPressed = false scLastGoal = nil end
    end)

    AutomaHub:addItem(tabId, { t="toggle", name="Auto Skillcheck", default=false, onChange=function(state) autoSkillCheckEnabled = state end })
end
    end)()

    __VD_MODULES["Visual/Esp.lua"] = (function()
return function(ctx)
    local Players = ctx.Players
    local LocalPlayer = ctx.LocalPlayer
    local AutomaHub = ctx.AutomaHub
    local tabId = ctx.tabs.Visual
    local espEnabled = false
    local activeConnections = {}
    local activeHighlights = {}

    local function getPlayerColor(player)
        if player.Team and (player.Team.Name:lower():find("killer") or player.Team.Name:lower():find("hunter")) then return Color3.fromRGB(255, 0, 0) end
        if player:GetAttribute("Role") == "Killer" or player:GetAttribute("Killer") then return Color3.fromRGB(255, 0, 0) end
        return Color3.fromRGB(0, 255, 0)
    end

    local function cleanupModel(model)
        pcall(function()
            if activeHighlights[model] then for _, obj in ipairs(activeHighlights[model]) do obj:Destroy() end activeHighlights[model] = nil end
        end)
    end
    local function cleanupPlayer(player)
        pcall(function()
            if activeConnections[player] then for _, conn in ipairs(activeConnections[player]) do conn:Disconnect() end activeConnections[player] = nil end
            if player.Character then cleanupModel(player.Character) end
        end)
    end
    local function updateESPColor(player, hl, nameLabel)
        pcall(function()
            local color = getPlayerColor(player)
            if hl and hl.Parent then hl.FillColor = color hl.OutlineColor = color end
            if nameLabel and nameLabel.Parent then nameLabel.TextColor3 = color end
        end)
    end

    local function applyESP(model, defaultColor, nameText)
        cleanupModel(model)
        if not espEnabled then return end
        local hl = Instance.new("Highlight")
        hl.FillColor = defaultColor hl.OutlineColor = defaultColor hl.FillTransparency = 0.6 hl.OutlineTransparency = 0 hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop hl.Parent = model
        local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
        if root then
            local bill = Instance.new("BillboardGui")
            bill.Name = "ESP_NameTag" bill.Size = UDim2.new(0, 200, 0, 45) bill.StudsOffset = Vector3.new(0, 2.5, 0) bill.AlwaysOnTop = true bill.LightInfluence = 0 bill.MaxDistance = 2000 bill.Adornee = root bill.Parent = root
            local container = Instance.new("Frame")
            container.Size = UDim2.new(1, 0, 1, 0) container.BackgroundTransparency = 1 container.Parent = bill
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Size = UDim2.new(1, 0, 0.6, 0) nameLabel.BackgroundTransparency = 1 nameLabel.TextSize = 14 nameLabel.Font = Enum.Font.SourceSansBold nameLabel.TextColor3 = defaultColor nameLabel.Text = nameText nameLabel.TextStrokeTransparency = 0 nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0) nameLabel.Parent = container
            local distLabel = Instance.new("TextLabel")
            distLabel.Size = UDim2.new(1, 0, 0.4, 0) distLabel.Position = UDim2.new(0, 0, 0.6, 0) distLabel.BackgroundTransparency = 1 distLabel.TextSize = 11 distLabel.Font = Enum.Font.SourceSans distLabel.TextColor3 = Color3.fromRGB(255, 255, 255) distLabel.Text = "" distLabel.TextStrokeTransparency = 0 distLabel.TextStrokeColor3 = Color3.new(0, 0, 0) distLabel.Parent = container
            local player = Players:GetPlayerFromCharacter(model)
            if player then updateESPColor(player, hl, nameLabel) end
            task.spawn(function()
                while bill and bill.Parent and espEnabled do
                    pcall(function()
                        local charRoot = model:FindFirstChild("HumanoidRootPart")
                        local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if charRoot and localRoot then distLabel.Text = "[" .. tostring(math.floor((charRoot.Position - localRoot.Position).Magnitude)) .. "m]" else distLabel.Text = "" end
                    end)
                    task.wait(0.3)
                end
            end)
        end
        activeHighlights[model] = { hl, bill }
    end

    local function setupPlayer(player)
        if player == LocalPlayer then return end
        cleanupPlayer(player)
        activeConnections[player] = {}
        local function onCharacter(char)
            task.wait(0.5)
            pcall(function()
                if not espEnabled then return end
                applyESP(char, getPlayerColor(player), player.Name)
                local hl = char:FindFirstChildOfClass("Highlight")
                local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
                local bill = root and root:FindFirstChild("ESP_NameTag")
                local nameLabel = bill and bill:FindFirstChildOfClass("Frame") and bill:FindFirstChildOfClass("Frame"):FindFirstChildOfClass("TextLabel")
                if hl and nameLabel then
                    table.insert(activeConnections[player], player:GetPropertyChangedSignal("Team"):Connect(function() updateESPColor(player, hl, nameLabel) end))
                end
            end)
        end
        if player.Character then task.spawn(onCharacter, player.Character) end
        table.insert(activeConnections[player], player.CharacterAdded:Connect(onCharacter))
    end

    local function startESP() for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end end
    local function stopESP()
        for _, p in ipairs(Players:GetPlayers()) do cleanupPlayer(p) end
        for model in pairs(activeHighlights) do cleanupModel(model) end
        activeHighlights = {}
        activeConnections = {}
        -- Brute-force: sapu bersih sisa ESP yang ga ke-track (respawn, billboard nyangkut, dll)
        pcall(function()
            for _, p in ipairs(Players:GetPlayers()) do
                local char = p.Character
                if char then
                    for _, obj in ipairs(char:GetDescendants()) do
                        if obj:IsA("Highlight") or (obj:IsA("BillboardGui") and obj.Name == "ESP_NameTag") then
                            obj:Destroy()
                        end
                    end
                end
            end
        end)
    end
    Players.PlayerAdded:Connect(setupPlayer)
    Players.PlayerRemoving:Connect(cleanupPlayer)

    AutomaHub:addItem(tabId, { t="toggle", name="ESP", default=false, onChange=function(state) espEnabled = state if state then startESP() else stopESP() end end })
end
    end)()

    __VD_MODULES["Aim/AimTwistOfFate.lua"] = (function()
return function(ctx)
    local Workspace = ctx.Workspace
    local Teams = ctx.Teams
    local UserInputService = ctx.UserInputService
    local RunService = ctx.RunService
    local Players = ctx.Players
    local LocalPlayer = ctx.LocalPlayer
    local silentSupported = ctx.silentSupported
    local AutomaHub = ctx.AutomaHub
    local tabId = ctx.tabs.Aim

    local aimTargetMode = "Killer"
    local silentAimEnabled, aimLockEnabled, aimWallcheck, enableLead = false, false, true, true
    local fovRadius, fovFollowMouse, aimShowFov = 120, true, true
    local AIM_TARGET_PART = "HumanoidRootPart"
    local AIM_BULLET_SPEED = 200
    local AIM_MUZZLE_OFFSET = Vector3.new(-1.41, -1.10, -5.44)
    local AIM_LEAD_MULT = 1.0
    local AIM_SMOOTH = 0.25
    local AimCamera = Workspace.CurrentCamera
    local aimSilentDir, aimTargetVel = nil, nil
    local aimVelSampleName, aimVelSamplePos, aimVelSampleT = nil, nil, 0

    local function aimGetTeam() if aimTargetMode == "Survivor" then return Teams:FindFirstChild("Survivors") end return Teams:FindFirstChild("Killer") end
    local function aimGetFovCenter() if fovFollowMouse then local m = UserInputService:GetMouseLocation() return Vector2.new(m.X, m.Y) end local vp = AimCamera.ViewportSize return Vector2.new(vp.X/2, vp.Y/2) end
    local function aimGetPart(plr) return plr and plr.Character and plr.Character:FindFirstChild(AIM_TARGET_PART) end

    local function aimHasLOS(part)
        if not part or not part.Parent then return false end
        local origin = AimCamera.CFrame.Position
        local rp = RaycastParams.new()
        rp.FilterType = Enum.RaycastFilterType.Exclude rp.IgnoreWater = true
        local ignore = {}
        for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then table.insert(ignore, plr.Character) end end
        rp.FilterDescendantsInstances = ignore
        local char = part.Parent
        local points = { part.Position }
        local head = char and char:FindFirstChild("Head")
        if head then table.insert(points, head.Position) end
        table.insert(points, part.Position + Vector3.new(0, 2.5, 0))
        table.insert(points, part.Position - Vector3.new(0, 2.5, 0))
        for _, p in ipairs(points) do if Workspace:Raycast(origin, p - origin, rp) == nil then return true end end
        return false
    end

    local function aimGetTarget()
        local team = aimGetTeam() if not team then return nil end
        local center = aimGetFovCenter()
        local best, bestDist = nil, fovRadius
        for _, plr in ipairs(team:GetPlayers()) do
            if plr ~= LocalPlayer then
                local part = aimGetPart(plr)
                if part then
                    local sp, onScreen = AimCamera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= bestDist then if (not aimWallcheck) or aimHasLOS(part) then best, bestDist = plr, d end end
                    end
                end
            end
        end
        return best
    end

    local function aimComputeDir(part, targetVel)
        local muzzle = AimCamera.CFrame:PointToWorldSpace(AIM_MUZZLE_OFFSET)
        local tp = part.Position local aimPoint = tp
        if enableLead and targetVel then
            local tvel = targetVel * AIM_LEAD_MULT
            local tof = (tp - muzzle).Magnitude / AIM_BULLET_SPEED
            for _ = 1, 2 do local predicted = tp + tvel * tof tof = (predicted - muzzle).Magnitude / AIM_BULLET_SPEED end
            aimPoint = tp + tvel * tof
        end
        local dir = (aimPoint - muzzle) if dir.Magnitude < 0.01 then return nil end return dir.Unit
    end

    local aimFovCircle = nil
    if Drawing then
        aimFovCircle = Drawing.new("Circle")
        aimFovCircle.Thickness = 2 aimFovCircle.NumSides = 64 aimFovCircle.Radius = fovRadius
        aimFovCircle.Filled = false aimFovCircle.Visible = false aimFovCircle.Color = Color3.fromRGB(255, 255, 255)
    end

    local aimRenderConn = RunService.RenderStepped:Connect(function()
        AimCamera = Workspace.CurrentCamera
        if not (silentAimEnabled or aimLockEnabled) then aimSilentDir = nil if aimFovCircle then aimFovCircle.Visible = false end return end
        if aimFovCircle then aimFovCircle.Visible = aimShowFov aimFovCircle.Radius = fovRadius aimFovCircle.Position = aimGetFovCenter() end
        local target = aimGetTarget()
        if target then
            local part = aimGetPart(target)
            if part then
                local pos = part.Position local now = tick()
                if aimVelSampleName == target.Name and aimVelSamplePos then
                    local dt = now - aimVelSampleT
                    if dt >= 0.04 then
                        local instVel = (pos - aimVelSamplePos) / dt
                        aimTargetVel = aimTargetVel and aimTargetVel:Lerp(instVel, 0.5) or instVel
                        aimVelSamplePos = pos aimVelSampleT = now
                    end
                else aimVelSampleName = target.Name aimVelSamplePos = pos aimVelSampleT = now aimTargetVel = Vector3.zero end
                local dir = aimComputeDir(part, aimTargetVel)
                aimSilentDir = (silentAimEnabled and dir) or nil
                if aimFovCircle then aimFovCircle.Color = Color3.fromRGB(255, 0, 0) end
                if aimLockEnabled and dir and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
                    local cf = AimCamera.CFrame local goal = CFrame.new(cf.Position, cf.Position + dir)
                    AimCamera.CFrame = cf:Lerp(goal, AIM_SMOOTH)
                end
            else aimSilentDir = nil aimVelSampleName = nil if aimFovCircle then aimFovCircle.Color = Color3.fromRGB(255, 255, 255) end end
        else aimSilentDir = nil aimVelSampleName = nil if aimFovCircle then aimFovCircle.Color = Color3.fromRGB(255, 255, 255) end end
    end)

    ctx.onNamecall(function(self, method, ...)
        if method == "FireServer" and silentAimEnabled and aimSilentDir and self.Name == "Fire" then
            local p = self.Parent
            if p and p.Parent and p.Parent.Name == "Items" then
                local args = { ... }
                if typeof(args[2]) == "Vector3" then args[2] = aimSilentDir return true, ctx.callOriginal(self, unpack(args)) end
                for i, v in ipairs(args) do if typeof(v) == "Vector3" then args[i] = aimSilentDir return true, ctx.callOriginal(self, unpack(args)) end end
            end
        end
        return false
    end)

    if getgenv then
        local g = getgenv()
        if g.__tomaAimRender then pcall(function() g.__tomaAimRender:Disconnect() end) end
        g.__tomaAimRender = aimRenderConn
        if g.__tomaFov then pcall(function() g.__tomaFov:Remove() end) end
        g.__tomaFov = aimFovCircle
    end

    AutomaHub:addItem(tabId, { t="dropdown", name="Aim Target", options={"Killer","Survivor"}, default="Killer", onChange=function(option) if option == "Killer" or option == "Survivor" then aimTargetMode = option end end })
    AutomaHub:addItem(tabId, { t="toggle", name=silentSupported and "Silent Aim" or "Silent Aim (Unsupported)", default=false, onChange=function(state) if silentSupported then silentAimEnabled = state end end })
    AutomaHub:addItem(tabId, { t="toggle", name="Aim Lock", default=false, onChange=function(state) aimLockEnabled = state end })
    AutomaHub:addItem(tabId, { t="toggle", name="Wallcheck", default=true, onChange=function(state) aimWallcheck = state end })
    AutomaHub:addItem(tabId, { t="toggle", name="Lead Prediction", default=true, onChange=function(state) enableLead = state end })
    AutomaHub:addItem(tabId, { t="slider", name="Lead Strength", min=0, max=3, default=1, onChange=function(value) if value then AIM_LEAD_MULT = value end end })
    AutomaHub:addItem(tabId, { t="toggle", name="POV Circle", default=true, onChange=function(state) aimShowFov = state end })
    AutomaHub:addItem(tabId, { t="slider", name="FOV Radius", min=40, max=400, default=120, onChange=function(value) if value and value >= 40 then fovRadius = value end end })
end
    end)()

    __VD_MODULES["Aim/AimVeil.lua"] = (function()
return function(ctx)
    local Workspace = ctx.Workspace
    local Teams = ctx.Teams
    local UserInputService = ctx.UserInputService
    local RunService = ctx.RunService
    local LocalPlayer = ctx.LocalPlayer
    local silentSupported = ctx.silentSupported
    local AutomaHub = ctx.AutomaHub
    local tabId = ctx.tabs.Aim

    local veilEnabled, veilEnableLead, veilFovRadius, veilAimLock, veilShowFov = false, true, 150, false, true
    local veilFovFollowMouse = true
    local VEIL_TARGET_PART = "HumanoidRootPart"
    local VEIL_GRAVITY = 98.1
    local VEIL_AIM_SMOOTH = 0.35
    local VEIL_AIM_LOCK_SPEED = 165
    local veilOffsets = { { dist=40, offset=1.9 }, { dist=60, offset=1.4 }, { dist=80, offset=1.0 } }

    local function veilOffsetForDist(dist)
        local best, bestDiff = 1.0, math.huge
        for _, e in ipairs(veilOffsets) do local diff = math.abs(dist - e.dist) if diff < bestDiff then bestDiff = diff best = e.offset end end
        return best
    end

    -- state Veil (di-update loop, dibaca hook)
    local veilTargetPos, veilTargetVel, veilTargetName = nil, nil, nil
    local veilSampleName, veilSamplePos, veilSampleT = nil, nil, 0
    local veilLockedPlayer = nil
    local veilLockGraceUntil = 0

    local function veilGetFovCenter() if veilFovFollowMouse then local m = UserInputService:GetMouseLocation() return Vector2.new(m.X, m.Y) end local vp = Workspace.CurrentCamera.ViewportSize return Vector2.new(vp.X/2, vp.Y/2) end
    local function veilGetPart(plr) return plr and plr.Character and plr.Character:FindFirstChild(VEIL_TARGET_PART) end

    -- cek target masih dalam jangkauan lempar (root>=0 = reachable)
    local function veilInRange(origin, targetPos, speed, g)
        local disp = targetPos - origin
        local dy = disp.Y
        local flatX, flatZ = disp.X, disp.Z
        local dx = math.sqrt(flatX * flatX + flatZ * flatZ)
        if dx < 0.001 then return true end
        local v2 = speed * speed
        local root = v2 * v2 - g * (g * dx * dx + 2 * dy * v2)
        return root >= 0
    end

    local function veilGetTarget()
        local team = Teams:FindFirstChild("Survivors") if not team then return nil end
        local cam = Workspace.CurrentCamera local origin = cam.CFrame.Position local center = veilGetFovCenter()
        local best, bestDist = nil, veilFovRadius
        for _, plr in ipairs(team:GetPlayers()) do
            if plr ~= LocalPlayer then
                local part = veilGetPart(plr)
                if part then
                    local sp, onScreen = cam:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        if d <= bestDist and veilInRange(origin, part.Position, VEIL_AIM_LOCK_SPEED, VEIL_GRAVITY) then best, bestDist = plr, d end
                    end
                end
            end
        end
        return best
    end

    -- ballistic arc solver (math murni -> aman dipanggil di hook)
    local function veilSolveBallistic(origin, target, speed, g)
        local disp = target - origin
        local dy = disp.Y
        local flatX, flatZ = disp.X, disp.Z
        local dx = math.sqrt(flatX * flatX + flatZ * flatZ)
        if dx < 0.001 then return (disp.Magnitude > 0) and disp.Unit or nil, 0 end
        local v2 = speed * speed
        local root = v2 * v2 - g * (g * dx * dx + 2 * dy * v2)
        local tanTheta
        if root < 0 then tanTheta = 1 else local sq = math.sqrt(root) tanTheta = (v2 - sq) / (g * dx) end
        local horiz = Vector3.new(flatX / dx, 0, flatZ / dx)
        local dir = (horiz + Vector3.new(0, tanTheta, 0))
        if dir.Magnitude < 0.001 then return nil end
        dir = dir.Unit
        local cosTheta = math.sqrt(dir.X * dir.X + dir.Z * dir.Z)
        local tof = (speed * cosTheta > 0.001) and (dx / (speed * cosTheta)) or 0
        return dir, tof
    end

    local function veilSolveLead(origin, targetPos, targetVel, speed, g)
        local pred = targetPos
        local dist = (targetPos - origin).Magnitude
        local applyLead = veilEnableLead and targetVel
        local mult = applyLead and veilOffsetForDist(dist) or 0
        local dir, tof
        for _ = 1, 3 do
            dir, tof = veilSolveBallistic(origin, pred, speed, g)
            if not dir then return nil end
            if applyLead then pred = targetPos + targetVel * (tof * mult) end
        end
        return dir, tof
    end

    local veilFovCircle = nil
    if Drawing then
        veilFovCircle = Drawing.new("Circle")
        veilFovCircle.Thickness = 2 veilFovCircle.NumSides = 64 veilFovCircle.Radius = veilFovRadius
        veilFovCircle.Filled = false veilFovCircle.Visible = false veilFovCircle.Color = Color3.fromRGB(255, 255, 255)
    end

    local veilRenderConn = RunService.RenderStepped:Connect(function()
        if not (veilEnabled or veilAimLock) then
            veilTargetPos, veilTargetVel, veilTargetName = nil, nil, nil
            veilSampleName = nil veilLockedPlayer = nil
            if veilFovCircle then veilFovCircle.Visible = false end
            return
        end
        if veilFovCircle then veilFovCircle.Visible = veilShowFov veilFovCircle.Radius = veilFovRadius veilFovCircle.Position = veilGetFovCenter() end
        -- HOLD klik kiri PAS DI STANCE LEMPAR (spearmode) -> kunci target POV; ga ganti sampe lepas.
        local stanceChar = LocalPlayer.Character
        local inThrowStance = stanceChar and stanceChar:GetAttribute("spearmode") == true
        local holding = inThrowStance and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
        local target
        if holding then
            if not veilLockedPlayer then veilLockedPlayer = veilGetTarget() end
            if not (veilLockedPlayer and veilLockedPlayer.Parent and veilGetPart(veilLockedPlayer)) then veilLockedPlayer = veilGetTarget() end
            target = veilLockedPlayer
            veilLockGraceUntil = tick() + 0.3
        elseif veilLockedPlayer and tick() < veilLockGraceUntil and veilLockedPlayer.Parent and veilGetPart(veilLockedPlayer) then
            target = veilLockedPlayer
        else
            veilLockedPlayer = nil
            target = veilGetTarget()
        end
        if target then
            local part = veilGetPart(target)
            if part then
                local pos = part.Position local now = tick()
                if veilSampleName == target.Name and veilSamplePos then
                    local dt = now - veilSampleT
                    if dt >= 0.04 then
                        local instVel = (pos - veilSamplePos) / dt
                        veilTargetVel = veilTargetVel and veilTargetVel:Lerp(instVel, 0.5) or instVel
                        veilSamplePos = pos veilSampleT = now
                    end
                else veilSampleName = target.Name veilSamplePos = pos veilSampleT = now veilTargetVel = Vector3.zero end
                veilTargetPos = pos veilTargetName = target.Name
                if veilFovCircle then veilFovCircle.Color = Color3.fromRGB(255, 0, 0) end
                -- AIM LOCK: arahin kamera ke ARAH LEMPAR (ballistic arc), bukan flat ke target
                if veilAimLock and holding then
                    local cam = Workspace.CurrentCamera local origin = cam.CFrame.Position
                    local dir = veilSolveLead(origin, pos, veilTargetVel, VEIL_AIM_LOCK_SPEED, VEIL_GRAVITY)
                    if dir then local goal = CFrame.new(origin, origin + dir) cam.CFrame = cam.CFrame:Lerp(goal, VEIL_AIM_SMOOTH) end
                end
            else veilTargetPos, veilTargetVel = nil, nil veilSampleName = nil end
        else veilTargetPos, veilTargetVel = nil, nil veilSampleName = nil if veilFovCircle then veilFovCircle.Color = Color3.fromRGB(255, 255, 255) end end
    end)

    -- HOOK silent aim Veil: timpa arah Spearthrow pas FireServer
    ctx.onNamecall(function(self, method, ...)
        if method == "FireServer" and veilEnabled and veilTargetPos and self.Name == "Spearthrow" then
            local p = self.Parent
            if p and p.Name == "Veil" then
                local args = { ... }
                local dirArg, speedArg, originArg = args[1], args[2], args[3]
                if typeof(dirArg) == "Vector3" and type(speedArg) == "number" and typeof(originArg) == "Vector3" then
                    local newDir = veilSolveLead(originArg, veilTargetPos, veilTargetVel, speedArg, VEIL_GRAVITY)
                    if newDir then args[1] = newDir return true, ctx.callOriginal(self, unpack(args)) end
                end
            end
        end
        return false
    end)

    if getgenv then
        local g = getgenv()
        if g.__tomaVeilRender then pcall(function() g.__tomaVeilRender:Disconnect() end) end
        g.__tomaVeilRender = veilRenderConn
        if g.__tomaVeilFov then pcall(function() g.__tomaVeilFov:Remove() end) end
        g.__tomaVeilFov = veilFovCircle
    end

    AutomaHub:addItem(tabId, { t="toggle", name=silentSupported and "Veil Aim" or "Veil Aim (Unsupported)", default=false, onChange=function(state) if silentSupported then veilEnabled = state end end })
    AutomaHub:addItem(tabId, { t="toggle", name="Veil Aim Lock", default=false, onChange=function(state) veilAimLock = state end })
    AutomaHub:addItem(tabId, { t="toggle", name="Veil Lead Prediction", default=true, onChange=function(state) veilEnableLead = state end })
    AutomaHub:addItem(tabId, { t="toggle", name="Veil POV Circle", default=true, onChange=function(state) veilShowFov = state end })
    AutomaHub:addItem(tabId, { t="slider", name="Veil FOV Radius", min=40, max=400, default=150, onChange=function(value) if value and value >= 40 then veilFovRadius = value end end })
    for i, e in ipairs(veilOffsets) do
        AutomaHub:addItem(tabId, { t="input", name="Veil Offset Dist #"..i, default=tostring(e.dist), onChange=function(text) local num = tonumber(text) if num then e.dist = num end end })
        AutomaHub:addItem(tabId, { t="slider", name="Veil Offset #"..i, min=0, max=5, default=e.offset, onChange=function(value) if value then e.offset = value end end })
    end
end
    end)()

    local function runModule(path)
        local init = __VD_MODULES[path]
        if type(init) == "function" then
            local ok, err = pcall(init, ctx)
            if not ok then warn("[AutomaHub/VD] init error " .. path .. ": " .. tostring(err)) end
        end
    end

    runModule("Combat/AutoParry.lua")
    runModule("Combat/AutoParryDashHidden.lua")
    runModule("Combat/AutoDogdeAbbys.lua")
    runModule("Combat/SkillCheck.lua")
    runModule("Visual/Esp.lua")
    runModule("Aim/AimTwistOfFate.lua")
    runModule("Aim/AimVeil.lua")

    installNamecallHook()
    if KillerTeam then
        hookKillerAnimators()
        KillerTeam.PlayerAdded:Connect(hookKillerAnimators)
        KillerTeam.PlayerRemoved:Connect(hookKillerAnimators)
    end

    if type(AutomaHub.rebuild) == "function" then AutomaHub.rebuild() end
    print("[AutomaHub] Violence District loaded!")
end
