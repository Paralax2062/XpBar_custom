-- Imports
local core_mainmenu = require("core_mainmenu")
local cfg = require("XpBar.configuration")

local lib_helpers = require("solylib.helpers")
local lib_unitxt = require("solylib.unitxt")
local lib_items = require("solylib.items.items")
local lib_items_list = require("solylib.items.items_list")
local lib_items_cfg = require("solylib.items.items_configuration")
-- TODO move to options
local optionsLoaded, options = pcall(require, "XpBar.options")

local trip = 0
local textVal
local displayVal

local optionsFileName = "addons/XpBar/options.lua"

-- Constants
local _PlayerArray = 0x00A94254
local _PlayerMyIndex = 0x00A9C4F4
local _PLTPointer = 0x00A94878

if optionsLoaded then
    -- If options loaded, make sure we have all those we need
    options.configurationEnableWindow = options.configurationEnableWindow == nil and true or options.configurationEnableWindow
    options.enable = options.enable == nil and true or options.enable
    options.xpEnableWindow = options.xpEnableWindow == nil and true or options.xpEnableWindow
    options.xpNoTitleBar = options.xpNoTitleBar or ""
    options.xpNoResize = options.xpNoResize or ""
    options.xpNoMove = options.xpNoMove or ""
    options.xpEnableInfoText = options.xpEnableInfoText == nil and true or options.xpEnableInfoText
    options.xpTransparent = options.xpTransparent == nil and true or options.xpTransparent
    options.xpBarColor = options.xpBarColor or 0xFFE6B300
    options.xpBarX = options.xpBarX or 50
    options.xpBarY = options.xpBarY or 50
    options.xpBarWidth = options.xpBarWidth or -1
    options.xpBarHeight = options.xpBarHeight or 0
    options.xpBarNoOverlay = options.xpBarNoOverlay == nil and true or options.xpBarNoOverlay
else
    options = 
    {
        configurationEnableWindow = true,
        enable = true,
        xpEnableWindow = true,
        xpNoTitleBar = "",
        xpNoResize = "",
        xpNoMove = "",
        xpEnableInfoText = true,
        xpTransparent = false,
        xpBarColor = 0xFFE6B300,
        xpBarW = 50,
        xpBarY = 50,
        xpBarWidth = -1,
        xpBarHeight = 0,
        xpBarNoOverlay = false,
    }
end

local function SaveOptions(options)
    local file = io.open(optionsFileName, "w")
    if file ~= nil then
        io.output(file)

        io.write("return {\n")
        io.write(string.format("    configurationEnableWindow = %s,\n", tostring(options.configurationEnableWindow)))
        io.write(string.format("    enable = %s,\n", tostring(options.enable)))
        io.write("\n")
        io.write(string.format("    xpEnableWindow = %s,\n", tostring(options.xpEnableWindow)))
        io.write(string.format("    xpNoTitleBar = \"%s\",\n", options.xpNoTitleBar))
        io.write(string.format("    xpNoResize = \"%s\",\n", options.xpNoResize))
        io.write(string.format("    xpNoMove = \"%s\",\n", options.xpNoMove))
        io.write(string.format("    xpEnableInfoText = %s,\n", tostring(options.xpEnableInfoText)))
        io.write(string.format("    xpTransparent = %s,\n", tostring(options.xpTransparent)))
        io.write(string.format("    xpBarColor = 0x%08X,\n", options.xpBarColor))
        io.write(string.format("    xpBarX = %f,\n", options.xpBarX))
        io.write(string.format("    xpBarY = %f,\n", options.xpBarY))
        io.write(string.format("    xpBarWidth = %f,\n", options.xpBarWidth))
        io.write(string.format("    xpBarHeight = %f,\n", options.xpBarHeight))
        io.write(string.format("    xpBarNoOverlay = %s,\n", tostring(options.xpBarNoOverlay)))
        io.write("}\n")

        io.close(file)
    end
end

local function GetColorAsFloats(color)
    color = color or 0xFFFFFFFF

    local a = bit.band(bit.rshift(color, 24), 0xFF) / 255;
    local r = bit.band(bit.rshift(color, 16), 0xFF) / 255;
    local g = bit.band(bit.rshift(color, 8), 0xFF) / 255;
    local b = bit.band(color, 0xFF) / 255;

    return { r = r, g = g, b = b, a = a }
end

local imguiProgressBar = function(progress, color)
    color = color or 0xE6B300FF

    if progress == nil then
        imgui.Text("imguiProgressBar() Invalid progress")
        return
    end

    local overlay = nil
    if options.xpBarNoOverlay then
        overlay = ""
    end

    c = GetColorAsFloats(color)
    imgui.PushStyleColor("PlotHistogram", c.r, c.g, c.b, c.a)
    imgui.ProgressBar(progress, options.xpBarWidth, options.xpBarHeight, overlay)
    imgui.PopStyleColor()
end

