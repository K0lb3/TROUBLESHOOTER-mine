-------------------------------------------------
-- 트러블북 챕터 오픈 체크
-------------------------------------------------
function CalculatedProperty_TroublebookOpened(obj, arg)

	if not obj.parent then
		return false
	end
	local company = obj.parent.parent;
	if not company then
		return false;
	end
	local isOpened = false;
	for index, value in ipairs(obj.Stage) do
		local isMissionCleared = company.MissionCleared[value.Mission];
		if isMissionCleared then
			isOpened = true;
			break;
		end
	end
	return isOpened and StringToBool(company.OfficeMenu.TroubleBook.Opened, false);	
end

function CalculatedProperty_TroublebookNextChapter(obj, arg)
	local troublebookClsList = GetClassList('Troublebook');
	local myOrder = obj.Order;
	for _, bookCls in pairs(troublebookClsList) do
		if bookCls.Order == myOrder + 1 then
			return bookCls;
		end
	end
	return nil;
end