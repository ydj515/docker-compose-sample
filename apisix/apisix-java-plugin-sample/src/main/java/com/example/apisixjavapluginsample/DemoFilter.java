package com.example.apisixjavapluginsample;

import org.apache.apisix.plugin.runner.HttpRequest;
import org.apache.apisix.plugin.runner.HttpResponse;
import org.apache.apisix.plugin.runner.filter.PluginFilter;
import org.apache.apisix.plugin.runner.filter.PluginFilterChain;
import org.springframework.stereotype.Component;

import java.util.ArrayList;
import java.util.List;

@Component
public class DemoFilter implements PluginFilter {
//    private final Logger logger = LoggerFactory.getLogger(DemoFilter.class);

    @Override
    public String name() {
        return "DemoFilter";
    }

    @Override
    public void filter(HttpRequest request, HttpResponse response, PluginFilterChain chain) {
        System.out.println("filter chain start");
        request.getHeaders().forEach((k, v) -> System.out.println(k + ": " + v));

        // do something

        chain.filter(request, response);
    }

    /**
     * If you need to fetch some Nginx variables in the current plugin, you will need to declare them in this function.
     *
     * @return a list of Nginx variables that need to be called in this plugin
     */
    @Override
    public List<String> requiredVars() {
        List<String> vars = new ArrayList<>();
        vars.add("remote_addr");
        vars.add("server_port");
        return vars;
    }

    /**
     * If you need to fetch request body in the current plugin, you will need to return true in this function.
     */
    @Override
    public Boolean requiredBody() {
        return true;
    }
}