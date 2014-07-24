--[[
	CostumeNames by porten. Comments/suggestions etc are welcome, just look me up on Curse.
]]

require "Window"

local CostumeNames = {} 
local Character, Costumes
local CN

function CostumeNames:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 
    return o
end

function CostumeNames:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		"Character", "Costumes"
	}
	
	-- Init structure for saved names
	self.tSettings = self.tSettings or {}
	self.tSettings.tCostumeNames = self.tSettings.tCostumeNames or {}
	
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)	
	CN = self
end

function CostumeNames:OnDependencyError()
	-- Either Character or Custumes (pref. both) required for this addon to function
	if Apollo.GetAddon("Character") ~= nil or Apollo.GetAddon("Costumes") ~= nil then
		return true
	end
end

function CostumeNames:OnLoad()
    -- Load form for later use
	CN.xmlDoc = XmlDoc.CreateFromFile("CostumeNames.xml")
	CN.xmlDoc:RegisterCallback("OnDocLoaded", CN)
end

function CostumeNames:OnDocLoaded()
	-- Prepare hooks & overlays for Character addon
	Character = Apollo.GetAddon("Character")
	if Character ~= nil then
		CN.Character_UpdateCostumeSlotIcons = Character.UpdateCostumeSlotIcons
		Character.UpdateCostumeSlotIcons = CN.Character_InterceptUpdateCostumeSlotIcons
	
		-- Hook showing of Costume selection window
		CN.Character_CostumeSelectionWindowCheck = Character.CostumeSelectionWindowCheck
		Character.CostumeSelectionWindowCheck = CN.Character_InterceptCostumeSelectionWindowCheck

		-- Hook hiding of Costume selection window
		CN.Character_CostumeSelectionWindowUnCheck = Character.CostumeSelectionWindowUnCheck
		Character.CostumeSelectionWindowUnCheck = CN.Character_InterceptCostumeSelectionWindowUnCheck		
	
		-- Register for event fired when a costume selection is made, or window is closed
		Apollo.RegisterEventHandler("CharacterPanel_CostumeUpdated", "Character_InterceptCostumeSelectionWindowUnCheck", CN)
		Apollo.RegisterEventHandler("CharacterWindowHasBeenClosed", "Character_InterceptCostumeSelectionWindowUnCheck", CN)		
	else
		Print("Warning: Addon 'CostumeNames' is designed for use with the stock Character addon.")
	end
	
	-- Prepare hooks & overlays for Costumes addon
	Costumes = Apollo.GetAddon("Costumes")
	if Costumes ~= nil then
		-- Hook showing Costumes window
		CN.Costumes_ShowCostumeWindow = Costumes.ShowCostumeWindow
		Costumes.ShowCostumeWindow = CN.Costumes_InterceptShowCostumeWindow
	else
		Print("Warning: Addon 'CostumeNames' is designed for use with the stock Costumes addon.")
	end
end


	--[[ Hooks into Character addon ]]
	

-- Only hooked to re-hide costume buttons. They keep getting shown by various events triggering ShowCharacterWindow.
function CostumeNames:Character_InterceptUpdateCostumeSlotIcons()
	Print("UpdateCostumeSlotIcons!")
	-- Pass on to character
	CN.Character_UpdateCostumeSlotIcons(Character)
	
	-- And re-toggle editability of fields (just check if any of my editfields are visible)
	if CN.wndCharacterOverlay ~= nil then
		CN:ToggleEditability(CN.wndCharacterOverlay:FindChild("CostumeNameEdit1"):IsShown())
	end
end

-- Show the Character overlay window
function CostumeNames:Character_InterceptCostumeSelectionWindowCheck()
	-- Show costume selection window
	CN.Character_CostumeSelectionWindowCheck(Character)
	
	-- Load Character overlay form first time the costumes button is pressed
	local wndCostumeBtnHolder = Character.wndCharacter:FindChild("CostumeBtnHolder")
	if CN.wndCharacterOverlay == nil then				
		CN.wndCharacterOverlay = Apollo.LoadForm(CN.xmlDoc, "CharacterOverlayForm", wndCostumeBtnHolder:GetParent(), CostumeNames)	
		if CN.wndCharacterOverlay == nil then		
			Apollo.AddAddonErrorText(CostumeNames, "CharacterOverlayForm not loaded")
			return
		end
	end
			
	-- Populate overlay form with initial button texts
	CostumeNames:PopulateButtonsFromSettings(wndCostumeBtnHolder)
	
	-- Show overlay window itself
	CN.wndCharacterOverlay:Show(true, true)	
