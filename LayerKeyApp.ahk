#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

#Include %A_ScriptDir%\json.ahk

; ============================================================
;  LayerKeyApp
;  Transforme la touche Menu (AppsKey / VK_APPS) en "touche de
;  calque" maintenue : tant qu'elle est appuyee, chaque touche
;  declenche une action personnalisee (appli, URL, son, commande).
;  Interface graphique de configuration + icone barre des taches.
; ============================================================

; ---------- Chemins ----------
global AppName      := "LayerKeyApp"
global ConfigDir    := A_AppData "\LayerKey"
global ConfigPath   := ConfigDir "\config.json"
global StartupLink  := A_Startup "\LayerKeyApp.lnk"

; ---------- Etat runtime ----------
global Mappings        := []       ; tableau de Map("key","type","target")
global StartWithWin    := false
global EngineEnabled   := true
global LayerActive     := false
global RegisteredKeys  := []       ; touches actuellement enregistrees
global ConfigGui       := ""       ; fenetre de config (creee a la demande)
global MainLV          := ""       ; ListView de la fenetre de config
global OverlayGui      := ""
global TypeLabels      := Map("app","Application (.exe)", "url","Lien / URL", "sound","Son (.wav/.mp3)", "cmd","Commande")

; ---------- Demarrage ----------
LoadConfig()
BuildTray()
BuildOverlay()
RegisterHotkeys()
UpdateTrayState()

; La touche Menu seule ne doit plus rien faire (pas de menu contextuel).
; Ces hotkeys globaux pilotent l'activation du calque.
*AppsKey:: {
    global EngineEnabled, LayerActive
    if (!EngineEnabled)
        return
    LayerActive := true
    ShowOverlay()
}
*AppsKey up:: {
    global LayerActive
    LayerActive := false
    HideOverlay()
}

return  ; fin de la section auto-execute

; ============================================================
;  MOTEUR : contexte du calque + enregistrement dynamique
; ============================================================

; Contexte reutilise (meme objet fonction) pour HotIf.
LayerCtx(*) => LayerActive

; Enregistre les hotkeys a partir de Mappings.
RegisterHotkeys() {
    global Mappings, RegisteredKeys
    errs := ""
    HotIf(LayerCtx)
    ; Desactive les anciennes touches
    for key in RegisteredKeys {
        try Hotkey(key, "Off")
    }
    RegisteredKeys := []
    ; Enregistre les nouvelles
    for m in Mappings {
        key := m["key"]
        if (key = "")
            continue
        try {
            Hotkey(key, DoAction.Bind(m), "On")
            RegisteredKeys.Push(key)
        } catch as e {
            errs .= "  - touche `"" key "`" : " e.Message "`n"
        }
    }
    HotIf()  ; reinitialise le contexte
    if (errs != "")
        MsgBox("Certaines touches n'ont pas pu etre enregistrees :`n" errs, AppName, "Icon!")
    UpdateOverlayText()
}

; Execute l'action d'un mapping. (*) absorbe le nom du hotkey.
DoAction(m, *) {
    type   := m["type"]
    target := m["target"]
    try {
        switch type {
            case "app":   Run(target)
            case "url":   Run(target)
            case "sound": SoundPlay(target)
            case "cmd":   Run(A_ComSpec ' /c ' target, , "Hide")
            default:      Run(target)
        }
    } catch as e {
        ToolTip("Erreur : " e.Message)
        SetTimer(() => ToolTip(), -2000)
    }
}

; ============================================================
;  OVERLAY : petit rappel visuel pendant que le calque est actif
; ============================================================

BuildOverlay() {
    global OverlayGui
    OverlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20", AppName " overlay")
    OverlayGui.BackColor := "1E1E1E"
    OverlayGui.MarginX := 14
    OverlayGui.MarginY := 12
    OverlayGui.SetFont("s10 cCCCCCC", "Segoe UI")
    OverlayGui.Add("Text", "cFFFFFF", "Calque actif")
    OverlayGui.SetFont("s9 cCCCCCC", "Segoe UI")
    OverlayGui.Add("Text", "vOvlBody w280", "")
    UpdateOverlayText()
}

