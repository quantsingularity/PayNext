package com.fintech.common.util;

import io.jsonwebtoken.*;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Date;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.stereotype.Component;

@Slf4j
@Component
public class JwtUtil {

  @Value("${jwt.secret}")
  private String secret;

  private final long expiration = 604800000L;

  private Key getSigningKey() {
    byte[] keyBytes = secret.getBytes(StandardCharsets.UTF_8);
    return Keys.hmacShaKeyFor(keyBytes);
  }

  public String generateToken(UserDetails userDetails) {
    return generateToken(userDetails, null);
  }

  /**
   * Generate a token and, when a userId is provided, embed it as a "userId" claim so
   * downstream services can scope data to the authenticated user without an extra
   * lookup. The existing single-argument overload is preserved for compatibility.
   */
  public String generateToken(UserDetails userDetails, Long userId) {
    Date now = new Date();
    Date expiryDate = new Date(now.getTime() + expiration);

    JwtBuilder builder =
        Jwts.builder()
            .setSubject(userDetails.getUsername())
            .claim(
                "role",
                userDetails.getAuthorities().stream()
                    .findFirst()
                    .map(Object::toString)
                    .orElse("USER"));
    if (userId != null) {
      builder.claim("userId", userId);
    }

    return builder
        .setIssuedAt(now)
        .setExpiration(expiryDate)
        // HS256 requires a 256-bit (32-byte) key. The shared default secret is 59 bytes,
        // which is below the 512-bit minimum HS512 demands and caused a WeakKeyException at
        // token generation. Parsing auto-detects the algorithm from the JWT header, so
        // existing validation across services continues to work unchanged.
        .signWith(getSigningKey(), SignatureAlgorithm.HS256)
        .compact();
  }

  /** Return the userId claim embedded in the token, or null if absent or unparseable. */
  public Long getUserIdFromToken(String token) {
    try {
      Claims claims = extractAllClaims(token);
      if (claims == null) {
        return null;
      }
      Object userId = claims.get("userId");
      if (userId == null) {
        return null;
      }
      return Long.valueOf(String.valueOf(userId));
    } catch (Exception e) {
      log.error("Error extracting userId from token: {}", e.getMessage());
      return null;
    }
  }

  public String getUsernameFromToken(String token) {
    try {
      Claims claims =
          Jwts.parserBuilder()
              .setSigningKey(getSigningKey())
              .build()
              .parseClaimsJws(token)
              .getBody();
      return claims.getSubject();
    } catch (io.jsonwebtoken.security.SecurityException ex) {
      log.error("Invalid JWT signature: {}", ex.getMessage());
    } catch (MalformedJwtException ex) {
      log.error("Invalid JWT token: {}", ex.getMessage());
    } catch (ExpiredJwtException ex) {
      log.error("Expired JWT token: {}", ex.getMessage());
    } catch (UnsupportedJwtException ex) {
      log.error("Unsupported JWT token: {}", ex.getMessage());
    } catch (IllegalArgumentException ex) {
      log.error("JWT claims string is empty: {}", ex.getMessage());
    }
    return null;
  }

  public boolean validateToken(String token, String username) {
    try {
      String extractedUsername = getUsernameFromToken(token);
      return extractedUsername != null
          && extractedUsername.equals(username)
          && !isTokenExpired(token);
    } catch (Exception e) {
      log.error("Error validating token: {}", e.getMessage());
      return false;
    }
  }

  private boolean isTokenExpired(String token) {
    try {
      Claims claims =
          Jwts.parserBuilder()
              .setSigningKey(getSigningKey())
              .build()
              .parseClaimsJws(token)
              .getBody();
      return claims.getExpiration().before(new Date());
    } catch (ExpiredJwtException ex) {
      return true;
    } catch (Exception ex) {
      log.error("Error checking token expiration: {}", ex.getMessage());
      return true;
    }
  }

  public Claims extractAllClaims(String token) {
    try {
      return Jwts.parserBuilder()
          .setSigningKey(getSigningKey())
          .build()
          .parseClaimsJws(token)
          .getBody();
    } catch (Exception e) {
      log.error("Error extracting claims from token: {}", e.getMessage());
      return null;
    }
  }
}
