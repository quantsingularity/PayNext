package com.fintech.apigateway.config;

import org.springframework.cloud.gateway.route.RouteLocator;
import org.springframework.cloud.gateway.route.builder.RouteLocatorBuilder;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Explicit gateway routes that expose a single, consistent public API contract under
 * the /api prefix and forward to the backend services discovered via Eureka.
 *
 * Incoming public path        rewritten to        forwarded to
 * /api/users/**           ->  /users/**       ->  user-service
 * /api/payments/**        ->  /payments/**    ->  payment-service
 * /api/notifications/**   ->  /notifications/** ->  notification-service
 *
 * The RewritePath replacement uses a named capture group, which is why these routes
 * are defined in Java rather than in properties or YAML: there the ${segment}
 * replacement collides with Spring's own ${...} property placeholder resolution.
 */
@Configuration
public class GatewayRoutesConfig {

  @Bean
  public RouteLocator paynextRoutes(RouteLocatorBuilder builder) {
    return builder
        .routes()
        .route(
            "user-service",
            r ->
                r.path("/api/users/**")
                    .filters(f -> f.rewritePath("/api/(?<segment>.*)", "/${segment}"))
                    .uri("lb://user-service"))
        .route(
            "payment-service",
            r ->
                r.path("/api/payments/**")
                    .filters(f -> f.rewritePath("/api/(?<segment>.*)", "/${segment}"))
                    .uri("lb://payment-service"))
        .route(
            "notification-service",
            r ->
                r.path("/api/notifications/**")
                    .filters(f -> f.rewritePath("/api/(?<segment>.*)", "/${segment}"))
                    .uri("lb://notification-service"))
        .build();
  }
}
