function MasterAbilityScript(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents, abilityAnimationInfo)
	-- 배틀 이벤트 핸들러 등록
	if battleEvents then
		local abilityEventClsList = GetClassList('AbilityDirectingEvent');
		for objKey, events in pairs(battleEvents) do
			local eventOffset = {};
			for i, event in ipairs(events) do
				(function()
					local eventCls = nil;
					local eventArgs = nil;
					if type(event) == 'string' then
						eventCls = abilityEventClsList[event];
					elseif type(event) == 'table' then
						local dtype = event.Type;
						eventCls = abilityEventClsList[dtype];
						eventArgs = event;
					else
						return;
					end
					if eventCls.AliveOnly and GetObjectByKey(objKey, true).HP <= 0 then
						return;
					end
					local eventType = eventCls.DirectingEvent;
					if eventType == 'Custom' then
						eventType = SafeIndex(eventArgs, 'EventType') or 'Ending';
					end
					local msgId = ad:UpdateBattleEvent(objKey, eventCls.name, eventArgs);
					ad:Connect(ad:Sleep(0.5), msgId, 0);
					local offset = SafeIndex(eventOffset, eventType) or 0;
					ad:SubscribeDirectingEvent(objKey, eventType, msgId, offset);
					eventOffset[eventType] = offset + 0.1;
				end)();
			end
		end
	end
	
	ad:NewDirectingThread();
	local messageVisible = ad:GetConfig('MessageVisible');
	if messageVisible ~= nil and not messageVisible then
		ad:EnableBattleMessage(false);
	end
	
	if not IsMoveTypeAbility(ability) then
		if IsClient() and not ad:GetConfig('NoCamera') and GetOption().Gameplay.DisableAbilityCam then
			ad:SetConfig('SystemCamera', true);
		else
			ad:RunScript('IncreaseCameraControlLock', nil, true);
		end
	end
	
	-- 어빌리티 카메라 흔들림 끄기
	if IsClient() and GetOption().Gameplay.DisableWiggleCam then
		ad:SetConfig('NoWiggle', true);
	end
	
	local sightObjs = {};
	if not IsMoveTypeAbility(ability) and not ad:GetConfig('NoAutoSight') then
		AutoSightOn(ad, userInfo.User);		-- 가장 처음에 켜줘야 할듯
		table.insert(sightObjs, userInfo.User);
		
		for i, targetInfos in ipairs({primaryTargetInfos, secondaryTargetInfos}) do
			for j, targetInfo in ipairs(targetInfos) do
				if targetInfo.Target and targetInfo.Target.name and targetInfo.Target ~= userInfo.User then
					AutoSightOn(ad, targetInfo.Target);
					table.insert(sightObjs, targetInfo.Target);
				end
			end
		end
	end
	if ad:GetConfig('Preemptive') then
		local preemptiveTargets = {};	
		for i, targetInfos in ipairs({primaryTargetInfos, secondaryTargetInfos}) do
			for j, targetInfo in ipairs(targetInfos) do
				if targetInfo.Target and targetInfo.Target.name and targetInfo.Target ~= userInfo.User then
					preemptiveTargets[GetObjKey(targetInfo.Target)] = true;
				end
			end
		end
		for targetKey, _ in pairs(preemptiveTargets) do
			ad:StopUpdate(targetKey);
		end
		ad:Wait(ad:Sleep((ad:GetConfig('PreemptiveOrder') or 0) * 2));
	elseif not ability.NoPrepareTarget and not ad:GetConfig('NoLook') then
		local direct = userInfo.DirectPrepare;
		--캐릭터들 바라보기 처리 
		for i, targetInfos in ipairs({primaryTargetInfos, secondaryTargetInfos}) do
			for j, targetInfo in ipairs(targetInfos) do
				if targetInfo.Target ~= userInfo.User then
					ad:LookAt(GetObjKey(targetInfo.Target), GetObjKey(userInfo.User), direct, true);
				end
			end
		end
	end
	if not ability.NoPrepare then
		local up;
		if ad:GetConfig('Preemptive') and userInfo.Target and userInfo.Target.name then
			up = GetModelPosition(userInfo.Target);
		else
			local usingPos = userInfo.UsingPos;
			up = {x = usingPos.x, y = usingPos.y, z = usingPos.z};
		end
		local direct = userInfo.DirectPrepare;
		ad:PrepareAbility(GetObjKey(userInfo.User), up, direct);
	end

	local apUnit = GetInstantProperty(userInfo.User, 'AutoPlayable');
	local apStrategy = GetInstantProperty(userInfo.User, 'AutoPlayStrategy');
	local isAutoCameraTarget = GetRelationWithPlayer(userInfo.User) ~= 'Team' or (apUnit and apStrategy and apStrategy ~= 'Manual')
	if ad:GetConfig('Preemptive') or (isAutoCameraTarget and not ad:GetConfig('NoCamera')) or ad:GetConfig('SystemCamera') then
		if not ability.AbilityWithMove then
			local camId;
			if userInfo.Target.name ~= nil and userInfo.Target ~= userInfo.User then
				camId = ad:ChangeCameraTargetingMode(GetObjKey(userInfo.User), GetObjKey(userInfo.Target), '_SYSTEM_', false, true, 0.5);
			else
				if not GetOption().Gameplay.DisableTargetCam then
					camId = ad:ChangeCameraTarget(GetObjKey(userInfo.User), '_SYSTEM_', false, true, 0.5);
				else
					camId = ad:Sleep(0);
				end
			end
			ad:Wait(camId);
		end
		if ad:GetConfig('Preemptive') then
			ad:BlockCamera(true);
		end
	end
	LogAndPrint('======================= MasterAbilityScript =========================');
	LogAndPrint( ability.name, userInfo);
	LogAndPrint('=========================================================================')
	ad:FireDirectingEvent(nil, 'Beginning', ad:Wait(-1));
	
	local playScript = 'PLAY_' .. ability.name;
	if ability.DirectingScript and ability.DirectingScript ~= '' then
		playScript = ability.DirectingScript;
	end
	
	local playID = -1;
	local playFunc = _G[playScript];
	if playFunc ~= nil then
		local retID = playFunc(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
		if retID ~= nil then
			playID = retID;
		end
	else
		playID = PlayAbilityDirect(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
	end
	
	ad:FireDirectingEvent(nil, 'Ending', ad:Wait(playID));
	if messageVisible ~= nil and not messageVisible then
		ad:EnableBattleMessage(true);
	end
	
	local finalId = nil;
	if ad:GetConfig('Preemptive') then
		ad:Wait(playID);
		ad:BlockCamera(false);
		ad:TurnBack(GetObjKey(userInfo.User));
		for i, targetInfos in ipairs({primaryTargetInfos, secondaryTargetInfos}) do
			for j, targetInfo in ipairs(targetInfos) do
				if targetInfo.Target and targetInfo.Target.name and targetInfo.Target ~= userInfo.User then
					ad:ContinueUpdate(GetObjKey(targetInfo.Target));
				end
			end
		end
		finalId = ad:ChangeCameraTarget(GetObjKey(userInfo.Target), '_SYSTEM_', false, true, 0.5);
	elseif not ad:GetConfig('SystemCamera') and not IsMoveTypeAbility(ability) then
		ad:Wait(playID);
		if not ad:GetConfig('NoCamera') then
			finalId = ad:ChangeCameraTarget(GetObjKey(userInfo.User), '_SYSTEM_', false, true, 0.5);
		else
			finalId = ad:Sleep(0);
		end
	end
	
	if not IsMoveTypeAbility(ability) then
		for i, sightObj in ipairs(sightObjs) do
			AutoSightOff(ad, -1, sightObj);
		end
	end
	
	if not ad:GetConfig('SystemCamera') and not IsMoveTypeAbility(ability) then
		ad:Connect(ad:RunScript('DecreaseCameraControlLock', nil, true), finalId, -1);
	end
	
	local chatInfos = GetAbilityDirectorSystemBattleChat(userInfo, primaryTargetInfos, secondaryTargetInfos);
	if #chatInfos > 0 then
		local prevID = ad:Wait(playID);
		for _, chatInfo in ipairs(chatInfos) do
			local chatID = ad:AddMissionChat(chatInfo.Type, chatInfo.Message, chatInfo.Args);
			ad:Connect(chatID, prevID, -1);
			prevID = chatID;
		end
	end
	
	if ad:GetConfig('HideUI') then
		ad:BattleUIControl(true, true);
	end
	
	local achievementTest = false;	-- 테스트를 할때 true로 켜주면 됨
	if achievementTest or (IsClient() and IsSteamInitialized()) then
		local achievements, addStats = GetAbilityAchievements(ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents);
		if #achievements > 0 then
			local prevID = ad:Wait(playID);
			for _, achievement in ipairs(achievements) do
				if achievementTest then
					LogAndPrint('AchievementHasAchieved!', achievement);
				else
					local achieveID = ad:UpdateSteamAchievement(achievement, true);
					ad:Connect(achieveID, prevID, -1);
					prevID = achieveID;
				end
			end
			playID = prevID;
		end
		if #addStats > 0 then
			local prevID = ad:Wait(playID);
			for _, addStat in ipairs(addStats) do
				if achievementTest then
					LogAndPrint('StatHasAchieved!', addStat.Type, addStat.Value);
				else
					local achieveID = ad:AddSteamStat(addStat.Type, addStat.Value);
					ad:Connect(achieveID, prevID, -1);
					prevID = achieveID;
				end
			end
		end
	end
end
function GetAbilityDirectorSystemBattleChat(userInfo, primaryTargetInfos, secondaryTargetInfos)
	local ability = userInfo.Ability;
	if IsMoveTypeAbility(ability) then
		return {};
	end
	
	local user = userInfo.User;
	
	local userRelation = GetRelationWithPlayer(user);
	local relationKey = nil;
	if userRelation == 'Team' then
		relationKey = 'Player';
	elseif userRelation == 'Enemy' then
		relationKey = 'Enemy';
	else
		relationKey = 'Other';
	end
	
	local targetDamageInfos = {};
	for _, targetInfos in ipairs({ primaryTargetInfos, secondaryTargetInfos }) do
		for _, targetInfo in ipairs(targetInfos) do
			if targetInfo.MainDamage ~= nil then
				table.insert(targetDamageInfos, { Target = targetInfo.Target, Damage = targetInfo.MainDamage, AttackerState = targetInfo.AttackerState, DefenderState = targetInfo.DefenderState });
			end
		end
	end

	local chatInfos = {};
	local AddChatInfo = function (actionKey, msg, target, damage)
		local type = relationKey..actionKey;
		local args = { Ability = ability.name, ObjectKey = GetObjKey(user) };
		if target ~= nil then
			args.TargetKey = GetObjKey(target);
		end
		if damage ~= nil then
			args.Damage = damage;
		end
		table.insert(chatInfos, { Type = type, Message = msg, Args = args });
	end
	
	if ability.Type ~= 'Attack' then
		local msg = 'AbilityUsed';
		if user.Obstacle or user.name == 'Object_Explosion' then
			msg = msg..'_Obstacle';
		end
		AddChatInfo('Attack', msg);
	end

	if ability.Type == 'Attack' or ability.Type == 'Heal' then
		if ability.Type == 'Attack' and #targetDamageInfos == 0 then
			local msg = 'AbilityNoTarget';
			if user.Obstacle or user.name == 'Object_Explosion' then
				msg = msg..'_Obstacle';
			end
			AddChatInfo('Attack', msg);
		end
		
		for _, damageInfo in ipairs(targetDamageInfos) do
			local actionKey = nil;
			local msg = nil;
			local damage = damageInfo.Damage;
			
			if damageInfo.DefenderState == 'Hit' then
				if damageInfo.AttackerState == 'Critical' then
					actionKey = 'AttackCritical';
					msg = 'AbilityCritical';
				else
					actionKey = 'Attack';
					msg = 'AbilityNormal';
				end
			elseif damageInfo.DefenderState == 'Block' then
				actionKey = 'Block';
				msg = 'AbilityBlock';
			elseif damageInfo.DefenderState == 'Dodge' then
				actionKey = 'Dodge';
				if GetBuffStatus(damageInfo.Target, 'Unconscious', 'Or') or damageInfo.Target.Race.name == 'Object' then
					msg = 'AbilityMiss';
				else
					msg = 'AbilityDodge';
				end
			elseif damageInfo.DefenderState == 'Heal' then
				actionKey = 'Heal';
				msg = 'AbilityHeal';
				damage = -damage;
			end
			if msg ~= nil and (user.Obstacle or user.name == 'Object_Explosion') then
				msg = msg..'_Obstacle';
			end
			
			if actionKey ~= nil then
				AddChatInfo(actionKey, msg, damageInfo.Target, damage);
			end
		end
	end
	return chatInfos;
end
function CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, ifFunc)
	local count = 0;
	for i, targetInfos in ipairs({primaryTargetInfos, secondaryTargetInfos}) do
		for j, targetInfo in ipairs(targetInfos) do
			local target = targetInfo.Target;
			if target and target.name and ifFunc(targetInfo) then
				count = count + 1;
			end
		end
	end
	return count;
end
function HasBattleEventIf(battleEvents, ifFunc)
	if not battleEvents then
		return false;
	end
	for objKey, events in pairs(battleEvents) do
		for i, event in ipairs(events) do
			if ifFunc(event) then
				return true, event;
			end
		end
	end
	return false;
end
function HasBattleEventType(battleEvents, eventType)
	return HasBattleEventIf(battleEvents, function(event)
		if type(event) == 'string' then
			return event == eventType;
		elseif type(event) == 'table' then
			return event.Type == eventType;
		else
			return false;
		end
	end);
end
function GetAbilityAchievements(ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	local achievements = {};
	local addStats = {};
	
	local user = userInfo.User;
	local relation = GetRelationWithPlayer(user);
	
	if relation == 'Team' then
		local userFunc = _G['GetUserAbilityAchievements_'..user.Info.name];
		if userFunc then
			userFunc(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents);
		end
	end
	
	if not HasSteamAchievement('SituationDoubleKO') and ability.Type == 'Attack' and ability.ApplyTarget == 'Any' then
		local playerDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Team' and targetInfo.IsDead;
		end);
		local enemyDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead;
		end);
		if playerDeadCount >= 1 and enemyDeadCount >= 1 then
			table.insert(achievements, 'SituationDoubleKO');
		end
	end
	
	if not HasSteamAchievement('SituationDodgeInSmoke') and ability.Type == 'Attack' and relation == 'Enemy' then
		local playerDodgeInSmokeCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Team' and targetInfo.DefenderState == 'Dodge' and HasBuff(targetInfo.Target, 'SmokeScreen');
		end);
		if playerDodgeInSmokeCount >= 1 then
			table.insert(achievements, 'SituationDodgeInSmoke');
		end
	end
	
	if not HasSteamAchievement('SituationWindPressureStun') and ability.name == 'WindPressureGrenade' and relation == 'Team' then
		local knockbackStunCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.KnockbackPower > 0 and targetInfo.SlideType == 'None';
		end);
		if knockbackStunCount >= 3 then
			table.insert(achievements, 'SituationWindPressureStun');
		end
	end
	
	if not HasSteamAchievement('SituationPsionicStoneGet') and string.match(ability.name, '^InvestigatePsionicStone.*') then
		table.insert(addStats, {Type = 'PsionicStoneGetCount', Value = 1});
	end
	
	if not HasSteamAchievement('SituationConceal10') and ability.name == 'Conceal' and relation == 'Team' then
		table.insert(addStats, {Type = 'ConcealCount', Value = 1});
	end
	
	if not HasSteamAchievement('AbilityTrapDesigner') and ability.Type == 'Trap' and relation == 'Team' then
		table.insert(addStats, {Type = 'TrapUseCount', Value = 1});
	end
	
	if (ability.name == 'AnnihilatingFire' or ability.name == 'Machine_DoubleFire') and relation == 'Team' and not HasSteamAchievement('AbilityHeissingAnnihilatingFire') then
		local enemyDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead;
		end);
		if enemyDeadCount >= 3 then
			table.insert(achievements, 'AbilityHeissingAnnihilatingFire');
		end
	end
	
	-- 대상 테스트
	local alreadySet = {};
	for _, infos in ipairs({primaryTargetInfos, secondaryTargetInfos}) do
	for _, targetInfo in ipairs(infos) do
		if not HasSteamAchievement('AbilitySionFlashAura') and targetInfo.Target.name ~= nil and targetInfo.Target.Info.name == 'Sion' and GetRelationWithPlayer(targetInfo.Target) == 'Team' then
			if GetBuff(targetInfo.Target, 'FlashAura') and targetInfo.DefenderState == 'Dodge' then
				table.insert(addStats, {Type = 'FlashAuraDodgeCount', Value = 1});
			end
		end
		
		--[[ TODO: 임시 봉인
		if not alreadySet.SituationDamage9999 and not HasSteamAchievement('SituationDamage9999') and targetInfo.ShowDamage >= 9999 then
			alreadySet.SituationDamage9999 = true;
			table.insert(achievements, 'SituationDamage9999');
		end
		]]
	end
	end

	return achievements, addStats;
