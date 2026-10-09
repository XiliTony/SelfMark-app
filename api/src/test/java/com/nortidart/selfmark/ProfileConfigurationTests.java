package com.nortidart.selfmark;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

class ProfileConfigurationTests {
    @Test
    void productionProfileDoesNotReadLocalConfigurationOrDevdata() {
        new ApplicationContextRunner()
                .withInitializer(new ConfigDataApplicationContextInitializer())
                .withPropertyValues("spring.profiles.active=prod")
                .run(context -> {
                    assertThat(context.getEnvironment().getProperty("spring.datasource.username"))
                            .isNotEqualTo("selfmark");
                    assertThat(context.getEnvironment().getProperty("spring.flyway.locations[0]"))
                            .isEqualTo("classpath:db/migration");
                    assertThat(context.getEnvironment().getProperty("spring.flyway.locations[1]"))
                            .isNull();
                });
    }

    @Test
    void localProfileExplicitlyLoadsLocalConfigurationAndDevdata() {
        new ApplicationContextRunner()
                .withInitializer(new ConfigDataApplicationContextInitializer())
                .withPropertyValues("spring.profiles.active=local")
                .run(context -> {
                    assertThat(context.getEnvironment().getProperty("spring.datasource.username"))
                            .isEqualTo("selfmark");
                    assertThat(context.getEnvironment().getProperty("spring.flyway.locations[1]"))
                            .isEqualTo("classpath:db/devdata");
                });
    }

    @Test
    void testProfileLoadsDevdataWithoutLocalConfiguration() {
        new ApplicationContextRunner()
                .withInitializer(new ConfigDataApplicationContextInitializer())
                .withPropertyValues("spring.profiles.active=test")
                .run(context -> {
                    assertThat(context.getEnvironment().getProperty("spring.datasource.username"))
                            .isNotEqualTo("selfmark");
                    assertThat(context.getEnvironment().getProperty("spring.flyway.locations[1]"))
                            .isEqualTo("classpath:db/devdata");
                });
    }

    @Test
    void productionProfileWinsOverDevelopmentSeedLocation() {
        new ApplicationContextRunner()
                .withInitializer(new ConfigDataApplicationContextInitializer())
                .withPropertyValues("spring.profiles.active=prod,local")
                .run(context -> {
                    assertThat(context.getEnvironment().getProperty("spring.flyway.locations[0]"))
                            .isEqualTo("classpath:db/migration");
                    assertThat(context.getEnvironment().getProperty("spring.flyway.locations[1]"))
                            .isNull();
                });
    }

    @Test
    void noProfileDoesNotImplicitlyLoadLocalConfiguration() {
        new ApplicationContextRunner()
                .withInitializer(new ConfigDataApplicationContextInitializer())
                .run(context -> {
                    assertThat(context.getEnvironment().getProperty("spring.datasource.username"))
                            .isNotEqualTo("selfmark");
                    assertThat(context.getEnvironment().getProperty("spring.flyway.locations[1]"))
                            .isNull();
                });
    }
}
