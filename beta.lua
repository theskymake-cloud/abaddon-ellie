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
local SoundService        = game:GetService("SoundService")
local Debris              = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer:WaitForChild("PlayerGui")

-- ==================== RE-EXECUTE CLEANUP ====================
if _G.AbaddonCleanup then pcall(_G.AbaddonCleanup) end
if _G.AbaddonGui then pcall(function() _G.AbaddonGui:Destroy() end) end
if _G.ASC_MainLoop then pcall(function() _G.ASC_MainLoop:Disconnect() end) end
_G.ASC_MainLoop = nil

-- leftovers from old versions
for _, n in ipairs({ "AbaddonBlur", "AbaddonSandyCC", "AbaddonSandyBlur" }) do
    local o = Lighting:FindFirstChild(n)
    if o then pcall(function() o:Destroy() end) end
end

local Conns, Cleanups = {}, {}
local function track(c) Conns[#Conns + 1] = c return c end
local function onCleanup(fn) Cleanups[#Cleanups + 1] = fn end
_G.AbaddonCleanup = function()
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Conns = {}
    for _, fn in ipairs(Cleanups) do pcall(fn) end
    Cleanups = {}
    if _G.AbaddonFakeLagStop then pcall(_G.AbaddonFakeLagStop) end
    if _G.AbaddonRestoreCollide then pcall(_G.AbaddonRestoreCollide) end
end

local KEY_TOGGLE  = Enum.KeyCode.RightShift
local SPIN_SPEED  = 720
local SANDY_SPEED = 22
local SANDY_SOUND = "rbxassetid://128482950258388"
local CROSSHAIR_X = -38 -- ~1 cm to the left (96 dpi)
local CONFIG_FILE = "Abaddon_config.json"

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

-- ==================== PALETTE (gamesense) ====================
local C = {
    Black     = Color3.fromRGB(0, 0, 0),
    White     = Color3.fromRGB(255, 255, 255),
    Outer     = Color3.fromRGB(32, 32, 32),
    Bg        = Color3.fromRGB(17, 17, 17),
    Side      = Color3.fromRGB(13, 13, 13),
    Field     = Color3.fromRGB(34, 34, 34),
    FieldHov  = Color3.fromRGB(46, 46, 46),
    Off       = Color3.fromRGB(44, 44, 44),
    Border    = Color3.fromRGB(48, 48, 48),
    Text      = Color3.fromRGB(205, 205, 205),
    TextDim   = Color3.fromRGB(140, 140, 140),
    TextFaint = Color3.fromRGB(88, 88, 88),
    Accent    = Color3.fromRGB(159, 202, 43),
    Green     = Color3.fromRGB(159, 202, 43),
    Yellow    = Color3.fromRGB(214, 175, 98),
    Red       = Color3.fromRGB(226, 96, 96),
}

-- ==================== STATE ====================
local State = {
    Open           = false,
    ESP_Survivors  = false,
    ESP_Killer     = false,
    ESP_Generators = false,
    ESP_Hooks      = false,
    ESP_Pallets    = false,
    ESP_Gates      = false,
    ESP_Info       = false,
    Tracers        = false,
    Fullbright     = false,
    NoShadows      = false,
    NoTextures     = false,
    CustomTime     = false,
    AutoSkillCheck = false,
    AntiAFK        = false,
    KillerAlert    = false,
    AlertRange     = 60,
    Radar          = false,
    RadarRange     = 120,
    WalkSpeed      = 16,
    WalkSpeedLock  = true,
    Noclip         = false,
    TPTool         = false,
    BackWalk       = false,
    Spin           = false,
    Fly            = false,
    FlySpeed       = 60,
    AntiFling      = false,
    CameraFOV      = 70,
    ThirdPerson    = false,
    ShiftLock      = true,
    MaxZoom        = 128,
    ClockTime      = 14,
    Hoodwink       = false,
    HideUsername   = false,
    BindIsland     = true,
    Logs           = true,
    Crosshair      = false,
    CrosshairSize  = 10,
    FakeLag        = false,
    FakeLagTime    = 200,
    Sandevistan    = false,
    Halo           = false,
    HaloColorHex   = "FFD76A",
    Trail          = false,
    TrailStyle     = "Default",
    ESP_SurvivorColorHex  = "8CB4DC",
    ESP_KillerColorHex    = "C85555",
    ESP_GeneratorColorHex = "8CC89B",
}

local DEFAULT_STATE = {}
for k, v in pairs(State) do DEFAULT_STATE[k] = v end

local widgetRegistry = {}

-- ==================== COLOR UTILS ====================
local function hexToColor3(hex)
    hex = tostring(hex):gsub("#", ""):gsub("%s", ""):upper()
    if #hex ~= 6 then return nil end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not r or not g or not b then return nil end
    return Color3.fromRGB(r, g, b)
end

local function color3ToHex(c)
    return string.format("%02X%02X%02X",
        math.floor(c.R * 255 + 0.5),
        math.floor(c.G * 255 + 0.5),
        math.floor(c.B * 255 + 0.5))
end

local ESPColors = {
    Survivor  = hexToColor3(State.ESP_SurvivorColorHex)  or Color3.fromRGB(140, 180, 220),
    Killer    = hexToColor3(State.ESP_KillerColorHex)    or Color3.fromRGB(200, 85, 85),
    Generator = hexToColor3(State.ESP_GeneratorColorHex) or Color3.fromRGB(140, 200, 155),
}

-- ==================== FONTS ====================
local FONT = Enum.Font.Code
local function fontReg(o)  o.Font = FONT end
local function fontMed(o)  o.Font = FONT end
local function fontBold(o) o.Font = FONT end

-- ==================== UI HELPERS ====================
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function corner() end

local function stroke(p, col, th)
    return new("UIStroke", {
        Color = col or C.Black, Thickness = th or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end

local function gloss(p, b)
    return new("UIGradient", {
        Rotation = 90, Color = ColorSequence.new(C.White, b or Color3.fromRGB(150, 150, 150)),
    }, p)
end

local function rule(parent, pos, size, col)
    return new("Frame", {
        Position = pos, Size = size, BackgroundColor3 = col or C.Border,
        BorderSizePixel = 0, ZIndex = 3, Active = false,
    }, parent)
end

local function topGradient(parent, h)
    local f = new("Frame", {
        Name = "TopLine", Size = UDim2.new(1, 0, 0, h or 2), BackgroundColor3 = C.White,
        BorderSizePixel = 0, ZIndex = 10, Active = false,
    }, parent)
    new("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0,   Color3.fromRGB(55, 177, 218)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(203, 61, 211)),
            ColorSequenceKeypoint.new(1,   Color3.fromRGB(201, 211, 61)),
        }),
    }, f)
    return f
end

local function tween(o, t, props, style)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quart), props)
    tw:Play()
    return tw
end

-- ==================== ROOT GUI ====================
local ScreenGui = new("ScreenGui", {
    Name = "AbaddonUI", ResetOnSpawn = false, IgnoreGuiInset = true,
    DisplayOrder = 2147483647, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, getPersistentParent())
_G.AbaddonGui = ScreenGui

task.spawn(function()
    while true do
        task.wait(0.5)
        if not ScreenGui then return end
        if ScreenGui.Parent == nil then
            pcall(function() ScreenGui.Parent = getPersistentParent() end)
        end
    end
end)

local function resolveImageUrl(url)
    if writefile and getcustomasset then
        local ok, path = pcall(function()
            local filename = "abaddon_hoodwink.png"
            if isfile and isfile(filename) then return getcustomasset(filename) end
            local body = game:HttpGet(url, true)
            writefile(filename, body)
            return getcustomasset(filename)
        end)
        if ok and type(path) == "string" and path ~= "" then return path end
    end
    return url
end

local Overlay = new("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 10,
}, ScreenGui)

-- ==================== MAIN PANEL ====================
local PW, PH = 700, 470
local SB_W = 130

local Panel = new("CanvasGroup", {
    Name = "Panel", Size = UDim2.fromOffset(PW, PH),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.Outer, BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 100,
    GroupTransparency = 1,
}, ScreenGui)
stroke(Panel, C.Black)

local Body = new("Frame", {
    Name = "Body", Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 1, -10),
    BackgroundColor3 = C.Bg, BorderSizePixel = 0, ZIndex = 2,
}, Panel)
stroke(Body, C.Black)
topGradient(Body, 2)

local TopBar = new("Frame", {
    Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 26),
    BackgroundTransparency = 1, Active = true, ZIndex = 5,
}, Body)

local TopTitle = new("TextLabel", {
    Size = UDim2.fromOffset(70, 26), Position = UDim2.fromOffset(10, 0),
    BackgroundTransparency = 1, RichText = true,
    Text = '<font color="rgb(255,255,255)">ab</font><font color="rgb(159,202,43)">addon</font>',
    TextColor3 = C.Text, TextSize = 15,
    TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 6,
}, TopBar)
fontBold(TopTitle)

local TopSub = new("TextLabel", {
    Size = UDim2.fromOffset(60, 26), Position = UDim2.fromOffset(84, 1), BackgroundTransparency = 1,
    Text = "by ellie", TextColor3 = C.TextFaint, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 6,
}, TopBar)
fontMed(TopSub)

local CloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(20, 18), Position = UDim2.new(1, -28, 0, 4),
    BackgroundColor3 = C.Field, Text = "x", TextColor3 = C.TextDim, TextSize = 12,
    AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 8,
}, TopBar)
stroke(CloseBtn, C.Black)
gloss(CloseBtn)
fontMed(CloseBtn)
CloseBtn.MouseEnter:Connect(function()
    tween(CloseBtn, 0.1, { TextColor3 = C.Red, BackgroundColor3 = C.FieldHov })
end)
CloseBtn.MouseLeave:Connect(function()
    tween(CloseBtn, 0.1, { TextColor3 = C.TextDim, BackgroundColor3 = C.Field })
end)

rule(Body, UDim2.fromOffset(0, 28), UDim2.new(1, 0, 0, 1), C.Black)
rule(Body, UDim2.fromOffset(0, 29), UDim2.new(1, 0, 0, 1), C.Border)

local Sidebar = new("Frame", {
    Size = UDim2.new(0, SB_W, 1, -30), Position = UDim2.fromOffset(0, 30),
    BackgroundColor3 = C.Side, BorderSizePixel = 0, ZIndex = 2,
}, Body)
rule(Sidebar, UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0), C.Black)
rule(Sidebar, UDim2.new(1, -2, 0, 0), UDim2.new(0, 1, 1, 0), C.Border)

local TabList = new("Frame", {
    Size = UDim2.new(1, -14, 1, -64), Position = UDim2.fromOffset(6, 8),
    BackgroundTransparency = 1, ZIndex = 3,
}, Sidebar)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, TabList)

local Card = new("Frame", {
    Size = UDim2.new(1, -14, 0, 38), Position = UDim2.new(0, 6, 1, -46),
    BackgroundColor3 = C.Bg, BorderSizePixel = 0, ZIndex = 3,
}, Sidebar)
stroke(Card, C.Black)

local Avatar = new("ImageLabel", {
    Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(5, 5),
    BackgroundColor3 = C.Field, BorderSizePixel = 0, ZIndex = 4,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
}, Card)
stroke(Avatar, C.Black)

local NameLbl = new("TextLabel", {
    Size = UDim2.new(1, -40, 0, 14), Position = UDim2.fromOffset(38, 4),
    BackgroundTransparency = 1, Text = "@" .. LocalPlayer.Name, TextColor3 = C.Text, TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Active = false, ZIndex = 4,
}, Card)
fontBold(NameLbl)

local StatusDot = new("Frame", {
    Size = UDim2.fromOffset(5, 5), Position = UDim2.fromOffset(39, 24),
    BackgroundColor3 = C.Green, BorderSizePixel = 0, ZIndex = 4,
}, Card)
local StatusLbl = new("TextLabel", {
    Size = UDim2.new(1, -52, 0, 12), Position = UDim2.fromOffset(49, 20),
    BackgroundTransparency = 1, Text = "ACTIVE", TextColor3 = C.TextFaint, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 4,
}, Card)
fontMed(StatusLbl)

local Content = new("Frame", {
    Size = UDim2.new(1, -SB_W, 1, -30), Position = UDim2.fromOffset(SB_W, 30),
    BackgroundTransparency = 1, ZIndex = 2,
}, Body)

-- ==================== TOASTS ====================
local function notify() end

-- ==================== LOG FEED ====================
local LogContainer = new("Frame", {
    Size = UDim2.fromOffset(380, 400), Position = UDim2.fromOffset(10, 10),
    BackgroundTransparency = 1, ZIndex = 400,
}, ScreenGui)
new("UIListLayout", {
    Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top,
}, LogContainer)

local logCounter = 0
local LOG_COLORS = {
    info    = Color3.fromRGB(215, 215, 215),
    success = Color3.fromRGB(159, 202, 43),
    error   = Color3.fromRGB(226, 96, 96),
    warn    = Color3.fromRGB(214, 175, 98),
}

local MAX_LOGS = 6
local lastLogText, lastLogTime = nil, 0

