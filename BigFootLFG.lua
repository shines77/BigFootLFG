local EnableFilter = true

local EnableForbiddenRepeat = true
local EnableForbiddenTrash = true
local EnableForbiddenBigfoot = true

DEFAULT_CHAT_FRAME:AddMessage("已启用BigfootLFG，具体指令请输入/bflfg" )

-- 过滤器的更新间隔 (单位: 秒)
local UpdateInterval = 5

-- 玩家几秒才能说一次话，超过这个频率的发言不会显示(防止疯狂说不同的话这种)
local ChatInterval = 2
-- 相同的内容多少秒内不会重复显示(单位: 秒)
local ContentRepeatInterval = 30

-- 忽略的符号字符
local Symbols = {"`","~","@","#","^","*","=","|"," ","，","。","、","？","！","：","；","’","‘","“","”","【","】","『","』","《","》","<",">","（","）"}

-- 屏蔽商业喊话的关键字列表
local MatchForbidden = {"无限","大量","邮寄","丝绸","魔纹","符文布","硬甲皮","英雄","活动","血色","厄运","飞机","航班","直达","1G","2G","3G","1Ｇ","2Ｇ","3Ｇ","1金","2金","3金"}
-- 出现组合屏蔽词库内的几个不同词语就进行屏蔽
local MatchCount = 2

-- 硬屏蔽的关键字列表
local HardForbidden = {"装等","无限收","无线收","高价收","大量收","效率","带血色","老板","老木板","{rt"}

-- 大脚白名单模式显示的过滤词
local Show = {"治疗","奶","N","牧师","MS","DPS","拉怪","猎人","LR","法师","FS","黑石深渊","黑石"}

-- 大脚白名单模式过滤后需要去屏蔽的词
local ForbiddenOnShow = {"公会","工会",
                         "怒焰","NY","ny",
                         "哀嚎","AH","ah",
                         --"死亡矿井","死矿","SK","sk","SW","sw",
                         --"监狱","JY","jy",
                         "黑暗深渊","SY","sy",
                         "影牙","YY","yy",
                         "剃刀","沼泽","TDZZ","tdzz",
                         "诺莫瑞根","瑞根","矮人本",
                         --"血色","XS","墓地","MD","图书馆","武器库","军械库","教堂",
                         "高地","TDGD","tdgd",
                         "奥达曼","ADM","adm",
                         "祖尔","祖尔法拉克","ZUL","zul",
                         --"AA",
}

local ForbiddenOnShow2 = {
                         -- "黑石","黑石深渊","深渊","HS","hs",
}

--
-- About string.find(), string.gsub() in Lua.
--
-- See: https://www.cnblogs.com/meamin9/p/4502461.html
--

local function removeElementByKey(tbl, key)
    local tmp = {}
    
    for i in pairs(tbl) do
        table.insert(tmp, i)
    end

    local newTbl = {}

    local i = 1
    while i <= #tmp do
        local val = tmp[i]
        if val == key then
            table.remove(tmp, i)
        else
            newTbl[val] = tbl[val]
            i = i + 1
        end
    end

    return newTbl
end

function utf8ToChars(input)
     local list = {}
     local len  = string.len(input)
     local index = 1
     local arr  = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
     while index <= len do
        local c = string.byte(input, index)
        local offset = 1
        if c < 0xc0 then
            offset = 1
        elseif c < 0xe0 then
            offset = 2
        elseif c < 0xf0 then
            offset = 3
        elseif c < 0xf8 then
            offset = 4
        elseif c < 0xfc then
            offset = 5
        end
        local str = string.sub(input, index, index + offset - 1)
        -- print(str)
        index = index + offset
        table.insert(list, str)
     end

     return list
end

function MergeTable(...)
    local tabs = {...}
    if not tabs then
        return {}
    end
    local origin = tabs[1]
    for i = 2, #tabs do
        if origin then
            if tabs[i] then
                for k, v in pairs(tabs[i]) do
                    table.insert(origin,v)
                end
            end
        else
            origin = tabs[i]
        end
    end
    return origin
end

function removeDuplicates(str)
    
    local chars = utf8ToChars(str)
    
    local buffChars = {
        old = {},
        new = {},
    }
    
    local index = 1
    
    for i = 1, #chars do
        table.insert(buffChars.new, chars[i])
        
        if not buffChars.old[index] or chars[i] ~= buffChars.old[index] then
            MergeTable(buffChars.old, buffChars.new)
            buffChars.new = {}
        else
            index = index + 1

            if index > 2 and index > #buffChars.old then
                --buffChars.new = {}
                --index = 1
                break
            end
        end
    end

    local ret = ""
    for i = 1, #buffChars.old do
        ret = ret .. buffChars.old[i]
    end
    
    return ret
end

