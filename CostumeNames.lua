--[[
	CostumeNames by porten. Comments/suggestions etc are welcome, just look me up on Curse.
]]

require "Window"

local CostumeNames = {} 
local Character, Costumes

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
end

function CostumeNames:OnDependencyError()
	-- Either Character or Custumes (pref. both) required for this addon to function
	if Apollo.GetAddon("Character") ~= nil or Apollo.GetAddon("Costumes") ~= nil then
		return true
	end
end

function CostumeNames:OnLoad()
    -- Load form for later use
	self.xmlDoc = XmlDoc.CreateFromFile("CostumeNames.xml")
	
	-- Hook into relevant areas of supported addons
	Character = Apollo.GetAddon("Character")
	if Character ~= nil then
		-- Hook showing of Costume selection window
		self.Character_CostumeSelectionWindowCheck = Character.CostumeSelectionWindowCheck
		Character.CostumeSelectionWindowCheck = self.Character_InterceptCostumeSelectionWindowCheck

		-- Hook hiding of Costume selection window
		self.Character_CostumeSelectionWindowUnCheck = Character.CostumeSelectionWindowUnCheck
		Character.CostumeSelectionWindowUnCheck = self.Character_InterceptCostumeSelectionWindowUnCheck		
	
		-- Register for event fired when a costume selection is made
		Apollo.RegisterEventHandler("CharacterPanel_CostumeUpdated", "Character_InterceptCostumeSelectionWindowUnCheck", self)
	end
	
	Costumes = Apollo.GetAddon("Costumes")
	if Costumes ~= nil then
	
	end
end


	--[[ Hooks into Character addon ]]
	
function CostumeNames:Character_InterceptCostumeSelectionWindowCheck()
	local CostumeNames = Apollo.GetAddon("CostumeNames") -- Injected method, no ref for CostumeNames
	
	-- Show costume selection window
	CostumeNames.Character_CostumeSelectionWindowCheck(Character)
	
	-- Load overlay form, using same parent as the costume button holder
	local costumeBtnHolder = Character.wndCharacter:FindChild("CostumeBtnHolder")
	CostumeNames.wndCharacterOverlay = Apollo.LoadForm(CostumeNames.xmlDoc, "CostumeNamesOverlayForm", costumeBtnHolder:GetParent(), CostumeNames)	
	
	-- Set button texts	
	CostumeNames:PopulateButtonsFromSettings(costumeBtnHolder)
	
	-- Show overlay window itself
	CostumeNames.wndCharacterOverlay:Show(true, false)	
end

function CostumeNames:Character_InterceptCostumeSelectionWindowUnCheck(wndHandler, wndControl)
	-- Hide the Character overlay window
	local CostumeNames = Apollo.GetAddon("CostumeNames") -- Injected method, no ref for CostumeNames
	
	-- Pass uncheck on to Character
	CostumeNames.Character_CostumeSelectionWindowUnCheck(Character, wndHandler, wndControl)
	
	-- And hide my own overlay
	CostumeNames.wndCharacterOverlay:Show(false, true)
	CostumeNames:ToggleEditability(false)
end


	--[[ Character-addon overlay button functions ]]

function CostumeNames:OnEditNameButtonCheck(wndHandler, wndControl, eMouseButton)
	self:ToggleEditability(true)
end

function CostumeNames:OnEditNameButtonUncheck(wndHandler, wndControl, eMouseButton)
	self:ToggleEditability(false)
end

-- Initial population of button labels and editbox values from saved settings
function CostumeNames:PopulateButtonsFromSettings(wndCostumeBtnHolder)
	local CostumeNames = Apollo.GetAddon("CostumeNames")
	for idx = 1, GameLib.GetCostumeCount() do
		local strSavedName = CostumeNames:GetName(idx)
		wndCostumeBtnHolder:FindChild("CostumeBtn"..idx):SetText(strSavedName)
		CostumeNames.wndCharacterOverlay:FindChild("CostumeNameEdit"..idx):SetText(strSavedName)
	end
end

function CostumeNames:ToggleEditability(bEdit)
local CostumeNames = Apollo.GetAddon("CostumeNames")
	for idx = 1, GameLib.GetCostumeCount() do
		local strSavedName = self:GetName(idx)
			
		if bEdit then
			-- Edit-mode ON, update editbox value to saved name			
			CostumeNames.wndCharacterOverlay:FindChild("CostumeNameEdit"..idx):SetText(strSavedName)
		else
			-- Edit-mode OFF, update settings and button labels			
			local strNewName = CostumeNames.wndCharacterOverlay:FindChild("CostumeNameEdit"..idx):GetText()
			Character.wndCharacter:FindChild("CostumeBtn"..idx):SetText(strNewName)
			self.tSettings.tCostumeNames[idx] = strNewName
		end

		-- Update show/hide of buttons and editboxes
		self.wndCharacterOverlay:FindChild("CostumeNameEdit"..idx):Show(bEdit, true)
		Character.wndCharacter:FindChild("CostumeBtn"..idx):Show(not bEdit, true)
	end
end


	--[[ Save/Restore savedata ]]
	
function CostumeNames:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 
	end
		
	return self.tSettings
end

-- Restore addon config per character. Called by engine when loading UI.
function CostumeNames:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then 
		return 
	end
	
	self.tSettings = tSavedData
	self.tSettings.tCostumeNames = self.tSettings.tCostumeNames or {}
end

function CostumeNames:GetName(idx)
	return Apollo.GetAddon("CostumeNames").tSettings.tCostumeNames[idx] or String_GetWeaselString(Apollo.GetString("Character_CostumeNum"), idx)
end


local CostumeNamesInst = CostumeNames:new()
CostumeNamesInst:Init()

