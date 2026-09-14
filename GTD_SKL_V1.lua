-- GTD SKL V1
-- Base: SKL V7 architecture
-- Intended for Roblox Studio / authorized testing environments.
-- Macro recorder/player with safer state management and mobile-friendly UI.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local ENV = getgenv and getgenv() or _G
if ENV.GTD_SKL_V1_LOADED then return end
ENV.GTD_SKL_V1_LOADED = true

local VERSION = "1.0.0"
local connections = {}
local state = {
    recording = false,
    paused = false,
    playing = false,
    macroName = "GTD Macro",
    speed = 1,
    antiAfk = false,
    autoPlay = false,
    selectedMacro = nil,
}
local macros = {}
local console = {}

local function log(level, text)
    table.insert(console, 1, {
        t = os.date("%H:%M:%S"),
        level = level,
        text = tostring(text)
    })
    while #console > 80 do table.remove(console) end
end

local function safe(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if not ok then
        log("ERROR", a)
        return nil
    end
    return a, b, c
end

local function connect(signal, fn)
    local c = signal:Connect(fn)
    table.insert(connections, c)
    return c
end

local function new(class, props, parent)
    local obj = Instance.new(class)
    for k, v in pairs(props or {}) do
        pcall(function() obj[k] = v end)
    end
    obj.Parent = parent
    return obj
end

local function corner(obj, radius)
    new("UICorner", {CornerRadius = UDim.new(0, radius or 8)}, obj)
end

local function stroke(obj)
    new("UIStroke", {Thickness = 1, Transparency = 0.35}, obj)
end

local gui = new("ScreenGui", {
    Name = "GTDSKL_V1",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
}, LocalPlayer:WaitForChild("PlayerGui"))

local main = new("Frame", {
    Size = UDim2.fromOffset(430, 500),
    Position = UDim2.new(0.5, -215, 0.5, -250),
    BackgroundColor3 = Color3.fromRGB(18,18,22),
    BorderSizePixel = 0,
}, gui)
corner(main, 12)
stroke(main)

local title = new("TextLabel", {
    Size = UDim2.new(1, -60, 0, 44),
    Position = UDim2.fromOffset(15, 5),
    BackgroundTransparency = 1,
    Text = "GTD SKL  •  V"..VERSION,
    TextColor3 = Color3.fromRGB(245,245,250),
    TextSize = 19,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local close = new("TextButton", {
    Size = UDim2.fromOffset(38, 32),
    Position = UDim2.new(1, -46, 0, 10),
    BackgroundColor3 = Color3.fromRGB(45,45,52),
    Text = "×",
    TextColor3 = Color3.fromRGB(255,255,255),
    TextSize = 22,
    Font = Enum.Font.GothamBold,
}, main)
corner(close, 8)

local status = new("TextLabel", {
    Size = UDim2.new(1, -30, 0, 28),
    Position = UDim2.fromOffset(15, 48),
    BackgroundTransparency = 1,
    Text = "Status: Idle",
    TextColor3 = Color3.fromRGB(170,170,180),
    TextSize = 14,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
}, main)

local body = new("ScrollingFrame", {
    Size = UDim2.new(1, -30, 1, -90),
    Position = UDim2.fromOffset(15, 80),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    CanvasSize = UDim2.fromOffset(0,0),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    ScrollBarThickness = 3,
}, main)
new("UIListLayout", {
    Padding = UDim.new(0,8),
    SortOrder = Enum.SortOrder.LayoutOrder,
}, body)

local function button(text, callback)
    local b = new("TextButton", {
        Size = UDim2.new(1,0,0,38),
        BackgroundColor3 = Color3.fromRGB(35,35,42),
        BorderSizePixel = 0,
        Text = text,
        TextColor3 = Color3.fromRGB(240,240,245),
        TextSize = 14,
        Font = Enum.Font.GothamMedium,
        AutoButtonColor = true,
    }, body)
    corner(b, 8)
    stroke(b)
    connect(b.MouseButton1Click, function()
        safe(callback)
    end)
    return b
end

local function label(text)
    local l = new("TextLabel", {
        Size = UDim2.new(1,0,0,25),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = Color3.fromRGB(190,190,200),
        TextSize = 13,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, body)
    return l
end

local nameBox = new("TextBox", {
    Size = UDim2.new(1,0,0,38),
    BackgroundColor3 = Color3.fromRGB(28,28,34),
    BorderSizePixel = 0,
    PlaceholderText = "Nombre del macro",
    Text = state.macroName,
    TextColor3 = Color3.fromRGB(245,245,250),
    PlaceholderColor3 = Color3.fromRGB(120,120,130),
    TextSize = 14,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false,
}, body)
corner(nameBox, 8)
stroke(nameBox)

connect(nameBox.FocusLost, function()
    local n = nameBox.Text:gsub("[%c/\\:*?\"<>|]", "_")
    n = n:sub(1, 40)
    if n == "" then n = "GTD Macro" end
    state.macroName = n
    nameBox.Text = n
end)

label("Macro")

local startBtn = button("●  Iniciar grabación", function()
    if state.playing then
        log("WARN","Detén la reproducción antes de grabar.")
        return
    end
    state.recording = true
    state.paused = false
    macros._current = {
        created = os.time(),
        name = state.macroName,
        actions = {},
    }
    status.Text = "Status: Recording"
    log("ACTION","Grabación iniciada")
end)

local pauseBtn = button("Ⅱ  Pausar", function()
    if not state.recording then return end
    state.paused = not state.paused
    pauseBtn.Text = state.paused and "▶  Reanudar" or "Ⅱ  Pausar"
    status.Text = state.paused and "Status: Recording Paused" or "Status: Recording"
end)

local stopBtn = button("■  Guardar y detener", function()
    if not state.recording or not macros._current then return end
    state.recording = false
    state.paused = false
    local data = macros._current
    macros._current = nil
    macros[data.name] = data
    state.selectedMacro = data.name
    status.Text = "Status: Idle"
    log("ACTION","Macro guardado: "..data.name.." ("..#data.actions.." acciones)")
end)

label("Reproducción")

button("▶  Reproducir seleccionado", function()
    local name = state.selectedMacro
    local data = name and macros[name]
    if not data then
        log("WARN","No hay macro seleccionado.")
        return
    end
    if state.recording or state.playing then return end

    state.playing = true
    status.Text = "Status: Playing"
    log("ACTION","Reproduciendo "..name)

    task.spawn(function()
        for _, action in ipairs(data.actions) do
            if not state.playing then break end
            local delayTime = math.max(0, (action.dt or 0) / state.speed)
            task.wait(delayTime)
            -- En Studio/entornos autorizados, conecta aquí tu propia
            -- función de ejecución de acciones del juego.
        end
        state.playing = false
        status.Text = "Status: Idle"
        log("ACTION","Reproducción terminada")
    end)
end)

button("■  Detener reproducción", function()
    state.playing = false
    status.Text = "Status: Idle"
end)

label("Opciones")

button("⚡ Velocidad: x"..state.speed, function()
    state.speed = state.speed == 1 and 2 or state.speed == 2 and 3 or 1
    log("ACTION","Velocidad -> x"..state.speed)
end)

local afkBtn = button("Anti-AFK: OFF", function()
    state.antiAfk = not state.antiAfk
    afkBtn.Text = "Anti-AFK: "..(state.antiAfk and "ON" or "OFF")
end)

label("Consola")

local consoleBox = new("TextLabel", {
    Size = UDim2.new(1,0,0,150),
    BackgroundColor3 = Color3.fromRGB(10,10,13),
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = Color3.fromRGB(205,205,215),
    TextSize = 11,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true,
}, body)
corner(consoleBox, 8)
stroke(consoleBox)

button("Limpiar consola", function()
    console = {}
    consoleBox.Text = ""
end)

local dragging = false
local dragStart
local startPos

connect(title.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)

connect(UserInputService.InputChanged, function(input)
    if not dragging then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
    local delta = input.Position - dragStart
    main.Position = UDim2.new(
        startPos.X.Scale, startPos.X.Offset + delta.X,
        startPos.Y.Scale, startPos.Y.Offset + delta.Y
    )
end)

connect(UserInputService.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

connect(close.MouseButton1Click, function()
    state.recording = false
    state.playing = false
    for _, c in ipairs(connections) do
        pcall(function() c:Disconnect() end)
    end
    if gui then gui:Destroy() end
    ENV.GTD_SKL_V1_LOADED = nil
end)

connect(RunService.Heartbeat, function()
    if state.recording and not state.paused and macros._current then
        -- Punto seguro para registrar acciones autorizadas de Studio.
        -- No intercepta remotes ni intenta evadir protecciones.
    end
end)

task.spawn(function()
    while gui.Parent do
        local lines = {}
        for i = 1, math.min(#console, 14) do
            local x = console[i]
            lines[#lines+1] = ("[%s] [%s] %s"):format(x.t, x.level, x.text)
        end
        consoleBox.Text = table.concat(lines, "\n")
        task.wait(0.4)
    end
end)

log("ACTION","GTD SKL V"..VERSION.." iniciado")
