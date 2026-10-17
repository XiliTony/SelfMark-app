package com.nortidart.selfmark.plugin.service;

import com.fasterxml.jackson.databind.node.JsonNodeFactory;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.stereotype.Component;

@Component
public class DefaultPluginConfigFactory {
    public ObjectNode create(String code) {
        return switch (code) {
            case "quadrant-board" -> board();
            case "pomodoro" -> JsonNodeFactory.instance.objectNode().put("label", "专注");
            default -> throw new IllegalStateException("Missing default config for plugin code: " + code);
        };
    }

    private ObjectNode board() {
        var root = JsonNodeFactory.instance.objectNode();
        root.put("active", "quadrant");
        var quadrant = root.putObject("quadrant");
        quadrant.put("xAxisLabel", "紧急度");
        quadrant.put("yAxisLabel", "重要度");
        var regions = quadrant.putArray("regions");
        regions.addObject().put("key", "q1").put("name", "重要且紧急");
        regions.addObject().put("key", "q2").put("name", "重要不紧急");
        regions.addObject().put("key", "q3").put("name", "紧急不重要");
        regions.addObject().put("key", "q4").put("name", "不重要不紧急");
        var pyramid = root.putObject("pyramid").putArray("regions");
        pyramid.addObject().put("key", "p1").put("name", "顶层目标");
        pyramid.addObject().put("key", "p2").put("name", "中层计划");
        pyramid.addObject().put("key", "p3").put("name", "底层行动");
        return root;
    }
}
