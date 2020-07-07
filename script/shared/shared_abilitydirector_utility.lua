local tempSightKeyCount = 0;
function TestChatArgs(chatType, msg, args, debug)
	if string.find(chatType, 'Buff') or string.find(chatType, 'Debuff') then
		local buff = args.Buff;
		if buff == nil or GetClassList('Buff')[buff] == nil then
			LogAndPrint(string.format('[DataError] %s - %s args is invalid', debug, chatType), '- buff:', buff, ', msg:', msg, ', args:', args);
			Traceback();
		end
	elseif string.find(chatType, 'MasteryEvent') then
		local mastery = args.MasteryType;
		if mastery == nil or GetClassList('Mastery')[mastery] == nil then
			LogAndPrint(string.format('[DataError] %s - %s args is invalid', debug, chatType), '- mastery:', mastery, ', msg:', msg, ', args:', args);
			Traceback();
		end
	end
end
function AddCustomBindFunctionToDirectingScripter(ad)
	if ad == nil then
		LogAndPrint(debug.traceback());
	end
	function ad:ShowOpening(message, font, fontColor, typingDelay, holdTime)
		return self:RunScript('ShowOpening', { message = message, font = font, fontColor = fontColor, typingDelay = typingDelay, holdTime = holdTime }, false, true, 'SkipOpening')
	end
	function ad:ShowLevelUp(objKey, team, name, curLv, nextLv, targetJob, targetESP)
		return self:RunScript('ShowLevelUp', { objKey = objKey, Team = team, Name = name, curLv = curLv, nextLv = nextLv, Job = targetJob, ESP = targetESP}, false, false)
	end
	function ad:ShowCompanyLevelUp(team, level)
		return self:RunScript('ShowCompanyLevelUp', { Team = team, Level = level }, true)
	end
	function ad:ShowAcquireMastery(team, name)
		return self:RunScript('ShowAcquireMastery', { Team = team, Name = name }, true)
	end
	function ad:ShowAcquireMasteryInfo(team, name, guide)
		return self:RunScript('ShowAcquireMasteryInfo', { Team = team, Name = name, Guide = guide }, false, false)
	end
	function ad:ShowAcquireMasteryDirecting(team, name, count, guide, invoker)
		return self:RunScript('ShowAcquireMasteryDirecting', { Team = team, Name = name, Count = count, Guide = guide, Invoker = invoker }, true)
	end
	function ad:UpdateCoverStateIcon(objKey, coverState)
		return self:RunScript('UpdateCoverStateIcon', { objKey = objKey, coverState = coverState }, true)
	end
	function ad:UpdateStatusName(objKey, visible)
		return self:RunScript('UpdateStatusName', { objKey = objKey, visible = visible }, true)
	end
	function ad:HideCoverStateIcon(objKey)
		return self:RunScript('HideCoverStateIcon', { objKey = objKey }, true)
	end
	function ad:UpdateTopIcon(objKey, iconState)
		return self:RunScript('UpdateTopIcon', { objKey = objKey, IconState = iconState }, true)
	end
	function ad:HideTopIcon(objKey)
		return self:RunScript('HideTopIcon', { objKey = objKey }, true)
	end
	function ad:UpdateBattleMessage(objKey, color, message )
		return self:RunScript('UpdateBattleMessage', { objKey = objKey, Color = color, message = message }, true)
	end
	function ad:UpdateBattleMessageText(objKey, color, text )
		return self:RunScript('UpdateBattleMessageText', { objKey = objKey, Color = color, text = text }, true)
	end
	ad.AbilityDirectingEventClsList = GetClassList('AbilityDirectingEvent');
	function ad:UpdateBattleEvent(objKey, eventType, eventArgs)
		local eventCls = ad.AbilityDirectingEventClsList[eventType];
		return eventCls.HandleFunc(self, objKey, eventType, eventArgs, eventCls);
	end
	function ad:AddMissionChat(chatType, msg, args)
		TestChatArgs(chatType, msg, args, 'AddMissionChat');
		return self:RunScript('AddMissionChat', { Type = chatType, Message = msg, Args = args }, true)
	end
	function ad:AddChat(chatType, msg, args)
		TestChatArgs(chatType, msg, args, 'AddChatDS');
		return self:RunScript('AddChatDS', {Type = chatType, Message = msg, Args = args}, true);
	end
	function ad:AddRelationMissionChat(chatType, msg, args)
		TestChatArgs(chatType, msg, args, 'AddRelationMissionChat');
		return self:RunScript('AddRelationMissionChat', { Type = chatType, Message = msg, Args = args }, true)
	end
	function ad:AlertScreenEffect(objKey)
		return self:RunScript('AlertScreenEffect', { objKey = objKey }, true)
	end
	function ad:UpdateInteractionMessage(objKey, interaction, interactionType, interactionSubType)
		return self:RunScript('UpdateInteractionMessage', { objKey = objKey, interaction = interaction, interactionType = interactionType, interactionSubType = interactionSubType }, true)
	end
	function ad:UpdateTitleMessage(title, titleColor, content, contentColor, img)
		return self:RunScript('UpdateTitleMessage', {title = title, titleColor = titleColor, content = content, contentColor = contentColor, img = img }, true)
	end
	function ad:UpdateTitleMessageWithText(titleText, titleColor, contentText, contentColor, img)
		return self:RunScript('UpdateTitleMessageWithText', {title = titleText, titleColor = titleColor, content = contentText, contentColor = contentColor, img = img }, true)
	end
	function ad:UpdateBattleSystemMessage(title, text, mark)
		return self:RunScript('UpdateBattleSystemMessage', {title = title, text = text, mark = mark}, true)
	end
	function ad:UpdateBattleSystemMessage_KeyWord(title, text, mark)
		return self:RunScript('UpdateBattleSystemMessage_KeyWord', {title = title, text = text, mark = mark}, true)
	end
	function ad:UpdateBattleSystemMessage_Help(help, mark)
		return self:RunScript('UpdateBattleSystemMessage_Help', {help = help, mark = mark}, true)
	end
	function ad:UpdateBalloonChat(objKey, message, balloonType, font, fontColor, lifeTime, aliveOnly)
		return self:RunScript('UpdateBalloonChat', { objKey = objKey, message = message, balloonType = balloonType, font = font, fontColor = fontColor, lifeTime = lifeTime, aliveOnly = (aliveOnly == nil and true or aliveOnly) }, true)
	end
	function ad:UpdateBalloonChatVoiceText(objKey, voiceKey, balloonType, font, fontColor, lifeTime)
		return self:RunScript('UpdateBalloonChatVoiceText', { objKey = objKey, voiceKey = voiceKey, balloonType = balloonType, font = font, fontColor = fontColor, lifeTime = lifeTime }, true)
	end
	function ad:UpdateBalloonCivilMessage(objKey, civilType, ageType, balloonType, lifeTime)
		return self:RunScript('UpdateBalloonCivilMessage', { objKey = objKey, civilType = civilType, ageType = ageType, balloonType = balloonType, LifeTime = lifeTime}, true)
	end
	function ad:UpdateBalloonChatWithText(objKey, text, balloonType, font, fontColor, lifeTime, aliveOnly)
		return self:RunScript('UpdateBalloonChatWithText', { objKey = objKey, text = text, balloonType = balloonType, font = font, fontColor = fontColor, lifeTime = lifeTime, aliveOnly = (aliveOnly == nil and true or aliveOnly) }, true)
	end
	function ad:StartMissionDirect(hideUI)
		return self:RunScript('StartMissionDirect', {HideUI = hideUI}, true)
	end
	function ad:EndMissionDirect(showUI)
		return self:RunScript('EndMissionDirect', {ShowUI = showUI}, true)
	end
	function ad:BattleUIControl(visible, previous)
		return self:RunScript('BattleUIControl', { visible = visible, previous = previous }, true)
	end
	function ad:MissionDashBoardVisible(visible)
		return self:RunScript('MissionDashBoardVisible', {visible = visible}, true)
	end
	function ad:MissionSubInterfaceVisible(visible)
		return self:RunScript('MissionSubInterfaceVisible', {visible = visible}, true)
	end
	function ad:HideBattleStatus(objKey)
		return self:RunScript('HideBattleStatus', { objKey = objKey}, true)
	end
	function ad:MissionVisualArea_AddCustom(key, particlePosition, particle, visible, team)
		return self:RunScript('MissionVisualArea_AddCustom', { particlePosition = particlePosition, visible = visible, key = key, particle = particle, team = team}, true)
	end
	function ad:MissionVisualArea_AddCustomMulti(key, particlePositions, particle, visible, team)
		return self:RunScript('MissionVisualArea_AddCustomMulti', { particlePositions = particlePositions, visible = visible, key = key, particle = particle, team = team}, true);
	end
	function ad:MissionVisualRange_AddCustom(key, visible, pos, visibleObjKey, allyRange, enemyRange)
		return self:RunScript('MissionVisualRange_AddCustom', {key = key, visible = visible, pos = pos, visibleObjKey = visibleObjKey, allyRange = allyRange, enemyRange = enemyRange});
	end
	function ad:UpdateDamagedGauge(objKey, args)
		local argsStr = PackTableToString(args);
		local damageStatus = self:UpdateAttachingWindow(objKey, 'Status', 'UpdateDamagedGauge', argsStr)

		local damageUI = self:RunScript('UpdateDamagedGaugeInUI', { objKey = objKey, argsStr = argsStr })
		self:Connect(damageUI, damageStatus, 0)
		
		return damageStatus
	end
	function ad:UpdateCostDamagedGauge(objKey, args)
		local argsStr = PackTableToString(args);
		local damageStatus = self:UpdateAttachingWindow(objKey, 'Status', 'UpdateCostDamagedGauge', argsStr)

		local damageUI = self:RunScript('UpdateCostDamagedGaugeInUI', { objKey = objKey, argsStr = argsStr })
		self:Connect(damageUI, damageStatus, 0)
		
		return damageStatus
	end
	function ad:UpdateSPDamagedGauge(objKey, args)
		local argsStr = PackTableToString(args);
		local damageStatus = self:UpdateAttachingWindow(objKey, 'Status', 'UpdateSPDamagedGauge', argsStr)

		local damageUI = self:RunScript('UpdateSPDamagedGaugeInUI', { objKey = objKey, argsStr = argsStr })
		self:Connect(damageUI, damageStatus, 0)
		
		return damageStatus
	end
	function ad:NoStatusUIWithThisAction(startActionID, endActionID)
		if endActionID == nil then
			endActionID = startActionID;
		end
		local offID = self:ChangeStatusVisible(false);
		local onID = self:ChangeStatusVisible(true);
		self:Connect(offID, startActionID, 0); -- 시작할 때 끄고
		self:Connect(onID, endActionID, -1); -- 끝날 때 켠다
	end
	-- 음성 연출 추가용 함수
	function ad:PlayVoiceAndText(obj, voiceKey, needCamMove, camMoveOffset, voiceRefID, sleepTime, twoDimentionalSound)
		local objKey = GetObjKey(obj);
		local voiceSound, voiceSoundVolume, voiceOffset, voiceText = GetObjectVoiceSound(obj, voiceKey);
		if voiceSound == nil then
			return voiceRefID;
		end
		local enableID = self:EnableIf('TestObjectVisibleAndAliveVoice', objKey);
		self:Connect(enableID, voiceRefID, 0);
		local nextRefID = nil;
		local sleepID = self:Sleep(sleepTime + voiceOffset + 0.5);
		self:Connect(sleepID, enableID, -1);
		if voiceSound ~= 'None' then
			local voiceID = nil;
			if twoDimentionalSound then
				voiceID = self:PlaySound(voiceSound, 'Voice', voiceSoundVolume, true);
			else
				voiceID = self:PlaySound3D(voiceSound, objKey, '_CENTER_', 3000, 'Voice', voiceSoundVolume or 1.0, true);
			end
			self:Connect(voiceID, sleepID, -1);
			nextRefID = voiceID;
		end
		if voiceText and voiceText ~= 'None' then
			self:UpdateCharacterVoiceText(voiceText, objKey);
		end
		nextRefID = voiceRefID;
		return nextRefID;
	end;
	-- 임시 시야함수
	function ad:TemporarySightWithThisAction(pos, range, startID, startRef, endID, endRef)
		local sightObjKey = string.format('_TS:%d', tempSightKeyCount);
		tempSightKeyCount = tempSightKeyCount + 1;
		local onID = self:CreateClientSightObject(sightObjKey, pos.x, pos.y, pos.z, range);
		local offID = self:DestroyClientSightObject(sightObjKey);
		self:Connect(onID, startID, startRef);
		self:Connect(offID, endID, endRef);
	end;
	function ad:TemporarySightTargetWithThisAction(objKey, range, startID, startRef, endID, endRef)
		local onID = self:EnableTemporalSightTarget(objKey, 0, range);
		local offID = self:DisableTemporalSightTarget(objKey, 0);
		self:Connect(onID, startID, startRef);
		self:Connect(offID, endID, endRef);
	end;
	function ad:ShowAlertLine(fromObjKey, toObjKey, particleName)
		return self:RunScript('ShowAlertLine', {FromKey = fromObjKey, ToKey = toObjKey, ParticleName = particleName}, true);
	end
	function ad:ShowBuffEffect(objKey, buffName)
		return self:RunScript('ShowBuffEffect', {objKey = objKey, buffName = buffName});
	end
	function ad:HideBuffEffect(objKey, buffName)
		return self:RunScript('HideBuffEffect', {objKey = objKey, buffName = buffName});
	end
	function ad:EnableBattleMessage(enable)
		return self:RunScript('EnableBattleMessage', {enable = enable});
	end
	function ad:ClearDyingObjects()
		return self:RunScript('ClearDyingObjects', {});
	end
	function ad:SkipPointOn()
		return self:RunScript('SkipPointOn', {});
	end
	function ad:SkipPointOff()
		return self:RunScript('SkipPointOff', {});
	end
	function ad:RegisterMoveCameraHandler(userKey, mainMoveId, jumpCamType, returnCamType, direct, startRelease, endRelease)
		if direct == nil then
			direct = true;
		end
		-- 점프시 카메라 연출부 시작
		local enableJumpStart = self:EnableIf('TestMoveFollowCamera', {TargetKey = userKey});
		self:SetConditional(enableJumpStart);
		local onJumpOrLandStarted, jumpStartKey = self:SubscribeFSMEvent(userKey, 'JumpOrLandStarted', 'OnJumpStartCamCheck', {});
		self:SetConditional(onJumpOrLandStarted);
		self:Connect(onJumpOrLandStarted, enableJumpStart, -1);
		self:Connect(self:ChangeCameraTarget(userKey, jumpCamType, direct, startRelease, 0), onJumpOrLandStarted, 0);
		local enableJumpEnd = self:EnableIf('TestMoveFollowCamera', {TargetKey = userKey});
		self:SetConditional(enableJumpEnd);
		local onJumpOrLandEnded, jumpEndKey = self:SubscribeFSMEvent(userKey, 'JumpOrLandStepOut', 'OnJumpEndCamCheck', {})
		self:SetConditional(onJumpOrLandEnded);
		self:Connect(onJumpOrLandEnded, enableJumpEnd, -1);
		self:Connect(self:ChangeCameraTarget(userKey, returnCamType, direct, endRelease, 0), onJumpOrLandEnded, 0);
		local onShown, onShownKey = self:SubscribeFSMEvent(userKey, 'VisibleUpdated', 'OnShownUnit', {});
		self:SetConditional(onShown);
		self:Connect(self:ChangeCameraTarget(userKey, '_SYSTEM_', false, false, 0.5), onShown, -1);
		for _, key in ipairs({jumpStartKey, jumpEndKey, onShownKey}) do
			self:Connect(self:UnsubscribeFSMEvent(key), mainMoveId, -1);
		end
	end
	function ad:StartRushMoveCamera(target, movePos, moveCameraKey, refID, refOffset, endRef, speedFactor)
		--LogAndPrint('StartRushMoveCamera', refID, refOffset);
		local targetKey = GetObjKey(target);
		local speedStartID = self:ChangeSpeedFactor(speedFactor);
		local speedEndID = self:ChangeSpeedFactor(1);
		local returnCamID = self:ChangeCameraTarget(targetKey, '_SYSTEM_', true, false);
		local backCamStartID = self:ChangeCameraTarget(targetKey, moveCameraKey, true, false);
		local moveSoundEffect = self:PlaySound3D('windPressure.ogg', targetKey, '_CENTER_', 3000, 'Effect', 1.0);		
		local camSleep = self:Sleep(0.1);
		local enableCameraStart = self:EnableIf('TestEnableActionCameraMove');
		self:Connect(enableCameraStart, refID, refOffset);
		self:Connect(camSleep, enableCameraStart, 0);
		self:Connect(moveSoundEffect, camSleep, 0);
		self:Connect(backCamStartID, camSleep, -1);
		self:Connect(speedStartID, camSleep, -1);
		
		-- returnCamID 를 mainMove 종료 직전 일정 거리 이전에서 커넥트하고 싶습니다.
		local enableCameraEnd = self:EnableIf('TestEnableActionCameraMove');
		if endRef then
			self:Connect(enableCameraEnd, endRef, -1);
			endRef = enableCameraEnd;
		else
			local nearToDestID = self:MakeEvent('CheckUnitArriveInRange', {TargetKey=targetKey, CheckPos=movePos, Range= 2});
			self:SetConditional(nearToDestID);
			self:Connect(enableCameraEnd, nearToDestID, -1);
			endRef = enableCameraEnd;
		end
		self:Connect(returnCamID, endRef, -1);
		self:Connect(speedEndID, endRef, -1);
		
		self:NoStatusUIWithThisAction(backCamStartID, endRef);
	end
	function ad:GeneralMove(target, movePos, noCamera, useRush, refID)
		local rushCamEnabled = false;
		if IsSamePosition(GetPosition(target), movePos) then
			if not noCamera then
				local objKey = GetObjKey(target);
				local enableCam = self:EnableIf('TestMoveFollowCamera', {TargetKey = objKey});
				self:Connect(self:ChangeCameraTarget(objKey, '_SYSTEM_', false, true, 0.5), enableCam, -1);
				if refID then
					self:Connect(enableCam, refID, 0);
				end
			end
		else
			local maxDist = 0;
			local priorDist = 0;
			local moveAbility = FindMoveAbility(target)
			if moveAbility.name == 'Move' then
				maxDist = target.MoveDist * (1 + target.SecondaryMoveRatio);
				priorDist = target.MoveDist;
			elseif moveAbility.name == 'SecondMove' or moveAbility.name == 'ExtraMove' then
				maxDist = target.MoveDist * target.SecondaryMoveRatio;
				priorDist = maxDist;
			end
			local objKey = GetObjKey(target);
			local movePath, moveDist = GetMovePath(target, { movePos }, maxDist, priorDist);
			local moveAniSpeed = 1;
			local forceAni = '';
			if moveDist >= target.Shape.RushDistance then
				moveAniSpeed = target.Shape.MoveCameraAniSpeed;
				forceAni = 'Rush';
			end
			if noCamera then
				local moveId = self:Move(GetObjKey(target), movePos, false, true, forceAni, maxDist, priorDist, true, moveAniSpeed, true);
				if refID then
					self:Connect(moveID, refID, 0);
				end
			else
				local isJump = IsEnableJump(movePath);
				local camMove = self:ChangeCameraTarget(objKey, '_SYSTEM_', false);
				local sleep = self:Sleep(0);
				local camOptionTest = self:TernaryConnector('TestMoveFollowCamera', {TargetKey = objKey}, camMove, sleep);
				if refID then
					self:Connect(camOptionTest, refID, 0);
				end
				rushCamEnabled = GetCompany(target) ~= nil and GetDistance3D(GetPosition(target), movePos) > 4 and useRush and ( not isJump );
				local moveID = self:Move(GetObjKey(target), movePos, false, true, forceAni, maxDist, priorDist, true, moveAniSpeed, true);
				self:Connect(moveID, camOptionTest, -1);
				local moveCameraKey = target.Shape.MoveCamera;
				if RandomTest(50) then
					moveCameraKey = moveCameraKey..'_Right';
				else
					moveCameraKey = moveCameraKey..'_Left';
				end
				if rushCamEnabled then
					self:StartRushMoveCamera(target, movePos, moveCameraKey, camOptionTest, -1, moveID, 1.1);
				else
					moveCameraKey = '_SYSTEM_';
				end
				local direct, startRelease;
				if moveCameraKey == '_SYSTEM_' then
					direct = false;
					startRelease = false;
				else
					direct = true;
					startRelease = true;
				end
				self:RegisterMoveCameraHandler(objKey, moveID, '_SYSTEM_TARGET_', moveCameraKey, direct, startRelease, false);
			end
		end
		return rushCamEnabled;
	end
	function ad:ShowSubtitle(dialogArgs)
		return self:RunScript('ShowSubtitle', dialogArgs, dialogArgs.LifeTime > 0, true, 'SkipSubtitle');
	end
	function ad:ShowBackgroundImage(args)
		return self:RunScript('ShowBackgroundImage', args);
	end
	function ad:HideBackgroundImage(args)
		return self:RunScript('HideBackgroundImage', args);
	end
	function ad:AddSteamStat(statName, addValue, team)
		return self:RunScript('AddSteamStatByDirecting', { statName = statName, addValue = addValue, team = team }, false, true);
	end
	function ad:UpdateSteamStat(statName, value, team)
		return self:RunScript('UpdateSteamStatByDirecting', { statName = statName, value = value, team = team }, false, true);
	end
	function ad:UpdateSteamAchievement(achievementName, achieved, team)
		return self:RunScript('UpdateSteamAchievementByDirecting', { achievementName = achievementName, achieved = achieved, team = team }, false, true);
	end
	function ad:ShowFrontmessage(message, messageColor, team)
		return self:RunScript('Direct_ShowFrontmessage', {Message = message, MessageColor = messageColor or 'Corn', Team = team});
	end
	function ad:ShowFrontmessageWithText(textForm, messageColor, team)
		return self:RunScript('Direct_ShowFrontmessageWithText', {Text = textForm, MessageColor = messageColor or 'Corn', Team = team});
	end
	function ad:ShowConditionEffect(fillData)
		return self:RunScript('ShowConditionEffect', fillData, false, false, '');
	end
	function ad:SetNamedAssetVisible(key, visible)
		return self:RunScript('SetNamedAssetVisibleDirect', {key = key, visible = visible});
	end
	function ad:SetNamedAssetVisibleAll(key, visible)
		return self:RunScript('SetNamedAssetVisibleAllDirect', {visible = visible});
	end
	function ad:SetLayerAssetVisible(key, visible)
		return self:RunScript('SetLayerAssetVisibleDirect', {key = key, visible = visible});
	end
	function ad:HideObjectMarker(objKey)
		return self:RunScript('HideObjectMarkerByDirecting', { objKey = objKey }, true);
	end
	function ad:RunScriptArgs(funcName, ...)
		return self:RunScript('RunScriptArgs', { funcName = funcName, args = { ... } });
	end
	function ad:PlayLobbyPopupEffect(type, arg)
		return self:RunScript('PlayLobbyPopupEffectByDirecting', { type = type, arg = arg }, true);
	end
	function ad:ShowCredit(args)
		return self:RunScript('ShowCredit', args);
	end
	function ad:UpdateCharacterVoiceText(message, objKey)
		return self:RunScript('UpdateCharacterVoiceText', { message = message, objKey = objKey }, true);
	end
	function ad:StartLobbyCameraMode(cameraMode, direct)
		return self:RunScript('StartLobbyCameraModeDirect', { cameraMode = cameraMode, direct = direct }, false, false);
	end
	function ad:ChangeLobbyMap(lobbyDefName)
		return self:RunScript('ChangeLobbyMapDirect', { lobbyDefName = lobbyDefName }, false, false);
	end
