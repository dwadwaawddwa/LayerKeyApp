#Requires AutoHotkey v2.0
; ============================================================
;  JSON minimal (serialisation + parsing) pour AHK v2
;  - Json_Dump(valeur, indent) -> texte JSON
;  - Json_Parse(texte)         -> Map / Array / valeurs
;  Types supportes : Map (objet), Array (tableau), string,
;  Integer, Float, true, false, null (=> "").
; ============================================================

Json_Dump(val, indent := 0) {
    pad  := StrRepeat("  ", indent)
    pad2 := StrRepeat("  ", indent + 1)
    if (val is Map) {
        if (val.Count = 0)
            return "{}"
        s := "{`n"
        first := true
        for k, v in val {
            if (!first)
                s .= ",`n"
            first := false
            s .= pad2 Json_Str(k) ": " Json_Dump(v, indent + 1)
        }
        return s "`n" pad "}"
    } else if (val is Array) {
        if (val.Length = 0)
            return "[]"
        s := "[`n"
        first := true
        for v in val {
            if (!first)
                s .= ",`n"
            first := false
            s .= pad2 Json_Dump(v, indent + 1)
        }
        return s "`n" pad "]"
    } else if (val is Integer || val is Float) {
        return String(val)
    } else {
        return Json_Str(val)
    }
}

Json_Str(s) {
    s := String(s)
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return '"' s '"'
}

StrRepeat(str, n) {
    out := ""
    Loop n
        out .= str
    return out
}

; --- Parser ---
Json_Parse(text) {
    pos := 1
    val := _JsonVal(&text, &pos)
    return val
}

_JsonSkipWs(&text, &pos) {
    while (pos <= StrLen(text)) {
        c := SubStr(text, pos, 1)
        if (c = " " || c = "`t" || c = "`n" || c = "`r")
            pos++
        else
            break
    }
}

_JsonVal(&text, &pos) {
    _JsonSkipWs(&text, &pos)
    c := SubStr(text, pos, 1)
    if (c = "{")
        return _JsonObj(&text, &pos)
    if (c = "[")
        return _JsonArr(&text, &pos)
    if (c = '"')
        return _JsonStr(&text, &pos)
    if (c = "t") {
        pos += 4
        return true
    }
    if (c = "f") {
        pos += 5
        return false
    }
    if (c = "n") {
        pos += 4
        return ""
    }
    return _JsonNum(&text, &pos)
}

_JsonObj(&text, &pos) {
    obj := Map()
    pos++  ; passe {
    _JsonSkipWs(&text, &pos)
    if (SubStr(text, pos, 1) = "}") {
        pos++
        return obj
    }
    loop {
        _JsonSkipWs(&text, &pos)
        key := _JsonStr(&text, &pos)
        _JsonSkipWs(&text, &pos)
        pos++  ; passe :
        val := _JsonVal(&text, &pos)
        obj[key] := val
        _JsonSkipWs(&text, &pos)
        c := SubStr(text, pos, 1)
        pos++
        if (c = "}")
            break
        ; sinon c = "," -> continue
    }
    return obj
}

_JsonArr(&text, &pos) {
    arr := []
    pos++  ; passe [
    _JsonSkipWs(&text, &pos)
    if (SubStr(text, pos, 1) = "]") {
        pos++
        return arr
    }
    loop {
        val := _JsonVal(&text, &pos)
        arr.Push(val)
        _JsonSkipWs(&text, &pos)
        c := SubStr(text, pos, 1)
        pos++
        if (c = "]")
            break
    }
    return arr
}

_JsonStr(&text, &pos) {
    pos++  ; passe le guillemet ouvrant
    out := ""
    while (pos <= StrLen(text)) {
        c := SubStr(text, pos, 1)
        pos++
        if (c = '"')
            break
        if (c = "\") {
            e := SubStr(text, pos, 1)
            pos++
            switch e {
                case '"': out .= '"'
                case "\": out .= "\"
                case "/": out .= "/"
                case "n": out .= "`n"
                case "r": out .= "`r"
                case "t": out .= "`t"
                case "b": out .= "`b"
                case "f": out .= "`f"
                case "u":
                    hex := SubStr(text, pos, 4)
                    pos += 4
                    out .= Chr(Integer("0x" hex))
                default: out .= e
            }
        } else {
            out .= c
        }
    }
    return out
}

_JsonNum(&text, &pos) {
    numStr := ""
    while (pos <= StrLen(text)) {
        c := SubStr(text, pos, 1)
        if (InStr("0123456789+-.eE", c)) {
            numStr .= c
            pos++
        } else {
            break
        }
    }
    if (InStr(numStr, ".") || InStr(numStr, "e") || InStr(numStr, "E"))
        return Float(numStr)
    return Integer(numStr)
}
