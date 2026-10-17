package com.nortidart.selfmark.plugin;

import static org.assertj.core.api.Assertions.assertThat;

import com.nortidart.selfmark.ApiApplication;
import com.nortidart.selfmark.plugin.mapper.PluginMapper;
import java.sql.Connection;
import java.util.List;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.ConfigurableApplicationContext;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.testcontainers.containers.MySQLContainer;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;

@Testcontainers(disabledWithoutDocker = true)
class PluginMigrationTests {
    @Container static final MySQLContainer<?> MYSQL = new MySQLContainer<>("mysql:8.4")
            .withDatabaseName("migration").withUsername("selfmark").withPassword("selfmark");

    @Test
    void upgradesV3AndProductionRestartsPreserveCatalogAndConfig() throws Exception {
        var dataSource = new DriverManagerDataSource(MYSQL.getJdbcUrl(), MYSQL.getUsername(), MYSQL.getPassword());
        var jdbc = new JdbcTemplate(dataSource);
        Flyway.configure().dataSource(dataSource).locations("classpath:db/migration").target("3")
                .load().migrate();
        jdbc.update("""
                INSERT INTO user(mobile,password,username)
                VALUES ('13800404999','test-only-placeholder','Migration Test')
                """);
        long user = jdbc.queryForObject("SELECT id FROM user WHERE mobile='13800404999'", Long.class);
        List<Long> ids;
        try (var first = startProductionContext()) {
            ids = jdbc.queryForList("SELECT id FROM plugin ORDER BY sort,id", Long.class);
            assertThat(ids).hasSize(2);
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user", Integer.class)).isEqualTo(1);
            assertThat(first.getBean(PluginMapper.class).selectMarket(user)).hasSize(2);
            jdbc.update("INSERT INTO user_plugin(user_id,plugin_id,config,enabled) VALUES (?,?,?,0)",
                    user, ids.getFirst(), "{\"custom\":\"保留配置\"}");
        }
        try (var second = startProductionContext()) {
            assertThat(jdbc.queryForList("SELECT id FROM plugin ORDER BY sort,id", Long.class)).isEqualTo(ids);
            var market = second.getBean(PluginMapper.class).selectMarket(user);
            assertThat(market.getFirst().getEnabled()).isFalse();
            assertThat(market.getFirst().getConfig().get("custom").asText()).isEqualTo("保留配置");
            assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user WHERE mobile='13800138001'", Integer.class))
                    .isZero();
        }
        try (Connection connection = dataSource.getConnection()) {
            ScriptUtils.executeSqlScript(connection, new ClassPathResource("db/migration/V5__seed_builtin_plugins.sql"));
            ScriptUtils.executeSqlScript(connection, new ClassPathResource("db/migration/V5__seed_builtin_plugins.sql"));
        }
        assertThat(jdbc.queryForList("SELECT id FROM plugin ORDER BY sort,id", Long.class)).isEqualTo(ids);
        assertThat(jdbc.queryForObject("SELECT COUNT(*) FROM user_plugin WHERE user_id=?", Integer.class, user))
                .isEqualTo(1);
        assertThat(Flyway.configure().dataSource(dataSource).locations("classpath:db/migration")
                .load().validateWithResult().validationSuccessful).isTrue();
    }

    private ConfigurableApplicationContext startProductionContext() {
        return new SpringApplicationBuilder(ApiApplication.class).web(WebApplicationType.NONE).run(
                "--spring.profiles.active=prod",
                "--spring.datasource.url=" + MYSQL.getJdbcUrl(),
                "--spring.datasource.username=" + MYSQL.getUsername(),
                "--spring.datasource.password=" + MYSQL.getPassword(),
                "--spring.flyway.locations=classpath:db/migration",
                "--selfmark.jwt.secret=selfmark-migration-test-secret-at-least-32-characters",
                "--management.health.defaults.enabled=false");
    }
}
