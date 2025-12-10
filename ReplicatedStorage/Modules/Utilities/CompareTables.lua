local function AreColorsEqual(colorA, colorB, epsilon)
	local epsilon = epsilon or 0.001

	if math.abs(colorA.R - colorB.R) > epsilon then
		return false
	end

	if math.abs(colorA.G - colorB.G) > epsilon then
		return false
	end

	if math.abs(colorA.B - colorB.B) > epsilon then
		return false
	end

	return true
end

local function CompareTables(arr1, arr2)
	for i, v in pairs(arr1) do
		if (typeof(v) == "table") then
			if typeof(arr2[i]) == "table" then
				if (CompareTables(arr2[i], v) == false) then
					return false
				end
			else
				local matched = true
				for ii, vv in pairs(v) do
					if (typeof(vv) == "Color3" and typeof(arr2[i]) == "Color3") then
						if not AreColorsEqual(vv, arr2[i]) then
							matched = false
							break
						end
					else
						if (vv ~= arr2[i]) then
							matched = false
							break
						end
					end
				end
				if not matched then
					return false
				end
			end
		else
			if (typeof(v) == "Color3" and typeof(arr2[i]) == "Color3") then
				if not AreColorsEqual(v, arr2[i]) then
					return false
				end
			else
				if (v ~= arr2[i]) then
					return false
				end
			end
		end
	end
	return true
end

return CompareTables
