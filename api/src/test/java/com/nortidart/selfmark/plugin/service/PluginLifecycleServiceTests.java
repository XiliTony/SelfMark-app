package com.nortidart.selfmark.plugin.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.fasterxml.jackson.databind.node.JsonNodeFactory;
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

@ExtendWith(MockitoExtension.class)
class PluginLifecycleServiceTests {
    @Mock PluginMapper pluginMapper;
    @Mock UserPluginMapper userPluginMapper;
    @Mock DefaultPluginConfigFactory defaultConfigFactory;
    PluginService service;

    @BeforeEach
    void setUp() {
        service = new PluginService(pluginMapper, userPluginMapper, defaultConfigFactory);
    }

    @Test
    void zeroChangedRowsStillReturnsDisabledInstanceWithOriginalConfig() {
        var instance = instance(42L);
        instance.setConfig(JsonNodeFactory.instance.objectNode().put("label", "自定义"));
        instance.setEnabled(false);
        var plugin = new Plugin();
        plugin.setId(1L);
        plugin.setCode("pomodoro");
        plugin.setName("番茄钟");
        when(userPluginMapper.selectByIdForUpdate(11L)).thenReturn(instance);
        when(userPluginMapper.setEnabled(11L, 42L, false)).thenReturn(0);
        when(userPluginMapper.selectById(11L)).thenReturn(instance);
        when(pluginMapper.selectById(1L)).thenReturn(plugin);
        var response = service.setEnabled(42L, 11L, JsonNodeFactory.instance.objectNode().put("enabled", false));
        assertThat(response.enabled()).isFalse();
        assertThat(response.config()).isEqualTo(instance.getConfig());
        verify(userPluginMapper, never()).replaceConfig(any(), any(), any());
        verify(userPluginMapper, never()).updateById(any(UserPlugin.class));
        verifyNoInteractions(defaultConfigFactory);
    }

    @Test
    void forbiddenUninstallNeverDeletes() {
        when(userPluginMapper.selectByIdForUpdate(11L)).thenReturn(instance(99L));
        assertThatThrownBy(() -> service.uninstall(42L, 11L))
                .isInstanceOfSatisfying(BusinessException.class, exception -> assertThat(exception.getCode()).isEqualTo(403));
        verify(userPluginMapper, never()).deleteOwned(any(), any());
        verifyNoInteractions(pluginMapper, defaultConfigFactory);
    }

    @Test
    void absentUninstallIs404WithoutDeleting() {
        assertThatThrownBy(() -> service.uninstall(42L, 11L))
                .isInstanceOfSatisfying(BusinessException.class, exception -> assertThat(exception.getCode()).isEqualTo(404));
        verify(userPluginMapper, never()).deleteOwned(any(), any());
    }

    @Test
    void unexpectedZeroDeletedRowsCannotReportSuccess() {
        when(userPluginMapper.selectByIdForUpdate(11L)).thenReturn(instance(42L));
        when(userPluginMapper.deleteOwned(11L, 42L)).thenReturn(0);
        assertThatThrownBy(() -> service.uninstall(42L, 11L)).isInstanceOf(IllegalStateException.class);
    }

    private UserPlugin instance(long userId) {
        var instance = new UserPlugin();
        instance.setId(11L);
        instance.setUserId(userId);
        instance.setPluginId(1L);
        return instance;
    }
}
