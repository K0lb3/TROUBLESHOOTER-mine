function CalculatedProperty_FieldEffect_CustomEventHandler(self)
	local eventHandlers = {};

	table.insert(eventHandlers, {Event='FieldEffectTimeElapsed', Script=FieldEffect_TimeElapsed, Order=0});
	
	table.insert(eventHandlers, {Event='UnitCreated', Script=FieldEffect_UnitCreated, Order=1});
	table.insert(eventHandlers, {Event='FieldEffectInitialized', Script=FieldEffect_FieldEffectInitialized, Order=1});
	table.insert(eventHandlers, {Event='FieldEffectAdded', Script=FieldEffect_FieldEffectAdded, Order=1});
	
	for i, affector in ipairs(self.BuffAffector) do
		if affector.ApplyType == 'ThroughTile' then
			table.insert(eventHandlers, {Event='UnitMoved', Script=FieldEffect_UnitMoved_ThroughTile(i), Order=1});
			table.insert(eventHandlers, {Event='UnitPositionChanged', Script=FieldEffect_UnitPositionChanged_ThroughTile(i), Order=1});
		else
			table.insert(eventHandlers, {Event='FieldEffectRemoved', Script=FieldEffect_FieldEffectRemoved_InTile(i), Order=1});
			table.insert(eventHandlers, {Event='InvalidateBuffAffectorTarget', Script=FieldEffect_InvalidateBuffAffectorTarget_InTile(i), Order=1});
		end
	end
	
	return eventHandlers;
end

function FieldEffect_TimeElapsed(eventArg, fieldEffect, instanceList, ds)
	local actions = {};
	
	local removePositionList = {};

	-- Life 업데이트
	for i, instance in ipairs(instanceList) do
		instance.Life = instance.Life - 1;

		if instance.Life <= 0 then
			table.insert(removePositionList, PositionPropertyToTable(instance.Position));
		end
	end
	
	if #removePositionList > 0 then
		table.insert(actions, Result_RemoveFieldEffect(fieldEffect.name, removePositionList));
	end
	
	return unpack(actions);
end