local function clearLogs()
    for _, c in ipairs(LogContainer:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end
end

local function pushLog(text, kind)
    if not State.Logs then return end
    local now = os.clock()
    if text == lastLogText and now - lastLogTime < 1.5 then return end
    lastLogText, lastLogTime = text, now

    kind = kind or "info"
    logCounter = logCounter + 1
    local col = LOG_COLORS[kind] or LOG_COLORS.info

    local bg = new("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = C.Bg, BackgroundTransparency = 0.1,
        BorderSizePixel = 0, LayoutOrder = logCounter, GroupTransparency = 1, ZIndex = 401,
    }, LogContainer)
    stroke(bg, C.Black)
    new("Frame", {
        Size = UDim2.new(0, 2, 1, 0), BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 3, Active = false,
    }, bg)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -14, 1, 0), Position = UDim2.fromOffset(10, 0),
        BackgroundTransparency = 1, Text = string.format("[%s] %s", os.date("%H:%M:%S"), text),
        TextColor3 = col, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 3,
    }, bg)
    fontMed(lbl)

    local alive = {}
    for _, c in ipairs(LogContainer:GetChildren()) do
        if c:IsA("CanvasGroup") then alive[#alive + 1] = c end
    end
    table.sort(alive, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    while #alive > MAX_LOGS do table.remove(alive, 1):Destroy() end

    tween(bg, 0.15, { GroupTransparency = 0 })
    task.delay(4, function()
        if not bg.Parent then return end
        tween(bg, 0.25, { GroupTransparency = 1 })
        task.wait(0.3)
        if bg.Parent then bg:Destroy() end
    end)
end

-- ==================== WATERMARK (top right) ====================
local Watermark = new("Frame", {
    Name = "AbaddonWatermark", Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X,
    Position = UDim2.new(1, -10, 0, 10), AnchorPoint = Vector2.new(1, 0),
    BackgroundColor3 = C.Bg, BorderSizePixel = 0, ZIndex = 250,
}, ScreenGui)
stroke(Watermark, C.Black)
topGradient(Watermark, 2)

local WmLabel = new("TextLabel", {
    Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
    BackgroundTransparency = 1, RichText = true, TextColor3 = C.Text, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Active = false,
}, Watermark)
new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), PaddingTop = UDim.new(0, 2) }, WmLabel)
fontMed(WmLabel)

local fpsCounter, fpsTime, currentFps = 0, 0, 0
track(RunService.RenderStepped:Connect(function(dt)
    fpsCounter = fpsCounter + 1
    fpsTime = fpsTime + dt
    if fpsTime >= 0.5 then
        currentFps = math.floor(fpsCounter / fpsTime + 0.5)
        fpsCounter, fpsTime = 0, 0
    end
end))

local function fpsColorHex(fps)
    if fps >= 50 then return "rgb(159,202,43)" end
    if fps >= 30 then return "rgb(214,175,98)" end
    return "rgb(226,96,96)"
end
local function pingColorHex(ping)
    if ping <= 80 then return "rgb(159,202,43)" end
    if ping <= 150 then return "rgb(214,175,98)" end
    return "rgb(226,96,96)"
end

task.spawn(function()
    while Watermark.Parent do
        local ok, ping = pcall(function() return math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
        if not ok then ping = 0 end
        local name = State.HideUsername and "@ellieabaddon" or ("@" .. LocalPlayer.Name)
        WmLabel.Text = string.format(
            '<font color="rgb(255,255,255)">ab</font><font color="rgb(159,202,43)">addon</font> <font color="rgb(90,90,90)">|</font> <font color="rgb(205,205,205)">%s</font> <font color="rgb(90,90,90)">|</font> <font color="%s">%d fps</font> <font color="rgb(90,90,90)">|</font> <font color="%s">%dms</font>',
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
        local img = new("ImageLabel", {
            Name = "AbaddonHoodwink", Size = UDim2.fromOffset(330, 330),
            Position = UDim2.new(1, -20, 0, 50), AnchorPoint = Vector2.new(1, 0),
            BackgroundTransparency = 1, ZIndex = 2147483600, ImageTransparency = 1,
        }, ScreenGui)
        img.Image = resolveImageUrl(HOODWINK_URL)
        tween(img, 0.35, { ImageTransparency = 0 }, Enum.EasingStyle.Quint)
        hoodwinkImg = img
    elseif hoodwinkImg then
        local old = hoodwinkImg
        hoodwinkImg = nil
        tween(old, 0.3, { ImageTransparency = 1 })
        task.delay(0.32, function() old:Destroy() end)
    end
end

-- ==================== KEYBINDS + BIND ISLAND ====================
local BindList, Binding = {}, nil
local ISL_W = 230

local KEY_ALIAS = {
    LeftShift = "LShift", RightShift = "RShift", LeftControl = "LCtrl", RightControl = "RCtrl",
    LeftAlt = "LAlt", RightAlt = "RAlt", Return = "Enter", Backspace = "Bksp", Space = "Space",
    Zero = "0", One = "1", Two = "2", Three = "3", Four = "4",
    Five = "5", Six = "6", Seven = "7", Eight = "8", Nine = "9",
    Insert = "Ins", Delete = "Del", PageUp = "PgUp", PageDown = "PgDn",
}
local function keyName(k) return type(k) == "string" and k or k.Name end
local function keyDisplay(k)
    if type(k) == "string" then return k end
    return KEY_ALIAS[k.Name] or k.Name
end
local function keyFromName(nm)
    if nm == "M4" or nm == "M5" then return nm end
    local ok, kc = pcall(function() return Enum.KeyCode[nm] end)
    return ok and kc or nil
end

local Island = new("CanvasGroup", {
    Name = "BindIsland", Size = UDim2.fromOffset(ISL_W, 40),
    Position = UDim2.new(0.5, 0, 0, 105), AnchorPoint = Vector2.new(0.5, 0),
    BackgroundColor3 = C.Bg, BorderSizePixel = 0,
    GroupTransparency = 1, Visible = false, ZIndex = 260,
}, ScreenGui)
stroke(Island, C.Black)
topGradient(Island, 2)

local IslandList = new("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 3,
}, Island)
new("UIPadding", {
    PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 6),
    PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
}, IslandList)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, IslandList)

local islandToken = 0
local function refreshIsland()
    for _, c in ipairs(IslandList:GetChildren()) do
        if c:IsA("GuiObject") then c:Destroy() end
    end

    local n = 0
    if Binding then
        n = n + 1
        local lbl = new("TextLabel", {
            Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1,
            Text = "Press a key for " .. Binding.label .. " | Esc = clear",
            TextColor3 = C.Accent, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = n, ZIndex = 4, Active = false,
        }, IslandList)
        fontMed(lbl)
    end

    if State.BindIsland then
        for _, e in ipairs(BindList) do
            if e.key then
                n = n + 1
                local on = e.isOn()
                local row = new("Frame", {
                    Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, LayoutOrder = n, ZIndex = 4,
                }, IslandList)
                new("Frame", {
                    Size = UDim2.fromOffset(5, 5), Position = UDim2.new(0, 0, 0.5, -2),
                    BackgroundColor3 = on and C.Accent or C.TextFaint, BorderSizePixel = 0, ZIndex = 5,
                }, row)
                local nm = new("TextLabel", {
                    Size = UDim2.new(1, -52, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
                    Text = e.label, TextColor3 = on and C.Text or C.TextDim, TextSize = 11,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
                    ZIndex = 5, Active = false,
                }, row)
                fontMed(nm)
                local tl = new("TextLabel", {
                    Size = UDim2.fromOffset(46, 18), Position = UDim2.new(1, -46, 0, 0), BackgroundTransparency = 1,
                    Text = "[" .. keyDisplay(e.key) .. "]", TextColor3 = C.TextDim, TextSize = 10,
                    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6, Active = false,
                }, row)
                fontMed(tl)
            end
        end
    end

    islandToken = islandToken + 1
    if n > 0 then
        local h = 8 + 6 + n * 18 + math.max(0, n - 1) * 2
        Island.Visible = true
        tween(Island, 0.2, { Size = UDim2.fromOffset(ISL_W, h), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
    else
        local tok = islandToken
        tween(Island, 0.15, { GroupTransparency = 1 })
        task.delay(0.17, function() if tok == islandToken then Island.Visible = false end end)
    end
end

local function startBinding(entry)
    local prev = Binding
    Binding = entry
    if prev and prev ~= entry then prev.refreshBadge() end
    entry.refreshBadge()
    refreshIsland()
    pushLog("Press a key / M4 / M5 for " .. entry.label .. " (Esc = clear)", "info")
    if not iskeypressed then pushLog("M4/M5 need executor support (iskeypressed)", "warn") end
end

local function cancelBinding()
    if not Binding then return end
    local e = Binding
    Binding = nil
    e.refreshBadge()
    refreshIsland()
end

local function clearAllBinds()
    Binding = nil
    for _, e in ipairs(BindList) do e.key = nil e.refreshBadge() end
    refreshIsland()
    pushLog("All binds cleared", "info")
end

track(UserInputService.InputBegan:Connect(function(input, processed)
    if Binding then
        local ut = input.UserInputType
        if ut == Enum.UserInputType.Keyboard then
            local e, kc = Binding, input.KeyCode
            if kc == Enum.KeyCode.Unknown then return end
            Binding = nil
            if kc == Enum.KeyCode.Escape then
                e.key = nil
                pushLog("Bind cleared: " .. e.label, "warn")
            elseif kc == KEY_TOGGLE then
                pushLog(keyDisplay(kc) .. " is reserved for the menu", "error")
            else
                e.key = kc
                pushLog("Bind: " .. e.label .. " → " .. keyDisplay(kc), "success")
            end
            e.refreshBadge()
            refreshIsland()
        elseif ut == Enum.UserInputType.MouseButton1 or ut == Enum.UserInputType.MouseButton2 then
            cancelBinding()
        end
        return
    end

    if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    for _, e in ipairs(BindList) do
        if e.key and e.key == input.KeyCode then e.toggle() end
    end
end))

local MOUSE_EXTRA = { M4 = 0x05, M5 = 0x06 }
local mouseExtraDown = { M4 = false, M5 = false }

local function mouseExtraHeld(vk)
    local ok, res = pcall(iskeypressed, vk)
    return ok and res == true
end

local function onExtraMouse(name)
    if Binding then
        local e = Binding
        Binding = nil
        e.key = name
        pushLog("Bind: " .. e.label .. " → " .. name, "success")
        e.refreshBadge()
        refreshIsland()
        return
    end
    if UserInputService:GetFocusedTextBox() then return end
    for _, e in ipairs(BindList) do
        if e.key == name then e.toggle() end
    end
end

track(RunService.Heartbeat:Connect(function()
    if not iskeypressed then return end
    if isrbxactive and not isrbxactive() then return end
    for name, vk in pairs(MOUSE_EXTRA) do
        local held = mouseExtraHeld(vk)
        if held and not mouseExtraDown[name] then
            mouseExtraDown[name] = true
            onExtraMouse(name)
        elseif not held then
            mouseExtraDown[name] = false
        end
    end
end))

-- ==================== TAB SYSTEM ====================
local Tabs, Pages = {}, {}
local pageCols = {}
local groupOf  = {}

local function setActiveTab(name)
    for n, t in pairs(Tabs) do
        local active = (n == name)
        tween(t.btn, 0.12, { BackgroundTransparency = active and 0 or 1 })
        tween(t.lbl, 0.12, { TextColor3 = active and C.White or C.TextDim })
        tween(t.bar, 0.12, {
            BackgroundTransparency = active and 0 or 1,
            Size = active and UDim2.fromOffset(2, 14) or UDim2.fromOffset(2, 0),
        })
        Pages[n].Visible = active
    end
end

local function createTab(name, order)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.Bg, BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, LayoutOrder = order, BorderSizePixel = 0, ZIndex = 4,
    }, TabList)

    local bar = new("Frame", {
        Size = UDim2.fromOffset(2, 0), Position = UDim2.new(0, 0, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = C.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = 5,
    }, btn)

    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
        Text = string.lower(name), TextColor3 = C.TextDim, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        Active = false, ZIndex = 5,
    }, btn)
    fontMed(lbl)

    btn.MouseEnter:Connect(function()
        if Pages[name] and Pages[name].Visible then return end
        tween(lbl, 0.1, { TextColor3 = C.Text })
    end)
    btn.MouseLeave:Connect(function()
        if Pages[name] and Pages[name].Visible then return end
        tween(lbl, 0.1, { TextColor3 = C.TextDim })
    end)

    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, -16, 1, -16), Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 3,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollingEnabled = true,
        ElasticBehavior = Enum.ElasticBehavior.Never,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.Accent, ScrollBarImageTransparency = 0.3,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
    }, Content)
    new("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Top,
    }, page)
    new("UIPadding", { PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) }, page)

    local function makeCol(order)
        local col = new("Frame", {
            Size = UDim2.new(0.5, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 3,
        }, page)
        new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, col)
        return col
    end
    pageCols[page] = { L = makeCol(1), R = makeCol(2), hL = 0, hR = 0 }

    Tabs[name]  = { btn = btn, lbl = lbl, bar = bar }
    Pages[name] = page
    btn.MouseButton1Click:Connect(function() setActiveTab(name) end)
    return page
end

-- ==================== WIDGETS ====================
local ROW, BODY = 20, 112

local function glassRow(parent, order, h)
    local g = groupOf[parent]
    local tgt = g and g.box or parent
    if g then
        local pc = pageCols[parent]
        pc[g.col] = pc[g.col] + (h or ROW) + 4
    end
    return new("Frame", {
        Size = UDim2.new(1, 0, 0, h or ROW), BackgroundTransparency = 1,
        BorderSizePixel = 0, LayoutOrder = order, ZIndex = 4,
    }, tgt)
end

local function hoverLabel(hit, lbl)
    hit.MouseEnter:Connect(function() tween(lbl, 0.08, { TextColor3 = C.White }) end)
    hit.MouseLeave:Connect(function() tween(lbl, 0.1, { TextColor3 = C.Text }) end)
end

