function InitializeStageVariableStatic(cls, mission, instance, reinitialize)
	if reinitialize then
		return;
	end
	UpdateStageVariable(mission, instance.Key, instance.Value, true);
end

function InitializeStageVariableStaticEx(cls, mission, instance, reinitialize)
	if reinitialize then
		return;
	end
	UpdateStageVariable(mission, instance.Key, StageDataBinder(mission, instance.StageDataBindingInit[1], {}));
end

function InitializeStageVariableTeamUnitCounter(cls, mission, instance, reinitialize)
	if not reinitialize then
		SubscribeGlobalWorldEvent(mission, 'MissionPrepare', function(eventArg, ds)
			return Result_UpdateStageVariable(instance.Key, #(table.filter(GetAllUnit(mission), function(u) return u.Team == instance.Team; end)));
		end, 0);
	end
	if StringToBool(instance.Linked, false) then
		local createHandler = function(eventArg, ds)
			if GetTeam(eventArg.Unit, true) ~= instance.Team then
				return;
			end
			if GetInstantProperty(eventArg.Unit, 'NoTeamUnitCounter') then
				return;
			end
			local variable = GetStageVariable(mission, instance.Key);
			return Result_UpdateStageVariable(instance.Key, variable + 1);
		end;
		local deadHandler = function(eventArg, ds)
			if GetTeam(eventArg.Unit, true) ~= instance.Team then
				return;
			end
			if GetInstantProperty(eventArg.Unit, 'NoTeamUnitCounter') then
				return;
			end
			if eventArg.EventType == 'UnitDead' and (not eventArg.Virtual and eventArg.Unit.HP > 0) then
				return;
			end
			local variable = GetStageVariable(mission, instance.Key);
			return Result_UpdateStageVariable(instance.Key, variable - 1);
		end;
		local teamChangedHandler = function(eventArg, ds)
			if (eventArg.PrevTeam ~= instance.Team and eventArg.Team ~= instance.Team)
				or eventArg.Temporary
				or IsDead(eventArg.Unit) then
				return;
			end
			if GetInstantProperty(eventArg.Unit, 'NoTeamUnitCounter') then
				return;
			end
			local variable = GetStageVariable(mission, instance.Key);
			if eventArg.PrevTeam == instance.Team then
				variable = variable - 1;
			end
			if eventArg.Team == instance.Team then
				variable = variable + 1;
			end
			return Result_UpdateStageVariable(instance.Key, variable);
		end;
		SubscribeGlobalWorldEvent(mission, 'UnitCreated', createHandler);
		SubscribeGlobalWorldEvent(mission, 'UnitDead', deadHandler);
		SubscribeGlobalWorldEvent(mission, 'UnitBeingExcluded', deadHandler);
		SubscribeGlobalWorldEvent(mission, 'UnitTeamChanged', teamChangedHandler);
		SubscribeGlobalWorldEvent(mission, 'UnitReturnFromDeath', function(eventArg, ds)
			if GetTeam(eventArg.Unit, true) ~= instance.Team then
				return;
			end
			if GetInstantProperty(eventArg.Unit, 'NoTeamUnitCounter') then
				return;
			end
			return Result_UpdateStageVariable(instance.Key, GetStageVariable(mission, instance.Key) + 1);
		end);
	end
end

function GetTeamAbilityUseCount(mission, team, abilityName)
	local mid = GetMissionID(mission);
    local teamCount = GetTeamCount(mid, team, false, true);
    local count = 0
	for i = 1, teamCount do
		local teamMember = GetTeamUnitByIndex(mid, team, i, false, true);
		local ability = GetAbilityObject(teamMember, abilityName);
		if ability and ability.name and ability.UseCount > 0 then
		    count = count + ability.UseCount;
		end
	end
	return count;
end
function InitializeStageVariableTeamAbilityUseCount(cls, mission, instance, reinitialize)
	if not reinitialize then
		SubscribeGlobalWorldEvent(mission, 'MissionPrepare', function(eventArg, ds)
			return Result_UpdateStageVariable(instance.Key, GetTeamAbilityUseCount(mission, instance.Team, instance.Ability));
		end, 0);
	end
	if StringToBool(instance.Linked, false) then
		local handler = function(eventArg, ds)
			if GetTeam(eventArg.Unit, true) ~= instance.Team then
				return;
			end
			if eventArg.EventType == 'UnitDead' and eventArg.Unit.HP > 0 then
				return;
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamAbilityUseCount(mission, instance.Team, instance.Ability));
		end;
		SubscribeGlobalWorldEvent(mission, 'UnitDead', handler);
		SubscribeGlobalWorldEvent(mission, 'UnitBeingExcluded', handler);
		SubscribeGlobalWorldEvent(mission, 'UnitTeamChanged', function(eventArg, ds)
			if (eventArg.PrevTeam ~= instance.Team and eventArg.Team ~= instance.Team)
				or eventArg.Temporary then
				return;
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamAbilityUseCount(mission, instance.Team, instance.Ability));
		end);
		SubscribeGlobalWorldEvent(mission, 'AbilityUsed', function(eventArg, ds)
			if GetTeam(eventArg.Unit) ~= instance.Team then
				return;
			end
			if eventArg.Ability.name ~= instance.Ability then
				return;
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamAbilityUseCount(mission, instance.Team, instance.Ability));
		end);
		SubscribeGlobalWorldEvent(mission, 'UnitItemEquipped', function(eventArg, ds)
			if GetTeam(eventArg.Unit) ~= instance.Team then
				return;
			end
			if eventArg.PrevItem and eventArg.PrevItem.name then
				if eventArg.Item.Ability.name ~= instance.Ability and eventArg.PrevItem.Ability.name ~= instance.Ability then
					return;
				end
			else
				if eventArg.Item.Ability.name ~= instance.Ability then
					return;
				end
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamAbilityUseCount(mission, instance.Team, instance.Ability));
		end);
		SubscribeGlobalWorldEvent(mission, 'UnitItemUnequipped', function(eventArg, ds)
			if GetTeam(eventArg.Unit) ~= instance.Team then
				return;
			end
			if eventArg.Item.Ability.name ~= instance.Ability then
				return;
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamAbilityUseCount(mission, instance.Team, instance.Ability));
		end);
	end
