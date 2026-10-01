local Players             = game:GetService("Players")
local RunService          = game:GetService("RunService")
local UserInputService    = game:GetService("UserInputService")
local TweenService        = game:GetService("TweenService")
local Lighting            = game:GetService("Lighting")
local VirtualInputManager = game:GetService("VirtualInputManager")
local GuiService          = game:GetService("GuiService")
local VirtualUser         = game:GetService("VirtualUser")
local TeleportService     = game:GetService("TeleportService")
local HttpService         = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

if _G.AbaddonGui then pcall(function() _G.AbaddonGui:Destroy() end) end
if _G.ASC_MainLoop then pcall(function() _G.ASC_MainLoop:Disconnect() end) end
_G.ASC_MainLoop = nil

local KEY_TOGGLE  = Enum.KeyCode.RightShift
local SPIN_SPEED  = 720
local CONFIG_FILE = "Abaddon_config.json"
local SCRIPT_START = tick()

-- ==================== PERSISTENT PARENT ====================
local function getPersistentParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    if get_hidden_gui then
        local ok, hui = pcall(get_hidden_gui)
        if ok and hui then return hui end
    end
    local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if ok and coreGui then return coreGui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

-- Строгая, приглушённая палитра
local C = {
    Bg          = Color3.fromRGB(6,   6,   7),
    Panel       = Color3.fromRGB(11,  11,  12),
    PanelSoft   = Color3.fromRGB(16,  16,  18),
    PanelDark   = Color3.fromRGB(8,   8,   9),
    Border      = Color3.fromRGB(34,  34,  38),
    BorderSoft  = Color3.fromRGB(24,  24,  27),
    Text        = Color3.fromRGB(220, 220, 224),
    TextDim     = Color3.fromRGB(120, 120, 126),
    TextFaint   = Color3.fromRGB(72,  72,  78),
    Accent      = Color3.fromRGB(200, 200, 205),
    ToggleOff   = Color3.fromRGB(28,  28,  32),
    Green       = Color3.fromRGB(140, 195, 155),
    Yellow      = Color3.fromRGB(200, 165, 95),
    Red         = Color3.fromRGB(200, 85,  85),
    Survivor    = Color3.fromRGB(140, 180, 220),
    Killer      = Color3.fromRGB(200, 85,  85),
    Generator   = Color3.fromRGB(140, 200, 155),
}

local State = {
    Open           = false,
    ESP_Survivors  = false,
    ESP_Killer     = false,
    ESP_Generators = false,
    Fullbright     = false,
    NoShadows      = false,
    NoTextures     = false,
    AutoSkillCheck = false,
    AntiAFK        = false,
    WalkSpeed      = 16,
    HipHeight      = 0,    -- ФИКС: было 2, из-за этого персонаж висел в воздухе
    Noclip         = false,
    TPTool         = false,
    BackWalk       = false,
    Spin           = false,
    Fly            = false,
    FlySpeed       = 60,
    AntiFling      = false,
    CameraFOV      = 70,
    ClockTime      = 14,
    Hoodwink       = false,
    HideUsername   = false,
}

local DEFAULT_STATE = {}
for k, v in pairs(State) do DEFAULT_STATE[k] = v end

local widgetRegistry = {}

local VERDANA
pcall(function() VERDANA = Font.fromName("Verdana") end)
local function applyFont(obj)
    if VERDANA then obj.FontFace = VERDANA
    else obj.Font = Enum.Font.SourceSans end
    obj.TextStrokeTransparency = 0.6
    obj.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
end

local Blur = Lighting:FindFirstChild("AbaddonBlur") or Instance.new("BlurEffect")
Blur.Name = "AbaddonBlur"
Blur.Size = 0
Blur.Parent = Lighting

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AbaddonUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 2147483647
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = getPersistentParent()
_G.AbaddonGui = ScreenGui

-- ==================== PERSISTENCE WATCHER ====================
task.spawn(function()
    while true do
        task.wait(0.5)
        local ok = pcall(function()
            if not ScreenGui or not ScreenGui.Parent then return end
        end)
        if not ok then return end
        if ScreenGui.Parent == nil then
            local parent = getPersistentParent()
            if parent then
                pcall(function() ScreenGui.Parent = parent end)
            end
        end
        if Blur and Blur.Parent == nil then
            pcall(function() Blur.Parent = Lighting end)
        end
    end
end)

-- ==================== URL RESOLVER ====================
local function resolveImageUrl(url)
    if writefile and getcustomasset then
        local ok, path = pcall(function()
            local filename = "abaddon_hoodwink.png"
            if isfile and isfile(filename) then
                return getcustomasset(filename)
            end
            local body = game:HttpGet(url, true)
            writefile(filename, body)
            return getcustomasset(filename)
        end)
        if ok and type(path) == "string" and path ~= "" then
            return path
        end
    end
    return url
end

local Overlay = Instance.new("Frame")
Overlay.Size = UDim2.new(1, 0, 1, 0)
Overlay.BackgroundColor3 = C.Bg
Overlay.BackgroundTransparency = 1
Overlay.BorderSizePixel = 0
Overlay.Visible = false
Overlay.ZIndex = 10
Overlay.Parent = ScreenGui

local Grid = Instance.new("Frame")
Grid.Size = UDim2.new(1, 0, 1, 0)
Grid.BackgroundTransparency = 1
Grid.ClipsDescendants = true
Grid.Visible = false
Grid.ZIndex = 11
Grid.Parent = ScreenGui

local NODE_COUNT, MAX_LINK = 52, 190
local nodes, links = {}, {}

local function makeNode()
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 2, 0, 2)
    dot.AnchorPoint = Vector2.new(0.5, 0.5)
    dot.BackgroundColor3 = Color3.fromRGB(220, 220, 224)
    dot.BackgroundTransparency = math.random(30, 65) / 100
    dot.BorderSizePixel = 0
    dot.ZIndex = 12
    dot.Parent = Grid
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    return {
        x = math.random() * 1400, y = math.random() * 800,
        vx = (math.random() - 0.5) * 55, vy = (math.random() - 0.5) * 55,
        dot = dot,
    }
end
for i = 1, NODE_COUNT do nodes[i] = makeNode() end

local function getLink(i)
    if not links[i] then
        local f = Instance.new("Frame")
        f.BorderSizePixel = 0
        f.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.Visible = false
        f.ZIndex = 11
        f.Parent = Grid
        links[i] = f
    end
    return links[i]
end

local cam = workspace.CurrentCamera
RunService.RenderStepped:Connect(function(dt)
    if not Grid.Visible then return end
    if not cam then cam = workspace.CurrentCamera end
    if not cam then return end
    local vp = cam.ViewportSize
    for _, n in ipairs(nodes) do
        n.x = n.x + n.vx * dt
        n.y = n.y + n.vy * dt
        if n.x < 0 then n.x = 0 n.vx = -n.vx end
        if n.x > vp.X then n.x = vp.X n.vx = -n.vx end
        if n.y < 0 then n.y = 0 n.vy = -n.vy end
        if n.y > vp.Y then n.y = vp.Y n.vy = -n.vy end
        n.dot.Position = UDim2.new(0, n.x, 0, n.y)
    end
    local li = 1
    for i = 1, #nodes do
        for j = i + 1, #nodes do
            local a, b = nodes[i], nodes[j]
            local dx, dy = a.x - b.x, a.y - b.y
            local d = math.sqrt(dx*dx + dy*dy)
            if d < MAX_LINK then
                local f = getLink(li)
                f.Visible = true
                f.Size = UDim2.new(0, d, 0, 1)
                f.Position = UDim2.new(0, (a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)
                f.Rotation = math.deg(math.atan2(dy, dx))
                f.BackgroundTransparency = 0.65 + (1 - d / MAX_LINK) * 0.3
                li = li + 1
            end
        end
    end
    for k = li, #links do links[k].Visible = false end
end)

local Panel = Instance.new("Frame")
Panel.Name = "Panel"
Panel.Size = UDim2.new(0, 620, 0, 420)
Panel.Position = UDim2.new(0.5, 0, 0.5, 0)
Panel.AnchorPoint = Vector2.new(0.5, 0.5)
Panel.BackgroundColor3 = C.Panel
Panel.BackgroundTransparency = 0.06
Panel.BorderSizePixel = 0
Panel.Visible = false
Panel.ClipsDescendants = true
Panel.ZIndex = 100
Panel.Parent = ScreenGui
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 2)

