package com.nortidart.selfmark.plugin.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.junit.jupiter.api.Test;

class DefaultPluginConfigFactoryTests {
    private final DefaultPluginConfigFactory factory = new DefaultPluginConfigFactory();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Test
    void completeBoardDefaultsAndNestedObjectsAreIndependent() throws Exception {
        var expected = objectMapper.readTree("""
                {
                  "active":"quadrant",
                  "quadrant":{
                    "xAxisLabel":"紧急度","yAxisLabel":"重要度",
                    "regions":[
                      {"key":"q1","name":"重要且紧急"},
                      {"key":"q2","name":"重要不紧急"},
                      {"key":"q3","name":"紧急不重要"},
                      {"key":"q4","name":"不重要不紧急"}
                    ]
                  },
                  "pyramid":{"regions":[
                    {"key":"p1","name":"顶层目标"},
                    {"key":"p2","name":"中层计划"},
                    {"key":"p3","name":"底层行动"}
                  ]}
                }
                """);
        var a = factory.create("quadrant-board");
        var b = factory.create("quadrant-board");
        assertThat(a).isEqualTo(expected).isNotSameAs(b);
        a.put("active", "pyramid");
        ((ObjectNode) a.at("/quadrant/regions/0")).put("name", "changed");
        ((ObjectNode) a.at("/pyramid/regions/0")).put("name", "changed");
        assertThat(b).isEqualTo(expected);
        assertThat(factory.create("quadrant-board")).isEqualTo(expected);
    }

    @Test
    void completePomodoroDefaultsAreIndependent() throws Exception {
        var a = factory.create("pomodoro");
        var b = factory.create("pomodoro");
        assertThat(a).isEqualTo(objectMapper.readTree("{\"label\":\"专注\"}"));
        assertThat(a).isNotSameAs(b);
        a.put("label", "changed");
        assertThat(b.get("label").asText()).isEqualTo("专注");
        assertThat(factory.create("pomodoro")).isEqualTo(b);
    }

    @Test
    void missingDefaultsFailExplicitly() {
        assertThatThrownBy(() -> factory.create("unconfigured"))
                .isInstanceOf(IllegalStateException.class).hasMessageContaining("unconfigured");
    }
}
