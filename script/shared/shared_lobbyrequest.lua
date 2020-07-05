function isnumber(v)
	return type(v) == 'number';
end
function isstring(v)
	return type(v) == 'string';
end
function isboolean(v)
	return type(v) == 'boolean';
end

local test = function(testcase)
	for i, v in ipairs(testcase) do
		if not v then
			return false;
		end
	end
	return true;
end

function LRValidator_ResearchOption(value)
	return true;
--[[	-- 이렇게 해보고 싶지만 테스트가 귀찮으니 다음에 해야징
	return test(
	{
		isnumber(value.Quality),
		isnumber(value.Research),
		isnumber(value.Production),
		isnumber(value.Quantity)
	});
]]
end