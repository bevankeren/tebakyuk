--[[
    BEVERLY HUB v11.0
    TebakYuk Omniscient - Lime/Green Theme - No Emoticons
    Secret word read from: ScreenGui.PanelB.TargetFrame.TargetWordLabel
    Auto-answer via: ScreenGui.PanelA.TextBox -> ReleaseFocus
]]

------------------------------------------------------------------------
-- SERVICES
------------------------------------------------------------------------
local RS  = game:GetService("ReplicatedStorage")
local Plr = game:GetService("Players")
local Run = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CG  = game:GetService("CoreGui")
local TS  = game:GetService("TweenService")

local LP = Plr.LocalPlayer
local GameRemotes    = RS:WaitForChild("GameRemotes", 10)
local WordListModule = require(RS:WaitForChild("WordListModule"))

------------------------------------------------------------------------
-- PALETTE -- Lime Green Theme
------------------------------------------------------------------------
local P = {
    bg0  = Color3.fromRGB(240, 255, 240),  -- very light green
    bg1  = Color3.fromRGB(220, 250, 220),  -- light tint
    bg2  = Color3.fromRGB(200, 240, 200),  -- card background
    bg3  = Color3.fromRGB(180, 230, 180),  -- active state
    -- primary lime
    lim  = Color3.fromRGB(132, 204, 22),    -- lime-400
    grn  = Color3.fromRGB(34,  197, 94),    -- green-400
    teal = Color3.fromRGB(16,  185, 129),   -- emerald-400
    -- alerts
    yel  = Color3.fromRGB(210, 160, 0),     -- yellow, darker for light bg
    red  = Color3.fromRGB(220, 40, 40),     -- rose, darker
    -- text
    t1   = Color3.fromRGB(2, 60, 40),       -- very dark green
    t2   = Color3.fromRGB(10, 100, 60),     -- dark green
    t3   = Color3.fromRGB(40, 150, 90),     -- medium green
    -- border
    bdr  = Color3.fromRGB(160, 220, 160),
    bdrH = Color3.fromRGB(120, 200, 120),
}

------------------------------------------------------------------------
-- DATABASE
------------------------------------------------------------------------
local AllWords, AllWordsCombined, UniqueCategories = {}, {}, {}
local WordToCat = {}

for diffName, diffTable in pairs(WordListModule) do
    if type(diffTable) == "table" and diffName ~= "TTS_OVERRIDES" then
        for catName, wordList in pairs(diffTable) do
            local nk = string.upper(catName:gsub("[%W_]", ""))
            local display = catName:gsub("_", " ")
            if not AllWords[nk] then
                AllWords[nk] = {}
                table.insert(UniqueCategories, display)
            end
            if type(wordList) == "table" then
                for _, w in ipairs(wordList) do
                    local u = string.upper(tostring(w))
                    table.insert(AllWords[nk], u)
                    table.insert(AllWordsCombined, u)
                    WordToCat[u] = display
                end
            end
        end
    end
end

local function Dedupe(t)
    local s, u = {}, {}
    for _, w in ipairs(t) do if not s[w] then s[w]=true; u[#u+1]=w end end
    return u
end
for k, v in pairs(AllWords) do AllWords[k] = Dedupe(v) end
AllWordsCombined = Dedupe(AllWordsCombined)
table.sort(UniqueCategories)

------------------------------------------------------------------------
-- STATE
------------------------------------------------------------------------
local Cfg = {
    AutoAnswer = false,
    Delay      = 2.5,
    Speed      = 16,
    Noclip     = false,
    Fly        = false,
    FlySpd     = 50,
}
local St = { Role=nil, Len=0, Pat="", Firing=false, SecretWord=nil, RevealedCategory=nil }
local Farm = { Winner=false, Loser=false }

------------------------------------------------------------------------
-- CLEANUP
------------------------------------------------------------------------
for _, n in ipairs({"BeverlyHubV9","BeverlyHubV10","BeverlyHubV10_1","BeverlyHubV11"}) do
    local f = CG:FindFirstChild(n); if f then f:Destroy() end
end

------------------------------------------------------------------------
-- ROOT
------------------------------------------------------------------------
local Root = Instance.new("ScreenGui")
Root.Name = "BeverlyHubV11"
Root.ResetOnSpawn = false
Root.DisplayOrder = 9999
Root.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Root.IgnoreGuiInset = true
Root.Parent = CG

------------------------------------------------------------------------
-- UTILITIES
------------------------------------------------------------------------
local function corner(i, r)
    local c = Instance.new("UICorner", i); c.CornerRadius = UDim.new(0, r or 8); return c
end
local function stroke(i, col, th)
    local s = Instance.new("UIStroke", i)
    s.Color = col or P.bdr; s.Thickness = th or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    return s
end
local function grad(i, c0, c1, rot)
    local g = Instance.new("UIGradient", i)
    g.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, c0),
        ColorSequenceKeypoint.new(1, c1)
    }
    g.Rotation = rot or 90; return g
end
local function tw(i, t, props, es)
    return TS:Create(i, TweenInfo.new(t, es or Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props)
end
local function mLabel(parent, txt, font, size, col, xa)
    local l = Instance.new("TextLabel", parent)
    l.BackgroundTransparency = 1; l.Text = txt
    l.Font = font or Enum.Font.Gotham; l.TextSize = size or 12
    l.TextColor3 = col or P.t1
    l.TextXAlignment = xa or Enum.TextXAlignment.Left
    l.TextWrapped = true; l.Size = UDim2.new(1,0,1,0)
    return l
end
local function draggable(frame, handle)
    local down, ds, sp = false
    handle.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            down=true; ds=i.Position; sp=frame.Position
            i.Changed:Connect(function()
                if i.UserInputState == Enum.UserInputState.End then down=false end
            end)
        end
    end)
    UIS.InputChanged:Connect(function(i)
        if down and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - ds
            frame.Position = UDim2.new(sp.X.Scale, sp.X.Offset+d.X, sp.Y.Scale, sp.Y.Offset+d.Y)
        end
    end)