end
function AbilityDirectingEventHandler_Message(ad, objKey, eventType, eventArgs)
	return ad:RunScript('UpdateBattleEvent', { objKey = objKey, eventType = eventType, eventArgs = eventArgs }, true)
end
function AbilityDirectingEventHandler_AddCost(ad, objKey, eventType, eventArgs, eventCls)
	return ad:PlayUIEffect(objKey, '', 'AddCost', 0, 0, PackTableToString({Value = eventArgs.Count, CostType = eventArgs.CostType, AliveOnly = eventCls.AliveOnly, Delay = eventArgs.Delay}));
end
function AbilityDirectingEventHandler_AddSp(ad, objKey, eventType, eventArgs, eventCls)
	return ad:PlayUIEffect(objKey, '', 'AddSp', 0, 0, PackTableToString({Value = eventArgs.Count, SpType = eventArgs.SpType, AliveOnly = eventCls.AliveOnly, Delay = eventArgs.Delay}));
end
function AbilityDirectingEventHandler_AddWait(ad, objKey, eventType, eventArgs, eventCls)
	return ad:PlayUIEffect(objKey, '', 'AddTime', 0, 0, PackTableToString({Value = eventArgs.Time, AliveOnly = eventCls.AliveOnly, Delay = eventArgs.Delay}));
