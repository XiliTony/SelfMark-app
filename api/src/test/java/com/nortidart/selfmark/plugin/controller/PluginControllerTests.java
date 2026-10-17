package com.nortidart.selfmark.plugin.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.nortidart.selfmark.auth.mapper.UserMapper;
import com.nortidart.selfmark.auth.security.JwtUtil;
import com.nortidart.selfmark.auth.service.TokenBlacklistService;
import com.nortidart.selfmark.common.context.UserContext;
import com.nortidart.selfmark.plugin.dto.MarketPluginResponse;
import com.nortidart.selfmark.plugin.mapper.PluginMapper;
import com.nortidart.selfmark.plugin.mapper.UserPluginMapper;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest(properties = {
        "spring.autoconfigure.exclude=com.baomidou.mybatisplus.autoconfigure.MybatisPlusAutoConfiguration,"
                + "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
                + "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration"
})
@AutoConfigureMockMvc
class PluginControllerTests {
    @MockitoBean UserMapper userMapper;
    @MockitoBean PluginMapper pluginMapper;
    @MockitoBean UserPluginMapper userPluginMapper;
    @MockitoBean TokenBlacklistService tokenBlacklistService;
    @Autowired MockMvc mockMvc;
    @Autowired JwtUtil jwtUtil;
    @Autowired ObjectMapper objectMapper;

    @Test
    void uninstalledFieldsAreExplicitNullAndIdentityComesFromToken() throws Exception {
        when(pluginMapper.selectMarket(42L)).thenReturn(List.of(
                plugin(1L, "quadrant-board", "画板", 1), plugin(2L, "pomodoro", "番茄钟", 2)));
        String body = mockMvc.perform(get("/api/plugins").param("userId", "999")
                        .header("Authorization", "Bearer " + jwtUtil.issue(42L, "USER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.msg").value("success"))
                .andExpect(jsonPath("$.data.length()").value(2))
                .andExpect(jsonPath("$.data[0].code").value("quadrant-board"))
                .andExpect(jsonPath("$.data[0].installed").value(false))
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
        var first = objectMapper.readTree(body).at("/data/0");
        for (String field : List.of("description", "userPluginId", "enabled", "config")) {
            assertThat(first.has(field)).isTrue();
            assertThat(first.get(field).isNull()).isTrue();
        }
        assertThat(first.has("userId")).isFalse();
        verify(pluginMapper).selectMarket(42L);
        assertThatThrownBy(UserContext::getRequired).isInstanceOf(IllegalStateException.class);
    }

    @Test
    void disabledInstallationStillHasObjectConfiguration() throws Exception {
        var installed = plugin(1L, "quadrant-board", "画板", 1);
        installed.setUserPluginId(9L);
        installed.setEnabled(false);
        installed.setConfig(objectMapper.readTree("{\"foo\":1,\"label\":\"中文\"}"));
        when(pluginMapper.selectMarket(42L)).thenReturn(List.of(installed));
        mockMvc.perform(get("/api/plugins")
                        .header("Authorization", "Bearer " + jwtUtil.issue(42L, "USER")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data[0].installed").value(true))
                .andExpect(jsonPath("$.data[0].userPluginId").value(9))
                .andExpect(jsonPath("$.data[0].enabled").value(false))
                .andExpect(jsonPath("$.data[0].config.foo").value(1));
    }

    @Test
    void emptyMarketReturnsAnArray() throws Exception {
        when(pluginMapper.selectMarket(42L)).thenReturn(List.of());
        mockMvc.perform(get("/api/plugins")
                        .header("Authorization", "Bearer " + jwtUtil.issue(42L, "USER")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.data").isEmpty());
    }

    @Test
    void missingInvalidAndLoggedOutTokensCannotReadMarket() throws Exception {
        mockMvc.perform(get("/api/plugins")).andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/plugins").header("Authorization", "Bearer invalid"))
                .andExpect(status().isUnauthorized());
        String token = jwtUtil.issue(42L, "USER");
        when(tokenBlacklistService.isBlacklisted(jwtUtil.parse(token).getId())).thenReturn(true);
        mockMvc.perform(get("/api/plugins").header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value(401));
        verifyNoInteractions(pluginMapper);
    }

    private MarketPluginResponse plugin(Long id, String code, String name, int sort) {
        var result = new MarketPluginResponse();
        result.setId(id);
        result.setCode(code);
        result.setName(name);
        result.setSort(sort);
        return result;
    }

    @Test
    void unauthenticatedInstallationDoesNotReachPersistence() throws Exception {
        mockMvc.perform(post("/api/plugins/quadrant-board/install"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401))
                .andExpect(jsonPath("$.msg").value("未登录"));
        verifyNoInteractions(pluginMapper, userPluginMapper);
    }
}
