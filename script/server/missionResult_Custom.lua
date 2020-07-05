----------------------------------------------------------------------------
-- 커스텀 미션 결과 프로퍼티 적용 부분.
----------------------------------------------------------------------------
function MissionResult_Custom_Tutorial_CrowBill(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then 
		if tutorialProgress == 'CrowBill' then
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'FireflyPark');
			dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'LandOfStart');
		end
	end
end
function MissionResult_Custom_Tutorial_FireflyPark(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then 
		if tutorialProgress == 'FireflyPark' then
		
			local missionValue_Albus_Selection = GetStageVariable(mission, 'Albus_Selection');
			local missionValue_Jean_Selection = GetStageVariable(mission, 'Jean_Selection');
			-- 장의 선택
			if missionValue_Jean_Selection == 1 then
				-- 긍정적인 마인드
				dc:AcquireMastery(company, 'PositiveMind', 1);
				dc:UpdateCompanyProperty(company, 'Technique/Ambush/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/Ambush/IsNew', true);
			elseif missionValue_Jean_Selection == 2 then
				-- 기습
				dc:AcquireMastery(company, 'Ambush', 1);
				dc:UpdateCompanyProperty(company, 'Technique/PositiveMind/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/PositiveMind/IsNew', true);
			end
			if missionValue_Albus_Selection == 1 then
				-- 인내심
				dc:AcquireMastery(company, 'Patience', 1);
				dc:UpdateCompanyProperty(company, 'Technique/PangOfConscience/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/PangOfConscience/IsNew', true);
			elseif missionValue_Albus_Selection == 2 then
				-- 양심의 가책
				dc:AcquireMastery(company, 'PangOfConscience', 1);
				dc:UpdateCompanyProperty(company, 'Technique/Patience/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/Patience/IsNew', true);
			end
			-- 능숙함 주기.
			dc:AcquireMastery(company, 'Deftness', 1);
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'CompanyName');
			dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'LandOfStart');
			dc:UpdateCompanyProperty(company, 'MissionCleared/Tutorial_FireflyPark_Roster', true);
		end
	end
end
function MissionResult_Custom_Tutorial_Silverlining(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then 
		if tutorialProgress == 'Silverlining' then
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'OfficeContract');
			dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'LandOfStart');
			dc:UpdateCompanyProperty(company, 'ActivityReport/Unlock', true);
			dc:GiveSystemMailOneKey(company, 'Javier02');
			
			-- 유저의 선택
			local missionValue_SelectionPlayType = GetStageVariable(mission, 'SelectionPlayType');
			if missionValue_SelectionPlayType == 1 then
				-- 돈이 전화 - 
				dc:AcquireMastery(company, 'Supporter', 1);
				dc:UpdateCompanyProperty(company, 'Technique/Alacrity/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/Alacrity/IsNew', true);
				dc:UpdateCompanyProperty(company, 'Technique/HighSpeed/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/HighSpeed/IsNew', true);
			elseif missionValue_SelectionPlayType == 2 then
				-- 알버스 전화 -
				dc:AcquireMastery(company, 'Alacrity', 1);
				dc:UpdateCompanyProperty(company, 'Technique/Supporter/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/Supporter/IsNew', true);
				dc:UpdateCompanyProperty(company, 'Technique/HighSpeed/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/HighSpeed/IsNew', true);
			elseif missionValue_SelectionPlayType == 3 then
				-- 전파방해기 모두 파괴 - 신속
				dc:AcquireMastery(company, 'HighSpeed', 1);
				dc:UpdateCompanyProperty(company, 'Technique/Supporter/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/Supporter/IsNew', true);
				dc:UpdateCompanyProperty(company, 'Technique/Alacrity/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/Alacrity/IsNew', true);
			else
				dc:UpdateCompanyProperty(company, 'Technique/Alacrity/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/Alacrity/IsNew', true);
				dc:UpdateCompanyProperty(company, 'Technique/Supporter/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/Supporter/IsNew', true);
				dc:UpdateCompanyProperty(company, 'Technique/HighSpeed/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/HighSpeed/IsNew', true);				
			end
		end
	else
		-- 패배 시.
		if tutorialProgress == 'Silverlining' then
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'Silverlining_Lose');
		end
	end
