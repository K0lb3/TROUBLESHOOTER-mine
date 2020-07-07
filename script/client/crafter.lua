function MasterDirectingScript_Crafter(ds, script, args)
	if _G[script] == nil then
		print(script .. 'Function not exist');
	else
		_G[script](0, ds, args);
	end
end

function MapComponentStartingPointer(type, component)
	return { Type = "Model", Name = "Albus" };
end

function MapComponentNormal(type, component)
	local mon = GetClassList('Monster')[component.Object];
	if mon and mon.name then
		return { Type = "Model", Name = mon.Object.name };
	else
		LogAndPrint('MapComponentNormal - no monster:', component.Object);
		return { Type = "Model", Name = "Albus" };
	end
end

function MapComponentCitizen(type, component)
	if IsValidString(component.Object) then
		return component.Object;
	end
	
	local citizenTypeList = GetClassList('Citizen');
	local citizenCls = citizenTypeList[component.CitizenType or 'Healthy'];
	local objectInfo = citizenCls.Objects[1];

	return { Type = "Model", Name = objectInfo.Type };
end

function MapComponentObstacle(type, component)
	return { Type = "Model", Name = GetClassList('Monster')[GetClassList('Obstacle')[component.Obstacle].MonsterSet[1].Monster].Object.name };
end

function MapComponentWatchtower(type, component)
	if component.TowerState == 'Active' then
		return { Type = "Model", Name = 'Watchtower_Active_Enemy' };
	elseif component.TowerState == 'Deactive' then
		return { Type = "Model", Name = 'Watchtower_Active_Enemy' };
	else
		return { Type = "Model", Name = 'Watchtower_Active_Enemy' };
	end
end
function MapComponentSurveillanceNetwork(type, component)
	return { Type = "Model", Name = 'Surveillance' };
end
function MapComponentFieldEffect(type, component)
	local fieldEffectList = GetClassList('FieldEffect');
	local fieldEffect = fieldEffectList[component.FieldEffectType];
	LogAndPrint('fieldEffect.MeshName:', fieldEffect.MeshName);
	if fieldEffect.MeshName ~= '' then
		return { Type = "Mesh", Name = fieldEffect.MeshName };
	else
		return { Type = "Particle", Name = fieldEffect.ParticleName };
	end
end
function MapComponentPositionHolder(type, component)
	return { Type = 'Particle', Name = 'Particles/Dandylion/Selection_Position' };
end

function MapComponentInvestigationTarget(type, component)
	local investigationInfo = SafeIndex(component, 'InvestigationType', 1);
	local invType = SafeIndex(investigationInfo, 'Type') or 'Chest';
	local monName = 'InvestigationTarget_' .. invType;
	if invType == 'Chest' then
		local chestType = SafeIndex(investigationInfo, 'ChestType');
		if chestType then
			local chestTypeCls = GetClassList('ChestType')[chestType];
			if chestTypeCls and chestTypeCls.name then
				monName = chestTypeCls.MonsterActive.name;
			end
		end
	elseif invType == 'Lock' then
		local lockType = SafeIndex(investigationInfo, 'LockType');
		if lockType then
			local lockTypeCls = GetClassList('LockType')[lockType];
			if lockTypeCls and lockTypeCls.name then
				monName = lockTypeCls.MonsterActive.name;
			end
		end
	end
	return { Type = "Model", Name = GetClassList('Monster')[monName].Object.name };
end

function MapComponentInteractionArea(type, component)
	local interactionCls = GetClassList('InteractionArea')[component.InteractionArea];
	return { Type = "Particle", Name = interactionCls.Particle };
end

function MapComponentPsionicStone(type, component)
	local dashboard = GetStageDashboard(component.DashboardKey);
	if not dashboard then
		return 'Object_PsionicStone_Empty_A';
	end
	
	local psionicStoneGen = dashboard.PsionicStoneGen;

	local picker = RandomPicker.new();
	for _, entry in ipairs(psionicStoneGen[1].Entry) do
		picker:addChoice(entry.Prob, entry.PsionicStoneType);
	end
	local pickType = picker:pick();
	
	local psionicStone = GetClassList('PsionicStone')[pickType];
	return { Type = "Model", Name = psionicStone.Object.Object.name };
end

function MapComponentDrakyEgg(type, component)
	local candidate = { 'Mon_Beast_Dragon_Egg_A', 'Mon_Beast_Dragon_Egg_B', 'Mon_Beast_Dragon_Egg_C' };
	return { Type = "Model", Name = candidate[math.random(1, #candidate)] };
end

function GetNamedEventFullArgumentList(self, key)
	local result = {};
	for _, arg in ipairs(self.MeetForm.ArgumentList) do
		table.insert(result, arg);
	end
	for _, arg in ipairs(self.DangerForm.ArgumentList) do
		table.insert(result, arg);
	end
	return result;
end

function ConvertStagePosition(stageElem, posX, posY, posZ)
	LogAndPrint('ConvertStagePosition - posX, posY:', posX, posY);
	-- table.print(stageElem, LogAndPrint);
	ConvertStagePositionCommon(stageElem.Dashboards, posX, posY, posZ);
	ConvertStagePositionCommon(stageElem.MapComponents, posX, posY, posZ);
	ConvertStagePositionCommon(stageElem.Triggers, posX, posY, posZ);
	ConvertStagePositionCommon(stageElem.MissionDirects, posX, posY, posZ);
	if stageElem.StartCamera then
		stageElem.StartCamera[1].Px = stageElem.StartCamera[1].Px + posX;
		stageElem.StartCamera[1].Py = stageElem.StartCamera[1].Py + posY;
		stageElem.StartCamera[1].Pz = stageElem.StartCamera[1].Py + posZ;
	end

	return stageElem;
end
function ConvertStagePositionValue(v, posX, posY, posZ)
	if type(v) ~= 'table' then
		return nil;
	end
	local pos = v[1];
	if pos == nil then
		return nil;
	end
	if IsInvalidPosition(pos) then
		return nil;
	end
	if pos.x ~= math.floor(pos.x) or pos.y ~= math.floor(pos.y) then
		return nil;
	end
	return {{x = pos.x + posX, y = pos.y + posY, z = pos.z + posZ}};	
end
function ConvertStagePositionNode(curNode, checkSet, posX, posY, posZ)
	if type(curNode) ~= 'table' then
		return;
	end
	for k, v in pairs(curNode) do
		if checkSet[k] then
			local newV = ConvertStagePositionValue(v, posX, posY, posZ);
			if newV ~= nil then
				curNode[k] = newV;
			end
		else
			ConvertStagePositionNode(v, checkSet, posX, posY, posZ);
		end
	end
end
function ConvertStagePositionCommon(curNode, posX, posY, posZ)
	local checkList = { 'Position', 'RetreatPosition', 'From', 'To' };
	local checkSet = {};
	for _, key in ipairs(checkList) do
		checkSet[key] = true;
	end
	ConvertStagePositionNode(curNode, checkSet, posX, posY, posZ);
end