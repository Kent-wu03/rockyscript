-- ================================================
--   ROCKYHUB LAUNCHER
--   by RockyBandel
--   Edit GITHUB_USER dan GITHUB_REPO dibawah!
-- ================================================

local GITHUB_USER  = "USERNAME"       -- <-- ganti username GitHub kamu
local GITHUB_REPO  = "REPO"           -- <-- ganti nama repo kamu
local LAUNCHER_FILE = "rockylauncher.lua"  -- nama file ini sendiri (dikecualikan dari list)
local CONFIG_DIR    = "rockyhub_cfg"  -- subfolder penyimpanan config (otomatis dibuat)

-- ================================================
--   SIMPLE JSON (encode/decode minimal)
-- ================================================

local json = {}

local function escapeStr(s)
    return s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t')
end

function json.encode(val, indent)
    indent = indent or 0
    local t = type(val)
    if t == "nil" then return "null"
    elseif t == "boolean" then return tostring(val)
    elseif t == "number" then return tostring(val)
    elseif t == "string" then return '"' .. escapeStr(val) .. '"'
    elseif t == "table" then
        -- check if array
        local isArr = #val > 0
        if isArr then
            local items = {}
            for _, v in ipairs(val) do
                table.insert(items, json.encode(v))
            end
            return "[" .. table.concat(items, ",") .. "]"
        else
            local items = {}
            for k, v in pairs(val) do
                table.insert(items, '"' .. escapeStr(tostring(k)) .. '":' .. json.encode(v))
            end
            return "{" .. table.concat(items, ",") .. "}"
        end
    end
    return "null"
end

function json.decode(s)
    local pos = 1
    local function skip()
        while pos <= #s and s:sub(pos,pos):match('%s') do pos = pos + 1 end
    end
    local function peek() skip(); return s:sub(pos,pos) end
    local function consume(c)
        skip()
        if s:sub(pos,pos) ~= c then return false end
        pos = pos + 1; return true
    end
    local parseVal

    local function parseStr()
        consume('"')
        local res = {}
        while pos <= #s do
            local c = s:sub(pos,pos)
            if c == '"' then pos = pos + 1; break
            elseif c == '\\' then
                pos = pos + 1
                local e = s:sub(pos,pos)
                if     e == '"'  then table.insert(res, '"')
                elseif e == '\\' then table.insert(res, '\\')
                elseif e == 'n'  then table.insert(res, '\n')
                elseif e == 'r'  then table.insert(res, '\r')
                elseif e == 't'  then table.insert(res, '\t')
                else table.insert(res, e) end
                pos = pos + 1
            else
                table.insert(res, c); pos = pos + 1
            end
        end
        return table.concat(res)
    end

    local function parseNum()
        skip()
        local start = pos
        if s:sub(pos,pos) == '-' then pos = pos + 1 end
        while pos <= #s and s:sub(pos,pos):match('[%d%.eE%+%-]') do pos = pos + 1 end
        return tonumber(s:sub(start, pos-1))
    end

    local function parseArr()
        consume('[')
        local arr = {}
        skip()
        if peek() == ']' then consume(']'); return arr end
        while true do
            table.insert(arr, parseVal())
            skip()
            if peek() == ']' then consume(']'); break end
            consume(',')
        end
        return arr
    end

    local function parseObj()
        consume('{')
        local obj = {}
        skip()
        if peek() == '}' then consume('}'); return obj end
        while true do
            skip()
            local k = parseStr()
            consume(':')
            obj[k] = parseVal()
            skip()
            if peek() == '}' then consume('}'); break end
            consume(',')
        end
        return obj
    end

    parseVal = function()
        skip()
        local c = peek()
        if c == '"' then return parseStr()
        elseif c == '{' then return parseObj()
        elseif c == '[' then return parseArr()
        elseif c == 't' then pos = pos + 4; return true
        elseif c == 'f' then pos = pos + 5; return false
        elseif c == 'n' then pos = pos + 4; return nil
        else return parseNum() end
    end

    local ok, result = pcall(parseVal)
    return ok and result or nil
