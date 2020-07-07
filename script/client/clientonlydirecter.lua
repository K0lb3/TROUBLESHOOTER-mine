function ClientDirecting_OnCharacterDead(cds, dead, killer)
	local msg = 'Dead';
	if dead.Obstacle then
		msg = msg..'_Obstacle';
	end
	local rel = GetRelationWithPlayer(dead);
	if rel == 'Team' then
		if not dead.Obstacle then
			cds:ShowFrontmessage(string.format(GuideMessage('FrontMessageUnitDead'), dead.Info.Title), 'Corn');
		end
		cds:AddMissionChat('PlayerDead', msg, { Name = dead.Info.Title, ObjectKey = GetObjKey(dead) });
	elseif rel == 'Enemy' then
		cds:AddMissionChat('EnemyDead', msg, { Name = dead.Info.Title, ObjectKey = GetObjKey(dead) });
	else
		cds:AddMissionChat('OtherDead', msg, { Name = dead.Info.Title, ObjectKey = GetObjKey(dead) });
	end	
	
	CheckSteamAchievement_OnCharacterDead(cds, dead, killer);
end

function ClientDirecting_OnCharacterResurrect(cds, resurrected, mode)
	if mode == 'system' or mode == 'direct' then
		return;
	end
	cds:ShowFrontmessage(string.format(GuideMessage('FrontMessageUnitResurrect_' .. (mode or 'Normal')), resurrected.Info.Title), 'Corn');
end

function ClientDirecting_OnCharacterLevelUp(cds, target, curLv, nextLv)
	-- 미션 승리 액션이 처리된 후에는 연출 완전 생략
	local session = GetSession();
	if session.winner ~= nil then
		return;
	end
	local pos = GetPosition(target);
	local targetJob = '';
	local targetESP = '';
	if target.Job and target.Job.name then
		targetJob = target.Job.name;
	end
	if target.ESP and target.ESP.name then
		targetESP = target.ESP.name;
	end	

	if IsMission() then
		cds:ChangeCameraPosition(pos.x, pos.y, pos.z, false, 1);	
	end
	
	cds:AddMissionChat('LevelUp', 'LevelUp',  { Name = target.Info.Title, Level = nextLv, Team = GetTeam(target) });
	if not IsMission() or GetFSMState(target) ~= 'Dead' then
		cds:PlayParticle(GetObjKey(target), '_BOTTOM_', GetSystemConstant('LevelUpEffect'), 2, false, false);
		if GetOption().Gameplay.SimpleLevelUp then
			cds:ShowFrontmessage(FormatMessage(GuideMessage('LevelUp'), {Name = target.Info.Title, Level = nextLv}), 'Corn');
		else
			cds:ShowLevelUp(GetObjKey(target), GetTeam(target), target.Info.Title, curLv, nextLv, targetJob, targetESP);
		end
	else
		cds:ShowFrontmessage(FormatMessage(GuideMessage('LevelUp'), {Name = target.Info.Title, Level = nextLv}), 'Corn');
	end
end

