-- [[ Lumina HUB | Loader ]]
-- Detects which game you are in and loads the matching Lumina HUB script.
-- Usage:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/xZenbo/Lumina-HUB/main/Loader.lua"))()

local REPO = "https://raw.githubusercontent.com/xZenbo/Lumina-HUB/main/"

-- Supported games, keyed by GameId (the universe id), so every place inside a
-- game (lobby, worlds, sub-places) loads the same script.
local Games = {
    [10629695169] = { Name = "Tap Simulator REBORN", File = "Lumina HUB | Tap Sim Reborn" },
    [10708913337] = { Name = "Anime Dice",           File = "Lumina HUB | Anime Dice" },
}

local StarterGui = game:GetService("StarterGui")

local function notify(text)
    pcall(StarterGui.SetCore, StarterGui, "SendNotification", {
        Title = "Lumina HUB",
        Text = text,
        Duration = 6,
    })
end

-- File names contain spaces and "|", so encode them for the URL
local function urlEncode(path)
    return (path:gsub("[^%w%-%._~/]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local entry = Games[game.GameId]
if not entry then
    notify("This game isn't supported yet.")
    warn("[Lumina HUB] Unsupported game. GameId:", game.GameId, "PlaceId:", game.PlaceId)
    return
end

notify("Loading " .. entry.Name .. "...")

local ok, source = pcall(game.HttpGet, game, REPO .. urlEncode(entry.File))
if not ok or type(source) ~= "string" or #source == 0 then
    notify("Couldn't download the " .. entry.Name .. " script.")
    warn("[Lumina HUB] Download failed:", source)
    return
end

local chunk, compileError = loadstring(source)
if not chunk then
    notify("The " .. entry.Name .. " script failed to compile.")
    warn("[Lumina HUB] Compile error:", compileError)
    return
end

local ran, runError = pcall(chunk)
if not ran then
    notify("The " .. entry.Name .. " script hit an error.")
    warn("[Lumina HUB] Runtime error:", runError)
end
