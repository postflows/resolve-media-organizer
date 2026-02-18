# ================================================
# Media Organizer
# Part of PostFlows toolkit for DaVinci Resolve
# https://github.com/postflows
# ================================================

script = {
    'name': 'Media Organizer',
    'version': '1.0',
    'author': 'https://github.com/postflows'
}

ui = fu.UIManager
dispatcher = bmd.UIDispatcher(ui)
project = resolve.GetProjectManager().GetCurrentProject()
mediapool = project.GetMediaPool()

winID = 'OrganizerWindow'
folderDialogID = 'FolderDialog'
organizeID = 'OrganizeButton'
statusID = 'StatusLabel'

# Global variables
selected_folders = []  # Selected folders from dialog
root_folder_name = None  # Root folder name

RAW_CODECS = [
    "BRAW", "Blackmagic RAW", "R3D", "RED RAW", "RED", "ARRIRAW",
    "Cinema DNG", "CinemaDNG", "Sony RAW", "X-OCN", "X-OCN ST", "X-OCN LT",
    "ProRes RAW", "Canon RAW", "Canon Cinema RAW Light", "Z CAM ZRAW"
]


PRIMARY_COLOR = "#c0c0c0"
HOVER_COLOR = "#f26419"
BORDER_COLOR = "#3a6ea5"
TEXT_COLOR = "#ebebeb"

START_LOGO_CSS = """
    QLabel {
        color: #62b6cb;
        font-size: 22px;
        font-weight: bold;
        letter-spacing: 1px;
        font-family: 'Futura';
    }
"""

END_LOGO_CSS = """
    QLabel {
        color: rgb(255, 255, 255);
        font-size: 22px;
        font-weight: bold;
        letter-spacing: 1px;
        font-family: 'Futura';
    }
"""

CHECKBOX_STYLE = """
    QCheckBox { spacing: 12px; color: #ebebeb; font-size: 12px; }
    QCheckBox::indicator { width: 20px; height: 20px; border: 2px solid #3a6ea5; }
    QCheckBox::indicator:checked { background-color: #c0c0c0; }
    QCheckBox:disabled { color: #808080; }
    QCheckBox::indicator:disabled { border: 2px solid #5a5a5a; background-color: #2a2a2a; }
"""

BUTTON_STYLE = """
    QPushButton { background-color: #4C956C; color: #FFFFFF; font-size: 16px; border-radius: 14px; min-height: 30px; }
    QPushButton:hover { background-color: #61B15A; }
    QPushButton:disabled { background-color: #3a6ea5; color: #808080; }
"""
PRIMARY_ACTION_BUTTON_STYLE = f"""
    QPushButton {{
        border: 1px solid #2C6E49;
        max-height: 40px;
        border-radius: 14px;
        background-color: #4C956C;
        color: #FFFFFF;
        min-height: 30px;
        font-size: 16px;
        font-weight: bold;
    }}
    QPushButton:hover {{
        border: 1px solid {PRIMARY_COLOR};
        background-color: #61B15A;
    }}
    QPushButton:pressed {{
        border: 2px solid {PRIMARY_COLOR};
        background-color: #76C893;
    }}
"""
SECONDARY_ACTION_BUTTON_STYLE = f"""
    QPushButton {{
        border: 1px solid #bc4749;
        max-height: 28px;
        border-radius: 14px;
        background-color: #bc4749;
        color: #FFFFFF;
        min-height: 28px;
        font-size: 13px;
        font-weight: bold;
    }}
    QPushButton:hover {{
        border: 1px solid {PRIMARY_COLOR};
        background-color: #f07167;
    }}
    QPushButton:pressed {{
        border: 2px solid {PRIMARY_COLOR};
        background-color: #D00000;
    }}
"""
THIRD_ACTION_BUTTON_STYLE = """
     QPushButton {
        border: 1px solid rgb(71,91,98);
        max-height: 28px;
        border-radius: 14px;
        background-color: rgb(71,91,98);
        color: rgb(255, 255, 255);
        min-height: 28px;
        font-size: 13px;
    }
    QPushButton:hover {
        border: 1px solid rgb(176,176,176);
        background-color: rgb(89,90,183);
    }
    QPushButton:pressed {
        border: 2px solid rgb(119,121,252);
        background-color: rgb(119,121,252);
    }
    QPushButton:disabled {
        border: 2px solid #bc4749;
        background-color: #bc4749;
        color: rgb(150, 150, 150);
    }
"""

