-- 로비 공지 체크
function GetNeedNoticeList(company)
	local list = {};
	local noticeClsList = GetClassList('Notice');
	for key, noticeCls in pairs(noticeClsList) do
		-- 이전에 확인된 버젼과 다를 때만 보여준다.
		if noticeCls.Version ~= company.NoticeVersions[key] then
			local enabled = false;
			if noticeCls.CheckFunc == 'Disabled' then
				enabled = false;
			elseif noticeCls.CheckFunc ~= 'None' then
				local checkFunc = _G[noticeCls.CheckFunc];
				if checkFunc then
					enabled = checkFunc(noticeCls, company);
				end
			else
				enabled = true;
			end
			if enabled then
				table.insert(list, key);
			end
		end
	end
	return list;
end
function CheckNotice_EndContentsNotice(cls, company)
--	return company.MissionCleared.Tutorial_TrainingRoomAfter;
	return false;
end
