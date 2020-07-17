function MasterLobbyEnterDialogScript(lobbyType, ldm, company)
	-- 공용 로직
	LobbyEnter(ldm, company, lobbyType);
	-- 개별 로직.
	local func = _G['LobbyEnter_' ..lobbyType];
	if func then
		func(ldm, company);
	end
	LobbyEnterPost(ldm, company, lobbyType);
end
function LobbyEnter(ldm, company, lobbyType)
	-- 리포트 갱신 로직.
	local dc = ldm:GetDatabaseCommiter();
	
	-- 업적 갱신 (나중에 추가된 업적이나, 갱신 타이밍을 놓친 업적들을 추가 처리함)
	CheckAchievements(ldm, company, dc);
	
	-- ErrorCorrection
	CheckDataErrors(ldm, company, dc);
	
	-- 클래스 레벨에 따른 업데이트
	CheckRosterJobLevel(ldm, company, dc);
	
	-- 세트 마스터리 언락처리
	CheckMasterySetIndex(ldm, company, dc);
	
	-- 특성 연구 언락처리
	CheckTechniqueUnlock(ldm, company, dc);
		
	-- 제작 레시피 언락처리
	CheckRecipeUnlock(ldm, company, dc);
	
	-- 야수 어빌리티 활성화
	CheckBeastActiveAbility(ldm, company, dc);
	
	-- 기계 공용 마스터리 장착 해제
	CheckMachineInvalidMastery(ldm, company, dc);
	
	-- 무기 코스튬
	CheckWeaponCostumeUnlock(ldm, company, dc);
	
	-- 아시아 서버 한정 보상 지급
--	CheckAsiaServerErrorReward(ldm, company, dc);
	
	local isResetActivityReport = company.ResetActivityReport;
	if isResetActivityReport then
		
		ResetActivityReport(dc, company);		
		
		-- 회사 리셋 리포트 프로퍼티 값 변경.
		dc:UpdateCompanyProperty(company, 'ResetActivityReport', false);
		dc:Commit('InitializeActivityReport');
	end
	
	-- 새로운 지역 이동 갱신 여부
	local curLocation = company.Waypoint[lobbyType];
	if curLocation and curLocation.name ~= nil then
		if curLocation.IsNew then
			local dc = ldm:GetDatabaseCommiter();
			dc:UpdateCompanyProperty(company, string.format('Waypoint/%s/IsNew',lobbyType), false);
			dc:Commit('IsNewUpdateLocation');
		end
	end
	
	-- 회사 운영에 관련된 공용 로직을 로비 타입에 따라 비활성화함	
	local lobbyCls = GetClassList('LobbyWorldDefinition')[lobbyType];
	if not lobbyCls.EnableCommonLobbyEnter then
		return;
	end	
	
	-- 영입 로직.
	for key, roster in pairs(company.Scout) do
		if roster.NeedScout then
			ProgressDialog(ldm, nil, company, 'Initial_SetRosterInfo_NeedScout', {roster_name=roster.name});
		end
	end
	
	local allRosters = GetAllRoster(company);
	if #allRosters > 1 then	-- 혹시나 싶어서..
		-- 로스터 레벨 켈리브레이션
		local companyLevelSum = 0;
		for _, r in ipairs(allRosters) do
			companyLevelSum = companyLevelSum + r.Lv;
		end
		for _, r in ipairs(allRosters) do
			if r.NeedLevelAdjustment then
				local companyMeanLv = math.floor((companyLevelSum - r.Lv) / (#allRosters - 1));
				dc:UpdatePCProperty(r, 'NeedLevelAdjustment', false);

				local levelDv = companyMeanLv - r.Lv;
				if levelDv >= 2 then
					local addLv = math.floor(levelDv / 2);
					dc:UpdatePCProperty(r, 'Lv', r.Lv + addLv);
					ldm:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('RosterLevelAdjusted'), {RosterName = ClassDataText('Pc', r.name, 'Info', 'Title'), Level = addLv}));
					ldm:AddChat('Notice', FormatMessageText(GuideMessageText('RosterLevelAdjustedChat'), {RosterName = ClassDataText('Pc', r.name, 'Info', 'Title'), Level = addLv}), {});
				end
			end
		end
	end
	
	-- 회사 이름이 유효한지 테스트
	if company.CompanyName ~= company.InvalidCompanyName then
		local isValid, reason, reasonSub = IsValidCompanyName(company.CompanyName);
		if not isValid and reason == 'SystemToken' then
			dc:GiveSystemMailOneKey(company, 'CompanyName_SystemToken', false, { CompanyName = company.CompanyName, InvalidToken = reasonSub });
			dc:UpdateCompanyProperty(company, 'InvalidCompanyName', company.CompanyName);
			dc:UpdateCompanyProperty(company, 'LastNameChangeTime', 0);
			dc:Commit('CheckIsValidCompanyName');
		end
	end
	
	-- 활동 보고서
	if company.ActivityReportCounter > 0 and company.ActivityReportDuration > 0 and company.ActivityReportCounter >= company.ActivityReportDuration then
		ProgressDialog(ldm, nil, company, 'ActivityReport_Main', {});
	end	
	
	-- 메일 쓰기 활성화
	if StringToBool(company.LobbyMenu.ZoneMove.Opened, false) and not StringToBool(company.LobbyMenu.MailBox.Write, false) then
		ProgressDialog(ldm, nil, company, 'Pierto_Tutorial_ZoneMove_MailWrite');
	end
	
	-- 엔딩 이후 편지배달
	if company.Progress.Character.Albus == 29 and not company.Progress.Tutorial.ThankLetter then
		ProgressDialog(ldm, nil, company, 'Office_Episode_01_ThanksLetter');
	end
	
	-- 로비 가이드 트리거
	ProgressLobbyGuideTrigger(ldm, company, { EventType = 'LobbyEnter', EventArgs = { LobbyType = lobbyType }});	
