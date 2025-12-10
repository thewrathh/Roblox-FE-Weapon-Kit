function ScanClone(t, targ)
	for k, v in pairs(t) do
		if type(v) == "table" then
			targ[k] = {}
			ScanClone(v, targ[k])
		else
			targ[k] = v
		end
	end
end

return function(t)
	local clone = {}
	ScanClone(t, clone)
	return clone
end