function FieldEffect_ApplyBuffToTargets(ds, targetArgs, fieldEffect, buffAffector, refID, giver, quiet, blink, sequential)
	-- blink이면 연출 연결없이 처리되므로, 기본적으로 sequential=true로 처리되는 게 좋다.
	if blink and sequential == nil then
		sequential = true;
	end
	local modifier = function (buff)
		buff.UseAddedMessage = false;
		if buffAffector.ApplyType == 'InTile' then
			buff.MasterFieldAffector = buffAffector.name;
		end
	end

	for _, targetArg in ipairs(targetArgs) do
		local actions = {};
		local buffLevel, buffLevelReasons = buffAffector:ApplyLevelDeterminer(fieldEffect, targetArg.targetUnit);
		buffLevel = buffLevel * targetArg.buffLevel;
		InsertBuffActions(actions, giver or targetArg.targetUnit, targetArg.targetUnit, buffAffector.ApplyBuff.name, buffLevel, sequential, modifier, false, {Type = 'FieldEffect', Value = buffAffector.name});

		local targetKey = GetObjKey(targetArg.targetUnit);
		local immune, reason = BuffImmunityTest(buffAffector.ApplyBuff, targetArg.targetUnit);
		if (#actions > 0 or #buffLevelReasons > 0) and reason ~= 'Hidden' then
			local mission = targetArg.targetUnit;
			if not blink and not IsValidPosition(mission, targetArg.checkPos) then
				blink = true;
			end		
			local eventCmd = nil;
			local connectCmd = nil;
			if not blink then
				if refID == nil then
					eventCmd = ds:SubscribeFSMEvent(targetKey, 'StepForward', 'CheckUnitArrivePosition', {CheckPos = targetArg.checkPos }, true);
					ds:SetConditional(eventCmd);
				else
					eventCmd = refID;
				end
				
				local aliveTest = ds:EnableIf('TestObjectAlive', targetKey);
				ds:Connect(aliveTest, eventCmd, -1);
				eventCmd = aliveTest;
				connectCmd = eventCmd;
			end
			
			if targetArg.buffLevel > 0 and not quiet and not blink then
				local camMoveTime = 1;
				if not immune then
					local findObjCamMove = ds:ChangeCameraTarget(targetKey, '_SYSTEM_', false, false, camMoveTime);
					ds:Connect(findObjCamMove, eventCmd, -1);		
				end
				
				local detectedMessage = nil;
				if buffAffector.ApplyBuff.UseAddedMessage and buffLevel > 0 then
					if not immune then
						detectedMessage = ds:UpdateBattleEvent(targetKey, 'BuffInvoked', { Buff = buffAffector.ApplyBuff.name })
					else
						detectedMessage = ds:UpdateBattleEvent(targetKey, 'BuffImmuned', { Buff = buffAffector.ApplyBuff.name, Reason = reason });
					end
				
					ds:Connect(detectedMessage, eventCmd, -1);
					connectCmd = detectedMessage;
				elseif buffLevel == 0 then
					ReasonToUpdateBattleEventMulti(targetArg.targetUnit, ds, buffLevelReasons, eventCmd, -1);
					if GetCompany(targetArg.targetUnit) then
						if table.findif(buffLevelReasons, function(reason) return reason.Type == 'WildLife' or reason.Type == 'WildLife2'; end) ~= nil then
							ds:Connect(ds:AddSteamStat('WildLifeBlockDebuffCount', 1, GetTeam(targetArg.targetUnit)), eventCmd, -1);
						end
					end
				end
				
				if buffAffector.ApplyParticle ~= 'None' then
					local particleID = ds:PlayParticle(targetKey, buffAffector.ApplyParticlePos, buffAffector.ApplyParticle, 1.0);
					ds:Connect(particleID, eventCmd, -1);
				end
				
				if buffAffector.ApplySound ~= 'None' then
					local soundID = ds:PlaySound3D(buffAffector.ApplySound, targetKey, '_CENTER_', 3000, 'Effect', 1.0);
					ds:Connect(soundID, eventCmd, -1);
				end
			end
			
			for _, action in pairs(actions) do
				local actionCmd = ds:WorldAction(action, true, false);
				if actionCmd ~= -1 and not blink then
					ds:Connect(actionCmd, connectCmd);
				end
			end
		end
	end
end

function FieldEffect_UnitMoved_ThroughTile(affectorIndex)
	return function(eventArg, fieldEffect, instanceList, ds)
		if eventArg.Unit.Untargetable and eventArg.Unit.HP <= 0 then
			return;
		end

		local targetArgs = {};

		local startPos = eventArg.Path[1];
		local startInRange = HasFieldEffectInstance(fieldEffect, startPos, eventArg.MoveIdentifier);

		local targetPos = nil;

		for _, pos in ipairs(eventArg.Path) do
			if HasFieldEffectInstance(fieldEffect, pos, eventArg.MoveIdentifier) then
				targetPos = pos;
				break;
			end
		end
		
		if targetPos ~= nil and (not startInRange) then
			table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = 1, checkPos = targetPos });		
		end

		FieldEffect_ApplyBuffToTargets(ds, targetArgs, fieldEffect, fieldEffect.BuffAffector[affectorIndex]);
	end
end

function FieldEffect_UnitPositionChanged_ThroughTile(affectorIndex)
	return function(eventArg, fieldEffect, instanceList, ds)
		if eventArg.Unit.Untargetable and eventArg.Unit.HP <= 0 then
			return;
		end

		local targetArgs = {};

		local applyPositions = table.map(instanceList, function(instance) return PositionPropertyToTable(instance.Position); end);
		
		local startInRange = HasFieldEffectInstance(fieldEffect, eventArg.BeginPosition, eventArg.MoveIdentifier);
		local endInRange = HasFieldEffectInstance(fieldEffect, eventArg.Position, eventArg.MoveIdentifier);
		
		if not startInRange and endInRange then
			table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = 1, checkPos = eventArg.Position });		
		end
		
		FieldEffect_ApplyBuffToTargets(ds, targetArgs, fieldEffect, fieldEffect.BuffAffector[affectorIndex], nil, nil, eventArg.NoEvent, eventArg.Blink);
	end
end