end
function MissionResult_Custom_Tutorial_RamjiPlaza(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then 
		if tutorialProgress == 'RamjiPlaza' then
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'RamjiPlaza_Win');
			
			-- 상황에 따른 정보 넣기.			
			local missionValue_Anne = GetStageVariable(mission, 'Anne');
			local missionValue_EventIrene = GetStageVariable(mission, 'EventIrene');
			local missionValue_EventAlley = GetStageVariable(mission, 'EventAlley');
			local missionValue_Selection_Alley = GetStageVariable(mission, 'Selection_Alley');
			local missionValue_EventTraveler = GetStageVariable(mission, 'EventTraveler');
			local missionValue_Selection_Traveler = GetStageVariable(mission, 'Selection_Traveler');
			
			if missionValue_EventIrene > 0 then
				dc:UpdateCompanyProperty(company, 'Progress/Character/Irene', 1);
			end		
			if missionValue_EventAlley > 0 then
				dc:UpdateCompanyProperty(company, 'Progress/Selection/RamJi_Selection_Alley', missionValue_Selection_Alley);
				dc:UpdateCompanyProperty(company, 'Progress/Character/Ray', 1);
				dc:UpdateCompanyProperty(company, 'Progress/Character/Leton', 1);
			end
			if missionValue_EventTraveler > 0 then
				dc:UpdateCompanyProperty(company, 'Progress/Selection/RamJi_Selection_Traveler', missionValue_Selection_Traveler);
				dc:UpdateCompanyProperty(company, 'Progress/Character/Alisa', 1);
				dc:UpdateCompanyProperty(company, 'Progress/Character/Bianca', 1);
			end
			if missionValue_Anne > 0 then
				dc:UpdateCompanyProperty(company, 'Progress/Character/Anne', 1);
			end
		end
	else
		-- 패배 시.
		if tutorialProgress == 'RamjiPlaza' then
			dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'RamjiPlaza_Lose');
		end
	end
end
function MissionResult_Custom_Tutorial_PugoStreet(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then 
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'ScoutSion');
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office', 21);
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'LandOfStart');
		
		local missionValue_SionSelect = GetStageVariable(mission, 'SionSelect');
		if missionValue_SionSelect == 1 then
			-- 시온 받아들인다. 
			dc:AcquireMastery(company, 'Challenger', 1);
			dc:UpdateCompanyProperty(company, 'Technique/Consideration/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/Consideration/IsNew', true);
		elseif missionValue_SionSelect == 2 then
			-- 시온 거절한다.
			dc:AcquireMastery(company, 'Consideration', 1);
			dc:UpdateCompanyProperty(company, 'Technique/Challenger/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/Challenger/IsNew', true);
		else
			-- 그 외
			dc:UpdateCompanyProperty(company, 'Technique/Consideration/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/Consideration/IsNew', true);
			dc:UpdateCompanyProperty(company, 'Technique/Challenger/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/Challenger/IsNew', true);
		end		
	else
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'PugoStreet_Lose');
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Office', 21);
	end
end
function MissionResult_Custom_Tutorial_Construction_A(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Irene', 2);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Sharky', 1);
	end
end
function MissionResult_Custom_Tutorial_Road_113(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then
		local missionValue_HeissingRunaway = GetStageVariable(mission, 'HeissingRunaway');
		if missionValue_HeissingRunaway ~= 1 then
			dc:UpdateCompanyProperty(company, 'Progress/Character/Heissing', 1);		
		end
		dc:UpdateCompanyProperty(company, 'Progress/Character/Pierto', 1);
	end
end
function MissionResult_Custom_Tutorial_CrowBillAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Irene', 3);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Issac', 1);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Anne', 2);
	end
