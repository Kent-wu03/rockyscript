ids = 4585 -- id seed
delay_recon = 3500
wplant = "RFIAV" -- worldplant

-- do not touch
SendVariantList({[0] = "OnDialogRequest", [1] = [[
set_default_color|`w
add_label_with_icon|small|`cAuto Plant|left|1438|
add_label_with_icon|small|`9Script by RockyBandel|left|2480|
add_spacer|small|
add_smalltext|`2This script is free|
add_spacer|small|
add_smalltext|`2Feature|
add_label_with_icon|small|`cAuto reconnect `0- `5(ignore error console)|left|3802|
add_label_with_icon|small|`cAuto find & take seed|left|6016|
add_label_with_icon|small|`cAuto detect tile|left|102|
add_spacer|small|
add_smalltext|`4DO NOT SELL THIS SCRIPT!|
add_quick_exit|]]})

ChangeValue("[C] Modfly v2", true)

ispt = true
dc = false

function getdata()
    for _, tile in ipairs(GetTiles()) do
        if tile.y % 2 == 1 and tile.x > 0 and tile.x < 99 then
            if tile.fg == 0 then
                return tile
            end
        end
    end
    return nil
end

function log(text)
    SendVariantList({[0] = "OnTextOverlay", [1] = "[ `^RockyHub Info `w] : " .. text})
end

function ltc(text)
    LogToConsole("`^" .. text)
end

function move(tx, ty, s, h)
    s = s or 4
    while true do
        local x = math.floor(GetLocal().pos.x / 32)
        local y = math.floor(GetLocal().pos.y / 32)
        if x == tx and y == ty then return true end
        local dx, dy, nx, ny = tx - x, ty - y, x, y
        if h then
            nx = x + math.max(-s, math.min(s, dx))
            if nx == x then ny = y + math.max(-s, math.min(s, dy)) end
        else
            ny = y + math.max(-s, math.min(s, dy))
            if ny == y then nx = x + math.max(-s, math.min(s, dx)) end
        end
        FindPath(nx, ny)
        Sleep(300 + math.random(30, 80))
    end
end

function plant(x, y)
    SendPacketRaw(false, {type=3, value=ids, px=x, py=y, x=GetLocal().pos.x, y=GetLocal().pos.y})
    Sleep(175)
end

function ts(id)
    for _, obj in pairs(GetObjectList()) do
        if obj.id == id then
            move(math.floor(obj.pos.x / 32), math.floor(obj.pos.y / 32))
            SendPacketRaw(false, {type=11, value=obj.oid, x=obj.pos.x, y=obj.pos.y})
            return true
        end
    end
    log("Seed not found")
    return false
end

function planting()
    while ispt do
        local world = GetWorld()
        if not world or world.name ~= wplant then
            Sleep(1300)
            ltc("Reconnecting to " .. wplant)
            RequestJoinWorld(wplant)
            Sleep(delay_recon)
            world = GetWorld()
            if world and world.name == wplant then
                dc = true
            end
        end

        if dc then
            log("Going back to pos")
            dc = false
        end

        Sleep(500)

        local skip = false
        if GetItemCount(ids) <= 1 then
            log("Take Seed")
            if not ts(ids) then
                Sleep(1000)
                skip = true
            else
                Sleep(500)
            end
        end

        if not skip then
            local tile = getdata()
            if tile then
                FindPath(tile.x, tile.y, 500)
                local t = GetTile(tile.x, tile.y)
                if t and t.fg == 0 then
                    plant(tile.x, tile.y)
                end
            else
                log("Done Plant")
                Sleep(500)
				ispt = false
                break
            end
        end

        Sleep(100)
    end
end

while true do
    if not ispt then
        break
    end

    local ok, err = pcall(planting)
    if not ok then
        ltc("Error: " .. tostring(err))
        Sleep(3000)
    end
    Sleep(200)
end