; Unreal World Character Reroller

; === CONFIGURATION ===
; Set your target values for each attribute
global CONFIG := {
    GameExecutable: "urw.exe",
    LogFile: A_ScriptDir "\reroller.log",
    RerollFrequency: 20, ; Milliseconds between rerolls (increase if CPU usage is high)
    ScanDelay: 10,      ; How long to wait after rerolling before reading stat values
    RerollKey: "n",     ; Key used to reroll character
    StopHotkey: "^2",   ; Ctrl+2 to stop rerolling
    StartHotkey: "^1",  ; Ctrl+1 to start rerolling
    Pattern: {
        Signature: "0F B6 C2 B9 01 00 00 00 0F 47 C1 B9 03 00 00 00 A2",
        Offset: 17      ; Bytes to skip to get the attribute array address
    },
    Attributes: Map(
        "Strength",     {offset: 0,    target: 13},
        "Agility",      {offset: 1,    target: 13},
        "Dexterity",    {offset: 4,    target: 13},
        "Speed",        {offset: 5,    target: 13},
        "Endurance",    {offset: 7,    target: 13},
        "SmellTaste",   {offset: 8,    target: 13},
        "Eyesight",     {offset: 11,   target: 13},
        "Touch",        {offset: 12,   target: 13},
        "Will",         {offset: 13,   target: 13},
        "Intelligence", {offset: 16,   target: 13},
        "Hearing",      {offset: 17,   target: 13},
        "Height",       {offset: -14,  target: 60},
        "Weight",       {offset: -18,  target: 200}
    )
}

LogMessage("Initializing reroller")

; Initialize global variables
global g_ProcessHandle := 0
global g_AttributeArrayAddress := 0
global g_BaseAddress := 0
global g_IsRunning := false
global g_TotalAttempts := 0

; Register hotkeys
HotIfWinActive("ahk_exe " CONFIG.GameExecutable)
Hotkey CONFIG.StartHotkey, StartRerolling
Hotkey CONFIG.StopHotkey, StopRerolling

; Start the rerolling process
StartRerolling(*) {
    global g_IsRunning, g_TotalAttempts

    if (g_IsRunning) {
        LogMessage("Already running!")
        return
    }

    ; Reset counters and state
    g_TotalAttempts := 0
    g_IsRunning := true
    
    ; Check if the game is running
    if (!FindGameProcess()) {
        LogMessage("Game not found! Please start Unreal World first.")
        g_IsRunning := false
        return
    }
    
    ; Locate attribute array in memory
    if (!LocateAttributeArray()) {
        LogMessage("Could not locate the attribute array in memory!")
        g_IsRunning := false
        return
    }
    
    LogMessage("Starting reroll loop - press " CONFIG.StopHotkey " to stop")
    
    ; Start the main rerolling loop
    SetTimer RerollLoop, CONFIG.RerollFrequency
}

; Stop the rerolling process
StopRerolling(*) {
    global g_IsRunning

    if (!g_IsRunning) {
        LogMessage("Reroller not running!")
        return
    }

    g_IsRunning := false
    SetTimer RerollLoop, 0
    LogMessage("Rerolling stopped after " g_TotalAttempts " attempts")
}

; Main rerolling logic
RerollLoop() {
    global g_IsRunning, g_TotalAttempts

    if (!g_IsRunning) {
        SetTimer(, 0)
        return
    }
    
    ; Press the reroll key
    Send CONFIG.RerollKey
    g_TotalAttempts++
    
    Sleep CONFIG.ScanDelay
    
    ; Check all attributes
    allAttributesGood := true
    
    for attrName, attrData in CONFIG.Attributes {
        attrValue := ReadAttributeValue(attrName, attrData.offset)
        
        ; Debug log current values
        LogMessage("Check " attrName ": " attrValue " (Target: " attrData.target ")")
        
        if (attrValue < attrData.target) {
            allAttributesGood := false
            break
        }
    }
    
    ; If all attributes meet the targets, stop rerolling
    if (allAttributesGood) {
        LogMessage("Success! All attributes meet targets after " g_TotalAttempts " attempts")
        g_IsRunning := false
        SetTimer(, 0)
    }
}

; Read an attribute value from memory
ReadAttributeValue(attrName, offset) {
    ; Special case for weight, which is 2 bytes
    numBytes := (attrName == "Weight" ? 2 : 1)
    
    ; Read the memory
    value := ReadMemory(g_AttributeArrayAddress + offset, g_ProcessHandle, numBytes)
    
    return value
}

; Read memory from the process
ReadMemory(address, handle, size := 1) {
    if (size == 1) {
        if (DllCall("ReadProcessMemory", "Ptr", handle, "Ptr", address, "UChar*", &result := 0, "Ptr", size, "Ptr", 0)) {
            return result
        }
    } else if (size == 2) {
        if (DllCall("ReadProcessMemory", "Ptr", handle, "Ptr", address, "UShort*", &result := 0, "Ptr", size, "Ptr", 0)) {
            return result
        }
    } else if (size == 4) {
        if (DllCall("ReadProcessMemory", "Ptr", handle, "Ptr", address, "UInt*", &result := 0, "Ptr", size, "Ptr", 0)) {
            return result
        }
    }
    
    return 0
}