end
local function animBorder(s, c0, c1)
    task.spawn(function()
        local g = Instance.new("UIGradient", s)
        g.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, c0),
            ColorSequenceKeypoint.new(0.5, c1),
            ColorSequenceKeypoint.new(1, c0)
        }
        local a = 0
        while s.Parent do a=(a+0.8)%360; g.Rotation=a; Run.RenderStepped:Wait() end
    end)
end

------------------------------------------------------------------------
-- KEY SYSTEM
------------------------------------------------------------------------
local KeyCode = "beverlyhubontop"

local keyWrap = Instance.new("Frame", Root)
keyWrap.Size = UDim2.fromOffset(280, 140)
keyWrap.Position = UDim2.new(0.5, -140, 0.5, -70)
keyWrap.BackgroundColor3 = P.bg0
keyWrap.BackgroundTransparency = 0.35
keyWrap.BorderSizePixel = 0


local kc = Instance.new("UICorner", keyWrap); kc.CornerRadius = UDim.new(0, 12)
local ks = Instance.new("UIStroke", keyWrap); ks.Color = P.lim; ks.Thickness = 2; ks.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local kTitle = Instance.new("TextLabel", keyWrap)
kTitle.BackgroundTransparency = 1; kTitle.Text = "BEVERLY HUB - LOG IN"
kTitle.Font = Enum.Font.GothamBold; kTitle.TextSize = 14; kTitle.TextColor3 = P.t1
kTitle.Size = UDim2.new(1, 0, 0, 30); kTitle.Position = UDim2.new(0, 0, 0, 10)

local kInput = Instance.new("TextBox", keyWrap)
kInput.Size = UDim2.new(1, -40, 0, 36)
kInput.Position = UDim2.new(0, 20, 0, 48)
kInput.BackgroundColor3 = P.bg2
kInput.BackgroundTransparency = 0.2
kInput.BorderSizePixel = 0
kInput.Font = Enum.Font.Gotham; kInput.TextSize = 13; kInput.TextColor3 = P.t1
kInput.PlaceholderText = "Enter Key..."
kInput.PlaceholderColor3 = P.t3
kInput.Text = ""
local kic = Instance.new("UICorner", kInput); kic.CornerRadius = UDim.new(0, 6)
local kis = Instance.new("UIStroke", kInput); kis.Color = P.bdr; kis.Thickness = 1; kis.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local kBtn = Instance.new("TextButton", keyWrap)
kBtn.Size = UDim2.new(1, -40, 0, 32)
kBtn.Position = UDim2.new(0, 20, 0, 94)
kBtn.BackgroundColor3 = P.lim
kBtn.BorderSizePixel = 0
kBtn.Font = Enum.Font.GothamBold; kBtn.TextSize = 13; kBtn.TextColor3 = Color3.new(1,1,1)
kBtn.Text = "VERIFY"
local kbc = Instance.new("UICorner", kBtn); kbc.CornerRadius = UDim.new(0, 6)

------------------------------------------------------------------------
-- MAIN HUB WINDOW
------------------------------------------------------------------------
local W, H, SB, TBAR = 420, 355, 74, 38

local hubWrap = Instance.new("Frame", Root)
hubWrap.Name = "HubWrap"
hubWrap.Size = UDim2.fromOffset(W, H)
hubWrap.Position = UDim2.new(0, 14, 0, 14)
hubWrap.Visible = false

hubWrap.BackgroundTransparency = 1
hubWrap.ClipsDescendants = true

local hub = Instance.new("Frame", hubWrap)
hub.Size = UDim2.fromOffset(W, H)
hub.BackgroundColor3 = P.bg0
hub.BackgroundTransparency = 0.35
hub.BorderSizePixel = 0; corner(hub, 12)

-- animated green border
local hubSt = stroke(hub, P.lim, 1.5)
animBorder(hubSt, P.lim, P.teal)

-- TITLE BAR
local tbar = Instance.new("Frame", hub)
tbar.Size=UDim2.new(1,0,0,TBAR); tbar.BackgroundColor3=P.bg1
tbar.BackgroundTransparency=0.5; tbar.BorderSizePixel=0; corner(tbar,12)

local tFix=Instance.new("Frame",tbar)
tFix.Size=UDim2.new(1,0,0,12); tFix.Position=UDim2.new(0,0,1,-12)
tFix.BackgroundColor3=P.bg1; tFix.BackgroundTransparency=0.5; tFix.BorderSizePixel=0

local hubTitle = mLabel(tbar,"  BEVERLY HUB",Enum.Font.GothamBold,13,P.t2)
hubTitle.Size=UDim2.new(1,-80,1,0)

draggable(hubWrap, tbar)

local function winBtn(parent, xOff, ico, bg)
    local b = Instance.new("TextButton",parent)
    b.Size=UDim2.fromOffset(22,22); b.Position=UDim2.new(1,xOff,0.5,-11)
    b.BackgroundColor3=bg or P.bg3; b.BorderSizePixel=0
    b.Text=ico; b.Font=Enum.Font.GothamBold; b.TextSize=11; b.TextColor3=P.t2
    corner(b,5)
    b.MouseEnter:Connect(function() tw(b,0.1,{BackgroundColor3=(bg or P.bg3):Lerp(P.t1,0.15)}):Play() end)
    b.MouseLeave:Connect(function() tw(b,0.1,{BackgroundColor3=bg or P.bg3}):Play() end)
    return b
end
local hubMin   = winBtn(tbar,-52,"─")
local hubClose = winBtn(tbar,-27,"X",Color3.fromRGB(160,40,40))

-- SIDEBAR
local sidebar = Instance.new("Frame",hub)
sidebar.Size=UDim2.new(0,SB,1,-TBAR); sidebar.Position=UDim2.new(0,0,0,TBAR)
sidebar.BackgroundColor3=P.bg1; sidebar.BackgroundTransparency=0.3; sidebar.BorderSizePixel=0

local sbLine=Instance.new("Frame",hub)
sbLine.Size=UDim2.new(0,1,1,-TBAR); sbLine.Position=UDim2.new(0,SB,0,TBAR)
sbLine.BackgroundColor3=P.bdr; sbLine.BackgroundTransparency=0.5; sbLine.BorderSizePixel=0

