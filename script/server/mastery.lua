--------------------------------------- CP propertys ---------------------------------------
function Get_Mastery_ApplyValue(mastery)
	local result = 0;
	result = mastery.BaseValue + mastery.Lv * mastery.MulValue;
	if mastery.MaxAmount > 0 then 
		result = math.min(result, mastery.MaxAmount);
	end
	return result;
end
--------------------------------------- EventHandler ---------------------------------------
function CalculatedProperty_MasteryCustomEventHandler(self, arg)
	local eventHandlers = {};
	
	local needInitializeEvent = false;
	for _, handler in ipairs(GetWithoutError(self, 'EventHandler') or {}) do
		if handler.Event == 'MasteryInitialized' then
			needInitializeEvent = true;
			break;
		end
	end
	if needInitializeEvent then
		table.insert(eventHandlers, {Event='MissionBegin', Script=Mastery_MasteryInitialize_MissionBegin, Order = 1});
		table.insert(eventHandlers, {Event='UnitPositionChanged_Self', Script=Mastery_MasteryInitialize_UnitPositionChanged, Order = 1});
		table.insert(eventHandlers, {Event='UnitCreated_Self', Script=Mastery_MasteryInitialize_UnitPositionChanged, Order = 1});
	end	
	
	if self.InvalidateWhenBuffStateChanged then
		table.insert(eventHandlers, {Event='BuffAdded_Self', Script=Mastery_SelfInvalidator, Order=1});
		table.insert(eventHandlers, {Event='BuffRemoved_Self', Script=Mastery_SelfInvalidator, Order=1});
	end

	return eventHandlers;
end

function Mastery_MasteryInitialize_MissionBegin(eventArg, mastery, owner, ds)
	if not mastery.NeedInitialize then
		return;
	end
	mastery.NeedInitialize = false;
	return Result_FireWorldEvent('MasteryInitialized', {Unit = owner, Mastery = mastery, AllowInvalidPosition = true}, owner);
end
function Mastery_MasteryInitialize_UnitPositionChanged(eventArg, mastery, owner, ds)
	if not mastery.NeedInitialize then
		return;
	end
	mastery.NeedInitialize = false;
	return Result_FireWorldEvent('MasteryInitialized', {Unit = owner, Mastery = mastery, AllowInvalidPosition = true}, owner);
end
function Mastery_SelfInvalidator(eventArg, mastery, owner, ds)
	return Result_InvalidateObject(owner);
end
-------------  utility --------------
function AddMasteryDamageChat(ds, object, mastery, damage)
	if mastery == nil or mastery.name == nil then
		LogAndPrint('[DataError] AddMasteryDamageChat Mastery is invalid - mastery:', mastery, ', object:', GetUnitDebugName(object), ', damage:', damage);
		Traceback();
		return;
	end
	local msg = 'MasteryDamage';
	local damageAmount = damage;
	if damage < 0 then
		msg = 'MasteryHeal';
		damageAmount = -damage;
	end
	ds:AddRelationMissionChat('MasteryEvent', msg, { ObjectKey = GetObjKey(object), MasteryType = mastery.name, Damage = damageAmount });
end
function MasteryActivatedHelper(ds, mastery, target, eventType, needCam, refId, refOffset, noChat)
	if mastery == nil or mastery.name == nil then
		LogAndPrint('[DataError] MasteryActivatedHelper Mastery is invalid - mastery:', mastery, ', target:', GetUnitDebugName(target), ', eventType:', eventType);
		Traceback();
		return;
	end
	local targetKey = GetObjKey(target);
	local invoke = ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery.name });
	if needCam then
		local visible = ds:EnableIf('TestObjectVisibleAndAlive', targetKey);
		local cam = ds:ChangeCameraTarget(targetKey, '_SYSTEM_', false);
		ds:Connect(cam, visible, -1);
		ds:Connect(invoke, cam, 0.5);
		invoke = cam;
	end
	if not noChat then
		ds:AddMissionChat(GetMasteryEventKey(target), 'MasteryEvent', {ObjectKey = targetKey, MasteryType = mastery.name, EventType = eventType});
	end
	if refId then
		ds:Connect(invoke, refId, refOffset);
	end
end
function MasteryDamageHelper(ds, mastery, target, damage, needCam, refId, refOffset, noChat)
	if mastery == nil or mastery.name == nil then
		LogAndPrint('[DataError] MasteryDamageHelper Mastery is invalid - mastery:', mastery, ', target:', GetUnitDebugName(target), ', damage:', damage);
		Traceback();
		return;
	end
	local targetKey = GetObjKey(target);
	local invoke = ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery.name });
	if needCam then
		local visible = ds:EnableIf('TestObjectVisibleAndAlive', targetKey);
		local cam = ds:ChangeCameraTarget(targetKey, '_SYSTEM_', false);
		ds:Connect(cam, visible, -1);
		ds:Connect(invoke, cam, 0.5);
		invoke = cam;
	end
	if not noChat then
		AddMasteryDamageChat(ds, target, mastery, damage);
	end
	if refId then
		ds:Connect(invoke, refId, refOffset);
	end
end
------------------------------------------------------------------------------
-- 이벤트 공용
-------------------------------------------------------------------------------
-- DuplicateApplyChecker 초기화
function MasteryCommon_ResetDuplicateApplyChecker(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
------------------------------------------------------------------------------
-- 마스터리 초기화 [MasteryInitialized]
-------------------------------------------------------------------------------
-- 디스크 레이돔
function Mastery_Module_DiskRadom_Initialized(eventArg, mastery, owner, ds)
	local masteryTable = GetMastery(owner);
	local buffType = 'InformationConstruction_Aura';
	-- 강화 디스크 레이돔
	if GetMasteryMastered(masteryTable, 'Module_ReinforcedDiskRadom') then
		buffType = 'InformationSharing_Aura';
	end
	-- 정보 제어 프로그램
	if GetMasteryMastered(masteryTable, 'Module_InformationControl') then
		buffType = buffType..'_Range6';
	end
	SetInstantProperty(owner, mastery.name, buffType);
	return Result_AddBuff(owner, owner, buffType, 1, nil, true);
end
-- 해체 전문가
function Mastery_DismantlingSpecialist_Initialized(eventArg, mastery, owner, ds)
	SetInstantProperty(owner, 'DismantlingSpecialist', true);
end
-- 정보 교란
function Mastery_InformationDistortion_Initalized(eventArg, mastery, owner, ds)
	local buffType = 'InformationDistortion_Aura';
	if GetMasteryMastered(GetMastery(owner), 'InformationSpecialist') then
		buffType = 'InformationDistortion_Aura_Range6';
	end
	return Result_AddBuff(owner, owner, buffType, 1, nil, true);
end
-- 정보 교란기
function Mastery_Module_InformationJammer_Initialized(eventArg, mastery, owner, ds)
	local masteryTable = GetMastery(owner);
	local buffType = 'InformationDistortion_Aura';
	-- 강화 정보 교란기
	if GetMasteryMastered(masteryTable, 'Module_ReinforcedInformationJammer') then
		buffType = 'InformationFalsification_Aura';
	end
	-- 정보 제어 프로그램
	if GetMasteryMastered(masteryTable, 'Module_InformationControl') then
		buffType = buffType..'_Range6';
	end
	SetInstantProperty(owner, mastery.name, buffType);
	return Result_AddBuff(owner, owner, buffType, 1, nil, true);
end
-- 지식의 보고
function Mastery_TreasureHouseOfKnowledge_Initialized(eventArg, mastery, owner, ds)
	local company = GetCompany(owner);
	if company == nil then
		return;
	end
	local prevTHOK = GetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount') or 0;
	SetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount', prevTHOK + mastery.ApplyAmount);
end
-- 카리스마
function Mastery_Charisma_MasteryInitialized(eventArg, mastery, owner, ds)
	local buffType = 'Charisma';
	-- 혁명가
	if GetMasteryMastered(GetMastery(owner), 'Revolutionist') then
		buffType = 'Charisma_Range6';
	end
	return Result_AddBuff(owner, owner, buffType, 1, nil, true, nil, nil, {Type = 'Charisma'});
end
-- 억압
function Mastery_Oppression_MasteryInitialized(eventArg, mastery, owner, ds)
	local buffType = 'Oppression';
	-- 지배자
	if GetMasteryMastered(GetMastery(owner), 'Overlord') then
		buffType = 'Oppression_Range6';
	end
	return Result_AddBuff(owner, owner, buffType, 1, nil, true, nil, nil, {Type = 'Oppression'});
end
-- 악취
function Mastery_BadSmell_MasteryInitialized(eventArg, mastery, owner, ds)
	return Result_AddBuff(owner, owner, 'BadSmell_Aura', 1, nil, true, nil, nil, {Type = 'BadSmell'});
end
-- 향기
function Mastery_GoodSmell_MasteryInitialized(eventArg, mastery, owner, ds)
	return Result_AddBuff(owner, owner, 'GoodSmell_Aura', 1, nil, true, nil, nil, {Type = 'GoodSmell'});
end
-- 발광
function Mastery_Illumination_MasteryInitialized(eventArg, mastery, owner, ds)
	local actions = {};
	table.insert(actions, Result_AddBuff(owner, owner, 'Illumination_Aura', 1, nil, true, nil, nil, {Type = 'Illumination'}));
	table.insert(actions, Result_AddBuff(owner, owner, 'Illumination_Aura_Exposure', 1, nil, true, nil, nil, {Type = 'Illumination'}));
	return unpack(actions);
end
-- 함정 시스템
function Mastery_TrapSystem_MasteryInitialized(eventArg, mastery, owner, ds)
	local mvrKey = string.format('TRAP_AREA:%s', GetObjKey(owner));
	RegisterConnectionRestoreRoutine(GetMission(owner), mvrKey, function(ds)
		ds:MissionVisualRange_AddCustom(mvrKey, true, GetPosition(owner), GetObjKey(owner), 'Sphere2_Trap_Ally','Sphere2_Trap');
	end);
	ds:MissionVisualRange_AddCustom(mvrKey, true, GetPosition(owner), GetObjKey(owner), 'Sphere2_Trap_Ally','Sphere2_Trap');
	
	local mvaKey = string.format('TRAP_CLOCKING:%s', GetObjKey(owner));
	RegisterConnectionRestoreRoutine(GetMission(owner), mvaKey, function(ds)
		ds:MissionVisualArea_AddCustom(mvaKey, GetPosition(owner), 'Particles/Dandylion/EmptyDistortion', true, nil);
	end);
	ds:MissionVisualArea_AddCustom(mvaKey, GetPosition(owner), 'Particles/Dandylion/EmptyDistortion', true, nil);
end
-- 사냥꾼의 일상
function Mastery_LifeOfHunter_MasteryInitialized(eventArg, mastery, owner, ds)
	SetInstantProperty(owner, 'DailyHuntingNow', true);
end
local AddMessageRemover = function(b) b.UseAddedMessage = false; end;
-- 어빌리티를 사용하는 버프 토글형 특성 (ex. 사냥의 마음가짐)
function Mastery_CommonToggleBuff_MasteryInitialized(eventArg, mastery, owner, ds)
	return Result_AddBuff(owner, owner, mastery.Buff.name, 1, AddMessageRemover);
end
-- 전사의 후예
function Mastery_DescendantOfWarrior_MasteryInitialized(eventArg, mastery, owner, ds)
	local buffName = mastery.Buff.name;
	local mastery_SuccessorOfWarrior = GetMasteryMastered(GetMastery(owner), 'SuccessorOfWarrior');
	if mastery_SuccessorOfWarrior then
		buffName = mastery_SuccessorOfWarrior.Buff.name;
	end
	return Result_AddBuff(owner, owner, buffName, 1, AddMessageRemover);
end
-- 수호자의 후예
function Mastery_DescendantOfGuardian_MasteryInitialized(eventArg, mastery, owner, ds)
	local buffName = mastery.Buff.name;
	local mastery_SuccessorOfGuardian = GetMasteryMastered(GetMastery(owner), 'SuccessorOfGuardian');
	if mastery_SuccessorOfGuardian then
		buffName = mastery_SuccessorOfGuardian.Buff.name;
	end
	return Result_AddBuff(owner, owner, buffName, 1, AddMessageRemover);
end
-- 사냥꾼 인장
function Mastery_Amulet_Hunter_MasteryInitialized(eventArg, mastery, owner, ds)
	return Result_AddBuff(owner, owner, mastery.Buff.name, 1, AddMessageRemover);
end
-- 특성 불살
function Mastery_DoNotKill_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, nil, AddMessageRemover);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'MissionBegin'});
	return unpack(actions);
end
-- 특성 무법자
function Mastery_Outlaw_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, nil, AddMessageRemover);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'MissionBegin'});
	return unpack(actions);
end
-- 특성 별이 빛나는 밤
function Mastery_StarryNight_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	local mission = GetMission(owner);
	local isStarry = (mission.Weather.name == 'Windy' or mission.Weather.name == 'Clear');
	local isNight = (mission.MissionTime.name == 'Evening' or mission.MissionTime.name == 'Night');
	if isStarry and isNight then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, nil, AddMessageRemoverr);
	else
		InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, nil, AddMessageRemover);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'MissionBegin'});
	return unpack(actions);
end
-- 특성 방어진
function Mastery_DefenseCordon_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	local masteryTable = GetMastery(owner);
	local buffName = 'DefenseCordon_Aura';
	InsertBuffActions(actions, owner, owner, buffName, 1, nil, AddMessageRemover);
	return unpack(actions);
end
-- 특성 생명의 기원
function Mastery_OriginOfLife_MasteryInitialized(eventArg, mastery, owner, ds)
	local actions = {};
	local masteryTable = GetMastery(owner);
	local buffName = 'OriginOfLife_Aura';
	-- 빛의 아이
	local mastery_ChildOfLight = GetMasteryMastered(masteryTable, 'ChildOfLight');
	if mastery_ChildOfLight then
		buffName = 'OriginOfLife_Aura_Range6';
	end
	InsertBuffActions(actions, owner, owner, buffName, 1, nil, AddMessageRemover);
	return unpack(actions);
end
-- 특성 성스러운 방패
function Mastery_HolyShield_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	local masteryTable = GetMastery(owner);
	local buffName = 'HolyShield_Aura';
	-- 성자
	local mastery_Saint = GetMasteryMastered(masteryTable, 'Saint');
	if mastery_Saint then
		buffName = 'HolyShield_Aura_Range6';
	end
	InsertBuffActions(actions, owner, owner, buffName, 1, nil, AddMessageRemover);
	-- 빛의 아이
	local mastery_ChildOfLight = GetMasteryMastered(masteryTable, 'ChildOfLight');
	if mastery_ChildOfLight then
		local buffName = 'WillOfLight_Aura';
		-- 성스러운 방패와 범위가 같아야 하므로, 성자에 의한 범위 확장도 같이 적용된다.
		if mastery_Saint then
			buffName = 'WillOfLight_Aura_Range6';
		end
		InsertBuffActions(actions, owner, owner, buffName, 1, nil, AddMessageRemover);
	end
	return unpack(actions);
end
-- 특성 살수의 인장
function Mastery_Amulet_Killer_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, AddMessageRemover);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'MasteryInitialized'});
	return unpack(actions);
end
-- 수리 가능 오브젝트
function Mastery_RepairableObject_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	return Result_UpdateInteraction(owner, 'Repair', true);
end
-- 야샤 알집
function Mastery_HatchedObjectYasha_MasteryInitialized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, 'HatchedObjectYasha', 1, true, AddMessageRemover);
	return unpack(actions);
end
-- 항동결 수액
function Mastery_AntiFreezingInfusionSolution_Initalized(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery then
		return;
	end
	local buffName = mastery.SubBuff.name;
	local buffLv = mastery.ApplyAmount;
	local masteryTable = GetMastery(owner);
	-- 고급 항동결 수액
	local mastery_AntiFreezing = GetMasteryMastered(masteryTable, 'AntiFreezing');
	if mastery_AntiFreezing then
		buffLv = buffLv + mastery_AntiFreezing.ApplyAmount;
	end
	-- 항동결 부작용
	local mastery_AntiFreezingSideEffect = GetMasteryMastered(masteryTable, 'AntiFreezingSideEffect');
	if mastery_AntiFreezingSideEffect then
		buffLv = buffLv + mastery_AntiFreezingSideEffect.ApplyAmount;
	end
	mastery.CountChecker = mastery.ApplyAmount2;
	return Result_AddBuff(owner, owner, buffName, buffLv, nil, true, nil, nil, {Type = mastery.name});
end
-----------------------------------------------------------------------
-- 유닛 사망 [UnitDead]
-------------------------------------------------------------------------------
function Mastery_Skull_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or GetTeam(eventArg.Unit) ~= GetTeam(owner)
		or not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end
	
	local actions = {};
	local subAct = mastery.ApplyAmount;
	AddActionApplyActForDS(actions, owner, -subAct, ds, 'Friendly');
	if owner.Act < subAct then
		mastery.DuplicateApplyChecker = 1;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	return unpack(actions);
end
-- 이타주의자
function Mastery_Altruist_UnitDead(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or GetTeam(owner) ~= GetTeam(eventArg.Killer)
		or owner == eventArg.Killer
		or not IsInSight(owner, GetPosition(eventArg.Killer, true), true)
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	local actions = {};
	local applyAct = -mastery.ApplyAmount;	
	if PositionInRange(CalculateRange(owner, GetClassList('Mastery').TeamPlayer.Range, GetPosition(owner)), GetPosition(eventArg.Killer)) then	
		applyAct = applyAct - mastery.ApplyAmount;
	end
	AddActionApplyActForDS(actions, owner, applyAct, ds, 'Friendly');
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 지식의 보고
function Mastery_TreasureHouseOfKnowledge_UnitDead(eventArg, mastery, owner, ds)
	if owner.HP > 0 then
		return;
	end
	
	local company = GetCompany(owner);
	if not company then
		return;
	end
	
	local prevTHOK = GetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount');
	SetCompanyInstantProperty(company, 'TreasureHouseOfKnowledgeAmount', prevTHOK - mastery.ApplyAmount);
end
-- 사냥꾼과 사냥개
function Mastery_HunterAndHuntingDog_UnitDead(eventArg, mastery, owner, ds)
	local hostKey = GetInstantProperty(eventArg.Killer, 'SummonMaster');
	local damageFlag = SafeIndex(eventArg, 'DamageInfo', 'Flag');
	if hostKey ~= GetObjKey(owner)
		or (SafeIndex(damageFlag, 'AttackWithBeast') == nil or SafeIndex(damageFlag, 'InvokedByTrap') == nil) then
		return;
	end
	
	local actions = {};
	for _, obj in ipairs(GetNearObject(eventArg.Unit, mastery.ApplyAmount)) do
		if IsEnemy(owner, obj) and not IsDead(obj) then
			InsertBuffActions(actions, owner, obj, mastery.Buff.name, 1, true);
		end
	end
	if #actions <= 0 then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	return unpack(actions);
end
-- 함정 시스템
function Mastery_TrapSystem_UnitDead(eventArg, mastery, owner, ds)
	local mvrKey = string.format('TRAP_AREA:%s', GetObjKey(owner));
	UnregisterConnectionRestoreRoutine(GetMission(owner), mvrKey);
	ds:MissionVisualRange_AddCustom(mvrKey, false);
	
	local mvaKey = string.format('TRAP_CLOCKING:%s', GetObjKey(owner));
	UnregisterConnectionRestoreRoutine(GetMission(owner), mvaKey);
	ds:MissionVisualArea_AddCustom(mvaKey, nil, nil, false);
	return Result_ChangeTeam(owner, '_dummy', false);
end
-- 특성 두번째 심장.
function Mastery_SecondHeart_UnitDead(eventArg, mastery, owner, ds)
	if GetBuff(owner, mastery.Buff.name) then
		return;
	end
	local limit = 1;
	-- 세번째 심장
	local mastery_ThirdHeart = GetMasteryMastered(GetMastery(owner), 'ThirdHeart');
	if mastery_ThirdHeart then
		limit = mastery_ThirdHeart.ApplyAmount;
	end
	if mastery.DuplicateApplyChecker >= limit then
		return;
	end
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if mastery_ThirdHeart then
		ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery_ThirdHeart.name });
	end	
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(objKey);
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
	ds:Connect(resurrectID, particleID, 3.8);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	if mastery_ThirdHeart then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_ThirdHeart.name, EventType = 'UnitDead'});
	end
	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	local restoreAmount = mastery.ApplyAmount;
	if mastery_ThirdHeart then
		restoreAmount = mastery_ThirdHeart.ApplyAmount2;
	end
	local hpUpdate = Result_PropertyUpdated('HP', math.floor(owner.MaxHP * restoreAmount / 100), owner, true);
	hpUpdate.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_Resurrect(owner, 'Normal', true, mastery));
	table.insert(actions, Result_AddBuff(owner, owner, mastery.Buff.name, 1));
	table.insert(actions, hpUpdate);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	return unpack(actions);
end
-- 특성 : 불사조
function Mastery_Phoenix_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or GetBuff(owner, mastery.Buff.name) then
		return;
	end
	
	-- 1. 화염 속성 초능력자가 아니면 작동 안함.
	if not owner.ESP and owner.ESP.name ~= 'Fire' then
		LogAndPrint(string.format('[%s]>>[%s:%s] Failed to rebirth with Phoenix (not fire ESP user)', GetMissionID(owner), owner.name, GetObjKey(owner)));
		return;
	end
	-- 2. SP가 없을 경우.
	if owner.MaxSP == 0 or owner.SP == 0 then
		-- 불사조 특성의 기능적 특성상 발동 하지 않는 조건이 컨트롤하기 어렵고 가끔씩 실수로 등장하기 때문에 로그를 따로 남겨둘
		LogAndPrint(string.format('[%s]>>[%s:%s] Failed to rebirth with Phoenix (no SP)', GetMissionID(owner), owner.name, GetObjKey(owner)));
		return;
	end
	
	LogAndPrint(string.format('[%s]>>[%s:%s] Succeed to rebirth with Phoenix', GetMissionID(owner), owner.name, GetObjKey(owner)));
	
	local resetSP = true;	
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false, false, 0.5);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(objKey);	
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/Pheonix', 5);
	ds:Connect(resurrectID, particleID, 3.8);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	if owner.Info.name == 'Carter' and GetCompany(owner) then
		ds:UpdateSteamAchievement('AbilityCarter', true, GetTeam(owner));
	end
	local hpUpdate = Result_PropertyUpdated('HP', math.max(1, math.min(owner.MaxHP, owner.SP * mastery.ApplyAmount)), owner, true);
	
	local masteryTable = GetMastery(owner);
	local mastery_LastFlame = GetMasteryMastered(masteryTable, 'LastFlame');
	if mastery_LastFlame then
		resetSP = false;
	end
	hpUpdate.sequential = true;
	
	local actions = {Result_Resurrect(owner, 'Normal', resetSP, mastery), Result_AddBuff(owner, owner, mastery.Buff.name, 1, nil, true), hpUpdate};
	
	local mastery_RevengeFlame = GetMasteryMastered(GetMastery(owner), 'RevengeFlame');
	if mastery_RevengeFlame then
		MasteryActivatedHelper(ds, mastery_RevengeFlame, owner, 'UnitDead_Self');
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
		if not owner.TurnState.TurnEnded then
			table.append(actions, {GetInitializeTurnActions(owner)});
		end
	end
	
	return unpack(actions);
end
-- 긴급 구조 프로그램
function Mastery_Module_EmergencyRescue_UnitDead_Self(eventArg, mastery, owner, ds)
	if GetInstantProperty(owner, 'EmergencyRescueTarget') == nil then
		return;
	end
	-- 긴급 구조하러 가는중에 죽음..
	mastery.CountChecker = 1;
	local ret = Result_FireWorldEvent('EmergencyRescueCompleted', {Receptionist = owner, Target = GetInstantProperty(owner, 'EmergencyRescueTarget'), Succeed = false});
	SetInstantProperty(owner, 'EmergencyRescueTarget', nil);
	
	return ret;
end
-- 긴급 구조 프로그램
function Mastery_Module_EmergencyRescue_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or GetRelation(owner, eventArg.Unit) ~= 'Team'
		or eventArg.Unit.Obstacle then
		return;
	end
	local onGoingRescueTargets = GetInstantProperty(owner, 'OnGoingRescueTargets') or {};
	if onGoingRescueTargets[GetObjKey(eventArg.Unit)] then
		-- 이미 다른놈이 출동함
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	local target = eventArg.Unit;
	if GetBuff(target, mastery.Buff.name) then
		return;
	end
	local myPos = GetPosition(owner);
	local targetPos = GetPosition(target);
	if GetDistance3D(myPos, targetPos) >= (mastery.ApplyAmount + 0.4) then
		return;
	end
	local limit = mastery.ApplyAmount2;
	if mastery.DuplicateApplyChecker >= limit then
		return;
	end
	if target.Race.name == 'Machine' or target.Race.name == 'Object' then
		return;
	end
	if owner.Cost < mastery.ApplyAmount3 then
		return;
	end
	
	local movePos = GetMovePosition(owner, targetPos, 1.8, true, nil, true);
	local mission = GetMission(owner);
	if not IsValidPosition(mission, movePos) or GetDistance3D(movePos, targetPos) > 1.8 then
		return;
	end
	
	SetInstantProperty(owner, 'EmergencyRescueTarget', target);
	ds:WorldAction(Result_FireWorldEvent('EmergencyRescueReceived', {Receptionist = owner, Target = target}), true);
	StashCurrentActionChunk(mission);
	
	local objKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Move(objKey, movePos);
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return Result_DirectingScript(function (mid, ds, args)
		if IsDead(owner) or mastery.CountChecker > 0 then
			mastery.CountChecker = 0;
			PopLastActionChunk(mid);
			return;
		end
		SetInstantProperty(owner, 'EmergencyRescueTarget', nil);
		ds:LookAt(objKey, targetKey);
		ds:Sleep(1.5);
		local resurrectID = ds:Resurrect(targetKey);
		local particleID = ds:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
		ds:Connect(resurrectID, particleID, 3.8);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
		
		local restoreAmount = mastery.ApplyAmount4;	
		local hpUpdate = Result_PropertyUpdated('HP', math.floor(target.MaxHP * restoreAmount / 100), target, true);
		hpUpdate.sequential = true;
		
		local actions = {};
		table.insert(actions, Result_Resurrect(target, 'Normal', true, mastery));
		table.insert(actions, Result_AddBuff(owner, target, mastery.Buff.name, 1));
		table.insert(actions, hpUpdate);
		table.insert(actions, Result_PropertyUpdated('Act', -target.Speed, target, nil, true));
		if not target.TurnState.TurnEnded then
			table.append(actions, {GetInitializeTurnActions(target)});
		end
		AddActionCostForDS(actions, owner, -mastery.ApplyAmount3, true, nil, ds);
		table.insert(actions, Result_FireWorldEvent('EmergencyRescueCompleted', {Receptionist = owner, Target = target, Succeed = true}));
		table.insert(actions, Result_FireWorldEvent('UnitReturnFromDeath', {Unit = target}));
		table.insert(actions, Result_DirectingScript(function(mid, ds, args)
			PopLastActionChunk(mid);
		end, nil));
		return unpack(actions);
	end, nil, true, true);
end
-- 특성 : 전우애
function Mastery_Comradeship_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner
		or GetRelation(owner, eventArg.Unit) ~= 'Team'
		or eventArg.Unit.Obstacle then
		return;
	end
	if not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end	
	-- 어빌리티 데미지인 경우에만 DuplicateApplyChecker를 사용한다.
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability' then
		if mastery.DuplicateApplyChecker > 0 then
			return;
		end
		mastery.DuplicateApplyChecker = 1;
	end
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	
	local actions = {};
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	elseif owner.Act > mastery.ApplyAmount then
		AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	else
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	end
	return unpack(actions);
end
-- 특성 포식자
function Mastery_Predator_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner then
		return;
	end
	-- 자기 자신을 죽인 경우는 발동안함
	if eventArg.Unit == owner then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end	
	if not eventArg.Unit.Race.Edible
		or eventArg.Unit.name == 'Mon_PC_Kylie_Hologram' then
		-- 못먹는건 발동 안함
		return;
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	local playAniID = ds:PlayAni(objKey, 'AstdIdle', false, -1, true);
	
	local addHP = math.floor(owner.MaxHP * mastery.ApplyAmount/100);	
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	DirectDamageByType(ds, owner, 'Predator', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false, playAniID, 1.0);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_Predator_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
function Mastery_Catharsis_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
-- 특성 구사일생.
function Mastery_CheatDeath_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or GetBuff(owner, mastery.Buff.name) then
		return;
	end
	local applyAmount = mastery.ApplyAmount;
	-- 빗나간 죽음
	local mastery_LuckyCheatDeath = GetMasteryMastered(GetMastery(owner), 'LuckyCheatDeath');
	if mastery_LuckyCheatDeath then
		local adjustValue = GetInstantProperty(owner, mastery_LuckyCheatDeath.name) or 0;
		applyAmount = applyAmount + adjustValue;
	end
	if RandomTest(100 - applyAmount) then
		return;
	end
	
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', true);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Sleep(1.5);
	local resurrectID = ds:Resurrect(objKey);
	local particleID = ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/CheatDeath', 2);
	ds:Connect(particleID, resurrectID, 0);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	local hpUpdate = Result_PropertyUpdated('HP', owner.MaxHP, owner, true);
	hpUpdate.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_Resurrect(owner, 'Normal', true, mastery));
	table.insert(actions, Result_AddBuff(owner, owner, mastery.Buff.name, 1));
	table.insert(actions, hpUpdate);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	-- 빗나간 죽음
	if mastery_LuckyCheatDeath then
		SetInstantProperty(owner, mastery_LuckyCheatDeath.name, nil);
	end
	return unpack(actions);
end
-- 특성 불살
function Mastery_DoNotKill_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner or eventArg.Unit == owner then
		return;
	end
	local buff = GetBuff(owner, mastery.Buff.name );
	if not buff then
		return;
	end	
	local actions = {};	
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, -1 * buff.Lv);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end

-- 특성 : 겨울잠
function Mastery_Hibernation_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or GetBuff(owner, 'Rebirth') then
		return;
	end
	
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', true);
	ds:Sleep(0.5);
	ds:Resurrect(objKey);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	local hpUpdate = Result_PropertyUpdated('HP', 1, owner, true);
	hpUpdate.sequential = true;
	return Result_Resurrect(owner, 'Normal', true, mastery), Result_AddBuff(owner, owner, 'Rebirth', 1), Result_AddBuff(owner, owner, mastery.Buff.name, 1, nil,true), hpUpdate;
end
-- 특성 원령
function Mastery_VindictiveSpirit_UnitDead(eventArg, mastery, owner, ds)
	local killer = eventArg.Killer;
	if killer == nil or killer == owner then
		return;
	end
	local actions = {};
	local targetKey = GetObjKey(killer);
	local ownerKey = GetObjKey(owner);
	
	local cam = ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false);
	local f = ds:ForceEffect(ownerKey, '_CENTER_', targetKey, '_CENTER_', 'VindictiveSpirit');
	InsertBuffActions(actions, owner, killer, mastery.Buff.name, 1);
	actions[#actions]._ref = f;
	actions[#actions]._ref_offset = -1;
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', true);
	return unpack(actions);
end
-- 특성 희생
function Mastery_Sacrifice_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local targetList = {};
	local mission = GetMission(owner);
	local range = CalculateRange(owner, mastery.Range, GetPosition(owner));
	for i, pos in ipairs(range) do
		local target = GetObjectByPosition(mission, pos);
		if target and owner ~= target and GetRelation(owner, target) == 'Team' then
			table.insert(targetList, target);
		end
	end
	if #targetList == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', true);	
	local applyAct = -1 * mastery.ApplyAmount2;
	for _, target in ipairs(targetList) do
		local targetKey = GetObjKey(target);
		local added, reasons = AddActionApplyAct(actions, owner, target, applyAct, 'Friendly');
		if added then
			ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1);
	end
	return unpack(actions);
end
-- 이타주의자
function Mastery_Altruist_UnitDead_Self(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local targetList = {};
	local mission = GetMission(owner);
	local range = CalculateRange(owner, mastery.Range, GetPosition(owner));
	for i, pos in ipairs(range) do
		local target = GetObjectByPosition(mission, pos);
		if target and owner ~= target and GetRelation(owner, target) == 'Team' then
			table.insert(targetList, target);
		end
	end
	if #targetList == 0 then
		return;
	end
	local actions = {};
	local applyAct = -1 * mastery.ApplyAmount2;
	for _, target in ipairs(targetList) do
		local addSp = target.MaxSP - target.SP;
		AddSPPropertyActionsObject(actions, target, addSp, true, ds, true);
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', true);
	return unpack(actions);
end
-- 특성 지옥문
function Mastery_HellGate_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local killer = eventArg.Killer;
	
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local mission = GetMission(owner);
	local targetList = GetTargetInRangeSight(owner, mastery.Range, 'Enemy', true);
	
	local firstForce = nil;
	local cam = ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	for index, target in ipairs (targetList) do
		if target ~= killer then
			local targetKey = GetObjKey(target);
			local f = ds:ForceEffect(objKey, '_CENTER_', targetKey, '_CENTER_', 'VindictiveSpirit');
			InsertBuffActions(actions, owner, target, mastery.Buff.name, 1);
			actions[#actions]._ref = f;
			actions[#actions]._ref_offset = -1;
			if firstForce then
				ds:Connect(f, firstForce, 0);
			else
				firstForce = f;
			end
		end
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', true);
	return unpack(actions);
end
-- 특성 성난 황소
function Mastery_AngryBull_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or GetRelation(owner, eventArg.Unit) ~= 'Team'
		or owner.Affiliation.name ~= eventArg.Unit.Affiliation.name
		or eventArg.Unit.Obstacle then
		return;
	end
	local actions = {};	
	local pos = GetPosition(eventArg.Unit);
	if not IsInSight(owner, pos, true) then
		return;
	end
	local masteryBuff = GetBuff(owner, mastery.Buff.name);
	if masteryBuff and masteryBuff.Life == masteryBuff.Turn then
		return;
	end
	local objKey = GetObjKey(owner);
	local connectID = nil;
	if not masteryBuff and not GetBuffStatus(owner, 'Unconscious', 'Or') then
		local aniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
		connectID = aniID;
	end
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if connectID == nil then
		connectID = masteryEventID;
	else
		ds:Connect(masteryEventID, connectID, 0);
	end
	ds:SetCommandLayer(connectID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(connectID);
	local chatID = ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	ds:Connect(chatID, masteryEventID, 0);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 특성 백호
function IsAllyRelation(from, to)
	local relation = GetRelation(from, to);
	return relation == 'Team' or relation == 'Ally';
end
function Mastery_WhiteTiger_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer == owner 
		or not IsAllyRelation(owner, eventArg.Killer)
		or owner.Affiliation.name ~= eventArg.Killer.Affiliation.name
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.Unit.Obstacle then
		return;
	end
	local actions = {};	
	local pos = GetPosition(eventArg.Killer);
	if not IsInSight(owner, pos, true) then
		return;
	end
	local masteryBuff = GetBuff(owner, mastery.Buff.name);
	if masteryBuff and masteryBuff.Life == masteryBuff.Turn then
		return;
	end
	local objKey = GetObjKey(owner);
	local connectID = nil;
	if not masteryBuff and not GetBuffStatus(owner, 'Unconscious', 'Or') then
		local aniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
		connectID = aniID;
	end
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if connectID == nil then
		connectID = masteryEventID;
	else
		ds:Connect(masteryEventID, connectID, 0);
	end
	ds:SetCommandLayer(connectID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(connectID);
	local chatID = ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	ds:Connect(chatID, masteryEventID, 0);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 특성 타오르는 불꽃
function Mastery_BurningFlame_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner then
		return;
	end
	if not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	local actions = {};
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Fire', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end
-- 일반
function Mastery_NormalObject_UnitDead(eventArg, mastery, owner, ds)	
	local actions = {};
	
	local moveCam = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	local lookPos = GetPosition(owner);
	local enableId = ds:EnableIf('TestPositionIsVisible', lookPos);
	ds:Connect(enableId, moveCam, -1);
	ds:SetCommandLayer(enableId, game.DirectingCommand.CM_SECONDARY);
	local delay = ds:Sleep(1.5);
	ds:SetCommandLayer(delay, game.DirectingCommand.CM_SECONDARY);
	ds:Connect(delay, enableId, 0);
	local destroyedMonType = GetInstantProperty(owner, 'DestroyedMonsterType');
	if destroyedMonType then
		local direction = GetDirection(owner);
		local clearDying = Result_ClearDyingObjects();
		clearDying._ref = delay;
		clearDying._ref_offset = 0;
		table.insert(actions, clearDying);
		local destroy = Result_CreateMonster(GenerateUnnamedObjKey(GetMission(owner)), destroyedMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		destroy._ref = delay;
		destroy._ref_offset = 0;
		table.insert(actions, destroy);
	end
	return unpack(actions);
end
-- 인화성
function Mastery_FlammableObject_UnitDead(eventArg, mastery, owner, ds)
	local flameExplosionInitializer = function(sprayObject, args)
		SetInstantProperty(sprayObject, 'MonsterType', 'Explosion');
		if eventArg.Killer then
			SetExpTaker(sprayObject,GetExpTaker(eventArg.Killer));
		end
		UNIT_INITIALIZER(sprayObject, sprayObject.Team, {Patrol = false});
	end;
	
	local usingPos = GetPosition(owner);
	local useAbilityName = owner.Ability[1].name;

	local explosionObjKey = GenerateUnnamedObjKey(GetMission(owner));
	local createAction = Result_CreateMonster(explosionObjKey, 'Explosion', usingPos, '_neutral_',  flameExplosionInitializer, {}, 'DoNothingAI', nil, true);
	local mission = GetMission(owner);
	ApplyActions(mission, { createAction }, false);
	local explosionObj = GetUnit(mission, explosionObjKey);
	-- 터지는 오브젝트의 MaxHP 비례 데미지 때문에, 생성된 오브젝트의 Base_MaxHP를 원본 오브젝트의 MaxHP로 덮어씀
	explosionObj.Base_MaxHP = owner.MaxHP;
	InvalidateObject(explosionObj);
	local abilityUse = Result_UseAbility(explosionObj, useAbilityName, usingPos, nil, true);
	abilityUse.sequential = true;
	
	local actions = {};
	table.insert(actions, Result_AddBuff(owner, owner, 'Burning', 1, nil, true, false, true));
	table.insert(actions, abilityUse);
	
	local destroyedMonType = GetInstantProperty(owner, 'DestroyedMonsterType');
	if destroyedMonType then
		local direction = GetDirection(owner);
		local destroy = Result_CreateMonster(GenerateUnnamedObjKey(GetMission(owner)), destroyedMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		destroy.sequential = true;
		local clearDying = Result_ClearDyingObject(owner);
		clearDying.sequential = true;
		table.insert(actions, destroy);
		table.insert(actions, clearDying);
	end
	return unpack(actions);
end
function Mastery_Obstacle_UnitDead(eventArg, mastery, owner, ds)
	local mission = GetMission(owner);
	local obstacleCls = GetClassList('Obstacle')[GetInstantProperty(owner, 'ObstacleType')];
	if obstacleCls.DestroyReward <= 0 then
		return;
	end
	mission.Instance.IllegalObjectReward = mission.Instance.IllegalObjectReward + obstacleCls.DestroyReward;
	mission.Instance.Obstacle[obstacleCls.name].DestroyCount = mission.Instance.Obstacle[obstacleCls.name].DestroyCount + 1;
end
-- 드라키 알
function Mastery_HatchedObject_UnitDead(eventArg, mastery, owner, ds)
	if owner.HP > 0 then
		return;
	end
	local actions = {};
	
	ds:PlayParticle(GetObjKey(owner), '_BOTTOM_', 'Particles/Dandylion/Impact_Blunt2', 2, false, false, true);
	local moveCam = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	local lookPos = GetPosition(owner);
	local enableId = ds:EnableIf('TestPositionIsVisible', lookPos);
	ds:Connect(enableId, moveCam, -1);
	ds:SetCommandLayer(enableId, game.DirectingCommand.CM_SECONDARY);
	local delay = ds:Sleep(1.5);
	ds:SetCommandLayer(delay, game.DirectingCommand.CM_SECONDARY);
	ds:Connect(delay, enableId, 0);
	local destroyedMonType = GetInstantProperty(owner, 'DestroyedMonsterType');
	if destroyedMonType then
		local direction = GetDirection(owner);
		local clearDying = Result_ClearDyingObjects();
		clearDying._ref = delay;
		clearDying._ref_offset = 0;
		table.insert(actions, clearDying);
		local destroy = Result_CreateMonster(GenerateUnnamedObjKey(GetMission(owner)), destroyedMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		destroy._ref = delay;
		destroy._ref_offset = 0;
		table.insert(actions, destroy);
	end
	return unpack(actions);
end
function Mastery_Deathblow_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo ==nil
		or not eventArg.TargetInfo.IsDead
		or eventArg.TargetInfo.PrevHP ~= eventArg.TargetInfo.MaxHP then
		return;
	end
	
	mastery.DuplicateApplyChecker = 1;
	
	ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
	local actions = {};
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end
function Mastery_Bloodbath_UnitKilled(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or not IsEnemy(owner, eventArg.Unit)
		or not HasBuffType(eventArg.Unit, nil, nil, mastery.BuffGroup.name)
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	if owner.TurnState.TurnEnded then
		local added, reasons = AddActionApplyAct(actions, owner, owner, -1 * mastery.ApplyAmount, 'Friendly');
		if added then
			ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = -1 * mastery.ApplyAmount, Delay = true });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	else
		table.append(actions, {GetInitializeTurnActions(owner)});
		table.insert(actions, Result_FireWorldEvent('ActionPointRestored', {Unit = owner}, self));
	end
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_Bloodbath_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
function Mastery_Rampage_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo == nil
		or not eventArg.TargetInfo.IsDead then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = -mastery.ApplyAmount });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_Rampage_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
function Mastery_BloodWind_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or eventArg.DamageInfo == nil
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo == nil
		or not eventArg.TargetInfo.IsDead then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = -mastery.ApplyAmount });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	AddSPPropertyActions(actions, owner, 'Wind', mastery.ApplyAmount2, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_BloodWind_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-- 특성 승리의 포효
function Mastery_VictoryShout_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or eventArg.DamageInfo == nil
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo == nil
		or not eventArg.TargetInfo.IsDead then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	AddSPPropertyActions(actions, owner, owner.ESP.name, mastery.ApplyAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_VictoryShout_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-- 특성 광견.
function Mastery_CrazyDog_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or eventArg.DamageInfo == nil
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.TargetInfo == nil
		or not eventArg.TargetInfo.IsDead then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	AddSPPropertyActions(actions, owner, owner.ESP.name, mastery.ApplyAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_CrazyDog_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-- 영혼 인도자
function Mastery_SoulGuide_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner 
		or eventArg.Unit.Obstacle 
		or not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end
	-- 생명체가 아니면 리턴.
	local target = eventArg.Unit;
	if not target.Race.Life then
		return;
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
end
function Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, explodeAbility, directingConfig, team)
	local flameExplosionInitializer = function(sprayObject, args)
		SetInstantProperty(sprayObject, 'MonsterType', 'Explosion');
		SetInstantProperty(sprayObject, 'NoTeamUnitCounter', true);
		if eventArg.Killer then
			SetExpTaker(sprayObject,GetExpTaker(eventArg.Killer));
		end
		UNIT_INITIALIZER(sprayObject, sprayObject.Team, {Patrol = false});
	end;
	
	local usingPos = GetPosition(owner);
	local useAbilityName = explodeAbility;

	local explosionObjKey = GenerateUnnamedObjKey(GetMission(owner));
	local createAction = Result_CreateMonster(explosionObjKey, 'Explosion', usingPos, team or '_neutral_',  flameExplosionInitializer, {}, 'DoNothingAI', nil, true);
	local mission = GetMission(owner);
	ApplyActions(mission, { createAction }, false);
	local explosionObj = GetUnit(mission, explosionObjKey);
	-- 터지는 오브젝트의 MaxHP 비례 데미지 때문에, 생성된 오브젝트의 Base_MaxHP를 원본 오브젝트의 MaxHP로 덮어씀
	explosionObj.Base_MaxHP = owner.MaxHP;
	InvalidateObject(explosionObj);
	local abilityUse = Result_UseAbility(explosionObj, useAbilityName, usingPos, nil, true, directingConfig or {});
	abilityUse.sequential = true;
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead_Self', false);
	
	return abilityUse, Result_DestroyObject(explosionObj, false, true);
end
-- 얼음주머니
function Mastery_IceSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, mastery.ChainAbility);
end
-- 번개주머니
function Mastery_LightningSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, mastery.ChainAbility);
end
-- 독주머니
function Mastery_VenomSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, mastery.ChainAbility);
end
-- 불꽃주머니
function Mastery_FlameSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, mastery.ChainAbility);
end
-- 거미줄 주머니
function Mastery_WebSac_UnitDead(eventArg, mastery, owner, ds)
	return Mastery_Explode_UnitDead_Share(eventArg, mastery, owner, ds, 'ToxicLeakage_WebSac', nil, GetTeam(owner));
end
-- 티마
function Mastery_Tima_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner or not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	if not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end	
	-- 어빌리티 데미지인 경우에만 DuplicateApplyChecker를 사용한다.
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability' then
		if mastery.DuplicateApplyChecker > 0 then
			return;
		end
		mastery.DuplicateApplyChecker = 1;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	-- 코스트
	local addCost = mastery.ApplyAmount;
	local _, reasons = AddActionCost(actions, owner, addCost, true);			
	ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end
-- 동질감
function Mastery_SenseOfKinship_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer == owner 
		or not IsAllyRelation(owner, eventArg.Killer)
		or not IsEnemy(owner, eventArg.Unit)
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local pos = GetPosition(eventArg.Killer);
	if not IsInSight(owner, pos, true) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 거짓 정보
function Mastery_FakeInformation_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Killer == owner then
		return;
	end
	local actions = {};
	local target = eventArg.Killer;
	local targetKey = GetObjKey(target);
	local applyAct = mastery.ApplyAmount;
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	local added, reasons = AddActionApplyAct(actions, owner, target, applyAct, 'Hostile');
	if added then
		ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(target, ds, reasons);
	return unpack(actions);
end
-- 생존 모드
function Mastery_Module_SurvivalMode_UnitDead(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner then
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	local target = eventArg.Unit;
	if SafeIndex(target, 'Race', 'name') ~= 'Machine' then
		return;
	end
	local targetPos = GetPosition(target);
	if not IsInSight(owner, targetPos, true) then
		return;
	end
	-- 체력 충분
	if owner.HP / owner.MaxHP > mastery.ApplyAmount / 100 then
		return;
	end
	-- 연료 부족 or 이동 불가
	if owner.Cost < mastery.ApplyAmount4 or not owner.Movable then
		return;
	end
	local movePos = GetMovePosition(owner, targetPos, 1.8, true, nil, true);
	local mission = GetMission(owner);
	if not IsValidPosition(mission, movePos) or GetDistance3D(movePos, targetPos) > 1.8 then
		return;
	end
	local objKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Move(objKey, movePos);
	ds:LookAt(objKey, targetKey);
	ds:Sleep(1.5);
	ds:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/SecondHeart', 5);
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');	
	-- 비용 소모
	AddActionApplyActForDS(actions, owner, mastery.ApplyAmount3, ds, 'Cost');
	local resultCost = AddActionCostForDS(actions, owner, -mastery.ApplyAmount4, true, nil, ds);
	owner.Cost = resultCost;
	-- 연료 회복
	if target.Cost > 0 then
		AddActionCostForDS(actions, owner, target.Cost, true, nil, ds);		
	end
	-- 체력 회복
	local addHP = target.MaxHP * mastery.ApplyAmount2/100;
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false); 
	-- 자율 행동 강화 프로그램
	local mastery_Module_AutoAction = GetMasteryMastered(GetMastery(owner), 'Module_AutoAction');
	if mastery_Module_AutoAction then
		AddActionApplyActForDS(actions, owner, -mastery_Module_AutoAction.ApplyAmount2, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_Module_AutoAction, owner, 'UnitDead');
	end	
	return unpack(actions);
end
-- 나는 히어로 아이린이다!
function Mastery_ImHeroIrene_UnitDead(eventArg, mastery, owner, ds)
	if owner == eventArg.Unit
		or not IsTeamOrAlly(owner, eventArg.Unit)
		or not IsInSight(owner, GetPosition(eventArg.Unit), true)
		or eventArg.Unit.Obstacle then
		return;
	end
	-- 어빌리티 데미지인 경우에만 DuplicateApplyChecker를 사용한다.
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability' then
		-- 히어로의 책임감 특성으로 버프가 걸렸을 수 있으므로, PreAbilityUsing에서 미리 확인한 버프 유무를 사용함
		local hasBuff = GetInstantProperty(owner, mastery.name);
		if not hasBuff or mastery.DuplicateApplyChecker > 0 then
			return;
		end
		mastery.DuplicateApplyChecker = 1;
	else
		-- 버프 체크
		if not HasBuff(owner, mastery.SubBuff.name) then
			return;
		end	
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitDead');
	if owner.TurnState.TurnEnded then
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	else
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 유닛 부활. [UnitResurrect]
-------------------------------------------------------------------------------
-- 히어로는 포기하지 않는다.
function Mastery_HeroDontGiveUp_UnitResurrect(eventArg, mastery, owner, ds)
	MasteryActivatedHelper(ds, mastery, owner, 'UnitResurrect_Self');
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	
	local mastery_ImHeroIrene = GetMasteryMastered(GetMastery(owner), 'ImHeroIrene');
	if mastery_ImHeroIrene then
		local activate = false;
		Linq.new(GetAllUnitInSight(owner, true))
		:where(function(o) return owner ~= o and IsAllyOrTeam(owner, o); end)
		:foreach(function(o)
			InsertBuffActions(actions, owner, o, mastery_ImHeroIrene.Buff.name, 1, true);
			activate = true;
		end);
		if activate then
			MasteryActivatedHelper(ds, mastery_ImHeroIrene, owner, 'UnitResurrect_Self');
		end
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
		if not owner.TurnState.TurnEnded then
			table.append(actions, {GetInitializeTurnActions(owner)});
		end
	end
	return unpack(actions);
end
function Mastery_LastFlame_UnitResurrect(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};	
	local invoker = eventArg.ResurrectInfo.invoker;
	if invoker and invoker.name == 'Phoenix' then
		if owner.Overcharge > 0 then
			table.insert(actions, Result_PropertyUpdated('Overcharge', owner.OverchargeDuration, owner, false, true));
		else
			AddSPPropertyActions(actions, owner, owner.ESP.name, owner.MaxSP - owner.SP, true, ds, true);
		end
	end
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 유닛 이동시작. [UnitMoveStarted]
-------------------------------------------------------------------------------
-- 이동중 블락 개시
function Mastery_UnitMovingBlocker_UnitMoveStarted(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 1;
end
-- 거미줄 잇기
function Mastery_JoinCobweb_UnitMoveStarted(eventArg, mastery, owner, ds)
	local fieldEffects = GetFieldEffectByPosition(owner, eventArg.BeginPosition);
	local enabled = false;
	for _, instance in ipairs(fieldEffects) do
		local type = instance.Owner.name;
		if type == 'Web' then
			enabled = true;
			break;
		end
	end
	
	if not enabled then
		return;
	end
	
	mastery.DuplicateApplyChecker = 1;
end
-- 거미줄 재단사
function Mastery_WebTailor_UnitMoveStarted(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 1;
end
-- 고속 호버링
function Mastery_Module_HighSpeedHovering_UnitMoveStarted(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.TurnState.TurnEnded then
		return;
	end
	
	local satisfied = false;
	if eventArg.MovingForAbility then
		local totalPathLength = 0;
		local prevPos = eventArg.StraightPath[1];
		for i, pos in ipairs(eventArg.StraightPath) do
			totalPathLength = totalPathLength + GetDistance3D(prevPos, pos);
			prevPos = pos;
		end
		satisfied = totalPathLength > mastery.ApplyAmount;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
end
-----------------------------------------------------------------------
-- 유닛 이동. [UnitMoved]
-------------------------------------------------------------------------------
-- 경공
function Mastery_AirWalk_UnitMoved(eventArg, mastery, owner, ds)
	local satisfied = false;
	
	if eventArg.MovingForAbility then		
		satisfied = true;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	
	local actions = {};
	if eventArg.Position.z - eventArg.BeginPosition.z > 15 then
		AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	elseif eventArg.Position.z - eventArg.BeginPosition.z < -15 then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	end
	
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitMoved_Self');
	return unpack(actions);
end
-- 이동중 블락 해제
function Mastery_UnitMovingBlocker_UnitMoved(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
-- 거미줄 잇기
function Mastery_JoinCobweb_UnitMoved(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
-- 거미줄 재단사
function Mastery_WebTailor_UnitMoved(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
	
	local fieldEffectCount = GetInstantProperty(owner, mastery.name) or 0;
	SetInstantProperty(owner, mastery.name, nil);
	if fieldEffectCount <= 0 then
		return;
	end
	
	local stepCount = math.floor(fieldEffectCount / mastery.ApplyAmount);	-- ApplyAmount 당
	if stepCount <= 0 then
		return;
	end
	local applyAct = -1 * stepCount * mastery.ApplyAmount2;			-- ApplyAmount2 만큼 감소
	
	local actions = {};
	local ownerKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'FieldEffectAdded');
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 교류발전기
function Mastery_Module_Alternator_UnitMoved(eventArg, mastery, owner, ds)	
	local distance = 0;
	local prevPos = nil;
	for _, p in ipairs(eventArg.StraightPath) do
		if prevPos then
			distance = distance + GetDistance3D(p, prevPos);
		end
		prevPos = p;
	end
	local addFuel = math.floor(distance);
	-- 고속 호버링
	local mastery_Module_HighSpeedHovering = GetMasteryMastered(GetMastery(owner), 'Module_HighSpeedHovering');
	if mastery_Module_HighSpeedHovering then
		addFuel = addFuel + math.floor(addFuel * mastery_Module_HighSpeedHovering.ApplyAmount2 / 100);
	end
	local actions = {};
	local _, reasons = AddActionCost(actions, owner, addFuel, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', {CostType = owner.CostType.name, Count = addFuel});
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitMoved_Self');
	return unpack(actions);
end
-- 고속 주행 프로그램
function Mastery_Module_HighSpeedHover_UnitMoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.TurnState.TurnEnded then
		return;
	end
	
	local satisfied = false;
	if eventArg.MovingForAbility then
		local totalPathLength = 0;
		local prevPos = eventArg.StraightPath[1];
		for i, pos in ipairs(eventArg.StraightPath) do
			totalPathLength = totalPathLength + GetDistance3D(prevPos, pos);
			prevPos = pos;
		end
		satisfied = totalPathLength > mastery.ApplyAmount;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	
	local enhancementCount = mastery.CustomCacheData['Application_Enhancement'] or 0;
	local controlCount = mastery.CustomCacheData['Application_Control'] or 0;
	
	local actions = {};
	if enhancementCount > 0 then
		local stepCount = math.floor(enhancementCount / mastery.ApplyAmount2);	-- ApplyAmount2 당
		local applyAct = -1 * stepCount * mastery.ApplyAmount3;				-- ApplyAmount3 만큼 감소
		local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
		if added then
			ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
	if controlCount > 0 then
		local stepCount = math.floor(controlCount / mastery.ApplyAmount2);	-- ApplyAmount2 당
		local addCost = stepCount * mastery.ApplyAmount3;						-- ApplyAmount3 만큼 증가
		local _, reasons = AddActionCost(actions, owner, addCost, true);
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', {CostType = owner.CostType.name, Count = addCost});
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
	if enhancementCount > 0 or controlCount > 0 then
		if not eventArg.MovingForDirect then
			ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
		end
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitMoved'});
	end
	
	return unpack(actions);
end
-- 질주
function Mastery_WindRush_UnitMoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.TurnState.TurnEnded then
		return;
	end
	
	local satisfied = false;
	
	if eventArg.MovingForAbility then
		local totalPathLength = 0;
		local prevPos = eventArg.StraightPath[1];
		for i, pos in ipairs(eventArg.StraightPath) do
			totalPathLength = totalPathLength + GetDistance3D(prevPos, pos);
			prevPos = pos;
		end
		
		satisfied = totalPathLength > mastery.ApplyAmount;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	
	local masteryTable = GetMastery(owner);
	local hasteAmount = mastery.ApplyAmount2;
	local mastery_GreatMilitaryAffairs = GetMasteryMastered(masteryTable, 'GreatMilitaryAffairs');
	if mastery_GreatMilitaryAffairs then
		hasteAmount = hasteAmount + mastery_GreatMilitaryAffairs.ApplyAmount;
	end
	
	local actions = {};
	local applyAct = -1 * hasteAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	if not eventArg.MovingForDirect then
		ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitMoved'});
	if mastery_GreatMilitaryAffairs then
		MasteryActivatedHelper(ds, mastery_GreatMilitaryAffairs, owner, 'UnitMoved');
	end
	
	-- 전장을 뚫어라
	local mastery_DrillBattleField = GetMasteryMastered(masteryTable, 'DrillBattleField');
	if mastery_DrillBattleField then
		InsertBuffActions(actions, owner, owner, mastery_DrillBattleField.Buff.name, 1, true);
		MasteryActivatedHelper(ds, mastery_DrillBattleField, owner, 'UnitMoved');
	end
	
	return unpack(actions);
end
-- 바람길
function Mastery_Windway_UnitMoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.TurnState.TurnEnded then
		return;
	end
	
	local satisfied = false;
	
	if eventArg.MovingForAbility then
		local totalPathLength = 0;
		local prevPos = eventArg.StraightPath[1];
		for i, pos in ipairs(eventArg.StraightPath) do
			totalPathLength = totalPathLength + GetDistance3D(prevPos, pos);
			prevPos = pos;
		end
		
		satisfied = totalPathLength > mastery.ApplyAmount;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	
	local actions = {};
	local applySP = mastery.ApplyAmount2;
	AddSPPropertyActions(actions, owner, 'Wind', applySP, true, ds, true);
	if not eventArg.MovingForDirect then
		ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitMoved'});
	
	-- 돌풍
	local mastery_Squall = GetMasteryMastered(GetMastery(owner), 'Squall');
	if mastery_Squall then
		AddActionApplyActForDS(actions, owner, -mastery_Squall.ApplyAmount, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_Squall, owner, 'UnitMoved');
	end
	
	return unpack(actions);
end
-- 무모한 돌진
function Mastery_RushHeadlong_UnitMoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.TurnState.TurnEnded then
		return;
	end
	
	local satisfied = false;
	
	if eventArg.MovingForAbility then
		local totalPathLength = 0;
		local prevPos = eventArg.StraightPath[1];
		for i, pos in ipairs(eventArg.StraightPath) do
			totalPathLength = totalPathLength + GetDistance3D(prevPos, pos);
			prevPos = pos;
		end
		
		satisfied = totalPathLength > mastery.ApplyAmount;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	
	mastery.DuplicateApplyChecker = 1;
end
-- 자율 운동 AI
function Mastery_EnhancedMovementAI_UnitMoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.TurnState.TurnEnded then
		return;
	end
	
	local satisfied = false;
	if eventArg.MovingForAbility then
		local totalPathLength = 0;
		local prevPos = eventArg.StraightPath[1];
		for i, pos in ipairs(eventArg.StraightPath) do
			totalPathLength = totalPathLength + GetDistance3D(prevPos, pos);
			prevPos = pos;
		end
		satisfied = totalPathLength > mastery.ApplyAmount;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	
	local hasteAmount = mastery.ApplyAmount2;
	
	local actions = {};
	local applyAct = -1 * hasteAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	if not eventArg.MovingForDirect then
		ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitMoved'});
		
	return unpack(actions);
end
-- 기선제압
function Mastery_Forestallment_UnitMovedSingleStep(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0 
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or mastery.DuplicateApplyChecker > 0
		or owner.IsMovingNow > 0
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= 1.8
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	local mission = GetMission(owner);
	local alreadyObj = GetObjectByPosition(mission, eventArg.Position);
	if alreadyObj ~= nil and alreadyObj ~= eventArg.Unit then
		-- 이 위치에 이미 누군가 있어!
		return;
	end
	
	local overwatch = FindAbility(owner, owner.OverwatchAbility);
	if overwatch == nil or overwatch.HitRateType ~= 'Melee' then
		return;
	end
	local rangeClsList = GetClassList('Range');
	local range = CalculateRange(owner, overwatch.TargetRange, GetPosition(owner));
	local p = eventArg.Position;
	if PositionInRange(range, p) then
		local targetKey = GetObjKey(eventArg.Unit);
		local eventCmd = ds:SubscribeFSMEvent(targetKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos=p}, true, true);
		if eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
			ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
			ds:Connect(eventArg.MoveID, eventCmd, 0);
		else
			ds:SetConditional(eventCmd);
		end
		
		local chatID = ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitMovedSingleStep'});
		ds:Connect(chatID, eventCmd, -1);		
		local hitCount = eventArg.OverwatchHitCount or 0;
		local battleEvents = {{Object = owner, EventType = mastery.name}};
		local targetPos = GetPosition(eventArg.Unit);
		local resultModifier = {ReactionAbility=true, Forestallment=true, Moving=true, BattleEvents = battleEvents}
		-- 선의 선
		local mastery_AcuityForestallment = GetMasteryMastered(GetMastery(owner), 'AcuityForestallment');
		if mastery_AcuityForestallment then
			resultModifier['Inevitable'] = true;
			resultModifier['AttackerState'] = 'Critical';
			resultModifier['DefenderState'] = 'Hit';
		end		
		local abilityAction = Result_UseAbilityTarget(owner, owner.OverwatchAbility, eventArg.Unit, resultModifier, true, {NoCamera = true, Preemptive=true, PreemptiveOrder = hitCount});
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
		abilityAction.nonsequential = true;
		abilityAction.free_action = true;
		abilityAction._ref = eventCmd;
		abilityAction._ref_offset = -1;
		abilityAction.final_useable_checker = function()
			return GetBuffStatus(owner, 'Attackable', 'And')
				and PositionInRange(CalculateRange(owner, overwatch.TargetRange, GetPosition(owner)), eventArg.Position);
		end;
		eventArg.OverwatchHitCount = hitCount + 1;
		return abilityAction;
	end
end
-- 자동 제압 사격
function Mastery_Module_ForestallmentFire_UnitMovedSingleStep(eventArg, mastery, owner, ds)
	local applyDist = mastery.ApplyAmount;
	if applyDist == 1 then
		applyDist = 1.4;
	end
	if eventArg.Unit.HP <= 0 
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or mastery.DuplicateApplyChecker > 0
		or owner.IsMovingNow > 0
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= (applyDist + 0.4)
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	return Mastery_Module_ForestallmentFire_TestMoveStep(eventArg, mastery, owner, ds);
end
function Mastery_Module_ForestallmentFire_TestMoveStep(eventArg, mastery, owner, ds)
	local actions = {};
	if owner.Cost < mastery.ApplyAmount3 then
		return;
	end
	if not Mastery_CloseCheckFire_ActivateTest(actions, eventArg, mastery, owner, ds, mastery.ApplyAmount2) then
		return;
	end
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount3, true, nil, ds);
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
-- 근접 제압 사격
function Mastery_CloseCheckFire_UnitMovedSingleStep(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0 
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= (mastery.ApplyAmount + 0.4)
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	return Mastery_CloseCheckFire_TestMoveStep(eventArg, mastery, owner, ds);
end
function Mastery_CloseCheckFire_TestMoveStep(eventArg, mastery, owner, ds)
	local actions = {};
	if not Mastery_CloseCheckFire_ActivateTest(actions, eventArg, mastery, owner, ds, mastery.ApplyAmount2) then
		return;
	end
	return unpack(actions);
end
-- 자동 반응 사격
function Mastery_Module_CloseCheckFire_UnitMovedSingleStep(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0 
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= (mastery.ApplyAmount + 0.4)
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	return Mastery_Module_CloseCheckFire_TestMoveStep(eventArg, mastery, owner, ds);
end
function Mastery_Module_CloseCheckFire_TestMoveStep(eventArg, mastery, owner, ds)
	local actions = {};
	if owner.Cost < mastery.ApplyAmount3 then
		return;
	end
	if not Mastery_CloseCheckFire_ActivateTest(actions, eventArg, mastery, owner, ds, mastery.ApplyAmount2) then
		return;
	end
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount3, true, nil, ds);
	return unpack(actions);
end
function Mastery_CloseCheckFire_ActivateTest(actions, eventArg, mastery, owner, ds, applyAct)
	local alreadyHitSet = GetInstantProperty(owner, mastery.name) or {};
	if alreadyHitSet[GetObjKey(eventArg.Unit)] then
		return false;
	end
	local mission = GetMission(owner);
	local alreadyObj = GetObjectByPosition(mission, eventArg.Position);
	if alreadyObj == nil or alreadyObj ~= eventArg.Unit then
		-- 여기 없거나 다른 누군가가 있어!
		return false;
	end
	
	local overwatch = FindAbility(owner, owner.OverwatchAbility);
	if overwatch == nil then
		return false;
	end
	local rangeClsList = GetClassList('Range');
	local range = CalculateRange(owner, overwatch.TargetRange, GetPosition(owner));
	local p = eventArg.Position;
	if not PositionInRange(range, p) then
		return false;
	end
	
	local targetKey = GetObjKey(eventArg.Unit);
	local eventCmd = ds:SubscribeFSMEvent(targetKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos=p}, true, true);
	if eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
		ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
		ds:Connect(eventArg.MoveID, eventCmd, 0);
	else
		ds:SetConditional(eventCmd);
	end
	
	alreadyHitSet[GetObjKey(eventArg.Unit)] = true;
	SetInstantProperty(owner, mastery.name, alreadyHitSet);
	
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedCustomEvent', Args = {Mastery = mastery.name, EventType = 'Beginning', MissionChat = true} });
	-- Cost 증가
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	if action then
		ds:WorldAction(action, true);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	-- 어빌리티 사용
	local hitCount = eventArg.OverwatchHitCount or 0;
	local targetPos = GetPosition(eventArg.Unit);
	local abilityAction = Result_UseAbilityTarget(owner, owner.OverwatchAbility, eventArg.Unit, {ReactionAbility=true, CloseCheckFire=true, Moving=true, BattleEvents = battleEvents, InvokeMastery = mastery.name}, true, {NoCamera = true, Preemptive=true, PreemptiveOrder = hitCount});
	abilityAction.nonsequential = true;
	abilityAction.free_action = true;
	abilityAction._ref = eventCmd;
	abilityAction._ref_offset = -1;
	abilityAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, overwatch.TargetRange, GetPosition(owner)), eventArg.Position);
	end;
	eventArg.OverwatchHitCount = hitCount + 1;
	table.insert(actions, abilityAction);
	return true;
end
function Mastery_CounterAttack_UnitMoveStarted(eventArg, mastery, owner, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
end
function Mastery_CounterAttack_UnitMoved(eventArg, mastery, owner, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
end
function Mastery_OneSpoon_UnitMoved(eventArg, mastery, owner, ds)
	SetInstantProperty(owner, 'OneSpoonablePosCache', nil);
end
-- 분노의 일격
function Mastery_RageBlow_UnitMoved(eventArg, mastery, owner, ds)
	if owner ~= eventArg.Unit
		or mastery.DuplicateApplyChecker > 0
		or owner.HP <= 0
		or not owner.TurnState.TurnEnded
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	local overwatch = FindAbility(owner, owner.OverwatchAbility);
	if overwatch == nil or overwatch.HitRateType ~= 'Melee' then
		return;
	end
	local buffRageList = GetBuffType(owner, 'Buff', nil, 'Rage');
	if #buffRageList == 0 then
		return;
	end
	
	local GetNearUnitMap = function(targetPos)
		local nearUnitMap = {};
		local mission = GetMission(owner);
		local nearPosList = CalculateRange(owner, 'Diamond1_NoFill_Melee', targetPos);
		for _, nearPos in ipairs(nearPosList) do
			local obj = GetObjectByPosition(mission, nearPos);
			if obj and not obj.Cloaking then
				nearUnitMap[GetObjKey(obj)] = obj;
			end
		end
		return nearUnitMap;
	end;
	
	local attackTargets = {};
	local prevNearUnitMap = GetNearUnitMap(eventArg.BeginPosition);
	local nextNearUnitMap = GetNearUnitMap(eventArg.Position);
	for objKey, obj in pairs(nextNearUnitMap) do
		if prevNearUnitMap[objKey] == nil then
			table.insert(attackTargets, obj);
		end
	end
	if #attackTargets == 0 then
		return;
	end
	attackTargets = table.shuffle(attackTargets);
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	
	local ownerPos = GetPosition(owner);
	local targetPosMap = {};
	for _, target in ipairs(attackTargets) do
		targetPosMap[GetObjKey(target)] = GetPosition(target);
	end
	
	mastery.DuplicateApplyChecker = 1;
	
	for _, target in ipairs(attackTargets) do
		-- 반복 중에 사용자의 위치가 바뀌었으면 중단
		if owner.HP <= 0 or not IsSamePosition(GetPosition(owner), ownerPos) then
			break;
		end
		-- 반복 중에 대상의 위착 바뀌었으면 무시
		local targetPos = targetPosMap[GetObjKey(target)];
		if target.HP > 0 and IsSamePosition(GetPosition(target), targetPos) then
			local applyAct = mastery.ApplyAmount;
			local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
			local battleEvents = {};
			table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery.name} });
			if action then
				ds:WorldAction(action, true);
				table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
			end
			table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
			
			local overwatchAttack = Result_UseAbility(owner, overwatch.name, targetPos, {ReactionAbility = true, BattleEvents = battleEvents}, true, {});
			overwatchAttack.free_action = true;
			overwatchAttack.final_useable_checker = function()
				return GetBuffStatus(owner, 'Attackable', 'And')
					and PositionInRange(CalculateRange(owner, overwatch.TargetRange, GetPosition(owner)), targetPos)
			end;
			ds:WorldAction(overwatchAttack, true);
		end
	end
	
	mastery.DuplicateApplyChecker = 0;
end
-- 강력한 날갯짓
function Mastery_StrongWingStroke_UnitMoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.TurnState.TurnEnded then
		return;
	end
	
	local satisfied = false;
	
	if eventArg.MovingForAbility then
		local totalPathLength = 0;
		local prevPos = eventArg.StraightPath[1];
		for i, pos in ipairs(eventArg.StraightPath) do
			totalPathLength = totalPathLength + GetDistance3D(prevPos, pos);
			prevPos = pos;
		end
		
		satisfied = totalPathLength > mastery.ApplyAmount;
	else
		satisfied = eventArg.IsDash;
	end
	if not satisfied then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitMoved');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	-- 하늘 위의 암살자
	local mastery_SkyAssassin = GetMasteryMastered(GetMastery(owner), 'SkyAssassin');
	if mastery_SkyAssassin then
		MasteryActivatedHelper(ds, mastery_SkyAssassin, owner, 'UnitMoved');
		local applyAct = -1 * mastery_SkyAssassin.ApplyAmount;
		local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
		if added then
			ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
	return unpack(actions);
end
-- 고속 호버링
function Mastery_Module_HighSpeedHovering_UnitMoved(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
-----------------------------------------------------------------------
-- 이동 스탭 [UnitMovedSingleStep]
-------------------------------------------------------------------------------
-- 거미줄 잇기
function Mastery_JoinCobweb_UnitMovedSingleStep(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	local isDisable = false;
	local fieldEffects = GetFieldEffectByPosition(owner, eventArg.Position);
	for _, instance in ipairs(fieldEffects) do
		local type = instance.Owner.name;
		if type == 'Fire' or type == 'Spark' or type == 'PoisonGas' or type == 'Web' then
			isDisable = true;
			break;
		end
	end
	if isDisable then
		return;
	end
	
	local eventCmd = ds:SubscribeFSMEvent(GetObjKey(owner), 'StepForward', 'CheckUnitArrivePosition', {CheckPos=eventArg.Position}, true, true);
	if eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
		ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
		ds:Connect(eventArg.MoveID, eventCmd, 0);
	else
		ds:SetConditional(eventCmd);
	end
	
	local action = Result_AddFieldEffect('Web', {eventArg.Position}, owner);
	action._ref = eventCmd;
	action._ref_offset = -1;
	return action;
end
function Mastery_TrapSystem_UnitMovedSingleStep(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0 
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= 4 then
		return;
	end
	
	local mission = GetMission(owner);
	local alreadyObj = GetObjectByPosition(mission, eventArg.Position);
	if alreadyObj ~= nil and alreadyObj ~= eventArg.Unit then
		-- 이 위치에 이미 누군가 있어!
		return;
	end
	
	local overwatch = FindAbility(owner, GetInstantProperty(owner, 'TrapAbility'));
	if not overwatch then
		LogAndPrint('Mastery_TrapSystem_UnitMovedSingleStep', 'Trap Ability가 없다니 이게 무슨 소리요?', owner.name, GetInstantProperty(owner, 'TrapAbility'));
		return;
	end
	
	local rangeClsList = GetClassList('Range');
	local range = CalculateRange(owner, overwatch.ApplyRange, GetPosition(owner));
	local p = eventArg.Position;
	if not PositionInRange(range, p) then
		return;
	end
	
	local actions = {};
	
	local ownerKey = GetObjKey(owner);
	local trapOwner = GetExpTaker(owner);
	if trapOwner.HP > 0 then
		local trapQueue = GetInstantProperty(trapOwner, 'TrapQueue') or {};
		trapQueue = table.filter(trapQueue, function(trapKey) return trapKey ~= ownerKey; end);
		table.insert(actions, Result_UpdateInstantProperty(trapOwner, 'TrapQueue', trapQueue));
	end
	
	local targetKey = GetObjKey(eventArg.Unit);
	local eventCmd = ds:SubscribeFSMEvent(targetKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos=p}, true, true);
	if eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
		ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
		ds:Connect(eventArg.MoveID, eventCmd, 0);
	else
		ds:SetConditional(eventCmd);
	end
	local hitCount = eventArg.OverwatchHitCount or 0;
	local resultModifier = {TrapAbility=true, BattleEvents={{Object = owner, EventType = 'AbilityInvokedBeginning', Args = {Ability = overwatch.name}}}};
	-- 연쇄 효과 : 휘말림
	if eventArg.Unit.TurnState.TurnEnded then
		resultModifier.Engaging = true;
		local moveInvoker = eventArg.Invoker;
		if moveInvoker and moveInvoker.Unit then
			resultModifier.EngagingInvoker = moveInvoker.Unit;
		end
	end
	local targetPos = GetPosition(eventArg.Unit);
	local abilityAction = Result_UseAbility(owner, overwatch.name, GetPosition(owner), resultModifier, true, {NoCamera = true, Preemptive=true, PreemptiveOrder = hitCount});
	abilityAction.nonsequential = true;
	abilityAction.free_action = true;
	abilityAction._ref = eventCmd;
	abilityAction._ref_offset = -1;
	eventArg.OverwatchHitCount = hitCount + 1;
	table.insert(actions, abilityAction);
	table.insert(actions, Result_DestroyObject(owner, true));
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 턴 시작. [UnitTurnStart]
-------------------------------------------------------------------------------
-- 죽음을 경배하라.
function Mastery_Skull_UnitTurnStart(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	return unpack(actions);
end
-- 태양광 패널
function Mastery_SubSupportDevice_Solar_UnitTurnStart(eventArg, mastery, owner, ds)
	local mission = GetMission(owner);
	
	
	-- 태양광 패널
	local targetType = nil;
	local curTime = mission.MissionTime.name;
	local curWeather = mission.Weather.name
	if curTime == 'Daytime' then
		if curWeather == 'Clear' then
			targetType = 'ApplyAmount';
		elseif curWeather == 'Cloud' or curWeather == 'Fog' then
			targetType = 'ApplyAmount3';
		end
	elseif curTime == 'Morning' then
		if curWeather == 'Clear' then
			targetType = 'ApplyAmount2';
		elseif curWeather == 'Cloud' or curWeather == 'Fog' then
			targetType = 'ApplyAmount4';
		end
	end
	if targetType == nil then
		return;
	end
	
	local actions = {};
	AddActionCostForDS(actions, owner, mastery[targetType], true, nil, ds);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	
	return unpack(actions);
end
-- 다중 처리
function Mastery_MultiProcessing_UnitTurnStart(eventArg, mastery, owner, ds)
	mastery.CountChecker = 0;
end
-- 나노 스킨
function Mastery_SubSupportDevice_NonoSkin_UnitTurnStart(eventArg, mastery, owner, ds)
	if mastery.CountChecker >= mastery.ApplyAmount3
		or owner.HP / owner.MaxHP > mastery.ApplyAmount / 100 then
		return;
	end
	
	local actions = {};
	local addHP = owner.MaxHP * mastery.ApplyAmount2 / 100;
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	DirectDamage(ds, owner, '', 'DodgerBlue', 1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), 'Heal', 'Normal', 'Heal', 'Chest', true, false); 
	return unpack(actions);
end
-- 책벌레
function Mastery_Bookworm_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local debuffList = GetBuffType(owner, 'Debuff');
	if #debuffList == 0 then
		return;
	end
	for index, debuff in ipairs (debuffList) do
		table.insert(actions, Result_RemoveBuff(owner, debuff.name, true));
	end
	
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	
	return unpack(actions);
	
end
-- 자동 충전
function Mastery_AutoCharge_UnitTurnStart(eventArg, mastery, owner, ds)
	local actions = {};
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	return unpack(actions);
end
-- 생존 제어
function Mastery_Application_ControlLife_UnitTurnStart(eventArg, mastery, owner, ds)
	if owner.Cost < mastery.ApplyAmount3
		or owner.HP / owner.MaxHP >= mastery.ApplyAmount / 100 then
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	
	local actions = {};
	local addHp = math.floor(owner.MaxHP * mastery.ApplyAmount2 / 100);
	local reasons = AddActionRestoreHP(actions, owner, owner, addHp);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = -mastery.ApplyAmount3 });
	local _, reasons2 = AddActionCost(actions, owner, -math.floor(addHp * mastery.ApplyAmount3 / 100), true, true);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons2);
	DirectDamageByType(ds, owner, 'HPRestore', -1 * addHp, math.min(owner.HP + addHp, owner.MaxHP), true, false);
	
	return unpack(actions);
end
-- 대지를 부르는 자 - 5 세트
function Mastery_VendureNeguriSet5_UnitTurnStart(eventArg, mastery, owner, ds)
	if owner.SP <= 0 then
		return;
	end
	local applyDist = mastery.ApplyAmount;
	if applyDist == 1 then
		applyDist = 1.4;
	end
	local nearAllies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsAllyOrTeam(owner, o) and o.Race.name ~= 'Machine' end)
		:toList();
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	local actionID = ds:Sleep(0);
	-- 안됌..
	--ds:Connect(ds:PlayParticle(GetObjKey(owner), '_BOTTOM_', 'Particles/Dandylion/Grenade_Explosion_EMP', 1, true, true, false), actionID, 0);
	local actions = {};
	for _, a in ipairs(nearAllies) do
		local addHP = owner.SP;
		local reasons = AddActionRestoreHP(actions, owner, a, addHP);
		ReasonToUpdateBattleEventMulti(a, ds, reasons);
		DirectDamageByType(ds, a, 'VendureNeguriSet5', -1 * addHP, math.min(a.HP + addHP, a.MaxHP), false, false, actionID, 0);
	end
	return unpack(actions);	
end
-- 번개를 부르는 자 - 5 세트
function Mastery_LightningNeguriSet5_UnitTurnStart(eventArg, mastery, owner, ds)
	if owner.SP <= 0 then
		return;
	end
	local applyDist = mastery.ApplyAmount;
	if applyDist == 1 then
		applyDist = 1.4;
	end
	local nearEnemies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsEnemy(owner, o) end)
		:toList();
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	local actionID = ds:Sleep(0);
	-- 안됌..
	--ds:Connect(ds:PlayParticle(GetObjKey(owner), '_BOTTOM_', 'Particles/Dandylion/Grenade_Explosion_EMP', 1, true, true, false), actionID, 0);
	local actions = {};
	for _, e in ipairs(nearEnemies) do
		local damage = Result_Damage(owner.SP, 'Normal', 'Hit', owner, e, 'Mastery', mastery.SubType, mastery);	-- 버프에 의한 체력 변화는 스스로 주는거다!
		local realDamage, reasons = ApplyDamageTest(e, owner.SP, 'Mastery');
		local isDead = e.HP <= realDamage;
		local remainHP = math.clamp(e.HP - realDamage, 0, e.MaxHP);

		DirectDamageByType(ds, e, 'LightningNeguriSet5', owner.SP, remainHP, false, isDead, actionID, 0);
		ReasonToUpdateBattleEventMulti(e, ds, reasons, actionID, 0);
		AddMasteryDamageChat(ds, e, mastery, realDamage);
		table.insert(actions, damage);
		if realDamage > 0 then
			InsertBuffActions(actions, owner, e, mastery.Buff.name, 1, true);
		end
	end
	return unpack(actions);
end
-- 특성 히어로
function Mastery_LonelyHero_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local unitCount = #(table.filter(GetAllUnitInSight(owner, true), function(o) 
		return owner ~= o and IsTeamOrAlly(owner, o);
	end));
	if unitCount > 0 then
		return;
	end
	
	local modifier = nil;
	local buff = GetBuff(owner, mastery.Buff.name);
	if buff then
		table.insert(actions, Result_BuffPropertyUpdated('Life', buff.Turn, owner, buff.name, true));
	else
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart_Self'});
	return unpack(actions);
end
-- 꿈은 이루어진다
function Mastery_DreamComeTrue_UnitTurnStart(eventArg, mastery, owner, ds)
	local bb = GetBuffType(owner, nil, nil, 'Sleep');
	if #bb == 0 then
		local actions = {};
		if RandomTest(mastery.ApplyAmount) then
			MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
			InsertBuffActions(actions, owner, owner, 'Sleep', 1);
		end
		return unpack(actions);
	end
	
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	
	local goodBuff = goodBuffPicker:PickBuff();
	if goodBuff == nil then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	local actions = {};
	InsertBuffActions(actions, owner, owner, goodBuff, 1);
	return unpack(actions);
end
-- 압도
function Mastery_Devastate_UnitTurnStart(eventArg, mastery, owner, ds)
	local meleeRange = GetMeleeDistancePositions(owner);
	local candidatePicker = RandomPicker.new();
	for _, p in pairs(meleeRange) do
		local obj = GetObjectByPosition(GetMission(owner), p);
		if obj and IsEnemy(owner, obj) and not obj.Cloaking then
			candidatePicker:addChoice(GetHate(owner, obj) + 1, obj);
		end
	end
	
	local target = candidatePicker:pick();
	if not target then
		return;
	end
	
	local applyActAction, reasons = GetApplyActAction(owner, mastery.ApplyAmount, nil, 'Cost');
	local battleEvents = {};
	table.insert(battleEvents, {Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery.name}});
	if applyActAction then
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = mastery.ApplyAmount } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	
	local resultModifier = {ReactionAbility = true, Devastate = true, BattleEvents = battleEvents};
	local directingConfig = {};
	local success, abilityAction = GetMeleeAbilityUseAction(owner, target, resultModifier, directingConfig);
	
	if not success then
		return;
	end
	if applyActAction then
		ds:WorldAction(applyActAction, true);
	end
	
	return abilityAction;
end
-- 샘솟는 마력
function Mastery_SpellAcceleration_UnitTurnStart(eventArg, mastery, owner, ds)
	if not HasBuff(owner, mastery.SubBuff.name) then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart');
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, mastery.ApplyAmount);
	return unpack(actions);
end
-- 마력 복사
function Mastery_SpellPowerCopy_UnitTurnStart(eventArg, mastery, owner, ds)
	local buff = GetBuff(owner, mastery.Buff.name);
	if buff == nil then
		return;
	end
	local addLv = buff.Lv * (mastery.ApplyAmount - 1);
	local nextLv = math.min(buff.Lv + addLv, buff:MaxStack());
	local addLvReal = nextLv - buff.Lv;
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff.name, addLv, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	-- 마력 가속 회로
	local masteryTable = GetMastery(owner);
	local mastery_AccelerationCircuit = GetMasteryMastered(masteryTable, 'AccelerationCircuit');
	if mastery_AccelerationCircuit then
		local stepCount = math.floor(addLvReal / mastery_AccelerationCircuit.ApplyAmount2);	-- ApplyAmount 당
		if stepCount > 0 then
			local applyAct = -1 * stepCount * mastery_AccelerationCircuit.ApplyAmount;		-- ApplyAmount 만큼 감소
			local ownerKey = GetObjKey(owner);
			MasteryActivatedHelper(ds, mastery_AccelerationCircuit, owner, 'UnitTurnStart_Self');
			local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
			if added then
				ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
			end
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		end
	end
	return unpack(actions);
end
-- 특성 전광석화 초기화
function Mastery_LightningReflexes_UnitTurnStart(eventArg, mastery, owner, ds)
	if owner ~= eventArg.Unit then
		return;
	end
	SetInstantProperty(owner, 'LightningReflexesUsed', nil);		-- 전광석화 사용여부 초기화
end
function Mastery_Shared_SpRegen_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local addAmount = mastery.ApplyAmount;
	-- 불꽃놀이
	local mastery_Firework = GetMasteryMastered(GetMastery(owner), 'Firework');
	if mastery_Firework then
		addAmount = addAmount + mastery_Firework.ApplyAmount;
	end	
	local actions = {};
	AddSPPropertyActions(actions, owner, 'Fire', addAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
	if mastery_Firework then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_Firework.name, EventType = 'UnitTurnStart'});
	end
	return unpack(actions);
end
-- 지옥불 반지
function Mastery_Ring_Hellfire_UnitTurnStart(eventArg, mastery, owner, ds)
	return Mastery_Shared_SpRegen_UnitTurnStart(eventArg, mastery, owner, ds);
end
-- EternalFlame	꺼지지 않는 불꽃 / 시작 턴 불 SP n 개 생성 구문.
function Mastery_EternalFlame_UnitTurnStart(eventArg, mastery, owner, ds)
	return Mastery_Shared_SpRegen_UnitTurnStart(eventArg, mastery, owner, ds);
end
-- 절정의 기백 / 시작 턴 불 SP n 개 생성 구문.
function Mastery_OverchargeSpirit_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local addAmount = 0;
	local mastery_VastSpirit = GetMasteryMastered(GetMastery(owner), 'VastSpirit');
	if mastery_VastSpirit then
		addAmount = mastery_VastSpirit.CustomCacheData;
	end	
	local actions = {};
	AddSPPropertyActions(actions, owner, 'Spirit', addAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
	return unpack(actions);
end
-- BoneChilling	사무치는 냉기 / 시작 턴 얼음 SP n 개 생성 구문.
function Mastery_BoneChilling_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	AddSPPropertyActions(actions, owner, 'Ice', mastery.ApplyAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
	return unpack(actions);
end
-- Dewdrop 이슬방울 / 시작 턴 물 SP n 개 생성 구문.
function Mastery_Dewdrop_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local addAmount = mastery.ApplyAmount;
	-- 안개비
	local mastery_Smir = GetMasteryMastered(GetMastery(owner), 'Smir');
	if mastery_Smir then
		addAmount = addAmount + mastery_Smir.ApplyAmount;
	end	
	local actions = {};
	AddSPPropertyActions(actions, owner, 'Water', addAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
	if mastery_Smir then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_Smir.name, EventType = 'UnitTurnStart'});
	end
	return unpack(actions);
end
-- Cauterize 소작 / 턴 시작시 상태 이상 버프를 해제, 해제한 버프 개수 당 n 개의 불씨 소모.
function Mastery_Cauterize_UnitTurnStart(eventArg, mastery, owner, ds)
	local actions = {};
	local removeBuffList = {};
	local remainSP = owner.SP;
	local applyAmount = mastery.ApplyAmount;
	if owner.Overcharge > 0 then -- 과충전 상태에선 공짜!
		applyAmount = 0;
	end	
	if remainSP >= applyAmount then
		local debuffList = GetBuffType(owner, 'Debuff');
		if #debuffList > 0 then
			for index, debuff in ipairs (debuffList) do
				if remainSP < applyAmount then
					break;
				end
				table.insert(actions, Result_RemoveBuff(owner, debuff.name, true));
				remainSP = remainSP - applyAmount;
				table.insert(removeBuffList, debuff.name);
			end
		end
	end
	local totalCount = #removeBuffList;	
	if totalCount > 0 then
		local cosumedSP = owner.SP - remainSP;
		if cosumedSP > 0 then
			AddSPPropertyActions(actions, owner, 'Fire', -cosumedSP, true, ds, true);
		end
		local masteryTable = GetMastery(owner);
		local mastery_LastFlame = GetMasteryMastered(masteryTable, 'LastFlame');
		if mastery_LastFlame then
			local addHP = totalCount * math.max(1, math.floor(owner.MaxHP * mastery_LastFlame.ApplyAmount/100));
			local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
			if owner.HP < owner.MaxHP then
				DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false);
			end
		end
		local objKey = GetObjKey(owner);
		ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
		for _, buffName in ipairs(removeBuffList) do
			ds:UpdateBattleEvent(GetObjKey(owner), 'BuffDischarged', { Buff = buffName });
		end
	end
	return unpack(actions);
end
-- 자동 복원
function Mastery_Module_Cauterize_UnitTurnStart(eventArg, mastery, owner, ds)
	local actions = {};
	local removeBuffList = {};
	local remainCost = owner.Cost;
	local applyAmount = mastery.ApplyAmount;
	if remainCost >= applyAmount then
		local debuffList = GetBuffType(owner, 'Debuff');
		if #debuffList > 0 then
			for index, debuff in ipairs (debuffList) do
				if remainCost < applyAmount then
					break;
				end
				table.insert(actions, Result_RemoveBuff(owner, debuff.name, true));
				remainCost = remainCost - applyAmount;
				table.insert(removeBuffList, debuff.name);
			end
		end
	end
	if #actions <= 0 then
		return;
	end
	local consumedCost = owner.Cost - remainCost;
	if consumedCost > 0 then
		AddActionCostForDS(actions, owner, -consumedCost, true, nil, ds);
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	local objKey = GetObjKey(owner);
	for _, buffName in ipairs(removeBuffList) do
		ds:UpdateBattleEvent(objKey, 'BuffDischarged', { Buff = buffName });
	end
	-- 자율 방어 행동 최적화
	local mastery_Module_AutoDefence = GetMasteryMastered(GetMastery(owner), 'Module_AutoDefence');
	if mastery_Module_AutoDefence then
		AddActionApplyActForDS(actions, owner, -mastery_Module_AutoDefence.ApplyAmount, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_Module_AutoDefence, owner, 'UnitTurnStart_Self');
	end	
	return unpack(actions);
end
-- 특성 행운의 숫자.
function Mastery_LuckyNumber_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	mastery.CountChecker = mastery.CountChecker + 1;
	if mastery.CountChecker == mastery.ApplyAmount then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
		mastery.CountChecker = 0;
	end
	return unpack(actions);
end
-- 특성 행운
function Mastery_Luck_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local applyAmount = mastery.ApplyAmount;
	-- 영웅의 일격
	local mastery_Argonaut = GetMasteryMastered(GetMastery(owner), 'Argonaut');
	if mastery_Argonaut then
		applyAmount = applyAmount + mastery_Argonaut.ApplyAmount2;
	end
	if RandomTest(applyAmount) then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
	end
	return unpack(actions);
end
function Mastery_Cheerfulness_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local targetList = GetTargetInRangeSight(owner, 'Sight', 'Enemy', true);
	if #targetList == 0 then
		return;
	end
	local actions = {};
	AddSPPropertyActions(actions, owner, owner.ESP.name, mastery.ApplyAmount, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
	return unpack(actions);
end
function Mastery_HungryWolf_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	if owner.HP == owner.MaxHP and owner.Cost == owner.MaxCost then
		return;
	end
	
	-- 매 턴 발생.
	mastery.CountChecker = mastery.CountChecker + 1;
	local skipRate = math.min(100, math.max(0, 100 - mastery.CountChecker * 10));	
	if RandomTest(skipRate) then
		return;
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	
	
	local testType = 'HP';
	local isAvailableRestoreHP = false;
	local isAvailableRestoreCost = false;
	if owner.HP < owner.MaxHP then
		isAvailableRestoreHP = true;
	end
	if owner.Cost < owner.MaxCost then
		isAvailableRestoreCost = true;
	end
	
	if isAvailableRestoreHP and isAvailableRestoreCost then
		if RandomTest(50) then
			testType = 'HP';
		else
			testType = 'Cost';
		end
	elseif isAvailableRestoreHP then
		testType = 'HP';
	elseif isAvailableRestoreCost then
		testType = 'Cost';
	end
	
	local testRate = 0;
	if testType == 'HP' then
		testRate = ( 1 - owner.HP/owner.MaxHP) * 100;
	elseif testType == 'Cost' then
		testRate = ( 1 - owner.Cost/owner.MaxCost) * 100;
	end
	if RandomTest(testRate) then
		local cam = ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
		local aniID = ds:PlayAni(objKey, 'Eat', false, -1, true);
		ds:Connect(aniID, cam, 0.5);
		local battleEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
		local subEvent = ds:UpdateBattleEvent(objKey, 'GetWordCustomEvent', {Word = 'HungryWolf_Snack', EventType = 'FirstHit', Color = 'Yellow'});
		local chatID = ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitTurnStart'});
		local playSoundID = ds:PlaySound3D('CameraMove.wav', objKey, '_CENTER_', 3000, 'Effect', 1.0, true);
		local particleID = ds:PlayParticle(objKey, '_CENTER_', 'Particles/Dandylion/Sion_HungryWolf_HP', 2, true, false, true);
		
		ds:Connect(particleID, aniID, 0);
		ds:Connect(playSoundID, aniID, 0);
		ds:Connect(battleEventID, aniID, 0);
		ds:Connect(subEvent, battleEventID, 0);
		ds:Connect(chatID, aniID, -1);
		
		-- 체력
		local addHP = math.floor(math.random(15,25)/100 * owner.MaxHP);
		local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		local damageAction = DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false);
		AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
		-- 코스트
		local addCost = math.min(owner.MaxCost - owner.Cost, math.random(15,30));
		local _, reasons = AddActionCost(actions, owner, addCost, true, false);
		ds:Connect(ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost }), damageAction, 0.5);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons, damageAction, 0.5);
		ds:Connect(ds:UpdateCostDamagedGauge(objKey, {damage = -addCost, isFinal = true}), damageAction, 0.5);
		
		local addSt = GetInstantProperty(owner, 'AddSatiety') or 0;
		addSt = addSt + mastery.ApplyAmount2;
		SetInstantProperty(owner, 'AddSatiety', addSt);
	end
	mastery.CountChecker = 0;
	return unpack(actions);
end
function Mastery_Pride_UnitTurnStartSelf(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if owner.HP > owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end
	local actions = {};
	AddSPPropertyActions(actions, owner, owner.ESP.name, mastery.ApplyAmount2, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
	return unpack(actions);
end
function Mastery_NatureBalance_UnitTurnStart(eventArg, mastery, owner, ds)
  if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local applySP = mastery.ApplyAmount;
	local masteryTable = GetMastery(owner);
	local mastery_Sincerity = GetMasteryMastered(masteryTable, 'Sincerity');
	if mastery_Sincerity then
		applySP = applySP + mastery_Sincerity.ApplyAmount;
	end
	AddSPPropertyActions(actions, owner, 'Earth', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnStart'});
	return unpack(actions);
end
function Mastery_Bloodwalker_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	local buff = GetBuff(owner, 'Bloodwalker');
	
	if owner.HP > owner.MaxHP * mastery.ApplyAmount/100 then
		return;
	end
	
	local modifier = nil;
	local skipDirect = false;
	local buff = GetBuff(owner, mastery.Buff.name);
	if buff then
		-- 다시 걸어줄 필요 없음
		if buff.Life >= buff.Turn then
			return;
		end
		-- 버프 갱신, 연출 생략
		modifier = function(b)
			b.UseAddedMessage = false;
		end;
		skipDirect = true;
		return unpack(actions);
	end
	
	if skipDirect then
		-- 연출 생략 시에는 채팅 메시지만 남긴다.
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitTurnStart'});
	else
		local cam = ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
		local aniID = ds:PlayAni(objKey, 'AstdIdle', false, -1, true);
		ds:Connect(aniID, cam, 0.5);
		local battleEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
		local chatID = ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitTurnStart'});
		local playSoundID = ds:PlaySound3D('CameraMove.wav', objKey, '_CENTER_', 3000, 'Effect', 1.0);
		
		ds:Connect(playSoundID, aniID, 0);
		ds:Connect(battleEventID, aniID, 0);
		ds:Connect(chatID, aniID, -1);
	end
	
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, modifier);
	return unpack(actions);
end
function Mastery_Tima_UnitTurnStart(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker == 1 or IsControllable(owner) then
		mastery.DuplicateApplyChecker = 0;
		return;
	end
	-- 의식불명 혹은 이동불가 상태 혹은 행동제어 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or')
		or not owner.Movable
		or GetActionController(owner) ~= 'None' then
		return;
	end
	
	local dangerRatio = GetInstantProperty(owner, 'RecoveryRatio') or 0.25;
	if dangerRatio == nil then
		return;
	end
	if owner.HP / owner.MaxHP > dangerRatio then
		return;
	end
	
	mastery.DuplicateApplyChecker = 1;
	local retreatPos = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function(self, adb, args)
		if adb.RelativeMinEnemyDistance < 0 then
			return -9988;
		end
		
		local totalScore = 1000;
		totalScore = totalScore - adb.Dangerous * 50;
		if adb.OnFieldEffect('Bush') then
			totalScore = totalScore + 1000;
		end
		
		totalScore = totalScore - math.abs(adb.MinEnemyDistance - 8) * 20;
		
		return totalScore + adb.MoveDistance * 5;
	end, {}, {});
	if retreatPos == nil then
		return;
	end
	ds:GeneralMove(owner, retreatPos, false, false, nil);
	return Result_TurnEnd(owner, true);
end
function Mastery_Yasha_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 만피 이상이면 발동 안함
	if owner.HP >= owner.MaxHP then
		return;
	end
	if not IsObjectOnFieldEffect(owner, 'Web') then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local addHP = math.floor(owner.MaxHP * mastery.ApplyAmount/100);
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	DirectDamageByType(ds, owner, 'HPRestore', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	return unpack(actions);
end
-- 생기발랄
function Mastery_Vivacious_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local buffList = GetBuffType(owner, 'Debuff', 'Mental');
	if #buffList == 0 then
		return;
	end
	local actions = {};
	for _, buff in ipairs(buffList) do
		InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv);	
	end
	local addAmount = #buffList / mastery.ApplyAmount * mastery.ApplyAmount2;
	AddSPPropertyActions(actions, owner, 'Spirit', addAmount, true, ds, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStar_Self');
	return unpack(actions);
end
-- 이독 제독
function Mastery_PoisonRemovePoison_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local buffList = GetBuffType(owner, nil, nil, mastery.BuffGroup.name);
	if #buffList == 0 then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStar_Self');
	for _, buff in ipairs(buffList) do
		InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv, true);
		ds:UpdateBattleEvent(objKey, 'BuffDischarged', { Buff = buff.name });
	end
	local addAmount = math.floor(#buffList / mastery.ApplyAmount) * mastery.ApplyAmount2;
	if addAmount > 0 then
		AddSPPropertyActions(actions, owner, 'Water', addAmount, true, ds, true);
	end
	return unpack(actions);
end
-- 생명의 온기
function Mastery_LifeAura_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 오라 버프 가져오기
	local buffName = nil;
	local masteryTable = GetMastery(owner);
	local mastery_OriginOfLife = GetMasteryMastered(masteryTable, 'OriginOfLife');
	if mastery_OriginOfLife then
		buffName = 'OriginOfLife_Aura';
	end
	local mastery_ChildOfLight = GetMasteryMastered(masteryTable, 'ChildOfLight');
	if mastery_ChildOfLight then
		buffName = 'OriginOfLife_Aura_Range6';
	end
	if buffName == nil then
		return;
	end
	local auraBuff = GetBuff(owner, buffName);
	if auraBuff == nil then
		return;
	end
	-- 대상 선정
	local list = {};
	local mission = GetMission(owner);
	local range = CalculateRange(owner, auraBuff.AuraRange, GetPosition(owner));
	for i, pos in ipairs(range) do
		local target = GetObjectByPosition(mission, pos);
		if target and owner ~= target and GetRelation(owner, target) == 'Team' then
			table.insert(list, target);
		end
	end
	if #list == 0 then
		return;
	end
	table.scoresort(list, function(target) return target.Act end);
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStar_Self');
	for _, target in ipairs(list) do
		local targetKey = GetObjKey(target);
		-- 기력 회복
		if target.CostType.name == 'Vigor' then
			local addCost = mastery.ApplyAmount;
			local afterCost, reasons = AddActionCost(actions, target, addCost, true);
			if target.Cost < afterCost then
				ds:UpdateBattleEvent(targetKey, 'AddCost', { CostType = target.CostType.name, Count = addCost });
			end
			ReasonToUpdateBattleEventMulti(target, ds, reasons);
		end
		-- 턴 대기 시간 감소
		local nextAct = math.max(target.Act - mastery.ApplyAmount2, 0);
		local hasteAct = target.Act - nextAct;
		if hasteAct > 0 then
			local added, reasons = AddActionApplyAct(actions, owner, target, -hasteAct, 'Friendly');
			if added then
				ds:UpdateBattleEvent(targetKey, 'AddWaitCustomEvent', {Time = -hasteAct, EventType = 'Ending'});
			end
			ReasonToUpdateBattleEventMulti(target, ds, reasons);
		end
	end
	return unpack(actions);
end
-- 점액질 피부
function Mastery_MucusSkin_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local debuffList = GetBuffType(owner, 'Debuff', 'Physical');
	if #debuffList == 0 then
		return;
	end
	local picker = RandomPicker.new(false);
	for _, buff in ipairs(debuffList) do
		picker:addChoice(1, buff);
	end	
	local removeBuffList = picker:pickMulti(mastery.ApplyAmount);
	local actions = {};
	local objKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart');
	for _, buff in ipairs(removeBuffList) do
		table.insert(actions, Result_RemoveBuff(owner, buff.name, true));
		ds:UpdateBattleEvent(objKey, 'BuffDischarged', { Buff = buff.name });
	end
	-- 점액 분비
	local mastery_SecretionOfMucus = GetMasteryMastered(GetMastery(owner), 'SecretionOfMucus');	
	if mastery_SecretionOfMucus and #removeBuffList > 0 then
		MasteryActivatedHelper(ds, mastery_SecretionOfMucus, owner, 'AbilityUsed_Self');
		AddActionApplyActForDS(actions, owner, -mastery_SecretionOfMucus.ApplyAmount, ds, 'Friendly');
	end
	return unpack(actions);
end
-- 수풀에서 수풀로
function Mastery_FieldEffectToFieldEffect_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local testBuffList = {};
	if mastery.Buff and mastery.Buff.name then
		table.insert(testBuffList, mastery.Buff.name);
	end
	if mastery.SubBuff and mastery.SubBuff.name then
		table.insert(testBuffList, mastery.SubBuff.name);
	end	
	local isOnFieldEffect = IsObjectOnFieldEffectBuffAffector(owner, testBuffList);
	if isOnFieldEffect then
		mastery.DuplicateApplyChecker = 1;
	else
		mastery.DuplicateApplyChecker = 0;
	end
end
-- 잠꾸러기
function Mastery_Sleepyhead_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local sleepBuffList = GetBuffType(owner, 'Debuff', nil, 'Sleep');
	if #sleepBuffList == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	for _, buff in ipairs(sleepBuffList) do
		table.insert(actions, Result_BuffPropertyUpdated('Life', buff.Turn, owner, buff.name, true));
	end
	return unpack(actions);	
end
-- 그림자 걷기
function Mastery_ShadowStep_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if IsExposedByEnemy(owner) then
		return;
	end
	local enemyList = GetTargetInRangeSight(owner, 'Sight', 'Enemy', true);
	if #enemyList == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	local addCost = mastery.ApplyAmount;
	local _, reasons = AddActionCost(actions, owner, addCost, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 수풀 속의 암살자
function Mastery_BushAssassin_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 수풀 속의 포식자.
	local mastery_AmbushingPredator = GetMasteryMastered(GetMastery(owner), 'AmbushingPredator');
	if not mastery_AmbushingPredator then
		return;
	end
	if not IsObjectOnFieldEffectBuffAffector(owner, mastery.Buff.name) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	MasteryActivatedHelper(ds, mastery_AmbushingPredator, owner, 'UnitTurnStart_Self');
	InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, true);
	return unpack(actions);
end
-- 안개 속의 암살자
function Mastery_SmokeAssassin_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 안개 속의 포식자
	local mastery_IntheSmokePredator = GetMasteryMastered(GetMastery(owner), 'IntheSmokePredator');
	if not mastery_IntheSmokePredator then
		return;
	end
	if not IsObjectOnFieldEffectBuffAffector(owner, mastery.Buff.name) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	MasteryActivatedHelper(ds, mastery_IntheSmokePredator, owner, 'UnitTurnStart_Self');
	InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, true);
	return unpack(actions);
end
-- 자동 프로토콜 복구
function Mastery_AutoProtocolRestore_UnitTurnStart(eventArg, mastery, owner, ds)
	local enableUseCount = 0;
	for _, ability in ipairs(GetEnableProtocolAbilityList(owner)) do
		if ability.IsUseCount then
			enableUseCount = enableUseCount + ability.UseCount;
		end
	end
	if enableUseCount > mastery.ApplyAmount then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	-- 사용 횟수 제한이 있는 모든 프로토콜 어빌리티 UseCount 증가 (MaxUseCount를 넘기지는 않음)
	local abilityList = GetAllAbility(owner);
	abilityList = table.filter(abilityList, function(ability)
		return IsProtocolAbility(ability) and ability.IsUseCount and ability.AutoUseCount;
	end);
	
	local restoreAmount = mastery.ApplyAmount2;
	local mastery_SpareParts = GetMasteryMastered(GetMastery(owner), 'SpareParts');
	if mastery_SpareParts then
		restoreAmount = restoreAmount + mastery_SpareParts.ApplyAmount;
		MasteryActivatedHelper(ds, mastery_SpareParts, owner, 'UnitTurnStart_Self');
	end
	for _, ability in ipairs(abilityList) do
		if ability.UseCount < ability.MaxUseCount then
			local newCount = math.min(ability.UseCount + restoreAmount, ability.MaxUseCount);
			UpdateAbilityPropertyActions(actions, owner, ability.name, 'UseCount', newCount);
		end
	end
	return unpack(actions);
end
-- 앤이 좋아요
function Mastery_ILikeAnne_UnitTurnStart(eventArg, mastery, owner, ds)
	-- 반경 ApplyAmount 칸
	local targetObjects = Linq.new(GetNearObject(owner, mastery.ApplyAmount + 0.4))
		:where(function(o) return o.Info.name == 'Anne' end)
		:toList();
	if #targetObjects == 0 then
		return;
	end
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	local buff = goodBuffPicker:PickBuff();
	if buff == nil then
		return;
	end	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart', true);
	InsertBuffActions(actions, owner, owner, buff, 1, true);
	return unpack(actions);
end
-- 몽유병
function Mastery_Somnambulism_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local sleepBuffs = GetBuffType(owner, nil, nil, mastery.BuffGroup.name);
	if #sleepBuffs == 0 then
		return;
	end
	
	DoFuncWithExceptBuffStatus(owner, sleepBuffs, { 'Movable', 'Unconscious' }, true, function()
		if not owner.Movable or GetBuffStatus(owner, 'Unconscious', 'Or') then
			return;
		end
		local target = nil;
		local mission = GetMission(owner);
		local summonMaster = GetInstantProperty(owner, 'SummonMaster');
		if summonMaster ~= nil then
			target = GetUnit(mission, summonMaster);
		else
			local ownerPos = GetPosition(owner);
			target = Linq.new(GetAllUnitInSight(owner, false))
				:where(function(o) return owner ~= o and IsEnemy(owner, o); end)
				:orderByAscending(function(o) return GetDistance3D(ownerPos, GetPosition(o)); end)
				:first();
		end
		if target == nil then
			return;
		end
		local targetPos = GetPosition(target);
		local movePos = GetMovePosition(owner, targetPos, 1.8, true, nil, true);
		if not IsValidPosition(mission, movePos) then
			return;
		end
		MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart', true);
		ds:Move(GetObjKey(owner), movePos);
	end);
end
-- 고급 항동결 수액
function Mastery_AntiFreezing_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local removeBuffList = {};
	local remainSP = owner.SP;
	local applyAmount = mastery.ApplyAmount3;
	if owner.Overcharge > 0 then -- 과충전 상태에선 공짜!
		applyAmount = 0;
	end	
	if remainSP >= applyAmount then
		local debuffList = GetBuffType(owner, 'Debuff');
		if #debuffList > 0 then
			for index, debuff in ipairs (debuffList) do
				if remainSP < applyAmount then
					break;
				end
				remainSP = remainSP - applyAmount;
				table.insert(removeBuffList, debuff.name);
			end
		end
	end
	local totalCount = #removeBuffList;	
	if totalCount == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart');
	local cosumedSP = owner.SP - remainSP;
	if cosumedSP > 0 then
		AddSPPropertyActionsObject(actions, owner, -cosumedSP, true, ds, true);
	end
	local objKey = GetObjKey(owner);
	for _, buffName in ipairs(removeBuffList) do
		table.insert(actions, Result_RemoveBuff(owner, buffName, true));
		ds:UpdateBattleEvent(objKey, 'BuffDischarged', { Buff = buffName });
	end
	return unpack(actions);
end
-- 항동결 수액
function Mastery_AntiFreezingInfusionSolution_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local company = GetCompany(owner);
	if not company then
		return;
	end
	local testBuff = GetBuff(owner, mastery.SubBuff.name);
	local testBuffLv = testBuff and testBuff.Lv or 0;
	if testBuffLv < mastery.CountChecker then
		local msgType = 'MasteryBuffCountMessage';
		if testBuffLv <= 0 then
			msgType = 'MasteryBuffCountMessage_Zero';
		end
		local formatTable = { BuffName = ClassDataText('Buff', mastery.SubBuff.name, 'Title'), BuffLv = testBuffLv };
		ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText(msgType), formatTable), 'Corn', GetTeam(owner));
		mastery.CountChecker = testBuffLv;
	end
end
-- 광휘
function Mastery_Brilliance_UnitTurnStart(eventArg, mastery, owner, ds)
	local applyDist = mastery.ApplyAmount;
	local addBuffLv = 1;
	local masteryTable = GetMastery(owner);
	-- 빛나는 자
	local mastery_Luminary = GetMasteryMastered(masteryTable, 'Luminary');
	if mastery_Luminary then
		applyDist = mastery_Luminary.ApplyAmount;
	end
	-- 청중 압도하기
	local mastery_OverwhelmAudience = GetMasteryMastered(masteryTable, 'OverwhelmAudience');
	if mastery_OverwhelmAudience then
		addBuffLv = addBuffLv + mastery_OverwhelmAudience.ApplyAmount;
	end
	local raceBuffMap = {
		Human = mastery.Buff.name,
		Beast = mastery.SubBuff.name,
	};	
	local nearEnemies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsEnemy(owner, o) and o.Lv <= owner.Lv and raceBuffMap[o.Race.name] ~= nil end)
		:toList();
	if #nearEnemies == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	for _, e in ipairs(nearEnemies) do
		InsertBuffActions(actions, owner, e, raceBuffMap[e.Race.name], addBuffLv, true);
	end
	return unpack(actions);
end
-- 소유욕
function Mastery_Possessiveness_UnitTurnStart(eventArg, mastery, owner, ds)
	local ownerKey = GetObjKey(owner);
	local nearUnits = GetNearObject(owner, mastery.ApplyAmount + 0.4);
	
	local found = false;
	for _, target in ipairs(nearUnits) do
		local masterKey = GetInstantProperty(target, 'SummonMaster');
		if masterKey and masterKey == ownerKey then
			found = true;
			break;
		end	
	end
	if not found then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	local buff = GetBuff(owner, mastery.SubBuff.name);
	if buff then
		table.insert(actions, Result_BuffPropertyUpdated('Life', buff.Turn, owner, buff.name, true));
	else
		InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, true);
	end
	return unpack(actions);
end
-- 복종심
function Mastery_Obedience_UnitTurnStart(eventArg, mastery, owner, ds)
	local masterKey = GetInstantProperty(owner, 'SummonMaster');
	if not masterKey then
		return;
	end	
	local host = GetUnit(owner, masterKey);
	if host == nil then
		return;
	end
	if GetDistance3D(GetPosition(owner), GetPosition(host)) >= (mastery.ApplyAmount + 0.4) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	local buff = GetBuff(owner, mastery.SubBuff.name);
	if buff then
		table.insert(actions, Result_BuffPropertyUpdated('Life', buff.Turn, owner, buff.name, true));
	else
		InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, true);
	end
	return unpack(actions);
end
-- 자연 치유
function Mastery_Autotherapy_UnitTurnStart(eventArg, mastery, owner, ds)
	local hpRatio = owner.HP / owner.MaxHP * 100;
	if hpRatio > mastery.ApplyAmount then
		return;
	end
	if owner.SP < mastery.ApplyAmount3 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	local addHP = math.floor(owner.MaxHP * mastery.ApplyAmount2 / 100);
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	if owner.HP < owner.MaxHP then
		DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false);
	end
	AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	AddSPPropertyActionsObject(actions, owner, -1 * mastery.ApplyAmount3, true, ds, true);
	return unpack(actions);
end
-- 드라키의 고귀한 비늘
function Mastery_Amulet_Draky_Scale2_UnitTurnStart(eventArg, mastery, owner, ds)
	if HasBuff(owner, mastery.Buff.name) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 드라키의 완벽한 비늘
function Mastery_Amulet_Draky_Scale3_UnitTurnStart(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
-- 너보다 조금 더 높은 곳에
function Mastery_HigherThanYou_UnitTurnStart(eventArg, mastery, owner, ds)
	local enemyList = table.filter(GetAllUnitInSight(owner, true), function(o)
		return owner ~= o and IsEnemy(owner, o);
	end);
	if #enemyList == 0 then
		return;
	end
	local ownerPos = GetPosition(owner);	
	local heightEnemyList = table.filter(enemyList, function(o)
		return GetHeight(GetPosition(o), ownerPos) > 0;
	end);
	if #heightEnemyList > 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 신경질쟁이
function Mastery_Dorori_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local unitCount = #(table.filter(GetAllUnitInSight(owner, true), function(o) 
		return owner ~= o and IsEnemy(owner, o);
	end));
	if unitCount == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	-- 코스트
	local addCost = mastery.ApplyAmount;
	if HasBuffType(owner, nil, nil, mastery.BuffGroup.name) then
		addCost = addCost + mastery.ApplyAmount2;
	end
	AddActionCostForDS(actions, owner, addCost, true, nil, ds);		
	return unpack(actions);
end
-- 폭염의 괴수, 혹한의 괴수, 빗속의 괴수
local g_environmentMosnterFieldEffect = {
	HotMonster = 'Fire',
	ColdMonster = 'IceMist',
	RainMonster = 'Spark',
};
function Mastery_EnvironmentMosnter_UnitTurnStart(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 만피 이상이면 발동 안함
	if owner.HP >= owner.MaxHP then
		return;
	end
	local fieldEffect = g_environmentMosnterFieldEffect[mastery.name];
	if not fieldEffect or not IsObjectOnFieldEffect(owner, fieldEffect) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	local objKey = GetObjKey(owner);
	local addHP = math.floor(owner.MaxHP * mastery.ApplyAmount2/100);
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	DirectDamageByType(ds, owner, 'HPRestore', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false);
	AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	return unpack(actions);
end
-- 황금 날개 부적
function Mastery_Amulet_Neguri_GoldESP_Set_UnitTurnStart(eventArg, mastery, owner, ds)
	local enemyList = table.filter(GetAllUnitInSight(owner, true), function(o)
		return owner ~= o and IsEnemy(owner, o);
	end);
	if #enemyList > 0 then
		return;
	end	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 턴 획득 [UnitTurnAcquired]
-------------------------------------------------------------------------------
-- 공연시스템
function Mastery_PerformanceSystem_UnitTurnAcquired(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	
	local effectMap = {};	
	local uesableAbilityList = GetAvailableAbility(owner);
	uesableAbilityList = table.filter(uesableAbilityList, function(ability) return not IsMoveTypeAbility(ability) end);	
	uesableAbilityList = SortAbilityList(owner, uesableAbilityList);
	
	for _, info in ipairs(owner.PerformanceList) do
		local stepCount = info.StepCount;
		local stepIndex = info.StepIndex % info.StepCount;
		for i, ability in ipairs(uesableAbilityList) do
			if i % stepCount == stepIndex then
				effectMap[ability.name] = info.Type;
			end
		end
	end
	local actions = {};
	local changed = {};
	local allAbilityList = GetAllAbility(owner, false, false);
	for _, ability in ipairs(allAbilityList) do
		local oldEffect = ability.PerformanceEffect;
		local newEffect = effectMap[ability.name] or 'None';
		if oldEffect ~= newEffect then
			UpdateAbilityPropertyActions(actions, owner, ability.name, 'PerformanceEffect', newEffect);
			changed[ability.name] = newEffect;
		end
	end
	
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 턴 종료 [UnitTurnEnd]
-------------------------------------------------------------------------------
-- 전장의 방랑자
function Mastery_BattleWanderer_UnitTurnEnd(eventArg, mastery, owner, ds)
	local enemyList = GetTargetInRangeSight(owner, 'Sight', 'Enemy', true);
	if #enemyList >= 0 then
		return;
	end
	
	local actions = {};
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	return unpack(actions);
end
-- 전술적 연계
function Mastery_TacticalConnection_UnitTurnEnd(eventArg, mastery, owner, ds)
	if owner == eventArg.Unit
		or GetTeam(owner) ~= GetTeam(eventArg.Unit) 
		or GetDistance2D(GetPosition(owner), GetPosition(eventArg.Unit)) > 1 then
		return;
	end
	local actions = {};
	local applyAct = -mastery.ApplyAmount;
	local mastery_BattleWanderer = GetMasteryMastered(GetMastery(owner), 'BattleWanderer');
	if mastery_BattleWanderer then
		applyAct = applyAct - mastery_BattleWanderer.ApplyAmount3;
	end
	AddActionApplyActForDS(actions, owner, applyAct, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd');
	if mastery_BattleWanderer then
		MasteryActivatedHelper(ds, mastery_BattleWanderer, owner, 'UnitTurnEnd');
	end
	return unpack(actions);
end
-- 재빠른 전황 파악
function Mastery_RapidUnderstandingBattle_UnitTurnEnd(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end
	if eventArg.Unit.PreBattleState or GetBuffStatus(eventArg.Unit, 'Unconscious', 'Or') then
		return;
	end
	local actions = {};
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd');
	return unpack(actions);
end
-- 지원 회복
function Mastery_SupportHeal_UnitTurnEnd(eventArg, mastery, owner, ds)
	mastery.CountChecker = 0;
end
-- 다중 처리
function Mastery_MultiProcessing_UnitTurnEnd(eventArg, mastery, owner, ds)
	if mastery.CountChecker < mastery.ApplyAmount then
		return;
	end
	local enableUseCount = 0;
	for _, ability in ipairs(GetEnableProtocolAbilityList(owner)) do
		if ability.IsUseCount then
			enableUseCount = enableUseCount + ability.UseCount;
		end
	end
	
	local reduceAct = math.floor(enableUseCount / mastery.ApplyAmount2) * mastery.ApplyAmount;
	local actions = {};
	AddActionApplyActForDS(actions, owner, -reduceAct, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	return unpack(actions);
end
-- 자동 경계 이동
function Mastery_Module_MoveOverwatch_UnitTurnEnd(eventArg, mastery, owner, ds)
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	if owner.Cost < mastery.ApplyAmount then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount, true, nil, ds);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	-- 자율 방어 행동 최적화
	local mastery_Module_AutoDefence = GetMasteryMastered(GetMastery(owner), 'Module_AutoDefence');
	if mastery_Module_AutoDefence then
		AddActionApplyActForDS(actions, owner, -mastery_Module_AutoDefence.ApplyAmount, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_Module_AutoDefence, owner, 'UnitTurnEnd_Self');
	end	
	return unpack(actions);
end
-- 불꽃을 부르는 자 - 5 세트
function Mastery_FlameNeguriSet5_UnitTurnEnd(eventArg, mastery, owner, ds)
	if owner.SP <= 0 then
		return;
	end
	local applyDist = mastery.ApplyAmount;
	if applyDist == 1 then
		applyDist = 1.4;
	end
	local nearEnemies = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return IsEnemy(owner, o) end)
		:toList();
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	local actionID = ds:Sleep(0);
	-- 안됌..
	--ds:Connect(ds:PlayParticle(GetObjKey(owner), '_BOTTOM_', 'Particles/Dandylion/Grenade_Explosion_EMP', 1, true, true, false), actionID, 0);
	local actions = {};
	for _, e in ipairs(nearEnemies) do
		local damage = Result_Damage(owner.SP, 'Normal', 'Hit', owner, e, 'Mastery', mastery.SubType, mastery);	-- 버프에 의한 체력 변화는 스스로 주는거다!
		local realDamage, reasons = ApplyDamageTest(e, owner.SP, 'Mastery');
		local isDead = e.HP <= realDamage;
		local remainHP = math.clamp(e.HP - realDamage, 0, e.MaxHP);

		DirectDamageByType(ds, e, 'FlameNeguriSet5', owner.SP, remainHP, false, isDead, actionID, 0);
		ReasonToUpdateBattleEventMulti(e, ds, reasons, actionID, 0);
		AddMasteryDamageChat(ds, e, mastery, realDamage);
		table.insert(actions, damage);
		if realDamage > 0 then
			InsertBuffActions(actions, owner, e, mastery.Buff.name, 1, true);
		end
	end
	return unpack(actions);
end
-- 괴수 조련사
function Mastery_MonsterMaster_UnitTurnEnd(eventArg, mastery, owner, ds)
	local beast = SafeIndex(GetInstantProperty(owner, 'SummonBeast'), 'Target');
	if beast == nil 
		or eventArg.Unit ~= beast then
		return;
	end
	
	if GetDistanceFromObjectToObject(owner, beast) > mastery.ApplyAmount + 0.4 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	local actions = {};
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	AddActionApplyActForDS(actions, beast, -mastery.ApplyAmount2, ds, 'Friendly');
	
	return unpack(actions);	
end
-- 길잡이
function Mastery_Pathfinder_UnitTurnEnd(eventArg, mastery, owner, ds)
	local host = GetUnit(owner, GetInstantProperty(owner, 'SummonMaster'));
	if host == nil then
		return;
	end
	
	if not IsInSight(owner, GetPosition(host), true) then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	local actions = {};
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	AddActionApplyActForDS(actions, host, -mastery.ApplyAmount, ds, 'Friendly');
	
	return unpack(actions);
end
-- 고약한 잠버릇
function Mastery_BadSleepType_UnitTurnEnd(eventArg, mastery, owner, ds)
	local sleepBuffs = GetBuffType(owner, nil, nil, 'Sleep');
	if #sleepBuffs == 0 then
		return;
	end
	
	local prevStat = {};
	for index, buff in ipairs(sleepBuffs) do
		prevStat[index] = {Attackable = buff.Attackable, Sight = {}};
		for sindex, value in ipairs(buff.Base_SightRange) do
			prevStat[index].Sight[sindex] = value;
			buff.Base_SightRange[sindex] = 0;
		end
		buff.Attackable = true;
		InvalidateObject(buff);
	end
	InvalidateBuffStatusCache(owner, 'Attackable');
	InvalidateObject(owner);
	InvalidateSight(owner);
	local abilities = table.filter(GetAvailableAbility(owner, true), function (ability) return ability.Type == 'Attack' end);
	
	local usingAbility, usingPos, _, score = FindAIMainAction(owner, abilities, {{Strategy = function(self, adb)
			local score = 100;
			if adb.IsIndirect then
				score = 0;
			end
			return score + 100 / (adb.Distance + 1);
		end, Target = 'Attack'}}, {}, {});
		
	for index, buff in ipairs(sleepBuffs) do
		buff.Attackable = prevStat[index].Attackable;
		for sindex, value in ipairs(buff.Base_SightRange) do
			buff.Base_SightRange[sindex] = prevStat[index].Sight[sindex];
		end
		InvalidateObject(buff);
	end
	InvalidateBuffStatusCache(owner, 'Attackable');
	InvalidateObject(owner);
	InvalidateSight(owner);
	if usingAbility == nil then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	local useAbility = Result_UseAbility(owner, usingAbility.name, usingPos, {ReactionAbility = true}, true);
	useAbility.free_action = true;
	return useAbility;
end
-- 거미줄 넓히기
function Mastery_ExpandCobweb_UnitTurnEnd(eventArg, mastery, owner, ds)
	if not IsObjectOnFieldEffect(owner, 'Web') then
		return;
	end
	
	local range = table.filter(CalculateRange(owner, 'Box1_Attack', GetPosition(owner)), function(pos)
		local fieldEffects = GetFieldEffectByPosition(owner, pos);
		for _, instance in ipairs(fieldEffects) do
			local type = instance.Owner.name;
			if type == 'Fire' or type == 'Spark' or type == 'PoisonGas' or type == 'Web' then
				return false;
			end
		end
		return true;
	end);
	
	if #range == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');

	return Result_AddFieldEffect('Web', range);
end
-- 지원 사격
function Mastery_SupportingFire_UnitTurnEnd(eventArg, mastery, owner, ds)
	mastery.CountChecker = 0;
end
function Mastery_RestoreTraining_UnitTurnEnd(eventArg, mastery, owner, ds)
	if owner.HP >= owner.MaxHP
		or owner.Cost < mastery.ApplyAmount then
		return;
	end
	
	local actions = {};
	local addHP = owner.MaxHP * mastery.ApplyAmount2 / 100;
	local _, costReasons = AddActionCost(actions, owner, -mastery.ApplyAmount, true);
	local hpReasons = AddActionRestoreHP(actions, owner, owner, addHP);
	DirectDamageByType(ds, owner, 'Heal', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false);
	ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', {CostType = owner.CostType.name, Count = -mastery.ApplyAmount});
	ReasonToUpdateBattleEventMulti(owner, ds, costReasons);
	ReasonToUpdateBattleEventMulti(owner, ds, hpReasons);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	return unpack(actions);
end
-- 특성 보복 사격.
function Mastery_CounterShoot_UnitTurnEnd(eventArg, mastery, owner, ds)
	mastery.CountChecker = 0;
end
-- 특성 마지막 불꽃. / 턴 종료 시 화염 SP 5 생성 구문
function Mastery_LastFlame_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	AddSPPropertyActions(actions, owner, 'Fire', mastery.ApplyAmount2, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnEnd'});
	return unpack(actions);
end
-- 특성 뿌리 내리기.
function Mastery_Rooting_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	if not owner.TurnState.Moved then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnEnd'});
	return unpack(actions);
end
-- 기선 제압
function Mastery_Forestallment_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;	-- 해당 마스터리는 턴당 1회만 발동합니다.
end
-- 자동 제압 사격
function Mastery_Module_ForestallmentFire_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;	-- 해당 마스터리는 턴당 1회만 발동합니다.
	SetInstantProperty(owner, mastery.name, nil);
end
-- 근접 제압 사격
function Mastery_CloseCheckFire_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	SetInstantProperty(owner, mastery.name, nil);
end
-- 은신처
function Mastery_Hideout_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or owner.PreBattleState
		or GetInstantProperty(owner, 'NoTurnEndMove')
		or not owner.Movable 
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or not GetBuffStatus(owner, 'AutoMovable', 'And') then
		return;
	end
	local unitCount = #(table.filter(GetAllUnitInSight(owner, true), function(o) 
		return owner ~= o and IsEnemy(owner, o);
	end));
	if unitCount == 0 then
		return;
	end
	
	local masteryTable = GetMastery(owner);
	-- 너보다 조금 더 높은 곳에
	local mastery_HigherThanYou = GetMasteryMastered(masteryTable, 'HigherThanYou');	
	-- 초원의 사냥꾼
	local mastery_BushHunting = GetMasteryMastered(masteryTable, 'BushHunting');
	-- 완벽한 잠복
	local mastery_PerfectCover = GetMasteryMastered(masteryTable, 'PerfectCover');
	
	if mastery_HigherThanYou then
		-- 그런 거 없다.		
	elseif mastery_BushHunting then
		-- 이미 SubBuff 효과가 있는 지형 효과 위치면 안함
		if IsObjectOnFieldEffectBuffAffector(owner, mastery_BushHunting.SubBuff.name) then
			return;
		end
	else
		-- 엄폐위치에서는 안함
		if not owner.Coverable or IsCoveredPosition(GetMission(owner), GetPosition(owner)) then
			return;
		end
	end
	
	local applyAmount = mastery.ApplyAmount;
	if mastery_HigherThanYou then
		applyAmount = mastery_HigherThanYou.ApplyAmount;
	elseif mastery_BushHunting then
		applyAmount = mastery_BushHunting.ApplyAmount;
	elseif mastery_PerfectCover then
		applyAmount = mastery_PerfectCover.ApplyAmount;
	end
	
	local prevPos = GetPosition(owner);
	local highHeightAmount = GetSystemConstant('HighHeight');
	
 	local distance = applyAmount + 0.4;
	local pos, score, _ = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function (self, adb)
		if adb.MoveDistance > distance then
			return -100;	-- 거리제한
		end
		if mastery_HigherThanYou then
			local height = GetHeight(adb.Position, prevPos);
			if height <= highHeightAmount then
				return -100;
			end
			return 100 + math.random(0, 100) / 100;
		elseif mastery_BushHunting then
			if not adb.OnFieldEffectAffector(mastery_BushHunting.SubBuff.name) then
				return -100;
			end
			return 100 + math.random(0, 100) / 100;
		else
			if not adb.Coverable then
				return -100;
			end
			return adb.CoverScore + math.random(0, 100) / 100;
		end
	end, {}, {});
	if score == nil or score <= 0 then
		-- 엄폐되는 근처 지역 없나봄..
		return;
	end
	
	
	local ownerKey = GetObjKey(owner);
	ds:ChangeCameraTarget(ownerKey, '_SYSTEM_');
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Move(ownerKey, pos);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnEnd'});
	
	local actions = {};
	local mastery_HelpMePlease = GetMasteryMastered(GetMastery(owner), 'HelpMePlease');
	if mastery_HelpMePlease then
		MasteryActivatedHelper(ds, mastery_HelpMePlease, owner, 'UnitTurnEnd_Self');
		InsertBuffActions(actions, owner, owner, mastery_HelpMePlease.Buff.name, 1);
	end
	return unpack(actions);
end
function Mastery_ShakingSpray_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	return Result_DestroyObject(owner, false, true);
end
function Mastery_OneSpoon_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;	-- 해당 마스터리는 턴당 1회만 발동합니다.	
end
-- 전술적 보완 & 전술적 집중 공용
function Mastery_TacticalShared_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	return Result_UpdateInstantProperty(owner, mastery.name, {});
end
function Mastery_Wanderer_UnitTurnEnd(eventArg, mastery, owner, ds)
	mastery.CountChecker = 0;
end
function Mastery_Mutation_UnitTurnEnd(eventArg, mastery, owner, ds)
	local actions = {};
	local removeBuffList = {};
	local addBuffList = {};
	
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	
	local debuffList = GetBuffType(owner, 'Debuff');
	if #debuffList > 0 then
		for index, debuff in ipairs (debuffList) do
			table.insert(actions, Result_RemoveBuff(owner, debuff.name, true));
			table.insert(removeBuffList, debuff.name);
			local goodBuffName = goodBuffPicker:PickBuff();
			if goodBuffName then
				InsertBuffActions(actions, owner, onwer, goodBuffName, 1, true, function(b) b.UseAddedMessage = false end);
				table.insert(addBuffList, goodBuffName);
			end
		end
	end
	local totalCount = #removeBuffList;
	if totalCount > 0 then
		local objKey = GetObjKey(owner);
		MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
		for _, buffName in ipairs(removeBuffList) do
			ds:UpdateBattleEvent(objKey, 'BuffDischarged', { Buff = buffName });
		end
		for _, buffName in ipairs(addBuffList) do
			ds:UpdateBattleEvent(objKey, 'BuffInvoked', { Buff = buffName });
		end
		ds:Sleep(1.5);
	end
	local addCount = #addBuffList;
	if addCount > 0 then
		-- 유쾌한 마녀
		local masteryTable = GetMastery(owner);
		local mastery_HappyWitch = GetMasteryMastered(masteryTable, 'HappyWitch');
		if mastery_HappyWitch then
			local applyAct = -1 * math.floor(addCount/mastery_HappyWitch.ApplyAmount) * mastery_HappyWitch.ApplyAmount2;
			local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
			if added then
				ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct, Delay = true });
			end
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
			MasteryActivatedHelper(ds, mastery_HappyWitch, owner, 'UnitTurnEnd_Self', false);
		end
	end
	return unpack(actions);
end
-- 무모한 돌진
function Mastery_RushHeadlong_UnitTurnEnd(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker == 0 then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
	local allyList = GetTargetInRangeSight(owner, 'Sight', 'Team', true);
	local enemyList = GetTargetInRangeSight(owner, 'Sight', 'Enemy', true);
	if #enemyList <= #allyList then
		return;
	end
	local actions = {};
	local applyAct = -1 * mastery.ApplyAmount2;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
	
	local masteryTable = GetMastery(owner);
	local mastery_Opportunist = GetMasteryMastered(masteryTable, 'Opportunist');
	if mastery_Opportunist and IsCoveredPosition(GetMission(owner), GetPosition(owner)) then
		InsertBuffActions(actions, owner, owner, mastery_Opportunist.Buff.name, 1, true);
		MasteryActivatedHelper(ds, mastery_Opportunist, owner, 'UnitTurnEnd_Self');
	end
	local mastery_Bomber = GetMasteryMastered(masteryTable, 'Bomber');
	if mastery_Bomber then
		InsertBuffActions(actions, owner, owner, mastery_Bomber.Buff.name, 1, true);
		MasteryActivatedHelper(ds, mastery_Bomber, owner, 'UnitTurnEnd_Self');
	end
	return unpack(actions);
end
-- 기다림
function Mastery_Waiting_UnitTurnEnd(eventArg, mastery, owner, ds)
	-- 이미 턴 종료가 된 상태이므로 Wait를 보면 안 되고 Act를 봐야 한다.
	if owner.Act < mastery.ApplyAmount then
		return;
	end
	
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	
	local goodBuff = goodBuffPicker:PickBuff();
	if goodBuff == nil then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	local actions = {};
	InsertBuffActions(actions, owner, owner, goodBuff, 1, true);
	return unpack(actions);
end
-- 고통의 황혼
function Mastery_TwilightOfPain_UnitTurnEnd(eventArg, mastery, owner, ds)
	local lostHPRatio = 1 - owner.HP / owner.MaxHP;
	local stepCount = math.floor(lostHPRatio * 100 / mastery.ApplyAmount);	-- ApplyAmount 당
	if stepCount <= 0 then
		return;
	end
	local applyAct = -1 * stepCount * mastery.ApplyAmount2;					-- ApplyAmount2 만큼 감소
	local actions = {};
	local ownerKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	local mastery_LastBerserker = GetMasteryMastered(GetMastery(owner), 'LastBerserker');
	if mastery_LastBerserker then
		local stepCount = math.floor(lostHPRatio * 100 / mastery_LastBerserker.ApplyAmount);	-- ApplyAmount 당
		local addSp = stepCount * mastery_LastBerserker.ApplyAmount2;
		AddSPPropertyActionsObject(actions, owner, addSp);
		MasteryActivatedHelper(ds, mastery_LastBerserker, owner, 'UnitTurnEnd_Self');
	end
	return unpack(actions);
end
-- 저수
function Mastery_Neguri_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 만피 이상이면 발동 안함
	if owner.HP >= owner.MaxHP then
		return;
	end
	if not IsObjectOnFieldEffectBuffAffector(owner, { mastery.Buff.name, mastery.SubBuff.name } ) then
		return;
	end
	local applyAmount = mastery.ApplyAmount;
	local mission = GetMission(owner);
	if mission.Weather.name == 'Rain' then
		applyAmount = applyAmount * (1 + mastery.ApplyAmount2 / 100);
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local addHP = math.floor(owner.MaxHP * applyAmount/100);
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	DirectDamageByType(ds, owner, 'HPRestore', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitTurnEnd_Self'});
	AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	return unpack(actions);
end
-- 번영
function Mastery_Prosperity_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 만피 미만이면 발동 안함
	if owner.HP < owner.MaxHP then
		return;
	end
	-- 턴 대기시간 감소
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
	local applyAct = -1 * mastery.ApplyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	local objKey = GetObjKey(owner);
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 습기
function Mastery_Damp_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if not IsObjectOnFieldEffectBuffAffector(owner, { mastery.Buff.name, mastery.SubBuff.name } ) then
		return;
	end
	local applyAmount = mastery.ApplyAmount;
	local mission = GetMission(owner);
	if mission.Weather.name == 'Rain' then
		applyAmount = applyAmount + mastery.ApplyAmount;
	end
	-- 턴 대기시간 감소
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
	local applyAct = -1 * applyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	local objKey = GetObjKey(owner);
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 서릿바람
function Mastery_FrostWind_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 근접 범위
	local meleeRange = CalculateRange(owner, 'Box1_Attack', GetPosition(owner));
	local targetObjects = BuffHelper.GetObjectsInRange(GetMission(owner), meleeRange, function(target)
		return IsEnemy(owner, target);
	end);
	if #targetObjects == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	local mastery_Blizzard = GetMasteryMastered(GetMastery(owner), 'Blizzard');
	if mastery_Blizzard then
		MasteryActivatedHelper(ds, mastery_Blizzard, owner, 'UnitTurnEnd_Self');
	end
	for _, target in ipairs(targetObjects) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
		if mastery_Blizzard then
			AddActionApplyActForDS(actions, target, mastery_Blizzard.ApplyAmount, ds, 'Hostile');
		end
	end
	return unpack(actions);
end
-- 모래바람
function Mastery_Sandstorm_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local targetObjects = {};
	-- 하얀 모래바람
	local mastery_WhiteSandstorm = GetMasteryMastered(GetMastery(owner), 'WhiteSandstorm');
	if mastery_WhiteSandstorm then
		-- 반경 ApplyAmount 칸
		targetObjects = Linq.new(GetNearObject(owner, mastery_WhiteSandstorm.ApplyAmount + 0.4))
			:where(function(o) return IsEnemy(owner, o) end)
			:toList();
	else
		-- 근접 범위
		local meleeRange = CalculateRange(owner, 'Box1_Attack', GetPosition(owner));
		targetObjects = BuffHelper.GetObjectsInRange(GetMission(owner), meleeRange, function(target)
			return IsEnemy(owner, target);
		end);
	end
	if #targetObjects == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	for _, target in ipairs(targetObjects) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	end
	return unpack(actions);
end
-- XX에서 XX로
function Mastery_FieldEffectToFieldEffect_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if mastery.DuplicateApplyChecker == 0 then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
	local testBuffList = {};
	if mastery.Buff and mastery.Buff.name then
		table.insert(testBuffList, mastery.Buff.name);
	end
	if mastery.SubBuff and mastery.SubBuff.name then
		table.insert(testBuffList, mastery.SubBuff.name);
	end	
	local isOnFieldEffect = IsObjectOnFieldEffectBuffAffector(owner, testBuffList);
	if not isOnFieldEffect then
		return;
	end
	-- 턴 대기시간 감소
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
	local applyAct = -1 * mastery.ApplyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	-- 수풀에서 수풀로
	if mastery.name == 'BushToBush' then
		local masteryTable = GetMastery(owner);
		-- 초원의 사냥꾼
		local mastery_BushHunting = GetMasteryMastered(masteryTable, 'BushHunting');
		if mastery_BushHunting then
			MasteryActivatedHelper(ds, mastery_BushHunting, owner, 'UnitTurnEnd_Self', true);
			InsertBuffActions(actions, owner, owner, mastery_BushHunting.Buff.name, 1, true);
		end
	end
	return unpack(actions);
end
-- 무리짓기
function Mastery_Grouping_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local allyList = GetTargetInRangeSight(owner, 'Sight', 'Team', true);
	local enemyList = GetTargetInRangeSight(owner, 'Sight', 'Enemy', true);
	if #enemyList >= #allyList or #enemyList == 0 then
		return;
	end
	-- 턴 대기시간 감소
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
	local applyAct = -1 * mastery.ApplyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 최상의 상태
function Mastery_BestCondition_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if owner.HP < owner.MaxHP then
		return;
	end
	-- 턴 대기시간 감소
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
	local applyAct = -1 * mastery.ApplyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 소각의 희열
function Mastery_CatharsisOfIncineration_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local curRange = mastery.Range;
	local mission = GetMission(owner);	
	local masteryTable = GetMastery(owner);
	local mastery_SeaOfFire = GetMasteryMastered(masteryTable, 'SeaOfFire');
	if mastery_SeaOfFire then
		curRange = mastery_SeaOfFire.Range;
	end
	local targetRange = CalculateRange(owner, curRange, GetPosition(owner));
	local targetCount = 0;
	for _, targetPos in ipairs(targetRange) do
		local instances = GetFieldEffectByPosition(mission, targetPos);
		if instances then
			for _, instance in ipairs(instances) do
				if instance.Owner.name == 'Fire' then
					targetCount = targetCount + 1;
					break;
				end
			end
		end
	end
	local finalCount = math.floor(targetCount/mastery.ApplyAmount);
	if finalCount == 0 then
		return;
	end
	-- 턴 대기시간 감소
	local actions = {};	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
	local applyAct = -1 * finalCount * mastery.ApplyAmount2;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 그물 연결망
function Mastery_WebNetwork_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local curRange = mastery.Range;
	local mission = GetMission(owner);	
	local targetRange = CalculateRange(owner, curRange, GetPosition(owner));
	local targetCount = 0;
	for _, targetPos in ipairs(targetRange) do
		local instances = GetFieldEffectByPosition(mission, targetPos);
		if instances then
			for _, instance in ipairs(instances) do
				if instance.Owner.name == mastery.FieldEffect.name then
					targetCount = targetCount + 1;
					break;
				end
			end
		end
	end
	local finalCount = math.floor(targetCount/mastery.ApplyAmount);
	if finalCount == 0 then
		return;
	end
	-- 턴 대기시간 감소
	local actions = {};	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
	local applyAct = -1 * finalCount * mastery.ApplyAmount2;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 그림자 걷기
function Mastery_ShadowStep_UnitTurnEnd(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if IsExposedByEnemy(owner) then
		return;
	end
	local enemyList = GetTargetInRangeSight(owner, 'Sight', 'Enemy', true);
	if #enemyList == 0 then
		return;
	end
	-- 턴 대기시간 감소
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self', true);
	local applyAct = -1 * mastery.ApplyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 마력 가속 회로
function Mastery_AccelerationCircuit_UnitTurnEnd(eventArg, mastery, owner, ds)
	-- 마력 노심
	local masteryTable = GetMastery(owner);
	local mastery_MagicCore = GetMasteryMastered(masteryTable, 'MagicCore');
	if not mastery_MagicCore then
		return;
	end
	local actions = {};
	local buff = GetBuff(owner, mastery.Buff.name);
	if buff then
		local stepCount = math.floor(buff.Lv / mastery.ApplyAmount2);	-- ApplyAmount 당
		if stepCount <= 0 then
			return;
		end
		local applyAct = -1 * stepCount * mastery.ApplyAmount;			-- ApplyAmount 만큼 감소
		local ownerKey = GetObjKey(owner);
		MasteryActivatedHelper(ds, mastery_MagicCore, owner, 'UnitTurnEnd_Self');
		MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
		local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
		if added then
			ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	else
		-- ApplyAmount 개 생성하고 퉁침
		MasteryActivatedHelper(ds, mastery_MagicCore, owner, 'UnitTurnEnd_Self');
		MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, mastery.ApplyAmount, true);
	end
	return unpack(actions);
end
-- 강철의 전투법사
function Mastery_IronBattleMage_UnitTurnEnd(eventArg, mastery, owner, ds)
	if HasBuff(owner, mastery.Buff.name) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	
	-- 철의 요새
	local masteryTable = GetMastery(owner);
	local mastery_FortressOfIron = GetMasteryMastered(masteryTable, 'FortressOfIron');
	if mastery_FortressOfIron then
		InsertBuffActions(actions, owner, owner, 'FortressOfIron', 1, true, nil, true);
	end
	
	return unpack(actions);
end
-- 떠돌이 싸움꾼
function Mastery_WandererFighter_UnitTurnEnd(eventArg, mastery, owner, ds)
	local targetList = GetTargetInRangeSight(owner, mastery.Range, 'Team', true);
	if #targetList > 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnEnd_Self');
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 버프 추가.
-------------------------------------------------------------------------------

-----------------------------------------------------------------------
-- 버프 제거.
-------------------------------------------------------------------------------
function Mastery_Awakening_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= mastery.SubBuff.name then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'BuffRemoved'});
	return unpack(actions);
end
-- 연막 이동
function Mastery_MoveWithSmokeScreen_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.BuffName ~= mastery.Buff.name then
		return;
	end
	if eventArg.Buff.IsTurnShow then
		return;
	end	
	local actions = {};
	local modifier = function(b)
		b.IsTurnShow = true;
	end;
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, modifier);
	table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', true, owner, mastery.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Turn', mastery.ApplyAmount, owner, mastery.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', mastery.ApplyAmount, owner, mastery.Buff.name, true, true));
	MasteryActivatedHelper(ds, mastery, owner, 'BuffRemoved_Self');
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 어빌리티 사용 [AbilityUsed]
-------------------------------------------------------------------------------
-- 막 잡은 먹잇감
function Mastery_FastFishing_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.name ~= 'PreyThrow' then
		return;
	end
	
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and IsDead(targetInfo.Target);
	end) then
		return;
	end
	
	local actions = {};
	AddActionRestoreActions(actions, owner);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 빛보다 빠른 주먹
function Mastery_FlashFist_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Melee' then
		SetInstantProperty(owner, mastery.name, nil);
		return;
	end
	local buffGivedSet = GetInstantProperty(owner, mastery.name) or {};
	local info = FindAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and IsMeleeDistance(GetPosition(owner), GetPosition(targetInfo.Target)) and IsSamePosition(eventArg.UserInfo.UsingPos, GetPosition(targetInfo.Target)) and buffGivedSet[GetObjKey(targetInfo.Target)];
	end);
	SetInstantProperty(owner, mastery.name, nil);
	if not info then
		return;
	end
	local actions = {};
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 물실호기
function Mastery_StrikeWhileTheIronIsHot_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Melee'
		or mastery.DuplicateApplyChecker > 0 then
		SetInstantProperty(owner, mastery.name, nil);
		return;
	end
	local buffGivedSet = GetInstantProperty(owner, mastery.name) or {};
	local info = FindAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and IsMeleeDistance(GetPosition(owner), GetPosition(targetInfo.Target)) and IsSamePosition(eventArg.UserInfo.UsingPos, GetPosition(targetInfo.Target)) and buffGivedSet[GetObjKey(targetInfo.Target)];
	end);
	SetInstantProperty(owner, 'StrikeWhileTheIronIsHot', nil);
	if not info then
		return;
	end
	
	local usingTarget = info.Target;
	
	local targetPos;
	local ability = eventArg.Ability;
	if ability.TargetType == 'Single' then
		if eventArg.UserInfo.Target.HP <= 0 then
			return;
		end
		targetPos = GetPosition(eventArg.UserInfo.Target);
	else
		targetPos = eventArg.PositionList[#(eventArg.PositionList)];
	end
	
	local range = CalculateRange(owner, ability.TargetRange, GetPosition(owner));
	if not PositionInRange(range, targetPos) then
		return;
	end
	
	local resultModifier = { ReactionAbility = true, StrikeWhileTheIronIsHot = true };
		
	local masteryTable = GetMastery(owner);
		
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});	
	
	local actions = {};
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery.name}});
	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;	
	
	resultModifier.BattleEvents = battleEvents;
	local config = {NoCamera = true};
	
	local eventCmd = nil;
	if SafeIndex(eventArg, 'DirectingConfig', 'Preemptive') then
		resultModifier.ReactionAbility = true;
		resultModifier.Moving = SafeIndex(eventArg, 'ResultModifier', 'Moving');
		config.Preemptive = true;
		config.PreemptiveOrder = 2;
		eventCmd = eventArg.ActionID;
	end
	local chainAttack = Result_UseAbility(owner, ability.name, targetPos, resultModifier, true, config);
	if SafeIndex(eventArg, 'DirectingConfig', 'Preemptive') then
		chainAttack.nonsequential = true;
	end
	chainAttack.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, ability.TargetRange, GetPosition(owner)), targetPos)
	end;
	chainAttack.free_action = true;
	if eventCmd ~= nil then	
		chainAttack._ref = eventCmd;
		chainAttack._ref_offset = 0;
	end
	table.insert(actions, chainAttack);
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
	end, nil, true, true));
	return unpack(actions);
end
-- 무기 파괴
function Mastery_WeaponBreaker_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsGetAbilitySubType(eventArg.Ability, 'Physical') then
		return;
	end
	local actions = {};
	local alreadyTarget = {};
	local applyAmount = mastery.ApplyAmount;
	-- 백병전의 달인
	local mastery_MeleeBattleMaster = GetMasteryMastered(GetMastery(owner), 'MeleeBattleMaster');
	if mastery_MeleeBattleMaster then
		applyAmount = 100;
	end
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState == 'Dodge' then
			return;
		end
		local target = targetInfo.Target;
		if alreadyTarget[GetObjKey(target)] then
			return;
		end
		alreadyTarget[GetObjKey(target)] = true;
		
		if not RandomTest(applyAmount) then
			return;
		end
		
		InsertBuffActions(actions, self, target, mastery.Buff.name, 1, true);
	end);
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	
	return unpack(actions);
end
-- 지옥불 팔찌
function Mastery_Bangle_HellFire_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local actions = {};
	local alreadyTarget = {};
	
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.AttackerState ~= 'Critical' or targetInfo.DefenderState == 'Dodge' then
			return;
		end
		local target = targetInfo.Target;
		if alreadyTarget[GetObjKey(target)] then
			return;
		end
		alreadyTarget[GetObjKey(target)] = true;
		
		local targetBuffList = GetBuffType(target, 'Buff');
		if #targetBuffList > 0 then
			for _, buff in ipairs(targetBuffList) do
				InsertBuffActions(actions, owner, target, buff.name, -buff.Lv);
			end
			if target.CostType.name == 'Vigor' then
				AddActionCostForDS(actions, target, -math.floor(#targetBuffList / mastery.ApplyAmount) * mastery.ApplyAmount2, true, nil, ds);
			end
		end
	end);
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	
	return unpack(actions);
end
-- 드라키의 반짝이는 비늘
function Mastery_Amulet_Draky_Set2_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
			return targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState == 'Hit';
		end) then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	local actions = {};
	AddActionCostForDS(actions, owner, mastery.ApplyAmount, true, nil, ds);
	return unpack(actions);
end
-- 두려움이 없는 자 - 5 세트
function Mastery_DrakyNoFearrSet5_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local actions = {};
	local allowRace = Set.new({'Human', 'Beast'});
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if allowRace[targetInfo.Target.Race.name] == nil 
			or targetInfo.AttackerState ~= 'Critical' 
			or targetInfo.DefenderState == 'Dodge' then
			return;
		end
		
		InsertBuffActions(actions, owner, targetInfo.Target, mastery.Buff.name, 1);
	end);
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 동족 포식
function Mastery_Cannibalization_Failed(mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
	mastery.CountChecker = 0;
	local firstInvoker = GetInstantProperty(owner, 'Cannibalization_Invoker');
	local damageAction = Result_Damage(owner.MaxHP, 'Normal', 'Hit', firstInvoker, owner, 'System', 'Etc', mastery);
	local realDamage, reasons = ApplyDamageTest(owner, owner.MaxHP, 'System');
	local isDead = owner.HP <= realDamage;
	local remainHP = math.clamp(owner.HP - realDamage, 0, owner.MaxHP);
	DirectDamageByType(ds, owner, 'Cannibalization_Failed', owner.MaxHP, remainHP, true, isDead, actionID, 0);
	SetInstantProperty(owner, 'Cannibalization_Invoker', nil);
	SetInstantProperty(owner, 'Undead', nil);
	return damageAction;
end
function Mastery_Cannibalization_AbilityUsed(eventArg, mastery, owner, ds)
	if SafeIndex(eventArg, 'ResultModifier', 'Cannibalization') == nil then
		return;
	end

	-- TODO: 동족 포식에 사용된 어빌리티가 광역기가 되면 로직 개선이 필요함
	local firstTargetInfo = eventArg.PrimaryTargetInfos[1];
	if firstTargetInfo == nil then
		return Mastery_Cannibalization_Failed(mastery, owner, ds);
	end
	
	if not firstTargetInfo.IsDead then
		return Mastery_Cannibalization_Failed(mastery, owner, ds);
	end
	
	local beastTypeCls = GetBeastTypeClassFromObject(firstTargetInfo.Target);
	if beastTypeCls == nil then
		return Mastery_Cannibalization_Failed(mastery, owner, ds);
	end
	
	local evolutionLevel = beastTypeCls.EvolutionType[beastTypeCls.EvolutionStage].Level;
	mastery.DuplicateApplyChecker = 0;
	mastery.CountChecker = 0;
	SetInstantProperty(owner, 'Undead', nil);
	SetInstantProperty(owner, 'Cannibalization_Invoker', nil);
	
	local actions = {};
	if evolutionLevel == 1 then 	-- 성장기
		AddActionRestoreHPForDS(actions, owner, owner, owner.MaxHP * mastery.ApplyAmount / 100, ds, 'Cannibalization_Succeeded');
		AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount3, ds, 'Friendly');
	elseif evolutionLevel == 2 then
		AddActionRestoreHPForDS(actions, owner, owner, owner.MaxHP * mastery.ApplyAmount2 / 100, ds, 'Cannibalization_Succeeded');
		AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount4, ds, 'Friendly');
	else
		AddActionRestoreHPForDS(actions, owner, owner, owner.MaxHP, ds, 'Cannibalization_Succeeded');
		if owner.TurnState.TurnEnded then
			table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
		else
			table.append(actions, {GetInitializeTurnActions(owner)});
		end
	end
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 식인 야수
function Mastery_SlaughterBeast_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local needCheckBuff = false;
	local applyBuffGroup = SafeIndex(GetWithoutError(eventArg.Ability, 'ApplyTargetBuff'), 'Group');
	local applySubBuffGroup = SafeIndex(GetWithoutError(eventArg.Ability, 'ApplyTargetSubBuff'), 'Group');
	if applyBuffGroup == mastery.BuffGroup.name or applySubBuffGroup == mastery.BuffGroup.name then
		needCheckBuff = true;
	end
	
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.Target.Race.name ~= 'Human' then
			return false;
		end
		return targetInfo.IsDead or (needCheckBuff and targetInfo.BuffApplied);
	end) then
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 기회창출자
function Mastery_Chancemaker_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.HitRateType ~= 'Throw'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local actions = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' then
			AddActionApplyActForDS(actions, targetInfo.Target, mastery.ApplyAmount, ds, 'Hostile');
		end
	end);
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 재빠른 준비
function Mastery_RapidPreparation_AbilityUsed(eventArg, mastery, owner, ds)
	if owner.TurnState.TurnEnded
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	return Result_DirectingScript(function(mid, ds, args)
		local availableAbilities = GetAvailableAbility(owner);
		if #availableAbilities == 0 then
			return;
		end
		
		local actions = {};
		AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
		MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
		
		local mastery_Chancemaker = GetMasteryMastered(GetMastery(owner), 'Chancemaker');
		if mastery_Chancemaker then
			AddActionCostForDS(actions, owner, mastery_Chancemaker.ApplyAmount, true, nil, ds);
			AddActionApplyActForDS(actions, owner, -mastery_Chancemaker.ApplyAmount, ds, 'Friendly');
		end
		
		return unpack(actions)
	end, nil, true, true);
end
-- 나는 포기하지 않는다.
function Mastery_IDontGiveUp_AbilityUsed(eventArg, mastery, owner, ds)
	local actions = {};
	table.insert(actions, Result_UpdateInstantProperty(owner, 'IDontGiveUp_SweepTarget', nil));
	if mastery.CountChecker == 0 then
		return unpack(actions);
	end
	
	mastery.CountChecker = 0;
	
	local allDead = true;
	for _, target in ipairs(GetInstantProperty(owner, 'IDontGiveUp_Target')) do
		if not IsDead(target) then
			allDead = false;
			break;
		end
	end
	SetInstantProperty(owner, 'IDontGiveUp_Target', nil);
	if allDead then
		return unpack(actions);
	end
	
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount2);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 지원 회복
function Mastery_SupportHeal_AbilityUsed(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or eventArg.Ability.Type ~= 'Attack'
		or mastery.CountChecker >= mastery.ApplyAmount2
		or not GetBuffStatus(owner, 'Healable', 'And')
		or owner.IsMovingNow > 0 then
		return;
	end
	
	local healAbility = FindAbilityIf(owner, function (ability) 
		return ability.Type == 'Heal' and IsGetAbilitySubType(ability, 'ESP') and ability.TargetType == 'Single'; 
	end);
	
	if healAbility == nil then
		return;
	end
	
	local range = CalculateRange(owner, healAbility.TargetRange, GetPosition(owner));
	local usingTarget = nil;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		if targetInfo.Target 
			and targetInfo.Target ~= onwer
			and targetInfo.Target.HP > 0 
			and IsInSight(owner, targetInfo.Target, true) 
			and PositionInRange(range, GetPosition(targetInfo.Target)) 
			and IsTeamOrAlly(owner, targetInfo.Target) 
			and targetInfo.Target.HP <= targetInfo.Target.MaxHP * mastery.ApplyAmount / 100 then
			usingTarget = targetInfo.Target;
			return false;
		end
		return true;
	end);
	
	if usingTarget == nil then
		return;
	end
	
	local applyAct = mastery.ApplyAmount3;
	mastery.CountChecker = mastery.CountChecker + 1;
	
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	local battleEvents = {};
	if action then
		ds:WorldAction(action, true);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	table.insert(battleEvents, {Object = owner, EventType = 'HealSupport', Args = nil});
	
	local healAction = Result_UseAbilityTarget(owner, healAbility.name, usingTarget, {ReactionAbility=true, SupportHeal=true, BattleEvents=battleEvents}, true, {});
	healAction.free_action = true;
	healAction.final_useable_checker = function()
		return not GetBuffStatus(owner, 'Unconscious', 'Or')
			and PositionInRange(CalculateRange(owner, healAbility.TargetRange, GetPosition(owner)), GetPosition(usingTarget));
	end;
	return healAction;
end
function Mastery_AbilityUsed_CriticalHit(eventArg, mastery, owner, ds, applyFunc)
	local actions = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.Target and targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState == 'Hit' then
			applyFunc(actions, targetInfo);
		end
	end);
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);	
end
-- 강화된 라이플
function Mastery_Module_Rifle_AbilityUsed(eventArg, mastery, owner, ds)
	if SafeIndex(owner, 'Weapon', 'Type', 'name') ~= 'OuterDevice_Rifle'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	return Mastery_AbilityUsed_CriticalHit(eventArg, mastery, owner, ds, function(actions, targetInfo)
		InsertBuffActions(actions, owner, targetInfo.Target, mastery.Buff.name, 1, true);
	end);
end
-- 강화된 냉각 레이저
function Mastery_Module_IceLaser_AbilityUsed(eventArg, mastery, owner, ds)
	if SafeIndex(owner, 'Weapon', 'Type', 'name') ~= 'OuterDevice_IceLaser'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	return Mastery_AbilityUsed_CriticalHit(eventArg, mastery, owner, ds, function(actions, targetInfo)
		AddActionApplyActForDS(actions, targetInfo.Target, mastery.ApplyAmount, ds, 'Hostile');
	end);
end
-- 강화된 화염 방사기
function Mastery_Module_Flamethrower_AbilityUsed(eventArg, mastery, owner, ds)
	if SafeIndex(owner, 'Weapon', 'Type', 'name') ~= 'OuterDevice_FlameThrower'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	return Mastery_AbilityUsed_CriticalHit(eventArg, mastery, owner, ds, function(actions, targetInfo)
		InsertBuffActions(actions, owner, targetInfo.Target, mastery.Buff.name, 1, true);
	end);
end
-- 다중 처리
function Mastery_MultiProcessing_AbilityUsed(eventArg, mastery, owner, ds)
	if not IsProtocolAbility(eventArg.Ability) 
		or owner.TurnState.TurnEnded then
		return;
	end
	
	mastery.CountChecker = mastery.CountChecker + 1;
end
-- 정보 제어
function Mastery_InformationControl_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.name ~= 'SearchProtocol' then
		return;
	end
	local nearestTarget = nil;
	local minDist = 999999;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		if targetInfo.Target == owner or not IsEnemy(owner, targetInfo.Target) then
			return;
		end
		if nearestTarget == nil or minDist > GetDistance3D(GetPosition(owner), GetPosition(targetInfo.Target)) then
			nearestTarget = targetInfo.Target;
			minDist = GetDistance3D(GetPosition(owner), GetPosition(targetInfo.Target));
		end
	end);
	if nearestTarget == nil then
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, owner, nearestTarget, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 재빠른 반응 공격
function Mastery_RapidCounterAttack_AbilityUsed(eventArg, mastery, owner, ds)
	if not SafeIndex(eventArg.ResultModifier, 'Counter')
		and not SafeIndex(eventArg.ResultModifier, 'ReactionAbility') then
		return;
	end
	
	local actions = {};
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 자동 재정비
function Mastery_Module_AutoReload_AbilityUsed(eventArg, mastery, owner, ds)
	if owner.TurnState.TurnEnded 	-- 턴중에만 발동
		or eventArg.Ability.Type ~= 'Attack' then		
		return;
	end
	if owner.Cost < mastery.ApplyAmount2 then
		return;
	end
	
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return targetInfo.IsDead and (targetInfo.PrevHP == targetInfo.MaxHP) and not targetInfo.Target.Obstacle;
	end) then
		return;
	end
	
	local actions = {};
	if mastery.ApplyAmount == 1 then
		AddActionRestoreActions(actions, owner);
	elseif mastery.ApplyAmount > 1 then
		table.append(actions, {GetInitializeTurnActions(owner)});
		table.insert(actions, Result_FireWorldEvent('ActionPointRestored', {Unit = owner}, self));
	end
	-- UnitKilled 이벤트 핸들러에서 돌려줄거임 
	-- MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	mastery.CountChecker = 1;	-- UnitKilled이벤트 단에서 이용
	return unpack(actions);	
end
-- 흑철 불꽃검
function Mastery_Sword_BlackIron_Epic_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local actions = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		if targetInfo.AttackerState ~= 'Critical' or targetInfo.DefenderState == 'Dodge' then
			return;
		end
		InsertBuffActions(actions, owner, targetInfo.Target, mastery.Buff.name, 1, true);
	end);
	if not table.empty(actions) then
		MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	end
	return unpack(actions);
end
function Mastery_Sword_BlackIron_Fire_Epic_AbilityUsed(eventArg, mastery, owner, ds)
	return Mastery_Sword_BlackIron_Epic_AbilityUsed(eventArg, mastery, owner, ds);
end
function Mastery_Sword_BlackIron_Ice_Epic_AbilityUsed(eventArg, mastery, owner, ds)
	return Mastery_Sword_BlackIron_Epic_AbilityUsed(eventArg, mastery, owner, ds);
end
function Mastery_Sword_BlackIron_Wind_Epic_AbilityUsed(eventArg, mastery, owner, ds)
	return Mastery_Sword_BlackIron_Epic_AbilityUsed(eventArg, mastery, owner, ds);
end
function Mastery_BloodWitch_AbilityUsed(eventArg, mastery, owner, ds)
	if mastery.BloodSucker == 0 and mastery.BindingPower == 0 then
		return;
	end
	
	local bloodWitchEvent = {EventFlag = {}};
	
	if mastery.BloodSucker ~= 0 then
		bloodWitchEvent.EventFlag.BloodSucker = true;
		bloodWitchEvent.RestoreHPAmount = mastery.BloodSucker;
	end
	
	if mastery.BindingPower ~= 0 then
		bloodWitchEvent.EventFlag.BindingPower = true;
		bloodWitchEvent.Buff = mastery.Buff.name;
	end
	
	mastery.BloodSucker = 0;
	mastery.BindingPower = 0;
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return Result_FireWorldEvent('BloodWitchApplied', bloodWitchEvent, owner);
end
-- 기습 훈련
function Mastery_AmbushTraining_AbilityUsed(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	
	local targetList = Linq.new(GetInstantProperty(owner, 'AmbushingKillList') or {})
		:selectMany(function(target) return GetTargetInRangeSight(target, mastery.Range, 'Team|Ally') end)
		:distinct()
		:toList();
	
	local actions = {};
	for index, target in ipairs (targetList) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	end
	
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	
	mastery.CountChecker = 0;
	return unpack(actions);
end
-- 이중 극독
function Mastery_VenomExplosion_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local explodeAbility = mastery.ChainAbility;
	if eventArg.Unit ~= owner and eventArg.Ability.name ~= explodeAbility then
		return;
	end
	local actions = {};
	if eventArg.Unit == owner then
		-- 폭발 처리
		if mastery.CountChecker <= 0 then
			return;
		end
		mastery.CountChecker = 0;
		local targetList = GetInstantProperty(owner, 'VenomExplosionKillList') or {};
		SetInstantProperty(owner, 'VenomExplosionKillList', nil);
		for _, target in ipairs(targetList) do
			local flameExplosionInitializer = function(sprayObject, args)
				SetInstantProperty(sprayObject, 'MonsterType', 'Explosion');
				if eventArg.Killer then
					SetExpTaker(sprayObject,GetExpTaker(eventArg.Killer));
				end
				UNIT_INITIALIZER(sprayObject, sprayObject.Team, {Patrol = false});
			end;
			
			local usingPos = GetPosition(target);
			local useAbilityName = explodeAbility;

			local explosionObjKey = GenerateUnnamedObjKey(GetMission(owner));
			local createAction = Result_CreateMonster(explosionObjKey, 'Explosion', usingPos, '_neutral_',  flameExplosionInitializer, {}, 'DoNothingAI', nil, true);
			local mission = GetMission(owner);
			ApplyActions(mission, { createAction }, false);
			local explosionObj = GetUnit(mission, explosionObjKey);
			-- 터지는 오브젝트의 MaxHP 비례 데미지 때문에, 생성된 오브젝트의 Base_MaxHP를 원본 오브젝트의 MaxHP로 덮어씀
			explosionObj.Base_MaxHP = owner.MaxHP;
			InvalidateObject(explosionObj);
			-- 중독 디버프 리스트 전달
			local poisonList = GetInstantProperty(target, 'VenomExplosionPoisonList') or {};
			SetInstantProperty(explosionObj, 'VenomExplosionPoisonList', poisonList);			
			-- 어빌리티 발동 시 특성 연출
			local battleEvents = {};
			table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery.name} });
			local abilityUse = Result_UseAbility(explosionObj, useAbilityName, usingPos, {BattleEvents = battleEvents}, true);
			abilityUse.sequential = true;
			-- 액션 추가
			table.insert(actions, abilityUse);
			table.insert(actions, Result_DestroyObject(explosionObj, false, true));
		end
		if #actions > 0 then
			MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
		end
	else
		-- 폭발 후처리
		local poisonList = GetInstantProperty(eventArg.Unit, 'VenomExplosionPoisonList') or {};
		if #poisonList == 0 then
			return;
		end
		local hitTargetInfos = FilterAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
			return targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0;
		end);
		if #hitTargetInfos == 0 then
			return;
		end
		for _, targetInfo in ipairs(hitTargetInfos) do
			for _, buffName in ipairs(poisonList) do
				InsertBuffActions(actions, owner, targetInfo.Target, buffName, 1, true);
			end
		end
	end
	return unpack(actions);
end
-- 숨겨둔 거미줄
function Mastery_HiddenWeb_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local positions = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		if targetInfo.AttackerState ~= 'Critical' then
			return;
		end
		local fieldEffects = GetFieldEffectByPosition(owner, GetPosition(targetInfo.Target));
		for _, instance in ipairs(fieldEffects) do
			local type = instance.Owner.name;
			if type == 'Fire' or type == 'Spark' or type == 'PoisonGas' or type == 'Web' then
				return;
			end
		end
		
		table.insert(positions, GetPosition(targetInfo.Target));
	end);
	
	if #positions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	local action = Result_AddFieldEffect('Web', positions, owner);
	action.sequential = true;
	return action;
end
-- 그물 위의 사냥꾼
function Mastery_WebHunter_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' 
		or mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	
	local targetEnemyInfos = FilterAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		return IsObjectOnFieldEffectBuffAffector(targetInfo.Target, { mastery.Buff.name, mastery.SubBuff.name }) and IsEnemy(owner, targetInfo.Target);
	end);
	
	local hasDeadEnemy = HasAnyAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
		return targetInfo.IsDead;
	end);
	
	-- 그물 속의 암살자
	local applyTargets = {};
	local mastery_WebAssassin = GetMasteryMastered(GetMastery(owner), 'WebAssassin');
	if mastery_WebAssassin then
		ForeachAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
			local target = targetInfo.Target;
			if targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and target.HP > 0 then
				applyTargets[GetObjKey(target)] = target;
			end
		end);
	end
	
	local isActivated = false;
	if hasDeadEnemy or (mastery_WebAssassin and not table.empty(applyTargets)) then
		isActivated = true;
	end
	if not isActivated then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	if hasDeadEnemy then
		AddActionRestoreActions(actions, owner);
	end
	if mastery_WebAssassin and not table.empty(applyTargets) then
		MasteryActivatedHelper(ds, mastery_WebAssassin, owner, 'AbilityUsed_Self');
		local applyBuff = mastery_WebAssassin.SubBuff.name;
		for targetKey, target in pairs(applyTargets) do
			InsertBuffActions(actions, owner, target, applyBuff, 1, true);
		end
	end
	
	return unpack(actions);
end
-- 수면 위의 사냥꾼
function Mastery_OntheWaterHunter_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' 
		or mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	
	local targetEnemyInfos = FilterAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		return IsObjectOnFieldEffectBuffAffector(targetInfo.Target, { mastery.Buff.name, mastery.SubBuff.name }) and IsEnemy(owner, targetInfo.Target);
	end);
	
	local hasDeadEnemy = HasAnyAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
		return targetInfo.IsDead;
	end);
	
	-- 수면 위의 암살자
	local applyTargets = {};
	local mastery_WaterAssassin = GetMasteryMastered(GetMastery(owner), 'WaterAssassin');
	if mastery_WaterAssassin then
		ForeachAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
			local target = targetInfo.Target;
			if targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and target.HP > 0 then
				applyTargets[GetObjKey(target)] = target;
			end
		end);
	end
	
	local isActivated = false;
	if hasDeadEnemy or (mastery_WaterAssassin and not table.empty(applyTargets)) then
		isActivated = true;
	end
	if not isActivated then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	if hasDeadEnemy then
		AddActionRestoreActions(actions, owner);
	end
	if mastery_WaterAssassin and not table.empty(applyTargets) then
		MasteryActivatedHelper(ds, mastery_WaterAssassin, owner, 'AbilityUsed_Self');
		local applyAct = mastery_WaterAssassin.ApplyAmount;
		for targetKey, target in pairs(applyTargets) do
			local added, reasons = AddActionApplyAct(actions, owner, target, applyAct, 'Hostile');
			if added then
				ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
			end
			ReasonToUpdateBattleEventMulti(target, ds, reasons);
		end
	end
	
	return unpack(actions);
end
-- 안개 속의 사냥꾼
function Mastery_SmokeHunter_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' 
		or mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	
	local targetEnemyInfos = FilterAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		return IsObjectOnFieldEffectBuffAffector(targetInfo.Target, mastery.Buff.name) and IsEnemy(owner, targetInfo.Target);
	end);
	
	local hasDeadEnemy = HasAnyAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
		return targetInfo.IsDead;
	end);
	
	-- 안개 속의 암살자
	local applyTargets = {};
	local mastery_SmokeAssassin = GetMasteryMastered(GetMastery(owner), 'SmokeAssassin');
	if mastery_SmokeAssassin then
		ForeachAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
			local target = targetInfo.Target;
			if targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and target.HP > 0 then
				applyTargets[GetObjKey(target)] = target;
			end
		end);
	end
	
	local isActivated = false;
	if hasDeadEnemy or (mastery_SmokeAssassin and not table.empty(applyTargets)) then
		isActivated = true;
	end
	if not isActivated then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	if hasDeadEnemy then
		AddActionRestoreActions(actions, owner);
	end
	if mastery_SmokeAssassin and not table.empty(applyTargets) then
		MasteryActivatedHelper(ds, mastery_SmokeAssassin, owner, 'AbilityUsed_Self');
		local applyAct = mastery_SmokeAssassin.ApplyAmount;
		for targetKey, target in pairs(applyTargets) do
			local added, reasons = AddActionApplyAct(actions, owner, target, applyAct, 'Hostile');
			if added then
				ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
			end
			ReasonToUpdateBattleEventMulti(target, ds, reasons);
		end
	end
	
	return unpack(actions);
end
-- 수풀 속의 사냥꾼
function Mastery_BushHunter_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' 
		or mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	
	local targetEnemyInfos = FilterAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		return not IsObjectOnFieldEffectBuffAffector(targetInfo.Target, mastery.Buff.name) and IsEnemy(owner, targetInfo.Target);
	end);
	
	local hasDeadEnemy = HasAnyAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
		return targetInfo.IsDead;
	end);
	
	-- 수풀 속의 암살자
	local applyTargets = {};
	local mastery_BushAssassin = GetMasteryMastered(GetMastery(owner), 'BushAssassin');
	if mastery_BushAssassin then
		ForeachAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
			local target = targetInfo.Target;
			if targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and target.HP > 0 then
				applyTargets[GetObjKey(target)] = target;
			end
		end);
	end
	
	local isActivated = false;
	if hasDeadEnemy or (mastery_BushAssassin and not table.empty(applyTargets)) then
		isActivated = true;
	end
	if not isActivated then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	if hasDeadEnemy then
		AddActionRestoreActions(actions, owner);
	end
	if mastery_BushAssassin and not table.empty(applyTargets) then
		MasteryActivatedHelper(ds, mastery_BushAssassin, owner, 'AbilityUsed_Self');
		local applyAct = mastery_BushAssassin.ApplyAmount;
		for targetKey, target in pairs(applyTargets) do
			local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Hostile');
			if added then
				ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
			end
			ReasonToUpdateBattleEventMulti(target, ds, reasons);
		end
	end
	
	return unpack(actions);
end
-- 하늘 위의 사냥꾼
function Mastery_OntheSkyHunter_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local prevPos = GetInstantProperty(owner, 'OntheSkyHunter');
	SetInstantProperty(owner, 'OntheSkyHunter', nil);
	if not prevPos then
		return;
	end
	
	local targetEnemyInfos = FilterAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		local height = GetHeight(prevPos, targetInfo.TargetPos);
		local attackerHight = IsAttakerHighPosition(height, GetMastery(owner), GetMastery(targetInfo.Target));	
		return attackerHight and IsEnemy(owner, targetInfo.Target);
	end);
	
	local hasDeadEnemy = HasAnyAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
		return targetInfo.IsDead;
	end);
	
	-- 하늘 위의 암살자
	local mastery_SkyAssassin = GetMasteryMastered(GetMastery(owner), 'SkyAssassin');
	local hasCritEnemy = HasAnyAbilityUsingInfo(targetEnemyInfos, function(targetInfo)
		return targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and targetInfo.Target.HP > 0;
	end);	
	
	local isActivated = false;
	if hasDeadEnemy or (mastery_SkyAssassin and hasCritEnemy) then
		isActivated = true;
	end
	if not isActivated then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	if hasDeadEnemy then
		AddActionRestoreActions(actions, owner);
	end
	if mastery_SkyAssassin and hasCritEnemy then
		MasteryActivatedHelper(ds, mastery_SkyAssassin, owner, 'AbilityUsed_Self');
		local applyAct = -1 * mastery_SkyAssassin.ApplyAmount;
		local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
		if added then
			ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
	return unpack(actions);
end
-- 꿰뚫는 탄환
function Mastery_UnavoidableBullet_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsGetAbilitySubType(eventArg.Ability, 'Piercing') then
		return;
	end
	
	local actions = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		if targetInfo.DefenderState == 'Dodge' 
			or IsDead(targetInfo.Target) then
			return;
		end
		
		InsertBuffActions(actions, owner, targetInfo.Target, mastery.Buff.name, 1, true);
	end);
	
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 저격
function Mastery_SnipingTraining_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or owner.ExposedByEnemy then
		return;
	end
	
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		return targetInfo.Target and targetInfo.IsDead;
	end) then
		return;
	end
	
	local actions = {};
	AddActionRestoreActions(actions, owner);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	return unpack(actions);
end
-- 야수 협공
function Mastery_AttackWithBeast_AbilityUsed(eventArg, mastery, owner, ds, invokedByTrap)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local allowTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		if targetInfo.Target and targetInfo.Target.HP > 0 then
			allowTargets[GetObjKey(targetInfo.Target)] = true;
		end
		return true;
	end);
	
	if next(allowTargets) == nil then
		return;
	end
	
	return Mastery_AttackWithBeastActivated(allowTargets, mastery, owner, ds, invokedByTrap);
end
function Mastery_AttackWithBeastActivated(allowTargets, mastery, owner, ds, invokedByTrap)
	-- 궁극기를 제외한 공격 어빌리티
	local beast = SafeIndex(GetInstantProperty(owner, 'SummonBeast'), 'Target');
	if not beast then
		return;
	end
	if not GetBuffStatus(beast, 'Attackable', 'And') then
		return;
	end
	
	local abilities = table.filter(GetAvailableAbility(beast, true), function (ability) return ability.Type == 'Attack' and not ability.SPFullAbility end);
	local abilityRank = {};
	for i, ability in ipairs(abilities) do
		abilityRank[ability.name] = #abilities - i;
	end
	
	local usingAbility, usingPos, _, score = FindAIMainAction(beast, abilities, {{Strategy = function(self, adb)
			local count = table.count(adb.ApplyTargets, function(t) return allowTargets[GetObjKey(t)] end);
			if count == 0 then
				return -22;
			end
			local score = 100;
			if adb.IsIndirect then
				score = 0;
			end
			score = score + abilityRank[adb.Ability.name] * 200;
			return score + 100 / (adb.Distance + 1);
		end, Target = 'Attack'}}, {}, {});
		
	if usingAbility == nil or usingPos == nil then
		return;
	end
	
	local actions = {};
	
	local action, reasons = GetApplyActAction(beast, mastery.ApplyAmount, nil, 'Cost');
	local battleEvents = {};
	if action then
		table.insert(actions, action);
		table.insert(battleEvents, { Object = beast, EventType = 'AddWait', Args = { Time = mastery.ApplyAmount } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(beast, reasons, 'FirstHit'));
	table.insert(battleEvents, {Object = beast, EventType = 'AttackWithBeast', Args = nil});
	
	local overwatchAction = Result_UseAbility(beast, usingAbility.name, usingPos, {ReactionAbility=true, BattleEvents=battleEvents, AttackWithBeast=true, InvokedByTrap = invokedByTrap}, true, {});
	overwatchAction.free_action = true;
	overwatchAction.final_useable_checker = function()
		return GetBuffStatus(beast, 'Attackable', 'And')
			and PositionInRange(CalculateRange(beast, usingAbility.TargetRange, GetPosition(beast)), usingPos);
	end;
	table.insert(actions, overwatchAction);
	
	-- 괴수사냥꾼
	local mastery_MonsterHunter = GetMasteryMastered(GetMastery(owner), 'MonsterHunter');
	if mastery_MonsterHunter then
		SubscribeWorldEvent(beast, 'AbilityUsed_Self', function(eventArg, ds, subscriptionID)
			if eventArg.Ability.Type ~= 'Attack' then
				UnsubscribeWorldEvent(beast, subscriptionID);
				return;
			end
			local actions = {};
			ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
				if SafeIndex(targetInfo, 'Target', 'Race', 'name') == 'Beast' then
					AddActionApplyActForDS(actions, targetInfo.Target, mastery_MonsterHunter.ApplyAmount2, ds, 'Hostile');
				end
			end);
			if #actions > 0 then
				MasteryActivatedHelper(ds, mastery_MonsterHunter, owner, 'AbilityUsed_Self');
			end
			UnsubscribeWorldEvent(beast, subscriptionID);
			return unpack(actions);
		end);
	end
	return unpack(actions);
end
-- 지원 사격
function Mastery_SupportingFire_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner
		or not IsAllyOrTeam(owner, eventArg.Unit)
		or eventArg.Ability.Type ~= 'Attack'
		or mastery.DuplicateApplyChecker > 0
		or owner.IsMovingNow > 0
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or SafeIndex(eventArg, 'ResultModifier', 'SupportingFire') then
		return;
	end
	
	local limit = 1;
	local masteryTable = GetMastery(owner);
	-- 전장의 지배자
	local mastery_BattleOwner = GetMasteryMastered(masteryTable, 'BattleOwner');
	if mastery_BattleOwner then
		limit = limit + mastery_BattleOwner.ApplyAmount;
	end
	-- 내가 여기 있다.
	local mastery_ImHere = GetMasteryMastered(masteryTable, 'ImHere');
	if mastery_ImHere then
		limit = limit + mastery_ImHere.ApplyAmount2;
	end
	-- 이 기회는 나의 것
	local mastery_INeverLostOpportunity = GetMasteryMastered(masteryTable, 'INeverLostOpportunity');
	if mastery_INeverLostOpportunity then
		limit = limit + mastery_INeverLostOpportunity.ApplyAmount2;
	end
	if mastery.CountChecker >= limit then
		return;
	end
	
	local actions = {};
	if not Mastery_SupportingFire_ActivateTest(actions, mastery, eventArg, owner, ds, mastery.ApplyAmount, 'FireSupport') then
		return;
	end
	mastery.CountChecker = mastery.CountChecker + 1;
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	return unpack(actions);
end
function Mastery_Module_SupportingFire_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner
		or not IsAllyOrTeam(owner, eventArg.Unit)
		or eventArg.Ability.Type ~= 'Attack'
		or mastery.DuplicateApplyChecker > 0
		or owner.IsMovingNow > 0
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or SafeIndex(eventArg, 'ResultModifier', 'SupportingFire') then
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	if owner.Cost < mastery.ApplyAmount2 then
		return;
	end
	local actions = {};
	if not Mastery_SupportingFire_ActivateTest(actions, mastery, eventArg, owner, ds, mastery.ApplyAmount, 'AutoFireSupport') then
		return;
	end
	
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount2, true, nil, ds);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	return unpack(actions);
end
function Mastery_SupportingFire_ActivateTest(actions, mastery, eventArg, owner, ds, applyAct, battleEvent)	
	local overwatch = FindAbility(owner, owner.OverwatchAbility);
	if overwatch == nil then
		return false;
	end
	
	local rangeClsList = GetClassList('Range');
	local range = CalculateRange(owner, overwatch.TargetRange, GetPosition(owner));
	
	local usingTarget = nil;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		if targetInfo.Target and targetInfo.Target.HP > 0 and IsInSight(owner, targetInfo.Target, true) and PositionInRange(range, GetPosition(targetInfo.Target)) then
			usingTarget = targetInfo.Target;
			return false;
		end
		return true;
	end);
	
	if usingTarget == nil then
		return false;
	end
	
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	local battleEvents = {};
	if action then
		table.insert(actions, action);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	table.insert(battleEvents, {Object = owner, EventType = battleEvent, Args = nil});
	
	local overwatchAction = Result_UseAbilityTarget(owner, owner.OverwatchAbility, usingTarget, {ReactionAbility=true, BattleEvents=battleEvents, SupportingFire = true, InvokeMastery = mastery.name}, true, {});
	overwatchAction.free_action = true;
	overwatchAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, overwatch.TargetRange, GetPosition(owner)), GetPosition(usingTarget));
	end;
	if eventArg.DirectingConfig.Preemptive then
		local eventCmd = ds:SubscribeFSMEvent(GetObjKey(usingTarget), 'StepForward', 'CheckUnitArrivePosition', {CheckPos=GetPosition(usingTarget)}, true);
		ds:SetConditional(eventCmd);
		
		overwatchAction.directing_config.Preemptive = eventArg.DirectingConfig.Preemptive;
		overwatchAction.directing_config.PreemptiveOrder = eventArg.DirectingConfig.PreemptiveOrder + 1;
		overwatchAction.nonsequential = true;
		overwatchAction._ref = eventCmd;
		overwatchAction._ref_offset = -1;
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	table.insert(actions, overwatchAction);
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
	end, nil, true, true));
	return true;
end
-- 강한 유대감
function Mastery_StrongFellowship_AbilityUsed(eventArg, mastery, owner, ds)
	local masterKey = GetInstantProperty(owner, 'SummonMaster');
	if masterKey == nil then
		return;
	end
	local master = GetUnit(owner, masterKey);
	if master == nil
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(eventArg.Unit, master) then
		return;
	end
	
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return targetInfo.Target == master and targetInfo.MainDamage > 0;
	end) then
		return;
	end
	
	if not IsInSight(owner, eventArg.Unit, true) then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	local applyAct = mastery.ApplyAmount;
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -applyAct, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 정밀한 저격
function Mastery_DetailedSnipe_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.TargetType ~= 'Single' or eventArg.Ability.HitRateType ~= 'Force' or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local actions = {};
	local snipeTypeList = GetClassList('SnipeType');
	local snipeTypeName = SafeIndex(eventArg.DetailInfo, 'SnipeType') or 'Head';
	local snipeType = SafeIndex(snipeTypeList, snipeTypeName);
	if not snipeType then
		return;
	end
	local delayAmount = snipeType.ApplyAct;
	local mastery_Infallibility = GetMasteryMastered(GetMastery(owner), 'Infallibility');
	if mastery_Infallibility then
		delayAmount = delayAmount * (1 + mastery_Infallibility.ApplyAmount / 100);
	end
	local addBuff = snipeType.ApplyTargetBuff;
	local addBuffLv = snipeType.ApplyTargetBuffLv;

	local exist = false;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' then
			if delayAmount ~= 0 then
				exist = true;
				local action, reasons = GetApplyActAction(targetInfo.Target, delayAmount, nil, 'Hostile');
				if action then
					table.insert(actions, action);
					ds:UpdateBattleEvent(GetObjKey(targetInfo.Target), 'AddWait', { Time = delayAmount });
				else
					ReasonToUpdateBattleEventMulti(owner, ds, reasons);
				end
			end
			if addBuff ~= 'None' and addBuffLv ~= 0 then
				exist = true;
				InsertBuffActions(actions, owner, targetInfo.Target, addBuff, addBuffLv, true);
			end
		end
	end);
	
	if exist then
		MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	end
	return unpack(actions);
end
-- 거점 사수
function Mastery_HoldPosition_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsCoveredPosition(GetMission(owner), GetPosition(owner))
		or HasBuff(owner, 'Conceal_For_Aura') then
		return;
	end
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target);
	end) then
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	return unpack(actions);
end
-- 함정 시스템
function Mastery_TrapSystem_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		-- 공격 아닌 어빌리티도 쓸 수 있나?..
		return;
	end
	local trapHost = GetExpTaker(owner);
	if trapHost == nil then
		return;
	end
	
	local masteryTable = GetMastery(trapHost);
	-- 덫 사냥꾼
	local mastery_TrapHunter = GetMasteryMastered(masteryTable, 'TrapHunter');
	-- 설계된 함정
	local mastery_TrapDesign = GetMasteryMastered(masteryTable, 'TrapDesign');
	-- 강력한 덫
	local mastery_PowerfulTrap = GetMasteryMastered(masteryTable, 'PowerfulTrap');
	local powerfulTrapTargets = nil;
	if mastery_PowerfulTrap then
		powerfulTrapTargets = GetInstantProperty(owner, 'PowerfulTrap') or {};
		SetInstantProperty(owner, 'PowerfulTrap', nil);
	end
	
	local confuseRate = mastery_TrapHunter and mastery_TrapHunter.ApplyAmount2 or 0;
	
	local trapHunterCount, trapDesignCount, powerfulTrapCount = 0, 0, 0;
	local actions = {};
	local appliedTargets = {};
	table.insert(actions, Result_ChangeTeam(owner, '_dummy'));
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if target == nil then
			return;
		end
		table.insert(appliedTargets, targetInfo.Target);
		if not targetInfo.IsDead and targetInfo.DefenderState ~= 'Dodge' and mastery_TrapHunter then
			if RandomTest(confuseRate) then
				InsertBuffActions(actions, trapHost, target, mastery_TrapHunter.Buff.name, 1);
			end
			AddActionApplyActForDS(actions, target, mastery_TrapHunter.ApplyAmount, ds, 'Hostile');
			trapHunterCount = trapHunterCount + 1;
		elseif targetInfo.IsDead and mastery_TrapDesign then
			trapDesignCount = trapDesignCount + 1;
		end
		if mastery_PowerfulTrap and powerfulTrapTargets[GetObjKey(target)] then
			if eventArg.Ability.name == 'FireTrapActivate' then
				-- 화염 계열
				-- 피해량 증가 효과는 데미지 계산에서 처리함
			elseif eventArg.Ability.name == 'IceTrapActivate' then
				-- 얼음 계열
				InsertBuffActions(actions, trapHost, target, mastery_PowerfulTrap.Buff.name, 1, true);
			elseif eventArg.Ability.name == 'LightningTrapActivate' then
				-- 번개 계열
				InsertBuffActions(actions, trapHost, target, mastery_PowerfulTrap.SubBuff.name, 1, true);
			elseif eventArg.Ability.name == 'PoisonTrapActivate' then
				-- 중독 계열
				InsertBuffActions(actions, trapHost, target, mastery_PowerfulTrap.ThirdBuff.name, 1, true);
			elseif eventArg.Ability.name == 'LightTrapActivate' then
				-- 섬광 계열
				AddActionApplyActForDS(actions, target, mastery_PowerfulTrap.ApplyAmount2, ds, 'Hostile');
			end
			powerfulTrapCount = powerfulTrapCount + 1;
		end
	end);
	
	if trapHunterCount > 0 then
		MasteryActivatedHelper(ds, mastery_TrapHunter, trapHost, 'AbilityUsed_Self');
	end
	if trapDesignCount > 0 then
		AddActionApplyActForDS(actions, trapHost, -mastery_TrapDesign.ApplyAmount2 * trapDesignCount, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_TrapDesign, trapHost, 'AbilityUsed_Self');
	end
	if powerfulTrapCount > 0 then
		MasteryActivatedHelper(ds, mastery_PowerfulTrap, trapHost, 'AbilityUsed_Self');
	end

	table.insert(actions, Result_FireWorldEvent('MyTrapActivated', {Trap = owner, ApplyTargets = appliedTargets}, trapHost, true));
	
	return unpack(actions);
end
-- 노래하는 보라곰 / 백호의 이빨
-- 치명타 공격 시, 버프 걸리는 로직.
function Mastery_AddBuffByCriticalHit_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local actions = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' and targetInfo.AttackerState == 'Critical' then
			InsertBuffActions(actions, owner, targetInfo.Target, mastery.Buff.name, 1, true);
		end
	end);
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed', nil , nil, nil, true);
	return unpack(actions);
end
-- 익숙한 솜씨
function Mastery_PracticedHand_AbilityUsed(eventArg, mastery, owner, ds)
	if not eventArg.Ability.ItemAbility then
		return;
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'PreAbilityUsing'});
	ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -mastery.ApplyAmount, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 자세 무너뜨리기
function Mastery_BreakStance_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local targetList = GetTargetListFromAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState ~= 'Dodge' and IsEnemy(owner, targetInfo.Target);
	end);
	if #targetList == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	for _, target in ipairs(targetList) do
		AddAbilityCoolActions(actions, target, mastery.ApplyAmount, function(ability)
			return ability.Type == 'Attack';
		end);
	end
	-- 절차탁마
	local mastery_Polishing = GetMasteryMastered(GetMastery(owner), 'Polishing');
	if mastery_Polishing then
		MasteryActivatedHelper(ds, mastery_Polishing, owner, 'AbilityUsed_Self');
		for _, target in ipairs(targetList) do
			AddActionApplyActForDS(actions, target, mastery_Polishing.ApplyAmount, ds, 'Hostile');
		end
	end
	return unpack(actions);
end
-- 요동치는 물결
function Mastery_WaveStream_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsGetAbilitySubType(eventArg.Ability, 'Water') then
		return;
	end
	local actions = {};
	local activated = false;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.AttackerState ~= 'Critical'
			or targetInfo.DefenderState == 'Dodge'
			or not IsEnemy(owner, targetInfo.Target) then
			return;
		end
		activated = true;
		AddAbilityCoolActions(actions, targetInfo.Target, mastery.ApplyAmount, function(ability)
			return ability.Type == 'Attack';
		end);
	end);
	if activated then
		MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	end
	return unpack(actions);
end
-- 직격탄
function Mastery_DirectShot_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Throw' then
		return;
	end
	
	local hasDead = false;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if not targetInfo.Target then
			return true;
		end
		if GetInstantProperty(targetInfo.Target, 'DirectShotApplied') and targetInfo.IsDead then
			hasDead = true;
		end
		SetInstantProperty(targetInfo.Target, 'DirectShotApplied', nil);
	end);
	
	local actions = {};
	local mastery_Bomber = GetMasteryMastered(GetMastery(owner), 'Bomber');
	if hasDead and mastery_Bomber then
		InsertBuffActions(actions, owner, owner, mastery_Bomber.Buff.name, 1);
		MasteryActivatedHelper(ds, mastery_Bomber, owner, 'AbilityUsed_Self');
	end
	
	return unpack(actions);
end
-- 한방에 한 명씩
function Mastery_OneShotOneKill_AbilityUsed(eventArg, mastery, owner, ds)
	if owner.TurnState.TurnEnded 	-- 턴중에만 발동
		or eventArg.Ability.Type ~= 'Attack' then		
		return;
	end
	
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return targetInfo.IsDead and (targetInfo.PrevHP == targetInfo.MaxHP) and not targetInfo.Target.Obstacle;
	end) then
		return;
	end
	
	local actions = {};
	AddActionRestoreActions(actions, owner);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	return unpack(actions);
end
-- 마력 가속기
function Mastery_SpellAccelerator_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if not HasBuff(owner, mastery.Buff.name) then
		return;
	end

	local hasDamage = false;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.MainDamage > 0 then
			hasDamage = true;
			return false;
		end
	end);
	
	if not hasDamage then
		return;
	end
	
	local actions = {};
	local applyAct = -mastery.ApplyAmount2;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Friendly');
	if action then
		table.insert(actions, action);
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	else
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	return unpack(actions);
end
-- 파괴의 검
function Mastery_DestroySword_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.SubType ~= 'Slashing' then
		return;
	end
	
	local applyActTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState == 'Block' then
			applyActTargets[GetObjKey(targetInfo.Target)] = targetInfo.Target;
		end
	end);
	if table.empty(applyActTargets) then
		return;
	end
	local actions = {};
	local applyAct = mastery.ApplyAmount;	
	for targetKey, target in pairs(applyActTargets) do
		local action, reasons = GetApplyActAction(target, applyAct, nil, 'Hostile');
		if action then
			table.insert(actions, action);
			ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
		else
			ReasonToUpdateBattleEventMulti(target, ds, reasons);
		end
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	return unpack(actions);
end
-- 침묵의 사격
function Mastery_SilencingShot_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force' then
		return;
	end
	
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' and targetInfo.Target.Race.name ~= 'Machine' then
			applyTargets[GetObjKey(targetInfo.Target)] = targetInfo.Target;
		end
	end);
	
	local mastery_YouCanNotDoAnything = GetMasteryMastered(GetMastery(owner), 'YouCanNotDoAnything');
	local youCanNotDoAnythingActivated = false;
	
	local actions = {};
	for _, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1);
		
		if mastery_YouCanNotDoAnything then
			AddAbilityCoolActions(actions, target, mastery_YouCanNotDoAnything.ApplyAmount, function(ability)
				if IsGetAbilitySubType(ability, 'ESP') then
					youCanNotDoAnythingActivated = true;
					return true;
				end
			end);
		end
	end
	
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	if youCanNotDoAnythingActivated then
		MasteryActivatedHelper(ds, mastery_YouCanNotDoAnything, owner, 'AbilityUsed');
	end
	return unpack(actions);
end
-- 마녀의 시샘
function Mastery_WitchJealousy_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if IsEnemy(owner, targetInfo.Target) then
			applyTargets[GetObjKey(targetInfo.Target)] = targetInfo.Target;
		end
	end);
	
	local mastery_SoulReaper = GetMasteryMastered(GetMastery(owner), 'SoulReaper');
	local badBuffList = nil;
	if mastery_SoulReaper then
		badBuffList = Linq.new(GetClassList('Buff_Negative'))
			:select(function(pair) return pair[1]; end)
			:toList();
	end
	
	local actions = {};
	for _, target in pairs(applyTargets) do
		for __, buff in ipairs(GetBuffList(target)) do
			if buff.Type == 'Buff' and (buff.SubType == 'Physical' or buff.SubType == 'Mental') then
				InsertBuffActions(actions, owner, target, buff.name, -buff.Lv);
				if mastery_SoulReaper then
					local buffPicker = RandomBuffPicker.new(target, badBuffList);
					local b = buffPicker:PickBuff();
					if b then
						InsertBuffActions(actions, owner, target, b, 1);
					end
				end
			end
		end
	end
	
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	if mastery_SoulReaper then
		MasteryActivatedHelper(ds, mastery_SoulReaper, owner, 'AbilityUsed');
	end
	return unpack(actions);
end
-- 구속력
function Mastery_BindingPower_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' then
			applyTargets[GetObjKey(targetInfo.Target)] = targetInfo.Target;
		end
	end);
	
	local actions = {};
	for _, target in pairs(applyTargets) do
		if RandomTest(mastery.ApplyAmount) then
			InsertBuffActions(actions, owner, target, mastery.Buff.name, 1);
		end
	end
	if #actions <= 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	
	local mastery_BloodWitch = GetMasteryMastered(GetMastery(owner), 'BloodWitch');
	if mastery_BloodWitch then
		mastery_BloodWitch.BindingPower = 1;
	end
	return unpack(actions);
end
-- 나는 아직 배고프다.
function Mastery_ImStillHungry_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force' then
		return;
	end
	local deadCount = 0;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead then
			deadCount = deadCount + 1;
		end
	end);
	if deadCount < 2 then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
	return unpack(actions);
end
-- 전심전력
function Mastery_GreatApplication_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local deadCount = 0;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead then
			deadCount = deadCount + 1;
		end
	end);
	if deadCount < 1 then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
	return unpack(actions);
end
-- 반동 제어
function Mastery_ControlReactor_AbilityUsed(eventArg, mastery, owner, ds)
	local prevCheck = mastery.DuplicateApplyChecker > 0;

	if eventArg.Ability.HitRateType == 'Force' then
		mastery.DuplicateApplyChecker = 1;
	else
		mastery.DuplicateApplyChecker = 0;
	end
	
	if not prevCheck or mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	local reduceAmount = mastery.ApplyAmount;
	
	local masteryTable = GetMastery(owner);
	local mastery_ImStillHungry = GetMasteryMastered(masteryTable, 'ImStillHungry');
	if mastery_ImStillHungry then
		reduceAmount = reduceAmount + mastery_ImStillHungry.ApplyAmount2;
	end
	
	local applyAct = -1 * reduceAmount;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Friendly');
	local actions = {};
	if action then
		table.insert(actions, action);
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed', false);
	
	return unpack(actions);
end
-- 꾸준한 치료
function Mastery_SteadyCure_AbilityUsed(eventArg, mastery, owner, ds)
	local prevCheck = mastery.DuplicateApplyChecker > 0;

	if eventArg.Ability.Type == 'Heal' then
		mastery.DuplicateApplyChecker = 1;
	else
		mastery.DuplicateApplyChecker = 0;
	end
	
	if not prevCheck or mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	local reduceAmount = mastery.ApplyAmount;
	
	local applyAct = -1 * reduceAmount;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Friendly');
	local actions = {};
	if action then
		table.insert(actions, action);
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed', false);	
	return unpack(actions);
end
-- 철갑탄
function Mastery_IronBullet_AbilityUsed(eventArg, mastery, owner, ds)	
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force' then
		return;
	end
	local testTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState == 'Dodge' then
			return;
		end
		if not IsMachineOrHeavyArmor(targetInfo.Target) then
			return;
		end
		testTargets[GetObjKey(targetInfo.Target)] = targetInfo.Target;
	end);
	if table.empty(testTargets) then
		return;
	end
	
	local prob = mastery.ApplyAmount;
	local mastery_ICanDoIt = GetMasteryMastered(GetMastery(owner), 'ICanDoIt');
	if mastery_ICanDoIt then
		prob = 100;
	end
	local actions = {};
	for _, target in pairs(testTargets) do
		if RandomTest(prob) then
			InsertBuffActions(actions, owner, target, mastery.Buff.name, 1);
		end
	end
	if #actions == 0 then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	if mastery_ICanDoIt then
		MasteryActivatedHelper(ds, mastery_ICanDoIt, owner, 'AbilityUsed_Self');
	end
	return unpack(actions);	
end
-- 맹독탄
function Mastery_PoisonBullet_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force' then
		return;
	end
	local masteryTable = GetMastery(owner);
	local mastery_ThisIsTheLastTime = GetMasteryMastered(masteryTable, 'ThisIsTheLastTime');
	
	local testTargets = {};
	local deadTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState == 'Dodge' then
			return;
		end
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		testTargets[targetKey] = targetInfo.Target;
		if mastery_ThisIsTheLastTime and IsEnemy(owner, target) and targetInfo.IsDead then
			deadTargets[targetKey] = targetInfo.Target;
		end
	end);
	if table.empty(testTargets) then
		return;
	end
	
	local actions = {};
	local prob = mastery.ApplyAmount;
	if mastery_ThisIsTheLastTime then
		prob = 100;
	end
	for _, target in pairs(testTargets) do
		if RandomTest(prob) then
			InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
		end
	end
	if #actions > 0 then
		MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', false);
		if mastery_ThisIsTheLastTime then
			MasteryActivatedHelper(ds, mastery_ThisIsTheLastTime, owner, 'AbilityUsed_Self', false);
		end
	end
	if mastery_ThisIsTheLastTime and not table.empty(deadTargets) then
		local sleepID = ds:Sleep(0);
		local sleepIndex = 1;
		for _, target in pairs(deadTargets) do
			local abilityAction, destroyAction = Mastery_Explode_UnitDead_Share({ Killer = owner }, mastery_ThisIsTheLastTime, target, ds, mastery_ThisIsTheLastTime.ChainAbility);
			abilityAction.directing_config = { NoCamera=true, Preemtive=true };
			abilityAction.nonsequential = true;
			abilityAction.sequential = nil;
			abilityAction._ref = sleepID;
			abilityAction._ref_offset = sleepIndex * 0.1;
			sleepIndex = sleepIndex + 1;
			table.append(actions, { abilityAction, destroyAction} );
		end
	end
	return unpack(actions);
end
-- 반이능탄
function Mastery_AntiESPBullet_AbilityUsed(eventArg, mastery, owner, ds)
		if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force' then
		return;
	end
	
	local testTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState == 'Dodge' then
			return;
		end
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		testTargets[targetKey] = targetInfo.Target;
	end);
	if table.empty(testTargets) then
		return;
	end
	
	local actions = {};
	local prob = mastery.ApplyAmount;
	local mastery_YouCanNotDoAnything = GetMasteryMastered(GetMastery(owner), 'YouCanNotDoAnything');
	if mastery_YouCanNotDoAnything then
		prob = 100;
	end
	for _, target in pairs(testTargets) do
		if RandomTest(prob) then
			InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
		end
	end
	if #actions == 0 then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', false);
	if mastery_YouCanNotDoAnything then
		MasteryActivatedHelper(ds, mastery_YouCanNotDoAnything, owner, 'AbilityUsed_Self');
	end
	return unpack(actions);
end
-- 마력 흡수
function Mastery_SpellAbsorbing_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local actions = {};
	local alreadyTarget = {};
	local applyCount, meleeApplyCount = 0, 0;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.AttackerState ~= 'Critical' then
			return;
		end
		local target = targetInfo.Target;
		if alreadyTarget[GetObjKey(target)] then
			return;
		end
		alreadyTarget[GetObjKey(target)] = true;
		
		local isMeleeDistance = IsMeleeDistanceAbility(owner, target);
		if isMeleeDistance then
			applyCount = applyCount + 1;
			meleeApplyCount = meleeApplyCount + 1;
		end
		
		local targetBuffList = GetBuffType(target, 'Buff');
		if #targetBuffList > 0 then
			for _, buff in ipairs(targetBuffList) do
				InsertBuffActions(actions, owner, target, buff.name, -buff.Lv);
			end
			applyCount = applyCount + #targetBuffList;
			if isMeleeDistance then
				meleeApplyCount = meleeApplyCount + #targetBuffList;
			end
		end
	end);
	if applyCount == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', false);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, applyCount);
	
	local mastery_SpellConverter = GetMasteryMastered(GetMastery(owner), 'SpellConverter');
	if mastery_SpellConverter and meleeApplyCount > 0 then
		local addHP = owner.MaxHP * meleeApplyCount * mastery_SpellConverter.ApplyAmount2/100;
		local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		MasteryActivatedHelper(ds, mastery_SpellConverter, owner, 'AbilityUsed_Self');
		DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false); 
	end
	return unpack(actions);
end
-- 타오르는 불꽃.
function Mastery_BurningFlame_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local ability = eventArg.Ability;
	if ability.SubType == 'Fire' and not ability.SPFullAbility and not eventArg.IsFreeAction then
		local masteryTable = GetMastery(owner);
		local addAmount = ability.Cost;
		-- 덧불
		local mastery_Kindling = GetMasteryMastered(masteryTable, 'Kindling');
		if mastery_Kindling then
			addAmount = addAmount + math.max(1, math.floor(mastery_Kindling.ApplyAmount/100 * ability.Cost));
		end
		-- 불꽃 갈기 부적
		local mastery_Amulet_Neguri_Fire_Set = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Fire_Set');
		if mastery_Amulet_Neguri_Fire_Set then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Fire_Set.ApplyAmount/100 * ability.Cost));
		end
		-- 황금 갈기 부적
		local mastery_Amulet_Neguri_Gold = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Gold');
		if mastery_Amulet_Neguri_Gold then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Gold.ApplyAmount/100 * ability.Cost));
		end
		AddSPPropertyActions(actions, owner, 'Fire', addAmount, true, ds, true);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end
	return unpack(actions);
end
function Mastery_Deathblow_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	mastery.DuplicateApplyChecker = 0;
end
-- 얼어붙은 심장
function Mastery_FrozenHeart_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local ability = eventArg.Ability;
	if ability.SubType == 'Ice' and not ability.SPFullAbility and not eventArg.IsFreeAction then
		local masteryTable = GetMastery(owner);
		local addAmount = ability.Cost;
		-- 한파
		local mastery_ColdWave = GetMasteryMastered(masteryTable, 'ColdWave');
		if mastery_ColdWave then
			local applyAmount = mastery_ColdWave.ApplyAmount;
			-- 얼어붙은 대지
			local mastery_FrozenGround = GetMasteryMastered(masteryTable, 'FrozenGround');
			if mastery_FrozenGround then
				applyAmount = applyAmount + mastery_FrozenGround.ApplyAmount;
			end
			addAmount = addAmount + math.max(1, math.floor(applyAmount/100 * ability.Cost));
		end
		-- 황금 갈기 부적
		local mastery_Amulet_Neguri_Gold = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Gold');
		if mastery_Amulet_Neguri_Gold then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Gold.ApplyAmount/100 * ability.Cost));
		end
		AddSPPropertyActions(actions, owner, 'Ice', addAmount, true, ds, true);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end
	return unpack(actions);
end
-- 신경 회로
function Mastery_NeuralCircuit_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local ability = eventArg.Ability;
	if ability.SubType == 'Lightning' and not ability.SPFullAbility and not eventArg.IsFreeAction then
		local masteryTable = GetMastery(owner);
		local addAmount = ability.Cost;
		-- 전기 펄스
		local mastery_ElectricPulse = GetMasteryMastered(masteryTable, 'ElectricPulse');
		if mastery_ElectricPulse then
			local applyAmount = mastery_ElectricPulse.ApplyAmount;
			-- 신경 자극
			local mastery_NeuralStimulation = GetMasteryMastered(masteryTable, 'NeuralStimulation');
			if mastery_NeuralStimulation then
				applyAmount = applyAmount + mastery_NeuralStimulation.ApplyAmount;
			end
			-- 강화된 신경망
			local mastery_EnhancedNeuralNetwork = GetMasteryMastered(masteryTable, 'EnhancedNeuralNetwork');
			if mastery_EnhancedNeuralNetwork then
				applyAmount = applyAmount + mastery_EnhancedNeuralNetwork.ApplyAmount;
			end
			addAmount = addAmount + math.max(1, math.floor(applyAmount/100 * ability.Cost));
		end
		-- 섬광 갈기 부적
		local mastery_Amulet_Neguri_Lighting_Set = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Lighting_Set');
		if mastery_Amulet_Neguri_Lighting_Set then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Lighting_Set.ApplyAmount/100 * ability.Cost));
		end		
		-- 황금 갈기 부적
		local mastery_Amulet_Neguri_Gold = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Gold');
		if mastery_Amulet_Neguri_Gold then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Gold.ApplyAmount/100 * ability.Cost));
		end
		AddSPPropertyActions(actions, owner, 'Lightning', addAmount, true, ds, true);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end
	return unpack(actions);
end
-- 미풍
function Mastery_Breeze_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local ability = eventArg.Ability;
	if ability.SubType == 'Wind' and not ability.SPFullAbility and not eventArg.IsFreeAction then
		local masteryTable = GetMastery(owner);
		local addAmount = ability.Cost;
		-- 순풍
		local mastery_FairWind = GetMasteryMastered(masteryTable, 'FairWind');
		if mastery_FairWind then
			addAmount = addAmount + math.max(1, math.floor(mastery_FairWind.ApplyAmount/100 * ability.Cost));
		end
		-- 황금 갈기 부적
		local mastery_Amulet_Neguri_Gold = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Gold');
		if mastery_Amulet_Neguri_Gold then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Gold.ApplyAmount/100 * ability.Cost));
		end
		AddSPPropertyActions(actions, owner, 'Wind', addAmount, true, ds, true);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end
	return unpack(actions);
end
-- 정보 분석
function Mastery_InformationAnalysis_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyEnemy = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target);
	end);
	if not hasAnyEnemy then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Info', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	return unpack(actions);
end
-- 자연의 균형
function Mastery_NatureBalance_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local ability = eventArg.Ability;
	local mission = GetMission(owner);

	if ability.SubType == 'Earth' and not ability.SPFullAbility and not eventArg.IsFreeAction then
		local masteryTable = GetMastery(owner);
		local addAmount = ability.Cost;
		local buffName = nil;
		if mission.MissionTime.name == 'Daytime' or mission.MissionTime.name == 'Morning' then
			-- 백야
			local mastery_WhiteNight = GetMasteryMastered(masteryTable, 'WhiteNight');
			if mastery_WhiteNight then
				addAmount = addAmount + math.max(1, math.floor(mastery_WhiteNight.ApplyAmount/100 * ability.Cost));
				-- 강렬한 빛
				local mastery_StrongLight = GetMasteryMastered(masteryTable, 'StrongLight');
				if mastery_StrongLight then
					addAmount = addAmount + math.max(1, math.floor(mastery_StrongLight.ApplyAmount/100 * ability.Cost));
				end
			end
		elseif mission.MissionTime.name == 'Night' or mission.MissionTime.name == 'Evening' then
			-- 일식
			local mastery_Eclipse = GetMasteryMastered(masteryTable, 'Eclipse');
			if mastery_Eclipse then
				local eclipseAmount = mastery_Eclipse.ApplyAmount;
				-- 밤의 수호자
				local mastery_NightGuardian = GetMasteryMastered(masteryTable, 'NightGuardian');
				if mastery_NightGuardian then
					eclipseAmount = eclipseAmount + mastery_NightGuardian.ApplyAmount2;
				end
				addAmount = addAmount + math.max(1, math.floor(eclipseAmount/100 * ability.Cost));
			end
		end
		-- 진흙 갈기 부적
		local mastery_Amulet_Neguri_Earth_Set = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Earth_Set');
		if mastery_Amulet_Neguri_Earth_Set then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Earth_Set.ApplyAmount/100 * ability.Cost));
		end
		-- 황금 갈기 부적
		local mastery_Amulet_Neguri_Gold = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Gold');
		if mastery_Amulet_Neguri_Gold then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Gold.ApplyAmount/100 * ability.Cost));
		end
		AddSPPropertyActions(actions, owner, 'Earth', addAmount, true, ds, true);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end
	return unpack(actions);
end
-- 흐르는 물
-- 이슬비
function Mastery_RunningWater_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local ability = eventArg.Ability;
	if ability.SubType == 'Water' and not ability.SPFullAbility and not eventArg.IsFreeAction then
		local masteryTable = GetMastery(owner);
		local addAmount = ability.Cost;
		-- 이슬비
		local mastery_Drizzle = GetMasteryMastered(masteryTable, 'Drizzle');
		if mastery_Drizzle then
			local applyAmount = mastery_Drizzle.ApplyAmount;
			-- 안개비
			local mastery_Smir = GetMasteryMastered(masteryTable, 'Smir');
			if mastery_Smir then
				applyAmount = applyAmount + mastery_Smir.ApplyAmount2;
			end
			addAmount = addAmount + math.max(1, math.floor(applyAmount/100 * ability.Cost));
		end
		-- 황금 갈기 부적
		local mastery_Amulet_Neguri_Gold = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Gold');
		if mastery_Amulet_Neguri_Gold then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Gold.ApplyAmount/100 * ability.Cost));
		end
		AddSPPropertyActions(actions, owner, 'Water', addAmount, true, ds, true);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end
	return unpack(actions);
end
-- 호쾌한 기백.
function Mastery_IntrepidSpirit_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local ability = eventArg.Ability;
	if ability.Type == 'Attack' and not ability.SPFullAbility and not eventArg.IsFreeAction then
		local masteryTable = GetMastery(owner);
		local addAmount = ability.Cost;
		-- 쇄도하는 기백
		local mastery_SpiritRush = GetMasteryMastered(masteryTable, 'SpiritRush');
		if mastery_SpiritRush then
			addAmount = addAmount + math.max(1, math.floor(mastery_SpiritRush.ApplyAmount/100 * addAmount));
		end
		-- 황금 갈기 부적
		local mastery_Amulet_Neguri_Gold = GetMasteryMastered(masteryTable, 'Amulet_Neguri_Gold');
		if mastery_Amulet_Neguri_Gold then
			addAmount = addAmount + math.max(1, math.floor(mastery_Amulet_Neguri_Gold.ApplyAmount/100 * ability.Cost));
		end
		AddSPPropertyActions(actions, owner, 'Spirit', addAmount, true, ds, true);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end
	return unpack(actions);
end
-- 열손실 억제기
function Mastery_PreventHeatLoss_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local ability = eventArg.Ability;
	if not ability.SPFullAbility and not eventArg.IsFreeAction then
		local masteryTable = GetMastery(owner);
		local addAmount = math.floor(ability.Cost * mastery.ApplyAmount/100);
		AddSPPropertyActions(actions, owner, 'Heat', addAmount, true, ds, true);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end
	return unpack(actions);
end
function Mastery_InnerPeace_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.name ~= 'StandBy' then
		return;
	end

	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local _, reasons = AddActionCost(actions, owner, mastery.ApplyAmount, true);
	if owner.Cost < owner.MaxCost then
		ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = math.min(owner.MaxCost - owner.Cost, mastery.ApplyAmount) });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTurnEnd'});
	return unpack(actions);
end
function Mastery_Shaking_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end

	local ability = eventArg.Ability;
	if ability.Type ~= 'Attack' then
		return;
	end
	local buffName = 'Shaking';
	
	local thresholdLevel = mastery.ApplyAmount - 1;
	local mastery_ShakeShake = GetMasteryMastered(GetMastery(owner), 'ShakeShake');
	if mastery_ShakeShake then
		thresholdLevel = mastery_ShakeShake.ApplyAmount - 1;
	end
	
	local actions = {};
	local buff = GetBuff(owner, buffName);
	if not buff or buff.Lv < thresholdLevel then
		InsertBuffActions(actions, owner, owner, buffName, 1);
		
		if buff and buff.Lv == (thresholdLevel - 1) then
			local ownerKey = GetObjKey(owner);
			ds:UpdateBattleEvent(ownerKey, 'BuffInvoked', { Buff = buffName });
			if mastery_ShakeShake then
				MasteryActivatedHelper(ds, mastery_ShakeShake, owner, 'AbilityUsed_Self');
			end
		end
	end
	return unpack(actions);
end
function Mastery_ShakingSpray_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	return Result_DestroyObject(owner, false, true);
end
function Mastery_Responsibility_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local actions = {};
	local isSuccess = false;
	local enemyCount = #eventArg.PrimaryTargetInfos + #eventArg.SecondaryTargetInfos;
	
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if info.DefenderState ~= 'Dodge' and info.DefenderState ~= 'Block' then
				isSuccess = true;
			end
		end
	end
	if enemyCount > 0 and not isSuccess then
		local objKey = GetObjKey(owner);
		local baseWait = owner.Wait + eventArg.Ability.CastDelay;
		local nextAct = math.max(36, baseWait - mastery.ApplyAmount);
		local hasteAct = baseWait - nextAct;
		if hasteAct > 0 then
			local added, reasons = AddActionApplyAct(actions, owner, owner, -hasteAct, 'Friendly');
			if added then
				ds:UpdateBattleEvent(objKey, 'AddWaitCustomEvent', {Time = -hasteAct, EventType = 'Ending'});
			end
			ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		end
		AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount2, true, ds, true)
		local msteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });		
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end	
	return unpack(actions);
end
function Mastery_Relaxed_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	local actions = {};
	local isSuccess = false;
	local enemyCount = #eventArg.PrimaryTargetInfos + #eventArg.SecondaryTargetInfos;
	
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if info.DefenderState ~= 'Dodge' then
				isSuccess = true;
			end
		end
	end
	if enemyCount > 0 and not isSuccess then
		local objKey = GetObjKey(owner);
		AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
		local msteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });		
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	end	
	return unpack(actions);
end
function GetSpoonablePos(owner)
	local cacheList = GetInstantProperty(owner, 'OneSpoonablePosCache');
	if cacheList ~= nil then
		return cacheList;
	end
	local spoonAbility = FindAbility(owner, owner.OverwatchAbility);
	if spoonAbility == nil then
		return {};
	end
	local useablePositions = CalculateRange(owner, spoonAbility.TargetRange, GetPosition(owner));
	local myPos = GetPosition(owner);
	local finalList = table.filter(useablePositions, function(p)
		return GetDistance3D(myPos, p) < 1.8;
	end);
	SetInstantProperty(owner, 'OneSpoonablePosCache', finalList);
	return finalList;
end
function Mastery_OneSpoon_AbilityUsed(eventArg, mastery, owner, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Team'
		or owner == eventArg.Unit
		or eventArg.Unit.Affiliation.name ~= 'Spoon'
		or mastery.DuplicateApplyChecker > 0 
		or eventArg.Ability.Type ~= 'Attack'
		or eventArg.DirectingConfig.Preemptive
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	
	local spoonAbility = FindAbility(owner, owner.OverwatchAbility);
	if spoonAbility == nil then
		-- 어빌리티가 존재하지만 비활성화된 경우에는 에러 로그를 남가지 않음
		if not FindAbility(owner, owner.OverwatchAbility, false) then
			LogAndPrint('[DataError]', 'No Ability for OneSpoon.', owner.name, 'owner.OverwatchAbility:', owner.OverwatchAbility);
		end
		return;
	end
	
	local myPos = GetPosition(owner);
	
	local spoonPos = nil;
	local spoonablePosList = GetSpoonablePos(owner);
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if not info.IsDead and info.Target.name and IsEnemy(owner, info.Target) and info.Target.HP > 0 then
				local p = GetPosition(info.Target);
				if PositionInRange(spoonablePosList, p) then
					spoonPos = p;
					break;
				end
			end
		end
		if spoonPos then
			break;
		end
	end
	
	if spoonPos == nil then
		return;
	end
	
	local range = CalculateRange(owner, spoonAbility.TargetRange, myPos);
	local targetPos = spoonPos;
	if not PositionInRange(range, targetPos) then
		return;
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	
	local applyAct = mastery.ApplyAmount;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = 'OneSpoon' });
	if action then
		ds:WorldAction(action, true);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	
	local spoonAttack = Result_UseAbility(owner, spoonAbility.name, targetPos, {ReactionAbility = true, BattleEvents = battleEvents}, true, {});
	spoonAttack.free_action = true;
	spoonAttack.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(GetSpoonablePos(owner), targetPos)
	end;
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	ds:WorldAction(spoonAttack, true);
end
-- 응징
function Mastery_Retribution_AbilityUsed(eventArg, mastery, owner, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or owner == eventArg.Unit
		or eventArg.Ability.Type ~= 'Attack'
		or eventArg.DirectingConfig.Preemptive
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And') 
		or eventArg.Unit.HP <= 0 then
		return;
	end
	
	local myPos = GetPosition(owner);
	local enemyPos = GetPosition(eventArg.Unit);
	if not IsMeleeDistance(myPos, enemyPos) then
		return;
	end
	
	-- 자신이 포함되어 있으면 발동하지 않음
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if info.Target.name and owner == info.Target then
				return;
			end
		end
	end
	-- 아군이 포함되어 있어야 발동함
	local isRetribution = false;
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if info.Target.name and GetRelation(owner, info.Target) == 'Team' then
				isRetribution = true;
				break;
			end
		end
		if isRetribution then
			break;
		end
	end
	if not isRetribution then
		return;
	end
	
	local retributionAbility = FindAbility(owner, owner.OverwatchAbility);
	if retributionAbility == nil then
		-- 어빌리티가 존재하지만 비활성화된 경우에는 에러 로그를 남가지 않음
		if not FindAbility(owner, owner.OverwatchAbility, false) then
			LogAndPrint('[DataError]', 'No Ability for Retribution.', 'owner.OverwatchAbility:', owner.OverwatchAbility);
		end
		return;
	end
	
	local range = CalculateRange(owner, retributionAbility.TargetRange, myPos);
	if not PositionInRange(range, enemyPos) then
		return;
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	
	local applyAct = mastery.ApplyAmount;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery.name} });
	if action then
		ds:WorldAction(action, true);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	
	local retributionAttack = Result_UseAbility(owner, retributionAbility.name, enemyPos, {ReactionAbility = true, Retribution = true, BattleEvents = battleEvents}, true, {});
	retributionAttack.free_action = true;
	retributionAttack.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, retributionAbility.TargetRange, GetPosition(owner)), enemyPos)
	end;
	ds:WorldAction(retributionAttack, true);
end
-- 자동 응징
function Mastery_Module_Retribution_AbilityUsed(eventArg, mastery, owner, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or owner == eventArg.Unit
		or eventArg.Ability.Type ~= 'Attack'
		or eventArg.DirectingConfig.Preemptive
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And') 
		or mastery.DuplicateApplyChecker > 0
		or eventArg.Unit.HP <= 0 then
		return;
	end
	if owner.Cost < mastery.ApplyAmount3 then
		return;
	end
	
	local myPos = GetPosition(owner);
	local enemyPos = GetPosition(eventArg.Unit);
	if GetDistance3D(myPos, enemyPos) >= (mastery.ApplyAmount + 0.4) then
		return;
	end
	
	-- 자신이 포함되어 있으면 발동하지 않음
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if info.Target.name and owner == info.Target then
				return;
			end
		end
	end
	-- 아군이 포함되어 있어야 발동함
	local isRetribution = false;
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if info.Target.name and GetRelation(owner, info.Target) == 'Team' then
				isRetribution = true;
				break;
			end
		end
		if isRetribution then
			break;
		end
	end
	if not isRetribution then
		return;
	end
	
	local retributionAbility = FindAbility(owner, owner.OverwatchAbility);
	if retributionAbility == nil then
		-- 어빌리티가 존재하지만 비활성화된 경우에는 에러 로그를 남가지 않음
		if not FindAbility(owner, owner.OverwatchAbility, false) then
			LogAndPrint('[DataError]', 'No Ability for Retribution.', 'owner.OverwatchAbility:', owner.OverwatchAbility);
		end
		return;
	end
	
	local range = CalculateRange(owner, retributionAbility.TargetRange, myPos);
	if not PositionInRange(range, enemyPos) then
		return;
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery.name} });
	-- 턴 대기 시간
	local applyAct = mastery.ApplyAmount2;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	if action then
		ds:WorldAction(action, true);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	-- 연료 소모
	local addCost = -1 * mastery.ApplyAmount3;
	local costActions = {};
	local _, reasons2 = AddActionCost(costActions, owner, addCost, true, false);
	if #costActions > 0 then
		for _, action in ipairs(costActions) do
			ds:WorldAction(action, true);
		end
		table.insert(battleEvents, { Object = owner, EventType = 'AddCost', Args = { CostType = owner.CostType.name, Count = addCost } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons2, 'FirstHit'));
	ReasonToUpdateBattleEventMulti(owner, ds, reasons, damageAction, 1);
	-- 응징 공격
	local retributionAttack = Result_UseAbility(owner, retributionAbility.name, enemyPos, {ReactionAbility = true, Retribution = true, BattleEvents = battleEvents}, true, {});
	retributionAttack.free_action = true;
	retributionAttack.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, retributionAbility.TargetRange, GetPosition(owner)), enemyPos)
	end;
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;	
	ds:WorldAction(retributionAttack, true);
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
end
-- 칼날 폭풍
function Mastery_Bladestorm_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.SubType ~= 'Slashing'
		or eventArg.Ability.HitRateType ~= 'Melee'
		or mastery.DuplicateApplyChecker > 0
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	-- 피의 잔영
	local masteryTable = GetMastery(owner);
	local mastery_BloodShadow = GetMasteryMastered(masteryTable, 'BloodShadow');
	
	local hit = false;
	local bleeding = false;
	for i, infoList in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infoList) do
			if info.DefenderState ~= 'Dodge' then
				hit = true;
				if mastery_BloodShadow and HasBuffType(info.Target, nil, nil, mastery_BloodShadow.BuffGroup.name) then
					bleeding = true;
				end	
			end
		end
	end
	if not hit then
		return;
	end
	
	local applyRate = mastery.ApplyAmount;
	if mastery_BloodShadow then
		-- 피의 잔영
		applyRate = applyRate + mastery_BloodShadow.ApplyAmount;
		if bleeding then
			applyRate = applyRate + mastery_BloodShadow.ApplyAmount2;
		end
	end	
	if not RandomTest(applyRate) then
		return;
	end
	
	local ability = eventArg.Ability;
	
	local targetPos;
	if ability.TargetType == 'Single' then
		if eventArg.UserInfo.Target.HP <= 0 then
			return;
		end
		targetPos = GetPosition(eventArg.UserInfo.Target);
	else
		targetPos = eventArg.PositionList[#(eventArg.PositionList)];
	end
	
	local range = CalculateRange(owner, ability.TargetRange, GetPosition(owner));
	if not PositionInRange(range, targetPos) then
		return;
	end
	
	local resultModifier = { ReactionAbility = true, Bladestorm = true };
		
	local masteryTable = GetMastery(owner);
	local mastery_DualBlades = GetMasteryMastered(masteryTable, 'DualBlades');
	if mastery_DualBlades then
		resultModifier['Inevitable'] = true;
	end
		
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});	
	
	local actions = {};
	local applyAct = mastery.ApplyAmount2;
	local applyActAction, reasons = GetApplyActAction(owner, applyAct, 'Cost');
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery.name}});
	if applyActAction then
		table.insert(actions, applyActAction);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	
	resultModifier.BattleEvents = battleEvents;
	local config = {NoCamera = true};
	
	local eventCmd = nil;
	if SafeIndex(eventArg, 'DirectingConfig', 'Preemptive') then
		resultModifier.ReactionAbility = true;
		resultModifier.Moving = SafeIndex(eventArg, 'ResultModifier', 'Moving');
		config.Preemptive = true;
		config.PreemptiveOrder = 2;
		eventCmd = eventArg.ActionID;
	end
	local chainAttack = Result_UseAbility(owner, ability.name, targetPos, resultModifier, true, config);
	if SafeIndex(eventArg, 'DirectingConfig', 'Preemptive') then
		chainAttack.nonsequential = true;
	end
	chainAttack.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, ability.TargetRange, GetPosition(owner)), targetPos)
	end;
	chainAttack.free_action = true;
	if eventCmd ~= nil then
		chainAttack._ref = eventCmd;
		chainAttack._ref_offset = 0;
	end
	table.insert(actions, chainAttack);
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
	end, nil, true, true));
	return unpack(actions);
end
-- 동일한 표적
function Mastery_SameTarget_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local actions = {};
	local successTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' then
			local target = targetInfo.Target;
			local targetKey = GetObjKey(target);
			successTargets[targetKey] = true;
		end
	end);
	table.insert(actions, Result_UpdateInstantProperty(owner, 'SameTarget', successTargets));

	local masteryTable = GetMastery(owner);
	-- 특성 완벽주의자
	local mastery_Perfectionist = GetMasteryMastered(masteryTable, 'Perfectionist');
	if mastery_Perfectionist then
		local hasDeadSameTarget = false;
		local prevSuccessTargets = GetInstantProperty(owner, 'SameTarget') or {};
		ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
			local target = targetInfo.Target;
			local targetKey = GetObjKey(target);
			if targetInfo.IsDead and IsEnemy(owner, target) and prevSuccessTargets[targetKey] then
				hasDeadSameTarget = true;
				return false;
			end
		end);
		if hasDeadSameTarget then
			MasteryActivatedHelper(ds, mastery_Perfectionist, owner, 'AbilityUsed_Self');
			AddActionRestoreActions(actions, owner);
		end
	end
	return unpack(actions);
end
-- 전술적 보완 & 전술적 집중 공용
function Mastery_TacticalShared_AbilityUsed(eventArg, mastery, owner, ds, ifFunc)
	if eventArg.Unit == owner
		or not IsAllyRelation(owner, eventArg.Unit)
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end	
	local applyTargets = {};
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if ifFunc(info) then
				local objKey = GetObjKey(info.Target);
				applyTargets[objKey] = true;
			end
		end
	end
	return Result_UpdateInstantProperty(owner, mastery.name, applyTargets);
end
-- 전술적 보완
function Mastery_TacticalSupplementation_AbilityUsed(eventArg, mastery, owner, ds)
	return Mastery_TacticalShared_AbilityUsed(eventArg, mastery, owner, ds, function(info)
		return info.DefenderState == 'Dodge';
	end);
end
-- 전황 정보 분석
function Mastery_Module_TacticalSupplementation_AbilityUsed(eventArg, mastery, owner, ds)
	return Mastery_TacticalShared_AbilityUsed(eventArg, mastery, owner, ds, function(info)
		return info.DefenderState == 'Dodge' or info.DefenderState == 'Block';
	end);
end
-- 전술적 집중
function Mastery_TacticalConcentration_AbilityUsed(eventArg, mastery, owner, ds)
	return Mastery_TacticalShared_AbilityUsed(eventArg, mastery, owner, ds, function(info)
		return info.DefenderState ~= 'Dodge' and info.MainDamage > 0
	end);
end
-- 이 기회는 나의 것
function Mastery_INeverLostOpportunity_AbilityUsed(eventArg, mastery, owner, ds)
	return Mastery_TacticalShared_AbilityUsed(eventArg, mastery, owner, ds, function(info)
		return info.DefenderState == 'Dodge' or (info.DefenderState ~= 'Dodge' and info.MainDamage > 0);
	end);
end
function Mastery_INeverLostOpportunity_AbilityUsedSelf(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local testTargets = GetInstantProperty(owner, mastery.name) or {};
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return testTargets[GetObjKey(targetInfo.Target)] and IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	if not hasAnyDead then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 영혼 치유사
function Mastery_SoulHealer_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Heal'
		or not IsGetAbilitySubType(eventArg.Ability, 'ESP') then
		return;
	end
	
	local addCostVal = mastery.ApplyAmount;
	local guardian = GetMasteryMastered(GetMastery(owner), 'SoulGuardian');
	if guardian then
		addCostVal = addCostVal + guardian.ApplyAmount2;
	end
	
	local actions = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(info)
		local target = info.Target;
		-- 생명체가 아니면 리턴.
		if not target.Race.Life then
			return;
		end
		local resultCost, reasons = AddActionCost(actions, target, addCostVal, true);
		if target.Cost < resultCost then
			local eventID = ds:UpdateBattleEvent(GetObjKey(target), 'AddCost', { CostType = target.CostType.name, Count = resultCost - target.Cost });
			ds:SetCommandLayer(eventID, game.DirectingCommand.CM_SECONDARY);
			ds:SetContinueOnNormalEmpty(eventID);
			ReasonToUpdateBattleEventMulti(owner, ds, reasons, eventID, 0);
		end
	end);
	local masteryEventID = ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name, AliveOnly = true });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	return unpack(actions);
end
-- 특성 위협
function Mastery_Threat_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local mission = GetMission(owner);
	
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(info)
		local target = info.Target;
		if info.MainDamage <= 0
			or info.AttackerState ~= 'Critical'
			or (target.HP + info.MainDamage) > target.MaxHP * (mastery.ApplyAmount / 100)
			or not IsUnprotectedExposureState(target, info.TargetPos)
			or target.HP <= 0 then
			return;
		end
	
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);	
	end);
	
	if #actions == 0 then
		return;
	end
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local aniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
	ds:Connect(masteryEventID, aniID, 0);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	
	local mastery_SuccessorOfWarrior = GetMasteryMastered(GetMastery(owner), 'SuccessorOfWarrior');
	if mastery_SuccessorOfWarrior then
		AddActionApplyActForDS(actions, owner, -mastery_SuccessorOfWarrior.ApplyAmount, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_SuccessorOfWarrior, owner, 'AbilityUsed');
	end

	return unpack(actions);	
end
-- 위치 선점
function Mastery_PositionOfAdvantage_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local masteryTable = GetMastery(owner);
	local mastery_PreoccupyPosition = GetMasteryMastered(masteryTable, 'PreoccupyPosition')
	if not mastery_PreoccupyPosition then
		return;
	end
	if mastery.DuplicateApplyChecker == 0 then
		local reactionAbility = SafeIndex(eventArg, 'ResultModifier', 'ReactionAbility') and true or false;
		local counterAttack = SafeIndex(eventArg, 'ResultModifier', 'Counter') and true or false;
		local notStableAttack = reactionAbility or counterAttack;
		if IsStableAttack(owner) and not notStableAttack then
			SetInstantProperty(owner, 'StableAttack', true);
		else
			SetInstantProperty(owner, 'StableAttack', nil);
		end
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
end
function Mastery_PositionOfAdvantage_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local masteryTable = GetMastery(owner);
	local mastery_PreoccupyPosition = GetMasteryMastered(masteryTable, 'PreoccupyPosition')
	if not mastery_PreoccupyPosition then
		return;
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	if eventArg.IsFreeAction then
		return;
	end

	local hitTargets = {};
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			if IsEnemy(owner, info.Target) and info.DefenderState ~= 'Dodge' and info.MainDamage > 0 then
				table.insert(hitTargets, info.Target);
    			break;
			end
		end
	end
	if #hitTargets == 0 then
		return;
	end
	
	local isStableAttack = GetInstantProperty(owner, 'StableAttack');
	SetInstantProperty(owner, 'StableAttack', nil);
	
	-- 안정된 자세도 아니고, 높은 위치가 적용되는 적이 하나도 없으면 무시
	if not isStableAttack then
		local heightTargets = table.filter(hitTargets, function(target)
			local _, height = GetDistanceFromObjectToObjectAbility(eventArg.Ability, owner, target);
			return IsAttakerHighPosition(height, masteryTable, GetMastery(target));	
		end);
		if #heightTargets == 0 then
			return;
		end
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	local applyAct = -mastery_PreoccupyPosition.ApplyAmount;

	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});

	return unpack(actions);
end
function Mastery_Wanderer_AbilityUsed(eventArg, mastery, owner, ds)
	return Result_UpdateInstantProperty(owner, 'WandererActive', eventArg.Ability.Type == 'Move');
end
-- 특성 제압
function Mastery_Overpower_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local resultModifier = eventArg.ResultModifier;
	local isForestallment = SafeIndex(resultModifier, 'Forestallment');
	local isMovingTarget = SafeIndex(eventArg.DirectingConfig, 'Preemptive');
	if not isForestallment then
		return;
	end
	
	-- 세트 특성인데 없을리가...
	local mastery_Forestallment = GetMasteryMastered(GetMastery(owner), 'Forestallment');
	if not mastery_Forestallment then
		return;
	end
	if mastery_Forestallment.DuplicateApplyChecker == 0 then
		return;
	end

	local mission = GetMission(owner);
	
	-- 어빌리티 피격 대상
	local targetInfoMap = {};
	for i, infos in ipairs({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}) do
		for j, info in ipairs(infos) do
			local target = info.Target;
			local targetKey = GetObjKey(target);
			targetInfoMap[targetKey] = info;
		end
	end
	
	-- 근접 범위
	local meleeRange = CalculateRange(owner, 'Box1_Attack', GetPosition(owner));
	
	-- 근접한 적 TargetInfo 필터링
	local meleeTargetInfos = {};
	local hasEnemyNotTarget = false;
	for _, pos in ipairs(meleeRange) do
		local obj = GetObjectByPosition(mission, pos);
		if obj and IsEnemy(owner, obj) then
			local objKey = GetObjKey(obj);
			local targetInfo = targetInfoMap[objKey];
			if targetInfo then
				table.insert(meleeTargetInfos, targetInfo);
			else
				hasEnemyNotTarget = true;
				break;
			end
		end
	end
	-- 어빌리티 대상이 아닌 적이 하나라도 있으면, 발동 안함
	if hasEnemyNotTarget then
		return;
	end

	local hasFailTarget = false;
	for _, targetInfo in ipairs(meleeTargetInfos) do
		if not targetInfo.IsDead then
			-- 이동 중인 적은 기선제압으로 바로 죽인 게 아니면, 발동 안함
			if isMovingTarget then
				hasFailTarget = true;
				break;
			end
			-- 넉백이 안 되었으면, 발동 안함
			if targetInfo.SlideType ~= 'Knockback' then
				hasFailTarget = true;
				break;
			end
			-- 넉백 위치가 근접 범위 안이면, 발동 안함
			if PositionInRange(meleeRange, targetInfo.AfterPosition) then
				hasFailTarget = true;
				break;
			end
		end
	end
	-- 근접한 어빌리티 대상 중에 발동 대상이 아닌 게 하나라도 있으면 실패
	if hasFailTarget then
		return;
	end
	
	-- 턴 대기시간 증가
	local actions = {};
	local applyAct = mastery.ApplyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Cost');
	local objKey = GetObjKey(owner);
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	
	table.insert(actions, Result_FireWorldEvent('OverpowerInvoked_Self', {Unit=owner}, self, true));
	
	return unpack(actions);
end
function Mastery_Overpower_OverpowerInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 기선 제압 활성화
	local mastery_Forestallment = GetMasteryMastered(GetMastery(owner), 'Forestallment');
	if not mastery_Forestallment then
		return;
	end
	mastery_Forestallment.DuplicateApplyChecker = 0;
end
function Mastery_Sweeping_AbilityUsed(eventArg, mastery, owner, ds)
	if owner.TurnState.TurnEnded
		or eventArg.Ability.Type ~= 'Attack'
		or table.count(GetAllUnitInSight(owner, true), function(obj) return IsEnemy(owner, obj) and obj.HP > 0; end) > 0 then
		return;
	end
	local allDead = true;
	local killExist = false;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(info)
		if not IsInSight(owner, info.Target, true) 
			or not IsEnemy(owner, info.Target) then
			return true;
		end
		if info.Target.HP > 0 then
			allDead = false;
			return false;
		else
			killExist = true;
		end
		return true;
	end);
	if not (allDead and killExist) then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	local actions = {};
	AddActionRestoreActions(actions, owner);
	return unpack(actions);
end
function Mastery_WhiteMagicCircuit_AbilityUsed(eventArg, mastery, owner, ds)
	if (eventArg.Ability.Type ~= 'Heal' and eventArg.Ability.Type ~= 'Assist')
		or eventArg.Ability.ItemAbility
		or not IsGetAbilitySubType(eventArg.Ability, 'ESP') then
		return;
	end

	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWaitCustomEvent', {Time = -mastery.ApplyAmount, EventType = 'Ending'});
	end
	ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'PreAbilityUsing'});	
	
	return unpack(actions);
end
-- 특성 저주 받은 검
function Mastery_CursedSword_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.SubType ~= 'Slashing' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and target.HP > 0 then
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	-- 타겟별 확률 테스트
	local badBuffList = Linq.new(GetClassList('Buff_Negative'))
		:select(function(pair) return pair[1]; end)
		:toList();
	
	local prob = mastery.ApplyAmount;
	local masteryTable = GetMastery(owner);
	local mastery_UnlimitedBlade = GetMasteryMastered(masteryTable, 'UnlimitedBlade');
	if mastery_UnlimitedBlade then
		prob = 100;
	end
	
	local applyInfos = table.map(applyTargets, function(target)
		if not RandomTest(prob) then
			return;
		end
		local buffPicker = RandomBuffPicker.new(target, badBuffList);
		local pickBuff = buffPicker:PickBuff();
		if not pickBuff then
			return;
		end
		return { Target = target, Buff = pickBuff };
	end);
	if table.empty(applyInfos) then
		return;
	end
		
	local actions = {};
	local objKey = GetObjKey(owner);
	for targetKey, info in pairs(applyInfos) do
		ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery.name });
		InsertBuffActions(actions, owner, info.Target, info.Buff, 1, true);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'AbilityUsed'});
	return unpack(actions);
end
-- 특성 보이지 않는 검
function Mastery_InvisibleSword_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local battleTargets = GetInstantProperty(owner, 'InvisibleSword') or {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if IsEnemy(owner, target) then
			local targetKey = GetObjKey(target);
			battleTargets[targetKey] = true;
		end
	end);	
	return Result_UpdateInstantProperty(owner, 'InvisibleSword', battleTargets);
end
-- 특성 무한검
function Mastery_UnlimitedBlade_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local killCount = 0;
	local killTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		if IsEnemy(owner, target) and target.HP <= 0 and not killTargets[targetKey] then
			killCount = killCount + 1;
			killTargets[targetKey] = true;
		end
	end);
	if table.empty(killTargets) then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, killCount, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'AbilityUsed'});
	return unpack(actions);
end
-- 특성 재생의 축복
function Mastery_BlessOfRegeneration_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Heal'
		or not IsGetAbilitySubType(eventArg.Ability, 'ESP') then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		applyTargets[targetKey] = target;
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	for targetKey, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'AbilityUsed'});
	return unpack(actions);
end
-- 특성 기적
function Mastery_Miracle_AbilityUsed(eventArg, mastery, owner, ds)
	if (eventArg.Ability.Type ~= 'Heal' and eventArg.Ability.Type ~= 'Assist')
		or (eventArg.Ability.Type == 'Assist' and eventArg.Ability.Cost <= 0)
		or eventArg.Ability.ItemAbility	then
		return;
	end
	if not GetInstantProperty(owner, 'Miracle') then
		return;
	end
	SetInstantProperty(owner, 'Miracle', nil);
	
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		if IsTeamOrAlly(owner, target) then
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local actions = {};
	
	-- 성자
	local masteryTable = GetMastery(owner);
	local mastery_Saint = GetMasteryMastered(masteryTable, 'Saint');
	if mastery_Saint then
		local objKey = GetObjKey(owner);
		local applyAct = -1 * mastery_Saint.ApplyAmount;
		ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery_Saint.name });
		for targetKey, target in pairs(applyTargets) do
			local added, reasons = AddActionApplyAct(actions, owner, target, applyAct, 'Friendly');
			if added then
				ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
			end
			ReasonToUpdateBattleEventMulti(target, ds, reasons);
		end
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_Saint.name, EventType = 'AbilityUsed'});
	end
	
	return unpack(actions);
end
-- 특성 마도의 길
function Mastery_TheWayOfMage_AbilityUsed(eventArg, mastery, owner, ds)
	local ability = eventArg.Ability;
	if not IsGetAbilitySubType(ability, 'ESP')
		or ability.ItemAbility
		or ability.ApplyTargetBuff.name == nil
		or ability.ApplyTargetBuff.Type ~= 'Debuff'
		or ability.ApplyTargetBuffLv <= 0 then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if IsEnemy(owner, target) and targetInfo.BuffApplied then
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	for targetKey, target in pairs(applyTargets) do
		local immune, reason = BuffImmunityTest(mastery.Buff, target);
		-- 종족 면역은 굳이 버프를 걸어서 표시할 필요는 없겠지...
		if not immune or reason ~= 'ImmuneRace' then
			InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
		end
	end
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	return unpack(actions);
end
-- 특성 파죽지세
function IsUnyieldingAbility(resultModifier)
	return resultModifier and (resultModifier.Forestallment or resultModifier.Bladestorm or resultModifier.Counter);
end
function Mastery_Unyielding_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsUnyieldingAbility(eventArg.ResultModifier) then
		return;
	end
	local hasNotDodge = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return targetInfo.DefenderState ~= 'Dodge';
	end);
	if not hasNotDodge then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	return unpack(actions);
end
-- 약육강식
function Mastery_LawOfTheJungle_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local deadCount = 0;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead then
			deadCount = deadCount + 1;
		end
	end);
	if deadCount < 1 then
		return;
	end
	
	local actions = {};
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	local goodBuff = goodBuffPicker:PickBuff();
	if goodBuff then
		InsertBuffActions(actions, owner, owner, goodBuff, 1);
		MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	end
	return unpack(actions);
end
-- 사냥꾼의 본능
function Mastery_InstinctOfHunter_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasTarget = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead and targetInfo.PrevHP <= targetInfo.MaxHP * mastery.ApplyAmount / 100;
	end);
	if not hasTarget then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 유체역학
function Mastery_FluidMechanics_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' then
			local target = targetInfo.Target;
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	for targetKey, target in pairs(applyTargets) do
		local applyAct = mastery.ApplyAmount;
		if target.Race.name == 'Machine' then
			applyAct = applyAct + mastery.ApplyAmount2;
		end		
		local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Hostile');
		if added then
			ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
	end
	return unpack(actions);
end
-- 불꽃의 군주
function Mastery_LordOfFlame_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.SubType ~= 'Fire' then
		return;
	end
	-- 증오의 군주
	local masteryTable = GetMastery(owner);
	local mastery_LordOfHatred = GetMasteryMastered(masteryTable, 'LordOfHatred');
	if not mastery_LordOfHatred then
		return;
	end
	local lostHPRatio = (owner.MaxHP - owner.HP) / owner.MaxHP;
	local addSP = math.floor(lostHPRatio * 100 / mastery.ApplyAmount2) * mastery.ApplyAmount3;
	if addSP <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'OverchargeEnded');
	MasteryActivatedHelper(ds, mastery_LordOfHatred, owner, 'OverchargeEnded');
	AddSPPropertyActions(actions, owner, owner.ESP.name, addSP, true, ds, true);
	return unpack(actions);
end
-- 폭풍 망치
function Mastery_StormHammer_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.SubType ~= 'Wind' then
		return;
	end
	-- 넉백 파워가 있어도 뒤가 막혀서 밀리지 않고 스턴 걸리는 경우는 무시
	local hasAnyKnockbackMoved = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.KnockbackPower > 0 and targetInfo.SlideType == 'Knockback';
	end);
	-- 바람 속성 공격 + 바람 망치 + 명중 + 데미지 상황에서 넉백 파워가 없으면 넉백 면역으로 간주
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and targetInfo.KnockbackPower == 0 then
			local target = targetInfo.Target;
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if not hasAnyKnockbackMoved and table.empty(applyTargets) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	for targetKey, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	end
	if hasAnyKnockbackMoved  then
		AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	end
	return unpack(actions);
end
-- 하얀 모래바람
function Mastery_WhiteSandstorm_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.SubType ~= 'Earth' then
		return;
	end
	local ownerPos = GetPosition(owner);
	local checkDist = mastery.ApplyAmount + 0.4;
	local hasAnyTarget = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		return targetInfo.IsDead and GetDistance3D(ownerPos, GetPosition(target)) <= checkDist and HasBuffType(target, nil, nil, mastery.BuffGroup.name);
	end);
	if not hasAnyTarget  then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	AddActionRestoreActions(actions, owner);
	return unpack(actions);
end
-- 붉은 달
function Mastery_Redmoon_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or GetWithoutError(eventArg.Ability.ApplyTargetBuff, 'Type') ~= 'Debuff' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.BuffApplied and not targetInfo.IsDead then
			local target = targetInfo.Target;
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	for targetKey, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	end
	return unpack(actions);
end
-- 얼어붙은 영혼 수확자
function Mastery_FrozenReaper_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.CountChecker = 0;
end
function Mastery_FrozenReaper_AbilityUsed(eventArg, mastery, owner, ds)
	if owner.TurnState.TurnEnded 	-- 턴중에만 발동
		or eventArg.Ability.Type ~= 'Attack' then		
		return;
	end
	if mastery.CountChecker <= 0 then
		return;
	end
	local actions = {};
	AddActionRestoreActions(actions, owner);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	return unpack(actions);
end
-- 앤이 좋아요
function Mastery_ILikeAnne_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.Unit)
		or not IsInSight(owner, GetPosition(eventArg.Unit), true) then
		return;
	end
	local hasAnneDamage = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return targetInfo.Target.Info.name == 'Anne' and targetInfo.MainDamage > 0;
	end);
	if not hasAnneDamage then
		return;
	end
	local abilities = table.filter(GetAvailableAbility(owner, true), function (ability) return ability.Type == 'Attack' and not ability.SPFullAbility end);
	local abilityRank = {};
	for i, ability in ipairs(abilities) do
		abilityRank[ability.name] = #abilities - i;
	end
	
	local usingAbility, usingPos, _, score = FindAIMainAction(owner, abilities, {{Strategy = function(self, adb)
		local count = table.count(adb.ApplyTargets, function(t) return t == eventArg.Unit end);
		if count == 0 then
			return -22;
		end
		local score = 100;
		if adb.IsIndirect then
			score = 0;
		end
		score = score + abilityRank[adb.Ability.name] * 200;
		return score + 100 / (adb.Distance + 1);
	end, Target = 'Attack'}}, {}, {});
	
	if usingAbility == nil or usingPos == nil then
		return;
	end
	
	local actions = {};
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery.name} });
	
	local overwatchAction = Result_UseAbility(owner, usingAbility.name, usingPos, {ReactionAbility=true, BattleEvents=battleEvents}, true, {});
	overwatchAction.free_action = true;
	overwatchAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, usingAbility.TargetRange, GetPosition(owner)), usingPos);
	end;
	table.insert(actions, overwatchAction);
	
	return unpack(actions);
end
-- 재소탕
function Mastery_Resweeping_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force'
		or eventArg.Ability.SubType ~= 'Piercing' then
		return;
	end
	local targetList = GetInstantProperty(owner, mastery.name);
	SetInstantProperty(owner, mastery.name, nil);
	if not targetList then
		return;
	end
	local mission = GetMission(owner);
	local aliveList = table.filter(table.map(targetList, function(targetKey)
		return GetUnit(mission, targetKey, true);
	end), function(target)
		return target and not IsDead(target);
	end);
	if #aliveList == 0 then
		return;
	end
	local actions = {};
	AddActionRestoreActions(actions, owner);
	
	-- 나는 포기하지 않는다.
	local mastery_IDontGiveUp = GetMasteryMastered(GetMastery(owner), 'IDontGiveUp');
	if mastery_IDontGiveUp then
		table.insert(actions, Result_UpdateInstantProperty(owner, 'IDontGiveUp_SweepTarget', Set.new(table.map(aliveList, function(o) return GetObjKey(o); end))));
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	return unpack(actions);
end
-- 깜짝 놀래키기
function Mastery_Surprising_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	local ownerPos = GetPosition(owner);
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if IsEnemy(owner, target) and targetInfo.DefenderState ~= 'Dodge' then
			local coverState = GetCoverStateForCritical(target, GetMastery(target), ownerPos, owner);
			if coverState ~= 'None' and target.Movable and not GetBuffStatus(target, 'Unconscious', 'Or') then
				local targetKey = GetObjKey(target);
				applyTargets[targetKey] = target;
			end
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	for _, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	end
	-- 깜짝 공연
	local mastery_SurprisingStage = GetMasteryMastered(GetMastery(owner), 'SurprisingStage');
	if mastery_SurprisingStage then
		local subTargets = {};
		local applyDist = mastery_SurprisingStage.ApplyAmount;
		for _, target in pairs(applyTargets) do
			local targetObjects = Linq.new(GetNearObject(target, applyDist + 0.4))
				:where(function(o) return o ~= target and IsEnemy(owner, o) end)
				:toList();
			for _, subTarget in ipairs(targetObjects) do
				subTargets[GetObjKey(subTarget)] = subTarget;
			end
		end
		for _, target in pairs(subTargets) do
			if target.Movable and not GetBuffStatus(target, 'Unconscious', 'Or') then
				InsertBuffActions(actions, owner, target, mastery_SurprisingStage.Buff.name, 1, true);
			end
		end
	end
	return unpack(actions);
end
-- 청중 사로잡기
function Mastery_CaptivateAudience_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	if not hasAnyDead then
		return;
	end
	local applyDist = mastery.ApplyAmount;
	local addBuffLv = 1;
	local masteryTable = GetMastery(owner);
	-- 빛나는 자
	local mastery_Luminary = GetMasteryMastered(masteryTable, 'Luminary');
	if mastery_Luminary then
		applyDist = mastery_Luminary.ApplyAmount;
	end
	-- 청중 압도하기
	local mastery_OverwhelmAudience = GetMasteryMastered(masteryTable, 'OverwhelmAudience');
	if mastery_OverwhelmAudience then
		addBuffLv = addBuffLv + mastery_OverwhelmAudience.ApplyAmount;
	end
	local targetObjects = Linq.new(GetNearObject(owner, applyDist + 0.4))
		:where(function(o) return GetRelation(owner, o) == 'Team' end)
		:toList();
	if #targetObjects == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);
	for _, target in ipairs(targetObjects) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, addBuffLv, true);
	end
	return unpack(actions);	
end
-- 혁명가
function Mastery_Revolutionist_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDeadHigherLv = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead and targetInfo.Target.Lv > owner.Lv;
	end);
	local hasAnyDeadLowerLv = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead and targetInfo.Target.Lv < owner.Lv;
	end);
	if not hasAnyDeadHigherLv and not hasAnyDeadLowerLv then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);
	-- 모험가
	if hasAnyDeadHigherLv then
		AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	end
	-- 우월감
	if hasAnyDeadLowerLv then
		InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, true);
	end
	return unpack(actions);	
end
-- 지배자
function Mastery_Overlord_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDeadLowerLv = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead and targetInfo.Target.Lv < owner.Lv;
	end);
	local hasAnyDeadSenseOfDuty = mastery.CountChecker > 0;
	mastery.CountChecker = 0;
	if not hasAnyDeadLowerLv or not hasAnyDeadSenseOfDuty then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);
	-- 우월감
	if hasAnyDeadLowerLv then
		InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, true);
	end
	-- 사명감
	if hasAnyDeadSenseOfDuty then
		AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	end
	return unpack(actions);	
end
-- 일그러진 마음
function Mastery_UglyMind_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		if IsEnemy(owner, target) and targetInfo.IsDead and not applyTargets[targetKey] then
			local buffList = GetBuffType(target, 'Buff');
			if #buffList > 0 then
				applyTargets[targetKey] = { Target = target, BuffList = buffList };
			end
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);
	local addBuffLvSet = {};
	for _, info in pairs(applyTargets) do
		local target = info.Target;
		for _, buff in ipairs(info.BuffList) do
			-- 대상 버프 제거
			InsertBuffActions(actions, owner, target, buff.name, -buff.Lv, true);
			-- 추가될 버프 레벨 누적
			if buff.Stack then
				addBuffLvSet[buff.name] = (addBuffLvSet[buff.name] or 0) + buff.Lv;
			else
				addBuffLvSet[buff.name] = 1;
			end
		end
	end
	-- 버프 추가
	for buffName, buffLv in pairs(addBuffLvSet) do
		InsertBuffActions(actions, owner, owner, buffName, buffLv, true);
	end
	return unpack(actions);	
end
-- 얼어붙는 피
function Mastery_FrozenBlood_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.SubType ~= 'Ice' then
		return;
	end
	local actions = {};
	local testBuff = GetBuff(owner, 'AntiFreezingInfusionSolution');
	if testBuff and testBuff.Lv > 0 then
		InsertBuffActions(actions, owner, owner, testBuff.name, -1 * testBuff.ApplyAmount, true);
		-- 항동결 부작용
		local mastery_AntiFreezingSideEffect = GetMasteryMastered(GetMastery(owner), 'AntiFreezingSideEffect');
		if mastery_AntiFreezingSideEffect then
			MasteryActivatedHelper(ds, mastery_AntiFreezingSideEffect, owner, 'AbilityUsed');
			-- HP 회복
			local addHP = math.floor(owner.MaxHP * mastery_AntiFreezingSideEffect.ApplyAmount2 / 100);
			AddActionRestoreHPForDS(actions, owner, owner, addHP, ds);
			AddMasteryDamageChat(ds, owner, mastery_AntiFreezingSideEffect, -1 * addHP);
			-- 기력 회복
			local addCost = math.floor(owner.MaxCost * mastery_AntiFreezingSideEffect.ApplyAmount2 / 100);
			AddActionCostForDS(actions, owner, addCost, true, nil, ds);
		end
	else
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	end
	return unpack(actions);
end
-- 공연시스템
function Mastery_PerformanceSystem_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.PerformanceEffect == 'None' then
		return;
	end
	local actions = {};
	AddPerformanceEffectAction(actions, owner, eventArg.Ability.PerformanceEffect, eventArg.Ability.name);
	return unpack(actions);
end
-- 경쾌한 안무
function Mastery_NimbleMovements_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.PerformanceEffect ~= 'Dance_Nimble' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	AddActionApplyActForDS(actions, owner, -1 * mastery.ApplyAmount2, ds, 'Friendly');
	return unpack(actions);
end
-- 화려한 안무
function Mastery_FlashyHandMovements_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.PerformanceEffect ~= 'Dance_FlashyHand' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount2, true, ds, true);
	return unpack(actions);
end
-- 정교한 안무
function Mastery_UnderstatedMovements_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.PerformanceEffect ~= 'Dance_Understated' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	-- 어빌리티 재사용 대기 시간 감소
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount2, function (ability)
		return ability.name ~= eventArg.Ability.name;
	end);
	return unpack(actions);
end
-- 격렬한 안무
function Mastery_PowerfulMovements_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.PerformanceEffect ~= 'Dance_Powerful' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 순회 공연
function Mastery_ShowOnTour_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.PerformanceEffect == 'None' then
		return;
	end
	local newEffect = eventArg.Ability.PerformanceEffect;
	local prevEffect = GetInstantProperty(owner, mastery.name);
	SetInstantProperty(owner, mastery.name, newEffect);
	-- 처음 공연 효과는 기록만 하고 넘어감
	if not prevEffect then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	if prevEffect == newEffect then
		AddActionApplyActForDS(actions, owner, -1 * mastery.ApplyAmount, ds, 'Friendly');
	else
		AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	end
	return unpack(actions);
end
-- 임기응변
function IsAdaptationToCircumstancesAbility(resultModifier)
	return resultModifier and (resultModifier.Counter or resultModifier.ReactionAbility);
end
function Mastery_AdaptationToCircumstances_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsAdaptationToCircumstancesAbility(eventArg.ResultModifier) then
		return;
	end
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	if not hasAnyDead then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);	
	AddActionApplyActForDS(actions, owner, -1 * mastery.ApplyAmount, ds, 'Friendly');
	return unpack(actions);
end
-- 피의 광란
function Mastery_BloodFrenzy_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyBuffGroup = SafeIndex(GetWithoutError(eventArg.Ability, 'ApplyTargetBuff'), 'Group');
	local applySubBuffGroup = SafeIndex(GetWithoutError(eventArg.Ability, 'ApplyTargetSubBuff'), 'Group');
	if applyBuffGroup ~= mastery.BuffGroup.name and applySubBuffGroup ~= mastery.BuffGroup.name then
		return;
	end
	local hasAnyBuff = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.BuffApplied;
	end);
	if not hasAnyBuff then
		return;
	end
	return Mastery_BloodFrenzy_InvokeCommon(mastery, owner, ds, 'AbilityUsed');
end
function Mastery_BloodFrenzy_InvokeCommon(mastery, owner, ds, eventType)
	local addBuffList = Linq.new(GetClassList('Buff_Rage'))
		:where(function(pair)
			local buff = GetClassList('Buff')[pair[1]];
			return buff.Type == 'Buff' and buff.SubType ~= 'Aura'; end)
		:select(function(pair) return pair[1]; end)
		:toList();
	local buffPicker = RandomBuffPicker.new(owner, addBuffList);
	local pickBuff = buffPicker:PickBuff();
	if not pickBuff then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, eventType);
	InsertBuffActions(actions, owner, owner, pickBuff, 1, true);
	return unpack(actions);
end
-- 물에 독타기
function Mastery_PoisonedWater_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.SubType ~= 'Water' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if targetInfo.MainDamage > 0 and targetInfo.AttackerState == 'Critical' and target.HP > 0 then
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local buffList = GetClassList('Buff');
	local addBuffList = Linq.new(GetClassList('Buff_Poison'))
		:where(function(pair)
			local buff = buffList[pair[1]];
			return buff.Type == 'Debuff' and buff.SubType ~= 'Aura'; end)
		:select(function(pair) return pair[1]; end)
		:toList();
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);
	for _, target in pairs(applyTargets) do
		local buffPicker = RandomBuffPicker.new(target, addBuffList);
		local pickBuff = buffPicker:PickBuff();
		if pickBuff then
			InsertBuffActions(actions, owner, target, pickBuff, 1, true);
		end
	end
	return unpack(actions);
end
-- 최상위 포식자
function Mastery_ApaxPredator_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	-- 다른 요소로 인해 자신의 HP가 이미 변경되었을 수도 있으므로, 공격 전 HP와 현재 HP 중에서 작은 값으로 최대한 잘 발동하게...
	local ownerHP = math.min(GetInstantProperty(owner, mastery.name), owner.HP);
	local hasAnyDeadHigherHP = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead and targetInfo.PrevHP > ownerHP;
	end);
	if not hasAnyDeadHigherHP then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 주포 연사
function Mastery_CannonContinuousFire_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	if not hasAnyDead then
		return;
	end	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	-- 어빌리티 재사용 대기 시간 감소
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount2, function (ability)
		return ability.Type == 'Attack';
	end);
	return unpack(actions);
end
-- 일격즉참
function Mastery_OneSlashing_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.SubType ~= 'Slashing' then
		return;
	end
	if not HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead and (targetInfo.PrevHP == targetInfo.MaxHP) and not targetInfo.Target.Obstacle;
	end) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
	return unpack(actions);
end
-- 선혈의 미치광이
function Mastery_BloodSwordBerserker_AbilityUsed(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	mastery.CountChecker = 0;
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 바위 망치
function Mastery_StoneHammer_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	-- 물리 공격 어빌리티 적중 대상
	local applyTargets = {};
	if IsGetAbilitySubType(eventArg.Ability, 'Physical') then
		ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
			local target = targetInfo.Target;
			if targetInfo.DefenderState ~= 'Dodge' and target.HP > 0 then
				applyTargets[GetObjKey(target)] = target;
			end
		end);
	end
	-- 적 Dead 성공
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	if table.empty(applyTargets) and not hasAnyDead then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	for _, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	end
	if hasAnyDead then
		AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	end
	return unpack(actions);
end
-- 만독
function Mastery_AllPoison_AbilityUsed(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	mastery.CountChecker = 0;
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	AddActionRestoreActions(actions, owner);
	return unpack(actions);
end
-- 히어로의 책임감
function Mastery_HeroResponsibility_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	local hasAnyTarget = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local isAlly = IsTeamOrAlly(owner, target);
		local isCitizen = GetInstantProperty(target, 'CitizenType') ~= nil;
		if (not isAlly and not isCitizen) or target.Obstacle then
			return false;
		end
		if not IsInSight(owner, GetPosition(target), true) then
			return false;
		end
		return targetInfo.IsDead or (targetInfo.MainDamage >= target.MaxHP * mastery.ApplyAmount / 100);
	end);
	if not hasAnyTarget then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	return unpack(actions);
end
-- 그림자 저격
function Mastery_ShadowSniper_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsGetAbilitySubType(eventArg.Ability, 'Piercing')
		or eventArg.Ability.HitRateType ~= 'Force' then
		return;
	end
	local hasDeadTarget = false;
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
		local target = targetInfo.Target;
		if IsEnemy(owner, target) and targetInfo.IsDead and GetDistanceFromObjectToObject(owner, target) >= mastery.ApplyAmount then
			hasDeadTarget = true;
			Linq.new(GetNearObject(target, mastery.ApplyAmount2 + 0.4))
				:where(function(o) return IsEnemy(owner, o) and target ~= o end)
				:foreach(function(o) applyTargets[GetObjKey(o)] = o end);
		end
	end);
	if not hasDeadTarget then
		return;
	end
	
	local enemyConfused = false;
	local applyFunc = nil;
	if owner.ExposedByEnemy then
		-- 적 팀 시야에 노출된 경우: 전투 불능이 된 적의 반경 2칸 내의 모든 적은 턴 대기 시간이 10 증가합니다.
		applyFunc = function(actions, unit)
			local added, reasons = AddActionApplyAct(actions, owner, unit, mastery.ApplyAmount, 'Hostile');
			if added then
				ds:UpdateBattleEvent(GetObjKey(unit), 'AddWait', { Time = mastery.ApplyAmount, Delay = true });
			end
			ReasonToUpdateBattleEventMulti(unit, ds, reasons);
		end;
	else
		-- 적 팀 시야에 노출되지 않은 경우: 전투 불능이 된 적의 반경 2칸 내의 모든 적은 혼란 상태가 됩니다.
		applyFunc = function(actions, unit)
			InsertBuffActions(actions, owner, unit, mastery.Buff.name, 1, true);
			enemyConfused = true;
		end;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	for _, target in pairs(applyTargets) do
		applyFunc(actions, target);
	end
	
	local mastery_ShadowInDark = GetMasteryMastered(GetMastery(owner), 'ShadowInDark');
	if mastery_ShadowInDark and not owner.ExposedByEnemy then
		AddActionRestoreActions(actions, owner);
		MasteryActivatedHelper(ds, mastery_ShadowInDark, owner, 'UnitKilled_Self');
	end
	
	-- 그림자 저격 혼란 업적
	if enemyConfused then
		table.insert(actions, Result_FireWorldEvent('ShadowSniperConfused', { Unit = owner }));
		ds:UpdateSteamAchievement('SituationShadowSniperConfusion', true, GetTeam(owner));
	end
	
	return unpack(actions);
end
-- 낚시왕
function Mastery_KingOfFishing_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	if not owner.ExposedByEnemy and table.find({'ClimbWeb', 'FallWeb_Move', 'PreyFishing', 'PreyDown'}, eventArg.Ability.name) then
		MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
		if eventArg.Ability.name == 'ClimbWeb' then
			AddActionRestoreActions(actions, owner);
		else
			InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
		end
	elseif eventArg.Ability.Type == 'Attack' and mastery.DuplicateApplyChecker > 0 then
		local hasDeadEnemy = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function(targetInfo)
			return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead and IsObjectOnFieldEffectBuffAffector(targetInfo.Target, 'Web');
		end);
		if hasDeadEnemy then
			MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
			AddActionRestoreActions(actions, owner);
		end
	end
	return unpack(actions);
end
-- 떠돌이 싸움꾼
function Mastery_WandererFighter_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	-- 적 Dead 성공
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	if not hasAnyDead then
		return;
	end
	-- 범위 체크
	local targetList = GetTargetInRangeSightReposition(SafeIndex(eventArg.Ability, 'AbilityWithMove'), owner, mastery.Range, 'Team', true);
	if #targetList > 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
-- 반응 사격 제어 프로그램
function Mastery_Module_WeaponAimResponsiveFire_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local invokeMastery = SafeIndex(eventArg, 'ResultModifier', 'InvokeMastery');
	if not invokeMastery or not table.find({'Module_SupportingFire', 'Module_ForestallmentFire', 'Module_CloseCheckFire'}, invokeMastery) then
		return;
	end	
	-- 적 Dead 성공
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	if not hasAnyDead then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	return unpack(actions);
end
-- 선혈의 야수
function Mastery_BloodyBeast_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if mastery.CountChecker <= 0 then
		return;
	end
	mastery.CountChecker = 0;
	
	local buffList = GetClassList('Buff');
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:where(function(buffName) return buffList[buffName].SubType == 'Mental'; end)
		:toList();
	
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	local goodBuff = goodBuffPicker:PickBuff();
	if not goodBuff then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	InsertBuffActions(actions, owner, owner, goodBuff, 1, true);
	-- 선혈의 괴수
	local mastery_BloodyMonster = GetMasteryMastered(GetMastery(owner), 'BloodyMonster');
	if mastery_BloodyMonster then
		MasteryActivatedHelper(ds, mastery_BloodyMonster, owner, 'AbilityUsed');
		AddActionCostForDS(actions, owner, mastery_BloodyMonster.ApplyAmount3, true, nil, ds);
	end
	return unpack(actions);
end
-- 선혈의 괴수
function Mastery_BloodyMonster_AbilityUsed(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	mastery.CountChecker = 0;
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	return unpack(actions);
end
-- 질투의 화신
function Mastery_JealousyIncarnate_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		-- 대상이 야수가 아니면 안 됨
		if SafeIndex(target, 'Race', 'name') ~= 'Beast' then
			return;
		end
		-- 내가 야수면, 대상의 등급이 더 높으면 안 됨
		if SafeIndex(owner, 'Race', 'name') == 'Beast' then
			if owner.Grade.Weight < target.Grade.Weight then
				return;
			end
		end
		local testDamage = math.floor(target.MaxHP * mastery.ApplyAmount / 100);
		if targetInfo.MainDamage >= testDamage and targetInfo.AttackerState == 'Critical' and target.HP > 0 then
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	for targetKey, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	end
	return unpack(actions);

end
-- 붉은 송곳니
function Mastery_Amulet_Dorori_Fang_Red_AbilityUsed(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	mastery.CountChecker = 0;
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	AddActionCostForDS(actions, owner, mastery.ApplyAmount, true, nil, ds);
	return unpack(actions);
end
-----------------------------------------------------------------------
-- 어빌리티 사용 임박 [PreAbilityUsing]
-----------------------------------------------------------------------
-- 나는 포기하지 않는다
function Mastery_IDontGiveUp_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.CountChecker = 0;
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force' then
		return;
	end
	local targetPos = eventArg.PositionList[#(eventArg.PositionList)];
	local applyTargets = table.filter(BuildApplyTargetInfos(owner, eventArg.Ability, targetPos), function(info)
		return info.Object and IsEnemy(owner, info.Object);
	end);
	if #applyTargets < mastery.ApplyAmount then
		return;
	end
	mastery.CountChecker = 1;
	targetList = table.map(applyTargets, function(info) return GetObjKey(info.Object) end);
	SetInstantProperty(owner, 'IDontGiveUp_Target', targetList);
end
-- 반동 제어기
function Mastery_Module_ControlReactor_PreAbilityUsing(eventArg, mastery, owner, ds)
	if owner.TurnState.TurnEnded
		or eventArg.Ability.Type ~= 'Attack'
		or owner.TurnState.Moved then
		return;
	end
	
	return Result_DirectingScript(function (mid, ds, args)
		local actions = {};
		MasteryActivatedHelper(ds, mastery, owner, 'PreAbilityUsing_Self');
		AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
		return unpack(actions);
	end);
end
-- 그물 위의 사냥꾼, 수면 위의 사냥꾼, 수풀 속의 사냥꾼
function Mastery_OnFieldHunter_PreAbilityUsing(eventArg, mastery, owner, ds)
	if IsObjectOnFieldEffectBuffAffector(owner, { mastery.Buff.name, mastery.SubBuff.name }, true) then
		mastery.DuplicateApplyChecker = 1;
	else
		mastery.DuplicateApplyChecker = 0;
	end
end
-- 하늘 위의 사냥꾼
function Mastery_OntheSkyHunter_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local prevPos = GetAbilityUsingPosition(owner);
	SetInstantProperty(owner, 'OntheSkyHunter', prevPos);
end
-- 외로운 싸움꾼
function Mastery_LonelyFighter_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	
	-- 특성 외토리늑대. 6칸 안에 아군 유닛이 없으면 명중률이 상승
	local targetList = GetTargetInRangeSightReposition(SafeIndex(eventArg.Ability, 'AbilityWithMove'), owner, mastery.Range, 'Team', true);
	if #targetList > 0 then
		return;
	end
	
	local actions = {};
	local action, reasons = GetApplyActAction(owner, -mastery.ApplyAmount, nil, 'Friendly');
	if action then
		table.insert(actions, action);
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -mastery.ApplyAmount });
	end
	ReasonToUpdateBattleEventMulti(target, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	
	return unpack(actions);
end
-- 기선 제압
function GetMeleeAbilityUseAction(user, target, resultModifier, directingConfig)
	local overwatchAbility = FindAbility(user, user.OverwatchAbility);
	if not overwatchAbility or overwatchAbility.HitRateType ~= 'Melee' then
		return false;
	end
	local userPos = GetPosition(user);
	local usingPos = GetPosition(target);
	if not IsMeleeDistance(userPos, usingPos) then
		return false;
	end
	local range = CalculateRange(user, overwatchAbility.TargetRange, userPos);
	local canHit = PositionInRange(range, usingPos);
	
	if not canHit then
		return false;
	end
	
	local abilityAction = Result_UseAbility(user, user.OverwatchAbility, usingPos, resultModifier, true, directingConfig);
	abilityAction.free_action = true;
	abilityAction.final_useable_checker = function()
		return GetBuffStatus(user, 'Attackable', 'And')
			and PositionInRange(CalculateRange(user, overwatchAbility.TargetRange, GetPosition(user)), usingPos)
	end;
	return true, abilityAction;
end
function Mastery_Forestallment_PreAbilityUsing(eventArg, mastery, owner, ds)
	if GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or mastery.DuplicateApplyChecker > 0
		or eventArg.Ability.Type ~= 'Attack' 
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetInstantProperty(owner, 'Undead')
		or owner.IsMovingNow > 0 then
		return;
	end

	local target = eventArg.Unit;
	local battleEvents = {{Object = owner, EventType = mastery.name}};
	local resultModifier = {ReactionAbility = true, Forestallment=true, BattleEvents = battleEvents};
	local directingConfig = table.deepcopy(eventArg.DirectingConfig);
	directingConfig.MessageVisible = true;
	
	-- 선의 선
	local mastery_AcuityForestallment = GetMasteryMastered(GetMastery(owner), 'AcuityForestallment');
	if mastery_AcuityForestallment then
		resultModifier['Inevitable'] = true;
		resultModifier['AttackerState'] = 'Critical';
		resultModifier['DefenderState'] = 'Hit';
	end	
	
	local success, action = GetMeleeAbilityUseAction(owner, target, resultModifier, directingConfig);
	if not success then
		return;
	end
	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'PreAbilityUsing'});
	return action;
end
-- 자동 제압 사격
function Mastery_Module_ForestallmentFire_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or mastery.DuplicateApplyChecker > 0
		or eventArg.Ability.Type ~= 'Attack' 
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not IsMeleeDistance(GetPosition(owner), GetPosition(eventArg.Unit))
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or owner.IsMovingNow > 0 then
		return;
	end
	local actions = {};
	if owner.Cost < mastery.ApplyAmount3 then
		return;
	end
	local alreadyHitSet = GetInstantProperty(owner, mastery.name) or {};
	if alreadyHitSet[GetObjKey(eventArg.Unit)] then
		return;
	end	
	local overwatch = FindAbility(owner, owner.OverwatchAbility);
	if overwatch == nil then
		return false;
	end
	local rangeClsList = GetClassList('Range');
	local range = CalculateRange(owner, overwatch.TargetRange, GetPosition(owner));
	local p = GetPosition(eventArg.Unit);
	if not PositionInRange(range, p) then
		return false;
	end
	alreadyHitSet[GetObjKey(eventArg.Unit)] = true;
	SetInstantProperty(owner, mastery.name, alreadyHitSet);
	
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedCustomEvent', Args = {Mastery = mastery.name, EventType = 'Beginning', MissionChat = true} });
	-- Cost 증가
	local applyAct = mastery.ApplyAmount2;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	if action then
		ds:WorldAction(action, true);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	-- 어빌리티 사용
	local targetPos = GetPosition(eventArg.Unit);
	local abilityAction = Result_UseAbilityTarget(owner, owner.OverwatchAbility, eventArg.Unit, {ReactionAbility=true, CloseCheckFire=true, BattleEvents = battleEvents, InvokeMastery = mastery.name}, true, {NoCamera = true});
	abilityAction.free_action = true;
	abilityAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, overwatch.TargetRange, GetPosition(owner)), targetPos);
	end;
	table.insert(actions, abilityAction);
	
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount3, true, nil, ds);
	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
-- 방랑자
function Mastery_Wanderer_PreAbilityUsing(eventArg, mastery, owner, ds)
	return Result_UpdateInstantProperty(owner, 'WandererActive', false);
end
-- 특성 기적
function Mastery_Miracle_PreAbilityUsing(eventArg, mastery, owner, ds)
	if (eventArg.Ability.Type ~= 'Heal' and eventArg.Ability.Type ~= 'Assist')
		or (eventArg.Ability.Type == 'Assist' and eventArg.Ability.Cost <= 0)
		or eventArg.Ability.ItemAbility	then
		return;
	end
	local applyAmount = mastery.ApplyAmount;
	local masteryTable = GetMastery(owner);
	-- 헌신적인 사랑
	local mastery_InfinityLove = GetMasteryMastered(masteryTable, 'InfinityLove');
	if mastery_InfinityLove then
		applyAmount = applyAmount + mastery_InfinityLove.ApplyAmount;
	end
	if not RandomTest(applyAmount) then
		SetInstantProperty(owner, 'Miracle', nil);
		return;
	end
	
	SetInstantProperty(owner, 'Miracle', true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'PreAbilityUsing'});	
	ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name });
end
-- 재소탕
function Mastery_Resweeping_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.HitRateType ~= 'Force'
		or eventArg.Ability.SubType ~= 'Piercing' then
		return;
	end
	local targetList = nil;
	if IsStableAttack(owner) then
		local targetPos = eventArg.PositionList[#(eventArg.PositionList)];
		local applyTargets = table.filter(BuildApplyTargetInfos(owner, eventArg.Ability, targetPos), function(info)
			return info.Object and IsEnemy(owner, info.Object);
		end);
		if #applyTargets >= mastery.ApplyAmount2 then
			targetList = table.map(applyTargets, function(info) return GetObjKey(info.Object) end);
		end
	end
	SetInstantProperty(owner, mastery.name, targetList);
end
-- 연환계
function Mastery_ChainTactics_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	SubscribeWorldEvent(owner, 'ActionDelimiter', function(eventArg, ds, subscriptionID)
		UnsubscribeWorldEvent(owner, subscriptionID);
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
	end);
end
-- 사냥꾼과 사냥개
function Mastery_HunterAndHuntingDog_PreAbilityUsing(eventArg, mastery, owner, ds)
	if GetInstantProperty(eventArg.Unit, 'SummonMaster') ~= GetObjKey(owner) then
		return;
	end
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	mastery.CountChecker = 0;
	SubscribeWorldEvent(owner, 'ActionDelimiter', function(eventArg, ds, subscriptionID)
		UnsubscribeWorldEvent(owner, subscriptionID);
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
	end);
end
-- 최상위 포식자
function Mastery_ApaxPredator_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	SetInstantProperty(owner, mastery.name, owner.HP);
end
-- 나는 히어로 아이린이다!
function Mastery_ImHeroIrene_PreAbilityUsing(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	SetInstantProperty(owner, mastery.name, HasBuff(owner, mastery.SubBuff.name));
	mastery.DuplicateApplyChecker = 0;
end
-- 낚시왕
function Mastery_KingOfFishing_PreAbilityUsing(eventArg, mastery, owner, ds)
	if HasBuff(owner, 'ClimbWeb') then
		mastery.DuplicateApplyChecker = 1;
	else
		mastery.DuplicateApplyChecker = 0;
	end
end
------------------------------------------------------------------------------------
-- 적에게 피해를 받을때 [UnitTakeDamage]
--------------------------------------------------------------------------------------
-- 해골 인장
function Mastery_Amulet_Scourge_UnitTakeDamage(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	local abilityName = 'Potion_Scourge';
	
	local ability = FindAbility(owner, abilityName);
	ability.UseCount = ability.UseCount - mastery.CountChecker;
	mastery.CountChecker = 0;
	
	return Result_SynchronizeAbility(owner, abilityName);
end
-- 동족 포식
function Mastery_Cannibalization_UnitTakeDamage(eventArg, mastery, owner, ds)
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability'
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'System' then
		-- 어빌리티에 의한 데미지는 여기서 처리안함 AbilityAffected를 보기
		return;
	end
	
	local invoker = owner;
	if SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Buff' then
		invoker = GetExpTaker(SafeIndex(eventArg, 'DamageInfo', 'damage_invoker'));
	end
	
	return Mastery_Cannibalization_Test(mastery, owner, ds, invoker);
end
-- 야수 AI위협도 관련
function Buff_Beast_Loyalty_UnitTakeDamage(eventArg, mastery, owner, ds)
	local master = GetUnit(owner, GetInstantProperty(owner, 'SummonMaster'));
	if master ~= eventArg.Giver and master ~= eventArg.Receiver then
		return;
	end
	
	local aggroTarget = nil;
	local aggroAmount = 0;
	if master == eventArg.Giver then
		aggroTarget = eventArg.Receiver;
		aggroAmount = 10;
	else
		aggroTarget = eventArg.Giver;
		aggroAmount = 20;
	end
	AddHate(owner, aggroTarget, aggroAmount);
end
-- 빗물통
function Mastery_RainBarrel_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage < owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end
	
	local restoreAmount = eventArg.Damage * mastery.ApplyAmount2 / 100;
	local actions = {};
	AddActionCost(actions, owner, restoreAmount, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage');
	-- 안개비
	local mastery_Smir = GetMasteryMastered(GetMastery(owner), 'Smir');
	if mastery_Smir then
		AddSPPropertyActions(actions, owner, 'Water', mastery_Smir.ApplyAmount, true, ds, true);
	end
	return unpack(actions);
end
-- 야수 친구
function Mastery_BeastFriend_UnitTakeDamage(eventArg, mastery, owner, ds)
	local beast = SafeIndex(GetInstantProperty(owner, 'SummonBeast'), 'Target');
	if eventArg.Giver ~= eventArg.Receiver 
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Copy'
		or SafeIndex(eventArg, 'DamageInfo', 'damage_type') == 'Ability'
		or (eventArg.Damage >= 0 and SafeIndex(eventArg, 'DamageInfo', 'damage_type') ~= 'Heal')
		or not beast
		or (eventArg.Receiver ~= owner and eventArg.Receiver ~= beast) then
		return;
	end
	
	local target = nil;
	local giver = nil;
	if eventArg.Receiver == owner then
		target = beast;
		giver = owner;
	else
		target = owner;
		giver = beast;
	end
	local actions = {};
	local addHP = math.floor(-eventArg.Damage * mastery.ApplyAmount / 100);
	local reasons = AddActionRestoreHP(actions, giver, target, addHP, 'Copy');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage');
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	if addHP > 0 then
		DirectDamageByType(ds, target, 'Heal', -addHP, math.min(target.HP + addHP, target.MaxHP), false, false);
	end
	
	-- 괴수 사냥꾼
	local mastery_MonsterHunter = GetMasteryMastered(GetMastery(owner), 'MonsterHunter');
	if mastery_MonsterHunter then
		AddActionApplyActForDS(actions, owner, -mastery_MonsterHunter.ApplyAmount, ds, 'Friendly');
		AddActionApplyActForDS(actions, beast, -mastery_MonsterHunter.ApplyAmount, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_MonsterHunter, owner, 'UnitTakeDamage');
	end
	return unpack(actions);
end
-- 사냥꾼 인장
function Mastery_Amulet_Hunter_UnitTakeDamage(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker ~= 1 then
		return;
	end
	
	mastery.DuplicateApplyChecker = 2;
	return Result_RemoveBuff(owner, mastery.Buff.name);
end
-- 물러서지 않는 자 - 5 세트
function Mastery_DrakyGuardianSet5_UnitTakeDamage(eventArg, mastery, owner, ds)
	local damageInfo = eventArg.DamageInfo;
	if damageInfo and damageInfo.damage_sub_type ~= 'Etc' then
		return Result_UpdateInstantProperty(owner, mastery.name, damageInfo.damage_sub_type);
	end
end
------------------------------------------------------------------------------------
-- 적에게 피해를 줄때. [UnitGiveDamage]
--------------------------------------------------------------------------------------
-- 추적하는 눈
function Mastery_ChaserEyes_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Receiver.HP > 0
		or (not eventArg.Receiver.PreBattleState and GetInstantProperty(eventArg.Receiver, 'AwakenRightBefore') == nil) then
		return;
	end
	local findObjectKey = GetObjKey(owner);
	
	local actions = {};
	local nearPreBattleAllies = Linq.new(GetAllUnitInSight(eventArg.Receiver, true))
		:where(function(o) return IsAllyOrTeam(eventArg.Receiver, o) and (o.PreBattleState or GetInstantProperty(o, 'AwakenRightBefore')) and o.HP > 0 and RandomTest(mastery.ApplyAmount) end)
		:toList();
		
	if #nearPreBattleAllies == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitGiveDamage_Self', true);
	ds:ChangeCameraTarget(GetObjKey(eventArg.Receiver), '_SYSTEM_', false);
	local alert = ds:AlertScreenEffect(findObjectKey);
	for _, ally in ipairs(nearPreBattleAllies) do
		local allyKey = GetObjKey(ally);
		ds:Connect(ds:LookAt(allyKey, findObjectKey), alert, 0);
		ds:Connect(ds:UpdateBalloonChat(allyKey, '!', 'Shout_Enemy'), alert, 0);
		table.append(actions, GetRemovePreBattleStateBuffActions(ally));
	end
	ds:Sleep(1);
	for _, ally in ipairs(nearPreBattleAllies) do
		InsertBuffActions(actions, owner, ally, mastery.Buff.name, 1, true);
	end
	return unpack(actions);
end
-- 특성 상처 감염
function Mastery_WoundInfection_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		if IsEnemy(owner, target) and targetInfo.MainDamage > 0 and target.HP > 0 and not applyTargets[targetKey] then
			local testBuffList = {};
			table.append(testBuffList, GetBuffType(target, 'Debuff', nil, 'Bleeding'));
			table.append(testBuffList, GetBuffType(target, 'Debuff', nil, 'Bruise'));
			testBuffList = table.filter(testBuffList, function(testBuff) return BuffIsActivated(testBuff) end);
			if #testBuffList > 0 then
				applyTargets[targetKey] = target;
			end
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	for targetKey, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed_Self'});
	
	-- 잔인한 검
	local masteryTable = GetMastery(owner);
	local mastery_CruelSword = GetMasteryMastered(masteryTable, 'CruelSword');
	if mastery_CruelSword then
		local applyAct = mastery_CruelSword.ApplyAmount;
		for targetKey, target in pairs(applyTargets) do
			local action, reasons = GetApplyActAction(target, applyAct, nil, 'Hostile');
			if action then
				table.insert(actions, action);
				ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
			else
				ReasonToUpdateBattleEventMulti(target, ds, reasons);
			end
		end
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_CruelSword.name, EventType = 'AbilityUsed_Self'});
	end
	return unpack(actions);
end
-- 신경 회로
function Mastery_NeuralCircuit_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or (eventArg.DamageInfo.damage_invoker and eventArg.DamageInfo.damage_invoker.SPFullAbility)
		or eventArg.DefenderState == 'Dodge'
		or eventArg.AttackerState ~= 'Critical' then
		return;
	end
	if not IsEnemy(eventArg.Giver, eventArg.Receiver) then
		return;
	end
	if eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Lightning', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name});
	return unpack(actions);
end
-- 특성 미풍
function Mastery_Breeze_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or (eventArg.DamageInfo.damage_invoker and eventArg.DamageInfo.damage_invoker.SPFullAbility) then
		return;
	end
	if not IsEnemy(eventArg.Giver, eventArg.Receiver) then
		return;
	end
	if eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	local target = eventArg.Receiver;
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Wind', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);	
end
-- 응급 치료
function Mastery_FirstAid_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner or eventArg.DamageInfo.damage_type ~= 'Ability' or eventArg.Damage > 0 or eventArg.DefenderState ~= 'Heal' then
		return;
	end
	local actions = {};
	local target = eventArg.Receiver;
	local objKey = GetObjKey(owner);
	
	local buffList = GetBuffType(target, 'Debuff', 'Physical');
	if #buffList == 0 then
		return;
	end
	for index, buff in ipairs (buffList) do
		InsertBuffActions(actions, owner, target, buff.name, -1 * buff.Lv, true);	
	end	
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	-- 정성어린 치료	
	local masteryTable = GetMastery(owner);
	local mastery_CarefulCure = GetMasteryMastered(masteryTable, 'CarefulCure');
	if mastery_CarefulCure then
		local addHP = math.floor(math.abs(eventArg.Damage) * mastery_CarefulCure.ApplyAmount2/100);
		local reasons = AddActionRestoreHP(actions, owner, target, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery_CarefulCure.name });
		DirectDamageByType(ds, target, 'HPRestore', -1 * addHP, math.min(target.HP + addHP, target.MaxHP), true, false); 
		AddMasteryDamageChat(ds, owner, mastery_CarefulCure, -1 * addHP);	
	end
	
	local mastery_GoodPotion = GetMasteryMastered(masteryTable, 'GoodPotion');
	if mastery_GoodPotion then
		local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
			:select(function(pair) return pair[1]; end)
			:toList();
		local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
		local goodBuff = goodBuffPicker:PickBuff();
		if goodBuff then
			InsertBuffActions(actions, owner, target, goodBuff, 1, true);
			MasteryActivatedHelper(ds, mastery_GoodPotion, owner, 'UnitGiveDamage_Self');
		end
	end
	return unpack(actions);
end
-- 정신 안정
function Mastery_MentalStability_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner or eventArg.DamageInfo.damage_type ~= 'Ability' or eventArg.Damage > 0 or eventArg.DefenderState ~= 'Heal' then
		return;
	end
	local actions = {};
	local target = eventArg.Receiver;
	local objKey = GetObjKey(owner);
	
	local buffList = GetBuffType(target, 'Debuff', 'Mental');
	if #buffList == 0 then
		return;
	end
	for index, buff in ipairs (buffList) do
		InsertBuffActions(actions, owner, target, buff.name, -1 * buff.Lv);	
	end	
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	-- 성자
	local masteryTable = GetMastery(owner);
	local mastery_Saint = GetMasteryMastered(masteryTable, 'Saint');
	if mastery_Saint then
		local addHP = math.floor(math.abs(eventArg.Damage) * mastery_Saint.ApplyAmount2/100);
		local reasons = AddActionRestoreHP(actions, owner, target, addHP);
		ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery_Saint.name });
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		DirectDamageByType(ds, target, 'HPRestore', -1 * addHP, math.min(target.HP + addHP, target.MaxHP), true, false);
		AddMasteryDamageChat(ds, owner, mastery_Saint, -1 * addHP);
	end
	return unpack(actions);
end
-- 치유의 물결.
function Mastery_HealingWave_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner
		or mastery.DuplicateApplyChecker > 0
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or not IsGetAbilitySubType(eventArg.DamageInfo.damage_invoker, 'ESP')
		or eventArg.DamageInfo.damage >= 0
		or eventArg.DamageInfo.remain_hp < eventArg.Receiver.MaxHP
		or eventArg.DefenderState ~= 'Heal' then
		return;
	end
	local actions = {};
	local applyAmount = mastery.ApplyAmount;
	-- 정성어린 치료	
	local masteryTable = GetMastery(owner);
	local mastery_CarefulCure = GetMasteryMastered(masteryTable, 'CarefulCure');
	if mastery_CarefulCure then
		applyAmount = applyAmount + mastery_CarefulCure.ApplyAmount;
	end
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	local added, reasons = AddActionApplyAct(actions, owner, owner, -applyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = -applyAmount });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_HealingWave_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
-- 특성 훔치기
function Mastery_Steal_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.HitRateType ~= 'Melee' then
		return;
	end
	local stealTargets = FindStealTargets(owner, eventArg, function(owner, target, targetInfo)
		return IsEnemy(owner, target) and targetInfo.DefenderState ~= 'Dodge';	
	end);
	if #stealTargets == 0 then
		return;
	end
	local stealTarget = table.shuffle(stealTargets)[1];
	local target = stealTarget.Target;
	local equipPosList = stealTarget.EquipPosList;
	local equipPos = table.shuffle(equipPosList)[1];
	
	local ownerMasteryTable = GetMastery(owner);
	local targetMasteryTable = GetMastery(target);
	local mastery_PhantomThief = GetMasteryMastered(ownerMasteryTable, 'PhantomThief');
	local mastery_ArseneLupin = GetMasteryMastered(ownerMasteryTable, 'ArseneLupin');
	local mastery_Sherlock = GetMasteryMastered(targetMasteryTable, 'Sherlock');
	local mastery_Detective = GetMasteryMastered(targetMasteryTable, 'Detective');

	local prob = mastery.ApplyAmount;
	if mastery_PhantomThief then
		prob = prob * mastery_PhantomThief.ApplyAmount;
	end

	if RandomTest(100 - prob) then
		return;
	end
	
	local isStealSuccess = true;
	if mastery_Sherlock or mastery_Detective then
		isStealSuccess = false;
	end
	
	local isPhantomThief = false;	
	if mastery_PhantomThief then
		isPhantomThief = true;
	end
	
	local actions = {};
	
	local ownerKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	
	local battleMessageID = ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	local lastActionID = battleMessageID;
	
	if isPhantomThief then
		local phantomThiefID = ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery_PhantomThief.name });
		ds:Connect(phantomThiefID, lastActionID, 0.2);
		lastActionID = phantomThiefID;
	end
	
	if isStealSuccess then
		lastActionID = ApplyStealActions(actions, ds, owner, target, equipPos, lastActionID, 1.5);
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	end
	
	if mastery_ArseneLupin then
		local lupinID = ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery_ArseneLupin.name });
		ds:Connect(lupinID, lastActionID, 1.0);
		lastActionID = lupinID;
		if isStealSuccess then
			InsertBuffActions(actions, owner, target, mastery_ArseneLupin.Buff.name, 1, true);
		end
	end
	
	if mastery_Sherlock then
		local sherlockID = ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery_Sherlock.name });
		ds:Connect(sherlockID, lastActionID, 1.0);
		lastActionID = sherlockID;
		if not isStealSuccess then
			InsertBuffActions(actions, target, owner, mastery_Sherlock.Buff.name, 1, true);
		end
	elseif mastery_Detective then
		local detectiveID = ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery_Detective.name });
		ds:Connect(detectiveID, lastActionID, 1.0);
		lastActionID = detectiveID;
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'AbilityUsed_Self'});
	if isPhantomThief then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery_PhantomThief.name, EventType = 'AbilityUsed_Self'});
	end
	if mastery_ArseneLupin then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery_ArseneLupin.name, EventType = 'AbilityUsed_Self'});
	end
	if mastery_Sherlock then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery_Sherlock.name, EventType = 'AbilityUsed_Self'});
	end
	if mastery_Detective then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery_Detective.name, EventType = 'AbilityUsed_Self'});
	end
	
	return unpack(actions);
end
-- 특성 강탈
function Mastery_Rob_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local stealTargets = FindStealTargets(owner, eventArg, function(owner, target, targetInfo)
		return IsEnemy(owner, target) and targetInfo.IsDead;
	end);
	if #stealTargets == 0 then
		return;
	end
	local stealTarget = table.shuffle(stealTargets)[1];
	local target = stealTarget.Target;
	local equipPosList = stealTarget.EquipPosList;
	local equipPos = table.shuffle(equipPosList)[1];

	local actions = {};
	
	local ownerKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	
	local battleMessageID = ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	local lastActionID = battleMessageID;
	
	lastActionID = ApplyStealActions(actions, ds, owner, target, equipPos, lastActionID, 1.5);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);

	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'AbilityUsed_Self'});
	
	return unpack(actions);
end
function FindStealTargets(owner, eventArg, checkFunc)
	local stealTargets = {};
	local stealTargetSet = {};
	local equipPosList = { 'Inventory1', 'Inventory2', 'GrenadeBag', 'AlchemyBag', 'DoubleGear', 'Module_AuxiliaryWeapon', 'Module_AssistEquipment' };
	
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		if stealTargetSet[targetKey] then
			return;
		end
		if checkFunc then
			if not checkFunc(owner, target, targetInfo) then
				return;
			end
		end
		local stealPosList = table.filter(equipPosList, function(equipPos)
			local item = target[equipPos];
			if item.name == nil then
				return false;
			end
			-- 소모성 아이템이 아니면 제외
			if not item.Consumable then
				return false;
			end
			-- 어빌리티의 사용 횟수 제한이 있는 아이템은, 사용 횟수가 남아있는 경우만 훔치는 대상이다.
			local ability = item.Ability;
			if ability.name ~= nil and ability.IsUseCount then
				if ability.UseCount <= 0 then
					return false;
				end
			end
			return true;
		end);
		if #stealPosList == 0 then
			return;
		end
		table.insert(stealTargets, { Target = target, EquipPosList = stealPosList });
		stealTargetSet[targetKey] = true;
	end);
	
	return stealTargets;
end
function ApplyStealActions(actions, ds, owner, target, equipPos, refID, refOffset)
	local item = target[equipPos];
	local itemName = item.name;

	local isUseCountItem = false;
	local isUsedItem = false;
	local itemUsedCount = 0;
	local newUseCount = 0;
	
	local ability = item.Ability;
	if ability.name ~= nil and ability.IsUseCount then
		isUseCountItem = true;
		itemUsedCount = ability.MaxUseCount - ability.UseCount;	
		if itemUsedCount > 0 then
			isUsedItem = true;
		end
		newUseCount = GetClassList('Ability')[ability.name].MaxUseCount - itemUsedCount;
	end

	table.insert(actions, Result_UnEquipItem(target, itemName, equipPos));
	local newEquipPos = GetAutoEquipmentPosition(owner, item, true);
	
	local ownerKey = GetObjKey(owner);
	local targetKey = GetObjKey(target);
	
	local isInstantEquip = false;
	if IsControllable(owner) then
		local playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
		local sleepID = ds:Sleep(3);
		local interactionID = ds:UpdateInteractionMessage(ownerKey, 'ItemAcqired', itemName);
		
		if refID then
			ds:Connect(interactionID, refID, refOffset);
		else
			ds:Connect(interactionID, ds:Sleep(0), -1);
		end
		ds:Connect(playSoundID, interactionID, 0.5);
		ds:Connect(sleepID, interactionID, 0);
		
		local enableEquip = IsEnableEquipItem(owner, item);
		local temporaryEquip = not item.Consumable and GetRosterFromObject(owner) == nil;
		local yielding = item.Consumable and GetRosterFromObject(owner) == nil;

		local mySlotIsEmpty = false;
		local curUseCount = nil;
		local discardWhenEquip = false;
		if newEquipPos ~= nil then
			local prevItem = owner[newEquipPos];
			if prevItem == nil or prevItem.name == nil or (prevItem.Ability.IsUseCount and prevItem.Ability.UseCount == 0) then
				mySlotIsEmpty = true;
			end
			if not mySlotIsEmpty then
				local ability = prevItem.Ability;
				if ability and ability.name ~= nil and ability.IsUseCount then
					curUseCount = ability.UseCount;
					local itemUsedCount = ability.MaxUseCount - ability.UseCount;	
					if itemUsedCount > 0 then
						discardWhenEquip = true;
					end
				end
			end
		end
		local dialogID, sel = ds:Dialog('InstantEquipDialog', {ObjKey = ownerKey, ItemType = itemName, EnableEquip = enableEquip, UsedItem = isUsedItem, MySlotIsEmpty = mySlotIsEmpty, IsTemporaryEquip = temporaryEquip, IsYielding = yielding, CurUseCount = curUseCount, NewUseCount = newUseCount, DiscardWhenEquip = discardWhenEquip, EquipPos = newEquipPos});
		if sel == 1 then	-- Yes
			isInstantEquip = true;
			if temporaryEquip then
				local giveItem = Result_GiveItem(owner, itemName, 1);
				table.insert(actions, giveItem);
			end
		elseif not isUsedItem then	-- 한번도 사용하지 않은 아이템을 훔친 경우만 획득한다.
			local giveItem = Result_GiveItem(owner, itemName, 1);
			local giveItemConverter = BuildGiveItemConverter(owner);
			table.append(actions, { giveItemConverter(giveItem) });
		end	
		
		refID = dialogID;
	else
		isInstantEquip = false;
	end
		
	if isInstantEquip then
		local equipItem = Result_EquipItem(owner, itemName, nil, newEquipPos);
		ds:WorldAction(equipItem, false, false);	-- 착용한 아이템의 UseCount를 조정하려면, 액션을 바로 적용해야 한다.
		
		if isUseCountItem then
			local newItem = owner[newEquipPos];
			local newAbility = newItem.Ability;
			local newUseCount = newAbility.MaxUseCount - itemUsedCount;
			
			UpdateAbilityPropertyActions(actions, owner, newAbility.name, 'UseCount', newUseCount);
		end
	end
	
	return refID;
end

function Mastery_Scribbles_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= 0 or eventArg.DamageInfo.damage_type ~= 'Ability' then
		return;
	end
	
	local actions = {};
	local buffList = table.filter(GetBuffList(eventArg.Receiver), function (buff)
		return buff.Type == 'Buff' and (buff.SubType == 'Physical' or buff.SubType == 'Mental');
	end);
	if #buffList == 0 then
		return;
	end
	for i, buff in ipairs(buffList) do
		InsertBuffActions(actions, owner, eventArg.Receiver, buff.name, -buff.Lv, true);
	end
	local masteryEventID = ds:UpdateBattleEvent(GetObjKey(eventArg.Receiver), 'MasteryInvoked', { Mastery = mastery.name, AliveOnly = true });
	ds:SetCommandLayer(masteryEventID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(masteryEventID);
	return unpack(actions);
end
function Mastery_BurnSoul_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		-- 생명체가 아니면 리턴.
		if not target.Race.Life then
			return;
		end
		if targetInfo.MainDamage > 0 and targetInfo.AttackerState == 'Critical' and target.HP > 0 then
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local masteryTable = GetMastery(owner);
	local mastery_SoulTaker = GetMasteryMastered(masteryTable, 'SoulTaker');
	local mastery_MagicControl = GetMasteryMastered(masteryTable, 'MagicControl');
	local burnAmount = mastery.ApplyAmount;
	if mastery_SoulTaker then
		burnAmount = burnAmount + mastery_SoulTaker.ApplyAmount;
	end
	if mastery_MagicControl then
		burnAmount = burnAmount + math.floor(burnAmount * mastery_MagicControl.ApplyAmount / 100);
	end

	local applyTargetList = {};
	for targetKey, target in pairs(applyTargets) do
		table.insert(applyTargetList, target);
	end
	local singleTarget = nil;
	if #applyTargetList == 1 then
		singleTarget = applyTargetList[1];
	end
	
	local actions = {};
	
	local masteryEventID = nil;
	if singleTarget then
		masteryEventID = ds:ChangeCameraTarget(GetObjKey(singleTarget), '_SYSTEM_', false);
	else
		masteryEventID = ds:Sleep(0);
	end
	ds:SetCommandLayer(masteryEventID, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(masteryEventID);
	ds:Connect(ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitGiveDamage'}), masteryEventID, -1);
	if mastery_MagicControl then
		ds:Connect(ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_MagicControl.name, EventType = 'UnitGiveDamage'}), masteryEventID, -1);
	end
	local totalBurnAmount = 0;
	for _, target in ipairs(applyTargetList) do
		local targetKey = GetObjKey(target);
		local afterCost, reasons = AddActionCost(actions, target, -burnAmount, true);
		local applyBurnAmount = target.Cost - afterCost;
		totalBurnAmount = totalBurnAmount + applyBurnAmount;
		ds:Connect(ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery.name, AliveOnly = true }), masteryEventID, -1);
		if mastery_MagicControl then
			ds:Connect(ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery_MagicControl.name, AliveOnly = true }), masteryEventID, -1);
		end
		if applyBurnAmount > 0 then
			ds:Connect(ds:UpdateBattleEvent(targetKey, 'AddCost', { CostType = target.CostType.name, Count = -applyBurnAmount }), masteryEventID, -1);
		end
		ReasonToUpdateBattleEventMulti(target, ds, reasons, masteryEventID, -1);
	end
	if singleTarget then
		ds:Connect(ds:ChangeCameraTarget(GetObjKey(singleTarget), '_SYSTEM_', false, false, 0.5), masteryEventID, -1); -- 슬립용
	end	

	if mastery_SoulTaker then
		local ownerKey = GetObjKey(owner);
		local afterCost, reasons = AddActionCost(actions, owner, totalBurnAmount, true);
		local addAmount = afterCost - owner.Cost;
		masteryEventID = ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false, 0.5);
		ds:Connect(ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_SoulTaker.name, EventType = 'UnitGiveDamage'}), masteryEventID, -1);
		ds:Connect(ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', {Mastery = mastery_SoulTaker.name, AliveOnly = true }), masteryEventID, -1);
		if addAmount > 0 then
			ds:Connect(ds:UpdateBattleEvent(ownerKey, 'AddCost', { CostType = owner.CostType.name, Count = addAmount }), masteryEventID, -1);
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons, masteryEventID, -1);
		ds:Connect(ds:ChangeCameraTarget(ownerKey, '_SYSTEM_', false, false, 0.5), masteryEventID, -1);
	end
	return unpack(actions);
end
-- 피의 갈증
function Mastery_Bloodthirst_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or eventArg.DefenderState == 'Dodge'
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	if not HasBuffType(eventArg.Receiver, nil, nil, mastery.BuffGroup.name) then
		return;
	end
	if not IsEnemy(eventArg.Giver, eventArg.Receiver) then
		return;
	end
	if eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWaitCustomEvent', {Time = -mastery.ApplyAmount, EventType = 'Ending'});
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitGiveDamage'});
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	return unpack(actions);
end
function Mastery_Bloodthirst_PreAbilityUsing(eventArg, mastery, owner, ds)
	mastery.DuplicateApplyChecker = 0;
end
-- 생기 흡수
function Mastery_BloodSucker_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyDamage = 0;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if HasBuffType(targetInfo.Target, nil, nil, 'Bleeding') and targetInfo.MainDamage > 0 then
			applyDamage = applyDamage + math.max(0, (targetInfo.PrevHP - targetInfo.RemainHP));
		end
	end);
	if applyDamage <= 0 then
		return;
	end	
	local applyAmountRatio = 100;
	local masteryTable = GetMastery(owner);
	-- 선혈의 기억
	local mastery_LegendOfDracula = GetMasteryMastered(masteryTable, 'LegendOfDracula');
	if mastery_LegendOfDracula then
		applyAmountRatio = applyAmountRatio + mastery_LegendOfDracula.ApplyAmount;
	end
	-- 검귀
	local mastery_GhostSword = GetMasteryMastered(masteryTable, 'GhostSword');
	if mastery_GhostSword then
		applyAmountRatio = applyAmountRatio + mastery_GhostSword.ApplyAmount;
	end
	local applyAmount = mastery.ApplyAmount * applyAmountRatio / 100;
	
	local mastery_BloodWitch = GetMasteryMastered(masteryTable, 'BloodWitch');
	if mastery_BloodWitch then
		mastery_BloodWitch.BloodSucker = math.floor(applyDamage * mastery_BloodWitch.ApplyAmount / 100);
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	local playAniID = ds:PlayAni(objKey, 'AstdIdle', false, -1, true);
	
	local addHP = math.floor(applyDamage * applyAmount / 100);	
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	DirectDamageByType(ds, owner, 'BloodSucker', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false, playAniID, 0.75);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitGiveDamage_Self'});
	if mastery_LegendOfDracula then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_LegendOfDracula.name, EventType = 'UnitGiveDamage_Self'});
	end
	AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	-- 얼어붙은 마지막 생명의 불꽃
	local mastery_FrozenLastLifeFlame = GetMasteryMastered(masteryTable, 'FrozenLastLifeFlame');
	if mastery_FrozenLastLifeFlame then
		local removeBuff = GetBuff(owner, mastery_FrozenLastLifeFlame.SubBuff.name);
		if removeBuff and removeBuff.Lv > 0 then
			MasteryActivatedHelper(ds, mastery_FrozenLastLifeFlame, owner, 'AbilityUsed_Self');
			local removeBuffLv = math.min(removeBuff.Lv, mastery_FrozenLastLifeFlame.ApplyAmount);
			InsertBuffActions(actions, owner, owner, removeBuff.name, -1 * removeBuffLv, true);
		end
	end
	return unpack(actions);
end
-- 재생의 불꽃
function Mastery_FlameRegenerator_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' or eventArg.Ability.SubType ~= 'Fire' then
		return;
	end
	local applyDamage = 0;
	local hasDeadTarget = false;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if HasBuffType(targetInfo.Target, nil, nil, mastery.BuffGroup.name) and targetInfo.MainDamage > 0 then
			applyDamage = applyDamage + math.max(0, (targetInfo.PrevHP - targetInfo.RemainHP));
			if targetInfo.IsDead then
				hasDeadTarget = true;
			end
		end
	end);
	if applyDamage <= 0 then
		return;
	end	
	local applyAmountRatio = 100;
	local masteryTable = GetMastery(owner);
	local applyAmount = mastery.ApplyAmount * applyAmountRatio / 100;
	-- 초열
	local mastery_Gehenna = GetMasteryMastered(masteryTable, 'Gehenna');
	if mastery_Gehenna then
		applyAmount = applyAmount + (applyAmount * mastery_Gehenna.ApplyAmount2 / 100);
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	local playAniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
	
	local addHP = math.floor(applyDamage * applyAmount / 100);	
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	if owner.HP < owner.MaxHP then
		DirectDamageByType(ds, owner, 'FlameRegenerator', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false, playAniID, 1.0);
	end
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	-- 복수의 불꽃
	local mastery_RevengeFlame = GetMasteryMastered(masteryTable, 'RevengeFlame');
	if mastery_RevengeFlame and hasDeadTarget and not owner.TurnState.TurnEnded then
		AddActionRestoreActions(actions, owner);
		MasteryActivatedHelper(ds, mastery_RevengeFlame, owner, 'AbilityUsed_Self');
	end
	return unpack(actions);
end
function Mastery_BloodSword_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local restoreAmount = 0;
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.Target.Race.name == 'Machine' or targetInfo.Target.Obstacle or targetInfo.MainDamage <= 0 or targetInfo.MainDamage < targetInfo.Target.MaxHP * mastery.ApplyAmount / 100 then
			return;
		end
		local applyRatio = mastery.ApplyAmount2 / 100;
		if HasBuffType(targetInfo.Target, nil, nil, mastery.BuffGroup.name) or targetInfo.IsDead then
			applyRatio = applyRatio * 2;
		end
		restoreAmount = math.max(0, (targetInfo.PrevHP - targetInfo.RemainHP)) * applyRatio;
	end);
	if restoreAmount <= 0 then
		return;
	end	
	local masteryTable = GetMastery(owner);
	local mastery_LegendOfDracula = GetMasteryMastered(masteryTable, 'LegendOfDracula');
	if mastery_LegendOfDracula then
		restoreAmount = restoreAmount * (1 + mastery_LegendOfDracula.ApplyAmount / 100);
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	local playAniID = ds:PlayAni(objKey, 'AstdIdle', false, -1, true);
	
	local addHP = math.floor(restoreAmount);
	local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	if owner.HP < owner.MaxHP then
		DirectDamageByType(ds, owner, 'BloodSword', -addHP, math.min(owner.MaxHP, owner.HP + addHP), true, false, playAniID, 1.0);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitGiveDamage_Self'});
	if mastery_LegendOfDracula then
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery_LegendOfDracula.name, EventType = 'UnitGiveDamage_Self'});
	end
	AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	return unpack(actions);
end
-- 점액 뿌리기
function Mastery_SprayMucus_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyAmount = mastery.ApplyAmount;
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if targetInfo.MainDamage > 0 and targetInfo.AttackerState == 'Critical' and target.HP > 0 then
			local buffList = GetBuffType(target, 'Buff');
			if #buffList > 0 then
				local targetKey = GetObjKey(target);
				local applyInfo = applyTargets[targetKey];			
				if not applyInfo then
					applyInfo = { Target = target, Count = applyAmount, BuffList = buffList };
				else
					applyInfo.Count = applyInfo.Count + applyAmount;
				end
				applyTargets[targetKey] = applyInfo;
			end
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	local removeBuffTotalList = {};
	for targetKey, applyInfo in pairs(applyTargets) do
		local target = applyInfo.Target;
		local count = applyInfo.Count;
		local buffList = applyInfo.BuffList;
	
		local picker = RandomPicker.new(false);
		for _, buff in ipairs(buffList) do
			picker:addChoice(1, buff);
		end
		local removeBuffList = picker:pickMulti(count);
		local masteryEventID = ds:UpdateBattleEvent(targetKey, 'MasteryInvoked', { Mastery = mastery.name, AliveOnly = true });
		ds:SetCommandLayer(masteryEventID, game.DirectingCommand.CM_SECONDARY);
		ds:SetContinueOnNormalEmpty(masteryEventID);
		for i, buff in ipairs(removeBuffList) do
			table.insert(actions, Result_RemoveBuff(target, buff.name, true));
			ds:UpdateBattleEvent(targetKey, 'BuffDischarged', { Buff = buff.name });
		end
		table.append(removeBuffTotalList, removeBuffList);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityUsed'});
	-- 점액 분비
	local mastery_SecretionOfMucus = GetMasteryMastered(GetMastery(owner), 'SecretionOfMucus');	
	if mastery_SecretionOfMucus and #removeBuffTotalList > 0 then
		MasteryActivatedHelper(ds, mastery_SecretionOfMucus, owner, 'AbilityUsed_Self');
		for _, buff in ipairs(removeBuffTotalList) do
			InsertBuffActions(actions, owner, owner, buff.name, 1, true);
		end
	end
	return unpack(actions);
end
-- 풍화
function Mastery_Weathered_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if not target.ESP or not target.ESP.name then
			return;
		end
		if targetInfo.MainDamage > 0 and targetInfo.AttackerState == 'Critical' and target.HP > 0 then
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);
	local applyAmount = -1 * mastery.ApplyAmount;
	for _, target in pairs(applyTargets) do
		AddSPPropertyActionsObject(actions, target, applyAmount, true, ds, true);
	end
	
	local mastery_SandCastle = GetMasteryMastered(GetMastery(owner), 'SandCastle');
	if mastery_SandCastle and owner.ESP.name == 'Earth' then
		MasteryActivatedHelper(ds, mastery_SandCastle, owner, 'AbilityUsed_Self');
		AddSPPropertyActionsObject(actions, owner, mastery_SandCastle.ApplyAmount2, true, ds, true);
	end
	return unpack(actions);
end
-- 맹장의 기백
function Mastery_GeneralSpirit_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if not target.ESP or not target.ESP.name then
			return;
		end
		if target.Lv >= owner.Lv then
			return;
		end
		if targetInfo.MainDamage > 0 and targetInfo.AttackerState == 'Critical' and target.HP > 0 then
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);
	local applyAmount = -1 * mastery.ApplyAmount;
	for _, target in pairs(applyTargets) do
		AddSPPropertyActionsObject(actions, target, applyAmount, true, ds, true);
	end
	return unpack(actions);
end
-- 혼란 일으키는 특성 전략 계열
-- 화공, 뇌공
function Mastery_ConfusionTactics_PreAbilityUsing(eventArg, mastery, owner, ds)
	local isTestAbility = false;
	local ability = eventArg.Ability;
	if ability.Type == 'Attack' and GetWithoutError(ability.ApplyFieldEffects, 'Fake') == nil then
		for _, info in ipairs(ability.ApplyFieldEffects) do
			if info.Method == 'Add' and info.Type == mastery.FieldEffect.name then
				isTestAbility = true;
				break;
			end		
		end
	end
	if isTestAbility then
		mastery.DuplicateApplyChecker = 1;
	else
		mastery.DuplicateApplyChecker = 0;
	end
end
function Mastery_ConfusionTactics_AbilityUsed(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker < 0 then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
	local candidates = GetInstantProperty(owner, mastery.name) or {};
	if table.empty(candidates) then
		return;
	end
	
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);	
		if IsEnemy(owner, target) and candidates[targetKey] then
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	for _, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	end
	-- 연계된 화공, 연계된 뇌공
	local setMasteryName = nil;
	if mastery.name == 'FireTactics' then
		setMasteryName = 'ChainFireTactics';
	elseif mastery.name == 'LightningTactics' then
		setMasteryName = 'ChainLightningTactics';
	end
	if setMasteryName then
		local setMastery = GetMasteryMastered(GetMastery(owner), setMasteryName);
		if setMastery then
			MasteryActivatedHelper(ds, setMastery, owner, 'BuffAdded');
			AddActionApplyActForDS(actions, owner, -setMastery.ApplyAmount, ds, 'Friendly');
			for _, obj in ipairs(GetNearObject(owner, setMastery.ApplyAmount3 + 0.4)) do
				if IsTeamOrAlly(owner, obj) then
					AddActionApplyActForDS(actions, obj, -setMastery.ApplyAmount, ds, 'Friendly');
				end
			end
		end
	end
	return unpack(actions);
end
-- 사기충천
function Mastery_MoraleBoosting_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	if not hasAnyDead then
		return;
	end
	local curRange = mastery.Range;
	local masteryTable = GetMastery(owner);
	local mastery_GeneralSpirit = GetMasteryMastered(masteryTable, 'GeneralSpirit');
	if mastery_GeneralSpirit then
		curRange = mastery_GeneralSpirit.Range;
	end	
	local targetRange = CalculateRange(owner, curRange, GetPosition(owner));
	local targetObjects = BuffHelper.GetObjectsInRange(GetMission(owner), targetRange, function(target)
		return GetRelation(owner, target) == 'Team';
	end);
	if #targetObjects == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self', true);	
	for _, target in ipairs(targetObjects) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1);
	end
	return unpack(actions);
end
-- 독의 고통
function Mastery_VenomPain_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if IsEnemy(owner, target) and HasBuffType(target, nil, nil, 'Poison') and targetInfo.AttackerState == 'Critical' and targetInfo.MainDamage > 0 then
			applyTargets[GetObjKey(target)] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	local applyAct = mastery.ApplyAmount;
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	for targetKey, target in pairs(applyTargets) do
		local added, reasons = AddActionApplyAct(actions, owner, target, applyAct, 'Hostile');
		if added then
			ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
	end
	return unpack(actions);
end
-- 소각
function Mastery_Incineration_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.SubType ~= 'Fire' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		local targetKey = GetObjKey(target);
		if targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and not applyTargets[targetKey] then
			local buffList = GetBuffType(target, 'Buff');
			if #buffList > 0 then
				applyTargets[targetKey] = { Target = target, BuffList = buffList };
			end
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	local removeBuffCount = 0;
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	for targetKey, info in pairs(applyTargets) do
		local target = info.Target;
		local buffList = info.BuffList;
		local picker = RandomPicker.new(false);
		for _, buff in ipairs(buffList) do
			picker:addChoice(1, buff);
		end
		local removeBuffList = picker:pickMulti(mastery.ApplyAmount);
		for _, buff in ipairs(removeBuffList) do
			table.insert(actions, Result_RemoveBuff(target, buff.name, true));
			ds:UpdateBattleEvent(targetKey, 'BuffDischarged', { Buff = buff.name });
			removeBuffCount = removeBuffCount + 1;
		end
	end
	-- 업화
	local mastery_Hellfire = GetMasteryMastered(GetMastery(owner), 'Hellfire');
	if mastery_Hellfire and removeBuffCount > 0 then
		MasteryActivatedHelper(ds, mastery_Hellfire, owner, 'AbilityUsed_Self');
		local addHP = math.max(1, math.floor(owner.MaxHP * mastery_Hellfire.ApplyAmount/100));
		MasteryDamageHelper(ds, mastery, owner, -1 * addHP);
		local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		if owner.HP < owner.MaxHP then
			DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false);
		end
	end
	return unpack(actions);
end
-- 고전압
function Mastery_HighVoltage_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.SubType ~= 'Lightning' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		local target = targetInfo.Target;
		if IsEnemy(owner, target) and targetInfo.MainDamage >= target.MaxHP * mastery.ApplyAmount / 100 then
			applyTargets[GetObjKey(target)] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	local actions = {};
	local applyAct = mastery.ApplyAmount;
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	for _, target in pairs(applyTargets) do
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	end
	return unpack(actions);
end
-- 넌 이미 죽어있다.
function Mastery_AlreadyYoudie_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	if not hasAnyDead then
		return;
	end
	local actions = {};
	local applyAct = -1 * mastery.ApplyAmount2;
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 그림자 저격수
function Mastery_SniperInShadow_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or eventArg.Ability.SubType ~= 'Piercing'
		or owner.ExposedByEnemy then
		return;
	end
	local hasAnyEnemy = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target);
	end);
	local hasAnyDead = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and targetInfo.IsDead;
	end);
	-- 하나라도 죽거나, 적이 없으면 실패
	if hasAnyDead or not hasAnyEnemy then
		return;
	end	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed_Self');
	-- 턴 대기 시간 감소
	local applyAct = -1 * mastery.ApplyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	-- 어빌리티 재사용 대기 시간 감소
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount2, function (ability)
		return ability.Type == 'Attack' and ability.SubType == 'Piercing';
	end);
	return unpack(actions);
end
-- 배움의 기쁨
function Mastery_RoadOfStudies_AbilityUsed(eventArg, mastery, owner, ds)
	return Mastery_RoadOfStudies_FlushPrevExp(eventArg, mastery, owner, ds);
end
function Mastery_RoadOfStudies_FlushPrevExp(eventArg, mastery, owner, ds)
	local expInfo = GetInstantProperty(owner, mastery.name);
	if expInfo == nil then
		return;
	end
	SetInstantProperty(owner, mastery.name, nil);
	local nextExp = GetNextExp(owner.ExpType, expInfo.Lv);
	if expInfo.Exp < nextExp * mastery.ApplyAmount/100 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, eventArg.EventType);
	InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, true);
	return unpack(actions);
end
-- 헌신적인 사랑
function Mastery_InfinityLove_UnitGiveDamage(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner
		or eventArg.DamageInfo.damage_type ~= 'Ability'
		or not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'SupportHeal')
		or eventArg.DamageInfo.damage >= 0
		or eventArg.DamageInfo.remain_hp >= eventArg.Receiver.MaxHP
		or eventArg.DefenderState ~= 'Heal' then
		return;
	end
	local actions = {};
	local applyAct = -1 * mastery.ApplyAmount2;
	local ownerKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitGiveDamage');
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
------------------------------------------------------------------------------------
-- 어빌리티에 영향 받음. [AbilityAffected]
--------------------------------------------------------------------------------------
-- 촘촘한 비늘
function Mastery_DenseScale_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	
	return Result_UpdateInstantProperty(owner, 'DenseScale_LastDamageType', eventArg.Ability.SubType, true);
end
-- 동족 포식
function Mastery_Cannibalization_Test(mastery, owner, ds, invoker)
	if mastery.DuplicateApplyChecker <= 0
		or mastery.CountChecker > 0 then
		return;
	end
	mastery.CountChecker = 1;
	local abilities = {FindMoveAbility(owner), FindAbility(owner, owner.OverwatchAbility)};
	local aiConfig = {};
	local aiArgs = {};
	aiConfig.NoIndirect = true;
	aiConfig.FullMove = true;
	aiConfig.RecognizeFilter = function(obj)
		-- 동족 체크
		if owner.Job.name ~= obj.Job.name then
			return false;
		end
		local beastTypeCls = GetBeastTypeClassFromObject(obj);
		if beastTypeCls == nil then
			return false;
		end
		-- 레벨 체크
		if owner.Lv <= obj.Lv then
			return false;
		end
		-- 성장기 이상
		return beastTypeCls.EvolutionType[beastTypeCls.EvolutionStage].Level >= 1;
	end;
	local prevLoseIFF = ObjectLoseIFF(owner);
	SetObjectLoseIFF(owner, true);
	local pos, score, _ = FindAIMovePosition(owner, abilities, function(self, adb, args)
		if not adb.Attackable then
			return -199;
		end
		return 1000 - adb.MoveDistance * 5 - adb.MinEnemyDistance * 30;
	end, aiConfig, aiArgs);
	SetObjectLoseIFF(owner, prevLoseIFF);
	if pos == nil then
		return Mastery_Cannibalization_Failed(mastery, owner, ds);
	end
	
	SetInstantProperty(owner, 'Cannibalization_Invoker', invoker);
	local objKey = GetObjKey(owner);
	ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ds:Sleep(0.5);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:Move(objKey, pos);
	return Result_DirectingScript(function(mid, ds, args)
		if IsDead(owner) then
			mastery.DuplicateApplyChecker = 0;
			mastery.CountChecker = 0;
			return;
		end
		local prevLoseIFF = ObjectLoseIFF(owner);
		SetObjectLoseIFF(owner, true);
		local abil, pos = FindAIMainAction(owner, abilities, {{Strategy = function(self, adb, args)
			return 100 - adb.Distance - adb.Ability.Cost;
		end, Target = 'Attack'}}, aiConfig, aiArgs);
		SetObjectLoseIFF(owner, prevLoseIFF);
		local target = GetObjectByPosition(mid, pos);
		
		if abil == nil or target == nil then
			return Mastery_Cannibalization_Failed(mastery, owner, ds);
		end
		local directingConfig = {};
		directingConfig.NoCamera = true;
		directingConfig.NoMarker = true;
		directingConfig.NoVoice = true;
		directingConfig.NoDamageShow = true;
		directingConfig.Skipable = true;
		local battleEvents = {};
		--table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedCustomEvent', Args = {Mastery = mastery.name, EventType = 'Beginning', MissionChat = true} });
		return Result_UseAbility(owner, abil.name, pos, {ReactionAbility = true, DamageAdjust = 'Use', Damage = target.MaxHP, Cannibalization = true, BattleEvents = battleEvents}, true, directingConfig, nil, true);
	end, nil, true, true);
end
function Mastery_Cannibalization_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Cannibalization_Test(mastery, owner, ds, eventArg.User);
end
-- 자동 회피 반응
function Mastery_Module_LightningReflexes_AbilityAffected(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	
	local consumeCost = mastery.DuplicateApplyChecker * mastery.ApplyAmount;
	local actions = {};
	AddActionCostForDS(actions, owner, -consumeCost, true, nil, ds);
	mastery.DuplicateApplyChecker = 0;
	return unpack(actions);
end
-- 폭주(기계)
function Mastery_Module_MachineFury_AbilityAffected(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker ~= 1 then
		return;
	end
	
	mastery.DuplicateApplyChecker = 2;	
	local actions = {};
	-- 폭주 버프는 보상 처리를 위해 공격자가 걸어준 것으로 간주한다.
	InsertBuffActions(actions, eventArg.User, owner, mastery.Buff.name, 1, false, function(b)
		b.UseAddedMessage = false;	-- 데미지 컨베이어에서 가라로 메시지 띄움
	end, true);
	-- 자율 행동 강화 프로그램
	local mastery_Module_AutoAction = GetMasteryMastered(GetMastery(owner), 'Module_AutoAction');
	if mastery_Module_AutoAction then
		MasteryActivatedHelper(ds, mastery_Module_AutoAction, owner, 'AbilityAffected');
		table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
		if not owner.TurnState.TurnEnded then
			table.append(actions, {GetInitializeTurnActions(owner)});
		end
	end	
	return unpack(actions)
end
-- 생사의 갈림길
function Mastery_ThrillChaser_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not table.exist(eventArg.AbilityTargetInfos, function(targetInfo) return targetInfo.DefenderState == 'Dodge' end)
		or owner.HP > owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected', true);
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	return unpack(actions);
end
-- 제발 절 도와주세요!
function Mastery_HelpMePlease_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' 
		or not IsEnemy(owner, eventArg.User)
		or (GetBuff(owner, mastery.Buff.name) == nil and GetBuff(owner, 'Conceal_For_Aura') == nil) then
		return;
	end
	local dodgeCount = 0;
	ForeachAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		if targetInfo.DefenderState == 'Dodge' then
			dodgeCount = dodgeCount + 1;
		end
	end);
	
	if dodgeCount == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, GetMasteryMastered(GetMastery(owner), 'HideHide'), owner, 'AbilityAffected');
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	
	local actions = {};
	local addTime = - mastery.ApplyAmount * dodgeCount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, addTime, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', {Time = addTime, Delay = true});
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 굶주린 늑대
function Mastery_HungryWolf_AbilityAffected(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker ~= 1 then
		return;
	end
	
	mastery.DuplicateApplyChecker = 2;
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, false, function(b)
		b.UseAddedMessage = false;	-- 데미지 컨베이어에서 가라로 메시지 띄움
	end, true);
	return unpack(actions)
end
-- 운명에 맞서 싸운다
function Mastery_FightAgainstFate_AbilityAffected(eventArg, mastery, owner, ds)
	local needBuff = GetInstantProperty(owner, mastery.name);
	SetInstantProperty(owner, mastery.name, nil);
	if not needBuff then
		return;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, function(b)
		b.UseAddedMessage = false;	-- 데미지 컨베이어에서 가라로 메시지 띄움
	end, true);
	return unpack(actions);
end
-- 특수 장갑
function Mastery_Module_HardArmor_AbilityAffected(eventArg, mastery, owner, ds)
	local needCost = GetInstantProperty(owner, mastery.name);
	SetInstantProperty(owner, mastery.name, nil);
	if not needCost then
		return;
	end
	local actions = {};
	local addCost = -1 * mastery.ApplyAmount2;
	local _ reasons = AddActionCost(actions, owner, addCost, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 정의를 위한 승리의 검
-- 성검: 범죄 조직 소속인 적에게 피격 시, 턴 대기 시간이 10 감소합니다.
function Mastery_VictorySword_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.User.Affiliation.Type ~= 'Crime' then
		return;
	end
	if not HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState ~= 'Dodge';
	end) then
		return;
	end
	
	local actions = {};
	local applyAct = -mastery.ApplyAmount2;
	local action, reasons = GetApplyActAction(owner, -mastery.ApplyAmount2, nil, 'Friendly');
	if action then
		table.insert(actions, action);
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	return unpack(actions);
end
-- 반격류
function Mastery_CounterAction_AbilityAffected(eventArg, mastery, owner, ds, counterAbility, battleEventType)
	local range = CalculateRange(owner, counterAbility.TargetRange, GetPosition(owner));
	local targetPos = GetPosition(eventArg.User);
	if not PositionInRange(range, targetPos) then
		return;
	end
	
	if battleEventType == 'CounterAttack' then
		-- 반격 봉쇄
		local mastery_AntiCounterAttack  = GetMasteryMastered(GetMastery(eventArg.User), 'AntiCounterAttack');
		if mastery_AntiCounterAttack then
			ds:UpdateBattleEvent(GetObjKey(owner), 'CounterAttackBlocked');
			ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityAffected'});
			MasteryActivatedHelper(ds, mastery_AntiCounterAttack, eventArg.User, 'AbilityAffected');
			return;
		end
	end
	
	local resultModifier = { Counter = true };
	
	local masteryTable = GetMastery(owner);
	-- 살을 주고 뼈를 취한다.
	local mastery_Bonecrusher = GetMasteryMastered(masteryTable, 'Bonecrusher');
	if mastery_Bonecrusher then
		local hasNotDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
			return targetInfo.DefenderState ~= 'Dodge';
		end);
		if not hasNotDodge then
			resultModifier['Inevitable'] = true;
		else
			resultModifier['Inevitable'] = true;
			resultModifier['AttackerState'] = 'Critical';
			resultModifier['DefenderState'] = 'Hit';
		end
	end
	local damagePuff = 0;
	-- 보복
	local mastery_Revenge = GetMasteryMastered(masteryTable, 'Revenge');
	if mastery_Revenge then
		local hasNotDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
			return targetInfo.DefenderState ~= 'Dodge';
		end);
		if not hasNotDodge then
			damagePuff = damagePuff + mastery_Revenge.ApplyAmount;
		else
			damagePuff = damagePuff + mastery_Revenge.ApplyAmount2;
		end
	end
	-- 복수의 일격
	local mastery_RevengeStrikes = GetMasteryMastered(masteryTable, 'RevengeStrikes');
	if mastery_RevengeStrikes then
		damagePuff = damagePuff + mastery_RevengeStrikes.ApplyAmount;
	end
	resultModifier.DamagePuff = damagePuff;
	-- 차경
	local masteryInvoked_BorrowingEnergy = false;
	local masteryInvoked_MartialArtStaticMonement = false;
	local mastery_BorrowingEnergy = GetMasteryMastered(masteryTable, 'BorrowingEnergy');
	local mastery_MartialArtStaticMonement = GetMasteryMastered(masteryTable, 'MartialArtStaticMonement');
	if mastery_BorrowingEnergy then
		local addDamageTotal = 0;
		local applyAmount = mastery_BorrowingEnergy.ApplyAmount;
		local applyAmount2 = mastery_BorrowingEnergy.ApplyAmount2;
		-- 정중동
		if mastery_MartialArtStaticMonement then
			applyAmount2 = applyAmount2 + mastery_MartialArtStaticMonement.ApplyAmount2;		
		end
		ForeachAbilityUsingInfo({eventArg.AbilityTargetInfos}, function (targetInfo)
			local addDamage = 0;
			if targetInfo.DefenderState == 'Hit' then
				addDamage = math.floor(targetInfo.MainDamage * applyAmount / 100);
			elseif targetInfo.DefenderState == 'Block' then
				addDamage = math.floor(targetInfo.DamageBlocked * applyAmount2 / 100);
				if mastery_MartialArtStaticMonement and addDamage > 0 then
					masteryInvoked_MartialArtStaticMonement = true;
				end
			end
			addDamageTotal = addDamageTotal + addDamage;
		end);
		if addDamageTotal > 0 then
			resultModifier.DamagePuff_Add = addDamageTotal;
			masteryInvoked_BorrowingEnergy = true;
		end
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});	
	
	local actions = {};
	local applyAct = mastery.ApplyAmount;
	local action, reasons = GetApplyActAction(owner, applyAct, nil, 'Cost');
	local battleEvents = {};
	table.insert(battleEvents, { Object = owner, EventType = battleEventType });
	if action then
		table.insert(actions, action);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = applyAct } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	
	mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
	
	if mastery_Bonecrusher then
		table.insert(battleEvents, { Object = owner, EventType = 'Bonecrusher' });
	end
	if mastery_Revenge and resultModifier.DamagePuff then
		table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery_Revenge.name}});
	end
	if masteryInvoked_BorrowingEnergy then
		table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedCustomEvent', Args = {Mastery = mastery_BorrowingEnergy.name, EventType = 'Beginning', MissionChat = true}});
		if masteryInvoked_MartialArtStaticMonement then
			table.insert(battleEvents, { Object = owner, EventType = 'MasteryInvokedCustomEvent', Args = {Mastery = mastery_MartialArtStaticMonement.name, EventType = 'Beginning', MissionChat = true}});
		end		
	end
	resultModifier.BattleEvents = battleEvents;
	local cam = ds:ChangeCameraTargetingMode(GetObjKey(owner), GetObjKey(eventArg.User), '_SYSTEM_', false);
	local counterAttack = Result_UseAbility(owner, counterAbility.name, targetPos, resultModifier, true, {NoCamera = true});
	counterAttack.free_action = true;
	counterAttack.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, counterAbility.TargetRange, GetPosition(owner)), targetPos)
	end;
	counterAttack._ref = cam;
	counterAttack._ref_offset = 0.5;
	table.insert(actions, counterAttack);
	
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker - 1;
	end, nil, true, true));
	return unpack(actions);
end
-- 특성 반격
function Mastery_CounterAttack_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.User.HP <= 0
		or eventArg.User == owner
		or eventArg.Ability.Type ~= 'Attack'
		or mastery.DuplicateApplyChecker > 0 
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or GetInstantProperty(owner, 'Undead') then
		return;
	end
	
	local counterAbility = FindAbility(owner, owner.OverwatchAbility);
	if counterAbility == nil then
		-- 어빌리티가 존재하지만 비활성화된 경우에는 에러 로그를 남가지 않음
		if not FindAbility(owner, owner.OverwatchAbility, false) then
			LogAndPrint('[DataError]', 'No Ability for CounterAttack.', 'owner.OverwatchAbility:', owner.OverwatchAbility);
		end
		return;
	end
	if counterAbility.HitRateType ~= 'Melee' then
		return;
	end
	
	return Mastery_CounterAction_AbilityAffected(eventArg, mastery, owner, ds, counterAbility, 'CounterAttack');
end
function Mastery_CounterShoot_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.User.HP <= 0
		or eventArg.User == owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsLongDistanceAttack(eventArg.Ability)
		or mastery.DuplicateApplyChecker > 0 
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	
	local limit = 1;
	local mastery_ImNotDoneYet = GetMasteryMastered(GetMastery(owner), 'ImNotDoneYet');
	if mastery_ImNotDoneYet then
		limit = limit + mastery_ImNotDoneYet.ApplyAmount2;
	end
	if mastery.CountChecker >= limit then
		return;
	end
	
	if not HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end) then
		return;
	end
	
	local counterAbility = FindAbility(owner, owner.OverwatchAbility);
	if counterAbility == nil then
		-- 어빌리티가 존재하지만 비활성화된 경우에는 에러 로그를 남가지 않음
		if not FindAbility(owner, owner.OverwatchAbility, false) then
			LogAndPrint('[DataError]', 'No Ability for CounterShoot.', 'owner.OverwatchAbility:', owner.OverwatchAbility);
		end
		return;
	end
	if counterAbility.HitRateType ~= 'Force' then
		return;
	end
	
	mastery.CountChecker = mastery.CountChecker + 1;
	
	return Mastery_CounterAction_AbilityAffected(eventArg, mastery, owner, ds, counterAbility, 'CounterShoot');
end
function Mastery_App_AutoCounterShoot_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.User.HP <= 0
		or eventArg.User == owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsLongDistanceAttack(eventArg.Ability)
		or mastery.DuplicateApplyChecker > 0 
		or not GetBuffStatus(owner, 'Attackable', 'And') then
		return;
	end
	if owner.Cost < mastery.ApplyAmount2 then
		return;
	end
	
	if not HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end) then
		return;
	end
	
	local counterAbility = FindAbility(owner, owner.OverwatchAbility);
	if counterAbility == nil then
		-- 어빌리티가 존재하지만 비활성화된 경우에는 에러 로그를 남가지 않음
		if not FindAbility(owner, owner.OverwatchAbility, false) then
			LogAndPrint('[DataError]', 'No Ability for CounterShoot.', 'owner.OverwatchAbility:', owner.OverwatchAbility);
		end
		return;
	end
	if counterAbility.HitRateType ~= 'Force' then
		return;
	end
	
	return Mastery_CounterAction_AbilityAffected(eventArg, mastery, owner, ds, counterAbility, 'AutoCounterShoot');
end
-- 광전사
function Mastery_Berserker_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or GetRelation(eventArg.User, owner) ~= 'Enemy'
		or eventArg.SubAction 
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, nil, nil, {Type = 'Mastery', Value = mastery.name});

	local masteryTable = GetMastery(owner);
	local mastery_CrazyBeast = GetMasteryMastered(masteryTable, 'CrazyBeast');
	
	local cam = ds:ChangeCameraTarget(objKey, '_SYSTEM_', false, nil, 0.5);
	local look = ds:LookAt(objKey, GetObjKey(eventArg.User));
	ds:Connect(look, cam, 0);
	
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local aniID = ds:PlayAni(objKey, 'Rage', false);
	ds:Connect(aniID, look, -1);
	ds:Connect(masteryEventID, aniID, 0);
	
	if mastery_CrazyBeast then
		local applyAct = -mastery_CrazyBeast.ApplyAmount;
		local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
		if added then
			local addWaitID = ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
			ds:Connect(addWaitID, aniID, 0);
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons, aniID, 0);
	end
	local moveDist = owner.MoveDist / 2;
	if mastery_CrazyBeast then
		moveDist = moveDist + mastery_CrazyBeast.ApplyAmount2;
	end
	local pos = Get_MovePosition_Berserker(owner, eventArg.User, moveDist);
	if pos and owner.Movable then
		mastery.DuplicateApplyChecker = 1;
		ds:ReserveMove(objKey, pos, 'Rush', nil, moveDist, moveDist, true, {Type = 'Mastery', Value = mastery.name, Unit = eventArg.User});
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	if mastery_CrazyBeast then
		MasteryActivatedHelper(ds, mastery_CrazyBeast, owner, 'AbilityAffected');
	end
	return unpack(actions);
end
function Mastery_Berserker_UnitMoved(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
function Get_MovePosition_Berserker(owner, target, moveDist)
	local distance = moveDist;
	distance = distance + 0.4;
	
	local pos, score, _ = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function (self, adb)
		if adb.MoveDistance > distance then
			return -100;	-- 거리제한
		end
		
		local totalScore = 1000;
		local accuracyScore = adb.Accuracy;
		local allyDensityScore = adb.AllyDensity(2);
		local moveDistanceScore = adb.MoveDistance;
		local targetDistanceScore = 100 - GetDistance3D(adb.Position, GetPosition(target));

		-- 대상과 가까운 곳으로 간다.
		totalScore = totalScore + targetDistanceScore * 2;
		
		-- 가능하면 공격이 가능한 곳으로.
		if AttackMove(self, adb) > 0 then
			-- 공격 가능하면 잘 맞출 수 있는 곳을 찾는다.
			-- 다만 난이도를 위해 80% 이상 명중률은 동일 처리한다.
			totalScore = totalScore + 100 + math.min(80, accuracyScore);	
		end
		
		-- 아군이 붙는 곳을 싫어한다 ( 연출용 )
		totalScore = totalScore - allyDensityScore;
		-- 최대한 현재 위치에서 적게 움직이려고 한다.( 연출용 )
		totalScore = totalScore - moveDistanceScore;
		
		return totalScore;
	end, {}, {});
	
	if (not pos) or (score <= 0) or IsSamePosition(pos, GetPosition(owner)) then
		return nil;
	end
	
	return pos;	
end
function Mastery_Solidification_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	return Mastery_Solidification_InvokeCommon(mastery, owner, ds);
end
-- 흡경
function Mastery_AbsorbingEnergy_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or not IsMeleeDistance(GetPosition(owner), GetPosition(eventArg.User)) then
		return;
	end
	local hasAnyLowDamageHit = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0 and targetInfo.MainDamage < owner.MaxHP * mastery.ApplyAmount / 100;
	end);
	if not hasAnyLowDamageHit then
		return;
	end
	local actions = {};
	local applyAct = -1 * mastery.ApplyAmount2;
	local ownerKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 특성 그물 속의 암살자
function Mastery_WebAssassin_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner then
		return;
	end
	-- 특성 거미줄 곡예
	local mastery_WebCircus = GetMasteryMastered(GetMastery(owner), 'WebCircus');
	if not mastery_WebCircus then
		return;
	end
	if not IsObjectOnFieldEffect(owner, mastery_WebCircus.Buff.name) then
		return;
	end
		
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery_WebCircus, owner, 'AbilityAffected', true);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected', true);
	local objKey = GetObjKey(owner);
	local applyAct = -mastery.ApplyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 특성 수면 위의 암살자
function Mastery_WaterAssassin_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner then
		return;
	end
	-- 특성 물 위를 걷는 자
	local mastery_WaterWalker = GetMasteryMastered(GetMastery(owner), 'WaterWalker');
	if not mastery_WaterWalker then
		return;
	end
	if not IsObjectOnFieldEffectBuffAffector(owner, { mastery_WaterWalker.Buff.name, mastery_WaterWalker.SubBuff.name } ) then
		return;
	end
		
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery_WaterWalker, owner, 'AbilityAffected', true);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected', true);
	local objKey = GetObjKey(owner);
	local applyAct = -mastery.ApplyAmount2;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 원격 반응 공격
function Mastery_SummonObjectCounterAttack_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if not IsEnemy(owner, eventArg.User) or eventArg.User.HP <= 0 then
		return;
	end

	-- 소환한 기계들
	local testMachines = table.map((GetInstantProperty(owner, 'SummonMachines') or {}), function (m) return m.Target; end);
	-- 탈취한 기계들
	table.append(testMachines, Linq.new(GetInstantProperty(owner, 'ControlTakingOverTargets') or {})
		:select(function(objKey) return GetUnit(mission, objKey) end)
		:where(function(u) return u ~= nil; end)
		:toList());
		
	if #testMachines == 0 then
		return;
	end
	
	-- 궁극기를 제외한 공격 어빌리티
	local actions = {};
	for _, machine in ipairs(testMachines) do 
		(function()
			local abilities = table.filter(GetAvailableAbility(machine, true), function (ability) return ability.Type == 'Attack' and not ability.SPFullAbility end);
			local abilityRank = {};
			for i, ability in ipairs(abilities) do
				abilityRank[ability.name] = #abilities - i;
			end
			
			local usingAbility, usingPos, _, score = FindAIMainAction(machine, abilities, {{Strategy = function(self, adb)
				local count = table.count(adb.ApplyTargets, function(t) return t == eventArg.User end);
				if count == 0 then
					return -22;
				end
				local score = 100;
				if adb.IsIndirect then
					score = 0;
				end
				score = score + abilityRank[adb.Ability.name] * 200;
				return score + 100 / (adb.Distance + 1);
			end, Target = 'Attack'}}, {}, {});
				
			if usingAbility == nil or usingPos == nil then
				return;
			end
			
			local action, reasons = GetApplyActAction(machine, mastery.ApplyAmount, nil, 'Cost');
			local battleEvents = {};
			if action then
				table.insert(actions, action);
				table.insert(battleEvents, { Object = machine, EventType = 'AddWait', Args = { Time = mastery.ApplyAmount } });
			end
			table.append(battleEvents, ReasonToBattleEventTableMulti(machine, reasons, 'FirstHit'));
			table.insert(battleEvents, { Object = machine, EventType = 'MasteryInvokedBeginning', Args = {Mastery = mastery.name} });
			
			local overwatchAction = Result_UseAbility(machine, usingAbility.name, usingPos, {ReactionAbility=true, BattleEvents=battleEvents, SummonObjectCounterAttack=true}, true, {});
			overwatchAction.free_action = true;
			overwatchAction.final_useable_checker = function()
				return GetBuffStatus(machine, 'Attackable', 'And')
					and PositionInRange(CalculateRange(machine, usingAbility.TargetRange, GetPosition(machine)), usingPos);
			end;
			table.insert(actions, overwatchAction);
		end)() 
	end
	
	return unpack(actions);
end
function Mastery_Module_DefenceOptimaztion_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if not IsEnemy(owner, eventArg.User) or eventArg.User.HP <= 0 then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	return Result_UpdateInstantProperty(owner, mastery.name, eventArg.Ability.SubType);
end
-- 앤이 좋아요
function Mastery_ILikeAnne_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.User.Info.name ~= 'Anne'
		or (eventArg.Ability.Type ~= 'Heal' and eventArg.Ability.Type ~= 'Assist') then
		return;
	end
	local hasAnyEffect = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		if eventArg.Ability.Type == 'Heal' then
			return targetInfo.DefenderState == 'Heal' and targetInfo.MainDamage < 0 and targetInfo.PrevHP < targetInfo.MaxHP;
		else
			return targetInfo.BuffRemoved;
		end		
	end);
	if not hasAnyEffect then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	return unpack(actions);
end
-- 혁명가
function Mastery_Revolutionist_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if not IsEnemy(owner, eventArg.User) or eventArg.User.Lv <= owner.Lv then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected', true);
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	return unpack(actions);
end
-- 일그러진 마음
function Mastery_UglyMind_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	if not IsEnemy(owner, eventArg.User) or eventArg.User.HP <= 0 then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local target = eventArg.User;
	local debuffList = GetBuffType(target, 'Debuff');	
	if #debuffList == 0 then
		return;
	end
	local actions = {};
	local applyAct = math.floor(#debuffList / mastery.ApplyAmount) * mastery.ApplyAmount2;
	if applyAct > 0 then
		MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected', true);
		AddActionApplyActForDS(actions, target, applyAct, ds, 'Hostile');	
	end
	return unpack(actions);
end
-- 곡예사
function Mastery_Acrobat_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' 
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	return unpack(actions);
end
-- 피의 광란
function Mastery_BloodFrenzy_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local applyBuffGroup = SafeIndex(GetWithoutError(eventArg.Ability, 'ApplyTargetBuff'), 'Group');
	local applySubBuffGroup = SafeIndex(GetWithoutError(eventArg.Ability, 'ApplyTargetSubBuff'), 'Group');
	if applyBuffGroup ~= mastery.BuffGroup.name and applySubBuffGroup ~= mastery.BuffGroup.name then
		return;
	end
	local hasAnyBuff = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.BuffApplied;
	end);
	if not hasAnyBuff then
		return;
	end
	return Mastery_BloodFrenzy_InvokeCommon(mastery, owner, ds, 'AbilityAffected');
end
-- 백병전의 달인
function Mastery_MeleeBattleMaster_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or mastery.CountChecker <= 0 then
		return;
	end
	mastery.CountChecker = 0;
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	return unpack(actions);
end
-- 폭염의 괴수, 혹한의 괴수, 달빛의 괴수, 빗속의 괴수
function Mastery_EnvironmentMosnter_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack'
		or mastery.CountChecker <= 0 then
		return;
	end
	mastery.CountChecker = 0;
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTurnStart_Self');
	-- 코스트
	local addCost = mastery.ApplyAmount3;
	AddActionCostForDS(actions, owner, addCost, true, nil, ds);		
	return unpack(actions);
end
-- 자율 방어 행동 최적화
function Mastery_Module_AutoDefence_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyFlag = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return SafeIndex(targetInfo.DamageFlag, 'Module_ShockAbsorber') or SafeIndex(targetInfo.DamageFlag, 'Module_LightningReflexes');
	end);
	if not hasAnyFlag then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	return unpack(actions);
end
------------------------------------------------------------------------------------
-- 적에게 피해를 입을때. [UnitTakeDamage]
--------------------------------------------------------------------------------------
-- 특성 암석화
function Mastery_Solidification_UnitTakeDamage(eventArg, mastery, owner, ds)
	-- 어빌리티 피격 처리는 AbilityAffected 핸들러에서 진행함
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	return Mastery_Solidification_InvokeCommon(mastery, owner, ds);
end
function Mastery_Solidification_InvokeCommon(mastery, owner, ds)
	local actions = {};
	local objKey = GetObjKey(owner);
	local addLv = 1;
	local mastery_SuccessorOfGuardian = GetMasteryMastered(GetMastery(owner), 'SuccessorOfGuardian');
	if mastery_SuccessorOfGuardian then
		addLv = addLv + mastery_SuccessorOfGuardian.ApplyAmount;
	end
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, addLv);	
	
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local aniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
	local sleepID = ds:Sleep(0.5);
	ds:Connect(aniID, masteryEventID, 0);
	ds:Connect(sleepID, aniID, 0);
	if mastery_SuccessorOfGuardian then
		MasteryActivatedHelper(ds, mastery_SuccessorOfGuardian, owner, '', false, masteryEventID, 0);
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
function Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, damageSubType)
	-- 어빌리티 피격 처리는 AbilityAffected 핸들러에서 진행함
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 or eventArg.DamageInfo.damage_type == 'Ability' or eventArg.DamageInfo.damage_sub_type ~= damageSubType then
		return;
	end
	return Mastery_Resistance4_InvokeCommon(mastery, owner, ds);
end
function Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, damageSubType)
	if eventArg.Target ~= owner or eventArg.Ability.SubType ~= damageSubType then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	return Mastery_Resistance4_InvokeCommon(mastery, owner, ds);
end
function Mastery_Resistance4_InvokeCommon(mastery, owner, ds)
	local actions = {};
	local objKey = GetObjKey(owner);	
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true, nil, true);
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 불꽃의 가호
function Mastery_FireResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Fire');
end
function Mastery_FireResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Fire');
end
-- 얼음의 가호
function Mastery_IceResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Ice');
end
function Mastery_IceResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Ice');
end
-- 번개의 가호
function Mastery_LightningResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Lightning');
end
function Mastery_LightningResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Lightning');
end
-- 바람의 가호
function Mastery_WindResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Wind');
end
function Mastery_WindResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Wind');
end
-- 물의 가호
function Mastery_WaterResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Water');
end
function Mastery_WaterResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Water');
end
-- 대지의 가호
function Mastery_EarthResistance4_UnitTakeDamage(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_UnitTakeDamage(eventArg, mastery, owner, ds, 'Earth');
end
function Mastery_EarthResistance4_AbilityAffected(eventArg, mastery, owner, ds)
	return Mastery_Resistance4_AbilityAffected(eventArg, mastery, owner, ds, 'Earth');
end
-- 재기의 바람
function Mastery_SecondWind_UnitTakeDamage(eventArg, mastery, owner, ds)
	-- 어빌리티 피격 처리는 AbilityAffected 핸들러에서 진행함
	if eventArg.Receiver ~= owner or eventArg.Damage <= 0 or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	if owner.HP > owner.MaxHP * mastery.ApplyAmount2 / 100 then
		return;
	end	
	return Mastery_SecondWind_InvokeCommon(mastery, owner, ds);
end
function Mastery_SecondWind_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner then
		return;
	end
	if owner.HP > owner.MaxHP * mastery.ApplyAmount2 / 100 then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	return Mastery_SecondWind_InvokeCommon(mastery, owner, ds);
end
function Mastery_SecondWind_InvokeCommon(mastery, owner, ds)
	local actions = {};
	local objKey = GetObjKey(owner);
	local evt = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if GetBuff(owner, mastery.Buff.name) then
		local addHP = math.max(1, math.floor(owner.MaxHP * mastery.ApplyAmount/100));
		local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		actions[#actions].sequential = true;
		DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), false, false, evt, 0); 
	else
		--  재생이 없으면 재생을 건다.
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 충분한 휴식
function Mastery_MindAndBodyRest_UnitTakeDamage(eventArg, mastery, owner, ds)
	-- 어빌리티 피격 처리는 AbilityAffected 핸들러에서 진행함
	if eventArg.Receiver ~= owner or (eventArg.Damage >= 0 and eventArg.DefenderState ~= 'Heal') or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	-- 실제 회복량이 0 이하이면서 최대 체력이라면 효율을 떨어뜨림
	local isFullHP = false;
	if eventArg.DamageInfo.damage >= 0 and owner.HP == owner.MaxHP then
		isFullHP = true;
	end	
	return Mastery_MindAndBodyRest_InvokeCommon(mastery, owner, ds, 'UnitTakeDamage_Self', isFullHP);
end
function Mastery_MindAndBodyRest_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner then
		return;
	end
	local hasAnyHeal = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Heal' and targetInfo.MainDamage <= 0;
	end);
	if not hasAnyHeal then
		return;
	end	
	local hasAnyHealEffective = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		-- 최대 HP 상태에서 들어온 회복은 효율을 떨어뜨림
		return targetInfo.DefenderState == 'Heal' and targetInfo.PrevHP < targetInfo.MaxHP;
	end);
	local isFullHP = not hasAnyHealEffective;
	return Mastery_MindAndBodyRest_InvokeCommon(mastery, owner, ds, 'AbilityAffected', isFullHP);
end
function Mastery_MindAndBodyRest_InvokeCommon(mastery, owner, ds, eventType, isFullHP)
	local actions = {};
	local objKey = GetObjKey(owner);
	local addCost = mastery.ApplyAmount;
	local applyAct = -1 * mastery.ApplyAmount;
	-- 최대 체력 시 효과 감소
	if isFullHP then
		addCost = addCost * (1 - mastery.ApplyAmount2 / 100);
		applyAct = applyAct * (1 - mastery.ApplyAmount2 / 100);
		LogAndPrint(mastery.ApplyAmount2,addCost, applyAct);
	end
	local masteryTable = GetMastery(owner);
	-- 선혈의 기억
	local mastery_LegendOfDracula = GetMasteryMastered(masteryTable, 'LegendOfDracula');
	if mastery_LegendOfDracula then
		local applyActAdd = -1 * mastery_LegendOfDracula.ApplyAmount2;
		if isFullHP then
			applyActAdd = applyActAdd * (1 - mastery_LegendOfDracula.ApplyAmount3 / 100);
		end
		applyAct = applyAct + applyActAdd;
	end
	-- 검귀
	local mastery_GhostSword = GetMasteryMastered(masteryTable, 'GhostSword');
	if mastery_GhostSword then
		local applyActAdd = -1 * mastery_GhostSword.ApplyAmount2;
		if isFullHP then
			applyActAdd = applyActAdd * (1 - mastery_GhostSword.ApplyAmount3 / 100);
		end
		applyAct = applyAct + applyActAdd;
	end
	MasteryActivatedHelper(ds, mastery, owner, eventType);
	if mastery_LegendOfDracula then
		MasteryActivatedHelper(ds, mastery_LegendOfDracula, owner, eventType);
	end
	if mastery_GhostSword then
		MasteryActivatedHelper(ds, mastery_GhostSword, owner, eventType);
	end
	local _, reasons = AddActionCost(actions, owner, addCost, true);
	ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 특성 투영 - 피해 입을때 버프 복사해오기.
function Mastery_TraceOn_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local masteryTable = GetMastery(owner);
	local mastery_HappyWitch = GetMasteryMastered(masteryTable, 'HappyWitch');
	
	local target = eventArg.User;
	local targetBuffList = GetBuffType(target, 'Buff');
	local targetDebuffList = GetBuffType(target, 'Debuff');
	
	local selectBuffList = {};
	if mastery_HappyWitch then
		-- 유쾌한 마녀 (모든 버프, 디버프 선택)
		table.append(selectBuffList, targetBuffList);
		table.append(selectBuffList, targetDebuffList);
	else
		--기본 투영 효과 (버프 1개 랜덤 선택)
		if #targetBuffList > 0 then
			local selectBuff = targetBuffList[math.random(1, #targetBuffList)];
			table.insert(selectBuffList, selectBuff);
		end
	end
	if #selectBuffList <= 0 then
		return;
	end
	
	local objKey = GetObjKey(owner);
	local actions = {};
	for _, selectBuff in ipairs(selectBuffList) do
		InsertBuffActions(actions, owner, owner, selectBuff.name, selectBuff.Lv, true);
	end
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local aniID = ds:PlayAni(objKey, 'AstdIdle', false, -1, true);
	ds:Connect(masteryEventID, aniID, 0);
	if mastery_HappyWitch then
		ds:Connect(ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery_HappyWitch.name }), masteryEventID, 0);
	end
	
	-- 일그러진 마음
	local mastery_UglyMind = GetMasteryMastered(masteryTable, 'UglyMind');
	if mastery_UglyMind then
		local applyAct = -1 * math.floor(#selectBuffList / mastery_UglyMind.ApplyAmount) * mastery_UglyMind.ApplyAmount2;
		if applyAct < 0 then
			MasteryActivatedHelper(ds, mastery_UglyMind, owner, 'AbilityAffected');
			AddActionApplyActForDS(actions, owner, applyAct, ds, 'Friendly');
		end
	end

	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityAffected'});
	return unpack(actions);
end
-- 특성 저주
function Mastery_Curse_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	
	local buffList = GetClassList('Buff');
	local badBuffList = Linq.new(GetClassList('Buff_Negative'))
		:select(function(pair) return pair[1]; end)
		:where(function(buffName) return buffList[buffName].SubType == 'Mental'; end)
		:toList();
		
	local target = eventArg.User;
	local buffPicker = RandomBuffPicker.new(target, badBuffList);
	local buff = buffPicker:PickBuff();
	if not buff then
		return;
	end
	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	InsertBuffActions(actions, owner, target, buff, 1, true);
	return unpack(actions);
end
-- 특성 무기 막기
function Mastery_WeaponBlocking_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Block';
	end);
	if not hasAnyBlock then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local masteryTable = GetMastery(owner);
	local applyAct = - mastery.ApplyAmount;
	local mastery_GuardianSword = GetMasteryMastered(masteryTable, 'GuardianSword'); 
	if mastery_GuardianSword then
		applyAct = applyAct - mastery_GuardianSword.ApplyAmount;
		ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	end
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 특성 신속한 대응
function Mastery_RapidReaction_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local applyAct = -mastery.ApplyAmount;
	local masteryTable = GetMastery(owner);
	local mastery_Opportunist = GetMasteryMastered(masteryTable, 'Opportunist');
	if mastery_Opportunist then
		applyAct = applyAct - mastery_Opportunist.ApplyAmount;
		MasteryActivatedHelper(ds, mastery_Opportunist, owner, 'AbilitAffected');
	end

	local mastery_ShakeShake = GetMasteryMastered(masteryTable, 'ShakeShake');
	if mastery_ShakeShake then
		InsertBuffActions(actions, owner, owner, mastery_ShakeShake.Buff.name, mastery_ShakeShake.ApplyAmount2);
		MasteryActivatedHelper(ds, mastery_ShakeShake, owner, 'AbilityAffected');
	end
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	if added then
		ds:UpdateBattleEvent(objKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	
	-- 전장을 뚫어라
	local mastery_DrillBattleField = GetMasteryMastered(masteryTable, 'DrillBattleField');
	if mastery_DrillBattleField then
		InsertBuffActions(actions, owner, owner, mastery_DrillBattleField.Buff.name, 1, true);
		MasteryActivatedHelper(ds, mastery_DrillBattleField, owner, 'AbilityAffected');
	end
	
	return unpack(actions);
end
-- 특성 흐르는 물
function Mastery_RunningWater_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner then
		return;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Water', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 특성 얼어붙은 심장
function Mastery_FrozenHeart_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasAnyBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Block';
	end);
	if not hasAnyBlock then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Ice', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 정보 분석
function Mastery_InformationAnalysis_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local applySP = mastery.ApplyAmount;
	AddSPPropertyActions(actions, owner, 'Info', applySP, true, ds, true);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'AbilityAffected'});
	return unpack(actions);
end
-- 특성 흘리기
function Mastery_Parry_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local checkDist = 1.4;
	local masteryTable = GetMastery(owner);
	local mastery_Mountain = GetMasteryMastered(masteryTable, 'Mountain');
	if mastery_Mountain then
		checkDist = mastery_Mountain.ApplyAmount;
	end
	if not IsMeleeDistanceAbility(eventArg.User, owner, checkDist) then
		return;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	local hasAnyBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Block';
	end);
	if not hasAnyDodge and not hasAnyBlock then
		return;
	end
	local actions = {};
	local giveAct;
	if hasAnyDodge then
		giveAct = mastery.ApplyAmount;
	else
		giveAct = mastery.ApplyAmount2;
	end
	local action, reasons = GetApplyActAction(eventArg.User, giveAct, nil, 'Hostile');
	if action ~= nil then
		table.insert(actions, action);
	end
	
	local cam = ds:ChangeCameraTarget(GetObjKey(eventArg.User), '_SYSTEM_', false);
	ds:Connect(ds:UpdateBattleEvent(GetObjKey(owner), 'MasteryInvoked', { Mastery = mastery.name }), cam, 0.5);
	if action then
		ds:Connect(ds:UpdateBattleEvent(GetObjKey(eventArg.User), 'AddWait', { Time = giveAct, Delay = true }), cam, 0.5);
	end
	ReasonToUpdateBattleEventMulti(eventArg.User, ds, reasons, cam, 0.5);
	
	local gatekeeper = GetMasteryMastered(GetMastery(owner), 'Gatekeeper');
	if gatekeeper then
		local action, reasons = GetApplyActAction(owner, -gatekeeper.ApplyAmount2, nil, 'Friendly');
		if action then
			table.insert(actions, action);
			ds:Connect(ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -gatekeeper.ApplyAmount2, Delay = true }), cam, 0.5);
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons, cam, 0.5);
	end
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 특성 견제 공격
function Mastery_ContainingAttack_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 then
			local target = targetInfo.Target;
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	local applyAct = mastery.ApplyAmount;
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	for targetKey, target in pairs(applyTargets) do
		local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Hostile');
		if added then
			ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 특성 그물 속의 먹잇감
function Mastery_FoodinWeb_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local applyTargets = {};
	ForeachAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		if targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0 and HasBuff(targetInfo.Target, 'Web') then
			local target = targetInfo.Target;
			local targetKey = GetObjKey(target);
			applyTargets[targetKey] = target;
		end
	end);
	if table.empty(applyTargets) then
		return;
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	local applyAct = mastery.ApplyAmount;
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	for targetKey, target in pairs(applyTargets) do
		local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Hostile');
		if added then
			ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
	end
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 기회 포착
function Mastery_OpportunityAcquisition_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDodgeOrBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge' or targetInfo.DefenderState == 'Block';
	end);
	if not hasAnyDodgeOrBlock then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityUsed');
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
function Direct_ObstacleDisabled(mid, ds, args)
	local objKey = args.ObjKey;
	local playId = ds:PlayUIEffect(objKey, '', 'BigText', 0, 0, PackTableToString({Text = WordText('ObstacleDisabled'), Color = 'FFFFFFCC'}));
	ds:SetCommandLayer(playId, game.DirectingCommand.CM_SECONDARY);
	ds:SetContinueOnNormalEmpty(playId);
end
function ReplaceMonster(ds, mon, replaceMonType, playDead)
	local direction = GetDirection(mon);
	local newObjKey = GenerateUnnamedObjKey(GetMission(mon));
	local destroy = Result_DestroyObject(mon, false, true);
	local create = Result_CreateMonster(newObjKey, replaceMonType, GetPosition(mon), '_neutral_', function(obj, arg)
		UNIT_INITIALIZER(obj, GetTeam(obj));
		SetDirection(obj, direction);
	end, nil, 'DoNothingAI', {}, true);
	destroy.sequential = true;
	create.sequential = true;
	if playDead then
		local eventID = ds:SetDead(GetObjKey(mon), 'Normal', 0, 0, 0, 0, 0);
		destroy._ref = eventID;
		destroy._ref_offset = -1;
		create._ref = eventID;
		create._ref_offset = -1;
	end
	return destroy, create;
end
function Mastery_FlammableObject_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_base <= 0 then
		return;
	end
	if eventArg.DamageInfo.damage_sub_type == 'Ice' then
		local disabledMonType = GetInstantProperty(owner, 'DisabledMonsterType');
		if not disabledMonType then
			LogAndPrint('Cannot find DisabledMonsterType', owner.name, GetObjKey(owner));
			return;
		end
		local actions = {ReplaceMonster(ds, owner, disabledMonType, false)};
		local directing = Result_DirectingScript('Direct_ObstacleDisabled', {ObjKey = newObjKey});
		directing.sequential = true;
		table.insert(actions, directing);
		return unpack(actions);
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
	local abilityBuff = eventArg.DamageInfo.damage_type == 'Ability';
	if not abilityBuff then
		ds:UpdateBattleEvent(GetObjKey(owner), 'BuffInvoked', {Buff = 'Burning'});
	end
	if eventArg.Giver == owner then
		return;
	end
	return Result_AddBuff(owner, owner, 'Burning', 1, nil, true, abilityBuff);
end
function Mastery_ToxicObject_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_base <= 0 then
		return;
	end
	if eventArg.DamageInfo.damage_sub_type == 'Ice' then
		local disabledMonType = GetInstantProperty(owner, 'DisabledMonsterType');
		local direction = GetDirection(owner);
		local newObjKey = GenerateUnnamedObjKey(GetMission(owner));
		local destroy = Result_DestroyObject(owner, false, true);
		local create = Result_CreateMonster(newObjKey, disabledMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		local directing = Result_DirectingScript('Direct_ObstacleDisabled', {ObjKey = newObjKey});
		destroy.sequential = true;
		create.sequential = true;
		directing.sequential = true;
		return destroy, create, directing;
	end
	
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
	return Result_AddBuff(owner, owner, 'Burning', 1, nil, true, false), Result_UseAbility(owner, 'ToxicLeakage', GetPosition(owner), nil, true);
end
function Mastery_Civil_UnitTurnEnd(eventArg, mastery, owner, ds)
	local team = GetTeam(eventArg.Unit);
	if team == 'citizen'
		or team == 'player'
		or string.find(team, '[e|E]nemy') == nil
		or eventArg.Unit.Race.name == 'Object'
		or GetDistance3D(GetPosition(owner), GetPosition(eventArg.Unit)) >= 2 then
		return;
	end
	
	local unitKey = GetObjKey(owner);
	ds:ChangeCameraTarget(unitKey, '_SYSTEM_', false)
	ds:UpdateBalloonCivilMessage(unitKey, 'Feared', owner.Info.AgeType);
	
	local injured = GetBuff(owner, 'InjuredRescue') or GetBuff(owner, 'InjuredRageRescue');
	
	if injured then
		return;
	end
	
	local pos = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function(self, adb, args)
		if adb.MoveDistance > 3 then
			return -9999;
		end
		
		local score = 0;
		if adb.Coverable then
			score = score + 1000;
		end
		
		if not adb.ClearPath then
			score = score + 500;
		end
		return score + math.min(adb.MinBadFieldDistance, adb.MinEnemyDistance);
	end, {}, {});
	if pos == nil then
		return;
	end
	ds:ReserveMove(unitKey, pos, nil, false, nil, nil, true);
end
function Mastery_HardshipWay_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(eventArg.User, owner)
		or owner.HP <= 0 then
		return;
	end
	local hasNotDodgeAndDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0;
	end);
	if not hasNotDodgeAndDamage then
		return;
	end
	local actions = {};
	local ownerKey = GetObjKey(owner);
	ds:UpdateBattleEvent(ownerKey, 'MasteryInvoked', { Mastery = mastery.name });
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = -mastery.ApplyAmount });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = ownerKey, MasteryType = mastery.name, EventType = 'UnitDead'});
	return unpack(actions);
end
-- 특성 아르고노트
function Mastery_Argonaut_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(eventArg.User, owner)
		or owner.HP <= 0 then
		return;
	end
	local hasNotDodgeAndDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0;
	end);
	if not hasNotDodgeAndDamage then
		return;
	end
	if owner.HP > owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end
	if owner.Overcharge > 0 then
		return;
	end
	
	local actions = {};
	local objKey = GetObjKey(owner);
	AddSPPropertyActions(actions, owner, owner.ESP.name, owner.MaxSP - owner.SP, true, ds, true);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 특성 에너지 전환.
function Mastery_ConversionOfEnergy_UnitTakeDamage(eventArg, mastery, owner, ds)
	if not IsEnemy(eventArg.Giver, owner)
		or eventArg.DefenderState == 'Dodge'
		or eventArg.Damage <= 0
		or owner.HP <= 0 
		or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	return Mastery_ConversionOfEnergy_InvokeCommon(mastery, owner, ds, eventArg.Damage);
end
function Mastery_ConversionOfEnergy_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(eventArg.User, owner)
		or owner.HP <= 0 then
		return;
	end
	local totalDamage = 0;
	ForeachAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		if targetInfo.MainDamage > 0 then
			totalDamage = totalDamage + targetInfo.MainDamage;
		end
	end);
	if totalDamage <= 0 then
		return;
	end
	return Mastery_ConversionOfEnergy_InvokeCommon(mastery, owner, ds, totalDamage);
end
function Mastery_ConversionOfEnergy_InvokeCommon(mastery, owner, ds, damage)
	if damage < owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end
	local actions = {};
	local addsp = math.max(1, math.floor(damage * mastery.ApplyAmount2/100));
	
	local masteryTable = GetMastery(owner);
	local mastery_Generator = GetMasteryMastered(masteryTable, 'Generator');
	if mastery_Generator then
		addsp = addsp + mastery_Generator.ApplyAmount2;
	end	
	local mastery_AuxiliaryPower = GetMasteryMastered(GetMastery(owner), 'AuxiliaryPower');
	if mastery_AuxiliaryPower and addsp > 0 then
		InsertBuffActions(actions, owner, owner, mastery_AuxiliaryPower.Buff.name, addsp, true);
		MasteryActivatedHelper(ds, mastery_AuxiliaryPower, owner, 'Etc');
	end
	
	local objKey = GetObjKey(owner);
	AddSPPropertyActions(actions, owner, owner.ESP.name, addsp, true, ds, true);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'UnitTakeDamage'});
	return unpack(actions);
end
-- 연료 전환
function Mastery_Module_ConversionOfFuel_UnitTakeDamage(eventArg, mastery, owner, ds)
	if not IsEnemy(eventArg.Giver, owner)
		or eventArg.DefenderState == 'Dodge'
		or eventArg.Damage <= 0
		or owner.HP <= 0 
		or eventArg.DamageInfo.damage_type == 'Ability' then
		return;
	end
	return Mastery_Module_ConversionOfFuel_InvokeCommon(mastery, owner, ds, eventArg.Damage, 'UnitTakeDamage_Self');
end
function Mastery_Module_ConversionOfFuel_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or not IsEnemy(eventArg.User, owner)
		or owner.HP <= 0 then
		return;
	end
	local totalDamage = 0;
	ForeachAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		if targetInfo.MainDamage > 0 then
			totalDamage = totalDamage + targetInfo.MainDamage;
		end
	end);
	if totalDamage <= 0 then
		return;
	end
	return Mastery_Module_ConversionOfFuel_InvokeCommon(mastery, owner, ds, totalDamage, 'AbilityAffected');
end
function Mastery_Module_ConversionOfFuel_InvokeCommon(mastery, owner, ds, damage, eventType)
	if damage < owner.MaxHP * mastery.ApplyAmount / 100 then
		return;
	end
	local actions = {};
	local applyAmount = mastery.ApplyAmount2;
	-- 연비 강화 프로그램
	local mastery_Module_FuelEnhancement = GetMasteryMastered(GetMastery(owner), 'Module_FuelEnhancement');
	if mastery_Module_FuelEnhancement then
		applyAmount = applyAmount * (1 + mastery_Module_FuelEnhancement.ApplyAmount2 / 100);
	end
	local addCost = math.max(1, math.floor(damage * applyAmount/100));
	local _ reasons = AddActionCost(actions, owner, addCost, true);
	ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	MasteryActivatedHelper(ds, mastery, owner, eventType);
	if mastery_Module_FuelEnhancement then
		MasteryActivatedHelper(ds, mastery_Module_FuelEnhancement, owner, eventType);
	end
	
	return unpack(actions);
end
-- 특성 보이지 않는 검
function Mastery_InvisibleSword_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local battleTargets = GetInstantProperty(owner, 'InvisibleSword') or {};
	local targetKey = GetObjKey(eventArg.User);
	battleTargets[targetKey] = true;
	return Result_UpdateInstantProperty(owner, 'InvisibleSword', battleTargets);
end
function Mastery_SpellPowerOfCrack_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(owner, eventArg.User) then
		return;
	end
	local hasDodgeOrBlock = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge' or targetInfo.DefenderState == 'Block';
	end);
	if not hasDodgeOrBlock then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	
	local addlv = 1;
	local mastery_SpellAcceleration = GetMasteryMastered(GetMastery(owner), 'SpellAcceleration');
	if mastery_SpellAcceleration then
		MasteryActivatedHelper(ds, mastery_SpellAcceleration, owner, 'AbilityAffected');
		addLv = addlv + mastery_SpellAcceleration.ApplyAmount;
	end
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, addLv, true, nil, nil, {Type = 'Mastery', Value = mastery.name});
	return unpack(actions);
end
-- 인공지능 모듈 - 회피 기동
function Get_MovePosition_EscapeMove(owner, target, moveDist)
	local distance = moveDist;
	distance = distance + 0.4;
	
	local pos, score, _ = FindAIMovePosition(owner, {FindMoveAbility(owner)}, function (self, adb)
		if adb.MoveDistance > distance then
			return -100;	-- 거리제한
		end
		if adb.BadField then
			return -1357;
		end
		
		local totalScore = 1000;
		local accuracyScore = adb.Accuracy;
		local allyDensityScore = adb.AllyDensity(2);
		local moveDistanceScore = adb.MoveDistance;
		local targetDistanceScore = GetDistance3D(adb.Position, GetPosition(target));
		local dangerousScore = adb.Dangerous;
		
		-- 대상과 먼 곳으로 간다.
		totalScore = totalScore + targetDistanceScore * 5;
		
		-- 가능하면 조금 더 안전한 곳으로
		totalScore = totalScore + dangerousScore;
		
		-- 아군이 붙는 곳을 싫어한다 ( 연출용 )
		totalScore = totalScore - allyDensityScore;
		-- 최대한 현재 위치에서 적게 움직이려고 한다.( 연출용 )
		totalScore = totalScore - moveDistanceScore;
		
		return totalScore;
	end, {}, {});
	
	if (not pos) or (score <= 0) or IsSamePosition(pos, GetPosition(owner)) then
		return nil;
	end
	
	return pos;	
end
function Mastery_Module_EscapeMove_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or eventArg.Ability.Type ~= 'Attack'
		or not IsEnemy(eventArg.User, owner)
		or not owner.Movable
		or eventArg.SubAction
		or GetBuffStatus(owner, 'Unconscious', 'Or')
		or owner.HP <= 0 then
		return;
	end
	if owner.Cost < mastery.ApplyAmount then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	
	local moveDist = owner.MoveDist / 2;
	local pos = Get_MovePosition_EscapeMove(owner, eventArg.User, moveDist);
	if pos then
		ds:ReserveMove(objKey, pos, 'Rush', false, moveDist, moveDist, true, {Type = 'Mastery', Value = mastery.name, Unit = eventArg.User});
		AddActionCostForDS(actions,  owner, -mastery.ApplyAmount, true, nil, ds);
	end
	return unpack(actions);
end
-- 교란
function Mastery_Feint_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return;
	end
	local applyAct = mastery.ApplyAmount;
	if eventArg.Ability.TargetType ~= 'Single' then
		applyAct = mastery.ApplyAmount2;
	end
	local actions = {};
	local target = eventArg.User;
	local targetKey = GetObjKey(target);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	local added, reasons = AddActionApplyAct(actions, target, target, applyAct, 'Hostile');
	if added then
		ds:UpdateBattleEvent(targetKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(target, ds, reasons);
	return unpack(actions);
end
-- 돌입준비
function IsDodgeOnCover_AbilityAffected(eventArg, owner)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' then
		return false;
	end
	local hasAnyDodge = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.DefenderState == 'Dodge';
	end);
	if not hasAnyDodge then
		return false;
	end
	local coverState = GetCoverStateForCritical(owner, GetMastery(owner), GetPosition(eventArg.User), eventArg.User);
	if coverState == 'None' then
		return false;
	end
	return true;
end
function Mastery_RushReady_AbilityAffected(eventArg, mastery, owner, ds)
	if not IsDodgeOnCover_AbilityAffected(eventArg, owner) then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	local applyAmount = mastery.ApplyAmount;
	-- 완벽한 잠복
	local mastery_PerfectCover = GetMasteryMastered(GetMastery(owner), 'PerfectCover');
	if mastery_PerfectCover then
		applyAmount = applyAmount + mastery_PerfectCover.ApplyAmount2;
	end
	local applyAct = -1 * applyAmount;
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = applyAct, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 붉은 꽃
function Mastery_Amulet_Flower_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack' then
		return;
	end
	local hasAnyCritical = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.AttackerState == 'Critical' and targetInfo.DefenderState ~= 'Dodge' and targetInfo.MainDamage > 0;
	end);
	if not hasAnyCritical then
		return;
	end
	local prob = mastery.ApplyAmount;
	if not RandomTest(prob) then
		return;
	end
	local dataList = GetClassList('Buff_'..mastery.BuffGroup.name);
	if not dataList then
		LogAndPrint('Random BuffGroup is not defined -:', mastery.BuffGroup.name);
		return;
	end
	
	local rageBuffList = Linq.new(dataList)
		:select(function(pair) return pair[1]; end)
		:toList();
	local buffPicker = RandomBuffPicker.new(owner, rageBuffList);
	local pickBuff = buffPicker:PickBuff();
	if not pickBuff then
		return;
	end	
	local actions = {};
	local objKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	InsertBuffActions(actions, owner, owner, pickBuff, 1, true);
	return unpack(actions);
end
-- 마법 재구성
function Mastery_MagicReconsitutation_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_type ~= 'Ability' then
		return;
	end
	local testFlags = table.filter({ 'IronHeart', 'MagicField', 'ImpulseFields' }, function(flag)
		return SafeIndex(eventArg, 'DamageInfo', 'Flag', flag);
	end);
	if #testFlags == 0 then
		return;
	end
	local addLv = #testFlags;
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, addLv, true, nil, nil, {Type = 'Mastery', Value = mastery.name});
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage');
	return unpack(actions);
end
-- 충격흡수
function Mastery_Module_ShockAbsorber_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_type ~= 'Ability' then
		return;
	end
	local testFlags = table.filter({ 'Module_ShockAbsorber' }, function(flag)
		return SafeIndex(eventArg, 'DamageInfo', 'Flag', flag);
	end);
	if #testFlags == 0 then
		return;
	end
	local actions = {};
	local addCost = -1 * mastery.ApplyAmount2;
	local _ reasons = AddActionCost(actions, owner, addCost, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 맹독 가죽
function Mastery_PoisonSkin_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack'
		or not IsMeleeDistance(GetPosition(owner), GetPosition(eventArg.User)) then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local target = eventArg.User;
	local poisonBuffList = Linq.new(GetClassList('Buff'))
		:where(function(pair) return pair[2].Group == 'Poison'; end)
		:select(function(pair) return pair[1]; end)
		:toList();
	local buffPicker = RandomBuffPicker.new(target, poisonBuffList);
	local pickBuff = buffPicker:PickBuff();
	if not pickBuff then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	InsertBuffActions(actions, owner, target, pickBuff, 1, true);
	return unpack(actions);
end
-- 정전기
function Mastery_StaticElectricity_AbilityAffected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or GetRelation(owner, eventArg.User) ~= 'Enemy'
		or eventArg.Ability.Type ~= 'Attack'
		or not IsMeleeDistance(GetPosition(owner), GetPosition(eventArg.User)) then
		return;
	end
	local hasAnyDamage = HasAnyAbilityUsingInfo(eventArg.AbilityTargetInfos, function (targetInfo)
		return targetInfo.MainDamage > 0;
	end);
	if not hasAnyDamage then
		return;
	end
	local actions = {};
	local damTargets = {};
	table.insert(damTargets, eventArg.User);
	local mastery_AuxiliaryPower = GetMasteryMastered(GetMastery(owner), 'AuxiliaryPower');
	if mastery_AuxiliaryPower == nil then
		table.insert(damTargets, owner);
	else
		MasteryActivatedHelper(ds, mastery_AuxiliaryPower, owner, 'AbilityAffected');
	end
	for _, target in ipairs(damTargets) do
		local damage = mastery.ApplyAmount;
		local realDamage, reasons = ApplyDamageTest(target, damage, 'Mastery');
		local isDead = target.HP <= realDamage;
		local remainHP = math.clamp(target.HP - realDamage, 0, target.MaxHP);
		DirectDamageByType(ds, target, 'StaticElectricity', damage, remainHP, true, isDead);
		ReasonToUpdateBattleEventMulti(target, ds, reasons);
		local damageAction = Result_Damage(damage, 'Normal', 'Hit', owner, target, 'Mastery', 'Lightning', mastery);
		damageAction.sequential = true;
		table.insert(actions, damageAction);
		ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEventTargetDamage', {ObjectKey = GetObjKey(owner), TargetKey = GetObjKey(target), MasteryType = mastery.name, Damage = damage});
	end
	return unpack(actions);
end
-- 축전기
function Mastery_Capacitor_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= 0
		or owner.HP <= 0 then
		return;
	end
	local actions = {};
	local addLv = eventArg.Damage;
	local mastery_BigCapacitor = GetMasteryMastered(GetMastery(owner), 'BigCapacitor');
	if mastery_BigCapacitor then
		addLv = math.floor(addLv * (1 + mastery_BigCapacitor.ApplyAmount / 100));
		MasteryActivatedHelper(ds, mastery_BigCapacitor, owner, 'UnitTakeDamage_Self');
	end
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, addLv, true, nil, nil, {Type = 'Mastery', Value = mastery.name});
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage_Self');
	return unpack(actions);
end
-- 긴급 구동
function Mastery_Module_EmergencyMode_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= 0
		or owner.HP <= 0 then
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	if eventArg.Damage <= owner.MaxHP * mastery.ApplyAmount/100 then
		return;
	end
	if owner.Cost < mastery.ApplyAmount2 then
		return;
	end
	if not owner.TurnState.TurnEnded and owner.Act <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage_Self');
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount2, true, nil, ds);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	-- 자율 행동 강화 프로그램
	local mastery_Module_AutoAction = GetMasteryMastered(GetMastery(owner), 'Module_AutoAction');
	if mastery_Module_AutoAction then
		-- 바로 턴 대기시간을 줄일 수 없으므로, 턴 획득 시까지 지연시킴
		SubscribeWorldEvent(owner, 'UnitTurnAcquired', function(eventArg, ds, subscriptionID)
			if eventArg.Unit ~= owner then
				return;
			end
			UnsubscribeWorldEvent(owner, subscriptionID);
			local actions = {};
			AddActionApplyActForDS(actions, owner, -mastery_Module_AutoAction.ApplyAmount2, ds, 'Friendly');
			MasteryActivatedHelper(ds, mastery_Module_AutoAction, owner, 'UnitDead');
			return unpack(actions);
		end);
	end	
	return unpack(actions);
end
-- 드라키의 화려한 비늘
function Mastery_Amulet_Draky_Scale_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.Damage <= 0
		or owner.HP <= 0 then
		return;
	end
	-- 의식불명 상태에서는 발동 안함
	if GetBuffStatus(owner, 'Unconscious', 'Or') then
		return;
	end
	if eventArg.Damage < owner.MaxHP * mastery.ApplyAmount/100 then
		return;
	end
	if not owner.TurnState.TurnEnded and owner.Act <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitTakeDamage_Self');
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	if not owner.TurnState.TurnEnded then
		table.append(actions, {GetInitializeTurnActions(owner)});
	end
	return unpack(actions);
end
-- 바위 망치
function Mastery_StoneHammer_UnitTakeDamage(eventArg, mastery, owner, ds)
	if eventArg.DamageInfo.damage_type ~= 'Ability' then
		return;
	end
	local testFlags = table.filter({ 'RockCastle' }, function(flag)
		return SafeIndex(eventArg, 'DamageInfo', 'Flag', flag);
	end);
	if #testFlags == 0 then
		return;
	end
	-- 다시 걸어줄 필요 없음
	local buff = GetBuff(owner, mastery.SubBuff.name);
	if buff and buff.Life >= buff.Turn then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'AbilityAffected');
	InsertBuffActions(actions, owner, owner, mastery.SubBuff.name, 1, true);
	return unpack(actions);
end
------------------------------------------------------------------------------------
-- 액션 구분자 [ActionDelimiter]
--------------------------------------------------------------------------------------
function Mastery_SoulGuide_ActionDelimiter(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker == 0 then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local cam = ds:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	
	local addCostVal = mastery.ApplyAmount * mastery.DuplicateApplyChecker;
	local guardian = GetMasteryMastered(GetMastery(owner), 'SoulGuardian');
	if guardian then
		addCostVal = addCostVal + guardian.ApplyAmount * mastery.DuplicateApplyChecker;
	end
	
	local afterCost, reasons = AddActionCost(actions, owner, addCostVal, true);
	if owner.Cost < afterCost then
		ds:Connect(ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = afterCost - owner.Cost }), cam, 0.5);
	end
	ds:Connect(ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name }), cam, 0.5);
	ReasonToUpdateBattleEventMulti(owner, ds, reasons, cam, 0.5);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'ActionDelimiter'});
	
	local mastery_SoulReaper = GetMasteryMastered(GetMastery(owner), 'SoulReaper');
	if mastery_SoulReaper then
		InsertBuffActions(actions, owner, owner, mastery_SoulReaper.Buff.name, mastery.DuplicateApplyChecker);
		MasteryActivatedHelper(ds, mastery, owner, 'ActionDelimiter', nil, cam, 0.5);
	end
	mastery.DuplicateApplyChecker = 0;
	return unpack(actions);
end
-- 배움의 기쁨
function Mastery_RoadOfStudies_ActionDelimiter(eventArg, mastery, owner, ds)
	return Mastery_RoadOfStudies_FlushPrevExp(eventArg, mastery, owner, ds);
end
--------------------------------------------------------------------------------------------
-- 유닛을 죽임 [UnitKilled]
--------------------------------------------------------------------------------------------
-- 무장 해제
function Mastery_Disarming_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local aniID = ds:PlayAni(objKey, 'Rage', false, -1, true);
	ds:Connect(masteryEventID, aniID, 0);
	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 영혼 흡수
function Mastery_DrainSoul_UnitKilled(eventArg, mastery, owner, ds)
	-- 생명체가 아니면 리턴.
	local target = eventArg.Unit;
	if not owner.Race.Life or not target.Race.Life then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local objKey = GetObjKey(owner);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local actions = {};
	local _, reasons = AddActionCost(actions, owner, owner.MaxCost, true);
	if owner.Cost < owner.MaxCost then
		ds:UpdateBattleEvent(objKey, 'AddCost', { CostType = owner.CostType.name, Count = owner.MaxCost - owner.Cost });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 예측불허
function Mastery_Unpredictability_UnitKilled(eventArg, mastery, owner, ds)
	local damageFlag = SafeIndex(eventArg, 'DamageInfo', 'Flag');
	if not table.exist({'Retribution', 'Devastate', 'Forestallment', 'Counter'}, function(flag) return SafeIndex(damageFlag, flag) ~= nil; end) then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	local actions = {};
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount3, ds, 'Friendly');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 맹독술사
function Mastery_Poisonmage_UnitKilled(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or #GetBuffType(eventArg.Unit, nil, nil, mastery.BuffGroup.name) == 0
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	local actions = {};
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount2);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 프로그래머
function Mastery_Programmer_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	AddSPPropertyActionsObject(actions, owner, math.floor(mastery.CustomCacheData / mastery.ApplyAmount) * mastery.ApplyAmount, true, ds, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 자동 재정비
function Mastery_Module_AutoReload_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.CountChecker < 1 then
		return;
	end
	
	mastery.CountChecker = 0;
	local actions = {};
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
	AddActionCostForDS(actions, owner, -mastery.ApplyAmount2, true, nil, ds);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	-- 자율 행동 강화 프로그램
	local mastery_Module_AutoAction = GetMasteryMastered(GetMastery(owner), 'Module_AutoAction');
	if mastery_Module_AutoAction then
		AddActionApplyActForDS(actions, owner, -mastery_Module_AutoAction.ApplyAmount2, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_Module_AutoAction, owner, 'UnitKilled_Self');
	end
	return unpack(actions);
end
-- 특성 : 희열
function Mastery_Catharsis_UnitKilled(eventArg, mastery, owner, ds)
	if eventArg.Killer ~= owner 
		or eventArg.Unit == owner
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local objKey = GetObjKey(owner);
	local masteryEventID = ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	local look = ds:LookPos(objKey, GetPosition(eventArg.Unit));
	local aniID = ds:PlayAni(objKey, 'Catharsis', false, -1, true);
	ds:Connect(aniID, look, -1);
	ds:Connect(masteryEventID, aniID, 0);
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitDead'});
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 일찍 나는 새
function Mastery_EarlyBird_UnitKilled(eventArg, mastery, owner, ds)
	if eventArg.Unit == owner
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local tmGrade = eventArg.Unit.TroublemakerGradeMap[GetTeam(owner)];
	if tmGrade == nil or tmGrade < 7 then
		return;
	end
	
	local actions = {};
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount3);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 나는 전설이다
function Mastery_ImLegend_UnitKilled(eventArg, mastery, owner, ds)
	if not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'CloseCheckFire') then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	local actions = {};
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount, ds, 'Friendly');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 내 꿈은 히어로
function Mastery_MyDreamIsHero_UnitKilled(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or not HasBuff(owner, mastery.Buff.name)
		or eventArg.Unit.Affiliation.Type ~= 'Crime'
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	if RandomTest(100 - mastery.ApplyAmount) then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
	return Mastery_MyDreamIsHero_ActivatePositiveEffect(mastery, owner, ds);
end
-- 기회 창출
function Mastery_OpportunityCreation_UnitKilled(eventArg, mastery, owner, ds)
	local dead = eventArg.Unit;
	
	local mastery_BattleOwner = GetMasteryMastered(GetMastery(owner), 'BattleOwner');
	local enemyApplied = false;
	local actions = {};
	for _, o in ipairs(GetNearObject(dead, mastery.ApplyAmount)) do	-- 1칸이 8칸이라고 해서..
		local applyAct = nil;
		if IsTeamOrAlly(owner, o) then
			applyAct = -mastery.ApplyAmount2;
		elseif IsEnemy(owner, o) and mastery_BattleOwner then
			applyAct = mastery_BattleOwner.ApplyAmount2;
			enemyApplied = true;
		end
		
		if applyAct then
			local added, reasons = AddActionApplyAct(actions, owner, o, applyAct, 'Friendly');
			if added then
				ds:UpdateBattleEvent(GetObjKey(o), 'AddWait', { Time = applyAct, Delay = true });
			end
			ReasonToUpdateBattleEventMulti(o, ds, reasons);
		end
	end
	if #actions == 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	if enemyApplied then
		MasteryActivatedHelper(ds, mastery_BattleOwner, owner, 'UnitKilled_Self');
	end
	return unpack(actions);
end
-- 명군사
function Mastery_GreatMilitaryAffair_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	
	MasteryActivatedHelper(ds, GetMasteryMastered(GetMastery(owner), 'Ambush'), owner, 'UnitKilled_Self');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	local actions = {};
	AddActionRestoreActions(actions, owner);
	mastery.CountChecker = 0;
	return unpack(actions);
end
-- 연계된 화공, 연계된 뇌공
function Mastery_ChainConfusionTactics_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	MasteryActivatedHelper(ds, GetMasteryMastered(GetMastery(owner), 'Ambush'), owner, 'UnitKilled_Self');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	local actions = {};
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount2);
	mastery.CountChecker = 0;
	return unpack(actions);
end
-- 달빛 사냥꾼
function Mastery_MoonHunter_UnitKilled(eventArg, mastery, owner, ds)
	if mastery.CountChecker <= 0 then
		return;
	end
	if not IsDarkTime(GetMission(owner).MissionTime.name) then
		return;
	end
	
	MasteryActivatedHelper(ds, GetMasteryMastered(GetMastery(owner), 'Ambush'), owner, 'UnitKilled_Self');
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self');
	local actions = {};
	AddActionRestoreActions(actions, owner);
	mastery.CountChecker = 0;
	return unpack(actions);
end
-- 정의를 위한 승리의 검
--  성검: 범죄 조직 소속인 적이 $Dead$이 되면, 기력이 10 회복됩니다.
--  성검: 범죄 조직 소속인 적이 $Dead$이 되면, SP가 10 상승합니다.
function Mastery_VictorySword_UnitKilled(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or eventArg.Unit.Affiliation.Type ~= 'Crime'
		or mastery.DuplicateApplyChecker > 0 then
		return;
	end
	
	local actions = {};
	local result, reasons = AddActionCost(actions, owner, mastery.ApplyAmount2, true);
	ds:UpdateBattleEvent(GetObjKey(owner), 'AddCost', { CostType = owner.CostType.name, Count = result - owner.Cost });
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount2, true, ds, true);
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled');
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 난 이미 알고있다.
function Mastery_AlreadyIknow_UnitKilled(eventArg, mastery, owner, ds)
	if not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'ReactionAbility') then
		return;
	end
	if eventArg.DamageInfo.damage_type ~= 'Ability' then
		return;
	end
	local ability = eventArg.DamageInfo.damage_invoker;
	if not ability or ability.HitRateType == 'Melee' then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount2, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -1 * mastery.ApplyAmount2, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self', false);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 처형인
function Mastery_Executioner_UnitKilled(eventArg, mastery, owner, ds)
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount2, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -1 * mastery.ApplyAmount2, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self', false);
	return unpack(actions);
end
-- 일기당천
function Mastery_MatchlessWarrior_UnitKilled(eventArg, mastery, owner, ds)
	if not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'Counter') 
		and not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'Forestallment') then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount2, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', { Time = -1 * mastery.ApplyAmount2, Delay = true });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self', false);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 제압
function Mastery_Overpower_UnitKilled(eventArg, mastery, owner, ds)
	if not SafeIndex(eventArg, 'DamageInfo', 'Flag', 'Forestallment') then
		return;
	end
	if mastery.DuplicateApplyChecker > 0 then
		return;
	end
	local actions = {};
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount2, true, ds, true);

	-- 제압의 기선제압 활성화 기능이 발동했다고 혼란을 줄 수 있으므로, 일단 여기서는 표시를 하지 말자.
--	MasteryActivatedHelper(ds, mastery, owner, 'UnitKilled_Self', false);
	mastery.DuplicateApplyChecker = 1;
	return unpack(actions);
end
-- 정절의 기백
function Mastery_OverchargeSpirit_UnitKilled(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit) then
		return;
	end
	if owner.Overcharge <= 0 then
		return;
	end
	mastery.CountChecker = 	mastery.CountChecker + 1;
end
-- 정절의 기백
function Mastery_OverchargeSpirit_OverchargeEnded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if mastery.CountChecker <= 0 then
		return;
	end
	local actions = {};
	local addSP = mastery.CountChecker;
	MasteryActivatedHelper(ds, mastery, owner, 'OverchargeEnded');
	AddSPPropertyActions(actions, owner, owner.ESP.name, addSP, true, ds, true);
	mastery.CountChecker = 0;
	return unpack(actions);
end
-- 마력 회수
function Mastery_SpellPowerReturn_AbilityUsed(eventArg, mastery, owner, ds)
	if eventArg.Ability.Type ~= 'Attack' or not IsGetAbilitySubType(eventArg.Ability, 'ESP') then
		return;
	end
	local spellPower = GetBuff(owner, mastery.Buff.name);
	if spellPower == nil then
		return;
	end
	local hasAnyMeleeEnemy = HasAnyAbilityUsingInfo({eventArg.PrimaryTargetInfos, eventArg.SecondaryTargetInfos}, function (targetInfo)
		return IsEnemy(owner, targetInfo.Target) and IsMeleeDistanceAbility(owner, targetInfo.Target);
	end);
	if not hasbit(spellPower.DuplicateApplyChecker, bit(2)) then
		spellPower.DuplicateApplyChecker = spellPower.DuplicateApplyChecker + bit(2);
	end
	local actions = {};
	local mastery_SpellConverter = GetMasteryMastered(GetMastery(owner), 'SpellConverter');
	if mastery_SpellConverter and hasAnyMeleeEnemy and spellPower.Lv >= 2 then
		local addHP = owner.MaxHP * math.floor(spellPower.Lv / 2) * mastery_SpellConverter.ApplyAmount2/100;
		local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		MasteryActivatedHelper(ds, mastery_SpellConverter, owner, 'AbilityUsed_Self');
		DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false); 
	end
	return unpack(actions);
end
-------------------------------------------------------------------------------------------
-- 프로퍼티 갱신됨 [UnitPropertyUpdated]
-------------------------------------------------------------------------------------------
-- 심해 탈출
function Mastery_DeepseaEscape_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.PropertyName ~= 'Act' then
		return;
	end
	local applyAmount = mastery.ApplyAmount;
	-- 더는 기다릴 수 없어.
	local mastery_ICanNotWait = GetMasteryMastered(GetMastery(owner), 'ICanNotWait');
	if mastery_ICanNotWait then
		applyAmount = mastery_ICanNotWait.ApplyAmount;
	end
	if tonumber(eventArg.Value) < applyAmount then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitPropertyUpdated_Self', true);
	table.insert(actions, Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true));
	-- 더는 기다릴 수 없어.
	if mastery_ICanNotWait then
		MasteryActivatedHelper(ds, mastery_ICanNotWait, owner, 'UnitPropertyUpdated_Self', true);
		if owner.Overcharge > 0 then
			table.insert(actions, Result_PropertyUpdated('Overcharge', owner.OverchargeDuration, owner, false, true));
		else
			AddSPPropertyActions(actions, owner, owner.ESP.name, owner.MaxSP - owner.SP, true, ds, true);
		end
	end
	return unpack(actions);
end
-- 호환성 증가 - 지연 복구
function Mastery_MachineUnique_Waiting_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.PropertyName ~= 'Act'
		or tonumber(eventArg.Value) < mastery.ApplyAmount then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'UnitPropertyUpdated_Self', true);
	return Result_PropertyUpdated('Act', -owner.Speed, nil, nil, true);
end
-- 빗나간 죽음
function Mastery_LuckyCheatDeath_UnitPropertyUpdated(eventArg, mastery, owner, ds)
	if eventArg.PropertyName ~= 'Overcharge' then
		return;
	end
	local curValue = tonumber(eventArg.Value);
	local prevValue = GetInstantProperty(owner, 'PrevOvercharge') or 0;
	SetInstantProperty(owner, 'PrevOvercharge', curValue);
	if curValue <= 0 or curValue <= prevValue then
		return;
	end
	local adjustValue = GetInstantProperty(owner, mastery.name) or 0;
	adjustValue = adjustValue + mastery.ApplyAmount2;
	SetInstantProperty(owner, mastery.name, adjustValue);
end
----------------------------------- End of EventHandler ------------------------------------
-- DB에는 존재하지 않을 수 있으나 무조건 기본으로 들고 들어갈 마스터리 설정
function GetBaseMastery_PC(obj) -- Pc.Object
	local list = SetBasicMasteries(obj, true);
	-- 1. 회사 선택 특성.
	local company = GetCompany(obj);
	if company == nil then
		LogAndPrint('GetBaseMastery_PC', 'ERROR! No company');
		Traceback();
	elseif company.CompanyMastery ~= 'None' then
		local curCompnayMastery = company.CompanyMasteries[company.CompanyMastery];
		if curCompnayMastery.Opened then
			list[company.CompanyMastery] = 1;
		end
	end
	-- 2. 개인 선택 특성.
	local roster = GetRosterFromObject(obj)
	if roster and roster.BasicMastery ~= 'None' then
		list[roster.BasicMastery] = 1;
	end
	if roster and roster.RosterType == 'Pc' then
		local fixedMastery = GetWithoutError(roster, 'FixedMastery');
		if fixedMastery then
			for i = 1, #fixedMastery do
				local fixedMasteryName = fixedMastery[i];
				list[fixedMasteryName] = 1;
			end
		end
	end
	if roster and roster.RosterType == 'Beast' then
		for i = 1, roster.BeastType.EvolutionMaxStage do
			local evolutionMastery = GetWithoutError(roster, string.format('EvolutionMastery%d', i));
			if evolutionMastery and evolutionMastery ~= 'None' then
				list[evolutionMastery] = i;
			end
		end
	end
	if roster and roster.RosterType == 'Machine' then
		if roster.OSType ~= 'None' then
			list[roster.OSType] = 1;
		end
		if roster.CraftMastery ~= 'None' then
			list[roster.CraftMastery] = 1;
		end
		for i = 1, 3 do
			local upgradeMastery = GetWithoutError(roster, string.format('AIUpgradeMastery%d', i));
			if upgradeMastery and upgradeMastery ~= 'None' then
				list[upgradeMastery] = i + 1;
			end
		end
	end
	return list;
end
-------------------------------------------------------------------------------
-- 필드 이펙트 추가
-------------------------------------------------------------------------------
function Mastery_FlammableObject_FieldEffectAdded(eventArg, mastery, owner, ds)
	local fieldCls = GetClassList('FieldEffect')[eventArg.FieldEffectType];
	for _, affector in ipairs(fieldCls.BuffAffector) do
		if affector.ApplyBuff.name ~= 'Burn' then
			return;
		end
	end
	
	if not PositionInRange( eventArg.PositionList, GetPosition(owner)) then
		return;
	end
	
	return Result_Damage(owner.HP, 'Normal', 'Hit', owner, owner, 'Ability', 'Fire', mastery);
end
function Mastery_ShockableObject_FieldEffectAdded(eventArg, mastery, owner, ds)
	local fieldCls = GetClassList('FieldEffect')[eventArg.FieldEffectType];
	for _, affector in ipairs(fieldCls.BuffAffector) do
		if affector.ApplyBuff.name ~= 'ElectricShock' then
			return;
		end
	end
	
	if not PositionInRange( eventArg.PositionList, GetPosition(owner)) then
		return;
	end
	
	return Result_Damage(owner.HP, 'Normal', 'Hit', owner, owner, 'Ability', 'Lightning', mastery);
end
function Mastery_WebTailor_FieldEffectAdded(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner then
		return;
	end
	local isTargetFieldEffect = false;
	local fieldCls = GetClassList('FieldEffect')[eventArg.FieldEffectType];
	for _, affector in ipairs(fieldCls.BuffAffector) do
		if affector.ApplyBuff.name == mastery.Buff.name then
			isTargetFieldEffect = true;
			break;
		end
	end	
	if not isTargetFieldEffect then
		return;
	end
	local fieldEffectCount = #eventArg.PositionList;
	-- 이동 중엔 카운팅만 한다.
	if mastery.DuplicateApplyChecker > 0 then
		local prevCount = GetInstantProperty(owner, mastery.name) or 0;
		local newCount = prevCount + fieldEffectCount;
		SetInstantProperty(owner, mastery.name, newCount);
		return;
	end
	local stepCount = math.floor(fieldEffectCount / mastery.ApplyAmount);	-- ApplyAmount 당
	if stepCount <= 0 then
		return;
	end
	local applyAct = -1 * stepCount * mastery.ApplyAmount2;			-- ApplyAmount2 만큼 감소
	
	local actions = {};
	local ownerKey = GetObjKey(owner);
	MasteryActivatedHelper(ds, mastery, owner, 'FieldEffectAdded');
	local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
	if added then
		ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	return unpack(actions);
end
-- 업화
function Mastery_Hellfire_FieldEffectAdded(eventArg, mastery, owner, ds)
	if eventArg.Giver ~= owner
		or eventArg.FieldEffectType ~= 'Fire'
		or SafeIndex(eventArg.ActionInfo, 'invoke_type') ~= 'Ability'
		or owner.CostType.name ~= 'Vigor' then
		return;
	end
	local fieldEffectCount = #eventArg.PositionList;
	if fieldEffectCount == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'FieldEffectAdded');
	AddActionCostForDS(actions, owner, fieldEffectCount, true, nil, ds);
	return unpack(actions);
end
-------------------------------------------------------------------------------
-- 유닛 위치 변화 [UnitPositionChanged]
-------------------------------------------------------------------------------
-- 기선 제압
function Mastery_Forestallment_UnitPositionChanged(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0 
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or mastery.DuplicateApplyChecker > 0
		or owner.IsMovingNow > 0
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or not IsMeleeDistance(GetPosition(owner), eventArg.Position)
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or eventArg.Blink 
		or eventArg.NoEvent then
		return;
	end
	local mission = GetMission(owner);
	local alreadyObj = GetObjectByPosition(mission, eventArg.Position);
	if alreadyObj ~= nil and alreadyObj ~= eventArg.Unit then
		-- 이 위치에 이미 누군가 있어!
		return;
	end
	
	local overwatch = FindAbility(owner, owner.OverwatchAbility);
	if overwatch == nil or overwatch.HitRateType ~= 'Melee' then
		return;
	end
	local rangeClsList = GetClassList('Range');
	local range = CalculateRange(owner, overwatch.TargetRange, GetPosition(owner));
	local p = eventArg.Position;
	if PositionInRange(range, p) then
		local targetKey = GetObjKey(eventArg.Unit);
		local eventCmd = ds:SubscribeFSMEvent(targetKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos=p}, true, true);
		if eventArg.MoveID and ds:GetRefID(eventArg.MoveID) ~= eventArg.MoveID then
			ds:Connect(eventCmd, eventArg.MoveID, 0);		-- 루프를 만들어서 교체를 시키려고
			ds:Connect(eventArg.MoveID, eventCmd, 0);
		else
			ds:SetConditional(eventCmd);
		end
		
		local chatID = ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = GetObjKey(owner), MasteryType = mastery.name, EventType = 'UnitMovedSingleStep'});
		ds:Connect(chatID, eventCmd, -1);		
		local hitCount = eventArg.OverwatchHitCount or 0;
		local battleEvents = {{Object = owner, EventType = mastery.name}};
		local targetPos = GetPosition(eventArg.Unit);
		local abilityAction = Result_UseAbilityTarget(owner, owner.OverwatchAbility, eventArg.Unit, {ReactionAbility=true, Forestallment=true, Moving=true, BattleEvents = battleEvents}, true, {NoCamera = true, Preemptive=true, PreemptiveOrder = hitCount});
		mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
		abilityAction.nonsequential = true;
		abilityAction.free_action = true;
		abilityAction._ref = eventCmd;
		abilityAction._ref_offset = -1;
		abilityAction.final_useable_checker = function()
			return GetBuffStatus(owner, 'Attackable', 'And')
				and PositionInRange(CalculateRange(owner, overwatch.TargetRange, GetPosition(owner)), eventArg.Position);
		end;
		eventArg.OverwatchHitCount = hitCount + 1;
		return abilityAction;
	end
end
-- 자동 제압 사격
function Mastery_Module_ForestallmentFire_UnitPositionChanged(eventArg, mastery, owner, ds)
	local applyDist = mastery.ApplyAmount;
	if applyDist == 1 then
		applyDist = 1.4;
	end
	if eventArg.Unit.HP <= 0 
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy'
		or mastery.DuplicateApplyChecker > 0
		or owner.IsMovingNow > 0
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= (applyDist + 0.4)
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or eventArg.Blink then
		return;
	end
	return Mastery_Module_ForestallmentFire_TestMoveStep(eventArg, mastery, owner, ds);
end
-- 근접 제압 사격
function Mastery_CloseCheckFire_UnitPositionChanged(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= (mastery.ApplyAmount + 0.4)
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or eventArg.Blink then
		return;
	end
	return Mastery_CloseCheckFire_TestMoveStep(eventArg, mastery, owner, ds);
end
-- 자동 반응 사격
function Mastery_Module_CloseCheckFire_UnitPositionChanged(eventArg, mastery, owner, ds)
	if eventArg.Unit.HP <= 0
		or GetRelation(owner, eventArg.Unit) ~= 'Enemy' 
		or eventArg.Unit.Cloaking
		or not owner.TurnState.TurnEnded 
		or GetDistance3D(GetPosition(owner), eventArg.Position) >= (mastery.ApplyAmount + 0.4)
		or not GetBuffStatus(owner, 'Attackable', 'And')
		or eventArg.Blink then
		return;
	end
	return Mastery_Module_CloseCheckFire_TestMoveStep(eventArg, mastery, owner, ds);
end
-------------------------------------------------------------------------------
-- 기타 이벤트
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
--- 해킹
function Mastery_SurveillanceNetworking_HackingOccured(eventArg, mastery, owner, ds)
	local command = eventArg.Success and 'Converted' or 'Alert';
	
	local actions = {Result_FireWorldEvent('WatchtowerControl', {Commander = owner, Command = command, Hacker = eventArg.Hacker})};
	if eventArg.Success then
		table.insert(actions, Result_ChangeTeam(owner, GetTeam(eventArg.Hacker)));
	else
		local hackerKey = GetObjKey(eventArg.Hacker);
		ds:UpdateBattleEvent(hackerKey, 'GetWord', { Color = 'Red', Word = 'Detected' });
		ds:AlertScreenEffect(hackerKey);
	end
	return unpack(actions);
end
-- 격앙
function Mastery_Excitement_ActionPointRestored(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	
	local actions = {}
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	MasteryActivatedHelper(ds, mastery, owner, 'ActionPointRestored', nil);
	return unpack(actions);
end
---------------------------------------------------------------------------------
-- [ActionCostAdded]
---------------------------------------------------------------------------------
-- 연료 제어
function Mastery_Application_FuelControl_ActionCostAdded(eventArg, mastery, owner, ds)
	if eventArg.AddAmount >= 0 then
		return;
	end
	
	local actions = {};
	local restoreAct = mastery.ApplyAmount2 * math.floor(-eventArg.AddAmount / mastery.ApplyAmount);
	if restoreAct > 0 then
		AddActionApplyActForDS(actions, owner, -restoreAct, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery, owner, 'ActionCostAdded');
	end
	return unpack(actions);
end
-- 독립형 OS
function Mastery_MacOS_ActionCostAdded(eventArg, mastery, owner, ds)
	if eventArg.AddAmount <= 0 then
		return;
	end
	
	local actions = {};
	local restoreAct = math.min(mastery.ApplyAmount, eventArg.AddAmount);
	if restoreAct > 0 then
		AddActionApplyActForDS(actions, owner, -restoreAct, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery, owner, 'ActionCostAdded');
	end
	return unpack(actions);
end
-- 자폭
function Mastery_Module_Suicide_ActionCostAdded(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker > 0
		or owner.Cost > 0 then
		return;
	end
	
	mastery.DuplicateApplyChecker = 1;
	local actions = {};
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	return unpack(actions);
end
function Mastery_Fuel_ActionCostAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.AddAmount == 0 then
		return;
	end
	
	local actions = {};
	local buff = GetBuff(owner, mastery.Buff.name)
	
	if owner.Cost == 0 and buff == nil then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1);
	elseif owner.Cost > 0 and buff ~= nil then
		InsertBuffActions(actions, owner, owner, mastery.Buff.name, -1 * buff.Lv);
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- [ChainEffectOccured]
--------------------------------------------------------------------------------
-- 사냥꾼과 사냥개
function Mastery_HunterAndHuntingDog_ChainEffectOccured(eventArg, mastery, owner, ds)
	-- 어빌리티 사용 중에만 발동
	if mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	if GetInstantProperty(eventArg.Trigger, 'SummonMaster') ~= GetObjKey(owner) then
		return;
	end
	if mastery.CountChecker > 0 then
		return;
	end	
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'ChainEffectOccured');
	AddActionApplyActForDS(actions, owner, -mastery.ApplyAmount2, ds, 'Friendly');
	mastery.CountChecker = 1;
	return unpack(actions);
end
-- 연환계
function Mastery_ChainTactics_ChainEffectOccured(eventArg, mastery, owner, ds)
	-- 어빌리티 사용 중에만 발동
	if mastery.DuplicateApplyChecker <= 0 then
		return;
	end
	local trigger = eventArg.Trigger;
	if GetMasteryMastered(GetMastery(trigger), 'TrapSystem') then
		trigger = GetExpTaker(trigger);
	end
	if trigger ~= owner then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'ChainEffectOccured');
	
	local hasteAmount = mastery.ApplyAmount;	
	local mastery_GreatMilitaryAffairs = GetMasteryMastered(GetMastery(owner), 'GreatMilitaryAffairs');
	if mastery_GreatMilitaryAffairs then
		hasteAmount = hasteAmount + mastery_GreatMilitaryAffairs.ApplyAmount;
		MasteryActivatedHelper(ds, mastery_GreatMilitaryAffairs, owner, 'ChainEffectOccured');
	end
	
	-- 설계된 함정
	local mastery_TrapDesign = GetMasteryMastered(GetMastery(owner), 'TrapDesign');
	if mastery_TrapDesign then
		MasteryActivatedHelper(ds, mastery_TrapDesign, owner, 'ChainEffectOccured');
	end
	
	for _, obj in ipairs(GetNearObject(owner, mastery.ApplyAmount2 + 0.4)) do
		if IsTeamOrAlly(owner, obj) then
			AddActionApplyActForDS(actions, obj, -hasteAmount, ds, 'Friendly');
		end
	end
	if mastery_TrapDesign then
		for _, obj in ipairs(GetNearObject(eventArg.Unit, mastery_TrapDesign.ApplyAmount + 0.4)) do
			if IsEnemy(owner, obj) then
				AddActionApplyActForDS(actions, obj, mastery_TrapDesign.ApplyAmount2, ds, 'Hostile');
			end
		end
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- [HackingSucceeded]
--------------------------------------------------------------------------------
function Mastery_Genius_HackingSucceeded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local abilityName = SafeIndex(eventArg, 'Ability', 'name');
	if abilityName ~= 'HackingProtocol' then
		return;
	end
	-- 사용 횟수 제한이 있는 모든 프로토콜 어빌리티 (UseCount가 MaxUseCount 이상이면 무시)
	local abilityList = GetAllAbility(owner);
	abilityList = table.filter(abilityList, function(ability)
		return IsProtocolAbility(ability) and ability.IsUseCount and ability.AutoUseCount and ability.UseCount < ability.MaxUseCount;
	end);
	if #abilityList == 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'HackingSucceeded');
	-- 사용 횟수 제한이 있는 모든 프로토콜 어빌리티 UseCount 증가 (MaxUseCount를 넘기지는 않음)
	for _, ability in ipairs(abilityList) do
		local newCount = math.min(ability.UseCount + mastery.ApplyAmount2, ability.MaxUseCount);
		UpdateAbilityPropertyActions(actions, owner, ability.name, 'UseCount', newCount);
	end
	return unpack(actions);
end
---------------------------------------------------------------------------------
-- 데미지 컨베이어
---------------------------------------------------------------------------------
function DamageConveyor_FlammableObject(owner, mastery, damage, damageBase, damageInfo, test)
	if damageBase <= 0 then
		return damage;
	end
	if damageInfo.damage_sub_type == 'Ice' then
		return 0;	-- 빙결 데미지는 안들어감
	elseif damageInfo.damage_sub_type == 'Fire' or damageInfo.damage_sub_type == 'Lightning' or (damageInfo.damage_invoker and damageInfo.damage_invoker.name == 'FragGrenade') then
		return owner.HP;
	end
	return damage;
end
function DamageConveyor_Amulet_Guardian(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_Amulet_Scourge(owner, mastery, damage, damageBase, damageInfo, test)
	local scorgeAbil = FindAbility(owner, 'Potion_Scourge');
	if not scorgeAbil or mastery.CountChecker >= scorgeAbil.UseCount then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.CountChecker = mastery.CountChecker + 1;
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_SandCastle(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
			if damageInfo.damage_type == 'Ability' then
				AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			end
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_Amulet_Hunter(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker > 0 then
		return damage;
	end
	
	if damage > 0 then
		if not test then
			mastery.DuplicateApplyChecker = 1;
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	end
	
	return damage;
end
function DamageConveyor_Module_MachineFury(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker > 0 then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP and GetBuff(owner, 'Shutdown') == nil then
		if not test then
			mastery.DuplicateApplyChecker = 1;
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			AddBattleEvent(owner, 'BuffInvokedFromAbility', {Buff = mastery.Buff.name, EventType = 'FirstHit'});
		end
		return owner.HP - 1, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_HungryWolf(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker > 0 then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = 1;
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			AddBattleEvent(owner, 'GetWordCustomEvent', {Word = 'HungryWolf_GetBack', EventType = 'FirstHit', Color = 'Yellow'});
			AddBattleEvent(owner, 'BuffInvokedFromAbility', {Buff = mastery.Buff.name, EventType = 'FirstHit'});
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
function DamageConveyor_FightAgainstFate(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker >= mastery.ApplyAmount then
		return damage;
	end
	-- 데미지로 죽을 것 같으면
	if damage >= owner.HP then
		if not test then
			mastery.DuplicateApplyChecker = mastery.DuplicateApplyChecker + 1;
			SetInstantProperty(owner, mastery.name, true);
		end
		if damageInfo.damage_type == 'Ability' and not test then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
			AddBattleEvent(owner, 'BuffInvokedFromAbility', {Buff = mastery.Buff.name, EventType = 'FirstHit'});
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 특수 장갑
function DamageConveyor_Module_HardArmor(owner, mastery, damage, damageBase, damageInfo, test)
	local testHP = math.floor(owner.MaxHP * mastery.ApplyAmount / 100);
	if damage > 0 and damage < testHP and owner.Cost >= mastery.ApplyAmount2 then
		if not test then
			SetInstantProperty(owner, mastery.name, true);
		end
		if damageInfo.damage_type == 'Ability' then
			AddMasteryInvokedEvent(owner, mastery.name, 'FirstHit');
		end
		return 0, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
	else
		return damage;
	end
end
-- 동족 포식
function DamageConveyor_Cannibalization(owner, mastery, damage, damageBase, damageInfo, test)
	if mastery.DuplicateApplyChecker > 0 
		or damage <= owner.HP 
		or damageInfo.damage_type == 'System'
		or GetBuffStatus(owner, 'Unconscious', 'Or') then
		return damage;
	end
	
	if not test then
		mastery.DuplicateApplyChecker = 1;
		SetInstantProperty(owner, 'Undead', true);
	end
	return owner.HP - 1, {Type = mastery.name, Value = true, ValueType = 'Mastery'};
end
---------------------------------------------------------------------------------
-- 과충전 해제
---------------------------------------------------------------------------------
--- 재정비
function Mastery_Rearrange_OverchargeEnded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end

	local actions = {};
	
	local addSP = mastery.ApplyAmount;
	local objKey = GetObjKey(owner);
	
	-- 각성
	local masteryTable = GetMastery(owner);
	local mastery_Awakening = GetMasteryMastered(masteryTable, 'Awakening');
	if mastery_Awakening then
		addSP = addSP + mastery_Awakening.ApplyAmount2;
	end
	
	AddSPPropertyActions(actions, owner, owner.ESP.name, addSP, true, ds, true);
	ds:UpdateBattleEvent(objKey, 'MasteryInvoked', { Mastery = mastery.name });
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEvent', {ObjectKey = objKey, MasteryType = mastery.name, EventType = 'OverchargeEnded'});
	
	return unpack(actions);
end
-- 불꽃의 군주
function Mastery_LordOfFlame_OverchargeEnded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 꺼지지 않는 불꽃
	local masteryTable = GetMastery(owner);
	local mastery_EternalFlame = GetMasteryMastered(masteryTable, 'EternalFlame');
	if not mastery_EternalFlame then
		return;
	end
	local actions = {};
	local addSP = mastery.ApplyAmount;
	MasteryActivatedHelper(ds, mastery, owner, 'OverchargeEnded');
	MasteryActivatedHelper(ds, mastery_EternalFlame, owner, 'OverchargeEnded');
	AddSPPropertyActions(actions, owner, owner.ESP.name, addSP, true, ds, true);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 버프 추가 [BuffAdded]
----------------------------------------------------------------------------
-- 숙면
function Mastery_DeepSleep_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	SetInstantProperty(owner, 'DeepSleep_ExpCache_'..eventArg.Buff.name, {Lv = owner.Lv, Exp = owner.Exp, JobLv = owner.JobLv, JobExp = owner.JobExp});
end
-- 함정 시스템
function Mastery_TrapSystem_BuffAdded(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker > 0 
		or not owner.Detected then
		return;
	end
	mastery.DuplicateApplyChecker = 1;
	local ownerCamMove = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false, false, 0.5);
	local detectMessage = ds:UpdateBattleEvent(GetObjKey(owner), 'GetWordAliveOnly', { Color = 'Red', Word = 'Detected' });
	ds:Connect(detectMessage, ownerCamMove, 0.25);
end
-- 나의 꿈은 히어로
function Mastery_MyDreamIsHero_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.BuffName ~= mastery.Buff.name then
		return;
	end
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	local buff = goodBuffPicker:PickBuff();
	if buff == nil then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff, 1);
	return unpack(actions);
end
-- 꼭꼭 숨어라
function Mastery_HideHide_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.BuffName ~= 'Conceal' and eventArg.BuffName ~= 'Conceal_For_Aura' then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	local actions = {};
	local added, reasons = AddActionApplyAct(actions, owner, owner, -mastery.ApplyAmount, 'Friendly');
	if added then
		ds:UpdateBattleEvent(GetObjKey(owner), 'AddWait', {Time = -mastery.ApplyAmount, Delay = true});
	end
	ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	
	return unpack(actions);
end
-- 행운의 여신
function Mastery_GoddessOfFortune_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.BuffName ~= mastery.Buff.name then
		return;
	end
	
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	local buff = goodBuffPicker:PickBuff();
	if buff == nil then
		return;
	end
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff, 1);
	return unpack(actions);
end
-- 기만
function Mastery_Subterfuge_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if eventArg.Buff.Type ~= 'Buff' and eventArg.Buff.Type ~= 'Debuff' then
		return;
	end
	if eventArg.Buff.SubType ~= 'Physical' and eventArg.Buff.SubType ~= 'Mental' then
		return;
	end
	-- 1턴 이하의 디버프에는 적용되지 않음
	if eventArg.Buff.Type == 'Debuff' and eventArg.Buff.Turn <= 1 then
		return;
	end
	local addTurn = 1;
	if eventArg.Buff.Type == 'Debuff' then
		addTurn = -1;
	end
	local actions = {};
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	return unpack(actions);
end
-- 자가 면역
function Mastery_Autoimmunity_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if eventArg.Buff.Type ~= 'Debuff' then
		return;
	end
	if eventArg.Buff.SubType ~= 'Physical' and eventArg.Buff.SubType ~= 'Mental' then
		return;
	end
	-- 1턴 이하의 디버프에는 적용되지 않음
	if eventArg.Buff.Turn <= 1 then
		return;
	end
	local addTurn = -1 * math.max(1, math.round(eventArg.Buff.Turn * mastery.ApplyAmount2 / 100));
	local actions = {};
	table.insert(actions, Result_BuffPropertyUpdated('Turn', eventArg.Buff.Turn + addTurn, owner, eventArg.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', eventArg.Buff.Life + addTurn, owner, eventArg.Buff.name, true, true));
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded_Self');
	return unpack(actions);
end
-- 살수의 인장
function Mastery_Amulet_Killer_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	if eventArg.Unit ~= owner
		or eventArg.Buff.name ~= mastery.Buff.name
		or mastery.DuplicateApplyChecker > 1 then
		return;
	end
	local actions = {};
	table.insert(actions, Result_BuffPropertyUpdated('IsTurnShow', false, owner, mastery.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Turn', 99999, owner, mastery.Buff.name, false, true));
	table.insert(actions, Result_BuffPropertyUpdated('Life', 99999, owner, mastery.Buff.name, true, true));
	return unpack(actions);
end
-- 보호색
function Mastery_ProtectiveColoration_BuffAdded(eventArg, mastery, owner, ds)
	if not IsEnemy(owner, eventArg.Unit)
		or GetDistance3D(GetPosition(owner), GetPosition(eventArg.Unit)) > mastery.ApplyAmount + 0.4
		or eventArg.Buff.Type ~= 'Buff'
		or (eventArg.Buff.SubType ~= 'Physical' and eventArg.Buff.SubType ~= 'Mental') then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	InsertBuffActions(actions, owner, owner, eventArg.Buff.name, 1, true);
	return unpack(actions);
end
-- 광기의 희열
function Mastery_CatharsisOfRage_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Buff.Group ~= 'Rage' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	AddAbilityCoolActions(actions, owner, -mastery.ApplyAmount);
	
	local mastery_LastBerserker = GetMasteryMastered(GetMastery(owner), 'LastBerserker');
	if mastery_LastBerserker and (owner.CostType.name == 'Vigor' or owner.CostType.name == 'Rage') then
		AddActionCostForDS(actions, owner, mastery_LastBerserker.ApplyAmount3, true, nil, ds);
		MasteryActivatedHelper(ds, mastery_LastBerserker, owner, 'BuffAdded');
	end
	
	return unpack(actions);
end
-- 좋은 꿈은 전파된다.
function Mastery_DreamDistribute_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Buff.Type ~= 'Buff'
		or (eventArg.Buff.SubType ~= 'Physical' and eventArg.Buff.SubType ~= 'Mental')
		or not HasBuffType(owner, nil, nil, 'Sleep') then
		return;
	end
	-- 연쇄 발동 방지
	local buffInvoker = SafeIndex(eventArg, 'Invoker');
	if buffInvoker and buffInvoker.Type == 'Mastery' and buffInvoker.Value == mastery.name then
		return;
	end
	local mission = GetMission(owner);
	local teamUnits = GetTeamUnits(mission, GetTeam(owner));
	teamUnits = table.filter(teamUnits, function(target)
		return target ~= owner and GetBuff(target, eventArg.Buff.name) == nil;
	end);
	if #teamUnits == 0 then
		return;
	end
	local target = teamUnits[math.random(1, #teamUnits)];
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffAdded');
	InsertBuffActions(actions, owner, target, eventArg.Buff.name, 1, true, nil, nil, {Type = 'Mastery', Value = mastery.name});
	return unpack(actions);
end
-- 화공
function Mastery_ConfusionTactics_BuffAdded(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker < 0
		or not IsEnemy(owner, eventArg.Unit)
		or eventArg.Buff.Type ~= 'Debuff'
		or eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	local buffInvoker = SafeIndex(eventArg, 'Invoker');
	if not buffInvoker or buffInvoker.Type ~= 'FieldEffect' or buffInvoker.Value ~= mastery.FieldEffect.name then
		return;
	end
	local buffGiver = GetBuffGiver(eventArg.Buff);
	if not buffGiver or buffGiver ~= owner then
		return;
	end
	local target = eventArg.Unit;
	local candidates = GetInstantProperty(owner, mastery.name) or {};
	candidates[GetObjKey(target)] = true;
	SetInstantProperty(owner, mastery.name, candidates);
end
-- 빗나간 죽음
function Mastery_LuckyCheatDeath_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Buff.name ~= mastery.Buff.name then
		return;
	end
	local adjustValue = GetInstantProperty(owner, mastery.name) or 0;
	adjustValue = adjustValue + mastery.ApplyAmount;
	SetInstantProperty(owner, mastery.name, adjustValue);
end
-- 특정 버프 추가 시에 오라 버프 해제 (ex. 디스크 레이돔, 정보 교란기)
function Mastery_AuraDisabledBySubBuff_BuffAdded(eventArg, mastery, owner, ds)
	if eventArg.Buff.name ~= mastery.SubBuff.name then
		return;
	end
	local auraBuff = GetInstantProperty(owner, mastery.name);
	if not auraBuff or not HasBuff(owner, auraBuff) then
		return;
	end
	return Result_RemoveBuff(owner, auraBuff, true);
end
--------------------------------------------------------------------------------
-- 버프 제거 [BuffRemoved]
----------------------------------------------------------------------------
-- 꿈속의 꿈
function Mastery_DreamInDream_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	
	if not RandomTest(mastery.ApplyAmount) then
		return;
	end
	
	local picker = RandomBuffPicker.new(owner, GetClassList('BuffGroup').Sleep.BuffList);
	local buff = picker:PickBuff();
	if buff == nil then
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, owner, owner, buff, 1, true);
	MasteryActivatedHelper(ds, mastery, owner, 'BuffRemoved_Self');
	return unpack(actions);
end
-- 숙면
function Mastery_DeepSleep_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	
	local cacheKey = 'DeepSleep_ExpCache_'..eventArg.Buff.name;
	local cache = GetInstantProperty(owner, cacheKey);
	if cache == nil then
		LogAndPrint('Mastery_DeepSleep_BuffRemoved', 'Exp Cache Data 소실', eventArg.Buff.name);
		return;
	end
	
	
	SetInstantProperty(owner, cacheKey, nil);
	if eventArg.Buff.Life > 0 then
		-- 라이프가 남아있음. 시간흐름으로 풀린게 아님
		return;
	end
	
	local addExp = math.floor(CalculateExpDiff(owner.ExpType, cache.Lv, cache.Exp, owner.Lv, owner.Exp) * mastery.ApplyAmount / 100);
	local addJobExp = math.floor(CalculateExpDiff(owner.JobExpType, cache.JobLv, cache.JobExp, owner.JobLv, owner.JobExp) * mastery.ApplyAmount / 100);
	
	
	local reason = 'Mastery_'..mastery.name;
	local action = Result_AddExp(owner, addExp, addJobExp, reason);
	
	-- 휴식 경험치 경감
	owner.RestExp = math.max(0, owner.RestExp - addExp);
	owner.RestJobExp = math.max(0, owner.RestJobExp - addJobExp);
	
	-- 연출 처리
	local objKey = GetObjKey(owner);
	local addExpCmd = ds:PlayUIEffect(objKey, '_CENTER_', 'AddExp', 6, 2, PackTableToString({exp = addExp, reason = reason, AliveOnly=true}));
	local chatCmd = ds:AddMissionChat('AddExp', 'AddExp', {ObjectKey = objKey, Exp = addExp, Reason = reason});
	ds:Connect(chatCmd, addExpCmd, 0);
	local chatCmdJob = ds:AddMissionChat('AddExp', 'AddJobExp', {ObjectKey = objKey, Exp = addJobExp, Reason = reason});
	ds:Connect(chatCmdJob, addExpCmd, 0);
	
	MasteryActivatedHelper(ds, mastery, owner, 'BuffRemoved_Self', nil, addExpCmd, 0);
	
	return action;
end
-- 함정 시스템
function Mastery_TrapSystem_BuffRemoved(eventArg, mastery, owner, ds)
	if mastery.DuplicateApplyChecker == 0 
		or owner.Detected then
		return;
	end
	mastery.DuplicateApplyChecker = 0;
end
-- 특정 버프 해제 시에 오라 버프 복원 (ex. 디스크 레이돔, 정보 교란기)
function Mastery_AuraDisabledBySubBuff_BuffRemoved(eventArg, mastery, owner, ds)
	if eventArg.Buff.name ~= mastery.SubBuff.name then
		return;
	end
	local auraBuff = GetInstantProperty(owner, mastery.name);
	if not auraBuff or HasBuff(owner, auraBuff) then
		return;
	end
	return Result_AddBuff(owner, owner, auraBuff, 1, nil, true);
end
--------------------------------------------------------------------------------
-- 팀 변경 [UnitTeamChanged]
----------------------------------------------------------------------------
-- 함정 시스템
function Mastery_TrapSystem_UnitTeamChanged(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	-- 팀 변경이 되었으므로 범위표기 갱신
	local mvrKey = string.format('TRAP_AREA:%s', GetObjKey(owner));
	
	UnregisterConnectionRestoreRoutine(GetMission(owner), mvrKey);
	ds:MissionVisualRange_AddCustom(mvrKey, false);
	
	RegisterConnectionRestoreRoutine(GetMission(owner), mvrKey, function(ds)
		ds:MissionVisualRange_AddCustom(mvrKey, true, GetPosition(owner), GetObjKey(owner), 'Sphere2_Trap_Ally','Sphere2_Trap');
	end);
	ds:MissionVisualRange_AddCustom(mvrKey, true, GetPosition(owner), GetObjKey(owner), 'Sphere2_Trap_Ally','Sphere2_Trap');
end
--------------------------------------------------------------------------------
-- 아이템 획득 [UnitItemAcquired]
----------------------------------------------------------------------------
-- 황금의 도시
function Mastery_GoldenCity_UnitItemAcquired(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local itemRank = eventArg.Item.Rank.name;
	if itemRank ~= 'Legend' and itemRank ~= 'Epic' and itemRank ~= 'Rare' and itemRank ~= 'Uncommon' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'UnitItemAcquired_Self');
	if itemRank == 'Legend' then
		local addHP = math.floor(owner.MaxHP * mastery.ApplyAmount2 / 100);
		local reasons = AddActionRestoreHP(actions, owner, owner, addHP);
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
		DirectDamageByType(ds, owner, 'HPRestore', -1 * addHP, math.min(owner.HP + addHP, owner.MaxHP), true, false);
		AddMasteryDamageChat(ds, owner, mastery, -1 * addHP);
	elseif itemRank == 'Epic' then
		local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
		local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
		local goodBuff = goodBuffPicker:PickBuff();
		if goodBuff ~= nil then
			InsertBuffActions(actions, owner, owner, goodBuff, 1);
		end
	elseif itemRank == 'Rare' then
		local ownerKey = GetObjKey(owner);
		local applyAct = -1 * mastery.ApplyAmount;
		local added, reasons = AddActionApplyAct(actions, owner, owner, applyAct, 'Friendly');
		if added then
			ds:UpdateBattleEvent(ownerKey, 'AddWait', { Time = applyAct });
		end
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	elseif itemRank == 'Uncommon' then
		local ownerKey = GetObjKey(owner);
		local addCost = mastery.ApplyAmount;
		local _, reasons = AddActionCost(actions, owner, addCost, true);
		ds:UpdateBattleEvent(ownerKey, 'AddCost', { CostType = owner.CostType.name, Count = addCost });
		ReasonToUpdateBattleEventMulti(owner, ds, reasons);
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 유닛 레벨업 [UnitLvAdded]
----------------------------------------------------------------------------
function Mastery_RoadOfStudies_UnitLvAdded(eventArg, mastery, owner, ds)
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, eventArg.EventType);
	InsertBuffActions(actions, owner, owner, mastery.Buff.name, 1, true);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 유닛 경험치 획득 [UnitExpAdded]
----------------------------------------------------------------------------
function Mastery_RoadOfStudies_UnitExpAdded(eventArg, mastery, owner, ds)
	local expInfo = GetInstantProperty(owner, mastery.name) or { Lv = owner.Lv, Exp = 0 };
	expInfo.Exp = expInfo.Exp + eventArg.ExpBase;
	SetInstantProperty(owner, mastery.name, expInfo);
end
--------------------------------------------------------------------------------
-- 유닛 생성 [UnitCreated]
----------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 유닛 상호 작용 [UnitInteractObject]
----------------------------------------------------------------------------
function Mastery_RepairableObject_UnitInteractObject(eventArg, mastery, owner, ds)
	if eventArg.Interaction.name ~= 'Repair'
		or eventArg.Target ~= owner then
		return;
	end
	local disabledMonType = GetInstantProperty(owner, 'DisabledMonsterType');
	local direction = GetDirection(owner);
	local newObjKey = GenerateUnnamedObjKey(GetMission(owner));
	local destroy = Result_DestroyObject(owner, false, true);
	local create = Result_CreateMonster(newObjKey, disabledMonType, GetPosition(owner), '_neutral_', function(obj, arg)
		UNIT_INITIALIZER(obj, GetTeam(obj));
		SetDirection(obj, direction);
	end, nil, 'DoNothingAI', {}, true);
	destroy.sequential = true;
	create.sequential = true;
	return destroy, create;
end
--------------------------------------------------------------------------------
-- 전투 돌입 [RunIntoBattle]	Args: Unit(object), Trigger(object), BuffType(string)
----------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- 우호적 야수 참전 (야수 소환/길들이기) [FriendlyBeastHasJoined]	Args: Beast(object), FirstJoin(boolean)
----------------------------------------------------------------------------
-- 휴식 훈련
function Mastery_RestTraining_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if eventArg.Beast ~= owner or IsDead(owner) then
		return;
	end
	local unsummonTime = GetInstantProperty(owner, 'UnsummonTime');
	if unsummonTime == nil then
		return;
	end
	
	local thisTime = GetMissionElapsedTime(owner);
	local recoveryAmount = math.floor((thisTime - unsummonTime) / mastery.ApplyAmount) * mastery.ApplyAmount2 / 100 * owner.MaxHP;
	return Result_PropertyUpdated('HP', math.floor(owner.HP + recoveryAmount), owner, true);
end
-- 야수 훈련
function Mastery_BeastTraining_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if not eventArg.FirstJoin and GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	local actions = {};
	table.insert(actions, Result_UpdateMastery(eventArg.Beast, reinforceMastery.name, 1));
	if not IsDead(eventArg.Beast) then
		table.insert(actions, Result_PropertyAdded('HP', reinforceMastery.MaxHP, eventArg.Beast, 0, nil, true, true));
	end
	return unpack(actions);
end
-- 괴수 사냥군
function Mastery_MonsterHunter_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if not eventArg.FirstJoin and GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	local actions = {};
	table.insert(actions, Result_UpdateMastery(eventArg.Beast, reinforceMastery.name, 1));
	if not IsDead(eventArg.Beast) then
		table.insert(actions, Result_PropertyAdded('HP', reinforceMastery.MaxHP, eventArg.Beast, 0, nil, true, true));
	end
	return unpack(actions);
end
-- 사냥꾼의 일상
function Mastery_LifeOfHunter_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
		
	SetInstantProperty(eventArg.Beast, 'DailyHuntingNow', true);
end
function Mastery_RushTraining_FriendlyBeastHasJoined(eventArg, mastery, owner, ds)
	if owner ~= eventArg.Beast then
		return;
	end
	SubscribeWorldEvent(owner, 'UnitTurnStart_Self', function(eventArg, ds, subscriptionID)
		UnsubscribeWorldEvent(owner, subscriptionID);
		MasteryActivatedHelper(ds, mastery, owner, 'FriendlyBeastHasJoined');
	end);
	return Result_PropertyUpdated('Act', -owner.Speed, owner, true, true);
end
--------------------------------------------------------------------------------
-- 우호적 야수 떠남 (야수 해제) [FriendlyBeastAboutToLeave]	Args: Beast(object)
----------------------------------------------------------------------------
-- 사냥꾼의 일상
function Mastery_LifeOfHunter_FriendlyBeastAboutToLeave(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= GetInstantProperty(eventArg.Beast, 'SummonMaster') then
		return;
	end
	SetInstantProperty(eventArg.Beast, 'DailyHuntingNow', nil);
end
-- 휴식 훈련
function Mastery_RestTraining_FriendlyBeastAboutToLeave(eventArg, mastery, owner, ds)
	if eventArg.Beast ~= owner then
		return;
	end
	return Result_UpdateInstantProperty(owner, 'UnsummonTime', GetMissionElapsedTime(owner));
end
--------------------------------------------------------------------------------
-- 우호적 기계 참전 (기계 소환/제어권 탈취) [FriendlyMachineHasJoined]	Args: Machine(object), FirstJoin(boolean)
----------------------------------------------------------------------------
-- 해체 전문가
function Mastery_DismantlingSpecialist_FriendlyMachineHasJoined(eventArg, mastery, owner, ds)
	-- 기계 소환도 아니고, 제어권 탈취도 아니면 무시
	local isSummoned = GetObjKey(owner) == GetInstantProperty(eventArg.Machine, 'SummonMaster');
	local isHacked = Set.new(GetInstantProperty(owner, 'ControlTakingOverTargets') or {})[GetObjKey(eventArg.Machine)];
	if not isSummoned and not isHacked then
		return;
	end
	SetInstantProperty(eventArg.Machine, 'DismantlingSpecialist', true);
end
-- XX역학 (동역학, 고체역학, 유체역학, 열역학 등)
function Mastery_CommonMechanics_FriendlyMachineHasJoined(eventArg, mastery, owner, ds)
	-- 기계 소환도 아니고, 제어권 탈취도 아니면 무시
	local isSummoned = GetObjKey(owner) == GetInstantProperty(eventArg.Machine, 'SummonMaster');
	local isHacked = Set.new(GetInstantProperty(owner, 'ControlTakingOverTargets') or {})[GetObjKey(eventArg.Machine)];
	if not isSummoned and not isHacked then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	return Result_UpdateMastery(eventArg.Machine, reinforceMastery.name, 1);
end
--------------------------------------------------------------------------------
-- 우호적 기계 떠남 (기계 해제) [FriendlyMachineAboutToLeave]	Args: Machine(object), MasterKey(string, object key)
----------------------------------------------------------------------------
-- 해체 전문가
function Mastery_DismantlingSpecialist_FriendlyMachineAboutToLeave(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= eventArg.MasterKey then
		return;
	end
	SetInstantProperty(eventArg.Machine, 'DismantlingSpecialist', nil);
end
-- XX역학 (동역학, 고체역학, 유체역학, 열역학 등)
function Mastery_CommonMechanics_FriendlyMachineAboutToLeave(eventArg, mastery, owner, ds)
	if GetObjKey(owner) ~= eventArg.MasterKey then
		return;
	end
	local reinforceMastery = mastery.Mastery;
	return Result_UpdateMastery(eventArg.Machine, reinforceMastery.name, -1);
end
--------------------------------------------------------------------------------
-- 순찰 회피 [PatrolAvoided]	Args: Unit(object), Buff(buff)
----------------------------------------------------------------------------
-- 위장
function Mastery_Camouflage_PatrolAvoided(eventArg, mastery, owner, ds)
	if owner == eventArg.Unit then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'PatrolAvoided');
	
	local actions = {};
	-- 설계된 함정
	local mastery_TrapDesign = GetMasteryMastered(GetMastery(owner), 'TrapDesign');
	if mastery_TrapDesign then
		AddActionApplyActForDS(actions, owner, -mastery_TrapDesign.ApplyAmount2, ds, 'Friendly');
		MasteryActivatedHelper(ds, mastery_TrapDesign, owner, 'PatrolAvoided');
	end
	
	-- 달빛 사냥꾼
	local mastery_MoonHunter = GetMasteryMastered(GetMastery(owner), 'MoonHunter');
	if mastery_MoonHunter and IsDarkTime(GetMission(owner).MissionTime.name) then
		if AddRandomGoodBuffAction(actions, owner, owner) then
			MasteryActivatedHelper(ds, mastery_MoonHunter, owner, 'PatrolAvoided');
		end
	end
	
	return unpack(actions);
end
-- MyTrapActivated	내 트랩 발동!
function Mastery_AttackWithBeast_MyTrapActivated(eventArg, mastery, owner, ds)
	local allowTargets = {};
	for _, obj in ipairs(eventArg.ApplyTargets) do
		if not IsDead(obj) then
			allowTargets[GetObjKey(obj)] = true;
		end
	end
	return Mastery_AttackWithBeastActivated(allowTargets, mastery, owner, ds, true);
end
--------------------------------------------------------------------------------
-- 시민 구출 [CitizenRescued]
----------------------------------------------------------------------------
function Mastery_MyDreamIsHero_CitizenRescued(eventArg, mastery, owner, ds)
	if eventArg.Savior ~= owner
		or GetBuff(owner, mastery.Buff.name) == nil then
		return;
	end
	return Mastery_MyDreamIsHero_ActivatePositiveEffect(mastery, owner, ds);
end
function Mastery_MyDreamIsHero_ActivatePositiveEffect(mastery, owner, ds)
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(owner, goodBuffList);
	
	local goodBuff = goodBuffPicker:PickBuff();
	if goodBuff == nil then
		return;
	end
	
	MasteryActivatedHelper(ds, mastery, owner, 'Etc');
	local actions = {};
	InsertBuffActions(actions, owner, owner, goodBuff, 1, true);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 덫 파괴 [TrapHasBeenCracked]
----------------------------------------------------------------------------
function Mastery_TrapSystem_TrapHasBeenCracked(eventArg, mastery, owner, ds)
	ds:UpdateBattleEvent(GetObjKey(owner), 'Malfunction', {});
	ds:PlayParticle(GetObjKey(owner), '_CENTER_', 'Particles/Dandylion/Muzzle_Explosion', 1, true, true, false);
	return Result_PropertyUpdated('Base_Detected', true, owner), Result_DestroyObject(self, true);
end
--------------------------------------------------------------------------------
-- XX 쐐기 발동 [BoltInvoked]
----------------------------------------------------------------------------
function Mastery_IceFraction_BoltInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or not HasBuffType(eventArg.Target, nil, nil, mastery.BuffGroup.name) then
		return;
	end
	local addBuff = mastery.Buff.name;
	-- 얼어붙은 검
	local mastery_FrozenSword = GetMasteryMastered(GetMastery(owner), 'FrozenSword');
	if mastery_FrozenSword then
		addBuff = mastery_FrozenSword.Buff.name;
	end
	
	local alreadyBuff = GetBuff(eventArg.Target, addBuff);
	if alreadyBuff and alreadyBuff.Age == 0 then
		return;
	end
	
	local actions = {};
	InsertBuffActions(actions, owner, eventArg.Target, addBuff, 1, true, nil, true);
	MasteryActivatedHelper(ds, mastery, eventArg.Target, 'BoltInvoked');
	return unpack(actions);
end
function Mastery_BoltCommon_BoltInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.Mastery ~= mastery.name then
		return;
	end
	local target = eventArg.Target;
	local damage = eventArg.Damage;	
	ds:AddMissionChat(GetMasteryEventKey(owner), 'MasteryEventTargetDamage', {ObjectKey = GetObjKey(owner), TargetKey = GetObjKey(target), MasteryType = mastery.name, Damage = damage});
end
-- 불꽃 쐐기
function Mastery_FlameBolt_BoltInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Mastery ~= 'FireBolt'
		or eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'Etc');
	local target = eventArg.Target;
	if not HasBuff(target, mastery.Buff.name) then
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	else
		InsertBuffActions(actions, owner, target, mastery.SubBuff.name, 1, true);
	end
	return unpack(actions);
end
-- 섬광 쐐기
function Mastery_FlashBolt_BoltInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or eventArg.Mastery ~= 'LightningBolt'
		or eventArg.Damage <= 0 then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'Etc');
	local target = eventArg.Target;
	-- 턴 대기 시간 증가
	if HasBuffType(target, nil, nil, mastery.BuffGroup.name) then
		AddActionApplyActForDS(actions, target, mastery.ApplyAmount, ds, 'Hostile');
	end
	-- 버프 추가
	if not HasBuff(target, mastery.Buff.name) then
		InsertBuffActions(actions, owner, target, mastery.Buff.name, 1, true);
	else
		InsertBuffActions(actions, owner, target, mastery.SubBuff.name, 1, true);
	end
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 은신 발각 [CloakingDetected]
----------------------------------------------------------------------------
function Mastery_FullyReady_CloakingDetected(eventArg, mastery, owner, ds)
	if eventArg.Target ~= owner
		or owner.HP < 0 then
		return;
	end
	local allowTargets = {};
	allowTargets[GetObjKey(eventArg.Unit)] = true;
	
	-- 궁극기를 제외한 공격 어빌리티
	local abilities = table.filter(GetAvailableAbility(owner, true), function (ability) return ability.Type == 'Attack' and not ability.SPFullAbility end);
	local abilityRank = {};
	for i, ability in ipairs(abilities) do
		abilityRank[ability.name] = #abilities - i;
	end
	
	local usingAbility, usingPos, _, score = FindAIMainAction(owner, abilities, {{Strategy = function(self, adb)
		local count = table.count(adb.ApplyTargets, function(t) return allowTargets[GetObjKey(t)] end);
		if count == 0 then
			return -22;
		end
		local score = 100;
		if adb.IsIndirect then
			score = 0;
		end
		score = score + abilityRank[adb.Ability.name] * 200;
		return score + 100 / (adb.Distance + 1);
	end, Target = 'Attack'}}, {}, {});
	
	if usingAbility == nil or usingPos == nil then
		return;
	end
	
	local actions = {};
	
	local action, reasons = GetApplyActAction(owner, mastery.ApplyAmount, nil, 'Cost');
	local battleEvents = {};
	if action then
		table.insert(actions, action);
		table.insert(battleEvents, { Object = owner, EventType = 'AddWait', Args = { Time = mastery.ApplyAmount } });
	end
	table.append(battleEvents, ReasonToBattleEventTableMulti(owner, reasons, 'FirstHit'));
	table.insert(battleEvents, {Object = owner, EventType = 'MasteryInvokedCustomEvent', Args = {Mastery = mastery.name, EventType = 'CloakingDetected', MissionChat = true} });
	
	local overwatchAction = Result_UseAbility(owner, usingAbility.name, usingPos, {ReactionAbility=true, BattleEvents=battleEvents}, true, {});
	overwatchAction.final_useable_checker = function()
		return GetBuffStatus(owner, 'Attackable', 'And')
			and PositionInRange(CalculateRange(owner, usingAbility.TargetRange, GetPosition(owner)), usingPos);
	end;
	table.insert(actions, overwatchAction);
	
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 공연 효과 발생 [PerformanceEffectAdded]
----------------------------------------------------------------------------
-- 공연시스템
function Mastery_PerformanceSystem_PerformanceEffectAdded(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner
		or owner.PerformanceType == 'None' then
		return;
	end
	local performanceCls = GetClassList('Performance')[owner.PerformanceType];
	if not performanceCls then
		return;
	end
	
	local masteryTable = GetMastery(owner);

	local actions = {};
	local performanceList = GetInstantProperty(owner, 'PerformanceList') or {};
	
	-- 슬롯 4개씩 멋짐 체크
	if #performanceList >= 4 then
		local greatList = {};
		while true do
			local prevCount = #greatList;
			for i = 1, #performanceList - 3 do
				local effect1 = performanceList[i];
				local effect2 = performanceList[i + 1];
				local effect3 = performanceList[i + 2];
				local effect4 = performanceList[i + 3];
				local greatCls = TestPerformanceGreatType(performanceCls, effect1, effect2, effect3, effect4);
				if greatCls then
					table.insert(greatList, greatCls);
					for j = 3, 0, -1 do
						table.remove(performanceList, i + j);
					end
					-- 정기 공연
					local mastery_SubscriptionConcert = GetMasteryMastered(masteryTable, 'SubscriptionConcert');
					if mastery_SubscriptionConcert then
						table.insert(performanceList, i, effect4);
					end
					break;
				end
			end
			if prevCount == #greatList then
				break;
			end
		end
		if #greatList > 0 then		
			for _, greatCls in ipairs(greatList) do
				AddPerformanceGreatActionForDS(actions, owner, greatCls, ds);
			end
		end
	end
	
	-- 마무리 체크
	-- 즉흥적인 마무리
	local hasShowClose = false;
	if eventArg.Ability ~= 'ShowClose' and HasBuff(owner, 'ShowClose') then
		hasShowClose = true;
	end
	if hasShowClose or #performanceList >= owner.PerformanceSlot then
		local greatLv = owner.PerformanceGreatLv;
		local prevList = table.deepcopy(performanceList);
		-- 마무리 발동
		AddPerformanceFinishActionForDS(actions, owner, performanceCls, greatLv, #performanceList, ds);
		-- 슬롯 비움
		performanceList = {};
		-- 앙코르
		local mastery_Encore = GetMasteryMastered(masteryTable, 'Encore');
		if mastery_Encore then
			local insertCount = math.min(greatLv, owner.PerformanceSlot - 1);
			if insertCount > 0 then
				for i = 1, insertCount do 
					table.insert(performanceList, prevList[i]);
				end
			end
		end
		if hasShowClose then
			table.insert(actions, Result_RemoveBuff(owner, 'ShowClose', true));
		end
	end	

	-- 남은 슬롯 반영
	table.insert(actions, Result_UpdateInstantProperty(owner, 'PerformanceList', performanceList, true));
	-- 액션이 처리되기 전의 서버 로직에서 반영되도록 바로 적용
	SetInstantProperty(owner, 'PerformanceList', performanceList);
	
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 공연 멋짐 발생 [PerformanceGreatInvoked]
----------------------------------------------------------------------------
-- 각광
function Mastery_Spotlight_PerformanceGreatInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'PerformanceGreatInvoked');
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	AddActionCostForDS(actions, owner, mastery.ApplyAmount, true, nil, ds);
	AddActionApplyActForDS(actions, owner, -1 * mastery.ApplyAmount, ds, 'Friendly');
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 공연 마무리 발생 [PerformanceFinishInvoked]
----------------------------------------------------------------------------
-- 앙코르 공연
function Mastery_EncoreStage_PerformanceFinishInvoked(eventArg, mastery, owner, ds)
	if eventArg.Unit ~= owner or eventArg.GreatLv < mastery.ApplyAmount then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'PerformanceFinishInvoked');
	AddActionRestoreActions(actions, owner);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 구조 요청 접수 [RescueCallReceived]
----------------------------------------------------------------------------
-- 응급 구조 프로그램
function Mastery_Module_EmergencyRescue_EmergencyRescueReceived(eventArg, mastery, owner, ds)
	if owner == eventArg.Receptionist then
		return;
	end
	local onGoingRescueTargets = GetInstantProperty(owner, 'OnGoingRescueTargets') or {};
	onGoingRescueTargets[GetObjKey(eventArg.Target)] = true;
	SetInstantProperty(owner, 'OnGoingRescueTargets', onGoingRescueTargets);
end
--------------------------------------------------------------------------------
-- 구조 요청 완료 [RescueCallCompleted]
----------------------------------------------------------------------------
-- 응급 구조 프로그램
function Mastery_Module_EmergencyRescue_EmergencyRescueCompleted(eventArg, mastery, owner, ds)
	local onGoingRescueTargets = GetInstantProperty(owner, 'OnGoingRescueTargets') or {};
	onGoingRescueTargets[GetObjKey(eventArg.Target)] = nil;
	SetInstantProperty(owner, 'OnGoingRescueTargets', onGoingRescueTargets);
end
--------------------------------------------------------------------------------
-- 버프 면역 적용 [BuffImmuned]
----------------------------------------------------------------------------
function Mastery_BigLightningRod_BuffImmuned(eventArg, mastery, owner, ds)
	if eventArg.Reason ~= 'Mastery_LightningRod'
		or owner.ESP.name ~= mastery.Type.name then	-- 번개 SP체크
		return;
	end
	
	local actions = {};
	AddSPPropertyActionsObject(actions, owner, mastery.ApplyAmount, true, ds, true);
	MasteryActivatedHelper(ds, mastery, owner, 'BuffImmuned_Self');
	return unpack(actions);
end
-- 지배자
function Mastery_Overlord_BuffImmuned(eventArg, mastery, owner, ds)
	if eventArg.Reason ~= 'Mastery_ToughSpirit' then
		return;
	end
	local actions = {};
	MasteryActivatedHelper(ds, mastery, owner, 'BuffImmuned_Self');
	InsertBuffActions(actions, owner, owner, mastery.ThirdBuff.name, 1, true);
	return unpack(actions);
end
--------------------------------------------------------------------------------
-- 버프를 줌 [BuffGived]
----------------------------------------------------------------------------
-- 빛보다 빠른 주먹 / 물실호기
function Mastery_SharedBuffAppliedSet(eventArg, mastery, owner, ds)
	if not eventArg.AbilityBuff
		or eventArg.Buff.Group ~= mastery.BuffGroup.name then
		return;
	end
	local buffGivedSet = GetInstantProperty(owner, mastery.name) or {};
	buffGivedSet[GetObjKey(eventArg.Unit)] = true;
	SetInstantProperty(owner, mastery.name, buffGivedSet);
end
--------------------------------------------------------------------------------
-- 조사 상호 작용 [InvestigationOccured]
----------------------------------------------------------------------------
-- 야사 알
function Mastery_HatchedObjectYasha_InvestigationOccured(eventArg, mastery, owner, ds)
	local actions = {};
	
	local itemProb = 10;
	-- 확률 보정
	local mission = GetMission(owner);
	local company = GetCompany(eventArg.Detective);
	local prevCount = GetCompanyInstantProperty(company, 'Lockpick_UnderWaterWayCount') or 0;
	local units = GetAllUnit(mission);
	local remainCount = table.count(units, function(o) return o.name == owner.name end);
	if remainCount == 1 and prevCount == 0 then
		itemProb = 100;
	end
	if RandomTest(itemProb) then
		local giveItem = Result_GiveItem(eventArg.Detective, 'Lockpick_UnderWaterWay', 1);
		table.append(actions, { GiveItemWithInstantEquipDialog(ds, giveItem, eventArg.Detective) });
		SetCompanyInstantProperty(company, 'Lockpick_UnderWaterWayCount', prevCount + 1);	
	end
	
	-- 남은 야샤 소환, 버프 해제
	local buff = GetBuff(owner, 'HatchedObjectYasha');
	if buff and buff.Life > 0 then
		Buff_HatchedObjectYasha_DoHatching(ds, owner, buff.Life);
		InsertBuffActions(actions, owner, owner, buff.name, -1 * buff.Lv);
	end
	
	-- 오브젝트 교체
	ds:PlayParticle(GetObjKey(owner), '_BOTTOM_', 'Particles/Dandylion/Impact_Blunt2', 2, false, false, true);
	local moveCam = ds:ChangeCameraTarget(GetObjKey(owner), '_SYSTEM_', false);
	local lookPos = GetPosition(owner);
	local enableId = ds:EnableIf('TestPositionIsVisible', lookPos);
	ds:Connect(enableId, moveCam, -1);
	ds:SetCommandLayer(enableId, game.DirectingCommand.CM_SECONDARY);
	local delay = ds:Sleep(1.5);
	ds:SetCommandLayer(delay, game.DirectingCommand.CM_SECONDARY);
	ds:Connect(delay, enableId, 0);
	table.insert(actions, Result_ChangeTeam(owner, '_dummy', false));
	table.insert(actions, Result_DestroyObject(owner, false, true));	
	local destroyedMonType = GetInstantProperty(owner, 'DestroyedMonsterType');
	if destroyedMonType then
		local direction = GetDirection(owner);
		local clearDying = Result_ClearDyingObjects();
		clearDying._ref = delay;
		clearDying._ref_offset = 0;
		table.insert(actions, clearDying);
		local destroy = Result_CreateMonster(GenerateUnnamedObjKey(GetMission(owner)), destroyedMonType, GetPosition(owner), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		destroy._ref = delay;
		destroy._ref_offset = 0;
		table.insert(actions, destroy);
	end

	return unpack(actions);
end