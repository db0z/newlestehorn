-- UI things

function tileButton(n, highlight)
    local x, y, w, h = ui:widgetBounds()
    ui:image({p8data.spritesheet, p8data.quads[n]})

    local hov = false
    if ui:inputIsHovered(x, y, w, h) then
        hov = true
    end
    if hov or highlight then
        love.graphics.setLineWidth(1)
        if hov then
            love.graphics.setColor(0, 1, 0.5)
        else
            love.graphics.setColor(1, 1, 1)
        end
        x, y = x - 0.5, y - 0.5
        w, h = w + 1, h + 1
        ui:line(x, y, x + w, y)
        ui:line(x, y, x, y + h)
        ui:line(x + w, y, x + w, y + h)
        ui:line(x, y + h, x + w, y + h)
    end
    if ui:inputIsMousePressed("left", x, y, w, h) then
        return true
    end
end

function toolLabel(label, tool)
    local hov = ui:widgetIsHovered()
    local x, y, w, h = ui:widgetBounds()

    local color = "#afafaf"
    if tool == app.tool then
        color = "#00ff88"
    end

    if hov then
        local bg = "#00ff88" --"#afafaf"
        ui:rectMultiColor(x, y, w + 4, h, bg, bg, bg, bg)
        color = "#2d2d2d"
        ui:stylePush {
            window = {
                background = bg,
            }
        }

        app.tool = tool
    end

    ui:label(label, "left", color)

    if hov then ui:stylePop() end
end

function closeToolMenu()
    app.toolMenuX, app.toolMenuY = nil, nil
end



-- MAIN LOOP

function love.load(args)
    love.keyboard.setKeyRepeat(true)

    ui = nuklear.newUI()

    global_scale=1 -- global scale, to run nicely on hi dpi displays
    tms = 4 -- tile menu scale

    for _,v in ipairs(args) do
        if v=="--hidpi" then
            global_scale = 2
            tms = 4*global_scale
        end
    end

    --p8data = loadpico8(love.filesystem.getSource().."\\celeste.p8")

    newProject()
    pushHistory()

    openPico8("test.p8")

    checkmarkIm=love.graphics.newImage("checkmark.png")
    checkmarkWithBg=love.graphics.newCanvas(checkmarkIm:getWidth()*5/4,checkmarkIm:getHeight()*5/4)
    love.graphics.setCanvas(checkmarkWithBg)
    love.graphics.clear(0x64/0xff,0x64/0xff,0x64/0xff)
    love.graphics.draw(checkmarkIm,checkmarkIm:getWidth()/8,checkmarkIm:getHeight()/8)
    love.graphics.setCanvas()
end