local sbList=Instance.new("UIListLayout",sidebar)
sbList.SortOrder=Enum.SortOrder.LayoutOrder
sbList.Padding=UDim.new(0,2)
sbList.HorizontalAlignment=Enum.HorizontalAlignment.Center
Instance.new("UIPadding",sidebar).PaddingTop=UDim.new(0,8)

-- CONTENT
local content=Instance.new("Frame",hub)
content.Size=UDim2.new(1,-SB-1,1,-TBAR); content.Position=UDim2.new(0,SB+1,0,TBAR)
content.BackgroundTransparency=1; content.BorderSizePixel=0; content.ClipsDescendants=true

------------------------------------------------------------------------
-- TAB SYSTEM
------------------------------------------------------------------------
local tabMap = {}
local curTab = nil

local function makeTab(name, label, order)
    local btn=Instance.new("TextButton",sidebar)
    btn.Size=UDim2.new(1,-8,0,58); btn.LayoutOrder=order
    btn.BackgroundColor3=P.bg3; btn.BackgroundTransparency=1
    btn.BorderSizePixel=0; btn.Text=""; btn.AutoButtonColor=false; corner(btn,8)

    local icoL=mLabel(btn,label,Enum.Font.GothamBold,11,P.t3,Enum.TextXAlignment.Center)
    icoL.Size=UDim2.new(1,0,0,28); icoL.Position=UDim2.new(0,0,0,8)

    local namL=mLabel(btn,name:upper(),Enum.Font.GothamBold,8,P.t3,Enum.TextXAlignment.Center)
    namL.Size=UDim2.new(1,0,0,12); namL.Position=UDim2.new(0,0,0,36)

    local ind=Instance.new("Frame",btn)
    ind.Size=UDim2.new(0,3,0.55,0); ind.AnchorPoint=Vector2.new(0,0.5)
    ind.Position=UDim2.new(0,0,0.5,0)
    ind.BackgroundColor3=P.lim; ind.BackgroundTransparency=1; ind.BorderSizePixel=0; corner(ind,2)

    local page=Instance.new("ScrollingFrame",content)
    page.Name="Page_"..name; page.Size=UDim2.new(1,-4,1,-6); page.Position=UDim2.new(0,2,0,3)
    page.BackgroundTransparency=1; page.Visible=false; page.BorderSizePixel=0
    page.ScrollBarThickness=3; page.ScrollBarImageColor3=P.lim
    page.CanvasSize=UDim2.new(0,0,0,0); page.AutomaticCanvasSize=Enum.AutomaticSize.Y
    page.ScrollingDirection=Enum.ScrollingDirection.Y
    local pl=Instance.new("UIListLayout",page)
    pl.SortOrder=Enum.SortOrder.LayoutOrder; pl.Padding=UDim.new(0,5)
    Instance.new("UIPadding",page).PaddingTop=UDim.new(0,4)

    local ctrl = {}
    function ctrl.on()
        tw(btn,0.18,{BackgroundTransparency=0.72}):Play()
        tw(icoL,0.18,{TextColor3=P.lim}):Play()
        tw(namL,0.18,{TextColor3=P.t2}):Play()
        tw(ind,0.18,{BackgroundTransparency=0}):Play()
    end
    function ctrl.off()
        tw(btn,0.18,{BackgroundTransparency=1}):Play()
        tw(icoL,0.18,{TextColor3=P.t3}):Play()
        tw(namL,0.18,{TextColor3=P.t3}):Play()
        tw(ind,0.18,{BackgroundTransparency=1}):Play()
    end

    tabMap[name]={btn=btn,page=page,ctrl=ctrl}

    btn.MouseButton1Click:Connect(function()
        if curTab==name then return end
        if curTab then tabMap[curTab].page.Visible=false; tabMap[curTab].ctrl.off() end
        curTab=name; page.Visible=true; ctrl.on()
    end)
    btn.MouseEnter:Connect(function() if curTab~=name then tw(btn,0.1,{BackgroundTransparency=0.85}):Play() end end)
    btn.MouseLeave:Connect(function() if curTab~=name then tw(btn,0.1,{BackgroundTransparency=1}):Play() end end)

    return page
end

------------------------------------------------------------------------
-- COMPONENTS
------------------------------------------------------------------------
local function secLabel(parent, txt, order)
    local f=Instance.new("Frame",parent); f.Size=UDim2.new(1,0,0,16); f.BackgroundTransparency=1; f.LayoutOrder=order
    local l=mLabel(f,txt:upper(),Enum.Font.GothamBold,8,P.t3); l.Size=UDim2.new(1,-4,1,0); l.Position=UDim2.new(0,4,0,0)
    local ul=Instance.new("Frame",f); ul.Size=UDim2.new(1,-4,0,1); ul.Position=UDim2.new(0,2,1,-1)
    ul.BackgroundColor3=P.bdr; ul.BackgroundTransparency=0.5; ul.BorderSizePixel=0
    return f
end

local function cardF(parent, h, order)
    local f=Instance.new("Frame",parent)
    f.Size=UDim2.new(1,0,0,h); f.LayoutOrder=order
    f.BackgroundColor3=P.bg2; f.BackgroundTransparency=0.25
    f.BorderSizePixel=0; corner(f,8); stroke(f,P.bdr,1)
    return f
end