local function CheckMatchForbidden(str)
    local match = 0
    for _, word in ipairs(MatchForbidden) do
        local start, end2, substr = string.find(str, word, 1, true)
        if start ~= nil and start > 0 then
            match = match + 1
        end
        --[[
        local _, result = gsub(str, word, "")
        if (result > 0) then
            match = match + 1
        end
        --]]
    end

    if match >= MatchCount then
        return true
    else
        return false
    end
end


local anti_spam = CreateFrame("Frame")
local last30Seconds = {}
local function last30Seconds_OnUpdate()
    if not last30Seconds then return end
    if not anti_spam.lastcheck then anti_spam.lastcheck = GetTime() end
    if GetTime() - anti_spam.lastcheck < UpdateInterval then return end
    for _, c in pairs(last30Seconds) do
        for s,t in pairs(c) do
            if GetTime() - t.time > ContentRepeatInterval then
                c[s] = nil
            end
        end
    end
    anti_spam.lastcheck = GetTime()
end

anti_spam:SetScript("OnUpdate", last30Seconds_OnUpdate)

local function removeServerDash(name)
    local dash = name:find("-");
    if dash then
        return name:sub(1, dash - 1);
    end
    return name;
end

local lastLineId = 0
local lastNeedBlocked = false
local lastFilteredMsg = ""

-- zone channel id : Zone ID used for generic system channels (1 for General, 2 for Trade, 22 for LocalDefense, 23 for WorldDefense and 26 for LFG). 
-- Not used for custom channels or if you joined an Out-Of-Zone channel ex: "General - Stormwind City"
function ChatChannelFilter(self, event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelId, channelIndex, channelBaseName, unused, lineId, guid, bnSenderId)

    if EnableFilter then
        if UnitIsUnit(playerName2, "player") then
            return false
        end

        for _, symbol in ipairs(Symbols) do
            text, a = gsub(text, symbol, "")
        end
        
        text = removeDuplicates(text)
        
        -- 防刷屏
        local nameNoDash = removeServerDash(playerName)
        if nameNoDash ~= UnitName("player") and EnableForbiddenRepeat then
            t = GetTime()

            last30Seconds[self.name] = last30Seconds[self.name] or {}
            
            if last30Seconds[self.name][nameNoDash] then
                if t - last30Seconds[self.name][nameNoDash].time < ChatInterval then
                    last30Seconds[self.name][nameNoDash] = { time = t, content = text }
                    --print("dect spam : " .. nameNoDash .. ":".. text)
                    return true
                end
                
                if t - last30Seconds[self.name][nameNoDash].time < ContentRepeatInterval and msg == last30Seconds[self.name][nameNoDash].content then
                    last30Seconds[self.name][nameNoDash] = { time = t, content = text }
                    --print("dect repeat : " .. nameNoDash .. ":".. text)
                    return true
                end
            end

            last30Seconds[self.name][nameNoDash] = { time = t, content = text }
        end
        
        -- 硬屏蔽
        for _, word in ipairs(HardForbidden) do
            local start, end2, substr = string.find(text, word, 1, true)
            if start ~= nil and start > 0 then
                return true
            end
            --[[
            local _, result = gsub(text, word, "")
            if (result > 0) then
                return true
            end
            --]]
        end

        -- 多词语
        if CheckMatchForbidden(text) then
            return true
        end
        
        -- 大脚白名单模式
        if EnableForbiddenBigfoot and (channelBaseName == "大脚世界频道" or channelBaseName == "大脚世界频道2" or channelBaseName == "世界频道" or channelBaseName == "大脚世界频道3" or channelBaseName == "大脚世界频道4") then
            local find = false
            for _, word in ipairs(Show) do
                local start, end2, substr = string.find(text, word, 1, true)
                if start ~= nil and start > 0 then
                    find = true
                    break
                end
                --[[
                local newString, result = gsub(text, word, "");
                if (result > 0) then
                    find = true
                    break
                end
                --]]
            end

            if find then
                for _, word in ipairs(ForbiddenOnShow) do
                    local start, end2, substr = string.find(text, word, 1, true)
                    if start ~= nil and start > 0 then
                        return true
                    end
                    --[[
                    local newString, result = gsub(text, word, "");
                    if (result > 0) then
                        return true
                    end
                    --]]
                end
                
                return false
            else
                return true
            end
        end
    end
    
    return false
end

--
-- API ChatFrame AddMessageEventFilter
-- https://wowwiki.fandom.com/wiki/API_ChatFrame_AddMessageEventFilter
--

-- ffc0c0 (WoW DefaultChatTextColor)
-- See: https://wowwiki.fandom.com/wiki/API_ChangeChatColor

-- ff9d00 (Oringe)
-- ffdd00 (Golden)