end
function LobbyEnterPost(ldm, company, lobbyType)
	-- 회사 운영에 관련된 공용 로직을 로비 타입에 따라 비활성화함
	local lobbyCls = GetClassList('LobbyWorldDefinition')[lobbyType];
	if not lobbyCls.EnableCommonLobbyEnter then
		return;
	end

	if company.OfficeRentVill > 0 and company.OfficeRentDuration > 0 and company.OfficeRentCounter >= company.OfficeRentDuration + company.OfficeRentCountDelayCont then
		ProgressDialog(ldm, nil, company, 'OfficeRent_Main', {});
	end	
	local rosterList = GetAllRoster(company);
	for _, roster in ipairs(rosterList) do
		if roster.Salary > 0 and roster.SalaryDuration > 0 and roster.SalaryCounter >= roster.SalaryDuration + roster.SalaryCountDelayCont then
			ProgressDialog(ldm, nil, company, 'Salary_Main', {roster_name=roster.name});
		end
	end
	for _, roster in ipairs(rosterList) do
		if roster.Salary > 0 and roster.SalaryDuration > 0 and (not roster.SalaryNoticed) and roster.SalaryCounter + 1 == roster.SalaryDuration then
			ProgressDialog(ldm, nil, company, 'Salary_Notice', {roster_name=roster.name});
		end
	end
end
function LobbyEnter_Office(ldm, company)
	ProgressDialog(ldm, nil, company, 'Office_Main', {});
end
function LobbyEnter_Office_Albus(ldm, company)
	ProgressDialog(ldm, nil, company, 'Office_Albus_Main', {});
end
function LobbyEnter_Office_Night(ldm, company)
	ProgressDialog(ldm, nil, company, 'Office_Night_Main', {});
end
function LobbyEnter_ShooterStreet(ldm, company)
	ProgressDialog(ldm, nil, company, 'ShooterStreet_Main', {});
end
function LobbyEnter_LandOfStart(ldm, company)
	ProgressDialog(ldm, nil, company, 'LOS_Main', {});
end


--- return nil => 로비 진입 계속
--- return string, table of string => 로비 진입 중단 및 리턴 타입의 미션과 라인업으로 직행
function MasterLobbyPreenterMission_Script(company, lobbyType, dc)
	local func = _G['LobbyPreenterMission_' ..lobbyType];
	if func then
		return func(company, dc);
	end
	return nil, nil;
end

function LobbyPreenterMission_Office(company, dc)
	local openingStage = company.Progress.Tutorial.Opening;	
	if openingStage == 'CrowBill' then
		return 'Tutorial_CrowBill', {};
	elseif openingStage == 'SkipTutorial' then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'FireflyPark');
		dc:Commit('SkipTutorial');
		return 'Tutorial_FireflyPark', {};
	elseif openingStage == 'FireflyPark' then
		return 'Tutorial_FireflyPark', {};
	end
end
function LobbyPreenterMission_LandOfStart(company, dc)
	local openingStage = company.Progress.Tutorial.Opening;
	if openingStage == 'CrowBill' then
		return 'Tutorial_CrowBill', {};
	elseif openingStage == 'FireflyPark' then
		return 'Tutorial_FireflyPark', {};
	elseif openingStage == 'Silverlining' then
		return 'Tutorial_Silverlining', {};
	elseif openingStage == 'PugoStreet' then
		return 'Tutorial_PugoStreet', {};
	elseif openingStage == 'Road_113' then
		return 'Tutorial_Road_113', {};
	end
	return nil;
end

function MasterLobbyPreenterLobby_Script(company, lobbyType, dc)
	local func = _G['LobbyPreenterLobby_' ..lobbyType];
	if func then
		return func(company, dc);
	end
	return nil, nil;
end

function LobbyPreenterLobby_Office(company, dc)
	-- 1. 창고 강화, 분해 오픈.
	if (company.Progress.Tutorial.Office == 41 or company.Progress.Tutorial.Office == 42)
		and company.Office == 'Office_Silverlining_Workshop'
		and company.MissionCleared.Tutorial_BlueFogStreet
	then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office', 42);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 1);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('ItemUpgradeChangeLocation') then
			return 'Office_Night';
		end
	end
	-- 2. 시온 이벤트.
	if company.Progress.Character.Sion == 0
		and company.MissionCleared.Tutorial_PurpleStreet
	then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Sion', 1);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 2);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('SionAlbusConversation') then
			return 'Office_Night';
		end
	end
	-- 3. 사무실, 사수거리 공용 이벤트 처리
	local ret = LobbyPreenterLobby_CommonEvent(company, dc, 'Office');
	if ret then
		return ret;
	end
	return nil;
end
function LobbyPreenterLobby_ShooterStreet(company, dc)
	-- 1. 사무실, 사수거리 공용 이벤트 처리
	local ret = LobbyPreenterLobby_CommonEvent(company, dc, 'ShooterStreet');
	if ret then
		return ret;
	end
	return nil;
end
function LobbyPreenterLobby_Office_Night(company, dc)
	-- 까마귀 폐허 미션 - 승리 / 패배
	if company.Progress.Character.Heissing == 10 then
		ReserveChangeLocationCore(dc, company, 'Office');
		if dc:Commit('HeissingReturnConversation') then
			return 'Office';
		end
	end	
	return nil;
end

