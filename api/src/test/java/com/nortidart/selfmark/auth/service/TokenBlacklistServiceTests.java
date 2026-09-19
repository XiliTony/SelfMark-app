package com.nortidart.selfmark.auth.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Duration;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.data.redis.RedisConnectionFailureException;

@ExtendWith(MockitoExtension.class)
class TokenBlacklistServiceTests {
    private static final String BLACKLIST_KEY = "selfmark:auth:jwt:blacklist:jti-1";

    @Mock StringRedisTemplate redis;
    @Mock ValueOperations<String, String> values;

    @Test
    void storesOnlyJtiWithRemainingTokenTtl() {
        TokenBlacklistService service = new TokenBlacklistService(redis);
        when(redis.opsForValue()).thenReturn(values);

        service.blacklist("jti-1", 42);

        verify(values).set(eq(BLACKLIST_KEY), eq("1"), eq(Duration.ofSeconds(42)));
    }

    @Test
    void checksRedisKeyAndDoesNotUseAnotherStore() {
        when(redis.hasKey(BLACKLIST_KEY)).thenReturn(true);

        assertThat(new TokenBlacklistService(redis).isBlacklisted("jti-1")).isTrue();
        verify(redis).hasKey(BLACKLIST_KEY);
    }

    @Test
    void failsClosedWhenRedisCannotStoreBlacklist() {
        when(redis.opsForValue()).thenReturn(values);
        doThrow(new RedisConnectionFailureException("Redis unavailable"))
                .when(values).set(BLACKLIST_KEY, "1", Duration.ofSeconds(42));

        assertThatThrownBy(() -> new TokenBlacklistService(redis).blacklist("jti-1", 42))
                .isInstanceOf(RedisConnectionFailureException.class);
    }

    @Test
    void failsClosedWhenRedisCannotCheckBlacklist() {
        when(redis.hasKey(BLACKLIST_KEY))
                .thenThrow(new RedisConnectionFailureException("Redis unavailable"));

        assertThatThrownBy(() -> new TokenBlacklistService(redis).isBlacklisted("jti-1"))
                .isInstanceOf(RedisConnectionFailureException.class);
    }
}