end

function IsInteractionType(ability, interactionName)
	if ability.Type ~= 'Interaction' then
		return false;
	end
	if interactionName and ability.ApplyTargetDetail ~= interactionName then
		return false;
	end
	return true;
end
function GetTeamInteractionUseCount(mission, team, interactionName)
	local mid = GetMissionID(mission);
    local teamCount = GetTeamCount(mid, team, false, true);
    local count = 0
	for i = 1, teamCount do
		local teamMember = GetTeamUnitByIndex(mid, team, i, false, true);
		local abilityList = GetAllAbility(teamMember);
		for _, ability in ipairs(abilityList) do
			if IsInteractionType(ability, interactionName) and ability.UseCount > 0 then
				count = count + ability.UseCount;
			end
		end
	end
	return count;
end
function InitializeStageVariableTeamInteractionUseCount(cls, mission, instance, reinitialize)
	if not reinitialize then
		SubscribeGlobalWorldEvent(mission, 'MissionPrepare', function(eventArg, ds)
			return Result_UpdateStageVariable(instance.Key, GetTeamInteractionUseCount(mission, instance.Team, instance.Interaction));
		end, 0);
	end
	if StringToBool(instance.Linked, false) then
		local handler = function(eventArg, ds)
			if GetTeam(eventArg.Unit, true) ~= instance.Team then
				return;
			end
			if eventArg.EventType == 'UnitDead' and eventArg.Unit.HP > 0 then
				return;
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamInteractionUseCount(mission, instance.Team, instance.Interaction));
		end;
		SubscribeGlobalWorldEvent(mission, 'UnitDead', handler);
		SubscribeGlobalWorldEvent(mission, 'UnitBeingExcluded', handler);
		SubscribeGlobalWorldEvent(mission, 'UnitTeamChanged', function(eventArg, ds)
			if (eventArg.PrevTeam ~= instance.Team and eventArg.Team ~= instance.Team)
				or eventArg.Temporary then
				return;
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamInteractionUseCount(mission, instance.Team, instance.Interaction));
		end);
		SubscribeGlobalWorldEvent(mission, 'AbilityUsed', function(eventArg, ds)
			if GetTeam(eventArg.Unit) ~= instance.Team then
				return;
			end
			if not IsInteractionType(eventArg.Ability, instance.Interaction) then
				return;
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamInteractionUseCount(mission, instance.Team, instance.Interaction));
		end);
		SubscribeGlobalWorldEvent(mission, 'UnitItemEquipped', function(eventArg, ds)
			if GetTeam(eventArg.Unit) ~= instance.Team then
				return;
			end
			if eventArg.PrevItem and eventArg.PrevItem.name then
				if not IsInteractionType(eventArg.Item.Ability, instance.Interaction) and not IsInteractionType(eventArg.PrevItem.Ability, instance.Interaction) then
					return;
				end
			else
				if not IsInteractionType(eventArg.Item.Ability, instance.Interaction) then
					return;
				end
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamInteractionUseCount(mission, instance.Team, instance.Interaction));
		end);
		SubscribeGlobalWorldEvent(mission, 'UnitItemUnequipped', function(eventArg, ds)
			if GetTeam(eventArg.Unit) ~= instance.Team then
				return;
			end
			if not IsInteractionType(eventArg.Item.Ability, instance.Interaction) then
				return;
			end
			return Result_UpdateStageVariable(instance.Key, GetTeamInteractionUseCount(mission, instance.Team, instance.Interaction));
		end);
	end