local pStroke = Instance.new("UIStroke", Panel)
pStroke.Color = C.Border
pStroke.Transparency = 0.25
pStroke.Thickness = 1

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundTransparency = 1
TopBar.ZIndex = 105
TopBar.Active = true
TopBar.Parent = Panel

local TopTitle = Instance.new("TextLabel", TopBar)
TopTitle.Size = UDim2.new(0, 200, 0, 16)
TopTitle.Position = UDim2.new(0, 16, 0, 12)
TopTitle.BackgroundTransparency = 1
TopTitle.Text = "ABADDON"
TopTitle.TextColor3 = C.Text
TopTitle.TextSize = 12
TopTitle.TextXAlignment = Enum.TextXAlignment.Left
TopTitle.Active = false
TopTitle.ZIndex = 106
applyFont(TopTitle)

local TopSub = Instance.new("TextLabel", TopBar)
TopSub.Size = UDim2.new(0, 200, 0, 12)
TopSub.Position = UDim2.new(0, 104, 0, 14)
TopSub.BackgroundTransparency = 1
TopSub.Text = "lzteam"
TopSub.TextColor3 = C.TextFaint
TopSub.TextSize = 9
TopSub.TextXAlignment = Enum.TextXAlignment.Left
TopSub.Active = false
TopSub.ZIndex = 106
applyFont(TopSub)

local HDiv = Instance.new("Frame", Panel)
HDiv.Size = UDim2.new(1, 0, 0, 1)
HDiv.Position = UDim2.new(0, 0, 0, 40)
HDiv.BackgroundColor3 = C.BorderSoft
HDiv.BorderSizePixel = 0
HDiv.ZIndex = 105

local CloseBtn = Instance.new("TextButton", TopBar)
CloseBtn.Size = UDim2.new(0, 24, 0, 24)
CloseBtn.Position = UDim2.new(1, -30, 0, 8)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "×"
CloseBtn.TextColor3 = C.TextDim
CloseBtn.TextSize = 16
CloseBtn.AutoButtonColor = false
CloseBtn.ZIndex = 107
applyFont(CloseBtn)

CloseBtn.MouseEnter:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), {TextColor3 = C.Text}):Play()
end)
CloseBtn.MouseLeave:Connect(function()
    TweenService:Create(CloseBtn, TweenInfo.new(0.15), {TextColor3 = C.TextDim}):Play()
end)

local SB_W = 160
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, SB_W, 1, -41)
Sidebar.Position = UDim2.new(0, 0, 0, 41)
Sidebar.BackgroundColor3 = C.PanelDark
Sidebar.BackgroundTransparency = 0.2
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex = 101
Sidebar.Parent = Panel

local SBDiv = Instance.new("Frame", Sidebar)
SBDiv.Size = UDim2.new(0, 1, 1, 0)
SBDiv.Position = UDim2.new(1, -1, 0, 0)
SBDiv.BackgroundColor3 = C.BorderSoft
SBDiv.BorderSizePixel = 0
SBDiv.ZIndex = 102

local TabList = Instance.new("Frame", Sidebar)
TabList.Size = UDim2.new(1, -20, 0, 240)
TabList.Position = UDim2.new(0, 10, 0, 12)
TabList.BackgroundTransparency = 1
TabList.ZIndex = 102

local TabLayout = Instance.new("UIListLayout", TabList)
TabLayout.Padding = UDim.new(0, 2)
TabLayout.SortOrder = Enum.SortOrder.LayoutOrder

local Card = Instance.new("Frame", Sidebar)
Card.Size = UDim2.new(1, -20, 0, 56)
Card.Position = UDim2.new(0, 10, 1, -66)
Card.BackgroundColor3 = C.PanelSoft
Card.BackgroundTransparency = 0.2
Card.BorderSizePixel = 0
Card.ZIndex = 102
Instance.new("UICorner", Card).CornerRadius = UDim.new(0, 2)
local cardStroke = Instance.new("UIStroke", Card)
cardStroke.Color = C.Border
cardStroke.Transparency = 0.5
cardStroke.Thickness = 1

local Avatar = Instance.new("ImageLabel", Card)
Avatar.Size = UDim2.new(0, 38, 0, 38)
Avatar.Position = UDim2.new(0, 9, 0, 9)
Avatar.BackgroundColor3 = C.PanelDark
Avatar.BorderSizePixel = 0
Avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
Avatar.ZIndex = 103
Instance.new("UICorner", Avatar).CornerRadius = UDim.new(0, 2)
local avStroke = Instance.new("UIStroke", Avatar)
avStroke.Color = C.Border
avStroke.Transparency = 0.4
avStroke.Thickness = 1

local NameLbl = Instance.new("TextLabel", Card)
NameLbl.Size = UDim2.new(1, -58, 0, 14)
NameLbl.Position = UDim2.new(0, 54, 0, 16)
NameLbl.BackgroundTransparency = 1
NameLbl.Text = "@" .. LocalPlayer.Name
NameLbl.TextColor3 = C.Text
NameLbl.TextSize = 11
NameLbl.TextXAlignment = Enum.TextXAlignment.Left
NameLbl.Active = false
NameLbl.ZIndex = 103
applyFont(NameLbl)

local StatusDot = Instance.new("Frame", Card)
StatusDot.Size = UDim2.new(0, 5, 0, 5)
StatusDot.Position = UDim2.new(0, 55, 0, 36)
StatusDot.BackgroundColor3 = C.Green
StatusDot.BorderSizePixel = 0
StatusDot.ZIndex = 103
Instance.new("UICorner", StatusDot).CornerRadius = UDim.new(1, 0)

local StatusLbl = Instance.new("TextLabel", Card)
StatusLbl.Size = UDim2.new(1, -68, 0, 12)
StatusLbl.Position = UDim2.new(0, 66, 0, 32)
StatusLbl.BackgroundTransparency = 1
StatusLbl.Text = "BETA"
StatusLbl.TextColor3 = C.TextFaint
StatusLbl.TextSize = 9
StatusLbl.TextXAlignment = Enum.TextXAlignment.Left
StatusLbl.Active = false
StatusLbl.ZIndex = 103
applyFont(StatusLbl)

local Content = Instance.new("Frame", Panel)
Content.Size = UDim2.new(1, -SB_W, 1, -41)
Content.Position = UDim2.new(0, SB_W, 0, 41)
Content.BackgroundTransparency = 1
Content.ZIndex = 101