end
function AbilityDirectingEventHandler_SearchProtocolSucceeded(ad, objKey, eventType, eventArgs, eventCls)
	return ad:PlayUIEffect(objKey, '', 'SearchProtocol', 0, 0, PackTableToString({Value = eventArgs.Count, AliveOnly = eventCls.AliveOnly, Delay = eventArgs.Delay}));
end
function AbilityDirectingEventHandler_BigText(ad, objKey, eventType, eventArgs, eventCls)
	return ad:PlayUIEffect(objKey, '', 'BigText', 0, 0, PackTableToString({Text = eventArgs.Text, Color = eventArgs.Color or eventCls.Color, AliveOnly = eventCls.AliveOnly, Delay = eventArgs.Delay, AnimKey = eventArgs.AnimKey, Font = eventArgs.Font}));
end
function AbilityDirectingEventHandler_BuffImmuned(ad, objKey, eventType, eventArgs)
	local ret = AbilityDirectingEventHandler_Message(ad, objKey, eventType, eventArgs);
	local buffCls = GetClassList('Buff')[eventArgs.Buff];
	local buffKey = 'BuffImmuned';
	if buffCls.Type == 'Debuff' then
		buffKey = 'DebuffImmuned';
	end
	ad:Connect(ad:AddRelationMissionChat(buffKey, 'BuffImmuned', { ObjectKey = objKey, Buff = eventArgs.Buff}), ret, 0);
	return ret;