end

function InitializeStageVariableDummy(cls, mission, instance, reinitialize)
	if reinitialize then
		return;
	end
	UpdateStageVariable(mission, instance.Key, nil, true);
end

function InitializeStageVariableCompanyMissionProperty(cls, mission, instance, reinitialize)
	if not reinitialize then
		local companies = GetAllCompanyInMission(mission);
		if #companies == 0 then
			UpdateStageVariable(mission, instance.Key, instance.Value, true);
		else
			local value = instance.Value;
			local method = instance.MergeMethod;
			if method == 'FirstCompany' then
				local firstCompany = companies[1];
				local cmp = GetCompanyMissionProperty(firstCompany);
				if cmp.StageVariable[instance.Key] ~= nil then
					value = cmp.StageVariable[instance.Key];
				end
			end
			UpdateStageVariable(mission, instance.Key, value, true);
		end
	end
	
	SubscribeGlobalWorldEvent(mission, 'StageVariableUpdated', function(eventArg, ds)
		if instance.Key ~= eventArg.Key then
			return;
		end
		local companies = GetAllCompanyInMission(mission);
		if #companies == 0 then
			return;
		end
		
		local key = eventArg.Key;
		local value = eventArg.Value;
		
		local dc = GetMissionDatabaseCommiter(mission);
		local method = instance.MergeMethod;
		if method == 'FirstCompany' then
			local company = companies[1];
			local companyMissionProp = GetCompanyMissionProperty(company);
			dc:UpdateCompanyMissionProperty(companyMissionProp, mission.name, 'StageVariable/' .. key, value);
			local cmpVar = companyMissionProp.StageVariable;
			cmpVar[key] = value;
			companyMissionProp.StageVariable = cmpVar;		-- DB저장은 따로 되는거고 일단 여기서 갱신
		end
	end);
end

function InitializeStageVariableVariableReferrer(cls, mission, instance, reinitialize)	
	local activate = reinitialize;
	if not reinitialize then
		SubscribeGlobalWorldEvent(mission, 'MissionPrepare', function(eventArg, ds)
			UpdateStageVariable(mission, instance.Key, StageVariableExprProcesser(mission, instance.StageVarExpr));
			activate = true;
		end, 1);
	end

	local referrers = Set.new(Linq.new(SafeIndex(instance.Referrer, 1, 'Variable') or {})
		:select(function(r) return r.Variable; end)
		:toList());
	
	SubscribeGlobalWorldEvent(mission, 'StageVariableUpdated', function(eventArg, ds)
		if not activate or not referrers[eventArg.Key] then
			return nil;
		end
		return Result_UpdateStageVariable(instance.Key, StageVariableExprProcesser(mission, instance.StageVarExpr));
	end);
end

function InitializeStageVariableExistUnit(cls, mission, instance, reinitialize)
	if reinitialize then
		return;
	end
	local mid = GetMissionID(mission);
	local unit = GetUnitFromUnitIndicator(mid, instance.Unit, {}, true);
	local value = unit and 1 or 0;	
	UpdateStageVariable(mission, instance.Key, value, true);
end

function GetStageVariableCaption(cls, instance)
	local descBase = cls.Desc;
	local desc = descBase;
	if cls.name == 'Static' then
		desc = string.format('\\[%s\\] %s: %s', descBase, tostring(instance.Key), tostring(instance.Value));
	elseif cls.name == 'TeamUnitCounter' then
		desc = string.format('\\[%s\\] %s: %s (%s)', descBase, instance.Key, instance.Team, StringToBool(instance.Linked, false) and 'Linked' or 'Unlinked');
	elseif cls.name == 'TeamAbilityUseCount' then
		desc = string.format('\\[%s\\] %s: %s, %s (%s)', descBase, instance.Key, instance.Team, instance.Ability, StringToBool(instance.Linked, false) and 'Linked' or 'Unlinked');
	elseif cls.name == 'Dummy' then
		desc = string.format('\\[%s\\] %s: %s', descBase, instance.Key, instance.Desc or "");
	elseif cls.name == 'StaticEx' then
		desc = string.format('\\[%s\\] %s: %s', descBase, instance.Key, GetStageDataBindingString(instance.StageDataBindingInit));
	elseif cls.name == 'ContinuousVariable' then
		desc = string.format('\\[%s\\] %s: %s (base)', descBase, tostring(instance.Key), tostring(instance.Value));
	elseif cls.name == 'VariableReferrer' then
		desc = string.format('\\[%s\\] %s: %s', descBase, tostring(instance.Key), instance.StageVarExpr);
	elseif cls.name == 'ExistUnit' then
		desc = string.format('\\[%s\\] %s: %s', descBase, tostring(instance.Key), GetUnitIndicatorString(instance.Unit));
	end
	return desc;
end