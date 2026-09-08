--[[
    ╔═════════════════════════════════════════════╗
    ║   PRISON LIFE HUB v6.2 | Wind UI              ║
    ║   Mobile + PC | Todos os bugs corrigidos    ║
    ╚═════════════════════════════════════════════╝
]]

--// Servicos
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- FIX: atualiza a camera quando ela troca (morte/respawn nao quebram Fly/Aimbot)
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = Workspace.CurrentCamera or Camera
end)

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

--// Wind UI (URL corrigida)
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/raw/main/dist/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "Prison Life Hub",
    Icon = "lock",
    Author = "v6.2 - Full Fix",
    Theme = "Dark",
    Size = UDim2.fromOffset(580, 440),
    KeySystem = false,
    ToggleKeybind = Enum.KeyCode.RightShift,
})

--// Config
local cfg = {
    ApplyStats = true, Speed = 16, Jump = 50,
    Fly = false, FlySpeed = 60,
    Noclip = false, InfJump = false,
    ActiveAntiStun = false,
    KillAura = false, AuraRange = 12,
    Aimbot = false, AimSmooth = 0.4, AimFOV = 120, ShowFOV = true,
    SilentAim = false, SilentChance = 100, SilentHitbox = "Head",
    NoRecoil = false, NoSpread = false, InfAmmo = false, FastFire = false, FireDelay = 0.1,
    HitboxSize = 10, HitboxTrans = 0.8,
    ESPNames = false, ESPChams = false, ESPTeamColor = true,
    ItemESP = false,
    AutoM9 = false, AutoRejoin = false,
}

local ESPFillColor = Color3.fromRGB(120, 120, 255)
local ESPOutlineColor = Color3.fromRGB(255, 255, 255)
local FOVColor = Color3.fromRGB(255, 255, 255)

--// Helpers
local function getChar() return LocalPlayer.Character end
local function getRoot()
    local c = getChar()
    return c and c:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    local c = getChar()
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- ============================================================
--  ITENS (declare ANTES das conexoes — fix do "call nil global")
-- ============================================================
local giveItemSafe -- forward declaration
do
    local function tryPickup(itemName)
        local prisonItems = Workspace:FindFirstChild("Prison_ITEMS")
        if not prisonItems then return false end
        -- busca recursiva em qualquer pasta (giver, single, etc.)
        for _, item in ipairs(prisonItems:GetDescendants()) do
            if item.Name == itemName then
                local pickup = item:FindFirstChild("ITEMPICKUP")
                if pickup then
                    -- ItemHandler eh RemoteFunction: precisa InvokeServer
                    local ok = pcall(function()
                        Workspace.Remote.ItemHandler:InvokeServer(pickup)
                    end)
                    return ok
                end
            end
        end
        return false
    end

    giveItemSafe = function(name)
        local ok, err = pcall(function()
            if not tryPickup(name) then
                error("item nao encontrado no mapa")
            end
        end)
        WindUI:Notify({
            Title = "Itens",
            Content = ok and ("Pegando: " .. name) or ("Falha ao pegar " .. name .. " (item nao existe ou foi removido)"),
            Duration = 3,
            Type = ok and "Info" or "Warning"
        })
    end
end

-- ============================================================
--                     STATUS (speed/jump)
-- ============================================================
task.spawn(function()
    while true do
        task.wait(0.25)
        if cfg.ApplyStats then
            local hum = getHum()
            if hum and hum.Health > 0 then
                hum.WalkSpeed = cfg.Speed
                pcall(function() hum.UseJumpPower = true end)
                hum.JumpPower = cfg.Jump
            end
        end
    end
end)

-- ============================================================
--                       FLY
-- ============================================================
local flyConn, flyBV, flyBG
local function stopFly()
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    cfg.Fly = false
end
local function startFly()
    stopFly()
    local root = getRoot()
    if not root then return end
    cfg.Fly = true
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = root
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
    flyBG.P = 20000
    flyBG.Parent = root
    flyConn = RunService.RenderStepped:Connect(function()
        if not flyBV or not flyBV.Parent then return end
        local root = getRoot()
        local hum = getHum()
        if not root then return end
        if hum and hum.Health <= 0 then stopFly(); return end

        local vel = Vector3.zero
        if isMobile then
            if hum then vel = hum.MoveDirection * cfg.FlySpeed end
        else
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move += Vector3.new(0, 0, -1) end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move += Vector3.new(0, 0, 1) end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move += Vector3.new(-1, 0, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move += Vector3.new(1, 0, 0) end
            if move.Magnitude > 0 then
                vel = Camera.CFrame:VectorToWorldSpace(move).Unit * cfg.FlySpeed
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.E) then vel += Vector3.new(0, cfg.FlySpeed, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.Q) then vel -= Vector3.new(0, cfg.FlySpeed, 0) end
        end
        flyBV.Velocity = vel
        if flyBG and flyBG.Parent then
            flyBG.CFrame = CFrame.lookAt(root.Position, root.Position + Camera.CFrame.LookVector)
        end
    end)
