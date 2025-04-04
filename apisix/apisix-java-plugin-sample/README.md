# apisix-java-plugin-sample

apisix에서 `ext-plugin-pre-req`에서 사용할 수 있는 java plugin모듈입니다.

## environment

- java17
- maven3
- springboot 2.7.1
- apisix-runner-starter

## useage
apisix java plugin 사용법

### build jar
```shell
./mvnw clean package
```

### x 권한 추가
```shell
chmod +x target/executable-jar-with-library-jar-with-dependencies.jar
```

### apisix plugin 설정

- `org.apache.apisix.plugin.runner` 활성화

    ```java
    @SpringBootApplication(scanBasePackages = {"com.example.apisixjavapluginsample", "org.apache.apisix.plugin.runner"})
    public class ApisixJavaPluginSampleApplication {
        // ...
    }
    ```

- `PluginFilter` implement로 filter 생성

    ```java
    @Component
    public class DemoFilter implements PluginFilter {

        @Override
        public String name() {
            return "DemoFilter"; // apisix에 등록할 필터명과 동일해야합니다.
        }

        @Override
        public void filter(HttpRequest request, HttpResponse response, PluginFilterChain chain) {

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
            // do something
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
    ```

### apisix config

옮긴 jar 파일을 사용할수 있게 apisix에 설정합니다.

- apisix-config.yaml

    `ext-plugin-pre-req`와 `ext-plugin-post-req`를 활성화 하고 `ext-plugin`에 jar 기동 명령어를 작성합니다.
    
    ```shell
    plugins:
    - ext-plugin-pre-req
    - ext-plugin-post-req
    ...
    
    ext-plugin:
    cmd: ['java', '-jar', '-Xmx1g', '-Xms1g', '/usr/local/apisix/libs/apisix-demo-jar-with-dependencies.jar']
    ```

- route 설정

    `ext-plugin-pre-req`의 name값은 아래와 동일해야합니다.

    ```java
    @Override
    public String name() {
        return "DemoFilter";
    }
    ```

```shell
curl -i -X PUT http://127.0.0.1:9180/apisix/admin/routes/1 \
-H "X-API-KEY: {ADMIN_API_KEY}" \
-H "Content-Type: application/json" \
-d '{
  "uri": "/api/*",
  "plugins": {
    "prometheus":{},
    "active_health_control": {
      "health_check_enabled": true,
      "admin_api_url": "http://apisix1:9180",
      "admin_api_token": "{ADMIN_API_KEY}",
      "health_check_path": "http://{HEALTH_CHECK_FOR_HOST}/api/health",
      "expected_status": 200,
      "interval": 5
    },
    "limit-req":{
      "rate": 200,
      "burst": 20,
      "key": "route_id",
      "policy": "redis",
      "redis_host": "redis",
      "redis_port": 6379,
      "redis_timeout": 1000,
      "rejected_code": 429
    },
    "ext-plugin-pre-req":{
      "conf":[
        {
          "name":"DemoFilter",
          "value":""
        }
      ]
    }
  },
  "methods": ["GET", "POST"],
  "upstream": {
    "type": "roundrobin",
    "nodes": {
      "{UPSTREAM_HOST}:{UPSTREAM_PORT}": 1
    }
  }
}'
```