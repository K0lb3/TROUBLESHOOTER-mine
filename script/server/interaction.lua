function Interaction_Rescue(user, target, interactionCls, ability, ds)

end
function Interaction_Release(user, target, interactionCls, ability, ds)
	local pos = GetPosition(target);
	local objKey = GetObjKey(target);
	local particleID = ds:PlayParticle(objKey, '_CENTER_', 'Particles/Dandylion/OpenChest', 1);
	local playSoundID = ds:PlaySound3D('BoxOpen.wav', objKey, '_CENTER_', 3000, 'Effect', 1.0);
	ds:Connect(particleID, playSoundID, 0.3333);	
	
	local playSoundID2 = ds:PlaySound('Success.wav', 'Layout', 1);
	local sleepID2 = ds:Sleep(3);
	local interactionID = ds:UpdateInteractionMessage(objKey, 'Release', target.Info.name);
	ds:Connect(playSoundID2, interactionID, 0.5);
	ds:Connect(sleepID2, interactionID, 0);
end
function Interaction_Comfort(user, target, interactionCls, ability, ds)
	local actions = {};
	-- 근심 걱정 모두 떨쳐 버리고~
	ds:WorldAction(Result_RemoveBuff(target, 'Civil_Stabilized'), true);
	ds:WorldAction(Result_RemoveBuff(target, 'Civil_Unrest'), true);
	ds:WorldAction(Result_RemoveBuff(target, 'Civil_Confusion'), true);
	
	-- 안심
	return Result_AddBuff(user, target, 'Civil_Stabilized', 1);
end

function Interaction_Cure(user, target, interactionCls, ability, ds)

end

function Interaction_Repair(user, target, interactionCls, ability, ds)
	ds:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = interactionCls.Ability.name });
--	return ReplaceWatchtower(target, 'Active', GetTeam(user));
end

function Interaction_Fueling(user, target, interactionCls, ability, ds)
	local addCost = nil;
	if target.name == 'Object_ElectricCharger' then
		addCost = 400;
	elseif target.name == 'Object_OilingMachine' then
		addCost = 800;
	end
	if not addCost then
		return;
	end
	local actions = {};
	local _, reasons = AddActionCost(actions, user, addCost, true, true);			
	ds:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = interactionCls.Ability.name });
	ds:UpdateBattleEvent(GetObjKey(user), 'AddCost', { CostType = user.CostType.name, Count = addCost });
	ReasonToUpdateBattleEventMulti(user, ds, reasons);
	
	local disabledMonType = GetInstantProperty(target, 'FueledMonsterType');
	if disabledMonType then
		local direction = GetDirection(target);
		local newObjKey = GenerateUnnamedObjKey(GetMission(target));
		local destroy = Result_DestroyObject(target, false, true);
		local create = Result_CreateMonster(newObjKey, disabledMonType, GetPosition(target), '_neutral_', function(obj, arg)
			UNIT_INITIALIZER(obj, GetTeam(obj));
			SetDirection(obj, direction);
		end, nil, 'DoNothingAI', {}, true);
		local directing = Result_DirectingScript('Direct_ObstacleDisabled', {ObjKey = newObjKey});
		destroy.sequential = true;
		create.sequential = true;
		directing.sequential = true;
		table.append(actions, { destroy, create, directing });
	end
	return unpack(actions);
end

function Interaction_Activate(user, target, interactionCls, ability, ds)
	ds:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = interactionCls.Ability.name });
	return Result_FireWorldEvent('Activated', {Unit = user}, target);
end

function Interaction_Deactivate(user, target, interactionCls, ability, ds)
	ds:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = interactionCls.Ability.name });
	return Result_FireWorldEvent('Deactivated', {Unit = user}, target);
end

function Interaction_Activate_Light(user, target, interactionCls, ability, ds)

end

