--------------------------------------------------
-- 트러블 메이커. 몬스터 경험치 획득 / 킬 카운트
-------------------------------------------------
function AddExp_TroubleMaker(dc, dead, expTaker, attackerState, isOverKill, isPerfectKill, ds, isKill)
	local company = GetCompany(expTaker);
	if not company then
		return;
	end
	-- 트러블메이커에 등록된 녀석이어야 한다.
	local baseMonType = FindBaseMonsterTypeWithCache(dead);
	local troublemaker = GetWithoutError(company.Troublemaker, baseMonType);
	if not troublemaker then
		return;
	end
	
	-- 최대 치면 더 이상 처리하지않는다.
	if troublemaker.MaxExp > troublemaker.Exp then
		local point = 1;
		-- 치명타 사망 2배
		if attackerState == 'Critical' then
			point = point * 2;
		end
		-- 오버킬 사망 2배
		if isOverKill then
			point = point * GetSystemConstant('OverKillReward_Troublemaker');
		end
		-- 퍼펙트 킬 사망 2배
		if isPerfectKill then
			point = point * GetSystemConstant('PerfectKillReward_Troublemaker');
		end
		-- 도전 모드 2배
		local mission = GetMission(expTaker);
		local missionAttribute = GetMissionAttribute(mission);
		if missionAttribute and missionAttribute.ChallengerMode then
			point = point * GetSystemConstant('ChallenerModeReward_Troublemaker');
		end
		-- 장벽 지구 보너스
		local reputationMultiplier = 0;
		local wallAreaBonus = GetDivisionTypeBonusValue(company.Reputation, 'Area_Wall');
		if wallAreaBonus > 0 then
			reputationMultiplier = reputationMultiplier + wallAreaBonus;
		end
		-- 관할 구역 보너스 - 시민 제보
		local isEnableCitizenReport, bonusCitizenReport = IsEnableAllowDivisionBonus(company, 'CitizenReport');		
		if isEnableCitizenReport then
			reputationMultiplier = reputationMultiplier + bonusCitizenReport.ApplyAmount;
		end
		if reputationMultiplier > 0 then
			point = math.floor(point * (100 + reputationMultiplier) / 100);
		end
		-- 펜 카메라
		local mastery_Pen_Camera = GetMasteryMastered(GetMastery(expTaker), 'Pen_Camera');
		if mastery_Pen_Camera then
			point = math.floor(point * (1 + mastery_Pen_Camera.ApplyAmount / 100));
		end		
		if troublemaker.Exp + point > troublemaker.MaxExp then
			point = troublemaker.MaxExp - troublemaker.Exp;
		end
		dc:AddCompanyProperty(company, string.format('Troublemaker/%s/Exp', troublemaker.name), point);
		if troublemaker.Exp == 0 then
			dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/IsNew', troublemaker.name), true);
		end
	end
	-- 죽였을 때만 발동 (길들이기, 제어권 탈취, 이능석 추출 제외)
	if isKill then
		-- IsKill 프로퍼티
		if not troublemaker.IsKill then
			dc:UpdateCompanyProperty(company, string.format('Troublemaker/%s/IsKill', troublemaker.name), true);
		end
		-- 트러블메이커 업적
		local achievement = troublemaker.Achievement;
		if achievement and achievement.name ~= nil and achievement.name ~= 'None' then
			local achieved = false;
			if troublemaker.AchievementCheckFunc ~= 'None' then
				local checkFunc = _G[troublemaker.AchievementCheckFunc];
				if checkFunc and checkFunc(company, troublemaker, dead, expTaker) then
					achieved = true;
				end
			else
				achieved = true;
			end
			if achieved then
				ds:UpdateSteamAchievement(achievement.name, true, GetTeam(expTaker));
			end
		end
		-- 현상금 메일 전송
		local wantedCls = GetClassList('TroublemakerWanted')[baseMonType];
		if wantedCls then
			local mailList = GetCompanyInstantProperty(company, 'MailList') or {};
			local wantedVill = wantedCls.Vill;
			table.insert(mailList, { MailKey = wantedCls.Type.Mail, ItemType = 'Vill', ItemCount = wantedVill, MailProperty = {WantedType=wantedCls.name}});
			SetCompanyInstantProperty(company, 'MailList', mailList);
		end
	end
end

function CheckTroublemakerAchievement_Scott(company, troublemaker, dead, killer)
	local mission = GetMission(dead);
	if mission.name ~= 'Tutorial_PurpleBackStreet' then
		return false;
	end
	return true;
end

function CheckTroublemakerAchievement_Brothers(company, troublemaker, dead, killer)
	local props = GetCompanyInstantProperty(company, 'AchievementBrothers') or {};
	props[troublemaker.name] = true;
	SetCompanyInstantProperty(company, 'AchievementBrothers', props);
	
	if not props.Mon_Gangster_DeliveryFat or not props.Mon_Gangster_DeliveryHelmet then
		return false;
	end
	return true;
end

local s_tmAchievementSkulls = {
	'Mon_Gangster_SkullFat', 'Mon_Gangster_SkullHelmet', 'Mon_Gangster_SkullNormal', 'Mon_Gangster_SkullThin',
};
function CheckTroublemakerAchievement_Skulls(company, troublemaker, dead, killer)
	local props = GetCompanyInstantProperty(company, 'AchievementSkulls') or {};
	props[troublemaker.name] = true;
	SetCompanyInstantProperty(company, 'AchievementSkulls', props);
	
	local successCount = table.count(s_tmAchievementSkulls, function(tmName)
		local tmExp = SafeIndex(GetWithoutError(company.Troublemaker, tmName), 'Exp') or 0;
		return props[tmName] or tmExp > 0;
	end);
	if successCount ~= #s_tmAchievementSkulls then
		return false;
	end
	return true;
end