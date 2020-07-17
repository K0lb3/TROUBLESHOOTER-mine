function InitializeInvestigationTarget(unitDecl, obj, reinitialize)
	local investigationInfo = SafeIndex(unitDecl, 'InvestigationType', 1);
	local investigationType = investigationInfo.Type;
	local investigationTargetCls = GetClassList('InvestigationTarget')[investigationType];
	
	if not reinitialize then
		obj.ScentOfPresence = false;
		
		if investigationType == 'Chest' then
			local mission = GetMission(obj);
			local openReward = SafeIndex(investigationInfo, 'OpenReward_Chest', 1);
			if openReward.Type == 'Item_Chest_Difficulty' then
				-- 현재 난이도에 맞는 아이템이 하나도 없으면, 상자를 없앤다.
				local itemCollections = GetItemCollections(mission, openReward);
				if itemCollections == nil or #itemCollections == 0 then
					DestroyMonster(obj);
					return;
				end
			elseif openReward.Type == 'ItemSet_Chest_Difficulty' then
				local itemCollectionSet = GetItemCollectionSet(mission, openReward);
				if itemCollectionSet == nil or itemCollectionSet == 'None' then
					DestroyMonster(obj);
					return;
				end
			end
		end	
		
		EnableInteraction(obj, investigationTargetCls.Interaction.name);
		local infomationPriority = SafeIndex(investigationInfo, 'OpenReward_Chest', 1, 'Priority')
									or SafeIndex(investigationInfo, 'OpenReward_Lock', 1, 'Priority')
									or SafeIndex(investigationInfo, 'Priority');
		SetInstantProperty(obj, 'InformationPriority', infomationPriority);		-- 있으면 설정될듯
		SetInstantPropertyWithUpdate(obj, 'InvestigationInfo', investigationInfo);
	end
	
	SubscribeWorldEvent(obj, 'InvestigationOccured', investigationTargetCls.InvestigationOccuredCallback(obj, investigationInfo));
	
	if investigationInfo.Type == 'Pc' then
		local interactorKey = SafeIndex(investigationInfo, 'ConditionOutputInteraction', 1, 'Interactor');
		local interacteeKey = SafeIndex(investigationInfo, 'ConditionOutputInteraction', 1, 'Interactee');
		local successActionList = SafeIndex(investigationInfo, 'OnSuccessActionList', 1, 'Action');
		if type(successActionList) == 'table' then
			SubscribeWorldEvent(obj, 'InformationAcquired', function(eventArg, ds)
				if eventArg.Unit ~= obj then
					return;
				end
				local conditionOutput = {};
				if interactorKey ~= nil and interactorKey ~= '' then
					conditionOutput[interactorKey] = eventArg.Acquirer;
				end
				if interacteeKey ~= nil and interacteeKey ~= '' then
					conditionOutput[interacteeKey] = eventArg.Unit;
				end
				return unpack(PlayTriggerAction(GetMission(obj), ds, successActionList, conditionOutput));
			end);
		end
		local failActionList = SafeIndex(investigationInfo, 'OnFailActionList', 1, 'Action');
		if type(failActionList) == 'table' then
			SubscribeWorldEvent(obj, 'ContentsBroken', function(eventArg, ds)
				if eventArg.Unit ~= obj then
					return;
				end
				local conditionOutput = {};
				if interactorKey ~= nil and interactorKey ~= '' then
					conditionOutput[interactorKey] = eventArg.Breaker;
				end
				if interacteeKey ~= nil and interacteeKey ~= '' then
					conditionOutput[interacteeKey] = eventArg.Unit;
				end
				return unpack(PlayTriggerAction(GetMission(obj), ds, failActionList, conditionOutput));
			end);
		end
	end
end

function OpenEmptyChest(opener, ds, connectID)
	local interactionID = ds:UpdateInteractionMessage(GetObjKey(opener), 'EmptyChest', '');
	local sleepID = ds:Sleep(3);
	local playSoundID = ds:PlaySound('Fail.wav', 'Layout', 1);
	if connectID then
		ds:Connect(interactionID, connectID, 1.5);
	end
	ds:Connect(playSoundID, interactionID, 0.5);
	ds:Connect(sleepID, interactionID, 0);
	
	ds:AddMissionChat('Interaction', 'FoundNothing', {ObjectKey = GetObjKey(opener)});
end

function BreakLock(breaker, obj, ds, connectID)
	local interactionID = ds:UpdateInteractionMessage(GetObjKey(breaker), 'ContentsBroken', '');
	local sleepID = ds:Sleep(3);
	local playSoundID = ds:PlaySound('Fail.wav', 'Layout', 1);
	if connectID then
		ds:Connect(interactionID, connectID, 1.5);
	end
	ds:Connect(playSoundID, interactionID, 0.5);
	ds:Connect(sleepID, interactionID, 0);
	ds:AddMissionChat('Interaction', 'ContentsBroken', {ObjectKey = GetObjKey(breaker)});
	return Result_FireWorldEvent('ContentsBroken', {Unit = obj, Breaker = breaker});