; Find the running game process
FindGameProcess() {
    global g_ProcessHandle, g_BaseAddress

    if (!(PID := ProcessExist(CONFIG.GameExecutable))) {
        LogMessage("Couldn't find URW process")
        return false
    }
    
    LogMessage("URW process found at PID " PID ".")
    
    ; Close previous handle if exists
    if (g_ProcessHandle) {
        DllCall("CloseHandle", "Ptr", g_ProcessHandle)
    }
    
    ; Open process with read access
    g_ProcessHandle := DllCall("OpenProcess", "UInt", 0x0010, "Int", false, "UInt", PID, "Ptr")
    
    if (!g_ProcessHandle) {
        LogMessage("Failed to open process handle")
        return false
    }
    
    ; Get base address
    g_BaseAddress := GetModuleBaseAddress(CONFIG.GameExecutable, PID)
    
    if (!g_BaseAddress) {
        LogMessage("Failed to get base address")
        return false
    }
    
    LogMessage("Game found (PID: " PID ", Base: 0x" Format("{:X}", g_BaseAddress) ")")
    return true
}

; Get the base address of a module
GetModuleBaseAddress(moduleName, pid) {
    static PROCESS_QUERY_INFORMATION := 0x0400
    static PROCESS_VM_READ := 0x0010
    static TH32CS_SNAPMODULE := 0x00000008
    static TH32CS_SNAPMODULE32 := 0x00000010
    
    if (!pid) 
        return 0
        
    ; Create snapshot of all modules in the process
    hSnapshot := DllCall("CreateToolhelp32Snapshot", "UInt", TH32CS_SNAPMODULE | TH32CS_SNAPMODULE32, "UInt", pid, "Ptr")
    if (hSnapshot == -1)
        return 0
        
    ; Set up module entry structure
    moduleEntry := Buffer(A_PtrSize == 8 ? 568 : 548, 0)
    NumPut("UInt", moduleEntry.Size, moduleEntry, 0)
    
    ; Get first module
    if (!DllCall("Module32First", "Ptr", hSnapshot, "Ptr", moduleEntry))
    {
        DllCall("CloseHandle", "Ptr", hSnapshot)
        return 0
    }
    
    baseAddress := 0
    
    ; Iterate through modules looking for the requested one
    Loop
    {
        ; Extract module name
        currentName := StrGet(moduleEntry.Ptr + (A_PtrSize == 8 ? 48 : 32), 256, "CP0")
        
        ; If module found, get its base address
        if (currentName = moduleName)
        {
            baseAddress := NumGet(moduleEntry, A_PtrSize == 8 ? 24 : 20, "Ptr")
            break
        }
        
        ; Get next module
        if (!DllCall("Module32Next", "Ptr", hSnapshot, "Ptr", moduleEntry))
            break
    }
    
    DllCall("CloseHandle", "Ptr", hSnapshot)
    return baseAddress
}

; Write a message to the log file
LogMessage(message) {
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend timestamp " " message "`n", CONFIG.LogFile
}

; Find the attribute array in memory using pattern scanning
LocateAttributeArray() {
    global g_AttributeArrayAddress

    ; Get the pattern from configuration
    pattern := CONFIG.Pattern.Signature
    patternOffset := CONFIG.Pattern.Offset
    
    LogMessage("Starting pattern scan for attribute array...")
    
    ; Try multiple memory regions with different sizes
    searchRanges := [
        {start: g_BaseAddress, end: g_BaseAddress + 0x800000},        ; First 8MB
        {start: g_BaseAddress + 0x800000, end: g_BaseAddress + 0x1000000}, ; Next 8MB
        {start: g_BaseAddress, end: g_BaseAddress + 0x2000000, step: 0x200000}, ; Broader scan of first 32MB
        {start: g_BaseAddress, end: g_BaseAddress + 0x10000000, step: 0x1000000} ; Full scan up to 256MB
    ]
    
    ; Try each search range until we find the pattern
    patternAddress := 0
    
    for range in searchRanges {
        if (range.HasOwnProp("step")) {
            ; For broader sweeps, try multiple sub-ranges
            currentStart := range.start
            while (currentStart < range.end) {
                currentEnd := Min(currentStart + range.step, range.end)
                LogMessage("Scanning memory region: " Format("0x{:X}", currentStart) " - " Format("0x{:X}", currentEnd))
                
                patternAddress := ScanProcessMemory(g_ProcessHandle, currentStart, currentEnd, pattern)
                if (patternAddress) {
                    break 2 ; Found it, exit both loops
                }
                
                currentStart += range.step
            }
        } else {
            ; Scan the entire range at once
            LogMessage("Scanning memory region: " Format("0x{:X}", range.start) " - " Format("0x{:X}", range.end))
            patternAddress := ScanProcessMemory(g_ProcessHandle, range.start, range.end, pattern)
            if (patternAddress) {
                break ; Found it, exit the loop
            }
        }
    }
    
    if (!patternAddress) {
        LogMessage("Pattern scanning failed, trying fallback patterns...")
        ; TODO add alternative patterns here if needed
        return false
    }
    
    ; Read the attribute array address from the instruction
    attributeAddressPtr := patternAddress + patternOffset
    
    ; Read the address as a 4-byte value (assuming 32-bit application)
    if (!DllCall("ReadProcessMemory", "Ptr", g_ProcessHandle, "Ptr", attributeAddressPtr, 
                "UInt*", &g_AttributeArrayAddress := 0, "Ptr", 4, "Ptr", 0)) {
        LogMessage("Failed to read attribute array address pointer at " Format("0x{:X}", attributeAddressPtr))
        return false
    }
    
    LogMessage("Found attribute array address at: 0x" Format("{:X}", g_AttributeArrayAddress))
    
    ; Verify it's valid by reading a known attribute
    testValue := ReadMemory(g_AttributeArrayAddress, g_ProcessHandle, 1)
    LogMessage("Test read from attribute array: " testValue)
    
    if (testValue == 0) {
        LogMessage("Warning: Test read from attribute array returned 0, address may be invalid")
    }
    
    return true
}