function LobbyPreenterLobby_CommonEvent(company, dc, location)
	-- 3. 재료 도감 열기.
	-- 제작대 오픈 이후.
	if not StringToBool(company.OfficeMenu.ItemBook.Opened, false)
		and StringToBool(company.OfficeMenu.TroublemakerList.Opened, false)
		and StringToBool(company.OfficeMenu.TroubleBook.Opened, false)
	then
		local eventEnabled = false;
		if company.Progress.Tutorial.ItemBook == 0 then
			-- 작업대 오픈 이후 제작을 1번이라도 했으면, 재료 도감 오픈 이벤트가 진행이 가능하게 처리
			-- 강화/분해/추출은 따로 경험치 정보가 없으므로, 패치 이전에 한 적이 있어도 어쩔 수가 없다.
			if StringToBool(company.WorkshopMenu.Upgrade.Opened) then
				for _, recipe in pairs(company.Recipe) do
					if recipe.Opened and recipe.Exp > 0 then
						eventEnabled = true;
						break;
					end
				end
			end
		elseif company.Progress.Tutorial.ItemBook <= 3 then
			eventEnabled = true;
		end
		if eventEnabled then
			dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ItemBook', 2);
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/ItemBookEvent', true);
			ReserveChangeLocationCore(dc, company, 'Office_Night');
			if dc:Commit('ItemBookConversation') then
				return 'Office_Night';
			end
		end
	end
	
	-- 4. 헤이싱, 앤 이벤트
	-- 잿빛 항구 H 물류 창고 완료 후.
	if company.Progress.Character.Anne == 5
		and company.Progress.Character.Heissing	== 7
		and company.MissionCleared.Tutorial_GrayPortWareHouse
	then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 3);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('AnneHeissingConversation') then
			return 'Office_Night';
		end
	end
	-- 5. 헤이싱, 알버스 이벤트
	-- 먼지바람 톨게이트 완료 후.
	if company.Progress.Character.Ray == 4 and company.MissionCleared.Tutorial_DustWind then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 4);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('AlbusHeissingConversation') then
			return 'Office_Night';
		end
	end
	-- 6. 알버스. 지젤. 앤 이벤트.
	-- 은빛구름시장거리 완료 후
	if company.Progress.Character.Albus == 10 and company.MissionCleared.Tutorial_DustWindRestArea then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', true);
		dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 5);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('AlbusGiselleAnneConversation') then
			return 'Office_Night';
		end
	end	
	-- 7. 헤이싱, 레이 이벤트
	-- 자홍거리 상점가 이후
	if company.Progress.Character.Heissing == 8 and company.MissionCleared.Tutorial_PurpleStreetAfter then
		dc:UpdateCompanyProperty(company, 'Progress/ZoneEnter/FadeInOut', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 6);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('RayHeissingConversation') then
			return 'Office_Night';
		end
	end
	-- 8. 알버스, 돈 이벤트
	-- 푸고샵 애프터 이후
	if company.Progress.Character.Albus == 17 and company.MissionCleared.Tutorial_PugoStreetAfter then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 7);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('AlbusDonConversation') then
			return 'Office_Night';
		end
	end
	
	-- 9. 레톤 영입 미션
	-- 레톤 영입 미션
	if company.Progress.Character.Leton == 2 and company.MissionCleared.Tutorial_GroundWaterSlum then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 8);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('LetonVisitConversation') then
			return 'Office_Night';
		end
	end	
	
	-- 10. 까마귀 폐허 미션	-- 헤이싱 이탈
	if company.Progress.Character.Heissing == 9 and company.MissionCleared.Tutorial_CrowRuinsAfter then
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 9);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('HeissingAbsentConversation') then
			return 'Office_Night';
		end
	end

	-- 11. 하늘바람 포장마차 완료
	if company.Progress.Character.Albus == 20 and company.MissionCleared.Tutorial_SkyBlueAfter then
		dc:UpdateCompanyProperty(company, 'Progress/ZoneEnter/FadeInOut', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 10);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('KylieAbsentConversation') then
			return 'Office_Night';
		end
	end

	-- 12. 미워도 다시 한번 완료.
	if company.Progress.Character.Albus == 23 and company.MissionCleared.Tutorial_PurpleStreet_Kylie then
		dc:UpdateCompanyProperty(company, 'Progress/ZoneEnter/FadeInOut', false);
		if location ~= 'Office' then
			ReserveChangeLocationCore(dc, company, 'Office');
		end
		if dc:Commit('RayGloomyConversation') then
			if location ~= 'Office' then
				return 'Office';
			end
		end
	end
	
	-- 13. 서로를 위해 완료.
	if company.Progress.Character.Albus == 25 and company.MissionCleared.Tutorial_TrainingRoomAfter then
		dc:UpdateCompanyProperty(company, 'Progress/ZoneEnter/FadeInOut', false);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office_Night', 11);
		ReserveChangeLocationCore(dc, company, 'Office_Night');
		if dc:Commit('DonReminiscenceConversation') then
			return 'Office_Night';
		end
	end
	return nil;
end
function GetLobbyEnterLoadingAndBGM(company, lobbyType)
	-- 밤 오피스.
	if lobbyType == 'Office_Night' then		
		if company.Progress.Character.Anne == 5	and company.Progress.Character.Heissing	== 7 and company.MissionCleared.Tutorial_GrayPortWareHouse 	then
			return 'Lobby_Office_HeissingAndAnne', 'Arrival';
		end
		if company.Progress.Character.Ray == 4 and company.MissionCleared.Tutorial_DustWind	then
			return 'Lobby_Office_HeissingAndRay', 'AloneTime';
		end
	end
	if lobbyType == 'Office' then
		if company.Progress.Character.Heissing == 10 then 
			return 'Lobby_Office_Heissing', 'FairyTale';
		end
	end	
end
local g_hiddenTechMap = nil;
function CheckSituationTechniqueHidden(company)
	if not g_hiddenTechMap then
		g_hiddenTechMap = {};
		local techList = GetClassList('Technique');
		for _, tech in pairs(techList) do
			for _, unlockTech in ipairs(tech.UnLockTechnique) do
				g_hiddenTechMap[unlockTech] = true;
			end
		end
	end
	
	for key, _ in pairs(g_hiddenTechMap) do
		if company.Technique[key].Opened then
			return true;
		end		
	end
	return false;
