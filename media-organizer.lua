-- ================================================
-- Media Organizer
-- Part of PostFlows toolkit for DaVinci Resolve
-- https://github.com/postflows
-- ================================================

local resolve = Resolve()
if not resolve then
    print("Error: Resolve API is not available.")
    return
end

local project = resolve:GetProjectManager():GetCurrentProject()
if not project then
    print("Error: No project is open.")
    return
end

local mediaPool = project:GetMediaPool()
if not mediaPool then
    print("Error: Media Pool is not available.")
    return
end

local ui = fu.UIManager
local disp = bmd.UIDispatcher(ui)

local winID = "OrganizerWindow"
local folderDialogID = "FolderDialog"
local organizeID = "OrganizeButton"
local statusID = "StatusLabel"

local selectedFolders = {}
local rootFolderName = nil

local RAW_CODECS = {
    "BRAW", "Blackmagic RAW", "R3D", "RED RAW", "RED", "ARRIRAW",
    "Cinema DNG", "CinemaDNG", "Sony RAW", "X-OCN", "X-OCN ST", "X-OCN LT",
    "ProRes RAW", "Canon RAW", "Canon Cinema RAW Light", "Z CAM ZRAW"
}

local PRIMARY_COLOR = "#c0c0c0"
local BORDER_COLOR = "#3a6ea5"
local TEXT_COLOR = "#ebebeb"