local function mkToggle(parent, lText, dText, default, order, cb)
    local h = dText and 50 or 38
    local f = cardF(parent, h, order)
    local l = mLabel(f, lText, Enum.Font.GothamBold, 12, P.t1)
    l.Size=UDim2.new(1,-58,0,20); l.Position=UDim2.new(0,12,0,dText and 8 or 9)
    if dText then
        local d=mLabel(f,dText,Enum.Font.Gotham,10,P.t3); d.Size=UDim2.new(1,-58,0,14); d.Position=UDim2.new(0,12,0,28)
    end
    local track=Instance.new("Frame",f); track.Size=UDim2.fromOffset(36,20); track.Position=UDim2.new(1,-46,0.5,-10); track.BorderSizePixel=0; corner(track,10)
    local knob=Instance.new("Frame",track); knob.Size=UDim2.fromOffset(14,14); knob.Position=UDim2.new(0,3,0.5,-7); knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; corner(knob,7)
    local val=default
    local function ref(anim)
        local t=anim and 0.18 or 0
        if val then tw(track,t,{BackgroundColor3=P.lim}):Play(); tw(knob,t,{Position=UDim2.new(0,19,0.5,-7)}):Play()
        else tw(track,t,{BackgroundColor3=P.bg3}):Play(); tw(knob,t,{Position=UDim2.new(0,3,0.5,-7)}):Play() end
    end
    ref(false)
    local click=Instance.new("TextButton",f)
    click.Size=UDim2.new(1,0,1,0); click.BackgroundTransparency=1; click.Text=""
    click.MouseButton1Click:Connect(function() val=not val; ref(true); cb(val) end)
    return f
end

local function mkSlider(parent, lText, mn, mx, step, default, order, cb)
    local f=cardF(parent,52,order)
    local l=mLabel(f,lText,Enum.Font.GothamBold,12,P.t1); l.Size=UDim2.new(0.65,0,0,20); l.Position=UDim2.new(0,12,0,6)
    local vl=mLabel(f,tostring(default),Enum.Font.GothamBold,12,P.grn,Enum.TextXAlignment.Right); vl.Size=UDim2.new(0.3,-10,0,20); vl.Position=UDim2.new(0.7,0,0,6)
    local track=Instance.new("Frame",f); track.Size=UDim2.new(1,-24,0,5); track.Position=UDim2.new(0,12,0,34); track.BackgroundColor3=P.bg3; track.BorderSizePixel=0; corner(track,3)
    local fill=Instance.new("Frame",track); fill.Size=UDim2.new((default-mn)/(mx-mn),0,1,0); fill.BackgroundColor3=P.lim; fill.BorderSizePixel=0; corner(fill,3); grad(fill,P.lim,P.teal,0)
    local knob=Instance.new("Frame",track); knob.Size=UDim2.fromOffset(12,12); knob.AnchorPoint=Vector2.new(0.5,0.5); knob.Position=UDim2.new((default-mn)/(mx-mn),0,0.5,0); knob.BackgroundColor3=Color3.new(1,1,1); knob.BorderSizePixel=0; corner(knob,6)
    local drag=false
    local function setV(px)
        local rel=math.clamp((px-track.AbsolutePosition.X)/track.AbsoluteSize.X,0,1)
        local v=math.round((mn+(mx-mn)*rel)/step)*step; v=math.clamp(v,mn,mx)
        local pct=(v-mn)/(mx-mn)
        fill.Size=UDim2.new(pct,0,1,0); knob.Position=UDim2.new(pct,0,0.5,0); vl.Text=tostring(v); cb(v)
    end
    track.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true; setV(i.Position.X) end end)
    track.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then setV(i.Position.X) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
    return f
end

------------------------------------------------------------------------
-- PAGES
------------------------------------------------------------------------
local oPage = makeTab("OP", "OP", 1)
local fPage = makeTab("Farm", "FARM", 2)
local mPage = makeTab("Move",   "MOVE",   3)

-- OP
secLabel(oPage, "Auto Answer", 1)
mkToggle(oPage, "Auto Answer", "Auto-kirim kandidat kata", Cfg.AutoAnswer, 2, function(v) Cfg.AutoAnswer=v end)
mkSlider(oPage, "Delay (detik)", 0.5, 8, 0.5, Cfg.Delay, 3, function(v) Cfg.Delay=v end)

secLabel(oPage, "Status", 4)
local statCard = cardF(oPage, 72, 5)

local sRole = mLabel(statCard, "  Role  :  --", Enum.Font.GothamBold, 12, P.t2)
sRole.Size=UDim2.new(1,0,0,22); sRole.Position=UDim2.new(0,0,0,4)

local sWord = mLabel(statCard, "  Kata musuh  :  --", Enum.Font.GothamBold, 13, P.lim)
sWord.Size=UDim2.new(1,0,0,22); sWord.Position=UDim2.new(0,0,0,24)

local sInfo = mLabel(statCard, "  --", Enum.Font.Gotham, 10, P.t3)
sInfo.Size=UDim2.new(1,0,0,16); sInfo.Position=UDim2.new(0,0,0,46)

local sFire = mLabel(statCard, "", Enum.Font.Gotham, 10, P.grn)
sFire.Size=UDim2.new(1,0,0,14); sFire.Position=UDim2.new(0,0,0,56)

-- Farm
secLabel(fPage, "Role Auto Farm", 1)
mkToggle(fPage, "Pemberi Kata (Tumbal)", "Membocorkan Rahasia di Global Chat", Farm.Loser, 2, function(v) Farm.Loser=v end)
mkToggle(fPage, "Penebak (Winner)", "Menunggu Bocoran Chat & Auto-Win", Farm.Winner, 3, function(v) Farm.Winner=v end)

-- Movement
secLabel(mPage, "Player", 1)
mkToggle(mPage, "Noclip", "Tembus dinding", Cfg.Noclip, 2, function(v) Cfg.Noclip=v end)
mkSlider(mPage, "WalkSpeed", 16, 150, 2, Cfg.Speed, 3, function(v) Cfg.Speed=v end)
secLabel(mPage, "Fly", 4)
mkToggle(mPage, "Enable Fly", "WASD + Space / Ctrl", Cfg.Fly, 5, function(v)
    Cfg.Fly=v
    if not v then
        local hrp=LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            for _, n in ipairs({"BvFlyGyro","BvFlyVel"}) do local o=hrp:FindFirstChild(n); if o then o:Destroy() end end
        end
    end
end)
mkSlider(mPage, "Fly Speed", 10, 250, 5, Cfg.FlySpd, 6, function(v) Cfg.FlySpd=v end)

-- activate OP default
curTab="OP"; oPage.Visible=true; tabMap["OP"].ctrl.on()