end
function CheckStorySkyWindParkAllSelect(company)
	if company.Progress.Character.GiselleTraining == 0		-- 알버스
		or not company.Technique.Hysterie.Opened 			-- 시온
		or not company.Technique.HeroResponsibility.Opened	-- 아이린
		or not company.Technique.Waiting.Opened				-- 앤
		or company.Progress.Character.Kylie == 2			-- 헤이싱
		or not company.Technique.ColdRefusal.Opened			-- 레이
	then
		return false;
	end
	return true;
end
function CheckSituationFirstMachine(company)
	local machineList = GetAllRoster(company, 'Machine');
	if #machineList > 0 then
		return true;
	end
	return false;
end
function MakeMissionClearTester(missionType)
	return function(company) return company.MissionCleared[missionType] end;
end
local g_checkAchievementFuncs = {
	StoryTroubleshooter = function(company) return GetRoster(company, 'Albus') ~= nil; end,
	StoryOfficeAlbus = function(company) return company.Progress.Tutorial.Roster >= 12; end,
	StoryOfficeSilverlining = function(company) return company.Office ~= 'Office_Albus'; end,
	StoryRamjiPlaza = function(company) return company.Progress.Tutorial.Office >= 20; end,
	StoryPugoStreet = function(company) return GetRoster(company, 'Sion') ~= nil; end,
	StoryConstructionA = function(company) return company.Progress.Character.Irene >= 2; end,
	StoryRoad113 = function(company) return company.Progress.Character.Pierto >= 1; end,
	StoryCrowBillAfter = function(company) return company.Progress.Character.Irene >= 3; end,
	StoryPugoShop = function(company) return company.Progress.Character.Heissing >= 2; end,
	StoryPurpleBackStreet = function(company) return company.Progress.Character.Issac >= 2; end,
	StoryPugoBackStreet = function(company) return company.Progress.Character.Sharky >= 2; end,
	StoryHansando = function(company) return company.Progress.Character.Kylie >= 1; end,
	StoryGrayCemeteryPark = function(company) return company.Progress.Character.Anne >= 4; end,
	StoryLokoCabin = function(company) return company.Progress.Character.Issac >= 6; end,
	StoryOrsay = function(company) return company.Progress.Character.Danny >= 1; end,
	StoryLasa = function(company) return company.Progress.Character.Ryo >= 1; end,
	StorySkyBlue = function(company) return company.Progress.Character.Issac >= 7; end,
	StoryPurpleStreet = function(company) return company.Progress.Character.Ryo >= 2 end,
	StoryPugoShopAfter = function(company) return company.Progress.Character.Heissing >= 3 end,
	StoryRoad112 = function(company) return company.MissionCleared.Tutorial_Road_112 end,
	StoryMetroStreet = function(company) return company.MissionCleared.Tutorial_MetroStreet end,
	StoryStarStreet = function(company) return company.MissionCleared.Tutorial_StarStreet end,
	StoryCrescentBridge = function(company) return company.MissionCleared.Tutorial_CrescentBridge end,
	StoryGrayPortWareHouse = function(company) return company.MissionCleared.Tutorial_GrayPortWareHouse end,
	StorySkyWindPark = function(company) return company.MissionCleared.Tutorial_SkyWindPark end,
	StoryTrainingRoom = function(company) return company.MissionCleared.Tutorial_TrainingRoom end,
	StoryPugoBackStreetAfter = function(company) return company.MissionCleared.Tutorial_PugoBackStreetAfter end,
	StoryRoad111 = function(company) return company.MissionCleared.Tutorial_Road_111 end,
	StoryDustWindRestArea = MakeMissionClearTester('Tutorial_DustWindRestArea'),
	SituationTechniqueHidden = CheckSituationTechniqueHidden,
	StoryGrayCemeteryParkAfter = MakeMissionClearTester('Tutorial_GrayCemeteryParkAfter'),
	ChallengeSkyWindParkAllSelect = CheckStorySkyWindParkAllSelect,
	StoryMarketStreet = MakeMissionClearTester('Tutorial_MarketStreet'),
	StoryRoad110 = function(company) return company.MissionCleared.Tutorial_Road_110 end,
	SituationFirstMachine = CheckSituationFirstMachine,
	StoryPurpleStreetAfter = MakeMissionClearTester('Tutorial_PurpleStreetAfter'),
	StoryCrowRuins = MakeMissionClearTester('Tutorial_CrowRuins'),
	StoryCrowRuinsAfter = MakeMissionClearTester('Tutorial_CrowRuinsAfter'),
	StoryPugoStreetAfter = MakeMissionClearTester('Tutorial_PugoStreetAfter'),
	StoryWasteBuilding = MakeMissionClearTester('Tutorial_WasteBuilding'),
	StoryGroundWaterSlum = MakeMissionClearTester('Tutorial_GroundWaterSlum'),
	RosterIrene = function(company) return GetRoster(company, 'Irene') ~= nil; end,
	RosterAnne = function(company) return GetRoster(company, 'Anne') ~= nil; end,
	RosterHeissing = function(company) return GetRoster(company, 'Heissing') ~= nil; end,
	RosterRay = function(company) return GetRoster(company, 'Ray') ~= nil; end,
	RosterGiselle = function(company) return GetRoster(company, 'Giselle') ~= nil; end,
	RosterKylie = function(company) return GetRoster(company, 'Kylie') ~= nil; end,
	RosterLeton = function(company) return GetRoster(company, 'Leton') ~= nil; end,
	ChallengeDrakyNestFindWay = function(company) return company.Progress.Mission.DrakyNest end,
	StoryCrowRuinsAfterAlley = MakeMissionClearTester('Tutorial_CrowRuinsAfter_Alley'),
	StorySkyBlueAfter = MakeMissionClearTester('Tutorial_SkyBlueAfter'),
	StoryPurpleStreetKylie = MakeMissionClearTester('Tutorial_PurpleStreet_Kylie'),
	StoryTrainingRoomAfter = MakeMissionClearTester('Tutorial_TrainingRoomAfter'),
	StorySilverliningAfter = MakeMissionClearTester('Tutorial_SilverliningAfter'),
	StoryWhiteTigerBase = MakeMissionClearTester('Tutorial_WhiteTigerBase'),
	SituationIreneKillLuna = function(company) return company.GuideTrigger.KillAchievement_IreneLuna.Pass end,
	SituationAlbusKillGiselle = function(company) return company.GuideTrigger.KillAchievement_AlbusGiselle.Pass end,
	SituationAnneKillAlbus = function(company) return company.GuideTrigger.KillAchievement_AnneAlbus.Pass end,
	SituationAnneKillIrene = function(company) return company.GuideTrigger.KillAchievement_AnneIrene.Pass end,	
};

