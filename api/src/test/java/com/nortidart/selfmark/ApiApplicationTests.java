package com.nortidart.selfmark;

import com.nortidart.selfmark.auth.mapper.UserMapper;
import com.nortidart.selfmark.plugin.mapper.PluginMapper;
import com.nortidart.selfmark.plugin.mapper.UserPluginMapper;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

@SpringBootTest(properties = {
        "spring.autoconfigure.exclude=com.baomidou.mybatisplus.autoconfigure.MybatisPlusAutoConfiguration,"
                + "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
                + "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
})
class ApiApplicationTests {

    @MockitoBean
    UserMapper userMapper;

    @MockitoBean
    PluginMapper pluginMapper;

    @MockitoBean
    UserPluginMapper userPluginMapper;

    @Test
    void contextLoads() {
    }

}
