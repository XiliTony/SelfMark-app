package com.nortidart.selfmark.auth.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.nortidart.selfmark.auth.dto.LoginRequest;
import com.nortidart.selfmark.auth.dto.RegisterRequest;
import com.nortidart.selfmark.auth.entity.User;
import com.nortidart.selfmark.auth.mapper.UserMapper;
import com.nortidart.selfmark.auth.security.JwtUtil;
import com.nortidart.selfmark.common.exception.BusinessException;
import com.nortidart.selfmark.config.JwtProperties;
import java.time.Duration;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.dao.DuplicateKeyException;

class AuthServiceTests {
    private UserMapper userMapper;
    private AuthService authService;
    private JwtUtil jwtUtil;

    @BeforeEach
    void setUp() {
        userMapper = mock(UserMapper.class);
        jwtUtil = new JwtUtil(
                new JwtProperties("selfmark-test-jwt-secret-at-least-32-characters", Duration.ofDays(7)));
        authService = new AuthService(userMapper, new BCryptPasswordEncoder(), jwtUtil);
    }

    @Test
    void registerStoresBcryptHashAndReturnsPasswordFreeDto() {
        when(userMapper.selectCount(any())).thenReturn(0L);
        AtomicReference<User> inserted = new AtomicReference<>();
        when(userMapper.insert(any(User.class))).thenAnswer(invocation -> {
            User user = invocation.getArgument(0);
            user.setId(7L);
            inserted.set(user);
            return 1;
        });

        var response = authService.register(new RegisterRequest("13800138000", "secret123", "Alice"));

        assertThat(inserted.get().getPassword()).startsWith("$2").isNotEqualTo("secret123");
        assertThat(new BCryptPasswordEncoder().matches("secret123", inserted.get().getPassword())).isTrue();
        assertThat(response.id()).isEqualTo(7L);
        assertThat(response.mobile()).isEqualTo("13800138000");
        assertThat(response.username()).isEqualTo("Alice");
        assertThat(response.token()).isNotBlank();
        assertThat(jwtUtil.parse(response.token()).getClaim("mobile").asString()).isEqualTo("13800138000");
        assertThat(jwtUtil.parse(response.token()).getClaim("account").isMissing()).isTrue();
    }

    @Test
    void duplicateMobileReturns409() {
        when(userMapper.selectCount(any())).thenReturn(1L);
        assertThatThrownBy(() -> authService.register(new RegisterRequest("13800138000", "secret123", "Alice")))
                .isInstanceOfSatisfying(BusinessException.class, exception -> {
                    assertThat(exception.getCode()).isEqualTo(409);
                    assertThat(exception.getMessage()).isEqualTo("手机号已注册");
                });
    }

    @Test
    void concurrentDuplicateKeyIsMappedTo409() {
        when(userMapper.selectCount(any())).thenReturn(0L);
        doThrow(new DuplicateKeyException("uk_user_mobile"))
                .when(userMapper).insert(any(User.class));

        assertThatThrownBy(() -> authService.register(new RegisterRequest("13800138000", "secret123", "Alice")))
                .isInstanceOfSatisfying(BusinessException.class, exception -> {
                    assertThat(exception.getCode()).isEqualTo(409);
                    assertThat(exception.getMessage()).isEqualTo("手机号已注册");
                });
    }

    @Test
    void registeredPasswordCanLogIn() {
        User user = user(7L, "13800138000", "Alice", new BCryptPasswordEncoder().encode("secret123"));
        when(userMapper.selectOne(any())).thenReturn(user);
        assertThat(authService.login(new LoginRequest("13800138000", "secret123")).id()).isEqualTo(7L);
    }

    @Test
    void unknownUsernameAndWrongPasswordBothReturn401() {
        when(userMapper.selectOne(any())).thenReturn(null);
        assertUnauthorized(() -> authService.login(new LoginRequest("13900139000", "secret123")));

        when(userMapper.selectOne(any()))
                .thenReturn(user(7L, "13800138000", "Alice",
                        new BCryptPasswordEncoder().encode("right-password")));
        assertUnauthorized(() -> authService.login(new LoginRequest("13800138000", "wrong-password")));
        verify(userMapper, org.mockito.Mockito.times(2)).selectOne(any());
    }

    private void assertUnauthorized(Runnable action) {
        assertThatThrownBy(action::run).isInstanceOfSatisfying(BusinessException.class,
                exception -> assertThat(exception.getCode()).isEqualTo(401));
    }

    private User user(Long id, String mobile, String username, String password) {
        User user = new User();
        user.setId(id);
        user.setMobile(mobile);
        user.setUsername(username);
        user.setPassword(password);
        return user;
    }
}
