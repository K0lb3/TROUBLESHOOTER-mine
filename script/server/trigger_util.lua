function IsUnitInSightToTeam(unit, team)
	local mid = GetMissionID(unit)
	local count = GetTeamCount(mid, team);
	if count <= 0 then
		return false;
	end
	
	local tu = GetTeamUnitByIndex(mid, team, 1);
	return IsInSight(tu, unit, false);
end

function CompareOperation(operation, thisValue, compareValue)
	local operationTable = {	Equal = function(a, b) return a == b end,
							NotEqual = function(a, b) return a ~= b end,
							LessThan = function(a, b) return a < b end,
							GreaterThan = function(a, b) return a > b end
							};
	
	local opFunc = operationTable[operation];
	if opFunc ~= nil then
		return opFunc(thisValue, compareValue);
	else
		LogAndPrint('CompareOperation', 'Not defined operation', operation);
		Traceback();
		return nil;
    end							
end

function EvaluateExpression(expression, env)
	setmetatable(env, _G);
	
	local filterFunc = loadstring('return ' .. expression);
	setfenv(filterFunc, env);
	return filterFunc();
end