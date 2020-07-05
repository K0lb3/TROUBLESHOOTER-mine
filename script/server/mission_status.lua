StatusOperator = {
	Sum = 1,
	Max = 2,
	And = 3,
	Or = 4
};

function GetMissionStatus(mission, statusType, operation, customBase)
	operation = operation or StatusOperator.Sum;
	
	local operationTable = {
		[StatusOperator.Sum] = {Operator = function (a, b) return a + b; end, BaseValue = 0},
		[StatusOperator.Max] = {Operator = function (a, b) return math.max(a, b); end, BaseValue = 0},
		[StatusOperator.And] = {Operator = function (a, b) return a and b; end, BaseValue = true},
		[StatusOperator.Or] = {Operator = function(a, b) return a or b; end, BaseValue = false}
	};
	
	local opInfo = operationTable[operation];
	if opInfo == nil then
		return nil;
	end
	
	local v = nil;
	if customBase ~= nil then
		v = customBase;
	else
		v = opInfo.BaseValue;
	end
	for i, company in ipairs(GetAllCompanyInMission(mission)) do
		local stat = company.MissionStatus[statusType];
		v = opInfo.Operator(v, stat);
	end
	return v;
end

function GetMissionAICorrectionClass(self, key)
	return GetClassList('MissionAIDifficultyCorrection')[self.DifficultyGrade];
end