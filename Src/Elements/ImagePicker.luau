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

	-- Grid Layout for image containers
	local GridLayout = New("UIGridLayout", {
		CellSize = UDim2.fromOffset(100, 120),
		CellPadding = UDim2.fromOffset(10, 10),
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
		ZIndex = 1,
	}, {
		New("UIPadding", {
			PaddingTop = UDim.new(0, 50),
		}),
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

		-- Main container for image + button
		local Container = New("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, {
			New("UIListLayout", {
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})

		-- Image container with spacing
		local ImageContainer = New("Frame", {
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundTransparency = 1,
			LayoutOrder = 1,
		}, {
			New("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
			}),
			New("ImageLabel", {
				Size = UDim2.fromOffset(80, 80),
				BackgroundTransparency = 1,
				Image = ImageUrl,
				ScaleType = ImageData.ScaleType or Enum.ScaleType.Stretch,
				ImageRectOffset = ImageData.ImageRectOffset or Vector2.zero,
				ImageRectSize = ImageData.ImageRectSize or Vector2.zero,
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.fromScale(0.5, 0),
			}, {
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
			}),
		})

		-- Selector highlight (accent color) - now just a border highlight
		local Selector = New("Frame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundColor3 = Color3.fromRGB(76, 194, 255),
			Position = UDim2.fromOffset(0, 0),
			AnchorPoint = Vector2.new(0, 0),
			Visible = false,
			ZIndex = 1,
			BackgroundTransparency = 0.7,
			ThemeTag = {
				BackgroundColor3 = "Accent",
			}
		}, {
			New("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),
		})

		-- Button that looks like dropdown button
		local SelectButton = New("TextButton", {
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 0.9,
			BackgroundColor3 = Color3.fromRGB(60, 60, 60),
			Text = "Select",
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
			TextSize = 13,
			TextColor3 = Color3.fromRGB(240, 240, 240),
			LayoutOrder = 2,
			ZIndex = 3,
			ThemeTag = {
				BackgroundColor3 = "DropdownFrame",
				TextColor3 = "Text",
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
		})

		ImageContainer.Parent = Container
		SelectButton.Parent = Container
		Selector.Parent = SelectButton

		ImagePicker.ImageButtons[ImageUrl] = {
			Button = SelectButton,
			Selector = Selector,
			ImageId = ImageUrl,
			Container = Container
		}

		Creator.AddSignal(SelectButton.MouseButton1Click, function()
			local ButtonData = ImagePicker.ImageButtons[ImageUrl]
			if ImagePicker.MultiSelect then
				if IsImageSelected(ImageUrl) then
					-- Deselect
					for i, SelectedId in next, ImagePicker.SelectedImages do
						if SelectedId == ImageUrl then
							table.remove(ImagePicker.SelectedImages, i)
							break
						end
					end
					ButtonData.Selector.Visible = false
					SelectButton.BackgroundTransparency = 0.9
					SelectButton.Text = "Select"
				else
					-- Select
					table.insert(ImagePicker.SelectedImages, ImageUrl)
					ButtonData.Selector.Visible = true
					SelectButton.BackgroundTransparency = 0.7
					SelectButton.Text = "Selected"
				end
			else
				-- Single select - clear previous selection
				for _, ButtonData in next, ImagePicker.ImageButtons do
					ButtonData.Selector.Visible = false
					ButtonData.Button.BackgroundTransparency = 0.9
					ButtonData.Button.Text = "Select"
				end
				ImagePicker.SelectedImages = {ImageUrl}
				ButtonData.Selector.Visible = true
				SelectButton.BackgroundTransparency = 0.7
				SelectButton.Text = "Selected"
			end

			if typeof(ImagePicker.Callback) == "function" then
				Library:SafeCallback(ImagePicker.Callback, ImagePicker.SelectedImages)
			end
			if typeof(ImagePicker.Changed) == "function" then
				Library:SafeCallback(ImagePicker.Changed, ImagePicker.SelectedImages)
			end
		end)

		Creator.AddSignal(SelectButton.MouseEnter, function()
			if not IsImageSelected(ImageUrl) then
				SelectButton.BackgroundTransparency = 0.7
			end
		end)

		Creator.AddSignal(SelectButton.MouseLeave, function()
			if not IsImageSelected(ImageUrl) then
				SelectButton.BackgroundTransparency = 0.9
			end
		end)

		return Container
	end

	function ImagePicker:BuildImageList()
		-- Clear existing buttons
		for _, ButtonData in next, ImagePicker.ImageButtons do
			ButtonData.Container:Destroy()
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
				ButtonData.Button.BackgroundTransparency = 0.7
				ButtonData.Button.Text = "Selected"
			else
				ButtonData.Selector.Visible = false
				ButtonData.Button.BackgroundTransparency = 0.9
				ButtonData.Button.Text = "Select"
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
			ButtonData.Button.BackgroundTransparency = 0.7
			ButtonData.Button.Text = "Selected"
		else
			ButtonData.Selector.Visible = false
			ButtonData.Button.BackgroundTransparency = 0.9
			ButtonData.Button.Text = "Select"
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
