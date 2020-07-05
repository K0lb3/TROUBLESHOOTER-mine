function RebaseClassTableToXmlTable(t)
	local ret = {};
	if t == nil then
		print(debug.traceback())
		return ret;
	end
	for key, value in pairs(t) do
		if type(value) == 'table' then
			if type(key) == 'number' then -- 숫자형 인덱스
				table.insert(ret, RebaseClassTableToXmlTable(value));
			else
				ret[key] = {RebaseClassTableToXmlTable(value)};
			end
		elseif key ~= 'name' then
			ret[key] = value;
		end
	end
	return ret;
end

function RebaseXmlTableToClassTable(t)
	local ret = {};
	for key, value in pairs(t) do
		if type(key) == 'number' then
			table.insert(ret, RebaseXmlTableToClassTable(value));
		else
			if type(value) == 'table' then
				ret[key] = RebaseXmlTableToClassTable(value[1]);
			else
				ret[key] = value;
			end
		end
	end
	return ret;
end

--[[
af = {FrameList = {Frame = {{Frame = 40}, {Frame = 45}}}};
a = RebaseClassTableToXmlTable(af);
LogAndPrint(af);
LogAndPrint(a);
bf = {FrameList = {{Frame = {{{Frame = 40}, {Frame = 45}}}}}};
b = RebaseXmlTableToClassTable(bf);
LogAndPrint(bf);
LogAndPrint(b);
]]