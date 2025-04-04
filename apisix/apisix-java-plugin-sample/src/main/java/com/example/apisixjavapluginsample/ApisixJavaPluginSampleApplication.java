package com.example.apisixjavapluginsample;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication(scanBasePackages = {"com.example.apisixjavapluginsample", "org.apache.apisix.plugin.runner"})
public class ApisixJavaPluginSampleApplication {

    public static void main(String[] args) {
        SpringApplication.run(ApisixJavaPluginSampleApplication.class, args);
    }

}
