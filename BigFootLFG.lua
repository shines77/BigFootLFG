local _, ns = ...

-- String functions
local string_find, string_sub, string_gsub, string_match, string_gmatch = string.find, string.sub, string.gsub, string.match, string.gmatch
local string_byte, string_char, string_len = string.byte, string.char, string.len

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
local MatchForbidden = {"无限","大量","长期","邮寄","托管","公会","工会","诚邀","加入","FM","附魔","十字军","冰寒","屠魔","丝绸","魔纹","符文布","硬甲皮","厚皮","宝箱","英雄","活动","血色","厄运","玛拉顿","加基森","STSM","stsm","斯坦索姆","冬泉谷","飞机","飞行","航班","直达","1G","2G","3G","4G","1Ｇ","2Ｇ","3Ｇ","4Ｇ","1金","2金","3金","4金"}
-- 出现组合屏蔽词库内的几个不同词语就进行屏蔽
local MatchCount = 2

-- 硬屏蔽的关键字列表
-- "老板","老木板"
local HardForbidden = {"装等","无限收","无线收","高价收","大量收","大米","小米","出米","支付宝","芝麻信用","飞机","带血色","老木板","{rt1}","{rt2}","{rt3}","{rt4}","{rt5}","{rt6}","{rt7}","{rt8}","RO点"}

-- 大脚白名单模式显示的过滤词
local Show = {
    -- "治疗","奶","N","牧师","MS","DPS","拉怪","猎人","LR","法师","FS","黑石深渊","黑石"
    "STSM","stsm","斯坦索姆"
}

-- 大脚白名单模式过滤后需要去屏蔽的词
local ForbiddenOnShow = {
    --"公会","工会",
    "怒焰","NY","ny",
    "哀嚎","AH","ah",
    "死亡矿井","死矿","SK","sk","SW","sw",
    "监狱","JY","jy",
    "黑暗深渊","SY","sy",
    "影牙","YY","yy",
    "剃刀","沼泽","TDZZ","tdzz",
    "诺莫瑞根","瑞根","矮人本",
    "血色","XS","墓地","MD","图书馆","武器库","军械库","教堂",
    "高地","TDGD","tdgd",
    "奥达曼","ADM","adm",
    --"祖尔","祖尔法拉克","ZUL","zul",
    -- "黑石","黑石深渊","深渊","HS","hs",
    --"AA",
}

ns.ClassColors = {
    ["DEATHKNIGHT"] = {r = 0.77, g = 0.12, b = 0.23},
    ["DRUID"] = {r = 1, g = 0.49, b = 0.04},
    ["HUNTER"] = {r = 0.58, g = 0.86, b = 0.49},
    ["MAGE"] = {r = 0, g = 0.76, b = 1},
    ["PALADIN"] = {r = 1, g = 0.22, b = 0.52},
    ["PRIEST"] = {r = 0.8, g = 0.87, b = .9},
    ["ROGUE"] = {r = 1, g = 0.91, b = 0.2},
    ["SHAMAN"] = {r = 0, g = 0.6, b = 0.6},
    ["WARLOCK"] = {r = 0.6, g = 0.47, b = 0.85},
    ["WARRIOR"] = {r = 0.9, g = 0.65, b = 0.45},
}

local function utf8ToChars_old(input)
    local chars = {}
    local len = string_len(input)
    local index = 1
    local utf8_arr = {0, 0xc0, 0xe0, 0xf0, 0xf8, 0xfc}
    while index <= len do
        local c = string_byte(input, index)
        local utf8_len = 1
        if c < 0xc0 then
            utf8_len = 1
        elseif c < 0xe0 then
            utf8_len = 2
        elseif c < 0xf0 then
            utf8_len = 3
        elseif c < 0xf8 then
            utf8_len = 4
        elseif c < 0xfc then
            utf8_len = 5
        end
        local chinese = string_sub(input, index, index + utf8_len - 1)
        index = index + utf8_len
        table.insert(chars, chinese)
    end

    return chars
end

--
-- See: https://blog.csdn.net/lingyun5905/article/details/86540171
--
--[[
    UTF8的编码规则：
    1. 字符的第一个字节范围： 0x00—0x7F(0-127), 或者 0xC2—0xF4(194-244); UTF8 是兼容 ascii 的，所以 0~127 就和 ascii 完全一致;
    2. 0xC0, 0xC1,0xF5—0xFF(192, 193 和 245-255)不会出现在UTF8编码中;
    3. 0x80—0xBF(128-191)只会出现在第二个及随后的编码中(针对多字节编码，如汉字).
--]]
--
local function utf8ToChars(input)
    local chars = {}
    for chinese in string_gmatch(input, "[%z\1-\127\194-\244][\128-\191]*") do
        table.insert(chars, chinese)
    end
    return chars
