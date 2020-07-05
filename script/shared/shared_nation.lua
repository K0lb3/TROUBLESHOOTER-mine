function CalculatedProperty_Sector_Desc(self, arg)
	local result = '';	
	for _, cotent in ipairs (self.Content) do
		local curTitle = "[colour='FFFFFF00']"..cotent.Title.."[colour='FFFFFFFF']";
		local curText = cotent.Text;
		if #cotent.SubText > 0 then
			for _, subCotent in ipairs (cotent.SubText) do
				curText = curText..'\n'.."[colour='FFFFAA00']"..subCotent.Title.."[colour='FFFFFFFF']"..'\n'..subCotent.Text;				
			end
		end
		if result == '' then
			result = curTitle..'\n'..curText;
		else
			result = result..'\n\n'..curTitle..'\n'..curText;
		end
	end	
	return result;
end