------------------------------------------------------------------------
-- MINIMIZE / CLOSE (Hub)
------------------------------------------------------------------------
local hubMin2=false
hubMin.MouseButton1Click:Connect(function()
    hubMin2=not hubMin2
    tw(hubWrap,0.25,{Size=hubMin2 and UDim2.fromOffset(W,TBAR) or UDim2.fromOffset(W,H)}):Play()
    hubMin.Text=hubMin2 and "[]" or "─"
end)
hubClose.MouseButton1Click:Connect(function()
    tw(hubWrap,0.2,{Size=UDim2.fromOffset(0,0)}):Play()
    task.delay(0.25,function() hubWrap.Visible=false end)
end)

------------------------------------------------------------------------
-- KAMUS / LIVE FEED PANEL
------------------------------------------------------------------------
local KW, KH, KTBAR = 265, 415, 36

local kamWrap=Instance.new("Frame",Root)
kamWrap.Name="KamusWrap"
kamWrap.Size=UDim2.fromOffset(KW,KH); kamWrap.Position=UDim2.new(1,-KW-14,0,14)
kamWrap.BackgroundTransparency=1; kamWrap.ClipsDescendants=true
kamWrap.Visible=false

local kamF=Instance.new("Frame",kamWrap)
kamF.Size=UDim2.fromOffset(KW,KH); kamF.BackgroundColor3=P.bg0
kamF.BackgroundTransparency=0.35; kamF.BorderSizePixel=0; corner(kamF,10)

local kamSt=stroke(kamF,P.grn,1.5); animBorder(kamSt,P.grn,P.lim)

-- kamus title bar
local ktbar=Instance.new("Frame",kamF)
ktbar.Size=UDim2.new(1,0,0,KTBAR); ktbar.BackgroundColor3=P.bg1; ktbar.BackgroundTransparency=0.5; ktbar.BorderSizePixel=0; corner(ktbar,10)
local ktFix=Instance.new("Frame",ktbar)
ktFix.Size=UDim2.new(1,0,0,10); ktFix.Position=UDim2.new(0,0,1,-10); ktFix.BackgroundColor3=P.bg1; ktFix.BackgroundTransparency=0.5; ktFix.BorderSizePixel=0

local ktitle=mLabel(ktbar,"  DATABASE & LIVE FEED",Enum.Font.GothamBold,12,P.t2)
ktitle.Size=UDim2.new(1,-56,1,0)

draggable(kamWrap,ktbar)
local kamMinBtn=winBtn(ktbar,-52,"─")
local kamClsBtn=winBtn(ktbar,-27,"X",Color3.fromRGB(160,40,40))

local kamScroll=Instance.new("ScrollingFrame",kamF)
kamScroll.Size=UDim2.new(1,-6,1,-(KTBAR+4)); kamScroll.Position=UDim2.new(0,3,0,KTBAR+2)
kamScroll.BackgroundTransparency=1; kamScroll.ScrollBarThickness=3; kamScroll.ScrollBarImageColor3=P.lim
kamScroll.BorderSizePixel=0; kamScroll.CanvasSize=UDim2.new(0,0,0,0); kamScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
kamScroll.ScrollingDirection=Enum.ScrollingDirection.Y
local kLayout=Instance.new("UIListLayout",kamScroll)
kLayout.SortOrder=Enum.SortOrder.LayoutOrder; kLayout.Padding=UDim.new(0,3)

local kamIsMin=false
kamMinBtn.MouseButton1Click:Connect(function()
    kamIsMin=not kamIsMin
    tw(kamWrap,0.25,{Size=kamIsMin and UDim2.fromOffset(KW,KTBAR) or UDim2.fromOffset(KW,KH)}):Play()
    kamMinBtn.Text=kamIsMin and "[]" or "─"
end)
kamClsBtn.MouseButton1Click:Connect(function()
    tw(kamWrap,0.2,{Size=UDim2.fromOffset(0,0)}):Play()
    task.delay(0.25,function() kamWrap.Visible=false end)
end)

------------------------------------------------------------------------
-- KAMUS CONTENT HELPERS
------------------------------------------------------------------------
local kOrd=0
local function kClear()
    kOrd=0
    for _,c in ipairs(kamScroll:GetChildren()) do if c:IsA("GuiObject") then c:Destroy() end end
end
local function kLbl(txt,col,bold,fixH)
    kOrd+=1
    local l=Instance.new("TextLabel",kamScroll)
    if fixH then l.Size=UDim2.new(1,-4,0,fixH); l.AutomaticSize=Enum.AutomaticSize.None
    else l.Size=UDim2.new(1,-4,0,0); l.AutomaticSize=Enum.AutomaticSize.Y end
    l.BackgroundTransparency=1; l.TextXAlignment=Enum.TextXAlignment.Left
    l.TextColor3=col or P.t2; l.Font=bold and Enum.Font.GothamBold or Enum.Font.Gotham
    l.TextSize=11; l.TextWrapped=true; l.Text=txt; l.LayoutOrder=kOrd
    return l
end
local function kDiv()
    kOrd+=1
    local f=Instance.new("Frame",kamScroll); f.Size=UDim2.new(1,-4,0,1); f.BackgroundColor3=P.bdrH
    f.BackgroundTransparency=0.5; f.BorderSizePixel=0; f.LayoutOrder=kOrd; grad(f,P.lim,P.teal,0)
end
local function kWordBtn(txt,col,highlight)
    kOrd+=1
    local f=Instance.new("Frame",kamScroll)
    f.Size=UDim2.new(1,-4,0,highlight and 26 or 22)
    f.BackgroundColor3=highlight and P.bg3 or P.bg2
    f.BackgroundTransparency=0.25
    f.BorderSizePixel=0; f.LayoutOrder=kOrd; corner(f,5)
    if highlight then stroke(f,P.lim,1) end
    local b=Instance.new("TextButton",f)
    b.Size=UDim2.new(1,0,1,0); b.BackgroundTransparency=1
    b.TextXAlignment=Enum.TextXAlignment.Left; b.Font=highlight and Enum.Font.GothamBold or Enum.Font.Gotham
    b.TextSize=highlight and 12 or 11; b.TextColor3=col or P.t1; b.Text="  "..txt
    b.MouseEnter:Connect(function() tw(f,0.1,{BackgroundTransparency=0.08}):Play() end)
    b.MouseLeave:Connect(function() tw(f,0.1,{BackgroundTransparency=0.25}):Play() end)
    return b
