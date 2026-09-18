package com.nortidart.selfmark.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.nio.charset.StandardCharsets;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.containers.GenericContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@SpringBootTest(properties = {
        "spring.flyway.enabled=true",
        "management.health.defaults.enabled=false",
        "management.health.redis.enabled=false"
})
@AutoConfigureMockMvc
@Testcontainers(disabledWithoutDocker = true)
class AuthIntegrationTests {
    @Container
    static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4")
            .withDatabaseName("selfmark")
            .withUsername("selfmark")
            .withPassword("selfmark");

    @Container
    static final GenericContainer<?> REDIS = new GenericContainer<>("redis:7.4-alpine")
            .withExposedPorts(6379);

    @DynamicPropertySource
    static void configureDatabase(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", MYSQL::getJdbcUrl);
        registry.add("spring.datasource.username", MYSQL::getUsername);
        registry.add("spring.datasource.password", MYSQL::getPassword);
        registry.add("spring.data.redis.host", REDIS::getHost);
        registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
    }

    @Autowired MockMvc mockMvc;
    @Autowired ObjectMapper objectMapper;
    @Autowired JdbcTemplate jdbcTemplate;

    @Test
    void registerLoginAndAuthenticationCompleteTheHttpDatabaseLoop() throws Exception {
        String registerJson = """
                {"mobile":"13800138000","password":"Password123","username":"Integration"}
                """;
        String registerBody = mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registerJson))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").value(200))
                .andExpect(jsonPath("$.data.id").isNumber())
                .andExpect(jsonPath("$.data.mobile").value("13800138000"))
                .andExpect(jsonPath("$.data.account").doesNotExist())
                .andExpect(jsonPath("$.data.username").value("Integration"))
                .andExpect(jsonPath("$.data.password").doesNotExist())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);

        JsonNode registerResponse = objectMapper.readTree(registerBody);
        assertProtectedEndpoint(registerResponse.at("/data/token").asText(), "13800138000", "Integration");

        String storedPassword = jdbcTemplate.queryForObject(
                "SELECT password FROM user WHERE mobile = ?", String.class, "13800138000");
        assertThat(storedPassword).startsWith("$2").hasSize(60).doesNotContain("Password123");

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(registerJson))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value(409))
                .andExpect(jsonPath("$.msg").value("手机号已注册"));

        String loginBody = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"mobile\":\"13800138000\",\"password\":\"Password123\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mobile").value("13800138000"))
                .andExpect(jsonPath("$.data.account").doesNotExist())
                .andExpect(jsonPath("$.data.password").doesNotExist())
                .andReturn().getResponse().getContentAsString(StandardCharsets.UTF_8);
        assertProtectedEndpoint(objectMapper.readTree(loginBody).at("/data/token").asText(),
                "13800138000", "Integration");
    }

    @Test
    void invalidCredentialsAndInvalidInputReturnClientErrors() throws Exception {
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"mobile\":\"13800138001\",\"username\":\"Missing Password\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value(400));

        String oversizedPassword = "密".repeat(25);
        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(
                                new Registration("13800138002", oversizedPassword, "Oversized"))))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.msg").value("password 不能超过 72 个 UTF-8 字节"));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"mobile\":\"13900139000\",\"password\":\"Password123\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401));

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"mobile\":\"13800138003\",\"password\":\"Password123\","
                                + "\"username\":\"Wrong Password\"}"))
                .andExpect(status().isOk());

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"mobile\":\"13800138003\",\"password\":\"WrongPassword\"}"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value(401))
                .andExpect(jsonPath("$.msg").value("手机号或密码错误"));

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"mobile\":\"not-a-mobile\",\"password\":\"Password123\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.msg").value("手机号格式错误"));
    }

    private void assertProtectedEndpoint(String token, String mobile, String username) throws Exception {
        assertThat(token).isNotBlank();
        mockMvc.perform(get("/api/users/me").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.mobile").value(mobile))
                .andExpect(jsonPath("$.data.account").doesNotExist())
                .andExpect(jsonPath("$.data.username").value(username))
                .andExpect(jsonPath("$.data.password").doesNotExist());
    }

    private record Registration(String mobile, String password, String username) { }
}