function FieldEffect_UnitCreated(eventArg, fieldEffect, instanceList, ds)
	if eventArg.Unit.Untargetable then
		return;
	end

	local targetArgs = {};
	
	local applyPositions = table.map(instanceList, function(instance) return PositionPropertyToTable(instance.Position); end);
	local unitPos = eventArg.Position;
	
	if BuffHelper.IsPositionInRange(unitPos, applyPositions) then
		table.insert(targetArgs, { targetUnit = eventArg.Unit, buffLevel = 1, checkPos = GetPosition(eventArg.Unit) });		
	end
	
	local eventId = ds:Sleep(0);
	for i, affector in ipairs(fieldEffect.BuffAffector) do
		FieldEffect_ApplyBuffToTargets(ds, targetArgs, fieldEffect, affector, eventId, nil, nil, nil, true);
	end
end

function FieldEffect_FieldEffectInitialized(eventArg, fieldEffect, instanceList, ds)
	if fieldEffect.name ~= eventArg.FieldEffectType then
		return;
	end
	
	local applyPositions = eventArg.PositionList;
	local applyObjects = BuffHelper.GetObjectsInRange(GetMission(fieldEffect), applyPositions, function (obj)
		return obj.HP > 0;
	end);
	
	local actions = {};
	for i, affector in ipairs(fieldEffect.BuffAffector) do
		local modifier = function (buff)
			buff.UseAddedMessage = false;
			if affector.ApplyType == 'InTile' then
				buff.MasterFieldAffector = affector.name;
			end
		end
		for _, obj in pairs(applyObjects) do
			local buffLevel, reason = affector:ApplyLevelDeterminer(fieldEffect, obj);
			InsertBuffActions(actions, obj, obj, affector.ApplyBuff.name, buffLevel, nil, modifier, false, {Type = 'FieldEffect', Value = fieldEffect.name});	
		end
	end

	return unpack(actions);
end

function FieldEffect_FieldEffectAdded(eventArg, fieldEffect, instanceList, ds)
	if fieldEffect.name ~= eventArg.FieldEffectType then
		return;
	end
	
	local targetArgs = {};
	
	local applyPositions = eventArg.PositionList;
	local applyObjects = BuffHelper.GetObjectsInRange(GetMission(fieldEffect), applyPositions, function (obj)
		return obj.HP > 0;
	end);
	
	for _, obj in pairs(applyObjects) do
		table.insert(targetArgs, { targetUnit = obj, buffLevel = 1, checkPos = GetPosition(obj) });					
	end
	
	for i, affector in ipairs(fieldEffect.BuffAffector) do
		FieldEffect_ApplyBuffToTargets(ds, targetArgs, fieldEffect, affector, eventArg.RefID, eventArg.Giver, true);
	end	
end

function FieldEffect_FieldEffectRemoved_InTile(affectorIndex)
	return function(eventArg, fieldEffect, instanceList, ds)
		if fieldEffect.name ~= eventArg.FieldEffectType then
			return;
		end
		
		local targetArgs = {};
		
		local applyPositions = eventArg.PositionList;
		local applyObjects = BuffHelper.GetObjectsInRange(GetMission(fieldEffect), applyPositions);
		
		for _, obj in pairs(applyObjects) do
			table.insert(targetArgs, { targetUnit = obj, buffLevel = -1, checkPos = GetPosition(obj) });					
		end
		
		FieldEffect_ApplyBuffToTargets(ds, targetArgs, fieldEffect, fieldEffect.BuffAffector[affectorIndex], eventArg.RefID);
	end
end