end

------------------------------------------------------------------------
-- DATABASE VIEW
------------------------------------------------------------------------
local function BuildDB()
    kClear()
    kLbl("DATABASE KATA",P.grn,true,16)
    kDiv()
    for _,cat in ipairs(UniqueCategories) do
        local nk=string.upper(cat:gsub("[%W_]",""))
        local words=AllWords[nk] or {}
        if #words>0 then
            kOrd+=1; local hord=kOrd
            local hdr=Instance.new("TextButton",kamScroll)
            hdr.Size=UDim2.new(1,-4,0,24); hdr.BackgroundColor3=P.bg2; hdr.BackgroundTransparency=0.4
            hdr.BorderSizePixel=0; hdr.LayoutOrder=hord
            hdr.TextXAlignment=Enum.TextXAlignment.Left; hdr.Font=Enum.Font.GothamBold
            hdr.TextSize=11; hdr.TextColor3=P.t1
            hdr.Text="  +  "..cat.."  ("..#words..")"; corner(hdr,5); stroke(hdr,P.bdr,1)
            kOrd+=1; local cord=kOrd
            local cont=Instance.new("Frame",kamScroll)
            cont.Size=UDim2.new(1,-4,0,0); cont.AutomaticSize=Enum.AutomaticSize.Y
            cont.BackgroundTransparency=1; cont.Visible=false; cont.LayoutOrder=cord; cont.BorderSizePixel=0
            local cl=Instance.new("UIListLayout",cont); cl.Padding=UDim.new(0,2)
            hdr.MouseButton1Click:Connect(function()
                cont.Visible=not cont.Visible
                hdr.Text=(cont.Visible and "  -  " or "  +  ")..cat.."  ("..#words..")"
                tw(hdr,0.15,{BackgroundTransparency=cont.Visible and 0.1 or 0.4}):Play()
            end)
            for _,w in ipairs(words) do
                local wf=Instance.new("Frame",cont); wf.Size=UDim2.new(1,-8,0,18); wf.BackgroundColor3=P.bg0; wf.BackgroundTransparency=0.5; wf.BorderSizePixel=0; corner(wf,3)
                mLabel(wf,"    "..w,Enum.Font.Gotham,10,P.t3)
            end
        end
    end
end

------------------------------------------------------------------------
-- LIVE FEED — PENEBAK (Role A)
------------------------------------------------------------------------
local function RunAutoTargetCat(cands)
    if St.Role~="A" then return end
    St.Firing=true
    task.spawn(function()
        for i,w in ipairs(cands) do
            if St.Role~="A" then break end
            sFire.Text="  Mencari: "..w.." ("..i.."/"..#cands..")"
            sWord.Text="  Tebak  :  "..w
            sWord.TextColor3=P.lim
            FireAnswer(w)
            task.wait(Cfg.Delay)
        end
        St.Firing=false; sFire.Text=""
        if St.Role=="A" then sWord.Text="  Selesai mencari."; sWord.TextColor3=P.t3 end
    end)
end

