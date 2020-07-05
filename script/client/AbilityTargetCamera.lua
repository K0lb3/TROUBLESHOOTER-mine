function GetAbilityTargetingCamera_Basic(ability, self, target)	
	if IsClient() and GetOption().Gameplay.DisableTargetCam then
		return '_SYSTEM_';
	end
	
	local abilityCamCls = GetClassList('AbilityTargetCamera')[ability.CamTargetKey];
	if not SafeIndex(abilityCamCls, 'name') then
		return '_SYSTEM_';
	end
	
	if abilityCamCls.Mode == 'Normal' then
		return abilityCamCls.CamTargetKey;
	elseif abilityCamCls.Mode == 'HeightDistance' then
		local selfPos = GetPosition(self);
		local targetPos = GetPosition(target);
		local distance = GetDistance2D(selfPos, targetPos);
		local height = GetHeight(selfPos, targetPos);
		local ratio = height / distance;
		local index = math.clamp(math.ceil(distance), 1, 8);
		
		local heightMode = nil;
		if ratio < -0.2 then -- 1칸 
			if math.abs(height) <= 2 then
				heightMode = 'High';
			else
				heightMode = 'VeryHigh';
			end
		elseif ratio < 0.2 then -- 지면
			heightMode = 'Mid';
		else
			if math.abs(height) <= 2 then
				heightMode = 'Low';
			else
				heightMode = 'VeryLow';
			end
		end
		local distanceMode = nil;
		if distance <= 3 then
			distanceMode = 'Near'
		else
			distanceMode = 'Far';
		end
		local camTargetKey = SafeIndex(abilityCamCls, heightMode, distanceMode);
		if camTargetKey then
			return FormatMessage(camTargetKey, { Index = index });
		else
			return abilityCamCls.CamTargetKey;
		end
	else
		return '_SYSTEM_';
	end
end