local function createSection(parent, text, order)
    local pc = pageCols[parent]
    local colKey = (pc.hL <= pc.hR) and "hL" or "hR"
    local colFrame = (colKey == "hL") and pc.L or pc.R
    pc[colKey] = pc[colKey] + 30

    local outer = new("Frame", {
        Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, LayoutOrder = order, ZIndex = 3,
    }, colFrame)

    local box = new("Frame", {
        Position = UDim2.fromOffset(0, 7), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 3,
    }, outer)
    stroke(box, C.Border)
    new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, box)
    new("UIPadding", {
        PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 8),
        PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8),
    }, box)

    local title = new("TextLabel", {
        Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X,
        Position = UDim2.fromOffset(8, 0), BackgroundColor3 = C.Bg, BorderSizePixel = 0,
        Text = string.lower(text), TextColor3 = C.White, TextSize = 11,
        ZIndex = 6, Active = false,
    }, outer)
    new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, title)
    fontBold(title)

    groupOf[parent] = { box = box, col = colKey }
    return outer
end

-- ---------- Color wheel (HSV) — fixed ----------
-- Every strip is a full-diameter bar rotated around the wheel center.
-- Its top half shows hue(rot), the bottom half shows hue(rot+180), the middle is white.
local function buildPicker(container, startColor, onChange)
    local api = {}
    local h, s, v = startColor:ToHSV()
    local SIZE = 96
    local R = SIZE / 2

    local holder = new("Frame", {
        Size = UDim2.fromOffset(SIZE, SIZE), Position = UDim2.fromOffset(8, 8),
        BackgroundTransparency = 1, ZIndex = 4,
    }, container)

    local wheel = new("CanvasGroup", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 4,
    }, holder)
    new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, wheel)
    stroke(wheel, C.Black)

    local STRIPS = 120
    for i = 0, STRIPS - 1 do
        local rot = i * 180 / STRIPS
        local st = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(4, SIZE + 2), Rotation = rot,
            BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 4, Active = false,
        }, wheel)
        new("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0,   Color3.fromHSV(rot / 360, 1, 1)),
                ColorSequenceKeypoint.new(0.5, C.White),
                ColorSequenceKeypoint.new(1,   Color3.fromHSV(((rot + 180) % 360) / 360, 1, 1)),
            }),
        }, st)
    end

    -- brightness shade (darkens the wheel when V < 1)
    local shade = new("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Black, BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 5, Active = false,
    }, wheel)

    local marker = new("Frame", {
        Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 6, Active = false,
    }, holder)
    stroke(marker, C.Black)

    local prev = new("Frame", {
        Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(112, 8),
        BackgroundColor3 = startColor, BorderSizePixel = 0, ZIndex = 4,
    }, container)
    stroke(prev, C.Black)

    local hexBox = new("TextBox", {
        Size = UDim2.new(1, -144, 0, 20), Position = UDim2.fromOffset(138, 8),
        BackgroundColor3 = C.Field, Text = "",
        TextColor3 = C.Text, PlaceholderText = "#RRGGBB", PlaceholderColor3 = C.TextFaint,
        TextSize = 11, ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 4,
    }, container)
    stroke(hexBox, C.Black)
    fontMed(hexBox)

    local vLabel = new("TextLabel", {
        Size = UDim2.fromOffset(100, 12), Position = UDim2.fromOffset(112, 38), BackgroundTransparency = 1,
        Text = "brightness", TextColor3 = C.TextDim, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4, Active = false,
    }, container)
    fontMed(vLabel)

    local vTrack = new("Frame", {
        Size = UDim2.new(1, -124, 0, 8), Position = UDim2.fromOffset(112, 54),
        BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 4,
    }, container)
    stroke(vTrack, C.Black)
    local vGrad = new("UIGradient", { Color = ColorSequence.new(Color3.new(0, 0, 0), C.White) }, vTrack)
    local vKnob = new("Frame", {
        Size = UDim2.fromOffset(4, 12), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 6, Active = false,
    }, vTrack)
    stroke(vKnob, C.Black)

    local hint = new("TextLabel", {
        Size = UDim2.new(1, -124, 0, 30), Position = UDim2.fromOffset(112, 72), BackgroundTransparency = 1,
        Text = "Drag the wheel or type a hex value.",
        TextColor3 = C.TextFaint, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, ZIndex = 4, Active = false,
    }, container)
    fontReg(hint)

    local function refresh(fire)
        local col = Color3.fromHSV(h, s, v)
        local a = h * 2 * math.pi
        marker.Position = UDim2.new(0.5, R * s * math.sin(a), 0.5, -R * s * math.cos(a))
        marker.BackgroundColor3 = col
        prev.BackgroundColor3 = col
        shade.BackgroundTransparency = v
        hexBox.Text = "#" .. color3ToHex(col)
        vGrad.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1))
        vKnob.Position = UDim2.new(v, 0, 0.5, 0)
        if fire then onChange(col, color3ToHex(col)) end
    end

    local wheelHit = new("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 8,
    }, holder)
    local vHit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, -7), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = 8,
    }, vTrack)

    local dragWheel, dragV = false, false

    local function wheelFrom(pos)
        local c = holder.AbsolutePosition + holder.AbsoluteSize / 2
        local dx, dy = pos.X - c.X, pos.Y - c.Y
        local dist = math.sqrt(dx * dx + dy * dy)
        s = math.clamp(dist / R, 0, 1)
        if dist > 0.5 then h = (math.atan2(dx, -dy) / (2 * math.pi)) % 1 end
        refresh(true)
    end
    local function vFrom(x)
        v = math.clamp((x - vTrack.AbsolutePosition.X) / math.max(1, vTrack.AbsoluteSize.X), 0, 1)
        refresh(true)
    end

    local function isPress(i)
        return i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch
    end
    wheelHit.InputBegan:Connect(function(i) if isPress(i) then dragWheel = true wheelFrom(i.Position) end end)
    vHit.InputBegan:Connect(function(i) if isPress(i) then dragV = true vFrom(i.Position.X) end end)
    track(UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        if dragWheel then wheelFrom(i.Position) end
        if dragV then vFrom(i.Position.X) end
    end))
    track(UserInputService.InputEnded:Connect(function(i)
        if isPress(i) then dragWheel, dragV = false, false end
    end))

    hexBox.FocusLost:Connect(function()
        local col = hexToColor3(hexBox.Text)
        if col then
            h, s, v = col:ToHSV()
            refresh(true)
        else
            refresh(false)
        end
    end)

    function api.Set(col)
        h, s, v = col:ToHSV()
        refresh(false)
    end

    refresh(false)
    return api
end

-- ---------- Toggle (checkbox, + optional color wheel) ----------
local function createToggle(parent, label, default, order, callback, stateKey, colorOpt)
    local row = glassRow(parent, order, ROW)
    row.ClipsDescendants = true

    local box = new("Frame", {
        Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(0, 5),
        BackgroundColor3 = default and C.Accent or C.Off, BorderSizePixel = 0, Active = false, ZIndex = 5,
    }, row)
    stroke(box, C.Black)
    gloss(box)

    local lbl = new("TextLabel", {
        Size = UDim2.new(1, colorOpt and -86 or -60, 0, ROW), Position = UDim2.fromOffset(18, 0),
        BackgroundTransparency = 1, Text = label, TextColor3 = C.Text, TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
        Active = false, ZIndex = 4,
    }, row)
    fontMed(lbl)

    local isOn = default
    local function update(val, silent)
        isOn = val
        tween(box, 0.1, { BackgroundColor3 = val and C.Accent or C.Off })
        if callback then callback(val, silent) end
        refreshIsland()
    end

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, ROW), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 6,
    }, row)
    hoverLabel(hit, lbl)
    hit.MouseButton1Click:Connect(function() update(not isOn) end)

    local badge = new("TextLabel", {
        Size = UDim2.fromOffset(56, ROW), AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, colorOpt and -28 or -2, 0, 0), BackgroundTransparency = 1,
        Text = "", TextColor3 = C.TextDim, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right,
        Visible = false, ZIndex = 5, Active = false,
    }, row)
    fontMed(badge)

    local entry = { id = label, label = label, key = nil }
    entry.isOn = function() return isOn end
    entry.toggle = function() update(not isOn) end
    entry.refreshBadge = function()
        if Binding == entry then
            badge.Visible = true
            badge.Text = "[...]"
            badge.TextColor3 = C.Accent
        elseif entry.key then
            badge.Visible = true
            badge.Text = "[" .. keyDisplay(entry.key) .. "]"
            badge.TextColor3 = C.TextDim
        else
            badge.Visible = false
        end
    end
    BindList[#BindList + 1] = entry

    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton3 then startBinding(entry) end
    end)

    if colorOpt then
        local currentColor = hexToColor3(colorOpt.hex) or C.Accent
        local picker, expanded = nil, false

        local body = new("Frame", {
            Size = UDim2.new(1, 0, 0, BODY), Position = UDim2.fromOffset(0, ROW + 2),
            BackgroundColor3 = C.Side, BorderSizePixel = 0, Visible = false, ZIndex = 3,
        }, row)
        stroke(body, C.Black)

        local swatch = new("TextButton", {
            Size = UDim2.fromOffset(20, 10), Position = UDim2.new(1, -20, 0, 5),
            BackgroundColor3 = currentColor, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 8,
        }, row)
        stroke(swatch, C.Black)
        gloss(swatch)

        swatch.MouseButton1Click:Connect(function()
            expanded = not expanded
            if expanded then
                if not picker then
                    picker = buildPicker(body, currentColor, function(col, hex)
                        currentColor = col
                        swatch.BackgroundColor3 = col
                        colorOpt.onColor(col, hex)
                    end)
                end
                body.Visible = true
                tween(row, 0.2, { Size = UDim2.new(1, 0, 0, ROW + 2 + BODY + 2) }, Enum.EasingStyle.Quint)
            else
                tween(row, 0.18, { Size = UDim2.new(1, 0, 0, ROW) }, Enum.EasingStyle.Quint)
                task.delay(0.19, function() if not expanded then body.Visible = false end end)
            end
        end)

        widgetRegistry[colorOpt.stateKey] = {
            Set = function(hex)
                local col = hexToColor3(hex)
                if not col then return end
                currentColor = col
                swatch.BackgroundColor3 = col
                if picker then picker.Set(col) end
                colorOpt.onColor(col, color3ToHex(col))
            end,
            Get = function() return color3ToHex(currentColor) end,
        }
    end

    local widget = {
        Set = function(val) update(val, true) end,
        Get = function() return isOn end,
    }
    if stateKey then widgetRegistry[stateKey] = widget end
    return widget
end

local function glassBox(parent, size, pos, text, placeholder)
    local box = new("TextBox", {
        Size = size, Position = pos, BackgroundColor3 = C.Field,
        Text = text or "", TextColor3 = C.Text, PlaceholderText = placeholder or "", PlaceholderColor3 = C.TextFaint,
        TextSize = 11, ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 6,
    }, parent)
    stroke(box, C.Black)
    gloss(box, Color3.fromRGB(190, 190, 190))
    fontMed(box)
    return box
end

local function createInput(parent, label, default, order, callback, stateKey)
    local row = glassRow(parent, order, 22)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -72, 1, 0), BackgroundTransparency = 1,
        Text = label, TextColor3 = C.Text, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Active = false, ZIndex = 4,
    }, row)
    fontMed(lbl)

    local box = glassBox(row, UDim2.fromOffset(64, 18), UDim2.new(1, -64, 0.5, -9), tostring(default), "value")
    box.FocusLost:Connect(function()
        local num = tonumber(box.Text)
        if num then callback(num, false) else box.Text = tostring(default) end
    end)

    local widget = {
        Set = function(val) box.Text = tostring(val) callback(val, true) end,
        Get = function() return tonumber(box.Text) or default end,
    }
    if stateKey then widgetRegistry[stateKey] = widget end
    return widget
end

local function createButton(parent, label, order, callback, danger)
    local row = glassRow(parent, order, 22)
    local btn = new("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Field, Text = label,
        TextColor3 = C.TextDim, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6,
    }, row)
    stroke(btn, C.Black)
    gloss(btn, Color3.fromRGB(170, 170, 170))
    fontMed(btn)
    local hoverCol = danger and C.Red or C.White
    btn.MouseEnter:Connect(function()
        tween(btn, 0.1, { BackgroundColor3 = C.FieldHov, TextColor3 = hoverCol })
    end)
    btn.MouseLeave:Connect(function()
        tween(btn, 0.12, { BackgroundColor3 = C.Field, TextColor3 = C.TextDim })
    end)
    btn.MouseButton1Down:Connect(function() tween(btn, 0.05, { BackgroundColor3 = C.Bg }) end)
    btn.MouseButton1Click:Connect(callback)
end

local function createTextAction(parent, label, placeholder, order, callback)
    local row = glassRow(parent, order, 22)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -130, 1, 0), BackgroundTransparency = 1,
        Text = label, TextColor3 = C.Text, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Active = false, ZIndex = 4,
    }, row)
    fontMed(lbl)

    local box = glassBox(row, UDim2.fromOffset(78, 18), UDim2.new(1, -78 - 4 - 28, 0.5, -9), "", placeholder)

    local btn = new("TextButton", {
        Size = UDim2.fromOffset(28, 18), Position = UDim2.new(1, -28, 0.5, -9),
        BackgroundColor3 = C.Field, Text = "go",
        TextColor3 = C.Accent, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6,
    }, row)
    stroke(btn, C.Black)
    gloss(btn, Color3.fromRGB(170, 170, 170))
    fontBold(btn)
    btn.MouseEnter:Connect(function() tween(btn, 0.1, { BackgroundColor3 = C.FieldHov }) end)
    btn.MouseLeave:Connect(function() tween(btn, 0.1, { BackgroundColor3 = C.Field }) end)
    btn.MouseButton1Click:Connect(function() callback(box.Text) end)
    return box
end

