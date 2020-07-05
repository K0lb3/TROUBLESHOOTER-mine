-----------------------------------------------------
-- 트러블북 관련
-----------------------------------------------------
function IsEnableStartTroublebookMission(company, episode)
	return company.Troublebook[episode].Opened;
end