end
function AbilityDirectingEventHandler_BuffInvoked(ad, objKey, eventType, eventArgs)
	local ret = AbilityDirectingEventHandler_Message(ad, objKey, eventType, eventArgs);
	local buffCls = GetClassList('Buff')[eventArgs.Buff];
	if buffCls.TriggerSound ~= 'None' then
		ad:Connect(ad:PlaySound(buffCls.TriggerSound, 'Effect', 1, true), ret, 0);
	end
	return ret;
end
function AbilityDirectingEventHandler_BuffInvokedAbility(ad, objKey, eventType, eventArgs)
	local ret = AbilityDirectingEventHandler_Message(ad, objKey, eventType, eventArgs);
	local buffCls = GetClassList('Buff')[eventArgs.Buff];
	if not eventArgs.NoEffect then
		ad:Connect(ad:ShowBuffEffect(objKey, buffCls.name), ret, 0);
	end
	if buffCls.TriggerSound ~= 'None' then
		ad:Connect(ad:PlaySound(buffCls.TriggerSound, 'Effect', 1, true), ret, 0);
	end
	return ret;
end

function AbilityDirectingEventHandler_BuffRevealedFromAbility(ad, objKey, eventType, eventArgs)
	local ret = AbilityDirectingEventHandler_Message(ad, objKey, eventType, eventArgs);
	local buffCls = GetClassList('Buff')[eventArgs.Buff];
	if buffCls.TriggerSound ~= 'None' then
		ad:Connect(ad:PlaySound(buffCls.TriggerSound, 'Effect', 1, true), ret, 0);
	end
	return ret;
