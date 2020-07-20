	-----------------------------------------------------------------------------------------
------------------------- 전투 유닛 생성시 최초 호출되는 값 -----------------------------
-----------------------------------------------------------------------------------------
function UNIT_INITIALIZER(self, team, datatable)
	if not IsAbleInitilaize(self, team) then
		return;
	end
	-- 유닛 상태 체크 이벤트 핸들러용 버프
	AddBuff(self, 'State', 1);

	-- 아군이 아닌 순찰이 켜진 녀석들만.
	local startingBuff = SafeIndex(datatable, 'StartingBuff');
	if team ~= 'player' and startingBuff and startingBuff ~= 'None' then
		if startingBuff == 'Stand' or startingBuff == 'FixedStand' then
			AddBuff(self, 'Stand', 1);
		elseif startingBuff == 'Patrol' or startingBuff == 'FixedPatrol' then
			AddBuff(self, 'Patrol', 1);
		elseif startingBuff == 'Detecting' then
			AddBuff(self, 'Detecting', 1);
		end
		if startingBuff == 'FixedStand' or startingBuff == 'FixedPatrol' then
			SetInstantProperty(self, 'NoSupportDetectingAlert', true);
		end
	end
	local angerBuff = SafeIndex(datatable, 'AngerBuff');
	if team ~= 'player' and angerBuff and angerBuff ~= 'None' then
		AddBuff(self, angerBuff, 1);
	end
	
	if not SafeIndex(datatable, 'IsRosterObject') then
		-- 기본 어빌리티 추가
		for index, value in ipairs (self.Base_Ability.Abilities) do
			GiveAbility(self, value.AbilityName, false);
		end
		if team == 'player' then
			for _, idspace in ipairs({'Interaction', 'InteractionArea'}) do
				for __, interactionCls in pairs(GetClassList(idspace)) do
					if interactionCls.AutoAbility then
						GiveAbility(self, interactionCls.Ability.name, false);
						for _, autoActive in ipairs(interactionCls.Ability.AutoActiveAbility) do
							local autoActiveAbility = GetAbilityObject(self, autoActive);
							if not autoActiveAbility then
								GiveAbility(self, autoActive, false);
							end
						end
					end
				end
			end
		end
		-- 마스터리 설정
		SetMasteryForBattle(self, datatable and datatable.IsPc or false);
		BuildMasteryAbilities(self);
		BuildItemAutoActiveAbilities(self);
	end

	-- 기본값 세팅 --
	self.HP = self.MaxHP;
	self.LowestHP = self.MaxHP;
	self.Shield = 0;
	self.Act = self.Wait;
	
	if self.CostType.name == 'Vigor' or self.CostType.name == 'Fuel' then
		self.Cost = self.MaxCost;
	elseif self.CostType.name == 'Rage' then
		self.Cost = 0;
	end
	
	if team then
		self.Team = team;
	end
	
	-- 어빌리티 기본값 세팅 --
	local abilityList = GetAllAbility(self, false, true);
	for _, ability in ipairs(abilityList) do
		Shared_InitializeUnitAbility(ability, self);
	end	

	-- 인스턴스 프로퍼티 초기화
	SetInstantProperty(self, 'Target', nil);

	local monType = GetInstantProperty(self, 'MonsterType');
	if monType then
		local monCls = GetClassList('Monster')[monType];
		SetInstantProperty(self, 'RecoveryRatio', monCls.RecoveryRatio);
		if monCls.AutoPlayable == 'On' then
			SetInstantProperty(self, 'AutoPlayable', true);
		elseif monCls.AutoPlayable == 'Off' then
			SetInstantProperty(self, 'AutoPlayable', false);
			SetInstantProperty(self, 'DisableRetreat', true);
		elseif monCls.AutoPlayable == 'Repeatable' then
			local mission = GetMission(self);
			local isRepeatable = mission.IsRepeatableMission;
			SetInstantProperty(self, 'AutoPlayable', isRepeatable);
		end
	else
		-- 로스터 PC 만.
		-- 컨디션에 따른 버프 걸어주기
		local pc = nil;
		if not SafeIndex(datatable, 'IsRosterObject') or SafeIndex(datatable, 'IsRosterReplace') then
			pc = GetRosterFromObject(self);
			if pc then
				SetInstantProperty(self, 'RosterType', pc.name);
			end
		end
		if pc and pc.RosterType == 'Pc' then
			local pcStateKey = GetPcStateFromConditionValue(self.CP, self.MaxCP);
			if pc and pc.ConditionState == 'Rest' then
				pcStateKey = 'Slight';
			end
			local masteryTable = GetMastery(self);
			local mastery_PositiveMind = GetMasteryMastered(masteryTable, 'PositiveMind');
			if mastery_PositiveMind and self.CP / self.MaxCP * 100 >= mastery_PositiveMind.ApplyAmount then
				pcStateKey = 'Available';
			end
			local pcStateCls = GetClassList('PcState')[pcStateKey];
			if pcStateCls and pcStateCls.Buff ~= 'None' then
				AddBuff(self, pcStateCls.Buff, 1);
			end
			if pc.FoodSetEffect ~= 'None' then
				local foodSetCls = GetClassList('FoodSet')[pc.FoodSetEffect];
				if foodSetCls and foodSetCls.Buff then
					local buff = AddBuff(self, foodSetCls.Buff.name, 1);
					local addRatio = 0;
					local mastery_Gourmand = GetMasteryMastered(masteryTable, 'Gourmand');
					if mastery_Gourmand and buff then
						addRatio = addRatio + mastery_Gourmand.ApplyAmount;
					end
					local mastery_Bodybuilder = GetMasteryMastered(masteryTable, 'Bodybuilder');
					if mastery_Bodybuilder and buff then
						addRatio = addRatio + mastery_Bodybuilder.ApplyAmount;
					end
					if addRatio > 0 then
						local addTurn = math.floor(foodSetCls.Buff.Turn * addRatio / 100);
						buff.Turn = buff.Turn + addTurn;
						buff.Life = buff.Life + addTurn;
					end
				end
			end
		end
	end

	for key, value in pairs(datatable) do
		SetInstantProperty(self, key, value);
	end

	if FindAbility(self, 'Overwatch') ~= nil then
		SetInstantProperty(self, 'HasOverwatch', true);
	end	
	if FindAbility(self, 'SetTarget') ~= nil then
		SetInstantProperty(self, 'HasSetTarget', true);
	end
	if FindAbility(self, 'Aiming') ~= nil then
		SetInstantProperty(self, 'HasAiming', true);
	end
	
	-- 트러블메이커 정보 등급
	local baseMonType = FindBaseMonsterTypeWithCache(self);
	if baseMonType then
		local gradeMap = {};
		local mission = GetMission(self);
		local companies = GetAllCompanyInMission(mission);
		for _, company in ipairs(companies) do
			local tm = GetWithoutError(company.Troublemaker, baseMonType);
			if tm then
				local team = GetUserTeam(company);
				local grade = GetTroublemakerInfoGrade(tm);
				gradeMap[team] = grade;
			end
		end
		self.TroublemakerGradeMap = gradeMap;
	end