function ClientDirecting_OnCharacterJobLevelUp(cds, target, curLv, nextLv)
	-- 미션 승리 액션이 처리된 후에는 연출 완전 생략
	local session = GetSession();
	if session.winner ~= nil then
		-- 스팀 업적 처리는 적용
		if IsSteamInitialized() and not HasSteamAchievement('SituationClassLv16') and nextLv >= 16 then
			cds:UpdateSteamAchievement('SituationClassLv16', true);
		end
		return;
	end
	local pos = GetPosition(target);
	
	if IsMission() then
		cds:ChangeCameraPosition(pos.x, pos.y, pos.z, false, 1);	
	end	

	cds:AddMissionChat('LevelUp', 'JobLevelUp',  { Name = target.Info.Title, Level = nextLv, Team = GetTeam(target) });
	if not IsMission() or GetFSMState(target) ~= 'Dead' then
		cds:PlayParticle(GetObjKey(target), '_BOTTOM_', GetSystemConstant('LevelUpEffectJob'), 2, false, false, true);
		cds:PlayUIEffect(GetObjKey(target), '', 'JobLevelUp', 0, 0, PackTableToString({Level = nextLv, Job = target.Job.name, AliveOnly = true}));
	end
	
	if IsSteamInitialized() and not HasSteamAchievement('SituationClassLv16') and nextLv >= 16 then
		cds:UpdateSteamAchievement('SituationClassLv16', true);
	end
	
	if IsMission() then
		local session = GetSession();
		local company = session.company_info;
		local rosters = session.rosters;
		local pcInfo = GetPcInfo(target, rosters);
		if pcInfo then
			local rewardMasteries = {};
			if pcInfo.RosterType == 'Pc' then
				rewardMasteries = GetRewardMasteriesByJobLevel(company, pcInfo, target.Job.name, curLv + 1, nextLv, true);
			elseif pcInfo.RosterType == 'Beast' then
				rewardMasteries = GetRewardMasteriesByJobLevel_Beast(company, pcInfo, curLv + 1, nextLv, true);
			elseif pcInfo.RosterType == 'Machine' then
				rewardMasteries = GetRewardMasteriesByJobLevel_Machine(company, pcInfo, curLv + 1, nextLv, nil, true);
			end
			for _, mastery in ipairs(rewardMasteries) do
				local masteryTitle = GetStringFontColorChangeTagWithColorKey('White', mastery.Title, 'Corn');
				local messageType = 'JobLevelUp_RewardMastery';
				if company.Technique[mastery.name].Opened then
					messageType = 'JobLevelUp_RewardMastery_Already';
				end
				cds:ShowFrontmessage(FormatMessage(GuideMessage(messageType), {MasteryName = masteryTitle}), 'Corn');
			end
		end
	end
end

function ClientDirecting_OnAcquireMastery(cds, team, mastery, count, guide, invoker)
	-- 미션 승리 액션이 처리된 후에는 연출 완전 생략
	local session = GetSession();
	if session.winner ~= nil then
		return;
	end
	local connectID = nil;
	if invoker and not GetOption().Gameplay.SimpleMasteryAchievement then
		connectID = cds:MakeEvent('CheckUnitFreeWithUIEffect', {TargetKey = invoker});
	end
	local show = cds:ShowAcquireMasteryInfo(team, mastery, guide);
	local chat = cds:AddMissionChat('GiveMastery', 'GiveMastery', { MasteryType = mastery, MasteryCount = count, Team = team });
	if connectID then
		cds:Connect(show, connectID, -1);
		cds:Connect(chat, connectID, -1);
	end
end

function ClientDirecting_SteamAchievement(cds, achievement)
	if HasSteamAchievement(achievement) then
		return;
	end
	cds:UpdateSteamAchievement(achievement, true);
end

function ClientDirecting_OnItemGet(cds, receiver, item, count, itemProperties, giveItemArgs)
	if GetRelationWithPlayer(receiver) ~= 'Team' then
		return;
	end
	-- 미션 승리 액션이 처리된 후에는 연출 완전 생략
	local session = GetSession();
	if session.winner ~= nil then
		-- 등가 교환 스팀 스탯 증가는 적용
		local message = SafeIndex(giveItemArgs, 'message');
		if message == 'GiveItemExchangeOfEquivalents' and SafeIndex(giveItemArgs, 'original_item') then
			cds:AddSteamStat('ExchangeOfEquivalentsCount', 1);
		end	
		return;
	end
	local message = SafeIndex(giveItemArgs, 'message') or 'GiveItem';
	local chatArgs = { ItemType = item, ItemCount = count, Team = GetTeam(receiver), ItemProperties = itemProperties};
	if SafeIndex(giveItemArgs, 'original_item') then
		chatArgs.ItemType2 = giveItemArgs.original_item;
		chatArgs.ItemCount2 = giveItemArgs.original_amount;
		chatArgs.ItemProperties2 = giveItemArgs.original_properties;
		
		local giveItemChatCategory = GetClassList('ChatSubCategory').GiveItem;
		local formatTable = giveItemChatCategory:FormatTableMaker(message, chatArgs);
		
		cds:ChangeCameraTarget(GetObjKey(receiver), '_SYSTEM_', false);
		cds:ShowFrontmessageWithText(FormatMessageText(RawText(giveItemChatCategory.Message), formatTable));
		cds:UpdateBattleEvent(GetObjKey(receiver), 'BuffInvoked', {Buff = 'ExchangeOfEquivalents', EventType='FirstHit'});
		if message == 'GiveItemExchangeOfEquivalents' then
			cds:AddSteamStat('ExchangeOfEquivalentsCount', 1);
		end
	end
	cds:AddMissionChat('GiveItem', message, chatArgs);
