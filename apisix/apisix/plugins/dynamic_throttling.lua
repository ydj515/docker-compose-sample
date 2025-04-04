local core = require("apisix.core")
local http = require("resty.http")

-- Plugin metadata
local plugin_name = "dynamic_throttling"
local schema = {
    type = "object",
    properties = {
        prometheus_url = {type = "string"}, -- Prometheus API URL
        latencyQuery = {type = "string"},         -- Prometheus query to fetch latency
        rpsQuery = {type = "string"},         -- Prometheus query to fetch RPS
        route_id = {type = "string"},      -- Specific route ID for filtering
        default_rate = {type = "integer", minimum = 1}, -- Default rate limit
        max_rate = {type = "integer", minimum = 1},    -- Maximum rate limit
        min_rate = {type = "integer", minimum = 1},    -- Minimum rate limit
        threshold_latency = {type = "integer", minimum = 1}, -- Threshold latency in ms
        admin_api_url = {type = "string"}, -- APISIX Admin API URL
        admin_api_token = {type = "string"}, -- APISIX Admin API Token
        check_probability = {type = "number", minimum = 0, maximum = 1, default = 0.1},  -- 확률 추가
        sensitivity = {type = "number", minimum = 0, maximum = 1, default = 0.2}  -- 민감도 추가
    },
    required = {"prometheus_url", "latencyQuery", "rpsQuery", "rpsDemoniator",  "route_id", "default_rate", "max_rate", "min_rate", "threshold_latency", "admin_api_url", "admin_api_token", "check_probability", "sensitivity"}
}

local _M = {
    version = 0.2,
    priority = 1000,
    name = plugin_name,
    schema = schema
}

-- Initialization function
function _M.init()
    core.log.info("Initializing dynamic_throttling plugin")
end

function _M.fetch_latency(conf)
    local httpc = http.new()

    -- Fetch Prometheus data for specific route
    local query = conf.latencyQuery:gsub("<route_id>", conf.route_id)
    local res, err = httpc:request_uri(conf.prometheus_url, {
        method = "GET",
        query = {query = query}
    })

    if not res then
        core.log.error("Failed to fetch Prometheus data: ", err)
        return
    end

    local result = core.json.decode(res.body)
    if not result or not result.data or not result.data.result then
        core.log.error("Invalid Prometheus response: ", res.body)
        return
    end

    -- Extract latency from Prometheus result for type="upstream"
    local latency = nil
    for _, metric in ipairs(result.data.result) do
        if metric.metric and metric.metric.type == "upstream" then
            latency = tonumber(metric.value[2])
            break
        end
    end

    return latency
end

-- 
function _M.fetch_rps(conf)
    local httpc = http.new()

    -- Fetch Prometheus data for specific route
    local query = conf.rpsQuery:gsub("<route_id>", conf.route_id)
    local res, err = httpc:request_uri(conf.prometheus_url, {
        method = "GET",
        query = {query = query}
    })

    if not res then
        core.log.error("Failed to fetch Prometheus data: ", err)
        return
    end

    local result = core.json.decode(res.body)
    if not result or not result.data or not result.data.result or #result.data.result == 0 then
        core.log.error("Invalid Prometheus response: ", res.body)
        return
    end

    -- result[1].value가 제대로 존재하는지 확인
    local value_arr = result.data.result[1].value
    if not value_arr or #value_arr < 2 then
        local err_msg = "Missing 'value' field in Prometheus response: " .. res.body
        core.log.error(err_msg)
        return nil, err_msg
    end

    -- value 배열의 [2] 번째가 실제 값
    local rps_val = tonumber(value_arr[2])
    if not rps_val then
        local err_msg = "RPS value is not a number: " .. (value_arr[2] or "nil")
        core.log.error(err_msg)
        return nil, err_msg
    end

    -- rps 계산 (디폴트 분모가 없으면 1로 처리)
    local rps = math.floor(rps_val / (conf.rpsDemoniator or 1))
    return rps
end