LABEL_STYLE = """
    QLabel { color: #ebebeb; font-size: 13px; font-weight: bold; padding: 5px 0; }
    QLabel:disabled { color: #808080; }
"""

STATUS_S_LABEL_STYLE = """
    QLabel {
        color: #c0c0c0;
        font-size: 10px;
        font-weight: bold;
        padding: 5px 0;
    }
"""

MEDIA_TYPE_MAPPING = {
    "Video": lambda clip, fp: (clip.GetClipProperty("Type") in ["Video + Audio", "Video"] and 
                               not is_raw_codec(clip) and not fp.lower().endswith('.exr')),
    "Audio": lambda clip, fp: clip.GetClipProperty("Type") == "Audio",
    "Timeline": lambda clip, fp: clip.GetClipProperty("Type") == "Timeline",
    "Compound": lambda clip, fp: clip.GetClipProperty("Type") == "Compound",
    "Fusion": lambda clip, fp: clip.GetClipProperty("Type") == "Fusion",
    "Fusion Titles": lambda clip, fp: clip.GetClipProperty("Type") == "Fusion Title",
    "Fusion Generators": lambda clip, fp: clip.GetClipProperty("Type") == "Generator",
    "Subtitle": lambda clip, fp: clip.GetClipProperty("Type") == "Subtitle",
    "Still": lambda clip, fp: (clip.GetClipProperty("Type") == "Still" and 
                               not fp.lower().endswith('.exr')),
    "Multicam": lambda clip, fp: clip.GetClipProperty("Type") == "Multicam",
}

# Main window
win = ui.FindWindow(winID)
if win:
    win.Show()
    win.Raise()
    exit()