end

function InvestigateInformationHolder(opener, target, onFailed, connectID, ds)
	
	if GetInstantProperty(target, 'InformationOwner') then
		local playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
		local sleepID = ds:Sleep(3);
		local interactionID = ds:UpdateInteractionMessage(GetObjKey(opener), 'InformationAcquired', '');
		if connectID then
			ds:Connect(interactionID, connectID, 1.5);
		end
		ds:Connect(playSoundID, interactionID, 0.5);
		ds:Connect(sleepID, interactionID, 0);
		return Result_FireWorldEvent('InformationAcquired', {Unit = target, Acquirer = opener});
	else
		return onFailed();
	end
end

function IdentifyItemOptionProperties(targetProperties, item, luck)
	if item.Category.IsIdentify and item.Rank.Weight > 1 then
		local option = GetIdentifyItemOptions(item);
		local identifyOptionValueList, ratio = GetIdentifyItemOptionValue(option, luck);
		if #identifyOptionValueList > 5 then
			return;
		end
		targetProperties['Option/OptionKey'] = option.name;
		targetProperties['Option/Ratio'] = ratio;
		for index, status in ipairs (identifyOptionValueList) do
			targetProperties[string.format('Option/Type%d', index)] = status.Type;
			targetProperties[string.format('Option/Value%d', index)] = status.Value;
		end
	end
end

function OnInvestigationOccured_Chest(obj, investigationInfo)
	return function(eventArg, ds)
		-- 스킵 가능
		ds:RunScriptArgs('SetDirectingSkipEnabled', true);
		ds:SkipPointOn();
		local pos = GetPosition(obj);
		local objKey = GetObjKey(obj);
		local particleID = ds:PlayParticle(objKey, '_CENTER_', 'Particles/Dandylion/OpenChest', 1);
		local playSoundID = ds:PlaySound3D('BoxOpen.wav', objKey, '_CENTER_', 3000, 'Effect', 1.0);
		local deadAniID = ds:PlayPose(objKey, 'Dead', '', true);
		ds:Connect(playSoundID, deadAniID, 0);
		ds:Connect(particleID, deadAniID, 0.3333);
		local openReward = SafeIndex(investigationInfo, 'OpenReward_Chest', 1);
		local isInformationType = openReward.Type == 'Information';
		local unitInitializeFunc = function(unit, arg)
			UNIT_INITIALIZER_NON_BATTLE(unit, unit.Team);
		end;
		local objectOff = 'Object_ItemCube_Off';
		local chestType = SafeIndex(investigationInfo, 'ChestType');
		if chestType then
			local chestTypeCls = GetClassList('ChestType')[chestType];
			if chestTypeCls and chestTypeCls.name then
				objectOff = chestTypeCls.ObjectOff.name;
			end
		end		
		local createAction = Result_CreateObject(GenerateUnnamedObjKey(obj), objectOff, pos, GetTeam(obj), unitInitializeFunc, {}, 'DoNothingAI', nil, true, GetDirection(obj));
		createAction.sequential = true;		
		ds:WorldAction(Result_DestroyObject(obj, false, true));
		ds:WorldAction(createAction);
		
		-- 유닛, 회사 통계 갱신
		AddUnitStats(eventArg.Detective, 'OpenChest', 1, true);
		local company = GetCompany(eventArg.Detective);
		if company then
			ds:AddSteamStat('OpenChestCount', 1, GetUserTeam(company));
		end
		
		local actions = { (function()
			if isInformationType then
				return InvestigateInformationHolder(eventArg.Detective, obj, function() 
					OpenEmptyChest(eventArg.Detective, ds, deadAniID);
				end, deadAniID, ds);
			else
				local itemCollections = GetItemCollections(GetMission(obj), openReward);
				if itemCollections then
					itemCollections = RebaseXmlTableToClassTable(itemCollections);
				else
					local setType = GetItemCollectionSet(GetMission(obj), openReward);
					if setType == nil or setType == 'None' then
						itemCollections = nil;
					else
						itemCollections = GetClassList('ItemBox')[setType].Slot;
					end
				end
				if itemCollections == nil or #itemCollections == 0 then
					OpenEmptyChest(eventArg.Detective, ds, deadAniID);
					return;
				end
				local picker = RandomPicker.new();
				for i, slot in ipairs(itemCollections) do
					picker:addChoice(slot.Priority, SafeIndex(slot, 'Item'));
				end
				local pickedItem = picker:pick();
				LogAndPrint('pickedItem', pickedItem);
				local giveItem = Result_GiveItemByItemIndicator(eventArg.Detective, pickedItem, {});
				if giveItem == nil then
					OpenEmptyChest(eventArg.Detective, ds, deadAniID);
					return;
				end
				return GiveItemWithInstantEquipDialog(ds, giveItem, eventArg.Detective, deadAniID, 1.5);
			end
		end)() };
		-- 스킵 종료
		ds:SkipPointOff();
		ds:RunScriptArgs('SetDirectingSkipEnabled', false);
		return unpack(actions);
	end;