-- ---------- Selector (LMB = next, RMB = previous) ----------
local function createSelector(parent, label, options, default, order, callback, stateKey)
    local row = glassRow(parent, order, 22)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -112, 1, 0), BackgroundTransparency = 1,
        Text = label, TextColor3 = C.Text, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd, Active = false, ZIndex = 4,
    }, row)
    fontMed(lbl)

    local idx = table.find(options, default) or 1
    local btn = new("TextButton", {
        Size = UDim2.fromOffset(106, 18), Position = UDim2.new(1, -106, 0.5, -9),
        BackgroundColor3 = C.Field, Text = "< " .. options[idx] .. " >",
        TextColor3 = C.Accent, TextSize = 10, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6,
    }, row)
    stroke(btn, C.Black)
    gloss(btn, Color3.fromRGB(170, 170, 170))
    fontMed(btn)
    btn.MouseEnter:Connect(function() tween(btn, 0.1, { BackgroundColor3 = C.FieldHov }) end)
    btn.MouseLeave:Connect(function() tween(btn, 0.1, { BackgroundColor3 = C.Field }) end)

    local function setIdx(i, silent)
        idx = ((i - 1) % #options) + 1
        btn.Text = "< " .. options[idx] .. " >"
        if callback then callback(options[idx], silent) end
    end
    btn.MouseButton1Click:Connect(function() setIdx(idx + 1, false) end)
    btn.MouseButton2Click:Connect(function() setIdx(idx - 1, false) end)

    local widget = {
        Set = function(val)
            local i = table.find(options, val)
            if i then setIdx(i, true) end
        end,
        Get = function() return options[idx] end,
    }
    if stateKey then widgetRegistry[stateKey] = widget end
    return widget
end

local function createSlider(parent, label, min, max, default, order, callback, onRelease, stateKey)
    default = math.clamp(default or min, min, max)
    local row = glassRow(parent, order, 32)

    local lbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 14), BackgroundTransparency = 1,
        Text = label, TextColor3 = C.Text, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
        Active = false, ZIndex = 4,
    }, row)
    fontMed(lbl)

    local trackF = new("Frame", {
        Size = UDim2.new(1, 0, 0, 10), Position = UDim2.fromOffset(0, 18),
        BackgroundColor3 = C.Field, BorderSizePixel = 0, ZIndex = 4,
    }, row)
    stroke(trackF, C.Black)
    local rel0 = (default - min) / (max - min)
    local fill = new("Frame", {
        Size = UDim2.fromScale(rel0, 1), BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 5, Active = false,
    }, trackF)
    gloss(fill)

    local valLbl = new("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = tostring(default), TextColor3 = C.White, TextSize = 10, TextStrokeTransparency = 0.4,
        TextStrokeColor3 = C.Black, Active = false, ZIndex = 7,
    }, trackF)
    fontBold(valLbl)

    local current, dragging = default, false

    local function setValue(val, silent)
        val = math.clamp(math.floor(val + 0.5), min, max)
        current = val
        local rel = (val - min) / (max - min)
        fill.Size = UDim2.fromScale(rel, 1)
        valLbl.Text = tostring(val)
        if callback then callback(val, silent) end
    end
    local function updateFromX(x)
        local rel = math.clamp((x - trackF.AbsolutePosition.X) / math.max(1, trackF.AbsoluteSize.X), 0, 1)
        setValue(min + (max - min) * rel, false)
    end

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 14), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = 8,
    }, row)
    hoverLabel(hit, lbl)
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            updateFromX(input.Position.X)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            updateFromX(input.Position.X)
        end
    end))
    track(UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                if onRelease then onRelease(current) end
            end
        end
    end))

    local widget = {
        Set = function(val) setValue(val, true) end,
        Get = function() return current end,
    }
    if stateKey then widgetRegistry[stateKey] = widget end
    return widget
end

-- ==================== PAGES (categories) ====================
local VisualPage    = createTab("Visuals",   1)
local MainPage      = createTab("Main",      2)
local MovementPage  = createTab("Movement",  3)
local CosmeticsPage = createTab("Cosmetics", 4)
local FunPage       = createTab("Fun",       5)
local SettingsPage  = createTab("Settings",  6)
setActiveTab("Visuals")

-- ==================== HELPERS: roles / objects ====================
local function roleOf(plr)
    local t = plr.Team and plr.Team.Name:lower() or ""
    if t:find("killer") then return "killer" end
    if t:find("survivor") then return "survivor" end
    return nil
end

local function myRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local OBJ_DEFS = {
    { key = "ESP_Generators", id = "gen",    pat = { "generator" } },
    { key = "ESP_Hooks",      id = "hook",   pat = { "hook" } },
    { key = "ESP_Pallets",    id = "pallet", pat = { "pallet" } },
    { key = "ESP_Gates",      id = "gate",   pat = { "gate", "exit" } },
}
local ObjectsFound = { gen = {}, hook = {}, pallet = {}, gate = {} }

local function collectObjects()
    local out = { gen = {}, hook = {}, pallet = {}, gate = {} }
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and not Players:GetPlayerFromCharacter(obj) then
            local nm = obj.Name:lower()
            for _, d in ipairs(OBJ_DEFS) do
                local hit = false
                for _, p in ipairs(d.pat) do
                    if nm:find(p, 1, true) then hit = true break end
                end
                if hit then out[d.id][#out[d.id] + 1] = obj break end
            end
        end
    end
    ObjectsFound = out
    return out
end

-- ==================== FEATURE LOGIC ====================
local fbCache
local function setFullbright(on)
    if on then
        fbCache = {
            Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
            Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
            FogEnd = Lighting.FogEnd, ExposureCompensation = Lighting.ExposureCompensation,
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

local noShadowCache, noShadowConn = nil, nil
local function setNoShadows(on)
    State.NoShadows = on
    if on then
        noShadowCache = { GlobalShadows = Lighting.GlobalShadows, Effects = {} }
        Lighting.GlobalShadows = false
        for _, obj in ipairs(Lighting:GetDescendants()) do
            if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect")
            or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
                if obj.Enabled and obj.Name ~= "AbaddonSandyCC" then
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
                if obj:IsA("BasePart") and obj.CastShadow then obj.CastShadow = false end
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
                        elseif data.kind == "density" then obj.Density = data.value end
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

local texRestore, texConn = {}, nil
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
            texRestore[#texRestore + 1] = function() if obj.Parent then obj.Transparency = t end end
        end
        return
    end
    if obj:IsA("SurfaceAppearance") then
        local cm = obj.ColorMap
        if cm ~= "" then
            obj.ColorMap = ""
            texRestore[#texRestore + 1] = function() if obj.Parent then obj.ColorMap = cm end end
        end
        return
    end
    if obj:IsA("MeshPart") then
        local tid = obj.TextureID
        if tid ~= "" then
            obj.TextureID = ""
            texRestore[#texRestore + 1] = function() if obj.Parent then obj.TextureID = tid end end
        end
    end
    if obj:IsA("BasePart") then
        local mat = obj.Material
        if mat ~= Enum.Material.SmoothPlastic then
            obj.Material = Enum.Material.SmoothPlastic
            texRestore[#texRestore + 1] = function() if obj.Parent then obj.Material = mat end end
        end
    end
end

local function setNoTextures(on, silent)
    State.NoTextures = on
    if on then
        texRestore = {}
        for _, obj in ipairs(workspace:GetDescendants()) do pcall(stripOneTexture, obj) end
        if texConn then texConn:Disconnect() end
        texConn = workspace.DescendantAdded:Connect(function(obj)
            if not State.NoTextures then return end
            task.defer(function()
                if obj.Parent and State.NoTextures then pcall(stripOneTexture, obj) end
            end)
        end)
    else
        if texConn then texConn:Disconnect() texConn = nil end
        for _, fn in ipairs(texRestore) do pcall(fn) end
        texRestore = {}
    end
    if not silent then pushLog("No Textures: " .. (on and "enabled" or "disabled"), "info") end
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
local noclipTouched = setmetatable({}, { __mode = "k" })
local COLLIDE_PARTS = { Head = true, Torso = true, UpperTorso = true, LowerTorso = true }

local function restoreNoclip()
    for part in pairs(noclipTouched) do
        noclipTouched[part] = nil
        if part and part.Parent then part.CanCollide = true end
    end
    local char = LocalPlayer.Character
    if char then
        for _, p in ipairs(char:GetChildren()) do
            if p:IsA("BasePart") and COLLIDE_PARTS[p.Name] then p.CanCollide = true end
        end
    end
end
_G.AbaddonRestoreCollide = restoreNoclip

local function setNoclip(on)
    State.Noclip = on
    if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    if not on then
        restoreNoclip()
        task.defer(restoreNoclip)
        return
    end
    noclipConn = track(RunService.Stepped:Connect(function()
        if not State.Noclip then return end
        local char = LocalPlayer.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                noclipTouched[p] = true
                p.CanCollide = false
            end
        end
    end))
end

-- ==================== WALKSPEED LOCK (+ Sandevistan lock) ====================
local wsHumConn
local function enforceWalkSpeed(hum)
    local target
    if State.Sandevistan then
        target = SANDY_SPEED
    elseif State.WalkSpeedLock and State.WalkSpeed ~= 16 then
        target = State.WalkSpeed
    end
    if target and hum and hum.WalkSpeed ~= target then hum.WalkSpeed = target end
end

track(RunService.Stepped:Connect(function()
    local c = LocalPlayer.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hum then enforceWalkSpeed(hum) end
end))

local function hookWalkSpeed(char)
    if wsHumConn then wsHumConn:Disconnect() wsHumConn = nil end
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
    if not hum then return end
    wsHumConn = track(hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function() enforceWalkSpeed(hum) end))
end
task.spawn(hookWalkSpeed, LocalPlayer.Character)

-- ==================== FAKE LAG ====================
local fakeLagToken = 0
local fakeLagWidget

local function setOutLimit(v)
    return (pcall(function()
        game:GetService("NetworkClient"):SetOutgoingKBPSLimit(v)
    end))
end

local function setFakeLag(on)
    State.FakeLag = on
    fakeLagToken = fakeLagToken + 1
    local my = fakeLagToken
    if not on then
        setOutLimit(math.huge)
        return
    end
    task.spawn(function()
        while State.FakeLag and fakeLagToken == my do
            if not setOutLimit(1) then
                pushLog("Fake Lag: not supported by this executor", "error")
                if fakeLagWidget then fakeLagWidget.Set(false) end
                break
            end
            task.wait(math.max(State.FakeLagTime, 20) / 1000)
            setOutLimit(math.huge)
            task.wait(0.06)
        end
        if fakeLagToken == my then setOutLimit(math.huge) end
    end)
end

_G.AbaddonFakeLagStop = function()
    fakeLagToken = fakeLagToken + 1
    State.FakeLag = false
    setOutLimit(math.huge)
end

-- ==================== CROSSHAIR (shifted 1 cm left) ====================
local crosshairRoot
local function buildCrosshair()
    if crosshairRoot then crosshairRoot:Destroy() crosshairRoot = nil end
    if not State.Crosshair then return end
    local len = math.clamp(State.CrosshairSize or 10, 2, 80)
    local gap, thick = 4, 2
    local root = new("Frame", {
        Name = "AbaddonCrosshair", Size = UDim2.fromOffset(0, 0),
        Position = UDim2.new(0.5, CROSSHAIR_X, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1, ZIndex = 500, Active = false, Visible = not State.Open,
    }, ScreenGui)
    local function bar(w, h, x, y)
        local f = new("Frame", {
            Size = UDim2.fromOffset(w, h), Position = UDim2.fromOffset(x, y),
            BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 500, Active = false,
        }, root)
        new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1, Transparency = 0.3 }, f)
    end
    bar(thick, len, -thick / 2, -gap - len)
    bar(thick, len, -thick / 2, gap)
    bar(len, thick, -gap - len, -thick / 2)
    bar(len, thick, gap, -thick / 2)
    crosshairRoot = root
end

local function setCrosshair(on)
    State.Crosshair = on
    buildCrosshair()
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
            pushLog(string.format("TP to %.0f, %.0f", hit.Position.X, hit.Position.Z), "success")
        end
    end)
end

local function gotoPlayer(name)
    if not name or name == "" then pushLog("Enter a nickname to teleport to", "warn") return end
    name = name:lower()
    local found
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Name:lower():sub(1, #name) == name then found = plr break end
    end
    if not found then pushLog("Player not found: " .. name, "error") return end
    local thrp = found.Character and found.Character:FindFirstChild("HumanoidRootPart")
    local myhrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if thrp and myhrp then
        myhrp.CFrame = CFrame.new(thrp.Position + Vector3.new(0, 3, 0))
        pushLog("Teleported to " .. found.Name, "success")
    else
        pushLog("Target not loaded yet", "error")
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

    local okSig, signal = pcall(function() return RunService.PreSimulation end)
    if not okSig or not signal then signal = RunService.Stepped end

    local smoothedLook = nil
    backWalkConn = signal:Connect(function(_, dt)
        dt = type(dt) == "number" and dt or 1 / 60
        if State.Spin then return end
        local c = LocalPlayer.Character
        if not c then return end
        local h   = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not h or not hrp or h.Health <= 0 or h.Sit then return end
        h.AutoRotate = false

        local md = h.MoveDirection
        if md.Magnitude > 0.05 then
            local target = Vector3.new(-md.X, 0, -md.Z)
            if target.Magnitude > 0.01 then
                target = target.Unit
                smoothedLook = smoothedLook and smoothedLook:Lerp(target, math.clamp(dt * 12, 0, 1)) or target
                if smoothedLook.Magnitude < 0.01 then smoothedLook = target end
                local pos = hrp.Position
                hrp.CFrame = CFrame.lookAt(pos, pos + smoothedLook)
                hrp.AssemblyAngularVelocity = Vector3.zero
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

local cam = workspace.CurrentCamera
local function setCameraFOV(value)
    State.CameraFOV = value
    if not cam then cam = workspace.CurrentCamera end
    if cam then cam.FieldOfView = value end
end

-- ==================== FORCE THIRD PERSON + SHIFTLOCK ====================
local shiftApplied = false
local function releaseShiftLock()
    if not shiftApplied then return end
    shiftApplied = false
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    local c = LocalPlayer.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.CameraOffset = Vector3.zero
        if not State.Spin and not State.BackWalk and not State.Fly then hum.AutoRotate = true end
    end
end

local function setThirdPerson(on)
    State.ThirdPerson = on
    if not on then
        releaseShiftLock()
        pcall(function()
            LocalPlayer.CameraMinZoomDistance = 0.5
            LocalPlayer.CameraMaxZoomDistance = 128
        end)
    end
end

track(RunService.RenderStepped:Connect(function()
    if not State.ThirdPerson then return end
    pcall(function()
        LocalPlayer.CameraMode = Enum.CameraMode.Classic
        LocalPlayer.CameraMinZoomDistance = 8
        LocalPlayer.CameraMaxZoomDistance = math.max(State.MaxZoom, 12)
    end)

    local c = LocalPlayer.Character
    local hum = c and c:FindFirstChildOfClass("Humanoid")
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    local wc = workspace.CurrentCamera
    if not State.ShiftLock or State.Open or not hum or not hrp or not wc
        or hum.Health <= 0 or hum.Sit or hum.PlatformStand
        or State.Fly or State.Spin or State.BackWalk
        or wc.CameraSubject ~= hum then
        releaseShiftLock()
        return
    end

    shiftApplied = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    hum.AutoRotate = false
    hum.CameraOffset = Vector3.new(1.75, 0, 0)
    local look = wc.CFrame.LookVector
    hrp.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.atan2(-look.X, -look.Z), 0)
end))
onCleanup(function() setThirdPerson(false) end)

-- ==================== FLY ====================
local flyBodyVel, flyBodyGyro, flyConn
local flyKeys = { W = false, A = false, S = false, D = false, Space = false, LCtrl = false }

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
        flyBodyVel.Velocity = move.Magnitude > 0 and move.Unit * State.FlySpeed or Vector3.zero
    end)
end

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    local k = input.KeyCode
    if k == Enum.KeyCode.W then flyKeys.W = true end
    if k == Enum.KeyCode.A then flyKeys.A = true end
    if k == Enum.KeyCode.S then flyKeys.S = true end
    if k == Enum.KeyCode.D then flyKeys.D = true end
    if k == Enum.KeyCode.Space then flyKeys.Space = true end
    if k == Enum.KeyCode.LeftControl then flyKeys.LCtrl = true end
end))
track(UserInputService.InputEnded:Connect(function(input)
    local k = input.KeyCode
    if k == Enum.KeyCode.W then flyKeys.W = false end
    if k == Enum.KeyCode.A then flyKeys.A = false end
    if k == Enum.KeyCode.S then flyKeys.S = false end
    if k == Enum.KeyCode.D then flyKeys.D = false end
    if k == Enum.KeyCode.Space then flyKeys.Space = false end
    if k == Enum.KeyCode.LeftControl then flyKeys.LCtrl = false end
end))

local antiflingConn
local function setAntiFling(on)
    State.AntiFling = on
    if antiflingConn then antiflingConn:Disconnect() antiflingConn = nil end
    if not on then return end
    antiflingConn = RunService.Heartbeat:Connect(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local vel = hrp.AssemblyLinearVelocity
        if vel.Magnitude > 200 then hrp.AssemblyLinearVelocity = vel.Unit * 100 end
    end)
end

track(RunService.Heartbeat:Connect(function()
    if State.CustomTime and Lighting.ClockTime ~= State.ClockTime then
        Lighting.ClockTime = State.ClockTime
    end
end))

local function serverHop()
    pushLog("Server Hop: requesting...", "info")
    local ok, result = pcall(function()
        local url = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(game.PlaceId)
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if not ok or not result or not result.data then
        pushLog("Server Hop: failed to fetch server list", "error")
        return
    end
    local servers = {}
    for _, s in ipairs(result.data) do
        if s.playing < s.maxPlayers and s.id ~= game.JobId then servers[#servers + 1] = s.id end
    end
    if #servers == 0 then pushLog("Server Hop: no free servers", "warn") return end
    pushLog("Server Hop: teleporting...", "success")
    TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], LocalPlayer)
end

local function rejoin()
    pushLog("Rejoin...", "info")
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

-- ==================== GAMEPLAY: tracers ====================
local tracerLines = {}
local tracerWidget

local function clearTracers()
    for p, l in pairs(tracerLines) do
        pcall(function() l:Remove() end)
        tracerLines[p] = nil
    end
end
onCleanup(clearTracers)

local function setTracers(on)
    State.Tracers = on
    if on and not (Drawing and Drawing.new) then
        pushLog("Tracers: Drawing API not supported by this executor", "error")
        State.Tracers = false
        if tracerWidget then task.defer(function() tracerWidget.Set(false) end) end
        return
    end
    if not on then clearTracers() end
end

Players.PlayerRemoving:Connect(function(plr)
    local l = tracerLines[plr]
    if l then pcall(function() l:Remove() end) tracerLines[plr] = nil end
end)

track(RunService.RenderStepped:Connect(function()
    if not State.Tracers then return end
    if not (Drawing and Drawing.new) then return end
    local c = workspace.CurrentCamera
    if not c then return end
    local vs = c.ViewportSize
    local origin = Vector2.new(vs.X / 2, vs.Y)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local role = roleOf(plr)
            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            local ln = tracerLines[plr]
            if hrp and role then
                if not ln then
                    local ok, l = pcall(function()
                        local x = Drawing.new("Line")
                        x.Thickness = 1.5
                        x.Transparency = 1
                        return x
                    end)
                    if ok then ln = l tracerLines[plr] = l end
                end
                if ln then
                    local sp, onScreen = c:WorldToViewportPoint(hrp.Position)
                    if onScreen and sp.Z > 0 then
                        ln.From = origin
                        ln.To = Vector2.new(sp.X, sp.Y)
                        ln.Color = role == "killer" and ESPColors.Killer or ESPColors.Survivor
                        ln.Visible = true
                    else
                        ln.Visible = false
                    end
                end
            elseif ln then
                ln.Visible = false
            end
        end
    end
end))

-- ==================== GAMEPLAY: killer alert ====================
local AlertLbl = new("TextLabel", {
    Name = "AbaddonAlert", Size = UDim2.fromOffset(260, 22), Position = UDim2.new(0.5, 0, 0, 44),
    AnchorPoint = Vector2.new(0.5, 0), BackgroundColor3 = C.Bg, BorderSizePixel = 0,
    Text = "", TextColor3 = C.Red, TextSize = 12, Visible = false, ZIndex = 270, Active = false,
}, ScreenGui)
stroke(AlertLbl, C.Red)
fontBold(AlertLbl)

local lastAlertLog = 0
task.spawn(function()
    while ScreenGui.Parent do
        local show = false
        if State.KillerAlert and roleOf(LocalPlayer) ~= "killer" then
            local me = myRoot()
            if me then
                local best
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= LocalPlayer and roleOf(plr) == "killer" then
                        local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local d = (hrp.Position - me.Position).Magnitude
                            if not best or d < best then best = d end
                        end
                    end
                end
                if best and best <= State.AlertRange then
                    show = true
                    AlertLbl.Text = string.format("! KILLER NEARBY  %d studs !", math.floor(best))
                    if os.clock() - lastAlertLog > 3 then
                        lastAlertLog = os.clock()
                        pushLog("Killer nearby!", "error")
                    end
                end
            end
        end
        AlertLbl.Visible = show
        task.wait(0.2)
    end
end)

-- ==================== GAMEPLAY: radar ====================
local RADAR_SIZE = 150
local RadarFrame = new("Frame", {
    Name = "AbaddonRadar", Size = UDim2.fromOffset(RADAR_SIZE, RADAR_SIZE),
    Position = UDim2.new(0, 12, 1, -(RADAR_SIZE + 20)),
    BackgroundColor3 = C.Bg, BackgroundTransparency = 0.15, BorderSizePixel = 0,
    ClipsDescendants = true, Visible = false, ZIndex = 250,
}, ScreenGui)
stroke(RadarFrame, C.Black)
topGradient(RadarFrame, 2)
new("Frame", {
    Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 0.5, 0), BackgroundColor3 = C.Border,
    BorderSizePixel = 0, ZIndex = 251, Active = false,
}, RadarFrame)
new("Frame", {
    Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0.5, 0, 0, 0), BackgroundColor3 = C.Border,
    BorderSizePixel = 0, ZIndex = 251, Active = false,
}, RadarFrame)
new("Frame", {
    Size = UDim2.fromOffset(5, 5), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 265, Active = false,
}, RadarFrame)