UpdateOverlayText() {
    global OverlayGui, Mappings
    if (OverlayGui = "")
        return
    body := ""
    for m in Mappings {
        label := m["target"]
        if (StrLen(label) > 40)
            label := SubStr(label, 1, 37) "..."
        body .= Format("[{1}]  {2}`n", StrUpper(m["key"]), label)
    }
    if (body = "")
        body := "(aucun raccourci configure)"
    OverlayGui["OvlBody"].Value := RTrim(body, "`n")
}

ShowOverlay() {
    global OverlayGui
    if (OverlayGui = "")
        return
    UpdateOverlayText()
    OverlayGui.Show("AutoSize NoActivate x-9999 y-9999")
    OverlayGui.GetPos(, , &w, &h)
    x := A_ScreenWidth  - w - 24
    y := A_ScreenHeight - h - 60
    OverlayGui.Show("NoActivate x" x " y" y)
}

HideOverlay() {
    global OverlayGui
    if (OverlayGui != "")
        OverlayGui.Hide()
}

; ============================================================
;  BARRE DES TACHES (system tray)
; ============================================================

BuildTray() {
    tray := A_TrayMenu
    tray.Delete()
    tray.Add(AppName, (*) => "")
    tray.Disable(AppName)
    tray.Add()
    tray.Add("Calque active", (*) => ToggleEngine())
    tray.Add("Ouvrir la configuration", (*) => ShowConfig())
    tray.Add("Demarrer avec Windows", (*) => ToggleStartupFromTray())
    tray.Add()
    tray.Add("Quitter", (*) => ExitApp())
    tray.Default := "Ouvrir la configuration"
    A_IconTip := AppName
}

UpdateTrayState() {
    global EngineEnabled, StartWithWin
    tray := A_TrayMenu
    (EngineEnabled ? tray.Check("Calque active") : tray.Uncheck("Calque active"))
    (StartWithWin  ? tray.Check("Demarrer avec Windows") : tray.Uncheck("Demarrer avec Windows"))
    A_IconTip := AppName (EngineEnabled ? "" : " (desactive)")
}

ToggleEngine() {
    global EngineEnabled, LayerActive
    EngineEnabled := !EngineEnabled
    if (!EngineEnabled) {
        LayerActive := false
        HideOverlay()
    }
    ; Restaure la touche Menu native quand desactive
    try Hotkey("*AppsKey",    EngineEnabled ? "On" : "Off")
    try Hotkey("*AppsKey up", EngineEnabled ? "On" : "Off")
    UpdateTrayState()
}

ToggleStartupFromTray() {
    global StartWithWin
    SetStartup(!StartWithWin)
    UpdateTrayState()
    SaveConfig()
}

; ============================================================
;  DEMARRAGE AVEC WINDOWS (raccourci dans le dossier Demarrage)
; ============================================================

SetStartup(enable) {
    global StartWithWin, StartupLink
    if (enable) {
        if (A_IsCompiled)
            FileCreateShortcut(A_ScriptFullPath, StartupLink, A_ScriptDir)
        else
            FileCreateShortcut(A_AhkPath, StartupLink, A_ScriptDir, '"' A_ScriptFullPath '"')
        StartWithWin := true
    } else {
        if FileExist(StartupLink)
            FileDelete(StartupLink)
        StartWithWin := false
    }
}

; ============================================================
;  CONFIG : lecture / ecriture JSON
; ============================================================

LoadConfig() {
    global Mappings, StartWithWin, ConfigPath, StartupLink
    Mappings := []
    if !FileExist(ConfigPath) {
        SeedDefaultConfig()
        SaveConfig()
    } else {
        try {
            data := Json_Parse(FileRead(ConfigPath, "UTF-8"))
            if (data.Has("mappings")) {
                for item in data["mappings"] {
                    Mappings.Push(Map(
                        "key",    item.Has("key")    ? item["key"]    : "",
                        "type",   item.Has("type")   ? item["type"]   : "app",
                        "target", item.Has("target") ? item["target"] : ""))
                }
            }
        } catch as e {
            MsgBox("Config illisible, valeurs par defaut chargees.`n" e.Message, AppName, "Icon!")
            SeedDefaultConfig()
        }
    }
    ; L'etat "demarrer avec Windows" suit la presence reelle du raccourci
    StartWithWin := FileExist(StartupLink) ? true : false
}

