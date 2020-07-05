function ConfigureConditionalAIArgs(self, monCls, args)
	if monCls == nil then
		return;
	end
	local func = monCls.AIConfigFunc;
	if not func then
		return;
	end
	func(self, monCls, args);
end

function AIConfig_Sniper(self, monCls, args)
	local inSightEnemyFilter = function(o) return IsEnemy(self, o) and IsInSight(self, o); end;
	local nearEnemies = table.filter(GetNearObject(self, 4), inSightEnemyFilter);
	if #nearEnemies > 0 then
		args.RunAway = true;
	end
	local farEnemies = table.filter(GetNearObject(self, 8), inSightEnemyFilter);
	if #farEnemies == 0 then	
		args.NoMoveBonus = 300;
	end
	args.HeightBonus = 5;
end

function AIConfig_BabyDraky(self, monCls, args)
	if GetInstantProperty(self, 'GlidingMoveRightBefore') then
		SetInstantProperty(self, 'GlidingMoveRightBefore', nil);
		args.NoMoveBonus = 500;
	end
end