end

-- ================================================
--   FILE IO (read/write via Bothax MakeRequest workaround)
--   Bothax belum ada file IO native, pakai io standard Lua
-- ================================================

local SCRIPT_PATH_ANDROID = "/sdcard/Android/media/com.rtsoft.growtopia/scripts/"
local SCRIPT_PATH_WIN     = os.getenv("APPDATA") and (os.getenv("APPDATA") .. "\\Growtopia\\scripts\\") or nil
local BASE_PATH           = SCRIPT_PATH_WIN or SCRIPT_PATH_ANDROID

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function writeFile(path, content)
    -- pastiin folder ada dulu
    local dir = path:match("^(.*[/\\])")
    if dir then os.execute('mkdir -p "' .. dir .. '" 2>/dev/null || md "' .. dir .. '" 2>nul') end
    local f = io.open(path, "w")
    if not f then return false end
    f:write(content)
    f:close()
    return true
end

local function configPath(scriptName)
    local name = scriptName:gsub("%.lua$", "")
    return BASE_PATH .. CONFIG_DIR .. "/" .. name .. ".json"
end

local function loadConfig(scriptName)
    local content = readFile(configPath(scriptName))
    if not content then return {} end
    return json.decode(content) or {}
end

local function saveConfig(scriptName, cfgData)
    writeFile(configPath(scriptName), json.encode(cfgData))
end

-- ================================================
--   GITHUB API
-- ================================================

local function fetchScriptList()
    local url = "https://api.github.com/repos/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/contents/"
    local res = MakeRequest(url, "GET", {["User-Agent"] = "RockyHub-Launcher"})
    if res.error or res.status ~= 200 then
        return nil, "Gagal fetch GitHub (status " .. tostring(res.status) .. ")"
    end
    local data = json.decode(res.content)
    if not data then return nil, "Gagal parse response GitHub" end

    local scripts = {}
    for _, item in ipairs(data) do
        if item.type == "file"
            and item.name:match("%.lua$")
            and item.name ~= LAUNCHER_FILE
        then
            table.insert(scripts, {
                name       = item.name,
                raw_url    = item.download_url,
                sha        = item.sha or "",
            })
        end
    end
    return scripts, nil
end

local function fetchScriptMeta(rawUrl)
    -- Ambil baris config dari script (baca komentar khusus)
    -- Format di setiap script:
    --   ---META---
    --   -- @name    Nama Script
    --   -- @author  RockyBandel
    --   -- @desc    Deskripsi singkat
    --   ---CONFIG---
    --   -- @field idb number 880 ID Block
    --   -- @field wpabrik string worldkalian Nama World Pabrik
    --   -- @field bhit number 2 Jumlah Hit Block
    --   -- @field trash string 5026,5024,5028 ID Trash (pisah koma)
    --   ---END---
    local res = MakeRequest(rawUrl, "GET")
    if res.error or res.status ~= 200 then return nil end

    local meta   = {name = "", author = "", desc = ""}
    local fields = {}

    for line in res.content:gmatch("[^\n]+") do
        local k, v = line:match("^%s*%-%-%s*@name%s+(.+)")
        if k then meta.name = k end
        k, v = line:match("^%s*%-%-%s*@author%s+(.+)")
        if k then meta.author = k end
        k, v = line:match("^%s*%-%-%s*@desc%s+(.+)")
        if k then meta.desc = k end

        -- @field <key> <type: number|string|bool> <default> <label>
        local fkey, ftype, fdefault, flabel =
            line:match("^%s*%-%-%s*@field%s+(%S+)%s+(%S+)%s+(%S+)%s+(.*)")
        if fkey then
            table.insert(fields, {
                key     = fkey,
                ftype   = ftype,
                default = fdefault,
                label   = flabel or fkey,
            })
        end
    end

    return {meta = meta, fields = fields, raw_url = rawUrl, content = res.content}
end

-- ================================================
--   STATE
-- ================================================

