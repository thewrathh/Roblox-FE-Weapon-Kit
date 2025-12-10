return function(value)
	local hasUserData = false
	local function check(data)
		if hasUserData then
			return
		end
		for i, v in pairs(data) do
			if hasUserData then
				return
			end
			if type(v) == "userdata" then
				hasUserData = true
				return
			end
			if type(i) == "userdata" then
				hasUserData = true
				return
			end
			if type(v) == "table" then
				check(v)
			end
		end
	end
	check(value)
	return false
end
