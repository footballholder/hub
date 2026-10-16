-- Football Hub UI
-- custom ui

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local isStudio = RunService:IsStudio()
local isExploit = (writefile ~= nil) or (gethui ~= nil)

local ParentGui
if isStudio then
	ParentGui = LocalPlayer:WaitForChild("PlayerGui")
else
	ParentGui = (gethui and gethui()) or CoreGui
end

-- newer clients support ellipsis on long labels
local canTruncate = pcall(function()
	local probe = Instance.new("TextLabel")
	probe.TextTruncate = Enum.TextTruncate.AtEnd
	local probe2 = Instance.new("TextButton")
	probe2.TextTruncate = Enum.TextTruncate.AtEnd
end)

local function new(class, props)
	local inst = Instance.new(class)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	if canTruncate and not (props and props.TextWrapped) and (class == "TextLabel" or class == "TextButton") then
		inst.TextTruncate = Enum.TextTruncate.AtEnd
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(obj, radius)
	return new("UICorner", { CornerRadius = UDim.new(0, radius or 6), Parent = obj })
end

local function tween(obj, props, time)
	local ok, tw = pcall(function()
		return TweenService:Create(obj, TweenInfo.new(time or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	end)
	if ok and tw then
		tw:Play()
		return tw
	end
end

local function draggable(handle, win)
	local dragging, dragInput, dragStart, startPos

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = win.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	handle.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			win.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

local Library = {
	CurrentTheme = "Slate",
	ThemeObjects = {},
	Flags = {},
	FlagCallbacks = {},
	SaveFileName = "FootballHub.json",
	Themes = {
		Slate = {
			Main = Color3.fromRGB(23, 23, 26),
			Sidebar = Color3.fromRGB(17, 17, 20),
			Panel = Color3.fromRGB(30, 30, 34),
			Element = Color3.fromRGB(38, 38, 43),
			Hover = Color3.fromRGB(47, 47, 53),
			Border = Color3.fromRGB(52, 52, 59),
			Accent = Color3.fromRGB(122, 134, 255),
			Text = Color3.fromRGB(237, 238, 242),
			Dim = Color3.fromRGB(140, 142, 152),
			Danger = Color3.fromRGB(240, 92, 92),
		},
		Obsidian = {
			Main = Color3.fromRGB(18, 18, 18),
			Sidebar = Color3.fromRGB(12, 12, 12),
			Panel = Color3.fromRGB(25, 25, 25),
			Element = Color3.fromRGB(32, 32, 32),
			Hover = Color3.fromRGB(41, 41, 41),
			Border = Color3.fromRGB(46, 46, 46),
			Accent = Color3.fromRGB(235, 235, 235),
			Text = Color3.fromRGB(240, 240, 240),
			Dim = Color3.fromRGB(132, 132, 132),
			Danger = Color3.fromRGB(230, 80, 80),
		},
		Emerald = {
			Main = Color3.fromRGB(19, 24, 22),
			Sidebar = Color3.fromRGB(13, 18, 16),
			Panel = Color3.fromRGB(26, 33, 30),
			Element = Color3.fromRGB(33, 42, 38),
			Hover = Color3.fromRGB(42, 53, 48),
			Border = Color3.fromRGB(48, 60, 55),
			Accent = Color3.fromRGB(60, 220, 130),
			Text = Color3.fromRGB(233, 240, 236),
			Dim = Color3.fromRGB(134, 150, 142),
			Danger = Color3.fromRGB(240, 92, 92),
		},
		Midnight = {
			Main = Color3.fromRGB(20, 20, 28),
			Sidebar = Color3.fromRGB(14, 14, 21),
			Panel = Color3.fromRGB(27, 27, 38),
			Element = Color3.fromRGB(34, 34, 47),
			Hover = Color3.fromRGB(43, 43, 58),
			Border = Color3.fromRGB(50, 50, 68),
			Accent = Color3.fromRGB(168, 130, 255),
			Text = Color3.fromRGB(236, 235, 245),
			Dim = Color3.fromRGB(140, 138, 160),
			Danger = Color3.fromRGB(240, 92, 92),
		},
	},
}

local function theme()
	return Library.Themes[Library.CurrentTheme]
end

function Library:AddCustomTheme(name, colors)
	self.Themes[name] = colors
end

function Library:RegisterTheme(inst, prop, key)
	table.insert(self.ThemeObjects, { Inst = inst, Prop = prop, Key = key })
	inst[prop] = self.Themes[self.CurrentTheme][key]
	return inst
end

function Library:SetTheme(name)
	if not self.Themes[name] then
		return
	end
	self.CurrentTheme = name
	local t = self.Themes[name]
	for _, o in ipairs(self.ThemeObjects) do
		if o.Inst and o.Inst.Parent then
			tween(o.Inst, { [o.Prop] = t[o.Key] }, 0.25)
		end
	end
	self:Save()
end

function Library:Save()
	local ok, json = pcall(function()
		return HttpService:JSONEncode(self.Flags)
	end)
	if ok and isExploit and writefile then
		pcall(writefile, self.SaveFileName, json)
	end
end

function Library:Load()
	if not (isExploit and readfile and isfile) then
		return
	end
	if not isfile(self.SaveFileName) then
		return
	end
	local ok, json = pcall(readfile, self.SaveFileName)
	if not ok then
		return
	end
	local ok2, data = pcall(function()
		return HttpService:JSONDecode(json)
	end)
	if not ok2 or type(data) ~= "table" then
		return
	end
	for flag, value in pairs(data) do
		self.Flags[flag] = value
		if self.FlagCallbacks[flag] then
			pcall(self.FlagCallbacks[flag], value)
		end
	end
end

Players.PlayerRemoving:Connect(function(plr)
	if plr == LocalPlayer then
		Library:Save()
	end
end)

-- element builder, everything appended to target gets stacked by a UIListLayout
local function makeElements(target, owner)
	local API = {}

	-- group boxes can chain back to the tab so a build function can keep rebinding
	function API:CreateGroupbox(o)
		if not owner then
			return self
		end
		return owner:CreateGroupbox(o)
	end

	function API:CreateSection(name)
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, Parent = target })
		local lbl = new("TextLabel", {
			Size = UDim2.new(1, -14, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = string.upper(name),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = theme().Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Library:RegisterTheme(lbl, "TextColor3", "Dim")
		local dot = new("Frame", { Size = UDim2.new(0, 3, 0, 12), Position = UDim2.new(0, 0, 0.5, -6), BackgroundColor3 = theme().Accent, BorderSizePixel = 0, Parent = row })
		corner(dot, 2)
		Library:RegisterTheme(dot, "BackgroundColor3", "Accent")
		return row
	end

	function API:CreateLabel(text)
		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = theme().Element, Parent = target })
		corner(row, 6)
		Library:RegisterTheme(row, "BackgroundColor3", "Element")
		local lbl = new("TextLabel", {
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = text,
			TextWrapped = true,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = theme().Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Library:RegisterTheme(lbl, "TextColor3", "Text")
		return { Set = function(_, t) lbl.Text = t end }
	end

	function API:CreateButton(o)
		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = theme().Element,
			Text = "",
			AutoButtonColor = false,
			Parent = target,
		})
		corner(btn, 6)
		Library:RegisterTheme(btn, "BackgroundColor3", "Element")
		local lbl = new("TextLabel", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			Text = o.Name,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = theme().Text,
			Parent = btn,
		})
		Library:RegisterTheme(lbl, "TextColor3", "Text")
		btn.MouseEnter:Connect(function() tween(btn, { BackgroundColor3 = theme().Hover }, 0.12) end)
		btn.MouseLeave:Connect(function() tween(btn, { BackgroundColor3 = theme().Element }, 0.12) end)
		btn.MouseButton1Click:Connect(function()
			if o.Callback then
				pcall(o.Callback)
			end
		end)
		return btn
	end

	function API:CreateToggle(o)
		local flag = o.Flag or o.Name
		local state = o.CurrentValue or false
		Library.Flags[flag] = state

		local row = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 34),
			BackgroundColor3 = theme().Element,
			Text = "",
			AutoButtonColor = false,
			Parent = target,
		})
		corner(row, 6)
		Library:RegisterTheme(row, "BackgroundColor3", "Element")
		local lbl = new("TextLabel", {
			Size = UDim2.new(1, -68, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = o.Name,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = theme().Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Library:RegisterTheme(lbl, "TextColor3", "Text")

		local sw = new("Frame", { Size = UDim2.new(0, 34, 0, 18), Position = UDim2.new(1, -46, 0.5, -9), BackgroundColor3 = theme().Border, Parent = row })
		corner(sw, 9)
		local knob = new("Frame", { Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(0, 3, 0.5, -6), BackgroundColor3 = Color3.fromRGB(255, 255, 255), Parent = sw })
		corner(knob, 6)

		local function Fire(v)
			state = v and true or false
			Library.Flags[flag] = state
			tween(knob, { Position = state and UDim2.new(0, 19, 0.5, -6) or UDim2.new(0, 3, 0.5, -6) }, 0.15)
			tween(sw, { BackgroundColor3 = state and theme().Accent or theme().Border }, 0.15)
			if o.Callback then
				pcall(o.Callback, state)
			end
		end

		row.MouseButton1Click:Connect(function() Fire(not state) end)
		Library.FlagCallbacks[flag] = Fire
		Fire(state)
		return { Set = function(_, v) Fire(v) end }
	end

	function API:CreateSlider(o)
		local flag = o.Flag or o.Name
		local min, max = o.Range[1], o.Range[2]
		local val = o.CurrentValue or min
		Library.Flags[flag] = val

		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = theme().Element, Parent = target })
		corner(row, 6)
		Library:RegisterTheme(row, "BackgroundColor3", "Element")
		local lbl = new("TextLabel", {
			Size = UDim2.new(1, -80, 0, 20),
			Position = UDim2.new(0, 12, 0, 6),
			BackgroundTransparency = 1,
			Text = o.Name,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = theme().Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Library:RegisterTheme(lbl, "TextColor3", "Text")
		local valueLbl = new("TextLabel", {
			Size = UDim2.new(0, 60, 0, 20),
			Position = UDim2.new(1, -72, 0, 6),
			BackgroundTransparency = 1,
			Text = tostring(val),
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = theme().Accent,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
		Library:RegisterTheme(valueLbl, "TextColor3", "Accent")

		local hit = new("TextButton", { Size = UDim2.new(1, -24, 0, 16), Position = UDim2.new(0, 12, 0, 30), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = row })
		local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3), BackgroundColor3 = theme().Border, Parent = hit })
		corner(bar, 3)
		Library:RegisterTheme(bar, "BackgroundColor3", "Border")
		local fill = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BackgroundColor3 = theme().Accent, Parent = bar })
		corner(fill, 3)
		Library:RegisterTheme(fill, "BackgroundColor3", "Accent")

		local function Fire(v)
			local inc = o.Increment or 1
			v = math.clamp(tonumber(v) or min, min, max)
			v = math.floor(v / inc + 0.5) * inc
			val = v
			Library.Flags[flag] = val
			valueLbl.Text = tostring(val)
			local pct = (max - min) == 0 and 0 or (val - min) / (max - min)
			tween(fill, { Size = UDim2.new(pct, 0, 1, 0) }, 0.1)
			if o.Callback then
				pcall(o.Callback, val)
			end
		end

		hit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				local function update()
					local pct = math.clamp((Mouse.X - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
					Fire(min + ((max - min) * pct))
				end
				update()
				local move, release
				move = Mouse.Move:Connect(update)
				release = UserInputService.InputEnded:Connect(function(e)
					if e.UserInputType == Enum.UserInputType.MouseButton1 then
						move:Disconnect()
						release:Disconnect()
					end
				end)
			end
		end)

		Library.FlagCallbacks[flag] = Fire
		Fire(val)
		return { Set = function(_, v) Fire(v) end }
	end

	function API:CreateDropdown(o)
		local flag = o.Flag or o.Name
		local options = o.Options or {}
		local val = o.CurrentOption or options[1]
		Library.Flags[flag] = val

		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = theme().Element, ClipsDescendants = true, Parent = target })
		corner(row, 6)
		Library:RegisterTheme(row, "BackgroundColor3", "Element")
		local btn = new("TextButton", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = row })
		local lbl = new("TextLabel", {
			Size = UDim2.new(1, -130, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = o.Name,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = theme().Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = btn,
		})
		Library:RegisterTheme(lbl, "TextColor3", "Text")
		local valLbl = new("TextLabel", {
			Size = UDim2.new(0, 118, 1, 0),
			Position = UDim2.new(1, -24, 0, 0),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundTransparency = 1,
			Text = tostring(val) .. "  v",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = theme().Dim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = btn,
		})
		Library:RegisterTheme(valLbl, "TextColor3", "Dim")

		local list = new("Frame", { Size = UDim2.new(1, -16, 0, 0), Position = UDim2.new(0, 8, 0, 36), BackgroundTransparency = 1, Parent = row })
		new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = list })

		local open = false

		local function layout()
			local h = 0
			for _, c in ipairs(list:GetChildren()) do
				if c:IsA("TextButton") then
					h = h + c.Size.Y.Offset + 4
				end
			end
			h = math.max(h - 4, 0)
			list.Size = UDim2.new(1, -16, 0, h)
			row.Size = UDim2.new(1, 0, 0, open and (42 + h) or 34)
		end

		local function Fire(v)
			val = v
			Library.Flags[flag] = val
			valLbl.Text = tostring(val) .. "  v"
			if o.Callback then
				pcall(o.Callback, val)
			end
		end

		for _, opt in ipairs(options) do
			local ob = new("TextButton", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = theme().Sidebar, Text = "", AutoButtonColor = false, Parent = list })
			corner(ob, 5)
			local ol = new("TextLabel", {
				Size = UDim2.new(1, -16, 1, 0),
				Position = UDim2.new(0, 8, 0, 0),
				BackgroundTransparency = 1,
				Text = tostring(opt),
				Font = Enum.Font.Gotham,
				TextSize = 12,
				TextColor3 = theme().Dim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = ob,
			})
			ob.MouseEnter:Connect(function() tween(ob, { BackgroundColor3 = theme().Hover }, 0.1) end)
			ob.MouseLeave:Connect(function() tween(ob, { BackgroundColor3 = theme().Sidebar }, 0.1) end)
			ob.MouseButton1Click:Connect(function()
				Fire(opt)
				open = false
				for _, c in ipairs(list:GetChildren()) do
					if c:IsA("TextButton") then
						local l = c:FindFirstChildOfClass("TextLabel")
						if l then
							l.TextColor3 = (l.Text == tostring(val)) and theme().Accent or theme().Dim
						end
					end
				end
				layout()
			end)
		end

		btn.MouseButton1Click:Connect(function()
			open = not open
			layout()
		end)

		Library.FlagCallbacks[flag] = Fire
		Fire(val)
		return { Set = function(_, v) Fire(v) end }
	end

	function API:CreateTextbox(o)
		local flag = o.Flag or o.Name
		local val = o.CurrentValue or ""
		Library.Flags[flag] = val

		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = theme().Element, Parent = target })
		corner(row, 6)
		Library:RegisterTheme(row, "BackgroundColor3", "Element")
		local lbl = new("TextLabel", {
			Size = UDim2.new(0.42, -12, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = o.Name,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = theme().Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Library:RegisterTheme(lbl, "TextColor3", "Text")
		local box = new("TextBox", {
			Size = UDim2.new(0.58, -24, 0, 24),
			Position = UDim2.new(0.42, 0, 0.5, -12),
			BackgroundColor3 = theme().Sidebar,
			Text = val,
			PlaceholderText = o.PlaceholderText or "",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = theme().Text,
			PlaceholderColor3 = theme().Dim,
			ClearTextOnFocus = false,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		corner(box, 5)
		Library:RegisterTheme(box, "BackgroundColor3", "Sidebar")
		Library:RegisterTheme(box, "TextColor3", "Text")

		local function Fire(v)
			val = v
			box.Text = v
			Library.Flags[flag] = val
			if o.Callback then
				pcall(o.Callback, val)
			end
		end

		box.FocusLost:Connect(function() Fire(box.Text) end)
		Library.FlagCallbacks[flag] = Fire
		return { Set = function(_, v) Fire(v) end }
	end

	function API:CreateKeybind(o)
		local flag = o.Flag or o.Name
		local key = o.CurrentKey or "None"
		Library.Flags[flag] = key

		local row = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = theme().Element, Parent = target })
		corner(row, 6)
		Library:RegisterTheme(row, "BackgroundColor3", "Element")
		local lbl = new("TextLabel", {
			Size = UDim2.new(1, -100, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Text = o.Name,
			Font = Enum.Font.Gotham,
			TextSize = 13,
			TextColor3 = theme().Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Library:RegisterTheme(lbl, "TextColor3", "Text")
		local chip = new("TextButton", {
			Size = UDim2.new(0, 78, 0, 22),
			Position = UDim2.new(1, -90, 0.5, -11),
			BackgroundColor3 = theme().Sidebar,
			Text = key,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextColor3 = theme().Accent,
			AutoButtonColor = false,
			Parent = row,
		})
		corner(chip, 5)
		Library:RegisterTheme(chip, "BackgroundColor3", "Sidebar")
		Library:RegisterTheme(chip, "TextColor3", "Accent")

		local binding = false

		local function Fire(k)
			if typeof(k) == "EnumItem" then
				k = k.Name
			end
			if k == "" then
				k = "None"
			end
			key = k
			Library.Flags[flag] = key
			chip.Text = key
		end

		chip.MouseButton1Click:Connect(function()
			binding = true
			chip.Text = "..."
		end)

		UserInputService.InputBegan:Connect(function(input, gpe)
			if binding then
				if input.KeyCode == Enum.KeyCode.Backspace or input.KeyCode == Enum.KeyCode.Escape then
					Fire("None")
				elseif input.UserInputType == Enum.UserInputType.Keyboard then
					Fire(input.KeyCode)
				elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.MouseButton3 then
					Fire(input.UserInputType)
				end
				binding = false
			elseif not gpe and key ~= "None" then
				if input.KeyCode.Name == key or input.UserInputType.Name == key then
					if o.Callback then
						pcall(o.Callback, key)
					end
				end
			end
		end)

		Library.FlagCallbacks[flag] = Fire
		return { Set = function(_, k) Fire(k) end }
	end

	return API
end

-- group box: a titled panel on one side of the page
local function makeGroupbox(parentCol, o, owner)
	local box = new("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = theme().Panel, Parent = parentCol })
	corner(box, 8)
	Library:RegisterTheme(box, "BackgroundColor3", "Panel")

	local title = new("TextLabel", {
		Size = UDim2.new(1, -20, 0, 30),
		Position = UDim2.new(0, 12, 0, 6),
		BackgroundTransparency = 1,
		Text = o.Name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = theme().Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = box,
	})
	Library:RegisterTheme(title, "TextColor3", "Text")

	local divider = new("Frame", { Size = UDim2.new(1, -20, 0, 1), Position = UDim2.new(0, 10, 0, 36), BackgroundColor3 = theme().Border, BorderSizePixel = 0, Parent = box })
	Library:RegisterTheme(divider, "BackgroundColor3", "Border")

	local inner = new("Frame", { Size = UDim2.new(1, -20, 0, 0), Position = UDim2.new(0, 10, 0, 44), BackgroundTransparency = 1, Parent = box })
	local layout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = inner })
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		inner.Size = UDim2.new(1, -20, 0, layout.AbsoluteContentSize.Y)
		box.Size = UDim2.new(1, 0, 0, 44 + layout.AbsoluteContentSize.Y + 10)
	end)

	local api = makeElements(inner, owner)
	api.Frame = box
	return api
end

function Library:CreateWindow(options)
	options = options or {}
	self.SaveFileName = (options.SaveName or "FootballHub") .. ".json"
	if self.Themes[options.Theme or ""] then
		self.CurrentTheme = options.Theme
	end

	local old = ParentGui:FindFirstChild("FootballHubUi")
	if old then
		old:Destroy()
	end

	local gui = new("ScreenGui", {
		Name = "FootballHubUi",
		ResetOnSpawn = false,
		DisplayOrder = 999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = ParentGui,
	})

	local size = typeof(options.Size) == "UDim2" and options.Size or UDim2.new(0, 650, 0, 430)
	local pos = typeof(options.Position) == "UDim2" and options.Position or UDim2.new(0.5, 0, 0.5, 0)

	local main = new("Frame", {
		Name = "Main",
		Size = size,
		Position = pos,
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = theme().Main,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Visible = true,
		Parent = gui,
	})
	corner(main, 10)
	new("UIScale", { Scale = 1, Parent = main })
	self:RegisterTheme(main, "BackgroundColor3", "Main")

	local sidebar = new("Frame", { Size = UDim2.new(0, 170, 1, 0), BackgroundColor3 = theme().Sidebar, BorderSizePixel = 0, Parent = main })
	corner(sidebar, 10)
	local sidebarFill = new("Frame", { Size = UDim2.new(0, 14, 1, 0), Position = UDim2.new(1, -14, 0, 0), BackgroundColor3 = theme().Sidebar, BorderSizePixel = 0, Parent = sidebar })
	self:RegisterTheme(sidebar, "BackgroundColor3", "Sidebar")
	self:RegisterTheme(sidebarFill, "BackgroundColor3", "Sidebar")

	local brand = new("TextLabel", {
		Size = UDim2.new(1, -28, 0, 22),
		Position = UDim2.new(0, 16, 0, 18),
		BackgroundTransparency = 1,
		Text = options.Name or "Football Hub",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = theme().Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sidebar,
	})
	self:RegisterTheme(brand, "TextColor3", "Text")
	local sub = new("TextLabel", {
		Size = UDim2.new(1, -28, 0, 14),
		Position = UDim2.new(0, 16, 0, 40),
		BackgroundTransparency = 1,
		Text = options.Subtitle or "",
		Font = Enum.Font.Gotham,
		TextSize = 11,
		TextColor3 = theme().Dim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = sidebar,
	})
	self:RegisterTheme(sub, "TextColor3", "Dim")

	local tabScroll = new("ScrollingFrame", {
		Size = UDim2.new(1, -16, 1, -84),
		Position = UDim2.new(0, 8, 0, 70),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		Parent = sidebar,
	})
	local tabLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4), Parent = tabScroll })
	tabLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		tabScroll.CanvasSize = UDim2.new(0, 0, 0, tabLayout.AbsoluteContentSize.Y + 10)
	end)

	local content = new("Frame", { Size = UDim2.new(1, -170, 1, 0), Position = UDim2.new(0, 170, 0, 0), BackgroundTransparency = 1, Parent = main })

	local header = new("Frame", { Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1, Parent = content })
	local pageTitle = new("TextLabel", {
		Size = UDim2.new(1, -110, 1, 0),
		Position = UDim2.new(0, 18, 0, 0),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = theme().Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = header,
	})
	self:RegisterTheme(pageTitle, "TextColor3", "Text")

	local closeBtn = new("TextButton", {
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(1, -38, 0.5, -13),
		BackgroundColor3 = theme().Element,
		Text = "x",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = theme().Dim,
		AutoButtonColor = false,
		Parent = header,
	})
	corner(closeBtn, 6)
	local minBtn = new("TextButton", {
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(1, -70, 0.5, -13),
		BackgroundColor3 = theme().Element,
		Text = "-",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = theme().Dim,
		AutoButtonColor = false,
		Parent = header,
	})
	corner(minBtn, 6)

	local pages = new("Frame", { Size = UDim2.new(1, -16, 1, -52), Position = UDim2.new(0, 8, 0, 44), BackgroundTransparency = 1, Parent = content })

	draggable(brand, main)
	draggable(sub, main)
	draggable(header, main)

	local Window = { Tabs = {}, CurrentTab = nil, Gui = gui, Main = main, Pages = pages }

	local floatBtn = new("TextButton", {
		Size = UDim2.new(0, 130, 0, 32),
		Position = UDim2.new(0.5, -65, 0, 40),
		BackgroundColor3 = theme().Main,
		Text = options.Name or "Football Hub",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = theme().Text,
		AutoButtonColor = false,
		Visible = false,
		Parent = gui,
	})
	corner(floatBtn, 8)
	self:RegisterTheme(floatBtn, "BackgroundColor3", "Main")
	self:RegisterTheme(floatBtn, "TextColor3", "Text")
	draggable(floatBtn, floatBtn)
	floatBtn.MouseButton1Click:Connect(function()
		main.Visible = true
		floatBtn.Visible = false
	end)

	closeBtn.MouseButton1Click:Connect(function()
		gui.Enabled = false
	end)
	closeBtn.MouseEnter:Connect(function() tween(closeBtn, { TextColor3 = theme().Danger }, 0.12) end)
	closeBtn.MouseLeave:Connect(function() tween(closeBtn, { TextColor3 = theme().Dim }, 0.12) end)
	minBtn.MouseButton1Click:Connect(function()
		main.Visible = false
		floatBtn.Visible = true
	end)
	minBtn.MouseEnter:Connect(function() tween(minBtn, { TextColor3 = theme().Text }, 0.12) end)
	minBtn.MouseLeave:Connect(function() tween(minBtn, { TextColor3 = theme().Dim }, 0.12) end)

	function Window:SelectTab(tab)
		for _, t in ipairs(self.Tabs) do
			t.Content.Visible = (t == tab)
			tween(t.Btn, { BackgroundTransparency = (t == tab) and 0.45 or 1 }, 0.15)
			tween(t.Bar, { BackgroundTransparency = (t == tab) and 0 or 1 }, 0.15)
			tween(t.Label, { TextColor3 = (t == tab) and theme().Text or theme().Dim }, 0.15)
		end
		self.CurrentTab = tab
		pageTitle.Text = tab and tab.Name or ""
	end

	function Window:CreateTab(name)
		local btn = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = theme().Element,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			Parent = tabScroll,
		})
		corner(btn, 7)
		local bar = new("Frame", { Size = UDim2.new(0, 3, 0, 16), Position = UDim2.new(0, 2, 0.5, -8), BackgroundColor3 = theme().Accent, BorderSizePixel = 0, BackgroundTransparency = 1, Parent = btn })
		corner(bar, 2)
		local lbl = new("TextLabel", {
			Size = UDim2.new(1, -20, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Text = name,
			Font = Enum.Font.GothamMedium,
			TextSize = 13,
			TextColor3 = theme().Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = btn,
		})

		local page = new("ScrollingFrame", {
			Size = UDim2.new(1, 0, 1, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = theme().Accent,
			CanvasSize = UDim2.new(0, 0, 0, 0),
			Visible = false,
			Parent = pages,
		})
		self:RegisterTheme(page, "ScrollBarImageColor3", "Accent")

		local pageLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = page })
		local full = new("Frame", { Size = UDim2.new(1, -16, 0, 0), LayoutOrder = 1, BackgroundTransparency = 1, Parent = page })
		local fullLayout = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6), Parent = full })
		local cols = new("Frame", { Size = UDim2.new(1, -16, 0, 0), LayoutOrder = 2, BackgroundTransparency = 1, Parent = page })
		local left = new("Frame", { Size = UDim2.new(0.5, -6, 0, 0), BackgroundTransparency = 1, Parent = cols })
		local right = new("Frame", { Size = UDim2.new(0.5, -6, 0, 0), Position = UDim2.new(0.5, 6, 0, 0), BackgroundTransparency = 1, Parent = cols })
		local ll = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = left })
		local rl = new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), Parent = right })

		local function refresh()
			local h = math.max(left.Size.Y.Offset, right.Size.Y.Offset)
			cols.Size = UDim2.new(1, -16, 0, h)
			page.CanvasSize = UDim2.new(0, 0, 0, pageLayout.AbsoluteContentSize.Y + 24)
		end
		pageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(refresh)
		fullLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			full.Size = UDim2.new(1, -16, 0, fullLayout.AbsoluteContentSize.Y)
			refresh()
		end)
		ll:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			left.Size = UDim2.new(0.5, -6, 0, ll.AbsoluteContentSize.Y)
			refresh()
		end)
		rl:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			right.Size = UDim2.new(0.5, -6, 0, rl.AbsoluteContentSize.Y)
			refresh()
		end)

		local Tab = { Name = name, Btn = btn, Bar = bar, Label = lbl, Content = page, Left = left, Right = right, Full = full }

		local api = makeElements(full, Tab)
		for k, v in pairs(api) do
			Tab[k] = v
		end

		function Tab:CreateGroupbox(o)
			o = o or {}
			return makeGroupbox((o.Side == "Right") and right or left, o)
		end

		btn.MouseButton1Click:Connect(function() Window:SelectTab(Tab) end)
		table.insert(self.Tabs, Tab)
		if #self.Tabs == 1 then
			Window:SelectTab(Tab)
		end
		return Tab
	end

	local notifHolder = new("Frame", { Size = UDim2.new(0, 300, 1, -40), Position = UDim2.new(1, -320, 0, 20), BackgroundTransparency = 1, Parent = gui })
	new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = notifHolder })

	function Library:Notify(o)
		o = o or {}
		local nf = new("Frame", { Size = UDim2.new(0, 280, 0, 58), BackgroundColor3 = theme().Panel, BackgroundTransparency = 1, Parent = notifHolder })
		corner(nf, 8)
		local bar = new("Frame", { Size = UDim2.new(0, 3, 1, -18), Position = UDim2.new(0, 9, 0, 9), BackgroundColor3 = theme().Accent, BorderSizePixel = 0, Parent = nf })
		corner(bar, 2)
		local t = new("TextLabel", {
			Size = UDim2.new(1, -32, 0, 18),
			Position = UDim2.new(0, 20, 0, 9),
			BackgroundTransparency = 1,
			Text = o.Title or "Notice",
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextColor3 = theme().Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTransparency = 1,
			Parent = nf,
		})
		local d = new("TextLabel", {
			Size = UDim2.new(1, -32, 0, 26),
			Position = UDim2.new(0, 20, 0, 27),
			BackgroundTransparency = 1,
			Text = o.Text or "",
			Font = Enum.Font.Gotham,
			TextSize = 12,
			TextColor3 = theme().Dim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			TextTransparency = 1,
			Parent = nf,
		})
		tween(nf, { BackgroundTransparency = 0 }, 0.2)
		tween(t, { TextTransparency = 0 }, 0.2)
		tween(d, { TextTransparency = 0 }, 0.2)
		task.delay(o.Duration or 4, function()
			if not nf.Parent then
				return
			end
			tween(nf, { BackgroundTransparency = 1 }, 0.25)
			tween(t, { TextTransparency = 1 }, 0.25)
			tween(d, { TextTransparency = 1 }, 0.25)
			task.wait(0.3)
			nf:Destroy()
		end)
	end

	function Library:Toggle()
		gui.Enabled = not gui.Enabled
	end

	function Library:SetVisible(v)
		gui.Enabled = v and true or false
	end

	function Library:Destroy()
		gui:Destroy()
	end

	return Window
end

return Library



