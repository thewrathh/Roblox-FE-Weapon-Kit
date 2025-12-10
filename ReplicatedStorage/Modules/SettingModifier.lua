local function Add(a, b)
	return a + b
end

local function Multiply(a)
	return 1 * a
end

local function IsAlgebraic(v)
	return pcall(Add, v, v) and pcall(Multiply, v)
end

local function GetValue(list)
	local n = #list
	local last = list[n]
	if IsAlgebraic(last) then
		local baseType = typeof(last)
		local count = 1
		local sum = last
		for i = 1, n - 1 do
			local v = list[i]
			if typeof(v) == baseType then
				count = count + 1
				sum = sum + v
			end
		end
		return 1 / count * sum
	else
		return last
	end
end

local function GetProperties(...)
	local lists = {
		...
	}
	local properties = {}
	for i = 1, #lists do
		for property in next, lists[i], nil do
			properties[property] = (properties[property] or 0) + 1
		end
	end
	return properties
end

return function(setting, modTable)
	local newData = {}
	local sets = {}
	local muls = {}
	local adds = {}
	if modTable then
		local statSets = {}
		local statMuls = {}
		local statAdds = {}
		for i, v in ipairs(modTable) do
			local setters = v.Settings or {}
			local multipliers = v.Mods or {}
			local additions = v.Adds or {}
			for property, value in next, setters, nil do
				local list = statSets[property]
				if list then
					list[#list + 1] = value
				else
					statSets[property] = {value}
				end
			end
			for property, value in next, multipliers, nil do
				statMuls[property] = value * (statMuls[property] or 1)
			end
			for property, value in next, additions, nil do
				statAdds[#statAdds + 1] = {property, value}
			end
		end
		local properties = GetProperties(setting, statSets, statMuls)
		for property in next, properties, nil do
			local setList = statSets[property]
			local multiplier = statMuls[property]
			local default = setting[property]
			local value
			if setList and #setList ~= 0 then
				value = GetValue(setList)
			else
				value = default
			end
			if multiplier and IsAlgebraic(value) then
				value = multiplier * value
			end
			newData[property] = value
		end
		for index, propertyData in next, statAdds, nil do
			local property = propertyData[1]
			local value = propertyData[2]
			if not newData[property] or type(newData[property]) ~= "table" then
				newData[property] = {}
			end
			local propertyList = newData[property]
			propertyList[#propertyList + 1] = value
		end
	end
	return newData
end
