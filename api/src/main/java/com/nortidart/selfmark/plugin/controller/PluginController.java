package com.nortidart.selfmark.plugin.controller;

import com.nortidart.selfmark.common.context.UserContext;
import com.nortidart.selfmark.common.response.ApiResponse;
import com.nortidart.selfmark.plugin.dto.MarketPluginResponse;
import com.nortidart.selfmark.plugin.dto.InstalledPluginResponse;
import com.nortidart.selfmark.plugin.service.PluginService;
import java.util.List;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/plugins")
public class PluginController {
    private final PluginService pluginService;

    public PluginController(PluginService pluginService) {
        this.pluginService = pluginService;
    }

    @GetMapping
    public ApiResponse<List<MarketPluginResponse>> listMarket() {
        return ApiResponse.success(pluginService.listMarket(UserContext.getUserId()));
    }

    @PostMapping("/{code}/install")
    public ApiResponse<InstalledPluginResponse> install(@PathVariable String code) {
        return ApiResponse.success(pluginService.install(UserContext.getUserId(), code));
    }
}