local function notify(text)
    local n = Instance.new("Frame", ScreenGui)
    n.Size = UDim2.new(0, 240, 0, 32)
    n.Position = UDim2.new(1, -256, 1, 40)
    n.AnchorPoint = Vector2.new(0, 1)
    n.BackgroundColor3 = C.PanelSoft
    n.BackgroundTransparency = 0.05
    n.BorderSizePixel = 0
    n.ZIndex = 300
    Instance.new("UICorner", n).CornerRadius = UDim.new(0, 2)
    local s = Instance.new("UIStroke", n)
    s.Color = C.Border
    s.Transparency = 0.4

    local lbl = Instance.new("TextLabel", n)
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = C.Text
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Active = false
    applyFont(lbl)

    TweenService:Create(n, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
        Position = UDim2.new(1, -256, 1, -16),
    }):Play()
    task.wait(2)
    TweenService:Create(n, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {
        Position = UDim2.new(1, -256, 1, 40),
    }):Play()
    TweenService:Create(s, TweenInfo.new(0.3), {Transparency = 1}):Play()
    TweenService:Create(n, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
    task.wait(0.4)
    n:Destroy()
end

local LogContainer = Instance.new("Frame")
LogContainer.Size = UDim2.new(0, 400, 0, 400)
LogContainer.Position = UDim2.new(0, 16, 0, 16)
LogContainer.BackgroundTransparency = 1
LogContainer.ZIndex = 400
LogContainer.Parent = ScreenGui

local LogLayout = Instance.new("UIListLayout", LogContainer)
LogLayout.Padding = UDim.new(0, 4)
LogLayout.SortOrder = Enum.SortOrder.LayoutOrder
LogLayout.VerticalAlignment = Enum.VerticalAlignment.Top

local logCounter = 0

local LOG_COLORS = {
    info    = Color3.fromRGB(220, 220, 224),
    success = Color3.fromRGB(140, 195, 155),
    error   = Color3.fromRGB(200, 85,  85),
    warn    = Color3.fromRGB(200, 165, 95),
}

local function pushLog(text, kind)
    kind = kind or "info"
    logCounter = logCounter + 1
    local col = LOG_COLORS[kind] or LOG_COLORS.info

    local bg = Instance.new("Frame", LogContainer)
    bg.Size = UDim2.new(1, 0, 0, 24)
    bg.BackgroundColor3 = C.PanelDark
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.LayoutOrder = logCounter
    bg.ZIndex = 401
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 2)

    local st = Instance.new("UIStroke", bg)
    st.Color = C.Border
    st.Transparency = 1
    st.Thickness = 1

    local accent = Instance.new("Frame", bg)
    accent.Size = UDim2.new(0, 2, 1, 0)
    accent.Position = UDim2.new(0, 0, 0, 0)
    accent.BackgroundColor3 = col
    accent.BorderSizePixel = 0
    accent.BackgroundTransparency = 1
    accent.ZIndex = 402

    local lbl = Instance.new("TextLabel", bg)
    lbl.Size = UDim2.new(1, -18, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = string.format("[%s] %s", os.date("%H:%M:%S"), text)
    lbl.TextColor3 = col
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTransparency = 1
    lbl.TextStrokeTransparency = 0.6
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Active = false
    lbl.ZIndex = 402
    applyFont(lbl)

    TweenService:Create(bg, TweenInfo.new(0.22), {BackgroundTransparency = 0.25}):Play()
    TweenService:Create(st, TweenInfo.new(0.22), {Transparency = 0.6}):Play()
    TweenService:Create(accent, TweenInfo.new(0.22), {BackgroundTransparency = 0}):Play()
    TweenService:Create(lbl, TweenInfo.new(0.22), {TextTransparency = 0}):Play()

    task.delay(5, function()
        if not bg.Parent then return end
        TweenService:Create(bg, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
        TweenService:Create(st, TweenInfo.new(0.35), {Transparency = 1}):Play()
        TweenService:Create(accent, TweenInfo.new(0.35), {BackgroundTransparency = 1}):Play()
        TweenService:Create(lbl, TweenInfo.new(0.35), {TextTransparency = 1}):Play()
        task.wait(0.4)
        if bg.Parent then bg:Destroy() end
    end)
end

-- ==================== WATERMARK ====================
local Watermark = Instance.new("Frame")
Watermark.Name = "AbaddonWatermark"
Watermark.Size = UDim2.new(0, 480, 0, 26)
Watermark.Position = UDim2.new(0.5, 0, 1, -40)
Watermark.AnchorPoint = Vector2.new(0.5, 1)
Watermark.BackgroundColor3 = C.PanelDark
Watermark.BackgroundTransparency = 0.15
Watermark.BorderSizePixel = 0
Watermark.ZIndex = 250
Watermark.Parent = ScreenGui
Instance.new("UICorner", Watermark).CornerRadius = UDim.new(0, 2)
local wmStroke = Instance.new("UIStroke", Watermark)
wmStroke.Color = C.Border
wmStroke.Transparency = 0.5
wmStroke.Thickness = 1

local WmLabel = Instance.new("TextLabel", Watermark)
WmLabel.Size = UDim2.new(1, -24, 1, 0)
WmLabel.Position = UDim2.new(0, 12, 0, 0)
WmLabel.BackgroundTransparency = 1
WmLabel.RichText = true
WmLabel.TextColor3 = C.Text
WmLabel.TextSize = 12
WmLabel.TextXAlignment = Enum.TextXAlignment.Center
WmLabel.ZIndex = 251
WmLabel.Active = false
applyFont(WmLabel)

local fpsCounter, fpsTime, currentFps = 0, 0, 0
RunService.RenderStepped:Connect(function(dt)
    fpsCounter = fpsCounter + 1
    fpsTime = fpsTime + dt
    if fpsTime >= 0.5 then
        currentFps = math.floor(fpsCounter / fpsTime + 0.5)
        fpsCounter = 0
        fpsTime = 0
    end
end)

local function fpsColorHex(fps)
    if fps >= 50 then return "rgb(140, 195, 155)" end
    if fps >= 30 then return "rgb(200, 165, 95)" end
    return "rgb(200, 85, 85)"
end

local function pingColorHex(ping)
    if ping <= 80 then return "rgb(140, 195, 155)" end
    if ping <= 150 then return "rgb(200, 165, 95)" end
    return "rgb(200, 85, 85)"
end

task.spawn(function()
    while Watermark.Parent do
        local ok, ping = pcall(function()
            return math.floor(LocalPlayer:GetNetworkPing() * 1000)
        end)
        if not ok then ping = 0 end
        local name = State.HideUsername and "@ellieabaddon" or ("@" .. LocalPlayer.Name)
        WmLabel.Text = string.format(
            '<font color="rgb(220,220,224)">abaddon</font>  <font color="rgb(72,72,78)">|</font>  <font color="rgb(220,220,224)">%s</font>  <font color="rgb(72,72,78)">|</font>  <font color="%s">FPS %d</font>  <font color="rgb(72,72,78)">|</font>  <font color="%s">PING %d</font>',
            name, fpsColorHex(currentFps), currentFps, pingColorHex(ping), ping
        )
        task.wait(0.25)
    end
end)

-- ==================== HOODWINK ====================
local hoodwinkImg = nil
local HOODWINK_URL = "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ8uNn4Rwil6tRzyFXmlRUCOnCAnUlw33veEbK-auHw11oiZKgMxqOjrA2C&s=10"

local function setHoodwink(on)
    State.Hoodwink = on
    if on then
        if hoodwinkImg and hoodwinkImg.Parent then return end
        local img = Instance.new("ImageLabel")
        img.Name = "AbaddonHoodwink"
        img.Size = UDim2.new(0, 260, 0, 260)
        img.Position = UDim2.new(1, -20, 0, 20)
        img.AnchorPoint = Vector2.new(1, 0)
        img.BackgroundTransparency = 1
        img.ZIndex = 2147483600
        img.Parent = ScreenGui
        img.Image = resolveImageUrl(HOODWINK_URL)

        img.ImageTransparency = 1
        TweenService:Create(img, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {ImageTransparency = 0}):Play()
        hoodwinkImg = img
    else
        if hoodwinkImg then
            local old = hoodwinkImg
            hoodwinkImg = nil
            TweenService:Create(old, TweenInfo.new(0.3, Enum.EasingStyle.Quart), {ImageTransparency = 1}):Play()
            task.delay(0.32, function() old:Destroy() end)
        end
    end
end

-- ==================== TAB SYSTEM ====================
local Tabs, Pages = {}, {}

local function setActiveTab(name)
    for n, t in pairs(Tabs) do
        local active = (n == name)
        TweenService:Create(t.btn, TweenInfo.new(0.2, Enum.EasingStyle.Quart), {
            BackgroundTransparency = active and 0.65 or 1,
        }):Play()
        TweenService:Create(t.lbl, TweenInfo.new(0.2), {
            TextColor3 = active and C.Text or C.TextDim,
        }):Play()
        TweenService:Create(t.bar, TweenInfo.new(0.2), {
            BackgroundTransparency = active and 0.15 or 1,
        }):Play()
        Pages[n].Visible = active
    end
end

local function createTab(name, order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = C.PanelSoft
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.AutoButtonColor = false
    btn.LayoutOrder = order
    btn.ZIndex = 103
    btn.Parent = TabList
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 2)

    local bar = Instance.new("Frame", btn)
    bar.Size = UDim2.new(0, 2, 0, 12)
    bar.Position = UDim2.new(0, 0, 0.5, -6)
    bar.BackgroundColor3 = C.Accent
    bar.BackgroundTransparency = 1
    bar.BorderSizePixel = 0
    bar.Active = false
    bar.ZIndex = 104
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    local lbl = Instance.new("TextLabel", btn)
    lbl.Size = UDim2.new(1, -20, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = name
    lbl.TextColor3 = C.TextDim
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Active = false
    lbl.ZIndex = 104
    applyFont(lbl)

    local page = Instance.new("ScrollingFrame", Content)
    page.Size = UDim2.new(1, -32, 1, -28)
    page.Position = UDim2.new(0, 16, 0, 14)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.Visible = false
    page.ZIndex = 102
    page.ScrollingDirection = Enum.ScrollingDirection.Y
    page.ScrollingEnabled = true
    page.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
    page.ScrollBarThickness = 2
    page.ScrollBarImageColor3 = C.Border
    page.ScrollBarImageTransparency = 0.4
    page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.CanvasSize = UDim2.new(0, 0, 0, 0)

    local pl = Instance.new("UIListLayout", page)
    pl.Padding = UDim.new(0, 4)
    pl.SortOrder = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", page)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.PaddingRight  = UDim.new(0, 8)

    Tabs[name]  = { btn = btn, lbl = lbl, bar = bar }
    Pages[name] = page

    btn.MouseButton1Click:Connect(function()
        setActiveTab(name)
    end)

    return page
end

local function makeRow(parent, order, h)
    local row = Instance.new("Frame", parent)
    row.Size = UDim2.new(1, 0, 0, h or 36)
    row.BackgroundColor3 = C.PanelSoft
    row.BackgroundTransparency = 0.5
    row.BorderSizePixel = 0
    row.LayoutOrder = order
    row.ZIndex = 103
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 2)
    local st = Instance.new("UIStroke", row)
    st.Color = C.Border
    st.Transparency = 0.6
    st.Thickness = 1
    return row
end

local function createToggle(parent, label, default, order, callback, stateKey)
    local row = makeRow(parent, order)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -80, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.Text
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Active = false
    applyFont(lbl)

    local toggle = Instance.new("Frame", row)
    toggle.Size = UDim2.new(0, 32, 0, 16)
    toggle.Position = UDim2.new(1, -46, 0.5, -8)
    toggle.BackgroundColor3 = default and C.Accent or C.ToggleOff
    toggle.BorderSizePixel = 0
    toggle.Active = false
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", toggle)
    knob.Size = UDim2.new(0, 12, 0, 12)
    knob.Position = default and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    knob.BackgroundColor3 = default and C.PanelDark or Color3.fromRGB(160, 160, 165)
    knob.BorderSizePixel = 0
    knob.Active = false
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local isOn = default
    local function update(v, silent)
        isOn = v
        TweenService:Create(toggle, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {
            BackgroundColor3 = v and C.Accent or C.ToggleOff,
        }):Play()
        TweenService:Create(knob, TweenInfo.new(0.18, Enum.EasingStyle.Quart), {
            Position = v and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
            BackgroundColor3 = v and C.PanelDark or Color3.fromRGB(160, 160, 165),
        }):Play()
        if callback then callback(v, silent) end
    end

    local hit = Instance.new("TextButton", row)
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.ZIndex = 104
    hit.MouseButton1Click:Connect(function() update(not isOn) end)

    local widget = {
        Set = function(v) update(v, true) end,
        Get = function() return isOn end,
    }
    if stateKey then widgetRegistry[stateKey] = widget end
    return widget
end

local function createInput(parent, label, default, order, callback, stateKey)
    local row = makeRow(parent, order)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -150, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.Text
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Active = false
    applyFont(lbl)

    local box = Instance.new("TextBox", row)
    box.Size = UDim2.new(0, 92, 0, 22)
    box.Position = UDim2.new(1, -102, 0.5, -11)
    box.BackgroundColor3 = C.PanelDark
    box.BackgroundTransparency = 0.2
    box.Text = tostring(default)
    box.TextColor3 = C.Text
    box.PlaceholderText = "value"
    box.TextSize = 11
    box.ClearTextOnFocus = false
    box.ZIndex = 104
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 2)
    local st = Instance.new("UIStroke", box)
    st.Color = C.Border
    st.Transparency = 0.5
    applyFont(box)

    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then callback(num)
        else box.Text = tostring(default) end
    end)

    local widget = {
        Set = function(v)
            box.Text = tostring(v)
            callback(v)
        end,
        Get = function() return tonumber(box.Text) or default end,
    }
    if stateKey then widgetRegistry[stateKey] = widget end
    return widget