end

-- ============================================================
--                       NOCLIP
-- ============================================================
local noclipConn
local function stopNoclip()
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
    cfg.Noclip = false
end
local function startNoclip()
    stopNoclip()
    cfg.Noclip = true
    noclipConn = RunService.Stepped:Connect(function()
        local char = getChar()
        local hum = getHum()
        if not char then return end
        if hum and hum.Health <= 0 then stopNoclip(); return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end

-- Keybinds SO no PC
if not isMobile then
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.V then
            if cfg.Fly then stopFly() else startFly() end
        elseif input.KeyCode == Enum.KeyCode.N then
            if cfg.Noclip then stopNoclip() else startNoclip() end
        end
    end)
end

-- Pulo infinito
UserInputService.JumpRequest:Connect(function()
    if cfg.InfJump then
        local hum = getHum()
        if hum and hum.Health > 0 then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- FIX: limpa fly/noclip ao respawnar (agora giveItemSafe existe de verdade)
LocalPlayer.CharacterAdded:Connect(function()
    stopFly()
    stopNoclip()
    if cfg.AutoM9 then
        task.wait(3)
        giveItemSafe("M9")
    end
end)

-- ============================================================
--               ALVO DO SILENT AIM (1x por frame — fix de lag)
-- ============================================================
local SilentTarget = nil

local function isValidTarget(plr)
    if plr == LocalPlayer or not plr.Character then return false end
    if plr.Team ~= LocalPlayer.Team then
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health > 0
    end
    return false
end

local function getMousePos()
    if isMobile then
        return Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    end
    return UserInputService:GetMouseLocation()
end

local function computeSilentTarget()
    local target, best = nil, math.huge
    local mousePos = getMousePos()
    pcall(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if isValidTarget(plr) then
                local part = plr.Character:FindFirstChild(cfg.SilentHitbox)
                    or plr.Character:FindFirstChild("HumanoidRootPart")
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < best then
                            best = dist
                            target = plr
                        end
                    end
                end
            end
        end
    end)
    return target
end

RunService.RenderStepped:Connect(function()
    if cfg.SilentAim then
        SilentTarget = computeSilentTarget()
        if SilentTarget and math.random(1, 100) > cfg.SilentChance then
            SilentTarget = nil
        end
    else
        SilentTarget = nil
    end
end)

-- Silent Aim: so redireciona o ray ja calculado (sem loop dentro do hook)
if hookmetamethod and getnamecallmethod and newcclosure then
    local OldNamecall
    OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        if cfg.SilentAim and SilentTarget then
            local method = getnamecallmethod()
            if method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList" then
                local part = SilentTarget.Character
                    and (SilentTarget.Character:FindFirstChild(cfg.SilentHitbox)
                        or SilentTarget.Character:FindFirstChild("HumanoidRootPart"))
                if part then
                    local args = { ... }
                    local ray = args[1]
                    if typeof(ray) == "Ray" then
                        args[1] = Ray.new(ray.Origin, part.Position - ray.Origin)
                        return OldNamecall(self, table.unpack(args))
                    end
                end
            end
        end
        return OldNamecall(self, ...)
    end))
end

-- ============================================================
--                  LOOPS DE COMBATE
-- ============================================================
local lastAura = 0

RunService.Heartbeat:Connect(function()
    -- ANTI-STUN (PlatformStand + estados de ragdoll — fix taser por constraint)
    if cfg.ActiveAntiStun then
        local hum = getHum()
        if hum and hum.Health > 0 then
            if hum.PlatformStand then
                hum.PlatformStand = false
                hum:ChangeState(Enum.HumanoidStateType.GettingUp)
            end
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
                hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
            end)
        end
    end

    -- KILL AURA
    if cfg.KillAura and (os.clock() - lastAura) > 0.15 then
        lastAura = os.clock()
        local char = getChar()
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChildOfClass("Tool")
        local hum = getHum()
        if root and tool and hum and hum.Health > 0 then
            local target = nil
            local best = cfg.AuraRange + 1
            for _, plr in ipairs(Players:GetPlayers()) do
                if isValidTarget(plr) and plr.Character:FindFirstChild("HumanoidRootPart") then
                    local d = (root.Position - plr.Character.HumanoidRootPart.Position).Magnitude
                    if d <= cfg.AuraRange and d < best then
                        best = d
                        target = plr
                    end
                end
            end
            if target then
                root.CFrame = CFrame.lookAt(root.Position, target.Character.HumanoidRootPart.Position)
                pcall(function() tool:Activate() end)
            end
        end
    end

    -- AIMBOT
    if cfg.Aimbot then
        local target = nil
        local best = cfg.AimFOV
        local mousePos = getMousePos()
        pcall(function()
            for _, plr in ipairs(Players:GetPlayers()) do
                if isValidTarget(plr) then
                    local head = plr.Character:FindFirstChild("Head")
                    if head then
                        local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                        if onScreen then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            if dist <= cfg.AimFOV and dist < best then
                                best = dist
                                target = plr
                            end
                        end
                    end
                end
            end
        end)
        if target then
            local head = target.Character:FindFirstChild("Head")
            if head then
                Camera.CFrame = Camera.CFrame:Lerp(
                    CFrame.new(Camera.CFrame.Position, head.Position),
                    cfg.AimSmooth
                )
            end
        end
    end