-- Function to update limit-req plugin settings via Admin API
function _M.update_limit_req(conf, new_rate)
    local httpc = http.new()
    local update_payload = core.json.encode({
        plugins = {
            ["limit-req"] = {
                rate = math.floor(new_rate),
                burst = math.floor(new_rate * 0.1),
                rejected_code = 429
            }
        }
    })

    local res, err = httpc:request_uri(conf.admin_api_url .. "/apisix/admin/routes/" .. conf.route_id, {
        method = "PATCH",
        body = update_payload,
        headers = {
            ["Content-Type"] = "application/json",
            ["X-API-KEY"] = conf.admin_api_token
        }
    })

    if not res then
        core.log.error("Failed to update limit-req via Admin API: ", err)
    else
        core.log.debug("Successfully updated limit-req: ", res.status)
    end
end

function _M.fetch_current_rate_limit(conf)
    local httpc = http.new()
    local res, err = httpc:request_uri(conf.admin_api_url .. "/apisix/admin/routes/" .. conf.route_id, {
        method = "GET",
        headers = {
            ["X-API-KEY"] = conf.admin_api_token
        }
    })

    if not res then
        core.log.error("Failed to fetch current rate limit: ", err)
        return nil
    end

    local result = core.json.decode(res.body)
    if not result or not result.value or not result.value.plugins or not result.value.plugins["limit-req"] then
        core.log.error("No limit-req plugin found in response: ", res.body)
        return nil
    end

    return tonumber(result.value.plugins["limit-req"].rate)
end

function _M.calculate_new_rate(conf, current_rps, latency)
    local current_rate = _M.fetch_current_rate_limit(conf) or conf.default_rate  -- 현재 rate-limit 값
    core.log.debug("Current Rate Limit: ", current_rate)
    -- Latency가 높다면 즉시 감소
    if latency > conf.threshold_latency then
        return math.max(conf.min_rate, current_rate * (1 - conf.sensitivity))
    end

    -- 여기서부턴 latency가 threshold 이하인 경우
    
    -- 지연이 없는데, 현 RPS가 현재 rate보다 높다면 > late limit 증가
    if current_rps > current_rate then
        local new_rate = current_rate * (1 + conf.sensitivity)  -- 증가 비율 적용
        return math.min(conf.max_rate, new_rate)  -- max_rate 제한 적용
    end

    -- 지연이 없는데, 지금 rps가 default_rate보다 낮다면 > late limit 증가
    if current_rps < conf.default_rate then
        local new_rate = current_rate * (1 + conf.sensitivity)  
        return math.min(conf.default_rate, new_rate)  -- default_rate 제한 적용
    end

    -- 기본적으로 현재 rate 유지
    return current_rate
end

-- Plugin's main logic
function _M.access(conf, ctx)
     -- 확률적으로 Prometheus 호출 여부 결정
    if math.random() > conf.check_probability then
        core.log.debug("Skipping Prometheus check due to probability threshold")
        return
    end

    -- Fetch latency data from Prometheus
    local latency = _M.fetch_latency(conf)

    -- 에러 핸들링: latency 값이 없을 경우
    if not latency then
        core.log.error("No upstream latency data found for route ", conf.route_id)
        latency = conf.threshold_latency  -- 기본 임계값을 사용하거나
    end
    core.log.info("Latency for route ", conf.route_id, ": ", latency, " ms")

    -- 현재 설정되어 있는 rate limit 확인
    local current_rps = _M.fetch_rps(conf)
    core.log.debug("Current rps: ", current_rps)
    if not current_rps then
        core.log.error("Failed to fetch current RPS value")
        return
    end

    local new_rate = _M.calculate_new_rate(conf, current_rps, latency)

    -- 최종적으로 min/max 범위 제한 적용
    new_rate = math.max(conf.min_rate, math.min(conf.max_rate, new_rate))
    core.log.debug("Final Rate Limit: ", new_rate)
    _M.update_limit_req(conf, new_rate)
end

return _M
