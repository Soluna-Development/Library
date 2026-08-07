local httpService = game:GetService("HttpService")


type Dropdown = {Value: any, Values: {i: any}, Multi: boolean, Displayer: (v) -> (n)?, SetValue: (any) -> ()}

local DisplayerParser = {
	Encode = function(Value)
		local Encoded = {}

		for Val: any, Bool: boolean in Value do
			table.insert(Encoded, Val)
		end

		return Encoded
	end,
}

local function TableEqual(Table, Reflect)
	for Index, Value in Table do 
		if Reflect[Index] ~= Value then return false end 
	end 

	return true
end  

local function SetDisplayerDropdownValue(Dropdown: Dropdown, Value)
	if Dropdown.Multi then
		local Values = {}
		
		for _, DataValue in Value do 
			for _, DropdownValue in Dropdown.Values do 
				if typeof(DropdownValue) ~= 'table' or not TableEqual(DataValue, DropdownValue) then continue end 
				
				Values[DropdownValue] = true
				break
			end
		end
		
		Dropdown:SetValue(Values)
	else
		for _, DropdownValue in Dropdown.Values do 
			if typeof(DropdownValue) ~= 'table' or not TableEqual(Value, DropdownValue) then continue end 
			
			Dropdown:SetValue(DropdownValue)
			break
		end	
	end
end

