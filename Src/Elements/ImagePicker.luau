local TweenService = game:GetService("TweenService")
local Root = script.Parent.Parent
local Creator = require(Root.Modules.Creator)
local Flipper = require(Root.Packages.Flipper)

local New = Creator.New
local Spring = Flipper.Spring.new
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
		Opened = false,
		ImageButtons = {},
		Value = setmetatable({}, {
			__index = function(_, key)
				if key == "Selected" then
					return ImagePicker.SelectedImages
				end
				return rawget(ImagePicker, key)
			end
		})
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
	ImagePickerFrame.DescLabel.Size = UDim2.new(1, -170, 0, 14)

	ImagePicker.SetTitle = ImagePickerFrame.SetTitle
	ImagePicker.SetDesc = ImagePickerFrame.SetDesc

	local DisplayLabel = New("TextLabel", {
		FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Text = ImagePicker.MultiSelect and string.format("%d selected", #ImagePicker.SelectedImages) or (ImagePicker.SelectedImages[1] and "Selected" or "None"),
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Size = UDim2.new(1, -30, 0, 14),
		Position = UDim2.new(0, 8, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ThemeTag = {
			TextColor3 = "Text",
		},
	})

	local DropdownIco = New("ImageLabel", {
		Image = "rbxassetid://10709790948",
		Size = UDim2.fromOffset(16, 16),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		BackgroundTransparency = 1,
		ThemeTag = {
			ImageColor3 = "SubText",
		}
	})

	local PickerInner = New("TextButton", {
		Size = UDim2.fromOffset(160, 30),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundTransparency = 0.9,
		Parent = ImagePickerFrame.Frame,
		ThemeTag = {
			BackgroundColor3 = "DropdownFrame"
		}
	}, {
		New("UICorner", {
			CornerRadius = UDim.new(0, 5),
		}),
		New("UIStroke", {
			Transparency = 0.5,
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			ThemeTag = {
				Color = "InElementBorder",
			},
		}),
		DropdownIco,
		DisplayLabel,
	})

	-- Grid Layout for images
	local GridLayout = New("UIGridLayout", {
		CellSize = ImagePicker.ImageSize,
		CellPadding = UDim2.fromOffset(8, 8),
		FillDirection = Enum.FillDirection.Horizontal,
		FillMaxCells = ImagePicker.Columns,
		StartCorner = Enum.StartCorner.TopLeft,
	})

	local GridScrollFrame = New("ScrollingFrame", {
		Size = UDim2.new(1, -10, 1, -10),
		Position = UDim2.fromOffset(5, 5),
		BackgroundTransparency = 1,
		BottomImage = "rbxassetid://6889812791",
		MidImage = "rbxassetid://6889812721",
		TopImage = "rbxassetid://6276641225",
		ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255),
		ScrollBarImageTransparency = 0.95,
		ScrollBarThickness = 4,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromScale(0, 0),
	}, {
		GridLayout,
	})

	local PickerHolderFrame = New("Frame", {
		Size = UDim2.fromScale(1, 0.6),
		ThemeTag = {
			BackgroundColor3 = "DropdownHolder",
		},
	}, {
		GridScrollFrame,
		New("UICorner", {
			CornerRadius = UDim.new(0, 7),
		}),
		New("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			ThemeTag = {
				Color = "DropdownBorder",
			},
		}),
		New("ImageLabel", {
			BackgroundTransparency = 1,
			Image = "http://www.roblox.com/asset/?id=5554236805",
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(23, 23, 277, 277),
			Size = UDim2.fromScale(1, 1) + UDim2.fromOffset(30, 30),
			Position = UDim2.fromOffset(-15, -15),
			ImageColor3 = Color3.fromRGB(0, 0, 0),
			ImageTransparency = 0.1,
		}),
	})

	local PickerHolderCanvas = New("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(300, 300),
		Parent = self.Library.GUI,
		Visible = false,
	}, {
		PickerHolderFrame,
		New("UISizeConstraint", {
			MinSize = Vector2.new(280, 200),
		}),
	})

	Library.OpenFrames[#Library.OpenFrames + 1] = PickerHolderCanvas

	local function RecalculatePickerPosition()
		local Add = 0
		local Camera = game:GetService("Workspace").CurrentCamera
		if Camera.ViewportSize.Y - PickerInner.AbsolutePosition.Y < PickerHolderCanvas.AbsoluteSize.Y - 5 then
			Add = PickerHolderCanvas.AbsoluteSize.Y
				- 5
				- (Camera.ViewportSize.Y - PickerInner.AbsolutePosition.Y)
				+ 40
		end
		PickerHolderCanvas.Position =
			UDim2.fromOffset(PickerInner.AbsolutePosition.X - 1, PickerInner.AbsolutePosition.Y - 5 - Add)
	end

	local function RecalculateCanvasSize()
		GridScrollFrame.CanvasSize = UDim2.fromOffset(0, GridLayout.AbsoluteContentSize.Y + 10)
	end

	local function UpdateDisplay()
		if ImagePicker.MultiSelect then
			DisplayLabel.Text = string.format("%d selected", #ImagePicker.SelectedImages)
		else
			DisplayLabel.Text = ImagePicker.SelectedImages[1] and "Selected" or "None"
		end
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

			UpdateDisplay()
			
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
			ImageButton.Parent = GridScrollFrame
		end

		RecalculateCanvasSize()
	end

	function ImagePicker:Open()
		ImagePicker.Opened = true
		self.ScrollFrame.ScrollingEnabled = false
		PickerHolderCanvas.Visible = true
		PickerHolderFrame:TweenSize(
			UDim2.fromScale(1, 1),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quart,
			.2
		)

		ImagePicker:BuildImageList()

		-- Update button states based on current selection
		for ImageUrl, ButtonData in next, ImagePicker.ImageButtons do
			if IsImageSelected(ImageUrl) then
				ButtonData.Selector.Visible = true
				ButtonData.Button.BackgroundTransparency = 0.3
			else
				ButtonData.Selector.Visible = false
				ButtonData.Button.BackgroundTransparency = 0.5
			end
		end

		RecalculatePickerPosition()
	end

	function ImagePicker:Close()
		ImagePicker.Opened = false
		self.ScrollFrame.ScrollingEnabled = true
		PickerHolderFrame:TweenSize(
			UDim2.fromScale(1, 0),
			Enum.EasingDirection.Out,
			Enum.EasingStyle.Quart,
			.2
		)
		task.wait(0.2)
		PickerHolderCanvas.Visible = false
	end

	function ImagePicker:SetValue(Images)
		if typeof(Images) == "table" then
			ImagePicker.SelectedImages = Images
		else
			ImagePicker.SelectedImages = {Images}
		end
		UpdateDisplay()
		
		if typeof(ImagePicker.Callback) == "function" then
			Library:SafeCallback(ImagePicker.Callback, ImagePicker.SelectedImages)
		end
		if typeof(ImagePicker.Changed) == "function" then
			Library:SafeCallback(ImagePicker.Changed, ImagePicker.SelectedImages)
		end
	end

	function ImagePicker:SetImages(NewImages)
		ImagePicker.Images = NewImages
		if ImagePicker.Opened then
			ImagePicker:BuildImageList()
		end
	end

	function ImagePicker:OnChanged(Func)
		ImagePicker.Changed = Func
		Library:SafeCallback(Func, ImagePicker.SelectedImages)
	end

	function ImagePicker:Destroy()
		ImagePickerFrame:Destroy()
		PickerHolderCanvas:Destroy()
		Library.Options[Idx] = nil
	end

	Creator.AddSignal(PickerInner.MouseButton1Click, function()
		if ImagePicker.Opened then
			ImagePicker:Close()
		else
			ImagePicker:Open()
		end
	end)

	Creator.AddSignal(PickerInner:GetPropertyChangedSignal("AbsolutePosition"), RecalculatePickerPosition)

	-- Initialize
	UpdateDisplay()
	RecalculatePickerPosition()

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