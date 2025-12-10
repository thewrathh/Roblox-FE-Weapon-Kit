local Module = {}

function Module.GetLength(Dictionary)
	local Counter = 0 
	for _, v in pairs(Dictionary) do
		Counter = Counter + 1
	end
	return Counter
end

function Module.SelectRandom(Dictionary)
	local Keys = {}

	for key, _ in pairs(Dictionary) do
		table.insert(Keys, key)
	end

	if #Keys == 1 then
		local OnlyKey = Keys[1]
		return Dictionary[OnlyKey]
	end

	local Position = Random.new():NextInteger(1, #Keys)
	local Key = Keys[Position]

	return Dictionary[Key]
end

return Module
