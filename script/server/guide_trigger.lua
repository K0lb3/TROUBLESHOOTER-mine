function RegisterGuideTrigger(mid, company)
	local mission = GetMission(mid);
	for _, guideTrigger in pairs(company.GuideTrigger) do
		(function()
			if guideTrigger.Pass or not guideTrigger.IsEnable(mission, company) then
				return;
			end
			RegisterGuideTriggerOne(mid, company, guideTrigger);
		end)();
	end
end

function RegisterGuideTriggerOne(mid, company, guideTrigger)
	guideTrigger.Register(mid, company, guideTrigger, function ()
		local dc = GetMissionDatabaseCommiter(mid);
		dc:UpdateCompanyProperty(company, 'GuideTrigger/'..guideTrigger.name..'/Pass', true);
		SafeNewIndex(company, 'GuideTrigger', guideTrigger.name, 'Pass', true);
		if guideTrigger.Reserved then
			SafeNewIndex(company, 'GuideTrigger', guideTrigger.name, 'ThisPass', true);
		end
	end);
end

function RestorePassedGuideTriggerOne(mid, company, guideTrigger, dc)
	dc:UpdateCompanyProperty(company, 'GuideTrigger/'..guideTrigger.name..'/Pass', true);
	SafeNewIndex(company, 'GuideTrigger', guideTrigger.name, 'Pass', true);
	SafeNewIndex(company, 'GuideTrigger', guideTrigger.name, 'ThisPass', true);
	guideTrigger.Restorer(mid, company, guideTrigger, dc);
end

function GuideTriggerRestorer_Empty(mid, company, guideTrigger, dc)
end

function GuideTriggerRestorer_Mastery(mid, company, guideTrigger, dc)
	local acquiredMastery = guideTrigger.Mastery;
	dc:AcquireMastery(company, acquiredMastery, 1);
end

function GuideTriggerRestorer_MasteryCheckTechnique(mid, company, guideTrigger, dc)
	local tech = GetWithoutError(company.Technique, guideTrigger.Mastery);
	if tech and tech.Opened then
		return;
	end
	GuideTriggerRestorer_Mastery(mid, company, guideTrigger, dc);
end

function OnRequestPassGuideTrigger(mid, company, guideName)
	local mission = GetMission(mid);
	local dc = GetMissionDatabaseCommiter(mid);
	local guideTrigger = GetWithoutError(company.GuideTrigger, guideName);
	if guideTrigger == nil or guideTrigger.Pass then
		return;
	end
	local fireEvent = Result_FireWorldEvent('GuideTriggerPassed', {Team = GetUserTeam(company), GuideTrigger = guideName});
	ApplyActions(mission, { fireEvent }, false);
end

function GuideTriggerRegister_WorldEvent(mid, company, guideTriggerCls, completor)
	local passed = false;
	for _, eventType in ipairs(guideTriggerCls.EventType) do
		SubscribeGlobalWorldEvent(mid, eventType, function(eventArg, ds)
			if passed then
				return;
			end
			local ok, output = guideTriggerCls.Checker(eventArg, ds, company, guideTriggerCls);
			if not ok then
				return;
			end
			passed = true;
			guideTriggerCls.Director(eventArg, ds, company, output, guideTriggerCls);
			completor();
		end, 8);
	end
	SubscribeGlobalWorldEvent(mid, 'GuideTriggerPassed', function(eventArg, ds)
		if passed then
			return;
		end
		if guideTriggerCls.name ~= eventArg.GuideTrigger then
			return;
		end
		if GetUserTeam(company) ~= eventArg.Team then
			return;
		end
		passed = true;
		completor();
	end, 8);
end
function GuideTriggerRegister_BeastTraining(mid, company, guideTriggerCls, completor)
	SubscribeGlobalWorldEvent(mid, 'MissionEnd', function(eventArg, ds)
		if GetUserTeam(company) ~= eventArg.Winner then
			return;
		end
		
		if company.Stats.MissionClearWithBeast + GetCompanyStats(company)['MissionClearWithBeast'] < 10 then
			return;
		end;
		
		local frontMsg = ds:ShowFrontmessageWithText(GuideMessageText(guideTriggerCls.FrontmessageKey), 'Corn');
		local acquiredMastery = guideTriggerCls.Mastery;
		ds:Connect(ds:ShowAcquireMasteryDirecting(GetUserTeam(company), acquiredMastery, 1, 'MasteryAcquiredGuideNormal', nil), frontMsg, 3);
		local dc = GetMissionDatabaseCommiter(mid);
		dc:AcquireMastery(company, acquiredMastery, 1);
		completor();
	end, 8);
end
function GuideTriggerChecker_Empty(mid, company, guideTriggerCls, completor)
	return false;
