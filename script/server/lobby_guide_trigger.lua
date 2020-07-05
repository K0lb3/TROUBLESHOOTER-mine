function ProgressLobbyGuideTrigger(ds, company, args)
	local dc = ds:GetDatabaseCommiter();
	local needCommit = false;
	for _, guideTrigger in pairs(company.LobbyGuideTrigger) do
		if not guideTrigger.Pass and table.find(guideTrigger.EventType, args.EventType) then
			local ok, output = guideTrigger.Checker(args.EventType, args.EventArgs, company, guideTrigger);
			if ok then
				guideTrigger.Director(args.EventType, args.EventArgs, ds, company, output, guideTrigger);
				dc:UpdateCompanyProperty(company, 'LobbyGuideTrigger/'..guideTrigger.name..'/Pass', true);
				needCommit = true;
			end
		end
	end
	if needCommit then
		dc:Commit('ProgressLobbyGuideTrigger');
	end
end

function LobbyGuideTriggerDirector_BattleDialogMessage(eventType, eventArgs, ds, company, output, guideTrigger)
	local helpType = guideTrigger.HelpMessage.name;
	if not helpType then
		helpType = guideTrigger.name;
	end
	ds:Dialog("HelpMessageBox",{ Type = helpType });
end