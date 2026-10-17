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
class PluginConfigServiceTests {
    @Mock PluginMapper pluginMapper;
    @Mock UserPluginMapper userPluginMapper;
    @Mock DefaultPluginConfigFactory defaultConfigFactory;
    PluginService service;

    @BeforeEach
    void setUp() {
        service = new PluginService(pluginMapper, userPluginMapper, defaultConfigFactory);
    }

    @Test
    void zeroChangedRowsStillReturnsStoredConfigAndDisabledState() {
        var config = JsonNodeFactory.instance.objectNode().put("foo", 1);
        var instance = new UserPlugin();
        instance.setId(11L);
        instance.setUserId(42L);
        instance.setPluginId(1L);
        instance.setConfig(config);
        instance.setEnabled(false);
        var plugin = new Plugin();
        plugin.setId(1L);
        plugin.setCode("quadrant-board");
        plugin.setName("画板");
        when(userPluginMapper.selectByIdForUpdate(11L)).thenReturn(instance);
        when(userPluginMapper.replaceConfig(11L, 42L, config)).thenReturn(0);
        when(userPluginMapper.selectById(11L)).thenReturn(instance);
        when(pluginMapper.selectById(1L)).thenReturn(plugin);
        var response = service.replaceConfig(42L, 11L, config);
        assertThat(response.config()).isEqualTo(config);
        assertThat(response.enabled()).isFalse();
        assertThat(response.id()).isEqualTo(11L);
        verify(userPluginMapper).replaceConfig(11L, 42L, config);
        verify(userPluginMapper, never()).updateById(any(UserPlugin.class));
        verifyNoInteractions(defaultConfigFactory);
    }

    @Test
    void anotherOwnerIsForbiddenBeforeUpdate() {
        var instance = new UserPlugin();
        instance.setUserId(99L);
        when(userPluginMapper.selectByIdForUpdate(11L)).thenReturn(instance);
        assertThatThrownBy(() -> service.replaceConfig(42L, 11L, JsonNodeFactory.instance.objectNode()))
                .isInstanceOfSatisfying(BusinessException.class, exception -> assertThat(exception.getCode()).isEqualTo(403));
        verify(userPluginMapper, never()).replaceConfig(any(), any(), any());
        verifyNoInteractions(pluginMapper, defaultConfigFactory);
    }
}