end
function FindCloseTargetInSight(self, pred)
	local allTargets = table.filter(GetAllUnitInSight(self, true), pred);
	if #allTargets == 0 then
		return false;
	end
	
	local selfPos = GetPosition(self);
	table.sort(allTargets, function(a, b)
		local aPos = GetPosition(a);
		local bPos = GetPosition(b);
		local aDist = GetDistance3D(aPos, selfPos);
		local bDist = GetDistance3D(bPos, selfPos);
		return aDist < bDist;
	end);
	
	local target = allTargets[1];
	
	return true, allTargets[1];
end

function GuideTriggerChecker_FindBuffOwner(eventArg, ds, company, guideTriggerCls)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and GetBuff(unit, guideTriggerCls.TestBuff) ~= nil;
	end);
end
function GuideTriggerDirector_BattleDialogMessage(eventArg, ds, company, output, guideTriggerCls)
	local target = output;
	local targetKey = GetObjKey(target);
	local ownerKey = GetObjKey(eventArg.Unit);
	if targetKey then
		ds:ChangeCameraTarget(targetKey, '_SYSTEM_', false, false, 1);
	end
	local helpType = guideTriggerCls.HelpMessage.name;
	if not helpType then
		helpType = guideTriggerCls.name;
	end
	ds:Dialog("HelpMessageBox",{ Type = helpType });
	if ownerKey and ownerKey ~= targetKey then
		ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false, 1);
	end
end
function GuideTriggerDirector_BattleDialogMessage_FindEnemy(eventArg, ds, company, output, guideTriggerCls)
	eventArg.FindGuideTriggered = true;
	GuideTriggerDirector_BattleDialogMessage(eventArg, ds, company, output, guideTriggerCls);
end
function GuideTriggerDirector_BattleDialogMessagePosition(eventArg, ds, company, output, guideTriggerCls)
	local targetPos = output;
	local ownerKey = GetObjKey(eventArg.Unit);
	if targetPos then
		ds:ChangeCameraPosition(targetPos.x, targetPos.y, targetPos.z, false, 1);
	end
	local helpType = guideTriggerCls.HelpMessage.name;
	if not helpType then
		helpType = guideTriggerCls.name;
	end
	ds:Dialog("HelpMessageBox",{ Type = helpType });
	local ownerPos = GetPosition(eventArg.Unit);
	if ownerKey and not IsSamePosition(ownerPos, targetPos) then
		ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false, 1);
	end
end
function GuideTriggerDirector_BattleDialogMessageSync(eventArg, ds, company, output, guideTriggerCls)
	GuideTriggerDirector_BattleDialogMessage(eventArg, ds, company, output, guideTriggerCls);
	local propKey = string.format('GuideTrigger/%s/Pass', guideTriggerCls.name);
	ds:RunScript('UpdateCompanyPropertyByDirecting', { team = GetUserTeam(company), key = propKey, value = true });
end

