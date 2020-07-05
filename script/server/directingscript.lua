function MasterDirectingScript(ds, mid, script, args)
	if type(script) == 'string' then
		return _G[script](mid, ds, args);
	else
		return script(mid, ds, args);
	end
end
function MissionWin(mid, ds)
end
function MissionLose(mid, ds)
end
-----------------------------------------------------------------------------------------
-- 미션 시작시 연출 
-----------------------------------------------------------------------------------------
function MissionBeginningTest(mid, ds, args)
	MissionDirect_Dialog(mid, ds, args)
end
