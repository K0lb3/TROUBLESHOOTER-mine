------------------------------------------------------------------------
-- 회사 관련 함수 
------------------------------------------------------------------------
function GetCompany_Shared(self)
	if IsMissionServer() then
		return GetCompanyByTeam(GetMission(self), GetTeam(self));
	elseif IsClient() then
		if GetTeam(self) == GetPlayerTeamName() then
			local session = GetSession();
			return session.company_info;
		else
			return nil;
		end
	else
		return nil;
	end
end
------------------------------------------------------------------------
-- Calculated Property 
------------------------------------------------------------------------
function Get_MaxQuestCount(company)
	local count = 10;
	return count;
end
function Get_MaxMemberCount(company)
	local count = 8;
	return count;
end
function Get_MaxMasteryCount(company)
	local count = 999;
	return count;
end
function Get_MaxInventoryItemCount(company)
	local result = company.BaseInventoryItemCount;
	local officeList = GetClassList('Office');
	local curOffice = officeList[company.Office];
	if not curOffice then
		return result;
	end
	result = result + curOffice.InventoryCapacity;
	return result;
end
function Get_MaxRosterCount(company)
	return 8;
end
function Get_WorkshopUnlockPrice(company)
	return 20000;
end
function Get_MaxRP(company)
	local count = 1000;
	return count;
end
function Get_MaxNP(company)
	local count = 1000;
	return count;
end
function Get_MaxTroublesumCount(company)
	local count = 5;
	return count;
end
function GetRentInfoByCompany(company)
	local officeCls = GetClassList('Office')[company.Office];
	if not officeCls or not officeCls.name or officeCls.name == 'None' then
		return nil;
	end
	if company.OfficeRentType < 1 or company.OfficeRentType > #officeCls.MonthlyRent then
		return nil;
	end
	return officeCls.MonthlyRent[company.OfficeRentType];
end
function Get_OfficeRentVill(company)
	local rentInfo = GetRentInfoByCompany(company);
	if not rentInfo then
		return 0;
	end
	return rentInfo.Vill;
end
function Get_OfficeRentDuration(company)
	local rentInfo = GetRentInfoByCompany(company);
	if not rentInfo then
		return 0;
	end
	return rentInfo.ClearCount;
end
function Get_MaxBeastStoreCount(company)
	return 10 + company.Progress.Achievement.BeastManagerLevel * 10;
end
---------------------------------------------------------
-- 미션 스테이터스
---------------------------------------------------------
function Get_MissionStatus(status, arg)
	return 0;
end
---------------------------------------------------------
-- 회사 성향
---------------------------------------------------------
function Get_CompanyAlignment(company)
	
	local result = '';
	local prefix = '';
	local suffix = '';
	
	-- 1. Lawful - Neutral - Chaotic
	local index = 1;
	local lawful = company.AlignmentPoint.LawfulGood + company.AlignmentPoint.LawfulNeutral + company.AlignmentPoint.LawfulEvil;
	local neutral = company.AlignmentPoint.NeutralGood + company.AlignmentPoint.Neutral + company.AlignmentPoint.NeutralEvil;
	local chaotic = company.AlignmentPoint.ChaoticGood + company.AlignmentPoint.ChaoticNeutral + company.AlignmentPoint.ChaoticEvil;

	if lawful == chaotic then
		prefix = 'Neutral';
	elseif neutral > lawful and neutral > chaotic then
		prefix = 'Neutral';
	elseif lawful > chaotic then
		prefix = 'Lawful';
	elseif chaotic > lawful then
		prefix = 'Chaotic';
	end
	
	-- 2. Good - Neutral - Evil
	local good = company.AlignmentPoint.LawfulGood + company.AlignmentPoint.NeutralGood + company.AlignmentPoint.ChaoticGood;
	local neutral2 = company.AlignmentPoint.LawfulNeutral + company.AlignmentPoint.Neutral + company.AlignmentPoint.ChaoticNeutral;
	local evil = company.AlignmentPoint.LawfulEvil + company.AlignmentPoint.NeutralEvil + company.AlignmentPoint.ChaoticEvil;	
	
	if good == evil then
		suffix = 'Neutral';
	elseif neutral2 > good and neutral2 > evil then
		suffix = 'Neutral';
	elseif good > evil then
		suffix = 'Good';
	elseif evil > good then
		suffix = 'Evil';
	end
		
	if prefix == suffix then
		result = 'Neutral';
	else
		result = prefix..suffix;
	end
	return result;
