local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local SettingModifier = require(Modules.SettingModifier)
local Utilities = require(Modules.Utilities)
local CloneTable = Utilities.CloneTable

return function(Tool, Data, IsMelee, NPCData)
	local Setting = {}
	local Setting2 = {}
	
	if NPCData then
		if NPCData.Module then
			Setting = CloneTable(require(NPCData.Module))
			if NPCData.ModData and NPCData.ModData.ModNames then
				if NPCData.ModData.ModNames["Conditions"] then
					for _, v in pairs(NPCData.ModData.ModNames["Conditions"]) do
						if Setting.Conditions[v] then
							Setting = SettingModifier(Setting, {Setting.Conditions[v]})
						end
					end
				end
				if NPCData.ModData.ModNames["ConditionsInIndividualShot"] then
					for _, v in pairs(NPCData.ModData.ModNames["ConditionsInIndividualShot"]) do
						if Setting.ConditionsInIndividualShot[v] then
							Setting = SettingModifier(Setting, {Setting.ConditionsInIndividualShot[v]})
						end
					end
				end
				if NPCData.ModData.BulletId and NPCData.ModData.ModNames["ConditionsInIndividualBullet"] and NPCData.ModData.ModNames["ConditionsInIndividualBullet"][NPCData.ModData.BulletId] then
					for _, v in pairs(NPCData.ModData.ModNames["ConditionsInIndividualBullet"][NPCData.ModData.BulletId]) do
						if Setting.ConditionsInIndividualBullet[v] then
							Setting = SettingModifier(Setting, {Setting.ConditionsInIndividualBullet[v]})
						end
					end
				end
			end
		end
	else
		local Module = Tool:FindFirstChild("Setting")
		if Module then
			local NewModule = Module:FindFirstChild(Data.ModuleName, true)
			if NewModule then
				if IsMelee then
					Setting = CloneTable(require(Module))
					Setting2 = CloneTable(require(NewModule))
					return table.freeze(Setting), table.freeze(Setting2)
				else
					Setting = CloneTable(require(NewModule))
					if Data.ModNames then
						if Data.ModNames["Conditions"] then
							for _, v in pairs(Data.ModNames["Conditions"]) do
								if Setting.Conditions[v] then
									Setting = SettingModifier(Setting, {Setting.Conditions[v]})
								end
							end
						end
						if Data.ModNames["ConditionsInIndividualShot"] then
							for _, v in pairs(Data.ModNames["ConditionsInIndividualShot"]) do
								if Setting.ConditionsInIndividualShot[v] then
									Setting = SettingModifier(Setting, {Setting.ConditionsInIndividualShot[v]})
								end
							end
						end
						if Data.BulletId and Data.ModNames["ConditionsInIndividualBullet"] and Data.ModNames["ConditionsInIndividualBullet"][Data.BulletId] then
							for _, v in pairs(Data.ModNames["ConditionsInIndividualBullet"][Data.BulletId]) do
								if Setting.ConditionsInIndividualBullet[v] then
									Setting = SettingModifier(Setting, {Setting.ConditionsInIndividualBullet[v]})
								end
							end
						end
					end
				end
			end
		end
	end
	
	return table.freeze(Setting)
end