local DrawStuff = function()
    local myIndex = pso.read_u32(_PlayerMyIndex)
    local myAddress = pso.read_u32(_PlayerArray + 4 * myIndex)
    local pltData = pso.read_u32(_PLTPointer)

    -- Do the thing only if the pointer is not null
    if myAddress == 0 then
        if options.xpEnableInfoText then
            imgui.Text("Player data not found")
        end
    elseif pltData == 0 then
        if options.xpEnableInfoText then
            imgui.Text("PLT data not found")
        end
    else
        local myClass = pso.read_u8(myAddress + 0x961)
        local myLevel = pso.read_u32(myAddress + 0xE44)
        local myExp = pso.read_u32(myAddress + 0xE48)

        local pltLevels = pso.read_u32(pltData)
        local pltClass = pso.read_u32(pltLevels + 4 * myClass)

        local thisMaxLevelExp = pso.read_u32(pltClass + 0x0C * myLevel + 0x08)
        local nextMaxLevelexp

        if myLevel < 199 then
            nextMaxLevelexp = pso.read_u32(pltClass + 0x0C * (myLevel + 1) + 0x08)
        else
            nextMaxLevelexp = thisMaxLevelExp
        end

        local thisLevelExp = myExp - thisMaxLevelExp
        local nextLevelexp = nextMaxLevelexp - thisMaxLevelExp
        local levelProgress = 1
        if nextLevelexp ~= 0 then
            levelProgress = thisLevelExp / nextLevelexp
        end
		local remainingExp = nextLevelexp - thisLevelExp
		local theLevel = myLevel + 1
        lib_helpers.imguiProgressBar(false, levelProgress, options.xpBarWidth, options.xpBarHeight, "To Next Lv: "..comma_value(remainingExp),options.xpBarColor)
        
		--show trip xp
		if trip > myExp or trip == 0 then
			trip = myExp
		end
		
		--display trip
		lib_helpers.TextC(false, 0xFFAAAAAA, "    Trip: ")
		lib_helpers.TextC(false, 0xFFFFFFFF, "%-12s", comma_value(myExp - trip) .. " xp")
		imgui.SameLine(0, 12)
		
		if imgui.Button("Reset") then
			trip = myExp
		end
		
		if options.xpEnableInfoText then
			local percentage = string.format("%i",math.floor(levelProgress*100))
			local percentageString = string.format("(%s%s)", percentage, "%%")
			local percentageString = string.format("%-6s",percentageString)
			local levelString = string.format("%-6s", "Lv" .. theLevel  .. " ")
			local xpString = string.format("%-22s", comma_value(thisLevelExp) .. "/" .. comma_value(nextLevelexp) .. " ")

            lib_helpers.TextC(true, lib_items_cfg.white, "%s", levelString)
			lib_helpers.TextC(false, 0xFFAAAAAA, "%s", xpString)
			lib_helpers.TextC(false, lib_items_cfg.white, "%s", percentageString)
        end
		
		--show trip xp save and desc field
		lib_helpers.TextC(false, 0xFFAAAAAA, "    Desc:")
	
		imgui.SameLine(0, 7)
		
		if textVal == nil then
			displayVal = ""
		else
			displayVal = textVal
		end
		
		imgui.PushItemWidth(88)
		success, textVal = imgui.InputText("",string.format("%s",displayVal), 255)
		imgui.PopItemWidth()
		
		if success then
			displayVal = textVal
		end
		
		imgui.SameLine(0, 7)
		
		if imgui.Button("Save") then
			local file = io.open("addons/XpBar/trip.txt", "a")
			io.output(file)
			io.write(os.date('\n%Y-%m-%d %H:%M:%S', ts))
			io.write("  |  ")
			io.write(string.format("%-16s", comma_value(tostring(myExp - trip))))
			io.write(string.format("\"%s\"", displayVal))
			io.close(file)
		end
    end
end

function comma_value(amount)
  local formatted = amount
  while true do  
    formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
    if (k==0) then
      break
    end
  end
  return formatted
end

-- Drawing
local function present()
    local changedOptions = false
-- If the addon has never been used, open the config window
    -- and disable the config window setting
    if options.configurationEnableWindow then
        ConfigurationWindow.open = true
        options.configurationEnableWindow = false
    end

    ConfigurationWindow.Update()
    if ConfigurationWindow.changed then
        changedOptions = true
        ConfigurationWindow.changed = false
        SaveOptions(options)
    end

    -- Global enable here to let the configuration window work
    if options.enable == false then
        return
    end

    if options.xpTransparent then
        imgui.PushStyleColor("WindowBg", 0, 0, 0, 0)
    end

    if options.xpEnableWindow then
        if changedOptions == true then
            changedOptions = false
            imgui.SetNextWindowPos(options.xpBarX, options.xpBarY, "Always");
        end
        imgui.Begin("Experience Bar", nil, { options.xpNoTitleBar, options.xpNoResize, options.xpNoMove, "AlwaysAutoResize" })
        DrawStuff();
        imgui.End()
    end

    if options.xpTransparent then
        imgui.PopStyleColor(1)
    end
end

-- Init
local function init()
    ConfigurationWindow = cfg.ConfigurationWindow(options)

    local function mainMenuButtonHandler()
        ConfigurationWindow.open = not ConfigurationWindow.open
    end

    core_mainmenu.add_button("XP Bar", mainMenuButtonHandler)


    return
    {
        name = "Experience Bar",
        version = "1.4",
        author = "tornupgaming",
        description = "Displays your current character experience in a handy visual bar.",
        present = present,
    }
end

-- Exports for other modules
return
{
    __addon =
    {
        init = init
    }
}
