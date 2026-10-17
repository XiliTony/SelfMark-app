package com.nortidart.selfmark.plugin.controller;

import com.fasterxml.jackson.databind.JsonNode;
import com.nortidart.selfmark.common.context.UserContext;
import com.nortidart.selfmark.common.response.ApiResponse;
import com.nortidart.selfmark.plugin.dto.InstalledPluginResponse;
import com.nortidart.selfmark.plugin.service.PluginService;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/user-plugins")
public class UserPluginController {
    private final PluginService pluginService;

    public UserPluginController(PluginService pluginService) {
        this.pluginService = pluginService;
    }

    @PutMapping(value = "/{id}/config", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ApiResponse<InstalledPluginResponse> replaceConfig(@PathVariable Long id,
            @RequestBody JsonNode config) {
        return ApiResponse.success(pluginService.replaceConfig(UserContext.getUserId(), id, config));
    }

    @PutMapping(value = "/{id}/enabled", consumes = MediaType.APPLICATION_JSON_VALUE)
    public ApiResponse<InstalledPluginResponse> setEnabled(@PathVariable Long id,
            @RequestBody JsonNode body) {
        return ApiResponse.success(pluginService.setEnabled(UserContext.getUserId(), id, body));
    }

    @DeleteMapping("/{id}")
    public ApiResponse<Void> uninstall(@PathVariable Long id) {
        pluginService.uninstall(UserContext.getUserId(), id);
        return ApiResponse.success(null);
    }
}
