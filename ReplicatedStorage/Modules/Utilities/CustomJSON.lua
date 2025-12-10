--[[
Custom JSON encoder / decoder with userdata serialization support

Supported userdata:
-CFrame
-Vector3
-Vector2
-BrickColor
-Color3
-Enum
--]]

local CompressText, DecompressText = unpack(require(script.Parent:WaitForChild("TextCompress")))

local HttpService = game:GetService("HttpService")

function UDToString(v)
	local type = typeof(v)
	local r = ""
	if type == "CFrame" then
		--local rx, ry, rz = v:toEulerAnglesXYZ()
		--return "!%CF"..v.p.X..","..v.p.Y..","..v.p.Z..","..rx..","..ry..","..rz
		local str_res = "!%CF"
		local comp = {v:components()}
		str_res = str_res..comp[1]
		for i = 2, 12 do
			str_res = str_res..","..comp[i]
		end
		r = str_res
	elseif type == "Vector3" then
		r = "!%V3"..v.X..","..v.Y..","..v.Z
	elseif type == "Vector2" then
		r = "!%V2"..v.X..","..v.Y
	elseif type == "BrickColor" then
		r = "!%BC"..v.Number
	elseif type == "Color3" then
		local hue, sat, val = Color3.toHSV(v)
		r = "!%C3"..hue..","..sat..","..val
	elseif type == "EnumItem" then
		local s = string.split(tostring(v), ".")
		r = "!%EN"..s[2]..","..s[3]
	end
	return r
end

function StringToUD(v, acc)
	local args = {}
	for d in string.gmatch(v:sub(5), "[%w%.%-]+") do
		table.insert(args, d)
	end
	if v:sub(3, 4) == "CF" and #args == 12 then
		return CFrame.new(tonumber(args[1]), tonumber(args[2]), tonumber(args[3]), tonumber(args[4]), tonumber(args[5]), tonumber(args[6]), tonumber(args[7]), tonumber(args[8]), tonumber(args[9]), tonumber(args[10]), tonumber(args[11]), tonumber(args[12]))
	elseif v:sub(3, 4) == "V3" and #args == 3 then
		return Vector3.new(tonumber(args[1]), tonumber(args[2]), tonumber(args[3]))
	elseif v:sub(3, 4) == "V2" and #args == 2 then
		return Vector2.new(tonumber(args[1]), tonumber(args[2]))
	elseif v:sub(3, 4) == "BC" and #args == 1 then
		return BrickColor.new(tonumber(args[1]))
	elseif v:sub(3, 4) == "C3" and #args == 3 then
		return Color3.fromHSV(tonumber(args[1]), tonumber(args[2]), tonumber(args[3]))
	elseif v:sub(3, 4) == "EN" and #args == 2 then
		return Enum[args[1]][args[2]]
	end
	return v
end

function CheckUserData(val, encode)
	if encode then
		if type(val) == "userdata" then
			return UDToString(val)
		elseif type(val) == "number" then
			if val == math.huge then
				return "math.huge"
			else
				return val
			end
		end
	else
		if type(val) == "string" then
			if val == "math.huge" then
				return math.huge
			else
				if val:sub(1, 2) == "!%" then
					return StringToUD(val, 3)
				end
			end
		end
	end
	return val
end

function JSONEncode(dat)
	local res = {}
	local function Scan(t, targ)
		for k, v in pairs(t) do
			if type(v) == "table" then
				targ[k] = {}
				Scan(v, targ[k])
			else
				targ[k] = CheckUserData(v, true)
			end
		end
	end
	Scan(dat, res)
	
	return HttpService:JSONEncode(res)
end

function JSONDecode(dat)
	local res = HttpService:JSONDecode(dat)
	local function Scan(t)
		for k, v in pairs(t) do
			if type(v) == "table" then
				Scan(v)
			else
				t[k] = CheckUserData(v, false)
			end
		end
	end
	Scan(res)
		
	return res
end

--Temporarily disabled text compression because it would screw data up while decompressing/decoding

local function JSONEncodeComp(dat)
	return JSONEncode(dat) --CompressText(JSONEncode(dat))
end

local function JSONDecodeComp(dat)
	return JSONDecode(dat) --JSONDecode(DecompressText(dat))
end

return {
	JSONEncode,
	JSONDecode,
	JSONEncodeComp,
	JSONDecodeComp,
}