end
function GetUserAbilityAchievements_Albus(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if ability.name == 'GaleSlash' and not HasSteamAchievement('AbilityAlbus') then
		local enemyDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead;
		end);
		if enemyDeadCount >= 3 then
			table.insert(achievements, 'AbilityAlbus');
		end
	end
	if ability.name == 'Windwalker' and not HasSteamAchievement('AbilityAlbusWindwalker') then	
		local startPos = GetModelPosition(userInfo.User);
		local endPos = {x = userInfo.UsingPos.x, y = userInfo.UsingPos.y, z = userInfo.UsingPos.z}
		if not IsMovePathLinked(startPos, endPos) then
			table.insert(achievements, 'AbilityAlbusWindwalker');
		end
	end
	if ability.name == 'StormSlash' and not HasSteamAchievement('AbilityAlbusStormSlash') then
		local targetInfo = primaryTargetInfos[1];
		if targetInfo.PrevHP == targetInfo.MaxHP and targetInfo.RemainHP == 0 and targetInfo.ShowDamage > (targetInfo.PrevHP + targetInfo.MaxHP * 0.3) then
			table.insert(achievements, 'AbilityAlbusStormSlash');
		end
	end
end
function GetUserAbilityAchievements_Sion(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if ability.name == 'LightningStorm' and not HasSteamAchievement('AbilitySion') then
		local enemyDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead;
		end);
		if enemyDeadCount >= 3 then
			table.insert(achievements, 'AbilitySion');
		end
	end
	if ability.name == 'FlashSpecialBeam' and not HasSteamAchievement('AbilitySionFlashSpecialBeam') then
		local enemyDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead;
		end);
		if enemyDeadCount >= 3 then
			table.insert(achievements, 'AbilitySionFlashSpecialBeam');
		end
	end
end
function GetUserAbilityAchievements_Irene(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if not HasSteamAchievement('AbilityIrene') then
		local isChainAbility, eventData = HasBattleEventType(battleEvents, 'ChainAbility');
		if isChainAbility and eventData.ChainCount == 3 then
			table.insert(achievements, 'AbilityIrene');
		end
	end
	if not HasSteamAchievement('AbilityIreneUltimate4') then
		local isChainAbility, eventData = HasBattleEventType(battleEvents, 'ChainAbility');
		if isChainAbility and eventData.ChainCount == 4 then
			table.insert(achievements, 'AbilityIreneUltimate4');
		end
	end
	if ability.name == 'FlameStampKick' and not HasSteamAchievement('AbilityIreneFlameStampKick') then
		local enemyDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead;
		end);
		if enemyDeadCount >= 3 then
			table.insert(achievements, 'AbilityIreneFlameStampKick');
		end
	end
end
function GetUserAbilityAchievements_Anne(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if ability.name == 'StarFall' and not HasSteamAchievement('AbilityAnne') then
		local realHealCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return targetInfo.MainDamage < 0 and targetInfo.PrevHP < targetInfo.MaxHP;
		end);
		if realHealCount >= 3 then
			table.insert(achievements, 'AbilityAnne');
		end
	end
	if ability.name == 'EntanglingRoots' and not HasSteamAchievement('AbilityAnneEntanglingRoots') then
		local appliedEnemyCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy';
		end);
		if appliedEnemyCount >= 3 then
			table.insert(achievements, 'AbilityAnneEntanglingRoots');
		end
	end
	if ability.name == 'StarRain' and not HasSteamAchievement('AbilityAnneStarRain') then
		local enemyDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead;
		end);
		if enemyDeadCount >= 3 then
			table.insert(achievements, 'AbilityAnneStarRain');
		end
	end
end
function GetUserAbilityAchievements_Ray(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if ability.name == 'SprayHeal' and not HasSteamAchievement('AbilityRay') then
		if ability.UseCount <= 1 then
			table.insert(achievements, 'AbilityRay');
		end
	end
end
function GetUserAbilityAchievements_Heissing(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if not HasSteamAchievement('AbilityHeissing') then
		local deathblowCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead and targetInfo.PrevHP == targetInfo.MaxHP;
		end);
		if deathblowCount >= 1 then
			table.insert(achievements, 'AbilityHeissing');
		end
	end
end
function GetUserAbilityAchievements_Leton(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if not HasSteamAchievement('AbilityLeton') then
		local isCounterAttack = HasBattleEventType(battleEvents, 'CounterAttack');
		if isCounterAttack then
			local enemyDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
				return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead;
			end);
			if enemyDeadCount >= 1 then
				table.insert(achievements, 'AbilityLeton');
			end
		end
	end
	if ability.name == 'FrostFinalKick' and not HasSteamAchievement('AbilityLetonFrostFinalKick') then
		local deathblowCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead and targetInfo.PrevHP == targetInfo.MaxHP;
		end);
		if deathblowCount >= 1 then
			table.insert(achievements, 'AbilityLetonFrostFinalKick');
		end
	end
end
function GetUserAbilityAchievements_Alisa(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if not HasSteamAchievement('AbilityAlisa') then
		local isForestallment = HasBattleEventType(battleEvents, 'Forestallment');
		if isForestallment then
			local enemyDeadCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
				return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead;
			end);
			if enemyDeadCount >= 1 then
				table.insert(achievements, 'AbilityAlisa');
			end
		end
	end
end
function GetUserAbilityAchievements_Bianca(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if not HasSteamAchievement('AbilityBianca') then
		local knockbackStunCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.KnockbackPower > 0 and targetInfo.SlideType == 'None';
		end);
		if knockbackStunCount >= 1 then
			table.insert(achievements, 'AbilityBianca');
		end
	end
end
function GetUserAbilityAchievements_Giselle(achievements, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, battleEvents)
	if ability.Type == 'Attack' and not HasSteamAchievement('AbilityGiselleHeadshot') then
		local isHeadshot = HasBattleEventType(battleEvents, 'HeadShot');
		local deathblowCount = CheckTargetCountIf(primaryTargetInfos, secondaryTargetInfos, function(targetInfo)
			return GetRelationWithPlayer(targetInfo.Target) == 'Enemy' and targetInfo.IsDead and targetInfo.PrevHP == targetInfo.MaxHP;
		end);
		if isHeadshot and deathblowCount >= 1 then
			table.insert(achievements, 'AbilityGiselleHeadshot');
		end
	end
end
function PrepareAnimationActions(phase, actions, additionalActions, usingInfo, actionIndex)
	local ret = {};
	local firstHit = 9999;
	local finalHit = -9999;
	local nextCameraFrame = 0;
	local lastAttackAction = nil;
	
	local ProcessFunc = function(actions)
		for actionType, actionSet in pairs(actions) do (function()
			if actionType == 'MultiActionDefiner' then
				return;
			end
			for i, actionInstance in ipairs(actionSet) do (function()
				local action = nil;
				if type(actionInstance) == 'table' then	-- 툴에서 동적으로 연출정보를 변경하기 위해서 먼저 프로세스를 해서 넣는 경우에 대한 처리이니 당황하지 말자!
					action = table.deepcopy(actionInstance);	-- 이미 테이블로 바뀌어서 들어옴
				else
					action = ClassToTable(actionInstance);
				end
				action.Type = actionType;
				if IsAttackType(action.Type) and (action.Phase == nil or action.Phase == phase) then
					lastAttackAction = action;
				end
				
				if not CheckAdd(phase, action, usingInfo, actionIndex) then
					return;
				end
				
				if IsAttackType(action.Type) then
					action.HitResult = usingInfo.DefenderState;
					
					if firstHit > action.Frame then
						firstHit = action.Frame;
					end
					if finalHit < action.Frame then
						finalHit = action.Frame;
					end
				end
				
				if action.Type == 'Camera' and phase == 'Base' then
					local nframe = action.Frame;
					-- 순간 점프가 아닌경우 시작 타이밍을 마지막 카메라 액션 프레임으로 잡고 원하는 프레임에 도착하도록 DiffFrame을 설정한다
					if not StringToBool(action.DirectMove) then
						action.DiffFrame = (action.Frame - nextCameraFrame);
						action.Frame = nextCameraFrame;
					else
						action.DiffFrame = 0.0;
					end
					nextCameraFrame = nframe + 1;
				end
			
				if ret[action.Frame] == nil then
					ret[action.Frame] = {};
				end
				table.insert(ret[action.Frame], action);
			end
			)(); end
			
			-- Attack Alternative... 공격타입 액션이 있음에도 불구하고 아무런 공격 연출을 받지 못한 경우 마지막 공격연출을 어거지로 끼워넣어준다.
			if not IsDandyCrafter() and phase ~= 'Base' and firstHit == 9999 and lastAttackAction then
				lastAttackAction.HitResult = usingInfo.DefenderState;
				firstHit = lastAttackAction.Frame;
				finalHit = lastAttackAction.Frame;
				if ret[lastAttackAction.Frame] == nil then
					ret[lastAttackAction.Frame] = {};
				end
				table.insert(ret[lastAttackAction.Frame], lastAttackAction);
			end
			
		end)(); end
	end
	ProcessFunc(actions);
	ProcessFunc(additionalActions);
	
	-- firstHit과, finalHit처리는 Base페이즈가 아니라 Primary나 Secondary페이즈에서나 동작할듯.. Base페이즈는 공격이 안된다
	if firstHit < 9999 then
		for i, action in ipairs(ret[firstHit]) do
			if IsAttackType(action.Type) then
				ret[firstHit][i].FirstHit = true;
			end
		end
	end
	
	if finalHit > -9999 then
		for i, action in ipairs(ret[finalHit]) do
			if IsAttackType(action.Type) then
				ret[finalHit][i].FinalHit = true;
				if usingInfo.Target.name ~= nil and usingInfo.IsDead then
					ret[finalHit][i].IsDead = true;
				end
			end
		end
	end

	-- frame 단위로 소팅해서 {{Frame, Actions}, ...} 의 테이블로 바꿔준다
	local actionsSortedByFrame = {};
	local scoreFunc = function(t)
		return t.Frame;
	end;
	for frame, _actions in pairs(ret) do
		table.bininsert(actionsSortedByFrame, {Frame = frame, Actions = _actions}, scoreFunc);
	end
	return actionsSortedByFrame;
