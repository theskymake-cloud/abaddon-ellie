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

-- ==================== RE-EXECUTE CLEANUP ====================
if _G.AbaddonCleanup then pcall(_G.AbaddonCleanup) end
if _G.AbaddonGui then pcall(function() _G.AbaddonGui:Destroy() end) end
if _G.ASC_MainLoop then pcall(function() _G.ASC_MainLoop:Disconnect() end) end
_G.ASC_MainLoop = nil

local Conns = {}
local function track(c) Conns[#Conns + 1] = c return c end
_G.AbaddonCleanup = function()
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Conns = {}
end

local KEY_TOGGLE  = Enum.KeyCode.RightShift
local SPIN_SPEED  = 720
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

-- ==================== PALETTE ====================
local C = {
    Glass     = Color3.fromRGB(12, 14, 22),
    White     = Color3.fromRGB(255, 255, 255),
    Text      = Color3.fromRGB(242, 245, 252),
    TextDim   = Color3.fromRGB(168, 175, 195),
    TextFaint = Color3.fromRGB(112, 119, 140),
    Accent    = Color3.fromRGB(150, 186, 255),
    Violet    = Color3.fromRGB(176, 140, 255),
    Teal      = Color3.fromRGB(120, 224, 214),
    Green     = Color3.fromRGB(140, 205, 160),
    Yellow    = Color3.fromRGB(214, 175, 98),
    Red       = Color3.fromRGB(226, 96, 96),
}

-- ==================== STATE ====================
local State = {
    Open           = false,
    ESP_Survivors  = false,
    ESP_Killer     = false,
    ESP_Generators = false,
    Fullbright     = false,
    NoShadows      = false,
    NoTextures     = false,
    CustomTime     = false,
    AutoSkillCheck = false,
    AntiAFK        = false,
    WalkSpeed      = 16,
    HipHeight      = 0,
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
local function mkFont(weight)
    local ok, f = pcall(function()
        return Font.new("rbxasset://fonts/families/GothamSSm.json", weight, Enum.FontStyle.Normal)
    end)
    return ok and f or nil
end
local F_REG, F_MED, F_BOLD = mkFont(Enum.FontWeight.Regular), mkFont(Enum.FontWeight.Medium), mkFont(Enum.FontWeight.Bold)
local function fontReg(o)  if F_REG  then o.FontFace = F_REG  else o.Font = Enum.Font.Gotham       end end
local function fontMed(o)  if F_MED  then o.FontFace = F_MED  else o.Font = Enum.Font.GothamMedium end end
local function fontBold(o) if F_BOLD then o.FontFace = F_BOLD else o.Font = Enum.Font.GothamBold   end end

-- ==================== UI HELPERS ====================
local function new(class, props, parent)
    local o = Instance.new(class)
    for k, v in pairs(props) do o[k] = v end
    if parent then o.Parent = parent end
    return o
end

local function ns(t)
    local k = {}
    for i, p in ipairs(t) do k[i] = NumberSequenceKeypoint.new(p[1], p[2]) end
    return NumberSequence.new(k)
end

local function corner(p, r)
    return new("UICorner", { CornerRadius = UDim.new(0, r) }, p)
end

-- Gradient glass stroke: bright top-left, fades toward the middle, soft highlight bottom-right
local function glassStroke(p, k)
    k = k or 1
    local s = new("UIStroke", {
        Color = C.White, Thickness = 1, Transparency = 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
    new("UIGradient", {
        Rotation = 50,
        Transparency = ns({ {0, 1 - 0.6 * k}, {0.3, 1 - 0.14 * k}, {0.7, 1 - 0.1 * k}, {1, 1 - 0.38 * k} }),
    }, s)
    return s
end

-- Diagonal sheen across the glass surface
local function sheen(p, a, rot, r)
    local f = new("Frame", {
        Name = "Sheen", Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = C.White, BackgroundTransparency = 0,
        BorderSizePixel = 0, ZIndex = 1, Active = false,
    }, p)
    if r then corner(f, r) end
    new("UIGradient", {
        Rotation = rot or 35,
        Transparency = ns({ {0, 1 - a}, {0.5, 1 - a * 0.22}, {1, 1 - a * 0.5} }),
    }, f)
    return f
end

local function hairline(parent, pos, size, vertical, alpha)
    local f = new("Frame", {
        Position = pos, Size = size, BackgroundColor3 = C.White,
        BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 3, Active = false,
    }, parent)
    new("UIGradient", {
        Rotation = vertical and 90 or 0,
        Transparency = ns({ {0, 1}, {0.5, 1 - (alpha or 0.16)}, {1, 1} }),
    }, f)
    return f
end

local function tween(o, t, props, style)
    local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quart), props)
    tw:Play()
    return tw
end

-- ==================== ROOT GUI ====================
local Blur = Lighting:FindFirstChild("AbaddonBlur") or Instance.new("BlurEffect")
Blur.Name = "AbaddonBlur"
Blur.Size = 0
Blur.Parent = Lighting

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
        if Blur and Blur.Parent == nil then
            pcall(function() Blur.Parent = Lighting end)
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

-- dim overlay
local Overlay = new("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 10,
}, ScreenGui)

-- animated network grid behind the panel
local Grid = new("Frame", {
    Name = "Grid", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    ClipsDescendants = true, Visible = false, ZIndex = 11, Active = false,
}, ScreenGui)

local NODE_COUNT, MAX_LINK = 52, 190
local nodes, links = {}, {}

local function makeNode()
    local dot = new("Frame", {
        Size = UDim2.fromOffset(2, 2), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(220, 220, 224),
        BackgroundTransparency = math.random(30, 65) / 100,
        BorderSizePixel = 0, ZIndex = 12, Active = false,
    }, Grid)
    corner(dot, 9999)
    return {
        x = math.random() * 1400, y = math.random() * 800,
        vx = (math.random() - 0.5) * 55, vy = (math.random() - 0.5) * 55,
        dot = dot,
    }
end
for i = 1, NODE_COUNT do nodes[i] = makeNode() end

local function getLink(i)
    if not links[i] then
        links[i] = new("Frame", {
            BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(180, 180, 190),
            AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 11, Active = false,
        }, Grid)
    end
    return links[i]
end

-- ==================== MAIN PANEL (CanvasGroup = fades the whole glass) ====================
local PW, PH = 700, 470

local Panel = new("CanvasGroup", {
    Name = "Panel", Size = UDim2.fromOffset(PW, PH),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.Glass, BackgroundTransparency = 0.32,
    BorderSizePixel = 0, Visible = false, Active = true, ZIndex = 100,
    GroupTransparency = 1,
}, ScreenGui)
corner(Panel, 22)
glassStroke(Panel, 1)
sheen(Panel, 0.15, 35, 22)
hairline(Panel, UDim2.fromOffset(18, 0), UDim2.new(1, -36, 0, 1), false, 0.55)

track(RunService.RenderStepped:Connect(function(dt)
    if not Grid.Visible then return end
    local camera = workspace.CurrentCamera
    if not camera then return end
    local vp = camera.ViewportSize
    for _, n in ipairs(nodes) do
        n.x = n.x + n.vx * dt
        n.y = n.y + n.vy * dt
        if n.x < 0 then n.x = 0 n.vx = -n.vx end
        if n.x > vp.X then n.x = vp.X n.vx = -n.vx end
        if n.y < 0 then n.y = 0 n.vy = -n.vy end
        if n.y > vp.Y then n.y = vp.Y n.vy = -n.vy end
        n.dot.Position = UDim2.fromOffset(n.x, n.y)
    end
    local li = 1
    for i = 1, #nodes do
        for j = i + 1, #nodes do
            local a, b = nodes[i], nodes[j]
            local dx, dy = a.x - b.x, a.y - b.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d < MAX_LINK then
                local f = getLink(li)
                f.Visible = true
                f.Size = UDim2.fromOffset(d, 1)
                f.Position = UDim2.fromOffset((a.x + b.x) * 0.5, (a.y + b.y) * 0.5)
                f.Rotation = math.deg(math.atan2(dy, dx))
                f.BackgroundTransparency = 0.65 + (1 - d / MAX_LINK) * 0.3
                li = li + 1
            end
        end
    end
    for k = li, #links do links[k].Visible = false end
end))

-- ---- Top bar
local TopBar = new("Frame", {
    Size = UDim2.new(1, 0, 0, 54), BackgroundTransparency = 1, Active = true, ZIndex = 5,
}, Panel)

local TopTitle = new("TextLabel", {
    Size = UDim2.fromOffset(90, 54), Position = UDim2.fromOffset(24, 0),
    BackgroundTransparency = 1, Text = "ABADDON", TextColor3 = C.Text, TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 6,
}, TopBar)
fontBold(TopTitle)

local SubPill = new("Frame", {
    Size = UDim2.fromOffset(52, 18), Position = UDim2.fromOffset(112, 18),
    BackgroundColor3 = C.White, BackgroundTransparency = 0.92, BorderSizePixel = 0, ZIndex = 6, Active = false,
}, TopBar)
corner(SubPill, 9)
glassStroke(SubPill, 0.5)
local TopSub = new("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "lzteam",
    TextColor3 = C.TextDim, TextSize = 9, Active = false, ZIndex = 7,
}, SubPill)
fontMed(TopSub)