end

local function createButton(parent, label, order, callback)
    local row = makeRow(parent, order)
    row.BackgroundTransparency = 0.5

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = label
    btn.TextColor3 = C.Text
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.ZIndex = 104
    applyFont(btn)

    btn.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.15), {BackgroundTransparency = 0.25}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.15), {BackgroundTransparency = 0.5}):Play()
    end)
    btn.MouseButton1Click:Connect(callback)
end

local function createTextAction(parent, label, placeholder, order, callback)
    local row = makeRow(parent, order)
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -220, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.Text
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Active = false
    applyFont(lbl)

    local box = Instance.new("TextBox", row)
    box.Size = UDim2.new(0, 130, 0, 22)
    box.Position = UDim2.new(1, -176, 0.5, -11)
    box.BackgroundColor3 = C.PanelDark
    box.BackgroundTransparency = 0.2
    box.Text = ""
    box.TextColor3 = C.Text
    box.PlaceholderText = placeholder
    box.TextSize = 11
    box.ClearTextOnFocus = false
    box.ZIndex = 104
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 2)
    local bst = Instance.new("UIStroke", box)
    bst.Color = C.Border
    bst.Transparency = 0.5
    applyFont(box)

    local btn = Instance.new("TextButton", row)
    btn.Size = UDim2.new(0, 36, 0, 22)
    btn.Position = UDim2.new(1, -40, 0.5, -11)
    btn.BackgroundColor3 = C.PanelDark
    btn.BackgroundTransparency = 0.2
    btn.Text = "Go"
    btn.TextColor3 = C.Text
    btn.TextSize = 11
    btn.AutoButtonColor = false
    btn.ZIndex = 104
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 2)
    local btnst = Instance.new("UIStroke", btn)
    btnst.Color = C.Border
    btnst.Transparency = 0.5
    applyFont(btn)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.2}):Play()
    end)

    btn.MouseButton1Click:Connect(function()
        callback(box.Text)
    end)

    return box
end

local function createSlider(parent, label, min, max, default, order, callback, onRelease, stateKey)
    min = min or 0
    max = max or 100
    default = math.clamp(default or min, min, max)

    local row = makeRow(parent, order, 44)

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -90, 0, 18)
    lbl.Position = UDim2.new(0, 14, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.Text
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Active = false
    lbl.ZIndex = 104
    applyFont(lbl)

    local valLbl = Instance.new("TextLabel", row)
    valLbl.Size = UDim2.new(0, 70, 0, 18)
    valLbl.Position = UDim2.new(1, -84, 0, 4)
    valLbl.BackgroundTransparency = 1
    valLbl.Text = tostring(default)
    valLbl.TextColor3 = C.TextDim
    valLbl.TextSize = 11
    valLbl.TextXAlignment = Enum.TextXAlignment.Right
    valLbl.Active = false
    valLbl.ZIndex = 104
    applyFont(valLbl)

    local track = Instance.new("Frame", row)
    track.Size = UDim2.new(1, -28, 0, 3)
    track.Position = UDim2.new(0, 14, 0, 32)
    track.BackgroundColor3 = C.ToggleOff
    track.BorderSizePixel = 0
    track.ZIndex = 104
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local initialRel = (default - min) / (max - min)

    local fill = Instance.new("Frame", track)
    fill.Size = UDim2.new(initialRel, 0, 1, 0)
    fill.BackgroundColor3 = C.Accent
    fill.BorderSizePixel = 0
    fill.ZIndex = 105
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame", row)
    knob.Size = UDim2.new(0, 10, 0, 10)
    knob.AnchorPoint = Vector2.new(0.5, 0.5)
    knob.Position = UDim2.new(initialRel, 14, 0, 34)
    knob.BackgroundColor3 = C.Accent
    knob.BorderSizePixel = 0
    knob.ZIndex = 106
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local current = default
    local dragging = false

    local function setValue(v, silent)
        v = math.clamp(math.floor(v + 0.5), min, max)
        current = v
        local rel = (v - min) / (max - min)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        knob.Position = UDim2.new(0, 14 + rel * (track.AbsoluteSize.X), 0, 34)
        valLbl.Text = tostring(v)
        if callback then callback(v, silent) end
    end

    local function updateFromX(x)
        local rel = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
        setValue(min + (max - min) * rel, false)
    end

    track:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        local rel = (current - min) / (max - min)
        knob.Position = UDim2.new(0, 14 + rel * track.AbsoluteSize.X, 0, 34)
    end)

    local hit = Instance.new("TextButton", row)
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.AutoButtonColor = false
    hit.ZIndex = 107

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            updateFromX(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                if onRelease then onRelease(current) end
            end
        end
    end)

    local widget = {
        Set = function(v)
            setValue(v, true)
            if onRelease then onRelease(current) end
        end,
        Get = function() return current end,
    }
    if stateKey then widgetRegistry[stateKey] = widget end
    return widget