function love.update(dt)
    app.W, app.H = love.graphics.getDimensions()
    local rpw = app.W * 0.10 -- room panel width
    app.left, app.top = rpw, 0

    ui:frameBegin()
    --ui:scale(2)

    ui:stylePush {
        window = {
            spacing = {x = 1, y = 1},
            padding = {x = 1, y = 1},
        },
        selectable = {
            padding = {x = 0, y = 0},
            ["normal active"] = "#000000",
            ["hover active"] = "#000000",
            ["pressed active"] = "#000000",
        },
        checkbox = {
            ["cursor normal"] = checkmarkIm,
            ["cursor hover"] = checkmarkIm
        }
    }

    -- room panel
    if ui:windowBegin("Room Panel", 0, 0, rpw, app.H, {"scrollbar"}) then
        ui:layoutRow("dynamic", 25*global_scale, 1)
        for n = 1, #project.rooms do
            if ui:selectable("["..n.."] "..project.rooms[n].title, n == app.room) then
                app.room = n
            end
        end

        if app.roomAdded then
            ui:windowSetScroll(0, 100000)
            app.roomAdded = false
        end
    end
    ui:windowEnd()

    -- tool panel
    if app.showToolPanel then
        local tpw = 16*8*tms + 18
        if ui:windowBegin("Tool panel", app.W - tpw, 0, tpw, app.H) then
            -- tools list
            for i = 0, #toolslist - 1 do
                if i%4 == 0 then
                    ui:layoutRow("dynamic", 25*global_scale, 4)
                end

                local tool = toolslist[1 + i]

                if ui:selectable(tools[tool].name, app.tool == tool) then
                    if app.tool and app.tool ~= tool then
                        tools[app.tool].ondisabled()

                        app.tool = tool

                        tools[app.tool].onenabled()
                    end
                end
            end

            -- some spacing
            ui:layoutRow("dynamic", 10*global_scale, 0)

            -- tool panel
            tools[app.tool].panel()
        end
        ui:windowEnd()
    end

    app.enterPressed = false

    app.anyWindowHovered = ui:windowIsAnyHovered()

    ui:stylePop()

    -- tool update
    tools[app.tool].update(dt)

    ui:frameEnd()

    local x, y = love.mouse.getPosition()
    local mx, my = fromScreen(x, y)

    if app.roomResizeSideX and app.room then
        local room = activeRoom()

        local left, top = room.x, room.y
        local right, bottom = left + room.w*8, top + room.h*8

        local ax = app.roomResizeSideX > 0 and right or left
        local ay = app.roomResizeSideY > 0 and bottom or top

        local dx = div8(math.abs(mx-ax)) * sign(mx-ax) * app.roomResizeSideX
        local dy = div8(math.abs(my-ay)) * sign(my-ay) * app.roomResizeSideY

        if dx ~= 0 or dy ~= 0 then
            local newdata, neww, newh = {}, math.max(1, room.w + dx), math.max(1, room.h + dy)

            -- copy all tiles (even if outside bounds - so they persist if you cut part of room off and then resize back)
            for i, col in pairs(room.data) do
                for j, n in pairs(col) do
                    local i_, j_ = i + (ax == left and dx or 0), j + (ay == top and dy or 0)

                    if not newdata[i_] then newdata[i_] = {} end
                    newdata[i_][j_] = n
                end
            end
            -- add 0 when no data is there
            for i = 0, neww - 1 do
                newdata[i] = newdata[i] or {}
                for j = 0, newh - 1 do
                    newdata[i][j] = newdata[i][j] or 0
                end
            end

            room.x = room.x - (ax == left and 8*(neww-room.w) or 0)
            room.y = room.y - (ay == top and 8*(newh-room.h) or 0)
            room.data, room.w, room.h = newdata, neww, newh
        end
    end

    if app.message then
        app.messageTimeLeft = app.messageTimeLeft - dt
        if app.messageTimeLeft < 0 then
            app.message = nil
            app.messageTimeLeft = nil
        end
    end
end

function love.draw()
    love.graphics.clear(0.25, 0.25, 0.25)
    love.graphics.reset()
    love.graphics.setLineStyle("rough")

    local x, y = love.mouse.getPosition()
    local mx, my = fromScreen(x, y)

    local ox, oy = toScreen(0, 0)
    love.graphics.translate(math.floor(ox), math.floor(oy))
    love.graphics.scale(app.camScale)

    love.graphics.setColor(0.28, 0.28, 0.28)
    love.graphics.setLineWidth(2)
    for i = 0, 7 do
        for j = 0, 3 do
            love.graphics.rectangle("line", i*128, j*128, 128, 128)
        end
    end

    for _, room in ipairs(project.rooms) do
        if room ~= activeRoom() then
            drawRoom(room, p8data)
            love.graphics.setColor(0.5, 0.5, 0.5, 0.4)
            love.graphics.rectangle("fill", room.x, room.y, room.w*8, room.h*8)
        end
    end
    if activeRoom() then
        drawRoom(activeRoom(), p8data)
    end
    if project.selection then
        drawRoom(project.selection, p8data, true)
        love.graphics.setColor(0, 1, 0.5)
        love.graphics.setLineWidth(1 / app.camScale)
        love.graphics.rectangle("line", project.selection.x + 0.5 / app.camScale, project.selection.y + 0.5 / app.camScale, project.selection.w*8, project.selection.h*8)
    end

    -- tool draw
    tools[app.tool].draw()

    love.graphics.reset()
    love.graphics.setColor(1, 1, 1)
    love.graphics.translate(app.left, app.top)
    love.graphics.setFont(app.font)

    if app.message then
        love.graphics.print(app.message, 4, app.H - app.font:getHeight() - 4)
    end

    if app.playtesting then
        local s = app.playtesting == 1 and "[playtesting]" or "[playtesting, 2 dashes]"
        love.graphics.print(s, 4, 4)
    end
    ui:draw()
end