end)

-- ============================================================
--                 HITBOX EXPANDER
-- ============================================================
local hbOriginal = {}
local hitboxConn = nil
local function stopHitbox()
    if hitboxConn then hitboxConn:Disconnect(); hitboxConn = nil end
    for plr, data in pairs(hbOriginal) do
        pcall(function()
            if plr and plr.Character then
                local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.Size = data.size
                    hrp.Transparency = data.trans
                end
            end
        end)
    end
    table.clear(hbOriginal)
end
local function startHitbox()
    if hitboxConn then return end
    hitboxConn = RunService.Heartbeat:Connect(function()
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                local hrp = plr.Character.HumanoidRootPart
                if not hbOriginal[plr] then
                    hbOriginal[plr] = { size = hrp.Size, trans = hrp.Transparency }
                end
                hrp.Size = Vector3.new(cfg.HitboxSize, cfg.HitboxSize, cfg.HitboxSize)
                hrp.Transparency = cfg.HitboxTrans
            end
        end
    end)
end

-- ============================================================
--                     GUN MODS
-- ============================================================
-- FIX: usa o GunStates (module real do PL) + scan de NumberValues como fallback
local function applyGunMods()
    if not (cfg.NoRecoil or cfg.NoSpread or cfg.InfAmmo or cfg.FastFire) then return end
    local char = getChar()
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then return end

    -- metodo principal: module GunStates dentro da arma
    local gs = tool:FindFirstChild("GunStates")
    if gs then
        local ok, module = pcall(require, gs)
        if ok and type(module) == "table" then
            if cfg.InfAmmo then
                if module.MaxAmmo then module.MaxAmmo = math.huge end
                if module.CurrentAmmo then module.CurrentAmmo = math.huge end
                if module.StoredAmmo then module.StoredAmmo = math.huge end
            end
            if cfg.NoSpread and module.Spread then module.Spread = 0 end
            if cfg.NoRecoil and module.Recoil then module.Recoil = 0 end
            if cfg.FastFire and module.FireRate then module.FireRate = cfg.FireDelay end
            if cfg.FastFire and module.ReloadTime then module.ReloadTime = 0.0001 end
        end
    end

    -- fallback: NumberValues com nomes conhecidos
    for _, obj in ipairs(tool:GetDescendants()) do
        pcall(function()
            if obj:IsA("NumberValue") or obj:IsA("IntValue") then
                if cfg.NoRecoil and (obj.Name == "Recoil" or obj.Name == "RecoilAmount") then
                    obj.Value = 0
                end
                if cfg.NoSpread and (obj.Name == "Spread" or obj.Name == "MaxSpread") then
                    obj.Value = 0
                end
                if cfg.NoSpread and obj.Name == "Accuracy" then
                    obj.Value = 100
                end
                if cfg.FastFire and (obj.Name == "FireRate" or obj.Name == "RateOfFire"
                    or obj.Name == "Cooldown" or obj.Name == "FireDelay") then
                    obj.Value = cfg.FireDelay
                end
                if cfg.InfAmmo and (obj.Name == "Ammo" or obj.Name == "CurrentAmmo" or obj.Name == "Magazine") then
                    if obj.Value < 3 then
                        obj.Value = obj.MaxValue or 20
                    end
                end
            end
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(0.15)
        applyGunMods()
    end
end)

-- aplica mods automaticamente ao equipar uma arma
LocalPlayer.CharacterAdded:Connect(function(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            task.wait(0.3)
            applyGunMods()
        end
    end)
end)

