function PackTableToString(args)
	local s = "";

	for k,v in pairs(args) do
		if (type(k) == "string" or type(k) == "number") and (type(v) == "number" or type(v) == "string" or type(v) == "boolean" or type(v) == "table" or type(v) == "nil") then
			if s ~= "" then
				s = s..","
			end
			
			if type(k) == "string" then
				s = s..k
			elseif type(k) == "number" then
				s = s.."["..tostring(k).."]"
			end
			
			s = s.."="
			
			if type(v) == "number" or type(v) == "boolean" then
				s = s..tostring(v)
			elseif type(v) == "string" then
				s = s.."[=["..string.gsub(v, '\\', '\\\\').."]=]"
			elseif type(v) == "table" then
				s = s..PackTableToString(v)
			elseif type(v) == "nil" then
				s = s.."nil"
			end
		end
	end
	
	return "{"..s.."}"
end

function UnpackTableFromString(str)
	local func = loadstring("return "..str);
	if func == nil then
		LogAndPrint('UnpackTableFromString failed - str:', str);
		Traceback();
		return {};
	end
	return func();
end

function PackTableToStringReadable(args, forlog)
	local s = ""
	if args == nil then
		return  'nil';
	end
	if forlog and getmetatable(args) and getmetatable(args).__tostring then
		return tostring(args);
	end
	local kvList = {}
	for k, v in pairs(args) do
		if k ~= '__index' then
			table.insert(kvList, {k=k, v=v})
		end
	end
	
	table.sort(kvList, function (a, b)
		if type(a.k) == type(b.k) then
			return a.k < b.k
		else
			return type(a.k) < type(b.k)
		end
	end)
	
	local numberIndex = 1;
	for _, kv in ipairs(kvList) do
		local k = kv.k
		local v = kv.v
	
		if (type(k) == "string" or type(k) == "number") and (type(v) == "number" or type(v) == "string" or type(v) == "boolean" or type(v) == "table" or type(v) == "nil") then
			if s ~= "" then
				s = s..", "
			end
			
			if type(k) == "string" then
				s = s..k.."="
			elseif type(k) == "number" then
				if numberIndex == k then
					numberIndex = numberIndex + 1
				else
					s = s.."["..tostring(k).."]".."="
				end
			end
			
			if type(v) == "number" or type(v) == "boolean" then
				s = s..tostring(v)
			elseif type(v) == "string" then
				s = s.."\""..v.."\""
			elseif type(v) == "table" then
				s = s..PackTableToStringReadable(v, forlog);
			elseif type(v) == "nil" then
				s = s.."nil"
			end
		end
	end
	
	return "{"..s.."}"
end

-- http://rosettacode.org/wiki/Y_combinator#Lua
Y = function (f)
   return function(...)
      return (function(x) return x(x) end)(function(x) return f(function(y) return x(x)(y) end) end)(...)
   end
end
-- 원래 인자 하나밖에 안된다네 ㅠ

function GetBindFunctionList()
	local ret = {}
	for k, v in pairs(_G) do
		if type(v) == 'function' and #k > 0 then
			table.insert(ret, k);
		end
	end
	return ret;
end

-- https://stackoverflow.com/a/1252776
function table.empty(t)
	return (next(t) == nil);
end

