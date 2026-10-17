package com.nortidart.selfmark.plugin.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.fasterxml.jackson.databind.JsonNode;
import com.nortidart.selfmark.plugin.mapper.JsonNodeTypeHandler;
import java.time.LocalDateTime;

@TableName(value = "user_plugin", autoResultMap = true)
public class UserPlugin {
    @TableId(type = IdType.AUTO)
    private Long id;
    private Long userId;
    private Long pluginId;
    @TableField(typeHandler = JsonNodeTypeHandler.class)
    private JsonNode config;
    private Boolean enabled;
    private LocalDateTime createdAt;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public Long getUserId() { return userId; }
    public void setUserId(Long userId) { this.userId = userId; }
    public Long getPluginId() { return pluginId; }
    public void setPluginId(Long pluginId) { this.pluginId = pluginId; }
    public JsonNode getConfig() { return config; }
    public void setConfig(JsonNode config) { this.config = config; }
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }
}
