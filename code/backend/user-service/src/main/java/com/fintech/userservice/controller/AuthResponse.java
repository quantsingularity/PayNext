package com.fintech.userservice.controller;

import java.util.Map;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AuthResponse {
  private String token;
  private Map<String, Object> user;

  public AuthResponse(String token) {
    this.token = token;
  }
}