end

local VisualPage = createTab("Visual", 1)
local MainPage   = createTab("Main",   2)
local PlayerPage = createTab("Player", 3)
local FunPage    = createTab("Fun",    4)
local ConfigPage = createTab("Config", 5)

setActiveTab("Visual")

local fbCache
local function setFullbright(on)
    if on then
        fbCache = {
            Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness,
            ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd,
            ExposureCompensation = Lighting.ExposureCompensation,
        }
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 3
        Lighting.ClockTime = 12
        Lighting.FogEnd = 100000
        Lighting.ExposureCompensation = 0.5
    elseif fbCache then
        for k, v in pairs(fbCache) do Lighting[k] = v end
        fbCache = nil
    end
end

local noShadowCache = nil
local noShadowConn = nil

local function setNoShadows(on)
    State.NoShadows = on

    if on then
        noShadowCache = {
            GlobalShadows = Lighting.GlobalShadows,
            Effects = {},
        }
        Lighting.GlobalShadows = false

        for _, obj in ipairs(Lighting:GetDescendants()) do
            if obj.Name == "AbaddonBlur" then continue end
            if obj:IsA("BloomEffect")
            or obj:IsA("BlurEffect")
            or obj:IsA("ColorCorrectionEffect")
            or obj:IsA("SunRaysEffect")
            or obj:IsA("DepthOfFieldEffect") then
                if obj.Enabled then
                    noShadowCache.Effects[obj] = { kind = "enabled" }
                    obj.Enabled = false
                end
            elseif obj:IsA("Atmosphere") then
                if obj.Density > 0 then
                    noShadowCache.Effects[obj] = { kind = "density", value = obj.Density }
                    obj.Density = 0
                end
            end
        end

        task.spawn(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj.CastShadow then
                    obj.CastShadow = false
                end
            end
        end)

        if noShadowConn then noShadowConn:Disconnect() end
        noShadowConn = workspace.DescendantAdded:Connect(function(obj)
            if not State.NoShadows then return end
            if obj:IsA("BasePart") then
                task.defer(function()
                    if obj.Parent and State.NoShadows then obj.CastShadow = false end
                end)
            end
        end)
    else
        if noShadowConn then noShadowConn:Disconnect() noShadowConn = nil end

        if noShadowCache then
            Lighting.GlobalShadows = noShadowCache.GlobalShadows
            for obj, data in pairs(noShadowCache.Effects) do
                if obj and obj.Parent then
                    pcall(function()
                        if data.kind == "enabled" then obj.Enabled = true
                        elseif data.kind == "density" then obj.Density = data.value
                        end
                    end)
                end
            end
            noShadowCache = nil
        else
            Lighting.GlobalShadows = true
        end

        task.spawn(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then obj.CastShadow = true end
            end
        end)
    end
end

local texRestore = {}
local texConn = nil

local function isInCharacter(obj)
    local model = obj:FindFirstAncestorOfClass("Model")
    return model ~= nil and Players:GetPlayerFromCharacter(model) ~= nil
end

