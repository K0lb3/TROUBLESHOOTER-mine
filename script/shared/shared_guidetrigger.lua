-- IsEnable
function GuideTriggerIsEnable_Default(mission, company)
	return mission.name ~= 'Tutorial_CrowBill';
end
function GuideTriggerIsEnable_AfterFireflyPark(mission, company)
	return GuideTriggerIsEnable_Default(mission, company) and mission.name ~= 'Tutorial_FireflyPark' and mission.name ~= 'Tutorial_FireflyPark_Roster';
end
function GuideTriggerIsEnable_AfterSilverlining(mission, company)
	return GuideTriggerIsEnable_AfterFireflyPark(mission, company) and mission.name ~= 'Tutorial_Silverlining';
end