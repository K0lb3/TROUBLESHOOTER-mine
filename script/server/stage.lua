-- stage
function PrintMember(members)
	for i = 1, #members - 1 do
		io.write(members[i].name .. ", ");
	end
	io.write(members[#members].name.."\n");
end
function SetUnitInitialize(mid, componentTag, unitList, defaultValueFiller, extraInitializer, preInitializer)
	if unitList == nil then return end
	for i = 1, #unitList do
		local unit = unitList[i];
		local dataTable = {};
		if defaultValueFiller then
			unit = defaultValueFiller(unit);
		end
		if unit.Object ~= nil then
			if unit.Key == nil or unit.Key == '' then
				unit.Key = GenerateUnnamedObjKey(mid)
			end
			local mon = nil;
			if not unit.RosterObject then
				--LogAndPrint('CreateMonster', unit.Key, unit.Object, unit.Team or 'obstacle', unit.Position[1], unit.Direction[1])
				mon = CreateMonster(mid, unit.Key, unit.Object, unit.Team or 'obstacle', unit.Position[1], unit.Direction[1]);
				SetInstantPropertyWithUpdate(mon, 'MonsterType', unit.Object);
				if unit.BaseObject ~= nil then
					SetInstantPropertyWithUpdate(mon, 'BaseMonsterType', unit.BaseObject);
				end
				InitObjectFromMonster(mon, GetClassList('Monster')[unit.BaseObject or unit.Object]);
			else
				if unit.RosterReplace then
					mon = unit.RosterObject;
					SetObjKey(mon, unit.Key);
				else
					mon = CopyObject(unit.RosterObject, unit.Key);
				end
				mon.Team = unit.Team;
				SetPosition(mon, unit.Position[1]);
				SetDirection(mon, unit.Direction[1]);
				dataTable.IsRosterObject = true;
				dataTable.IsRosterReplace = unit.RosterReplace;
			end
			RegisterMapComponentObject(mid, componentTag, i, mon);

			if unit.Group and unit.Group ~= '' then
				AddGroupObject(mid, unit.Group, mon);
			end
			
			if unit.AI then
				local aiArg = table.deepcopy(unit.AI[1]);
				local aiType = SafeIndex(aiArg, 'AIType');
				if aiType == nil or aiType == 'None' then
					aiType = 'NormalMonsterAI';
				end
				aiArg.AIType = nil;
				SetMonsterAIInfo(mon, aiType, aiArg);
			end
			
			if unit.RetreatPosition ~= nil then
				if unit.RetreatPosition[1] ~= nil then
					dataTable.RetreatPosition = unit.RetreatPosition[1];
				end
			end
			dataTable.PatrolRoute = unit.PatrolRoute;
			dataTable.PatrolMethod = unit.PatrolMethod;
			dataTable.PatrolRepeat = unit.PatrolRepeat;
			dataTable.StartingBuff = unit.StartingBuff;
			dataTable.AngerBuff = unit.AngerBuff;
			dataTable.SelfSightBattleTest = unit.SelfSightBattleTest;
			dataTable.RetreatOrder = unit.RetreatOrder;
			
			local introOverrideType = SafeIndex(unit, 'NamedEventOverride', 1, 'Type');
			if introOverrideType and introOverrideType ~= 'None' then
				SetInstantProperty(mon, 'AutoBossEventType', tostring(unit.AutoBossEvent));
			end
			
			if preInitializer then
				preInitializer(unit, mon);
			end
			UNIT_INITIALIZER(mon, unit.Team, dataTable);
			if extraInitializer then
				extraInitializer(unit, mon);
			end
			
			if unit.AutoPlayable and unit.AutoPlayable ~= 'Override' then
				SetInstantProperty(mon, 'AutoPlayable', unit.AutoPlayable == 'On');
				SetInstantProperty(mon, 'DisableRetreat', unit.AutoPlayable == 'Off');
			end
			
			if not unit.RosterObject then
				CreateMonsterSubordinates(mid, mon);
			end
		end
	end
end
function CreateMonsterSubordinates(mid, mon)
	local baseMonType = FindBaseMonsterTypeWithCache(mon);
	local monCls = GetClassList('Monster')[baseMonType];
	
	local beasts = GetWithoutError(monCls, 'Beast');
	if beasts then
		local beastKeys = {};
		for index, beastData in ipairs(beasts) do
			local beastCls = GetClassList('BeastType')[beastData.Beast];
			if beastCls then
				local monCls = beastCls.Monster;
				local beastKey = string.format('%s_%s_%d', GetObjKey(mon), 'Beast', index);
				local beast = CreateMonster(mid, beastKey, monCls.name, mon.Team, InvalidPosition(), InvalidPosition());
				SetMonsterBeastInitialize(beast, mon, index, beastCls, beastData.Loyalty);
				CreateMonsterSubordinates(mid, beast);
				SetInstantProperty(beast, 'SummonProb', beastData.Prob);
				table.insert(beastKeys, beastKey);
			end
		end
		SetInstantProperty(mon, 'BeastList', beastKeys);
		local UPDATE_TARGET = GetInstantProperty(mon, 'UPDATE_TARGET') or {};
		UPDATE_TARGET.BeastList = true;
		SetInstantProperty(mon, 'UPDATE_TARGET', UPDATE_TARGET);
	end
end
function IsAutoDisableRetreatMission(mission)
	local missionAttribute = GetMissionAttribute(mission);
	local eventGenType = SafeIndex(missionAttribute, 'EventGenType');
	local troubleBookEpisode = SafeIndex(missionAttribute, 'TroubleBookEpisode');
	local troubleBookStage = SafeIndex(missionAttribute, 'TroubleBookStage');
	
	if eventGenType then
		local eventCls = GetClassList('ZoneEventGen')[eventGenType];
		if eventCls and eventCls.Type == 'Scenario' then
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
function SetPlayerUnitInitiallize(mid, stage, team, fixedMembers, freeMembers, singlePlay, rosterUnits)
	local startPositions = stage.MapComponents[1].StartPosition;
	
	-- 1. 시작 위치 테이블 구성
	local startPoint = {};
	for i, startPosition in ipairs(startPositions) do
		if startPosition.Team == team or startPosition.Team == nil then		
			local pos = startPosition.Position[1];
			local dir = startPosition.Direction[1];
			local key = startPosition.Key;
			if key == nil or key == '' then
				key = GenerateUnnamedObjKey(mid);
			end
			local posData = {
				Position = pos,
				Direction = dir,
				Key = key
			};
			table.insert(startPoint, posData);
			-- LogAndPrint('SetPlayerUnitInitiallize', startPosition.Team, pos.x, pos.y, pos.z, dir.x, dir.y, dir.z);
		end
	end
	
	-- 2. 시작 멤버 테이블 구성
	local memberList = {};
	local fixedSet = {};
	for i, member in ipairs(fixedMembers) do
		table.insert(memberList, member);
		fixedSet[member] = true;
	end
	for i, member in ipairs(freeMembers) do
		table.insert(memberList, member);
	end
	
	local mission = GetMission(mid);
	local isAutoDisableRetreat = IsAutoDisableRetreatMission(mission);
	
	for i, member in ipairs(memberList) do
		local pc = GetRosterFromObject(member);
		if pc ~= nil then
			SetInstantProperty(member, 'CPAtMissionStart', pc:GetEstimatedCP());
			SetInstantProperty(member, 'SatietyAtMissionStart', pc:GetEstimatedSatiety());
			SetInstantProperty(member, 'RefreshAtMissionStart', pc:GetEstimatedRefresh());
			if fixedSet[member] and isAutoDisableRetreat then
				SetInstantProperty(member, 'DisableRetreat', true);
			end
			
			member.RestExp, member.RestJobExp = CalculateEstimatedRestExp(pc);
		end
	end
	
	memberList = table.filter(memberList, function(obj)
		local pc = GetRosterFromObject(obj);
		if not pc then
			return true;
		end
		local info = rosterUnits[pc.name];
		if not info then
			return true;
		end
		if info.Replace then
			local unit = info.Replace;
			unit.RosterObject = obj;
			unit.RosterReplace = true;
		end
		for _, unit in ipairs(info.Copy) do
			unit.RosterObject = obj;
			unit.RosterReplace = false;
		end
		info.RosterObject = obj;
		return false;
	end);
		
	if #startPoint < #memberList then
		LogAndPrint(string.format('[DataError] :: [%s] - [fixedMembers - %d] + [freeMembers - %d] is more than [ Start Position Count - %d ]', stage.map, #fixedMembers, #freeMembers, #startPoint));
		return;
	end
	
	--- 3. 우선 위치 배정
	local startPointKeyMap = {};
	for index, sp in ipairs(startPoint) do
		startPointKeyMap[sp.Key] = sp;
	end
	local memberListLeft = {};
	for i = 1, #memberList do
		local member = memberList[i];
		local sp = startPointKeyMap[member.Info.name];
		if sp then
			SetObjKey(member, sp.Key);
			SetPosition(member, sp.Position, true);
			SetDirection(member, sp.Direction);
			startPointKeyMap[sp.Key] = nil;
		else
			table.insert(memberListLeft, member);
		end
	end
	local startPointLeft = {};
	for key, sp in pairs(startPointKeyMap) do
		if sp ~= nil then
			table.insert(startPointLeft, sp);
		end
	end
	
	--- 4. 랜덤 배정
	for i = 1, #memberListLeft do
		local randomPos = math.random(1, #memberListLeft - i + 1);
		SetObjKey(memberListLeft[i], startPointLeft[randomPos].Key);
		SetPosition(memberListLeft[i], startPointLeft[randomPos].Position);
		SetDirection(memberListLeft[i], startPointLeft[randomPos].Direction);
		table.remove(startPointLeft, randomPos);
	end
end
function SetBeastUnitInitiallize(mid, stage, team, beastMembers, singlePlay)
	-- 1. 시작 멤버 테이블 구성
	local memberList = {};
	for i = 1, #beastMembers do
		table.insert(memberList, beastMembers[i]);
	end
	
	for i, member in ipairs(memberList) do
		local pc = GetRosterFromObject(member);
		if pc ~= nil then
			member.RestExp, member.RestJobExp = CalculateEstimatedRestExp(pc);
		end
		member.Team = '__summon__';
		SetObjKey(member, GetBeastObjKey(team, pc));
		SetPosition(member, InvalidPosition());
		SetDirection(member, Position(1, 0, 0));
		member.Base_SceneScale = pc.SceneScale;
		member.ExpType = 'Beast';
		member.JobExpType = 'JobBeast';
		-- 테이머 오브젝트 키 연결
		local company = GetCompanyByTeam(mid, team);
		if company then
			local lineupList = GetLineupMembers(company);
			for _, pcInfo in ipairs(lineupList) do
				if pcInfo.RosterKey == pc.Tamer then
					member.Tamer = GetObjKey(pcInfo);
					break;
				end
			end
		end
	end
end
function SetMachineUnitInitiallize(mid, stage, team, machineMembers, singlePlay)
	-- 1. 시작 멤버 테이블 구성
	local memberList = {};
	for i = 1, #machineMembers do
		table.insert(memberList, machineMembers[i]);
	end
	
	for i, member in ipairs(memberList) do
		local pc = GetRosterFromObject(member);
		if pc ~= nil then
			member.RestExp, member.RestJobExp = CalculateEstimatedRestExp(pc);
		end
		member.Team = '__summon__';
		SetObjKey(member, GetMachineObjKey(team, pc));
		SetPosition(member, InvalidPosition());
		SetDirection(member, Position(1, 0, 0));
		member.Base_SceneScale = pc.SceneScale;
		member.ExpType = 'Machine';
		member.JobExpType = 'JobMachine';
	end
end
function SetFieldEffectInitialize(mid, fieldEffectList)
	local typeTable = {};
	for _, fieldEffect in ipairs(fieldEffectList) do
		local type = fieldEffect.FieldEffectType;
		if typeTable[type] == nil then
			typeTable[type] = {};
		end
	
		table.insert(typeTable[type], fieldEffect.Position[1]);
	end
	
	for type, positionList in pairs(typeTable) do
		AddFieldEffect(mid, type, positionList);
	end
end
function SetMonsterSubordinateInitialize(subordinate, mon, index, hostCls)
	SetInstantPropertyWithUpdate(subordinate, 'MonsterType', hostCls.Monster.name);
	InitObjectFromMonster(subordinate, hostCls.Monster);
	
	local datatable = {};
	-- datatable.AngerBuff = GetInstantProperty(mon, 'AngerBuff');
	UNIT_INITIALIZER(subordinate, mon.Team, datatable);
	
	subordinate.Team = '__summon__';
	SetPosition(subordinate, InvalidPosition());
	SetDirection(subordinate, Position(1, 0, 0));
	subordinate.Base_SceneScale = hostCls.MissionScale;
end
function SetMonsterBeastInitialize(beast, mon, index, beastCls, loyalty)
	SetMonsterSubordinateInitialize(beast, mon, index, beastCls);
	beast.CP = loyalty;
	beast.MaxCP = 100;
	SetInstantProperty(beast, 'BeastType', beastCls.name);
	local UPDATE_TARGET = GetInstantProperty(beast, 'UPDATE_TARGET') or {};
	UPDATE_TARGET.BeastType = true;
	SetInstantProperty(beast, 'UPDATE_TARGET', UPDATE_TARGET);
	AddBuff(beast, 'Beast_Loyalty', 1);
	SetMonsterAIInfo(beast, 'BeastAI', {AlwaysApplyRallyPoint = true,
		RallyPoint = {{Type = 'Object', ObjectKey = GetObjKey(mon)}},
		RallyPower = 30,
		RallyRange = 4,
		HateRatio = 5,
	});
end
function MonsterBeastInitializer(beast, args)	-- c++ AT_CREATE_MONSTER 쪽에서 호출
	SetMonsterBeastInitialize(beast, unpack(args));
end

function GlobalInvestigationPsionicOccured(eventArg, ds)
	local obj = eventArg.Unit;
	local target = eventArg.Detective;
	local stoneType = GetInstantProperty(obj, 'PsionicStoneType');
	local stoneCls = GetClassList('PsionicStone')[stoneType];
	if not stoneCls or not stoneCls.name then
		return;
	end
	
	local pos = GetPosition(obj);
	local objKey = GetObjKey(obj);
	local effectName = stoneCls.ExtractEffect;
	local particleID = ds:PlayParticle(objKey, '_CENTER_', effectName, 1);
	local playSoundID = ds:PlaySound3D('Extract_Energy.ogg', objKey, '_CENTER_', 3000, 'Effect', 1.0);
	local sleepID = ds:Sleep(0.1);
	ds:Connect(playSoundID, sleepID, 0);
	ds:Connect(particleID, playSoundID, 0.3333);
		
	local unitInitializeFunc = function(unit, arg)
		UNIT_INITIALIZER_NON_BATTLE(unit, unit.Team);
	end;
	local createAction = Result_CreateObject(GenerateUnnamedObjKey(obj), stoneCls.ExtractedObject.Object.name, pos, '_neutral_', unitInitializeFunc, {}, 'DoNothingAI', nil, true);
	createAction.sequential = true;
	if not obj.BackgroundObject then
		ds:WorldAction(Result_PropertyUpdated('BackgroundObject', true, obj));
	end
	ds:WorldAction(Result_DestroyObject(obj, false, true));
	ds:WorldAction(createAction);

	local masteryTable = GetMastery(target);
	local rewardPicker = RandomPicker.new();
	for _, reward in ipairs(stoneCls.NormalReward) do
		local curCount = math.max(1, math.random(reward.Min, reward.Max));
		rewardPicker:addChoice(reward.Prob, { Type = 'Simple', ItemType = reward.ItemName, Count = curCount });
	end
	local pickReward = rewardPicker:pick();
	
	-- 이능석 랭크 증가
	-- 1) 추출업자 반지
	local mastery_Ring_Extractor_Set = GetMasteryMastered(masteryTable, 'Ring_Extractor_Set');
	if mastery_Ring_Extractor_Set and RandomTest(mastery_Ring_Extractor_Set.ApplyAmount) then
		local itemClsList = GetClassList('Item');
		local itemCls = itemClsList[pickReward.ItemType];
		-- 현재 보상이 이능석이면 (드라키 알에선 이능석이 아닌 게 나올 수 있음)
		if itemCls and itemCls.Type.name == 'PsionicStone' then
			local curWeight = itemCls.Rank.Weight;
			-- Rank의 Weight 값이 현재 보상보다 1 더 높은 보상이 있으면 그걸로 바꿔줌
			local upgradeRewardList = table.filter(stoneCls.NormalReward, function(reward)
				local itemCls = itemClsList[reward.ItemName];
				return itemCls and itemCls.Type.name == 'PsionicStone' and itemCls.Rank.Weight == curWeight + 1;
			end);
			if #upgradeRewardList > 0 then
				local rewardPicker = RandomPicker.new();
				for _, reward in ipairs(upgradeRewardList) do
					local curCount = math.max(1, math.random(reward.Min, reward.Max));
					rewardPicker:addChoice(reward.Prob, { Type = 'Simple', ItemType = reward.ItemName, Count = curCount });
				end
				pickReward = rewardPicker:pick();
				-- 발동 연출
				MasteryActivatedHelper(ds, mastery_Ring_Extractor_Set, target, 'InvestigationPsionicOccured');
			end
		end
	end
	
	-- 퍼센트 증가
	-- 1) 어빌리티 효율
	local multiplier = eventArg.Effective;
	-- 2) 추출업자 손목 보호대
	local mastery_Wrist_Extractor_Set = GetMasteryMastered(masteryTable, 'Wrist_Extractor_Set');
	if mastery_Wrist_Extractor_Set then
		multiplier = multiplier + mastery_Wrist_Extractor_Set.ApplyAmount;
	end
	pickReward.Count = pickReward.Count * (100 + multiplier) / 100;
	
	-- 배수 증가
	-- 1) 특성 대량 추출
	local mastery_MassExtract = GetMasteryMastered(masteryTable, 'MassExtract');
	if mastery_MassExtract then
		pickReward.Count = pickReward.Count * mastery_MassExtract.ApplyAmount;
	end
	pickReward.Count = math.floor(pickReward.Count);

	local giveItem = Result_GiveItemByItemIndicator(target, pickReward, {});
	if giveItem == nil then
		return;
	end
	
	local giveItemConverter = BuildGiveItemConverter(target);
	local actions = {giveItemConverter(giveItem)};
	
	local playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
	local sleepID = ds:Sleep(3);
	local interactionID = ds:UpdateInteractionMessage(GetObjKey(target), 'ItemAcqired', pickReward.ItemType);
	ds:Connect(playSoundID, interactionID, 0.5);
	ds:Connect(sleepID, interactionID, 0);
	
	local itemEvent = Result_FireWorldEvent('ItemAcquired', {Unit=target, Team=GetTeam(target), ItemType=pickReward.ItemType});
	table.insert(actions, itemEvent);
	
	local mission = GetMission(obj);
	local company = GetCompanyByTeam(mission, GetTeam(target));
	if company then
		AddCompanyStats(company, 'ExtractPsionicStone', 1);
	end
	
	-- 트러블 메이커 점수
	table.insert(actions, Result_DirectingScript(function(mid, ds, args)
		AddExp_TroubleMaker(GetMissionDatabaseCommiter(GetMission(obj)), obj, target, 'Normal', false, false, ds);
	end, nil, true));
	
	-- 사망 이벤트 처리 (팀 카운터)
	if GetTeam(obj) ~= '_neutral_' then
		table.insert(actions, Result_FireWorldEvent('UnitDead', {Unit = obj, Virtual = true, Killer = target}));
	end
	
	-- 업적
	if string.find(stoneCls.name, 'Mon_Beast_Dragon_Egg') ~= nil then
		ds:UpdateSteamAchievement('SituationPsionicStoneGetDraky', true, GetTeam(target));
	end
	
	return unpack(actions);
end

function SetPsionicStoneInitialize(mid, psionicStoneList, psionicStoneDashboards)
	local typeTable = {};
	for _, psionicStone in ipairs(psionicStoneList) do
		local type = psionicStone.DashboardKey;
		if typeTable[type] == nil then
			typeTable[type] = {};
		end
	
		table.insert(typeTable[type], { Position = psionicStone.Position[1], Direction = psionicStone.Direction[1], Key = psionicStone.Key });
	end
	
	local unitList = {};
	
	for type, genList in pairs(typeTable) do
		local dashboard = psionicStoneDashboards[type];
		local dashboardInst = GetMissionDashboard(mid, type);	
		if dashboard and dashboardInst then
			local genCount = math.min(dashboardInst.Count, #genList);
			dashboardInst.Count = genCount;
			
			local genPicker = RandomPicker.new(false);
			for _, genInfo in ipairs(genList) do
				genPicker:addChoice(1, genInfo);
			end
			
			local typePicker = RandomPicker.new();
			for _, entry in ipairs(dashboard.PsionicStoneGen[1].Entry) do
				typePicker:addChoice(entry.Prob, entry.PsionicStoneType);
			end
			
			for i = 1, genCount do
				local genInfo = genPicker:pick();
				local stoneType = typePicker:pick();
				local stoneCls = GetClassList('PsionicStone')[stoneType];

				local unit = {};
				if not genInfo.Key then
					unit.Key = string.format('_Stone_%d_', #unitList);
				else
					unit.Key = genInfo.Key;
				end
				unit.Object = stoneCls.Object.name;
				unit.Team = '_neutral_';
				unit.AI = {{AIType='DoNothingAI'}};
				unit.Position = { genInfo.Position };
				unit.Direction = { genInfo.Direction };
				unit.StoneType = stoneType;
				unit.DashboardKey = type;
				
				table.insert(unitList, unit);
			end
		end
	end
	
	SetUnitInitialize(mid, 'PsionicStone', unitList, function(unit)
		return unit;
	end, function(unit, obj)
		EnableInteraction(obj, 'InvestigatePsionicStone');
		SetInstantProperty(obj, 'PsionicStoneType', unit.StoneType);
		SetInstantProperty(obj, 'PsionicStoneDashboardKey', unit.DashboardKey);
	end);
end

function SetDrakyEggInitialize(mid, drakyEggList)
	local genTypeList = { 'Mon_Beast_Dragon_Egg_A', 'Mon_Beast_Dragon_Egg_B', 'Mon_Beast_Dragon_Egg_C' };
	
	local unitList = {};
	for i, genInfo in ipairs(drakyEggList) do
		local genType = genTypeList[math.random(1, #genTypeList)];
		local unit = {};
		if not genInfo.Key then
			unit.Key = string.format('_DrakyEgg_%d_', i);
		else
			unit.Key = genInfo.Key;
		end
		unit.Object = genType;
		unit.Team = genInfo.Team or '_neutral_';
		unit.AI = {{AIType='DoNothingAI'}};
		unit.Position = genInfo.Position;
		unit.Direction = genInfo.Direction;
		table.insert(unitList, unit);
	end
	SetUnitInitialize(mid, 'DrakyEgg', unitList);
end

function SetPositionHolderInitialize(mid, positionHolderList)
	for _, positionHolder in ipairs(positionHolderList) do
		RegisterPositionHolder(mid, positionHolder.Key or '', positionHolder.Group or '', positionHolder.Position[1], positionHolder.Direction[1]);
	end
end

function SetInteractionAreaInitialize(mid, interactionAreas, reinitialize)
	for i, ia in ipairs(interactionAreas) do
		local key = '';
		if not reinitialize then
			key = ia.SubKey;
			if key == nil or key == '' then
				key = GenerateUnnamedObjKey(mid);
			end
			local from = ia.Area[1].From[1];
			local to = ia.Area[1].To[1];
			local interactionType = ia.InteractionArea;
			if StringToBool(ia.Active, true) then
				EnableInteractionArea(mid, key, from, to, interactionType, ia.NamedAssetKey);
			end
			RegisterMapComponentKey(mid, 'InteractionArea', i, key);
		else
			key = RetreiveMapComponentKey(mid, 'InteractionArea', i);
		end
		local interactorKey = SafeIndex(ia, 'ConditionOutputInteractionArea', 1, 'Interactor');
		SubscribeGlobalWorldEvent(mid, 'UnitInteractArea', function(eventArg, ds)
			if key ~= eventArg.Key then
				return;
			end
			local conditionOutput = {};
			if interactorKey ~= nil and interactorKey ~= '' then
				conditionOutput[interactorKey] = eventArg.Unit;
			end
			return unpack(PlayTriggerAction(GetMission(mid), ds, ia.ActionList[1].Action, conditionOutput));
		end);
	end
end
-- 맵 이니셜라이즈 공용 함수
function MapInitializerShared(mid, stage, memberInfos, activeQuests)
	local mission = GetMission(mid);
	mission.IsRepeatableMission = IsRepeatableMission(mission);
	local missionAttribute = GetMissionAttribute(mission);
	local singlePlay = #memberInfos == 1;
	local enemyGradeUpCount = 0;
	local challengerMode = false;
	if missionAttribute and missionAttribute.ChallengerMode then
		challengerMode = true;
	end
	
	if singlePlay then
		local company = GetAllCompanyInMission(mid)[1];
		-- mission 난이도 설정
		local prevDifficulty = mission.Difficulty.name;
		local missionLv = mission.Difficulty.Lv;
		local challengerMinRatio = 1;
		local challengerMaxRatio = 1;
		if company.GameDifficulty == 'Safty' then
			missionLv = math.clamp(missionLv - company.EnemyGradeUpFailCount + company.EnemyGradeUpClearCount, 1, 3);
		elseif company.GameDifficulty == 'Easy' then
			missionLv = math.clamp(missionLv - 3 - company.EnemyGradeUpFailCount + company.EnemyGradeUpClearCount, 4, 6);
			challengerMinRatio = 1.1;
			challengerMaxRatio = 1.3;
		elseif company.GameDifficulty == 'Normal' then
			missionLv = math.clamp(missionLv + 6 - company.EnemyGradeUpFailCount + company.EnemyGradeUpClearCount, 7, 9);
			challengerMinRatio = 1.2;
			challengerMaxRatio = 1.4;
		elseif company.GameDifficulty == 'Hard' then
			missionLv = math.clamp(missionLv + 9 - company.EnemyGradeUpFailCount + company.EnemyGradeUpClearCount, 10, 12);
			challengerMinRatio = 1.3;
			challengerMaxRatio = 1.5;
		elseif company.GameDifficulty == 'Merciless' then
			missionLv = math.clamp(missionLv + 12 - company.EnemyGradeUpFailCount + company.EnemyGradeUpClearCount, 13, 15);
		end
		mission.Difficulty = GetClassList('MissionDifficulty')['Difficulty'..missionLv];
		SetMissionLevel(mission, missionLv);
		mission.DifficultyGrade = company.GameDifficulty;
		--LogAndPrint(string.format('MissionDifficulty Arranged From [%s] to [%s]', prevDifficulty, mission.Difficulty.name));
		
		if mission.EnableEnemyGradeUp then	
			local enemyGradeUpMinCount = mission.EnemyGradeUpMinCount + mission.Difficulty.EnemyGradeUpMinCount;
			local enemyGradeUpMaxCount = mission.EnemyGradeUpMaxCount + mission.Difficulty.EnemyGradeUpMaxCount;

			if company.EnemyGradeUpFailCount > 0 then
				enemyGradeUpMaxCount = math.max(enemyGradeUpMaxCount - company.EnemyGradeUpFailCount, enemyGradeUpMinCount);
			elseif company.EnemyGradeUpClearCount > 0 then
				enemyGradeUpMinCount = math.min(enemyGradeUpMinCount + company.EnemyGradeUpClearCount, enemyGradeUpMaxCount);
			end
			enemyGradeUpMinCount = math.max(0, enemyGradeUpMinCount);
			enemyGradeUpMaxCount = math.max(0, enemyGradeUpMaxCount);
			if challengerMode then
				enemyGradeUpMinCount = math.floor(enemyGradeUpMinCount * challengerMinRatio);
				enemyGradeUpMaxCount = math.floor(enemyGradeUpMaxCount * challengerMaxRatio);
			end
			enemyGradeUpCount = math.max(0, math.random(enemyGradeUpMinCount, enemyGradeUpMaxCount));
		end
	end
	
	-- General Initializer --
	RegisterGlobalEventHandler(mid);
	
	-- Stage Variable Initialize
	InitializeStageVariables(mission, SafeIndex(stage, 'Variables', 1, 'Variable'));
	
	-- 위치 지정	(다른 맵 컴포넌트와 달리 우선 등록한다. Dashboard에서 이용하기 위해서)
	SetPositionHolderInitialize(mid, stage.MapComponents[1].PositionHolder);
	
	-- 미션 오브젝티브 및 메인 패널 대시보드 등록
	local objectiveSet = {};
	local objectives = stage.Objectives[1].Objective;
	if objectives then
		for i, objective in ipairs(objectives) do
			objectiveSet[objective.Key] = objective;
		end
	end
	local mainPanelDashboard = {Type='MainPanel', MainObjective = {{}}, Objective1 = {{}}, Objective2 = {{}}, Objective3 = {{}}, Objective4={{}}, Objective5={{}}, Objective6= {{}}};
	local missionObjectiveClsList = GetClassList('MissionObjective');
	for panelKey, info in pairs(mission.Objectives) do
		 local key = info.Key;
		 local objective = objectiveSet[key];
		 if objective then
			LogAndPrintDev(key, panelKey);
			mainPanelDashboard[panelKey][1].Active = 'true';
			mainPanelDashboard[panelKey][1].Message = objective.Title;
			
			local missionObjectiveCls = missionObjectiveClsList[objective.Type];
			
			-- 실질적인 오브젝티브의 초기화 및 관련 이벤트 핸들링 처리들
			missionObjectiveCls.Initializer(mission, objective, panelKey);
		 end
	end
	-- table.print(mainPanelDashboard, LogAndPrint);
	RegisterMissionDashboard(mission, DASHBOARD_MAIN_PANEL_KEY, mainPanelDashboard);
	
	--- Mission Dashboard 등록 ---
	local missionStageKey = mission.StageKey;
	local psionicStoneDashboards = {};
	local dashboards = stage.Dashboards[1].Dashboard;
	if dashboards then
		for i, dashboard in ipairs(dashboards) do
			local stageKey = dashboard.StageKey;
			local key = dashboard.Key;
			dashboard.Key = nil;	-- key는 지워주자
			dashboard.StageKey = nil;	-- StageKey도
			if stageKey == 'All' or stageKey == missionStageKey then		-- StageKey가 All이거나 mission의 StageKey와 같은 대쉬보드 타입만 등록할거임
				local dashboardInst = RegisterMissionDashboard(mission, key, table.deepcopy(dashboard));
				if dashboardInst.Initializer then
					local succ, err = pcall(dashboardInst.Initializer, dashboardInst, key, mission, stage, dashboard);
					if not succ then
						LogAndPrint('MapInitializerShared', 'Failed to initialize dashboard', err);
					end
				end
				if dashboard.Type == 'PsionicStone' then
					psionicStoneDashboards[key] = dashboard;
				end
			end
		end
	end
	
	--- Map Component Setting --- 
	local mapComponents = stage.MapComponents[1];
	
	-- StartPosition에 할당되지 않는 로스터 오브젝트 정보 구성
	local rosterUnits = GetRosterUnitInfos(mapComponents);

	--- Player Setting ---
	for i, memberInfo in ipairs(memberInfos) do
		SetPlayerUnitInitiallize(mid, stage, memberInfo.Team, memberInfo.FixedMembers, memberInfo.FreeMembers, singlePlay, rosterUnits);
		SetBeastUnitInitiallize(mid, stage, memberInfo.Team, memberInfo.BeastMembers, singlePlay);
		SetMachineUnitInitiallize(mid, stage, memberInfo.Team, memberInfo.MachineMembers, singlePlay);
	end
	
	if singlePlay then
		local company = GetAllCompanyInMission(mid)[1];	
		-- 정예화
		if mission.EnableEnemyGradeUp and mapComponents.Enemy then
			-- 가혹한 난이도 보정 --
			-- enemyGradeUpMaxCount 최대치 보정
			if company.GameDifficulty == 'Merciless' then
				enemyGradeUpCount = #mapComponents.Enemy;
			end
			UpdateEnemyGradeUp(mapComponents.Enemy, enemyGradeUpCount);
		end
		-- 도전 모드
		if challengerMode then
			-- 레벨 보정
			local maxPcLv = 0;
			for i, memberInfo in ipairs(memberInfos) do
				for i = 1, #memberInfo.FixedMembers do
					local obj = memberInfo.FixedMembers[i];
					maxPcLv = math.max(maxPcLv, obj.Lv);
				end
				for i = 1, #memberInfo.FreeMembers do
					local obj = memberInfo.FreeMembers[i];
					maxPcLv = math.max(maxPcLv, obj.Lv);		
				end
			end
			local fixLv = 0;
			if maxPcLv > mission.Lv then
				fixLv = maxPcLv - mission.Lv;		
			end
			SetCompanyInstantProperty(company, 'ChallengerModeFixLv', fixLv);
		end
		-- 특성 보정 목록 (도전 모드 or 보스 레벨 보정)
		local masteryList = GetClassList('Mastery');
		local allowMasterySet = {};
		for k, v in pairs(company.Technique) do
			if v.Opened and v.ChallengerMode then
				local mastery = masteryList[k];
				if mastery and mastery.Category.EquipSlot ~= 'None' then
					local masteryTypeName = mastery.Type.name;
					local masteryCheckType = mastery.Type.CheckType;
					local info = { Name = mastery.name, Category = mastery.Category.EquipSlot, Cost = mastery.Cost };
					if masteryCheckType == 'All' then
						if mastery.Category.IsMachine then
							SafeInsert(allowMasterySet, 'Machine', info);
						else
							SafeInsert(allowMasterySet, 'All', info);
						end
					elseif masteryCheckType == 'PC' or masteryCheckType == 'ESP' or masteryCheckType == 'Job' or masteryCheckType == 'Race' then
						SafeInsert(allowMasterySet, masteryTypeName, info);
					end
				end
			end
		end
		SetCompanyInstantProperty(company, 'ChallengerModeMasterySet', allowMasterySet);
	end
	
	local stageSetting = SafeIndex(stage, 'Setting', 1);
	local bossList = {};
	local monsterClassList = GetClassList('Monster');
	
	local preInitializer = function (unit, mon)
		if singlePlay and not unit.RosterObject and not StringToBool(unit.DirectingObject, false) then
			local company = GetAllCompanyInMission(mid)[1];
			local difficultyCls = GetClassList('GameDifficulty')[company.GameDifficulty];
			--- 난이도에 따른 보스 레벨 보정은 미션 권장 레벨이 최대값이므로, 그 이상으로 올려주는 도전 모드에서는 굳이 보정해줄 필요가 없다.
			if challengerMode then
				-- 도전 모드 보정
				SetInstantProperty(mon, 'Challenger', true);
				-- 레벨 증가
				local fixLv = GetCompanyInstantProperty(company, 'ChallengerModeFixLv');
				-- 최소 레벨
				local gradeLv = { Elite = 2, Epic = 3, Legend = 4 };
				local minLv = mission.Lv + (gradeLv[mon.Grade.name] or 0);
				-- 최종 레벨
				mon.Lv = math.max(mon.Lv + fixLv, minLv);
				-- 아이템 감정
				local equipmentClsList = GetClassList('Equipment');
				for _, equipmentCls in pairs(equipmentClsList) do
					local slotType = equipmentCls.name;
					local item = GetWithoutError(mon, slotType);
					if item and item.name and IsEnableIdentifyItem(item) then
						local option = GetIdentifyItemOptions(item);
						local identifyOptionValueList, ratio = GetIdentifyItemOptionValue(option);
						if #identifyOptionValueList <= 5 then
							item.Option.OptionKey = option.name;
							item.Option.Ratio = ratio;
							for index, status in ipairs(identifyOptionValueList) do
								item.Option[string.format('Type%d', index)] = status.Type;
								item.Option[string.format('Value%d', index)] = status.Value;
							end
						end
					end
				end
			elseif IsBossMonster(mon) and difficultyCls and difficultyCls.UseBossLvFix then
				-- 보스 레벨 보정
				SetInstantProperty(mon, 'UseBossLvFix', true);
				-- 최소 레벨
				local minLv = mission.Lv - difficultyCls.BossFixLv;
				-- 최종 레벨
				mon.Lv = math.max(mon.Lv, minLv);
			end
		end
	
		if mon.Info.NamedEvent.name ~= nil and mon.Info.NamedEvent.name ~= 'None'
			and unit.AutoBossEvent and tostring(unit.AutoBossEvent) ~= 'false' then
			if unit.AutoBossEvent == 'MeetOnly' or tostring(unit.AutoBossEvent) == 'true' then
				SetInstantProperty(mon, 'NeedBossMeetEvent', true);
			end
			if unit.AutoBossEvent == 'HPOnly' or tostring(unit.AutoBossEvent) == 'true' then
				SetInstantProperty(mon, 'NeedBossDangerEvent', true);
			end
			table.insert(bossList, mon);
		end
	end;
	
	-- 적
	SetUnitInitialize(mid, 'Enemy', mapComponents.Enemy, nil, nil, preInitializer);
	SetUnitInitialize(mid, 'Ally', mapComponents.Ally, nil, nil, preInitializer);
	SetUnitInitialize(mid, 'Neutral', mapComponents.Neutral, nil, nil, preInitializer);
	
	-- 일반 오브젝트
	SetUnitInitialize(mid, 'Object', mapComponents.Object, nil, nil, preInitializer);
	
	RegisterAutoBossEvent(mid, bossList);
	
	-- 장애물
	local obstacleClsList = GetClassList('Obstacle');
	SetUnitInitialize(mid, 'Obstacle', mapComponents.Obstacle, function(unit)
		local obstacleCls = obstacleClsList[unit.Obstacle];
		unit.AI = {{AIType='DoNothingAI'}};
		if unit.Team == nil or unit.Team == '' then
			unit.Team = 'obstacle';
		end
		unit.MonsterSet = table.randompick(obstacleCls.MonsterSet);
		unit.Object = unit.MonsterSet.Monster;
		return unit;
	end, function (unit, obj)
		obj.Obstacle = true;
		obj.PublicTarget = unit.Team == 'obstacle';
		local obstacleCls = obstacleClsList[unit.Obstacle];
		if unit.MonsterSet.MonsterDisabled then
			SetInstantProperty(obj, 'DisabledMonsterType', unit.MonsterSet.MonsterDisabled);
		end
		if unit.MonsterSet.MonsterDestroyed then
			SetInstantProperty(obj, 'DestroyedMonsterType', unit.MonsterSet.MonsterDestroyed);
		end
		if unit.MonsterSet.MonsterFueled then
			SetInstantProperty(obj, 'FueledMonsterType', unit.MonsterSet.MonsterFueled);
		end
		SetInstantProperty(obj, 'ObstacleType', unit.Obstacle);
		if obstacleCls.DangerRange > 0 then
			SetupNearObjectCache(obj, obstacleCls.DangerRange);
		end
		for _, interactionCls in ipairs(obstacleCls.InteractionList) do
			EnableInteraction(obj, interactionCls.name);
		end
	end, function (unit, obj)
		local obstacleCls = obstacleClsList[unit.Obstacle];
		if obstacleCls.Method.name ~= 'None' and obstacleCls.Method.Mastery.name then
			UpdateTemporaryMastery(obj, obstacleCls.Method.Mastery.name, 1);
		end
		UpdateTemporaryMastery(obj, 'Obstacle', 1);
	end);
	
	-- 시민
	local citizenCount = 0;
	local citizenKeyIndex = 1;
	local citizenTypeList = GetClassList('Citizen');
	SetUnitInitialize(mid, 'Citizen', mapComponents.Citizen, function(unit)
		local citizenCls = citizenTypeList[unit.CitizenType or 'Healthy'];
		local objectInfo = table.randompick(citizenCls.Objects);
		if not IsValidString(unit.Object) then
			unit.Object = objectInfo.Type;
		end
		if not IsValidString(unit.FakeObject) then
			unit.FakeObject = objectInfo.FakeObject;
		end
		unit.Team = 'citizen';
		unit.AI = {{AIType='DoNothingAI'}};
		if not IsValidString(unit.Key) then
			unit.Key = 'Citizen' .. citizenKeyIndex;
			citizenKeyIndex = citizenKeyIndex + 1;
		end
		citizenCount = citizenCount + 1;
		return unit;
	end, function(unit, obj)
		SetInstantProperty(obj, 'CitizenType', unit.CitizenType or 'Healthy');
		local citizenCls = citizenTypeList[unit.CitizenType or 'Healthy'];
		citizenCls.Initializer(mission, citizenCls, unit, obj);
		
		local saviorKey = nil;
		local citizenKey = nil;
		if type(unit.ConditionOutputCitizen) ~= 'string' then
			saviorKey = SafeIndex(unit, 'ConditionOutputCitizen', 1, 'Savior');
			citizenKey = SafeIndex(unit, 'ConditionOutputCitizen', 1, 'Citizen');
		end
		
		local successActionList = SafeIndex(unit, 'OnSuccessActionList', 1, 'Action');
		if type(successActionList) == 'table' then
			SubscribeWorldEvent(obj, 'CitizenRescuing', function(eventArg, ds)
				if eventArg.Unit ~= obj then
					return;
				end
				local conditionOutput = {};
				if saviorKey ~= nil and saviorKey ~= '' then
					conditionOutput[saviorKey] = eventArg.Savior;
				end
				if citizenKey ~= nil and citizenKey ~= '' then
					conditionOutput[citizenKey] = eventArg.Unit;
				end
				return unpack(PlayTriggerAction(GetMission(mid), ds, successActionList, conditionOutput));
			end);
		end
		local failActionList = SafeIndex(unit, 'OnFailActionList', 1, 'Action');
		if type(failActionList) == 'table' then
			SubscribeWorldEvent(obj, 'CitizenRescueFailed', function(eventArg, ds)
				if eventArg.Unit ~= obj then
					return;
				end
				local conditionOutput = {};
				if saviorKey ~= nil and saviorKey ~= '' then
					conditionOutput[saviorKey] = eventArg.Savior;
				end
				if citizenKey ~= nil and citizenKey ~= '' then
					conditionOutput[citizenKey] = eventArg.Unit;
				end
				return unpack(PlayTriggerAction(GetMission(mid), ds, failActionList, conditionOutput));
			end);
		end
	end);
	mission.CitizenCount = citizenCount;
	
	-- 상호작용 오브젝트
	SetUnitInitialize(mid, 'Interaction', mapComponents.Interaction, function(unit)
		if unit.Team == nil or unit.Team == '' then
			unit.Team = '_neutral';
		end
		unit.AI = {{AIType='DoNothingAI'}};
		return unit;
	end, function(unit, obj)
		EnableInteraction(obj, unit.Interaction);
		local actionList = SafeIndex(unit, 'ActionList', 1, 'Action');
		local interactorKey = nil;
		local interacteeKey = nil
		local conditionOutput = SafeIndex(unit, 'ConditionOutputInteraction');
		if type(conditionOutput) == 'table' then
			interactorKey = SafeIndex(conditionOutput, 1, 'Interactor');
			interacteeKey = SafeIndex(conditionOutput, 1, 'Interactee');
		end
		if type(actionList) == 'table' then
			SubscribeWorldEvent(obj, 'UnitInteractObject_Self', function(eventArg, ds)
				if eventArg.Target ~= obj then
					return;
				end
				local conditionOutput = {};
				if interactorKey ~= nil and interactorKey ~= '' then
					conditionOutput[interactorKey] = eventArg.Unit;
				end
				if interacteeKey ~= nil and interacteeKey ~= '' then
					conditionOutput[interacteeKey] = eventArg.Target;
				end
				return unpack(PlayTriggerAction(GetMission(mid), ds, unit.ActionList[1].Action, conditionOutput));
			end);
		end
	end);
	
	-- 감시탑
	SetUnitInitialize(mid, 'Watchtower', mapComponents.Watchtower, function(unit)
		unit.TowerState = unit.TowerState or 'Active'
		if unit.TowerState == 'Destroyed' then
			unit.Team = '_neutral_';
		end
		unit.Object = GetWatchtowerMonsterType(unit.TowerState, unit.Team);
		unit.AI = {{AIType='DoNothingAI'}};
		unit.Key = GenerateUnnamedObjKey(mid);
		unit.Patrol = false;
		return unit;
	end, function(unit, obj)
		InitializeWatchtower(unit.TowerState, obj);
	end);
	
	-- 감시망
	SetUnitInitialize(mid, 'SurveillanceNetwork', mapComponents.SurveillanceNetwork, function(unit)
		unit.Object = 'SurveillanceNetwork';
		unit.Key = GenerateUnnamedObjKey(mid);
		unit.AI = {{AIType='DoNothingAI'}};
		unit.Patrol = false;
		return unit;
	end, function(unit, obj)
		InitializeSurveillanceNetwork(obj, unit.OnOff == 'On');
	end);

	-- 조사대상
	SetUnitInitialize(mid, 'InvestigationTarget', mapComponents.InvestigationTarget, function(unit)
		local investigationInfo = unit.InvestigationType[1];
		local invType = investigationInfo.Type;
		unit.Object = 'InvestigationTarget_' .. invType;
		if invType == 'Chest' then
			local chestType = SafeIndex(investigationInfo, 'ChestType');
			if chestType then
				local chestTypeCls = GetClassList('ChestType')[chestType];
				if chestTypeCls and chestTypeCls.name then
					unit.Object = chestTypeCls.MonsterActive.name;
				end
			end
		end
		if not IsValidString(unit.Key) then
			unit.Key = GenerateUnnamedObjKey(mid);
		end
		unit.AI = {{AIType='DoNothingAI'}};
		if invType == 'Lock' then
			unit.Team = 'fake_citizen';
		elseif invType == 'Server' and investigationInfo.ServerType[1].Type == 'Enemy' then
			unit.Team = investigationInfo.ServerType[1].Team;
		else
			unit.Team = '_neutral_';
		end
		unit.Patrol = false;
		return unit;
	end, function(unit, obj)
		InitializeInvestigationTarget(unit, obj);
	end);
	
	-- 조사원
	SetUnitInitialize(mid, 'SecretAgent', mapComponents.SecretAgent, function(unit)
		local secretAgentInfo = SafeIndex(unit, 'SecretAgentType', 1);
		unit.Team = 'secret_agent';
		return unit;
	end, function(unit, obj)
		InitializeSecretAgent(obj, unit);
	end);
	
	-- 호위대상
	SetUnitInitialize(mid, 'EscortTarget', mapComponents.EscortTarget, function(unit)
		local escortTargetInfo = SafeIndex(unit, 'EscortTargetType', 1);
		unit.Team = 'player';
		if escortTargetInfo.Object then
			unit.Object = escortTargetInfo.Object;
		end
		if escortTargetInfo.Type == 'TransportDrone' then
			unit.Object = 'TransportDrone';
			unit.AI = {{AIType = 'TransportDroneAI', PatrolRoute = escortTargetInfo.PatrolRoute}};
			unit.NoControl = true;
		elseif escortTargetInfo.Type == 'Combatant' then
			unit.AI = escortTargetInfo.CombatantAI;
			unit.PatrolRoute = escortTargetInfo.PatrolRoute;
			unit.PatrolMethod = 'Rotate';
			unit.PatrolRepeat = 1;
			unit.SelfSightBattleTest = true;
			unit.NoControl = true;
		end
		return unit;
	end, function(unit, obj)
		InitializeEscortTarget(obj, unit);
		if unit.NoControl then
			SetControllable(obj, false);
		end
	end);

	-- 지형 효과
	SetFieldEffectInitialize(mid, mapComponents.FieldEffect);
	
	-- 이능석
	SetPsionicStoneInitialize(mid, mapComponents.PsionicStone, psionicStoneDashboards);
	
	-- 드라키 알
	SetDrakyEggInitialize(mid, mapComponents.DrakyEgg);
	
	-- 상호작용 지역
	SetInteractionAreaInitialize(mid, mapComponents.InteractionArea);
	
	-- 퀘스트 초기화 작업
	local questClsList = GetClassList('Quest');
	for _, quest in ipairs(activeQuests) do
		local questCls = questClsList[quest];
		if questCls == nil then
			LogAndPrint('questCls', quest);
		end
		if questCls.Type.MissionInitializer ~= nil then
			questCls.Type.MissionInitializer(mid, questCls);
		end
	end
	
	-- StartPosition에 할당되지 않는 로스터 오브젝트 정리
	for _, info in pairs(rosterUnits) do
		-- 일반 오브젝트를 대체해서 사용되지 않으면, 게임에 남아있을 필요가 없으므로 파괴한다.
		if info.Replace == nil and info.RosterObject then
			DestroyMonster(info.RosterObject);
			info.RosterObject.IsUserMember = false;
		end
	end
	
	-- 미션 시작 시 씬 페이더 효과
	if mission.BeginFadeOut then
		SubscribeGlobalWorldEvent(mid, 'MissionPrepare', function(eventArg, ds)
			ds:SceneFadeOut('', true);
		end, -1);
	end
	
	-- 도전 모드 특성 캐쉬 정리
	ClearChallengerMasteryCache(mid);
end

function MapReinitializerShared(mid, stage, memberInfos)
	local mission = GetMission(mid);
	local singlePlay = #memberInfos == 1;
	
	if singlePlay then
		local company = GetAllCompanyInMission(mid)[1];
		-- mission 난이도 설정
		local prevDifficulty = mission.Difficulty.name;
		local missionLv = mission.Difficulty.Lv;
		if company.GameDifficulty == 'Easy' then
			missionLv = math.clamp(missionLv, 1, 3);
		elseif company.GameDifficulty == 'Normal' then
			missionLv = math.clamp(missionLv + 3, 4, 6)
		elseif company.GameDifficulty == 'Hard' then
			missionLv = math.clamp(missionLv + 6, 7, 9);
		end
		mission.Difficulty = GetClassList('MissionDifficulty')['Difficulty'..missionLv];
		SetMissionLevel(mission, missionLv);
		mission.DifficultyGrade = company.GameDifficulty;
		--LogAndPrint(string.format('MissionDifficulty Arranged From [%s] to [%s]', prevDifficulty, mission.Difficulty.name));
	end
	
	-- General Initializer --
	RegisterGlobalEventHandler(mid);
	
	-- Stage Variable Initialize
	InitializeStageVariables(mission, SafeIndex(stage, 'Variables', 1, 'Variable'), true);
	
	-- 위치 지정
	SetPositionHolderInitialize(mid, stage.MapComponents[1].PositionHolder);
	
	-- 미션 오브젝티브 및 메인 패널 대시보드 등록
	local objectiveSet = {};
	local objectives = stage.Objectives[1].Objective;
	if objectives then
		for i, objective in ipairs(objectives) do
			objectiveSet[objective.Key] = objective;
		end
	end
	local mainPanelDashboard = {Type='MainPanel', MainObjective = {{}}, Objective1 = {{}}, Objective2 = {{}}, Objective3 = {{}}, Objective4= {{}}, Objective5= {{}}, Objective6= {{}}};
	local missionObjectiveClsList = GetClassList('MissionObjective');
	for panelKey, info in pairs(mission.Objectives) do
		 local key = info.Key;
		 local objective = objectiveSet[key];
		 if objective then
			local missionObjectiveCls = missionObjectiveClsList[objective.Type];
			
			-- 실질적인 오브젝티브의 초기화 및 관련 이벤트 핸들링 처리들
			missionObjectiveCls.Initializer(mission, objective, panelKey, true);
		 end
	end
	
	--- Mission Dashboard 등록 ---
	local missionStageKey = mission.StageKey;
	local psionicStoneDashboards = {};
	local dashboards = stage.Dashboards[1].Dashboard;
	if dashboards then
		for i, dashboard in ipairs(dashboards) do
			local stageKey = dashboard.StageKey;
			local key = dashboard.Key;
			dashboard.Key = nil;	-- key는 지워주자
			dashboard.StageKey = nil;	-- StageKey도
			if stageKey == 'All' or stageKey == missionStageKey then		-- StageKey가 All이거나 mission의 StageKey와 같은 대쉬보드 타입만 등록할거임
				local dashboardInst = GetMissionDashboard(mission, key);
				if dashboardInst == nil then
					LogAndPrint('Dashboard is nil', key);
				end
				if dashboardInst.Initializer then
					dashboardInst:Initializer(key, mission, stage, dashboard, true);
				end
				if dashboard.Type == 'PsionicStone' then
					psionicStoneDashboards[key] = dashboard;
				end
			end
		end
	end
	
	--- Map Component Setting --- 
	local mapComponents = stage.MapComponents[1];
	
	local bossList = {};
	local normalObjectReinitializer = function(unit, mon)
		if mon.Info == nil or mon.Info.name == nil then
			local monCls = GetClassList('Monster')[unit.Object];
			if monCls then
				mon.Info = GetClassList('ObjectInfo')[monCls.Info.name];
			else
				LogAndPrint(string.format('[DataError] :: Reinializer failed - mission: %s, mon: %s:%s', mission.name, GetObjKey(mon), mon.name));
				return;
			end
		end
		if mon.Info.NamedEvent.name ~= nil and mon.Info.NamedEvent.name ~= 'None' 
			and unit.AutoBossEvent and tostring(unit.AutoBossEvent) ~= 'false' then
			table.insert(bossList, mon);
		end
	end
	
	local componentIterator = function(componentKey, componentDeclarations, iterFunc)
		for i, unit in ipairs(componentDeclarations) do
			local mon = RetrieveMapComponentObject(mid, componentKey, i);
			iterFunc(unit, mon);
		end
	end;

	-- 적
	componentIterator('Enemy', mapComponents.Enemy, normalObjectReinitializer);
	componentIterator('Ally', mapComponents.Ally, normalObjectReinitializer);
	componentIterator('Neutral', mapComponents.Neutral, normalObjectReinitializer);
	
	-- 일반 오브젝트
	componentIterator('Object', mapComponents.Object, normalObjectReinitializer);
	
	RegisterAutoBossEvent(mid, bossList, true);
	
	-- 시민
	local citizenCount = 0;
	local citizenTypeList = GetClassList('Citizen');
	for i, unit in ipairs(mapComponents.Citizen) do
		local obj = RetrieveMapComponentObject(mid, 'Citizen', i);
		
		if obj then
			local saviorKey = nil;
			local citizenKey = nil;
			if type(unit.ConditionOutputCitizen) ~= 'string' then
				saviorKey = SafeIndex(unit, 'ConditionOutputCitizen', 1, 'Savior');
				citizenKey = SafeIndex(unit, 'ConditionOutputCitizen', 1, 'Citizen');
			end
			
			local successActionList = SafeIndex(unit, 'OnSuccessActionList', 1, 'Action');
			
			if type(successActionList) == 'table' then
				SubscribeWorldEvent(obj, 'CitizenRescuing', function(eventArg, ds)
					if eventArg.Unit ~= obj then
						return;
					end
					local conditionOutput = {};
					if saviorKey ~= nil and saviorKey ~= '' then
						conditionOutput[saviorKey] = eventArg.Savior;
					end
					if citizenKey ~= nil and citizenKey ~= '' then
						conditionOutput[citizenKey] = eventArg.Unit;
					end
					return unpack(PlayTriggerAction(GetMission(mid), ds, successActionList, conditionOutput));
				end);
			end
			local failActionList = SafeIndex(unit, 'OnFailActionList', 1, 'Action');
			if type(failActionList) == 'table' then
				SubscribeWorldEvent(obj, 'CitizenRescueFailed', function(eventArg, ds)
					if eventArg.Unit ~= obj then
						return;
					end
					local conditionOutput = {};
					if saviorKey ~= nil and saviorKey ~= '' then
						conditionOutput[saviorKey] = eventArg.Savior;
					end
					if citizenKey ~= nil and citizenKey ~= '' then
						conditionOutput[citizenKey] = eventArg.Unit;
					end
					return unpack(PlayTriggerAction(GetMission(mid), ds, failActionList, conditionOutput));
				end);
			end
		end
	end
	
	-- 상호작용 오브젝트
	for i, unit in ipairs(mapComponents.Interaction) do
		local obj = RetrieveMapComponentObject(mid, 'Interaction', i);
		if obj then
			local actionList = SafeIndex(unit, 'ActionList', 1, 'Action');
			local interactorKey = nil;
			local interacteeKey = nil
			local conditionOutput = SafeIndex(unit, 'ConditionOutputInteraction');
			if type(conditionOutput) == 'table' then
				interactorKey = SafeIndex(conditionOutput, 1, 'Interactor');
				interacteeKey = SafeIndex(conditionOutput, 1, 'Interactee');
			end
			if type(actionList) == 'table' then
				SubscribeWorldEvent(obj, 'UnitInteractObject_Self', function(eventArg, ds)
					if eventArg.Target ~= obj then
						return;
					end
					local conditionOutput = {};
					if interactorKey ~= nil and interactorKey ~= '' then
						conditionOutput[interactorKey] = eventArg.Unit;
					end
					if interacteeKey ~= nil and interacteeKey ~= '' then
						conditionOutput[interacteeKey] = eventArg.Target;
					end
					return unpack(PlayTriggerAction(GetMission(mid), ds, unit.ActionList[1].Action, conditionOutput));
				end);
			end
		end
	end;

	-- 조사대상
	for i, unit in ipairs(mapComponents.InvestigationTarget) do
		local obj = RetrieveMapComponentObject(mid, 'InvestigationTarget', i);
		if obj then
			InitializeInvestigationTarget(unit, obj, true);
		end
	end;
	
	-- 조사원
	for i, unit in ipairs(mapComponents.SecretAgent) do
		local obj = RetrieveMapComponentObject(mid, 'SecretAgent', i);
		if obj then
			InitializeSecretAgent(obj, unit, true);
		end
	end;
	
	-- 호위대상
	for i, unit in ipairs(mapComponents.EscortTarget) do
		local obj = RetrieveMapComponentObject(mid, 'EscortTarget', i);
		if obj then
			InitializeEscortTarget(obj, unit, true);
		end
	end;
	
	-- 상호작용 지역
	SetInteractionAreaInitialize(mid, mapComponents.InteractionArea, true);
	
	-- 퀘스트 초기화 작업
	local questClsList = GetClassList('Quest');
	for _, quest in ipairs(activeQuests) do
		local questCls = questClsList[quest];
		if questCls.Type.MissionInitializer ~= nil then
			questCls.Type.MissionInitializer(mid, questCls, true);
		end
	end
	
	-- MissionReinitialized 이벤트 던짐
	ApplyActions(mid, { Result_FireWorldEvent('MissionReinitialized', {}) }, true);
end

function InitializeStageVariables(mission, variables, reinitialize)
	if variables == nil then
		return;
	end
	local variableTypeClsList = GetClassList("StageVariable");
	for i, variable in ipairs(variables) do
		local variableTypeCls = variableTypeClsList[variable.Type];
		-- LogAndPrint('Initialize Stage Variable', variable.Key, variable.Type);
		variableTypeCls:Initializer(mission, variable, reinitialize);
	end
end

function MapInitializer(mid, stage, memberInfos)
end

function UpdateEnemyGradeUp(unitList, gradeUpCount)
	if not unitList then
		return;
	end

	local monClsList = GetClassList('Monster');

	local picker = RandomPicker.new(false);
	for i = 1, #unitList do
		local unit = unitList[i];
		local monCls = monClsList[unit.Object];
		if monCls == nil then
			LogAndPrint(string.format('[DataError] :: [%s:%s] object is not exists Monster.xml', unit.Key, unit.Object));
		end
		if monCls and monCls.GradeUp ~= '' and monCls.GradeUp ~= 'None' and monClsList[monCls.GradeUp].name ~= 'None' and not StringToBool(unit.DisableGradeUp, false) then
			picker:addChoice(1, { Index = i, GradeUp = monCls.GradeUp, BaseMon = monCls.name });
		end
	end

	for i = 1, gradeUpCount do
		local pick = picker:pick();
		if pick == nil then
			break;
		end

		unitList[pick.Index].Object = pick.GradeUp;
		unitList[pick.Index].BaseObject = pick.BaseMon;
	end
end

function GetRosterUnitInfos(mapComponents)
	local rosterUnitInfos = {};
	for _, componentTag in ipairs({ 'Enemy', 'Ally', 'Neutral', 'Object' }) do
		local unitList = mapComponents[componentTag];
		if unitList then
			for i = 1, #unitList do
				local unit = unitList[i];
				local rosterInfo = unit.RosterInfo;
				if rosterInfo and rosterInfo[1] then
					local rosterKey = rosterInfo[1].RosterKey;
					local rosterMode = rosterInfo[1].RosterMode;
					local info = rosterUnitInfos[rosterKey];
					if not info then
						info = { Replace = nil, Copy = {} };
						rosterUnitInfos[rosterKey] = info;
					end
					if rosterMode == 'Replace' then
						if info.Replace == nil then
							info.Replace = unit;
						else
							LogAndPrint(string.format('[DataError] :: [%s] object has duplicated roster key [%s] with [%s]', unit.Key, rosterKey, info.Replace.Key));
						end
					else
						table.insert(info.Copy, unit);
					end
				end
			end
		end
	end
	return rosterUnitInfos;
end

function RegisterAutoBossEvent(mid, bossList, reinitialize)
	local dangerBossList = table.filter(bossList, function(o) return GetInstantProperty(o, 'NeedBossDangerEvent') end);
	
	for _, boss in ipairs(dangerBossList) do
		local exhausted = false;
		SubscribeWorldEvent(boss, 'UnitPropertyUpdated_Self', function(eventArg, ds, subscriptionID)
			if boss.HP <= 0
				or eventArg.PropertyName ~= 'HP'
				or boss.HP > boss.MaxHP / 2
				or exhausted then
				return;
			end
			SetInstantProperty(boss, 'NeedBossDangerEvent', nil);
			local bossKey = GetObjKey(boss);
			ds:StartMissionDirect(true);
			ds:MissionSubInterfaceVisible(false);
			ds:ChangeStatusVisible(false);
			ds:SkipPointOn();
			ds:EnableTemporalSightTarget(bossKey, 0, 3);
			ds:ChangeCameraTarget(bossKey, '_SYSTEM_', false);
			
			local actions = {};
			table.append(actions, {DoNamedDangerDirecting(boss.Info.NamedEvent, boss, ds)});
			
			ds:ChangeCameraTarget(foundTargetKey, '_SYSTEM_', false);
			ds:DisableTemporalSightTarget(bossKey, 0);
			ds:SkipPointOff();
			ds:ChangeStatusVisible(true);
			ds:MissionSubInterfaceVisible(true);
			ds:EndMissionDirect(true);
			
			UnsubscribeWorldEvent(boss, subscriptionID);
			exhausted = true;
			return unpack(actions);
		end);
	end

	local meetBossList = table.filter(bossList, function(o) return GetInstantProperty(o, 'NeedBossMeetEvent') end);
	local bossKeyMap = Set.new(table.map(meetBossList, function(o) return GetObjKey(o); end));
	SubscribeGlobalWorldEvent(mid, 'UnitMoved', function(eventArg, ds)
		if #meetBossList == 0 then
			return;
		end
		if GetTeam(eventArg.Unit) ~= 'player' and bossKeyMap[GetObjKey(eventArg.Unit)] == nil then
			return;
		end
		local foundTarget = nil;
		local found = {};
		local battleBossList = table.filter(meetBossList, function(o) return not o.PreBattleState; end)
		if GetTeam(eventArg.Unit) == 'player' then
			foundTarget = eventArg.Unit;
			for _, boss in ipairs(battleBossList) do
				if IsInSight(eventArg.Unit, GetPosition(boss), true) then
					table.insert(found, boss);
				end
			end
		else
			local foundPlayers = table.filter(GetAllUnitInSight(eventArg.Unit, true), function(o) return GetTeam(o) == 'player'; end);
			if #foundPlayers > 0 then
				foundTarget = foundPlayers[1];
				table.insert(found, eventArg.Unit);
			end
		end
		
		-- 보스 리스트 갱신
		local foundKeySet = Set.new(table.map(found, function(o) 
			bossKeyMap[GetObjKey(o)] = nil;
			return GetObjKey(o); 
		end));
		meetBossList = table.filter(meetBossList, function(o) return not foundKeySet[GetObjKey(o)]; end);
		found = table.filter(found, function(o) return o.HP > 0; end);
		if #found == 0 then
			return;
		end
		
		local foundTargetKey = GetObjKey(foundTarget)
		local actions = {};
		
		ds:StartMissionDirect(true);
		ds:MissionSubInterfaceVisible(false);
		ds:ChangeStatusVisible(false);
		ds:SkipPointOn();
		for _, boss in ipairs(found) do
			SetInstantProperty(boss, 'NeedBossMeetEvent', nil);
			local bossKey = GetObjKey(boss);
			
			ds:EnableTemporalSightTarget(bossKey, 0, 3);
			ds:ChangeCameraTarget(bossKey, '_SYSTEM_', false);
			
			table.append(actions, {DoNamedMeetDirecting(boss.Info.NamedEvent, boss, foundTarget, ds)});
			
			ds:ChangeCameraTarget(foundTargetKey, '_SYSTEM_', false);
			ds:DisableTemporalSightTarget(bossKey, 0);
		end
		ds:SkipPointOff();
		ds:ChangeStatusVisible(true);
		ds:MissionSubInterfaceVisible(true);
		ds:EndMissionDirect(true);
		return unpack(actions);
	end);
end