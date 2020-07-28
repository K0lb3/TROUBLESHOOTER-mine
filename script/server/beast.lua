function ApplyTamingActions(actions, user, target)
	local monType = FindBaseMonsterTypeWithCache(target);
	local beastTypeCls = GetClassList('BeastType')[monType];
	if not monType or not beastTypeCls then
		return;
	end
	local targetPos = GetPosition(target);
	local setPos = Result_SetPosition(target, InvalidPosition());
	setPos.sequential = true;
	setPos.forward = true;
	table.insert(actions, setPos);
	table.insert(actions, Result_FireWorldEvent('UnitDead', {Unit = target, Virtual = true, Killer = user}));
	table.insert(actions, Result_DestroyObject(target, false, true));
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		AddExp_TroubleMaker(GetMissionDatabaseCommiter(GetMission(user)), target, user, 'Normal', false, false, ds);
	end, nil, true));
	local beforeKey = GetObjKey(target);
	
	-- 소환된 야수인가
	local summonBefore = GetInstantProperty(target, 'SummonBefore');
	
	local mission = GetMission(target);
	local newObjKey = GenerateUnnamedObjKey(mission);
	local evolutionStage = beastTypeCls.EvolutionStage;
	local initialMasteries = PickBeastUniqueMasteryCandidate(target, beastTypeCls, true, evolutionStage - 1);
	local tamerKey = GetObjKey(user);
	
	local unitInitializeFunc = function(unit, arg)
		-- 몬스터로 생성했지만 Pc 처럼 초기화하기 위해 야매로...
		SetAutoType(unit, 'Grade', 'Normal');
		UNIT_INITIALIZER(unit, unit.Team);
		SetInstantProperty(unit, 'MonsterType', nil);
		SetControllable(unit, true);
		unit.Base_SceneScale = beastTypeCls.MissionScale;
		unit.ExpType = 'Beast';
		unit.JobExpType = 'JobBeast';
		unit.Tamer = tamerKey;
		-- 회사 특성
		local company = GetCompany(user);
		if company and company.CompanyMastery ~= 'None' then
			local curCompnayMastery = company.CompanyMasteries[company.CompanyMastery];
			if curCompnayMastery.Opened then
				UpdateTemporaryMastery(unit, company.CompanyMastery, 1);
			end
		end
		-- 몬스터 진화 특성 초기화
		local masteryList = GetClassList('Mastery');
		for masteryName, _ in pairs(beastTypeCls.Monster.Masteries) do
			local masteryCls = masteryList[masteryName];
			if masteryCls.Category.name == 'Beast' then
				UpdateTemporaryMastery(unit, masteryName, 0);
			end
		end
		-- 새로운 진화 특성 설정
		for i, masteryName in ipairs(initialMasteries) do
			UpdateTemporaryMastery(unit, masteryName, i);
		end
	end;
	local monKey = GenerateUnnamedObjKey(mission);
	local createAction = Result_CreateMonster(newObjKey, monType, targetPos, GetTeam(user), unitInitializeFunc, {}, 'DoNothingAI', nil, true);
	ApplyActions(mission, { createAction }, false);
	local target = GetUnit(mission, newObjKey);
	if not target then
		return;
	end
	
	local userKey = GetObjKey(user);
	local targetKey = GetObjKey(target);
	local userPos = GetPosition(user);
	local moveTo = GetMovePosition(target, userPos, 1);

	table.insert(actions, Result_SetPosition(target, GetPosition(target)));
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		ds:ChangeCameraTarget(targetKey, '_SYSTEM_', false, false);
		ds:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/LevelUp', 2);
		ds:Move(targetKey, moveTo, false, false);
		ds:LookAt(targetKey, userKey);
		ds:ChangeCameraTarget(userKey, '_SYSTEM_', false, false);
		ds:ReleasePose(userKey, 'TameEnd');
		ds:LookAt(userKey, targetKey);
		ds:PlayParticle(userKey, '_BOTTOM_', 'Particles/Dandylion/LevelUp', 2);
	end, nil, true));
	table.insert(actions, Result_FireWorldEvent('UnitTamed', {Unit = target, Tamer = user}));
	
	table.insert(actions, Result_UpdateUserMember(target, GetTeam(user), true));
	InsertBuffActions(actions, user, target, 'SummonBeast', 1, true, nil, true);
	table.insert(actions, Result_PropertyUpdated('Act', target.Wait, target, true, true));
	SetInstantProperty(user, 'SummonBeast', { Owner = user, Target = target });
	table.insert(actions, Result_UpdateInstantProperty(user, 'SummonBeastKey', GetObjKey(target)));
	SetInstantProperty(target, 'SummonMaster', GetObjKey(user));
	SetInstantProperty(target, 'SummonBefore', true);
	SetInstantProperty(target, 'Subordinate', true);
	table.insert(actions, Result_UpdateInstantProperty(target, 'DisableRetreat', true));
	table.insert(actions, Result_UpdateInstantProperty(target, 'BeastType', beastTypeCls.name));
	SetInstantProperty(target, 'EvolutionMastery', initialMasteries);
	
	local count = 4;
	local mastery_MonsterMaster = GetMasteryMastered(GetMastery(user), 'MonsterMaster');
	if mastery_MonsterMaster then
		count = count + mastery_MonsterMaster.ApplyAmount;
	end
	local candidateMasteries = PickBeastUniqueMasteryCandidate(target, beastTypeCls, true, count, true);
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		local actions = {};
		local helpInfo = {};
		local company = GetCompany(user);
		if company then
			for _, masteryType in ipairs({'Training', 'Nature', 'Gene', 'ESP'}) do
				local helpKey = 'EvolutionMastery'..masteryType;
				helpInfo[helpKey] = GetWithoutError(company.Progress.Tutorial, helpKey);
			end
		end
		local _, sel, result = ds:Dialog('ScoutBeast', {BeastType = beastTypeCls.name, CandidateMasteries = candidateMasteries, TargetKey = targetKey, HelpInfo = helpInfo});
		if sel > 0 then
			local masteryName = candidateMasteries[sel];
			table.insert(actions, Result_UpdateMastery(target, masteryName, evolutionStage));
			local evolutionMastery = GetInstantProperty(target, 'EvolutionMastery') or {};
			table.insert(evolutionMastery, masteryName);
			SetInstantProperty(target, 'EvolutionMastery', evolutionMastery);
			local company = GetCompany(user);
			if company then
				local mission = GetMission(user);
				local dc = GetMissionDatabaseCommiter(mission);
				local helpInfo = result.HelpInfo or {};
				for key, value in pairs(helpInfo) do
					local prevValue = GetWithoutError(company.Progress.Tutorial, key);
					if prevValue ~= nil and prevValue ~= value then
						dc:UpdateCompanyProperty(company, string.format('Progress/Tutorial/%s', key), value);
						company.Progress.Tutorial[key] = value;
					end
				end
			end
		end
		return unpack(actions);
	end, nil, true));
	
	-- 야수 리스트
	local tamingList = GetInstantProperty(user, 'TamingList') or {};
	table.insert(tamingList, newObjKey);
	table.insert(actions, Result_UpdateInstantProperty(user, 'TamingList', tamingList));
	
	-- 야수 영입
	local company = GetCompany(user);
	if company then
		local tamingListCompany = GetCompanyInstantProperty(company, 'TamingList') or {};
		table.insert(tamingListCompany, newObjKey);
		SetCompanyInstantProperty(company, 'TamingList', tamingListCompany);
		AddCompanyStats(company, 'TamingSuccessCount', 1);
	end
	local summonCount = GetInstantProperty(target, 'SummonCount') or 0;
	table.insert(actions, Result_UpdateInstantProperty(target, 'SummonCount', summonCount + 1));
	-- 위치 갱신은 이동 이벤트 처리단에서 이루어지지만 이벤트 필터 처리는 액션 처리단계에서 이루어져서 바로 던지면 제대로 핸들링 되지 않는다..
	table.insert(actions, Result_DirectingScript(function(mid, ds, arg)
		ds:AddSteamStat('TamingCount', 1, GetTeam(user));
		if summonBefore then
			ds:UpdateSteamAchievement('SituationTamingSummonBeast', true, GetTeam(user));
		end
		if target.Job.name == 'Draky' then
			ds:UpdateSteamAchievement('SituationTamingDraky', true, GetTeam(user));
		end
		return Result_FireWorldEvent('FriendlyBeastHasJoined', {Beast = target, FirstJoin = true}, nil, true), Result_FireWorldEvent('BeastTamingSucceeded', {Beast = target, Tamer=user, OriginalKey = beforeKey}, nil, true);
	end));
