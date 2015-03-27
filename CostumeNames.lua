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
	else
		Print("Warning: Addon 'CostumeNames' is designed for use with the stock Character addon.")
	end
	
	-- Prepare hooks & overlays for Costumes addon
	Costumes = Apollo.GetAddon("Costumes")
	if Costumes ~= nil then
		-- Hook showing Costumes window
		CN.Costumes_ShowCostumeWindow = Costumes.ShowCostumeWindow
		Costumes.ShowCostumeWindow = CN.Costumes_InterceptShowCostumeWindow
		
		CN.Costumes_UpdateCostumeSlotIcons = Costumes.UpdateCostumeSlotIcons
		Costumes.UpdateCostumeSlotIcons = CN.Costumes_InterceptUpdateCostumeSlotIcons
	else
		Print("Warning: Addon 'CostumeNames' is designed for use with the stock Costumes addon.")
	end
end


	--[[ Hooks into Character addon ]]

function CostumeNames:Character_InterceptUpdateCostumeSlotIcons()
	-- Pass on to character
	CN.Character_UpdateCostumeSlotIcons(Character)

	-- Populate Character costume selection button texts
	local wndCostumeBtnHolder = Character.wndCharacter:FindChild("CostumeBtnHolder")
	if wndCostumeBtnHolder ~= nil then
		CostumeNames:PopulateButtonsFromSettings(wndCostumeBtnHolder)
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
	if CN.wndCostumesOverlay == nil then
		CN.wndCostumesOverlay = Apollo.LoadForm(CN.xmlDoc, "CostumesOverlayForm", costumeBtnHolder:GetParent(), CostumeNames)
		CN.wndCostumesOverlay:Show(true, true)
		CN.wndCostumesOverlay:FindChild("CostumeNameEdit"):Show(false, true)
	end
end

function CostumeNames:Costumes_InterceptUpdateCostumeSlotIcons()
	-- Allow icons to be updated
	CN.Costumes_UpdateCostumeSlotIcons(Costumes)
	
	-- Update all button texts
	local costumeBtnHolder = Costumes.wndMain:FindChild("CostumeBtnHolder")
	CostumeNames:PopulateButtonsFromSettings(costumeBtnHolder)
	Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):SetText(CostumeNames:GetName(GameLib.GetCostumeIndex()))
end


	--[[ Costume addon overlay button functions ]]

function CostumeNames:OnCostumesEditNameButtonCheck()
	Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):Show(false, true)

	local wndEditbox = CN.wndCostumesOverlay:FindChild("CostumeNameEdit")
	wndEditbox:SetText(Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):GetText())
	wndEditbox:Show(true, true)	
end

function CostumeNames:OnCostumesEditNameButtonUncheck()
	local strNewName = CN.wndCostumesOverlay:FindChild("CostumeNameEdit"):GetText()
	Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):SetText(strNewName)
	CN.tSettings.tCostumeNames[GameLib.GetCostumeIndex()] = strNewName
	
	CN.wndCostumesOverlay:FindChild("CostumeNameEdit"):Show(false, true)
	Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):Show(true, true)
	
	-- Update all button texts
	local costumeBtnHolder = Costumes.wndMain:FindChild("CostumeBtnHolder")
	CostumeNames:PopulateButtonsFromSettings(costumeBtnHolder)	
	
	-- Also update buttons on Character panel if possible
	local wndCostumeBtnHolder = Character.wndCharacter:FindChild("CostumeBtnHolder")
	if wndCostumeBtnHolder ~= nil then
		CostumeNames:PopulateButtonsFromSettings(wndCostumeBtnHolder)
	end	
end


	--[[ Common functions ]]

-- Population of button labels and editbox values from saved settings
function CostumeNames:PopulateButtonsFromSettings(wndCostumeBtnHolder)
	for idx = 1, GameLib.GetCostumeCount() do
		local strSavedName = CostumeNames:GetName(idx)
		wndCostumeBtnHolder:FindChild("CostumeBtn"..idx):SetText(strSavedName)		
	end
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