function CheckAchievements(ldm, company, dc)
	local needCommit = false;
	for name, checkFunc in pairs(g_checkAchievementFuncs) do
		if not company.CheckAchievements[name] and checkFunc(company) then
			ldm:UpdateSteamAchievement(name, true);
			dc:UpdateCompanyProperty(company, string.format('CheckAchievements/%s', name), true);
			needCommit = true;
		end
	end
	-- 트러블메이커 업적 자동 체크 (AchievementCheckFunc가 없는 것만)
	for _, tmInfo in pairs(company.Troublemaker) do
		local achievement = SafeIndex(tmInfo.Achievement, 'name');
		if achievement and achievement ~= 'None' then
			if not company.CheckAchievements[achievement] and tmInfo.AchievementCheckFunc == 'None' and tmInfo.IsKill then
				ldm:UpdateSteamAchievement(achievement, true);
				dc:UpdateCompanyProperty(company, string.format('CheckAchievements/%s', achievement), true);
				needCommit = true;
			end
		end
	end
	if company.Stats.TamingSuccessCount < company.BeastIndex then
		dc:UpdateCompanyProperty(company, 'Stats/TamingSuccessCount', company.BeastIndex);
		needCommit = true;
	end
	if needCommit then
		dc:Commit('CheckAchievements');
	end
end

function CheckDataErrors(ldm, company, dc)
	local needCommit = false;
	-- 괴수 사냥꾼
	if company.GuideTrigger.GiantKiller.Pass and not company.Technique.GiantKiller.Opened then
		dc:AcquireMastery(company, 'GiantKiller', 1);
		needCommit = true;
	end
	
	if needCommit then
		dc:Commit('CheckDataErrors');
	end
end

function EnterLobbySystemNoticeCheck(company)
	local worldProperty = GetWorldProperty();
	
	-- 치안도 피버
	local noticeType = 'SafetyFeverNow';
	local zoneState = worldProperty.ZoneState;
	if IsSingleplayMode() then
		noticeType = 'SafetyFeverNow_Single';
		zoneState = company.ZoneState;
	end
	
	local userZone = GetClassList('LobbyWorldDefinition')[GetUserLocation(company)].Zone.name;
	if zoneState[userZone].SafetyFever then
		local feverTime = zoneState[userZone].FeverTime;
		SendSystemNotice(company, noticeType, {ZoneName=userZone, OffsetTime = feverTime + GetSystemConstant('ZONE_SAFETY_FEVER_DURATION'), LeftMissionCount = company.ActivityReportDuration - company.ActivityReportCounter});
	end
end
function CheckRosterJobLevel(ldm, company, dc)
	local rosterList = GetAllRoster(company, 'All');
	
	-- 처음 접속 시, 현재 레벨에 따른 클래스 레벨 보정
	if company.NeedAdjustJobLv then
		for _, roster in ipairs(rosterList) do
			if roster.RosterType == 'Pc' then
				local rosterCls = GetClassList('Pc')[roster.name];
				local startLv = rosterCls.Lv;
				local startJob = rosterCls.Object.Job.name;
				local addLv = roster.Lv - startLv;
				if addLv > 0 then			
					local jobKey = string.format('EnableJobs/%s/Lv', startJob);
					local expKey = string.format('EnableJobs/%s/Exp', startJob);
					
					local jobLv = 1;
					local jobExp = 0;
					if addLv >= 11 then
						jobLv = 10;
					elseif addLv >= 7 then
						jobLv = 8;
					elseif addLv >= 4 then
						jobLv = 6;
					end
					
					local prevJobLv = SafeIndex(roster, unpack(string.split(jobKey, '/')));
					if jobLv > prevJobLv then
						dc:UpdatePCProperty(roster, jobKey, jobLv);
						dc:UpdatePCProperty(roster, expKey, jobExp);
					end
				end
			end
		end
		dc:UpdateCompanyProperty(company, 'NeedAdjustJobLv', false);
		dc:Commit('NeedAdjustJobLv');
	end	

	-- 클래스 레벨에 따른 보상 특성 중에 언락이 안 된 것이 남아있으면 
	-- 직업 개방에 따른 추가 특성판
	local updateTechnique = false;
	for _, roster in ipairs(rosterList) do
		local rewardMasteries = {};
		if roster.RosterType == 'Pc' then
			local extraBoard = 0;
			local enableJobs = roster.EnableJobs;
			for jobName, job in pairs(enableJobs) do
				local rosterCls = GetClassList('Pc')[roster.name];
				local startJob = rosterCls.Object.Job.name;
				local isOpened = false;
				if jobName == startJob then
					isOpened = true;
				elseif IsSatisfiedChangeClass(roster, jobName) and (job.Lv > 1 or job.LastLv > 0) then
					isOpened = true;
				end
				if isOpened then
					table.append(rewardMasteries, GetRewardMasteriesByJobLevel(company, roster, jobName, 1, job.Lv));
				end
				if isOpened and StringToBool(job.ExtraMasteryBoard) then
					extraBoard = extraBoard + 1;
					dc:UpdatePCProperty(roster, string.format('EnableJobs/%s/ExtraMasteryBoard', jobName), false);
				end
			end
			if extraBoard > 0 then
				dc:AddPCProperty(roster, 'MasteryBoard/ExtraCount', extraBoard);
			end
		elseif roster.RosterType == 'Beast' then
			rewardMasteries = GetRewardMasteriesByJobLevel_Beast(company, roster, roster.LastJobLv, roster.JobLv);
			if #rewardMasteries > 0 then
				dc:UpdatePCProperty(roster, 'LastJobLv', roster.JobLv);
			end
		elseif roster.RosterType == 'Machine' then
			rewardMasteries = GetRewardMasteriesByJobLevel_Machine(company, roster, roster.LastJobLv, roster.JobLv);
			if #rewardMasteries > 0 then
				dc:UpdatePCProperty(roster, 'LastJobLv', roster.JobLv);
			end
		end
		updateTechnique = updateTechnique or #rewardMasteries > 0;
		for _, mastery in ipairs(rewardMasteries) do
			local techName = mastery.name;
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', techName), true);
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', techName), true);
		end
	end
	if updateTechnique then
		dc:Commit('UpdateTechniqueByJobLevel');
	end