layout = ui.VGroup(
    {'ID': 'root'},
    [
        ui.HGroup([
            ui.Label({"Weight": 0, "Text": "Media", "StyleSheet": START_LOGO_CSS}),
            ui.Label({"Weight": 0, "Text": "Organizer", "StyleSheet": END_LOGO_CSS, "Margin": -1.75}),
        ]),
        ui.VGap(10),
        ui.HGroup({'Weight': 0, 'Spacing': 10},
                 [
                     ui.VGroup({'Weight': 0},
                              [
                                  ui.CheckBox({'ID': 'videoCheckbox', 'Text': 'Video', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE}),
                                  ui.CheckBox({'ID': 'audioCheckbox', 'Text': 'Audio', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE}),
                                  ui.CheckBox({'ID': 'timelineCheckbox', 'Text': 'Timelines', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE}),
                                  ui.CheckBox({'ID': 'compoundCheckbox', 'Text': 'Compound Clips', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE})
                              ]),
                     ui.VGroup({'Weight': 0},
                              [
                                  ui.CheckBox({'ID': 'fusionCheckbox', 'Text': 'Fusion', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE}),
                                  ui.CheckBox({'ID': 'subtitleCheckbox', 'Text': 'Subtitles', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE}),
                                  ui.CheckBox({'ID': 'stillCheckbox', 'Text': 'Stills', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE}),
                                  ui.CheckBox({'ID': 'multicamCheckbox', 'Text': 'Multicam', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE})
                              ])
                 ]),
        ui.VGap(5),
        ui.Label({"Text": "Folders to Process", "Weight": 0, "StyleSheet": LABEL_STYLE}),
        ui.HGroup({'Weight': 0, 'Spacing': 5},
            [ui.Button({'ID': 'selectFoldersButton', 'Text': 'Select Folders', 'ToolTip': 'Select folders to process', 
                        'MinimumSize': (100, 20), 'StyleSheet': THIRD_ACTION_BUTTON_STYLE})]),
        ui.Label({'ID': 'selectedFoldersLabel', 'Text': 'No folders selected', 'Weight': 0, 'StyleSheet': STATUS_S_LABEL_STYLE}),
        ui.VGap(5),
        ui.Label({"Text": "Organize Options", "Weight": 0, "StyleSheet": LABEL_STYLE}),
        ui.VGroup({'Weight': 0, 'Spacing': 10},
        [
            ui.CheckBox({'ID': 'rootOnlyCheckbox', 'Text': 'Check root folder only', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE}),
            ui.CheckBox({'ID': 'selectedFolderCheckbox', 'Text': 'Use selected Mediapool folder only', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE}),
            ui.CheckBox({'ID': 'keywordsCheckbox', 'Text': 'Create subfolders by keywords', 'Checked': True, 'StyleSheet': CHECKBOX_STYLE}),
            ui.CheckBox({'ID': 'deleteEmptyCheckbox', 'Text': 'Delete empty bins', 'Checked': False, 'StyleSheet': CHECKBOX_STYLE})
        ]),
        ui.VGap(5),
        ui.HGroup({'Weight': 0, 'Spacing': 10},
            [ui.Button({'ID': organizeID, 'Text': 'Organize Media', 'ToolTip': 'Organize media by type', 
                        'MinimumSize': (150, 30), 'StyleSheet': BUTTON_STYLE})]),
        ui.VGap(5),
        ui.HGroup({'Weight': 0},
                 [ui.Label({'ID': statusID, 'Text': 'Ready', 'Weight': 1, 'StyleSheet': STATUS_S_LABEL_STYLE})])
    ]
)

win = dispatcher.AddWindow({
    'ID': winID,
    'WindowTitle': script['name'],
    'Events': {'Close': True},
    # 'Geometry': [100, 100, 270, 550],
    'FixedSize': (270, 550),
    'MinimumSize': [270, 300],
    'MaximumSize': [270, 600],
}, layout)

def get_clip_keywords(clip):
    """Return list of clip keywords from metadata."""
    keywords = clip.GetMetadata('Keywords')
    if keywords:
        return [kw.strip() for kw in keywords.split(',')]
    return []

def is_raw_codec(clip):
    """Check if clip codec is a RAW format."""
    codec = clip.GetClipProperty("Video Codec")
    return codec and any(raw_codec.upper() in codec.upper() for raw_codec in RAW_CODECS)

def get_all_clips_iterative(folders, root_only=True, include_video=False, include_audio=False, 
                            include_timeline=False, include_compound=False, include_fusion=False, 
                            include_subtitle=False, include_multicam=False):
    """Iteratively collect clips from folder list with filters."""
    clips = []
    stack = list(folders) if isinstance(folders, (list, tuple)) else [folders]
    while stack:
        current_folder = stack.pop()
        clips.extend(current_folder.GetClipList())
        if not root_only:
            stack.extend(current_folder.GetSubFolderList())

    filtered_clips = []
    for clip in clips:
        clip_type = clip.GetClipProperty("Type")
        if include_fusion and clip_type in ["Fusion", "Fusion Title", "Generator"]:
            filtered_clips.append(clip)
        elif include_audio and clip_type == "Audio":
            filtered_clips.append(clip)
        elif include_timeline and clip_type == "Timeline":
            filtered_clips.append(clip)
        elif include_compound and clip_type == "Compound":
            filtered_clips.append(clip)
        elif include_subtitle and clip_type == "Subtitle":
            filtered_clips.append(clip)
        elif include_multicam and clip_type == "Multicam":
            filtered_clips.append(clip)
        elif include_video and clip_type in ["Video + Audio", "Video", "Still"]:
            filtered_clips.append(clip)
    return filtered_clips