local function stripOneTexture(obj)
    if isInCharacter(obj) then return end

    if obj:IsA("Decal") or obj:IsA("Texture") then
        local t = obj.Transparency
        if t < 1 then
            obj.Transparency = 1
            texRestore[#texRestore+1] = function()
                if obj.Parent then obj.Transparency = t end
            end
        end
        return
    end

    if obj:IsA("SurfaceAppearance") then
        local cm = obj.ColorMap
        if cm ~= "" then
            obj.ColorMap = ""
            texRestore[#texRestore+1] = function()
                if obj.Parent then obj.ColorMap = cm end
            end
        end
        return
    end

    if obj:IsA("MeshPart") then
        local tid = obj.TextureID
        if tid ~= "" then
            obj.TextureID = ""
            texRestore[#texRestore+1] = function()
                if obj.Parent then obj.TextureID = tid end
            end
        end
    end

    if obj:IsA("BasePart") then
        local mat = obj.Material
        if mat ~= Enum.Material.SmoothPlastic then
            obj.Material = Enum.Material.SmoothPlastic
            texRestore[#texRestore+1] = function()
                if obj.Parent then obj.Material = mat end
            end
        end
    end
end

local function setNoTextures(on, silent)
    State.NoTextures = on

    if on then
        texRestore = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            pcall(stripOneTexture, obj)
        end

        if texConn then texConn:Disconnect() end
        texConn = workspace.DescendantAdded:Connect(function(obj)
            if not State.NoTextures then return end
            task.defer(function()
                if obj.Parent and State.NoTextures then
                    pcall(stripOneTexture, obj)
                end
            end)
        end)
    else
        if texConn then texConn:Disconnect() texConn = nil end
        for _, fn in ipairs(texRestore) do pcall(fn) end
        texRestore = {}
    end

    if not silent then
        pushLog("No Textures: " .. (on and "включены" or "выключены"), "info")
    end
end

local afkConn
local function setAntiAFK(on)
    if afkConn then afkConn:Disconnect() afkConn = nil end
    if not on then return end
    afkConn = LocalPlayer.Idled:Connect(function()
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end)
end

local noclipConn
local function setNoclip(on)
    State.Noclip = on
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if not on then return end
    noclipConn = RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
        end
    end)
end

local tpConn
local function setTPTool(on)
    State.TPTool = on
    if tpConn then tpConn:Disconnect() tpConn = nil end
    if not on then return end
    local mouse = LocalPlayer:GetMouse()
    tpConn = UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local hit = mouse.Hit
        if hit then
            hrp.CFrame = CFrame.new(hit.Position + Vector3.new(0, 3, 0))
            pushLog(string.format("TP на %.0f, %.0f", hit.Position.X, hit.Position.Z), "success")
        end
    end)
end

local function gotoPlayer(name)
    if not name or name == "" then
        pushLog("Введите ник для телепорта", "warn")
        return
    end
    name = name:lower()
    local found
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Name:lower():sub(1, #name) == name then
            found = plr
            break
        end
    end
    if not found then
        pushLog("Игрок не найден: " .. name, "error")
        return
    end
    local tchar = found.Character
    local thrp = tchar and tchar:FindFirstChild("HumanoidRootPart")
    local mychar = LocalPlayer.Character
    local myhrp = mychar and mychar:FindFirstChild("HumanoidRootPart")
    if thrp and myhrp then
        myhrp.CFrame = CFrame.new(thrp.Position + Vector3.new(0, 3, 0))
        pushLog("Телепорт к " .. found.Name, "success")
    else
        pushLog("Цель ещё не загружена", "error")
    end
end

local backWalkConn
local function setBackWalk(on)
    State.BackWalk = on
    if backWalkConn then backWalkConn:Disconnect() backWalkConn = nil end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and not State.Spin then hum.AutoRotate = not on end

    if not on then return end

    local smoothedLook = nil
    backWalkConn = RunService.Heartbeat:Connect(function(dt)
        if State.Spin then return end
        local c = LocalPlayer.Character
        if not c then return end
        local h   = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return end
        h.AutoRotate = false

        local md = h.MoveDirection
        if md.Magnitude > 0.05 then
            local target = Vector3.new(-md.X, 0, -md.Z)
            if target.Magnitude > 0.01 then
                target = target.Unit
                if not smoothedLook then
                    smoothedLook = target
                else
                    smoothedLook = smoothedLook:Lerp(target, math.clamp(dt * 9, 0, 1))
                end

                local pos = hrp.Position
                local desired = CFrame.lookAt(pos, pos + smoothedLook)
                hrp.CFrame = hrp.CFrame:Lerp(desired, math.clamp(dt * 18, 0, 1))
            end
        else
            smoothedLook = nil
        end
    end)
end

local spinConn
local function setSpin(on)
    State.Spin = on
    if spinConn then spinConn:Disconnect() spinConn = nil end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if not on then
        if hum and not State.BackWalk then hum.AutoRotate = true end
        return
    end

    spinConn = RunService.Heartbeat:Connect(function(dt)
        local c = LocalPlayer.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return end
        h.AutoRotate = false
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(SPIN_SPEED) * dt, 0)
    end)
end

local function setCameraFOV(value, silent)
    State.CameraFOV = value
    if not cam then cam = workspace.CurrentCamera end
    if cam then
        cam.FieldOfView = value
    end
    if not silent then
        pushLog("Camera FOV: " .. tostring(value), "info")
    end
end

local flyBodyVel, flyBodyGyro, flyConn
local flyKeys = {W = false, A = false, S = false, D = false, Space = false, LCtrl = false}

local function setFly(on)
    State.Fly = on
    if flyConn then flyConn:Disconnect() flyConn = nil end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if flyBodyVel then flyBodyVel:Destroy() flyBodyVel = nil end
    if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end

    if not on or not hrp then
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
        return
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end

    flyBodyVel = Instance.new("BodyVelocity")
    flyBodyVel.Name = "AbaddonFlyVel"
    flyBodyVel.MaxForce = Vector3.new(1e5, 1e5, 1e5)
    flyBodyVel.Velocity = Vector3.zero
    flyBodyVel.Parent = hrp

    flyBodyGyro = Instance.new("BodyGyro")
    flyBodyGyro.Name = "AbaddonFlyGyro"
    flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
    flyBodyGyro.P = 3000
    flyBodyGyro.D = 100
    flyBodyGyro.CFrame = hrp.CFrame
    flyBodyGyro.Parent = hrp

    flyConn = RunService.RenderStepped:Connect(function()
        local c = LocalPlayer.Character
        local root = c and c:FindFirstChild("HumanoidRootPart")
        if not root or not flyBodyVel or not flyBodyGyro then return end
        if not cam then cam = workspace.CurrentCamera end
        if not cam then return end
        flyBodyGyro.CFrame = cam.CFrame

        local move = Vector3.zero
        if flyKeys.W then move = move + cam.CFrame.LookVector end
        if flyKeys.S then move = move - cam.CFrame.LookVector end
        if flyKeys.A then move = move - cam.CFrame.RightVector end
        if flyKeys.D then move = move + cam.CFrame.RightVector end
        if flyKeys.Space then move = move + Vector3.new(0, 1, 0) end
        if flyKeys.LCtrl then move = move - Vector3.new(0, 1, 0) end

        if move.Magnitude > 0 then
            flyBodyVel.Velocity = move.Unit * State.FlySpeed
        else
            flyBodyVel.Velocity = Vector3.zero
        end
    end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.W then flyKeys.W = true end
    if input.KeyCode == Enum.KeyCode.A then flyKeys.A = true end
    if input.KeyCode == Enum.KeyCode.S then flyKeys.S = true end
    if input.KeyCode == Enum.KeyCode.D then flyKeys.D = true end
    if input.KeyCode == Enum.KeyCode.Space then flyKeys.Space = true end
    if input.KeyCode == Enum.KeyCode.LeftControl then flyKeys.LCtrl = true end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then flyKeys.W = false end
    if input.KeyCode == Enum.KeyCode.A then flyKeys.A = false end
    if input.KeyCode == Enum.KeyCode.S then flyKeys.S = false end
    if input.KeyCode == Enum.KeyCode.D then flyKeys.D = false end
    if input.KeyCode == Enum.KeyCode.Space then flyKeys.Space = false end
    if input.KeyCode == Enum.KeyCode.LeftControl then flyKeys.LCtrl = false end
end)

local antiflingConn
local function setAntiFling(on)
    State.AntiFling = on
    if antiflingConn then antiflingConn:Disconnect() antiflingConn = nil end
    if not on then return end
    antiflingConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local vel = hrp.AssemblyLinearVelocity
        if vel.Magnitude > 200 then
            hrp.AssemblyLinearVelocity = vel.Unit * 100
        end
    end)
end

local function serverHop()
    pushLog("Server Hop: запрос...", "info")
    local ok, result = pcall(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok or not result or not result.data then
        pushLog("Server Hop: не удалось получить список", "error")
        return
    end
    local servers = {}
    for _, s in ipairs(result.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then
            servers[#servers + 1] = s.id
        end
    end
    if #servers == 0 then
        pushLog("Server Hop: нет свободных серверов", "warn")
        return
    end
    local pick = servers[math.random(1, #servers)]
    pushLog("Server Hop: телепорт...", "success")
    TeleportService:TeleportToPlaceInstance(game.PlaceId, pick, LocalPlayer)
end

local function rejoin()
    pushLog("Rejoin...", "info")
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

-- ==================== CONFIG SYSTEM ====================
local function saveConfig()
    if not writefile then
        pushLog("Executor не поддерживает writefile", "error")
        return
    end
    local data = {}
    for k, v in pairs(State) do
        if type(v) ~= "function" and type(v) ~= "table" then
            data[k] = v
        end
    end
    local ok, err = pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
    if ok then
        pushLog("Конфиг сохранён (" .. CONFIG_FILE .. ")", "success")
    else
        pushLog("Ошибка сохранения: " .. tostring(err), "error")
    end
end

local function applyConfigData(data, silent)
    for key, w in pairs(widgetRegistry) do
        if data[key] ~= nil then
            pcall(function() w.Set(data[key]) end)
            State[key] = data[key]
        end
    end
    if data.HideUsername ~= nil then State.HideUsername = data.HideUsername end
    if not silent then
        pushLog("Конфиг применён", "success")
    end
end

local function loadConfig()
    if not readfile or not isfile then
        pushLog("Executor не поддерживает readfile", "error")
        return
    end
    if not isfile(CONFIG_FILE) then
        pushLog("Конфиг не найден", "warn")
        return
    end
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(CONFIG_FILE))
    end)
    if not ok or type(data) ~= "table" then
        pushLog("Ошибка чтения конфига", "error")
        return
    end
    applyConfigData(data, false)
    pushLog("Конфиг загружен", "success")
end

local function resetConfig()
    applyConfigData(DEFAULT_STATE, true)
    pushLog("Настройки сброшены к дефолту", "success")
    notify("Config reset")
end

local function deleteConfig()
    if not delfile then
        pushLog("Executor не поддерживает delfile", "error")
        return
    end
    pcall(function() delfile(CONFIG_FILE) end)
    pushLog("Файл конфига удалён", "info")
end

-- ==================== VISUAL PAGE ====================
createToggle(VisualPage, "ESP Survivors", false, 1, function(v, silent)
    State.ESP_Survivors = v
    if silent then return end
    notify("Survivors ESP: " .. (v and "ON" or "OFF"))
    pushLog("ESP Survivors: " .. (v and "включён" or "выключен"), "info")
end, "ESP_Survivors")

createToggle(VisualPage, "ESP Killer", false, 2, function(v, silent)
    State.ESP_Killer = v
    if silent then return end
    notify("Killer ESP: " .. (v and "ON" or "OFF"))
    pushLog("ESP Killer: " .. (v and "включён" or "выключен"), "info")
end, "ESP_Killer")

createToggle(VisualPage, "ESP Generators", false, 3, function(v, silent)
    State.ESP_Generators = v
    if silent then return end
    notify("Generators ESP: " .. (v and "ON" or "OFF"))
    pushLog("ESP Generators: " .. (v and "включён" or "выключен"), "info")
end, "ESP_Generators")

createToggle(VisualPage, "Fullbright", false, 4, function(v, silent)
    State.Fullbright = v
    setFullbright(v)
    if silent then return end
    notify("Fullbright: " .. (v and "ON" or "OFF"))
    pushLog("Fullbright: " .. (v and "включён" or "выключен"), "info")
end, "Fullbright")

createToggle(VisualPage, "No Shadows", false, 5, function(v, silent)
    setNoShadows(v)
    if silent then return end
    notify("No Shadows: " .. (v and "ON" or "OFF"))
    pushLog("No Shadows: " .. (v and "включены" or "выключены"), "info")
end, "NoShadows")

createToggle(VisualPage, "No Textures", false, 6, function(v, silent)
    setNoTextures(v, silent)
    if silent then return end
    notify("No Textures: " .. (v and "ON" or "OFF"))
end, "NoTextures")

-- ==================== MAIN PAGE ====================
createToggle(MainPage, "Auto Hit Perfect Skillcheck", false, 1, function(v, silent)
    State.AutoSkillCheck = v
    if silent then return end
    notify("Auto Skillcheck: " .. (v and "ON" or "OFF"))
    pushLog("Auto Skillcheck: " .. (v and "включён" or "выключен"), "info")
end, "AutoSkillCheck")

createToggle(MainPage, "Anti-AFK", false, 2, function(v, silent)
    State.AntiAFK = v
    setAntiAFK(v)
    if silent then return end
    notify("Anti-AFK: " .. (v and "ON" or "OFF"))
    pushLog("Anti-AFK: " .. (v and "включён" or "выключен"), "info")
end, "AntiAFK")

createToggle(MainPage, "Anti-Fling", false, 3, function(v, silent)
    setAntiFling(v)
    if silent then return end
    notify("Anti-Fling: " .. (v and "ON" or "OFF"))
    pushLog("Anti-Fling: " .. (v and "включён" or "выключен"), "info")
end, "AntiFling")

createToggle(MainPage, "Hide Username (watermark)", false, 4, function(v, silent)
    State.HideUsername = v
    if silent then return end
    pushLog("Watermark username: " .. (v and "@ellieabaddon" or "@" .. LocalPlayer.Name), "info")
end, "HideUsername")

-- ==================== PLAYER PAGE ====================
createInput(PlayerPage, "WalkSpeed", 16, 1, function(v)
    State.WalkSpeed = v
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v end
    notify("WalkSpeed: " .. tostring(v))
    pushLog("WalkSpeed изменён на " .. tostring(v), "info")
end, "WalkSpeed")

-- ФИКС: HipHeight применяется только если он не 0
createInput(PlayerPage, "Hip Height", 0, 2, function(v)
    State.HipHeight = v
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum and v ~= 0 then hum.HipHeight = v end
    notify("HipHeight: " .. tostring(v))
    pushLog("HipHeight изменён на " .. tostring(v), "info")
end, "HipHeight")

createToggle(PlayerPage, "Noclip", false, 3, function(v, silent)
    setNoclip(v)
    if silent then return end
    notify("Noclip: " .. (v and "ON" or "OFF"))
    pushLog("Noclip: " .. (v and "включён" or "выключен"), "info")
end, "Noclip")

createToggle(PlayerPage, "TP Tool (ЛКМ — телепорт)", false, 4, function(v, silent)
    setTPTool(v)
    if silent then return end
    notify("TP Tool: " .. (v and "ON" or "OFF"))
    pushLog("TP Tool: " .. (v and "включён" or "выключен"), "info")
end, "TPTool")

createToggle(PlayerPage, "Fly (WASD+Space/Ctrl)", false, 5, function(v, silent)
    setFly(v)
    if silent then return end
    notify("Fly: " .. (v and "ON" or "OFF"))
    pushLog("Fly: " .. (v and "включён" or "выключен"), "info")
end, "Fly")

createInput(PlayerPage, "Fly Speed", 60, 6, function(v)
    State.FlySpeed = v
    notify("Fly Speed: " .. tostring(v))
    pushLog("Fly Speed: " .. tostring(v), "info")
end, "FlySpeed")

createTextAction(PlayerPage, "Goto Player", "nickname", 7, function(name)
    gotoPlayer(name)
end)

createButton(PlayerPage, "Server Hop", 8, function()
    serverHop()
end)

createButton(PlayerPage, "Rejoin", 9, function()
    rejoin()
end)

-- ==================== FUN PAGE ====================
createToggle(FunPage, "Back Walk", false, 1, function(v, silent)
    setBackWalk(v)
    if silent then return end
    notify("Back Walk: " .. (v and "ON" or "OFF"))
    pushLog("Back Walk: " .. (v and "включён" or "выключен"), "info")
end, "BackWalk")

createToggle(FunPage, "Spin", false, 2, function(v, silent)
    setSpin(v)
    if silent then return end
    notify("Spin: " .. (v and "ON" or "OFF"))
    pushLog("Spin: " .. (v and "включён" or "выключен"), "info")
end, "Spin")

createSlider(FunPage, "Camera FOV", 60, 220, 70, 3,
    function(v, silent)
        setCameraFOV(v, silent)
    end,
    function(v)
        pushLog("Camera FOV: " .. tostring(v), "info")
    end,
    "CameraFOV"
)

createSlider(FunPage, "Time (ClockTime 0-24)", 0, 24, 14, 4,
    function(v, silent)
        State.ClockTime = v
        Lighting.ClockTime = math.clamp(v, 0, 24)
    end,
    function(v)
        pushLog("ClockTime: " .. tostring(v), "info")
    end,
    "ClockTime"
)

createToggle(FunPage, "Hoodwink", false, 5, function(v, silent)
    setHoodwink(v)
    if silent then return end
    notify("Hoodwink: " .. (v and "ON" or "OFF"))
    pushLog("Hoodwink: " .. (v and "включён" or "выключен"), "info")
end, "Hoodwink")

-- ==================== CONFIG PAGE ====================
createButton(ConfigPage, "Save Config", 1, function()
    saveConfig()
end)
createButton(ConfigPage, "Load Config", 2, function()
    loadConfig()
end)
createButton(ConfigPage, "Reset Config (defaults)", 3, function()
    resetConfig()
end)
createButton(ConfigPage, "Delete Config File", 4, function()
    deleteConfig()
end)

-- ==================== ESP ====================
local ESPFolder = Instance.new("Folder")
ESPFolder.Name = "AbaddonESP"
ESPFolder.Parent = ScreenGui

local playerEsp, playerTags = {}, {}
local genEsp = {}

local function clearEsp(cache, key)
    if cache[key] then cache[key]:Destroy() cache[key] = nil end
end

local function applyPlayerESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        local teamName = plr.Team and plr.Team.Name:lower() or ""
        local isKiller   = teamName:find("killer")   ~= nil
        local isSurvivor = teamName:find("survivor") ~= nil

        local want = (isKiller and State.ESP_Killer) or (isSurvivor and State.ESP_Survivors)

        if want and char then
            local col = isKiller and C.Killer or C.Survivor

            local h = playerEsp[plr]
            if not h then
                h = Instance.new("Highlight")
                h.Name = "ESP_" .. plr.Name
                h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                h.FillTransparency = 0.75
                h.OutlineTransparency = 0.15
                h.Parent = ESPFolder
                playerEsp[plr] = h
            end
            h.FillColor = col
            h.OutlineColor = col
            h.Adornee = char

            local head = char:FindFirstChild("Head")
            if head then
                local tag = playerTags[plr]
                if not tag or not tag.Parent then
                    tag = Instance.new("BillboardGui")
                    tag.Name = "AbaddonTag"
                    tag.Size = UDim2.new(0, 220, 0, 22)
                    tag.StudsOffset = Vector3.new(0, 3, 0)
                    tag.AlwaysOnTop = true
                    tag.Adornee = head
                    tag.Parent = char

                    local lbl = Instance.new("TextLabel", tag)
                    lbl.Name = "Label"
                    lbl.Size = UDim2.new(1, 0, 1, 0)
                    lbl.BackgroundTransparency = 1
                    lbl.TextSize = 12
                    lbl.TextStrokeTransparency = 0.35
                    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    applyFont(lbl)

                    playerTags[plr] = tag
                end
                tag.Adornee = head
                local lbl = tag:FindFirstChild("Label")
                if lbl then
                    lbl.Text = plr.Name
                    lbl.TextColor3 = col
                end
            end
        else
            clearEsp(playerEsp, plr)
            clearEsp(playerTags, plr)
        end
    end
end

local function applyGeneratorESP()
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (obj.Name == "Generator" or obj.Name:lower():find("generator")) then
            if State.ESP_Generators then
                if not genEsp[obj] then
                    local h = Instance.new("Highlight")
                    h.Adornee = obj
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillColor = C.Generator
                    h.OutlineColor = C.Generator
                    h.FillTransparency = 0.78
                    h.OutlineTransparency = 0.15
                    h.Parent = ESPFolder
                    genEsp[obj] = h
                end
            else
                clearEsp(genEsp, obj)
            end
        end
    end
end

task.spawn(function()
    while ScreenGui.Parent do
        pcall(applyPlayerESP)
        pcall(applyGeneratorESP)
        task.wait(0.5)
    end
end)

-- ==================== AUTO SKILLCHECK ====================
local TouchID         = 8822
local ActionPath      = "Survivor-mob.Controls.action.check"
local isProcessingHit = false

local function GetActionTarget()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil end
    local current = pg
    for segment in string.gmatch(ActionPath, "[^%.]+") do
        current = current and current:FindFirstChild(segment)
    end
    return current
end

local function TriggerMobileButton()
    local b = GetActionTarget()
    if b and b:IsA("GuiObject") then
        local p, s, i = b.AbsolutePosition, b.AbsoluteSize, GuiService:GetGuiInset()
        local cx, cy = p.X + (s.X / 2) + i.X, p.Y + (s.Y / 2) + i.Y
        pcall(function()
            VirtualInputManager:SendTouchEvent(TouchID, 0, cx, cy)
            task.wait(0.002)
            VirtualInputManager:SendTouchEvent(TouchID, 2, cx, cy)
        end)
    else
        pcall(function()
            VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
            task.wait(0.002)
            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
        end)
    end
end

local function EvaluateTeamState()
    local team = LocalPlayer.Team
    local teamName = team and team.Name:lower() or ""
    if teamName:find("survivor") then return "survivor" end
    if teamName:find("killer")   then return "killer"   end
    return "spectator"
end

_G.ASC_MainLoop = RunService.Heartbeat:Connect(function()
    if not State.AutoSkillCheck then isProcessingHit = false return end
    if EvaluateTeamState() ~= "survivor" then return end

    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return end
    local prompt = pg:FindFirstChild("SkillCheckPromptGui")
    if not prompt then isProcessingHit = false return end

    local check = prompt:FindFirstChild("Check")
    if not check or not check.Visible then isProcessingHit = false return end

    local line = check:FindFirstChild("Line")
    local goal = check:FindFirstChild("Goal")
    if not line or not goal then return end

    local lr = line.Rotation % 360
    local gr = goal.Rotation % 360

    local ss = (gr + 102) % 360
    local se = (gr + 116) % 360
    local isInZone = (ss > se and (lr >= ss or lr <= se)) or (lr >= ss and lr <= se)

    if not isInZone and isProcessingHit then isProcessingHit = false end
    if not isProcessingHit and isInZone then
        isProcessingHit = true
        local ok = pcall(TriggerMobileButton)
        if ok then
            pushLog("Успешный скилл-чек на " .. LocalPlayer.Name, "success")
        else
            pushLog("Ошибка при срабатывании скилл-чека", "error")
        end
        task.delay(0.02, function() isProcessingHit = false end)
    end
end)

-- ==================== OPEN / CLOSE ====================
local openToken = 0

local function setOpen(open)
    State.Open = open
    openToken = openToken + 1
    local myToken = openToken
    pushLog("Меню " .. (open and "открыто" or "закрыто"), "info")

    if open then
        Panel.Visible = true
        Overlay.Visible = true
        Grid.Visible = true
        Panel.Size = UDim2.new(0, 580, 0, 390)
        Panel.BackgroundTransparency = 1
        Overlay.BackgroundTransparency = 1
        TweenService:Create(Panel, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 620, 0, 420),
            BackgroundTransparency = 0.06,
        }):Play()
        TweenService:Create(Overlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.5}):Play()
        TweenService:Create(Blur, TweenInfo.new(0.32), {Size = 8}):Play()
    else
        TweenService:Create(Panel, TweenInfo.new(0.22, Enum.EasingStyle.Quart), {
            Size = UDim2.new(0, 580, 0, 390),
            BackgroundTransparency = 1,
        }):Play()
        TweenService:Create(Overlay, TweenInfo.new(0.24), {BackgroundTransparency = 1}):Play()
        TweenService:Create(Blur, TweenInfo.new(0.28), {Size = 0}):Play()
        task.delay(0.26, function()
            if myToken ~= openToken then return end
            Panel.Visible = false
            Overlay.Visible = false
            Grid.Visible = false
        end)
    end
end

CloseBtn.MouseButton1Click:Connect(function() setOpen(false) end)

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == KEY_TOGGLE then setOpen(not State.Open) end
end)