-- ============================================================
--                  ESP DE JOGADORES
-- ============================================================
local espObjects = {}
local function createESP(plr)
    if plr == LocalPlayer then return end
    local holder = Instance.new("BillboardGui")
    holder.Size = UDim2.fromOffset(200, 40)
    holder.StudsOffset = Vector3.new(0, 3, 0)
    holder.AlwaysOnTop = true
    holder.Enabled = false
    local label = Instance.new("TextLabel")
    label.Parent = holder
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.TextStrokeTransparency = 0.5
    label.TextColor3 = Color3.new(1, 1, 1)
    local highlight = Instance.new("Highlight")
    highlight.Enabled = false
    local function attach(char)
        local head = char:FindFirstChild("Head")
        holder.Parent = head or char:FindFirstChild("HumanoidRootPart")
        highlight.Adornee = char
        highlight.Parent = char
    end
    if plr.Character then pcall(attach, plr.Character) end
    plr.CharacterAdded:Connect(function(c)
        task.wait(1)
        pcall(attach, c)
    end)
    espObjects[plr] = { holder = holder, label = label, highlight = highlight }
end

RunService.RenderStepped:Connect(function()
    local myRoot = getRoot()
    for plr, obj in pairs(espObjects) do
        local char = plr and plr.Parent and plr.Character
        if not char then continue end
        obj.holder.Enabled = cfg.ESPNames
        obj.highlight.Enabled = cfg.ESPChams
        if cfg.ESPNames then
            local dist = myRoot and char:FindFirstChild("HumanoidRootPart")
                and math.floor((myRoot.Position - char.HumanoidRootPart.Position).Magnitude) or "?"
            local teamName = plr.Team and plr.Team.Name or "Sem time"
            obj.label.Text = plr.Name .. " | " .. teamName .. " | " .. tostring(dist) .. "m"
            obj.label.TextColor3 = cfg.ESPTeamColor and plr.TeamColor.Color or Color3.new(1, 1, 1)
        end
        if cfg.ESPChams then
            obj.highlight.FillColor = cfg.ESPTeamColor and plr.TeamColor.Color or ESPFillColor
            obj.highlight.OutlineColor = ESPOutlineColor
            obj.highlight.FillTransparency = 0.6
            obj.highlight.OutlineTransparency = 0
        end
    end
end)

for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(function(p) task.wait(2) createESP(p) end)
Players.PlayerRemoving:Connect(function(p)
    if espObjects[p] then
        pcall(function() espObjects[p].holder:Destroy() end)
        pcall(function() espObjects[p].highlight:Destroy() end)
        espObjects[p] = nil
    end
end)

-- FOV Circle: SO no PC e so se a Drawing API existir
local fovCircle = nil
if not isMobile and Drawing then
    pcall(function()
        fovCircle = Drawing.new("Circle")
        fovCircle.Thickness = 1
        fovCircle.Filled = false
        fovCircle.NumSides = 60
        fovCircle.Color = FOVColor
        fovCircle.Visible = false
    end)
end
RunService.RenderStepped:Connect(function()
    if fovCircle then
        local ok = pcall(function()
            fovCircle.Visible = cfg.ShowFOV and cfg.Aimbot
            fovCircle.Radius = cfg.AimFOV
            if not isMobile then
                fovCircle.Position = UserInputService:GetMouseLocation()
            end
        end)
        if not ok then fovCircle = nil end
    end
end)

-- ============================================================
--       ESP DE ITENS (fix: cria 1x e so limpa os sumidos)
-- ============================================================
local itemEspObjects = {}
RunService.RenderStepped:Connect(function()
    if cfg.ItemESP then
        for _, obj in ipairs(Workspace:GetChildren()) do
            if obj:IsA("Tool") and obj.Parent == Workspace and not itemEspObjects[obj] then
                local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                if handle then
                    local gui = Instance.new("BillboardGui")
                    gui.Size = UDim2.fromOffset(150, 25)
                    gui.StudsOffset = Vector3.new(0, 2, 0)
                    gui.AlwaysOnTop = true
                    gui.Parent = handle
                    local lbl = Instance.new("TextLabel")
                    lbl.Parent = gui
                    lbl.BackgroundTransparency = 1
                    lbl.Size = UDim2.fromScale(1, 1)
                    lbl.Font = Enum.Font.GothamBold
                    lbl.TextSize = 13
                    lbl.TextStrokeTransparency = 0.5
                    lbl.TextColor3 = Color3.fromRGB(255, 170, 0)
                    lbl.Text = obj.Name
                    itemEspObjects[obj] = gui
                end
            end
        end
    end
    -- limpa ESP de itens que sumiram
    for obj, gui in pairs(itemEspObjects) do
        if not cfg.ItemESP or obj.Parent ~= Workspace then
            pcall(function() gui:Destroy() end)
            itemEspObjects[obj] = nil
        end
    end
end)