end

function GiveItemWithInstantEquipDialog(ds, giveItem, target, refId, refOffset)
	local itemCls = GetClassList('Item')[giveItem.item_type];
	local itemProperties = {};
	IdentifyItemOptionProperties(itemProperties, itemCls);
	
	local playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
	local sleepID = ds:Sleep(3);
	local interactionID = ds:UpdateInteractionMessage(GetObjKey(target), 'ItemAcqired', giveItem.item_type, itemProperties);
	if refId then
		ds:Connect(interactionID, refId, refOffset);
	end
	ds:Connect(playSoundID, interactionID, 0.5);
	ds:Connect(sleepID, interactionID, 0);
	
	local enableEquip = IsEnableEquipItem(target, itemCls);	
	local temporaryEquip = not itemCls.Consumable and GetRosterFromObject(target) == nil;
	local yielding = itemCls.Consumable and GetRosterFromObject(target) == nil;
	
	local mySlotIsEmpty = false;
	local curUseCount = nil;
	local discardWhenEquip = false;
	local equipPos = GetAutoEquipmentPosition(target, itemCls, true);
	if equipPos ~= nil then
		local prevItem = target[equipPos];
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
	local id, sel = ds:Dialog('InstantEquipDialog', {ObjKey = GetObjKey(target), ItemType = itemCls.name, EnableEquip = enableEquip, ItemProperties = itemProperties, MySlotIsEmpty = mySlotIsEmpty, IsTemporaryEquip = temporaryEquip, IsYielding = yielding, CurUseCount = curUseCount, DiscardWhenEquip = discardWhenEquip, EquipPos = equipPos});
	if enableEquip and sel == 1 then		-- Yes
		local actions = {Result_EquipItem(target, itemCls.name, itemProperties, equipPos)};
		if temporaryEquip then
			giveItem.item_properties = itemProperties;
			table.insert(actions, giveItem);
		end
		return unpack(actions);
	end
	giveItem.item_properties = itemProperties;
	
	local giveItemConverter = BuildGiveItemConverter(target);
	return giveItemConverter(giveItem);
end

