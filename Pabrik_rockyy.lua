-- sblm start script berdiri di posisi break
config = {
    idb =880, -- id block
    bhit = 2, -- jumlah hit block
    plat = 102, -- plat for farm (for plant)
    trash = {5026, 5024 , 5028},
    wpabrik = "worldkalian", -- world pabrik
    idpabrik = "iddoor", -- id world pabrik
    delay_recon = 3500, -- delay reconnect
}

-- do not touch
SendVariantList({[0] = "OnDialogRequest", [1] = [[
set_default_color|`w
add_label_with_icon|small|`cPABRIK|left|1438|
add_label_with_icon|small|`9Script by RockyBandel|left|2480|
add_spacer|small|
add_smalltext|`2This script is free|
add_spacer|small|
add_smalltext|`2Feature|
add_label_with_icon|small|`cAuto reconnect `0- `5(ignore error console)|left|3802|
add_label_with_icon|small|`cFast PNB `0- `5keknya :v |left|1438|
add_label_with_icon|small|`cAuto detect tile|left|102|
add_label_with_icon|small|`cAuto store seed on vend|left|23|
add_label_with_icon|small|`cAuto plant & harvest|left|3200|
add_label_with_icon|small|`cAuto trash with custom id `0- `5Setting di config|left|5026|
add_spacer|small|
add_smalltext|`4DO NOT RESELL!|
add_quick_exit|]]})

ChangeValue("[C] Modfly v2", true)

farming = true
planting = false
harvesting = false
dc = false

config.ex = math.floor(GetLocal().pos.x / 32)
config.ey = math.floor(GetLocal().pos.y / 32)
config.ids = config.idb + 1
config.tworld = config.wpabrik.."|"..config.idpabrik
pos = {}

function log(text) 
    SendVariantList({[0] = "OnTextOverlay", [1] = "[ `^RockyHub Info `w] : " .. text}) 
end

function ltc(text)
    LogToConsole("`^"..text)
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

function getTile(x, y)
    for _, tile in pairs(GetTiles()) do
        if tile.x == x and tile.y == y then
            return tile
        end
    end
    return nil
end

