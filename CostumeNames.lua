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
	
	Apollo.RegisterEventHandler("CostumeSet", "OnCostumeChanged", self)
	
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
		CN.Character_Orig_ShowCharacterWindow = Character.ShowCharacterWindow
		Character.ShowCharacterWindow = CN.Character_Hook_ShowCharacterWindow	
	else
		Print("Warning: Addon 'CostumeNames' is designed for use with the stock Character addon.")
	end
	
	-- Prepare hooks & overlays for Costumes addon
	Costumes = Apollo.GetAddon("Costumes")
	if Costumes ~= nil then
		-- Hook showing Costumes window
		CN.Costumes_Orig_RedrawCostume = Costumes.RedrawCostume
		Costumes.RedrawCostume = CN.Costumes_Hook_RedrawCostume
	else
		Print("Warning: Addon 'CostumeNames' is designed for use with the stock Costumes addon.")
	end
end


-- Hook into the Character addon
function CostumeNames:Character_Hook_ShowCharacterWindow()
	-- Pass call to Character addon
	CN.Character_Orig_ShowCharacterWindow(Character)

	-- Update the Character-window button labels
	CN.UpdateCharacterWindow()
end


function CostumeNames:UpdateCharacterWindow()
	-- Safeguars against calls made when Character is not initialized/present (such as when updating names in the Holo Wardrobe)
	if Character == nil or Character.wndCharacter == nil then
		return 
	end

	-- Populate Character costume selection button texts
	local wndCostumeBtnHolder = Character.wndCharacter:FindChild("CostumeBtnHolder")
	if wndCostumeBtnHolder ~= nil then
		CostumeNames:PopulateButtonsFromSettings(wndCostumeBtnHolder)
	end
end


-- Hook into the Costumes addon
function CostumeNames:Costumes_Hook_RedrawCostume()
	-- Allow window to be shown
	CN.Costumes_Orig_RedrawCostume(Costumes)
	
	-- Update the Costume-window button labels
	CN.UpdateCostumeWindow()
	
	-- Load overlay form
	---[[
	if CN.wndCostumesOverlay == nil and Costumes.wndMain ~= nil then
		local costumeBtnHolder = Costumes.wndMain:FindChild("CostumeBtnHolder")
		CN.wndCostumesOverlay = Apollo.LoadForm(CN.xmlDoc, "CostumesOverlayForm", costumeBtnHolder:GetParent(), CostumeNames)
		CN.wndCostumesOverlay:Show(true, true)
		CN.wndCostumesOverlay:FindChild("CostumeNameEdit"):Show(false, true)
	end
	--]]
end

function CostumeNames:OnCostumeChanged()
	self:UpdateCostumeWindow()
end



function CostumeNames:UpdateCostumeWindow()
	-- Safeguars against calls made when Costumes is not initialized/present
	if Costumes == nil or Costumes.wndMain == nil then
		return 
	end
	
	-- Update all button texts
	local wndButtonHolder = Costumes.wndMain:FindChild("CostumeBtnHolder"):FindChild("Framing")	
	for idx = 1, CostumesLib.GetCostumeCount() do
		local strSavedName = CostumeNames:GetName(idx)
		local wndButton = wndButtonHolder:FindChildByUserData(idx)
		if wndButton ~= nil then
			wndButton:SetText(strSavedName)
		end
	end

	-- Update button with selected-costume name
	-- NB: Costumes.nSelectedCostumeId references the currently displayed (not equipped) costume. 
	-- If this is value is 0 it is because the "No Costume" option is selected in the Costume window
	if Costumes.nSelectedCostumeId ~= 0 then
		Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):SetText(CostumeNames:GetName(Costumes.nSelectedCostumeId or CostumesLib.GetCostumeIndex()))
	end
	
	-- Enable or disable edit button depending on "No Costume" idx 0 selection
	if CN.wndCostumesOverlay ~= nil and CN.wndCostumesOverlay:FindChild("CostumeNameEditButton") ~= nil then
		CN.wndCostumesOverlay:FindChild("CostumeNameEditButton"):Show(Costumes.nSelectedCostumeId ~= 0)
	end
end

	--[[ Costume addon overlay button functions ]]

function CostumeNames:OnCostumesEditNameButtonCheck()
	-- Hide dropdown button
	Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):Show(false, true)

	-- Show editbox instead, focus and place cursor at end
	local wndEditbox = CN.wndCostumesOverlay:FindChild("CostumeNameEdit")
	wndEditbox:SetText(Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):GetText())	
	wndEditbox:Show(true, true)	
	wndEditbox:SetFocus(true)
	wndEditbox:SetSel(string.len(wndEditbox:GetText()), string.len(wndEditbox:GetText()))
end

function CostumeNames:OnCostumesEditNameButtonUncheck()
	-- Hide editbox
	local wndEditbox = CN.wndCostumesOverlay:FindChild("CostumeNameEdit")	
	wndEditbox:Show(false, true)		
	
	-- Show dropdown button
	Costumes.wndMain:FindChild("SelectCostumeWindowToggle"):Show(true, true)
end

function CostumeNames:OnEditBoxChanged(wndHandler, wndControl, strText)
	local idx = Costumes.nSelectedCostumeId or CostumesLib.GetCostumeIndex()
	
	-- Update settings with new name
	CN.tSettings.tCostumeNames[idx] = strText
	
	-- Update Costumes and Character windows
	CN:UpdateCostumeWindow()
	CN:UpdateCharacterWindow()

end

	--[[ Common functions ]]

-- Population of button labels and editbox values from saved settings
function CostumeNames:PopulateButtonsFromSettings(wndCostumeBtnHolder)
	for idx = 1, CostumesLib.GetCostumeCount() do
		local strSavedName = CostumeNames:GetName(idx)
		wndCostumeBtnHolder:FindChild("CostumeBtn"..idx):SetText(strSavedName)		
	end
end

-- Gets a name from the saved tSettings-list, or provides a localized default "Costume X" string if no name is present
function CostumeNames:GetName(idx)
	return CN.tSettings.tCostumeNames[idx] or String_GetWeaselString(Apollo.GetString("Character_CostumeNum"), idx)	
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

local CostumeNamesInst = CostumeNames:new()
CostumeNamesInst:Init()