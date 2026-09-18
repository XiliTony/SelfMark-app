package com.nortidart.selfmark;

import com.auth0.jwt.JWT;
import com.auth0.jwt.algorithms.Algorithm;
import com.nortidart.selfmark.common.context.UserContext;
import com.nortidart.selfmark.common.exception.BusinessException;
import com.nortidart.selfmark.common.response.ApiResponse;
import com.nortidart.selfmark.auth.security.JwtUtil;
import com.nortidart.selfmark.auth.mapper.UserMapper;
import com.nortidart.selfmark.auth.service.TokenBlacklistService;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.data.redis.RedisConnectionFailureException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.time.Instant;
import java.util.Date;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.mockito.Mockito.doThrow;

@SpringBootTest
@AutoConfigureMockMvc
@Import(InfrastructureTests.TestEndpoints.class)
@TestPropertySource(properties = {
        "spring.autoconfigure.exclude=com.baomidou.mybatisplus.autoconfigure.MybatisPlusAutoConfiguration,"
                + "org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,"
                + "org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration",
        "management.health.defaults.enabled=false",
        "management.health.db.enabled=false",
        "management.health.redis.enabled=false"
})
class InfrastructureTests {

    @MockitoBean
    UserMapper userMapper;

    @MockitoBean
    TokenBlacklistService tokenBlacklistService;

    @Autowired
    private org.springframework.test.web.servlet.MockMvc mockMvc;

    @Autowired
    private JwtUtil jwtUtil;

    @Test
    void protectedApiWithoutTokenReturns401() throws Exception {
        mockMvc.perform(get("/api/test/current-user"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().json("{\"code\":401,\"msg\":\"未登录\",\"data\":null}"));
    }

    @Test
    void validTokenExposesCurrentUser() throws Exception {
        String token = jwtUtil.issue(42L, "USER");
        mockMvc.perform(get("/api/test/current-user").header("Authorization", "Bearer " + token))
                .andExpect(status().isOk())
                .andExpect(content().json("{\"code\":200,\"msg\":\"success\",\"data\":42}"));
    }

    @Test
    void redisBlacklistFailureDoesNotFailOpen() throws Exception {
        String token = jwtUtil.issue(42L, "USER");
        doThrow(new RedisConnectionFailureException("Redis unavailable"))
                .when(tokenBlacklistService).isBlacklisted(org.mockito.ArgumentMatchers.anyString());

        mockMvc.perform(get("/api/test/current-user").header("Authorization", "Bearer " + token))
                .andExpect(status().isInternalServerError())
                .andExpect(content().json("{\"code\":500,\"msg\":\"服务器内部错误\",\"data\":null}"));
    }

    @Test
    void invalidTokenReturns401() throws Exception {
        mockMvc.perform(get("/api/test/current-user").header("Authorization", "Bearer invalid"))
                .andExpect(status().isUnauthorized())
                .andExpect(content().json("{\"code\":401,\"msg\":\"token 无效\",\"data\":null}"));
    }

    @Test
    void expiredTokenReturns401() throws Exception {
        String token = JWT.create()
                .withIssuer("selfmark")
                .withJWTId("expired-token")
                .withClaim("userId", 1L)
                .withClaim("role", "USER")
                .withIssuedAt(Date.from(Instant.now().minusSeconds(120)))
                .withExpiresAt(Date.from(Instant.now().minusSeconds(60)))
                .sign(Algorithm.HMAC256("selfmark-test-jwt-secret-at-least-32-characters"));

        mockMvc.perform(get("/api/test/current-user").header("Authorization", "Bearer " + token))
                .andExpect(status().isUnauthorized())
                .andExpect(content().json("{\"code\":401,\"msg\":\"token 无效\",\"data\":null}"));
    }

    @Test
    void businessExceptionUsesUnifiedResponse() throws Exception {
        mockMvc.perform(get("/api/test/conflict").header("Authorization", "Bearer " + jwtUtil.issue(1L, "USER")))
                .andExpect(status().isConflict())
                .andExpect(content().json("{\"code\":409,\"msg\":\"冲突\",\"data\":null}"));
    }

    @Test
    void forbiddenBusinessExceptionUsesUnifiedResponse() throws Exception {
        mockMvc.perform(get("/api/test/forbidden")
                        .header("Authorization", "Bearer " + jwtUtil.issue(1L, "USER")))
                .andExpect(status().isForbidden())
                .andExpect(content().json("{\"code\":403,\"msg\":\"无权操作\",\"data\":null}"));
    }

    @Test
    void missingResourceUsesUnifiedResponse() throws Exception {
        mockMvc.perform(get("/api/test/not-found")
                        .header("Authorization", "Bearer " + jwtUtil.issue(1L, "USER")))
                .andExpect(status().isNotFound())
                .andExpect(content().json("{\"code\":404,\"msg\":\"资源不存在\",\"data\":null}"));
    }

    @Test
    void unexpectedExceptionUsesUnifiedResponse() throws Exception {
        mockMvc.perform(get("/api/test/error")
                        .header("Authorization", "Bearer " + jwtUtil.issue(1L, "USER")))
                .andExpect(status().isInternalServerError())
                .andExpect(content().json("{\"code\":500,\"msg\":\"服务器内部错误\",\"data\":null}"));
    }

    @Test
    void validationFailureUsesUnifiedResponse() throws Exception {
        mockMvc.perform(post("/api/test/validate")
                        .header("Authorization", "Bearer " + jwtUtil.issue(1L, "USER"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"name\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(content().json("{\"code\":400,\"data\":null}"));
    }

    @Test
    void unreadableJsonUsesUnifiedResponse() throws Exception {
        mockMvc.perform(post("/api/test/validate")
                        .header("Authorization", "Bearer " + jwtUtil.issue(1L, "USER"))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{"))
                .andExpect(status().isBadRequest())
                .andExpect(content().json("{\"code\":400,\"msg\":\"请求体格式错误\",\"data\":null}"));
    }

    @TestConfiguration(proxyBeanMethods = false)
    @RestController
    static class TestEndpoints {
        @GetMapping("/api/test/current-user")
        ApiResponse<Long> currentUser() {
            return ApiResponse.success(UserContext.getUserId());
        }

        @GetMapping("/api/test/conflict")
        ApiResponse<Void> conflict() {
            throw new BusinessException(409, "冲突");
        }

        @GetMapping("/api/test/forbidden")
        ApiResponse<Void> forbidden() {
            throw new BusinessException(403, "无权操作");
        }

        @GetMapping("/api/test/error")
        ApiResponse<Void> error() {
            throw new NullPointerException("test-only exception");
        }

        @GetMapping("/api/test/not-found")
        ApiResponse<Void> notFound() {
            throw new BusinessException(404, "资源不存在");
        }

        @PostMapping("/api/test/validate")
        ApiResponse<Void> validate(@Valid @RequestBody Request request) {
            return ApiResponse.success();
        }

        record Request(@NotBlank(message = "name 不能为空") String name) {
        }
    }
}