end
function CheckMasterySetIndex(ldm, company, dc)
	local rosterList = GetAllRoster(company, 'All');
	for _, roster in ipairs(rosterList) do
		for i = 1, roster.MasteryBoard.Count do
			local boardIndex = i - 1;
			local masteryTable = GetMastery(roster, boardIndex);
			for k, mastery in pairs(masteryTable) do
				if mastery.Lv > 0 and mastery.Category.name == 'Set' then
					local open = company.MasterySetIndex[mastery.name];
					if open == false then
						dc:UpdateCompanyProperty(company, 'MasterySetIndex/'..mastery.name, true);
						-- 중복 방지를 위한 수동 업데이트
						company.MasterySetIndex[mastery.name] = true;
						local formatTable = {
							MasteryName = ClassDataText('Mastery', k, 'Title'),
						};
						local text = FormatMessageText(GuideMessageText('MasterySetAvailableByUpdate'), formatTable);
						ldm:ShowFrontmessageWithText(text);
						ldm:AddChat('Notice', RemoveTagText(text));
					end
				end
			end
		end
	end
		
	-- 트러블메이커 특성 세트 언락
	for key, cls in pairs(GetClassList('MasterySet')) do
		(function()
			if not company.MasterySetIndex[key] then
				local troublemakers = cls.HavingTroublemakers;
				for troublemaker, _ in pairs(troublemakers) do
					if GetTroublemakerInfoGrade(company.Troublemaker[troublemaker]) >= 4 then
						dc:UpdateCompanyProperty(company, string.format('MasterySetIndex/%s', key), true);
						local monCls = GetClassList('Monster')[troublemaker];
						local formatTable = {
							MasteryName = ClassDataText('Mastery', key, 'Title'),
							TroublemakerName = ClassDataText('ObjectInfo', monCls.Info.name, 'Title'),
						};
						ldm:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('MasterySetAvailableByTroublemaker'), formatTable));
						ldm:AddChat('Notice', FormatMessageText(GuideMessageText('MasterySetAvailableByTroublemakerChat'), formatTable), {});
						return;
					end
				end
			end
		end)();
	end
	dc:Commit('AutoMasterySetIndexUpdate');
end
function CheckTechniqueUnlock(ldm, company, dc)
	for _, tech in pairs(company.Technique) do
		if tech.Opened and tech.Researched then
			for _, unlockTech in ipairs(tech.UnLockTechnique) do
				local curUnlockTechnique = company.Technique[unlockTech];
				if curUnlockTechnique and curUnlockTechnique.name ~= nil then
					if not curUnlockTechnique.Opened then
						dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', curUnlockTechnique.name), true);
						dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', curUnlockTechnique.name), true);
					end
				end
			end
		end
	end
	
	-- 에러 코렉션
	local testTechniques = {};
	if company.MissionCleared.Tutorial_PugoStreet then
		table.insert(testTechniques, 'Consideration');
		table.insert(testTechniques, 'Challenger');
	end
	-- 제작서 언락
	if company.Progress.Tutorial.MachineCraft >= 3 then
		table.append(testTechniques, { 'TrainingManualModule', 'TrainingManualModule2', 'TrainingManualModule3', 'TrainingManualModule4' });
	end
	for _, testTech in ipairs(testTechniques) do
		if not company.Technique[testTech].Opened then
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/Opened', testTech), true);
			dc:UpdateCompanyProperty(company, string.format('Technique/%s/IsNew', testTech), true);
		end
	end
	dc:Commit('CheckTechniqueUnlock');
end
function CheckRecipeUnlock(ldm, company, dc)
	for _, recipe in pairs(company.Recipe) do
		if recipe.Opened and recipe.Exp >= recipe.MaxExp then
			for _, unlockRecipeName in ipairs(recipe.UnLockRecipe) do
				local unlockRecipe = GetWithoutError(company.Recipe, unlockRecipeName);
				if unlockRecipe and not unlockRecipe.Opened then
					dc:UpdateCompanyProperty(company, string.format('Recipe/%s/Opened', unlockRecipeName), true);
					dc:UpdateCompanyProperty(company, string.format('Recipe/%s/IsNew', unlockRecipeName), true);
				end
			end
		end
	end
	dc:Commit('CheckRecipeUnlock');
