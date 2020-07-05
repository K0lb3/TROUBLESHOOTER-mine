------------------------------------------------------------------------
-- 로비 대사 특정 조건 만족
------------------------------------------------------------------------
function Check_LobbyIdleMessage_RecruitLetonComplete(company)
	return company.Progress.Character.Leton >= 8;
end
function Check_LobbyIdleMessage_Tutorial_CrowRuinsAfter_Alley_Win(company)
	return company.MissionCleared.Tutorial_CrowRuinsAfter_Alley and company.Technique.LoveHate.Opened;
end
function Check_LobbyIdleMessage_Tutorial_CrowRuinsAfter_Alley_Lose(company)
	return company.MissionCleared.Tutorial_CrowRuinsAfter_Alley and not company.Technique.LoveHate.Opened;
end
------------------------------------------------------------------------
function GetLobbyIdleMessage(company, objName, lobbyCls, idspace)
	local lobbyIdleMessageList = GetClassList(idspace);
	-- 기본 스테이지 대사 값.
	local grade, missionName = GetScenarioProgressGrade(company);
	local msgKey = missionName;
	
	-- 커스터마이징 값.
	if lobbyCls.name == 'Office_Albus' and missionName == 'Tutorial_FireflyPark' then	
		msgKey = lobbyCls.name;
	elseif company.Progress.Tutorial.Opening == 'OfficeMoveIn' and missionName == 'Tutorial_Silverlining' then
		if company.Progress.Tutorial.Office == 11 or company.Progress.Tutorial.Office == 12 or company.Progress.Tutorial.Office == 13 then
			msgKey = 'LeaveOfficeMoveIn';
		else
			msgKey = 'OfficeMoveIn';
		end
	end
	
	local ParseChatCls = function(chatCls)
		local checker = GetWithoutError(chatCls, 'Checker');
		if checker then
			local checkFunc = _G['Check_LobbyIdleMessage_'..checker];
			if not checkFunc or not checkFunc(company) then
				return {};
			end
		end
		local msgList = {};
		local text = GetWithoutError(chatCls, 'Text');
		if text then
			table.insert(msgList, chatCls);
		else
			for _, subCls in ipairs(chatCls) do
				table.insert(msgList, subCls);
			end
		end
		return msgList;
	end;
	
	local msgList = {};
	local curMsgList = SafeIndex(lobbyIdleMessageList, objName, 'Events', msgKey, 'Chat');
	if curMsgList then
		for _, cls in ipairs(curMsgList) do
			table.append(msgList, ParseChatCls(cls));
		end
	end
	-- 공용 대사 넣기.
	local commonList = SafeIndex(lobbyIdleMessageList, objName, 'Events', 'All', 'Chat');
	if commonList then
		for _, cls in ipairs(commonList) do
			if cls.MinGrade <= grade and cls.MaxGrade >= grade then
				table.insert(msgList, cls);
			end
		end
	end
	return msgList, curMsgList;
end