-- active_health_control.lua (Plugin-level periodic health checker with route discovery)
local core = require("apisix.core")
local http = require("resty.http")
local plugin_name = "active_health_control"

local schema = {
    type = "object",
    properties = {
        admin_api_url = {type = "string"},
        admin_api_token = {type = "string"},
        interval = {type = "integer", default = 10},
        health_check_path = {type = "string", default = "/api/health"},
        expected_status = {type = "integer", default = 200},
        rewrite_code = {type = "integer", default = 503},
        rewrite_body = {type = "string", default = '{"message": "API 점검 중입니다. 잠시 후 다시 시도해주세요."}'}
    },
    required = {"admin_api_url", "admin_api_token"}
}

local _M = {
    version = 0.1,
    priority = 1000,
    name = plugin_name,
    schema = schema
}

-- initialize plugin worker
function _M.init()
    core.log.info("[HealthCheck] worker id : ", ngx.worker.id())
    if ngx.worker.id() ~= 0 then
        core.log.info("[HealthCheck] skipping on worker ", ngx.worker.id())
        return
    end
    local plugin_conf = core.config.local_conf().plugin_attr and core.config.local_conf().plugin_attr[plugin_name]
    if not plugin_conf then
        core.log.warn("[HealthCheck] plugin config not found")
        return
    end
    local ok, err = ngx.timer.every(plugin_conf.interval or 10, _M.periodic_check)
    if not ok then
        core.log.error("[HealthCheck] failed to start timer: ", err)
    end
end

-- fetch all routes
function _M.fetch_all_routes(plugin_conf)
    local httpc = http.new()
    local res, err = httpc:request_uri(plugin_conf.admin_api_url .. "/apisix/admin/routes", {
        method = "GET",
        headers = {
            ["X-API-KEY"] = plugin_conf.admin_api_token
        }
    })

    if not res then
        core.log.error("[HealthCheck] Failed to fetch routes: ", err)
        return {}
    end

    local decoded = core.json.decode(res.body)
    return decoded.list or {}
end

-- get upstream node
function _M.get_upstream_node(route)
    if not route.value or not route.value.upstream or not route.value.upstream.nodes then
        return nil
    end
    for addr, _ in pairs(route.value.upstream.nodes) do
        local host, port = addr:match("([^:]+):?(%d*)")
        port = port ~= "" and port or "80"
        return host, port
    end
    return nil
end

-- set response-rewrite
function _M.set_response_rewrite(route_conf, route_id)
    local httpc = http.new()
    local patch_body = {
        plugins = {
            ["serverless-pre-function"] = {
                phase = "rewrite",
                functions = {
                    [[
                        return function(conf, ctx)
                            ngx.status = ]] .. (route_conf.rewrite_code or 503) .. [[
                            ngx.say("]] .. (route_conf.rewrite_body or "API 점검 중입니다. 잠시 후 다시 시도해주세요.") .. [[")
                            return ngx.exit(ngx.HTTP_OK)
                        end
                    ]]
                }
            }
        }
    }
    local res, err = httpc:request_uri(route_conf.admin_api_url .. "/apisix/admin/routes/" .. route_id, {
        method = "PATCH",
        body = core.json.encode(patch_body),
        headers = {
            ["Content-Type"] = "application/json",
            ["X-API-KEY"] = route_conf.admin_api_token
        }
    })
    if not res then
        core.log.error("[HealthCheck] Failed to set response-rewrite on route ", route_id, ": ", err)
    else
        core.log.info("[HealthCheck] Set response-rewrite on route ", route_id)
    end
end

-- remove response-rewrite
function _M.remove_response_rewrite(route_conf, route_id)
    local httpc = http.new()
    local get_res, get_err = httpc:request_uri(route_conf.admin_api_url .. "/apisix/admin/routes/" .. route_id, {
        method = "GET",
        headers = {
            ["X-API-KEY"] = route_conf.admin_api_token
        }
    })

    if not get_res or get_res.status ~= 200 then
        core.log.error("[HealthCheck] Failed to fetch route ", route_id, ": ", get_err or get_res.body)
        return
    end

    local route_data = core.json.decode(get_res.body)
    if not route_data or not route_data.value then
        core.log.error("[HealthCheck] Invalid route data for ", route_id)
        return
    end

    local route_cfg = route_data.value
    if route_cfg.plugins then
        route_cfg.plugins["serverless-pre-function"] = nil
    end
    route_cfg.create_time = nil
    route_cfg.update_time = nil
    route_cfg.id = nil

    local put_res, put_err = httpc:request_uri(route_conf.admin_api_url .. "/apisix/admin/routes/" .. route_id, {
        method = "PUT",
        body = core.json.encode(route_cfg),
        headers = {
            ["Content-Type"] = "application/json",
            ["X-API-KEY"] = route_conf.admin_api_token
        }
    })

    if not put_res or put_res.status >= 300 then
        core.log.error("[HealthCheck] Failed to update route ", route_id, ": ", put_err or put_res.body)
    else
        core.log.info("[HealthCheck] Removed response-rewrite from route ", route_id)
    end
end

-- health check logic for each route
function _M.check_route_health(route)
    local route_id = route.value.id
    local conf = route.value.plugins and route.value.plugins[plugin_name]
    if not conf or not conf.health_check_enabled then
        return
    end

    local url = conf.health_check_path
    local httpc = http.new()
    local res, err = httpc:request_uri(url, {
        method = "GET",
        ssl_verify = false,
        timeout = 3000
    })

    if not res or res.status ~= conf.expected_status then
        _M.set_response_rewrite(conf, route_id)
    else
        _M.remove_response_rewrite(conf, route_id)
    end
end

-- periodic checker
function _M.periodic_check(premature)
    if premature then return end
    local plugin_conf = core.config.local_conf().plugin_attr and core.config.local_conf().plugin_attr[plugin_name]
    if not plugin_conf then return end
    local routes = _M.fetch_all_routes(plugin_conf)
    for _, route in ipairs(routes) do
        ngx.timer.at(0, function()
            _M.check_route_health(route)
        end)
    end
end

return _M