end
function IsRepeatableMission(mission)
	local missionAttribute = GetMissionAttribute(mission);
	local eventGenType = SafeIndex(missionAttribute, 'EventGenType');
	local troubleBookEpisode = SafeIndex(missionAttribute, 'TroubleBookEpisode');
	local troubleBookStage = SafeIndex(missionAttribute, 'TroubleBookStage');
	
	if eventGenType then
		local eventCls = GetClassList('ZoneEventGen')[eventGenType];
		if eventCls and eventCls.Type ~= 'Scenario' then
			return true;
		end				
	elseif troubleBookEpisode then
		local troubleBook = GetClassList('Troublebook')[troubleBookEpisode];
		if troubleBook and troubleBook.name then
			local stage = troubleBook.Stage[troubleBookStage];
			if stage then
				return true;
			end
		end
	end
	return false;
end

function UNIT_INITIALIZER_NON_BATTLE(self, team)

	if not IsAbleInitilaize(self, team) then
		return;
	end

	-- 기본값 세팅 --
	self.HP = self.MaxHP;
	self.LowestHP = self.MaxHP;
	self.Shield = 0;
	self.Act = self.Wait;
	if self.CostType == 'Vigor' or self.CostType == 'Fuel' then
		self.Cost = self.MaxCost;
	elseif self.CostType == 'Rage' then
		self.Cost = 0;
	end
	if team then
		self.Team = team;
	end

	-- 인스턴스 프로퍼티 초기화
	SetInstantProperty(self, 'Target', nil);