SeedDefaultConfig() {
    global Mappings
    Mappings := [
        Map("key","y","type","url","target","https://www.youtube.com/feed/subscriptions"),
        Map("key","g","type","url","target","https://www.google.com"),
        Map("key","n","type","app","target","notepad.exe") ]
}

SaveConfig() {
    global Mappings, ConfigDir, ConfigPath
    if !DirExist(ConfigDir)
        DirCreate(ConfigDir)
    arr := []
    for m in Mappings
        arr.Push(Map("key", m["key"], "type", m["type"], "target", m["target"]))
    root := Map("trigger_key", "AppsKey", "mappings", arr)
    json := Json_Dump(root, 0)
    if FileExist(ConfigPath)
        FileDelete(ConfigPath)
    f := FileOpen(ConfigPath, "w", "UTF-8")
    f.Write(json)
    f.Close()
}

; ============================================================
;  FENETRE DE CONFIGURATION
; ============================================================

ShowConfig() {
    global ConfigGui, MainLV, Mappings
    if (ConfigGui != "") {
        ConfigGui.Show()
        RefreshList()
        return
    }
    g := Gui("+Resize +MinSize560x360", AppName " - Configuration")
    g.SetFont("s9", "Segoe UI")
    g.MarginX := 14, g.MarginY := 14

    g.Add("Text", , "Maintiens la touche Menu, puis appuie sur la touche indiquee pour lancer l'action.")

    MainLV := g.Add("ListView", "w560 h240 Grid", ["Touche", "Type", "Cible"])
    MainLV.ModifyCol(1, 90)
    MainLV.ModifyCol(2, 130)
    MainLV.ModifyCol(3, 330)
    MainLV.OnEvent("DoubleClick", (lv, row) => (row ? OpenEditor(row) : ""))

    g.Add("Button", "xm w110", "Ajouter").OnEvent("Click", (*) => OpenEditor(0))
    g.Add("Button", "x+8 w110 yp", "Modifier").OnEvent("Click", (*) => EditSelected())
    g.Add("Button", "x+8 w110 yp", "Supprimer").OnEvent("Click", (*) => DeleteSelected())
    g.Add("Button", "x+8 w110 yp", "Tester").OnEvent("Click", (*) => TestSelected())

    cb := g.Add("CheckBox", "xm y+16 vCbStartup", "Demarrer avec Windows")
    cb.Value := StartWithWin ? 1 : 0
    cb.OnEvent("Click", (ctrl, *) => (SetStartup(ctrl.Value ? true : false), SaveConfig(), UpdateTrayState()))

    g.Add("Button", "x+120 w130 yp-4 Default", "Enregistrer").OnEvent("Click", (*) => SaveAndReload())
    g.Add("Button", "x+8 w110 yp", "Fermer").OnEvent("Click", (*) => ConfigGui.Hide())

    g.OnEvent("Close", (*) => g.Hide())
    g.OnEvent("Escape", (*) => g.Hide())
    ConfigGui := g
    RefreshList()
    g.Show()
}

RefreshList() {
    global MainLV, Mappings, TypeLabels
    if (MainLV = "")
        return
    MainLV.Delete()
    for m in Mappings {
        tlabel := TypeLabels.Has(m["type"]) ? TypeLabels[m["type"]] : m["type"]
        MainLV.Add(, StrUpper(m["key"]), tlabel, m["target"])
    }
}

EditSelected() {
    global MainLV
    row := MainLV.GetNext()
    if (row)
        OpenEditor(row)
    else
        MsgBox("Selectionne d'abord un raccourci.", AppName)
}

DeleteSelected() {
    global MainLV, Mappings
    row := MainLV.GetNext()
    if (!row) {
        MsgBox("Selectionne d'abord un raccourci.", AppName)
        return
    }
    Mappings.RemoveAt(row)
    RefreshList()
}

TestSelected() {
    global MainLV, Mappings
    row := MainLV.GetNext()
    if (!row) {
        MsgBox("Selectionne d'abord un raccourci.", AppName)
        return
    }
    DoAction(Mappings[row])
}

