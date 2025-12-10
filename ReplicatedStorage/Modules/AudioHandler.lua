local AudioHandler = {}

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Camera = Workspace.CurrentCamera

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local PlayAudio = Remotes.PlayAudio

local Utilities = require(Modules.Utilities)
local Thread = Utilities.Thread
local CloneTable = Utilities.CloneTable
local CreatePacket, DecodePacket = unpack(Utilities.DataPacket)

local LoopingSounds = {}

function AudioHandler:PlayAudio(Audio, LowAmmoAudio, Replicate, NoDecode)
	if not Replicate and not NoDecode then
		Audio = DecodePacket(Audio)
	end
	if Audio.Instance and Audio.Origin then
		if Audio.LoopData then
			LowAmmoAudio = nil
			if Audio.LoopData.Enabled then
				local Sound = Audio.Instance:Clone()
				Sound.Name = Audio.Instance.Name.."Clone"
				Sound.Looped = true
				Sound.Parent = Audio.Origin
				
				local OriginalPlaybackSpeed = Sound.PlaybackSpeed
				
				if Audio.Silenced then
					Sound.PlaybackSpeed = Sound.PlaybackSpeed * 1.5

					local SilencedEqualizer	= script.SilencedEqualizer:Clone()
					SilencedEqualizer.Parent = Sound
				end
				
				if Audio.Echo then
					local DistanceEqualizer	= script.DistanceEqualizer:Clone()
					DistanceEqualizer.Enabled = false
					DistanceEqualizer.Parent = Sound
					
					local ReverbSoundEffect	= script.ReverbSoundEffect:Clone()
					ReverbSoundEffect.Enabled = false
					ReverbSoundEffect.Parent = Sound
				end
				
				table.insert(LoopingSounds, {
					Id = Audio.LoopData.Id,
					Instance = Sound,
					Origin = Audio.Origin,
					OriginalPlaybackSpeed = OriginalPlaybackSpeed
				})
			else
				for i, v in pairs(LoopingSounds) do
					if v.Id == Audio.LoopData.Id then
						v.Terminate = true
						break
					end
				end
			end
		else			
			local Sound = Audio.Instance:Clone()
			Sound.Name = Audio.Instance.Name.."Clone"
			Sound.Parent = Audio.Origin

			if Audio.TimePosition then
				Sound.TimePosition = Audio.TimePosition
			end

			if Audio.Echo then
				local Position = Audio.Origin.ClassName == "Attachment" and Audio.Origin.WorldPosition or Audio.Origin.Position
				local Distance = math.min(1000, (Camera.CFrame.p - Position).Magnitude)
				if Distance > 200 then
					local ReverbSoundEffect	= script.ReverbSoundEffect:Clone()
					ReverbSoundEffect.DryLevel = 0
					ReverbSoundEffect.WetLevel = (Distance / 1000) * -20
					ReverbSoundEffect.Parent = Sound

					local DistanceEqualizer	= script.DistanceEqualizer:Clone()
					DistanceEqualizer.LowGain = (Distance / 1000) * -15
					DistanceEqualizer.MidGain = (Distance / 1000) * 5
					DistanceEqualizer.HighGain = 0
					DistanceEqualizer.Parent = Sound
				end
			end

			if Audio.Silenced then
				Sound.PlaybackSpeed	= Sound.PlaybackSpeed * 1.5

				local SilencedEqualizer	= script.SilencedEqualizer:Clone()
				SilencedEqualizer.Parent = Sound
			end

			Thread:Delay(Audio.SoundDelay or 0, function()
				Sound:Play()
				Debris:AddItem(Sound, Sound.TimeLength / Sound.PlaybackSpeed)
			end)

			--[[Thread:Delay(Audio.SoundDelay or 0, function()
				repeat Thread:Wait() until Sound.TimeLength ~= 0
				Sound:Play()
				Debris:AddItem(Sound, Sound.TimeLength / Sound.PlaybackSpeed)
			end)]]

			if LowAmmoAudio then
				if not Replicate then
					LowAmmoAudio = DecodePacket(LowAmmoAudio)
				end
				if LowAmmoAudio.Instance and LowAmmoAudio.CurrentAmmo <= LowAmmoAudio.AmmoPerMag / 5 then
					local LowAmmoSound = LowAmmoAudio.Instance:Clone()
					LowAmmoSound.Name = LowAmmoAudio.Instance.Name.."Clone"
					LowAmmoSound.Parent = Audio.Origin

					if LowAmmoAudio.RaisePitch then
						LowAmmoSound.PlaybackSpeed = (math.max(math.abs(LowAmmoAudio.CurrentAmmo / 10 - 1), 0.4))
					end

					LowAmmoSound:Play()
					Debris:AddItem(Sound, Sound.TimeLength / Sound.PlaybackSpeed)
				end
			end
		end

		if Replicate then
			PlayAudio:FireServer(CreatePacket(CloneTable(Audio)), LowAmmoAudio ~= nil and CreatePacket(CloneTable(LowAmmoAudio)) or nil)
		end		
	end
end

RunService.RenderStepped:Connect(function(dt)
	for i, v in next, LoopingSounds, nil do
		if v.Terminate then
			v.Terminate = false
			if v.Instance then
				v.Instance:Destroy()
			end 
			table.remove(LoopingSounds, i)
		else
			if v.Instance and v.Origin then
				if not v.Instance.Playing then
					v.Instance:Play()
				end
				if v.Instance:FindFirstChild("DistanceEqualizer") and v.Instance:FindFirstChild("ReverbSoundEffect") then
					local Position = v.Origin.ClassName == "Attachment" and v.Origin.WorldPosition or v.Origin.Position
					local Distance = math.min(1000, (Camera.CFrame.p - Position).Magnitude)
					if Distance > 200 then						
						v.Instance.ReverbSoundEffect.Enabled = true
						v.Instance.ReverbSoundEffect.DryLevel = 0
						v.Instance.ReverbSoundEffect.WetLevel = (Distance / 1000) * -20
						
						v.Instance.DistanceEqualizer.Enabled = true
						v.Instance.DistanceEqualizer.LowGain = (Distance / 1000) * -15
						v.Instance.DistanceEqualizer.MidGain = (Distance / 1000) * 5
						v.Instance.DistanceEqualizer.HighGain = 0
					else						
						v.Instance.ReverbSoundEffect.Enabled = false
						v.Instance.DistanceEqualizer.Enabled = false
					end
				end
			else
				table.remove(LoopingSounds, i)
			end 
		end
	end
end)

return AudioHandler