hairline(Panel, UDim2.fromOffset(0, 54), UDim2.new(1, 0, 0, 1), false, 0.14)

local CloseBtn = new("TextButton", {
    Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -42, 0, 14),
    BackgroundColor3 = C.White, BackgroundTransparency = 0.92, Text = "×",
    TextColor3 = C.TextDim, TextSize = 17, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 8,
}, TopBar)
corner(CloseBtn, 13)
glassStroke(CloseBtn, 0.6)
fontMed(CloseBtn)
CloseBtn.MouseEnter:Connect(function()
    tween(CloseBtn, 0.15, { TextColor3 = C.Red, BackgroundTransparency = 0.82 })
end)
CloseBtn.MouseLeave:Connect(function()
    tween(CloseBtn, 0.18, { TextColor3 = C.TextDim, BackgroundTransparency = 0.92 })
end)

-- ---- Sidebar
local SB_W = 176
local Sidebar = new("Frame", {
    Size = UDim2.new(0, SB_W, 1, -55), Position = UDim2.fromOffset(0, 55),
    BackgroundTransparency = 1, ZIndex = 2,
}, Panel)
hairline(Sidebar, UDim2.new(1, -1, 0, 0), UDim2.new(0, 1, 1, 0), true, 0.14)

local TabList = new("Frame", {
    Size = UDim2.new(1, -20, 0, 280), Position = UDim2.fromOffset(10, 14),
    BackgroundTransparency = 1, ZIndex = 3,
}, Sidebar)
new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, TabList)