local function UpdateFeedA(candidates)
    kClear()
    kamWrap.Visible=true

    local pat=St.Pat~="" and St.Pat or string.rep("_ ",St.Len):gsub(" $","")
    kLbl("LIVE FEED  --  "..St.Len.." Huruf",P.grn,true,16)
    kLbl("Pola:  "..pat,P.t2,false,14)
    kDiv()

    sRole.TextColor3=P.grn; sRole.Text="  Role  :  PENEBAK"
    sWord.Text="  Mencari tau dari database..."
    sWord.TextColor3=P.t3

    if #candidates==0 then
        kLbl("Tidak ada kata cocok di database",P.red,true); sInfo.Text="  Kandidat: 0"; return
    end
    sInfo.Text="  Kandidat: "..#candidates
    sFire.Text=St.Firing and "  Sedang nembak..." or ""

    local grouped = {}
    for _, w in ipairs(candidates) do
        local cat = WordToCat[w] or "Lainnya"
        if not grouped[cat] then grouped[cat] = {} end
        table.insert(grouped[cat], w)
    end

    local sortedCats = {}
    for cat in pairs(grouped) do table.insert(sortedCats, cat) end
    table.sort(sortedCats)

    for _, cat in ipairs(sortedCats) do
        local groupWords = grouped[cat]
        kOrd+=1; local hord=kOrd
        
        local catHdr = Instance.new("Frame", kamScroll)
        catHdr.Size=UDim2.new(1,-4,0,24); catHdr.BackgroundTransparency=1; catHdr.LayoutOrder=hord
        
        local lLabel = mLabel(catHdr, "  ["..cat.."] - "..#groupWords.." kata", Enum.Font.GothamBold, 11, P.yel)
        lLabel.Size = UDim2.new(0.8, 0, 1, 0)
        
        local btnPlay = Instance.new("TextButton", catHdr)
        btnPlay.Size=UDim2.new(0,20,0,20); btnPlay.Position=UDim2.new(1,-24,0,2)
        btnPlay.BackgroundColor3=P.lim; btnPlay.BorderSizePixel=0; corner(btnPlay,4)
        btnPlay.Font=Enum.Font.GothamBold; btnPlay.Text=">"; btnPlay.TextColor3=Color3.new(1,1,1)
        btnPlay.MouseButton1Click:Connect(function()
            if not St.Firing then RunAutoTargetCat(groupWords) end
        end)
        
        for _, w in ipairs(groupWords) do
            local bw = kWordBtn(w, P.t1, false)
            bw.MouseButton1Click:Connect(function() FireAnswer(w) end)
        end
        kDiv()
    end
end

------------------------------------------------------------------------
-- LIVE FEED — PEMBERI KATA (Role B)
------------------------------------------------------------------------
local questionLog={}
local function RebuildRoleB()
    kClear()
    kamWrap.Visible=true
    kLbl("PEMBERI KATA",P.yel,true,16)
    kDiv()
    if St.SecretWord then
        kLbl("Kata rahasia kamu:",P.t3,false,12)
        kWordBtn(St.SecretWord,P.lim,true)
    end
    kDiv()
    kLbl("Pertanyaan masuk:",P.t2,true,14)
    if #questionLog==0 then kLbl("  (belum ada pertanyaan)",P.t3)
    else for i=#questionLog,1,-1 do kWordBtn(questionLog[i],P.t2) end end
    sRole.TextColor3=P.yel; sRole.Text="  Role  :  PEMBERI KATA"
    sWord.Text="  Kata rahasia  :  "..(St.SecretWord or "--")
    sWord.TextColor3=P.yel
    sInfo.Text="  Pilih: Ya / Tidak / Bisa Jadi"; sFire.Text=""
end

------------------------------------------------------------------------
-- ENGINE
------------------------------------------------------------------------
local function GetCandidates(len, pat)
    if len==0 then return {} end
    local lp="^"
    if pat and pat~="" then
        local c=pat:gsub("%s+","")
        for i=1,#c do local ch=c:sub(i,i); lp=lp..(ch=="_" and "." or ch:upper()) end
        lp=lp.."$"
    else lp=lp..string.rep(".",len).."$" end
    local res={}
    for _,word in ipairs(AllWordsCombined) do
        local cw=word:gsub("%s+","")
        if #cw==len then local ok,m=pcall(string.match,cw,lp); if ok and m then res[#res+1]=word end end
    end
    return res
end

local function FireAnswer(word)
    local r=GameRemotes:FindFirstChild("AskQuestion"); if r then r:FireServer(word) end
end

local function RunAutoFire(cands)
    if not Cfg.AutoAnswer or St.Role~="A" or St.Firing then return end
    St.Firing=true; sFire.Text="  Auto-fire dimulai..."
    task.spawn(function()
        task.wait(1.2)

        if not St.RevealedCategory and #cands > 15 and (St.Pat=="" or string.rep("_ ",St.Len):gsub(" $","")==St.Pat) then
             local firstAsk = true
             for _, cat in ipairs(UniqueCategories) do
                 if St.Role~="A" or not Cfg.AutoAnswer or St.RevealedCategory then break end

                 sWord.Text="  Tanya  : "..cat
                 sWord.TextColor3=P.yel
                 if firstAsk then
                     FireAnswer("Apakah ini " .. cat .. "?")
                     firstAsk = false
                 else
                     FireAnswer(cat .. "?")
                 end
                 
                 for w=1, 4 do
                     task.wait(0.85)
                     if St.RevealedCategory then break end
                 end
             end
             
             sFire.Text="  Menunggu Kategori Muncul..."
             while St.Role=="A" and Cfg.AutoAnswer and not St.RevealedCategory do
                 task.wait(1)
             end
        end

        if not Cfg.AutoAnswer or St.Role~="A" then St.Firing=false; return end

        if St.RevealedCategory then
            sWord.Text="  Kategori: "..St.RevealedCategory
            sWord.TextColor3=P.grn
            local filtered = {}
            for _, w in ipairs(cands) do
                if (WordToCat[w] or ""):upper() == St.RevealedCategory:upper() then
                    table.insert(filtered, w)
                end
            end
            if #filtered > 0 then
                cands = filtered
                UpdateFeedA(cands)
            end
            
            sFire.Text = "  Menyamar (tunggu 3 detik)..."
            task.wait(3.5)
        end

        for i,w in ipairs(cands) do
            if St.Role~="A" or not Cfg.AutoAnswer then break end
            sFire.Text="  Mencari: "..w.." ("..i.."/"..#cands..")"
            sWord.Text="  Tebak  :  "..w
            sWord.TextColor3=P.lim
            FireAnswer(w)
            task.wait(Cfg.Delay)
        end
        St.Firing=false; sFire.Text=""
        if St.Role=="A" then sWord.Text="  Selesai mencari."; sWord.TextColor3=P.t3 end
    end)
end

------------------------------------------------------------------------
-- AUTO FARM ENGINE
------------------------------------------------------------------------
local function AutoJoinNextRound()
    if not Farm.Winner and not Farm.Loser then return end
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local hum = LP.Character and LP.Character:FindFirstChild("Humanoid")
    if not hrp or not hum then return end
    if hum.Sit then return end

    if Farm.Winner then task.wait(0.5) end

    local seats = {}
    for _, s in ipairs(workspace:GetDescendants()) do
        if s:IsA("Seat") and not s.Occupant then
            local dist = (s.Position - hrp.Position).Magnitude
            if dist < 60 then
                table.insert(seats, {seat = s, dist = dist})
            end
        end
    end
    
    table.sort(seats, function(a, b) return a.dist < b.dist end)
    
    if #seats > 0 then
        local target = seats[1].seat
        hrp.CFrame = target.CFrame * CFrame.new(0, 3, 0)
        task.wait(0.2)
        target:Sit(hum)
    end
end

-- Looping penjamin auto join kalau belum join
task.spawn(function()
    while task.wait(2.5) do
        if (Farm.Winner or Farm.Loser) and St.Role == nil then
            AutoJoinNextRound()
        end
    end
end)

local function WhisperLoserWord(word)
    local tcs = game:GetService("TextChatService")
    if tcs.ChatVersion == Enum.ChatVersion.TextChatService then
        local gen = tcs:FindFirstChild("TextChannels") and tcs.TextChannels:FindFirstChild("RBXGeneral")
        if gen then gen:SendAsync(word) end
    else
        local rep = game:GetService("ReplicatedStorage")
        local dcc = rep:FindFirstChild("DefaultChatSystemChatEvents")
        if dcc and dcc:FindFirstChild("SayMessageRequest") then
            dcc.SayMessageRequest:FireServer(word, "All")
        end
    end
end

------------------------------------------------------------------------
-- REMOTE HOOKS
------------------------------------------------------------------------
GameRemotes:WaitForChild("Notification").OnClientEvent:Connect(function(msg)
    if type(msg) == "string" then
        local cat = msg:match("Kategori%-nya adalah <font.->(.-)</font>")
        if cat then
            St.RevealedCategory = cat:gsub("[^%a%s]", "") -- Bersihkan titik, seru, dll
        end
    end
end)

GameRemotes:WaitForChild("ShowBubbleChat").OnClientEvent:Connect(function(head, msg, color)
    if Farm.Winner and St.Role == "A" and type(msg)=="string" then
        local w = msg:upper()
        if WordToCat[w] then
            FireAnswer(w)
        end
    end
end)

GameRemotes:WaitForChild("StartRound").OnClientEvent:Connect(function(role, arg2, arg3)
    St.Role=role; St.Pat=""; St.Firing=false; questionLog={}; St.RevealedCategory=nil

    if role=="A" then
        St.SecretWord=nil
        St.Len=type(arg3)=="number" and arg3
            or (type(arg2)=="string" and select(2,arg2:gsub("_","")) or 0)
        
        local c=GetCandidates(St.Len,"")
        UpdateFeedA(c)

        if Cfg.AutoAnswer then
            task.delay(2.5, function() RunAutoFire(c) end)
        end

    elseif role=="B" then
        St.SecretWord=type(arg2)=="string" and arg2:upper() or nil
        St.Len=St.SecretWord and #St.SecretWord or 0
        RebuildRoleB()
        
        if Farm.Loser and St.SecretWord then
            sFire.Text = "  Membocorkan ke chat (Bypass)..."
            task.delay(1.5, function() WhisperLoserWord(St.SecretWord) end)
        end
    end
end)

GameRemotes:WaitForChild("UpdateClue").OnClientEvent:Connect(function(s)
    if type(s)~="string" or St.Role~="A" then return end
    St.Pat=s
    if St.Len>0 then
        local c=GetCandidates(St.Len,St.Pat)
        UpdateFeedA(c)
        RunAutoFire(c)
    end
end)

-- Log questions when Role B
GameRemotes:WaitForChild("AskQuestion").OnClientEvent:Connect(function(q)
    if St.Role=="B" and type(q)=="string" then
        table.insert(questionLog,q); if #questionLog>20 then table.remove(questionLog,1) end
        RebuildRoleB()
    end
end)

GameRemotes:WaitForChild("EndRound").OnClientEvent:Connect(function()
    St.Len=0; St.Pat=""; St.Role=nil; St.Firing=false; St.SecretWord=nil; questionLog={}
    sRole.Text="  Role  :  --"; sRole.TextColor3=P.t2
    sWord.Text="  Kata musuh  :  --"; sWord.TextColor3=P.t3
    sInfo.Text="  --"; sFire.Text=""
    BuildDB()
end)

------------------------------------------------------------------------
-- FLY / MOVEMENT LOOP
------------------------------------------------------------------------
local Cam=workspace.CurrentCamera; local flyG,flyV=nil,nil
Run.Stepped:Connect(function()
    local char=LP.Character; if not char then return end
    local hum=char:FindFirstChildOfClass("Humanoid"); local hrp=char:FindFirstChild("HumanoidRootPart")
    if hum and Cfg.Speed>16 then hum.WalkSpeed=Cfg.Speed end
    if Cfg.Noclip then for _,p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    if Cfg.Fly and hrp then
        if not flyG then flyG=Instance.new("BodyGyro");flyG.Name="BvFlyGyro";flyG.P=9e4;flyG.MaxTorque=Vector3.new(9e9,9e9,9e9);flyG.Parent=hrp end
        if not flyV then flyV=Instance.new("BodyVelocity");flyV.Name="BvFlyVel";flyV.Velocity=Vector3.zero;flyV.MaxForce=Vector3.new(9e9,9e9,9e9);flyV.Parent=hrp end
        if hum.Sit then hum.Sit=false end
        local d=Vector3.zero
        pcall(function()
            if UIS:IsKeyDown(Enum.KeyCode.W) then d+=Cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then d-=Cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then d-=Cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then d+=Cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) then d+=Vector3.yAxis end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d-=Vector3.yAxis end
        end)
        if d.Magnitude>0 then d=d.Unit end
        flyV.Velocity=d*Cfg.FlySpd; flyG.CFrame=Cam.CFrame
    else
        if flyG then flyG:Destroy();flyG=nil end
        if flyV then flyV:Destroy();flyV=nil end
    end
end)

