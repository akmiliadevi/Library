--- mock_roblox.lua
--- Minimal Roblox API mocks so Lib.lua can be loaded under standard Lua 5.3.

-- Lua 5.3 compat: provide table.clear if missing
if not table.clear then
    function table.clear(t)
        for k in pairs(t) do t[k] = nil end
    end
end

-- math.clamp (Roblox extension)
if not math.clamp then
    function math.clamp(x, lo, hi)
        if x < lo then return lo end
        if x > hi then return hi end
        return x
    end
end

---------------------------------------------------------------------------
-- Color3, UDim2, Vector2, Enum
---------------------------------------------------------------------------
Color3 = Color3 or {}
function Color3.fromRGB(r, g, b)
    return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255, _type = "Color3" }
end

UDim2 = UDim2 or {}
function UDim2.new(xs, xo, ys, yo)
    return { XScale = xs, XOffset = xo, YScale = ys, YOffset = yo, _type = "UDim2" }
end

Vector2 = Vector2 or {}
setmetatable(Vector2, {
    __call = function(_, x, y) return { X = x, Y = y, _type = "Vector2" } end,
})
function Vector2.new(x, y)
    return { X = x, Y = y, _type = "Vector2" }
end

---------------------------------------------------------------------------
-- Enum stubs
---------------------------------------------------------------------------
Enum = Enum or {}
Enum.Font = Enum.Font or { Gotham = "Gotham" }

---------------------------------------------------------------------------
-- Instance mock
---------------------------------------------------------------------------
Instance = Instance or {}
function Instance.new(className)
    local inst = {
        ClassName = className,
        _children = {},
        _props = {},
    }
    setmetatable(inst, {
        __index = function(self, k)
            return rawget(self, k) or rawget(self._props, k)
        end,
        __newindex = function(self, k, v)
            rawset(self._props, k, v)
        end,
    })
    inst.FindFirstChildWhichIsA = function(_, className2)
        for _, c in ipairs(inst._children) do
            if c.ClassName == className2 then return c end
        end
        return nil
    end
    inst.GetPropertyChangedSignal = function()
        return { Connect = function() return { Disconnect = function() end } end }
    end
    return inst
end

---------------------------------------------------------------------------
-- Mock signal helper
---------------------------------------------------------------------------
local function mockSignal()
    return {
        Connect = function(_, fn)
            return { Disconnect = function() end }
        end,
        Wait = function() end,
    }
end

---------------------------------------------------------------------------
-- Fake services
---------------------------------------------------------------------------
local json = {} -- minimal JSON encode/decode for testing