def get_all_folders_recursive(folder, parent_path=""):
    """Recursively collect all folders with their full paths."""
    folders = {}
    folder_name = folder.GetName()
    current_path = f"{parent_path}/{folder_name}" if parent_path else folder_name
    folders[current_path] = folder
    for subfolder in folder.GetSubFolderList():
        subfolders = get_all_folders_recursive(subfolder, current_path)
        folders.update(subfolders)
    return folders

def get_selected_folders_from_dialog(tree):
    """Collect selected folders and subfolders from FolderTree in dialog."""
    selected_folders = []
    all_folders = get_all_folders_recursive(mediapool.GetRootFolder())
    all_folders['Root'] = mediapool.GetRootFolder()

    print(f"Available folders in all_folders: {list(all_folders.keys())}")

    selected_items = list(tree.SelectedItems().values())
    print(f"Selected items in dialog: {[item.Text[0] for item in selected_items]}")

    for item in selected_items:
        folder_path = f"{root_folder_name}/{item.Text[0]}" if item.Text[0] != 'Root' else 'Root'
        print(f"Selected folder path: {folder_path}")
        if folder_path in all_folders:
            selected_folders.append(all_folders[folder_path])
            selected_folders.extend(all_folders[folder_path].GetSubFolderList(True))
        else:
            print(f"Folder path {folder_path} not found in all_folders")

    if not selected_items:
        print("No items selected in FolderTree dialog")
        return []

    return selected_folders

def organize_media(ev):
    try:
        win_items = win.GetItems()
        status_label = win_items[statusID]
        root_only = win_items['rootOnlyCheckbox'].Checked
        use_selected = win_items['selectedFolderCheckbox'].Checked
        use_keywords = win_items['keywordsCheckbox'].Checked
        delete_empty = win_items['deleteEmptyCheckbox'].Checked

        root_folder = mediapool.GetRootFolder()
        if use_selected:
            folders = [mediapool.GetCurrentFolder()]
        elif selected_folders:
            folders = selected_folders
        else:
            folders = [root_folder]

        checkbox_mapping = {
            "Video": "videoCheckbox",
            "Audio": "audioCheckbox",
            "Timeline": "timelineCheckbox",
            "Compound": "compoundCheckbox",
            "Fusion": "fusionCheckbox",
            "Subtitle": "subtitleCheckbox",
            "Still": "stillCheckbox",
            "Multicam": "multicamCheckbox"
        }
        media_types = {}
        for media_type, checkbox_id in checkbox_mapping.items():
            if win_items[checkbox_id].Checked:
                media_types[media_type] = []
                if media_type == "Fusion":
                    media_types["Fusion Titles"] = []
                    media_types["Fusion Generators"] = []
        if win_items['videoCheckbox'].Checked:
            media_types["RAW"] = []
            media_types["Sequences"] = []

        status_label.Text = "Analyzing files..."

        clips = get_all_clips_iterative(folders, root_only,
                                        win_items['videoCheckbox'].Checked or win_items['stillCheckbox'].Checked,
                                        win_items['audioCheckbox'].Checked,
                                        win_items['timelineCheckbox'].Checked,
                                        win_items['compoundCheckbox'].Checked,
                                        win_items['fusionCheckbox'].Checked,
                                        win_items['subtitleCheckbox'].Checked,
                                        win_items['multicamCheckbox'].Checked)

        status_label.Text = "Moving files..."
        moved_count = 0
        error_count = 0
        existing_folders = {folder.GetName(): folder for folder in root_folder.GetSubFolderList()}

        for clip in clips:
            file_path = clip.GetClipProperty("File Path")
            if "RAW" in media_types and clip.GetClipProperty("Type") in ["Video + Audio", "Video"] and is_raw_codec(clip):
                media_types["RAW"].append(clip)
            elif "Sequences" in media_types and clip.GetClipProperty("Type") in ["Video + Audio", "Video", "Still"] and file_path.lower().endswith('.exr'):
                media_types["Sequences"].append(clip)
            else:
                for media_type, condition in MEDIA_TYPE_MAPPING.items():
                    if media_type in media_types and condition(clip, file_path):
                        media_types[media_type].append(clip)
                        break

        for folder_name, clips_list in media_types.items():
            if clips_list:
                target_folder = existing_folders.get(folder_name) or mediapool.AddSubFolder(root_folder, folder_name)
                existing_folders[folder_name] = target_folder
                print(f"Created or using folder: {folder_name}")

                keyword_folders = {folder.GetName(): folder for folder in target_folder.GetSubFolderList()}
                keyword_groups = {}

                for clip in clips_list:
                    if use_keywords:
                        keywords = get_clip_keywords(clip)
                        if keywords:
                            keyword = keywords[0]
                            keyword_groups.setdefault(keyword, []).append(clip)
                        else:
                            if mediapool.MoveClips([clip], target_folder):
                                moved_count += 1
                            else:
                                error_count += 1
                    else:
                        if mediapool.MoveClips([clip], target_folder):
                            moved_count += 1
                        else:
                            error_count += 1

                if use_keywords:
                    for keyword, keyword_clips in keyword_groups.items():
                        keyword_folder = keyword_folders.get(keyword) or mediapool.AddSubFolder(target_folder, keyword)
                        keyword_folders[keyword] = keyword_folder
                        print(f"Created or using keyword subfolder: {keyword}")
                        for clip in keyword_clips:
                            if mediapool.MoveClips([clip], keyword_folder):
                                moved_count += 1
                            else:
                                error_count += 1

        if delete_empty:
            status_label.Text = "Removing empty folders..."
            print(f"Deleting empty folders in: {[folder.GetName() for folder in folders]}")
            delete_empty_folders(folders)

        status_label.Text = f"Complete! Moved {moved_count} files, {error_count} errors."
        print(f"\nComplete! Moved {moved_count} files, {error_count} errors.")

    except Exception as e:
        error_message = f"Error: {str(e)}"
        status_label.Text = error_message
        print(f"\n{error_message}")