-- 회복 포션
function GuideTriggerChecker_RestorePotion(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	
	local inv1Ability = SafeIndex(eventArg.Unit, 'Inventory1', 'Ability');
	if SafeIndex(inv1Ability, 'Type') ~= 'Heal' or SafeIndex(inv1Ability, 'UseCount') == 0 or (SafeIndex(inv1Ability, 'Cool') or 0) > 0 then
		return false;
	end
	
	return eventArg.Unit.HP / eventArg.Unit.MaxHP < 0.6, eventArg.Unit;
end
-- 활기
function GuideTriggerChecker_StateVitality(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end	
	local isBuff = false;
	if GetBuff(eventArg.Unit, 'Vitality') then
		isBuff = true;
	end
	return isBuff, eventArg.Unit;
end
-- 피로
function GuideTriggerChecker_StateFatigue(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	local isBuff = false;
	if GetBuff(eventArg.Unit, 'Fatigue') then
		isBuff = true;
	end
	return isBuff, eventArg.Unit;
end
-- 기력 회복
function GuideTriggerChecker_RestoreCost(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	
	local self = eventArg.Unit;
	if self.CostType.name ~= 'Vigor' or self.Cost == self.MaxCost then
		return false;
	end
	
	return self.Cost <= 20, self;
end
-- 턴 순서 표시
function GuideTriggerChecker_NeedTurnOrder(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	local self = eventArg.Unit;	
	local allUnits = GetAllUnitInSight(self, false);
	local turnOrderUnits = table.filter(allUnits, function(unit)
		return unit.IsTurnDisplay;
	end);
	return #turnOrderUnits >= 8, self;
end
-- 화남이 시민을 공격함.
function GuideTriggerChecker_AngerKillCivil(eventArg, ds,company)
	local receiver = eventArg.Receiver;
	local giver = eventArg.Giver;
	
	if eventArg.Damage < 0 then
		return false;
	end
	
	return GetInstantProperty(receiver, 'CitizenType') and GetBuff(giver, 'Anger'), giver;
end
-- 전투 불능
function GuideTriggerChecker_OutOfAction(eventArg, ds,company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	
	return true, eventArg.Unit;
end
-- 위험한 위치.
function GuideTriggerChecker_DangerMoved(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end

	-- 엄폐가 아닌 위치로 이동
	if IsCoveredPosition(company, GetPosition(eventArg.Unit)) then
		return false;
	end
	
	-- 적이 보이는 위치에서만 반응하자
	local self = eventArg.Unit;
	local allEnemies = table.filter(GetAllUnitInSight(self, true), function(unit)
		if IsEnemy(self, unit) and not GetBuff(self, 'Patrol') and not GetBuff(self, 'Stand') and not GetBuff(self, 'Detecting') then
			return true;
		else
			return false;
		end
	end);
	return #allEnemies > 0, self;
end
-- 버프 혹은 디버프
function GuideTriggerChecker_BuffAdded(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	local isBuff = false;
	if eventArg.Buff.Type == 'Buff' or eventArg.Buff.Type == 'DeBuff' then
		isBuff = true
	end
	return isBuff, eventArg.Unit;
end
-- 연쇄효과
function GuideTriggerChecker_ChainEffect(eventArg, ds, company, guideTriggerCls)
	if eventArg.ChainType ~= guideTriggerCls.ChainType then
		return;
	end
	local mission = GetMission(eventArg.Unit);
	local allUnits = GetAllUnitInSightByTeam(mission, GetUserTeam(company));
	local isInSight = false;
	for _, unit in ipairs(allUnits) do
		if unit == eventArg.Unit then
			isInSight = true;
			break;
		end
	end
	return isInSight, eventArg.Unit;
end
-- SP 게이지 / 획득
function GuideTriggerChecker_SPGained(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end	
	return eventArg.Unit.SP > 0, eventArg.Unit;
end
-- 과충전 
function GuideTriggerChecker_SPFullGained(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end	
	return eventArg.Unit.Overcharge > 0 , eventArg.Unit;
end
-- 순찰 발견.
function GuideTriggerChecker_FindPatrol(eventArg, ds, company)
	if eventArg.EventType == 'AbilityUsed' or eventArg.EventType == 'UnitMoved' then
		if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
			return false;
		end
		if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
			or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
			return false;
		end
		-- 적이 보이는 위치에서만 반응하자
		return FindCloseTargetInSight(eventArg.Unit, function(unit) 
			return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and IsEnemy(eventArg.Unit, unit) and GetBuff(unit, 'Patrol');
		end);
	elseif eventArg.EventType == 'PatrolDetected' then
		if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
			return false;
		end
		if eventArg.Type ~= 'Patrol' then
			return false;
		end
		return true, eventArg.Target;
	else
		return false;
	end
end
-- 감시 발견.
function GuideTriggerChecker_FindDetecting(eventArg, ds, company)
	if eventArg.EventType == 'AbilityUsed' or eventArg.EventType == 'UnitMoved' then
		if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
			return false;
		end
		if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
			or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
			return false;
		end
		-- 적이 보이는 위치에서만 반응하자
		return FindCloseTargetInSight(eventArg.Unit, function(unit) 
			return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and IsEnemy(eventArg.Unit, unit) and GetBuff(unit, 'Detecting');
		end);
	elseif eventArg.EventType == 'PatrolDetected' then
		-- 감시의 경우 전 맵에 영향을 주므로 누가 깨웠든 반응하자
		if eventArg.Type ~= 'Detecting' then
			return false;
		end
		return true, eventArg.Target;
	else
		return false;
	end
end
-- 상자 발견
function GuideTriggerChecker_FindChest(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and GetInstantProperty(unit, 'MonsterType') == 'InvestigationTarget_Chest';
	end);
end
-- 이능석 발견
function GuideTriggerChecker_FindPsionicStone(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and GetInstantProperty(unit, 'PsionicStoneType') ~= nil;
	end);
end
-- 아이 시민 발견
function GuideTriggerChecker_FindChildCivil(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and GetInstantProperty(unit, 'CitizenType') == 'Child';
	end);
end
-- 전기차 충전기
function GuideTriggerChecker_FindElectricCharger(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and unit.Obstacle and GetInstantProperty(unit, 'MonsterType') == 'Object_ElectricCharger';
	end);
end
-- 가스 주유기.
function GuideTriggerChecker_FindOilingMachine(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and unit.Obstacle and GetInstantProperty(unit, 'MonsterType') == 'Object_OilingMachine';
	end);
end
-- 유독물 탱크.
function GuideTriggerChecker_FindToxicSubstance(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and unit.Obstacle and GetInstantProperty(unit, 'MonsterType') == 'Object_ToxicSubstance';
	end);
end
-- 정예 몬스터 발견
function GuideTriggerChecker_FindEliteMonster(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	local self = eventArg.Unit;
	return FindCloseTargetInSight(self, function(unit) 
		return IsEnemy(self, unit) and not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and unit.Grade.name == 'Elite';
	end);
end
-- 영웅 몬스터 발견
function GuideTriggerChecker_FindEpicMonster(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	local self = eventArg.Unit;
	return FindCloseTargetInSight(self, function(unit) 
		return IsEnemy(self, unit) and not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and unit.Grade.name == 'Epic';
	end);
end
-- 전설 몬스터 발견
function GuideTriggerChecker_FindLegendMonster(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	local self = eventArg.Unit;
	return FindCloseTargetInSight(self, function(unit) 
		return IsEnemy(self, unit) and not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and unit.Grade.name == 'Legend';
	end);
end
-- 중립 유닛 발견
function GuideTriggerChecker_FindNeutral(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and GetRelation(eventArg.Unit, unit) == 'None' and unit.Race.name ~= 'Object' and GetInstantProperty(unit, 'CitizenType') == nil;
	end);
end
-- 동맹 유닛 발견
function GuideTriggerChecker_FindAlly(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and GetRelation(eventArg.Unit, unit) == 'Ally';
	end);
end
-- 3 세력 발견
function GuideTriggerChecker_FindThirdForce(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and GetRelation(eventArg.Unit, unit) == 'Enemy' and GetRelation(unit, 'enemy') == 'Enemy';
	end);
end
-- 목표물 발견.
function GuideTriggerChecker_FindSuppressionTarget(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 
		return not StringToBool(GetInstantProperty(unit, 'NoGuideTriggerTarget'), false) and GetBuff(unit, 'SuppressionTarget') ~= nil;
	end);
end
-- VIP
function GuideTriggerChecker_FindVIP(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	local self = eventArg.Unit;
	if not GetBuff(self, 'VIP') then
		return false;
	end
	return true, self;
end

function GuideTriggerChecker_UsedCCAbility(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Giver, GetTeam(eventArg.Giver)) ~= company
		and GetCompanyByTeam(eventArg.Receiver, GetTeam(eventArg.Receiver)) ~= company then
		return false;
	end
	if eventArg.DamageInfo.damage_type ~= 'Ability'
		or not eventArg.DamageInfo.damage_invoker.Containment
		or eventArg.DefenderState ~= 'Dodge' then
		return false;
	end
	return true, eventArg.Receiver;
end

function GuideTriggerChecker_FindTima(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company
		and eventArg.Unit.name ~= 'Mon_Beast_Tima_Base' then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) == company then
		return FindCloseTargetInSight(eventArg.Unit, function(unit) 
			return unit.name == 'Mon_Beast_Tima_Base';
		end);
	else
		local anyUnit = GetTeamUnitByIndex(company, GetCompanyTeam(company), 1);
		return IsInSight(anyUnit, eventArg.Unit), eventArg.Unit;
	end
end

function GuideTriggerChecker_FindHeadshot(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	return FindCloseTargetInSight(eventArg.Unit, function(unit) 	
		local masteryTable = GetMastery(unit);
		return IsEnemy(eventArg.Unit, unit) and (GetMasteryMastered(masteryTable, 'HeadShot') or GetMasteryMastered(masteryTable, 'DetailedSnipe'));
	end);
end

function InTileFieldEffectGuideChecker(eventArg, ds, company, guideTriggerCls)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company 
		or not SafeIndex(eventArg, 'Invoker', 'Type') == 'FieldEffect'
		or StringToBool(GetInstantProperty(eventArg.Unit, 'NoGuideTriggerTarget'), false) then
		return;
	end
	
	return guideTriggerCls.FieldEffectType == SafeIndex(eventArg, 'Invoker', 'Value'), eventArg.Unit;
end
-- 연쇄 효과: 충돌 (넉백 효과에 의한 스턴 발생)
function GuideTriggerChecker_KnockbackStunOccured(eventArg, ds, company, guideTriggerCls)
	local companyPass = (GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) == company or GetCompanyByTeam(GetBuffGiver(eventArg.Buff), GetTeam(GetBuffGiver(eventArg.Buff))) == company);
	local buffNamePass = eventArg.BuffName == 'Stun';
	local knockbackPass = SafeIndex(eventArg, 'Invoker', 'Type') == 'Knockback';
	return companyPass and buffNamePass and knockbackPass, eventArg.Unit;
end
-- 연쇄 효과: 연환 (하위 버프로 인한 상위 버프의 턴 증가)
function GuideTriggerChecker_BuffLifeAddedByGroup(eventArg, ds, company)
	local mission = GetMission(eventArg.Unit);
	local allUnits = GetAllUnitInSightByTeam(mission, GetUserTeam(company));
	local isInSight = false;
	for _, unit in ipairs(allUnits) do
		if unit == eventArg.Unit then
			isInSight = true;
			break;
		end
	end
	return isInSight, eventArg.Unit;
end
function GuideTriggerChecker_DirectingSkipAvailable(eventArg, ds, company, guideTriggerCls)
	return company.LastMission == GetMission(company).name;
end
-- 오버킬
function GuideTriggerChecker_MonsterOverKill(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end	
	return true, eventArg.Unit;
end
-- 퍼펙트킬
function GuideTriggerChecker_MonsterPerfectKill(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end	
	return true, eventArg.Unit;
end
-- 이동 중 넉백 무시
function GuideTriggerChecker_MovingKnockbackIgnored(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Attacker, GetTeam(eventArg.Attacker)) ~= company
	and GetCompanyByTeam(eventArg.Defender, GetTeam(eventArg.Defender)) ~= company then
		return false;
	end	
	return true, eventArg.Defender;
end
function GuideTriggerChecker_CheckAsIsEvent(eventArg, ds, company)
	return true;
end
-- 불꽃 장막
function GuideTriggerChecker_FireShieldTakeDamage(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Receiver, GetTeam(eventArg.Receiver)) ~= company then
		return false;
	end
	if eventArg.DamageInfo.damage_type ~= 'Ability'
		or eventArg.DamageInfo.damage_invoker.name ~= 'FlameExplosion_FireShield'
		or eventArg.DefenderState == 'Dodge' then
		return false;
	end
	return true, eventArg.Receiver;
end
-- 야수 사냥꾼 마스터리
function GuideTriggerChecker_BeastHunter(eventArg, ds, company)
	local expTaker = GetExpTaker(eventArg.Killer);
	if expTaker == nil then
		return false;
	end
	if GetCompanyByTeam(expTaker, GetTeam(expTaker)) ~= company then
		return false;
	end
	
	--LogAndPrint('GuideTriggerChecker_BeastHunter', company.Stats.LegendaryBeastKill + GetCompanyStats(company)['LegendaryBeastKill'], company.Stats.LegendaryBeastKill, GetCompanyStats(company)['LegendaryBeastKill']);
	
	return company.Stats.LegendaryBeastKill + GetCompanyStats(company)['LegendaryBeastKill'] >= 100, expTaker;
end
-- 기계 사냥꾼 마스터리
function GuideTriggerChecker_MachineHunter(eventArg, ds, company)
	local expTaker = GetExpTaker(eventArg.Killer);
	if expTaker == nil then
		return false;
	end
	if GetCompanyByTeam(expTaker, GetTeam(expTaker)) ~= company then
		return false;
	end
	
	return company.Stats.LegendaryMachineKill + GetCompanyStats(company)['LegendaryMachineKill'] >= 100, expTaker;
end
-- 거인 사냥꾼 마스터리
function GuideTriggerChecker_GiantKiller(eventArg, ds, company)
	local expTaker = GetExpTaker(eventArg.Killer);
	if expTaker == nil then
		return false;
	end
	if GetCompanyByTeam(expTaker, GetTeam(expTaker)) ~= company then
		return false;
	end
	
	return company.Stats.GiantKill + GetCompanyStats(company)['GiantKill'] >= 100, expTaker;
end
-- 대량 추출 마스터리
function GuideTriggerChecker_MassExtract(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	return company.Stats.ExtractPsionicStone + GetCompanyStats(company)['ExtractPsionicStone'] >= 100, eventArg.Unit;
end
-- 재료수집가 마스터리
function GuideTriggerChecker_MaterialCollector(eventArg, ds, company)
	local expTaker = GetExpTaker(eventArg.Killer);
	if expTaker == nil then
		return false;
	end
	if GetCompanyByTeam(expTaker, GetTeam(expTaker)) ~= company then
		return false;
	end
	return company.Stats.RewardItemMaterial + GetCompanyStats(company)['RewardItemMaterial'] >= 100, expTaker;
end
-- 내변의 평화 마스터리
function GuideTriggerChecker_InnerPeace(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if eventArg.Ability.name ~= 'StandBy' then
		return false;
	end
	return company.Stats.UseAbilityStandBy + GetCompanyStats(company)['UseAbilityStandBy'] >= 100, eventArg.Unit;
end
-- 야수 조련사
function GuideTriggerChecker_BeastMaster(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Tamer, GetTeam(eventArg.Tamer)) ~= company then
		return false;
	end
	
	return company.Stats.TamingSuccessCount + GetCompanyStats(company)['TamingSuccessCount'] >= 5, eventArg.Tamer;
end
-- 회사 스텟
function GuideTriggerChecker_CompanyStatTest(eventArg, ds, company, guideTriggerCls)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	return company.Stats[guideTriggerCls.CompanyStat] + GetCompanyStats(company)[guideTriggerCls.CompanyStat] >= guideTriggerCls.StatGoal, eventArg.Unit;
end
-- 연막
function GuideTriggerChecker_SmokeScreen(eventArg, ds, company)
	if eventArg.BuffName ~= 'SmokeScreen' then
		return false;
	end
	local invoker = SafeIndex(eventArg, 'Invoker');
	if not invoker or type(invoker) ~= 'table' or invoker.Type ~= 'FieldEffect' or invoker.Value ~= 'SmokeScreen' then
		return false;
	end
	local mission = GetMission(eventArg.Unit);
	local allUnits = GetAllUnitInSightByTeam(mission, GetUserTeam(company));
	local isInSight = false;
	for _, unit in ipairs(allUnits) do
		if unit == eventArg.Unit then
			isInSight = true;
			break;
		end
	end
	return isInSight, eventArg.Unit;
end
-- 침묵
function GuideTriggerChecker_Silence(eventArg, ds, company)
	return eventArg.BuffName == 'Silence'
		and (GetCompany(eventArg.Unit) == company or GetCompany(GetBuffGiver(eventArg.Buff)) == company);
end
-- 시전 지연
function GuideTriggerChecker_CastDelayTime(eventArg, ds, company)
	return GetCompany(eventArg.Unit) == company and eventArg.Ability.CastDelay > 0;
end
-- 심해 탈출
function GuideTriggerChecker_DeepseaEscape(eventArg, ds, company)
	return eventArg.PropertyName == 'Act' and GetCompany(eventArg.Unit) == company and tonumber(eventArg.Value) >= 300, eventArg.Unit;
end
function GuideTriggerDirector_AchievementMastery(eventArg, ds, company, unit, triggerCls)
	local frontMsg = ds:ShowFrontmessageWithText(GuideMessageText(triggerCls.FrontmessageKey), 'Corn');
	local acquiredMastery = triggerCls.Mastery;
	ds:Connect(ds:ShowAcquireMasteryDirecting(GetTeam(unit), acquiredMastery, 1, 'MasteryAcquiredGuideNormal', GetObjKey(unit)), frontMsg, 3);
	local dc = GetMissionDatabaseCommiter(GetMission(unit));
	dc:AcquireMastery(company, acquiredMastery, 1);
end
function GuideTriggerDirector_AchievementMasteryCheckTechnique(eventArg, ds, company, unit, triggerCls)
	local tech = GetWithoutError(company.Technique, triggerCls.Mastery);
	if tech and tech.Opened then
		return;
	end
	GuideTriggerDirector_AchievementMastery(eventArg, ds, company, unit, triggerCls);
end
function GuideTriggerDirector_AchievementMasteryWithSteam(eventArg, ds, company, unit, triggerCls)
	local tech = GetWithoutError(company.Technique, triggerCls.Mastery);
	if tech and tech.Opened then
		return;
	end
	GuideTriggerDirector_AchievementMastery(eventArg, ds, company, unit, triggerCls);
	ds:UpdateSteamAchievement(triggerCls.Achievement, true);
end
-- 스팀 킬 업적 관련
function GuideTriggerChecker_KillAchievement(eventArg, ds, company, guideTriggerCls)
	local killerName = SafeIndex(eventArg, 'Killer', 'Info', 'name');
	local unitName = SafeIndex(eventArg, 'Unit', 'Info', 'name');
	-- 버프 데미지 처리
	local damageInfo = SafeIndex(eventArg, 'DamageInfo');
	if damageInfo and damageInfo.damage_type == 'Buff' then
		local buff = damageInfo.damage_invoker;
		local expTaker = GetExpTaker(buff);
		local expTakerName = SafeIndex(expTaker, 'Info', 'name');
		if expTakerName then
			killerName = expTakerName;
		end
	end
	return killerName == guideTriggerCls.Killer and unitName == guideTriggerCls.Target, nil;
end
function GuideTriggerDirector_SteamAchievement(eventArg, ds, company, dummy, guideTriggerCls)
	ds:UpdateSteamAchievement(guideTriggerCls.Achievement, true);
end
-- 광분
function GuideTriggerChecker_Berserker(eventArg, ds, company)
	if eventArg.BuffName ~= 'Berserker'
		or SafeIndex(eventArg, 'Invoker', 'Type') ~= 'Mastery'
		or SafeIndex(eventArg, 'Invoker', 'Value') ~= 'Berserker' then
		return false;
	end
	local mission = GetMission(eventArg.Unit);
	local allUnits = GetAllUnitInSightByTeam(mission, GetUserTeam(company));
	local isInSight = false;
	for _, unit in ipairs(allUnits) do
		if unit == eventArg.Unit then
			isInSight = true;
			break;
		end
	end
	return isInSight, eventArg.Unit;
end
-- 위임
function GuideTriggerChecker_BattleEntrust(eventArg, ds, company)
	return GetCompany(eventArg.Unit) == company and GetInstantProperty(eventArg.Unit, 'AutoPlayable');
end
-- 이동 경로 사용자 지정
function GuideTriggerChecker_MovePointCustomizing(eventArg, ds, company)
	if GetCompany(eventArg.Unit) ~= company then
		return false;
	end
	local unit = eventArg.Unit;
	local pos, score = FindAIMovePosition(unit, {FindMoveAbility(unit)}, function(self, adb, args)
		if not adb.BadField then
			return -9999;
		end
		return 9999;
	end, {}, {});
	if pos == nil or score < 0 then
		return false;
	end
	return true, pos;
end
-- 전투 정보 보기
function GuideTriggerChecker_BattleInfoMode(eventArg, ds, company)
	if eventArg.EventType == 'UnitTurnStart' then
		if GetCompany(eventArg.Unit) ~= company then
			return false;
		end
		return company.Stats.MissionClear >= 10 or company.Stats.MissionFail >= 1, eventArg.Unit;
	elseif eventArg.EventType == 'UnitTurnAcquired' then
		if GetCompany(eventArg.Unit) ~= company then
			return false;
		end
		local self = eventArg.Unit;
		-- 행동력 1이상 소모 시
		if not self.TurnState.Moved then
			return false;
		end
		-- 시야 내에 적이 하나라도 있는지
		local allUnit = GetAllUnitInSight(self, false);
		local allEnemies = table.filter(allUnit, function(unit)
			return IsEnemy(self, unit);
		end);
		if #allEnemies == 0 then
			return false;
		end
		-- 시야 내의 적들 중에 공격 가능한 게 하나라도 있는지
		local enemyKeySet = {};
		for _, enemy in ipairs(allEnemies) do
			enemyKeySet[GetObjKey(enemy)] = true;
		end
		local attackStrategy = function(self, adb)
			-- 대상들 중에 없으면 무시
			if not enemyKeySet[GetObjKey(adb.Object)] then
				return -1;
			end
			return 100;
		end;
		local usingAbility, _, _, score = FindAIMainAction(self, GetAvailableAbility(self), {{Strategy = attackStrategy, Target = 'Attack'}}, {}, {});
		if usingAbility and score >= 0 then
			return false;
		end
		return true, self;
	else
		return false;
	end
end
-- 야수 발견
function GuideTriggerChecker_GiselleHunterBeastFound(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if (eventArg.EventType == 'AbilityUsed' and IsMoveTypeAbility(eventArg.Ability))
		or (eventArg.EventType == 'UnitMoved' and (eventArg.MovingForAbility or eventArg.MovingForDirect)) then
		return false;
	end
	if eventArg.Unit.Info.name ~= 'Giselle' or eventArg.Unit.Job.name ~= 'Hunter' then
		return false;
	end
	local self = eventArg.Unit;
	return FindCloseTargetInSight(self, function(unit) 
		return IsEnemy(self, unit) and unit.Race.name == 'Beast' and unit.Grade.name ~= 'Legend';
	end);
end
-- 테이밍 실패
function GuideTriggerChecker_GiselleHunterTamingFailed(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if eventArg.Unit.Info.name ~= 'Giselle' or eventArg.Unit.Job.name ~= 'Hunter' then
		return false;
	end
	return true, eventArg.Unit;
end
-- 테이밍 성공
function GuideTriggerChecker_GiselleHunterTamingSucceeded(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if eventArg.Unit.Info.name ~= 'Giselle' or eventArg.Unit.Job.name ~= 'Hunter' then
		return false;
	end
	return true, eventArg.Unit;
end
-- 그림자 걷기
function GuideTriggerChecker_ShadowStep(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	return true, eventArg.Unit;
end
-- 강철 장벽
function GuideTriggerChecker_IronWall(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if not HasBuff(eventArg.Unit, 'IronWall') then
		return false;
	end
	return true, eventArg.Unit;
end
-- 안정된 자세
function GuideTriggerChecker_StableStatus(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	local unit = eventArg.Unit;
	if not IsCoveredPosition(GetMission(unit), GetPosition(unit)) then
		return false;
	end	
	local abilities = table.filter(GetAvailableAbility(unit, true), function (ability) return ability.Type == 'Attack' end);
	local usingAbility, usingPos, _, score = FindAIMainAction(unit, abilities, {{Strategy = function(self, adb)
		local score = 100;
		if adb.IsIndirect then
			score = 0;
		end
		return score + 100 / (adb.Distance + 1);
	end, Target = 'Attack'}}, {}, {});
	if usingAbility == nil then
		return false;
	end	
	return true, unit;
end
-- 강력한 덫
function GuideTriggerChecker_PowerfulTrap(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if eventArg.Ability.Type ~= 'Trap' then
		return false;
	end
	return company.Stats.TrapUseCount + GetCompanyStats(company)['TrapUseCount'] >= 10, eventArg.Unit;
end
-- 보물 사냥꾼
function GuideTriggerChecker_TreasureHunter(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if eventArg.Ability.name ~= 'InvestigateChest' then
		return false;
	end
	-- 이 이벤트 핸들러가 InvestigationOccured에 의한 OpenChest 스탯 증가보다 먼저 처리되므로 야매로 1 더해서 체크함
	return company.Stats.OpenChest + GetCompanyStats(company)['OpenChest'] + 1 >= 100, eventArg.Unit;
end
-- 재시작
function GuideTriggerChecker_HackerRestart(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if eventArg.Unit.Job.name ~= 'Hacker' then
		return false;
	end
	local abilityList = GetAllAbility(eventArg.Unit);
	abilityList = table.filter(abilityList, function(ability)
		return IsProtocolAbility(ability);
	end);
	-- 프로토콜 어빌리티가 하나도 없는 건 좀...
	if #abilityList == 0 then
		return false;
	end
	local enableList = table.filter(abilityList, function(ability)
		return ability.IsUseCount and ability.UseCount > 0;
	end);
	return #enableList == 0, eventArg.Unit;
end
-- 자동 프로토콜 복구
function GuideTriggerChecker_EngineerAutoProtocolRestore(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if eventArg.Unit.Job.name ~= 'Engineer' then
		return false;
	end
	local abilityList = GetAllAbility(eventArg.Unit);
	abilityList = table.filter(abilityList, function(ability)
		return IsProtocolAbility(ability);
	end);
	-- 프로토콜 어빌리티가 하나도 없는 건 좀...
	if #abilityList == 0 then
		return false;
	end
	local enableList = table.filter(abilityList, function(ability)
		return ability.IsUseCount and ability.UseCount > 0;
	end);
	return #enableList == 0, eventArg.Unit;
end
-- 코드 최적화
function GuideTriggerChecker_CodeOptimization(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if not IsProtocolAbility(eventArg.Ability) then
		return false;
	end
	return company.Stats.ProtocolUseCount + GetCompanyStats(company)['ProtocolUseCount'] >= 50, eventArg.Unit;
end
-- 수색 프로토콜
function GuideTriggerChecker_SearchProtocolUsed(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	if eventArg.Ability.name ~= 'SearchProtocol' then
		return false;
	end
	return true, eventArg.Unit;
end
-- 은신
function GuideTriggerChecker_Stealth(eventArg, ds, company)
	local target = nil;
	if eventArg.EventType == 'AbilityUsed' then
		local applyBuff = SafeIndex(eventArg.Ability, 'ApplyTargetBuff', 'name');
		if not applyBuff or applyBuff ~= 'Stealth' then
			return false;
		end
		target = eventArg.Unit;
	elseif eventArg.EventType == 'CloakingDetected' then
		if eventArg.Type ~= 'Stealth' then
			return false;
		end
		target = eventArg.Target;
	end
	local mission = GetMission(target);
	local teamUnits = GetTeamUnits(mission, GetUserTeam(company));
	if #teamUnits == 0 then
		return false;
	end
	if not IsInSight(teamUnits[1], GetPosition(target)) then
		return false;
	end
	return true, target;
end
-- 최대 액션 타임
function GuideTriggerChecker_MaxActionTime(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company 
		or eventArg.PropertyName ~= 'Act' then
		return false;
	end
	return tonumber(eventArg.Value) >= 999;
end
-- 떠오르는 별
function GuideTriggerChecker_RisingStar(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	return eventArg.GreatLv > 0, eventArg.Unit;
end
-- 열연
function GuideTriggerChecker_EnthusiasticPerformance(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	return eventArg.GreatLv >= 5, eventArg.Unit;
end
-- 정기 공연
function GuideTriggerChecker_SubscriptionConcert(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	return company.Stats.PerformanceFinishCount + GetCompanyStats(company)['PerformanceFinishCount'] >= 10, eventArg.Unit;
end
-- 앙코르
function GuideTriggerChecker_Encore(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	return eventArg.EffectCount >= 8 and eventArg.GreatLv >= 1, eventArg.Unit;
end
-- 즉흥적인 마무리
function GuideTriggerChecker_ShowClose(eventArg, ds, company)
	if GetCompanyByTeam(eventArg.Unit, GetTeam(eventArg.Unit)) ~= company then
		return false;
	end
	return eventArg.GreatLv == 0, eventArg.Unit;
end
-- 끈끈한 거미줄
function GuideTriggerChecker_StickyWeb(eventArg, ds, company)
	return eventArg.BuffName == 'StickyWeb' and GetCompany(eventArg.Unit) == company;
end
-- 도망치기
function GuideTriggerChecker_AutoRetreat(eventArg, ds, company)
	if not GetInstantProperty(eventArg.Unit, 'AutoRetreat') then
		return false;
	end
	return true, eventArg.Unit;
end