local radarDots = {}
local function getDot(i)
    local d = radarDots[i]
    if not d then
        d = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, ZIndex = 262, Active = false,
        }, RadarFrame)
        radarDots[i] = d
    end
    return d
end

local radarT = 0
track(RunService.RenderStepped:Connect(function(dt)
    if not State.Radar then
        if RadarFrame.Visible then RadarFrame.Visible = false end
        return
    end
    RadarFrame.Visible = true
    radarT = radarT + dt
    if radarT < 0.03 then return end
    radarT = 0

    local c = workspace.CurrentCamera
    local me = myRoot()
    if not c or not me then return end
    local look = c.CFrame.LookVector
    local m = math.sqrt(look.X * look.X + look.Z * look.Z)
    if m < 0.001 then return end
    local fx, fz = look.X / m, look.Z / m
    local rx, rz = -fz, fx
    local half = RADAR_SIZE / 2
    local range = math.max(State.RadarRange, 10)
    local n = 0

    local function plot(pos, col, clamp, size)
        local dx, dz = pos.X - me.Position.X, pos.Z - me.Position.Z
        local px = (dx * rx + dz * rz) / range * half
        local py = -(dx * fx + dz * fz) / range * half
        local dist = math.sqrt(px * px + py * py)
        if dist > half - 4 then
            if not clamp then return end
            px, py = px / dist * (half - 4), py / dist * (half - 4)
        end
        n = n + 1
        local d = getDot(n)
        d.Visible = true
        d.Position = UDim2.new(0.5, px, 0.5, py)
        d.Size = UDim2.fromOffset(size, size)
        d.BackgroundColor3 = col
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local role = roleOf(plr)
            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if role and hrp then
                if role == "killer" then plot(hrp.Position, ESPColors.Killer, true, 6)
                else plot(hrp.Position, ESPColors.Survivor, false, 5) end
            end
        end
    end
    for _, g in ipairs(ObjectsFound.gen) do
        if g.Parent then plot(g:GetPivot().Position, ESPColors.Generator, false, 4) end
    end
    for i = n + 1, #radarDots do radarDots[i].Visible = false end
end))

-- ==================== GAMEPLAY: quick teleports ====================
local function tpTo(pos, label)
    local hrp = myRoot()
    if not hrp then pushLog("Character not loaded", "error") return end
    hrp.CFrame = CFrame.new(pos + Vector3.new(0, 4, 0))
    pushLog("Teleported: " .. label, "success")
end

local function nearestOf(list)
    local me = myRoot()
    if not me then return nil end
    local best, bd
    for _, o in ipairs(list) do
        if o.Parent then
            local p = o:GetPivot().Position
            local d = (p - me.Position).Magnitude
            if not bd or d < bd then best, bd = p, d end
        end
    end
    return best
end

local function tpNearestGen()
    local p = nearestOf(collectObjects().gen)
    if p then tpTo(p, "nearest generator") else pushLog("No generators found", "warn") end
end

local function tpNearestGate()
    local p = nearestOf(collectObjects().gate)
    if p then tpTo(p, "exit gate") else pushLog("No gates found", "warn") end
end

