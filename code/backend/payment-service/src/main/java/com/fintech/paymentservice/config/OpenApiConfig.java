package com.fintech.paymentservice.config;

import io.swagger.v3.oas.models.Components;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.info.Info;
import io.swagger.v3.oas.models.security.SecurityRequirement;
import io.swagger.v3.oas.models.security.SecurityScheme;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class OpenApiConfig {

  private static final String SCHEME = "bearerAuth";

  @Bean
  public OpenAPI paymentServiceOpenAPI() {
    return new OpenAPI()
        .info(
            new Info()
                .title("PayNext Payment Service API")
                .version("1.0.0")
                .description(
                    "Payments, balance, saved payment methods, and payment requests."))
        .components(
            new Components()
                .addSecuritySchemes(
                    SCHEME,
                    new SecurityScheme()
                        .type(SecurityScheme.Type.HTTP)
                        .scheme("bearer")
                        .bearerFormat("JWT")))
        .addSecurityItem(new SecurityRequirement().addList(SCHEME));
  }
}