function Interaction_Deactivate_Light(user, target, interactionCls, ability, ds)
	local company = GetCompany(user);
	if company and not company.Progress.Tutorial.LightOff then
		local mission = GetMission(user);
		local dc = GetMissionDatabaseCommiter(mission);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/LightOff', true);
		company.Progress.Tutorial.LightOff = true;
	end
end

function Interaction_Repair_Area(user, target, interactionCls, ability, ds)

end
function Interaction_Call_Area(user, target, interactionCls, ability, ds)

end
function Interaction_InvestigateCargo(user, target, interactionCls, ability, ds)

end
function Interaction_Call(user, target, interactionCls, ability, ds)
	ds:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = interactionCls.Ability.name });
	return Result_FireWorldEvent('Call', {Unit = user}, target);
end
function Interaction_HackOff(user, target, interactionCls, ability, ds)
	local success = RandomTest(50);
	local messageID = nil;
	local userKey = GetObjKey(user);
	local targetKey = GetObjKey(target);
	local camID = ds:ChangeCameraTarget(targetKey, '_SYSTEM_');
	local particlID = nil;
	local soundID = nil;
	local sleepID = ds:Sleep(3);
	local playSoundID = nil;
	if success then
		playSoundID = ds:PlaySound('Success.wav', 'Layout', 1);
		messageID = ds:UpdateInteractionMessage(userKey, 'HackingSuccess', target.Info.name);
		soundID = ds:PlaySound3D('BattleSystemMessageBox.wav', userKey, '_CENTER_', 3000, 'Effect', 1);
		particlID = ds:PlayParticle(userKey, '_TOP_', 'Particles/Dandylion/HackingSuccess', 2);		
	else
		playSoundID = ds:PlaySound('Fail.wav', 'Layout', 1);
		messageID = ds:UpdateInteractionMessage(userKey, 'HackingFailed', nil);
		particlID = ds:PlayParticle(userKey, '_TOP_', 'Particles/Dandylion/HackingFailed', 2);
	end
	if messageID then
		ds:Connect(messageID, camID, 0.5);
		ds:Connect(particlID, camID, 0);
		ds:Connect(sleepID, camID, 0.5);
		if soundID then
			ds:Connect(soundID, camID, 0.5);
		end
		if playSoundID then
			ds:Connect(playSoundID, messageID, 0.5);
		end
	end
	return Result_FireWorldEvent('HackingOccured', {Success = success, Hacker = user}, target);
end

function Interaction_Investigate(user, target, interactionCls, ability, ds)
	return Result_FireWorldEvent('InvestigationOccured', {Detective = user}, target);
end

function Interaction_OpenCargo(user, target, interactionCls, ability, ds)
end

function Interaction_InvestigatePsionicStone(user, target, interactionCls, ability, ds)
	local actions = {};
	LogAndPrint('Interaction_InvestigatePsionicStone', ability.name, ability.ApplyAmount);
	-- 이능석 추출
	local targetEvent = Result_FireWorldEvent('InvestigationPsionicOccured', {Unit = target, Detective = user, Effective = ability.ApplyAmount});
	table.insert(actions, targetEvent);
	-- 대쉬보드 반영
	local dashboardKey = GetInstantProperty(target, 'PsionicStoneDashboardKey');
	if dashboardKey then
		local globalEvent = Result_FireWorldEvent('InvestigationPsionicOccuredGlobal', {DashboardKey = dashboardKey});
		table.insert(actions, globalEvent);
	end
	return unpack(actions);
end

function Interaction_Collect(user, target, interactionCls, ability, ds)
	return Result_FireWorldEvent('CollectingOccurred', {Taker=user});
end

function Interaction_Arrest(user, target, interactionCls, ability, ds)
	local actions = {};
	ds:Move(GetObjKey(target), InvalidPosition(), true);
	InsertBuffActions(actions, target, user, 'CarryingBodies', 1, true, function(buff)
		SetInstantProperty(user, buff, target);
	end);
	return unpack(actions);
end