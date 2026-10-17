package com.nortidart.selfmark.plugin.service;

import com.baomidou.mybatisplus.core.toolkit.Wrappers;
import com.fasterxml.jackson.databind.JsonNode;
import com.nortidart.selfmark.common.exception.BusinessException;
import com.nortidart.selfmark.plugin.dto.InstalledPluginResponse;
import com.nortidart.selfmark.plugin.dto.MarketPluginResponse;
import com.nortidart.selfmark.plugin.entity.Plugin;
import com.nortidart.selfmark.plugin.entity.UserPlugin;
import com.nortidart.selfmark.plugin.mapper.PluginMapper;
import com.nortidart.selfmark.plugin.mapper.UserPluginMapper;
import java.util.List;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PluginService {
    private final PluginMapper pluginMapper;
    private final UserPluginMapper userPluginMapper;
    private final DefaultPluginConfigFactory defaultConfigFactory;

    public PluginService(PluginMapper pluginMapper, UserPluginMapper userPluginMapper,
            DefaultPluginConfigFactory defaultConfigFactory) {
        this.pluginMapper = pluginMapper;
        this.userPluginMapper = userPluginMapper;
        this.defaultConfigFactory = defaultConfigFactory;
    }

    public List<MarketPluginResponse> listMarket(Long userId) {
        return pluginMapper.selectMarket(userId);
    }

    @Transactional
    public InstalledPluginResponse install(Long userId, String code) {
        Plugin plugin = pluginMapper.selectOne(Wrappers.<Plugin>query().eq("code", code));
        if (plugin == null) {
            throw new BusinessException(404, "插件不存在");
        }
        if (userPluginMapper.selectCount(Wrappers.<UserPlugin>query()
                .eq("user_id", userId).eq("plugin_id", plugin.getId())) > 0) {
            throw new BusinessException(409, "插件已安装");
        }
        var instance = new UserPlugin();
        instance.setUserId(userId);
        instance.setPluginId(plugin.getId());
        instance.setConfig(defaultConfigFactory.create(plugin.getCode()));
        instance.setEnabled(true);
        // The unique key also protects requests that both passed the precheck.
        try {
            if (userPluginMapper.insert(instance) != 1) {
                throw new IllegalStateException("Plugin installation did not insert one row");
            }
        } catch (DuplicateKeyException exception) {
            throw new BusinessException(409, "插件已安装");
        }
        UserPlugin stored = userPluginMapper.selectById(instance.getId());
        if (stored == null) {
            throw new IllegalStateException("Installed plugin could not be read back");
        }
        return new InstalledPluginResponse(stored.getId(), plugin.getId(), plugin.getCode(),
                plugin.getName(), stored.getConfig(), stored.getEnabled());
    }

    @Transactional
    public InstalledPluginResponse replaceConfig(Long userId, Long id, JsonNode config) {
        validateId(id);
        if (config == null || !config.isObject()) {
            throw new BusinessException(400, "config 必须是 JSON 对象");
        }
        lockOwnedInstance(userId, id);
        // A same-value UPDATE may report zero changed rows; the locked row still exists.
        userPluginMapper.replaceConfig(id, userId, config);
        return installedResponse(id);
    }

    @Transactional
    public InstalledPluginResponse setEnabled(Long userId, Long id, JsonNode body) {
        validateId(id);
        if (body == null || !body.isObject() || !body.path("enabled").isBoolean()) {
            throw new BusinessException(400, "enabled 必须是布尔值");
        }
        lockOwnedInstance(userId, id);
        userPluginMapper.setEnabled(id, userId, body.get("enabled").booleanValue());
        return installedResponse(id);
    }

    @Transactional
    public void uninstall(Long userId, Long id) {
        validateId(id);
        lockOwnedInstance(userId, id);
        if (userPluginMapper.deleteOwned(id, userId) != 1) {
            throw new IllegalStateException("Plugin uninstall did not delete one locked row");
        }
    }

    private void validateId(Long id) {
        if (id == null || id <= 0) {
            throw new BusinessException(400, "id 必须是正整数");
        }
    }

    private void lockOwnedInstance(Long userId, Long id) {
        UserPlugin instance = userPluginMapper.selectByIdForUpdate(id);
        if (instance == null) {
            throw new BusinessException(404, "插件实例不存在");
        }
        if (!userId.equals(instance.getUserId())) {
            throw new BusinessException(403, "无权操作该插件实例");
        }
    }

    private InstalledPluginResponse installedResponse(Long id) {
        UserPlugin stored = userPluginMapper.selectById(id);
        if (stored == null) {
            throw new IllegalStateException("Updated plugin could not be read back");
        }
        Plugin plugin = pluginMapper.selectById(stored.getPluginId());
        if (plugin == null) {
            throw new IllegalStateException("Installed plugin references a missing catalog entry");
        }
        return new InstalledPluginResponse(stored.getId(), plugin.getId(), plugin.getCode(),
                plugin.getName(), stored.getConfig(), stored.getEnabled());
    }
}