-- profile card
local Card = new("Frame", {
    Size = UDim2.new(1, -20, 0, 58), Position = UDim2.new(0, 10, 1, -70),
    BackgroundColor3 = C.White, BackgroundTransparency = 0.92, BorderSizePixel = 0, ZIndex = 3,
}, Sidebar)
corner(Card, 14)
glassStroke(Card, 0.6)
sheen(Card, 0.1, 35, 14)

local Avatar = new("ImageLabel", {
    Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(10, 10),
    BackgroundColor3 = C.Glass, BorderSizePixel = 0, ZIndex = 4,
    Image = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150",
}, Card)
corner(Avatar, 19)
glassStroke(Avatar, 0.8)

local NameLbl = new("TextLabel", {
    Size = UDim2.new(1, -60, 0, 16), Position = UDim2.fromOffset(56, 12),
    BackgroundTransparency = 1, Text = "@" .. LocalPlayer.Name, TextColor3 = C.Text, TextSize = 11,
    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Active = false, ZIndex = 4,
}, Card)
fontBold(NameLbl)

local StatusDot = new("Frame", {
    Size = UDim2.fromOffset(6, 6), Position = UDim2.fromOffset(57, 35),
    BackgroundColor3 = C.Green, BorderSizePixel = 0, ZIndex = 4,
}, Card)
corner(StatusDot, 3)
local StatusLbl = new("TextLabel", {
    Size = UDim2.new(1, -76, 0, 12), Position = UDim2.fromOffset(69, 32),
    BackgroundTransparency = 1, Text = "ACTIVE", TextColor3 = C.TextFaint, TextSize = 9,
    TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 4,
}, Card)
fontMed(StatusLbl)

local Content = new("Frame", {
    Size = UDim2.new(1, -SB_W, 1, -55), Position = UDim2.fromOffset(SB_W, 55),
    BackgroundTransparency = 1, ZIndex = 2,
}, Panel)

-- ==================== TOASTS ====================
local function notify(text)
    task.spawn(function()
        local n = new("CanvasGroup", {
            Size = UDim2.fromOffset(250, 38), Position = UDim2.new(1, 20, 1, -60),
            AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = C.Glass, BackgroundTransparency = 0.25,
            BorderSizePixel = 0, GroupTransparency = 1, ZIndex = 300,
        }, ScreenGui)
        corner(n, 14)
        glassStroke(n, 1)
        sheen(n, 0.14, 35, 14)
        local dot = new("Frame", {
            Size = UDim2.fromOffset(6, 6), Position = UDim2.new(0, 14, 0.5, -3),
            BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 3,
        }, n)
        corner(dot, 3)
        local lbl = new("TextLabel", {
            Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(28, 0),
            BackgroundTransparency = 1, Text = text, TextColor3 = C.Text, TextSize = 11,
            TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 3,
        }, n)
        fontMed(lbl)

        tween(n, 0.32, { Position = UDim2.new(1, -266, 1, -60), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
        task.wait(2.4)
        tween(n, 0.25, { Position = UDim2.new(1, 20, 1, -60), GroupTransparency = 1 })
        task.wait(0.3)
        n:Destroy()
    end)
end

-- ==================== LOG FEED ====================
local LogContainer = new("Frame", {
    Size = UDim2.fromOffset(400, 400), Position = UDim2.fromOffset(16, 16),
    BackgroundTransparency = 1, ZIndex = 400,
}, ScreenGui)
new("UIListLayout", {
    Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Top,
}, LogContainer)

local logCounter = 0
local LOG_COLORS = {
    info    = Color3.fromRGB(226, 230, 240),
    success = Color3.fromRGB(140, 205, 160),
    error   = Color3.fromRGB(226, 96, 96),
    warn    = Color3.fromRGB(214, 175, 98),
}

local function pushLog(text, kind)
    kind = kind or "info"
    logCounter = logCounter + 1
    local col = LOG_COLORS[kind] or LOG_COLORS.info

    local bg = new("CanvasGroup", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = C.Glass, BackgroundTransparency = 0.3,
        BorderSizePixel = 0, LayoutOrder = logCounter, GroupTransparency = 1, ZIndex = 401,
    }, LogContainer)
    corner(bg, 9)
    glassStroke(bg, 0.8)
    sheen(bg, 0.1, 35, 9)
    local dot = new("Frame", {
        Size = UDim2.fromOffset(5, 5), Position = UDim2.new(0, 10, 0.5, -2),
        BackgroundColor3 = col, BorderSizePixel = 0, ZIndex = 3,
    }, bg)
    corner(dot, 3)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(22, 0),
        BackgroundTransparency = 1, Text = string.format("[%s] %s", os.date("%H:%M:%S"), text),
        TextColor3 = col, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 3,
    }, bg)
    fontMed(lbl)

    tween(bg, 0.22, { GroupTransparency = 0 })
    task.delay(5, function()
        if not bg.Parent then return end
        tween(bg, 0.35, { GroupTransparency = 1 })
        task.wait(0.4)
        if bg.Parent then bg:Destroy() end
    end)
end

