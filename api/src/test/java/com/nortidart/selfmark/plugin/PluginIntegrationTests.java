package com.nortidart.selfmark.plugin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.nortidart.selfmark.ApiApplication;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.CyclicBarrier;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

/** End-to-end acceptance tests for the complete plugin lifecycle. */
@SpringBootTest(properties = {
        "spring.profiles.active=prod",
        "spring.flyway.locations=classpath:db/migration",
        "selfmark.jwt.secret=selfmark-plugin-integration-secret-at-least-32-characters",
        "management.health.defaults.enabled=false"
})
@AutoConfigureMockMvc
@Testcontainers(disabledWithoutDocker = true)
class PluginIntegrationTests {
    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4")
            .withDatabaseName("selfmark").withUsername("selfmark").withPassword("selfmark")
            .withUrlParam("useAffectedRows", "true");

    @Container
    static final GenericContainer<?> REDIS = new GenericContainer<>("redis:7.4-alpine")
            .withExposedPorts(6379);

    @DynamicPropertySource
    static void configure(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
        registry.add("spring.data.redis.host", REDIS::getHost);
        registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
    }

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired JdbcTemplate jdbc;
    private final List<Long> users = new ArrayList<>();

    @AfterEach
    void cleanOwnUsers() {
        for (Long userId : users) {
            jdbc.update("DELETE FROM user_plugin WHERE user_id = ?", userId);
            jdbc.update("DELETE FROM user WHERE id = ?", userId);
        }
    }

    @Test
    void boardLifecycleRunsFromRegistrationThroughReinstall() throws Exception {
        var user = registerAndLogin("13800808001");
        JsonNode initialMarket = market(user.token());
        assertThat(initialMarket).hasSize(2);
        assertThat(initialMarket.get(0).get("code").asText()).isEqualTo("quadrant-board");
        assertThat(initialMarket.get(1).get("code").asText()).isEqualTo("pomodoro");
        assertUninstalled(initialMarket, "quadrant-board");
        assertUninstalled(initialMarket, "pomodoro");
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_plugin WHERE user_id=?", Integer.class, user.id()))
                .isZero();

        JsonNode installed = install(user.token(), "quadrant-board");
        long oldId = installed.at("/data/id").asLong();
        assertThat(installed.at("/data/config")).isEqualTo(boardDefaults());
        assertThat(installed.at("/data/enabled").asBoolean()).isTrue();
        assertStored(user.id(), oldId, boardDefaults(), true);

        ObjectNode switched = boardDefaults();
        ((ObjectNode) switched.get("quadrant")).put("xAxisLabel", "截止时间");
        ((ObjectNode) switched.at("/quadrant/regions/0")).put("name", "马上办");
        ((ObjectNode) switched.at("/pyramid/regions/0")).put("name", "年度目标");
        response(mockMvc.perform(put("/api/user-plugins/{id}/config", oldId)
                        .header("Authorization", bearer(user.token())).contentType("application/json")
                        .content(switched.toString())).andExpect(status().isOk()).andReturn());
        assertThat(market(user.token()).get(0).get("config")).isEqualTo(switched);
        switched.put("active", "pyramid");
        JsonNode updated = response(mockMvc.perform(put("/api/user-plugins/{id}/config", oldId)
                        .header("Authorization", bearer(user.token())).contentType("application/json")
                        .content(switched.toString())).andExpect(status().isOk()).andReturn());
        assertThat(updated.at("/data/config")).isEqualTo(switched);
        assertStored(user.id(), oldId, switched, true);

        JsonNode listed = market(user.token()).get(0);
        assertThat(listed.at("/config")).isEqualTo(switched);
        assertThat(listed.at("/installed").asBoolean()).isTrue();

        for (boolean enabled : List.of(false, true)) {
            JsonNode state = response(mockMvc.perform(put("/api/user-plugins/{id}/enabled", oldId)
                            .header("Authorization", bearer(user.token())).contentType("application/json")
                            .content("{\"enabled\":" + enabled + "}"))
                    .andExpect(status().isOk()).andReturn());
            assertThat(state.at("/data/enabled").asBoolean()).isEqualTo(enabled);
            assertThat(state.at("/data/config")).isEqualTo(switched);
            assertStored(user.id(), oldId, switched, enabled);
            assertThat(market(user.token()).get(0).get("config")).isEqualTo(switched);
            assertThat(market(user.token()).get(0).get("enabled").booleanValue()).isEqualTo(enabled);
        }

        JsonNode deleted = response(mockMvc.perform(delete("/api/user-plugins/{id}", oldId)
                        .header("Authorization", bearer(user.token())))
                .andExpect(status().isOk()).andReturn());
        assertThat(deleted.get("data").isNull()).isTrue();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_plugin WHERE id = ?", Integer.class, oldId))
                .isZero();
        assertUninstalled(market(user.token()), "quadrant-board");

        JsonNode reinstalled = install(user.token(), "quadrant-board");
        assertThat(reinstalled.at("/data/id").asLong()).isNotEqualTo(oldId);
        assertThat(reinstalled.at("/data/config")).isEqualTo(boardDefaults());
        assertThat(reinstalled.at("/data/enabled").asBoolean()).isTrue();
        assertStored(user.id(), reinstalled.at("/data/id").longValue(), boardDefaults(), true);
        assertThat(market(user.token()).get(0).get("userPluginId").longValue())
                .isEqualTo(reinstalled.at("/data/id").longValue());
    }