end
function CheckCostumeSystemMail(ldm, company, dc)
	local updateSystemMail = false;
	local systemMailList = GetClassList('SystemMail');
	local rosterList = GetAllRoster(company);
	for _, roster in ipairs(rosterList) do
		local costumeMailName = 'ItemSupply_Costume_'..roster.name;
		local costumeMailCls = systemMailList[costumeMailName];
		if costumeMailCls ~= nil and not company.SystemMailReceived[costumeMailName] then
			dc:GiveSystemMailOneKey(company, costumeMailName, true);
			dc:UpdateCompanyProperty(company, string.format('SystemMailReceived/%s', costumeMailName), true);
			updateSystemMail = true;
		end
	end
	if updateSystemMail then
		dc:Commit('CheckCostumeSystemMail');
	end
end
function CheckBeastActiveAbility(ldm, company, dc)
	local needCommit = false;
	local rosterList = GetAllRoster(company, 'Beast');	
	for _, pcInfo in ipairs(rosterList) do
		local beastType = GetWithoutError(pcInfo, 'BeastType');
		local availableAbilities = {};
		local startAbilities = {};
		for __, abilitySlot in ipairs(beastType.Abilities) do
			if abilitySlot.RequireLv <= pcInfo.JobLv and availableAbilities[abilitySlot.Name] == nil then
				availableAbilities[abilitySlot.Name] = true;
			end
			if abilitySlot.RequireLv <= 1 and StringToBool(abilitySlot.Default) and startAbilities[abilitySlot.Name] == nil then
				startAbilities[abilitySlot.Name] = true;
			end
		end
		
		-- 유효하지 않은 어빌리티 해제
		local activeAbilitySet = table.map(pcInfo.ActiveAbility, function (v) return v; end);
		for abilityName, isActive in pairs(activeAbilitySet) do
			if isActive and not availableAbilities[abilityName] then
				dc:UpdatePCProperty(pcInfo, string.format('ActiveAbility/%s', abilityName), false);
				activeAbilitySet[abilityName] = false;
				needCommit = true;
			end
		end
		
		-- 활성화된 어빌리티가 하나도 없으면 리셋
		local activeAbilityCount = 0;
		for _, isActive in pairs(activeAbilitySet) do
			if isActive then
				activeAbilityCount = activeAbilityCount + 1;
			end
		end
		if activeAbilityCount == 0 then
			for abilityName, _ in pairs(startAbilities) do
				dc:UpdatePCProperty(pcInfo, string.format('ActiveAbility/%s', abilityName), true);
				needCommit = true;
			end
		end
	end
	if needCommit then
		dc:Commit('CheckBeastActiveAbility');
	end
end
function CheckMachineInvalidMastery(ldm, company, dc)
	local needCommit = false;
	
	local checkCategorySet = {};
	local masteryCategoryList = GetClassList('MasteryCategory');
	for _, masteryCategory in pairs(masteryCategoryList) do
		if masteryCategory.EquipSlot ~= 'None' then
			local isMachine = false;
			for _, race in ipairs(masteryCategory.EnableRace) do
				if race.name == 'Machine' then
					isMachine = true;
					break;
				end
			end
			if not isMachine then
				checkCategorySet[masteryCategory.name] = true;
			end
		end
	end
	
	local rosterList = GetAllRoster(company, 'Machine');	
	for _, pcInfo in ipairs(rosterList) do
		for i = 1, pcInfo.MasteryBoard.Count do
			local boardIndex = i - 1;
			local masteryTable = GetMastery(pcInfo, boardIndex);
			for _, mastery in pairs(masteryTable) do
				if checkCategorySet[mastery.Category.name] then
					-- 1) 로스터 마스터리 레벨 초기화
					dc:UpdateMasteryLv(pcInfo, mastery.name, 0, boardIndex);
					-- 2) 회사 마스터리 카운트 증가
					dc:AcquireMastery(company, mastery.name, 1, true);
					needCommit = true;
				end
			end
		end
	end
	if needCommit then
		dc:Commit('CheckMachineInvalidMastery');
	end
end
function CheckWeaponCostumeUnlock(ldm, company, dc)
	if not company.WeaponCostumeOpened then
		return;
	end

	local opened = {};
	
	local allItems = GetAllItems(company);
	for i, item in ipairs(allItems) do
		if item.Category.name == 'Weapon' then
			local costume = GetWithoutError(item, 'UnlockWeaponCostume');
			if costume then
				opened[costume] = true;
			end
		end
	end
	local allWareItems = GetAllWareItems(company);
	for i, item in ipairs(allWareItems) do
		if item.Category.name == 'Weapon' then
			local costume = GetWithoutError(item, 'UnlockWeaponCostume');
			if costume then
				opened[costume] = true;
			end
		end
	end
	local rosters = GetAllRoster(company, 'Pc');
	for i, pcInfo in ipairs(rosters) do
		local item = SafeIndex(pcInfo, 'Object', 'Weapon');
		if item then
			local costume = GetWithoutError(item, 'UnlockWeaponCostume');
			if costume then
				opened[costume] = true;
			end
		end
	end
	
	local needCommit = false;
	for key, _ in pairs(opened) do
		if not company.WeaponCostume[key].Opened then
			dc:UpdateCompanyProperty(company, string.format('WeaponCostume/%s/Opened', key), true);
			needCommit = true;
		end
	end
	if needCommit then
		dc:Commit('CheckWeaponCostumeUnlock');
	end
end