do
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = Panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            Panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

UserInputService.InputChanged:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
    if not State.Open then return end
    for _, page in pairs(Pages) do
        if not page.Visible then continue end
        local mouse = UserInputService:GetMouseLocation()
        local topLeft = page.AbsolutePosition
        local bottomRight = topLeft + page.AbsoluteSize
        if mouse.X >= topLeft.X and mouse.X <= bottomRight.X
        and mouse.Y >= topLeft.Y and mouse.Y <= bottomRight.Y then
            local maxScroll = math.max(0, page.AbsoluteCanvasSize.Y - page.AbsoluteSize.Y)
            local newY = math.clamp(page.CanvasPosition.Y - input.Position.Z * 40, 0, maxScroll)
            page.CanvasPosition = Vector2.new(0, newY)
            break
        end
    end
end)

-- ==================== WELCOME ====================
local function showWelcome()
    local popup = Instance.new("Frame", ScreenGui)
    popup.Size = UDim2.new(0, 300, 0, 40)
    popup.Position = UDim2.new(0.5, 0, 1, 40)
    popup.AnchorPoint = Vector2.new(0.5, 1)
    popup.BackgroundColor3 = C.Panel
    popup.BackgroundTransparency = 1
    popup.BorderSizePixel = 0
    popup.ZIndex = 300
    Instance.new("UICorner", popup).CornerRadius = UDim.new(0, 2)

    local st = Instance.new("UIStroke", popup)
    st.Color = C.Border
    st.Transparency = 1
    st.Thickness = 1

    local txt = Instance.new("TextLabel", popup)
    txt.Size = UDim2.new(1, -24, 1, 0)
    txt.Position = UDim2.new(0, 12, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = "Welcome, @" .. LocalPlayer.Name
    txt.TextColor3 = C.Text
    txt.TextSize = 11
    txt.TextXAlignment = Enum.TextXAlignment.Center
    txt.ZIndex = 301
    applyFont(txt)

    TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, 0, 1, -36),
        BackgroundTransparency = 0.05,
    }):Play()
    TweenService:Create(st, TweenInfo.new(0.4), {Transparency = 0.4}):Play()

    task.wait(3)
    TweenService:Create(popup, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, 0, 1, 60),
        BackgroundTransparency = 1,
    }):Play()
    TweenService:Create(st, TweenInfo.new(0.4), {Transparency = 1}):Play()
    task.wait(0.5)
    popup:Destroy()