-- ============================================================
--             TELEPORTE SEGURO
-- ============================================================
local lastTP = 0
local function safeTeleport(cf)
    if not cf then return false end
    local hrp = getRoot()
    if not hrp then
        WindUI:Notify({ Title = "Teleporte", Content = "Personagem nao encontrado! Espere o respawn.", Duration = 3, Type = "Warning" })
        return false
    end
    if os.clock() - lastTP < 0.5 then return false end
    lastTP = os.clock()

    local wasFlying = cfg.Fly
    if wasFlying then stopFly() end

    hrp.CFrame = cf
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.AssemblyAngularVelocity = Vector3.zero

    local holdConn
    holdConn = RunService.Heartbeat:Connect(function()
        if hrp.Parent then
            hrp.AssemblyLinearVelocity = Vector3.zero
        end
    end)
    task.delay(0.25, function()
        if holdConn then holdConn:Disconnect() end
        if wasFlying and not cfg.Fly then
            local root = getRoot()
            if root then root.CFrame = cf end
            startFly()
        end
    end)
    return true
end

-- ============================================================
--                    MISC UTILITIES
-- ============================================================
pcall(function()
    game:GetService("CoreGui").ChildAdded:Connect(function(child)
        if child.Name == "RobloxPromptGui" then
            if cfg.AutoRejoin then
                task.wait(1)
                TeleportService:Teleport(game.PlaceId)
            end
        end
    end)
end)

-- Anti AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