function CheckAsiaServerErrorReward(ldm, company, dc)
	if not company.NeedAsiaServerErrorReward then
		return;
	end

	local maxLv = 0;
	local rosters = GetAllRoster(company, 'Pc');
	for i, pcInfo in ipairs(rosters) do
		maxLv = math.max(maxLv, pcInfo.Lv);
	end
	LogAndPrint('CheckAsiaServerErrorReward - company:', company.CompanyName, ', maxLv:', maxLv);
	if maxLv <= 0 then
		return;
	end	
	
	-- 3레벨 보정
	maxLv = math.min(maxLv + 3, 50);
	
	local allRosters = GetAllRoster(company, 'All');
	for _, pcInfo in ipairs(allRosters) do
		-- 3레벨 증가
		local curLv = pcInfo.Lv;
		local nextLv = math.min(curLv + 3, 50);
		if nextLv > curLv then
			LogAndPrint(string.format(' - %s Lv: %d -> %d', pcInfo.RosterKey, curLv, nextLv));
			dc:UpdatePCProperty(pcInfo, 'Lv', nextLv);
		end
		-- 직업레벨 16렙
		local targetjob = pcInfo.Object.Job.name;
		local targetKey, expKey;
		if pcInfo.RosterType == 'Pc' then
			targetKey = string.format('EnableJobs/%s/Lv', targetjob);
			expKey = string.format('EnableJobs/%s/Exp', targetjob);
		elseif pcInfo.RosterType == 'Beast' or pcInfo.RosterType == 'Machine' then
			targetKey = 'JobLv';
			expKey = 'JobExp';
		end
		local prevJobLv = SafeIndex(pcInfo, unpack(string.split(targetKey, '/')));
		local prevJobExp = SafeIndex(pcInfo, unpack(string.split(expKey, '/')));
		if prevJobLv < 16 then
			LogAndPrint(string.format(' - %s JobLv: %d, %d -> 16, 0', pcInfo.RosterKey, prevJobLv, nextLv));
			dc:UpdatePCProperty(pcInfo, targetKey, 16);
			dc:UpdatePCProperty(pcInfo, expKey, 0);
		end
	end
	
	-- 빌 지급
	local vill = 0;
	if maxLv <= 10 then
		vill = 250000;
	elseif maxLv <= 20 then
		vill = 500000;	
	elseif maxLv <= 30 then
		vill = 1000000;
	elseif maxLv <= 40 then
		vill = 1500000;
	elseif maxLv <= 50 then
		vill = 2000000;
	end
	LogAndPrint(string.format(' - Vill: +%d', vill));
	dc:AddCompanyProperty(company, 'Vill', vill);
	
	-- 훈련서 지급
	local count = 0;
	if maxLv <= 10 then
		count = 1000;
	elseif maxLv <= 20 then
		count = 1000;	
	elseif maxLv <= 30 then
		count = 1000;
	elseif maxLv <= 40 then
		count = 1000;
	elseif maxLv <= 50 then
		count = 1000;
	end
	LogAndPrint(string.format(' - Statement_Mastery: +%d', count));
	dc:GiveItem(company, 'Statement_Mastery', count, true);
	
	-- 아이템 지급
	local itemLv = {};
	if maxLv <= 10 then
		itemLv = {};
	elseif maxLv <= 20 then
		itemLv = { 15, 20 };	
	elseif maxLv <= 30 then
		itemLv = { 25, 30 };
	elseif maxLv <= 40 then
		itemLv = { 35, 40 };
	elseif maxLv <= 50 then
		itemLv = { 45 };
	end
	
	local itemList = GetClassList('Item');
	local itemLvList = {};
	for k, itemCls in pairs(itemList) do
		if (itemCls.Category.name == 'Weapon' or itemCls.Category.name == 'Armor') and itemCls.Rank.name == 'Epic' then
			local lv = itemCls.RequireLv;
			if itemLvList[lv] == nil then
				itemLvList[lv] = {};
			end
			table.insert(itemLvList[lv], itemCls);
		end
	end
	
	for _, pcInfo in ipairs(rosters) do
		for _, lv in ipairs(itemLv) do
			local weapons = table.filter(itemLvList[lv] or {}, function(itemCls)
				for _, enableEquipWeapon in ipairs (pcInfo.Object.EnableEquipWeapon) do
					if itemCls.Type.name == enableEquipWeapon then
						return true;
					end
				end
				return false;
			end);
			local armors = table.filter(itemLvList[lv] or {}, function(itemCls)
				for _, enableEquipBody in ipairs (pcInfo.Object.EnableEquipBody) do
					if itemCls.Type.name == enableEquipBody then
						return true;
					end
				end
				return false;
			end);
			LogAndPrint(pcInfo.name, lv);
			LogAndPrint('- weapons:', table.map(weapons or {}, function(itemCls) return itemCls.name end));
			LogAndPrint('- armors:', table.map(armors or {}, function(itemCls) return itemCls.name end));
			for _, itemCls in ipairs(weapons) do
				dc:GiveItem(company, itemCls.name, 10, true);
			end
			for _, itemCls in ipairs(armors) do
				dc:GiveItem(company, itemCls.name, 10, true);
			end
		end
	end
	
	-- 추가 세트 아이템 제작 재료
	if maxLv >= 41 then
		local rewardList = {};
		local setList = { 'GoldNeguriESPSet', 'GoldNeguriAttackSet' };
		for _, setName in ipairs(setList) do
			local setCls = GetClassList('ItemSet')[setName];
			for i = 1, 5 do
				local itemName = setCls[string.format('Item%d', i)];
				LogAndPrint('i:', i, ', itemName:', itemName);
				local recipeCls = GetClassList('Recipe')[itemName];
				for _, matInfo in pairs(recipeCls.RequireMaterials) do
					rewardList[matInfo.Item] = (rewardList[matInfo.Item] or 0) + 10 * matInfo.Amount;
				end
			end
		end
		LogAndPrint('rewardList:', rewardList);
		for itemName, itemCount in pairs(rewardList) do
			dc:GiveItem(company, itemName, itemCount, true);
		end
	end
		
	dc:UpdateCompanyProperty(company, 'NeedAsiaServerErrorReward', false);
	dc:Commit('CheckAsiaServerErrorReward');
end