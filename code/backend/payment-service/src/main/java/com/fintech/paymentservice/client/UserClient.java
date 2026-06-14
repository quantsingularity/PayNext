package com.fintech.paymentservice.client;

import com.fintech.paymentservice.dto.UserDTO;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cloud.openfeign.FeignClient;
import org.springframework.stereotype.Component;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;

@FeignClient(name = "user-service", fallback = UserClient.UserClientFallback.class)
public interface UserClient {

  @GetMapping("/users/{id}")
  UserDTO getUserById(@PathVariable("id") Long id);

  @Component
  class UserClientFallback implements UserClient {
    private static final Logger logger = LoggerFactory.getLogger(UserClientFallback.class);

    @Override
    public UserDTO getUserById(Long id) {
      logger.warn("User service is down. Using fallback for user ID: {}", id);
      return new UserDTO(id, "Unknown User", "unknown@example.com");
    }
  }
}