    @Test
    void pomodoroPersistsItsLabelAndOwnershipIsIsolated() throws Exception {
        var owner = registerAndLogin("13800808002");
        var other = registerAndLogin("13800808003");
        JsonNode installed = install(owner.token(), "pomodoro");
        long id = installed.at("/data/id").asLong();
        assertThat(installed.at("/data/config")).isEqualTo(objectMapper.readTree("{\"label\":\"专注\"}"));
        JsonNode custom = objectMapper.readTree("{\"label\":\"深度工作\",\"minutes\":25}");
        JsonNode updated = response(mockMvc.perform(put("/api/user-plugins/{id}/config", id)
                        .header("Authorization", bearer(owner.token())).contentType("application/json")
                        .content(custom.toString())).andExpect(status().isOk()).andReturn());
        assertThat(updated.at("/data/config")).isEqualTo(custom);
        assertThat(market(owner.token()).get(1).get("config")).isEqualTo(custom);
        assertUninstalled(market(other.token()), "pomodoro");
        JsonNode otherMarket = response(mockMvc.perform(get("/api/plugins").param("userId", Long.toString(owner.id()))
                        .header("Authorization", bearer(other.token()))).andExpect(status().isOk()).andReturn()).get("data");
        assertUninstalled(otherMarket, "pomodoro");
        var before = jdbc.queryForMap("SELECT * FROM user_plugin WHERE id=?", id);

        for (String operation : List.of("config", "enabled")) {
            String body = operation.equals("config") ? "{\"label\":\"越权\"}" : "{\"enabled\":false}";
            JsonNode forbidden = response(mockMvc.perform(put("/api/user-plugins/{id}/{operation}", id, operation)
                            .header("Authorization", bearer(other.token())).contentType("application/json")
                            .content(body))
                    .andExpect(status().isForbidden()).andReturn());
            assertThat(forbidden.get("msg").asText()).isEqualTo("无权操作该插件实例");
            assertThat(jdbc.queryForMap("SELECT * FROM user_plugin WHERE id=?", id)).isEqualTo(before);
        }
        JsonNode forbidden = response(mockMvc.perform(delete("/api/user-plugins/{id}", id)
                        .header("Authorization", bearer(other.token())))
                .andExpect(status().isForbidden()).andReturn());
        assertThat(forbidden.get("msg").asText()).isEqualTo("无权操作该插件实例");
        assertThat(jdbc.queryForMap("SELECT * FROM user_plugin WHERE id=?", id)).isEqualTo(before);
        assertStored(owner.id(), id, custom, true);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_plugin WHERE user_id=?", Integer.class, other.id()))
                .isZero();
    }

    @Test
    void allFiveRoutesRejectMissingAndLoggedOutTokensWithoutChangingData() throws Exception {
        var user = registerAndLogin("13800808006");
        long id = install(user.token(), "pomodoro").at("/data/id").longValue();
        var before = jdbc.queryForMap("SELECT * FROM user_plugin WHERE id=?", id);
        assertUnauthorizedRoutes(id, null, "未登录");
        response(mockMvc.perform(post("/api/auth/logout").header("Authorization", bearer(user.token())))
                .andExpect(status().isOk()).andReturn());
        assertUnauthorizedRoutes(id, user.token(), "token 已登出");
        assertThat(jdbc.queryForMap("SELECT * FROM user_plugin WHERE id=?", id)).isEqualTo(before);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_plugin WHERE user_id=?", Integer.class, user.id()))
                .isEqualTo(1);
    }