def delete_empty_folders(folders):
    """Recursively delete empty folders within specified folders and subfolders."""
    if not isinstance(folders, (list, tuple)):
        folders = [folders]

    root_folder = mediapool.GetRootFolder()
    # Get all folders in media pool for checking
    all_folders = get_all_folders_recursive(root_folder)
    all_folders['Root'] = root_folder

    for folder in folders:
        # Check current folder and its subfolders
        subfolders = folder.GetSubFolderList()
        for subfolder in subfolders:
            delete_empty_folders([subfolder])
            if not subfolder.GetClipList() and not subfolder.GetSubFolderList():
                folder_name = subfolder.GetName()
                if mediapool.DeleteFolders([subfolder]):
                    print(f"Deleted empty folder: {folder_name}")
                else:
                    print(f"Failed to delete folder: {folder_name}")

def populate_folders(tree):
    global root_folder_name
    tree.Clear()
    tree.SetSelectionMode('ExtendedSelection')
    tree.SetHeaderHidden(True)

    root_folder = mediapool.GetRootFolder()
    root_folder_name = root_folder.GetName()
    print(f"Root folder: {root_folder_name}")
    subfolders = root_folder.GetSubFolderList()
    print(f"Subfolders: {[f.GetName() for f in subfolders]}")

    root_item = tree.NewItem()
    root_item.Text[0] = 'Root'
    tree.AddTopLevelItem(root_item)

    add_folders_to_tree(root_folder, root_item, "Root")

def add_folders_to_tree(folder, parent_item, current_path):
    tree = parent_item.TreeWidget()
    for subfolder in sorted(folder.GetSubFolderList(), key=lambda f: f.GetName()):
        row = tree.NewItem()
        subfolder_path = f"{current_path}/{subfolder.GetName()}" if current_path != "Root" else subfolder.GetName()
        row.Text[0] = subfolder_path
        parent_item.AddChild(row)
        add_folders_to_tree(subfolder, row, subfolder_path)
    parent_item.SetExpanded(True)