end

function ClientDirecting_OnBuffAdded(cds, target, buffName, lv, giver)
	local buffCls = GetClassList('Buff')[buffName];
	if buffCls.Type == 'System' then
		return;
	end
	local buffKey = 'Buff';
	if buffCls.Type == 'Debuff' then
		buffKey = 'Debuff';
	end
	local msg = 'BuffAdded';
	if buffCls.Stack and buffCls:MaxStack(target) > 1 then
		msg = 'BuffAddedStack'
	end
	cds:AddRelationMissionChat(buffKey, msg, { ObjectKey = GetObjKey(target), Buff = buffName, BuffLevel = lv });
	
	if IsSteamInitialized() then
		if buffName == 'Stun' and GetRelationWithPlayer(target) == 'Enemy' and giver and GetRelationWithPlayer(giver) == 'Team' then
			cds:AddSteamStat('EnemyStunCount', 1);
		end
		if buffName == 'Luck' and GetRelationWithPlayer(target) == 'Team' then
			cds:AddSteamStat('LuckCount', 1);
		end
	end
end

function ClientDirecting_OnBuffRemoved(cds, target, buffName)
	local buffCls = GetClassList('Buff')[buffName];
	if buffCls.Type == 'System' then
		return;
	end
	local buffKey = 'Buff';
	if buffCls.Type == 'Debuff' then
		buffKey = 'Debuff';
	end
	cds:AddRelationMissionChat(buffKey, 'BuffDischarged', { ObjectKey = GetObjKey(target), Buff = buffName });
end

function ClientDirecting_OnBuffLevelUp(cds, target, buffName, lv)
	local buffCls = GetClassList('Buff')[buffName];
	if buffCls.Type == 'System' then
		return;
	end
	if not buffCls.Stack or buffCls:MaxStack(target) <= 1 then
		return;
	end
	local buffKey = 'Buff';
	if buffCls.Type == 'Debuff' then
		buffKey = 'Debuff';
	end
	cds:AddRelationMissionChat(buffKey, 'BuffAddedStack', { ObjectKey = GetObjKey(target), Buff = buffName, BuffLevel = lv });
	
	if IsSteamInitialized() then
		--[[	TODO: 임시 봉인
		if buffName == 'CurseOfSword' and lv >= 99 and not HasSteamAchievement('SituationCurseOfSword') then
			cds:UpdateSteamAchievement('SituationCurseOfSword', true);
		end
		]]
	end
	
end

function ClientDirecting_BattleGuideSignal(cds, player, nearestEnemy, nearPos, guideMessage)
	local camID = cds:ChangeCameraTarget(GetObjKey(player), '_SYSTEM_', false);
	cds:PlayVoiceAndText(player, 'DetectCrackle', false, 0, camID, 0);
	local effect = cds:PlayParticlePosDir(nearPos, GetPosition(player), 'Particles/Dandylion/BattleGuideSignal', 200, 3.4, true);
	cds:Connect(effect, camID, -1);
	cds:Connect(cds:PlaySound('Alarm_Long.ogg', 'Effect', 1, true), camID, -1);
	if guideMessage ~= '' then
		cds:Connect(cds:Dialog('HelpMessageBox', { Type = guideMessage }), effect, 2.75);
	end
end

function ClientDirecting_HelpMessageBox(cds, helpType)
	cds:Dialog('HelpMessageBox', { Type = helpType });
end

function TestObjectAlive(objKey)
	local obj = GetObjectByKey(objKey);
	-- 부상 상태에서는 Dead FSM 상태가 이미 되어 있으므로 살아있는 걸로 간주함
	return (GetFSMState(obj) ~= 'Dead' or HasBuff(obj, 'InjuredRescue') or HasBuff(obj, 'InjuredRageRescue'));