-- ==================== WATERMARK ====================
local Watermark = new("CanvasGroup", {
    Name = "AbaddonWatermark", Size = UDim2.fromOffset(440, 30),
    Position = UDim2.new(0.5, 0, 1, -12), AnchorPoint = Vector2.new(0.5, 1),
    BackgroundColor3 = C.Glass, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 250,
}, ScreenGui)
corner(Watermark, 15)
glassStroke(Watermark, 1)
sheen(Watermark, 0.14, 35, 15)

local WmLabel = new("TextLabel", {
    Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0),
    BackgroundTransparency = 1, RichText = true, TextColor3 = C.Text, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3, Active = false,
}, Watermark)
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
    if fps >= 50 then return "rgb(140,205,160)" end
    if fps >= 30 then return "rgb(214,175,98)" end
    return "rgb(226,96,96)"
end
local function pingColorHex(ping)
    if ping <= 80 then return "rgb(140,205,160)" end
    if ping <= 150 then return "rgb(214,175,98)" end
    return "rgb(226,96,96)"
end

task.spawn(function()
    while Watermark.Parent do
        local ok, ping = pcall(function() return math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
        if not ok then ping = 0 end
        local name = State.HideUsername and "@ellieabaddon" or ("@" .. LocalPlayer.Name)
        WmLabel.Text = string.format(
            '<font color="rgb(226,232,245)">abaddon</font>  <font color="rgb(90,96,116)">|</font>  <font color="rgb(226,232,245)">%s</font>  <font color="rgb(90,96,116)">|</font>  <font color="%s">FPS %d</font>  <font color="rgb(90,96,116)">|</font>  <font color="%s">PING %d</font>',
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
            Name = "AbaddonHoodwink", Size = UDim2.fromOffset(260, 260),
            Position = UDim2.new(1, -20, 0, 20), AnchorPoint = Vector2.new(1, 0),
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

-- ==================== TAB SYSTEM ====================
local Tabs, Pages = {}, {}

local function setActiveTab(name)
    for n, t in pairs(Tabs) do
        local active = (n == name)
        tween(t.btn, 0.2, { BackgroundTransparency = active and 0.86 or 1 })
        tween(t.lbl, 0.2, { TextColor3 = active and C.Text or C.TextDim })
        tween(t.bar, 0.2, {
            BackgroundTransparency = active and 0 or 1,
            Size = active and UDim2.fromOffset(3, 16) or UDim2.fromOffset(3, 0),
        })
        Pages[n].Visible = active
    end
end

local function createTab(name, order)
    local btn = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = C.White, BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, LayoutOrder = order, BorderSizePixel = 0, ZIndex = 4,
    }, TabList)
    corner(btn, 11)

    local bar = new("Frame", {
        Size = UDim2.fromOffset(3, 0), Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = C.Accent, BackgroundTransparency = 1, BorderSizePixel = 0, Active = false, ZIndex = 5,
    }, btn)
    corner(bar, 2)

    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -26, 1, 0), Position = UDim2.fromOffset(20, 0), BackgroundTransparency = 1,
        Text = name, TextColor3 = C.TextDim, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        Active = false, ZIndex = 5,
    }, btn)
    fontMed(lbl)

    btn.MouseEnter:Connect(function()
        if Pages[name] and Pages[name].Visible then return end
        tween(btn, 0.12, { BackgroundTransparency = 0.94 })
    end)
    btn.MouseLeave:Connect(function()
        if Pages[name] and Pages[name].Visible then return end
        tween(btn, 0.15, { BackgroundTransparency = 1 })
    end)

    local page = new("ScrollingFrame", {
        Size = UDim2.new(1, -24, 1, -20), Position = UDim2.fromOffset(12, 10),
        BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 3,
        ScrollingDirection = Enum.ScrollingDirection.Y, ScrollingEnabled = true,
        ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
        ScrollBarThickness = 2, ScrollBarImageColor3 = C.White, ScrollBarImageTransparency = 0.6,
        AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(0, 0, 0, 0),
    }, Content)
    new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    new("UIPadding", { PaddingBottom = UDim.new(0, 14), PaddingRight = UDim.new(0, 8) }, page)

    Tabs[name]  = { btn = btn, lbl = lbl, bar = bar }
    Pages[name] = page
    btn.MouseButton1Click:Connect(function() setActiveTab(name) end)
    return page
end

-- ==================== WIDGETS ====================
local HEAD, BODY = 40, 158

local function glassRow(parent, order, h)
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, h or HEAD), BackgroundColor3 = C.White, BackgroundTransparency = 0.93,
        BorderSizePixel = 0, LayoutOrder = order, ZIndex = 3,
    }, parent)
    corner(row, 13)
    glassStroke(row, 0.6)
    sheen(row, 0.10, 35, 13)
    return row
end

local function hoverRow(row, hit)
    hit.MouseEnter:Connect(function() tween(row, 0.14, { BackgroundTransparency = 0.88 }) end)
    hit.MouseLeave:Connect(function() tween(row, 0.18, { BackgroundTransparency = 0.93 }) end)
end

local function createSection(parent, text, order)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Text = string.upper(text),
        TextColor3 = C.TextFaint, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order, ZIndex = 3, Active = false,
    }, parent)
    new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 8) }, lbl)
    fontBold(lbl)
    return lbl
end