def on_root_only_clicked(ev):
    win_items = win.GetItems()
    if win_items['rootOnlyCheckbox'].Checked:
        win_items['selectedFolderCheckbox'].Checked = False
        win_items['selectFoldersButton'].Enabled = False
        print("Enabled Select Folders button from rootOnlyCheckbox")
    else:
        win_items['selectFoldersButton'].Enabled = True
        print("Enabled Select Folders button from selectedFolderCheckbox")

def on_selected_folder_clicked(ev):
    win_items = win.GetItems()
    if win_items['selectedFolderCheckbox'].Checked:
        win_items['rootOnlyCheckbox'].Checked = False
        win_items['selectFoldersButton'].Enabled = False
        print("Disabled Select Folders button from selectedFolderCheckbox")
    else:
        win_items['selectFoldersButton'].Enabled = True
        print("Enabled Select Folders button from selectedFolderCheckbox")

def on_select_folders_clicked(ev):
    # Create dialog window dynamically
    folder_dialog = dispatcher.AddWindow({
        'ID': folderDialogID,
        'WindowTitle': 'Select Folders',
        'WindowFlags': {'Window': True, 'WindowStaysOnTopHint': True},
        'Geometry': [150, 150, 300, 400],
        'MinimumSize': [300, 300],
    }, ui.VGroup(
        {'ID': 'folderDialogRoot'},
        [
            ui.Label({"Text": "Select Folders", "Weight": 0, "StyleSheet": LABEL_STYLE}),
            ui.Tree({'ID': 'FolderTree', 'Weight': 3, 'MinimumSize': (0, 300)}),
            ui.VGap(10),
            ui.HGroup({'Weight': 0, 'Spacing': 10},
                [
                    ui.Button({'ID': 'okButton', 'Text': 'OK', 'MinimumSize': (80, 30), 'StyleSheet': BUTTON_STYLE}),
                    ui.Button({'ID': 'cancelButton', 'Text': 'Cancel', 'MinimumSize': (80, 30), 'StyleSheet': SECONDARY_ACTION_BUTTON_STYLE})
                ])
        ]
    ))

    # Populate folder tree
    tree = folder_dialog.Find('FolderTree')
    populate_folders(tree)

    # Dialog event handlers
    def on_folder_dialog_ok_clicked(ev):
        global selected_folders
        selected_folders = get_selected_folders_from_dialog(tree)
        win_items = win.GetItems()
        if selected_folders:
            win_items['selectedFoldersLabel'].Text = f"Selected: {[folder.GetName() for folder in selected_folders]}"
        else:
            win_items['selectedFoldersLabel'].Text = "No folders selected"
        print(f"Selected folders updated: {[folder.GetName() for folder in selected_folders]}")
        dispatcher.ExitLoop()

    def on_folder_dialog_cancel_clicked(ev):
        dispatcher.ExitLoop()

    folder_dialog.On['okButton'].Clicked = on_folder_dialog_ok_clicked
    folder_dialog.On['cancelButton'].Clicked = on_folder_dialog_cancel_clicked
    folder_dialog.On[folderDialogID].Close = on_folder_dialog_cancel_clicked

    # Show dialog and run its event loop
    folder_dialog.Show()
    dispatcher.RunLoop()
    folder_dialog.Hide()

win.On['selectFoldersButton'].Clicked = on_select_folders_clicked
win.On['rootOnlyCheckbox'].Clicked = on_root_only_clicked
win.On['selectedFolderCheckbox'].Clicked = on_selected_folder_clicked
win.On[organizeID].Clicked = organize_media
win.On[winID].Close = dispatcher.ExitLoop

win.Show()
dispatcher.RunLoop()