end

-- ==================== CHARACTER HOOKS ====================
LocalPlayer.CharacterAdded:Connect(function(char)
    pushLog("Персонаж загружен", "info")
    task.wait(0.4)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = State.WalkSpeed
        -- ФИКС: HipHeight не трогаем, если он 0 (иначе персонаж поднимается в воздух)
        if State.HipHeight and State.HipHeight ~= 0 then
            hum.HipHeight = State.HipHeight
        end
        hum.PlatformStand = false
    end
    if State.Noclip then setNoclip(true) end
    if State.BackWalk then setBackWalk(true) end
    if State.Spin then setSpin(true) end
    if State.Fly then setFly(true) end
    if State.NoShadows then
        task.spawn(function()
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") then obj.CastShadow = false end
            end
        end)
    end
end)

LocalPlayer.CharacterRemoving:Connect(function()
    pushLog("Персонаж выгружается", "warn")
end)

-- ==================== BOOT ====================
task.spawn(function()
    local ok, err = pcall(showWelcome)
    if not ok then pushLog("Ошибка при показе welcome: " .. tostring(err), "error") end
end)

task.spawn(function()
    if readfile and isfile and isfile(CONFIG_FILE) then
        task.wait(1)
        pcall(loadConfig)
    end
end)

notify("Abaddon loaded · RightShift")
pushLog("Abaddon успешно загружен", "success")