end

--
-- About string.find(), string.gsub() in Lua.
--
-- See: https://www.cnblogs.com/meamin9/p/4502461.html
-- See: https://www.cnblogs.com/zrtqsk/p/4372889.html
-- See: http://cloudwu.github.io/lua53doc/manual.html#6.4
--

local function utf8ToChars_match(input)
    local chars = {}
    local len = string_len(input)
    local index = 1
    while index <= len do
        local chinese = string_match(input, "[%z\1-\127\194-\244][\128-\191]", index)
        if chinese ~= nil then
            local utf8_len = string_len(chinese)
            index = index + utf8_len
            table.insert(chars, chinese)
        else
            index = index + 1
        end
    end
    return chars
end

local function utf8ToChars_find(input)
    local chars = {}
    local len = string_len(input)
    local index = 1
    while index <= len do
        local first, last = string_find(input, "[%z\1-\127\194-\244][\128-\191]", index)
        if first ~= nil then
            local utf8_len = last - first + 1
            local chinese = string_sub(input, first, utf8_len)
            index = last + 1
            table.insert(chars, chinese)
        else
            index = index + 1
        end
    end
    return chars
end

--
-- About utf8.codes(s) in Lua 5.3
--
-- See: http://cloudwu.github.io/lua53doc/manual.html#6.4
--
local function utf8ToChars_lua53(input)
    local chars = {}
    for offset, chinese in utf8.codes(input) do
        table.insert(chars, chinese)
    end
    return chars
end

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

local function mergeTable(...)
    local tabs = {...}
    if not tabs then
        return {}
    end

    local origin = tabs[1]
    for i = 2, #tabs do
        if origin then
            if tabs[i] then
                for k, v in pairs(tabs[i]) do
                    table.insert(origin, v)
                end
            end
        else
            origin = tabs[i]
        end
    end
    return origin
end