end
function ProcessHit(ad, infoRoot, action, hitTimeActionID, relativeTime, hitArg, actionDB)
	local targetKey = GetObjKey(hitArg.Target);
	local targetTeam = GetTeam(hitArg.Target);
	
	local hitMethodCls = GetClassList('HitMethod')[hitArg.HitMethod];
	if hitMethodCls == nil then
		LogAndPrint('Invalid HitMethod was specified', hitArg.HitMethod);
		return -1, actionDB;
	end
	
	-- 애니 재생
	local aniType = 'None';
	local offsetFrame = 0;
	local hitResult = hitArg.HitResult;
	
	local stopType = 'HitStop';
	local coreID = -1;
	local voiceSound, voiceSoundVolume, voiceOffset, voiceText = GetObjectVoiceSound(hitArg.Target, 'Dead');
	local PlayDeadAction = function(deadMethod, deadlyHitPower, rollPower, refPos, deadCameraStartOffset)
		local deadID = ad:SetDead(targetKey, deadMethod, deadlyHitPower, rollPower, refPos.x or 0, refPos.y or 0, refPos.z or 0);
		ad:Connect(ad:ContinueUpdate(targetKey), deadID, 0);
		local hideBattleStatus = ad:HideBattleStatus(targetKey);
		local originalTimeFinish = hitArg.Target.Shape.DeadFrame/30;
		local timeFinish = math.max( originalTimeFinish * 0.6, originalTimeFinish - 1);
		if ad:GetConfig('AllowDeadCamera') and IsEnableTrigger(ad, hitArg.UsingInfo) then
			local deadCamera_Start = ad:ChangeCameraTarget(targetKey, 'DeadCamera_Start', true, true);
			local deadCamera_Finish = ad:ChangeCameraTarget(targetKey, 'DeadCamera_Finish', false, false, timeFinish);
			local deadCamera_AfterFinish = ad:ChangeCameraTarget(targetKey, '_SYSTEM_', true, false);
			ad:Connect(deadCamera_Start, deadID, deadCameraStartOffset);
			ad:Connect(deadCamera_Finish, deadCamera_Start, 0);
			ad:Connect(deadCamera_AfterFinish, deadCamera_Finish, math.min(timeFinish + 0.5, originalTimeFinish * 0.9));
			ad:Connect(hideBattleStatus, deadID, 1);
			if not ad:GetConfig('HideUI') then
				local ui_On = ad:BattleUIControl(true);
				local ui_Off = ad:BattleUIControl(false);
				ad:Connect(ui_Off, deadCamera_Start, 0);
				ad:Connect(ui_On, deadCamera_AfterFinish, -1);
			end
		end
		if voiceSound and voiceSound ~= 'None' and TestCharacterVoiceTextFrequency() then
			local deadPlaySoundID = ad:PlaySound3D(voiceSound, targetKey, '_CENTER_', 3000, 'Effect', voiceSoundVolume or 1.0, true, 1);
			ad:Connect(deadPlaySoundID, deadID, voiceOffset);
			if voiceText and voiceText ~= 'None' then
				local textID = ad:UpdateCharacterVoiceText(voiceText, targetKey);
				ad:Connect(textID, deadPlaySoundID, 0);
			end
		end
		ad:SetConfig('NoCamera', true);
		return deadID;
	end
	
	local hitSoundType = nil;
	if action.FinalHit and hitArg.SlideType ~= 'None' then
		local offset = relativeTime;
		if offset < 0 then
			offset = -1;
		end
	
		if action.IsDead then
			if ad:GetConfig('Preemptive') then
				ad:Connect(ad:ContinueUpdate(targetKey), hitTimeActionID, offset);
			end
				
			stopType = 'KillStop';
			local deadID = PlayDeadAction('NormalKnockback', hitArg.KnockbackSpeed, 0, hitArg.AfterPosition, 1);
			ad:Connect(deadID, hitTimeActionID, offset);
			coreID = deadID;
		else
			stopType = 'FinishStop';
			hitSoundType = 'Hit_Knockback';
			local knockbackID = ad:Knockback(targetKey, hitArg.AfterPosition.x, hitArg.AfterPosition.y, hitArg.AfterPosition.z, hitArg.KnockbackSpeed, hitArg.KnockbackInverse);
			ad:Connect(knockbackID, hitTimeActionID, offset);	
			coreID = knockbackID;
		end
	else		
		if hitResult == 'Dodge' and not GetBuffStatus(hitArg.Target, 'Unconscious', 'Or') then
			aniType = 'Block';
			offsetFrame = 5;
			stopType = 'BlockStop';
		elseif hitResult == 'Hit' then
			if action.HitMode ~= nil and action.HitMode ~= 'Auto' then
				if action.HitMode == 'Finish' then
					stopType = 'FinishStop';
					aniType = 'Finish';
					hitSoundType = 'Hit_Final';
				elseif action.HitMode == 'Hit' then
					stopType = 'HitStop';
					aniType = 'Hit';
					hitSoundType = 'Hit';
				end
			else
				if action.FinalHit then
					stopType = 'FinishStop';
					aniType = 'Finish';
					hitSoundType = 'Hit_Final';
				else
					stopType = 'HitStop';
					aniType = 'Hit';
					hitSoundType = 'Hit';
				end
			end
		elseif hitResult == 'Block'then
			aniType = 'Block';
			offsetFrame = 5;
			stopType = 'BlockStop';
			hitSoundType = 'Hit_Block';
		end

		if action.IsDead then
			if ad:GetConfig('Preemptive') then
				ad:Connect(ad:ContinueUpdate(targetKey), hitTimeActionID, relativeTime);
			end
			stopType = 'KillStop';
			local rollPowerSet = {Left= -720, None=0, Right=720};
			local rollPower = rollPowerSet[action.RollType] or 0;
			local impactOrigin = actionDB.ImpactOrigin;
			local deadID = PlayDeadAction(hitArg.DeadMethod or 'Normal', hitArg.DeadlyHitPower or 1000, rollPower, impactOrigin, 0.3);
			ad:Connect(deadID, hitTimeActionID, relativeTime);
			coreID = deadID;
		elseif aniType ~= 'None' and not ad:GetConfig('Preemptive') then
			local hitAni = ad:HitAni(targetKey, hitArg.HitMethod, aniType, offsetFrame / 30);
			local offset = relativeTime - offsetFrame / 30;
			if relativeTime < 0 then
				offset = -1;
			elseif offset < 0 then
				offset = 0;
			end
			ad:Connect(hitAni, hitTimeActionID, offset);
			coreID = hitAni;
		else
			coreID = ad:Sleep(0.1);	-- 이 케이스면 에러 아닌가?
			ad:Connect(coreID, hitTimeActionID, relativeTime);
		end
	end
	
	-- DirectingEvent
	if action.FirstHit then
		ad:FireDirectingEvent(GetObjKey(hitArg.User), 'FirstHit', coreID, 0);
		ad:FireDirectingEvent(targetKey, 'FirstHit', coreID, 0);
	end
	if action.FinalHit then
		ad:FireDirectingEvent(GetObjKey(hitArg.User), 'FinalHit', coreID, 0);
		ad:FireDirectingEvent(targetKey, 'FinalHit', coreID, 0);
	end
	
	-- 피격 경직처리
	if stopType and stopType ~= 'None' and not ad:GetConfig('Preemptive') then
		local refID = hitTimeActionID;
		local offset = relativeTime;
		if relativeTime < 0 then-- 이건 포스처럼 타이밍을 모르는 경우.. 어차피 끝난 후 지연이 필요한 거니까 적당히 Sleep같은거를 끼워넣자
			refID = ad:Sleep(0.1);
			offset = 0;
			ad:Connect(refID, hitTimeActionID, relativeTime);
		end
		--업데이트 멈추기 시간 받아오기
		local selfStop = action[stopType .. '_Self'];
		local targetStop = action[stopType .. '_Target'];
		
		if selfStop ~= nil and selfStop > 0 then
			local userKey = GetObjKey(hitArg.From);
			local userStopID = ad:StopUpdate(userKey);
			ad:Connect(userStopID, refID, offset + 0.01);
			ad:Connect(ad:ContinueUpdate(userKey), userStopID, selfStop / 30);
			actionDB.Delay = actionDB.Delay + selfStop;
		end
		
		if targetStop ~= nil and targetStop then
			local targetStopID = ad:StopUpdate(targetKey, true);
			ad:Connect(targetStopID, refID, offset + 0.05);
			ad:Connect(ad:ContinueUpdate(targetKey), targetStopID, targetStop / 30);
		end
	end
			
	-- 사운드 및 이펙트 처리
	if hitArg.HitType == 'None' then
		return coreID, actionDB;
	end
	local hitEffectSoundCls = SafeIndex(GetClassList('HitEffectSound'), hitArg.HitType, hitArg.Target.Shape.BodyType, hitArg.AttackerState, hitResult);
	
	if hitEffectSoundCls == nil or hitEffectSoundCls.Effect == nil then
		local err = string.format('HitEffectSound 키 에러 (%s, %s, %s, %s)', hitArg.HitType, hitArg.Target.Shape.BodyType, hitArg.AttackerState, hitResult);
		LogAndPrint(err);
		return coreID, actionDB;
	end
	-- 피격 이펙트 소리.
	if hitEffectSoundCls.Sound ~= 'None' then
		ad:Connect(ad:PlaySound3D(hitEffectSoundCls.Sound, targetKey, hitMethodCls.EffectPos, hitEffectSoundCls.MinDistance or 3000, 'Effect', hitEffectSoundCls.Volume or 1.0, true, hitEffectSoundCls.MaxCount or 1), hitTimeActionID, relativeTime);
	end
	-- 피격자 소리.
	if hitSoundType then
		local hitVoiceSound, hitVoiceSoundVolume, hitVoiceOffset, hitVoiceText = GetObjectVoiceSound(hitArg.Target, hitSoundType);
		if hitVoiceSound and hitVoiceSound ~= 'None' and TestCharacterVoiceTextFrequency() then
			ad:Connect(ad:PlaySound3D(hitVoiceSound, targetKey, hitMethodCls.EffectPos, 3000, 'Effect', hitVoiceSoundVolume or 1.0, true, 1), coreID, 0.1);
			if hitVoiceText and hitVoiceText ~= 'None' then
				local textID = ad:UpdateCharacterVoiceText(hitVoiceText, targetKey);
				ad:Connect(textID, coreID, 0.1);
			end
		end
	end
	local hitBone = GetObjectBonePos(hitArg.Target, hitMethodCls.EffectPos);
	if hitBone == nil then
		LogAndPrint(string.format('Can\'t Find BoneMap Info (%s, %s)', hitArg.Target.Shape.BodySize, hitMethodCls.EffectPos));
		return coreID, actionDB;
	end
	
	if hitEffectSoundCls.Effect and hitEffectSoundCls.Effect ~= 'None' and hitEffectSoundCls.Effect ~= '' then
		ad:Connect(ad:PlayParticle(targetKey, hitMethodCls.EffectPos, hitEffectSoundCls.Effect, hitEffectSoundCls.EffectFrame / 30), hitTimeActionID, relativeTime);
	end
	
	-- 데미지 표기
	if not ad:GetConfig('NoDamageShow') then
		local hitState = 'Hit';
		if action.FirstHit and action.FinalHit then
			hitState = 'UniqueHit';
		elseif action.FirstHit then
			hitState = 'FirstHit';
		elseif action.FinalHit then
			hitState = 'FinalHit';
		end
		-- 데미지 수치 처리
		local isFinal = action.FinalHit or aniType == 'Dodge';
		local damageDisplayTime = 1.5;
		if isFinal then
			damageDisplayTime = 2;
		end
		local damage = ad:PlayUIEffect(targetKey, hitMethodCls.EffectPos, 'Damage', damageDisplayTime, damageDisplayTime, 
			PackTableToString({totalDamage = hitArg.TotalDamage, isFinal = isFinal, team = hitArg.Target.Team, damage = hitArg.DamageShow, attackerState = hitArg.AttackerState, defenderState = hitResult, hitState = hitState, Containment = SafeIndex(actionDB, 'Ability', 'Containment')})
		);
		ad:Connect(damage, hitTimeActionID, relativeTime);
	end
	
	-- 체력 게이지 처리
	--LogAndPrint(string.format("Client : hitArg.Damage [%d]", hitArg.Damage));
	local damageStatus = ad:UpdateDamagedGauge(targetKey, {damage = hitArg.Damage, isFinal = false});
	ad:Connect(damageStatus, hitTimeActionID, relativeTime);
	
	return coreID, actionDB;
end
function PlayHealAction(frame, infoRoot, action, mainAniID, ad, targetInfo, actionDB)
	-- Hit Action은 발생 즉시
	if targetInfo.Target.name == nil then
		return actionDB;
	end
	local hitProcessArg = {};
	hitProcessArg.Target = targetInfo.Target;
	hitProcessArg.AttackerState = targetInfo.AttackerState;
	hitProcessArg.HitMethod = action.HitMethod;
	hitProcessArg.Damage = action.Damage;
	hitProcessArg.DamageShow = action.DamageShow;
	hitProcessArg.TotalDamage = targetInfo.MainDamage;
	
	return ProcessHeal(ad, infoRoot, action, mainAniID, frame / 30, hitProcessArg, actionDB);
end
function ProcessHeal(ad, infoRoot, action, hitTimeActionID, relativeTime, hitArg, actionDB)
	local targetKey = GetObjKey(hitArg.Target);
	local targetTeam = GetTeam(hitArg.Target);
	
	local hitMethodCls = GetClassList('HitMethod')[hitArg.HitMethod];
	if hitMethodCls == nil then
		LogAndPrint('Invalid HitMethod was specified', hitArg.HitMethod);
		return -1, actionDB;
	end
	
	-- 애니 재생
	local hitResult = 'Heal';

	-- 데미지 표기
	local hitState = 'Hit';
	if action.FirstHit and action.FinalHit then
		hitState = 'UniqueHit';
	elseif action.FirstHit then
		hitState = 'FirstHit';
	elseif action.FinalHit then
		hitState = 'FinalHit';
	end
	
	local effectType = 'Heal';
	if action.HealType == 'Cost' then
		effectType = 'HealVigor';
	elseif action.HealType == 'SP' then
		effectType = 'HealCharging';
	end
	
	-- 사운드 및 이펙트 처리
	local hitEffectSoundCls = SafeIndex(GetClassList('HitEffectSound'), effectType, hitArg.Target.Shape.BodyType, hitArg.AttackerState, hitResult);
	
	if hitEffectSoundCls == nil then
		local err = string.format('HitEffectSound 키 에러 (%s, %s, %s, %s)', hitArg.HitType, hitArg.Target.Shape.BodyType, hitArg.AttackerState, hitResult);
		LogAndPrint(err);
		return -1, actionDB;
	end
	
	local coreID = -1;
	
	if hitEffectSoundCls.Sound ~= 'None' then
		coreID = ad:PlaySound3D(hitEffectSoundCls.Sound, targetKey, hitMethodCls.EffectPos, hitEffectSoundCls.MinDistance or 3000, 'Effect', hitEffectSoundCls.Volume or 1.0)
		ad:Connect(coreID, hitTimeActionID, relativeTime);
	end
	
	local hitBone = GetObjectBonePos(hitArg.Target, hitMethodCls.EffectPos);
	if hitBone == nil then
		LogAndPrint(string.format('Can\'t Find BoneMap Info (%s, %s)', hitArg.Target.Shape.BodySize, hitMethodCls.EffectPos));
		return coreID, actionDB;
	end
	
	if hitEffectSoundCls.Effect ~= 'None' and hitEffectSoundCls.Effect ~= '' then
		coreID = ad:PlayParticle(targetKey, hitMethodCls.EffectPos, hitEffectSoundCls.Effect, hitEffectSoundCls.EffectFrame / 30);
		ad:Connect(coreID, hitTimeActionID, relativeTime);
	end
	
	if action.HealType == nil or action.HealType == 'HP' then
		-- 데미지 수치 처리
		local isFinal = action.FinalHit;
		local damageDisplayTime = 1.5;
		if isFinal then
			damageDisplayTime = 2;
		end
		local damage = ad:PlayUIEffect(targetKey, hitMethodCls.EffectPos, 'Damage', damageDisplayTime, damageDisplayTime, PackTableToString({totalDamage = hitArg.TotalDamage, isFinal = isFinal, team = hitArg.Target.Team, damage = hitArg.DamageShow, attackerState = hitArg.AttackerState, defenderState = hitResult, hitState = hitState}));
		ad:Connect(damage, hitTimeActionID, relativeTime);
		
		-- 체력 게이지 처리
		--LogAndPrint(string.format("Client : hitArg.Damage [%d]", hitArg.Damage));
		local damageStatus = ad:UpdateDamagedGauge(targetKey, {damage = hitArg.Damage, isFinal = isFinal});
		ad:Connect(damageStatus, hitTimeActionID, relativeTime);
	elseif action.HealType == 'Cost' then
		ad:Connect(ad:UpdateCostDamagedGauge(targetKey, {damage = hitArg.Damage, isFinal = isFinal}), hitTimeActionID, relativeTime);
	elseif action.HealType == 'SP' then
		ad:Connect(ad:UpdateSPDamagedGauge(targetKey, {damage = hitArg.Damage, isFinal = isFinal}), hitTimeActionID, relativeTime);
	end

	return coreID, actionDB;
end
function PlaySpeedAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local isEnablePlay = IsEnableTrigger(ad, usingInfo);
	local speedID = -1;
	if true then
		speedID = ad:ChangeSpeedFactor(action.Speed);
		ad:Connect(speedID, mainAniID, frame / 30);
	end
	return speedID;
end
function PlayTrailAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local userKey = GetObjKey(usingInfo.User);
	local trailKey = action.TrailKey;
	
	local material = action.Material;
	if material == nil then
		material = 'Trail_Base';
	end
	local lifeTime = action.Time;
	if lifeTime == nil then
		lifeTime = 0.5;
	end
	
	local colorKey = 'FFFFFFFF';	-- 시로이
	if action.Color then
		colorKey = action.Color;
	end
	
	local showID = ad:ShowSwordTrail(userKey, trailKey, 0, material, lifeTime, colorKey );
	local hideID = ad:HideSwordTrail(userKey, trailKey, action.FadeTime );
	
	ad:Connect(showID, mainAniID, frame / 30);
	ad:Connect(hideID, mainAniID, (frame + action.ShowFrame) / 30);
	return showID;
end
function ParseParticleAttribute(particleAttributeData)
	local attribute = {};
	for _, attbPair in ipairs(SafeIndex(particleAttributeData, 'Pair') or {}) do
		local value = attbPair.ParticleAttributeValue;
		if value.Type == 'Float' then
			attribute[attbPair.Key] = tonumber(value.Value);
		elseif value.Type == 'Float2' then
			attribute[attbPair.Key] = {tonumber(value.Value), tonumber(value.Value2)};
		elseif value.Type == 'Float3' then
			attribute[attbPair.Key] = {tonumber(value.Value), tonumber(value.Value2), tonumber(value.Value3)};
		elseif value.Type == 'Float4' then
			attribute[attbPair.Key] = {tonumber(value.Value), tonumber(value.Value2), tonumber(value.Value3), tonumber(value.Value4)};
		end
	end
	return attribute;
end
function PlayParticleAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)

	local userKey = GetObjKey(usingInfo.User);
	local attribute = ParseParticleAttribute(action.ParticleAttribute);
	
	if action.Target == 'Target' then
		userKey = GetObjKey(usingInfo.Target);
	end
	
	local particleID = ad:PlayParticle(userKey, action.ParticlePos, action.Particle, (action.ParticleLength or 1) / 30, StringToBool(action.AttachModel, true), StringToBool(action.DirectClear, false), action.NoWait2 == 'On', attribute);
	local frameSep = action.FrameSeparation or 0;
	ad:Connect(particleID, mainAniID, (frame + frameSep * (actionDB.ActionIndex - 2)) / 30);
	return particleID;
