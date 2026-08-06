local Root = script.Parent.Parent
local Creator = require(Root.Modules.Creator)

local New = Creator.New
local Components = Root.Components

local Element = {}
Element.__index = Element
Element.__type = "ImagePicker"

function Element:New(Idx, Config)
	local Library = self.Library
	assert(Config.Title, "ImagePicker - Missing Title")
	assert(Config.Images, "ImagePicker - Missing Images table")

	local ImagePicker = {
		Images = Config.Images or {},
		SelectedImages = {},
		Columns = Config.Columns or 3,
		MultiSelect = Config.MultiSelect or false,
		ImageSize = Config.ImageSize or UDim2.fromOffset(80, 80),
		Callback = Config.Callback or function(Selected) end,
		Changed = Config.Changed or function(Selected) end,
		Type = "ImagePicker",
		ImageButtons = {},
	}

	-- Initialize selected images
	if Config.Default then
		if ImagePicker.MultiSelect then
			ImagePicker.SelectedImages = typeof(Config.Default) == "table" and Config.Default or {Config.Default}
		else
			ImagePicker.SelectedImages = {Config.Default}
		end
	end

	local ImagePickerFrame = require(Components.Element)(Config.Title, Config.Description, self.Container, false)
	ImagePickerFrame.DescLabel.Size = UDim2.new(1, 0, 0, 14)

	ImagePicker.SetTitle = ImagePickerFrame.SetTitle
	ImagePicker.SetDesc = ImagePickerFrame.SetDesc

	-- Grid Layout for images
	local GridLayout = New("UIGridLayout", {
		CellSize = ImagePicker.ImageSize,
		CellPadding = UDim2.fromOffset(8, 8),
		FillDirection = Enum.FillDirection.Horizontal,
		FillDirectionMaxCells = ImagePicker.Columns,
		StartCorner = Enum.StartCorner.TopLeft,
	})

	local GridFrame = New("Frame", {
		Size = UDim2.new(1, -20, 0, 0),
		Position = UDim2.fromOffset(10, 0),
		BackgroundTransparency = 1,
		Parent = ImagePickerFrame.Frame,
		AutomaticSize = Enum.AutomaticSize.Y,
	}, {
		GridLayout,
	})

	local function RecalculateGridSize()
		ImagePickerFrame.Frame.Size = UDim2.new(1, 0, 0, ImagePickerFrame.LabelHolder.AbsoluteSize.Y + GridFrame.AbsoluteSize.Y + 10)
	end

	local function IsImageSelected(ImageId)
		for _, SelectedId in next, ImagePicker.SelectedImages do
			if SelectedId == ImageId then
				return true
			end
		end
		return false
	end

	local function CreateImageButton(ImageId, Index)
		local ImageData = typeof(ImageId) == "table" and ImageId or {Id = ImageId}
		local ImageUrl = ImageData.Id or ImageId

		local Selector = New("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(76, 194, 255),
			Position = UDim2.fromOffset(0, 0),
			AnchorPoint = Vector2.new(0, 0),
			Visible = false,
			ThemeTag = {
				BackgroundColor3 = "Accent",
			}
		}, {
			New("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
		})

		local ImageLabel = New("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = ImageUrl,
			ScaleType = ImageData.ScaleType or Enum.ScaleType.Stretch,
			ImageRectOffset = ImageData.ImageRectOffset or Vector2.zero,
			ImageRectSize = ImageData.ImageRectSize or Vector2.zero,
		})

		local ImageButton = New("TextButton", {
			Size = ImagePicker.ImageSize,
			BackgroundTransparency = 0.5,
			BackgroundColor3 = Color3.fromRGB(60, 60, 60),
			Text = "",
			ThemeTag = {
				BackgroundColor3 = "DropdownOption",
			}
		}, {
			Selector,
			ImageLabel,
			New("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
			New("UIStroke", {
				Transparency = 0.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				ThemeTag = {
					Color = "InElementBorder",
				},
			}),
		})

		ImagePicker.ImageButtons[ImageUrl] = {
			Button = ImageButton,
			Selector = Selector,
			ImageId = ImageUrl
		}

		Creator.AddSignal(ImageButton.MouseButton1Click, function()
			if ImagePicker.MultiSelect then
				if IsImageSelected(ImageUrl) then
					-- Deselect
					for i, SelectedId in next, ImagePicker.SelectedImages do
						if SelectedId == ImageUrl then
							table.remove(ImagePicker.SelectedImages, i)
							break
						end
					end
					Selector.Visible = false
					ImageButton.BackgroundTransparency = 0.5
				else
					-- Select
					table.insert(ImagePicker.SelectedImages, ImageUrl)
					Selector.Visible = true
					ImageButton.BackgroundTransparency = 0.3
				end
			else
				-- Single select - clear previous selection
				for _, ButtonData in next, ImagePicker.ImageButtons do
					ButtonData.Selector.Visible = false
					ButtonData.Button.BackgroundTransparency = 0.5
				end
				ImagePicker.SelectedImages = {ImageUrl}
				Selector.Visible = true
				ImageButton.BackgroundTransparency = 0.3
			end
			
			if typeof(ImagePicker.Callback) == "function" then
				Library:SafeCallback(ImagePicker.Callback, ImagePicker.SelectedImages)
			end
			if typeof(ImagePicker.Changed) == "function" then
				Library:SafeCallback(ImagePicker.Changed, ImagePicker.SelectedImages)
			end
		end)

		Creator.AddSignal(ImageButton.MouseEnter, function()
			if not IsImageSelected(ImageUrl) then
				ImageButton.BackgroundTransparency = 0.3
			end
		end)

		Creator.AddSignal(ImageButton.MouseLeave, function()
			if not IsImageSelected(ImageUrl) then
				ImageButton.BackgroundTransparency = 0.5
			end
		end)

		return ImageButton
	end

	function ImagePicker:BuildImageList()
		-- Clear existing buttons
		for _, ButtonData in next, ImagePicker.ImageButtons do
			ButtonData.Button:Destroy()
		end
		ImagePicker.ImageButtons = {}

		-- Create new buttons
		for i, ImageId in next, ImagePicker.Images do
			local ImageButton = CreateImageButton(ImageId, i)
			ImageButton.Parent = GridFrame
		end

		RecalculateGridSize()
	end

	function ImagePicker:SetValue(Images)
		if typeof(Images) == "table" then
			ImagePicker.SelectedImages = Images
		else
			ImagePicker.SelectedImages = {Images}
		end
		
		-- Update button states
		for ImageUrl, ButtonData in next, ImagePicker.ImageButtons do
			if IsImageSelected(ImageUrl) then
				ButtonData.Selector.Visible = true
				ButtonData.Button.BackgroundTransparency = 0.3
			else
				ButtonData.Selector.Visible = false
				ButtonData.Button.BackgroundTransparency = 0.5
			end
		end
		
		if typeof(ImagePicker.Callback) == "function" then
			Library:SafeCallback(ImagePicker.Callback, ImagePicker.SelectedImages)
		end
		if typeof(ImagePicker.Changed) == "function" then
			Library:SafeCallback(ImagePicker.Changed, ImagePicker.SelectedImages)
		end
	end

	function ImagePicker:SetImages(NewImages)
		ImagePicker.Images = NewImages
		ImagePicker:BuildImageList()
	end

	function ImagePicker:OnChanged(Func)
		ImagePicker.Changed = Func
		Library:SafeCallback(Func, ImagePicker.SelectedImages)
	end

	function ImagePicker:Destroy()
		ImagePickerFrame:Destroy()
		Library.Options[Idx] = nil
	end

	-- Build the initial image list
	ImagePicker:BuildImageList()

	-- Set initial button states
	for ImageUrl, ButtonData in next, ImagePicker.ImageButtons do
		if IsImageSelected(ImageUrl) then
			ButtonData.Selector.Visible = true
			ButtonData.Button.BackgroundTransparency = 0.3
		else
			ButtonData.Selector.Visible = false
			ButtonData.Button.BackgroundTransparency = 0.5
		end
	end

	-- Register in Library.Options
	Library.Options[Idx] = ImagePicker

	return setmetatable(ImagePicker, {
		__index = function(self, key)
			if key == "Value" then
				return ImagePicker.SelectedImages
			end
			return rawget(ImagePicker, key) or Element[key]
		end
	})
end

return Element