-- ---------- Color wheel (HSV) ----------
local function buildPicker(container, startColor, onChange)
    local api = {}
    local h, s, v = startColor:ToHSV()
    local SIZE = 130
    local R = SIZE / 2

    local wheel = new("Frame", {
        Size = UDim2.fromOffset(SIZE, SIZE), Position = UDim2.fromOffset(18, 14),
        BackgroundTransparency = 1, ZIndex = 4,
    }, container)

    local STRIPS = 90
    local w = math.ceil(2 * math.pi * R / STRIPS) + 2
    for i = 0, STRIPS - 1 do
        local rot = i * 360 / STRIPS
        local st = new("Frame", {
            AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromOffset(w, R), Rotation = rot,
            BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 4, Active = false,
        }, wheel)
        new("UIGradient", {
            Rotation = 90,
            Color = ColorSequence.new(Color3.fromHSV(rot / 360, 1, 1), C.White),
        }, st)
    end

    local marker = new("Frame", {
        Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 6, Active = false,
    }, wheel)
    corner(marker, 7)
    new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }, marker)

    -- right side
    local prev = new("Frame", {
        Size = UDim2.fromOffset(34, 28), Position = UDim2.fromOffset(170, 14),
        BackgroundColor3 = startColor, BorderSizePixel = 0, ZIndex = 4,
    }, container)
    corner(prev, 9)
    glassStroke(prev, 0.9)

    local hexBox = new("TextBox", {
        Size = UDim2.fromOffset(110, 28), Position = UDim2.fromOffset(212, 14),
        BackgroundColor3 = C.White, BackgroundTransparency = 0.92, Text = "",
        TextColor3 = C.Text, PlaceholderText = "#RRGGBB", PlaceholderColor3 = C.TextFaint,
        TextSize = 11, ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 4,
    }, container)
    corner(hexBox, 9)
    glassStroke(hexBox, 0.6)
    fontMed(hexBox)

    local vLabel = new("TextLabel", {
        Size = UDim2.fromOffset(120, 14), Position = UDim2.fromOffset(170, 60), BackgroundTransparency = 1,
        Text = "BRIGHTNESS", TextColor3 = C.TextFaint, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4, Active = false,
    }, container)
    fontBold(vLabel)

    local vTrack = new("Frame", {
        Size = UDim2.new(1, -190, 0, 8), Position = UDim2.fromOffset(170, 82),
        BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 4,
    }, container)
    corner(vTrack, 4)
    local vGrad = new("UIGradient", { Color = ColorSequence.new(Color3.new(0, 0, 0), C.White) }, vTrack)
    local vKnob = new("Frame", {
        Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 6, Active = false,
    }, vTrack)
    corner(vKnob, 7)
    glassStroke(vKnob, 1)

    local hint = new("TextLabel", {
        Size = UDim2.new(1, -190, 0, 30), Position = UDim2.fromOffset(170, 112), BackgroundTransparency = 1,
        Text = "Drag the wheel for hue and saturation. You can also type a hex value.",
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
        hexBox.Text = "#" .. color3ToHex(col)
        vGrad.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.fromHSV(h, s, 1))
        vKnob.Position = UDim2.new(v, 0, 0.5, 0)
        if fire then onChange(col, color3ToHex(col)) end
    end

    local wheelHit = new("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 8,
    }, wheel)
    local vHit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, -8), BackgroundTransparency = 1,
        Text = "", AutoButtonColor = false, ZIndex = 8,
    }, vTrack)

    local dragWheel, dragV = false, false

    local function wheelFrom(pos)
        local c = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
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

-- ---------- Toggle (+ optional color wheel) ----------
local function createToggle(parent, label, default, order, callback, stateKey, colorOpt)
    local row = glassRow(parent, order, HEAD)
    row.ClipsDescendants = true

    local lbl = new("TextLabel", {
        Size = UDim2.new(1, colorOpt and -130 or -90, 0, HEAD), Position = UDim2.fromOffset(16, 0),
        BackgroundTransparency = 1, Text = label, TextColor3 = C.Text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left, Active = false, ZIndex = 4,
    }, row)
    fontMed(lbl)

    local pill = new("Frame", {
        Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -56, 0, 9),
        BackgroundColor3 = default and C.Accent or C.White,
        BackgroundTransparency = default and 0.12 or 0.86, BorderSizePixel = 0, Active = false, ZIndex = 4,
    }, row)
    corner(pill, 11)
    glassStroke(pill, 0.9)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(16, 16), Position = default and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3),
        BackgroundColor3 = default and C.White or Color3.fromRGB(196, 202, 218),
        BorderSizePixel = 0, Active = false, ZIndex = 5,
    }, pill)
    corner(knob, 8)

    local isOn = default
    local function update(val, silent)
        isOn = val
        tween(pill, 0.22, {
            BackgroundColor3 = val and C.Accent or C.White,
            BackgroundTransparency = val and 0.12 or 0.86,
        })
        tween(knob, 0.22, {
            Position = val and UDim2.fromOffset(21, 3) or UDim2.fromOffset(3, 3),
            BackgroundColor3 = val and C.White or Color3.fromRGB(196, 202, 218),
        })
        if callback then callback(val, silent) end
    end

    local hit = new("TextButton", {
        Size = UDim2.new(1, 0, 0, HEAD), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 6,
    }, row)
    hoverRow(row, hit)
    hit.MouseButton1Click:Connect(function() update(not isOn) end)

    -- color wheel
    if colorOpt then
        local currentColor = hexToColor3(colorOpt.hex) or C.Accent
        local picker, expanded = nil, false

        local body = new("Frame", {
            Size = UDim2.new(1, 0, 0, BODY), Position = UDim2.fromOffset(0, HEAD),
            BackgroundTransparency = 1, Visible = false, ZIndex = 3,
        }, row)
        hairline(body, UDim2.fromOffset(12, 0), UDim2.new(1, -24, 0, 1), false, 0.14)

        local swatch = new("TextButton", {
            Size = UDim2.fromOffset(22, 22), Position = UDim2.new(1, -94, 0, 9),
            BackgroundColor3 = currentColor, Text = "", AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 8,
        }, row)
        corner(swatch, 11)
        new("UIStroke", { Color = C.White, Transparency = 0.45, Thickness = 1.5 }, swatch)

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
                tween(row, 0.3, { Size = UDim2.new(1, 0, 0, HEAD + BODY) }, Enum.EasingStyle.Quint)
            else
                tween(row, 0.25, { Size = UDim2.new(1, 0, 0, HEAD) }, Enum.EasingStyle.Quint)
                task.delay(0.26, function() if not expanded then body.Visible = false end end)
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
        Size = size, Position = pos, BackgroundColor3 = C.White, BackgroundTransparency = 0.92,
        Text = text or "", TextColor3 = C.Text, PlaceholderText = placeholder or "", PlaceholderColor3 = C.TextFaint,
        TextSize = 11, ClearTextOnFocus = false, BorderSizePixel = 0, ZIndex = 6,
    }, parent)
    corner(box, 9)
    glassStroke(box, 0.6)
    fontMed(box)
    return box