end
function CalculateRangeType(usingInfo, rangeType)
	local posList = nil;
	if rangeType == 'UsingPos' then
		posList = {usingInfo.UsingPos};
	elseif rangeType == 'AverageApplyPos' then
		local applyRange = CalculateRange(usingInfo.User, usingInfo.Ability.ApplyRange, usingInfo.UsingPos);
		if #applyRange == 0 then
			LogAndPrint('CalculateRangeType', 'No Range');
			return {};
		end
		local myPos = vector3.new(GetPosition(usingInfo.User));
		local ndir = vector3.new(usingInfo.UsingPos) - myPos;
		applyRange = table.filter(applyRange, function(p) return ndir:angleWith(vector3.new(p) - myPos) < 5 end);
		local posSum = {x = 0, y = 0, z = 0};
		table.foreach(applyRange, function(i, pos) posSum = table.map2(posSum, pos, __op_add) end);
		local posAverageR = table.map(posSum, function(s) return s / #applyRange end);
		local minDistanceFinder = MinMaxer.new(function(p) return GetDistance3D(p, posAverageR) end);
		minDistanceFinder:UpdateMulti(applyRange);
		posList = {minDistanceFinder:GetMin()};
	else
		posList = CalculateRange(usingInfo.User, usingInfo.Ability[rangeType], usingInfo.UsingPos);
	end
	return posList;
end
function CalculateDirection(usingInfo, modelDirection)
	local userPos = usingInfo.User.name and GetPosition(usingInfo.User) or InvalidPosition();
	local targetPos = usingInfo.Target.name and GetPosition(usingInfo.Target) or InvalidPosition();
	local usingPos = { x = usingInfo.UsingPos.x, y = usingInfo.UsingPos.y, z = usingInfo.UsingPos.z};
	
	local from, to;
	-- SelfToTarget, TargetToSelf, SelfToUsingPos, Default
	if modelDirection == 'SelfToTarget' then
		from, to = userPos, targetPos;
	elseif modelDirection == 'TargetToSelf' then
		from, to = targetPos, userPos;
	elseif modelDirection == 'SelfToUsingPos' then
		from, to = userPos, usingPos;
	else
		return nil;
	end
	return table.map2(to, from, __op_sub);
end
function PlayParticleRange(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local particle = action.Particle;
	local rangeType = action.RangeType;
	local length = action.ParticleLength / 30;
	local directClear = StringToBool(action.DirectClear, false);
	local attribute = ParseParticleAttribute(action.ParticleAttribute);
	local particleDirection = action.ParticleDirection or 'SelfToUsingPos';
	
	local dir = CalculateDirection(usingInfo, particleDirection);
	
	local user = usingInfo.User;
	local particleID = -1;
	local posList = CalculateRangeType(usingInfo, action.RangeType);
	for i, pos in ipairs(posList) do
		local posDir = dir and table.map2(pos, dir, __op_add) or InvalidPosition();
		particleID = ad:PlayParticlePosDir(pos, posDir, particle, 0, length, directClear, action.NoWait2 == 'On', attribute);
		ad:Connect(particleID, mainAniID, frame / 30);
	end
	return particleID;
end
function PlayModelEffectAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local mesh = action.Mesh;
	local skeleton = action.Skeleton or '';
	local rangeType = action.RangeType;
	local animation = action.Animation;
	local showFrame = action.ShowFrame;
	local noWait = action.NoWait ~= 'Off';
	local modelDirection = action.ModelDirection;
	
	local dir = CalculateDirection(usingInfo, modelDirection);
	
	local posList = CalculateRangeType(usingInfo, action.RangeType);
	local effectID = -1;
	for i, pos in ipairs(posList) do
		effectID = ad:PlayModelEffect(mesh, skeleton, pos, animation, showFrame / 30, noWait, dir);
		ad:Connect(effectID, mainAniID, frame / 30);
	end
	return effectID;
end
function PlaySpawnAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local rangeType = action.RangeType;
	local modelDirection = action.ModelDirection;
	
	local dir = CalculateDirection(usingInfo, modelDirection);
	
	local posList = CalculateRangeType(usingInfo, action.RangeType);
	local effectID = -1;
	if #posList == 0 then
		return effectID;
	end
	
	local actor = nil;
	if action.Target == 'User' then
		actor = usingInfo.User;
	elseif action.Target == 'Target' then
		actor = usingInfo.Target;
	else
		return -1;
	end
	
	local retID = ad:Move(GetObjKey(actor), posList[1], true);
	ad:Connect(retID, mainAniID, frame / 30);
	ad:Connect(ad:LookPos(GetObjKey(actor), dir, true, true), retID, -1);
	return retID;
end
function PlayPlayAniAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local actor = nil;
	if action.Target == 'User' then
		actor = usingInfo.User;
	elseif action.Target == 'Target' then
		actor = usingInfo.Target;
	end
	local ret = ad:PlayAni(GetObjKey(actor), action.Animation, false);
	ad:Connect(ret, mainAniID, frame / 30);
	return ret;
end
function PlayCameraAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local user = GetObjKey(usingInfo.User);
	local target = GetObjKey(usingInfo.Target);
	local cameraID = -1;

	local isEnablePlay = IsEnableTrigger(ad, usingInfo);
	
	--LogAndPrint('PlayCameraAction', action.CameraMode, action.DirectMove, type(action.DirectMove));
	if isEnablePlay then
		local frameSeparation = action.FrameSeparation or 0;
		local moveTime = action.DiffFrame or actionDB.ActionIndex == 0 and 0 or (frameSeparation - 2);
		if action.CameraMode == 'SelfToTarget' then
			cameraID = ad:ChangeCameraTargetingMode(user, target, action.CamTargetKey, StringToBool(action.DirectMove), StringToBool(action.ReleaseAfter, true), moveTime / 30);
		elseif action.CameraMode == 'TargetToSelf' then
			cameraID = ad:ChangeCameraTargetingMode(target, user, action.CamTargetKey, StringToBool(action.DirectMove), StringToBool(action.ReleaseAfter, true), moveTime / 30);
		elseif action.CameraMode == 'Self' then
			cameraID = ad:ChangeCameraTarget(user, action.CamTargetKey, StringToBool(action.DirectMove), StringToBool(action.ReleaseAfter, true), moveTime / 30);
		elseif action.CameraMode == 'Target' then
			cameraID = ad:ChangeCameraTarget(target, action.CamTargetKey, StringToBool(action.DirectMove), StringToBool(action.ReleaseAfter, true), moveTime / 30);
		elseif action.CameraMode == 'SelfToUsingPos' then
			local usingPos = { x = usingInfo.UsingPos.x, y = usingInfo.UsingPos.y, z = usingInfo.UsingPos.z};
			cameraID = ad:ChangeCameraTargetingPositionMode(user, usingPos, action.CamTargetKey, StringToBool(action.DirectMove), StringToBool(action.ReleaseAfter, true), moveTime / 30);
		end
		if cameraID == -1 then
			LogAndPrint(string.format("[DataError] ::: cameraID is -1 Value!! %d frame on", frame));
		else
			ad:Connect(cameraID, mainAniID, (frame + frameSeparation * (actionDB.ActionIndex - 2)) / 30);
		end
	end
	return cameraID;
end
function PlayWiggleCameraAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local wiggleCamID = nil;
	if not ad:GetConfig('NoWiggle') and not ad:GetConfig('NoAutoSight') then
		wiggleCamID = ad:WiggleCamera(action.Power, action.Time);
	else
		wiggleCamID = ad:Sleep(0);
	end
	ad:Connect(wiggleCamID, mainAniID, frame / 30);
	return wiggleCamID;
end
function PlaySoundAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local actor = nil;
	if action.Target == 'User' then
		actor = usingInfo.User;
	elseif action.Target == 'Target' then
		actor = usingInfo.Target;
	end
	
	local soundID = -1;
	if actor then
		soundID = ad:PlaySound3D(action.Sound, GetObjKey(actor), action.FromPos, action.MinDistance or 3000, 'Effect', action.Volume or 1.0, action.NoWait ~= 'Off');
	else
		soundID = ad:PlaySound(action.Sound, 'Effect', action.Volume or 1.0, action.NoWait ~= 'Off');
	end
	local frameSep = action.FrameSeparation or 0;
	ad:Connect(soundID, mainAniID, (frame + frameSep * (actionDB.ActionIndex - 2)) / 30);
	return soundID;
end

function BuildHitProcessArg(action, targetInfo)
	local hitProcessArg = {};
	hitProcessArg.User = targetInfo.User;
	if action.Phase == 'Primary' then
		hitProcessArg.From = targetInfo.User;
	else
		hitProcessArg.From = targetInfo.TriggerObj;
	end
	hitProcessArg.Target = targetInfo.Target;
	hitProcessArg.HitType = action.HitType;
	hitProcessArg.AttackerState = targetInfo.AttackerState;
	hitProcessArg.DefenderState = targetInfo.DefenderState;
	hitProcessArg.HitResult = action.HitResult;
	hitProcessArg.HitMethod = action.HitMethod;
	hitProcessArg.Damage = action.Damage;
	hitProcessArg.DamageShow = action.DamageShow;
	hitProcessArg.TotalDamage = targetInfo.MainDamage;
	hitProcessArg.SlideType = targetInfo.SlideType;
	hitProcessArg.AfterPosition = targetInfo.AfterPosition;
	hitProcessArg.KnockbackSpeed = targetInfo.KnockbackSpeed;
	hitProcessArg.KnockbackInverse = targetInfo.KnockbackInverse;
	hitProcessArg.DeadMethod = action.DeadMethod;
	hitProcessArg.DeadlyHitPower = action.DeadlyHitPower;
	hitProcessArg.UsingInfo = targetInfo;
	if targetInfo.Target and targetInfo.SnipeType ~= 'None' then
		local snipeCls = GetClassList('Snipe')[targetInfo.Target.SnipeType];
		local snipeHitMethod = snipeCls.TargetPosition[targetInfo.SnipeType].HitMethod;
		if snipeHitMethod and snipeHitMethod ~= 'None' and GetClassList('HitMethod')[snipeHitMethod] ~= nil then
			hitProcessArg.HitMethod = snipeHitMethod;
		end
	end
	return hitProcessArg;
end
function PlayHitAction(frame, infoRoot, action, mainAniID, ad, targetInfo, actionDB)
	-- Hit Action은 발생 즉시
	if targetInfo.Target.name == nil then
		return actionDB;
	end
	local hitProcessArg = BuildHitProcessArg(action, targetInfo);
	
	local frameSep = action.FrameSeparation or 0;
	local relativeTime = (frame + frameSep * (actionDB.ActionIndex - 2)) / 30;
	return ProcessHit(ad, infoRoot, action, mainAniID, relativeTime, hitProcessArg, actionDB);
end
function PlayForceHitAction(frame, infoRoot, action, mainAniID, ad, targetInfo, actionDB)
	local hitProcessArg = BuildHitProcessArg(action, targetInfo);
	local forceCls = GetClassList('Force')[action.Force];
	hitProcessArg.HitType = forceCls.HitType;
	local particle = forceCls.Particle;
	local startSound = forceCls.StartSound;
	local endSound = forceCls.EndSound;
	local attribute = ParseParticleAttribute(action.ParticleAttribute);
	attribute.ForceIdentifier = targetInfo.User.Weapon.ForceIdentifier;
	
	local hitMethodCls = GetClassList('HitMethod')[action.HitMethod];
	if hitMethodCls == nil then
		return -1, actionDB;
	end
	
	local toPos = hitMethodCls.EffectPos;
	if targetInfo.Target and targetInfo.SnipeType ~= 'None' then
		local snipeCls = GetClassList('Snipe')[targetInfo.Target.SnipeType];
		toPos = snipeCls.TargetPosition[targetInfo.SnipeType].BoneName;
	end
	
	local forceID, endTime;
	if targetInfo.Target.name == nil then
		local pos = action.AlternativeShot and targetInfo.UsingPos or targetInfo.TargetPos;
		forceID = ad:ForceEffectPosition(GetObjKey(targetInfo.User), action.FromPos, pos.x, pos.y, pos.z, action.Force, action.AlternativeYOffset or 0, attribute);
		endTime = -1;
	else
		forceID = ad:ForceEffect(GetObjKey(targetInfo.User), action.FromPos, GetObjKey(targetInfo.Target), toPos, action.Force, false, '', attribute);
	end
	local frameSeparation = action.FrameSeparation or 0;
	ad:Connect(forceID, mainAniID, (frame + frameSeparation * (actionDB.ActionIndex - 2)) / 30);
	if startSound ~= 'None' then
		ad:Connect(ad:PlaySound3D(startSound, GetObjKey(targetInfo.User), action.FromPos, forceCls.StartSoundMinDistance or 3000, 'Effect', forceCls.StartSoundVolume or 1.0, true), forceID, 0);
	end
	if endSound ~= 'None' then
		ad:Connect(ad:PlaySound3D(endSound, GetObjKey(targetInfo.Target), toPos, forceCls.EndSoundMinDistance or 3000, 'Effect', forceCls.EndSoundVolume or 1.0, true), forceID, -1);
	end

	if targetInfo.Target.name then
		return ProcessHit(ad, infoRoot, action, forceID, -1, hitProcessArg, actionDB);
	else
		return forceID, actionDB;
	end
end

function PlayForceAction(frame, infoRoot, action, mainAniID, ad, targetInfo, actionDB)
	local forceCls = GetClassList('Force')[action.Force];
	local startSound = forceCls.StartSound;
	local endSound = forceCls.EndSound;
	
	local user = targetInfo.User;
	local attribute = ParseParticleAttribute(action.ParticleAttribute);
	attribute.ForceIdentifier = user.Weapon.ForceIdentifier;
	
	local toPos = action.ToPos;
	if targetInfo.Target and targetInfo.SnipeType ~= 'None' then
		local snipeCls = GetClassList('Snipe')[targetInfo.Target.SnipeType];
		toPos = snipeCls.TargetPosition[targetInfo.SnipeType].BoneName;
	end
	
	local forceID, endTime;
	if targetInfo.Target.name == nil then
		local pos = action.AlternativeShot and targetInfo.UsingPos or targetInfo.TargetPos;
		LogAndPrint('ForceEffectPosition', attribute);
		forceID = ad:ForceEffectPosition(GetObjKey(targetInfo.User), action.FromPos, pos.x, pos.y, pos.z, action.Force, 0.0, attribute);
		endTime = -1;
	else
		forceID = ad:ForceEffect(GetObjKey(targetInfo.User), action.FromPos, GetObjKey(targetInfo.Target), toPos, action.Force, false, '', attribute);
	end
	local frameSeparation = action.FrameSeparation or 0;
	ad:Connect(forceID, mainAniID, (frame + frameSeparation * (actionDB.ActionIndex - 2)) / 30);
	if startSound ~= 'None' then
		ad:Connect(ad:PlaySound3D(startSound, GetObjKey(targetInfo.User), action.FromPos, forceCls.StartSoundMinDistance or 3000, 'Effect', forceCls.StartSoundVolume or 1.0, true), forceID, 0);
	end
	if endSound ~= 'None' then
		ad:Connect(ad:PlaySound3D(endSound, GetObjKey(targetInfo.Target), toPos, forceCls.EndSoundMinDistance or 3000, 'Effect', forceCls.EndSoundVolume or 1.0, true), forceID, -1);
	end

	return forceID, actionDB;
end

function PlayChainForceHitAction(frame, infoRoot, action, mainAniID, ad, targetInfo, actionDB)
	if targetInfo.Target.name == nil then
		return actionDB;
	end
	local hitProcessArg = BuildHitProcessArg(action, targetInfo);
	local attribute = ParseParticleAttribute(action.ParticleAttribute);
	attribute.ForceIdentifier = hitProcessArg.From.Weapon.ForceIdentifier;
	
	local forceCls = GetClassList('Force')[action.Force];
	hitProcessArg.HitType = forceCls.HitType;
	local particle = forceCls.Particle;
	local startSound = forceCls.StartSound;
	local endSound = forceCls.EndSound;
	
	local hitMethodCls = GetClassList('HitMethod')[action.HitMethod];
	if hitMethodCls == nil then
		return actionDB;
	end
	
	local forceStartObjKey = GetObjKey(hitProcessArg.From);
	local connectID = mainAniID;
	local offset = 0;
	if frame == -1 then
		offset = frame;
	else
		offset = frame / 30;
	end
	local fromPos = action.FromPos;
	local lastForceChainID = SafeIndex(actionDB, 'ChainForce', targetInfo.ChainTriggerID, frame, 'ID');
	if lastForceChainID then
		forceStartObjKey = SafeIndex(actionDB, 'ChainForce', targetInfo.ChainTriggerID, frame, 'Object');
		connectID = lastForceChainID;
		offset = -1;
		fromPos = hitMethodCls.EffectPos;	-- 두번째 체인부터는 맞는 위치부터 맞는 위치로
	end
	
	local forceTargetObjKey = GetObjKey(targetInfo.Target);
	local forceID = ad:ForceEffect(forceStartObjKey, fromPos, forceTargetObjKey, hitMethodCls.EffectPos, action.Force, '', attribute);
	ForceNewIndex(actionDB, 'ChainForce', targetInfo.ChainTriggerID, frame, 'ID', forceID);
	ForceNewIndex(actionDB, 'ChainForce', targetInfo.ChainTriggerID, frame, 'Object', forceTargetObjKey);
	
	ad:Connect(forceID, connectID, offset);
	if startSound ~= 'None' then
		ad:Connect(ad:PlaySound3D(startSound, forceStartObjKey, fromPos, forceCls.StartSoundMinDistance or 3000, 'Effect', forceCls.StartSoundVolume or 1.0, true), forceID, 0);
	end
	if endSound ~= 'None' then
		ad:Connect(ad:PlaySound3D(endSound, forceTargetObjKey, hitMethodCls.EffectPos, forceCls.EndSoundMinDistance or 3000, 'Effect', forceCls.EndSoundVolume or 1.0, true), forceID, -1);
	end
	
	return ProcessHit(ad, infoRoot, action, forceID, -1, hitProcessArg, actionDB);
end
function PlayRemoveForceAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local actor = nil;
	if action.Target == 'User' then
		actor = usingInfo.User;
	elseif action.Target == 'Target' then
		actor = usingInfo.Target;
	end
	if actor ==  nil then
		LogAndPrint('PlayRemoveForceAction', '- Actor Not Exist - ', action.Target, usingInfo.User, usingInfo.Target);
		return;
	end
	local removeForceID = ad:DestroyIndependentForce(GetObjKey(actor), action.Key);
	ad:Connect(removeForceID, mainAniID, frame / 30);
	return removeForceID;
end
function PlayForceRangeAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local forceCls = GetClassList('Force')[action.Force];
	local startSound = forceCls.StartSound;
	local endSound = forceCls.EndSound;
	
	local user = usingInfo.User;
	local attribute = ParseParticleAttribute(action.ParticleAttribute);
	attribute.ForceIdentifier = user.Weapon.ForceIdentifier;
	
	local FireForceFunc = function(pos)
		local forceID = ad:ForceEffectPosition(GetObjKey(user), action.FromPos, pos.x, pos.y, pos.z, action.Force, action.YOffset or 0, attribute);
		ad:Connect(forceID, mainAniID, frame / 30);
		if startSound ~= 'None' then
			ad:Connect(ad:PlaySound3D(startSound, GetObjKey(user), action.FromPos, forceCls.StartSoundMinDistance or 3000, 'Effect', forceCls.StartSoundVolume or 1.0, true), forceID, 0);
		end
		if endSound ~= 'None' then
			ad:Connect(ad:PlaySound3DPosition(endSound, pos.x, pos.y, pos.z, forceCls.EndSoundMinDistance or 3000, 'Effect', forceCls.EndSoundVolume or 1.0, true), forceID, -1);
		end	
		return forceID;
	end

	local forceID = -1;	-- 알게뭐여
	for _, p in ipairs(CalculateRangeType(usingInfo, action.RangeType)) do
		forceID = FireForceFunc(p);
	end

	return forceID;
end
function PlayRushAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local actor = nil;
	local lookTarget = nil;
	local pos = nil;
	if action.Target == 'User' then
		actor = usingInfo.User;
	elseif action.Target == 'Target' then
		actor = usingInfo.Target;
		lookTarget = usingInfo.User;
	end
	if action.RushPositionIndicator == 'BasePos' then
		pos = GetPosition(actor);
	else
		pos = usingInfo[action.RushPositionIndicator];
	end
	local lookTarget = action.LookTarget or 'Target';
	if lookTarget == 'User' then
		lookTarget = usingInfo.User;
	elseif action.LookTarget == 'Target' then
		lookTarget = usingInfo.Target;
	end
	if lookTarget == actor then
		lookTarget = nil;
	end
	if actor == nil or pos == nil then
		LogAndPrint('actor or pos is empty', actor, pos);
		return;
	end
	
	local useFixSpeed = false;
	local speed = 0;
	if action.Speed ~= nil then
		useFixSpeed = true;
		speed = action.Speed;
	end
	
	local rushID = ad:Rush(GetObjKey(actor), GetObjKey(lookTarget), pos.x, pos.y, pos.z, action.ForwardOffset or 0, action.ShowFrame / 30, useFixSpeed, speed, action.YOffset or 0);
	ad:Connect(rushID, mainAniID, frame / 30);
	return rushID;
end
function PlayBreakpointAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local bpID = ad:InvokeBreakpoint()
	ad:Connect(bpID, mainAniID, frame / 30);
	return bpID;
end
function PlaySpecialSceneAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local beginID = ad:BeginSpecialScene(action.SceneColor);
	ad:Connect(beginID, mainAniID, frame / 30);
	ad:Connect(ad:EndSpecialScene(), beginID, action.ShowFrame / 30);
	return beginID;
end
function PlayVisibleAction(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local targetUnit = action.Target == 'User' and usingInfo.User or usingInfo.Target;
	local unitKey = GetObjKey(targetUnit);
	local actionId;
	if action.Visible == 'true' then
		actionId = ad:ShowObject(unitKey, false);
	else
		actionId = ad:HideObject(unitKey);
	end
	ad:Connect(actionId, mainAniID, frame / 30);
	return actionId;
end
function PlayBalloonChat(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local targetUnit = action.Target == 'User' and usingInfo.User or usingInfo.Target;
	local unitKey = GetObjKey(targetUnit);
	local ret = ad:UpdateBalloonChat(unitKey, action.Message);
	ad:Connect(ret, mainAniID, (frame + action.FrameSeparation * (actionDB.ActionIndex - 2)) / 30);
	return ret;
end

local sightObjectKeyIDCounter = 765;
function GetNewTemporarySightObjectKey()
	sightObjectKeyIDCounter = sightObjectKeyIDCounter + 1;
	return 'TempSightObject' .. sightObjectKeyIDCounter;
end
function PlaySightOn(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local objKey = GetNewTemporarySightObjectKey();
	local pos = GetPosition(usingInfo.Target);
	local createId = ad:CreateClientSightObject(objKey, pos.x, pos.y, pos.z, action.Range);
	ad:Connect(createId, mainAniID, (frame + action.FrameSeparation * (actionDB.ActionIndex - 2)) / 30);
	ad:Connect(ad:DestroyClientSightObject(objKey), createId, action.ShowFrame / 30);
	return createId;
end
function PlayEvent(frame, infoRoot, action, mainAniID, ad, usingInfo, actionDB)
	local ret = ad:Sleep(0);
	ad:Connect(ret, mainAniID, frame / 30);
	return ret;
end
function PlayAction(frame, infoRoot, action, refID, ad, usingInfo, actionDB)
	local ActionPlayer = {
		Sound = PlaySoundAction,
		Hit = PlayHitAction,
		ForceHit = PlayForceHitAction,
		Force = PlayForceAction,
		ChainForceHit = PlayChainForceHitAction,
		ForceRange = PlayForceRangeAction,
		Heal = PlayHealAction,
		Camera = PlayCameraAction,
		WiggleCamera = PlayWiggleCameraAction,
		Speed = PlaySpeedAction,
		Particle = PlayParticleAction,
		ParticleRange = PlayParticleRange,
		Trail = PlayTrailAction,
		Rush = PlayRushAction,
		RemoveForce = PlayRemoveForceAction,
		Breakpoint = PlayBreakpointAction,
		SpecialScene = PlaySpecialSceneAction,
		Visible = PlayVisibleAction,
		BalloonChat = PlayBalloonChat,
		SightOn = PlaySightOn,
		Event = PlayEvent,
		ModelEffect = PlayModelEffectAction,
		Spawn = PlaySpawnAction,
		PlayAni = PlayPlayAniAction,
		__index = function(t, key) print('not handled action type ' .. key); return function() end; end
	}
	setmetatable(ActionPlayer, ActionPlayer);
	
	if action.InRefID ~= nil and action.InRefID > 0 then
		local chainActionID = SafeIndex(actionDB, 'RefID', action.InRefID);
		if chainActionID ~= nil then
			refID = chainActionID;
		end
	end	
	
	local rFrame = frame + actionDB.Delay;
	local chainActionID, retDB = ActionPlayer[action.Type](rFrame, infoRoot, action, refID, ad, usingInfo, actionDB);
	
	local startEvent = SafeIndex(action, 'StartEvent');
	if startEvent ~= nil and startEvent ~= '' then
		ad:FireDirectingEvent(GetObjKey(usingInfo.User), startEvent, chainActionID, 0);
		if usingInfo.Target.name then
			ad:FireDirectingEvent(GetObjKey(usingInfo.Target), startEvent, chainActionID, 0);
		end
	end
	local endEvent = SafeIndex(action, 'EndEvent');
	if endEvent ~= nil and endEvent ~= '' then
		ad:FireDirectingEvent(GetObjKey(usingInfo.User), endEvent, chainActionID, -1);
		if usingInfo.Target.name then
			ad:FireDirectingEvent(GetObjKey(usingInfo.Target), endEvent, chainActionID, -1);
		end
	end
	
	if retDB then
		actionDB = retDB;
	end
	if StringToBool(action.ChainTrigger, false) then
		ForceNewIndex(actionDB, 'ChainTriggerID', usingInfo.ChainID, chainActionID);
	end
	if action.OutRefID ~= nil and action.OutRefID > 0 then
		ForceNewIndex(actionDB, 'RefID', action.OutRefID, chainActionID);
	end
	return actionDB;
end
function PlayAbilityDirect(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	if not abilityAnimationInfo then
		local animationInfoList = GetClassList('ObjectAnimationInfo');
		local animationPlayer = userInfo.User.Shape.ObjectAnimationInfo;
		local animationInfo = animationInfoList[animationPlayer];
		if animationInfo == nil then
			LogAndPrint(string.format('ObjectAnimationInfo %s is nil', animationPlayer));
			return -1;
		end
		abilityAnimationInfo = animationInfo.Abilities[ability.name];
		if abilityAnimationInfo == nil then
			LogAndPrint(string.format('Abilities of ObjectAnimationInfo %s is nil', ability.name));
			return -1;
		end
	end
	return PlayAbilityDirectInternal(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
end

function DistributeDamage(damageRatios, totalDamage)
	local epsilon = 1E-12;
	
	-- case : totalDamage == 0
	if math.abs(totalDamage) < epsilon then
		for i, damageRatio in ipairs(damageRatios) do
			damageRatio.damage = 0;
		end
		return;
	end

	local minRatio = 1.0 / math.abs(totalDamage);
	local remainRatio = 0;
	local newDamageRatios = {};
	
	for i, damageRatio in ipairs(damageRatios) do
		local newDamageRatio = {};
		newDamageRatio.localIndex = i;
		newDamageRatio.orgRatio = damageRatio.ratio;
		table.insert(newDamageRatios, newDamageRatio);
	end
	
	-- fix orginal ratio
	local totalRatio = 0;
	for _, damageRatio in ipairs(newDamageRatios) do
		totalRatio = totalRatio + damageRatio.orgRatio;
	end
	for _, damageRatio in ipairs(newDamageRatios) do
		damageRatio.orgRatio = damageRatio.orgRatio / totalRatio;
	end
	
	for _, damageRatio in ipairs(newDamageRatios) do
		local newRatio = math.floor(damageRatio.orgRatio / minRatio) * minRatio;
		newRatio = math.max(newRatio, minRatio);

		damageRatio.newRatio = newRatio;
		damageRatio.diffRatio = damageRatio.orgRatio - damageRatio.newRatio;
		remainRatio = remainRatio + damageRatio.diffRatio;
	end
	
	while remainRatio > epsilon do
		-- pick most different damage from original ratio
		table.sort(newDamageRatios, function (a,b) return a.diffRatio > b.diffRatio end);
		local damageRatio = newDamageRatios[1];

		damageRatio.newRatio = damageRatio.newRatio + minRatio;
		damageRatio.diffRatio = damageRatio.orgRatio - damageRatio.newRatio;
		remainRatio = remainRatio - minRatio;
	end
	
	while remainRatio < -epsilon do
		-- pick largest damage ratio (if new-ratio is eqaul, pick smallest org-ratio. if org-ratio is equal, pick front)
		local cmp = function(a, b)
			if math.abs(a.newRatio - b.newRatio) < epsilon then
				if math.abs(a.orgRatio - b.orgRatio) < epsilon then
					return a.localIndex < b.localIndex;
				else
					return a.orgRatio < b.orgRatio;
				end
			else
				return a.newRatio > b.newRatio;
			end
		end
		
		table.sort(newDamageRatios, cmp);
		local damageRatio = newDamageRatios[1];

		damageRatio.newRatio = damageRatio.newRatio - minRatio;
		damageRatio.diffRatio = damageRatio.orgRatio - damageRatio.newRatio;
		remainRatio = remainRatio + minRatio;
	end
			
	table.sort(newDamageRatios, function (a,b) return a.localIndex < b.localIndex end);
	
	for i, damageRatio in ipairs(newDamageRatios) do
		damageRatios[i].damage = math.floor(damageRatio.newRatio * totalDamage + epsilon);
	end
end

function PlayAbilityDirectInternal(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local user = GetObjKey(userInfo.User);
	local target = GetObjKey(userInfo.Target);
	-- UI 숨김 처리
	if not ad:GetConfig('Preemptive') and GetRelationWithPlayer(userInfo.User) == 'Team' and (ability.Type == 'Attack' or ability.Type == 'Assist' or ability.Type == 'Heal') then
		ad:SetConfig('HideUI', true);
		ad:BattleUIControl(false);
	end	
	-- Action Start!
	local camSpotlightMove = nil;
	if abilityAnimationInfo.CameraSpotlight then
		if userInfo.Target.name ~= nil then
			camSpotlightMove = ad:ChangeCameraTargetingMode(GetObjKey(userInfo.User), GetObjKey(userInfo.Target), '_SYSTEM_', false, false, 0.5);
		elseif GetAbilityUseType(ability) == 'Attack_Range' then
			camSpotlightMove = ad:ChangeCameraTargetingPositionMode(GetObjKey(userInfo.User), userInfo.UsingPos, '_SYSTEM_', false, false, 0.5);
		else
			camSpotlightMove = ad:ChangeCameraTarget(GetObjKey(userInfo.User), '_SYSTEM_', false, false, 0.5);
		end
	end
	local sleepTime = 0;
	local sleepID = ad:Sleep(sleepTime);
	-- 어빌리티 사용시 
	local voiceSound, voiceSoundVolume, voiceOffset, voiceText = GetObjectVoiceSound(userInfo.User, 'Ability_'..ability.name);
	if voiceSound ~= nil and voiceSound ~= 'None' and TestCharacterVoiceTextFrequency() then
		local enable = ad:EnableIf('TestObjectVisibleAndAlive', user);
		ad:Connect(enable, sleepID, 0);
		local voiceId = nil;
		if GetRelationWithPlayer(userInfo.User) == 'Team' then
			voiceId = ad:PlaySound(voiceSound, 'Voice', voiceSoundVolume, true);
		else
			voiceId = ad:PlaySound3D(voiceSound, user, '_CENTER_', 3000, 'Voice', voiceSoundVolume or 1.0, true);
		end
		ad:Connect(voiceId, enable, sleepTime + voiceOffset);
		if voiceText and voiceText ~= 'None' then
			local textID = ad:UpdateCharacterVoiceText(voiceText, user);
			ad:Connect(textID, voiceId, 0);
		end
	end
	if camSpotlightMove then
		ad:Connect(sleepID, camSpotlightMove, -1);
	end
	local mainAniID = 0;
	if abilityAnimationInfo.ReleasePose then
		mainAniID = ad:ReleasePose(user, ability.Animation);
	else
		if ability.Animation ~= '' then
			mainAniID = ad:PlayAni(user, ability.Animation, false);
		else
			mainAniID = ad:Sleep(0);
		end
	end
	ad:Connect(mainAniID, sleepID, -1);
	--ad:Connect(ad:BattleUIControl(false), mainAniID, 0);
	
	local impactOrigin = GetPosition(userInfo.User);
	if abilityAnimationInfo.ImpactOrigin == 'UsingPos' then
		impactOrigin = userInfo.UsingPos;
	end
	
	local autoGeneratedActions = {};
	for _, action in ipairs(abilityAnimationInfo.Actions.MultiActionDefiner) do
		local updateFunc = loadstring(action.ActionModifier);
		local actionBase = action.ActionBase;
		for index, frame in ipairs(action.FrameList.Frame) do
			local frame = frame.Frame;
			local newAction = nil;
			if type(actionBase) == 'table' then
				newAction = table.deepcopy(actionBase);
			elseif IsClass(actionBase) then
				newAction = ClassToTable(actionBase);
			elseif IsObject(actionBase) then
				newAction = ObjectToTable(actionBase);
			end
			
			newAction.Phase = action.Phase;
			newAction.Frame = frame;
			local env = {action = newAction, index = index};
			setmetatable(env, {__index = _G});
			setfenv(updateFunc, env);
			updateFunc();
			if autoGeneratedActions[newAction.Type] == nil then
				autoGeneratedActions[newAction.Type] = {newAction};
			else
				table.insert(autoGeneratedActions[newAction.Type], newAction);
			end
		end
	end
	
	local damageAction = Set.new({'Hit', 'ForceHit', 'Heal', 'ChainForceHit'});
	
	local CollectActionFunc = function(phase, usingInfo, actionIndex, isTarget)
		local actions = PrepareAnimationActions(phase, abilityAnimationInfo.Actions, autoGeneratedActions, usingInfo, actionIndex);
		local retActions = {};
		
		if isTarget and usingInfo.MainDamage ~= nil then
			local damageRatios = {};
			local damageRatiosShow = {};
			for i, actionInfo in ipairs(actions) do
				local frame = actionInfo.Frame;
				for j, action in ipairs(actionInfo.Actions) do
					if damageAction[action.Type] and action.Damage ~= nil and action.Damage ~= 0 then
						table.insert(damageRatios, { i = i, j = j, ratio = action.Damage, damage = 100 });
						table.insert(damageRatiosShow, { i = i, j = j, ratio = action.Damage, damage = 100 });
					end
				end
			end
			
			DistributeDamage(damageRatios, usingInfo.MainDamage);
			DistributeDamage(damageRatiosShow, usingInfo.ShowDamage);
			
			for _, damageRatio in ipairs(damageRatios) do
				actions[damageRatio.i].Actions[damageRatio.j].Damage = damageRatio.damage;
			end
			for _, damageRatio in ipairs(damageRatiosShow) do
				actions[damageRatio.i].Actions[damageRatio.j].DamageShow = damageRatio.damage;
			end
		end
		
		for i, actionInfo in ipairs(actions) do
			local frame = actionInfo.Frame;
			for j, action in ipairs(actionInfo.Actions) do
				local inRefID = (action.InRefID and action.InRefID or 0);
				table.insert(retActions, {Frame = frame, Action = action, ActionIndex = actionIndex, UsingInfo = usingInfo, InternalIndex = j, InRefID = inRefID});
				--actionDB = PlayAction(frame, abilityAnimationInfo, action, frameRefID, ad, usingInfo, actionDB)
			end
		end
		return retActions;
	end
	
	local targetCount = #primaryTargetInfos + #secondaryTargetInfos;
	ad:SetConfig('AllowDeadCamera', (targetCount <= 1));
	
	local actionCollection = {};
	for i, actionSet in ipairs(CollectActionFunc('Base', userInfo, 1, false)) do
		table.insert(actionCollection, actionSet);
	end
	for i, targetInfo in ipairs(primaryTargetInfos) do
		for j, actionSet in ipairs(CollectActionFunc('Primary', targetInfo, i + 1, true)) do
			table.insert(actionCollection, actionSet);
		end
	end
	local virtualTargetCount = math.max(ability.RandomPickCount, 1);
	for i = #primaryTargetInfos + 1, virtualTargetCount do
		for _, actionSet in ipairs(CollectActionFunc('Primary', userInfo, i + 1, false)) do
			if actionSet.Action.AlternativeShot then
				table.insert(actionCollection, actionSet);
			end
		end
	end
	--[[
	for i, action in ipairs(actionCollection) do
		LogAndPrint('Frame', action.Frame, 'ActionIndex', action.ActionIndex);
	end]]
	-- Base랑 Primary만 먼저 돌린다
	table.sort(actionCollection, function(a, b)
		if a.InRefID ~= b.InRefID then
			return a.InRefID < b.InRefID;
		elseif a.Frame ~= b.Frame then
			return a.Frame < b.Frame;
		elseif a.ActionIndex ~= b.ActionIndex then
			return a.ActionIndex < b.ActionIndex;
		else
			return a.InternalIndex < b.InternalIndex; 
		end
	end);
	
	local actionDB = {Delay = 0, ImpactOrigin = impactOrigin, Ability = ability};
	for i, actionSet in ipairs(actionCollection) do
		actionDB.ActionIndex = actionSet.ActionIndex;
		actionDB = PlayAction(actionSet.Frame, abilityAnimationInfo, actionSet.Action, mainAniID, ad, actionSet.UsingInfo, actionDB);
	end
	actionDB.Delay = 0;	-- Secondary는 딜레이 아직 미적용
	for i, targetInfo in ipairs(secondaryTargetInfos) do
		actionDB.ActionIndex = i;
		local refID = actionDB.ChainTriggerID[targetInfo.ChainTriggerID];
		if refID ~= -1 then
			for j, actionSet in ipairs(CollectActionFunc('Secondary', targetInfo, i, true)) do
				actionDB = PlayAction(actionSet.Frame, abilityAnimationInfo, actionSet.Action, refID, ad, actionSet.UsingInfo, actionDB);
			end
		else
			LogAndPrint('Chain Trriger Not Exist', targetInfo.ChainTriggerID);
		end
	end
	
	ad:Wait(-1);
	local endID = ad:EndSpecialScene();
	
	local missionEnded = false;
	if IsClient() then
		missionEnded = ad:GetConfig('ActionId') == GetSession().last_ability_id;
	end
	
	if ability.Type == 'Attack' and not ad:GetConfig('NoVoice') and not ad:GetConfig('Preemptive') and not missionEnded then
		local lastID = ProcessAbilityDamageFeedback(ad, userInfo, endID);
		return ProcessAbilityAttackVoice(ad, userInfo, primaryTargetInfos, secondaryTargetInfos, lastID);
	else
		return endID;
	end
end

function ProcessAbilityAttackVoice(ad, userInfo, primaryTargetInfos, secondaryTargetInfos, refID)
-- http://wk.dl.com/issues/427 참고

	-- 음성 연출 추가용 함수
	local AddVoiceProcessFunc = function(obj, voiceKey, camMoveOffset, voiceRefID, sleepTime)
		if ad:GetConfig('QuietMode') then
			return voiceRefID;
		end	
		if not IsObjectInSight(obj) then
			return voiceRefID;
		end
		local objKey = GetObjKey(obj);
		local voiceSound, voiceSoundVolume, voiceOffset, voiceText = GetObjectVoiceSound(obj, voiceKey);
		if voiceSound == nil then
			return voiceRefID;
		end
		local nextRefID = nil;
		local sleepID = ad:Sleep(sleepTime + voiceOffset);
		ad:Connect(sleepID, voiceRefID, -1);
		if voiceSound ~= 'None' and TestCharacterVoiceTextFrequency() then
			local voiceID = nil;
			if GetRelationWithPlayer(obj) == 'Team' then
				voiceID = ad:PlaySound(voiceSound, 'Voice', voiceSoundVolume, true);
			else
				voiceID = ad:PlaySound3D(voiceSound, objKey, '_CENTER_', 3000, 'Voice', voiceSoundVolume or 1.0, true);				
			end
			ad:Connect(voiceID, sleepID, -1);
			nextRefID = voiceID;
			if voiceText and voiceText ~= 'None' then
				local textID = ad:UpdateCharacterVoiceText(voiceText, objKey);
				ad:Connect(textID, voiceID, 0);
			end
		end
		nextRefID = voiceRefID;
		return nextRefID;
	end;
	
	-- 피격 상황 파악
	local isUserPlayerTeam = GetRelationWithPlayer(userInfo.User) == 'Team';
	local doVoice = isUserPlayerTeam;
	
	
	local criticalExist = false;
	local normalExist = false;
	local hitExist = false;
	local deadExist = false;
	local dodgeExist = false;
	local blockExist = false;
	
	local isAllDodge = true;
	local isAllBlock = true;
	local isAllDead = true;
	local isAllCritical = true;
	
	local isTargetObject = true;
	local HitStateTester = function (infoList)
		for i, info in ipairs(infoList) do
			doVoice = doVoice or GetRelationWithPlayer(info.Target) == 'Team';
			local isEffectiveTarget = false;
			if info.DefenderState ~= 'Heal' then
				isEffectiveTarget = (GetRelation(userInfo.User, info.Target) == 'Enemy');
			else
				isEffectiveTarget = (GetRelation(userInfo.User, info.Target) ~= 'Enemy');
			end
			if IsDandyCrafter() then
				isEffectiveTarget = true;
			end
			
			if IsObjectInSight(info.Target) and isEffectiveTarget then
				-- 모두 회피 체크				
				if info.IsDead then
					deadExist = true;
					isAllDodge = false;
					isAllBlock = false;
				elseif info.DefenderState == 'Block' then
					blockExist = true;
					isAllDodge = false;
					isAllDead = false;
				elseif info.DefenderState == 'Dodge' then
					dodgeExist = true;
					isAllBlock = false;
					isAllDead = false;
				else
					hitExist = true;
					isAllDodge = false;
					isAllBlock = false;
					isAllDead = false;
				end
				-- 공격자 조건.
				if info.AttackerState == 'Critical' then
					criticalExist = true;
				else
					normalExist = true;
					isAllCritical = false;
				end
			end
			
			if SafeIndex(info, 'Target', 'Race', 'name') ~= 'Object' then
				isTargetObject = false;
			end
			if info.IsDead and info.Target == userInfo.User then
				userInfo.IsDead = true;
			end
		end
	end;
	HitStateTester(primaryTargetInfos);
	HitStateTester(secondaryTargetInfos);
	
	-- 공격자 음성 선택
	local attackerVoiceKey = nil;
	if isAllDead then -- 모두 사망
		if isAllCritical then
			attackerVoiceKey = 'Kill_Critical';
		else
			attackerVoiceKey = 'Kill_Normal';
		end
	elseif isAllCritical and not dodgeExist and not blockExist then -- 크리티컬 공격.
		attackerVoiceKey = 'Attack_CriticalHit';
	elseif dodgeExist and isAllDodge then -- 모두 회피
		attackerVoiceKey = 'Attack_Miss';
	elseif blockExist and isAllBlock then -- 모두 블럭
		attackerVoiceKey = 'Attack_Fail';
	elseif ( blockExist or dodgeExist ) and not hitExist then -- 회피 블럭 혼재.
		attackerVoiceKey = 'Attack_Miss';
	else
		attackerVoiceKey = nil;
	end

	if userInfo.IsDead then	--- 아이고 공격하다 죽었습니다..
		attackerVoiceKey = nil;
	end
	
	if not isUserPlayerTeam then
		if RandomTest(50) then
			attackerVoiceKey = nil;
		end
	end
	if isTargetObject then
		attackerVoiceKey = nil;
	end
	-- 공격자 음성 재생
	local voiceRefID = refID;
	if attackerVoiceKey then
		LogAndPrint(userInfo.User, attackerVoiceKey)
		local nextVoiceRefID = AddVoiceProcessFunc(userInfo.User, attackerVoiceKey, 0.05, voiceRefID, 0.25);
		if voiceRefID ~= nextVoiceRefID then
			voiceRefID = nextVoiceRefID;
		end
	end
	
	-- 피격자 음성 재생
	if #primaryTargetInfos + #secondaryTargetInfos == 1 then
		local DefenderVoiceProcesser = function(infoList)
			for i, info in ipairs(infoList) do
				local defenderVoiceKey = nil;
				if info.IsDead then
					defenderVoiceKey = nil;
				elseif info.DefenderState == 'Hit' and criticalExist then 
					defenderVoiceKey = 'Damage';
				elseif info.DefenderState == 'Block' then
					defenderVoiceKey = 'Defence';
				elseif info.DefenderState == 'Dodge' then
					defenderVoiceKey = 'Enemy_Miss';
				end
				
				if defenderVoiceKey then
					if attackerVoiceKey == nil then
						AddVoiceProcessFunc(info.Target, defenderVoiceKey, 0.05, voiceRefID, 0.25);
					end
				end
			end
		end;
		DefenderVoiceProcesser(primaryTargetInfos);
		DefenderVoiceProcesser(secondaryTargetInfos);
	end	
	return ad:Wait(voiceRefID);
end

function ProcessAbilityDamageFeedback(ad, userInfo, mainAniID)
	if userInfo.Heal <= 0 and userInfo.SubDamage <= 0 then
		return mainAniID;
	end
	ad:Wait(mainAniID);
	local objKey = GetObjKey(userInfo.User);
	
	local camMove = ad:ChangeCameraTarget(objKey, '_SYSTEM_', false);
	ad:Connect(camMove, mainAniID, -1);
	
	local connectID = camMove;
	local offset = -1;
	
	local skipAmount = 0;
	-- 흡혈 처리
	if userInfo.Heal > 0 then
		local mhp = userInfo.User.MaxHP;
		local statusWin = GetAttachingWindow(userInfo.User, 'Status');
		local curHP = tonumber(statusWin:getChild('HP'):getText());	-- 달리 캐릭터의 현재 체력상태를 얻어올 방법이 마땅치 않음.. ㅠ
		local healAmount = userInfo.Heal;
		local possibleHealAmount = mhp - curHP;
		if possibleHealAmount < healAmount then
			skipAmount = healAmount - possibleHealAmount;
			healAmount = possibleHealAmount;
		end
		if healAmount >  0 then
			connectID = DirectDamageByType(ad, userInfo.User, 'HPDrain', -healAmount, curHP + healAmount, false, false, connectID, offset);
			offset = 1;
		end
	end
	-- 반사 데미지 처리
	if userInfo.SubDamage - skipAmount > 0 then
		connectID = DirectDamageByType(ad, userInfo.User, 'DamageReflection', userInfo.SubDamage - skipAmount, userInfo.RemainHP, false, userInfo.IsDead, connectID, offset);
	end
	local sleepID = ad:Sleep(1);
	ad:Connect(sleepID, connectID, 0);
	return ad:Wait(sleepID);
end

------------------ External AbilityDirect ----------------------------
function PLAY_Move(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	
	local user = GetObjKey(userInfo.User);

	-- 이동 위치에 이동 어빌리티 0.5초간 재생
	local usingPosList = userInfo.UsingPosList;
	local lastUsingPos = usingPosList[#usingPosList];
	local maxMoveDist = userInfo.MaxMoveDist;
	local priorMoveDist = userInfo.PriorMoveDist;
	local movePath, moveDist = GetMovePath(userInfo.User, usingPosList, maxMoveDist, priorMoveDist);
	local isJump = IsEnableJump(movePath);
	
	local isMoveCamera = false;
	local moveAniSpeed = 1;
	if GetRelationWithPlayer(userInfo.User) == 'Team' 
		and not isJump 
		and userInfo.IsDash 
		and userInfo.User.Shape.EnableMoveCamera 
		and (not GetOption().Gameplay.DisableRushCam and not GetOption().Gameplay.DisableTurnCam)
		and IsMissionMode() and not GetRootLayout('BattleMain', false):getUserData('IsNextTurnMyTeam') then
		isMoveCamera = true;
	end
	local forceAni = '';
	if moveDist >= userInfo.User.Shape.RushDistance then
		moveAniSpeed = userInfo.User.Shape.MoveCameraAniSpeed;
		forceAni = 'Rush';
	end
	
	local camMove = nil;
	if TestMoveFollowCamera({TargetKey = GetObjKey(userInfo.User)}) then
		camMove = ad:ChangeCameraTarget(user, '_SYSTEM_', false, false, 0.5);
	else
		camMove = ad:Sleep(0);
	end
	-- UI 숨김 처리
	if isMoveCamera then
		ad:SetConfig('HideUI', true);
		ad:Connect(ad:BattleUIControl(false), camMove, 0);
	end
	
	local firstPath = movePath[2];
	if firstPath then
		ad:Connect(ad:LookPos(user, firstPath, false, false), camMove, 0);
	end

	local mainMove = ad:MovePath(user, usingPosList, false, maxMoveDist, priorMoveDist, moveAniSpeed, nil, nil, nil, forceAni);
	local hideCover = ad:HideCoverStateIcon(user);
	
	ad:NewDirectingThread();
	local moveDelay = nil;
	if GetRelationWithPlayer(userInfo.User) == 'Team' then
		local movePointVisualizer = ad:PlayParticlePosition('Particles/Dandylion/Selection_Position', lastUsingPos.x, lastUsingPos.y, lastUsingPos.z, 1, true);
		moveDelay = ad:Wait(movePointVisualizer, 0.25);
	end
	-- 이동 시
	local voiceSound, voiceSoundVolume, _, voiceText = GetObjectVoiceSound(userInfo.User, 'Move');
	if voiceSound ~= nil and voiceSound ~= 'None' and IsObjectInSight(userInfo.User) and TestCharacterVoiceTextFrequency() then
		local voice = nil;
		if GetRelationWithPlayer(userInfo.User) == 'Team' then
			voice = ad:PlaySound(voiceSound, 'Voice', voiceSoundVolume, true);
		else
			voice = ad:PlaySound3D(voiceSound, user, '_CENTER_', 3000, 'Voice', voiceSoundVolume or 1.0, true);
		end
		if moveDelay then
			ad:Connect(voice, moveDelay, 0);
		else
			ad:Connect(voice, mainMove, 0);
		end
		if voiceText and voiceText ~= 'None' then
			local textID = ad:UpdateCharacterVoiceText(voiceText, user);
			ad:Connect(textID, voice, 0);
		end
	end
	if moveDelay then
		ad:Connect(camMove, moveDelay, -1);
		ad:Connect(hideCover, moveDelay, -1);
	end
	if GetRelationWithPlayer(userInfo.User) == 'Team' and not isMoveCamera then
		ad:Connect(mainMove, camMove, -1);
	end
	
	local jumpCamKey = '_SYSTEM_';
	local mainCamKey = '_SYSTEM_';
	local startCamRelease = false;
	if isMoveCamera then
		local moveCameraKey = userInfo.User.Shape.MoveCamera;
		if RandomTest(50) then
			moveCameraKey = moveCameraKey..'_Right';
		else
			moveCameraKey = moveCameraKey..'_Left';
		end
		jumpCamKey = '_SYSTEM_';
		mainCamKey = moveCameraKey;
		startCamRelease = true;
		ad:StartRushMoveCamera(userInfo.User, lastUsingPos, moveCameraKey, camMove, -1, nil, 1.1);
	else
		local currentlyInSight = IsObjectInSight(userInfo.User);
		local moveCamera = nil
		if TestMoveFollowCamera({TargetKey = GetObjKey(userInfo.User)}) then
			moveCamera = ad:ChangeCameraTarget(user, '_SYSTEM_', false, false);
		else
			moveCamera = ad:Sleep(0);
		end
		if currentlyInSight then
			ad:Connect(moveCamera, camMove, -1);
			if userInfo.IsDash then
				local speedStartID = ad:ChangeSpeedFactor(1.2);
				local speedEndID = ad:ChangeSpeedFactor(1);
				ad:Connect(speedStartID, mainMove, 0);				
				local nearToDestID = ad:MakeEvent('CheckUnitArriveInRange', {TargetKey=user, CheckPos=lastUsingPos, Range= 2});
				ad:SetConditional(nearToDestID);				
				ad:Connect(speedEndID, nearToDestID, -1);
			end
		else
			local whenVisible = ad:MakeEvent('CheckUnitIsVisble', {TargetKey=user, Visible=true});
			ad:SetConditional(whenVisible);
			ad:Connect(moveCamera, whenVisible, -1);
		end
	end
	
	if TestMoveFollowCamera({TargetKey = GetObjKey(userInfo.User)}) then
		ad:RegisterMoveCameraHandler(user, mainMove, jumpCamKey, mainCamKey, mainCamKey ~= '_SYSTEM_', startCamRelease, false);
	end
	
	-- 이동 종료 --
	ad:Connect(ad:UpdateCoverStateIcon(user), mainMove, -1);
end
function PLAY_SecondMove(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_Move(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos);
end
function PLAY_ExtraMove(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_Move(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos);
end
function PLAY_StartOverwatch(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	local user = GetObjKey(userInfo.User);
	local mainAni = ad:PlayAni(user, ability.Animation, false);
	ad:UpdateTopIcon(user, 'OverWatch');
end
function PLAY_FlameExplosion(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	AutoSightOn(ad, userInfo.User);		-- 가장 처음에 켜줘야 할듯
	ad:Wait(ad:ChangeCameraTarget(GetObjKey(userInfo.User), '_SYSTEM_', false, false, 0.5));

	local userKey = GetObjKey(userInfo.User);
	local sleep = ad:Sleep(2);
	local mainAniID = ad:PlayParticle(userKey, '_BOTTOM_', 'Particles/Dandylion/Grenade_Explosion_Sphere4', 4, true, false, true);
	local sound = ad:PlaySound3D('explosion.wav', userKey, '_CENTER_', 3000, 'Effect', 1.0, true);
	ad:Connect(mainAniID, sleep, 0);
	ad:Connect(sound, mainAniID, 0);
	
	local action = {};
	action.Phase = 'Primary';
	action.HitType = ability.SubType;
	action.HitMethod = 'Center';
	action.DeadMethod = 'Normal';
	action.DeadlyHitPower = 1;
	action.FinalHit = true;
	action.FirstHit = true;
	action.HitMode = 'Auto';
	action.RollType = 'None';
	action.RollPower = 1;
	local actionDB = {};
	actionDB.ImpactOrigin = GetPosition(userInfo.User);
	actionDB.Delay = 0;
	for i, targetInfo in ipairs(primaryTargetInfos) do
		action.HitResult = targetInfo.DefenderState;
		action.IsDead = targetInfo.IsDead;
		action.Damage = targetInfo.MainDamage;
		action.DamageShow = targetInfo.ShowDamage;
		local hitProcessArg = BuildHitProcessArg(action, targetInfo);
		ProcessHit(ad, {}, action, mainAniID, 0, hitProcessArg, actionDB);
	end
	ad:FireDirectingEvent(nil, 'SingularPoint', mainAniID, 0);
	AutoSightOff(ad, mainAniID, userInfo.User);		-- 가장 처음에 켜줘야 할듯
end

function PLAY_ExplosionShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, particle)
	AutoSightOn(ad, userInfo.User);		-- 가장 처음에 켜줘야 할듯
	ad:Wait(ad:ChangeCameraTarget(GetObjKey(userInfo.User), '_SYSTEM_', false, false, 0.5));

	local userKey = GetObjKey(userInfo.User);
	local sleep = ad:Sleep(1);
	local mainAniID = ad:PlayParticle(userKey, '_BOTTOM_', particle, 2.5, true, false, true);
	local sound = ad:PlaySound3D('explosion.wav', userKey, '_CENTER_', 3000, 'Effect', 1.0, true);
	ad:Connect(mainAniID, sleep, 0);
	ad:Connect(sound, mainAniID, 0);
	
	local action = {};
	action.Phase = 'Primary';
	action.HitType = ability.SubType;
	action.HitMethod = 'Center';
	action.DeadMethod = 'Normal';
	action.DeadlyHitPower = 1;
	action.FinalHit = true;
	action.FirstHit = true;
	action.HitMode = 'Auto';
	action.RollType = 'None';
	action.RollPower = 1;
	local actionDB = {};
	actionDB.ImpactOrigin = GetPosition(userInfo.User);
	actionDB.Delay = 0;
	for i, targetInfo in ipairs(primaryTargetInfos) do
		action.HitResult = targetInfo.DefenderState;
		action.IsDead = targetInfo.IsDead;
		action.Damage = targetInfo.MainDamage;
		action.DamageShow = targetInfo.ShowDamage;
		local hitProcessArg = BuildHitProcessArg(action, targetInfo);
		ProcessHit(ad, {}, action, mainAniID, 0, hitProcessArg, actionDB);
	end
	AutoSightOff(ad, mainAniID, userInfo.User);		-- 가장 처음에 켜줘야 할듯
end
function PLAY_FlameExplosion_Small(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_ExplosionShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, 'Particles/Dandylion/Grenade_Explosion');
end
function PLAY_FrostExplosion_Small(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_ExplosionShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, 'Particles/Dandylion/Grenade_Explosion_Ice');
end
function PLAY_LightningExplosion_Small(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_ExplosionShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, 'Particles/Dandylion/Spark_Lightning');
end
function PLAY_ToxicLeakageShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, particle)
	ad:Wait(ad:ChangeCameraTarget(GetObjKey(userInfo.User), '_SYSTEM_', false));

	local userKey = GetObjKey(userInfo.User);
	local mainAniID = ad:PlayParticle(userKey, '_BOTTOM_', particle, 2.5);
	local sound = ad:PlaySound3D('HitEffect/HIt_Granade_Smoke.ogg', userKey, '_CENTER_', 3000, 'Effect', 1.0, true);
	ad:Connect(sound, mainAniID, 0);
end
function PLAY_ToxicLeakage(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_ToxicLeakageShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, 'Particles/Dandylion/Grenade_Explosion_Gas');
end
function PLAY_ToxicLeakage_IceSac(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_ToxicLeakageShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, 'Particles/Dandylion/Grenade_Explosion_Ice');
end
function PLAY_ToxicLeakage_LightningSac(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_ToxicLeakageShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, 'Particles/Dandylion/Grenade_Explosion_Lightning');
end
function PLAY_ToxicLeakage_VenomSac(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_ToxicLeakageShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, 'Particles/Dandylion/Grenade_Explosion_Gas');
end
function PLAY_ToxicLeakage_Small(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_ToxicLeakageShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, 'Particles/Dandylion/Grenade_Explosion_Gas');
end
function PLAY_ToxicLeakage_WebSac(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	PLAY_ToxicLeakageShared(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, 'Particles/Dandylion/Grenade_Explosion_Ice');
end
function PLAY_RestoreHP(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	for i, info in ipairs(primaryTargetInfos) do
		DirectDamageByTypeWithState(ad, info.Target, 'HPRestore', info.MainDamage, info.RemainHP, info.AttackerState, 'Heal', true, false);
	end
end
function PLAY_Potion_AntiFreezingInfusionSolution(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	ad:UpdateBattleEvent(GetObjKey(userInfo.User), 'AbilityInvoked', {Ability = ability.name});
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.5);
	end
end
function PLAY_RestoreCost(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	for i, info in ipairs(primaryTargetInfos) do
		local targetKey = GetObjKey(info.Target);
		local soundID = ad:PlaySound3D('Rest.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0, true);
		local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Rest', 0.5);
		ad:Connect(ad:UpdateCostDamagedGauge(targetKey, {damage = primaryTargetInfos[1].MainDamage, isFinal = true}), particleID, 0.2);
		ad:Connect(soundID, particleID, 0);
	end
end
function PLAY_Rest(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	local targetKey = GetObjKey(userInfo.User);
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local soundID = ad:PlaySound3D('Rest.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0, true);
	local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Rest', 0.5);
	ad:Connect(ad:UpdateCostDamagedGauge(targetKey, {damage = primaryTargetInfos[1].MainDamage, isFinal = true}), particleID, 0.2);
	ad:Connect(soundID, particleID, 0);
end
function Play_StandBy(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	local targetKey = GetObjKey(userInfo.User);
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Buff_Conceal_Start', 1);
	local soundID = ad:PlaySound3D('Conceal.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0, true);
	ad:Connect(soundID, particleID, 0);
end
function Play_Restoration(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	for i, info in ipairs(primaryTargetInfos) do
		DirectDamageByTypeWithState(ad, info.Target, 'HPRestore', info.MainDamage, info.RemainHP, info.AttackerState, info.DefenderState, true, false);
	end
end
function PLAY_Conceal(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if not IsObjectInSight(userInfo.User) then
		return;
	end
	local targetKey = GetObjKey(userInfo.User);
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local soundID = ad:PlaySound3D('Conceal.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0, true);
	local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Buff_Conceal_Start', 1);
	ad:Connect(soundID, particleID, 0);
end
function PLAY_DeadlyCalm(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	local targetKey = GetObjKey(userInfo.User);
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local soundID = ad:PlaySound3D('Conceal.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0);
	local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Buff_Conceal_Start', 1.5);
	ad:Connect(soundID, particleID, 0);
end
function Play_Charging(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local esp = userInfo.User.ESP;
	if esp and esp.name and esp.name ~= 'None' then
		local targetKey = GetObjKey(userInfo.User);
		local soundID = ad:PlaySound3D('Conceal.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0);
		local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Charge_'..esp.name, 2);
		ad:Connect(ad:UpdateSPDamagedGauge(targetKey, {damage = primaryTargetInfos[1].MainDamage, isFinal = true}), particleID, 0.2);
		ad:Connect(soundID, particleID, 0);
	end
end
function Play_Overwatch(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
end
function Play_ExchangeOfEquivalents(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
end
function Play_Tame(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	local targetKey = GetObjKey(userInfo.User);
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	ad:PlayPose(targetKey, 'TameStart', 'TameStd', false, 'TameStdIdle');
	local soundID = ad:PlaySound3D('Conceal.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0);
	local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Buff_Conceal_Start', 1.5);
	ad:Connect(soundID, particleID, 0);
end
function PLAY_RecoverEnergy(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	local targetKey = GetObjKey(userInfo.User);
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local soundID = ad:PlaySound3D('Conceal.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0);
	local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Buff_Conceal_Start', 1.5);
	ad:Connect(soundID, particleID, 0);
end
function Play_Death(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	local targetKey = GetObjKey(userInfo.User);
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local soundID = ad:PlaySound3D('Conceal.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0);
	local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Buff_Conceal_Start', 1.5);
	ad:Connect(soundID, particleID, 0);
end
function Play_Comport(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	for i, info in ipairs(primaryTargetInfos) do
		local targetKey = GetObjKey(info.Target);
		local soundID = ad:PlaySound3D('HitEffect/Hit_Heal_Hit.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0);
		local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Comport', 3);
	end
end
function Play_Repair(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	for i, info in ipairs(primaryTargetInfos) do
		local targetKey = GetObjKey(info.Target);
		local soundID = ad:PlaySound3D('HitEffect/Hit_Heal_Hit.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0);
		local particleID = ad:PlayParticle(targetKey, '_CENTER_', 'Particles/Dandylion/Repair', 2.5);
	end
end
function Play_Call(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)

end
function Play_Cure(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	for i, info in ipairs(primaryTargetInfos) do
		local targetKey = GetObjKey(info.Target);
		local soundID = ad:PlaySound3D('HitEffect/Hit_Heal_Hit.wav', targetKey, 'Chest', 3000, 'Effect', 1.0);
		local particleID = ad:PlayParticle(targetKey, '_CENTER_', 'Particles/Dandylion/FirstAid', 2.5);
	end
end
function Play_HackOff(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local userKey = GetObjKey(userInfo.User);
	local particleID = ad:PlayParticle(userKey, '_TOP_', 'Particles/Dandylion/Hacking', 3);
	for i, info in ipairs(primaryTargetInfos) do
		local targetKey = GetObjKey(info.Target);
		local soundID = ad:PlaySound3D('Hacking.ogg', targetKey, 'Chest', 3000, 'Effect', 3.0);
	end	
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
end
function Play_Activate_Light(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local userKey = GetObjKey(userInfo.User);
	local particleID = ad:PlayParticle(userKey, '_TOP_', 'Particles/Dandylion/Activate_Light', 1);
	local soundID = ad:PlaySound3D('click_4.wav', userKey, 'Chest', 3000, 'Effect', 2);
	ad:Connect(soundID, particleID, 0);
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
end
function Play_Deactivate_Light(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local userKey = GetObjKey(userInfo.User);
	local particleID = ad:PlayParticle(userKey, '_TOP_', 'Particles/Dandylion/Activate_Light', 1);
	local soundID = ad:PlaySound3D('click_3.wav', userKey, 'Chest', 3000, 'Effect', 2);
	ad:Connect(soundID, particleID, 0);
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
end
function Play_InvestigatePsionicStone(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)
	-- 이능석 연출
end
function Play_InvestigateChest(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)

end
function Play_Release(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos)

end
function Play_ThrowGrenade(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local user = userInfo.User;
	if user.Shape.name == 'GrenadeMaster' or user.Shape.name == 'ShakingSpray' then
		PlayAbilityDirect(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
	else
		if user.Shape.ThrowFrame == 0 and user.Shape.ThrowFromPos == 'None' then
			return;
		end
		local animationInfoList = GetClassList('ObjectAnimationInfo');
		local animationInfo = animationInfoList['GrenadeMaster'];
		if animationInfo == nil then
			LogAndPrint(string.format('ObjectAnimationInfo GrenadeMaster is nil'));
			return;
		end
		local abilityAnimationInfo = animationInfo.Abilities[ability.name];
		abilityAnimationInfo = ClassToTable(abilityAnimationInfo);
		abilityAnimationInfo.Actions.ForceRange[1].Frame = user.Shape.ThrowFrame;
		abilityAnimationInfo.Actions.ForceRange[1].FromPos = user.Shape.ThrowFromPos;

		PlayAbilityDirect(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
	end
end
function Play_ThrowGrenade_NoDamageShow(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	-- FlashBangGrenade(섬광탄)은 데미지가 없는 어빌리티이지만 Hit 연출이 필요해서 데미지 표시를 끈다.
	ad:SetConfig('NoDamageShow', true);
	-- FlashBangGrenade(섬광탄)은 데미지가 없는 어빌리티이지만 Hit 연출이 필요해서 방어 상태를 Hit으로 강제로 바꿔준다.
	for i, targetInfo in ipairs(primaryTargetInfos) do
		if targetInfo.DefenderState == 'None' then
			targetInfo.DefenderState = 'Hit';
		end
	end
	Play_ThrowGrenade(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
end
function Play_Agency_GrenadeMaster(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local user = userInfo.User;
	if user.Shape.name == 'GrenadeMaster' or user.Shape.name == 'ShakingSpray' then
		PlayAbilityDirect(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
	else
		local animationInfoList = GetClassList('ObjectAnimationInfo');
		local animationInfo = animationInfoList['GrenadeMaster'];
		if animationInfo == nil then
			LogAndPrint(string.format('ObjectAnimationInfo GrenadeMaster is nil'));
			return;
		end
		local abilityAnimationInfo = animationInfo.Abilities[ability.name];
		PlayAbilityDirect(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
	end
end
function Play_Arrest(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	
end
function Play_SummonMachine(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	
end
function Play_UnsummonMachine(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	
end
function Play_WindAura_Disable(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local user = userInfo.User;
	ad:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = ability.name });
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
end
function Play_MagicOuterArmor_Disable(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local user = userInfo.User;
	ad:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = ability.name });
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
end
function Play_MagicAcceleration_Disable(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local user = userInfo.User;
	ad:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = ability.name });
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
end
function Play_FrostMane_Disable(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local user = userInfo.User;
	ad:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = ability.name });
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
end
function Play_Immolation_Fire_Disable(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local user = userInfo.User;
	ad:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = ability.name });
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
end
function Play_Immolation_Ice_Disable(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local user = userInfo.User;
	ad:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = ability.name });
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
end
function Play_Petrifactionn(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local user = userInfo.User;
	ad:ChangeMaterial(GetObjKey(user), '_Stone', true);
end
function Play_SummonBeast(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local usingPos = userInfo.UsingPos;
	usingPos = {x = usingPos.x, y = usingPos.y, z = usingPos.z};
	local up = GetNearestOccupiablePos(usingPos, true, false) or usingPos;
	
	local ani = ad:PlayAni(GetObjKey(userInfo.User), ability.Animation, false);
	local spawn = ad:Move(GetObjKey(userInfo.Target), up, true);
	ad:Connect(spawn, ani, 1.8);
	ad:Connect(ad:Move(GetObjKey(userInfo.Target), usingPos, false), spawn, -1);
end
function Play_UnsummonBeast(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local usingPos = userInfo.UsingPos;
	usingPos = {x = usingPos.x, y = usingPos.y, z = usingPos.z};
	local up = GetNearestOccupiablePos(usingPos, true, true) or usingPos;
	
	local ani = ad:PlayAni(GetObjKey(userInfo.User), ability.Animation, false);
	local move = ad:Move(GetObjKey(userInfo.Target), up, false);
	ad:Connect(move, ani, 1.8);
	ad:Connect(ad:Move(GetObjKey(userInfo.Target), InvalidPosition(), true), move, 1);
end
function Play_SearchProtocol(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	-- 어빌리티 디렉터 연출 적용
	local retID = PlayAbilityDirect(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
	
	-- 어빌리티 연출 끝날 때 UpdateBattleEvent 연출 적용
	local targetCount = table.count(primaryTargetInfos, function(targetInfo)
		return targetInfo.Target ~= userInfo.User;
	end);
	local objKey = GetObjKey(userInfo.User);
	local eventName, eventArgs;	
	if targetCount > 0 then
		eventName = 'SearchProtocolSucceeded';
		eventArgs = { Count = targetCount };
	else
		eventName = 'SearchProtocolFailed';
		eventArgs = {};
	end
	local msgID = ad:UpdateBattleEvent(objKey, eventName, eventArgs);
	ad:Connect(msgID, retID, -1);
	ad:Connect(ad:Sleep(1.0), msgID, 0);
	
	return retID;
end
function Play_HackingProtocol(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local protocolCls = GetClassList('HackingProtocol')[userInfo.ProtocolDetail];
	if protocolCls == nil then
		return;
	end
	local commandAbility = GetAbilityObject(self, protocolCls.Ability.name) or protocolCls.Ability;
	return PlayAbilityDirect(ad, commandAbility, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
end
function Play_AttackProtocol(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local protocolCls = GetClassList('AttackProtocol')[userInfo.ProtocolDetail];
	if protocolCls == nil then
		return;
	end
	local commandAbility = GetAbilityObject(self, protocolCls.Ability.name) or protocolCls.Ability;
	return PlayAbilityDirect(ad, commandAbility, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
end
function Play_AssistProtocol(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local protocolCls = GetClassList('AssistProtocol')[userInfo.ProtocolDetail];
	if protocolCls == nil then
		return;
	end
	local commandAbility = GetAbilityObject(self, protocolCls.Ability.name) or protocolCls.Ability;
	return PlayAbilityDirect(ad, commandAbility, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
end
function Play_EnhancedAttackProtocol(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	local protocolCls = GetClassList('EnhancedAttackProtocol')[userInfo.ProtocolDetail];
	if protocolCls == nil then
		return;
	end
	local commandAbility = GetAbilityObject(self, protocolCls.Ability.name) or protocolCls.Ability;
	return PlayAbilityDirect(ad, commandAbility, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo);
end
function Play_RemoveStickyWeb(ad, ability, userInfo, primaryTargetInfos, secondaryTargetInfos, abilityAnimationInfo)
	if IsObjectInSight(userInfo.User) then
		ad:Sleep(0.1);
	end
	local user = userInfo.User;
	ad:UpdateBattleEvent(GetObjKey(user), 'AbilityInvoked', { Ability = ability.name });
	for i, info in ipairs(primaryTargetInfos) do
		local targetKey = GetObjKey(info.Target);
		ad:PlayAni(targetKey, 'AstdIdle', false);
		local soundID = ad:PlaySound3D('Conceal.wav', targetKey, '_CENTER_', 3000, 'Effect', 1.0);
		local particleID = ad:PlayParticle(targetKey, '_BOTTOM_', 'Particles/Dandylion/Buff_Conceal_Start', 1.5);
	end
end
----------------------------------------- AbilityDirect Check&Get Data Utility  -----------------------------------------------
function IsAttackType(actionType)
	return actionType == 'Hit' or actionType == 'ForceHit' or actionType == 'ChainForceHit' or actionType == 'Heal';
end
function CheckStateFilter(filter, actionInfo)
	local filterCls = GetClassList('StateFilter')[filter];
	for _, banDS in ipairs(filterCls.BanDefenderState) do
		if banDS == actionInfo.DefenderState then
			return false;
		end
	end
	
	for _, banAS in ipairs(filterCls.BanAttackerState) do
		if banAS == actionInfo.AttackerState then
			return false;
		end
	end
	
	return true;
end

function CheckAdd(phase, action, usingInfo, actionIndex)
	-- phase check
	local actionPhase = 'Base';	-- default
	if IsAttackType(action.Type) then
		actionPhase = 'Primary';	-- Hit과 ForceHit은 기본값이 Primary
	end
	
	if action.Phase ~= nil then
		actionPhase = action.Phase;
	end
	if phase ~= actionPhase then
		return false;
	end
	
	if phase == 'Base' and IsAttackType(action.Type) then
		local tableString = '{';
		table.print(action, function(msg) tableString = tableString..' '..msg end);
		tableString = tableString .. '}';
		LogAndPrint('Exist - Set BasePhase Attack -', tableString);
		return false;	-- Base페이즈는 공격액션은 사용 불가!
	end
		
	local stateFilter = 'All';
	if action.StateFilter ~= nil then
		stateFilter = action.StateFilter;
	end
	for i, filterType in ipairs(string.split(stateFilter, '[, ]')) do
		if filterType ~= 'All' and not CheckStateFilter(filterType, usingInfo) then
			---LogAndPrint('Failed', filterType);
			return false;
		end
	end
	
	-- 아래의 필터체크는 Base페이즈는 생략한다
	if phase == 'Base' then
		return true;
	end

	-- filter check
	local filterList = 'All';	-- default
	if action.RangeFilter ~= nil then
		filterList = action.RangeFilter;
	end
	for i, filterType in ipairs(string.split(filterList, '[, ]')) do
		if not CheckFilter(filterType, usingInfo.User, usingInfo.Target, actionIndex, usingInfo.RepeatIndex) then
			--LogAndPrint('Fail CheckAdd Filter');
			return false;
		end
	end
	--LogAndPrint("Clear CheckAdd : ".. action.Type .. ', phase: ' .. phase);
	return true;
end
function CheckUnitArrivePosition(obj, handlerArg, eventArg)
	if IsSamePosition(eventArg.Position, handlerArg.CheckPos) then
		return true, true;
	elseif eventArg.Ended then
		return true, true;
	end
	return false;
end
function CheckUnitArriveInRange(arg)
	local target = GetObjectByKey(arg.TargetKey)
	if not target then
		return true;
	end
	
	local modelPos = GetModelPosition(target, true);	-- offset까지 받는다
	if GetDistance3D(arg.CheckPos, modelPos) < arg.Range then
		return true;
	end
end
function CheckUnitFreeWithUIEffect(arg)
	local target = GetObjectByKey(arg.TargetKey);
	if target == nil then
		return true;
	end
	local cnt = GetAttachingUIEffectCount(target);
	return cnt == 0;
end
function CheckUnitIsVisble(arg)
	local target = GetObjectByKey(arg.TargetKey);
	if not target then
		return true;
	end
	
	return IsObjectInSight(target);
end
function OnStateChangedDead(obj, handlerArg, eventArg)
	return eventArg.State == 'Dead', true;
end
function OnJumpStartCamCheck(obj, handlerArg, eventArg)
	-- 일단은 점프하면 무조건 OK로 하자
	LogAndPrint("OnJumpStartCamCheck");
	return true, false;
	--[[
	if GetTeam(obj) == 'player' and eventArg.Height > 150 then
		return true;
	else
		return false;
	end
	]]
end
function OnMoveStartCheck(obj, handlerArg, eventArg)
	LogAndPrint('OnMoveStartCheck', 'handled');
	return eventArg.State == 'Move' or eventArg.State == 'Knockback', true;
end
function OnJumpEndCamCheck(obj, handlerArg, eventArg)
	return true, false;
end
function IsEnableTrigger(ad, usingInfo)
	--[[return GetRelationWithPlayer(usingInfo.User) == 'Team'
			or GetRelationWithPlayer(usingInfo.Target) == 'Team';]]
	return not (ad:GetConfig('NoCamera') or ad:GetConfig('SystemCamera'));
end
function OnShownUnit(obj, handlerArg, eventArg)
	if eventArg.Visible then
		return true, false;
	end
	return false, false;
end
