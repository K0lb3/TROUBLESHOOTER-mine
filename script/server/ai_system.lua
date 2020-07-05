--- Game Logic Functions ---
function GetAbilityDamage(self, ability, target, usingPos, staticCache, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	perfChecker:Dive();
	--local start = os.clock();
	if staticCache == nil then
		local dam, info;
		dam, info, staticCache = GetDamageCalculator(self, target, ability, nil, usingPos, 1, 'Static', nil, nil, perfChecker);
	end
	local dam, info, result = GetDamageCalculator(self, target, ability, nil, usingPos, 1, 'PositionRelative', nil, nil, perfChecker);
	result:Merge(staticCache);
	--LogAndPrint('GetAbilityDamage', 'elapsed', os.clock() - start, dam, result:ComposeFormula());
	perfChecker:Rise();
	return result:ComposeFormula(), staticCache;
end
function GetAIEstimatedAbilityAccuracy(self, ability, target, usingPos, staticCache, perfChecker)
	if perfChecker == nil then
		perfChecker = MockPerfChecker;
	end
	perfChecker:Dive();
	local weather = 'Clear';
	local missionTime = 'Day';
	local temperature = 'Normal';
	local highLimit = 1;
	--local start = os.clock();
	if IsMissionServer() then
		local mission = GetMission(self);
		weather = mission.Weather.name;
		missionTime = mission.MissionTime.name;
		temperature = mission.Temperature.name;
		highLimit = mission.Difficulty.EnemyMaxAccuracy / 100;
	end
	if staticCache == nil then
		local dummy, dummy2;
		dummy, dummy2, staticCache = ability.GetHitRateCalculator(self, target, ability, usingPos, weather, missionTime, temperature, nil, 'Static', nil, perfChecker);
	end
	local dummy, dummy2, result = ability.GetHitRateCalculator(self, target, ability, usingPos, weather, missionTime, temperature, nil, 'PositionRelative', nil, perfChecker);
	result = (staticCache + result) / 100;
	if result == nil then
		result = 0.8;
	end
	perfChecker:Rise();
	--LogAndPrint('GetAIEstimatedAbilityAccuracy', 'elapsed', os.clock() - start);
	return math.min(result, highLimit), staticCache;
end
function GetAbilityEfficiency_Self(self, ability)
	-- Customizing
	return 10;
end
function GetAbilityEfficiency_Support(self, ability, target)
	-- Customizing
	if ability.name == 'Conceal' then
		return 10;
	elseif GetBuff(target, ability.ApplyTargetBuff.name) == nil then
		return 10;
	end
end
function IsOverwatchingAbility(ability)
	return ability.name == 'StartOverwatch';
end
function IsEnemy(self, unit, citizenOnly)
	local loseIff = ObjectLoseIFF(self);
	if ((loseIff and self ~= unit) or GetRelation(self, unit) == 'Enemy') then
		if citizenOnly then
			return GetInstantProperty(unit, 'CitizenType') ~= nil;
		else
			return true;
		end
	end
	return false;
end
function GetTargetScoreRatio(self, target)
	local scoreRatio = 1;
	if self.Race.name == 'Machine' and GetBuff(target, 'InformationDistortion') then
		scoreRatio = scoreRatio - 0.5;
	end
	if HasBuff(target, 'Giant') then
		scoreRatio = scoreRatio + 1;
	end
	if HasBuff(target, 'Giant_SideEffect') then
		scoreRatio = scoreRatio - 1;
	end	
	return math.max(scoreRatio, 0.1);	-- 최소 0.1 보정
end
--------------------------------------------------------------
-- 공격 전략 함수.
-----------------------------------------------------------------
function AIMovePositionFinderHelper(mid, sessionId)
	while true do
		if not ExecuteAIMovePositionSession(mid, sessionId) then
			break;
		end
		Sleep(1);
	end
end