-- Server Hop
local function serverHop()
    local requestFn = (syn and syn.request) or (http and http.request) or request or http_request
    if not requestFn then
        WindUI:Notify({ Title = "Erro", Content = "Seu executor nao suporta HTTP.", Duration = 4, Type = "Error" })
        return
    end
    local ok, body = pcall(function()
        return requestFn({ Url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100" })
    end)
    if not ok then
        WindUI:Notify({ Title = "Erro", Content = "Falha ao buscar servidores.", Duration = 4, Type = "Error" })
        return
    end
    local ok2, json = pcall(function() return HttpService:JSONDecode(body.Body) end)
    if ok2 and json and json.data then
        for _, server in ipairs(json.data) do
            if server.playing < server.maxPlayers and server.id ~= game.JobId then
                TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, LocalPlayer)
                break
            end
        end
    end
end

-- FPS Booster
local function fpsBoost()
    local Lighting = game:GetService("Lighting")
    for _, v in ipairs(Workspace:GetDescendants()) do
        pcall(function()
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Sparkles")
                or v:IsA("Smoke") or v:IsA("Fire") then
                v.Enabled = false
            elseif v:IsA("PointLight") or v:IsA("SurfaceLight") or v:IsA("SpotLight") then
                v.Enabled = false
            end
        end)
    end
    pcall(function() Lighting.GlobalShadows = false end)
    pcall(function() Lighting.FogEnd = 1e5 end)
    pcall(function() Workspace.Terrain.WaterWaveSize = 0 end)
    pcall(function() Workspace.Terrain.WaterWaveSpeed = 0 end)
    WindUI:Notify({ Title = "FPS Booster", Content = "Graficos otimizados!", Duration = 4, Type = "Success" })
end

-- Team Switcher (fix: usa TeamEvent do PL)
local function setTeam(teamName)
    local ok = false
    if teamName == "Inmates" then
        ok = pcall(function()
            Workspace.Remote.TeamEvent:FireServer("Bright orange")
            Workspace.Remote.loadchar:InvokeServer(LocalPlayer.Name)
        end)
    elseif teamName == "Guards" then
        ok = pcall(function()
            Workspace.Remote.TeamEvent:FireServer("Bright blue")
            Workspace.Remote.loadchar:InvokeServer(LocalPlayer.Name)
        end)
    elseif teamName == "Criminals" then
        -- nao existe evento: teleporta pra base criminosa (ficar la vira criminoso)
        local baseSpot = Workspace:FindFirstChild("Criminals Spawn", true)
        if baseSpot then
            local part = baseSpot:IsA("BasePart") and baseSpot or baseSpot:FindFirstChildWhichIsA("BasePart", true)
            if part then
                safeTeleport(part.CFrame + Vector3.new(0, 5, 0))
                ok = true
            end
        end
        if not ok then
            ok = safeTeleport(CFrame.new(-423, 46, -162))
        end
    end
    WindUI:Notify({
        Title = "Team Switcher",
        Content = ok and ("Trocando para: " .. teamName) or "Falha ao trocar de time.",
        Duration = 5,
        Type = ok and "Success" or "Warning"
    })
end

-- ============================================================
--                      INTERFACE
-- ============================================================
local TabPlayer = Window:Tab({ Title = "Jogador", Icon = "user" })
local TabCombat = Window:Tab({ Title = "Combate", Icon = "swords" })
local TabItens = Window:Tab({ Title = "Itens", Icon = "package" })
local TabTP = Window:Tab({ Title = "Teleportes", Icon = "map" })
local TabVisual = Window:Tab({ Title = "Visual", Icon = "eye" })
local TabMisc = Window:Tab({ Title = "Misc", Icon = "settings" })

--// ---------- JOGADOR ----------
local S1 = TabPlayer:Section({ Title = "Movimento" })
S1:Toggle({
    Title = "Fly",
    Desc = isMobile and "Mova com o direcional (thumbstick)" or "Mova com WASD, E/Q sobe e desce | tecla V",
    Value = false,
    Callback = function(v)
        if v then startFly() else stopFly() end
    end
})
S1:Slider({ Title = "Velocidade do Fly", Value = { Default = 60, Min = 20, Max = 300 }, Step = 5, Callback = function(v) cfg.FlySpeed = v end })
S1:Toggle({
    Title = "Noclip",
    Desc = "Atravessa paredes" .. (isMobile and "" or " | tecla N"),
    Value = false,
    Callback = function(v)
        if v then startNoclip() else stopNoclip() end
    end
})

local S1b = TabPlayer:Section({ Title = "Status" })
S1b:Toggle({ Title = "Aplicar Velocidade/Pulo", Value = true, Callback = function(v) cfg.ApplyStats = v end })
S1b:Slider({ Title = "Velocidade", Value = { Default = 16, Min = 16, Max = 200 }, Step = 1, Callback = function(v) cfg.Speed = v end })
S1b:Slider({ Title = "Forca do Pulo", Value = { Default = 50, Min = 50, Max = 300 }, Step = 10, Callback = function(v) cfg.Jump = v end })
S1b:Toggle({ Title = "Pulo Infinito", Value = false, Callback = function(v) cfg.InfJump = v end })

local S2 = TabPlayer:Section({ Title = "Utilidades" })
S2:Toggle({ Title = "Anti-Stun / Anti-Taser", Desc = "Anula ragdoll e stun do taser", Value = false, Callback = function(v) cfg.ActiveAntiStun = v end })

--// ---------- COMBATE ----------
local S3 = TabCombat:Section({ Title = "Kill Aura" })
S3:Toggle({ Title = "Kill Aura", Desc = "Segure uma faca/arma e ataque automatico", Value = false, Callback = function(v) cfg.KillAura = v end })
S3:Slider({ Title = "Alcance (studs)", Value = { Default = 12, Min = 5, Max = 40 }, Step = 1, Callback = function(v) cfg.AuraRange = v end })

local S4 = TabCombat:Section({ Title = "Aimbot" })
S4:Toggle({ Title = "Aimbot", Value = false, Callback = function(v) cfg.Aimbot = v end })
S4:Slider({ Title = "FOV", Value = { Default = 120, Min = 20, Max = 600 }, Step = 10, Callback = function(v) cfg.AimFOV = v end })
S4:Slider({ Title = "Suavidade", Value = { Default = 0.4, Min = 0.05, Max = 1 }, Step = 0.05, Callback = function(v) cfg.AimSmooth = v end })
S4:Toggle({ Title = "Mostrar circulo FOV", Desc = "So no PC", Value = true, Callback = function(v) cfg.ShowFOV = v end })
-- FIX: Colorpicker (P minusculo)
S4:Colorpicker({ Title = "Cor do FOV", Default = Color3.fromRGB(255, 255, 255), Callback = function(c)
    FOVColor = c
    if fovCircle then fovCircle.Color = c end
end })

local S13 = TabCombat:Section({ Title = "Silent Aim" })
S13:Toggle({ Title = "Silent Aim", Desc = "Tiros vao pro alvo mesmo errando", Value = false, Callback = function(v) cfg.SilentAim = v end })
S13:Slider({ Title = "Chance de Acerto (%)", Value = { Default = 100, Min = 10, Max = 100 }, Step = 5, Callback = function(v) cfg.SilentChance = v end })
-- FIX: Value em vez de Selected
S13:Dropdown({ Title = "Hitbox Alvo", Values = { "Head", "HumanoidRootPart", "Torso" }, Value = "Head", Callback = function(v) cfg.SilentHitbox = v end })

local S5 = TabCombat:Section({ Title = "Hitbox" })
S5:Toggle({ Title = "Hitbox Expander", Value = false, Callback = function(v)
    if v then startHitbox() else stopHitbox() end
end })
S5:Slider({ Title = "Tamanho da Hitbox", Value = { Default = 10, Min = 3, Max = 30 }, Step = 1, Callback = function(v) cfg.HitboxSize = v end })
S5:Slider({ Title = "Transparencia", Value = { Default = 0.8, Min = 0, Max = 1 }, Step = 0.1, Callback = function(v) cfg.HitboxTrans = v end })

--// ---------- ITENS ----------
local S6 = TabItens:Section({ Title = "Pegar Armas" })
S6:Button({ Title = "M9", Callback = function() giveItemSafe("M9") end })
S6:Button({ Title = "AK-47", Callback = function() giveItemSafe("AK-47") end })
S6:Button({ Title = "M4A1", Callback = function() giveItemSafe("M4A1") end })
S6:Button({ Title = "Remington 870", Callback = function() giveItemSafe("Remington 870") end })

local S7 = TabItens:Section({ Title = "Outros" })
S7:Button({ Title = "Crude Knife (faca)", Callback = function() giveItemSafe("Crude Knife") end })
S7:Button({ Title = "Martelo", Callback = function() giveItemSafe("Hammer") end })
S7:Paragraph({ Title = "Dica", Desc = "Keycard nao tem giver — pegue de guarda abatido." })
S7:Toggle({ Title = "Auto M9 ao respawnar", Value = false, Callback = function(v) cfg.AutoM9 = v end })

local S14 = TabItens:Section({ Title = "Gun Mods" })
S14:Toggle({ Title = "No Recoil", Value = false, Callback = function(v) cfg.NoRecoil = v end })
S14:Toggle({ Title = "Sem Spread", Value = false, Callback = function(v) cfg.NoSpread = v end })
S14:Toggle({ Title = "Municao Infinita", Value = false, Callback = function(v) cfg.InfAmmo = v end })
S14:Toggle({ Title = "Fast Fire", Value = false, Callback = function(v) cfg.FastFire = v end })
S14:Slider({ Title = "Delay do Fast Fire (s)", Value = { Default = 0.1, Min = 0.05, Max = 0.5 }, Step = 0.05, Callback = function(v) cfg.FireDelay = v end })

--// ---------- TELEPORTES ----------
local S8 = TabTP:Section({ Title = "Locais" })
local teleportes = {
    ["Celas"] = Vector3.new(-811, 98, -31),
    ["Patio"] = Vector3.new(-925, 98, 26),
    ["Cafeteria"] = Vector3.new(-845, 97, 36),
    ["Cozinha"] = Vector3.new(-845, 97, 68),
    ["Ginasio"] = Vector3.new(-892, 98, -139),
    ["Corredor Principal"] = Vector3.new(-845, 97, -90),
    ["Estacao de Policia"] = Vector3.new(-943, 97, 55),
    ["Sala de Armas"] = Vector3.new(-945, 97, 30),
    ["Torre de Guarda"] = Vector3.new(-908, 130, 90),
    ["Telhado"] = Vector3.new(-850, 125, 0),
    ["Esgoto"] = Vector3.new(-810, 62, -150),
    ["Base Criminosa"] = Vector3.new(-423, 46, -162),
}
local tpKeys = {}
for k in pairs(teleportes) do table.insert(tpKeys, k) end
table.sort(tpKeys)
local selectedTP = tpKeys[1]
S8:Dropdown({ Title = "Local", Values = tpKeys, Value = tpKeys[1], Callback = function(v) selectedTP = v end })
S8:Button({ Title = "Teleportar", Callback = function()
    if selectedTP and teleportes[selectedTP] then
        if safeTeleport(CFrame.new(teleportes[selectedTP])) then
            WindUI:Notify({ Title = "Teleporte", Content = "Voce foi para: " .. selectedTP, Duration = 3, Type = "Info" })
        end
    end
end })

local S8b = TabTP:Section({ Title = "Meus Waypoints" })
local savedWaypoints = {}
local wpKeys = {}
local selectedWP = nil
local wpDropdown
local function rebuildWaypoints()
    wpKeys = {}
    for k in pairs(savedWaypoints) do table.insert(wpKeys, k) end
    table.sort(wpKeys)
    pcall(function()
        if wpDropdown and wpDropdown.Refresh then wpDropdown:Refresh(wpKeys, wpKeys[1]) end
    end)
end
S8b:Button({ Title = "Salvar Posicao Atual", Callback = function()
    local hrp = getRoot()
    if not hrp then return end
    local name = "Ponto " .. tostring(os.time() % 10000)
    savedWaypoints[name] = hrp.Position
    rebuildWaypoints()
    WindUI:Notify({ Title = "Waypoint", Content = "Salvo: " .. name, Duration = 3, Type = "Success" })
end })
wpDropdown = S8b:Dropdown({ Title = "Waypoints Salvos", Values = { "Nenhum" }, Value = "Nenhum", Callback = function(v)
    if v ~= "Nenhum" and savedWaypoints[v] then selectedWP = v end
end })
S8b:Button({ Title = "Ir para Waypoint", Callback = function()
    if selectedWP and savedWaypoints[selectedWP] then
        if safeTeleport(CFrame.new(savedWaypoints[selectedWP])) then
            WindUI:Notify({ Title = "Teleporte", Content = "Voce foi para: " .. selectedWP, Duration = 3, Type = "Info" })
        end
    else
        WindUI:Notify({ Title = "Teleporte", Content = "Nenhum waypoint selecionado!", Duration = 3, Type = "Warning" })
    end
end })

local S9 = TabTP:Section({ Title = "Teleportar para Jogador" })
local selectedPlayer = nil
local function getPlayerNames()
    local names = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(names, p.Name) end
    end
    return names
end
local playerDD
playerDD = S9:Dropdown({ Title = "Jogador", Values = getPlayerNames(), Callback = function(v) selectedPlayer = v end })
S9:Button({ Title = "Atualizar Lista", Callback = function()
    pcall(function()
        if playerDD and playerDD.Refresh then playerDD:Refresh(getPlayerNames()) end
    end)
    WindUI:Notify({ Title = "Lista", Content = "Lista atualizada!", Duration = 3, Type = "Info" })
end })
S9:Button({ Title = "Ir ate o Jogador", Desc = "Aparece atras dele", Callback = function()
    if not selectedPlayer then
        WindUI:Notify({ Title = "Teleporte", Content = "Selecione um jogador primeiro!", Duration = 3, Type = "Warning" })
        return
    end
    local plr = Players:FindFirstChild(selectedPlayer)
    if plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
        local targetHRP = plr.Character.HumanoidRootPart
        local behindPos = targetHRP.Position - (targetHRP.CFrame.LookVector * 4) + Vector3.new(0, 3, 0)
        if safeTeleport(CFrame.lookAt(behindPos, targetHRP.Position)) then
            WindUI:Notify({ Title = "Teleporte", Content = "Voce foi ate: " .. selectedPlayer, Duration = 3, Type = "Info" })
        end
    else
        WindUI:Notify({ Title = "Teleporte", Content = "Jogador invalido ou sem personagem!", Duration = 3, Type = "Warning" })
    end
end })

--// ---------- VISUAL ----------
local S10 = TabVisual:Section({ Title = "ESP de Jogadores" })
S10:Toggle({ Title = "Nomes + Time + Distancia", Value = false, Callback = function(v) cfg.ESPNames = v end })
S10:Toggle({ Title = "Chams (Highlight)", Value = false, Callback = function(v) cfg.ESPChams = v end })
S10:Toggle({ Title = "Cores por Time", Value = true, Callback = function(v) cfg.ESPTeamColor = v end })
S10:Colorpicker({ Title = "Cor do Fill", Default = Color3.fromRGB(120, 120, 255), Callback = function(c)
    ESPFillColor = c
    cfg.ESPTeamColor = false
end })
S10:Colorpicker({ Title = "Cor do Outline", Default = Color3.fromRGB(255, 255, 255), Callback = function(c)
    ESPOutlineColor = c
end })

local S15 = TabVisual:Section({ Title = "ESP de Itens" })
S15:Toggle({ Title = "Armas/Facas no chao", Desc = "Destaca itens largados no mapa", Value = false, Callback = function(v) cfg.ItemESP = v end })

--// ---------- MISC ----------
local S11 = TabMisc:Section({ Title = "Performance" })
S11:Button({ Title = "FPS Booster", Callback = fpsBoost })

local S12 = TabMisc:Section({ Title = "Utilidades" })
S12:Toggle({ Title = "Auto Rejoin", Value = false, Callback = function(v) cfg.AutoRejoin = v end })
S12:Button({ Title = "Rejoin Servidor", Callback = function() TeleportService:Teleport(game.PlaceId) end })
S12:Button({ Title = "Server Hop", Callback = serverHop })

local S16 = TabMisc:Section({ Title = "Team Switcher" })
S16:Paragraph({ Title = "Aviso", Desc = "Pode exigir respawn para aplicar" })
S16:Button({ Title = "Virar Preso (Inmate)", Callback = function() setTeam("Inmates") end })
S16:Button({ Title = "Virar Policia (Guard)", Callback = function() setTeam("Guards") end })
S16:Button({ Title = "Virar Criminoso", Callback = function() setTeam("Criminals") end })

--// Inicia
Window:SelectTab(TabPlayer)
WindUI:Notify({
    Title = "Prison Life Hub",
    Content = "v6.2 carregado! " .. (isMobile
        and "Use o botao da WindUI (bolinha) para abrir/fechar o menu."
        or "V = Fly | N = Noclip | RightShift = Menu"),
    Duration = 6,
    Type = "Success"
})