    @Test
    void concurrentInstallationsHaveOneWinnerAndOneConflict() throws Exception {
        var user = registerAndLogin("13800808004");
        var barrier = new CyclicBarrier(2);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var first = executor.submit(() -> concurrentInstall(user.token(), barrier));
            var second = executor.submit(() -> concurrentInstall(user.token(), barrier));
            var results = List.of(first.get(30, TimeUnit.SECONDS), second.get(30, TimeUnit.SECONDS));
            assertThat(results.stream().map(result -> result.getResponse().getStatus()).toList())
                    .containsExactlyInAnyOrder(200, 409);
            for (MvcResult result : results) {
                JsonNode body = response(result);
                if (result.getResponse().getStatus() == 409) {
                    assertThat(body.get("msg").asText()).isEqualTo("插件已安装");
                } else {
                    assertStored(user.id(), body.at("/data/id").longValue(),
                            objectMapper.readTree("{\"label\":\"专注\"}"), true);
                }
            }
        }
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_plugin WHERE user_id = ?", Integer.class, user.id()))
                .isEqualTo(1);
    }

    @Test
    void concurrentConfigAndEnabledUpdatesKeepBothCommittedFields() throws Exception {
        var user = registerAndLogin("13800808007");
        long id = install(user.token(), "pomodoro").at("/data/id").longValue();
        var mutationBarrier = new CyclicBarrier(2);
        JsonNode config = objectMapper.readTree("{\"label\":\"并发配置\",\"nested\":[true,null]}");
        try (var executor = Executors.newFixedThreadPool(2)) {
            var configFuture = executor.submit(() -> {
                mutationBarrier.await(10, TimeUnit.SECONDS);
                return mockMvc.perform(put("/api/user-plugins/{id}/config", id)
                        .header("Authorization", bearer(user.token())).contentType("application/json")
                        .content(config.toString())).andReturn();
            });
            var enabledFuture = executor.submit(() -> {
                mutationBarrier.await(10, TimeUnit.SECONDS);
                return mockMvc.perform(put("/api/user-plugins/{id}/enabled", id)
                        .header("Authorization", bearer(user.token())).contentType("application/json")
                        .content("{\"enabled\":false}")).andReturn();
            });
            for (MvcResult result : List.of(configFuture.get(30, TimeUnit.SECONDS), enabledFuture.get(30, TimeUnit.SECONDS))) {
                assertThat(result.getResponse().getStatus()).isEqualTo(200);
                response(result);
            }
        }
        assertStored(user.id(), id, config, false);
        assertThat(market(user.token()).get(1).get("config")).isEqualTo(config);
        assertThat(market(user.token()).get(1).get("enabled").booleanValue()).isFalse();
    }

    @Test
    void deletionCommittedBeforeUpdatesDoesNotResurrectTheInstance() throws Exception {
        var user = registerAndLogin("13800808008");
        long id = install(user.token(), "pomodoro").at("/data/id").longValue();
        var deletionCommitted = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var deletion = executor.submit(() -> {
                try {
                    return mockMvc.perform(delete("/api/user-plugins/{id}", id)
                            .header("Authorization", bearer(user.token()))).andReturn();
                } finally {
                    deletionCommitted.countDown();
                }
            });
            var updates = executor.submit(() -> {
                assertThat(deletionCommitted.await(10, TimeUnit.SECONDS)).isTrue();
                var results = new ArrayList<MvcResult>();
                for (String operation : List.of("config", "enabled")) {
                    results.add(mockMvc.perform(put("/api/user-plugins/{id}/{operation}", id, operation)
                            .header("Authorization", bearer(user.token())).contentType("application/json")
                            .content(operation.equals("config") ? "{}" : "{\"enabled\":true}")).andReturn());
                }
                return results;
            });
            MvcResult deleted = deletion.get(30, TimeUnit.SECONDS);
            assertThat(deleted.getResponse().getStatus()).isEqualTo(200);
            assertThat(response(deleted).get("data").isNull()).isTrue();
            for (MvcResult result : updates.get(30, TimeUnit.SECONDS)) {
                assertThat(result.getResponse().getStatus()).isEqualTo(404);
                assertThat(response(result).get("msg").asText()).isEqualTo("插件实例不存在");
            }
        }
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_plugin WHERE id = ?", Integer.class, id))
                .isZero();
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_plugin WHERE user_id=?", Integer.class, user.id()))
                .isZero();
        assertUninstalled(market(user.token()), "pomodoro");
    }

    @Test
    void rebuildingApplicationContextPreservesSeedIdsAndUserState() throws Exception {
        TestUser user;
        long id;
        List<Map<String, Object>> catalog;
        JsonNode config = objectMapper.readTree("{\"label\":\"重启后保留\",\"count\":3}");
        ConfigurableApplicationContext first = startProductionContext();
        try (first) {
            MockMvc firstMvc = MockMvcBuilders.webAppContextSetup((WebApplicationContext) first).build();
            user = registerAndLogin(firstMvc, "13800808005");
            id = response(firstMvc.perform(post("/api/plugins/pomodoro/install")
                            .header("Authorization", bearer(user.token()))).andExpect(status().isOk()).andReturn())
                    .at("/data/id").longValue();
            response(firstMvc.perform(put("/api/user-plugins/{id}/config", id)
                            .header("Authorization", bearer(user.token())).contentType("application/json")
                            .content(config.toString())).andExpect(status().isOk()).andReturn());
            response(firstMvc.perform(put("/api/user-plugins/{id}/enabled", id)
                            .header("Authorization", bearer(user.token())).contentType("application/json")
                            .content("{\"enabled\":false}"))
                    .andExpect(status().isOk()).andReturn());
            catalog = jdbc.queryForList("SELECT code,id FROM plugin ORDER BY sort,id");
            assertStored(user.id(), id, config, false);
        }
        assertThat(first.isActive()).isFalse();

        try (ConfigurableApplicationContext rebuilt = startProductionContext()) {
            JdbcTemplate rebuiltJdbc = new JdbcTemplate(rebuilt.getBean(javax.sql.DataSource.class));
            assertThat(rebuiltJdbc.queryForList("SELECT code,id FROM plugin ORDER BY sort,id"))
                    .isEqualTo(catalog);
            assertThat(rebuiltJdbc.queryForObject("SELECT COUNT(*) FROM plugin", Integer.class)).isEqualTo(2);
            assertThat(objectMapper.readTree(rebuiltJdbc.queryForObject(
                    "SELECT config FROM user_plugin WHERE id = ?", String.class, id))).isEqualTo(config);
            assertThat(rebuiltJdbc.queryForObject("SELECT enabled FROM user_plugin WHERE id = ?", Integer.class, id))
                    .isEqualTo(0);
            assertThat(rebuiltJdbc.queryForObject("SELECT COUNT(*) FROM user WHERE mobile='13800138001'", Integer.class))
                    .isZero();
            MockMvc rebuiltMvc = MockMvcBuilders.webAppContextSetup((WebApplicationContext) rebuilt).build();
            JsonNode listed = response(rebuiltMvc.perform(get("/api/plugins").header("Authorization", bearer(user.token())))
                    .andExpect(status().isOk()).andReturn()).get("data").get(1);
            assertThat(listed.get("userPluginId").longValue()).isEqualTo(id);
            assertThat(listed.get("config")).isEqualTo(config);
            assertThat(listed.get("enabled").booleanValue()).isFalse();
        }
    }

    private MvcResult concurrentInstall(String token, CyclicBarrier barrier) throws Exception {
        barrier.await(10, TimeUnit.SECONDS);
        return mockMvc.perform(post("/api/plugins/pomodoro/install")
                        .header("Authorization", bearer(token))).andReturn();
    }

    private ConfigurableApplicationContext startProductionContext() {
        return new SpringApplicationBuilder(ApiApplication.class).web(WebApplicationType.SERVLET).run(
                "--server.port=0",
                "--spring.profiles.active=prod",
                "--spring.datasource.url=" + MYSQL.getJdbcUrl(),
                "--spring.datasource.username=" + MYSQL.getUsername(),
                "--spring.datasource.password=" + MYSQL.getPassword(),
                "--spring.data.redis.host=" + REDIS.getHost(),
                "--spring.data.redis.port=" + REDIS.getMappedPort(6379),
                "--spring.flyway.locations=classpath:db/migration",
                "--selfmark.jwt.secret=selfmark-plugin-integration-secret-at-least-32-characters",
                "--management.health.defaults.enabled=false");
    }

    private TestUser registerAndLogin(String mobile) throws Exception {
        return registerAndLogin(mockMvc, mobile);
    }

    private TestUser registerAndLogin(MockMvc mvc, String mobile) throws Exception {
        JsonNode registration = response(mvc.perform(post("/api/auth/register")
                        .contentType("application/json")
                        .content(objectMapper.writeValueAsString(Map.of(
                                "mobile", mobile, "password", "Password123", "username", "Plugin Integration"))))
                .andExpect(status().isOk()).andReturn());
        long id = registration.at("/data/id").asLong();
        users.add(id);
        JsonNode login = response(mvc.perform(post("/api/auth/login")
                        .contentType("application/json")
                        .content("{\"mobile\":\"" + mobile + "\",\"password\":\"Password123\"}"))
                .andExpect(status().isOk()).andReturn());
        assertThat(login.at("/data/id").longValue()).isEqualTo(id);
        assertThat(login.at("/data/token").asText()).isNotBlank();
        return new TestUser(id, login.at("/data/token").asText());
    }

    private JsonNode install(String token, String code) throws Exception {
        JsonNode body = response(mockMvc.perform(post("/api/plugins/{code}/install", code)
                        .header("Authorization", bearer(token))).andExpect(status().isOk()).andReturn());
        JsonNode data = body.get("data");
        assertThat(data.size()).isEqualTo(6);
        assertThat(data.get("id").longValue()).isPositive();
        assertThat(data.get("code").asText()).isEqualTo(code);
        assertThat(data.get("name").asText()).isEqualTo(code.equals("pomodoro") ? "番茄钟" : "画板");
        assertThat(data.get("pluginId").longValue()).isEqualTo(jdbc.queryForObject(
                "SELECT id FROM plugin WHERE code=?", Long.class, code));
        assertThat(data.get("enabled").isBoolean()).isTrue();
        assertThat(data.get("config").isObject()).isTrue();
        return body;
    }

    private JsonNode market(String token) throws Exception {
        return response(mockMvc.perform(get("/api/plugins")
                        .header("Authorization", bearer(token))).andExpect(status().isOk()).andReturn()).get("data");
    }

    private void assertUninstalled(JsonNode market, String code) {
        JsonNode entry = null;
        for (JsonNode candidate : market) {
            if (code.equals(candidate.get("code").asText())) {
                entry = candidate;
                break;
            }
        }
        assertThat(entry).isNotNull();
        assertThat(entry.get("installed").asBoolean()).isFalse();
        for (String field : List.of("userPluginId", "enabled", "config")) {
            assertThat(entry.has(field)).isTrue();
            assertThat(entry.get(field).isNull()).isTrue();
        }
    }

    private JsonNode response(MvcResult result) throws Exception {
        JsonNode body = objectMapper.readTree(result.getResponse().getContentAsString(StandardCharsets.UTF_8));
        assertThat(body.get("code").intValue()).isEqualTo(result.getResponse().getStatus());
        assertThat(body.has("data")).isTrue();
        if (result.getResponse().getStatus() == 200) {
            assertThat(body.get("msg").asText()).isEqualTo("success");
        } else {
            assertThat(body.get("data").isNull()).isTrue();
        }
        return body;
    }

    private void assertStored(long userId, long id, JsonNode config, boolean enabled) throws Exception {
        var row = jdbc.queryForMap("SELECT user_id,config FROM user_plugin WHERE id=?", id);
        assertThat(((Number) row.get("user_id")).longValue()).isEqualTo(userId);
        assertThat(objectMapper.readTree(row.get("config").toString())).isEqualTo(config);
        assertThat(jdbc.queryForObject("SELECT enabled FROM user_plugin WHERE id=?", Integer.class, id))
                .isEqualTo(enabled ? 1 : 0);
    }

    private ObjectNode boardDefaults() throws Exception {
        return (ObjectNode) objectMapper.readTree("""
                {"active":"quadrant","quadrant":{"xAxisLabel":"紧急度","yAxisLabel":"重要度",
                "regions":[{"key":"q1","name":"重要且紧急"},{"key":"q2","name":"重要不紧急"},
                {"key":"q3","name":"紧急不重要"},{"key":"q4","name":"不重要不紧急"}]},
                "pyramid":{"regions":[{"key":"p1","name":"顶层目标"},{"key":"p2","name":"中层计划"},
                {"key":"p3","name":"底层行动"}]}}
                """);
    }

    private void assertUnauthorizedRoutes(long id, String token, String message) throws Exception {
        List<MockHttpServletRequestBuilder> requests = List.of(
                get("/api/plugins"), post("/api/plugins/quadrant-board/install"),
                put("/api/user-plugins/{id}/config", id).contentType("application/json").content("{}"),
                put("/api/user-plugins/{id}/enabled", id).contentType("application/json").content("{\"enabled\":false}"),
                delete("/api/user-plugins/{id}", id));
        for (var request : requests) {
            if (token != null) {
                request.header("Authorization", bearer(token));
            }
            JsonNode body = response(mockMvc.perform(request).andExpect(status().isUnauthorized()).andReturn());
            assertThat(body.get("msg").asText()).isEqualTo(message);
        }
    }

    private String bearer(String token) {
        return "Bearer " + token;
    }

    private record TestUser(long id, String token) { }
}