-- http://lua-users.org/wiki/CopyTable
function table.deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[table.deepcopy(orig_key)] = table.deepcopy(orig_value)
        end
        setmetatable(copy, table.deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy;
end

-- http://lua-users.org/wiki/CopyTable
function table.shallowcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[orig_key] = orig_value
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function table.overwrite(dest, source)
	for k, v in pairs(source) do
		dest[k] = v;
	end
	return dest;
end

function table.shuffle(tab)
  local new = {}
  for i=1, #tab do
    table.insert(new, math.random(i), tab[i])
  end
  return new;
end

function table.count(t, testFunc)
	testFunc = testFunc or function(a) return true end;
	local count = 0;
	for key, value in pairs(t) do
		if testFunc(value) then
			count = count + 1;
		end
	end
	return count;
end

function table.exist(t, testFunc)
	for key, value in ipairs(t) do
		if testFunc(value, key) then
			return true;
		end
	end
	return false;
end

function __op_add(a, b) return a + b end;
function __op_sub(a, b) return a - b end;
function __op_mul(a, b) return a * b end;

function table.sum(t, valueFunc, base, pairFunc)
	base = base == nil and 0 or base;
	return table.foldr(t, function(a, base) return valueFunc(a) + base end, base);
end

function table.map2(t1, t2, opFunc)
	local retT = {};
	for k, v in pairs(t1) do
		retT[k] = opFunc(v, t2[k]);
	end
	return retT;
end

function table.min(t, scoreFunc)
	scoreFunc = scoreFunc or function(v) return v end;
	local minScore = nil;
	local minVal = nil;
	for k, v in pairs(t) do
		local thisScore = scoreFunc(v);
		if minScore == nil or minScore > thisScore then
			minScore = thisScore;
			minVal = v;
		end
	end
	
	return minVal, minScore;
end

function table.max(t, scoreFunc)
	scoreFunc = scoreFunc or function(v) return v end;
	local maxScore = nil;
	local maxVal = nil;
	for k, v in pairs(t) do
		local thisScore = scoreFunc(v);
		if maxScore == nil or maxScore > thisScore then
			maxScore = thisScore;
			maxVal = v;
		end
	end
	
	return maxVal;
end

function LogAndPrint(...)
	local msgs = {}
	for i = 1, arg.n do
		local v = arg[i];
		if type(v) == 'table' then
			msgs[i] = PackTableToStringReadable(v, true);
		else
			msgs[i] = tostring(v);
		end
	end
	local msg = table.concat(msgs, '\t');
	msg = ToAnsiStr(msg)
	Log(msg);
	print(msg);
end
function LogAndPrintDev(...)
	if not IsDevLogEnabled() then
		return;
	end
	LogAndPrint(...);
end
function LogOnly(...)
	local msgs = {}
	for i = 1, arg.n do
		local v = arg[i];
		if type(v) == 'table' then
			msgs[i] = PackTableToStringReadable(v, true);
		else
			msgs[i] = tostring(v);
		end
	end
	local msg = table.concat(msgs, '\t');
	msg = ToAnsiStr(msg)
	Log(msg);
end

function FormatMessage(formatStr, formatTable, patternResolver, keepUnresolved, onlyOne)
	local n = onlyOne and 1;
	patternResolver = patternResolver or function (p, k) return p ~= nil and tostring(p) or p; end
	for tryCount = 1, 5 do
		local prevStr = formatStr;
		if formatStr == nil or formatTable == nil or type(formatStr) ~= 'string' then
			Traceback();
		end
		local replacedSet = {};
		for from in string.gmatch(formatStr, '%$[^%$]+%$') do
			local fromKey = string.sub(from, 2, -2)
			local fromPattern = '%$'..fromKey..'%$';
			local replacePattern = patternResolver(formatTable[fromKey], fromKey);
			if replacePattern ~= nil and (onlyOne or not replacedSet[fromKey]) then
				if type(replacePattern) == 'function' then
					print('fromKey: ', fromKey, ' is FunCTION!!!!!');
				end
				replacePattern = string.gsub(replacePattern, '%%', '%%%%');
				fromPattern = string.gsub(fromPattern, '%(', '%%%(');
				fromPattern = string.gsub(fromPattern, '%)', '%%%)');
				formatStr = string.gsub(formatStr, fromPattern, replacePattern, n);
				replacedSet[fromKey] = true;
			end
		end
		if prevStr == formatStr then
			break;
		end
	end
	if keepUnresolved then
		return formatStr;
	end
	local ret = string.gsub(formatStr, '%$[^%$]+%$', '');
	return ret;
end

function IsSamePosition(p1, p2)
	if p1 == nil or p2 == nil then
		LogAndPrint('IsSamePosition', 'Input is nil', p1, p2);
		Traceback();
		return false;
	end
	return p1.x == p2.x and p1.y == p2.y and p1.z == p2.z;
end

function PositionInArea(range_from, range_to, pos)
	return range_from.x <= pos.x and range_from.y <= pos.y
		and pos.x <= range_to.x and pos.y <= range_to.y
end
function PositionInRange(posList, pos)
	for i, p in ipairs(posList) do
		if IsSamePosition(p, pos) then
			return true;
		end
	end
	return false;
end
function PositionInAreaIndicator(mid, areaIndicator, pos, conditionOutput)
	local areaIndicator = SafeIndex(areaIndicator, 1);
	local at = SafeIndex(areaIndicator, 'Type');
	if at == nil then
		return false;
	elseif at == 'Area' then
		return PositionInArea(areaIndicator.Area[1].From[1], areaIndicator.Area[1].To[1], pos);
	elseif at == 'Range' then
		local p = GetPositionFromPositionIndicator(mid, areaIndicator.PositionIndicator, conditionOutput, false);
		if IsInvalidPosition(p) then
			return false;
		end
		return GetDistance3D(p, pos) <= areaIndicator.Range;
	elseif at == 'PositionList' then
		local posList = table.map(areaIndicator.PositionList[1].PosElem, function(pi)
			return GetPositionFromPositionIndicator(mid, pi.PositionIndicator, conditionOutput, true);
		end);
		return PositionInRange(posList, pos);
	elseif at == 'PositionHolder' then
		local positionHolder = areaIndicator.PositionHolder;
		return PositionInRange(Linq.new(GetPositionHolders(mid))
			:where(function(ph) return ph.Group == areaIndicator.PosHolderGroup end)
			:select(function(ph) return ph.Position end)
			:toList(), pos);
	elseif at == 'Union' then
		local areainds = areaIndicator.AreaIndicatorList[1].Areas;
		if not areainds or #areainds == 0 then
			return false;
		end
		for _, ai in ipairs(areainds) do
			if PositionInAreaIndicator(mid, ai.AreaIndicator, pos, conditionOutput) then
				return true;
			end
		end
		return false;
	elseif at == 'Difference' then
		local aiFrom = areaIndicator.AreaIndicatorFrom;
		local aiDiff = areaIndicator.AreaIndicatorDiff;
		return PositionInAreaIndicator(mid, aiFrom, pos, conditionOutput) and not PositionInAreaIndicator(mid, aiDiff, pos, conditionOutput);
	elseif at == 'ConditionOutput' then
		return PositionInRange(conditionOutput[areaIndicator.Key], pos);
	else
		return false;
	end
end

function GetPositionListInArea(range_from, range_to)
	local ret = {};
	for x = range_from.x, range_to.x do
		for y = range_from.y, range_to.y do
			table.insert(ret, { x = x, y = y, z = 0 });
		end
	end
	return ret;
end

function GetPositionListInRangedArea(posFrom, range)
	local ret = {};
	for x = posFrom.x - range, posFrom.x + range do
		for y = posFrom.y - range, posFrom.y + range do
			local p = { x = x, y = y, z = 0 };
			if GetDistance2D(posFrom, p) <= range then
				table.insert(ret, p);
			end
		end
	end
	return ret;
end

function GetPositionListFromAreaIndicator(mid, areaIndicator, conditionOutput)
	local areaIndicator = SafeIndex(areaIndicator, 1);
	local at = SafeIndex(areaIndicator, 'Type');
	if at == nil then
		return {};
	elseif at == 'Area' then
		return table.map(GetPositionListInArea(areaIndicator.Area[1].From[1], areaIndicator.Area[1].To[1])
			, function (p) return GetValidPosition(mid, p, false); end);
	elseif at == 'Range' then
		local p = GetPositionFromPositionIndicator(mid, areaIndicator.PositionIndicator, conditionOutput, true);
		return table.map(GetPositionListInRangedArea(p, areaIndicator.Range)
			, function (p) return GetValidPosition(mid, p, false); end);
	elseif at == 'PositionList' then
		return table.map(areaIndicator.PositionList[1].PosElem, function(pi)
			return GetPositionFromPositionIndicator(mid, pi.PositionIndicator, conditionOutput, true);
		end);
	elseif at == 'PositionHolder' then
		local positionHolder = areaIndicator.PositionHolder;
		return Linq.new(GetPositionHolders(mid))
			:where(function(ph) return ph.Group == areaIndicator.PosHolderGroup end)
			:select(function(ph) return ph.Position end)
			:toList();
	elseif at == 'Union' then
		local areainds = areaIndicator.AreaIndicatorList[1].Areas;
		if not areainds or #areainds == 0 then
			return {};
		end
		return table.flatten(table.map(areainds, function(ai)
			return GetPositionListFromAreaIndicator(mid, ai.AreaIndicator, conditionOutput);
		end));
	elseif at == 'Difference' then
		local aiFrom = areaIndicator.AreaIndicatorFrom;
		local aiDiff = areaIndicator.AreaIndicatorDiff;
		local fromList = GetPositionListFromAreaIndicator(mid, aiFrom, conditionOutput);
		local diffList = GetPositionListFromAreaIndicator(mid, aiDiff, conditionOutput);
		return table.filter(fromList, function(p)
			for _, dp in ipairs(diffList) do
				if IsSamePosition(p, dp) then
					return false;
				end
			end
			return true;
		end);
	elseif at == 'ConditionOutput' then
		return conditionOutput[areaIndicator.Key];
	else
		return {};
	end
end

function Position(x, y, z)
	return {x = x, y = y, z = z};
end
function InvalidPosition()
	return { x = -1, y = -1, z = -1 };
end

function IsInvalidPosition(pos)
	if pos ~= nil and pos.x ~= nil and pos.y ~= nil and pos.z ~= nil then
		return IsSamePosition(pos, InvalidPosition());
	else
		return true;
	end
end

function SafeIndex(cls, ...)
	local ret = cls;
	if cls == nil then
		return nil;
	end
	if type(cls) ~= 'table' and type(cls) ~= 'userdata' then
		LogAndPrint('테이블이 아닌 녀석을 Indexing하려함.. 에러의심..', cls);
		LogAndPrint(debug.traceback());
		return nil;
	end
	for i, v in ipairs(arg) do
		if v == nil then
			return nil;
		end
		if ret and type(ret) ~= 'table' and type(ret) ~= 'userdata' then
			LogAndPrint('SafeIndex', cls, arg, type(ret));
			Traceback();
		end
		ret = ret[v];
		if ret == nil then
			return nil;
		end
	end
	return ret;
end
function SafeNewIndex(t, ...)
	if arg.n < 2 then
		-- 추가 인자가 최소 두개 들어와야..
		return;
	end
	local setValue = table.remove(arg);
	local lastKey = table.remove(arg);
	for i, key in ipairs(arg) do
		if t == nil then
			return;
		end
		t = t[key];
	end
	if t == nil then
		return;
	end
	t[lastKey] = setValue;
end
function ForceNewIndex(t, ...)
	if arg.n < 2 or t == nil then	-- t가 nil이면 답이 없습니다.
		-- 추가 인자가 최소 두개 들어와야..
		return;
	end
	local setValue = table.remove(arg);
	local lastKey = table.remove(arg);
	for i, key in ipairs(arg) do
		if t[key] == nil then
			t[key] = {};
		end
		t = t[key];
	end
	if t == nil then
		return;
	end
	t[lastKey] = setValue;
end
function ForceNewInsert(t, ...)
	if arg.n < 2 or t == nil then	-- t가 nil이면 답이 없습니다.
		-- 추가 인자가 최소 두개 들어와야..
		return;
	end
	local setValue = table.remove(arg);
	local lastKey = table.remove(arg);
	for i, key in ipairs(arg) do
		if t[key] == nil then
			t[key] = {};
		end
		t = t[key];
	end
	if t == nil or type(t) ~= 'table' then
		LogAndPrint('ForceNewInsert', 'Error', 'target invalid', t, lastKey, setValue);
		return;
	end
	if t[lastKey] == nil then
		t[lastKey] = {setValue};
	else
		table.insert(t[lastKey], setValue);
	end
end
function SafeInsert(mother, listKey, insertElem)
	if mother[listKey] == nil then
		mother[listKey] = {insertElem};
	else
		table.insert(mother[listKey], insertElem);
	end
end

function string.split(inputstr, sep, allowEmpty)
	if sep == nil then
		sep = "%s";
	end
	if not allowEmpty then
		sep = sep .. '+';
	end
	local t={};
	local s, e;
	repeat
		s, e = string.find(inputstr, sep, 1);
		if s then
			if s == 1 and allowEmpty then
				table.insert(t, '');
			elseif s ~= startIndex then
				table.insert(t, string.sub(inputstr, 1, s-1));
			end
			inputstr = string.sub(inputstr, e+1, -1);
		end
	until not s;
	if inputstr ~= '' then
		table.insert(t, inputstr);
	end
	return t;
end
function StringToBool(s, default)
	if s == 'true' or s == true then
		return true
	elseif s == 'false' or s == false then
		return false
	elseif default ~= nil then
		return default;
	else
		return nil;
	end
end
function ReturnRecColor(color)
	return string.format("tl:%s tr:%s bl:%s br:%s", color, color, color, color);
end
function munpack(...)
	local retT = {};
	for i, t in ipairs(arg) do
		for i, v in ipairs(t) do
			table.insert(retT, v);
		end
	end
	return unpack(retT);
end
function clamp(val, minVal, maxVal)
	if val < minVal then
		return minVal;
	elseif val > maxVal then
		return maxVal;
	else
		return val;
	end
end
function CompareValue(a,b)
	return b.Value < a.Value;
end
function table.map(t, mapFunc)
	local ret = {};
	for k, v in pairs(t) do
		ret[k] = mapFunc(v);
   end
   return ret;
end
function table.filter(t, filterFunc)
	local ret = {};
	for k, v in ipairs(t) do
		if filterFunc(v) then
			table.insert(ret, v);
		end
	end
	return ret;
end
function table.split(t, filterFunc)
	local ret = {};
	local ret2 = {};
	for k, v in ipairs(t) do
		if filterFunc(v) then
			table.insert(ret, v);
		else
			table.insert(ret2, v);
		end
	end
	return ret, ret2;
end
function table.tolist(t, resolveFunc)
	resolveFunc = resolveFunc or function(k, v) return {k, v}; end
	local ret = {};
	for k, v in pairs(t) do
		table.insert(ret, resolveFunc(k, v));
	end
	return ret;
end
function table.tomap(t, mapperFunc)
	mapperFunc = mapperFunc or function(v) return v, v; end
	local ret = {};
	for i, v in ipairs(t) do
		local mk, mv = mapperFunc(v);
		ret[mk] = mv;
	end
	return ret;
end
function table.find(t, _v, comparer)
	local comparer = comparer or function(a, b) return a == b end;
	
	for i, v in ipairs(t) do
		if comparer(v, _v) then
			return i;
		end
	end
	return nil;
end
function table.findif(t, ifFunc)
	for k, v in ipairs(t) do
		if ifFunc(v) then
			return true;
		end
	end
	return false;
end
function table.print(t, printLine, depth)
	printLine = printLine or LogAndPrint;
	local depth = depth or 0;
	local depthString = '';
	for i = 1, depth do
		depthString = depthString .. '  ';
	end
	for k, v in pairs(t) do
		if type(v) == 'table' then
			printLine(depthString .. tostring(k) .. ' = {');
			table.print(v, printLine, depth + 1);
			printLine(depthString .. '}');
		else
			printLine(depthString .. tostring(k) .. ': ' .. tostring(v));
		end
	end
end
function table.randompick(t)
	if #t == 0 then
		return nil;
	end
	return t[math.random(#t)];
end
function DistributePoints(m)
	local m = 
	{
	   { key = a, level = 0, max = 3 },
	   { key = b, level = 0, max = 3 },
	   { key = c, level = 0, max = 3 },
	   { key = d, level = 0, max = 3 },
	   { key = e, level = 0, max = 3 },
	   { key = f, level = 0, max = 3 },
	}

	local points = 100
	while points > 0 do
	   local index = math.random(1, #m)
	   if m[index].level == 0 then
		   local point = math.random(1, m[index].max)
		   m[index].level = point
		   points = point
	   end
	end
end

-- 안에 들어갈 인자값을 비교가능한 값으로 변환해 주는 함수를 fcompval에 넣으면됨
local default_fcompval = function( value ) return value end
local fcompf = function( a,b ) return a < b end
local fcompr = function( a,b ) return a > b end
function table.binsearch( t,value,fcompval,reversed )
	-- Initialise functions
	local fcompval = fcompval or default_fcompval
	local fcomp = reversed and fcompr or fcompf
	--	Initialise numbers
	local iStart,iEnd,iMid = 1,#t,0
	--	Initialise value --
	value = fcompval(value, -1);
	-- Binary Search
	while iStart <= iEnd do
		-- calculate middle
		iMid = math.floor( (iStart+iEnd)/2 )
		-- get compare value
		local value2 = fcompval( t[iMid], iMid )
		-- get all values that match
		if value == value2 then
			local tfound,num = { iMid,iMid },iMid - 1
			while iStart <= num and value == fcompval( t[num], num ) do
				tfound[1],num = num,num - 1
			end
			num = iMid + 1
			while num <= iEnd and value == fcompval( t[num], num ) do
				tfound[2],num = num,num + 1
			end
			return tfound
		-- keep searching
		elseif fcomp( value,value2 ) then
			iEnd = iMid - 1
		else
			iStart = iMid + 1
		end
	end
	return nil
end

function table.bininsert(t, value, fcompval, descending)
	-- Initialise compare function
	local fcompval = fcompval or default_fcompval
	local fcomp = descending and fcompr or fcompf
	-- Initialise comp value
	local cmpvalue = fcompval(value);
	-- Initialise numbers
	local iStart,iEnd,iMid,iState = 1,#t,1,0
	-- Get insert position
	while iStart <= iEnd do
		-- calculate middle
		iMid = math.floor( (iStart+iEnd)/2 )
		-- compare
		if fcomp( cmpvalue,fcompval(t[iMid]) ) then
			iEnd,iState = iMid - 1,0
		else
			iStart,iState = iMid + 1,1
		end
	end
	table.insert( t,(iMid+iState),value )
	return (iMid+iState)
end

function table.scoresort(t, scoreFunc, descending)
	local ret = {};
	while #t > 0 do
		table.bininsert(ret, table.remove(t), scoreFunc, descending);
	end
	table.append(t, ret);
	return t;
end

function table.append(dest, source)
	for _, value in ipairs(source) do
		table.insert(dest, value);
	end
	return dest;
end

function table.union(ta, tb)	-- don't care previous order
	local sa = Set.new(ta);
	local sb = Set.new(tb);
	local su = sa:union(sb);
	return su:getKeys();
end

function table.flatten(t, sublistFunc)
	sublistFunc = sublistFunc or function(subt) return subt end;
	local flatList = {};
	for _, subt in ipairs(t) do
		for _, v in ipairs(sublistFunc(subt)) do
			table.insert(flatList, v);
		end
	end
	return flatList;
end

function table.distinct(t)
	local s = Set.new(t);
	--LogAndPrint('table.distinct', s, s:getKeys());
	return s:getKeys();
end

function table.foldr(t, f, base)
	if #t == 0 then
		return base;
	end
	t = table.shallowcopy(t);
	local head = table.remove(t, 1);
	return f(head, table.foldr(t, f, base));
end

function table.foldl(t, f, base)
	if #t == 0 then
		return base;
	end
	t = table.shallowcopy(t);
	local tail = table.remove(t);
	return f(table.foldl(t, f, base), tail);
end

function table.clear(t)
	for k, _ in pairs(t) do
		t[k] = nil;
	end
	return t;
end

-- https://stackoverflow.com/a/4991602
function io.exists(name)
	local f = io.open(name, "r");
	if f ~= nil then
		io.close(f);
		return true;
	else
		return false;
	end
end

Linq = {};
function Linq.new(t)
	t = t or {}
	local ret = {};
	local tt = type(t);
	if tt == 'table' then
		if #t == 0 then
			ret.Data = {};
			for k, v in pairs(t) do
				table.insert(ret.Data, {k, v});
			end
		else
			ret.Data = table.shallowcopy(t);
		end
	elseif tt == 'function' then
		ret.Data = {};
		for d in t do
			table.insert(ret.Data, d);
		end
	else
		ret.Data = {};
		if GetWithoutError(t, 1) == nil then
			for k, v in pairs(t) do
				table.insert(ret.Data, {k, v});
			end
		else
			for i, v in ipairs(t) do
				table.insert(ret.Data, v);
			end
		end
	end
	setmetatable(ret, {__index = Linq});
	return ret;
end
function Linq.select(self, selectFunc)
	for i, d in ipairs(self.Data) do 
		self.Data[i] = selectFunc(d, i);
	end
	return self;
end
function Linq.where(self, whereFunc)
	self.Data = table.filter(self.Data, whereFunc);
	return self;
end
function Linq.toList(self)
	return table.tolist(self.Data, function(k,v) return v; end);
end
function Linq.toMap(self, mapperFunc)
	mapperFunc = mapperFunc or function(v) return v[1], v[2] end;
	return table.tomap(self.Data, mapperFunc);
end
function Linq.toSet(self)
	return Set.new(self:toList());
end
function Linq.orderBy(self, scoreFunc, descending)
	table.scoresort(self.Data, scoreFunc, descending);
	return self;
end
function Linq.orderByAscending(self, scoreFunc)
	return self:orderBy(scoreFunc);
end
function Linq.orderByDescending(self, scoreFunc)
	return self:orderBy(scoreFunc, true);
end
function Linq.first(self)
	return self.Data[1];
end
function Linq.foreach(self, foreachFunc)
	for i, v in ipairs(self.Data) do
		foreachFunc(v, i);
	end
	return self;
end
function Linq.foldr(self, foldFunc, base)
	return table.foldr(self.Data, foldFunc, base);
end
function Linq.foldl(self, foldFunc, base)
	return table.foldl(self.Data, foldFunc, base);
end
function Linq.sum(self, resolveFunc)
	return self:foldr(function(d, c) return resolveFunc(d) + c; end, 0);
end
-- https://stackoverflow.com/questions/958949/difference-between-select-and-selectmany 참고
function Linq.selectMany(self, selectManyFunc, resultResolver)
	resultResolver = resultResolver or function (p, c) return c; end;
	self.Data = table.flatten(table.map(self.Data, function (d) return table.map(selectManyFunc(d), function(sublist) return resultResolver(d, sublist); end) end));
	return self;
end
function Linq.distinct(self)
	self.Data = Set.new(self.Data):getKeys();
	return self;
end
function Linq.min(self, scoreFunc)
	return table.min(self.Data, scoreFunc);
end
function Linq.max(self, scoreFunc)
	return table.max(self.Data, scoreFunc);
end
function Linq.firstIf(self, filter)
	for _, data in ipairs(self.Data) do
		if filter(data) then
			return data;
		end
	end
	return nil;
end
function Linq.concat(self, tok)
	-- table.concat은 원본 테이블을 뭉개버리는거 같음..
	return table.concat(table.deepcopy(self.Data), tok);
end

Set = {};
function Set.new(t)
	t = t or {};
	local newSet = {};
	for i, v in ipairs(t) do
		newSet[v] = true;
	end
	setmetatable(newSet, {__index = Set});
	return newSet;
end
function Set:insert(arg)
	self[arg] = true;
end
function Set:remove(arg)
	self[arg] = nil;
end
function Set:union(s)
	local tfrom, tto;
	if #self > #s then
		tto = self;
		tfrom = s;
	else
		tto = s;
		tfrom = self;
	end
	for k, v in pairs(tfrom) do
		tto[k] = v;
	end
	return tto;
end
function Set:getKeys()
	local keys = {};
	for k, _ in pairs(self) do
		table.insert(keys, k);
	end
	return keys;
end

-- 랜덤 선택기
RandomPicker = {}
function RandomPicker.new(reload)
	local l = {pSum = 0, probabilities = {}, choices = {}, reload = (reload == nil and true or reload)}
	setmetatable(l, {__index = RandomPicker});
	return l;
end
function RandomPicker.export(self)
	return {pSum = self.pSum, probabilities = self.probabilities, choices = self.choices, reload = self.reload};
end
function RandomPicker.restore(data)
	local l = table.deepcopy(data);
	setmetatable(l, {__index = RandomPicker});
	return l;
end

function RandomPicker.addChoice(self, p, choice)
	if p == nil then
		LogAndPrint('p is nil');
		LogAndPrint(debug.traceback());
		return;
	end
	if p % 1 ~= 0 then
		LogAndPrint('RandomPicker.addChoice', 'probability value need to be integer value', p);
		p = math.floor(p);
		if p <= 0 then
			return;
		end
	end
	table.insert(self.probabilities, p + self.pSum);
	table.insert(self.choices, choice);
	self.pSum = self.pSum + p;
end

function RandomPicker.clear(self)
	self.pSum = 0;
	self.choices = {};
	self.probabilities = {};
end

function RandomPicker.pick(self)
	if #(self.probabilities) == 0 then
		return nil, 0;
	end
	if self.pSum - 1 < 0 or self.pSum > 2100000000 then
		LogAndPrint('RandomPicker.pick', 'Invalid Interval', self.pSum);
		Traceback();
		return nil, 0;
	end
	local ok, system_s_choice = pcall(math.random, 0, self.pSum-1);
	if not ok then
		LogAndPrint('RandomPicker.pick', 'Invalid call', 0, self.pSum-1);
		Traceback();
		return nil, 0;
	end
	-- 이진 탐색을 할거임
	local s, e, m = 1, #self.probabilities, 0;
	local flag = 0;
	while s <= e do
		m = math.floor((s + e) / 2);
		if system_s_choice < self.probabilities[m] then
			e, flag = m - 1, 0;
		else
			s, flag = m + 1, 1;
		end
	end
	local idx = m + flag;
	local ret = self.choices[idx];
	if not self.reload then
		local myP = idx == 1 and self.probabilities[idx] or self.probabilities[idx] - self.probabilities[idx - 1];
		table.remove(self.probabilities, idx);
		for i = idx, #(self.probabilities) do
			self.probabilities[i] = self.probabilities[i] - myP;
		end
		table.remove(self.choices, idx);
		self.pSum = self.pSum - myP;
	end
	return ret, idx;
end

function RandomPicker.pickMulti(self, n)
	local picks = {};
	for i = 1, n do
		local p = self:pick();
		if p == nil then
			break;
		end
		table.insert(picks, p);
	end
	return picks;
end

function RandomPicker.size(self)
	return #self.choices;
end

-- 테스트 코드 혹은 사용 예시
function Test_RandomPicker()
	local picker = RandomPicker.new();
	picker:addChoice(3, 1);
	picker:addChoice(1, 2);
	local statistic = {};
	setmetatable(statistic, {__index = function(t,v) return 0 end});
	for i = 1, 1000000 do
		local pick = picker:pick();
		statistic[pick] = statistic[pick] + 1;
	end
	for k, v in pairs(statistic) do
		print(k, v);
	end
	
	local noReloadPicker = RandomPicker.new(false);
	noReloadPicker:addChoice(3, 1);
	noReloadPicker:addChoice(1, 2);
	noReloadPicker:addChoice(2, 3);
	noReloadPicker:addChoice(1, 4);
	noReloadPicker:addChoice(100, 5);
	noReloadPicker:addChoice(100, 6);
	noReloadPicker:addChoice(100, 7);
	print('Size:', noReloadPicker:size());
	while true do
		local pick = noReloadPicker:pick();
		if pick == nil then
			break;
		end
		print(pick);
	end
end
-- see if the file exists
function file_exists(file)
  local f = io.open(file, "rb")
  if f then f:close() end
  return f ~= nil
end

-- get all lines from a file, returns an empty 
-- list/table if the file does not exist
function lines_from(file)
  if not file_exists(file) then return nil end
  lines = {}
  for line in io.lines(file) do 
    lines[#lines + 1] = line
  end
  return lines
end

function load_function(f)
	if f == nil then return nil end
	
	local dbgInfo = debug.getinfo(f, 'S');
	if string.sub(dbgInfo.source, 1, 1) ~= '@' then
		return nil;
	end
	local path = string.sub(dbgInfo.source, 2);
	local fulllines = lines_from(path);
	if fulllines == nil then
		return nil
	end
	local funclines = {};
	for line = dbgInfo.linedefined, dbgInfo.lastlinedefined do
		table.insert(funclines, fulllines[line]);
	end
	return table.concat(funclines, '\n'), path;
end

function AdjustNumberValue(num, decimalPlaces)
	local mul = math.pow(10, decimalPlaces or 0);
	return math.floor(num * mul) / mul;
end
function AdjustVector3Value(vec, decimalPlaces)
	return { x = AdjustNumberValue(vec.x, decimalPlaces), y = AdjustNumberValue(vec.y, decimalPlaces), z = AdjustNumberValue(vec.z, decimalPlaces) };
end
function tableAppend(t1, t2)
	for _, v in ipairs(t2) do
		table.insert(t1, v);
	end
end

function IsValidString(s)
	return (s ~= nil and type(s) == 'string' and s ~= '');
end

local sysConstCls = nil;
function GetSystemConstant(key)
	if sysConstCls == nil then
		sysConstCls = GetClassList('SystemConstant');
	end
	return sysConstCls[key].value;
end

function math.round(num, decimalPlaces)
	local mul = math.pow(10, decimalPlaces or 0);
	if not num then
		Traceback();
	end
	if num >= 0 then
		return math.floor(num * mul + 0.5) / mul;
	else
		return math.ceil(num * mul - 0.5) / mul;
	end
end

function math.clamp(num, min, max)
	return math.min(math.max(num, min), max);
end

function math.sign(x)
	return (x > 0 and 1 or (x < 0 and -1 or 0));
end

function pairsByKeys (t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0			-- iterator variable
	local iter = function ()	 -- iterator function
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end

function bit(b)
	return 2 ^ (b - 1);
end
 
function hasbit(w, b)
	return w % (b + b) >= b;
end

-- from https://forums.coronalabs.com/topic/42019-split-utf-8-string-word-with-foreign-characters-to-letters/
function UTF8ToCharArray(str)
    local charArray = {};
    local iStart = 0;
	if str == nil then
		LogAndPrint(debug.traceback());
		return {};
	end
    local strLen = str:len();
    
    local checkMultiByte = function(i)
        if (iStart ~= 0) then
            charArray[#charArray + 1] = str:sub(iStart, i - 1);
            iStart = 0;
        end        
    end
    
    for i = 1, strLen do
        local b = str:byte(i);
        local multiStart = hasbit(b, bit(7)) and hasbit(b, bit(8));
        local multiTrail = not hasbit(b, bit(7)) and hasbit(b, bit(8));
 
        if (multiStart) then
            checkMultiByte(i);
            iStart = i;
            
        elseif (not multiTrail) then
            checkMultiByte(i);
            charArray[#charArray + 1] = str:sub(i, i);
        end
    end
    
    -- process if last character is multi-byte
    checkMultiByte(strLen + 1);
 
    return charArray;
end

Remapper = {};
function Remapper.new(host, ruleSet)
	local newRemapper = {Host = host, RuleSet = ruleSet};
	setmetatable(newRemapper, Remapper);
	return newRemapper;
end
function Remapper.__index(self, keyChain)
	local k = keyChain;
	local remapRule = self.RuleSet[keyChain];
	if remapRule then
		keyChain = remapRule;
	end
	local chain = string.split(keyChain, '/');
	--LogAndPrint('Remapper.__index', k, keyChain, chain, SafeIndex(self.Host, unpack(chain)), debug.traceback());
	return SafeIndex(self.Host, unpack(chain));
end
function Remapper.__newindex(self, keyChain, value)
	local k = keyChain;
	local remapRule = self.RuleSet[keyChain];
	if remapRule then
		keyChain = remapRule;
	end
	local chain = string.split(keyChain, '/');
	--LogAndPrint('Remapper.__newindex', k, keyChain, chain, SafeIndex(self.Host, unpack(chain)), debug.traceback());
	table.insert(chain, value);
	SafeNewIndex(self.Host, unpack(chain));
end
function RemapperTest()
	local a = {A = {B= 5}};
	local rm = Remapper.new(a, {B = 'A/B'});
	rm.B = 7;
	print(rm.B, a.A.B);
end

CachedValue = {};
function CachedValue.new(calcFunc)
	local ret = {Valid = false, CalcFunc = calcFunc};
	setmetatable(ret, {__index = CachedValue, __tostring = CachedValue.tostring});
	return ret;
end
function CachedValue.get(self)
	if not self.Valid then
		self.Value = self.CalcFunc();
	end
	return self.Value;
end
function CachedValue.invalidate(self)
	self.Valid = false;
end
function CachedValue.tostring(self)
	return tostring(self:get());
end

WrapperObject = {};
function WrapperObject.new(host, changed, tostring)
	local ret = {_Host = host, _Changed = changed or {}, _Cached = {}};
	setmetatable(ret, {__index = WrapperObject.get, __newindex = WrapperObject.set, __tostring = tostring or WrapperObject.tostring});
	ret.addCachedValue = WrapperObject.addCachedValue;
	ret.invalidate = WrapperObject.invalidate;
	ret.getHost = WrapperObject.getHost;
	return ret;
end
function WrapperObject.get(self, key)
	local changed = self._Changed[key];
	if changed ~= nil then
		return changed;
	end
	local cached = self._Cached[key];
	if cached ~= nil then
		return cached:get();
	end
	return self._Host[key];
end
function WrapperObject.set(self, key, value)
	self._Changed[key] = value;
end
function WrapperObject.addCachedValue(self, key, calcFunc)
	self._Cached[key] = CachedValue.new(calcFunc);
end
function WrapperObject.invalidate(self)
	for _, cached in pairs(self._Cached) do
		cached:invalidate();
	end
end
function WrapperObject.getHost(self)
	return self._Host;
end
function WrapperObject.tostring(self)
	return string.format('[Wrapper:(%s,%s)]', tostring(self._Host), PackTableToStringReadable(self._Changed));
end

PerfChecker = {};
function PerfChecker.new()
	local ret = {Start = os.clock(), Last = os.clock(), PerfData = {}};
	setmetatable(ret, {__index = PerfChecker});
	return ret;
end
function PerfChecker.Check(self, title)
	local pData = self.PerfData[title] or {0, 0};
	local curTime = os.clock();
	local thisTime = curTime - self.Last;
	pData[1] = pData[1] + thisTime;
	pData[2] = pData[2] + 1;
	self.PerfData[title] = pData;
	self.Last = os.clock();
end
function PerfChecker.Report(self)
	local lastTime = os.clock();
	local fullTime = lastTime - self.Start;
	LogAndPrint('PerfChecker:Report', 'total elapsed', fullTime, '---------------------');
	local sortedPerfData = Linq.new(self.PerfData)
		:orderByDescending(function(pData) return pData[2][1] end)
		:toList();
	for _, pData in ipairs(sortedPerfData) do
		local title = pData[1];
		local titleTotal = pData[2][1];
		local count = pData[2][2];
		LogAndPrint('PerfChecker:Report', string.format('%s: %f(%d)[%.2f%%]', title, titleTotal, count, titleTotal / fullTime * 100));
	end
	LogAndPrint('PerfChecker:Report', 'end', '-----------------------');
end

-- 단순 랜덤 선택기
SimpleRandomPicker = {}
function SimpleRandomPicker.new(reload)
	local l = {invalidated = false, choices = {}, reload = (reload == nil and true or reload)}
	setmetatable(l, {__index = SimpleRandomPicker});
	return l;
end
function SimpleRandomPicker.addChoice(self, choice)
	table.insert(self.choices, choice);
	self.invalidated = true;
end
function SimpleRandomPicker.clear(self)
	self.choices = {};
	self.invalidated = false;
end
function SimpleRandomPicker.pick(self)
	if #self.choices == 0 then
		return nil, 0;
	end
	if self.invalidated then
		self.choices = table.shuffle(self.choices);
		self.invalidated = false;
	end
	local idx = #self.choices;
	local ret = self.choices[idx];
	if not self.reload then
		table.remove(self.choices, idx);
	else
		self.invalidated = true;
	end
	return ret, idx;
end
function SimpleRandomPicker.pickMulti(self, n)
	local picks = {};
	for i = 1, n do
		local p = self:pick();
		if p == nil then
			break;
		end
		table.insert(picks, p);
	end
	return picks;
end
function SimpleRandomPicker.size(self)
	return #self.choices;
end


-- MinMaxer
MinMaxer = {}
MinMaxer.default_valuator = function (v) return v; end;
function MinMaxer.new(valuator)
	if valuator == nil then
		valuator = MinMaxer.default_valuator;
	end
	local ret = {Min = nil, MinVal = nil, Max = nil, MaxVal = nil, Valuator = valuator};
	setmetatable(ret, {__index = MinMaxer});
	return ret;
end
function MinMaxer.Update(self, value)
	if self.Min == nil then
		self.Min = value;
		self.MinVal = self.Valuator(value);
		self.Max = value;
		self.MaxVal = self.MinVal;
		return;
	end
	
	local newVal = self.Valuator(value);
	if newVal < self.MinVal then
		self.Min = value;
		self.MinVal = newVal;
	end
	if newVal > self.MaxVal then
		self.Max = value;
		self.MaxVal = newVal;
	end
end
function MinMaxer.UpdateMulti(self, valueList)
	table.foreach(valueList, function(i, v) self:Update(v) end);
end
function MinMaxer.GetMin(self)
	return self.Min;
end
function MinMaxer.GetMax(self)
	return self.Max;
end
function MinMaxer.GetMinMax(self)
	return self:GetMin(), self:GetMax();
end
function MinMaxer.GetMinValue(self)
	return self.MinVal;
end
function MinMaxer.GetMaxValue(self)
	return self.MaxVal;
end
function MinMaxer.test()
	local distanceFrom100 = MinMaxer.new(function (v) return math.abs(100-v) end);
	for _, testCase in ipairs({34, 52, 67, 23, 164, 273}) do
		distanceFrom100:Update(testCase);
	end
	print(string.format('min distance from 100 is %d (%d)', distanceFrom100:GetMin(), distanceFrom100:GetMinValue()));
	print(string.format('max distance from 100 is %d (%d)', distanceFrom100:GetMax(), distanceFrom100:GetMaxValue()));
end

function xrange(s, e)
	if e == nil then
		e = s;
		s = 1;
	end
	local i = s - 1;
	return function ()
		i = i + 1;
		if i <= e then
			return i, i;
		end
	end;
end

function reordered_ipairs(a, scoreFunc)
	local reorderedData = Linq.new(a)
		:select(function(d, i) return {i, d} end)
		:orderByAscending(function(dataWithIndex) return scoreFunc(dataWithIndex[2], dataWithIndex[1]) end)
		:toList();
	
	local i = 0;
	return function()
		i = i + 1;
		if i > #reorderedData then
			return nil;
		end
		local ret = reorderedData[i];
		return ret[1], ret[2], i;		-- originalIndex, data, thisIndex
	end
end