------------------------------------------------------------------------
-- INIT
------------------------------------------------------------------------
BuildDB()
kBtn.MouseButton1Click:Connect(function()
    if kInput.Text == KeyCode then
        kBtn.Text = "SUCCESS"
        kBtn.BackgroundColor3 = P.grn
        task.wait(0.5)
        keyWrap:Destroy()
        hubWrap.Visible = true
    else
        local old = kInput.Text
        kInput.Text = "WRONG KEY!"
        kBtn.BackgroundColor3 = P.red
        task.wait(1)
        kInput.Text = old
        kBtn.BackgroundColor3 = P.lim
    end
end)

task.spawn(function()
    local t=Instance.new("Frame",Root)
    t.Size=UDim2.fromOffset(230,44); t.Position=UDim2.new(0.5,-115,1,20)
    t.BackgroundColor3=P.bg1; t.BackgroundTransparency=0.1; t.BorderSizePixel=0
    corner(t,10); stroke(t,P.lim,1)
    local tl=mLabel(t,"  Beverly Hub v11.0 -- Ready!",Enum.Font.GothamBold,12,P.t1)
    tl.Size=UDim2.new(1,0,0,24); tl.Position=UDim2.new(0,0,0,2)
    local ts=mLabel(t,"  Secret word interception aktif",Enum.Font.Gotham,10,P.t3)
    ts.Size=UDim2.new(1,0,0,16); ts.Position=UDim2.new(0,0,0,24)
    tw(t,0.35,{Position=UDim2.new(0.5,-115,1,-54)}):Play()
    task.wait(3); tw(t,0.3,{Position=UDim2.new(0.5,-115,1,20)}):Play()
    task.wait(0.35); t:Destroy()
end)