end

local function createInput(parent, label, default, order, callback, stateKey)
    local row = glassRow(parent, order, HEAD)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -150, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1,
        Text = label, TextColor3 = C.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        Active = false, ZIndex = 4,
    }, row)
    fontMed(lbl)

    local box = glassBox(row, UDim2.fromOffset(92, 24), UDim2.new(1, -106, 0.5, -12), tostring(default), "value")
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
    local row = glassRow(parent, order, HEAD)
    local btn = new("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = label,
        TextColor3 = C.TextDim, TextSize = 12, AutoButtonColor = false, ZIndex = 6,
    }, row)
    fontMed(btn)
    local hoverCol = danger and C.Red or C.Text
    btn.MouseEnter:Connect(function()
        tween(row, 0.14, { BackgroundTransparency = 0.86 })
        tween(btn, 0.14, { TextColor3 = hoverCol })
    end)
    btn.MouseLeave:Connect(function()
        tween(row, 0.18, { BackgroundTransparency = 0.93 })
        tween(btn, 0.18, { TextColor3 = C.TextDim })
    end)
    btn.MouseButton1Down:Connect(function() tween(row, 0.08, { BackgroundTransparency = 0.8 }) end)
    btn.MouseButton1Click:Connect(callback)
end

local function createTextAction(parent, label, placeholder, order, callback)
    local row = glassRow(parent, order, HEAD)
    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -240, 1, 0), Position = UDim2.fromOffset(16, 0), BackgroundTransparency = 1,
        Text = label, TextColor3 = C.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        Active = false, ZIndex = 4,
    }, row)
    fontMed(lbl)

    local box = glassBox(row, UDim2.fromOffset(140, 24), UDim2.new(1, -200, 0.5, -12), "", placeholder)

    local btn = new("TextButton", {
        Size = UDim2.fromOffset(44, 24), Position = UDim2.new(1, -52, 0.5, -12),
        BackgroundColor3 = C.Accent, BackgroundTransparency = 0.82, Text = "Go",
        TextColor3 = C.Text, TextSize = 11, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 6,
    }, row)
    corner(btn, 9)
    glassStroke(btn, 0.8)
    fontBold(btn)
    btn.MouseEnter:Connect(function() tween(btn, 0.15, { BackgroundTransparency = 0.6 }) end)
    btn.MouseLeave:Connect(function() tween(btn, 0.15, { BackgroundTransparency = 0.82 }) end)
    btn.MouseButton1Click:Connect(function() callback(box.Text) end)
    return box
end

