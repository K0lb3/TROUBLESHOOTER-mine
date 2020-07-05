function EventFormIndexer(self, key)
	if key == 'Override' or key == 'MyData' or key == 'Base' then
		return nil
	end
	local overrideData = SafeIndex(self.Override, key);
	if overrideData and overrideData ~= '' and overrideData then
		return overrideData;
	end
	local myData = GetWithoutError(self.MyData, key);
	if myData and myData ~= '' then
		return myData;
	else
		return self.Base[key];
	end
end
function GetTextFieldFromEventForm(eventForm, key)
	local ret = (function (eventForm, key)
	local overrideData = SafeIndex(eventForm.Override, key);
	if overrideData and overrideData ~= '' then
		return SentenceStringText(overrideData);
	end
	local myData = GetWithoutError(eventForm.MyData, key);
	if myData and myData ~= '' then
		return ClassDataText('NamedEvent', eventForm.MyData.name, key);
	end
	local baseData = GetWithoutError(eventForm.Base, key);
	if baseData then
		return ClassDataText(GetIdspace(eventForm.Base), eventForm.Base.name, key);	
	end
	return nil;
	end)(eventForm, key);
	return ret;
end

function DoNamedMeetDirecting(eventData, named, foundTarget, ds)
	local formData = eventData.MeetForm;
	local directingFunc = formData.Method;
	local eventForm = {Override = GetInstantProperty(named, 'NamedEventOverride'), Base = formData, MyData = eventData};
	
	setmetatable(eventForm, {__index = EventFormIndexer});
	return directingFunc(eventForm, named, foundTarget, ds);
end

function DoNamedDangerDirecting(eventData, named, ds)
	local formData = eventData.DangerForm;
	local directingFunc = formData.Method;
	local eventForm = {Override = GetInstantProperty(named, 'NamedEventOverride'), Base = formData, MyData = eventData};
	
	setmetatable(eventForm, {__index = EventFormIndexer});
	return directingFunc(eventForm, named, ds);
end

function NamedMeetDirecting_Basic(eventForm, named, foundTarget, ds)
	local namedKey = GetObjKey(named);
	local foundTargetKey = GetObjKey(foundTarget);
	ds:UpdateTitleMessageWithText(GetTextFieldFromEventForm(eventForm, 'Title'), nil, GetTextFieldFromEventForm(eventForm, 'Subtitle'), nil, nil);
	ds:LookAt(namedKey, foundTargetKey);
	local isBuff1 = eventForm.MeetBuff and eventForm.MeetBuff ~= '';
	local isBuff2 = eventForm.MeetBuff2 and eventForm.MeetBuff2 ~= '';
	local chatText = GetTextFieldFromEventForm(eventForm, 'MeetChat');
	local chatText2 = GetTextFieldFromEventForm(eventForm, 'MeetChat2');
	local chat = ds:UpdateBalloonChatWithText(namedKey, chatText, eventForm.MeetBalloon, 'NotoSansMedium-16_Auto', nil, eventForm.MeetChatInterval);
	if eventForm.MeetAnimation and eventForm.MeetAnimation ~= '' then		
		local ani = ds:PlayAni(namedKey, eventForm.MeetAnimation, false);
		ds:Connect(ani, chat, 0);
	end
	local sleep = ds:Sleep(eventForm.MeetChatInterval);
	ds:Connect(sleep, chat, 0);
	if chatText2 and eventForm.MeetChat2 ~= '' then
		local chat2 = ds:UpdateBalloonChatWithText(namedKey, chatText2, eventForm.MeetBalloon2, 'NotoSansMedium-16_Auto', nil, eventForm.MeetChatInterval2);
		ds:Connect(chat2, sleep, -1);
		ds:Connect(ds:Sleep(eventForm.MeetChatInterval2), sleep, -1);
	end	
	ds:UpdateTitleMessage('', nil, '', nil, nil);
	
	local actions = {};
	if isBuff1 then
		ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('UnitBuffStateUpdated'), {Unit = ClassDataText('ObjectInfo', named.Info.name, 'Title'), Buff = ClassDataText('Buff', eventForm.MeetBuff, 'Title')}), 'Tomato');
		InsertBuffActions(actions, named, named, eventForm.MeetBuff, 1, true);
	end
	if isBuff2 then
		ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('UnitBuffStateUpdated'), {Unit = ClassDataText('ObjectInfo', named.Info.name, 'Title'), Buff = ClassDataText('Buff', eventForm.MeetBuff2, 'Title')}), 'Tomato');
		InsertBuffActions(actions, named, named, eventForm.MeetBuff2, 1, true);
	end	
	return unpack(actions);
end
function NamedDangerDirecting_Basic(eventForm, named, ds)
	local namedKey = GetObjKey(named);
	local isBuff1 = eventForm.DangerBuff and eventForm.DangerBuff ~= '';
	local isBuff2 = eventForm.DangerBuff2 and eventForm.DangerBuff2 ~= '';
	local chatText = GetTextFieldFromEventForm(eventForm, 'DangerChat');
	local chatText2 = GetTextFieldFromEventForm(eventForm, 'DangerChat2');
	local chat = ds:UpdateBalloonChatWithText(namedKey, chatText, eventForm.DangerBalloon, 'NotoSansMedium-16_Auto', nil, eventForm.DangerChatInterval);
	if eventForm.DangerAnimation and eventForm.DangerAnimation ~= '' then
		local ani = ds:PlayAni(namedKey, eventForm.DangerAnimation, false);
		ds:Connect(ani, chat, 0);
	end
	local sleep = ds:Sleep(eventForm.DangerChatInterval);
	ds:Connect(sleep, chat, 0);
	if chatText2 and chatText2 ~= '' then
		local chat2 = ds:UpdateBalloonChatWithText(namedKey, chatText2, eventForm.DangerBalloon2, 'NotoSansMedium-16_Auto', nil, eventForm.DangerChatInterval2);
		ds:Connect(chat2, sleep, -1);
		ds:Connect(ds:Sleep(eventForm.DangerChatInterval2), sleep, -1);
	end
	ds:UpdateTitleMessage('', nil, '', nil, nil);
	
	local actions = {};
	if isBuff1 then
		ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('UnitBuffStateUpdated'), {Unit = ClassDataText('ObjectInfo', named.Info.name, 'Title'), Buff = ClassDataText('Buff', eventForm.DangerBuff, 'Title')}), 'Tomato');
		ds:Sleep(0.5);
		InsertBuffActions(actions, named, named, eventForm.DangerBuff, 1, true);		
	end
	if isBuff2 then
		ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('UnitBuffStateUpdated'), {Unit = ClassDataText('ObjectInfo', named.Info.name, 'Title'), Buff = ClassDataText('Buff', eventForm.DangerBuff2, 'Title')}), 'Tomato');
		ds:Sleep(0.5);
		InsertBuffActions(actions, named, named, eventForm.DangerBuff2, 1, true);
	end
	ds:ShowFrontmessageWithText(FormatMessageText(GuideMessageText('UnitOvercharged'), {Unit = ClassDataText('ObjectInfo', named.Info.name, 'Title')}), 'Tomato');
	AddSPPropertyActionsObject(actions, named, named.MaxSP);
	return unpack(actions);
end