local state = {
    loaded       = false,
    loading      = false,
    error        = nil,
    scripts      = {},          -- list dari GitHub
    selected     = nil,         -- index script yang dipilih
    scriptData   = nil,         -- meta + fields script terpilih
    loadingMeta  = false,
    cfgValues    = {},          -- nilai config saat ini (string semua, dikonversi saat run)
    runStatus    = nil,
    windowOpen   = true,
}

-- ================================================
--   ImGui DRAW
-- ================================================

local uiInputBuf = {}  -- buffer input ImGui per field

AddHook('OnDraw', 'rockyhub_launcher', function(dt)
    if not state.windowOpen then return end

    ImGui.SetNextWindowSize(420, 520, ImGuiCond_Once)
    local open
    state.windowOpen, open = ImGui.Begin('🚀 RockyHub Launcher', state.windowOpen)
    if not open then ImGui.End(); return end

    -- ── HEADER ──
    ImGui.TextColored(0.4, 0.9, 1.0, 1.0, "RockyHub Launcher")
    ImGui.SameLine()
    ImGui.TextDisabled("by RockyBandel")
    ImGui.Separator()

    -- ── FETCH BUTTON ──
    if not state.loaded and not state.loading then
        if ImGui.Button("🔄 Load Script List", -1, 0) then
            state.loading = true
            state.error   = nil
            RunThread(function()
                local list, err = fetchScriptList()
                if err then
                    state.error   = err
                    state.loading = false
                    return
                end
                state.scripts  = list
                state.loaded   = true
                state.loading  = false
            end)
        end
    end

    if state.loading then
        ImGui.TextColored(1, 0.8, 0.2, 1, "⏳ Mengambil list dari GitHub...")
    end

    if state.error then
        ImGui.TextColored(1, 0.3, 0.3, 1, "❌ " .. state.error)
        if ImGui.Button("Coba Lagi") then
            state.loaded  = false
            state.loading = false
            state.error   = nil
        end
    end

    -- ── SCRIPT LIST ──
    if state.loaded then
        ImGui.Text("📂 Script tersedia (" .. #state.scripts .. "):")
        ImGui.BeginChild("scriptlist", 0, 130, true)
        for i, sc in ipairs(state.scripts) do
            local label = sc.name
            local selected = (state.selected == i)
            if ImGui.Selectable(label, selected) and not state.loadingMeta then
                if state.selected ~= i then
                    state.selected   = i
                    state.scriptData = nil
                    state.cfgValues  = {}
                    uiInputBuf       = {}
                    state.runStatus  = nil
                    state.loadingMeta = true

                    RunThread(function()
                        local data = fetchScriptMeta(sc.raw_url)
                        if data then
                            state.scriptData = data
                            -- load saved config
                            local saved = loadConfig(sc.name)
                            for _, f in ipairs(data.fields) do
                                local val = saved[f.key]
                                if val ~= nil then
                                    state.cfgValues[f.key] = tostring(val)
                                else
                                    state.cfgValues[f.key] = f.default
                                end
                                uiInputBuf[f.key] = state.cfgValues[f.key]
                            end
                        end
                        state.loadingMeta = false
                    end)
                end
            end
        end
        ImGui.EndChild()

        -- tombol refresh list
        ImGui.SameLine()
        if ImGui.SmallButton("🔄") then
            state.loaded     = false
            state.selected   = nil
            state.scriptData = nil
            state.cfgValues  = {}
            uiInputBuf       = {}
            state.runStatus  = nil
        end

        ImGui.Separator()

        -- ── DETAIL + CONFIG ──
        if state.selected then
            local sc = state.scripts[state.selected]
            ImGui.TextColored(0.4, 0.9, 1.0, 1.0, "📜 " .. sc.name)

            if state.loadingMeta then
                ImGui.TextColored(1, 0.8, 0.2, 1, "⏳ Loading info script...")
            elseif state.scriptData then
                local sd = state.scriptData
                if sd.meta.desc ~= "" then
                    ImGui.TextWrapped("ℹ️ " .. sd.meta.desc)
                end
                if sd.meta.author ~= "" then
                    ImGui.TextDisabled("👤 " .. sd.meta.author)
                end

                ImGui.Spacing()

                -- CONFIG FIELDS
                if #sd.fields > 0 then
                    ImGui.Text("⚙️ Config:")
                    ImGui.BeginChild("cfgfields", 0, 160, true)
                    for _, f in ipairs(sd.fields) do
                        uiInputBuf[f.key] = uiInputBuf[f.key] or state.cfgValues[f.key] or f.default

                        if f.ftype == "bool" then
                            local bval = (uiInputBuf[f.key] == "true")
                            local changed, newval = ImGui.Checkbox(f.label .. "##" .. f.key, bval)
                            if changed then uiInputBuf[f.key] = tostring(newval) end
                        else
                            ImGui.Text(f.label)
                            ImGui.SameLine(130)
                            ImGui.SetNextItemWidth(-1)
                            local changed, newval = ImGui.InputText("##" .. f.key, uiInputBuf[f.key], 128)
                            if changed then uiInputBuf[f.key] = newval end
                        end
                    end
                    ImGui.EndChild()

                    -- SAVE CONFIG
                    if ImGui.Button("💾 Save Config", 130, 0) then
                        for k, v in pairs(uiInputBuf) do
                            state.cfgValues[k] = v
                        end
                        saveConfig(sc.name, state.cfgValues)
                        state.runStatus = "`2Config tersimpan!"
                    end
                    ImGui.SameLine()
                end

                -- RUN BUTTON
                if ImGui.Button("▶ Run Script", -1, 0) then
                    -- save dulu sebelum run
                    for k, v in pairs(uiInputBuf) do
                        state.cfgValues[k] = v
                    end
                    saveConfig(sc.name, state.cfgValues)

                    -- Inject config ke global lalu jalankan script
                    RunThread(function()
                        state.runStatus = "`eMemuat script..."

                        -- Build config global dari cfgValues
                        local cfgChunk = "config = config or {}\n"
                        for _, f in ipairs(sd.fields) do
                            local val = state.cfgValues[f.key] or f.default
                            if f.ftype == "number" then
                                cfgChunk = cfgChunk .. "config." .. f.key .. " = " .. (tonumber(val) or 0) .. "\n"
                            elseif f.ftype == "bool" then
                                cfgChunk = cfgChunk .. "config." .. f.key .. " = " .. (val == "true" and "true" or "false") .. "\n"
                            elseif f.ftype == "idlist" then
                                -- "5026,5024,5028" → {5026,5024,5028}
                                local ids = {}
                                for id in val:gmatch("[^,]+") do
                                    local n = tonumber(id:match("^%s*(.-)%s*$"))
                                    if n then table.insert(ids, n) end
                                end
                                local arr = "{" .. table.concat(ids, ",") .. "}"
                                cfgChunk = cfgChunk .. "config." .. f.key .. " = " .. arr .. "\n"
                            else
                                cfgChunk = cfgChunk .. 'config.' .. f.key .. ' = "' .. val:gsub('"', '\\"') .. '"\n'
                            end
                        end

                        -- Load script utama
                        local fn1, e1 = load(cfgChunk)
                        if fn1 then fn1() end

                        local fn2, e2 = load(sd.content)
                        if fn2 then
                            fn2()
                            state.runStatus = "`2Script berjalan!"
                        else
                            state.runStatus = "`4Error: " .. tostring(e2)
                        end
                    end)
                end

                -- STATUS
                if state.runStatus then
                    ImGui.Spacing()
                    SendVariantList({[0]="OnTextOverlay",[1]=state.runStatus})
                    -- tampilkan versi plain
                    local plain = state.runStatus:gsub("`%a", "")
                    ImGui.TextDisabled(plain)
                end
            else
                ImGui.TextDisabled("Pilih script dari list di atas")
            end
        else
            ImGui.TextDisabled("← Pilih script dari list di atas")
        end
    end

    ImGui.End()
end)

LogToConsole("`^[RockyHub] Launcher aktif! Buka ImGui untuk memilih script.")