function FieldEffect_Infect_TimeElapsed(eventArg, fieldEffect, instanceList, ds)

	if not fieldEffect.SpreadFieldEffect then
		return;
	end

	local actions = {};
	
	local addPositions = {};
	local offsets = { { x = 1, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }, { x = -1, y = 0, z = 0 }, { x = 0, y = -1, z = 0 } }

	local mission = GetMission(fieldEffect);
	
	local aliveInstanceList = table.filter(instanceList, function(instance) return (instance.Life > 0); end);
	local alivePositionList = table.map(aliveInstanceList, function(instance) return PositionPropertyToTable(instance.Position); end);
	
	for _, alivePosition in ipairs(alivePositionList) do
		local infectAreaRate = GetInfectAreaRate(mission, alivePosition, fieldEffect.name);
		if RandomTest(infectAreaRate) then
			local nearPositions = {};			
			for _, offset in ipairs(offsets) do
				local newPosition = GetValidPosition(mission, AddPosition(alivePosition, offset));
				if newPosition ~= nil and GetDistance3D(alivePosition, newPosition) < 1.4 and fieldEffect:IsEffectivePosition(newPosition) then
					table.insert(nearPositions, newPosition);
				end
			end
			
			if #nearPositions > 0 then
				local newPosition = nearPositions[math.random(1, #nearPositions)];
				if not BuffHelper.IsPositionInRange(newPosition, addPositions) then
					table.insert(addPositions, newPosition);
				end	
			end
		end
	end

	if #addPositions > 0 then
		table.insert(actions, Result_AddFieldEffect(fieldEffect.name, addPositions));
	end

	return unpack(actions);
end
function GetInfectAreaRate(mission, alivePosition, fieldEffectType)
	
	local result = 0;
	local tileType = GetTileType(mission, alivePosition);
	local weather = mission.Weather.name;
	local fieldEffectList = GetClassList('FieldEffect');
	local curFieldEffect = fieldEffectList[fieldEffectType];
	if not curFieldEffect then
		return 0;
	end
	
	-- 1. 타일에 따른 번짐 효과.
	local infectRateByTile = 0;
	local curInfectRateByTile = GetWithoutError(curFieldEffect.InfectRateByTile, tileType);
	if curInfectRateByTile then
		infectRateByTile = curInfectRateByTile;
	end	
	
	-- 2. 날씨에 따른 범짐 효과
	local infectRateByWeather = 0;
	local curInfectRateByWeather = GetWithoutError(curFieldEffect.InfectRateByWeather, weather);
	if curInfectRateByWeather then
		infectRateByWeather = curInfectRateByWeather;
	end
	
	-- 3. 총합
	local infectRate = infectRateByTile + infectRateByWeather;
	if infectRate <= 0 then
		return 0;
	end
	result = math.random(infectRate/2, infectRate);
	return math.max(0, math.min(result, 95));
end

function FieldEffect_RemoveFieldEffect_FieldEffectAdded(eventArg, fieldEffect, instanceList, ds)
	if fieldEffect.name ~= eventArg.FieldEffectType then
		return;
	end
	if GetWithoutError(fieldEffect, 'RemoveFieldEffect') == nil or fieldEffect.RemoveFieldEffect == 'None' then
		return;
	end
	
	local mission = GetMission(fieldEffect);
	local removePosList = {};
	
	for _, pos in ipairs(eventArg.PositionList) do
		local fieldEffects = GetFieldEffectByPosition(mission, pos);
		for _, fe in ipairs(fieldEffects) do
			if fe.Owner.name == fieldEffect.RemoveFieldEffect then
				table.insert(removePosList, pos);
			end
		end
	end
	
	if #removePosList == 0 then
		return;
	end
	
	local ret = Result_RemoveFieldEffect(fieldEffect.RemoveFieldEffect, removePosList);
	ret.sequential = true;
	return ret;
end

function FieldEffect_InvalidateBuffAffectorTarget_InTile(affectorIndex)
	return function(eventArg, fieldEffect, instanceList, ds)
		local target = eventArg.Unit;
		if target.Untargetable and target.HP <= 0 then
			return;
		end
		
		local curPos = GetPosition(target);
		local curInRange = HasFieldEffectInstance(fieldEffect, curPos);
		if not curInRange then
			return;
		end
		
		local buffAffector = fieldEffect.BuffAffector[affectorIndex];
		local buffImmuned = BuffImmunityTest(buffAffector.ApplyBuff, target);
		local hasBuff = HasBuff(target, buffAffector.ApplyBuff.name);
		
		local targetArgs = {};
		if hasBuff and buffImmuned then
			table.insert(targetArgs, { targetUnit = target, buffLevel = -1, checkPos = curPos });
		elseif not hasBuff and not buffImmuned then
			table.insert(targetArgs, { targetUnit = target, buffLevel = 1, checkPos = curPos });
		end
		
		FieldEffect_ApplyBuffToTargets(ds, targetArgs, fieldEffect, buffAffector);
	end
end