function FunctionProperty_FieldEffect_GetTurn(self, position)
	if not IsMissionServer() then
		return self.Base_Turn;
	end
	
	local adjustTurn = 0;
	local mission = GetMission(self);
	local adjustTurn = GetTurnFieldEffect(self, mission, position);
	return math.max(self.Base_Turn + adjustTurn, 1);
end
function GetTurnFieldEffect(self, mission, position)
	
	local result = 0;
	local tileType = nil;	
	if IsMissionServer() then
		tileType = GetTileType(mission, position);
	else
		tileType = GetTileType(position);
	end	
	local weather = mission.Weather.name;
	
	-- 타일별 추가 턴 적용 
	result = result + (GetWithoutError(self.AddTurnByTile, tileType) or 0);
	-- 날씨별 추가 턴 적용
	result = result + (GetWithoutError(self.AddTurnByWeather, weather) or 0);
	return result;
end
function CalculatedProperty_FieldEffectInstance_Turn(self)
	local position = PositionPropertyToTable(self.Position);
	return self.Owner:GetTurn(position);
end

function FunctionProperty_FieldEffect_IsZoneOfContorlTarget(self, unit)
	return true;
end

function FunctionProperty_FieldEffect_Fire_IsZoneOfContorlTarget(self, unit)
	local team = GetTeam(unit);
	if team == 'citizen' or team == 'fake_citizen' then
		return true;
	else
		return false;
	end
end

function IsObjectOnFieldEffect(object, fieldEffectName, usePrevPos)
	local position = usePrevPos and GetAbilityUsingPosition(object) or GetPosition(object);
	local instances = nil;
	if IsMissionServer() then
		local mission = GetMission(object);
		instances = GetFieldEffectByPosition(mission, position);
	elseif IsClient() then
		instances = GetFieldEffectByPosition(position);
	end
	if not instances then
		return false;
	end
	for _, instance in ipairs(instances) do
		if instance.Owner.name == fieldEffectName then
			return true;
		end
	end
	return false;
end

function IsObjectOnFieldEffectBuffAffector(object, buffAffectorList, usePrevPos)
	if not buffAffectorList or buffAffectorList == 'None' then
		return false;
	end
	local buffAffectorSet = Set.new(type(buffAffectorList) == 'string' and {buffAffectorList} or buffAffectorList);
	local position = usePrevPos and GetAbilityUsingPosition(object) or GetPosition(object);
	local instances = nil;
	if IsMissionServer() then
		local mission = GetMission(object);
		instances = GetFieldEffectByPosition(mission, position);
	elseif IsClient() then
		instances = GetFieldEffectByPosition(position);
	end
	if not instances then
		return false;
	end
	for _, instance in ipairs(instances) do
		for _, buffAffector in ipairs(instance.Owner.BuffAffector) do
			if buffAffectorSet[buffAffector.name] then
				return true;
			end
		end
	end
	return false;
end

function FunctionProperty_FieldEffect_IsEffectivePosition(self, position, mission)	
	local effectName = self.name;
	local tileType = nil;
	if IsMissionServer() then
		if not mission then
			mission = GetMission(self);
		end
		tileType = GetTileType(mission, position);
	elseif IsClient() then
		tileType = GetTileType(position);
	end
	if not tileType then
		return false;
	end
	for key, value in pairs (self.DisableFieldEffect) do
		if key == tileType then
			return false;
		end
	end
	return true;
end

function CalculatedProperty_FieldEffect_ApplyType(fieldEffect)
	for _, buffAffector in ipairs(fieldEffect.BuffAffector) do
		if buffAffector.ApplyType == 'ThroughTile' then
			return 'ThroughTile';
		end
	end
	return 'InTile';
end
local s_neutralizeFieldEffectMasteries = nil;
function DefaultFieldEffectApplyLevelDeterminer(buffAffector, fieldEffect, target)
	-- InTile형 버프 어펙터는 무시하지 않도록 로직이 변경되었음..
	if buffAffector.ApplyType == 'InTile' then
		return 1, {};
	end
	
	local buffApplyLv = 1;
	local reason = {};
	
	local mt = GetMastery(target);
	local mastery_WildLife = GetMasteryMasteredLikeWildLife(mt);
	-- 지형효과 디버프 면역 (ex. 전문 사냥꾼의 부츠, 철거업자 운동화)
	local mastery_ImmuneDebuff_FieldEffect = GetMasteryMastered(mt, 'Boots_BlackIron_Legend') or GetMasteryMastered(mt, 'Sneakers_Wrecking_Set');	
	local mastery = mastery_WildLife or mastery_ImmuneDebuff_FieldEffect;
	if mastery then
		local targetBuffApplySet = {
			Fire = true,
			Spark = true,
			Poison = true,
			AcidicPoison = true,
			Frostbite = true,
			Infection = true,
		};
		if targetBuffApplySet[buffAffector.name] then
			buffApplyLv = 0;
			table.insert(reason, MakeMasteryStatInfo(mastery.name, nil--[[don't care]]));
		end
	end
	-- XX 보호대, 방독면
	local itemMasteryList = { 'Amulet_FlameGuard', 'Amulet_FrostGuard', 'Amulet_AniESPLightning', 'Amulet_GasMask' };
	for _, masteryName in ipairs(itemMasteryList) do
		local mastery = GetMasteryMastered(mt, masteryName);
		if mastery then
			if buffAffector.ApplyBuff.Group == mastery.BuffGroup.name and buffAffector.ApplyBuff.Type == 'Debuff' then
				buffApplyLv = 0;
				table.insert(reason, MakeMasteryStatInfo(mastery.name, nil--[[don't care]]));
			end
		end
	end
	
	if s_neutralizeFieldEffectMasteries == nil then
		s_neutralizeFieldEffectMasteries = {};
		for _, masteryCls in pairs(GetClassList('Mastery')) do
			for _, neutralizeFieldEffect in ipairs(masteryCls.NeutralizeFieldEffect) do
				ForceNewInsert(s_neutralizeFieldEffectMasteries, neutralizeFieldEffect.name, masteryCls.name);
			end
		end
	end
	for _, masteryType in ipairs(s_neutralizeFieldEffectMasteries[fieldEffect.name]) do
		if GetMasteryMastered(mt, masteryType) then
			buffApplyLv = 0;
			table.insert(reason, MakeMasteryStatInfo(masteryType, nil));
		end
	end
	
	return buffApplyLv, reason;
end

function BuffAffectorImmunityTest(fieldEffect, affector, obj)
	if affector.ApplyBuff == nil then
		Traceback();
	end
	local immune = BuffImmunityTest(affector.ApplyBuff, obj);
	if immune then
		return true;
	end
	local buffLevel = affector:ApplyLevelDeterminer(fieldEffect, obj);
	if buffLevel <= 0 then
		return true;
	end
	return false;	
end

function BuffAffectorEffectivenessTest(fieldEffect, affector, obj)
	if BuffAffectorImmunityTest(fieldEffect, affector, obj) then
		return "None";
	end
	return affector.ApplyBuff.Type;		-- 'Debuff' 가 리턴되어야 나쁜효과로 간주해서 이동범위 로직에 영향을 줌
end