function MakeOnAccessedHandler(obj, prevSubscriptionID, doFunc)
	local exhausted = false;
	return function(eventArg, ds)
		if eventArg.Unit == obj
			or GetDistance3D(eventArg.Position, GetPosition(obj)) > 2.4 
			or GetOriginalTeam(eventArg.Unit) ~= 'player' 
			or exhausted then
			return;
		end
		exhausted = true;
		UnsubscribeWorldEvent(obj, prevSubscriptionID);
		return doFunc(obj, eventArg, ds);
	end
end

function SecretAgent_FriendlyReaction(obj, eventArg, ds)
	local objKey = GetObjKey(obj);
	
	ds:LookAt(objKey, GetObjKey(eventArg.Unit));
	ds:UpdateBalloonChat(objKey, '바깥은 혼자 돌아다니기엔 위험하단다. 이걸 가지고 가렴!');
	ds:Sleep(2);
	ds:UpdateBalloonChat(objKey, '그럼 난 이만~');
	local exitPos = FindAIMovePosition(obj, {FindMoveAbility(obj)}, function (self, adb)
		return adb.MoveDistance;	-- 가장 멀리 갈 수 있는 아무데나
	end, {}, {});
	ds:Move(objKey, exitPos);
	return Result_FireWorldEvent('InformationAcquired', {Acquirer = eventArg.Unit}), Result_DestroyObject(obj, false, true);
end

function SecretAgent_HostileReaction(obj, eventArg, ds)
	local objKey = GetObjKey(obj);
	
	ds:LookAt(objKey, GetObjKey(eventArg.Unit));
	ds:UpdateBalloonChat(objKey, '너는 우리편이 아니구나!');
	ds:Sleep(2);
	ds:UpdateBalloonChat(objKey, '가진 정보를 내놓으면 살려는 주지!');
	SubscribeWorldEvent(obj, 'UnitDead', function(eventArg, ds)
		if eventArg.Unit ~= obj 
			or GetTeam(eventArg.Killer) ~= 'player' then
			return;
		end
		
		ds:UpdateBalloonChat(objKey, 'Mo..ria..rty...');
		ds:Sleep(1);
		return Result_FireWorldEvent('InformationAcquired', {Acquirer = eventArg.Killer});
	end);
	local pos, score, debugInfo = FindAIMovePosition(obj, {FindMoveAbility(obj)}, DefencsiveMoveAI(), {}, {});
	ds:Move(objKey, pos);
	return Result_ChangeTeam(obj, 'secret_agent_hostile');
end

function InitializeSecretAgent(obj, unitDecl, reinitialize)
	local secretAgentInfo = SafeIndex(unitDecl, 'SecretAgentType', 1);
	local secretAgentCls = GetClassList('SecretAgent')[secretAgentInfo.Type];
	
	local subscriptionID = SubscribeWorldEvent(obj, 'UnitDead', function(deadEventArg, ds)
		if deadEventArg.Unit ~= obj then
			return;
		end
		
		return Result_CreateObject(GenerateUnnamedObjKey(obj), 'Object_Bomb', GetPosition(obj), '_neutral_', function(infoObj, args)
			EnableInteraction(infoObj, 'Collect');
			SubscribeWorldEvent(infoObj, 'CollectingOccurred', function(collectEventArg, ds)
				return Result_DestroyObject(infoObj, false), Result_FireWorldEvent('InformationAcquired', {Acquirer=deadEventArg.Killer});
			end);
		end, nil, 'DoNothingAI', nil);
	end);
	
	if secretAgentInfo.Type == 'Friend' then
		SubscribeWorldEvent(obj, 'UnitMoved', MakeOnAccessedHandler(obj, subscriptionID, SecretAgent_FriendlyReaction));
		return;
	elseif secretAgentInfo.Type == 'Foe' then
		SubscribeWorldEvent(obj, 'UnitMoved', MakeOnAccessedHandler(obj, subscriptionID, SecretAgent_HostileReaction));
		return;
	end
	
	-- Nogotiator
	SubscribeWorldEvent(obj, 'UnitMoved', MakeOnAccessedHandler(obj, subscriptionID, function(obj, eventArg, ds)
		local objKey = GetObjKey(obj);
		local negotiatingType = SafeIndex(secretAgentInfo, 'NegotiatingType', 1)
		
		if negotiatingType.Type == 'FullyDescribed' then
			-- 그냥 미션 다이렉트 재생
			PlayMissionDirect_Internal(GetMissionID(obj), ds, nil, SafeIndex(negotiatingType.MissionDirectScript, 1), 'SecretAgent');
			return true;
		end
		
		-- Simple
		local notice = negotiatingType.Notice;
		local friendlyMessage = negotiatingType.FriendlyMessage;
		local hostileMessage = negotiatingType.HostileMessage;
		ds:LookAt(objKey, GetObjKey(eventArg.Unit));
		ds:UpdateBalloonChat(objKey, '또 한명의 어린양이군..');
		ds:Sleep(2);
		
		local choices = {};
		table.insert(choices, {Msg = friendlyMessage, Tendency = 'Friendly', Notice = 'Friendly'});
		table.insert(choices, {Msg = hostileMessage, Tendency = 'Hostile', Notice = 'Hostile'});
		choices = table.shuffle(choices);
		local dialogArgs = {};

		dialogArgs.Content = notice;
		for i, choice in ipairs(choices) do
			local choice = {};
			choice.Message = choice.Msg;
			choice.Notice = choice.Notice;
			choice.Title = '';
			choice.Count = 0;
			dialogArgs[i] = choice;
		end
		
		local id, sel = ds:Dialog('NormalSelDialog', dialogArgs);
		ds:CloseDialog("NormalSelDialog");
		ds:Sleep(0.5);

		if sel ~= 0 and sel <= #choices then
			-- 정상 입력
			local choice = choices[sel];
			if choice.Tendency == 'Friendly' then
				return true, SecretAgent_FriendlyReaction(obj, eventArg, ds);
			elseif choice.Tendency == 'Hostile' then
				return true, SecretAgent_HostileReaction(obj, eventArg, ds);
			end
		end
		return false;
	end));
end