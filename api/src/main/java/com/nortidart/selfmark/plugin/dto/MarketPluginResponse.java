package com.nortidart.selfmark.plugin.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.databind.JsonNode;

@JsonInclude(JsonInclude.Include.ALWAYS)
public class MarketPluginResponse {
    private Long id;
    private String code;
    private String name;
    private String description;
    private Integer sort;
    private Long userPluginId;
    private Boolean enabled;
    private JsonNode config;

    public boolean isInstalled() { return userPluginId != null; }
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    public String getCode() { return code; }
    public void setCode(String code) { this.code = code; }
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }
    public Integer getSort() { return sort; }
    public void setSort(Integer sort) { this.sort = sort; }
    public Long getUserPluginId() { return userPluginId; }
    public void setUserPluginId(Long userPluginId) { this.userPluginId = userPluginId; }
    public Boolean getEnabled() { return enabled; }
    public void setEnabled(Boolean enabled) { this.enabled = enabled; }
    public JsonNode getConfig() { return config; }
    public void setConfig(JsonNode config) { this.config = config; }
}
