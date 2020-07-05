function GetRosterSalaryDialog(salaryDialogType, rosterKey, baseDialog)
	local salaryDialogClsList = GetClassList('Dialog');
	
	local picker = RandomPicker.new();
	local index = 1;
	repeat
		local dlgKey = salaryDialogType .. '_' .. rosterKey .. '_' .. index;
		local cls = salaryDialogClsList[dlgKey];
		if cls then
			picker:addChoice(1, cls);
		else
			break;
		end
		index = index + 1;
	until false;
	
	local selDlgCls = picker:pick();
	if selDlgCls == nil then
		return salaryDialogClsList[baseDialog];
	else
		return selDlgCls;
	end
end
function ProgressSalaryDialog(ldm, self, company, env, parsedScript)
	local dialog = GetRosterSalaryDialog(parsedScript.SalaryDialogType, parsedScript.RosterKey, parsedScript.BaseDialog);
	if dialog then
		return ProgressDialogCls(ldm, self, company, dialog, env);
	else
		return env;
	end
end

function ProgressSalaryAction(ldm, self, company, env, parsedScript)
	env.cur_roster = GetRoster(company, env.roster_name);
	env.salary_vill = env.cur_roster.Salary * env.cur_roster.SalaryDuration;
	env.bonus_vill = math.floor(env.salary_vill * 1.5);
	
	env = ProgressSalaryDialog(ldm, self, company, env, {SalaryDialogType = 'Salary_Event_Begin_To_Talk', RosterKey = env.roster_name, BaseDialog = 'Salary_Event_Begin_To_Talk_Base'});
	if company.Vill >= env.bonus_vill then
		env = ProgressSalaryDialog(ldm, self, company, env, {SalaryDialogType = 'Salary_Event_Selection_Full', RosterKey = env.roster_name, BaseDialog = 'Salary_Event_Selection_Full_Base'});
		env = ProgressDialog(ldm, self, company, 'Salary_Selection_Full', env);
	elseif company.Vill >= env.salary_vill then
		env = ProgressSalaryDialog(ldm, self, company, env, {SalaryDialogType = 'Salary_Event_Selection_NoBonus', RosterKey = env.roster_name, BaseDialog = 'Salary_Event_Selection_NoBonus_Base'});
		env = ProgressDialog(ldm, self, company, 'Salary_Selection_NoBonus', env);
	else
		env = ProgressSalaryDialog(ldm, self, company, env, {SalaryDialogType = 'Salary_Event_Selection_NoSalary', RosterKey = env.roster_name, BaseDialog = 'Salary_Event_Selection_NoSalary_Base'});
	end
	if env.method_type == 'SalaryNormal' then
		env = ProgressDialog(ldm, self, company, 'Salary_Process_Normal', env);
	elseif env.method_type == 'SalaryBonus' then
		env = ProgressDialog(ldm, self, company, 'Salary_Process_Bonus', env);
	else
		env = ProgressDialog(ldm, self, company, 'Salary_Process_Delay', env);
	end
end