end
--------------------------------------------------------------------------------------------
-- TurnStart_Common.(턴시작),  
-- TurnAcquired_Common.(턴획득),  
-- TurnEnd_Common.(턴종료)
-- AbilityUsed_Common(어빌리티 사용)
-- GiveDamage_Common(피해를 입힐때)
-- TakeDamage_Common(피해를 입을때)
-- Moved_Common(이동할때)
--------------------------------------------------------------------------------------------
function TurnStart_Common(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local mission = GetMission(owner);
	local totalElapsedTime = GetMissionElapsedTime(mission);
	UpdateBattleStateInfo(ds, owner, mission, 'TurnStart');
	
	-- 턴 시작시 전투 액션 업데이트
	UpdateBattleTurnStartActions(actions, owner, ds);
	if owner.CostType.name == 'Rage' then
		SetInstantProperty(owner, 'RageGuard', false);
	end
	
	if GetCompany(owner) == nil and not owner.PreBattleState and not GetBuff(owner, 'Silence') then
		-- 무한 루프가 발생했으므로, 일단 최대 20번까지만 반복 체크하도록 변경
		for i = 1, 20 do
			local allUnit = GetAllUnitInSight(owner, true);
			local aiSession = GetAISession(mission, GetTeam(owner));
			local enemyInSight = false;
			for _, e in ipairs(aiSession:GetTemporalSightObjects()) do
				if IsEnemy(owner, e) and GetDistanceFromObjectToObject(owner, e) <= owner.SightRange then
					enemyInSight = true;
					break;
				end
			end
			if not enemyInSight then
				local nearEnemy = table.filter(allUnit, function(o)
					return IsEnemy(owner, o);
				end);
				enemyInSight = #nearEnemy > 0;
			end
			if not enemyInSight then
				break;
			end
			local nearPreBattleAllies = table.filter(allUnit, function(o)
				return IsTeamOrAlly(owner, o) and o.PreBattleState;
			end);
			if #nearPreBattleAllies == 0 then
				break;
			end
			local founder = nearPreBattleAllies[1];
			local preBattleStateBuff = GetBuff(founder, 'Stand') or GetBuff(founder, 'Patrol') or GetBuff(founder, 'Detecting');
			table.append(actions, {Buff_Patrol_FindEnemy(founder, owner, GetPosition(owner), ds, false, nil, false, SafeIndex(preBattleStateBuff, 'name'), true)});
		end
	end
	
	return unpack(actions);
end
function IsExposedByEnemy(owner)
	local allEnemies = GetAllEnemyWithTeam(owner, GetTeam(owner));
	for _, enemyTeam in ipairs(allEnemies) do
		local aEnemy = GetTeamUnitByIndex(owner, enemyTeam, 1);
		if aEnemy then
			if IsInSight(aEnemy, GetPosition(owner)) then
				return true;
			end
		end
	end
	return false;
end
function UnitExposedByEnemyTest(owner)
	owner.ExposedByEnemy = IsExposedByEnemy(owner);
end
function TurnAcquired_Common(eventArg, buff, owner, giver, ds)
	local actions = {};
	
	if owner.ESP and owner.ESP.name then
		if owner.SP >= owner.MaxSP and owner.Overcharge == 0 then
			table.insert(actions, Result_PropertyUpdated('Overcharge', owner.OverchargeDuration, owner, true, true));
			if owner.MaxOverchargeDuration ~= owner.OverchargeDuration then
				table.insert(actions, Result_PropertyUpdated('MaxOverchargeDuration', owner.OverchargeDuration, owner, true, true));
			end
		end
	end
	
	return unpack(actions);
end
function PreAbilityUsing_Common(eventArg, buff, owner, giver, ds)
	-- 적 노출 테스트
	if owner.UseEnemyExposureFlag then
		UnitExposedByEnemyTest(owner);
	end
end
function ResetModifyAbilityAccuracyFromEventCache(eventArg, buff, owner, giver, ds)
	SetInstantProperty(owner, 'ModifyAbilityAccuracyFromEvent_Range_Attacker_Cache', nil);
end
function TurnEnd_Common(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local mission = GetMission(owner);
	local totalElapsed = GetMissionElapsedTime(mission);
	UpdateBattleStateInfo(ds, owner, mission, 'TurnEnd');
	
	if owner.CostType.name == 'Rage' then
		-- 자신의 코스트 자연 감소.
		if owner.Cost > 0 then
			-- 분노 계열 상태
			local buffRageList = GetBuffType(owner, nil, nil, 'Rage');
			-- 흉폭함
			local mastery_SavageBeast = GetMasteryMastered(GetMastery(owner), 'SavageBeast');
			if not GetInstantProperty(owner, 'RageGuard') and #buffRageList == 0 and not mastery_SavageBeast then
				local decreaseCost = -1 *  math.max(1, owner.RegenRage * 0.5);
				local retCost, reasons = AddActionCost(actions, owner, decreaseCost, true);
				local realAddValue = retCost - owner.Cost;
				if realAddValue ~= 0 then
					ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = realAddValue });
				end
				ReasonToUpdateBattleEventMulti(owner, ds, reasons);
			end
		end
	end
	
	-- 과충전 지속 턴 턴 감소.
	local curOvercharge = owner.Overcharge;
	if curOvercharge > 0 then
		AddOvercharge(actions, owner, -1, true);
		if curOvercharge == 1 then
			-- 마지막 턴이면 
			AddSP(actions, owner, -1 * owner.SP, true);
			table.insert(actions, Result_FireWorldEvent('OverchargeEnded', {Unit=owner}, owner));
		end
	end
	
	if #actions > 0 then
		return unpack(actions);
	end
	return;
