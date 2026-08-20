local Players = game:GetService("Players")
local Web = game:GetService("HttpService")

local player = Players.LocalPlayer
local parent = player:WaitForChild("PlayerGui")
local frame = parent:WaitForChild("InGame"):WaitForChild("Frame")

local SUGGESTIONS = 6
local SOURCE = "https://raw.githubusercontent.com/idkwhattot/WordList/refs/heads/main/EnglishWords.json" --delet

local dictionary = {}
local prefixCache = {}

local screen = Instance.new("ScreenGui")
screen.Name = "AutoCompleteSuggestions"
screen.ResetOnSpawn = false
screen.Parent = parent

local labels = {}
for i = 1, SUGGESTIONS do
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Suggestion"..i
    lbl.Size = UDim2.fromOffset(220, 28)
    lbl.Position = UDim2.new(1, -230, 0, 10 + (i-1)*30)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 22
    lbl.TextXAlignment = Enum.TextXAlignment.Right
    lbl.Text = ""
    lbl.Parent = screen
    labels[i] = lbl
end

task.spawn(function()
    local success, content = pcall(function()
        return game:HttpGet(SOURCE)
    end)
    if not success then
        warn("Failed to download dictionary")
        return
    end

    local data = nil
    local ok = pcall(function()
        data = Web:JSONDecode(content)
    end)

    if not ok or type(data) ~= "table" then
        warn("Dictionary decode failed")
        return
    end

    for word in pairs(data) do
        dictionary[#dictionary+1] = word:lower()
    end
    table.sort(dictionary)
end)

-- Basically just binary search
local function findRange(prefix)
    local low, high = 1, #dictionary
    local startIdx, endIdx

    while low <= high do
        local mid = math.floor((low + high) / 2)
        if dictionary[mid]:sub(1, #prefix) < prefix then
            low = mid + 1
        else
            high = mid - 1
        end
    end
    startIdx = low

    low, high = startIdx, #dictionary
    while low <= high do
        local mid = math.floor((low + high) / 2)
        if dictionary[mid]:sub(1, #prefix) == prefix then
            low = mid + 1
        else
            high = mid - 1
        end
    end
    endIdx = high

    if startIdx > endIdx then
        return nil, nil
    end
    return startIdx, endIdx
end

-- Yes, I know this is a slightly autistic way of designing the UI.
local function getWord()
    local wordFrame = frame:FindFirstChild("CurrentWord")
    if not wordFrame or not wordFrame.Visible then
        return ""
    end

    local letters = {}
    local numbered = {}
    for _, child in ipairs(wordFrame:GetChildren()) do
        local idx = tonumber(child.Name)
        if idx and child:FindFirstChild("Letter") then
            numbered[#numbered+1] = {idx = idx, obj = child}
        end
    end

    table.sort(numbered, function(a,b) return a.idx < b.idx end)
    for _, entry in ipairs(numbered) do
        local letter = entry.obj.Letter.Text
        if type(letter) == "string" then
            letters[#letters+1] = letter
        end
    end

    return table.concat(letters):lower()
end

local lastInput = ""
local function update()
    local prefix = getWord()
    if prefix == lastInput then
        return
    end
    lastInput = prefix

    for i = 1, SUGGESTIONS do
        labels[i].Text = ""
    end

    if prefix == "" then
        return
    end

    local range = prefixCache[prefix]
    local sIdx, eIdx -- Start and end indexes, sorry for the naming

    if range then
        sIdx, eIdx = range[1], range[2]
    else
        sIdx, eIdx = findRange(prefix)
        if sIdx then
            prefixCache[prefix] = {sIdx, eIdx}
            if #prefixCache > 4 then
                for k in pairs(prefixCache) do
                    prefixCache[k] = nil
                    break
                end
            end
        end
    end

    if not sIdx then
        return
    end

    local count = 0
    for i = sIdx, eIdx do
        if count >= SUGGESTIONS then break end
        local w = dictionary[i]
        if w and w ~= prefix then
            count += 1
            labels[count].Text = w
        end
    end
end

local display = frame:WaitForChild("CurrentWord")
display.ChildAdded:Connect(update)
display.ChildRemoved:Connect(update)