end

function AbilityDirectingEventHandler_StarShield(ad, objKey, eventType, eventArgs)
	local ret = AbilityDirectingEventHandler_Message(ad, objKey, eventType, eventArgs);
	ad:Connect(ad:HideBuffEffect(objKey, 'StarShield'), ret, 0);
	ad:Connect(ad:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/Anne/LightArrow_ImpactHit', 1.5, false), ret, 0);
	return ret;
end
function AbilityDirectingEventHandler_FreezingReleased(ad, objKey, eventType, eventArgs)
	local ret = ad:ReleasePose(objKey, 'None');
	return ret;
end
function AbilityDirectingEventHandler_FreezingRemoved(ad, objKey, eventType, eventArgs)
	local ret = ad:HideBuffEffect(objKey, 'Freezing');
	ad:Connect(ad:PlayParticle(objKey, '_BOTTOM_', 'Particles/Dandylion/Break_Ice', 1.5, false), ret, 0);
	ad:Connect(ad:PlaySound3D('HitEffect/Hit_Ice_Blunt.wav', objKey, 'Chest', 3000, 'Effect', 1.0), ret, 0);
	return ret;
end
function AbilityDirectingEventHandler_DirectDamageByType(ad, objKey, eventType, eventArgs, eventCls)
	return DirectDamageByType(ad, GetObjectByKey(objKey), eventArgs.DirectDamageType, eventArgs.Damage, eventArgs.NextHP, false, eventArgs.IsDead);
end
function AbilityDirectingEventHandler_MasteryInvoked(ad, objKey, eventType, eventArgs)
	local base = AbilityDirectingEventHandler_Message(ad, objKey, eventType, eventArgs);
	if eventArgs.MissionChat then
		local obj = nil;
		if IsMissionServer() then
			local mission = GetMissionFromDirectingScripter(ad);
			obj = GetUnit(mission, objKey);
		else
			obj = GetObjectByKey(objKey);
		end
		ad:Connect(ad:AddMissionChat(GetMasteryEventKey(obj), 'MasteryEvent', {ObjectKey = objKey, MasteryType = eventArgs.Mastery, EventType = eventArgs.WorldEventType}), base, 0);
	end
	return base;
end
function AbilityDirectingEventHandler_Dead(ad, objKey, eventType, eventArgs)
	return ad:SetDead(objKey, 'Normal', 0, 0, 0, 0, 0);
end
------------------------------------- AbilityDirect Action Utility -----------------------------------------
--- Damage : ad, ds 공용
-- damageType : attackerstate : 'Normal', 'Critical'
function DirectDamage(ds, obj, damageTitleText, damageBgColor, damage, nextHp, hitType, attackerState, hitResult, hitPos, isFocus, isDead, refID, refOffset)
	-- 카메라가 오브젝트 주변으로 이동하는가 아닌가...
	local user = GetObjKey(obj);
	local focusCamID = nil;
	if isFocus then
		focusCamID = ds:ChangeCameraTarget(user, '_SYSTEM_', false);
		if refID then
			ds:Connect(focusCamID, refID, refOffset);
		end
	end
	local hitEffectSoundCls = SafeIndex(GetClassList('HitEffectSound'), hitType, obj.Shape.BodyType, attackerState, hitResult);

	if hitEffectSoundCls == nil then
		local err = string.format('[DirectDamage] HitEffectSound 키 에러 (%s, %s, %s, %s)', hitType, obj.Shape.BodyType, attackerState, hitResult);
		LogAndPrint(err);
		LogAndPrint(debug.traceback());
		return;
	end

	local hitBone = GetObjectBonePos(obj, hitPos);
	if hitBone == nil then
		LogAndPrint(string.format('Can\'t Find BoneMap Info (%s, %s)', obj.Shape.BodyType, hitPos));
		return;
	end
	
	-- 	해당 피해 이유를 보여준다.
	local battleMessageColor;
	if damageBgColor ~= 'None' then
		battleMessageColor = damageBgColor;
	elseif hitType ~= 'Heal' then
		battleMessageColor = 'Red';
	else
		battleMessageColor = 'DodgerBlue';
	end

	local activation = ds:EnableIf('TestObjectVisibleAndAlive', GetObjKey(obj));
	local battleMessage = nil;
	if damageTitleText == '' then
		battleMessage = ds:Sleep(0);
	else
		battleMessage = ds:UpdateBattleMessageText(GetObjKey(obj), battleMessageColor, damageTitleText);
	end
	ds:Connect(battleMessage, activation, -1);
	if focusCamID then
		ds:Connect(activation, focusCamID, 0);
	elseif refID then
		ds:Connect(activation, refID, refOffset);
	end

	-- 연출 변수
	local effectSound = hitEffectSoundCls.Sound;
	local effectParticle = hitEffectSoundCls.Effect;
	local effectTime =  hitEffectSoundCls.EffectFrame / 30;
	local effectPos = hitPos;
	
	--- 연출
	local actionID = nil;
	
	if isDead then
		actionID = ds:SetDead(user, 'Normal', 0, 0, 0, 0, 0);
		local voiceSound, voiceSoundVolume, voiceOffset = GetObjectVoiceSound(obj, 'Dead');
		local hideBattleStatus = ds:HideBattleStatus(user);
		local timeFinish = obj.Shape.DeadFrame/30;
		if attackerState == 'Normal' then
			timeFinish = obj.Shape.DeadFrame * 0.6 /30;
		end
		local deadCamera_Start = ds:ChangeCameraTarget(user, 'DeadCamera_Start', true, false);
		local deadCamera_Finish = ds:ChangeCameraTarget(user, 'DeadCamera_Finish', false, false, timeFinish);
		local deadCamera_AfterFinish = ds:ChangeCameraTarget(user, '_SYSTEM_', true, false);
		local enableCamera = ds:EnableIf('TestEnableActionCameraDead');
		ds:Connect(enableCamera, actionID, 0);
		ds:Connect(deadCamera_Start, enableCamera, 0);
		ds:Connect(deadCamera_Finish, deadCamera_Start, 0);
		ds:Connect(deadCamera_AfterFinish, deadCamera_Finish, -1);
		ds:Connect(hideBattleStatus, actionID, 1);	
		if voiceSound and voiceSound ~= 'None' then
			local deadPlaySoundID = ds:PlaySound3D(voiceSound, user, '_CENTER_', 3000, 'Effect', voiceSoundVolume or 1.0, true);
			ds:Connect(deadPlaySoundID, actionID, voiceOffset);
		end
		-- 동결 사망 시의 추가 연출
		if HasBuff(obj, 'Freezing') then
			ds:Connect(ds:ReleasePose(user, 'None'), battleMessage, 0);
			ds:Connect(ds:HideBuffEffect(user, 'Freezing'), battleMessage, 0);
			ds:Connect(ds:PlayParticle(user, '_BOTTOM_', 'Particles/Dandylion/Break_Ice', 1.5, false), battleMessage, 0);
			ds:Connect(ds:PlaySound3D('HitEffect/Hit_Ice_Blunt.wav', user, 'Chest', 3000, 'Effect', 1.0), battleMessage, 0);
		end
	elseif damage >= 0 then
		local aniType = 'None';
		if hitResult == 'Dodge' then
			aniType = 'Block';
		elseif hitResult == 'Hit' then
			aniType = 'Finish';
		elseif hitResult == 'Block'then
			aniType = 'Block';
		else
			aniType = 'Hit';
		end
		actionID = ds:HitAni(user, 'Chest', aniType, 0);
	else
		actionID = ds:Sleep(0.01);	-- 아무 의미 없음
	end
	
	ds:Connect(actionID, battleMessage, 1);
	if hitEffectSoundCls.Sound ~= 'None' then
		ds:Connect(ds:PlaySound3D(effectSound, GetObjKey(obj), hitPos, hitEffectSoundCls.MinDistance or 2500, 'Effect', hitEffectSoundCls.Volume or 1.0, true), actionID, 0);
	end
	if hitEffectSoundCls.Effect ~= 'None' then
		local hitEffect = ds:PlayParticle(user, effectPos, effectParticle, effectTime, true, true, true);
		ds:Connect(hitEffect, actionID, 0);
	end
	
	local damageUI = ds:PlayUIEffect(user, effectPos, 'Damage', 1.5, 1, PackTableToString({damage = damage, attackerState = attackerState, defenderState = hitResult, hitState = 'UniqueHit'}));
	local damageStatus = ds:UpdateDamagedGauge(user, {nextHp = nextHp});
	ds:Connect(damageUI, actionID, 0);
	ds:Connect(damageStatus, actionID, 0);

	LogAndPrint(string.format('[%s] %d Direct Damaged %s -> %d', obj.name, damage, LoadText(damageTitleText), nextHp));
	return battleMessage;
end
function DirectDamageByType(ds, obj, directDamageType, damage, nextHp, isFocus, isDead, connectID, offset)
	local directDamageList = GetClassList('DirectDamageType');
	local curDirectDamage = directDamageList[directDamageType];
	local curDirectDamageName = SafeIndex(curDirectDamage, 'name');
	if curDirectDamageName == nil then
		LogAndPrint('[Error] DirectDamageByType - '..directDamageType);
		return;
	end
	local title = ClassDataText('DirectDamageType', directDamageType, 'Title');
	if curDirectDamage.Title == '' then
		title = '';
	end
	return DirectDamage(ds, 
		obj, 
		title, 
		curDirectDamage.BgColor,
		damage, 
		nextHp, 
		curDirectDamage.HitType, 
		curDirectDamage.AttackerState,
		curDirectDamage.HitResult,
		curDirectDamage.HitPos,
		isFocus, 
		isDead and not curDirectDamage.NoDeadCamera, 
		connectID, 
		offset
	);
end
function DirectDamageByTypeWithState(ds, obj, directDamageType, damage, nextHp, attackerState, hitResult, isFocus, isDead, connectID, offset)
	local directDamageList = GetClassList('DirectDamageType');
	local curDirectDamage = directDamageList[directDamageType];
	local curDirectDamageName = SafeIndex(curDirectDamage, 'name');
	if curDirectDamageName == nil then
		LogAndPrint('[Error] DirectDamageByTypeWithState - '..directDamageType);
		return;
	end
	return DirectDamage(ds, 
		obj, 
		ClassDataText('DirectDamageType', directDamageType, 'Title'), 
		curDirectDamage.BgColor,
		damage, 
		nextHp, 
		curDirectDamage.HitType, 
		attackerState,
		hitResult,
		curDirectDamage.HitPos,
		isFocus, 
		isDead and not curDirectDamage.NoDeadCamera, 
		connectID, 
		offset
	);
end
--- 시야 온 오프 ----
function AutoSightOn(ad, owner, connectId, distance)
	if not IsClient() then
		return;
	end
	-- 클라이언트에서만 한다
	local sightAction = ad:EnableTemporalSightTarget(GetObjKey(owner), 1, distance or 0)
	if connectId ~= nil then
		ad:Connect(sightAction, connectId, 0);
	end
	return sightObjKey;
end
function AutoSightOff(ad, connectId, owner)
	ad:Connect(ad:DisableTemporalSightTarget(GetObjKey(owner), 1), connectId, -1);
end
--------------------------------------------------------------------------------------------------------
-- 사운드 오브젝트.
--------------------------------------------------------------------------------------------------------
function GetVoiceSound(voiceType, key)
	LogAndPrint('GetVoiceSound ::', voiceType, key);
	local objVoiceSound = GetClassList('ObjectVoiceSound');
	if objVoiceSound[voiceType] == nil then
		return nil;
	end
	if objVoiceSound[voiceType].Actions[key] == nil then
		return nil;
	end
	local soundList = objVoiceSound[voiceType].Actions[key].Voice;
	if soundList == nil then
		return nil;
	end
	local picker = RandomPicker.new();
	for index, value in ipairs (soundList) do
		picker:addChoice(value.Prob, value);
	end
	local pickValue = picker:pick();
	return pickValue.Sound, pickValue.Volume, pickValue.Offset, pickValue.Text;
end
function GetObjectVoiceSound(object, key)
	local voiceType = object.Voice;
	local objVoiceSound = GetClassList('ObjectVoiceSound');
	if objVoiceSound[voiceType] == nil then
		return nil;
	end
	if objVoiceSound[voiceType].Actions[key] == nil then
		return nil;
	end
	local soundList = objVoiceSound[voiceType].Actions[key].Voice;
	if soundList == nil then
		return nil;
	end
	
	local lastPickPropName = 'LastPick' .. key;
	local lastPickIndex = GetInstantProperty(object, lastPickPropName);
	if #soundList == 1 then
		lastPickIndex = nil;
	end
	
	local picker = RandomPicker.new();
	for index, value in ipairs (soundList) do
		if index ~= lastPickIndex then
			picker:addChoice(value.Prob, value);
		else
			picker:addChoice(0, value);
		end
	end

	local pickValue, pickIdx = picker:pick();
	SetInstantProperty(object, lastPickPropName, pickIdx);
	local pickText = pickValue.Text;
	if pickText and pickText ~= 'None' then
		pickText = ClassDataText('ObjectVoiceSound', voiceType, 'Actions', key, 'Voice', pickIdx, 'Text');
	else
		pickText = nil;
	end
	return pickValue.Sound, pickValue.Volume, pickValue.Offset, pickText;
end
--------------------------------------------------------------------------------------------------------
-- 말풍선.
--------------------------------------------------------------------------------------------------------
function UpdateBalloonChat(args)
	local obj = GetObjectByKey(args.objKey);
	if obj == nil or not IsObjectInSight(obj) then
		return;
	end
	if args.aliveOnly and GetFSMState(obj) == 'Dead' then
		return;
	end
	local text = GetSentenceString(args.message);
	if text then
		local formatTable = {};
		FillImgSizeToFormatTable(formatTable);
		local form = text;
		text = FormatMessage(form, formatTable);
		if IsMissionMode() then
			table.insert(ui_session.translation_data, {Speaker = obj.Info.Title, Finalized = text, Original = GetDictionaryOriginalText(form, 'Text'), Translated = text, DictionaryType = 'Text'});
		end
	end
	Chat(obj, text, args.balloonType, args.font, nil, args.lifeTime);
	AddMissionChat({ Type = 'TalkNPC', Message = args.message, Args = { ObjectKey = args.objKey } });
end
function UpdateBalloonChatVoiceText(args)
	local obj = GetObjectByKey(args.objKey);
	if obj == nil or not IsObjectInSight(obj) then
		return;
	end
	local voiceSound, voiceSoundVolume, voiceOffset, voiceText = GetObjectVoiceSound(obj, args.voiceKey);
	args.message = voiceText;
	local text = GetSentenceString(args.message);
	if text then
		local formatTable = {};
		FillImgSizeToFormatTable(formatTable);
		text = FormatMessage(text, formatTable);
	end
	Chat(obj, text, args.balloonType, args.font, nil, args.lifeTime);
	AddMissionChat({ Type = 'TalkNPC', Message = args.message, Args = { ObjectKey = args.objKey } });
end
function UpdateBalloonChatWithText(args)
	local obj = GetObjectByKey(args.objKey);
	if obj == nil or not IsObjectInSight(obj) then
		return;
	end
	if args.aliveOnly and GetFSMState(obj) == 'Dead' then
		return;
	end
	local text = LoadText(args.text);
	if text then
		local formatTable = {};
		FillImgSizeToFormatTable(formatTable);
		text = FormatMessage(text, formatTable);
	end
	Chat(obj, text, args.balloonType, args.font, nil, args.lifeTime);
	AddMissionChat({ Type = 'TalkNPC', Message = args.message, Args = { ObjectKey = args.objKey } });
end
-------------------------------------------------------
-- balloonType 'Normal', 'Normal_Dark', 'Normal_Good', 'Normal_Rage', 'Shout', 'Shout_Dark', 'Shout_Good',	'Shout_Rage', 'Think', 'Think_Dark', 'Think_Good', 'Think_Rage'
-- Balloon.xml
function Chat(obj, message, balloonType, font, fontColor, lifeTime, attachType)
	if obj == nil then
		LogAndPrint("Chat Object is nil");
		return;
	end
	local win = GetAttachingWindow(obj, 'Balloon');
	if win == nil then	
		LogAndPrint('Object has no balloon win');
		return;
	end
	if message == '' then
		win:fireEvent('Stop', CEGUI.EventArgs());
		SetAttachingWindowVisible(obj, 'Balloon', false);
		return;
	end
	if not lifeTime then
		lifeTime = 3;
	end
	SetAttachingWindowVisible(obj, 'Balloon', true, lifeTime);
	ChangeWindowAttachType(obj, 'Balloon', attachType or 'Balloon');
	win:setUserData('BalloonChatCloseTime', os.clock() + lifeTime);
	if not IsUserInterfaceVisible() then
		win:setUserData('__ToggleInterfaceTarget', true);	-- system dependent..
		win:hide();
	end
	SetAttachingWindowVisible2(obj, 'Status', false);
	local objKey = nil;
	if IsMission() then
		objKey = GetObjKey(obj);
	end
	CreateScriptThread(function()
		Sleep(lifeTime * 1000);
		local reObj = obj;
		if objKey then
			reObj = GetObjectByKey(objKey);
		end
		if reObj == nil then
			return;
		end
		local win = GetAttachingWindow(reObj, 'Balloon');
		if os.clock() > (win:getUserData('BalloonChatCloseTime') or 0) then
			SetAttachingWindowVisible2(reObj, 'Status', true);
			if win:getUserData('__ToggleInterfaceTarget') and not IsUserInterfaceVisible() then
				win:setUserData('__ToggleInterfaceTarget', nil)
				SetAttachingWindowVisible2(reObj, 'Balloon', false);
			end
		end
	end);
	
	local bKey = nil;
	if balloonType then
		bKey = balloonType;
	else
		bKey = 'Normal_Civil';
	end
	-- 챗 비쥬얼 세팅.
	local chatBg = nil;
	local balloonList = GetClassList('Balloon');
	local bType = balloonList[bKey];
	if not bType or not bType.name then
		bType = balloonList['Normal_Civil'];
	end
	
	if font == nil then
		font = 'NotoSansMedium-13_Auto';
	end
	if fontColor == nil then
		fontColor = bType.FontColor;
	else
		fontColor = 'Cream';
	end
	
	local colorList = GetClassList('Color');
	
	local bgWin = win:getChild('Background');
	local shoutWin = bgWin:getChild('Shout');	
	local thinkWin = bgWin:getChild('Think');
	local normalWin = bgWin:getChild('Normal');
	
	-- 대화창 타입.	
	local screenWidth = 1920;
	local screenHeight = 1080;
	local baseballoonMinWidth = 0;
	local baseballoonMaxWidthOrigin = 260;
	local baseballoonMaxWidth = baseballoonMaxWidthOrigin * ui_session.min_screen_variation;
	local baseballoonMinHeight = 82;

	local marginPosX = 0;
	local marginPosY = 0;
	local marginWidth = 0;
	local marginHeight = 0;
	local marginHeight_adjust = 0;
	
	local curBalloonWin = nil;
	if bType.Type == 'Normal' then
		normalWin:show();
		thinkWin:hide();
		shoutWin:hide();
		curBalloonWin = normalWin;
		baseballoonMinWidth = 0;
		marginPosX = 0;
		marginPosY = 15;
		marginWidth = 50;
		marginHeight = 54;
		marginHeight_adjust = -4;
	elseif bType.Type == 'Think' then
		normalWin:hide();
		thinkWin:show();
		shoutWin:hide();	
		curBalloonWin = thinkWin;
		baseballoonMinWidth = 0;
		marginPosX = 0;
		marginPosY = 15;
		marginWidth = 50;
		marginHeight = 54;
		marginHeight_adjust = -4;
	elseif bType.Type == 'Shout' then
		normalWin:hide();
		thinkWin:hide();
		shoutWin:show();
		curBalloonWin = shoutWin;
		baseballoonMinWidth = 76;
		marginPosX = -14;
		marginPosY = 1;
		marginWidth = 50;
		marginHeight = 82;
		marginHeight_adjust = 14;
	end
	
	LogAndPrint('bType', bType.name, marginHeight)
	curBalloonWin:setProperty('FrameColours', colorList[bType.Color].ColorRect);
	curBalloonWin:setProperty('BackgroundColours', colorList[bType.Color].ColorRect);
	curBalloonWin:getChild('Frame'):setProperty('FrameColours', colorList[bType.FrameColor].ColorRect);

	
	local resultWidth = 0;
	local resultHeight = 0;
	
	local textWin = win:getChild('Text');	
	
		
	win:setWidth(CEGUI.UDim(baseballoonMaxWidthOrigin/screenWidth, 0));
	win:setHeight(CEGUI.UDim(baseballoonMinHeight/screenHeight, 0));
	textWin:setWidth(CEGUI.UDim(1, 0));
	textWin:setHeight(CEGUI.UDim(1, 0));
	
	local message = string.format("[colour='%s']%s", colorList[fontColor].ARGB, message);
	textWin:setProperty('Font', font);
	textWin:setProperty('HorzFormatting', 'LeftAligned');
	textWin:setText(message);
	local originWidth, originHeight = GetTextSize(textWin, false);
	LogAndPrint('1:', originWidth, originHeight, textWin:getPixelSize().width)
	if baseballoonMaxWidth > originWidth then
		-- 기본 크기보다 길이가 작은 텍스트일때.
		LogAndPrint('2:', win:getPixelSize().width, baseballoonMaxWidth, originWidth)
		resultWidth = math.max(baseballoonMinWidth, originWidth);
		resultHeight = originHeight;
		marginHeight = marginHeight + marginHeight_adjust;
		if baseballoonMinWidth > originWidth then
			textWin:setProperty('HorzFormatting', 'CentreAligned');
			if bType.Type == 'Shout' then
				marginPosX = -6;
			end
		end
	else
		-- 기본 크기보다 길이가 큰 텍스트일때.
		win:setWidth(CEGUI.UDim(0, baseballoonMaxWidth));
		resultWidth = baseballoonMaxWidth;
		textWin:setProperty('HorzFormatting', 'WordWrapLeftAligned');
		local recheckWidth, recheckHeight = GetTextSize(textWin, true);
		LogAndPrint('3:', recheckWidth, recheckHeight, baseballoonMinHeight)
		resultHeight = recheckHeight;
	end
	LogAndPrint('result', resultWidth, resultHeight, marginWidth, marginHeight)
	win:setWidth(CEGUI.UDim(0, resultWidth));
	win:setHeight(CEGUI.UDim(0, resultHeight));
	textWin:setWidth(CEGUI.UDim(1, 0));
	textWin:setHeight(CEGUI.UDim(1, 0));
	curBalloonWin:setWidth(CEGUI.UDim(1, marginWidth));
	curBalloonWin:setHeight(CEGUI.UDim(1, marginHeight));
	curBalloonWin:setPosition(CEGUI.UVector2(CEGUI.UDim(0, marginPosX), CEGUI.UDim(0, marginPosY)));
	if IsUserInterfaceVisible() then
		win:fireEvent('StartShow', CEGUI.EventArgs());
	end
	win:enable();
end
function UpdateBalloonCivilMessage(arg)
	local chatArg = {};
	chatArg.objKey = arg.objKey;
	chatArg.message = GetCivilMessage(arg.civilType, arg.ageType);
	if chatArg.message == nil then
		return;
	end
	chatArg.balloonType = arg.balloonType;
	chatArg.lifeTime = arg.lifeTime;
	UpdateBalloonChat(chatArg);
end
function MissionVisualArea_AddCustom(args)
	if args.team and args.team ~= GetPlayerTeamName() then
		return;
	end
	local particleKey = args.key;
	local particlePosition = args.particlePosition;
	local particleName = args.particle;
	if args.visible then
		ShowMissionVisualArea(particleKey, particlePosition, particlePosition, particleName, nil, nil);
	else
		HideMissionVisualArea(particleKey);
	end
end
function MissionVisualArea_AddCustomMulti(args)
	if args.team and args.team ~= GetPlayerTeamName() then
		return;
	end
	local particleKey = args.key;
	local particleName = args.particle;
	local noReset = false;
	if args.visible then
		for _, p in ipairs(args.particlePositions) do
			ShowMissionVisualArea(particleKey, p, p, particleName, nil, nil, noReset);
			noReset = true;
		end
	else
		HideMissionVisualArea(particleKey);
	end
end
function MissionVisualRange_AddCustom(args)
	local range = '';
	local visibleObj = GetUnit(args.visibleObjKey);
	if visibleObj == nil then	-- 하위 호환 처리
		range = args.range;
		if GetPlayerTeamName() ~= args.team then
			return;
		end
	elseif GetRelationWithPlayer(visibleObj) == 'Team' or GetRelationWithPlayer(visibleObj) == 'Ally' then
		range = args.allyRange;
	else
		range = args.enemyRange;
	end

	local handler = function(newVisible)
		if newVisible then
			ShowMissionVisualRange(args.key, range, args.pos, nil);
		else
			HideMissionVisualRange(args.key);
		end
	end;
	
	if args.visible then
		AddObjectVisibleUpdateHandler(visibleObj, args.key, handler);
	else
		RemvoeObjectVisibleUpdateHandler(visibleObj, args.key);
	end
	handler(IsObjectVisible(visibleObj) and args.visible);
end
function IsEnableJump(path)
	local enable = false;
	local prev = path[1];
	local height = 0;
	for i, p in ipairs(path) do
		height = GetHeight(p, prev);
		if math.abs(height) > 70 / 150 then
			enable = true;
			break;
		end
		prev = p;
	end
	return enable;
end
function RunScriptArgs(args)
	local func = _G[args.funcName];
	if func == nil then
		return;
	end
	func(unpack(args.args));
end