function getdata()
    ltc("Getting data")
    for _, tile in pairs(GetTiles()) do
        if tile.fg == config.plat and tile.y == config.ey + 1 then
            table.insert(pos, {x = tile.x, y = tile.y})
        end
    end
    ltc("total "..#pos.." tile")
end

function inv(id)
    for _, item in pairs(GetInventory()) do
        if item.id == id then return item.amount end
    end
    return 0
end

function trash()
    for _, id in ipairs(config.trash) do
        titem = inv(id)
        if titem >= 15 then
            SendPacket(2, "action|trash\n|itemID|"..id)
            Sleep(1000)
            SendPacket(2, "action|dialog_return\ndialog_name|trash_item\nitemID|"..id.."|\ncount|"..titem)
            Sleep(1010)
            log("Trashed "..titem.." items")
        end
    end
end

function checktree()
    for _, p in pairs(pos) do
        local tile = getTile(p.x, p.y - 1)

        if tile and tile.fg == config.ids then
            if not tile.extra or tile.extra.progress < 1.0 then
                return false
            end
        end
    end

    return true
end

function wrench(x, y)
    SendPacketRaw(false, {
        type = 3,
        value = 32,
        px = x,
        py = y,
        x = GetLocal().pos.x,
        y = GetLocal().pos.y
    })
end

function addvend()
    AddHook('OnVariant','blockvending', function(var, netid, delay)
        if var[0] == 'OnDialogRequest' then
            LogToConsole('Blocked Dialog!')
            return true
        end
    end)
    log("Add seed")
    wrench(config.ex,config.ey)
    SendPacket(2, "action|dialog_return\ndialog_name|vending\ntilex|"..config.ex.."|\ntiley|"..config.ey.."|\nbuttonClicked|addstock\n\nsetprice|100\nchk_peritem|1\nchk_perlock|0")
    RemoveHook('blockvending')
end

function collect(obj)
    SendPacketRaw(false, {type=11,value=obj.oid,x=obj.pos.x,y=obj.pos.y})
end

function collectDrop()
    local bx = config.ex - 1
    local by = config.ey

    for _, obj in pairs(GetObjectList()) do
        local ox = math.floor(obj.pos.x / 32)
        local oy = math.floor(obj.pos.y / 32)

        if math.abs(ox - bx) <= 2 and math.abs(oy - by) <= 2 then
            collect(obj)
            Sleep(20)
        end
    end
end

function plant(x,y)
	pkt = {}
	pkt.type = 3
	pkt.value = config.ids
	pkt.px = x
	pkt.py = y
	pkt.x = GetLocal().pos.x
	pkt.y = GetLocal().pos.y
	SendPacketRaw(false,pkt)
	Sleep(180)
end

function placeb(x,y)
	pkt = {}
	pkt.type = 3
	pkt.value = config.idb
	pkt.px = x
	pkt.py = y
	pkt.x = GetLocal().pos.x
	pkt.y = GetLocal().pos.y
	SendPacketRaw(false,pkt)
	Sleep(180)
end

function breakb(x, y)
	pkt = {}
	pkt.type = 3
	pkt.value = 18
	pkt.px = x
	pkt.py = y
	pkt.x = GetLocal().pos.x
	pkt.y = GetLocal().pos.y
	SendPacketRaw(false,pkt)
	Sleep(180)
end

function pnb()
    log("Start PNB")
    move(config.ex, config.ey, 4, false)
    while inv(config.idb) > 10 do
        local bx = config.ex - 1
        local by = config.ey

		collectDrop(bx, by)
        placeb(bx, by)

        for i = 1, config.bhit do
            breakb(bx, by)
        end
    end
end

function pt()
    log("Planting")
    for _, p in pairs(pos) do
        local above = getTile(p.x, p.y - 1)

        if above and above.fg == 0 then
			move(p.x,p.y - 1,4,false)
            plant(p.x, p.y-1)
            Sleep(100)
        end
    end
end

function collectht()
    local px = math.floor(GetLocal().pos.x / 32)
    local py = math.floor(GetLocal().pos.y / 32)

    for _, obj in pairs(GetObjectList()) do
        local ox = math.floor(obj.pos.x / 32)
        local oy = math.floor(obj.pos.y / 32)

        if math.abs(ox - px) <= 2 and math.abs(oy - py) <= 2 then
            collect(obj)
            Sleep(20)
        end
    end
end

function ht()
    while not checktree() do
        Sleep(5000)
    end
        log("Harvesting")
    for _, p in pairs(pos) do
        local above = getTile(p.x, p.y - 1)

        if above and above.fg == config.ids then
            if above.extra and above.extra.progress == 1.0 then
                if inv(config.idb) <= 170 then
                    move(p.x, p.y - 1, 4, false)
                    breakb(p.x, p.y - 1)
                    Sleep(100)
                    collectht()
                end
            end
        end
    end
end

function pabrik()
    local world = GetWorld()

    if not world or world.name ~= config.wpabrik then
        Sleep(1300)
        ltc("Reconnecting")
        RequestJoinWorld(config.tworld)
        Sleep(config.delay_recon)
        world = GetWorld()
        if world and world.name == config.wpabrik then
            dc = true
        end
    end

    if dc then
        log("Going back to pos")
        move(config.ex, config.ey, 4, false)
        dc = false
    end

    Sleep(500)
end    


function ds(x,jumlah)
        SendPacket(2, "action|drop\nitemID|" ..x)
        Sleep(500)
        SendPacket(2,
            "action|dialog_return\n" ..
            "dialog_name|drop_item\n" ..
            "itemID|" .. x .. "|\n" ..
            "count|" .. jumlah
        )
end

function pabrik()
    local world = GetWorld()
    if not world or world.name ~= config.wpabrik then
        Sleep(1300)
        ltc("Reconnecting to " .. config.wpabrik)
        RequestJoinWorld(config.tworld)
        Sleep(config.delay_recon)
        world = GetWorld()
        if world and world.name == config.wpabrik then
            dc = true
        end
    end

    if dc then
        log("Going back to pos")
        move(config.ex, config.ey, 4, false)
        dc = false
    end

    Sleep(500)

    local blockCount = inv(config.idb)
    local seedCount  = inv(config.ids)
    local condA = blockCount > 10  
    local condB = seedCount <= (#pos + 50)

    if condA and condB then
        pnb()

    elseif condA and not condB then
        toDrop = #pos
        ds(config.ids,toDrop)
        Sleep(800)
        addvend()
    else
        pt()
        ht()
        pnb()
    end
    trash()
    collectDrop()
    Sleep(500)
end

getdata()

while true do
    local ok, err = pcall(pabrik)
    if not ok then
        ltc("Error: " .. tostring(err))
        Sleep(3000)
    end
    Sleep(200)
end