end
function ApplySummonBeastActions(actions, user, target, targetPos)
	table.insert(actions, Result_ChangeTeam(target, GetTeam(user), false));
	local setPos = Result_SetPosition(target, targetPos);
	setPos.sequential = true;
	setPos.forward = true;
	setPos.delay_update = true;
	table.insert(actions, setPos);
	table.insert(actions, Result_UpdateUserMember(target, GetTeam(user), true));
	InsertBuffActions(actions, user, target, 'SummonBeast', 1, true, nil, true);
	local pcStateKey = GetPcStateFromConditionValue_Beast(target.CP, target.MaxCP);
	local pcStateCls = GetClassList('PcState')[pcStateKey];
	if pcStateCls and pcStateCls.Buff ~= 'None' then
		InsertBuffActions(actions, user, target, pcStateCls.Buff, 1, true, nil, true);
	end
	table.insert(actions, Result_PropertyUpdated('Act', target.Wait, target, true, true));
	table.insert(actions, Result_PropertyUpdated('TurnState/TurnEnded', true, target, true, true));
	SetInstantProperty(user, 'SummonBeast', { Owner = user, Target = target });
	table.insert(actions, Result_UpdateInstantProperty(user, 'SummonBeastKey', GetObjKey(target)));
	SetInstantProperty(target, 'SummonMaster', GetObjKey(user));
	SetInstantProperty(target, 'Subordinate', true);
	table.insert(actions, Result_UpdateInstantProperty(target, 'DisableRetreat', true));
	local first = not GetInstantProperty(target, 'SummonBefore');
	SetInstantProperty(target, 'SummonBefore', true);
	local summonCount = GetInstantProperty(target, 'SummonCount') or 0;
	table.insert(actions, Result_UpdateInstantProperty(target, 'SummonCount', summonCount + 1));
	
	local startingBuff = {Stand = 'Stand', Patrol = 'Patrol', Detecting = 'Patrol'};
	if user.Team ~= 'player' then
		for testBuff, applyBuff in pairs(startingBuff) do
			if GetBuff(user, testBuff) then
				if not GetBuff(target, applyBuff) then
					InsertBuffActions(actions, target, target, applyBuff, 1, true);
				end
				break;
			end
		end
		SetInstantProperty(target, 'NoSupportDetectingAlert', GetInstantProperty(user, 'NoSupportDetectingAlert'));
	end
	
	-- 위치 갱신은 이동 이벤트 처리단에서 이루어지지만 이벤트 필터 처리는 액션 처리단계에서 이루어져서 바로 던지면 제대로 핸들링 되지 않는다..
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		return Result_FireWorldEvent('FriendlyBeastHasJoined', {Beast = target, FirstJoin = first}, nil, true);
	end));
end
function ApplyUnsummonBeastActions(actions, user, target)
	local setPos = Result_SetPosition(target, InvalidPosition());
	setPos.sequential = true;
	setPos.forward = true;
	setPos.delay_update = true;
	table.insert(actions, Result_FireWorldEvent('FriendlyBeastAboutToLeave', {Beast = target}));
	table.insert(actions, setPos);
	table.insert(actions, Result_ChangeTeam(target, '__summon__', false));
	table.insert(actions, Result_UpdateUserMember(target, GetTeam(user), false));
	table.insert(actions, Result_RemoveBuff(target, 'SummonBeast'));
	SetInstantProperty(user, 'SummonBeast', nil);
	SetInstantProperty(target, 'SummonMaster', nil);
	local unsummonCount = GetInstantProperty(target, 'UnsummonCount') or 0;
	table.insert(actions, Result_UpdateInstantProperty(target, 'UnsummonCount', unsummonCount + 1));
end