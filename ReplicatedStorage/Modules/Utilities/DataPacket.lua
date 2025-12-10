local HttpService = game:GetService("HttpService")

local CompressText, DecompressText = unpack(require(script.Parent:WaitForChild("TextCompress")))
local HasUserdata = require(script.Parent:WaitForChild("HasUserdata"))

local function CreatePacket(data)
	local newPacket = {{}, {}}
	local newPacketData = newPacket[1]
	local newPacketIndex = newPacket[2]

	for i, v in pairs(data) do
		if v ~= nil then
			if (type(v) == "table" and (not HasUserdata(v))) or (type(v) == "string" and utf8.len(v) >= 10) then
				local wasTable = (type(v) == "table")
				local compressed, success, convertedToJSON

				success = pcall(function()
					compressed, convertedToJSON = CompressText(v)
				end)

				if success and compressed and (not convertedToJSON) and (compressed ~= v) then
					newPacketData[i] = compressed
					newPacketIndex[i] = (wasTable and 1 or true)
				else
					newPacketData[i] = v
					newPacketIndex[i] = false
				end
			else
				newPacketData[i] = v
				newPacketIndex[i] = false
			end
		else
			v = false
			newPacketData[i] = v
			newPacketIndex[i] = 2
		end
	end

	return newPacket
end

local function DecodePacket(packet)
	local newData = {}

	local packetData = packet[1]
	local packetIndex = packet[2]
	local packetLength = 0

	for i, isEncoded in pairs(packetIndex) do
		local subData = packetData[i]

		if isEncoded then
			if isEncoded ~= 2 then
				local wasTable = (isEncoded == 1)
				local decoded, success

				success = pcall(function()
					decoded = DecompressText(subData)
				end)

				if success and decoded then
					if wasTable then
						decoded = HttpService:JSONDecode(decoded)
					end

					newData[i] = decoded
					--table.insert(newData, decoded)
				else
					error("Failed to decode packet data ("..subData..")")
				end
			else
				newData[i] = nil
			end
		else
			newData[i] = subData
			--table.insert(newData, subData)
		end

		packetLength = i
	end

	return newData
end

return {
	CreatePacket,
	DecodePacket,
}
