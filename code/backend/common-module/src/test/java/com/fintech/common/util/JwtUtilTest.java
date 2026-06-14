package com.fintech.common.util;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.test.util.ReflectionTestUtils;

/** Unit tests for the JWT helper, covering the userId claim added for cross-service scoping. */
class JwtUtilTest {

  private JwtUtil jwtUtil;
  private UserDetails userDetails;

  @BeforeEach
  void setUp() {
    jwtUtil = new JwtUtil();
    // HS256 requires a key of at least 32 bytes; inject a long shared secret.
    ReflectionTestUtils.setField(
        jwtUtil, "secret", "paynext-test-secret-key-that-is-long-enough-1234567890");
    userDetails = User.withUsername("alice").password("encoded").roles("USER").build();
  }

  @Test
  void generateToken_withUserId_embedsRecoverableClaim() {
    String token = jwtUtil.generateToken(userDetails, 42L);

    assertEquals("alice", jwtUtil.getUsernameFromToken(token));
    assertEquals(42L, jwtUtil.getUserIdFromToken(token));
  }

  @Test
  void generateToken_withoutUserId_hasNoUserIdClaim() {
    String token = jwtUtil.generateToken(userDetails);

    assertEquals("alice", jwtUtil.getUsernameFromToken(token));
    assertNull(jwtUtil.getUserIdFromToken(token));
  }

  @Test
  void generatedToken_validatesForMatchingUsername() {
    String token = jwtUtil.generateToken(userDetails, 7L);

    org.junit.jupiter.api.Assertions.assertTrue(jwtUtil.validateToken(token, "alice"));
    org.junit.jupiter.api.Assertions.assertFalse(jwtUtil.validateToken(token, "bob"));
  }
}