SaveAndReload() {
    SaveConfig()
    RegisterHotkeys()
    ToolTip("Configuration enregistree")
    SetTimer(() => ToolTip(), -1200)
}

; ---------- Editeur d'un raccourci (ajout / modification) ----------
; index = 0 -> ajout ; sinon modification de Mappings[index]
OpenEditor(index) {
    global Mappings, TypeLabels
    isEdit := (index > 0)
    cur := isEdit ? Mappings[index] : Map("key","","type","app","target","")

    dlg := Gui("+Owner" (ConfigGui ? ConfigGui.Hwnd : "") " -MinimizeBox", isEdit ? "Modifier le raccourci" : "Ajouter un raccourci")
    dlg.SetFont("s9", "Segoe UI")
    dlg.MarginX := 14, dlg.MarginY := 14

    dlg.Add("Text", "w80", "Touche :")
    keyEdit := dlg.Add("Edit", "x+8 yp-3 w120 vKey", cur["key"])
    dlg.Add("Button", "x+8 yp w120", "Capturer une touche").OnEvent("Click", (*) => CaptureKey(keyEdit))

    dlg.Add("Text", "xm y+14 w80", "Action :")
    ; DropDownList des types
    labels := []
    typeKeys := ["app","url","sound","cmd"]
    for t in typeKeys
        labels.Push(TypeLabels[t])
    ddl := dlg.Add("DropDownList", "x+8 yp-3 w200 vType", labels)
    ; selection courante
    for i, t in typeKeys {
        if (t = cur["type"])
            ddl.Value := i
    }
    if (!ddl.Value)
        ddl.Value := 1

    dlg.Add("Text", "xm y+14 w80", "Cible :")
    tgtEdit := dlg.Add("Edit", "x+8 yp-3 w300 vTarget", cur["target"])
    dlg.Add("Button", "x+8 yp w90", "Parcourir...").OnEvent("Click", (*) => BrowseTarget(ddl, typeKeys, tgtEdit))

    dlg.Add("Text", "xm y+6 w400 cGray", "URL: https://...   |   Application: chemin .exe   |   Son: .wav/.mp3   |   Commande: ligne de commande")

    dlg.Add("Button", "xm y+16 w110", "Tester").OnEvent("Click", (*) => DoAction(Map("key", keyEdit.Value, "type", typeKeys[ddl.Value], "target", tgtEdit.Value)))
    dlg.Add("Button", "x+90 w110 Default", "OK").OnEvent("Click", (*) => EditorOK(dlg, index, keyEdit, ddl, typeKeys, tgtEdit))
    dlg.Add("Button", "x+8 w110", "Annuler").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    dlg.Show()
}

CaptureKey(keyEdit) {
    ToolTip("Appuie sur la touche a capturer...")
    ih := InputHook("L1")
    ih.KeyOpt("{All}", "E")   ; capture aussi les touches speciales
    ih.Start()
    ih.Wait()
    ToolTip()
    k := ih.Input
    if (k = "" && ih.EndKey != "")
        k := ih.EndKey
    if (k != "")
        keyEdit.Value := k
}

BrowseTarget(ddl, typeKeys, tgtEdit) {
    type := typeKeys[ddl.Value]
    if (type = "sound")
        sel := FileSelect(3, , "Choisir un son", "Sons (*.wav; *.mp3)")
    else if (type = "app")
        sel := FileSelect(3, , "Choisir une application", "Programmes (*.exe)")
    else
        sel := FileSelect(3, , "Choisir un fichier")
    if (sel != "")
        tgtEdit.Value := sel
}

EditorOK(dlg, index, keyEdit, ddl, typeKeys, tgtEdit) {
    global Mappings
    key    := Trim(keyEdit.Value)
    type   := typeKeys[ddl.Value]
    target := Trim(tgtEdit.Value)
    if (key = "") {
        MsgBox("Indique une touche.", AppName, "Icon!")
        return
    }
    if (target = "") {
        MsgBox("Indique une cible (URL, chemin, son ou commande).", AppName, "Icon!")
        return
    }
    m := Map("key", key, "type", type, "target", target)
    if (index > 0)
        Mappings[index] := m
    else
        Mappings.Push(m)
    dlg.Destroy()
    RefreshList()
}