local SaveManager = {} do
	SaveManager.Folder = "FluentSettings"
	SaveManager.Ignore = {}
	SaveManager.AutoSave = false
	SaveManager.AutoSaveConfig = nil
	SaveManager._SettingAutoSave = false
	SaveManager.Options, SaveManager.Library = {} :: { [string]: {Type: string, Value: any, SetValues: (self: any, NewValue: { [any]: any }) -> nil, SetValue: (self: any, NewValue: any, ...any) -> nil, SetValueRGB: (self: any, NewValue: Color3, Transparency: number?) -> nil} }, {}
	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object) 
				return { type = "Toggle", idx = idx, value = object.Value, Timestamp = object.Instance.CreatedAt } 
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = "Slider", idx = idx, value = object.Value, Timestamp = object.Instance.CreatedAt }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				local HasDisplayer = object.CustomDisplayer
				
				return { type = "Dropdown", idx = idx, value = (HasDisplayer and object.Multi and DisplayerParser.Encode(object.Value) or object.Value), mutli = object.Multi, Timestamp = object.Instance.CreatedAt, displayer = HasDisplayer}
			end,
			Load = function(idx, data)
				if data.value == nil then return end
				
				local DropdownElement = SaveManager.Options[idx]
				if not DropdownElement then return end
				
				local Value = data.value 
				if typeof(Value) ~= 'table' or (not data.displayer) then
					DropdownElement:SetValue(Value)
					return
				end
				
				SetDisplayerDropdownValue(DropdownElement, Value)
			end,
		},
		Colorpicker = {
			Save = function(idx, object)
				return { type = "Colorpicker", idx = idx, value = object.Value:ToHex(), transparency = object.Transparency, Timestamp = object.Instance.CreatedAt }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		Keybind = {
			Save = function(idx, object)
				return { type = "Keybind", idx = idx, mode = object.Mode, key = object.Value, Timestamp = object.Instance.CreatedAt }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] then 
					SaveManager.Options[idx]:SetValue(data.key, data.mode)
				end
			end,
		},

		Input = {
			Save = function(idx, object)
				return { type = "Input", idx = idx, text = object.Value, Timestamp = object.Instance.CreatedAt }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] and type(data.text) == "string" then
					SaveManager.Options[idx]:SetValue(data.text)
				end
			end,
		},
		ImagePicker = {
			Save = function(idx, object)
				return { type = "ImagePicker", idx = idx, value = object.Value, Timestamp = object.Instance.CreatedAt }
			end,
			Load = function(idx, data)
				if SaveManager.Options[idx] and data.value ~= nil then
					SaveManager.Options[idx]:SetValue(data.value)
				end
			end,
		},
		WindowSize = {
			Save = function(idx, object)
				local window = SaveManager.Library.CreatedWindow
				if window and window.Size then
					return { type = "WindowSize", idx = idx, sizeX = window.Size.X.Offset, sizeY = window.Size.Y.Offset, Timestamp = tick() }
				end
				return nil
			end,
			Load = function(idx, data)
				local window = SaveManager.Library.CreatedWindow
				if window and data.sizeX and data.sizeY then
					window.Size = UDim2.fromOffset(data.sizeX, data.sizeY)
					if window.Root then
						window.Root.Size = window.Size
					end
				end
			end
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function SaveManager:Save(name): (boolean, string?)
		if (not name) then
			return false, "No config file is selected"
		end

		local fullPath = `{self.Folder}/settings/{name}.json`

		local data = {
			objects = {}
		}

		for idx, option in next, SaveManager.Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			local savedData = self.Parser[option.Type].Save(idx, option)
			if savedData then
				data.objects[#data.objects + 1] = savedData
			end
		end

		-- Save window size
		local windowSizeData = self.Parser.WindowSize.Save("WindowSize", nil)
		if windowSizeData then
			data.objects[#data.objects + 1] = windowSizeData
		end

		table.sort(data.objects, function(v1: { Timestamp: number }, v2: { Timestamp: number })
			return v1.Timestamp < v2.Timestamp
		end)

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, "Failed to JSON-Encode data"
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name): (boolean, string?)
		if (not name) then
			return false, "No config file is selected"
		end

		local file = `{self.Folder}/settings/{name}.json`
		if not isfile(file) then return false, "invalid file" end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, "decode error" end

		-- Prevent auto-save from triggering during load
		SaveManager._SettingAutoSave = true
		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(self.Library.SafeCallback, self.Library, self.Parser[option.type].Load, option.idx, option)
			end
		end
		SaveManager._SettingAutoSave = false

		self.Library:SetTheme(self.Library.Theme)

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"InterfaceManager_InterfaceTheme", "InterfaceManager_AcrylicToggle", "InterfaceManager_TransparentToggle", "InterfaceManager_MenuKeybind"
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			`{self.Folder}/settings`
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(`{self.Folder}/settings`)

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == ".json" then
				local pos = file:find(".json", 1, true)
				local start = pos

				if typeof(pos) == "number" and typeof(start) == "number" then
					local char = file:sub(pos, pos)
					while char ~= "/" and char ~= "\\" and char ~= "" do
						pos = pos - 1
						char = file:sub(pos, pos)
					end

					if char == "/" or char == "\\" then
						local name = file:sub(pos + 1, start - 1)
						if name ~= "options" then
							out[#out + 1] = name
						end
					end
				end
			end
		end

		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
		self.Options = library.Options

		-- Hook into window size changes for auto-save
		if library.WindowSizeChanged then
			library.WindowSizeChanged:Connect(function()
				if SaveManager.AutoSave and SaveManager.AutoSaveConfig and not SaveManager._SettingAutoSave then
					task.spawn(function()
						SaveManager:Save(SaveManager.AutoSaveConfig)
					end)
				end
			end)
		end

		task.spawn(function()
			for idx, option in next, self.Options do
				if option.SetValue and not option._OriginalSetValue then
					option._OriginalSetValue = option.SetValue
					option.SetValue = function(self, ...)
						option._OriginalSetValue(self, ...)
						if SaveManager.AutoSave and SaveManager.AutoSaveConfig and idx ~= "SaveManager_AutoSave" and not SaveManager._SettingAutoSave then
							task.spawn(function()
								SaveManager:Save(SaveManager.AutoSaveConfig)
							end)
						end
					end
				end
				if option.SetValueRGB and not option._OriginalSetValueRGB then
					option._OriginalSetValueRGB = option.SetValueRGB
					option.SetValueRGB = function(self, ...)
						option._OriginalSetValueRGB(self, ...)
						if SaveManager.AutoSave and SaveManager.AutoSaveConfig and not SaveManager._SettingAutoSave then
							task.spawn(function()
								SaveManager:Save(SaveManager.AutoSaveConfig)
							end)
						end
					end
				end
			end
		end)
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(`{self.Folder}/settings/autoload.txt`) then
			local name = readfile(`{self.Folder}/settings/autoload.txt`)

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = `Failed to load autoload config: {err}`,
					Duration = 7
				})
			end

			return self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Auto loaded config %q", name),
				Duration = 7
			})
		end

		return nil
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, "Must set SaveManager.Library")

		local section = tab:AddSection("Configuration")

		section:AddInput("SaveManager_ConfigName",    { Title = "Config name" })
		section:AddDropdown("SaveManager_ConfigList", {
			Title = "Config list",
			Values = self:RefreshConfigList(),
			AllowNull = true,
			Callback = function(Value)
				if SaveManager.AutoSave and not SaveManager._SettingAutoSave then
					SaveManager.AutoSaveConfig = Value
					local autoSaveData = {
						enabled = SaveManager.AutoSave,
						config = Value
					}
					writefile(`{self.Folder}/settings/autosave.json`, httpService:JSONEncode(autoSaveData))
				end
			end
		})

		section:AddButton({
			Title = "Create config",
			Callback = function()
				local name = SaveManager.Options.SaveManager_ConfigName.Value

				if name:gsub(" ", "") == "" then 
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Invalid config name (empty)",
						Duration = 7
					})
				end

				local success, err = self:Save(name)
				if not success then
					return self.Library:Notify({
						Title = "Interface",
						Content = "Config loader",
						SubContent = "Failed to save config: " .. err,
						Duration = 7
					})
				end

				self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = string.format("Created config %q", name),
					Duration = 7
				})

				SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
				SaveManager.Options.SaveManager_ConfigList:SetValue(nil)

				return nil
			end
		})

		section:AddButton({Title = "Load config", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to load config: " .. err,
					Duration = 7
				})
			end

			return self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Loaded config %q", name),
				Duration = 7
			})
		end})

		section:AddButton({Title = "Overwrite config", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify({
					Title = "Interface",
					Content = "Config loader",
					SubContent = "Failed to overwrite config: " .. err,
					Duration = 7
				})
			end

			return self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Overwrote config %q", name),
				Duration = 7
			})
		end})

		section:AddButton({Title = "Refresh list", Callback = function()
			SaveManager.Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			SaveManager.Options.SaveManager_ConfigList:SetValue(nil)
		end})

		local AutoloadButton
		AutoloadButton = section:AddButton({Title = "Set as autoload", Description = "Current autoload config: none", Callback = function()
			local name = SaveManager.Options.SaveManager_ConfigList.Value
			writefile(`{self.Folder}/settings/autoload.txt`, name)
			AutoloadButton:SetDesc("Current autoload config: " .. name)
			self.Library:Notify({
				Title = "Interface",
				Content = "Config loader",
				SubContent = string.format("Set %q to auto load", name),
				Duration = 7
			})
		end})

		if isfile(`{self.Folder}/settings/autoload.txt`) then
			local name = readfile(`{self.Folder}/settings/autoload.txt`)
			AutoloadButton:SetDesc("Current autoload config: " .. name)
		end

		if isfile(`{self.Folder}/settings/autosave.json`) then
			local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(`{self.Folder}/settings/autosave.json`))
			if success then
				SaveManager.AutoSave = decoded.enabled or false
				SaveManager.AutoSaveConfig = decoded.config or nil
			end
		end

		section:AddToggle("SaveManager_AutoSave", {
			Title = "Auto Save",
			Description = "Automatically save config when settings change",
			Default = SaveManager.AutoSave,
			Callback = function(Value)
				local selectedConfig = SaveManager.Options.SaveManager_ConfigList.Value

				if Value and not selectedConfig then
					self.Library:Notify({
						Title = "Interface",
						Content = "Auto Save",
						SubContent = "Please select a config from the list first",
						Duration = 7
					})
					SaveManager._SettingAutoSave = true
					task.spawn(function()
						SaveManager.Options.SaveManager_AutoSave:SetValue(false)
						SaveManager._SettingAutoSave = false
					end)
					return
				end

				SaveManager.AutoSave = Value
				SaveManager.AutoSaveConfig = selectedConfig

				local autoSaveData = {
					enabled = Value,
					config = selectedConfig
				}
				writefile(`{self.Folder}/settings/autosave.json`, httpService:JSONEncode(autoSaveData))

				if Value then
					self.Library:Notify({
						Title = "Interface",
						Content = "Auto Save",
						SubContent = string.format("Auto-saving to config %q", selectedConfig),
						Duration = 7
					})
				else
					self.Library:Notify({
						Title = "Interface",
						Content = "Auto Save",
						SubContent = "Auto-save disabled",
						Duration = 7
					})
				end
			end
		})

		SaveManager:SetIgnoreIndexes({ "SaveManager_ConfigList", "SaveManager_ConfigName", "SaveManager_AutoSave" })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