local function removeDuplicates(str)
    local chars = utf8ToChars(str)
    local buffChars = {
        old = {},
        new = {},
    }
    
    local index = 1
    
    for i = 1, #chars do
        table.insert(buffChars.new, chars[i])
        
        if (not buffChars.old[index]) or (chars[i] ~= buffChars.old[index]) then
            mergeTable(buffChars.old, buffChars.new)
            buffChars.new = {}
        else
            index = index + 1

            if (index > 2) and (index > #buffChars.old) then
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

local function ContainsKeyword(text, keyword)
    local start = string_find(text, keyword, 1, true)
    if start ~= nil and start > 0 then
        return true
    else
        return false
    end    
end

local function ContainsKeywords(text, keywords)
    for _, keyword in ipairs(keywords) do
        local start = string_find(text, keyword, 1, true)
        if start ~= nil and start > 0 then
            return true
        end
    end
    return false
end

local function ContainsKeywordsCount(text, keywords)
    local count = 0
    for _, keyword in ipairs(keywords) do
        local start = string_find(text, keyword, 1, true)
        if start ~= nil and start > 0 then
            count = count + 1
        end
    end
    return count
end

local function CheckMatchForbidden(text)
    local match = ContainsKeywordsCount(text, MatchForbidden)
    --print("CheckMatchForbidden() = "..tostring(match))
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
    if (GetTime() - anti_spam.lastcheck) < UpdateInterval then return end
    for _, channel in pairs(last30Seconds) do
        for name, status in pairs(channel) do
            if (GetTime() - status.lastTime) > ContentRepeatInterval then
                channel[name] = nil
            end
        end
    end
    anti_spam.lastcheck = GetTime()
end

anti_spam:SetScript("OnUpdate", last30Seconds_OnUpdate)

local function removeServerDash(name)
    local dash = name:find("-")
    if dash then
        return name:sub(1, dash - 1)
    end
    return name
end

local lastLineId = 0
local lastBlockState = false
local lastFilteredMsg = ""

-- zone channel id : Zone ID used for generic system channels (1 for General, 2 for Trade, 22 for LocalDefense, 23 for WorldDefense and 26 for LFG). 
-- Not used for custom channels or if you joined an Out-Of-Zone channel ex: "General - Stormwind City"
function ChatChannelFilter(self, event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelId, channelIndex, channelBaseName, unused, lineId, guid, bnSenderId)

    if EnableFilter then
        if UnitIsUnit(playerName2, "player") then
            return false
        end

        --local nameNoDash = removeServerDash(playerName)
        --text = removeDuplicates(text)
        --print("Duplicates : [" .. nameNoDash .. "]： ".. text)

        for _, symbol in ipairs(Symbols) do
            text, a = string_gsub(text, symbol, "")
        end
        
        -- 硬屏蔽
        local isHardForbidden = ContainsKeywords(text, HardForbidden)
        if isHardForbidden then
            return true
        end
        
        -- 多词语
        local isMatchForbidden = CheckMatchForbidden(text)
        if isMatchForbidden then
            return true
        end

        -- 大脚白名单模式
        --if EnableForbiddenBigfoot and (channelBaseName == "大脚世界频道" or channelBaseName == "大脚世界频道2" or channelBaseName == "世界频道" or channelBaseName == "大脚世界频道3"or channelBaseName == "世界频道2" or channelBaseName == "大脚世界频道4") then
            local inWhiteList = ContainsKeywords(text, Show)
            if inWhiteList then
                return false
            else
                local isForbidden = ContainsKeywords(text, ForbiddenOnShow)
                if isForbidden then
                    return true
                end
            end
        --end

        text = removeDuplicates(text)
        
        -- 防刷屏
        local nameNoDash = removeServerDash(playerName)
        if nameNoDash ~= UnitName("player") and EnableForbiddenRepeat then
            t = GetTime()

            if not last30Seconds[self.name] then
                last30Seconds[self.name] = {}
            end
            -- last30Seconds[self.name] = last30Seconds[self.name] or {}
            
            local playerStatus = last30Seconds[self.name][nameNoDash]
            if playerStatus then
                if (t - playerStatus.lastTime) < ChatInterval then
                    -- print("dect spam : [" .. nameNoDash .. "]： ".. text)
                    return true
                end
                
                if (text == playerStatus.content) and ((t - playerStatus.lastTime) < ContentRepeatInterval) then
                    -- print("dect repeat : [" .. nameNoDash .. "]： ".. text)
                    return true
                end
            end

            last30Seconds[self.name][nameNoDash] = { lastTime = t, content = text }
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
        if lastBlockState then
            if (self == DEFAULT_CHAT_FRAME) then
                -- DEFAULT_CHAT_FRAME:AddMessage("\124cffffc0c0[" .. tostring(channelIndex) .. "." .. channelBaseName .. "] [\124r\124cffffdd00**" .. playerName2 .. "**\124r\124cffffc0c0]： " .. text .."\124r")
            end
            -- text = "消息已屏蔽"
            --return true, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelId, channelIndex, channelBaseName, unused, lineId, guid, bnSenderId
            return true
        else
            return lastBlockState
        end
    else
        lastLineId = lineId
        local blockState = ChatChannelFilter(self, event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelId, channelIndex, channelBaseName, unused, lineId, guid, bnSenderId)
        lastBlockState = blockState
        if blockState then
            if (self == DEFAULT_CHAT_FRAME) then
                -- DEFAULT_CHAT_FRAME:AddMessage("\124cffffc0c0[" .. tostring(channelIndex) .. "." .. channelBaseName .. "] [\124r\124cffffdd00*" .. playerName2 .. "*\124r\124cffffc0c0]： " .. text .."\124r")
            end
            -- text = "消息已屏蔽"
            --return true, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelId, channelIndex, channelBaseName, unused, lineId, guid, bnSenderId
            return true
        else
            return blockState
        end
    end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", BigFootLFG_Filter)
--ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", BigFootLFG_Filter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", BigFootLFG_Filter)
--ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", BigFootLFG_Filter)

AddLevelBeforeName = false