local function createSlider(parent, label, min, max, default, order, callback, onRelease, stateKey)
    default = math.clamp(default or min, min, max)
    local row = glassRow(parent, order, 56)

    local lbl = new("TextLabel", {
        Size = UDim2.new(1, -100, 0, 16), Position = UDim2.fromOffset(16, 9), BackgroundTransparency = 1,
        Text = label, TextColor3 = C.Text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        Active = false, ZIndex = 4,
    }, row)
    fontMed(lbl)
    local valLbl = new("TextLabel", {
        Size = UDim2.fromOffset(70, 16), Position = UDim2.new(1, -86, 0, 9), BackgroundTransparency = 1,
        Text = tostring(default), TextColor3 = C.Accent, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right,
        Active = false, ZIndex = 4,
    }, row)
    fontBold(valLbl)

    local trackF = new("Frame", {
        Size = UDim2.new(1, -32, 0, 6), Position = UDim2.fromOffset(16, 39),
        BackgroundColor3 = C.White, BackgroundTransparency = 0.86, BorderSizePixel = 0, ZIndex = 4,
    }, row)
    corner(trackF, 3)
    local rel0 = (default - min) / (max - min)
    local fill = new("Frame", {
        Size = UDim2.fromScale(rel0, 1), BackgroundColor3 = C.Accent, BorderSizePixel = 0, ZIndex = 5, Active = false,
    }, trackF)
    corner(fill, 3)
    local knob = new("Frame", {
        Size = UDim2.fromOffset(15, 15), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(rel0, 0, 0.5, 0), BackgroundColor3 = C.White, BorderSizePixel = 0, ZIndex = 6, Active = false,
    }, trackF)
    corner(knob, 8)
    glassStroke(knob, 1)

    local current, dragging = default, false

    local function setValue(val, silent)
        val = math.clamp(math.floor(val + 0.5), min, max)
        current = val
        local rel = (val - min) / (max - min)
        fill.Size = UDim2.fromScale(rel, 1)
        knob.Position = UDim2.new(rel, 0, 0.5, 0)
        valLbl.Text = tostring(val)
        if callback then callback(val, silent) end
    end
    local function updateFromX(x)
        local rel = math.clamp((x - trackF.AbsolutePosition.X) / math.max(1, trackF.AbsoluteSize.X), 0, 1)
        setValue(min + (max - min) * rel, false)
    end

    local hit = new("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 8,
    }, row)
    hoverRow(row, hit)
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            tween(knob, 0.12, { Size = UDim2.fromOffset(18, 18) })
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
                tween(knob, 0.12, { Size = UDim2.fromOffset(15, 15) })
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
local VisualPage   = createTab("Visuals",  1)
local MainPage     = createTab("Main",     2)
local MovementPage = createTab("Movement", 3)
local FunPage      = createTab("Fun",      4)
local SettingsPage = createTab("Settings", 5)
setActiveTab("Visuals")

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
            if obj.Name == "AbaddonBlur" then continue end
            if obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("ColorCorrectionEffect")
            or obj:IsA("SunRaysEffect") or obj:IsA("DepthOfFieldEffect") then
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

    local smoothedLook = nil
    backWalkConn = RunService.Heartbeat:Connect(function(dt)
        if State.Spin then return end
        local c = LocalPlayer.Character
        if not c then return end
        local h = c:FindFirstChildOfClass("Humanoid")
        local hrp = c:FindFirstChild("HumanoidRootPart")
        if not h or not hrp then return end
        h.AutoRotate = false
        local md = h.MoveDirection
        if md.Magnitude > 0.05 then
            local target = Vector3.new(-md.X, 0, -md.Z)
            if target.Magnitude > 0.01 then
                target = target.Unit
                smoothedLook = smoothedLook and smoothedLook:Lerp(target, math.clamp(dt * 9, 0, 1)) or target
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

local cam = workspace.CurrentCamera
local function setCameraFOV(value)
    State.CameraFOV = value
    if not cam then cam = workspace.CurrentCamera end
    if cam then cam.FieldOfView = value end
end

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

-- lock the time only while Custom Time is enabled
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

-- ==================== CONFIG SYSTEM ====================
local function saveConfig()
    if not writefile then pushLog("Executor does not support writefile", "error") return end
    local data = {}
    for k, v in pairs(State) do
        if k ~= "Open" and type(v) ~= "function" and type(v) ~= "table" then data[k] = v end
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

createSection(VisualPage, "World", 5)
simpleToggle(VisualPage, "Fullbright", 6, "Fullbright", function(v) setFullbright(v) end)
simpleToggle(VisualPage, "No Shadows", 7, nil, function(v) setNoShadows(v) end, nil, "enabled", "disabled")
simpleToggle(VisualPage, "No Textures", 8, nil, function(v, silent) setNoTextures(v, true) end, nil, "enabled", "disabled")
simpleToggle(VisualPage, "Custom Time", 9, "CustomTime")
createSlider(VisualPage, "Time of Day", 0, 24, 14, 10,
    function(v) State.ClockTime = v if State.CustomTime then Lighting.ClockTime = v end end,
    function(v) pushLog("ClockTime: " .. tostring(v), "info") end,
    "ClockTime")

createSection(VisualPage, "Camera", 11)
createSlider(VisualPage, "Field of View", 30, 120, 70, 12,
    function(v) setCameraFOV(v) end,
    function(v) pushLog("Camera FOV: " .. tostring(v), "info") end,
    "CameraFOV")

-- ==================== MAIN ====================
createSection(MainPage, "Skill Check", 1)
simpleToggle(MainPage, "Auto Hit Perfect Skillcheck", 2, "AutoSkillCheck")

createSection(MainPage, "Protection", 3)
simpleToggle(MainPage, "Anti-AFK", 4, "AntiAFK", function(v) setAntiAFK(v) end)
simpleToggle(MainPage, "Anti-Fling", 5, nil, function(v) setAntiFling(v) end)

-- ==================== MOVEMENT ====================
createSection(MovementPage, "Character", 1)
createInput(MovementPage, "WalkSpeed", 16, 2, function(v, silent)
    State.WalkSpeed = v
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = v end
    if silent then return end
    notify("WalkSpeed: " .. tostring(v))
    pushLog("WalkSpeed set to " .. tostring(v), "info")
end, "WalkSpeed")

createInput(MovementPage, "Hip Height", 0, 3, function(v, silent)
    State.HipHeight = v
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and v ~= 0 then hum.HipHeight = v end
    if silent then return end
    notify("HipHeight: " .. tostring(v))
    pushLog("HipHeight set to " .. tostring(v), "info")
end, "HipHeight")

simpleToggle(MovementPage, "Noclip", 4, nil, function(v) setNoclip(v) end)

createSection(MovementPage, "Flight", 5)
simpleToggle(MovementPage, "Fly  (WASD · Space · Ctrl)", 6, nil, function(v) setFly(v) end)
createInput(MovementPage, "Fly Speed", 60, 7, function(v, silent)
    State.FlySpeed = v
    if silent then return end
    notify("Fly Speed: " .. tostring(v))
    pushLog("Fly Speed: " .. tostring(v), "info")
end, "FlySpeed")

createSection(MovementPage, "Teleport", 8)
simpleToggle(MovementPage, "TP Tool  (LMB to teleport)", 9, nil, function(v) setTPTool(v) end)
createTextAction(MovementPage, "Goto Player", "nickname", 10, function(name) gotoPlayer(name) end)

-- ==================== FUN ====================
createSection(FunPage, "Character", 1)
simpleToggle(FunPage, "Back Walk", 2, nil, function(v) setBackWalk(v) end)
simpleToggle(FunPage, "Spin", 3, nil, function(v) setSpin(v) end)

createSection(FunPage, "Overlay", 4)
simpleToggle(FunPage, "Hoodwink", 5, nil, function(v) setHoodwink(v) end)

-- ==================== SETTINGS ====================
createSection(SettingsPage, "Interface", 1)
createToggle(SettingsPage, "Hide Username (watermark)", false, 2, function(v, silent)
    State.HideUsername = v
    if silent then return end
    pushLog("Watermark username: " .. (v and "@ellieabaddon" or "@" .. LocalPlayer.Name), "info")
end, "HideUsername")

createSection(SettingsPage, "Server", 3)
createButton(SettingsPage, "Server Hop", 4, serverHop)
createButton(SettingsPage, "Rejoin", 5, rejoin)

createSection(SettingsPage, "Config", 6)
createButton(SettingsPage, "Save Config", 7, saveConfig)
createButton(SettingsPage, "Load Config", 8, loadConfig)
createButton(SettingsPage, "Reset Config (defaults)", 9, resetConfig)
createButton(SettingsPage, "Delete Config File", 10, deleteConfig, true)

-- ==================== ESP ====================
local ESPFolder = new("Folder", { Name = "AbaddonESP" }, ScreenGui)
local playerEsp, playerTags, genEsp = {}, {}, {}

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
                    tag.Size = UDim2.new(0, 220, 0, 22)
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
                    l.Text = plr.Name
                    l.TextColor3 = col
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
        if obj:IsA("Model") and obj.Name:lower():find("generator") then
            if State.ESP_Generators then
                local h = genEsp[obj]
                if not h then
                    h = Instance.new("Highlight")
                    h.Adornee = obj
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.FillTransparency = 0.78
                    h.OutlineTransparency = 0.15
                    h.Parent = ESPFolder
                    genEsp[obj] = h
                end
                h.FillColor = ESPColors.Generator
                h.OutlineColor = ESPColors.Generator
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
    openToken = openToken + 1
    local myToken = openToken
    pushLog("Menu " .. (open and "opened" or "closed"), "info")

    if open then
        Panel.Visible, Overlay.Visible, Grid.Visible = true, true, true
        Panel.Size = UDim2.fromOffset(PW - 36, PH - 24)
        Panel.GroupTransparency = 1
        Overlay.BackgroundTransparency = 1

        tween(Panel, 0.38, { Size = UDim2.fromOffset(PW, PH), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
        tween(Overlay, 0.3, { BackgroundTransparency = 0.5 })
        tween(Blur, 0.4, { Size = 18 }, Enum.EasingStyle.Quint)
    else
        tween(Panel, 0.22, { Size = UDim2.fromOffset(PW - 20, PH - 14), GroupTransparency = 1 })
        tween(Overlay, 0.22, { BackgroundTransparency = 1 })
        tween(Blur, 0.26, { Size = 0 })
        task.delay(0.25, function()
            if myToken ~= openToken then return end
            Panel.Visible, Overlay.Visible, Grid.Visible = false, false, false
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
        Size = UDim2.fromOffset(300, 40), Position = UDim2.new(0.5, 0, 1, 40), AnchorPoint = Vector2.new(0.5, 1),
        BackgroundColor3 = C.Glass, BackgroundTransparency = 0.25, BorderSizePixel = 0,
        GroupTransparency = 1, ZIndex = 300,
    }, ScreenGui)
    corner(popup, 16)
    glassStroke(popup, 1)
    sheen(popup, 0.14, 35, 16)
    local txt = new("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1,
        Text = "Welcome, @" .. LocalPlayer.Name, TextColor3 = C.Text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3,
    }, popup)
    fontMed(txt)

    tween(popup, 0.45, { Position = UDim2.new(0.5, 0, 1, -56), GroupTransparency = 0 }, Enum.EasingStyle.Quint)
    task.wait(3)
    tween(popup, 0.4, { Position = UDim2.new(0.5, 0, 1, 60), GroupTransparency = 1 }, Enum.EasingStyle.Quint)
    task.wait(0.5)
    popup:Destroy()
end

-- ==================== CHARACTER HOOKS ====================
LocalPlayer.CharacterAdded:Connect(function(char)
    pushLog("Character loaded", "info")
    task.wait(0.4)
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then
        hum.WalkSpeed = State.WalkSpeed
        if State.HipHeight and State.HipHeight ~= 0 then hum.HipHeight = State.HipHeight end
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
    pushLog("Character unloading", "warn")
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