-- Minimal JSON encoder (handles strings, numbers, booleans, tables)
function json.encode(_, obj)
    if type(obj) == "nil" then return "null" end
    if type(obj) == "boolean" then return tostring(obj) end
    if type(obj) == "number" then return tostring(obj) end
    if type(obj) == "string" then
        return '"' .. obj:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n') .. '"'
    end
    if type(obj) == "table" then
        -- check if array
        local isArray = (#obj > 0)
        if isArray then
            local parts = {}
            for _, v in ipairs(obj) do
                parts[#parts + 1] = json.encode(nil, v)
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(obj) do
                if type(k) == "string" then
                    parts[#parts + 1] = json.encode(nil, k) .. ":" .. json.encode(nil, v)
                end
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    end
    return "null"
end

-- Minimal JSON decoder
local function skip_whitespace(s, i)
    while i <= #s and s:sub(i, i):match("%s") do i = i + 1 end
    return i
end

local parse_value -- forward declaration

local function parse_string(s, i)
    assert(s:sub(i, i) == '"')
    i = i + 1
    local result = {}
    while i <= #s do
        local c = s:sub(i, i)
        if c == '\\' then
            i = i + 1
            local esc = s:sub(i, i)
            if esc == 'n' then result[#result + 1] = '\n'
            elseif esc == 't' then result[#result + 1] = '\t'
            elseif esc == '"' then result[#result + 1] = '"'
            elseif esc == '\\' then result[#result + 1] = '\\'
            else result[#result + 1] = esc end
        elseif c == '"' then
            return table.concat(result), i + 1
        else
            result[#result + 1] = c
        end
        i = i + 1
    end
    error("Unterminated string")
end

local function parse_number(s, i)
    local j = i
    if s:sub(j, j) == '-' then j = j + 1 end
    while j <= #s and s:sub(j, j):match("[%d%.eE%+%-]") do j = j + 1 end
    return tonumber(s:sub(i, j - 1)), j
end

local function parse_object(s, i)
    assert(s:sub(i, i) == '{')
    i = skip_whitespace(s, i + 1)
    local obj = {}
    if s:sub(i, i) == '}' then return obj, i + 1 end
    while true do
        local key
        key, i = parse_string(s, i)
        i = skip_whitespace(s, i)
        assert(s:sub(i, i) == ':')
        i = skip_whitespace(s, i + 1)
        local val
        val, i = parse_value(s, i)
        obj[key] = val
        i = skip_whitespace(s, i)
        if s:sub(i, i) == '}' then return obj, i + 1 end
        assert(s:sub(i, i) == ',')
        i = skip_whitespace(s, i + 1)
    end
end

local function parse_array(s, i)
    assert(s:sub(i, i) == '[')
    i = skip_whitespace(s, i + 1)
    local arr = {}
    if s:sub(i, i) == ']' then return arr, i + 1 end
    while true do
        local val
        val, i = parse_value(s, i)
        arr[#arr + 1] = val
        i = skip_whitespace(s, i)
        if s:sub(i, i) == ']' then return arr, i + 1 end
        assert(s:sub(i, i) == ',')
        i = skip_whitespace(s, i + 1)
    end
end

parse_value = function(s, i)
    i = skip_whitespace(s, i)
    local c = s:sub(i, i)
    if c == '"' then return parse_string(s, i)
    elseif c == '{' then return parse_object(s, i)
    elseif c == '[' then return parse_array(s, i)
    elseif c == 't' then assert(s:sub(i, i + 3) == "true"); return true, i + 4
    elseif c == 'f' then assert(s:sub(i, i + 4) == "false"); return false, i + 5
    elseif c == 'n' then assert(s:sub(i, i + 3) == "null"); return nil, i + 4
    else return parse_number(s, i)
    end
end

function json.decode(_, s)
    if type(s) ~= "string" or s == "" then
        error("Cannot decode empty or non-string input")
    end
    local ok, val, pos = pcall(parse_value, s, 1)
    if not ok then error("JSON decode error: " .. tostring(val)) end
    if val == nil and not s:match("^%s*null%s*$") then
        error("JSON decode error: unexpected input")
    end
    return val
end

local HttpService = {
    JSONEncode = function(self, obj) return json.encode(self, obj) end,
    JSONDecode = function(self, str) return json.decode(self, str) end,
}

local RunService = { Heartbeat = mockSignal() }
local TweenService = {
    Create = function(_, inst, info, props)
        return { Play = function() end, Cancel = function() end }
    end,
}
local UserInputService = { InputBegan = mockSignal(), InputEnded = mockSignal() }
local Players = { LocalPlayer = { Name = "TestPlayer", UserId = 1 } }
local CoreGui = Instance.new("ScreenGui")

---------------------------------------------------------------------------
-- game:GetService
---------------------------------------------------------------------------
local services = {
    Players = Players,
    CoreGui = CoreGui,
    TweenService = TweenService,
    UserInputService = UserInputService,
    RunService = RunService,
    HttpService = HttpService,
}

game = game or {}
function game:GetService(name)
    return services[name] or {}
end

---------------------------------------------------------------------------
-- task stubs
---------------------------------------------------------------------------
task = task or {}
task.delay = task.delay or function(t, fn) return fn end
task.cancel = task.cancel or function() end
task.defer = task.defer or function(fn) return fn end
task.spawn = task.spawn or function(fn, ...) fn(...) end
task.wait = task.wait or function() end

---------------------------------------------------------------------------
-- Filesystem stubs (in-memory)
---------------------------------------------------------------------------
local _virtualFS = {}

function isfolder(path)
    return _virtualFS[path] == "__folder__"
end
function makefolder(path)
    _virtualFS[path] = "__folder__"
end
function isfile(path)
    return _virtualFS[path] ~= nil and _virtualFS[path] ~= "__folder__"
end
function readfile(path)
    return _virtualFS[path]
end
function writefile(path, content)
    _virtualFS[path] = content
end
function delfile(path)
    _virtualFS[path] = nil
end

-- Helper to reset virtual filesystem between tests
function _resetVirtualFS()
    _virtualFS = {}
end

---------------------------------------------------------------------------
-- warn stub
---------------------------------------------------------------------------
_G._warnLog = {}
warn = function(...)
    local args = { ... }
    local msg = table.concat(
        (function()
            local t = {}
            for _, v in ipairs(args) do t[#t + 1] = tostring(v) end
            return t
        end)(),
        " "
    )
    table.insert(_G._warnLog, msg)
end

function _clearWarnLog()
    _G._warnLog = {}
end

print("mock_roblox loaded")