local function tpSafeSpot()
    local objs = collectObjects()
    local killers = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and roleOf(plr) == "killer" then
            local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp then killers[#killers + 1] = hrp.Position end
        end
    end
    if #killers == 0 then pushLog("No killer found", "warn") return end
    local bestPos, bestScore
    for _, g in ipairs(objs.gen) do
        if g.Parent then
            local p = g:GetPivot().Position
            local minD
            for _, kp in ipairs(killers) do
                local d = (kp - p).Magnitude
                if not minD or d < minD then minD = d end
            end
            if not bestScore or minD > bestScore then bestPos, bestScore = p, minD end
        end
    end
    if bestPos then tpTo(bestPos, "far from killer") else pushLog("No generators found", "warn") end
end

-- ==================== GAMEPLAY: spectate ====================
local function spectate(name)
    if not name or name == "" then pushLog("Enter a nickname to spectate", "warn") return end
    name = name:lower()
    local found
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Name:lower():sub(1, #name) == name then found = plr break end
    end
    if not found then pushLog("Player not found: " .. name, "error") return end
    local hum = found.Character and found.Character:FindFirstChildOfClass("Humanoid")
    if hum and workspace.CurrentCamera then
        workspace.CurrentCamera.CameraSubject = hum
        pushLog("Spectating " .. found.Name, "success")
    else
        pushLog("Target not loaded yet", "error")
    end
end

local function unspectate()
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and workspace.CurrentCamera then
        workspace.CurrentCamera.CameraSubject = hum
        pushLog("Spectate stopped", "info")
    end
end

-- ==================== COSMETICS: shared helpers ====================
local function cs(...)
    local args, kps = { ... }, {}
    for i, c in ipairs(args) do kps[i] = ColorSequenceKeypoint.new((i - 1) / (#args - 1), c) end
    return ColorSequence.new(kps)
end
local function ns(...)
    local kps = {}
    for i, p in ipairs({ ... }) do kps[i] = NumberSequenceKeypoint.new(p[1], p[2]) end
    return NumberSequence.new(kps)
end
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TEX_FIRE  = "rbxasset://textures/particles/fire_main.dds"
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"

-- ==================== COSMETICS: HALO ====================
local haloPart, haloConn
local haloBeams, haloEmit, haloLight = {}, {}, nil

local function haloColor3()
    return hexToColor3(State.HaloColorHex) or rgb(255, 215, 106)
end

local function clearHalo()
    if haloConn then haloConn:Disconnect() haloConn = nil end
    if haloPart then pcall(function() haloPart:Destroy() end) haloPart = nil end
    haloBeams, haloEmit, haloLight = {}, {}, nil
end

local function updateHaloColor()
    local col = haloColor3()
    for _, e in ipairs(haloBeams) do
        if e.b.Parent then e.b.Color = ColorSequence.new(col:Lerp(C.White, e.mix)) end
    end
    for _, em in ipairs(haloEmit) do
        if em.Parent then em.Color = ColorSequence.new(col:Lerp(C.White, 0.4), col) end
    end
    if haloLight and haloLight.Parent then haloLight.Color = col end
end

local function buildHalo()
    clearHalo()
    if not State.Halo then return end
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    if not head then return end
    local col = haloColor3()

    local part = Instance.new("Part")
    part.Name = "AbaddonHalo"
    part.Size = Vector3.new(0.3, 0.3, 0.3)
    part.Transparency = 1
    part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
    part.Massless = true
    part.Parent = char

    local weld = Instance.new("Weld")
    weld.Part0, weld.Part1 = head, part
    weld.C0 = CFrame.new(0, 1.65, 0)
    weld.Parent = part
    haloPart = part

    local function ring(radius, width, transp, mixAmt, segs)
        local atts = {}
        for i = 0, segs - 1 do
            local a = i / segs * 2 * math.pi
            local at = Instance.new("Attachment")
            at.Position = Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
            at.Parent = part
            atts[i + 1] = at
        end
        for i = 1, segs do
            local b = Instance.new("Beam")
            b.Attachment0, b.Attachment1 = atts[i], atts[i % segs + 1]
            b.Width0, b.Width1 = width, width
            b.FaceCamera = true
            b.LightEmission = 1
            b.LightInfluence = 0
            b.Segments = 1
            b.Transparency = NumberSequence.new(transp)
            local mix = mixAmt * (0.5 + 0.5 * math.sin(i / segs * math.pi * 6))
            b.Color = ColorSequence.new(col:Lerp(C.White, mix))
            b.Parent = part
            haloBeams[#haloBeams + 1] = { b = b, mix = mix }
        end
        return atts
    end

    local main = ring(1.15, 0.10, 0.05, 0.6, 36)  -- bright core ring
    ring(1.15, 0.45, 0.86, 0.2, 36)               -- soft glow
    ring(0.85, 0.04, 0.35, 0.9, 28)               -- thin inner ring

    for i = 1, #main, 4 do
        local em = Instance.new("ParticleEmitter")
        em.Texture = TEX_SPARK
        em.Rate = 3
        em.Lifetime = NumberRange.new(1, 1.8)
        em.Speed = NumberRange.new(0.2, 0.8)
        em.SpreadAngle = Vector2.new(30, 30)
        em.EmissionDirection = Enum.NormalId.Top
        em.Acceleration = Vector3.new(0, 0.6, 0)
        em.Size = ns({ 0, 0.18 }, { 1, 0 })
        em.Transparency = ns({ 0, 0 }, { 0.7, 0.4 }, { 1, 1 })
        em.LightEmission = 1
        em.LightInfluence = 0
        em.LockedToPart = false
        em.RotSpeed = NumberRange.new(-90, 90)
        em.Rotation = NumberRange.new(0, 360)
        em.Color = ColorSequence.new(col:Lerp(C.White, 0.4), col)
        em.Parent = main[i]
        haloEmit[#haloEmit + 1] = em
    end

    local light = Instance.new("PointLight")
    light.Brightness, light.Range, light.Color = 1.5, 9, col
    light.Parent = part
    haloLight = light

    haloConn = RunService.RenderStepped:Connect(function()
        if not weld.Parent then return end
        local t = os.clock()
        weld.C0 = CFrame.new(0, 1.65 + math.sin(t * 2) * 0.08, 0)
            * CFrame.Angles(math.rad(8) * math.sin(t * 1.3), t * 1.2, math.rad(6) * math.cos(t * 1.1))
    end)
end

local function setHalo(on)
    State.Halo = on
    buildHalo()
end
onCleanup(clearHalo)

-- ==================== COSMETICS: TRAIL ====================
local TRAIL_STYLES = { "Default", "Shadow", "Neon", "Rainbow", "Inferno", "Stardust", "Frost" }
local trailObjs, trailEmit = {}, {}

local function clearTrail()
    for _, o in ipairs(trailObjs) do pcall(function() o:Destroy() end) end
    trailObjs, trailEmit = {}, {}
end

local function mkAtt(hrp, pos)
    local a = Instance.new("Attachment")
    a.Position = pos
    a.Parent = hrp
    trailObjs[#trailObjs + 1] = a
    return a
end

local function mkTrail(hrp, y0, y1, props)
    local a0, a1 = mkAtt(hrp, Vector3.new(0, y0, 0)), mkAtt(hrp, Vector3.new(0, y1, 0))
    local t = Instance.new("Trail")
    t.Attachment0, t.Attachment1 = a0, a1
    t.FaceCamera = true
    t.MinLength = 0.05
    for k, v in pairs(props) do t[k] = v end
    t.Parent = hrp
    trailObjs[#trailObjs + 1] = t
    return t
end

local function mkEmit(hrp, y, props, rate, idle)
    local at = mkAtt(hrp, Vector3.new(0, y, 0))
    local e = Instance.new("ParticleEmitter")
    e.LockedToPart = false
    for k, v in pairs(props) do e[k] = v end
    e.Rate = rate
    e.Parent = at
    trailEmit[#trailEmit + 1] = { e = e, base = rate, idle = idle or 0 }
    return e
end

local TrailBuilders = {}

TrailBuilders.Default = function(hrp)
    mkTrail(hrp, 0.9, -0.9, {
        Lifetime = 0.45, LightEmission = 0.6,
        Color = cs(C.White, rgb(180, 200, 255)),
        Transparency = ns({ 0, 0.25 }, { 1, 1 }),
        WidthScale = ns({ 0, 1 }, { 1, 0 }),
    })
end

TrailBuilders.Shadow = function(hrp)
    -- dense dark smoke hugging the floor
    mkEmit(hrp, -2.8, {
        Texture = TEX_SMOKE, Color = cs(rgb(22, 22, 28), rgb(0, 0, 0)),
        Size = ns({ 0, 2.6 }, { 1, 6.5 }),
        Transparency = ns({ 0, 0.4 }, { 0.6, 0.7 }, { 1, 1 }),
        Lifetime = NumberRange.new(1.8, 2.8), Speed = NumberRange.new(0.5, 2.5),
        SpreadAngle = Vector2.new(90, 90), EmissionDirection = Enum.NormalId.Top,
        Drag = 2, Acceleration = Vector3.new(0, -1, 0),
        Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-30, 30),
        LightEmission = 0, LightInfluence = 0,
    }, 45, 0.3)
    mkEmit(hrp, -2.6, {
        Texture = TEX_SMOKE, Color = cs(rgb(60, 30, 90), rgb(8, 0, 18)),
        Size = ns({ 0, 3 }, { 1, 8 }),
        Transparency = ns({ 0, 0.7 }, { 1, 1 }),
        Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0.3, 1.5),
        SpreadAngle = Vector2.new(90, 90), EmissionDirection = Enum.NormalId.Top,
        Drag = 2, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-20, 20),
        LightEmission = 0.1, LightInfluence = 0,
    }, 14, 0.3)
    mkTrail(hrp, -2.4, -2.9, {
        Lifetime = 0.6, LightEmission = 0.2,
        Color = cs(rgb(0, 0, 0), rgb(50, 20, 80)),
        Transparency = ns({ 0, 0.5 }, { 1, 1 }),
        WidthScale = ns({ 0, 1 }, { 1, 0 }),
    })
end

TrailBuilders.Neon = function(hrp)
    mkTrail(hrp, 1.2, -1.2, {
        Lifetime = 0.8, LightEmission = 1,
        Color = cs(rgb(0, 255, 255), rgb(255, 0, 200), rgb(120, 60, 255)),
        Transparency = ns({ 0, 0 }, { 0.6, 0.3 }, { 1, 1 }),
        WidthScale = ns({ 0, 1 }, { 1, 0 }),
    })
    mkTrail(hrp, 0.2, -0.2, {
        Lifetime = 0.5, LightEmission = 1,
        Color = cs(C.White, rgb(180, 255, 255)),
        Transparency = ns({ 0, 0 }, { 1, 1 }),
    })
    mkEmit(hrp, 0, {
        Texture = TEX_SPARK, Color = cs(rgb(0, 255, 255), rgb(255, 0, 200)),
        Size = ns({ 0, 0.35 }, { 1, 0 }), Transparency = ns({ 0, 0 }, { 1, 1 }),
        Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(1, 3),
        SpreadAngle = Vector2.new(180, 180), LightEmission = 1, LightInfluence = 0,
    }, 30, 0.1)
end

TrailBuilders.Rainbow = function(hrp)
    mkTrail(hrp, 1.1, -1.1, {
        Lifetime = 1.0, LightEmission = 0.8,
        Color = cs(rgb(255, 40, 40), rgb(255, 150, 30), rgb(255, 240, 40), rgb(60, 255, 90),
                   rgb(40, 220, 255), rgb(70, 90, 255), rgb(190, 70, 255)),
        Transparency = ns({ 0, 0.1 }, { 1, 1 }),
        WidthScale = ns({ 0, 1 }, { 1, 0.2 }),
    })
end

TrailBuilders.Inferno = function(hrp)
    mkTrail(hrp, 1.0, -1.0, {
        Lifetime = 0.6, LightEmission = 1,
        Color = cs(rgb(255, 220, 80), rgb(255, 90, 0), rgb(90, 0, 0)),
        Transparency = ns({ 0, 0.1 }, { 0.7, 0.5 }, { 1, 1 }),
        WidthScale = ns({ 0, 1 }, { 1, 0 }),
    })
    mkEmit(hrp, -1.6, {
        Texture = TEX_FIRE, Color = cs(rgb(255, 200, 60), rgb(255, 80, 0), rgb(80, 0, 0)),
        Size = ns({ 0, 1.7 }, { 1, 0 }), Transparency = ns({ 0, 0.2 }, { 0.7, 0.6 }, { 1, 1 }),
        Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 3),
        SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top,
        Acceleration = Vector3.new(0, 6, 0), Rotation = NumberRange.new(0, 360),
        LightEmission = 1, LightInfluence = 0,
    }, 40, 0.3)
    mkEmit(hrp, -1, {
        Texture = TEX_SPARK, Color = cs(rgb(255, 150, 40), rgb(255, 40, 0)),
        Size = ns({ 0, 0.3 }, { 1, 0 }), Transparency = ns({ 0, 0 }, { 1, 1 }),
        Lifetime = NumberRange.new(0.8, 1.6), Speed = NumberRange.new(2, 5),
        SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top,
        Acceleration = Vector3.new(0, 4, 0), LightEmission = 1, LightInfluence = 0,
    }, 15, 0.2)
end

TrailBuilders.Stardust = function(hrp)
    mkTrail(hrp, 1.0, -1.0, {
        Lifetime = 1.2, LightEmission = 1,
        Color = cs(rgb(200, 150, 255), rgb(110, 90, 255), rgb(70, 200, 255)),
        Transparency = ns({ 0, 0.3 }, { 1, 1 }),
        WidthScale = ns({ 0, 1 }, { 1, 0 }),
    })
    mkEmit(hrp, 0, {
        Texture = TEX_SPARK, Color = cs(rgb(215, 160, 255), rgb(120, 200, 255)),
        Size = ns({ 0, 0.5 }, { 1, 0 }), Transparency = ns({ 0, 0 }, { 0.8, 0.3 }, { 1, 1 }),
        Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(0.5, 2),
        SpreadAngle = Vector2.new(180, 180), Rotation = NumberRange.new(0, 360),
        RotSpeed = NumberRange.new(-120, 120), LightEmission = 1, LightInfluence = 0,
    }, 45, 0.25)
end

TrailBuilders.Frost = function(hrp)
    mkTrail(hrp, 1.0, -1.0, {
        Lifetime = 0.7, LightEmission = 0.5,
        Color = cs(C.White, rgb(200, 235, 255), rgb(120, 190, 255)),
        Transparency = ns({ 0, 0.2 }, { 1, 1 }),
        WidthScale = ns({ 0, 1 }, { 1, 0 }),
    })
    mkEmit(hrp, 0.5, {
        Texture = TEX_SPARK, Color = cs(C.White, rgb(160, 210, 255)),
        Size = ns({ 0, 0.3 }, { 1, 0.05 }), Transparency = ns({ 0, 0 }, { 1, 1 }),
        Lifetime = NumberRange.new(1, 2), Speed = NumberRange.new(0.5, 2),
        SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, -2, 0),
        LightEmission = 0.8, LightInfluence = 0,
    }, 35, 0.2)
    mkEmit(hrp, -2.7, {
        Texture = TEX_SMOKE, Color = cs(rgb(215, 235, 255), rgb(150, 200, 255)),
        Size = ns({ 0, 2 }, { 1, 5 }), Transparency = ns({ 0, 0.7 }, { 1, 1 }),
        Lifetime = NumberRange.new(1.5, 2.5), Speed = NumberRange.new(0.3, 1.5),
        SpreadAngle = Vector2.new(90, 90), EmissionDirection = Enum.NormalId.Top,
        Drag = 2, Rotation = NumberRange.new(0, 360), LightEmission = 0.3, LightInfluence = 0,
    }, 14, 0.3)
end

local function applyTrail()
    clearTrail()
    if not State.Trail then return end
    local hrp = myRoot()
    if not hrp then return end
    local builder = TrailBuilders[State.TrailStyle] or TrailBuilders.Default
    builder(hrp)
end
onCleanup(clearTrail)

-- emitters react to movement speed
track(RunService.Heartbeat:Connect(function()
    if #trailEmit == 0 then return end
    local hrp = myRoot()
    if not hrp then return end
    local v = hrp.AssemblyLinearVelocity
    local f = math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 14, 0, 1)
    for _, r in ipairs(trailEmit) do
        if r.e.Parent then r.e.Rate = r.base * (r.idle + (1 - r.idle) * f) end
    end
end))

-- ==================== FUN: SANDEVISTAN ====================
local SANDY_GREEN = rgb(110, 255, 150)
local SANDY_LIFE, SANDY_MAX = 0.65, 16
local sandyGhosts, sandyHL, sandyCC = {}, nil, nil
local sandyLastPos, sandyLastT = nil, 0

local sandyFlash = new("Frame", {
    Name = "AbaddonSandyFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(210, 255, 225),
    BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 900, Active = false,
}, ScreenGui)

local function sandyFlashFx()
    sandyFlash.BackgroundColor3 = rgb(215, 255, 228)
    sandyFlash.BackgroundTransparency = 0.05
    tween(sandyFlash, 0.8, { BackgroundTransparency = 1, BackgroundColor3 = SANDY_GREEN }, Enum.EasingStyle.Quad)
    local blur = Instance.new("BlurEffect")
    blur.Name = "AbaddonSandyBlur"
    blur.Size = 30
    blur.Parent = Lighting
    tween(blur, 0.8, { Size = 0 })
    Debris:AddItem(blur, 1)
end

local function playSandySound()
    local s = Instance.new("Sound")
    s.SoundId = SANDY_SOUND
    s.Volume = 2
    s.Parent = SoundService
    s:Play()
    Debris:AddItem(s, 15)
end

local function sandyPalette(on)
    if on then
        if not sandyCC then
            sandyCC = Instance.new("ColorCorrectionEffect")
            sandyCC.Name = "AbaddonSandyCC"
            sandyCC.Parent = Lighting
        end
        tween(sandyCC, 0.5, {
            TintColor = rgb(150, 255, 175), Saturation = 0.15, Contrast = 0.18, Brightness = 0.02,
        })
    elseif sandyCC then
        local cc = sandyCC
        sandyCC = nil
        tween(cc, 0.5, { TintColor = C.White, Saturation = 0, Contrast = 0, Brightness = 0 })
        task.delay(0.55, function() pcall(function() cc:Destroy() end) end)
    end
end

local function clearGhosts()
    for _, g in ipairs(sandyGhosts) do pcall(function() g.vp:Destroy() end) end
    sandyGhosts = {}
end

local function spawnGhost()
    local char = LocalPlayer.Character
    if not char then return end
    local vp = Instance.new("ViewportFrame")
    vp.Name = "AbaddonGhost"
    vp.Size = UDim2.fromScale(1, 1)
    vp.BackgroundTransparency = 1
    vp.BorderSizePixel = 0
    vp.ZIndex = 2
    vp.Active = false
    vp.Ambient = rgb(120, 255, 160)
    vp.LightColor = rgb(150, 255, 180)
    vp.ImageColor3 = rgb(120, 255, 160)
    vp.ImageTransparency = 0.4

    local count = 0
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Name ~= "AbaddonHalo" and p.Transparency < 0.95 then
            local ok, c = pcall(function() return p:Clone() end)
            if ok and c then
                for _, d in ipairs(c:GetChildren()) do
                    if not d:IsA("DataModelMesh") then d:Destroy() end
                    if d:IsA("SpecialMesh") then pcall(function() d.TextureId = "" end) end
                end
                pcall(function() if c:IsA("MeshPart") then c.TextureID = "" end end)
                c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
                c.CastShadow = false
                c.Transparency = 0
                c.Material = Enum.Material.Neon
                c.Color = SANDY_GREEN
                c.Parent = vp
                count = count + 1
            end
        end
    end
    if count == 0 then vp:Destroy() return end

    local vcam = Instance.new("Camera")
    vcam.Parent = vp
    vp.CurrentCamera = vcam
    local wc = workspace.CurrentCamera
    if wc then vcam.CFrame, vcam.FieldOfView = wc.CFrame, wc.FieldOfView end
    vp.Parent = ScreenGui

    sandyGhosts[#sandyGhosts + 1] = { vp = vp, cam = vcam, born = os.clock() }
    while #sandyGhosts > SANDY_MAX do
        local old = table.remove(sandyGhosts, 1)
        pcall(function() old.vp:Destroy() end)
    end
end

track(RunService.RenderStepped:Connect(function()
    local now = os.clock()
    local wc = workspace.CurrentCamera

    if State.Sandevistan then
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if sandyHL and char and sandyHL.Adornee ~= char then sandyHL.Adornee = char end
        if hrp then
            local pos = hrp.Position
            if (not sandyLastPos or (pos - sandyLastPos).Magnitude >= 1.4) and now - sandyLastT > 0.04 then
                if sandyLastPos then pcall(spawnGhost) end
                sandyLastPos, sandyLastT = pos, now
            end
        end
    end

    if #sandyGhosts == 0 or not wc then return end
    for i = #sandyGhosts, 1, -1 do
        local g = sandyGhosts[i]
        local age = (now - g.born) / SANDY_LIFE
        if age >= 1 or not g.vp.Parent then
            pcall(function() g.vp:Destroy() end)
            table.remove(sandyGhosts, i)
        else
            g.cam.CFrame = wc.CFrame
            g.cam.FieldOfView = wc.FieldOfView
            g.vp.ImageTransparency = 0.4 + 0.6 * age
            g.vp.ImageColor3 = rgb(120, 255, 160):Lerp(rgb(20, 120, 60), age)
        end
    end
end))

local function setSandevistan(on, silent)
    State.Sandevistan = on
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if on then
        sandyPalette(true)
        if not silent then
            sandyFlashFx()
            playSandySound()
        end
        if hum then hum.WalkSpeed = SANDY_SPEED end
        if not sandyHL then
            sandyHL = Instance.new("Highlight")
            sandyHL.FillTransparency = 1
            sandyHL.OutlineColor = SANDY_GREEN
            sandyHL.OutlineTransparency = 0.2
            sandyHL.DepthMode = Enum.HighlightDepthMode.Occluded
            sandyHL.Adornee = char
            sandyHL.Parent = ScreenGui
        end
        sandyLastPos = nil
    else
        sandyPalette(false)
        clearGhosts()
        if sandyHL then sandyHL:Destroy() sandyHL = nil end
        if hum then hum.WalkSpeed = State.WalkSpeed end
    end
end
onCleanup(function()
    State.Sandevistan = false
    sandyPalette(false)
    clearGhosts()
end)

-- ==================== CONFIG SYSTEM ====================
local function saveConfig()
    if not writefile then pushLog("Executor does not support writefile", "error") return end
    local data = {}
    for k, v in pairs(State) do
        if k ~= "Open" and type(v) ~= "function" and type(v) ~= "table" then data[k] = v end
    end
    data.Binds = {}
    for _, e in ipairs(BindList) do
        if e.key then data.Binds[e.id] = keyName(e.key) end
    end
    local ok, err = pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
    if ok then pushLog("Config saved (" .. CONFIG_FILE .. ")", "success")
    else pushLog("Save error: " .. tostring(err), "error") end
end

local function applyConfigData(data, silent)
    for key, w in pairs(widgetRegistry) do
        if data[key] ~= nil then
            pcall(function() w.Set(data[key]) end)
            State[key] = data[key]
        end
    end
    local binds = (data == DEFAULT_STATE) and {} or data.Binds
    if type(binds) == "table" then
        Binding = nil
        for _, e in ipairs(BindList) do
            local nm = binds[e.id]
            e.key = type(nm) == "string" and keyFromName(nm) or nil
            e.refreshBadge()
        end
        refreshIsland()
    end
    if not silent then pushLog("Config applied", "success") end
end

local function loadConfig()
    if not readfile or not isfile then pushLog("Executor does not support readfile", "error") return end
    if not isfile(CONFIG_FILE) then pushLog("Config not found", "warn") return end
    local ok, data = pcall(function() return HttpService:JSONDecode(readfile(CONFIG_FILE)) end)
    if not ok or type(data) ~= "table" then pushLog("Failed to read config", "error") return end
    applyConfigData(data, false)
    pushLog("Config loaded", "success")
end

local function resetConfig()
    applyConfigData(DEFAULT_STATE, true)
    pushLog("Settings reset to defaults", "success")
    notify("Config reset")
end

local function deleteConfig()
    if not delfile then pushLog("Executor does not support delfile", "error") return end
    pcall(function() delfile(CONFIG_FILE) end)
    pushLog("Config file deleted", "info")
end

-- ==================== toggle helper ====================
local function simpleToggle(page, label, order, key, apply, colorOpt, onText, offText)
    return createToggle(page, label, false, order, function(v, silent)
        if key then State[key] = v end
        if apply then apply(v, silent) end
        if silent then return end
        notify(label .. ": " .. (v and "ON" or "OFF"))
        pushLog(label .. ": " .. (v and (onText or "enabled") or (offText or "disabled")), "info")
    end, key, colorOpt)
end

-- ==================== VISUALS ====================
createSection(VisualPage, "ESP", 1)

simpleToggle(VisualPage, "ESP Survivors", 2, "ESP_Survivors", nil, {
    hex = State.ESP_SurvivorColorHex, stateKey = "ESP_SurvivorColorHex",
    onColor = function(col, hex) ESPColors.Survivor = col State.ESP_SurvivorColorHex = hex end,
})
simpleToggle(VisualPage, "ESP Killer", 3, "ESP_Killer", nil, {
    hex = State.ESP_KillerColorHex, stateKey = "ESP_KillerColorHex",
    onColor = function(col, hex) ESPColors.Killer = col State.ESP_KillerColorHex = hex end,
})
simpleToggle(VisualPage, "ESP Generators", 4, "ESP_Generators", nil, {
    hex = State.ESP_GeneratorColorHex, stateKey = "ESP_GeneratorColorHex",
    onColor = function(col, hex) ESPColors.Generator = col State.ESP_GeneratorColorHex = hex end,
})
simpleToggle(VisualPage, "ESP Hooks", 5, "ESP_Hooks")
simpleToggle(VisualPage, "ESP Pallets", 6, "ESP_Pallets")
simpleToggle(VisualPage, "ESP Exit Gates", 7, "ESP_Gates")
simpleToggle(VisualPage, "ESP Info (dist / hp)", 8, "ESP_Info")
tracerWidget = simpleToggle(VisualPage, "Tracers", 9, "Tracers", function(v) setTracers(v) end)

createSection(VisualPage, "World", 10)
simpleToggle(VisualPage, "Fullbright", 11, "Fullbright", function(v) setFullbright(v) end)
simpleToggle(VisualPage, "No Shadows", 12, nil, function(v) setNoShadows(v) end, nil, "enabled", "disabled")
simpleToggle(VisualPage, "No Textures", 13, nil, function(v, silent) setNoTextures(v, true) end, nil, "enabled", "disabled")
simpleToggle(VisualPage, "Custom Time", 14, "CustomTime")
createSlider(VisualPage, "Time of Day", 0, 24, 14, 15,
    function(v) State.ClockTime = v if State.CustomTime then Lighting.ClockTime = v end end,
    function(v) pushLog("ClockTime: " .. tostring(v), "info") end,
    "ClockTime")

createSection(VisualPage, "Camera", 16)
createSlider(VisualPage, "Field of View", 30, 120, 70, 17,
    function(v) setCameraFOV(v) end,
    function(v) pushLog("Camera FOV: " .. tostring(v), "info") end,
    "CameraFOV")
simpleToggle(VisualPage, "Force Third Person", 18, "ThirdPerson", function(v) setThirdPerson(v) end)
createToggle(VisualPage, "Shift Lock", true, 19, function(v, silent)
    State.ShiftLock = v
    if not v then releaseShiftLock() end
    if silent then return end
    pushLog("Shift Lock: " .. (v and "ON" or "OFF"), "info")
end, "ShiftLock")
createSlider(VisualPage, "Max Camera Zoom", 20, 500, 128, 20,
    function(v) State.MaxZoom = v end, nil, "MaxZoom")

-- ==================== MAIN ====================
createSection(MainPage, "Skill Check", 1)
simpleToggle(MainPage, "Auto Hit Perfect Skillcheck", 2, "AutoSkillCheck")

createSection(MainPage, "Protection", 3)
simpleToggle(MainPage, "Anti-AFK", 4, "AntiAFK", function(v) setAntiAFK(v) end)
simpleToggle(MainPage, "Anti-Fling", 5, nil, function(v) setAntiFling(v) end)

createSection(MainPage, "Survival", 6)
simpleToggle(MainPage, "Killer Proximity Alert", 7, "KillerAlert")
createSlider(MainPage, "Alert Range (studs)", 20, 200, 60, 8,
    function(v) State.AlertRange = v end, nil, "AlertRange")
simpleToggle(MainPage, "Radar", 9, "Radar")
createSlider(MainPage, "Radar Range (studs)", 50, 300, 120, 10,
    function(v) State.RadarRange = v end, nil, "RadarRange")

createSection(MainPage, "Quick Teleports", 11)
createButton(MainPage, "TP Nearest Generator", 12, tpNearestGen)
createButton(MainPage, "TP Exit Gate", 13, tpNearestGate)
createButton(MainPage, "TP Far From Killer", 14, tpSafeSpot)

createSection(MainPage, "Spectate", 15)
createTextAction(MainPage, "Spectate Player", "nickname", 16, function(name) spectate(name) end)
createButton(MainPage, "Stop Spectating", 17, unspectate)

-- ==================== MOVEMENT ====================
createSection(MovementPage, "Character", 1)
createInput(MovementPage, "WalkSpeed", 16, 2, function(v, silent)
    State.WalkSpeed = v
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and not State.Sandevistan then hum.WalkSpeed = v end
    if silent then return end
    notify("WalkSpeed: " .. tostring(v))
    pushLog("WalkSpeed set to " .. tostring(v), "info")
end, "WalkSpeed")

createToggle(MovementPage, "Lock WalkSpeed", true, 3, function(v, silent)
    State.WalkSpeedLock = v
    if silent then return end
    pushLog("WalkSpeed lock: " .. (v and "ON" or "OFF"), "info")
end, "WalkSpeedLock")

simpleToggle(MovementPage, "Noclip", 4, nil, function(v) setNoclip(v) end)

createSection(MovementPage, "Flight", 5)
simpleToggle(MovementPage, "Fly (WASD/Space/Ctrl)", 6, nil, function(v) setFly(v) end)
createInput(MovementPage, "Fly Speed", 60, 7, function(v, silent)
    State.FlySpeed = v
    if silent then return end
    notify("Fly Speed: " .. tostring(v))
    pushLog("Fly Speed: " .. tostring(v), "info")
end, "FlySpeed")

createSection(MovementPage, "Teleport", 8)
simpleToggle(MovementPage, "TP Tool (LMB)", 9, nil, function(v) setTPTool(v) end)
createTextAction(MovementPage, "Goto Player", "nickname", 10, function(name) gotoPlayer(name) end)

createSection(MovementPage, "Network", 11)
fakeLagWidget = simpleToggle(MovementPage, "Fake Lag", 12, nil, function(v) setFakeLag(v) end)
createInput(MovementPage, "Fake Lag Time (ms)", 200, 13, function(v)
    State.FakeLagTime = math.clamp(v, 20, 2000)
end, "FakeLagTime")

-- ==================== COSMETICS ====================
createSection(CosmeticsPage, "Halo", 1)
simpleToggle(CosmeticsPage, "Halo", 2, "Halo", function(v) setHalo(v) end, {
    hex = State.HaloColorHex, stateKey = "HaloColorHex",
    onColor = function(col, hex) State.HaloColorHex = hex updateHaloColor() end,
})

createSection(CosmeticsPage, "Trail", 3)
simpleToggle(CosmeticsPage, "Trail", 4, "Trail", function(v) applyTrail() end)
createSelector(CosmeticsPage, "Style (LMB/RMB)", TRAIL_STYLES, "Default", 5, function(v, silent)
    State.TrailStyle = v
    applyTrail()
    if not silent then pushLog("Trail style: " .. v, "info") end
end, "TrailStyle")

-- ==================== FUN ====================
createSection(FunPage, "Character", 1)
simpleToggle(FunPage, "Back Walk", 2, nil, function(v) setBackWalk(v) end)
simpleToggle(FunPage, "Spin", 3, nil, function(v) setSpin(v) end)

createSection(FunPage, "Overlay", 4)
simpleToggle(FunPage, "Hoodwink", 5, nil, function(v) setHoodwink(v) end)
simpleToggle(FunPage, "Crosshair", 6, "Crosshair", function(v) setCrosshair(v) end)
createInput(FunPage, "Crosshair Size", 10, 7, function(v)
    State.CrosshairSize = math.clamp(v, 2, 80)
    buildCrosshair()
end, "CrosshairSize")

createSection(FunPage, "Sandevistan", 8)
simpleToggle(FunPage, "Sandevistan (speed 22)", 9, "Sandevistan", function(v, silent) setSandevistan(v, silent) end)

-- ==================== SETTINGS ====================
createSection(SettingsPage, "Interface", 1)
createToggle(SettingsPage, "Hide Username (watermark)", false, 2, function(v, silent)
    State.HideUsername = v
    if silent then return end
    pushLog("Watermark username: " .. (v and "@ellieabaddon" or "@" .. LocalPlayer.Name), "info")
end, "HideUsername")
createToggle(SettingsPage, "Bind Island", true, 3, function(v, silent)
    State.BindIsland = v
    refreshIsland()
    if silent then return end
end, "BindIsland")
createToggle(SettingsPage, "Logs", true, 4, function(v, silent)
    State.Logs = v
    if not v then clearLogs() end
end, "Logs")

createSection(SettingsPage, "Keybinds", 5)
do
    local info = glassRow(SettingsPage, 6, 78)
    local t = new("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        Text = "Middle-click any toggle, then press a key (or Mouse4 / Mouse5) to bind it. Esc clears the bind. Binds work while the menu is closed.",
        TextColor3 = C.TextDim, TextSize = 10, TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        ZIndex = 4, Active = false,
    }, info)
    fontReg(t)
end
createButton(SettingsPage, "Clear All Binds", 7, clearAllBinds, true)

createSection(SettingsPage, "Server", 8)
createButton(SettingsPage, "Server Hop", 9, serverHop)
createButton(SettingsPage, "Rejoin", 10, rejoin)

createSection(SettingsPage, "Config", 11)
createButton(SettingsPage, "Save Config", 12, saveConfig)
createButton(SettingsPage, "Load Config", 13, loadConfig)
createButton(SettingsPage, "Reset Config (defaults)", 14, resetConfig)
createButton(SettingsPage, "Delete Config File", 15, deleteConfig, true)

-- ==================== ESP ====================
local ESPFolder = new("Folder", { Name = "AbaddonESP" }, ScreenGui)
local playerEsp, playerTags = {}, {}
local objHL = {}

local function clearEsp(cache, key)
    if cache[key] then cache[key]:Destroy() cache[key] = nil end
end

Players.PlayerRemoving:Connect(function(plr)
    clearEsp(playerEsp, plr)
    clearEsp(playerTags, plr)
end)

local function applyPlayerESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local char = plr.Character
        local teamName = plr.Team and plr.Team.Name:lower() or ""
        local isKiller   = teamName:find("killer")   ~= nil
        local isSurvivor = teamName:find("survivor") ~= nil
        local want = (isKiller and State.ESP_Killer) or (isSurvivor and State.ESP_Survivors)

        if want and char then
            local col = isKiller and ESPColors.Killer or ESPColors.Survivor

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
                    tag.Size = UDim2.new(0, 260, 0, 22)
                    tag.StudsOffset = Vector3.new(0, 3, 0)
                    tag.AlwaysOnTop = true
                    tag.Adornee = head
                    tag.Parent = char

                    local l = Instance.new("TextLabel", tag)
                    l.Name = "Label"
                    l.Size = UDim2.new(1, 0, 1, 0)
                    l.BackgroundTransparency = 1
                    l.TextSize = 12
                    l.TextStrokeTransparency = 0.35
                    l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    fontMed(l)
                    playerTags[plr] = tag
                end
                tag.Adornee = head
                local l = tag:FindFirstChild("Label")
                if l then
                    local txt = plr.Name
                    if State.ESP_Info then
                        local mine = myRoot()
                        local th = char:FindFirstChild("HumanoidRootPart")
                        local hm = char:FindFirstChildOfClass("Humanoid")
                        if mine and th then
                            txt = txt .. string.format(" [%d st]", math.floor((th.Position - mine.Position).Magnitude))
                        end
                        if hm then
                            txt = txt .. string.format(" %d hp", math.floor(hm.Health))
                        end
                    end
                    l.Text = txt
                    l.TextColor3 = col
                end
            end
        else
            clearEsp(playerEsp, plr)
            clearEsp(playerTags, plr)
        end
    end
end

local OBJ_COLORS = {
    gen    = function() return ESPColors.Generator end,
    hook   = Color3.fromRGB(226, 96, 96),
    pallet = Color3.fromRGB(214, 175, 98),
    gate   = Color3.fromRGB(120, 170, 255),
}

local function applyObjectESP()
    for _, d in ipairs(OBJ_DEFS) do
        local cc = OBJ_COLORS[d.id]
        local col = type(cc) == "function" and cc() or cc
        for _, obj in ipairs(ObjectsFound[d.id]) do
            if State[d.key] and obj.Parent then
                local h = objHL[obj]
                if not h or not h.Parent then
                    h = Instance.new("Highlight")
                    h.Adornee = obj
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillTransparency = 0.78
                    h.OutlineTransparency = 0.15
                    h.Parent = ESPFolder
                    objHL[obj] = h
                end
                h.FillColor = col
                h.OutlineColor = col
            elseif objHL[obj] then
                objHL[obj]:Destroy()
                objHL[obj] = nil
            end
        end
    end
    for obj, h in pairs(objHL) do
        if not obj.Parent then h:Destroy() objHL[obj] = nil end
    end
end

local function needObjectScan()
    if State.Radar then return true end
    for _, d in ipairs(OBJ_DEFS) do
        if State[d.key] then return true end
    end
    return false
end

task.spawn(function()
    local tickN = 0
    while ScreenGui.Parent do
        pcall(applyPlayerESP)
        if tickN % 2 == 0 then
            if needObjectScan() then pcall(collectObjects) end
            pcall(applyObjectESP)
        end
        tickN = tickN + 1
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
    local teamName = LocalPlayer.Team and LocalPlayer.Team.Name:lower() or ""
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
        local ok, err = pcall(TriggerMobileButton)
        if ok then pushLog("Skill check hit", "success")
        else pushLog("Skill check error: " .. tostring(err), "error") end
        task.delay(0.15, function() isProcessingHit = false end)
    end
end)

-- ==================== OPEN / CLOSE ====================
local openToken = 0

local function setOpen(open)
    State.Open = open
    if not open then cancelBinding() end
    openToken = openToken + 1
    local myToken = openToken
    if crosshairRoot then crosshairRoot.Visible = not open end

    if open then
        Panel.Visible, Overlay.Visible = true, true
        Panel.Size = UDim2.fromOffset(PW - 16, PH - 10)
        Panel.GroupTransparency = 1
        Overlay.BackgroundTransparency = 1

        tween(Panel, 0.2, { Size = UDim2.fromOffset(PW, PH), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
        tween(Overlay, 0.2, { BackgroundTransparency = 0.65 })
    else
        tween(Panel, 0.12, { GroupTransparency = 1 })
        tween(Overlay, 0.12, { BackgroundTransparency = 1 })
        task.delay(0.14, function()
            if myToken ~= openToken then return end
            Panel.Visible, Overlay.Visible = false, false
        end)
    end
end

CloseBtn.MouseButton1Click:Connect(function() setOpen(false) end)

track(UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == KEY_TOGGLE then setOpen(not State.Open) end
end))

do
    local dragging, dragStart, startPos
    TopBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = input.Position
            startPos  = Panel.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            Panel.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end))
end

track(UserInputService.InputChanged:Connect(function(input, gpe)
    if gpe then return end
    if input.UserInputType ~= Enum.UserInputType.MouseWheel then return end
    if not State.Open then return end
    for _, page in pairs(Pages) do
        if not page.Visible then continue end
        local mouse = UserInputService:GetMouseLocation()
        local topLeft = page.AbsolutePosition
        local bottomRight = topLeft + page.AbsoluteSize
        if mouse.X >= topLeft.X and mouse.X <= bottomRight.X and mouse.Y >= topLeft.Y and mouse.Y <= bottomRight.Y then
            local maxScroll = math.max(0, page.AbsoluteCanvasSize.Y - page.AbsoluteSize.Y)
            page.CanvasPosition = Vector2.new(0, math.clamp(page.CanvasPosition.Y - input.Position.Z * 40, 0, maxScroll))
            break
        end
    end
end))

-- ==================== WELCOME ====================
local function showWelcome()
    local popup = new("CanvasGroup", {
        Size = UDim2.fromOffset(260, 28), Position = UDim2.new(0.5, 0, 1, 40), AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = C.Bg, BorderSizePixel = 0,
        GroupTransparency = 1, ZIndex = 300,
    }, ScreenGui)
    stroke(popup, C.Black)
    topGradient(popup, 2)
    local txt = new("TextLabel", {
        Size = UDim2.new(1, -16, 1, -2), Position = UDim2.fromOffset(8, 2), BackgroundTransparency = 1,
        Text = "Welcome, @" .. LocalPlayer.Name, TextColor3 = C.Text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3,
    }, popup)
    fontMed(txt)

    tween(popup, 0.35, { Position = UDim2.new(0.5, 0, 1, -56), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
    task.wait(3)
    tween(popup, 0.3, { Position = UDim2.new(0.5, 0, 1, 60), GroupTransparency = 1 }, Enum.EasingStyle.Quint)
    task.wait(0.4)
    popup:Destroy()
end

-- ==================== CHARACTER HOOKS ====================
LocalPlayer.CharacterAdded:Connect(function(char)
    task.spawn(hookWalkSpeed, char)
    task.wait(0.4)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = State.Sandevistan and SANDY_SPEED or State.WalkSpeed
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
    if State.Halo then buildHalo() end
    if State.Trail then applyTrail() end
    sandyLastPos = nil
end)

-- ==================== BOOT ====================
task.spawn(function()
    local ok, err = pcall(showWelcome)
    if not ok then pushLog("Welcome popup error: " .. tostring(err), "error") end
end)

task.spawn(function()
    if readfile and isfile and isfile(CONFIG_FILE) then
        task.wait(1)
        pcall(loadConfig)
    end
end)

notify("Abaddon loaded · RightShift")
pushLog("Abaddon loaded successfully", "success")
