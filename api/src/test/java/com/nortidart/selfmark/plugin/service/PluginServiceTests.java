package com.nortidart.selfmark.plugin.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.baomidou.mybatisplus.core.conditions.Wrapper;
import com.nortidart.selfmark.common.exception.BusinessException;
import com.nortidart.selfmark.plugin.entity.Plugin;
import com.nortidart.selfmark.plugin.entity.UserPlugin;
import com.nortidart.selfmark.plugin.mapper.PluginMapper;
import com.nortidart.selfmark.plugin.mapper.UserPluginMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.DuplicateKeyException;

@ExtendWith(MockitoExtension.class)
class PluginServiceTests {
    @Mock PluginMapper pluginMapper;
    @Mock UserPluginMapper userPluginMapper;
    PluginService service;

    @BeforeEach
    void setUp() {
        service = new PluginService(pluginMapper, userPluginMapper, new DefaultPluginConfigFactory());
        var plugin = new Plugin();
        plugin.setId(1L);
        plugin.setCode("pomodoro");
        plugin.setName("番茄钟");
        when(pluginMapper.selectOne(any(Wrapper.class))).thenReturn(plugin);
    }

    @Test
    void uniqueConflictAfterSuccessfulPrecheckIs409() {
        when(userPluginMapper.selectCount(any(Wrapper.class))).thenReturn(0L);
        when(userPluginMapper.insert(any(UserPlugin.class))).thenThrow(new DuplicateKeyException("uk_user_plugin"));
        assertConflict();
        verify(userPluginMapper).insert(any(UserPlugin.class));
        verify(userPluginMapper, never()).selectById(any(Long.class));
    }

    @Test
    void alreadyInstalledDoesNotInsert() {
        when(userPluginMapper.selectCount(any(Wrapper.class))).thenReturn(1L);
        assertConflict();
        verify(userPluginMapper, never()).insert(any(UserPlugin.class));
    }

    @Test
    void otherInsertFailuresAreNotMisreportedAsConflict() {
        when(userPluginMapper.insert(any(UserPlugin.class)))
                .thenThrow(new DataIntegrityViolationException("database failure"));
        assertThatThrownBy(() -> service.install(42L, "pomodoro"))
                .isInstanceOf(DataIntegrityViolationException.class);
    }

    @Test
    void readbackFailurePropagatesForTransactionRollback() {
        when(userPluginMapper.insert(any(UserPlugin.class))).thenAnswer(invocation -> {
            invocation.<UserPlugin>getArgument(0).setId(11L);
            return 1;
        });
        assertThatThrownBy(() -> service.install(42L, "pomodoro"))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("read back");
    }

    private void assertConflict() {
        assertThatThrownBy(() -> service.install(42L, "pomodoro"))
                .isInstanceOfSatisfying(BusinessException.class, exception -> {
                    assertThat(exception.getCode()).isEqualTo(409);
                    assertThat(exception.getMessage()).isEqualTo("插件已安装");
                });
    }
}