end
---------------------------------------------------------
-- 회사 평판
---------------------------------------------------------
function GetCurrentAreaReputationList(company)
	local list = {};
	local companyReputation = company.Reputation;
	for key, value in pairs (companyReputation) do
		if value.Area == company.CurrentArea then
			table.insert(list, value);
		end
	end
	return list;
end
function ActivityReportTimeTest(company)
	if company.Progress.Tutorial.ForceActivityReport then
		return true;
	end
	
	return company.ActivityReportCounter >= company.ActivityReportDuration;
end
---------------------------------------------------------
-- 회사 특성 변경
---------------------------------------------------------
function IsEnableCahngeCompanyMastery(company, companyMasteryName)
	
	local reason = {};
	local isEnable = true;
	local curCompanyMastery = company.CompanyMasteries[companyMasteryName];
	-- 0 .데이터 에러.
	if not curCompanyMastery then
		LogAndPrint('DataError - NotExist CompanyMasteries - companyMasteryName', companyMasteryName);
		table.insert(reason, 'DataError');
		isEnable = false;
		return isEnable, reason;
	end
	-- 1. 습득 가능한 회사 특성인가.
	if not curCompanyMastery.Opened then
		table.insert(reason, 'notOpened');
		isEnable = false;
	end	

	-- 2. 회사에 돈이 있는가?
	if company.Vill < curCompanyMastery.Vill then
		table.insert(reason, 'NotEnoughVill');
		isEnable = false;
	end	
	return isEnable, curCompanyMastery.Vill, reason;
end
---------------------------------------------------------
-- 회사 이름 변경
---------------------------------------------------------
function GetChangeCompanyNameVill()
	return 1000;
end
function GetChangeCompanyNameDay()
	return 7;
end
function GetChangeCompanyNameTime()
	return 60 * 60 * 24 * GetChangeCompanyNameDay();
end
function ChangeNameTimeTest(company, curTime)
	if curTime == nil then
		curTime = os.time();
	end
	return company.LastNameChangeTime + GetChangeCompanyNameTime() < curTime;
end
function IsEnableChangeCompanyName(company, companyName)
	local reason = {};
	local isEnable = true;

	-- 1. 사용 가능한 이름인가?
	if not IsValidCompanyName(companyName) then
		table.insert(reason, 'InvalidName');
		isEnable = false;
	end	
	
	-- 2. 회사에 돈이 있는가?
	local needVill = GetChangeCompanyNameVill();
	if company.Vill < needVill then
		table.insert(reason, 'NotEnoughVill');
		isEnable = false;
	end	
	return isEnable, needVill, reason;
end
function IsValidCompanyName(name)
	local str = UTF8ToCharArray(name);
	local strLen = #str;
	
	local validName = false;

	local isValid = true;
	local reason = nil;
	local reasonSub = nil;
	
	local spaceCharacter = { ' ', '	', '　' };	
	for i, s in ipairs(str) do
		for _, char in ipairs(spaceCharacter) do 
			if char == s then
				isValid = false;
				reason = 'Space';
				break;
			end
		end
		if not isValid then
			break;
		end
	end
	
	local systemToken = GetClassList('FilteringWord')['SystemToken'];
	local invalidTokenList = {};
	for _, token in ipairs(systemToken) do
		if string.find(name, token, 1, true) then
			table.insert(invalidTokenList, token);
		end
	end
	if #invalidTokenList > 0 then
		isValid = false;
		reason = 'SystemToken';
		reasonSub = table.concat(invalidTokenList, ', ');
	end	
	
	local filteringWord = GetClassList('FilteringWord')['CompanyName'];
	for _, word in ipairs(filteringWord) do
		local removeSpaceWord = string.gsub(word, ' ', '');
		if name == removeSpaceWord then
			isValid = false;
			reason = 'Filtering';
			reasonSub = word;
			break;
		end
	end
	
	if strLen == 0 then
		isValid = false;
		reason = 'Empty';
	elseif strLen < 2 then
		isValid = false;
		reason = 'TooShort';
	elseif strLen > 20 then
		isValid = false;
		reason = 'TooLong';
	end
	
	return isValid, reason, reasonSub;
end