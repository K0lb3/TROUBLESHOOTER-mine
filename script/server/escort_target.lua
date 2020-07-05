function InitializeEscortTarget(obj, unitDecl, reinitialize)
	if not reinitialize then
		local escortTargetInfo = SafeIndex(unitDecl, 'EscortTargetType', 1);
		
		if escortTargetInfo.Type == 'VIP' then
			AddBuff(obj, 'VIP', 1);
			obj.IsTurnDisplay = true;
		end
		
		local prevEscortTargetCnt = GetStageVariable(GetMission(obj), '_escort_target_cnt_') or 0;
		UpdateStageVariable(GetMission(obj), '_escort_target_cnt_', prevEscortTargetCnt + 1);
	end
	
	SubscribeWorldEvent(obj, 'UnitArrivedEscapeArea', function(eventArg, ds)
		if eventArg.Unit ~= obj then
			return;
		end
		local exitPosO = eventArg.Dashboard.ExitPos;
		local exitPos = {x = exitPosO.x, y = exitPosO.y, z = exitPosO.z};
		if IsInvalidPosition(exitPos) then
			exitPos = FindAIMovePosition(obj, {FindMoveAbility(obj)}, function (self, adb)
				return adb.MoveDistance;	-- 가장 멀리 갈 수 있는 아무데나
			end, {}, {});
		end
		
		local unitKey = GetObjKey(obj);
		local moveTo = GetMovePosition(obj, exitPos, 0);
		local moveID = ds:Move(unitKey, moveTo, false, false);
		ds:HideBattleStatus(unitKey);
		ds:UpdateBattleEvent(unitKey, 'GetWord', { Color = 'WhiteBlue', Word = 'Rescued' });
		ds:Sleep(1.5);
		ds:UpdateBalloonCivilMessage(unitKey, 'VIPRescued', obj.Info.name);
		ds:Sleep(1.5);		
		return Result_FireWorldEvent('EscortComplete', {Unit=obj}), Result_DestroyObject(obj, false, true);
	end);
	SubscribeWorldEvent(obj, 'UnitDead', function(eventArg, ds)
		if eventArg.Unit ~= obj then
			return;
		end
		return Result_FireWorldEvent('EscortFailed', {Unit=obj});
	end);
end