end
function AbilityUsed_Common(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner
		or IsMoveTypeAbility(eventArg.Ability) then
		return;
	end
	local actions = {};
	local ability = eventArg.Ability;
	local pos = GetPosition(owner);
	LogAndPrint(string.format('[%s]>>[%s:%s] Use %s Ability to [%d,%d,%d] from [%d,%d,%d]', GetMissionGID(owner), owner.name, GetObjKey(owner), ability.name, eventArg.PositionList[1].x, eventArg.PositionList[1].y, eventArg.PositionList[1].z, pos.x, pos.y, pos.z));
	
	if owner.CostType.name == 'Rage' and (eventArg.Ability.Type == 'Attack' or eventArg.Ability.Type == 'Assist') then
		SetInstantProperty(owner, 'RageGuard', true);
	end

	if ability.Type == 'Heal' and ability.SubType2 == 'HP' and not (ability.ItemAbility or ability.SubType == 'None') then
		local mission = GetMission(owner);
		if mission.EnableKillReward and GetCompany(owner) ~= nil then
			local isTakeExp = not GetInstantProperty(owner, 'MonsterType');
			if isTakeExp then
				local masteryTable = GetMastery(owner);
				local mastery_Individualism = GetMasteryMastered(masteryTable, 'Individualism');
				local mastery_Learning = GetMasteryMastered(masteryTable, 'Learning');
				local mastery_Understanding = GetMasteryMastered(masteryTable, 'Understanding');
				local mastery_Insight = GetMasteryMastered(masteryTable, 'Insight');
				local mastery_Accounting = GetMasteryMastered(masteryTable, 'Accounting');
				local thokCount = GetCompanyInstantProperty(GetCompany(owner), 'TreasureHouseOfKnowledgeAmount') or 0;
				
				local ratio = 1;
				local ratioJob = 1;
				if mastery_Individualism then
					ratio = ratio + mastery_Individualism.ApplyAmount/100;
				end
				if mastery_Learning then
					ratio = ratio + mastery_Learning.ApplyAmount/100;
				end
				if mastery_Understanding then
					ratio = ratio + mastery_Understanding.ApplyAmount/100;
				end	
				if mastery_Insight then
					ratio = ratio + mastery_Insight.ApplyAmount/100;
				end
				if mastery_Accounting then
					ratio = ratio + mastery_Accounting.ApplyAmount/100;
				end
				if thokCount > 0 then
					ratio = ratio + thokCount / 100;
				end
				
				local addExp = math.floor(5 * ratio);
				local addExpJob = math.floor(5 * ratioJob);
				owner.RestExp = math.max(0, owner.RestExp - addExp);
				owner.RestJobExp = math.max(0, owner.RestJobExp - addExpJob);
				table.insert(actions, Result_AddExp(owner, addExp, addExpJob, 'Heal'));
				local objKey = GetObjKey(owner);
				ds:PlayUIEffect(objKey, '_CENTER_', 'AddExp', 6, 2, PackTableToString({exp = addExp, reason = 'Heal', AliveOnly=true}));
				ds:AddMissionChat('AddExp', 'AddExp', {ObjectKey = objKey, Exp = addExp, Reason = 'Heal'});
				ds:AddMissionChat('AddExp', 'AddJobExp', {ObjectKey = objKey, Exp = addExpJob, Reason = 'Heal'});
			end
		end
	end
	
	if #actions > 0 then
		return unpack(actions);
	end
	return;
end
function Moved_Common(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	LogAndPrint(string.format('[%s]>>[%s:%s] Moved [%d,%d,%d] -> [%d,%d,%d] %s', GetMissionGID(owner), owner.name, GetObjKey(owner), eventArg.BeginPosition.x, eventArg.BeginPosition.y, eventArg.BeginPosition.z, eventArg.Position.x, eventArg.Position.y, eventArg.Position.z, eventArg.MovingForAbility and 'MovingForAbility' or ''));
	local mission = GetMission(owner);
	local totalElapsed = GetMissionElapsedTime(mission);
	UpdateBattleStateInfo(ds, owner, mission, 'TurnProcess');
	
	if #actions > 0 then
		return unpack(actions);
	end
	return;
end
function TakeDamage_Common(eventArg, buff, owner, giver, ds)
	if eventArg.Receiver ~= owner then
		return;
	end
	LogAndPrintDev(string.format('[%s]>>[%s:%s] TakeDamage from [%s:%s], Damage [%d]', GetMissionGID(owner), owner.name, GetObjKey(owner), eventArg.Giver.name, GetObjKey(eventArg.Giver), eventArg.Damage));
	
	if owner.LowestHP > owner.HP then
		 owner.LowestHP = owner.HP;
	end
	local actions = {};
	-- 전투 코스트 관련.
	if eventArg.DamageInfo.damage_type ~= 'Ability' then
		UpdateBattleTakeDamageActions(actions, owner, ds);
	end
	return unpack(actions);
end
function AbilityAffected_Common(eventArg, buff, owner, giver, ds)
	local actions = {};
	-- 전투 코스트 관련.
	if eventArg.Ability.Type == 'Attack' then
		UpdateBattleTakeDamageActions(actions, owner, ds);
	end
	-- 회사 통계: 엄폐 중 회피
	if eventArg.Ability.Type == 'Attack' then
		local company = GetCompanyByTeam(GetMission(owner), GetTeam(owner));
		if company then
			if IsDodgeOnCover_AbilityAffected(eventArg, owner) then
				AddCompanyStats(company, 'DodgeOnCover', 1);
				table.insert(actions, Result_FireWorldEvent('UnitDodgedOnCover', {Unit = owner}));
			end
		end
	end
	return unpack(actions);
end
function GiveDamage_Common(eventArg, buff, owner, giver, ds)
	if eventArg.Giver ~= owner then
		return;
	end
	LogAndPrint(string.format('[%s]>>[%s:%s] GiveDamage to [%s:%s], Damage [%d]-------------', GetMissionGID(owner), owner.name, GetObjKey(owner), eventArg.Receiver.name, GetObjKey(eventArg.Receiver), eventArg.Damage));
	local actions = {};
	UpdateBattleGiveDamageActions(actions, owner);
	if #actions > 0 then
		return unpack(actions);
	end
end
function UnitResurrect_Common(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if not eventArg.ResurrectInfo.reset_sp then
		return;
	end
	local actions = {};
	AddSPPropertyActions(actions, owner, owner.ESP.name, -1 * owner.SP, true, ds, true);
	return unpack(actions);	
end
---------------------------------------------------------------------------------------------------
-- 버프 면역 핸들링
---------------------------------------------------------------------------------------------------
function BuffImmuned_Common(eventArg, buff, owner, giver, ds)
	if eventArg.Unit ~= owner 
		or eventArg.Reason == 'Hidden' then
		return;
	end
	
	if not eventArg.AbilityBuff then
		ds:UpdateBattleEvent(GetObjKey(owner), 'BuffImmuned', {Buff = eventArg.BuffName, Reason=eventArg.Reason})
	end
end
---------------------------------------------------------------------------------------------------
-- 
---------------------------------------------------------------------------------------------------
function UpdateBattleStateInfo(ds, owner, mission, turnState)
	local objectKey = GetObjKey(owner);
	
	if GetTeam(owner) == 'player' then
		-- 오브젝트 중심으로 엄폐 정보 처리
		local targetList =  GetAllUnit(mission);
		local nextTarget = nil;
		local targetActTemp = nil;
		for i, target in ipairs (targetList) do
			local targetKey = GetObjKey(target);
			if GetRelation(owner, target) ~= 'Team' then
				local coverState = GetCoverState(target, GetPosition(owner), owner);
				ds:UpdateCoverStateIcon(targetKey, coverState);
			end
		end
		if turnState == 'TurnEnd' then
			ds:UpdateStatusName(GetObjKey(owner), false);
		elseif turnState == 'TurnStart' then
			ds:UpdateStatusName(GetObjKey(owner), true);
		end
	end
end
function AddPropertyActions(actions, target, actionType, propertyKey, propertyValue)
    local prop = {}
    prop.type = actionType;
    prop.target = target;
    prop.property_key = propertyKey;
    prop.property_value = tostring(propertyValue);
	table.insert(actions, prop);	
end
---------------------------------------------------------------------------------------------------
function IsAbleInitilaize(obj, team)
	if obj == nil then
		LogAndPrint("UNIT_INITIALIZER Object is nil");
		return false;
	end
	return true;
end
function isUsableBuff(buff)
	local buffList = GetClassList('Buff');
	if buffList[buff].name == nil then
		return false;
	else
		return true;
	end
end
function SetMasteryForBattle(obj, isPc)
	local baseMastery = nil;
	local team = GetTeam(obj);
	if isPc then
		baseMastery = GetBaseMastery_PC(obj);
	else
		baseMastery = GetBaseMastery_Monster_Server(obj);
	end
	for masteryType, level in pairs(baseMastery) do
		UpdateTemporaryMastery(obj, masteryType, level);
	end
	-- 공연 시스템
	if obj.PerformanceSlot > 0 then
		UpdateTemporaryMastery(obj, 'PerformanceSystem', 1);
	end
end
function IsBossMonster(obj)
	local baseMonType = FindBaseMonsterTypeWithCache(obj);
	if not baseMonType then
		return obj.Grade.name == 'Epic' or obj.Grade.name == 'Legend';
	else
		local baseMon = GetClassList('Monster')[baseMonType];
		return baseMon.Grade == 'Epic' or baseMon.Grade == 'Legend';
	end
end
function GetBaseMastery_Monster_Server(obj)
	local list = GetBaseMastery_Monster(obj);
	if obj.Race.name == 'Object' then
		return list;
	end	

	-- 1. 도전 모드에 따른 추가 마스터리
	local mission = GetMission(obj);
	local needAdditionalMasteries = false;
	-- 도전 모드 체크
	local missionAttribute = GetMissionAttribute(mission);
	if SafeIndex(missionAttribute, 'ChallengerMode') and GetInstantProperty(obj, 'Challenger') then
		needAdditionalMasteries = true;
	end
	-- 보스 레벨 보정 체크
	if GetInstantProperty(obj, 'UseBossLvFix') then
		needAdditionalMasteries = true;
	end
	if IsSingleMission(mission) and needAdditionalMasteries then
		-- 추가 특성 적용
		local challengerMasteries, removeMasteries = GetUnitChallengerMasteries(obj, list);
		for _, masteryName in ipairs(challengerMasteries) do
			list[masteryName] = 1;
		end
		-- 기본 특성 중 각종 이유로 착용하면 안 되는 특성
		if #removeMasteries > 0 then
			LogAndPrint('[DataError] Monster object has remove masteries on challenger mode:', obj.name, removeMasteries);
		end
	end
	
	return list;
end

function GetMasterySlotCountByLv(lv)
	local list = {};
	local masteryUnlockLevelList = GetClassList('MasteryUnlockLevel');
	for key, cls in pairs(masteryUnlockLevelList) do
		local slotCount = 0;
		for index, unlockLevel in ipairs (cls.Unlock) do
			if lv >= unlockLevel then
				slotCount = slotCount + 1;
			end
		end
		list[key] = slotCount;
	end
	return list;
end
---------------------------------------------------------------------------------------------------
function GetCompanyStats(company)
	local stats = GetCompanyInstantProperty(company, 'Stats');
	if not stats then
		stats = {};
	end
	setmetatable(stats, {__index = function(t,v) return 0 end});
	return stats;
end
function AddCompanyStats(company, key, value)
	local stats = GetCompanyStats(company);
	stats[key] = stats[key] + value;
	SetCompanyInstantProperty(company, 'Stats', stats);
end
function GetUnitStats(obj)
	local stats = GetInstantProperty(obj, 'Stats');
	if not stats then
		stats = {};
	end
	setmetatable(stats, {__index = function(t,v) return 0 end});
	return stats;
end
function AddUnitStats(obj, key, value, withCompany)
	local stats = GetUnitStats(obj);
	stats[key] = stats[key] + value;
	SetInstantProperty(obj, 'Stats', stats);
	
	if withCompany then
		local company = GetCompanyByTeam(GetMission(obj), GetTeam(obj));
		if company then
			AddCompanyStats(company, key, value);
		end
	end
end
---------------------------------------------------------------------------------------------------
-- PC 값 Object로 가져오는 함수.
---------------------------------------------------------------------------------------------------
function InitObjectFromPC(obj, pc)
	obj.CP = pc:GetEstimatedCP();
	obj.MaxCP = pc.MaxCP;
	obj.OverChargeCP = pc.OverChargeCP;
	obj.BasicMastery = pc.BasicMastery;
	if pc.RosterType == 'Pc' then
		local enableJob = GetWithoutError(pc.EnableJobs, obj.Job.name);
		if not enableJob then
			return;
		end	
		local activeAbilitySet = table.map(enableJob.ActiveAbility, function (v) return StringToBool(v); end);
		-- 자동으로 같이 Active 되어야 하는 어빌리티 (ex. 토글형 어빌리티)
		for _, abilProp in ipairs(obj.Ability) do
			local autoActiveAbility = GetWithoutError(abilProp, 'AutoActiveAbility');
			local isActive = activeAbilitySet[abilProp.name] == true;
			if autoActiveAbility then
				-- 프로토콜 어빌리티는 비활성화된 상태에서 사용 가능해질 수 있으므로, 미리 어빌리티를 다 줘야 한다. (관리자 프로토콜)
				if IsProtocolAbility(abilProp) then
					isActive = true;
				end
				for _, abilityName in ipairs(autoActiveAbility) do
					activeAbilitySet[abilityName] = isActive;
					if isActive and not FindAbility(obj, abilityName) then
						GiveAbility(obj, abilityName, false);
					end
				end
			end
		end
		-- 어빌리티 편성 대상이 아닌 상호작용 어빌리티는 항상 활성화
		for _, abilProp in ipairs(obj.Ability) do
			if abilProp.Type == 'Interaction' and activeAbilitySet[abilProp.name] == nil then
				activeAbilitySet[abilProp.name] = true;
			end
		end
		-- Active 처리
		for _, abilProp in ipairs(obj.Ability) do
			abilProp.Active = activeAbilitySet[abilProp.name] == true;
		end
		obj.KnownJobs = Linq.new(pc.EnableJobs)
			:select(function(jobPair) return {jobPair[1], jobPair[2].Lv} end)
			:where(function(jobLevelPair) return jobLevelPair[2] > 0 end)
			:toMap();
	elseif pc.RosterType == 'Beast' then
		local beastType = GetWithoutError(pc, 'BeastType');
		if not beastType then
			return;
		end
		local activeAbilitySet = table.map(pc.ActiveAbility, function (v) return v; end);
		-- 자동으로 같이 Active 되어야 하는 어빌리티 (ex. 토글형 어빌리티)
		for _, abilProp in ipairs(obj.Ability) do
			local autoActiveAbility = GetWithoutError(abilProp, 'AutoActiveAbility');
			local isActive = activeAbilitySet[abilProp.name] == true;
			if autoActiveAbility then
				for _, abilityName in ipairs(autoActiveAbility) do
					activeAbilitySet[abilityName] = isActive;
					if isActive and not FindAbility(obj, abilityName) then
						GiveAbility(obj, abilityName, false);
					end
				end
			end
		end
		-- 어빌리티 편성 대상이 아닌 상호작용 어빌리티는 항상 활성화
		for _, abilProp in ipairs(obj.Ability) do
			if abilProp.Type == 'Interaction' and activeAbilitySet[abilProp.name] == nil then
				activeAbilitySet[abilProp.name] = true;
			end
		end
		-- Active 처리
		for _, abilProp in ipairs(obj.Ability) do
			abilProp.Active = activeAbilitySet[abilProp.name] == true;
		end
		obj.KnownJobs = { [obj.Job.name] = pc.JobLv };
	end
end
---------------------------------------------------------------------------------------------------
-- Monster 값을 Object로 가져오는 함수
---------------------------------------------------------------------------------------------------
function InitObjectFromMonster(obj, monster)
	if monster == nil then
		return;
	end
	
	obj.JobLv = monster.JobLv;
	
	if monster.Abilities then
		local activeAbilitySet = Set.new(monster.Abilities);
		-- 자동으로 같이 Active 되어야 하는 어빌리티 (ex. 토글형 어빌리티)
		for _, abilProp in ipairs(obj.Ability) do
			local autoActiveAbility = GetWithoutError(abilProp, 'AutoActiveAbility');
			local isActive = activeAbilitySet[abilProp.name] == true;
			if autoActiveAbility then
				for _, abilityName in ipairs(autoActiveAbility) do
					activeAbilitySet[abilityName] = isActive;
					if isActive and not FindAbility(obj, abilityName) then
						GiveAbility(obj, abilityName);
					end
				end
			end
		end
		for _, abilProp in ipairs(obj.Ability) do
			abilProp.Active = activeAbilitySet[abilProp.name] == true;
		end
	end
	
	if monster.EnableInteraction then
		for _, interactionType in ipairs(monster.EnableInteraction) do
			EnableInteraction(obj, interactionType);
		end
	end
	if monster.InstantProperty then
		for k, v in pairs(monster.InstantProperty) do
			SetInstantProperty(obj, k, v);
		end
	end
end
---------------------------------------------------------------------------------------------------
-- 경험치 제한
---------------------------------------------------------------------------------------------------
function GetUnitExpLimit(obj)
	if not obj then
		return 0;
	end
	local lvLimit = GetClassList('ExpLimit')[obj.ExpType].Limit;
	-- 야수는 테이머의 현재 레벨이 최대 레벨 제한이 된다.
	local tamer = GetTamerObject(obj);
	if tamer then
		lvLimit = math.min(lvLimit, tamer.Lv);
	end
	return lvLimit;
end
---------------------------------------------------------------------------------------------------
-- 도전 모드 특성 세팅
---------------------------------------------------------------------------------------------------
local g_challengerMasteryCache = {};
function GetUnitChallengerMasteries(obj, list)
	-- 1. 도전 모드에 따른 추가 마스터리
	local mission = GetMission(obj);
	local mid = GetMissionID(mission);
	
	-- MasteryBoardManager 초기화
	local mbm = game.MasteryBoardManagerCpp:new_local();
	
	local company = GetAllCompanyInMission(mid)[1];
	local masteryList = GetClassList('Mastery');
	
	local monCls = nil;
	local monsterKey = GetInstantProperty(obj, 'MonsterType');
	if monsterKey ~= nil then
		monCls = GetClassList('Monster')[monsterKey];
	end
	
	local dummyPc = nil;
	local privateSlot = nil;
	
	if obj.Race.name == 'Human' then
		local pcList = GetClassList('Pc');
		local basePcName = nil;
		if monCls ~= nil then
			for pcName, pcCls in pairs(pcList) do
				if monCls.Info.name == pcCls.Info.name then
					basePcName = pcName;
					break;
				end
			end
		end
		
		mbm:initPC('Pc', basePcName or 'Albus');
		mbm:setObject(obj);
		mbm:setLv(obj.Lv);
		
		local privateSlotList = { 'Basic', 'Sub', 'Attack', 'Defence' };
		local privateSlotPropMap = {
			Basic = 'Base_MaxBasicMasteryCount',
			Sub = 'Base_MaxSubMasteryCount',
			Attack = 'Base_MaxAttackMasteryCount',
			Defence = 'Base_MaxDefenceMasteryCount',
			Ability = 'Base_MaxAbilityMasteryCount',
		};
		if basePcName ~= nil then
			-- 기준이 되는 Pc 오브젝트가 있으면, 증가하는 슬롯을 찾음
			for slot, prop in pairs(privateSlotPropMap) do
				local count = GetWithoutError(basePc, prop) or 0;
				if count > 0 then
					privateSlot = slot;
					break;
				end
			end
		else
			-- 기준이 되는 Pc 오브젝트가 없으면, 랜덤으로 1개 슬롯을 증가시켜줌
			privateSlot = privateSlotList[math.random(1, #privateSlotList)];
			local dummyPc = mbm:getPC();
			for slot, prop in pairs(privateSlotPropMap) do
				if slot == privateSlot then
					dummyPc[prop] = 1;
				else
					dummyPc[prop] = 0;
				end
			end
		end
		
		dummyPc = mbm:getPC();
	elseif obj.Race.name == 'Beast' then
		local beastList = GetClassList('Beast');
		local beastTypeList = GetClassList('BeastType');
		local baseBeastType = nil;
		if monCls ~= nil then
			for _, typeCls in pairs(beastTypeList) do
				if monCls.Info.name == typeCls.Monster.Info.name  then
					baseBeastType = typeCls;
					break;
				end
			end
			-- 오브젝트 종류가 맞는 게 없으면, 대충 종류(직업)만 맞춘다.
			if baseBeastType == nil then
				for _, typeCls in pairs(beastTypeList) do
					if monCls.Object.Job.name == typeCls.Monster.Object.Job.name then
						baseBeastType = typeCls;
						break;
					end
				end
			end
			-- 그래도 없으면 적당히...
			if baseBeastType == nil then
				baseBeastType = beastTypeList['Mon_Beast_Tima_Base'];
			end
		end
		
		mbm:initPC('Beast', baseBeastType.name);
		mbm:setObject(obj);
		mbm:setLv(obj.Lv);
		
		dummyPc = mbm:getPC();
	elseif obj.Race.name == 'Machine' then
		local machineList = GetClassList('Machine');
		local machineTypeList = GetClassList('MachineType');
		local baseMachineType = nil;
		if monCls ~= nil then
			for _, typeCls in pairs(machineTypeList) do
				if monCls.Info.name == typeCls.Monster.Info.name and monCls.Object.ESP.name == typeCls.Monster.Object.ESP.name then
					baseMachineType = typeCls;
					break;
				end
			end
			-- 오브젝트 종류가 맞는 게 없으면, 대충 ESP만 맞춘다.
			if baseMachineType == nil then
				for _, typeCls in pairs(machineTypeList) do
					if monCls.Object.ESP.name == typeCls.Monster.Object.ESP.name then
						baseMachineType = typeCls;
						break;
					end
				end
			end
			-- 그래도 없으면 적당히...
			if baseMachineType == nil then
				baseMachineType = machineTypeList['Mon_DroneFrame_Rifle_Heat'];
			end
		end
		
		mbm:initPC('Machine', baseMachineType.name);
		mbm:setObject(obj);
		mbm:setLv(obj.Lv);
		
		dummyPc = mbm:getPC();
	end
	
	local removeList = {};
	for key, value in pairs(list) do
		if value > 0 then
			mbm:addMastery(key, true);
		end
	end
	mbm:invalidate();
	
	local categoryList = { 'Basic', 'Sub', 'Attack', 'Defence', 'Ability' };
	
	local randomPickerMap = {};
	for _, slot in ipairs(categoryList) do
		randomPickerMap[slot] = {};
		for i = 1, 5 do
			randomPickerMap[slot][i] = SimpleRandomPicker.new(false);		-- 비독립시행형 랜덤피커 생성
		end
	end
	
	-- 특성 연구 가능한 마스터리 목록
	local masteryCache = g_challengerMasteryCache[mid] or {};
	local masteries = nil;
	if monsterKey then
		masteries = masteryCache[monsterKey];
	end
	if not masteries then
		-- 새로 리스트 추출
		masteries = {};
		local allowMasterySet = GetCompanyInstantProperty(company, 'ChallengerModeMasterySet') or {};
		local checkMasteryTypeList = {};
		-- 0) 공용 마스터리
		if SafeIndex(obj, 'Race', 'name') == 'Machine' then
			table.insert(checkMasteryTypeList, 'Machine');
		else
			table.insert(checkMasteryTypeList, 'All');
		end
		-- 1) PC 마스터리
		table.insert(checkMasteryTypeList, dummyPc.name);
		-- 2) ESP 마스터리
		if obj.ESP and obj.ESP.name and obj.ESP.name ~= 'None' then
			table.insert(checkMasteryTypeList, obj.ESP.name);
		end
		-- 3) Job 마스터리
		if obj.Job and obj.Job.name and obj.Job.name ~= 'None' then
			local enableJobMasteryList = GetEnableJobMastery(obj.Job);
			for jobName, _ in pairs(enableJobMasteryList) do
				table.insert(checkMasteryTypeList, jobName);
			end
		end
		-- 4) Race 마스터리
		if obj.Race and obj.Race.name and obj.Race.name ~= 'None' then
			table.insert(checkMasteryTypeList, obj.Race.name);
		end
		
		for _, checkMasteryType in ipairs(checkMasteryTypeList) do
			local allowMasteryList = allowMasterySet[checkMasteryType];
			if allowMasteryList then
				table.foreachi(allowMasteryList, function(i, info)
					local masteryType = info.Name;
					-- 몬스터 보유 체크
					if list[masteryType] then
						return;
					end
					local mastery = masteryList[masteryType];
					-- SP 사용 여부
					if mastery.IsEnableESP then
						local isESP = SafeIndex(obj, 'ESP', 'name');
						if not isESP then
							return;
						end
					end
					table.insert(masteries, info);
				end);
			end
		end
		if monsterKey then
			masteryCache[monsterKey] = masteries;
			g_challengerMasteryCache[mid] = masteryCache;
		end
	end
	for _, info in ipairs(masteries) do
		local picker = SafeIndex(randomPickerMap, info.Category, info.Cost);
		if picker then
			picker:addChoice(info.Name);
		end
	end
	
	local targetSlotOrderList = { 'Attack', 'Defence', 'Sub', 'Basic', 'Ability' };
	local useBossLvFix = GetInstantProperty(obj, 'UseBossLvFix');
	if useBossLvFix then
		targetSlotOrderList = { 'Attack', 'Sub', 'Basic', 'Ability', 'Defence' };
	end
	if obj.Race and obj.Race.name == 'Machine' then
		-- 기계는 Basic 슬롯(FrameModule)을 우선적으로 배치해야함 (슬롯 확장이 일어나므로)
		targetSlotOrderList = { 'Basic', 'Attack', 'Defence', 'Sub', 'Ability' };
	end	
	local targetSlotList = {};
	if privateSlot ~= nil then
		table.insert(targetSlotList, { Slot = privateSlot, TryCount = 1 });
	end
	for _, slot in ipairs(targetSlotOrderList) do
		local remainCount = mbm:getRemainCount(slot);
		if privateSlot ~= nil and slot == privateSlot then
			remainCount = math.max(remainCount - 1, 0);
		end
		if remainCount > 0 then
			table.insert(targetSlotList, { Slot = slot, TryCount = remainCount });
		end
	end
	
	for _, info in ipairs(targetSlotList) do
		local slot = info.Slot;
		local tryCount = info.TryCount;
		local pickerList = randomPickerMap[slot];
		for i = 1, tryCount do
			local remainCost = mbm:getRemainCost(slot);
			local remainTP = mbm:getRemainTP()
			local remainCost = math.min(remainCost, remainTP);
			local remainCount = mbm:getRemainCount(slot);
			if remainCost <= 0 or remainCount <= 0 then
				break;
			end
			-- 현재 남은 코스트로 가능한 특성들 중에서 랜덤으로 아무거나
			local candidatePicker = RandomPicker.new();
			for cost, picker in ipairs(pickerList) do
				local pickerSize = picker:size();
				-- 보스 레벨 보정은 방어 슬롯의 3 코스트 이상 특성은 제외
				if useBossLvFix and slot == 'Defence' and cost >= 3 then
					pickerSize = 0;
				end
				if cost <= remainCost and pickerSize > 0 then
					candidatePicker:addChoice(pickerSize, picker);
				end
			end
			if candidatePicker:size() > 0 then
				local picker = candidatePicker:pick();
				local masteryName = picker:pick();	
				mbm:addMastery(masteryName, true);
			end
		end
	end
	
	local dumpStr = '';
	if IsDevLogEnabled() then
		dumpStr = '\n'..mbm:dumpStr();
	else
		dumpStr = mbm:dumpStr(true);
	end
	LogOnly(string.format('[%s]>>[%s:%s] MasteryBoard: %s', GetMissionGID(mission), obj.name, GetObjKey(obj), dumpStr));
	
	local ret = {};	
	for _, slot in ipairs(categoryList) do
		local masteries = mbm:getMasteryByCategory(slot);
		for _, mastery in ipairs(masteries) do
			local masteryName = mastery.name;
			if list[masteryName] == nil or list[masteryName] == 0 then
				table.insert(ret, masteryName);
			end
		end
	end
	return ret, removeList;
end
function ClearChallengerMasteryCache(mid)
	g_challengerMasteryCache[mid] = nil;
end