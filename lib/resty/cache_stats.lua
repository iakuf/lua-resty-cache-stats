local _M = {}

local cjson = require "cjson"
local cache_stats = ngx.shared.cache_stats
-- 初始化或更新窗口数据
local function update_window(window_key, value, window_size)
    local data = cache_stats:get(window_key)
    if not data then
        data = {}
    else
        data = cjson.decode(data)
    end
    table.insert(data, value)
    if #data > window_size then
        table.remove(data, 1)
    end
    cache_stats:set(window_key, cjson.encode(data))
end

local function calculate_stats(window_data)
    local sum = 0
    for _, v in ipairs(window_data) do
        sum = sum + v
    end
    return sum
end

local function update_rates()
    -- 声明周期列表和对应缓存键名
    local periods = { { "1min", 1 }, { "5min", 5 }, { "60min", 60 } }
    local stat_keys = { "hits", "misses", "hit_bytes", "missed_bytes" }

    -- 一次性获取所有统计数据
    local stats = {}
    for _, key in ipairs(stat_keys) do
        stats[key] = tonumber(cache_stats:get(key)) or 0
    end

    -- 更新各个时间窗口的数据
    for _, period_info in ipairs(periods) do
        local period, interval = unpack(period_info)
        for _, stat_key in ipairs(stat_keys) do
            update_window(period .. "_" .. stat_key .. "_window", stats[stat_key], interval)
        end
    end

    -- 计算并更新统计结果
    for _, period_info in ipairs(periods) do
        local period = period_info[1]
        local hits, misses, hit_bytes, missed_bytes = 0, 0, 0, 0
        for _, stat_key in ipairs(stat_keys) do
            local window_data = cache_stats:get(period .. "_" .. stat_key .. "_window") or "[]"
            local sum = calculate_stats(cjson.decode(window_data))
            stats[period .. "_" .. stat_key] = sum
            if stat_key == "hits" or stat_key == "misses" then
                hits = hits + (stat_key == "hits" and sum or 0)
                misses = misses + (stat_key == "misses" and sum or 0)
            elseif stat_key == "hit_bytes" or stat_key == "missed_bytes" then
                hit_bytes = hit_bytes + (stat_key == "hit_bytes" and sum or 0)
                missed_bytes = missed_bytes + (stat_key == "missed_bytes" and sum or 0)
            end
        end
    
        local total_requests = hits + misses
        local total_bytes = hit_bytes + missed_bytes
    
        local request_hit_rate = total_requests > 0 and string.format("%.2f", (hits / total_requests) * 100) or 0
        local traffic_hit_rate = total_bytes > 0 and string.format("%.2f", (hit_bytes / total_bytes) * 100) or 0
    
        -- 更新命中率和流量率
        cache_stats:set(period .. "_request_hit_rate", request_hit_rate)
        cache_stats:set(period .. "_traffic_hit_rate", traffic_hit_rate)

        -- 计几个总数
        cache_stats:set(period .. "_hits", hits)
        cache_stats:set(period .. "_misses", misses)
        cache_stats:set(period .. "_hit_bytes", hit_bytes)
        cache_stats:set(period .. "_missed_bytes", missed_bytes)

        cache_stats:set(period .. "_requests", total_requests)
        cache_stats:set(period .. "_bytes", total_bytes)
    end


    -- 重置当前统计
    for _, key in ipairs(stat_keys) do
        cache_stats:set(key, 0)
    end
end

function _M.init() 
    if ngx.worker.id() == 0 then
         local function handler(premature)
            if premature then
                ngx.log(ngx.ERR, "Premature timer")
                return false  -- 停止进一步的定时任务
            end
            update_rates()
            ngx.log(ngx.INFO, "Timer executed by worker 0")
            -- 不需要再手动设置定时器，`ngx.timer.every` 将自动继续
        end
    
        -- 设置定时器，每5秒执行一次 `handler`
        local ok, err = ngx.timer.every(60, handler)
        if not ok then
            ngx.log(ngx.ERR, "Failed to create repeated timer: ", err)
        end
    else
        ngx.log(ngx.INFO, "This is not worker 0, not scheduling the timer")
    end
end

function _M.track()
    local cache_status = ngx.var.upstream_cache_status or 'NONE'
    
    local bytes = tonumber(ngx.var.body_bytes_sent) or 0
    --ngx.log(ngx.INFO, "Entering log_by_lua_block, Bytes sent: ", bytes)
    
    if cache_status == "HIT" then
        cache_stats:incr("hits", 1, 0)
        cache_stats:incr("hit_bytes", bytes, 0)
    elseif cache_status == "MISS" or cache_status == "EXPIRED" then
        cache_stats:incr("misses", 1, 0)
        cache_stats:incr("missed_bytes", bytes, 0)
    end
end


function _M.get_stats()
    ngx.say("Cache Stats Overview:")
    
    -- 输出请求命中率
    ngx.say("\nRequest Hit Rates:")
    ngx.say("1 Minute Request Hit Rate: ", cache_stats:get("1min_request_hit_rate") or "N/A")
    ngx.say("5 Minutes Request Hit Rate: ", cache_stats:get("5min_request_hit_rate") or "N/A")
    ngx.say("60 Minutes Request Hit Rate: ", cache_stats:get("60min_request_hit_rate") or "N/A")
    
    -- 输出流量命中率
    ngx.say("\nTraffic Hit Rates:")
    ngx.say("1 Minute Traffic Hit Rate: ", cache_stats:get("1min_traffic_hit_rate") or "N/A")
    ngx.say("5 Minutes Traffic Hit Rate: ", cache_stats:get("5min_traffic_hit_rate") or "N/A")
    ngx.say("60 Minutes Traffic Hit Rate: ", cache_stats:get("60min_traffic_hit_rate") or "N/A")
    
    -- 输出关键统计指标
    local keys = {"hits", "misses", "requests", "hit_bytes", "missed_bytes", "bytes"}
    for _, period in ipairs({"1min", "5min", "60min"}) do
        ngx.say("\n");
        ngx.say("Detailed Stats".. "(" .. period..  ")" ..":")
        for _, key in ipairs(keys) do
            local full_key = period .. "_" .. key
            ngx.say(full_key .. ": ", cache_stats:get(full_key) or "N/A")
        end
    end
end
function _M.clear() 
  local keys = cache_stats:get_keys(0)  -- 获取所有键
  for _, key in ipairs(keys) do
      cache_stats:delete(key)  -- 删除每个键
  end
  ngx.say("All cache entries have been deleted.")
end

return _M