-----------------------------------------------------------------------
-- Add Level To Name
-----------------------------------------------------------------------
if AddLevelBeforeName then
    local Orgi_GetColoredName = GetColoredName
    local ChatTypeInfo = {
        ["CHANNEL"] = { colorNameByClass = true },
        ["WHISPER"] = { colorNameByClass = true },
        ["YELL"]    = { colorNameByClass = true },
        ["SAY"]     = { colorNameByClass = true },
    }

    function _GetColoredName(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12)
        --print("arg1 = "..arg1..", arg2 = "..arg2..", arg3 = "..arg3..", arg4 = "..tostring(arg4)..", arg5 = "..tostring(arg5))
        --print("arg6 = "..tostring(arg6)..", arg7 = "..tostring(arg7)..", arg8 = "..tostring(arg8)..", arg9 = "..tostring(arg9)..", arg10 = "..tostring(arg10))
        --print("arg11 = ".. tostring(arg11)..", arg12 = "..tostring(arg12))
        local chatType = string_sub(event, 10);
        --print("event = "..event..", chatType = ".. chatType)
        local fullName = arg2
        --print("fullName = ".. fullName..", level = "..tostring(level))
        if not string_find(fullName, "-", 1, true) then
            fullName = fullName.."-"..GetRealmName()
        end

        local name = Orgi_GetColoredName(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12)
        local info = ChatTypeInfo[chatType];
        if info and info.colorNameByClass and arg12 ~= "" then
            local level = UnitLevel(fullName)
            if level ~= nil and level > 0 then
                if string_find(name, "\124c", 1, true) ~= nil then
                    return name:gsub("(\124cff%x%x%x%x%x%x)(.-)(\124r)", "%1"..level..":%2%3")
                else
                    return level..":"..name
                end
            else
                return name
            end
        else
            return name
        end
    end
end

function GetColoredName_save(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12)
    local chatType = string_sub(event, 10);
    if string_sub(chatType, 1, 7) == "WHISPER" then
        chatType = "WHISPER";
    end
    if string_sub(chatType, 1, 7) == "CHANNEL" then
        chatType = "CHANNEL"..arg8;
    end
    local info = ChatTypeInfo[chatType];
    
    if info and info.colorNameByClass and arg12 ~= "" then
        local localizedClass, englishClass, localizedRace, englishRace, sex, name, realm = GetPlayerInfoByGUID(arg12);
        
        if englishClass then
            local classColorTable = ns.ClassColors[englishClass];
            if not classColorTable then
                return arg2;
            end
            return string.format("\124cff%.2x%.2x%.2x", classColorTable.r*255, classColorTable.g*255, classColorTable.b*255)..arg2.."\124r";
        end
    end
    
    return arg2;
end

--
-- See: http://nga.178.com/read.php?&tid=5046412&pid=86773175&to=1
-- See: https://www.wowinterface.com/forums/showthread.php?t=36850&__cf_chl_captcha_tk__=5a58aae389353194037de012cb793d84bdc2de9f-1575607113-0-ATnNC3n-m65mogkH0F3nCYSZlj_XIzcnVe0NS3_QdCDZ24byDw9nEj6gVJqqydvUjs4YG5DyIwQK_Hs8cdwq2H19jXkQiasc2VqiMMtldTbn72o354LOkenXCh5uYSeHbJgU8tLgCY8oXR1Kb0e1Cb2-scnJ_LhSJrAr1rNaVvviMaHvua8e8kbkuvh0wD4wac5oMjNGZ0GBp4YJFcTsYasSMyRiSTF8pb2BlaDvoc0q_ZmkXcHqobchO-O2xEoFuiX2HKCtHFqxPS2Ctg2wxoxzsKBu-MjAzlsmm8wkcKqPWag1JV4V5FDdlUxcZqlpGhZ83_lNBdJ5_uwd24gVjCM
--
local AddMessage_hooks = {}

local function ChatFrame_AddMessage(frame, channelName, ...)
    local start = string.find(channelName, "大脚世界频道", 1, true)
    if (start == nil) or (channelName == "大脚世界频道") then
        return AddMessage_hooks[frame](frame, channelName, ...)
    else
        return AddMessage_hooks[frame](frame, channelName:gsub("|h%[(%d+)%. 大脚世界频道(%d+)]|h", "|h%[%1%.世%]|h"), ...)
    end
end

for i = 1, NUM_CHAT_WINDOWS do
    -- 跳过 "战斗纪录" 窗口
    if i ~= 2 then
        local frame = _G["ChatFrame"..i]
        AddMessage_hooks[frame] = frame.AddMessage
        frame.AddMessage = ChatFrame_AddMessage
    end
end

AddMessage_hooks.FCF_OpenTemporaryWindow = FCF_OpenTemporaryWindow

function FCF_OpenTemporaryWindow(...)
    local frame = AddMessage_hooks.FCF_OpenTemporaryWindow(...)
    AddMessage_hooks[frame] = frame.AddMessage
    frame.AddMessage = ChatFrame_AddMessage
    return frame
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
