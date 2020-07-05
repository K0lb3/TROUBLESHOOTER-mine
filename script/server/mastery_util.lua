function AddActionApplyActForDS(actions, target, applyAct, ds, actionCategory, refId, refOffset)
	local action, reasons = GetApplyActAction(target, applyAct, nil, actionCategory);
	if action ~= nil then
		table.insert(actions, action);
		local applyActId = ds:UpdateBattleEvent(GetObjKey(target), 'AddWait', { Time = applyAct, Delay = true });
		if refId then
			ds:Connect(applyActId, refId, refOffset);
		end
	end
	ReasonToUpdateBattleEventMulti(target, ds, reasons, refId, refOffset);
end

function AddActionCostForDS(actions, target, cost, sequential, updateStatus, ds)
	local result, reasons = AddActionCost(actions, target, cost, sequential, updateStatus);
	ds:UpdateBattleEvent(GetObjKey(target), 'AddCost', { CostType = target.CostType.name, Count = result - target.Cost });
	ReasonToUpdateBattleEventMulti(target, ds, reasons);
	return result, reasons;
end

function AddRandomGoodBuffAction(actions, giver, target)
	local goodBuffList = Linq.new(GetClassList('Buff_Positive'))
		:select(function(pair) return pair[1]; end)
		:toList();
	local goodBuffPicker = RandomBuffPicker.new(target, goodBuffList);
	
	local goodBuff = goodBuffPicker:PickBuff();
	if goodBuff == nil then
		return false;
	end
	
	InsertBuffActions(actions, giver, target, goodBuff, 1, true);
	return true;
end

function AddActionRestoreHPForDS(actions, user, target, addHP, ds, directDamageType)
	local reasons = AddActionRestoreHP(actions, user, target, addHP);
	ReasonToUpdateBattleEventMulti(user, ds, reasons);
	if target.HP < target.MaxHP then
		DirectDamageByType(ds, target, directDamageType or 'HPRestore', -addHP, math.min(target.MaxHP, target.HP + addHP), true, false);
	end
end