local START_LOGO_CSS = [[
    QLabel {
        color: #62b6cb;
        font-size: 22px;
        font-weight: bold;
        letter-spacing: 1px;
        font-family: 'Futura';
    }
]]
local END_LOGO_CSS = [[
    QLabel {
        color: rgb(255, 255, 255);
        font-size: 22px;
        font-weight: bold;
        letter-spacing: 1px;
        font-family: 'Futura';
    }
]]
local CHECKBOX_STYLE = [[
    QCheckBox { spacing: 12px; color: #ebebeb; font-size: 12px; }
    QCheckBox::indicator { width: 20px; height: 20px; border: 2px solid #3a6ea5; }
    QCheckBox::indicator:checked { background-color: #c0c0c0; }
    QCheckBox:disabled { color: #808080; }
    QCheckBox::indicator:disabled { border: 2px solid #5a5a5a; background-color: #2a2a2a; }
]]
local BUTTON_STYLE = [[
    QPushButton { background-color: #4C956C; color: #FFFFFF; font-size: 16px; border-radius: 14px; min-height: 30px; }
    QPushButton:hover { background-color: #61B15A; }
    QPushButton:disabled { background-color: #3a6ea5; color: #808080; }
]]
local PRIMARY_ACTION_BUTTON_STYLE = [[
    QPushButton {
        border: 1px solid #2C6E49;
        max-height: 40px;
        border-radius: 14px;
        background-color: #4C956C;
        color: #FFFFFF;
        min-height: 30px;
        font-size: 16px;
        font-weight: bold;
    }
    QPushButton:hover { border: 1px solid ]] .. PRIMARY_COLOR .. [[; background-color: #61B15A; }
    QPushButton:pressed { border: 2px solid ]] .. PRIMARY_COLOR .. [[; background-color: #76C893; }
]]
local SECONDARY_ACTION_BUTTON_STYLE = [[
    QPushButton {
        border: 1px solid #bc4749;
        max-height: 28px;
        border-radius: 14px;
        background-color: #bc4749;
        color: #FFFFFF;
        min-height: 28px;
        font-size: 13px;
        font-weight: bold;
    }
    QPushButton:hover { border: 1px solid ]] .. PRIMARY_COLOR .. [[; background-color: #f07167; }
    QPushButton:pressed { border: 2px solid ]] .. PRIMARY_COLOR .. [[; background-color: #D00000; }
]]
local THIRD_ACTION_BUTTON_STYLE = [[
    QPushButton {
        border: 1px solid rgb(71,91,98);
        max-height: 28px;
        border-radius: 14px;
        background-color: rgb(71,91,98);
        color: rgb(255, 255, 255);
        min-height: 28px;
        font-size: 13px;
    }
    QPushButton:hover { border: 1px solid rgb(176,176,176); background-color: rgb(89,90,183); }
    QPushButton:pressed { border: 2px solid rgb(119,121,252); background-color: rgb(119,121,252); }
    QPushButton:disabled { border: 2px solid #bc4749; background-color: #bc4749; color: rgb(150, 150, 150); }
]]
local LABEL_STYLE = "QLabel { color: #ebebeb; font-size: 13px; font-weight: bold; padding: 5px 0; }"
local STATUS_S_LABEL_STYLE = "QLabel { color: #c0c0c0; font-size: 10px; font-weight: bold; padding: 5px 0; }"

local function isRawCodec(clip)
    local codec = clip:GetClipProperty("Video Codec") or ""
    local upper = codec:upper()
    for _, raw in ipairs(RAW_CODECS) do
        if upper:find(raw:upper(), 1, true) then
            return true
        end
    end
    return false
end

local function getClipKeywords(clip)
    local keywords = clip:GetMetadata("Keywords")
    if keywords and keywords ~= "" then
        local list = {}
        for part in string.gmatch(keywords, "[^,]+") do
            table.insert(list, part:match("^%s*(.-)%s*$"))
        end
        return list
    end
    return {}
end

local function getAllClipsIterative(folders, rootOnly, includeVideo, includeAudio, includeTimeline, includeCompound, includeFusion, includeSubtitle, includeMulticam)
    local clips = {}
    local stack = {}
    if type(folders) == "table" and not folders[1] then
        for _, f in pairs(folders) do table.insert(stack, f) end
    else
        for _, f in ipairs(folders or {}) do table.insert(stack, f) end
    end
    while #stack > 0 do
        local current = table.remove(stack)
        local list = current:GetClipList()
        if list then
            for _, c in ipairs(list) do
                table.insert(clips, c)
            end
        end
        if not rootOnly then
            local subList = current:GetSubFolderList()
            if subList then
                for _, sub in ipairs(subList) do
                    table.insert(stack, sub)
                end
            end
        end
    end
    local filtered = {}
    for _, clip in ipairs(clips) do
        local clipType = clip:GetClipProperty("Type") or ""
        if includeFusion and (clipType == "Fusion" or clipType == "Fusion Title" or clipType == "Generator") then
            table.insert(filtered, clip)
        elseif includeAudio and clipType == "Audio" then
            table.insert(filtered, clip)
        elseif includeTimeline and clipType == "Timeline" then
            table.insert(filtered, clip)
        elseif includeCompound and clipType == "Compound" then
            table.insert(filtered, clip)
        elseif includeSubtitle and clipType == "Subtitle" then
            table.insert(filtered, clip)
        elseif includeMulticam and clipType == "Multicam" then
            table.insert(filtered, clip)
        elseif includeVideo and (clipType == "Video + Audio" or clipType == "Video" or clipType == "Still") then
            table.insert(filtered, clip)
        end
    end
    return filtered
end

local function getAllFoldersRecursive(folder, parentPath)
    parentPath = parentPath or ""
    local result = {}
    local folderName = folder:GetName()
    local currentPath = (parentPath ~= "") and (parentPath .. "/" .. folderName) or folderName
    result[currentPath] = folder
    local subList = folder:GetSubFolderList()
    if subList then
        for _, sub in ipairs(subList) do
            for path, f in pairs(getAllFoldersRecursive(sub, currentPath)) do
                result[path] = f
            end
        end
    end
    return result
end

local function getFolderAndDescendants(folder)
    local list = {folder}
    local subList = folder:GetSubFolderList()
    if subList then
        for _, sub in ipairs(subList) do
            for _, f in ipairs(getFolderAndDescendants(sub)) do
                table.insert(list, f)
            end
        end
    end
    return list
end

local function getSelectedFoldersFromDialog(tree)
    local rootFolder = mediaPool:GetRootFolder()
    local allFolders = getAllFoldersRecursive(rootFolder)
    allFolders["Root"] = rootFolder
    local selectedItems = tree:SelectedItems()
    if not selectedItems or #selectedItems == 0 then
        return {}
    end
    local result = {}
    for _, item in ipairs(selectedItems) do
        local itemText = item.Text[0] or ""
        local folderPath = (itemText ~= "Root") and ((rootFolderName or "") .. "/" .. itemText) or "Root"
        local folder = allFolders[folderPath]
        if folder then
            for _, f in ipairs(getFolderAndDescendants(folder)) do
                table.insert(result, f)
            end
        end
    end
    return result
end

local function deleteEmptyFolders(folders)
    if type(folders) ~= "table" then
        folders = {folders}
    end
    local rootFolder = mediaPool:GetRootFolder()
    for _, folder in ipairs(folders) do
        local subList = folder:GetSubFolderList()
        if subList then
            for _, subfolder in ipairs(subList) do
                deleteEmptyFolders({subfolder})
                local clips = subfolder:GetClipList() or {}
                local subSub = subfolder:GetSubFolderList() or {}
                if #clips == 0 and #subSub == 0 then
                    if mediaPool:DeleteFolders({subfolder}) then
                        print("Deleted empty folder: " .. tostring(subfolder:GetName() or "?"))
                    end
                end
            end
        end
    end
end

local function addFoldersToTree(tree, folder, parentItem, currentPath)
    local subList = folder:GetSubFolderList()
    if not subList then return end
    local names = {}
    for _, sub in ipairs(subList) do
        table.insert(names, {name = sub:GetName(), folder = sub})
    end
    table.sort(names, function(a, b) return a.name < b.name end)
    for _, entry in ipairs(names) do
        local subfolder = entry.folder
        local row = tree:NewItem()
        local subName = subfolder:GetName() or ""
        local subfolderPath = (currentPath ~= "Root") and (currentPath .. "/" .. subName) or subName
        row.Text[0] = subfolderPath
        parentItem:AddChild(row)
        addFoldersToTree(tree, subfolder, row, subfolderPath)
    end
    parentItem:SetExpanded(true)
end

local function populateFolders(tree)
    tree:Clear()
    tree:SetSelectionMode("ExtendedSelection")
    tree:SetHeaderHidden(true)
    local rootFolder = mediaPool:GetRootFolder()
    rootFolderName = rootFolder:GetName()
    local rootItem = tree:NewItem()
    rootItem.Text[0] = "Root"
    tree:AddTopLevelItem(rootItem)
    addFoldersToTree(tree, rootFolder, rootItem, "Root")
end

local function matchesMediaType(clip, filePath, mediaType)
    local clipType = clip:GetClipProperty("Type") or ""
    filePath = filePath or ""
    local fpLower = filePath:lower()
    if mediaType == "Video" then
        return (clipType == "Video + Audio" or clipType == "Video") and not isRawCodec(clip) and not fpLower:match("%.exr$")
    elseif mediaType == "Audio" then return clipType == "Audio"
    elseif mediaType == "Timeline" then return clipType == "Timeline"
    elseif mediaType == "Compound" then return clipType == "Compound"
    elseif mediaType == "Fusion" then return clipType == "Fusion"
    elseif mediaType == "Fusion Titles" then return clipType == "Fusion Title"
    elseif mediaType == "Fusion Generators" then return clipType == "Generator"
    elseif mediaType == "Subtitle" then return clipType == "Subtitle"
    elseif mediaType == "Still" then
        return clipType == "Still" and not fpLower:match("%.exr$")
    elseif mediaType == "Multicam" then return clipType == "Multicam"
    end
    return false
end

local function organizeMedia(ev)
    local winItems = win:GetItems()
    local statusLabel = winItems[statusID]
    local ok, err = pcall(function()
        local rootOnly = winItems.rootOnlyCheckbox.Checked
        local useSelected = winItems.selectedFolderCheckbox.Checked
        local useKeywords = winItems.keywordsCheckbox.Checked
        local deleteEmpty = winItems.deleteEmptyCheckbox.Checked
        local rootFolder = mediaPool:GetRootFolder()
        local folders
        if useSelected then
            folders = {mediaPool:GetCurrentFolder()}
        elseif #selectedFolders > 0 then
            folders = selectedFolders
        else
            folders = {rootFolder}
        end
        local mediaTypes = {}
        local checkboxMap = {
            Video = "videoCheckbox",
            Audio = "audioCheckbox",
            Timeline = "timelineCheckbox",
            Compound = "compoundCheckbox",
            Fusion = "fusionCheckbox",
            Subtitle = "subtitleCheckbox",
            Still = "stillCheckbox",
            Multicam = "multicamCheckbox"
        }
        for mediaType, cbId in pairs(checkboxMap) do
            if winItems[cbId] and winItems[cbId].Checked then
                mediaTypes[mediaType] = {}
                if mediaType == "Fusion" then
                    mediaTypes["Fusion Titles"] = {}
                    mediaTypes["Fusion Generators"] = {}
                end
            end
        end
        if winItems.videoCheckbox and winItems.videoCheckbox.Checked then
            mediaTypes["RAW"] = {}
            mediaTypes["Sequences"] = {}
        end
        statusLabel.Text = "Analyzing files..."
        local clips = getAllClipsIterative(folders, rootOnly,
            winItems.videoCheckbox and winItems.videoCheckbox.Checked or (winItems.stillCheckbox and winItems.stillCheckbox.Checked),
            winItems.audioCheckbox and winItems.audioCheckbox.Checked,
            winItems.timelineCheckbox and winItems.timelineCheckbox.Checked,
            winItems.compoundCheckbox and winItems.compoundCheckbox.Checked,
            winItems.fusionCheckbox and winItems.fusionCheckbox.Checked,
            winItems.subtitleCheckbox and winItems.subtitleCheckbox.Checked,
            winItems.multicamCheckbox and winItems.multicamCheckbox.Checked)
        statusLabel.Text = "Moving files..."
        local movedCount = 0
        local errorCount = 0
        local existingFolders = {}
        local subList = rootFolder:GetSubFolderList()
        if subList then
            for _, folder in ipairs(subList) do
                existingFolders[folder:GetName()] = folder
            end
        end
        for _, clip in ipairs(clips) do
            local filePath = clip:GetClipProperty("File Path") or ""
            local clipType = clip:GetClipProperty("Type") or ""
            if mediaTypes["RAW"] and (clipType == "Video + Audio" or clipType == "Video") and isRawCodec(clip) then
                table.insert(mediaTypes["RAW"], clip)
            elseif mediaTypes["Sequences"] and (clipType == "Video + Audio" or clipType == "Video" or clipType == "Still") and filePath:lower():match("%.exr$") then
                table.insert(mediaTypes["Sequences"], clip)
            else
                for mediaType, _ in pairs(mediaTypes) do
                    if mediaType ~= "RAW" and mediaType ~= "Sequences" and matchesMediaType(clip, filePath, mediaType) then
                        table.insert(mediaTypes[mediaType], clip)
                        break
                    end
                end
            end
        end
        for folderName, clipsList in pairs(mediaTypes) do
            if #clipsList > 0 then
                local targetFolder = existingFolders[folderName]
                if not targetFolder then
                    targetFolder = mediaPool:AddSubFolder(rootFolder, folderName)
                    existingFolders[folderName] = targetFolder
                end
                local keywordFolders = {}
                local subList = targetFolder:GetSubFolderList()
                if subList then
                    for _, f in ipairs(subList) do
                        keywordFolders[f:GetName()] = f
                    end
                end
                local keywordGroups = {}
                for _, clip in ipairs(clipsList) do
                    if useKeywords then
                        local keywords = getClipKeywords(clip)
                        if #keywords > 0 then
                            local kw = keywords[1]
                            if not keywordGroups[kw] then keywordGroups[kw] = {} end
                            table.insert(keywordGroups[kw], clip)
                        else
                            if mediaPool:MoveClips({clip}, targetFolder) then
                                movedCount = movedCount + 1
                            else
                                errorCount = errorCount + 1
                            end
                        end
                    else
                        if mediaPool:MoveClips({clip}, targetFolder) then
                            movedCount = movedCount + 1
                        else
                            errorCount = errorCount + 1
                        end
                    end
                end
                if useKeywords then
                    for keyword, keywordClips in pairs(keywordGroups) do
                        local kf = keywordFolders[keyword]
                        if not kf then
                            kf = mediaPool:AddSubFolder(targetFolder, keyword)
                            keywordFolders[keyword] = kf
                        end
                        for _, clip in ipairs(keywordClips) do
                            if mediaPool:MoveClips({clip}, kf) then
                                movedCount = movedCount + 1
                            else
                                errorCount = errorCount + 1
                            end
                        end
                    end
                end
            end
        end
        if deleteEmpty then
            statusLabel.Text = "Removing empty folders..."
            deleteEmptyFolders(folders)
        end
        statusLabel.Text = string.format("Complete! Moved %d files, %d errors.", movedCount, errorCount)
    end)
    if not ok then
        statusLabel.Text = "Error: " .. tostring(err)
        print("Error: " .. tostring(err))
    end
end

local function onRootOnlyClicked(ev)
    local winItems = win:GetItems()
    if winItems.rootOnlyCheckbox.Checked then
        winItems.selectedFolderCheckbox.Checked = false
        winItems.selectFoldersButton.Enabled = false
    else
        winItems.selectFoldersButton.Enabled = true
    end
end

local function onSelectedFolderClicked(ev)
    local winItems = win:GetItems()
    if winItems.selectedFolderCheckbox.Checked then
        winItems.rootOnlyCheckbox.Checked = false
        winItems.selectFoldersButton.Enabled = false
    else
        winItems.selectFoldersButton.Enabled = true
    end
end

local function onSelectFoldersClicked(ev)
    local folderDialog = disp:AddWindow({
        ID = folderDialogID,
        WindowTitle = "Select Folders",
        WindowFlags = {Window = true, WindowStaysOnTopHint = true},
        Geometry = {150, 150, 300, 400},
        MinimumSize = {300, 300}
    }, ui:VGroup({
        ID = "folderDialogRoot"
    }, {
        ui:Label({Text = "Select Folders", Weight = 0, StyleSheet = LABEL_STYLE}),
        ui:Tree({ID = "FolderTree", Weight = 3, MinimumSize = {0, 300}}),
        ui:VGap(10),
        ui:HGroup({Weight = 0, Spacing = 10}, {
            ui:Button({ID = "okButton", Text = "OK", MinimumSize = {80, 30}, StyleSheet = BUTTON_STYLE}),
            ui:Button({ID = "cancelButton", Text = "Cancel", MinimumSize = {80, 30}, StyleSheet = SECONDARY_ACTION_BUTTON_STYLE})
        })
    }))
    local tree = folderDialog:Find("FolderTree")
    populateFolders(tree)
    function folderDialog.On.okButton.Clicked(ev2)
        selectedFolders = getSelectedFoldersFromDialog(tree)
        local winItems = win:GetItems()
        if #selectedFolders > 0 then
            local names = {}
            for _, folder in ipairs(selectedFolders) do
                table.insert(names, folder:GetName())
            end
            winItems.selectedFoldersLabel.Text = "Selected: " .. table.concat(names, ", ")
        else
            winItems.selectedFoldersLabel.Text = "No folders selected"
        end
        disp:ExitLoop()
    end
    function folderDialog.On.cancelButton.Clicked(ev2)
        disp:ExitLoop()
    end
    folderDialog.On[folderDialogID].Close = function(ev2) disp:ExitLoop() end
    folderDialog:Show()
    disp:RunLoop()
    folderDialog:Hide()
end

-- Find existing window
local existingWin = ui:FindWindow(winID)
if existingWin then
    existingWin:Show()
    existingWin:Raise()
    return
end

local layout = ui:VGroup(
    {ID = "root"},
    {
        ui:HGroup({
            ui:Label({Weight = 0, Text = "Media", StyleSheet = START_LOGO_CSS}),
            ui:Label({Weight = 0, Text = "Organizer", StyleSheet = END_LOGO_CSS, Margin = -1.75})
        }),
        ui:VGap(10),
        ui:HGroup({Weight = 0, Spacing = 10}, {
            ui:VGroup({Weight = 0}, {
                ui:CheckBox({ID = "videoCheckbox", Text = "Video", Checked = false, StyleSheet = CHECKBOX_STYLE}),
                ui:CheckBox({ID = "audioCheckbox", Text = "Audio", Checked = false, StyleSheet = CHECKBOX_STYLE}),
                ui:CheckBox({ID = "timelineCheckbox", Text = "Timelines", Checked = false, StyleSheet = CHECKBOX_STYLE}),
                ui:CheckBox({ID = "compoundCheckbox", Text = "Compound Clips", Checked = false, StyleSheet = CHECKBOX_STYLE})
            }),
            ui:VGroup({Weight = 0}, {
                ui:CheckBox({ID = "fusionCheckbox", Text = "Fusion", Checked = false, StyleSheet = CHECKBOX_STYLE}),
                ui:CheckBox({ID = "subtitleCheckbox", Text = "Subtitles", Checked = false, StyleSheet = CHECKBOX_STYLE}),
                ui:CheckBox({ID = "stillCheckbox", Text = "Stills", Checked = false, StyleSheet = CHECKBOX_STYLE}),
                ui:CheckBox({ID = "multicamCheckbox", Text = "Multicam", Checked = false, StyleSheet = CHECKBOX_STYLE})
            })
        }),
        ui:VGap(5),
        ui:Label({Text = "Folders to Process", Weight = 0, StyleSheet = LABEL_STYLE}),
        ui:HGroup({Weight = 0, Spacing = 5}, {
            ui:Button({ID = "selectFoldersButton", Text = "Select Folders", ToolTip = "Select folders to process", MinimumSize = {100, 20}, StyleSheet = THIRD_ACTION_BUTTON_STYLE})
        }),
        ui:Label({ID = "selectedFoldersLabel", Text = "No folders selected", Weight = 0, StyleSheet = STATUS_S_LABEL_STYLE}),
        ui:VGap(5),
        ui:Label({Text = "Organize Options", Weight = 0, StyleSheet = LABEL_STYLE}),
        ui:VGroup({Weight = 0, Spacing = 10}, {
            ui:CheckBox({ID = "rootOnlyCheckbox", Text = "Check root folder only", Checked = false, StyleSheet = CHECKBOX_STYLE}),
            ui:CheckBox({ID = "selectedFolderCheckbox", Text = "Use selected Mediapool folder only", Checked = false, StyleSheet = CHECKBOX_STYLE}),
            ui:CheckBox({ID = "keywordsCheckbox", Text = "Create subfolders by keywords", Checked = true, StyleSheet = CHECKBOX_STYLE}),
            ui:CheckBox({ID = "deleteEmptyCheckbox", Text = "Delete empty bins", Checked = false, StyleSheet = CHECKBOX_STYLE})
        }),
        ui:VGap(5),
        ui:HGroup({Weight = 0, Spacing = 10}, {
            ui:Button({ID = organizeID, Text = "Organize Media", ToolTip = "Organize media by type", MinimumSize = {150, 30}, StyleSheet = BUTTON_STYLE})
        }),
        ui:VGap(5),
        ui:HGroup({Weight = 0}, {
            ui:Label({ID = statusID, Text = "Ready", Weight = 1, StyleSheet = STATUS_S_LABEL_STYLE})
        })
    }
)

win = disp:AddWindow({
    ID = winID,
    WindowTitle = "Media Organizer",
    Events = {Close = true},
    FixedSize = {270, 550},
    MinimumSize = {270, 300},
    MaximumSize = {270, 600}
}, layout)

win.On["selectFoldersButton"].Clicked = onSelectFoldersClicked
win.On["rootOnlyCheckbox"].Clicked = onRootOnlyClicked
win.On["selectedFolderCheckbox"].Clicked = onSelectedFolderClicked
win.On[organizeID].Clicked = organizeMedia
win.On[winID].Close = function(ev) disp:ExitLoop() end

win:Show()
disp:RunLoop()
