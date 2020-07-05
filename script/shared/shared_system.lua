-- 이 파일은 리로드 되지 않도록 합니다.
if not system_loaded then

rawnext = next
function next(t, k)
	if type(t) == 'table' then
		return rawnext(t, k)
	else
		return MyNext(t, k)
	end
end

rawpairs = pairs
function pairs(t)
	if type(t) == 'table' then
		return rawpairs(t)
	else
		return next, t, nil
	end
end

function iter(a, i)
	i = i + 1
	local v = GetWithoutError(a, i);
	if v then
		return i, v
	end
end

rawipairs = ipairs
function ipairs(a)
	if type(a) == 'table' then
		return rawipairs(a)
	else
		return iter, a, 0
	end
end

function _EvaluateProperty(self, evalStr)
	local env = {self = self};
	env.__index = function (t, key)
		local ret = GetWithoutError(self, key);
		if ret == nil then
			return _G[key];
		else
			return ret;
		end
	end;
	setmetatable(env, env);
	local evalF = loadstring('return '..evalStr);
	setfenv(evalF, env);
	return evalF();
end

function Sleeper(msec)
	Sleep(msec);
end

function to_lua_function(f)
	return function(...) return f(...) end
end

system_loaded = true;
else
LogAndPrint("system already loaded");
end