--
-- See: https://wow.gamepedia.com/CHAT_MSG_CHANNEL
--
-- zone channel id : Zone ID used for generic system channels (1 for General, 2 for Trade, 22 for LocalDefense, 23 for WorldDefense and 26 for LFG). 
-- Not used for custom channels or if you joined an Out-Of-Zone channel ex: "General - Stormwind City"
--
function BigFootLFG_Filter(self, event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelId, channelIndex, channelBaseName, unused, lineId, guid, bnSenderId)
    if lineId == lastLineId then
        if lastNeedBlocked then
            if (self == DEFAULT_CHAT_FRAME) then
                -- DEFAULT_CHAT_FRAME:AddMessage("\124cffffc0c0[" .. tostring(channelIndex) .. "." .. channelBaseName .. "] [\124r\124cffffdd00**" .. playerName2 .. "**\124r\124cffffc0c0]： " .. text .."\124r")
            end
            -- text = "消息已屏蔽"
            --return true, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelId, channelIndex, channelBaseName, unused, lineId, guid, bnSenderId
            return true
        else
            return lastNeedBlocked
        end
    else
        lastLineId = lineId
        local needBlocked = ChatChannelFilter(self, event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelId, channelIndex, channelBaseName, unused, lineId, guid, bnSenderId)
        lastNeedBlocked = needBlocked
        if needBlocked then
            if (self == DEFAULT_CHAT_FRAME) then
                -- DEFAULT_CHAT_FRAME:AddMessage("\124cffffc0c0[" .. tostring(channelIndex) .. "." .. channelBaseName .. "] [\124r\124cffffdd00*" .. playerName2 .. "*\124r\124cffffc0c0]： " .. text .."\124r")
            end
            -- text = "消息已屏蔽"
            --return true, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelId, channelIndex, channelBaseName, unused, lineId, guid, bnSenderId
            return true
        else
            return needBlocked
        end
    end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", BigFootLFG_Filter)
--ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", BigFootLFG_Filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", BigFootLFG_Filter)
--ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", BigFootLFG_Filter)

AddLevelBeforeName = true

-----------------------------------------------------------------------
-- Add Level To Name
-----------------------------------------------------------------------
if AddLevelBeforeName then
    local Orgi_GetColoredName = GetColoredName

    function GetColoredName(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12)
        local fullName, level = arg2
        if (not strfind(fullName, "-")) then fullName = fullName.."-"..GetRealmName() end
        local name = Orgi_GetColoredName(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12)
        if level then
            if (strfind(name, "\124c")) then
                return name:gsub("(\124cff%x%x%x%x%x%x)(.-)(\124r)", "%1"..level..":%2%3")
            else
                return level..":"..name
            end
        else
            return name
        end
    end
end

SLASH_LFGHELP1 = "/bflfg";
SlashCmdList["LFGHELP"] = function(cmd)
    if EnableFilter then
        DEFAULT_CHAT_FRAME:AddMessage("disable filter BigFoot LFG channel message")
        EnableFilter = false
    else
        DEFAULT_CHAT_FRAME:AddMessage("enable filter BigFoot LFG channel message")
        EnableFilter = true
    end
    DEFAULT_CHAT_FRAME:AddMessage("大脚组队频道过滤器， 当前状态：" .. tostring(EnableFilter))
    DEFAULT_CHAT_FRAME:AddMessage("开/关屏蔽重复刷屏 输入/fuckspam， 当前状态：" .. tostring(EnableForbiddenRepeat))
    DEFAULT_CHAT_FRAME:AddMessage("开/关硬屏蔽模式 输入/fucktrash， 当前状态：" .. tostring(EnableForbiddenTrash))
    DEFAULT_CHAT_FRAME:AddMessage("开/关大脚白名单组队信息模式 输入/fuckbf， 当前状态：" .. tostring(EnableForbiddenBigfoot))
end

SLASH_FUCKSP1 = "/fuckspam";
SlashCmdList["FUCKSP"] = function(cmd)
    if EnableForbiddenRepeat then
        DEFAULT_CHAT_FRAME:AddMessage("disable forbidden repeat message")
        EnableForbiddenRepeat = false
    else
        DEFAULT_CHAT_FRAME:AddMessage("enable forbidden repeat message")
        EnableForbiddenRepeat = true
    end
end

SLASH_FUCKTR1 = "/fucktrash";
SlashCmdList["FUCKTR"] = function(cmd)
    if EnableForbiddenTrash then
        DEFAULT_CHAT_FRAME:AddMessage("disable forbidden trash message")
        EnableForbiddenTrash = false
    else
        DEFAULT_CHAT_FRAME:AddMessage("enable forbidden trash message")
        EnableForbiddenTrash = true
    end
end

SLASH_FUCKBF1 = "/fuckbf";
SlashCmdList["FUCKBF"] = function(cmd)
    if EnableForbiddenBigfoot then
        DEFAULT_CHAT_FRAME:AddMessage("disable fuck bigfoot channel")
        EnableForbiddenBigfoot = false
    else
        DEFAULT_CHAT_FRAME:AddMessage("enable fuck bigfoot channel")
        EnableForbiddenBigfoot = true
    end
end