function OnInvestigationOccured_Lock(obj, investigationInfo)
	return function(eventArg, ds)
		-- 스킵 가능
		ds:RunScriptArgs('SetDirectingSkipEnabled', true);
		ds:SkipPointOn();
		local pos = GetPosition(obj);
		local objKey = GetObjKey(obj);
		local particleID = ds:PlayParticle(objKey, '_CENTER_', 'Particles/Dandylion/OpenChest', 1);
		local playSoundID = ds:PlaySound3D('BoxOpen.wav', objKey, '_CENTER_', 3000, 'Effect', 1.0);
		local deadAniID = ds:PlayPose(objKey, 'Dead', '', true);
		ds:Connect(playSoundID, deadAniID, 0);
		ds:Connect(particleID, deadAniID, 0.3333);
		local openReward = SafeIndex(investigationInfo, 'OpenReward_Lock', 1);
		local isInformationType = openReward.Type == 'Information';
		local unitInitializeFunc = function(unit, arg)
			UNIT_INITIALIZER_NON_BATTLE(unit, unit.Team);
		end;
		local objectOff = 'Object_ItemCubeLock_Off';
		local keyItem = nil;
		local lockType = SafeIndex(investigationInfo, 'LockType');
		if lockType then
			local lockTypeCls = GetClassList('LockType')[lockType];
			if lockTypeCls and lockTypeCls.name then
				objectOff = lockTypeCls.ObjectOff.name;
				keyItem = SafeIndex(lockTypeCls, 'KeyItem', 'name');
			end
		end
		local usingPos = GetPosition(obj);
		local success = false;
		if eventArg.Ability == 'InvestigateLock_Key' then
			if keyItem then
				local ability = GetAbilityObject(eventArg.Detective, eventArg.Ability);
				if ability and ability.UseCount > 0 then
					local equipItem = GetWithoutError(eventArg.Detective, 'Inventory2');
					if equipItem and equipItem.name == keyItem then
						success = true;
					end
				end
			end
		elseif eventArg.Ability == 'InvestigateLock_Force' then
			local ability = GetAbilityObject(eventArg.Detective, eventArg.Ability);
			if ability then
				local mission = GetMission(obj);
				local weather = mission.Weather.name;
				local missionTime = mission.MissionTime.name;
				local temperature = mission.Temperature.name;
				local hitRate = ability.GetHitRateCalculator(eventArg.Detective, obj, ability, usingPos, weather, missionTime, temperature);
				-- 성공 확률 테스트
				if RandomTest(hitRate) then
					success = true;
				end
			end
		end
		if not success then
			ds:ShowFrontmessageWithText(GameMessageFormText({ Type = 'LockForceFailed' }, 'Corn'), 'Corn');
			ds:WorldAction(Result_AddFieldEffect('Fire', { usingPos }, obj));
			ds:UpdateBalloonCivilMessage(GetObjKey(eventArg.Detective), 'LockForceFailed', eventArg.Detective.Info.AgeType);
		end
		
		local createAction = Result_CreateObject(GenerateUnnamedObjKey(obj), objectOff, pos, GetTeam(obj), unitInitializeFunc, {}, 'DoNothingAI', nil, true, GetDirection(obj));
		createAction.sequential = true;		
		ds:WorldAction(Result_DestroyObject(obj, false, true));
		ds:WorldAction(createAction);
		
		local actions = {};
		if success then
			-- 열쇠 소모
			if eventArg.Ability == 'InvestigateLock_Key' then
				UpdateAbilityPropertyActions(actions, eventArg.Detective, eventArg.Ability, 'UseCount', 0);
			end
		
			-- 유닛, 회사 통계 갱신
			AddUnitStats(eventArg.Detective, 'OpenChest', 1, true);
			local company = GetCompany(eventArg.Detective);
			if company then
				ds:AddSteamStat('OpenChestCount', 1, GetUserTeam(company));
			end
			
			table.append(actions, {(function()
				if isInformationType then
					return InvestigateInformationHolder(eventArg.Detective, obj, function() 
						OpenEmptyChest(eventArg.Detective, ds, deadAniID);
					end, deadAniID, ds);
				else
					local itemCollections = GetItemCollections(GetMission(obj), openReward);
					if itemCollections then
						itemCollections = RebaseXmlTableToClassTable(itemCollections);
					else
						local setType = GetItemCollectionSet(GetMission(obj), openReward);
						if setType == nil or setType == 'None' then
							itemCollections = nil;
						else
							itemCollections = GetClassList('ItemBox')[setType].Slot;
						end
					end
					if itemCollections == nil or #itemCollections == 0 then
						OpenEmptyChest(eventArg.Detective, ds, deadAniID);
						return;
					end
					local picker = RandomPicker.new();
					for i, slot in ipairs(itemCollections) do
						picker:addChoice(slot.Priority, SafeIndex(slot, 'Item'));
					end
					local pickedItem = picker:pick();
					local giveItem = Result_GiveItemByItemIndicator(eventArg.Detective, pickedItem, {});
					if giveItem == nil then
						OpenEmptyChest(eventArg.Detective, ds, deadAniID);
						return;
					end
					return GiveItemWithInstantEquipDialog(ds, giveItem, eventArg.Detective, deadAniID, 1.5);
				end
			end)() });
		end
		-- 스킵 종료
		ds:SkipPointOff();
		ds:RunScriptArgs('SetDirectingSkipEnabled', false);
		return unpack(actions);
	end;
end

function OnInvestigationOccured_Pc(obj, investigationInfo)
	return function(eventArg, ds)
		return InvestigateInformationHolder(eventArg.Detective, obj, function() 
			BreakLock(eventArg.Detective, obj, ds);
		end, nil, ds);
	end
end

function OnInvestigationOccured_Server(obj, investigationInfo)
	return function(eventArg, ds)
		return InvestigateInformationHolder(eventArg.Detective, obj, function()
			if investigationInfo.ServerType[1].Type == 'Ally' then
				local organization = investigationInfo.ServerType[1].Organization;
				-- 소속과의 우호도 감소 처리 필요
			else
				-- 발견처리
				ds:WorldAction(Result_FireWorldEvent('UnitDetected', {Unit=eventArg.Detective}, eventArg.Detective));
				obj.Base_SightRange = 15;
				InvalidateObject(obj);
				local actions = {Buff_Patrol_FindEnemy(obj, eventArg.Detective, nil, ds, false, nil, true, 'Patrol')};
				obj.Base_SightRange = 0;
				InvalidateObject(obj);
				return unpack(actions);
			end
		end, nil, ds);
	end
end