end

-- Hide the Character overlay window
function CostumeNames:Character_InterceptCostumeSelectionWindowUnCheck(wndHandler, wndControl)
	-- Pass uncheck on to Character
	CN.Character_CostumeSelectionWindowUnCheck(Character, wndHandler, wndControl)
	
	-- And hide my own overlay
	CN.wndCharacterOverlay:Show(false, true)
	CostumeNames:ToggleEditability(false)	
end


	--[[ Character-addon overlay button functions ]]

function CostumeNames:OnEditNameButtonCheck(wndHandler, wndControl, eMouseButton)
	--local CostumeNames = Apollo.GetAddon("CostumeNames") -- Injected function, no ref for CostumeNames
	CN:ToggleEditability(true)
	
	-- Populate the list of selection buttons with correct name
	CN:PopulateButtonsFromSettings(Character.wndCharacter:FindChild("CostumeBtnHolder"))
	
	-- Also populate the corresponding Character overlay editboxes with same value
	for idx = 1, GameLib.GetCostumeCount() do
		local strSavedName = CostumeNames:GetName(idx)
		CN.wndCharacterOverlay:FindChild("CostumeNameEdit"..idx):SetText(strSavedName)		
	end
end

function CostumeNames:OnEditNameButtonUncheck(wndHandler, wndControl, eMouseButton)
	CN:ToggleEditability(false)
	CN:UpdateNamesFromCharacterEdit()
end

-- Initial population of button labels and editbox values from saved settings
function CostumeNames:PopulateButtonsFromSettings(wndCostumeBtnHolder)
	for idx = 1, GameLib.GetCostumeCount() do
		local strSavedName = CostumeNames:GetName(idx)
		wndCostumeBtnHolder:FindChild("CostumeBtn"..idx):SetText(strSavedName)		
	end
end

function CostumeNames:ToggleEditability(bEdit)
	local nCurrentCostume = GameLib.GetCostumeIndex()
	for idx = 1, GameLib.GetCostumeCount() do
		-- Update show/hide of buttons and editboxes
		Character.wndCharacter:FindChild("CostumeBtn"..idx):Show(not bEdit, true)
		
		local wndEdit = CN.wndCharacterOverlay:FindChild("CostumeNameEdit"..idx)
		wndEdit:SetTextColor(nCurrentCostume == idx and "ChannelSupport" or "UI_BtnTextGoldListNormal") -- highlight current costume by text color
		wndEdit:Show(bEdit, true)
	end
end

function CostumeNames:UpdateNamesFromCharacterEdit()
	local CostumeNames = Apollo.GetAddon("CostumeNames")
	
	for idx = 1, GameLib.GetCostumeCount() do
		local strNewName = CN.wndCharacterOverlay:FindChild("CostumeNameEdit"..idx):GetText()
		Character.wndCharacter:FindChild("CostumeBtn"..idx):SetText(strNewName)
		CN.tSettings.tCostumeNames[idx] = strNewName			
	end
end


	--[[ Hooks into Costumes addon ]]
	
function CostumeNames:Costumes_InterceptShowCostumeWindow()
	-- Allow window to be shown
	CN.Costumes_ShowCostumeWindow(Costumes)
	
	-- Update all button texts
	local costumeBtnHolder = Costumes.wndMain:FindChild("CostumeBtnHolder")
	CostumeNames:PopulateButtonsFromSettings(costumeBtnHolder)
	Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):SetText(CostumeNames:GetName(GameLib.GetCostumeIndex()))
	
	-- Load overlay form
	CN.wndCostumesOverlay = Apollo.LoadForm(CN.xmlDoc, "CostumesOverlayForm", costumeBtnHolder:GetParent(), CostumeNames)	
	
end


	--[[ Save/Restore savedata ]]
	
function CostumeNames:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 
	end
		
	return CN.tSettings
end

-- Restore addon config per character. Called by engine when loading UI.
function CostumeNames:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 
	end
	
	CN.tSettings = tSavedData
	CN.tSettings.tCostumeNames = CN.tSettings.tCostumeNames or {}
end

function CostumeNames:GetName(idx)
	return CN.tSettings.tCostumeNames[idx] or String_GetWeaselString(Apollo.GetString("Character_CostumeNum"), idx)	
end


local CostumeNamesInst = CostumeNames:new()
CostumeNamesInst:Init()