end
function MissionResult_Custom_Tutorial_PugoShop(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Heissing', 2);	
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'PugoShop_Win');
	else
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'PugoShop_Lose');
	end
end
function MissionResult_Custom_Tutorial_PurpleBackStreet(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then
		local missionValue_Irene = GetStageVariable(mission, 'Irene'); 
		if missionValue_Irene == 7 then
			-- 자홍거리에서 아이린 만남
			dc:UpdateCompanyProperty(company, 'Progress/Character/Irene', 4);
		else
			-- 자홍거리에서 아이린 동료 안됨.
			dc:UpdateCompanyProperty(company, 'Progress/Character/Irene', 5);
		end
		dc:UpdateCompanyProperty(company, 'Progress/Character/Issac', 2);
	end
end
function MissionResult_Custom_Tutorial_BlueFogStreet(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Irene', 7);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'ScoutIrene');
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'LandOfStart');
	end
end
function MissionResult_Custom_Tutorial_SilverliningMarco(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	local tutorialProgress = company.Progress.Tutorial.Opening;
	local missionValue_MarcoPlay = GetStageVariable(mission, 'MarcoPlay');
	local missionValue_DonPlay = GetStageVariable(mission, 'DonPlay');

	if win then
		if missionValue_MarcoPlay == 1 then
			dc:UpdateCompanyProperty(company, 'Progress/Character/Marco', 1);
		elseif missionValue_DonPlay == 1 then
			dc:UpdateCompanyProperty(company, 'Progress/Character/Marco', 2);
		end
	else
		if missionValue_MarcoPlay == 1 then
			dc:UpdateCompanyProperty(company, 'Progress/Character/Marco', 3);
		elseif missionValue_DonPlay == 1 then
			dc:UpdateCompanyProperty(company, 'Progress/Character/Marco', 4);
		end
	end
	dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'SilverliningMarco');
end
function MissionResult_Custom_Tutorial_PugoBackStreet(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		if not company.Technique.Comradeship.Opened then
			dc:AcquireMastery(company, 'Comradeship', 1);
		end
		dc:UpdateCompanyProperty(company, 'Progress/Character/Sharky', 2);
	end
end
function MissionResult_Custom_Tutorial_Hansando(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		-- 특성 나의 꿈은 히어로.
		if not company.Technique.MyDreamIsHero.Opened then
			dc:AcquireMastery(company, 'MyDreamIsHero', 1);
		end
		dc:UpdateCompanyProperty(company, 'Progress/Character/Issac', 5);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Kylie', 1);
		dc:GiveSystemMailOneKey(company, 'VHPD_Reward_Wanted_Hansando');
	end
end
function MissionResult_Custom_Tutorial_GrayCemeteryPark(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Anne', 4);
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'Office');
	end
end
function MissionResult_Custom_Tutorial_Lasa(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Ryo', 1);
	end
end
function MissionResult_Custom_Tutorial_Orsay(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Danny', 1);
	end
end
function MissionResult_Custom_Tutorial_LokoCabin(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Issac', 6);
	end
end
function MissionResult_Custom_Tutorial_SkyBlue(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Issac', 7);
	end
end
function MissionResult_Custom_Tutorial_PurpleStreet(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Ryo', 2);
		if not company.CompanyMasteries.HardFight.Opened then
			dc:UpdateCompanyProperty(company, 'CompanyMasteries/HardFight/Opened', true);
			dc:UpdateCompanyProperty(company, 'CompanyMasteries/HardFight/IsNew', true);
		end
	end
end
function MissionResult_Custom_Tutorial_PugoShopAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Sion', 3);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Heissing', 3);
		
		local missionValue_SionPhase01 = GetStageVariable(mission, 'SionPhase01');
		local missionValue_AlbusPhase01 = GetStageVariable(mission, 'AlbusPhase01');
		-- 질문
		if missionValue_SionPhase01 == 1 and missionValue_AlbusPhase01 == 1 then
			-- 불만 -불만 
			-- 직언.
			dc:AcquireMastery(company, 'ForthrightStatement', 1);
			dc:UpdateCompanyProperty(company, 'Technique/GraciousRefusal/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/GraciousRefusal/IsNew', true);
			dc:UpdateCompanyProperty(company, 'Technique/Frankness/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/Frankness/IsNew', true);
		elseif missionValue_SionPhase01 == 2 and missionValue_AlbusPhase01 == 3 then
			-- 회사 창업 동기 - 개인사(귀족)
			-- 정중한 거절
			dc:AcquireMastery(company, 'GraciousRefusal', 1);
			dc:UpdateCompanyProperty(company, 'Technique/ForthrightStatement/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/ForthrightStatement/IsNew', true);
			dc:UpdateCompanyProperty(company, 'Technique/Frankness/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/Frankness/IsNew', true);
		elseif missionValue_SionPhase01 == 3 and missionValue_AlbusPhase01 == 2 then
			-- 개인사 - 회사.
			-- 솔직함
			dc:AcquireMastery(company, 'Frankness', 1);
			dc:UpdateCompanyProperty(company, 'Technique/ForthrightStatement/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/ForthrightStatement/IsNew', true);
			dc:UpdateCompanyProperty(company, 'Technique/GraciousRefusal/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/GraciousRefusal/IsNew', true);
		else
			dc:UpdateCompanyProperty(company, 'Technique/ForthrightStatement/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/ForthrightStatement/IsNew', true);
			dc:UpdateCompanyProperty(company, 'Technique/GraciousRefusal/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/GraciousRefusal/IsNew', true);
			dc:UpdateCompanyProperty(company, 'Technique/Frankness/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/Frankness/IsNew', true);			
		end
	end
	
	-- 오피스 언락
	if not StringToBool(company.OfficeMenu.Opened, false) then
		dc:UpdateCompanyProperty(company, 'OfficeMenu/Opened', true);
	end
	-- 작업실 언락
	if company.Office == 'Office_Silverlining_Workshop' then
		if not StringToBool(company.WorkshopMenu.Opened, false) then
			dc:UpdateCompanyProperty(company, 'WorkshopMenu/Opened', true);
		end
	end
	--. 사무실 되돌려 보내기
	dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'Office');
end
function MissionResult_Custom_Tutorial_HansolStreet(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		local missionValue_TeamID = GetStageVariable(mission, 'TeamID');
		if missionValue_TeamID == 1 then
			-- 헤이싱 승리
			-- 돌파구.
			dc:AcquireMastery(company, 'Breakthrough', 1);
			dc:UpdateCompanyProperty(company, 'Technique/Wanderer/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/Wanderer/IsNew', true);
		elseif missionValue_TeamID == 2 then
			-- 카터 승리
			-- 방랑자
			dc:AcquireMastery(company, 'Wanderer', 1);
			dc:UpdateCompanyProperty(company, 'Technique/Breakthrough/Opened', true);
			dc:UpdateCompanyProperty(company, 'Technique/Breakthrough/IsNew', true);
		end
		dc:UpdateCompanyProperty(company, 'Progress/Character/Heissing', 4);
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'Office');
	end
end
function MissionResult_Custom_Tutorial_Road_112(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Kylie', 2);
	end
end
function MissionResult_Custom_Tutorial_MetroStreet(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Irene', 11);
	end
end
function MissionResult_Custom_Tutorial_StarStreet(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Jane', 1);
	end
end
function MissionResult_Custom_Tutorial_CrescentBridge(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Sion', 5);
	end
end
function MissionResult_Custom_Tutorial_GrayPortWareHouse(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Ray', 3);
	end
end
function MissionResult_Custom_Tutorial_DustWind(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Ray', 4);
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'Office');
	end
end
function MissionResult_Custom_Tutorial_SkyWindPark(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if win then
		local missionValue_PlayerSelect = GetStageVariable(mission, 'PlayerSelect');
		if missionValue_PlayerSelect == 1 then
			-- 최초 클리어 시 지젤 편지 보내기.
			if company.Progress.Character.GiselleTraining == 0 then
				dc:UpdateCompanyProperty(company, 'Progress/Character/GiselleTraining', 1);
				dc:GiveSystemMailOneKey(company, 'Giselle01');
			end
		elseif missionValue_PlayerSelect == 2 then
			
			local missionValue_Sion_Allelimination = GetStageVariable(mission, 'Sion_Allelimination');
			local missionValue_Sion_Escape = GetStageVariable(mission, 'Sion_Escape');
			
			-- 특성 히스테리 추가.
			if not company.Technique.Hysterie.Opened and missionValue_Sion_Allelimination == 1 then
				dc:AcquireMastery(company, 'Hysterie', 1);
				dc:UpdateCompanyProperty(company, 'Technique/TacticalRetreat/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/TacticalRetreat/IsNew', true);
			end
			-- 특성 작전상 후퇴.
			if not company.Technique.TacticalRetreat.Opened and missionValue_Sion_Escape == 1 then
				dc:AcquireMastery(company, 'TacticalRetreat', 1);
				dc:UpdateCompanyProperty(company, 'Technique/Hysterie/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/Hysterie/IsNew', true);
			end
		elseif missionValue_PlayerSelect == 3 then			
			local missionValue_Irene_Win = GetStageVariable(mission, 'Irene_Win');
			-- 특성 히어로의 책임감.
			if not company.Technique.HeroResponsibility.Opened and missionValue_Irene_Win == 1 then
				dc:AcquireMastery(company, 'HeroResponsibility', 1);
				dc:UpdateCompanyProperty(company, 'Technique/HeroDontGiveUp/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/HeroDontGiveUp/IsNew', true);
			end				
			-- 특성 히어로는 포기하지 않는다.
			if not company.Technique.HeroDontGiveUp.Opened and missionValue_Irene_Win == 2 then
				dc:AcquireMastery(company, 'HeroDontGiveUp', 1);
				dc:UpdateCompanyProperty(company, 'Technique/HeroResponsibility/Opened', true);
				dc:UpdateCompanyProperty(company, 'Technique/HeroResponsibility/IsNew', true);
			end
		elseif missionValue_PlayerSelect == 4 then
			if not company.Technique.Waiting.Opened then
				dc:AcquireMastery(company, 'Waiting', 1);
			end
		elseif missionValue_PlayerSelect == 5 then
			-- 최초 클리어 시 카일리 편지 보내기.
			if company.Progress.Character.Kylie == 2 then
				dc:UpdateCompanyProperty(company, 'Progress/Character/Kylie', 3);
				dc:GiveSystemMailOneKey(company, 'Kylie01');
			end
		elseif missionValue_PlayerSelect == 6 then
			-- 냉정한 거절.
			if not company.Technique.ColdRefusal.Opened then
				dc:AcquireMastery(company, 'ColdRefusal', 1);
			end
		end
	end
end
function MissionResult_Custom_Tutorial_TrainingRoom(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if win then
		if not isTroublebookMission then
			dc:UpdateCompanyProperty(company, 'Progress/Character/Jane', 3);			
		end
		local missionValue_TeamTypeSelection = GetStageVariable(mission, 'TeamTypeSelection');
		if missionValue_TeamTypeSelection == 1 then
			dc:GiveSystemMailOneKey(company, 'PoliceTraining01');
			-- 특성 설득 추가.
			if not company.Technique.Persuasion.Opened then
				dc:AcquireMastery(company, 'Persuasion', 1);
			end
		elseif missionValue_TeamTypeSelection == 2 then
			dc:GiveSystemMailOneKey(company, 'PoliceTraining02');
			local mailID = math.min(9, math.max(1, math.floor(math.random(1,9))));
			local mailName = 'PoliceTraining02_'..mailID;
			dc:GiveSystemMailOneKey(company, mailName);
			-- 특성 제비뽑기 추가.
			if not company.Technique.Sortilege.Opened then
				dc:AcquireMastery(company, 'Sortilege', 1);
			end
			
			local missionValue_CheckAchievement = GetStageVariable(mission, 'CheckAchievement');
			if missionValue_CheckAchievement == 2 then
				dc:UpdateCompanyProperty(company, 'Progress/Achievement/BattleTraining', 1);
			end			
		elseif missionValue_TeamTypeSelection == 3 then		
			dc:GiveSystemMailOneKey(company, 'PoliceTraining01');
			-- 특성 열린 마음 추가.
			if not company.Technique.OpenMind.Opened then
				dc:AcquireMastery(company, 'OpenMind', 1);
			end
		end
	end
end
function MissionResult_Custom_Tutorial_PugoBackStreetAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 1);
		dc:UpdateCompanyProperty(company, 'Progress/ZoneEnter/FadeInOut', false);
	end
end
function MissionResult_Custom_Tutorial_GrayCemeteryParkAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Giselle', 2);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 6);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'ScoutGiselle');
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'LandOfStart');
	end
end
function MissionResult_Custom_Tutorial_Road_111(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if win then
		local missionValue_PhaseStart = GetStageVariable(mission, 'PhaseStart');
		if missionValue_PhaseStart == 1 then
			-- 회사 특성 신속 처리
			if not company.CompanyMasteries.FastWork.Opened then
				dc:UpdateCompanyProperty(company, 'CompanyMasteries/FastWork/Opened', true);
				dc:UpdateCompanyProperty(company, 'CompanyMasteries/FastWork/IsNew', true);
			end
		elseif missionValue_PhaseStart == 2 then
			-- 회사 안전 제일 처리		
			if not company.CompanyMasteries.SafetyFirst.Opened then
				dc:UpdateCompanyProperty(company, 'CompanyMasteries/SafetyFirst/Opened', true);
				dc:UpdateCompanyProperty(company, 'CompanyMasteries/SafetyFirst/IsNew', true);
			end
		end
	end
end
function MissionResult_Custom_Tutorial_DustWindRestArea(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		
	end
end
function MissionResult_Custom_Tutorial_MarketStreet(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if win then		
		if not isTroublebookMission then
			dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 10);
		end
		local missionValue_AlbusSelect = GetStageVariable(mission, 'AlbusSelect');
		if missionValue_AlbusSelect == 1 then
			-- 특성 원칙주의
			if not company.Technique.Principlism.Opened then
				dc:AcquireMastery(company, 'Principlism', 1);
			end
		elseif missionValue_AlbusSelect == 2 then
			-- 특성 융통성
			if not company.Technique.Flexibility.Opened then
				dc:AcquireMastery(company, 'Flexibility', 1);
			end
		end
	end
end
-- 카일리 영입
function MissionResult_Custom_Tutorial_Road_110(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then		
		dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 14);
		dc:UpdateCompanyProperty(company, 'Progress/Tutorial/Opening', 'ScoutKylie');
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'Office');
	end
end
-- 
function MissionResult_Custom_Tutorial_PurpleStreetAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		
	end
end
-- 
function MissionResult_Custom_Tutorial_CrowRuins(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		
	end
end
--
function MissionResult_Custom_Tutorial_PugoStreetAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		
	end
end
--
function MissionResult_Custom_Tutorial_WasteBuilding(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		
	end
end
--
function MissionResult_Custom_Tutorial_GroundWaterSlum(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Leton', 2);
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'Office');
	end
end
--
function MissionResult_Custom_Tutorial_CrowRuinsAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		
	end
end
--
function MissionResult_Custom_Tutorial_CrowRuinsAfter_Alley(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	
	local missionValue_Win = GetStageVariable(mission, 'Win');
	if missionValue_Win == 2 then
		-- 헤이싱 승리
		if not company.Technique.LoveHate.Opened then 
			dc:AcquireMastery(company, 'LoveHate', 1);
		end
	end
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Heissing', 10);
	end
end
--
function MissionResult_Custom_Tutorial_SkyBlueAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 20);
	end
end
--
function MissionResult_Custom_Tutorial_PurpleStreet_Kylie(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 23);
	end
end
--
function MissionResult_Custom_Tutorial_TrainingRoomAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)

	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 25);
	end
end
function MissionResult_Custom_Tutorial_SilverliningAfter(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)

	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/ZoneEnter/FadeInOut', false);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 26);
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'Office');
	end	
end
function MissionResult_Custom_Tutorial_WhiteTigerBase(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)

	if isTroublebookMission then
		return;
	end
	if win then
		dc:UpdateCompanyProperty(company, 'Progress/ZoneEnter/FadeInOut', false);
		dc:UpdateCompanyProperty(company, 'Progress/Character/Albus', 28);
		dc:UpdateCompanyProperty(company, 'LastLocation/LobbyType', 'Office');
	end
end
----------------------------------------------------------------------------------------
-- 반복 미션.
-----------------------------------------------------------------------------------------
function MissionResult_Custom_Common_GamnamBaseParkPlace(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if win then
		local missionValue_Info = GetStageVariable(mission, 'Info');
		local missionValue_KimDead = GetStageVariable(mission, 'KimDead');
		if missionValue_Info >= 1 and missionValue_KimDead == 0 then
			local rewardCount = 0;
			local grade = mission.Difficulty.Lv;
			if grade < 4 then
				rewardCount = 5;
			elseif grade < 7 then
				rewardCount = math.random(6, 7);
			elseif grade < 10 then
				rewardCount = math.random(7, 8);
			else
				rewardCount = 6;
			end
			if rewardCount > 0 then
				dc:GiveSystemMail(company, 'Kim01', 'Kim01', 'Kim01', 'Statement_Mastery', rewardCount, nil, nil, 'General');
			end
		end
	end
	dc:UpdateCompanyProperty(company, 'Progress/Mission/Common_GamnamBaseParkPlace', 1);
end
----------------------------------------------------------------------------------------
-- 강력 사건
-----------------------------------------------------------------------------------------
function MissionResult_Custom_Raid_DrakyNest(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if win then
		if not company.Progress.Mission.DrakyNest then
			local missionValue_FindWay = GetStageVariable(mission, 'FindWay');
			if missionValue_FindWay == 1 then
				dc:UpdateCompanyProperty(company, 'Progress/Mission/DrakyNest', true);
			end			
		end
	end
end
----------------------------------------------------------------------------------------
-- 아직 아래는 정리 안된거.
-----------------------------------------------------------------------------------------
function MissionResult_Custom_PvPTest(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	local enemyElo = GetEnemyElo(company, 'OneToOne');
	local result;
	if win then
		result = 'Win';
	else
		result = 'Lose';
	end
	local myNextElo = CalculateNextEloPoint(company.BattleElo.OneToOne.Point, enemyElo, company.BattleElo.OneToOne.GamePlayed, result);
	dc:AddCompanyProperty(company, 'BattleElo/OneToOne/GamePlayed', 1);
	dc:UpdateCompanyProperty(company, 'BattleElo/OneToOne/Point', myNextElo);
end
----------------------------------------------------------------------------------------
-- 공용
-----------------------------------------------------------------------------------------
function MissionResult_Custom_Common(mission, dc, company, lineup, win, expResults, itemGetResults, isSurrender, missionAttribute, isTroublebookMission)
	if isTroublebookMission then
		return;
	end
	-- 릴리 메일 2
	if company.Progress.Character.Lily == 0 and company.MissionCleared.Tutorial_GrayCemeteryPark and win then
		dc:GiveSystemMailOneKey(company, 'Lily02');
		dc:UpdateCompanyProperty(company, 'Progress/Character/Lily', 1);
	end
end