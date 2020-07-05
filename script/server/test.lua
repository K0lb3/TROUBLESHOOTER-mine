function hello( a, b )
	-- print(a .. b);
	return 1, 2;
end

function TestScript( ... )
	local sum = 0
	for i = 1, arg.n do
		sum = sum + arg[i]
	end
	return sum;
end

function TestScriptMultithread( ... )
	local t = TestScript(...);
	x = (x or 0) + t;
	return t;
end

function MetatableTest(m)
	m.k1 = 3.45;
	m.count = #m;
	-- print(m.abc);
end

function ObjectTest(o)
	for i = 1, 10 do
		o.value1 = i;
		o = o.value3;
	end
end

function PropertyListTest(o)
	local sum = 0
	for i = 1, #o.list1 do
		sum = sum + o.list1[i]
	end
	return sum
end

function PropertyListTest2(o)
	local sum = 0;
	for i = 1, #o.list2 do
		sum = sum + o.list2[i].value1
	end
	return sum
end

function TestGetDistance(o1, o2)
	local dx = o1.position.x - o2.position.x
	local dy = o1.position.y - o2.position.y
	return math.sqrt(math.pow(dx, 2) + math.pow(dy, 2))
end

function TableReturnTest()
	local t = { 1, "2", true }
	t["123"] = "456"
	t.inner = { dummy = 7.22 }
	return t;
end

function TableParameterTest(t)
	function TableToString(t)
		local str = "{ "
		local isFirst = true;
		for k, v in pairs(t) do
			if isFirst then
				isFirst = false
			else
				str = str .. ", "
			end
			function ValueToString(v)
				if type(v) == "table" then
					return TableToString(v)
				elseif type(v) == "string" then
					return '"' .. v .. '"'
				else
					return tostring(v)
				end
			end
			local kStr = ValueToString(k)
			local vStr = ValueToString(v)
			str = str .. string.format("%s = %s",  kStr, vStr)
		end
		str = str .. " }"
		return str
	end
	
	return TableToString(t)
end
function REGISTER_TEST()
	local ret = TEST_FUNCTION(1, "test")
	TEST_EQUAL(ret, 52);
end

function ObjectOwnerTest(o)
	return o;
end

function ScriptThreadingTest(sleepTime, pushValue)
	Sleep(sleepTime);
	Push(pushValue);
end

function CP_TEST(self, propName)
	if propName == 'cptest2' then
		return 3.141592;
	end
	return self.value1 + self.value3.value1;
end

function CP_TEST2(self)
	return self.value1;
end

function FUNC_TEST(...)
	local sum = 0;
	for i, v in ipairs(arg) do
		Output(v);
		sum = sum + v;
	end
	return sum;
end
function FUNC_TEST2(...)
	local prod = 1;
	for i, v in ipairs(arg) do
		prod = prod * v;
	end
	return prod;
end
function MapTableCPTest(mt, key)
	return key;
end

function FunctableTest(o)
	local sum = 0;
	print('count', #o.functiontables);
	for i, f in ipairs(o.functiontables) do
		sum = sum + f(1, 2, 3, 4);
	end
	return sum;
end

function TEST_XML_CLASS(idspace, name, column)
	Output("HAHAHA");
	local cl = GetClassList(idspace);
	Output("size:", #cl[name]);
	for i = 1, #(cl[name]) do
		Output(cl[name][i]);
	end
	return cl[name][column];
end

function pairsTest(o)
	local sum = 0
	for k, v in pairs(o.list1) do
		Output(k);
		Output(v);
		sum = sum + v
	end
	return sum
end

function ipairsTest(o)
	local sum = 0
	for i, v in ipairs(o.list1) do
		Output(i);
		Output(v);
		sum = sum + v
	end
	return sum
end

function GetSumFunc()
	return function (...)
		local sum = 0;
		for i, v in ipairs(arg) do
			sum = sum + v;
		end
		return sum;
	end
end

function TableCppIterationTest()
	return { 1, 2, 3, 4, 5 }
end

function MakeCoroutineCounter()
	local count = 0;
	return function()
		count = count + 1;
		return count;
	end
end

function DoNotingTestScript(a)
	print(a);
end