; Convert a hex pattern string to a byte array and wildcard mask
ParsePattern(patternStr) {
    pattern := []
    mask := ""
    
    ; Remove extra spaces and split the pattern string
    cleanPattern := RegExReplace(patternStr, "\s+", " ")
    parts := StrSplit(cleanPattern, " ")
    
    ; Process each byte
    for part in parts {
        if (part == "??" || part == "?") {
            ; Wildcard byte (can be any value)
            pattern.Push(0)
            mask .= "?"
        } else {
            ; Convert hex string to number
            try {
                pattern.Push(Integer("0x" . part))
                mask .= "x"
            } catch {
                ; Skip invalid parts
                LogMessage("Warning: Invalid pattern part: " part)
            }
        }
    }
    
    return {bytes: pattern, mask: mask}
}

; Scan for a pattern in process memory
ScanProcessMemory(processHandle, startAddress, endAddress, patternStr) {
    ; Parse the pattern
    parsed := ParsePattern(patternStr)
    pattern := parsed.bytes
    mask := parsed.mask
    patternSize := pattern.Length
    
    if (patternSize == 0) {
        LogMessage("Error: Empty pattern after parsing")
        return 0
    }
    
    ; Buffer for reading memory - read in larger chunks for efficiency
    bufferSize := 4096 * 16  ; 64KB chunks
    memBuffer := Buffer(bufferSize, 0)
    
    ; Calculate how many bytes we need to check
    totalBytes := endAddress - startAddress
    
    ; Starting address for current chunk
    currentAddress := startAddress
    
    LogMessage("Scanning memory from " Format("0x{:X}", startAddress) " to " Format("0x{:X}", endAddress) " for pattern of size " patternSize)
    
    ; Scan memory in chunks
    while (currentAddress < endAddress) {
        ; Determine size to read (may be less than bufferSize near end)
        bytesToRead := Min(bufferSize, endAddress - currentAddress)
        
        ; Read memory chunk
        if (!DllCall("ReadProcessMemory", "Ptr", processHandle, "Ptr", currentAddress, 
                     "Ptr", memBuffer.Ptr, "Ptr", bytesToRead, "Ptr*", &bytesRead := 0) || bytesRead == 0) {
            ; Skip this region if it can't be read
            currentAddress += bytesToRead
            continue
        }
        
        ; Search the buffer for pattern
        Loop bytesRead - patternSize + 1 {
            i := A_Index - 1
            isMatch := true
            
            ; Check each byte of the pattern
            Loop patternSize {
                j := A_Index - 1
                ; Skip wildcard bytes (where mask is "?")
                if (SubStr(mask, j + 1, 1) == "x") {
                    ; This byte must match exactly
                    if (NumGet(memBuffer, i + j, "UChar") != pattern[j + 1]) {
                        isMatch := false
                        break
                    }
                }
            }
            
            ; If we found a match, return the address
            if (isMatch) {
                matchAddress := currentAddress + i
                LogMessage("Pattern found at: " Format("0x{:X}", matchAddress))
                return matchAddress
            }
        }
        
        ; Move to next chunk (overlap by pattern size to catch patterns split across chunks)
        currentAddress += bufferSize - patternSize
    }
    
    LogMessage("Pattern not found in memory range")
    return 0
}

; Exit handler to clean up
ExitFunc(ExitReason, ExitCode) {
    if (g_ProcessHandle)
        DllCall("CloseHandle", "Ptr", g_ProcessHandle)
    
    LogMessage("Script terminated: " ExitReason)
    return 0
}

OnExit(ExitFunc)
