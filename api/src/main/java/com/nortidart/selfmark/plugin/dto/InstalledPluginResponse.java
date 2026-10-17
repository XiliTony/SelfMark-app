package com.nortidart.selfmark.plugin.dto;

import com.fasterxml.jackson.databind.JsonNode;

public record InstalledPluginResponse(Long id, Long pluginId, String code, String name,
        JsonNode config, boolean enabled) { }