end

function TestObjectDead(objKey)
	local obj = GetObjectByKey(objKey);
	return GetFSMState(obj) == 'Dead';
end

function TestObjectVisibleAndAlive(objKey)
	local obj = GetObjectByKey(objKey);
	-- 부상 상태에서는 Dead FSM 상태가 이미 되어 있으므로 살아있는 걸로 간주함
	return IsObjectInSight(obj) and (GetFSMState(obj) ~= 'Dead' or HasBuff(obj, 'InjuredRescue') or HasBuff(obj, 'InjuredRageRescue'));
end

function TestGameOption(args)
	return SafeIndex(GetOption(), unpack(args.OptionKey)) == args.TargetValue;
end

function TestMoveFollowCamera(args)
	return not GetOption().Gameplay.DisableTurnCam or GetRelationWithPlayer(GetObjectByKey(args.TargetKey)) ~= 'Team';
end

function TestPositionIsVisible(pos)
	return IsVisiblePosition(pos);
end
function TestObjectVisibleAndAliveMulti(args)
	local objList = args.ObjectList;
	local mode = args.Mode;
	local value = nil;
	local op = nil;
	if mode == 'Or' then
		value = false;
		op = function(a, b) return a or b; end;
	elseif mode == 'And' then
		value = true;
		op = function(a, b) return a and b; end;
	end
	if op == nil then
		return false;
	end
	for i, objKey in ipairs(objList) do
		local obj = GetObjectByKey(objKey);
		local nv = IsObjectInSight(obj) and GetFSMState(obj) ~= 'Dead';
		value = op(value, nv);
	end
	--LogAndPrint('TestObjectVisibleAndAliveMulti', PackTableToStringReadable(args), value);
	return value;
end

function TestEnableActionCameraMove()
	-- 이동은 호크아이 모드에선 무조건 꺼짐
	if IsClient() and (GetOption().Gameplay.DisableRushCam 
						or IsHawkEyeMode() 
						or GetRootLayout('BattleMain', false):getUserData('IsNextTurnMyTurn')) then
		return false;
	end
	return true;
end
function TestEnableActionCameraDead()
	if IsClient() and GetOption().Gameplay.DisableAbilityCam then
		return false;
	end
	return true;
end
function TestCompanyTechniqueNotOpened(args)
	local techniqueName = args;

	local session = GetSession();
	local company = session.company_info;
	local technique = GetWithoutError(company.Technique, techniqueName);
	if not technique then
		return false;
	end
	return not technique.Opened;
end
function TestEnableDetailInteraction()
	if IsClient() and GetOption().Gameplay.SimpleInteraction then
		return false;
	end
	return true;
end

g_voiceTextCounter = 1;
g_voiceTextFrequency = 0;
function TestCharacterVoiceTextFrequency()
	local optionValue = GetOption().Gameplay.CharacterVoiceTextFrequency;
	if optionValue == 0 then
		return true;
	elseif optionValue == 1 then
		-- 빈도 재조정
		if g_voiceTextFrequency < 3 or g_voiceTextFrequency > 5 then
			g_voiceTextFrequency = math.random(3, 5);
		end
		if g_voiceTextCounter >= g_voiceTextFrequency then
			g_voiceTextCounter = 1;
			g_voiceTextFrequency = math.random(3, 5);
			return true;
		else
			g_voiceTextCounter = g_voiceTextCounter + 1;
			return false;
		end
	elseif optionValue == 2 then
		-- 빈도 재조정
		if g_voiceTextFrequency < 8 or g_voiceTextFrequency > 10 then
			g_voiceTextFrequency = math.random(8, 10);
		end
		if g_voiceTextCounter >= g_voiceTextFrequency then
			g_voiceTextCounter = 1;
			g_voiceTextFrequency = math.random(8, 10);
			return true;
		else
			g_voiceTextCounter = g_voiceTextCounter + 1;
			return false;
		end
	elseif optionValue == 3 then
		return false;
	else
		return true;	
	end
end
function TestObjectVisibleAndAliveVoice(objKey)
	return TestObjectVisibleAndAlive(objKey) and TestCharacterVoiceTextFrequency();
end

function ClientDirecting_SPOvercharged(cds, obj, noWait)
	-- 스킵 가능
	cds:RunScriptArgs('SetDirectingSkipEnabled', true);
	cds:SkipPointOn();
	local objKey = GetObjKey(obj);
	local icon = obj.ESP.SPImage;
	local fontColor = obj.ESP.FrontBarColor;
	local animationKey = 'TimeUp';
	local text = WordText('SPFullGained');
	local camMove = nil;
	if not noWait then
		camMove = cds:ChangeCameraTarget(objKey, '_SYSTEM_', false, true, 0.5);
	end
	local UIEffectID = cds:PlayUIEffect(objKey, '_CENTER_', 'GeneralNotifier', 3, 1.5, PackTableToString({Icon = icon, FontColor = fontColor, AnimationKey = animationKey, Text = text}));
	local voiceID = nil;
	local voiceSound, voiceSoundVolume, _, voiceText = GetObjectVoiceSound(obj, 'Overcharge');
	if voiceSound ~= nil and voiceSound ~= 'None' and TestCharacterVoiceTextFrequency() then
		if GetRelationWithPlayer(obj) == 'Team' then
			voiceID = cds:PlaySound(voiceSound, 'Voice', voiceSoundVolume, true);
		else
			voiceID = cds:PlaySound3D(voiceSound, objKey, '_CENTER_', 3000, 'Voice', voiceSoundVolume or 1.0, true);
		end
		if voiceText and voiceText ~= 'None' then
			local textID = cds:UpdateCharacterVoiceText(voiceText, objKey);
			cds:Connect(textID, voiceID, 0);
		end
	end
	
	local aniID = cds:PlayAni(objKey, 'Overcharge', false);
	if camMove then
		cds:Connect(aniID, camMove, 0);
	end
	local particleID = cds:PlayParticle(objKey, '_BOTTOM_', obj.ESP.Effect, obj.ESP.EffectTime, true, false, noWait);	
	cds:Connect(aniID, UIEffectID, 0);
	cds:Connect(particleID, UIEffectID, 0);
	if voiceID then
		cds:Connect(voiceID, UIEffectID, 0);
	end
	-- 스킵 종료
	cds:SkipPointOff();
	cds:RunScriptArgs('SetDirectingSkipEnabled', false);
end
function ClientDirecting_SPOverchargedAlert(cds, obj, noWait)
	local objKey = GetObjKey(obj);
	local icon = obj.ESP.SPImage;
	local fontColor = obj.ESP.FrontBarColor;
	local animationKey = 'TimeUp';
	local text = string.format(GetWord('SPFullGainedAlert'), math.floor(obj.SP/obj.MaxSP* 100));
	local camID = nil;
	if noWait then
		camID = cds:ChangeCameraTarget(objKey, '_SYSTEM_', false, false, 0.5);
	end
	local UIEffectID = cds:PlayUIEffect(objKey, '_CENTER_', 'GeneralNotifier', 3, 1.5, PackTableToString({Icon = icon, FontColor = fontColor, AnimationKey = animationKey, Text = text}));
	if camID then
		cds:Connect(UIEffectID, camID, 0);
	end
end
function ClientDirecting_OnGuideUDPConnection(cds, obj)
	cds:Dialog("HelpMessageBox", { Type = 'UDPConnection' });
end

function CheckSteamAchievement_OnCharacterDead(cds, dead, killer)
	if not HasSteamAchievement('SituationDyingOnSelfsameDay') then
		local targetList = { 'Albus', 'Sion', 'Irene' };
		local isTarget = false;
		for _, name in ipairs(targetList) do
			if dead.Info.name == name then
				isTarget = true;
				break;
			end
		end
		if isTarget then
			local key = 'DyingOnSelfsameDay';
			if not ui_session.achievements[key] then
				ui_session.achievements[key] = {};
			end
			ui_session.achievements[key][dead.Info.name] = true;
			
			local deads = table.filter(targetList, function(name)
				return ui_session.achievements[key][name] or false;
			end);
			
			if #deads == #targetList then
				cds:UpdateSteamAchievement('SituationDyingOnSelfsameDay', true);
			end
		end
	end
end