package com.fintech.userservice.controller;

import com.fintech.common.util.JwtUtil;
import com.fintech.common.util.PasswordValidator;
import com.fintech.userservice.model.User;
import com.fintech.userservice.model.UserProfile;
import com.fintech.userservice.repository.UserProfileRepository;
import com.fintech.userservice.service.UserPrincipal;
import com.fintech.userservice.service.UserService;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Pattern;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@Slf4j
@RestController
@RequestMapping("/users")
public class UserController {

  private static final Pattern EMAIL_PATTERN =
      Pattern.compile("^[A-Za-z0-9+_.-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$");

  private final UserService userService;
  private final AuthenticationManager authenticationManager;
  private final JwtUtil jwtUtil;
  private final UserProfileRepository userProfileRepository;

  @Autowired
  public UserController(
      UserService userService,
      AuthenticationManager authenticationManager,
      JwtUtil jwtUtil,
      UserProfileRepository userProfileRepository) {
    this.userService = userService;
    this.authenticationManager = authenticationManager;
    this.jwtUtil = jwtUtil;
    this.userProfileRepository = userProfileRepository;
  }

  @PostMapping("/register")
  public ResponseEntity<?> registerUser(@RequestBody User user) {
    if (user.getUsername() == null || user.getUsername().isBlank()) {
      return ResponseEntity.badRequest().body(Map.of("error", "Username is required"));
    }

    if (user.getEmail() == null || user.getEmail().isBlank()) {
      return ResponseEntity.badRequest().body(Map.of("error", "Email is required"));
    }

    if (!EMAIL_PATTERN.matcher(user.getEmail()).matches()) {
      return ResponseEntity.badRequest().body(Map.of("error", "Invalid email format"));
    }

    try {
      PasswordValidator.validate(user.getPassword());
    } catch (IllegalArgumentException e) {
      return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }

    if (userService.findByUsername(user.getUsername()) != null) {
      return ResponseEntity.badRequest().body(Map.of("error", "Username is already taken"));
    }

    if (userService.findByEmail(user.getEmail()) != null) {
      return ResponseEntity.badRequest().body(Map.of("error", "Email address is already in use"));
    }

    try {
      User savedUser = userService.saveUser(user);
      return ResponseEntity.status(HttpStatus.CREATED).body(buildUserMap(savedUser));
    } catch (IllegalArgumentException e) {
      return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
    }
  }

  @PostMapping("/login")
  public ResponseEntity<?> authenticateUser(@RequestBody User loginRequest) {
    if (loginRequest.getUsername() == null || loginRequest.getUsername().isBlank()) {
      return ResponseEntity.badRequest().body(Map.of("error", "Username is required"));
    }

    try {
      Authentication authentication =
          authenticationManager.authenticate(
              new UsernamePasswordAuthenticationToken(
                  loginRequest.getUsername(), loginRequest.getPassword()));
      SecurityContextHolder.getContext().setAuthentication(authentication);
      UserDetails principal = (UserDetails) authentication.getPrincipal();
      Long userId = (principal instanceof UserPrincipal) ? ((UserPrincipal) principal).getId() : null;
      String jwt = jwtUtil.generateToken(principal, userId);
      User user = userService.findByUsername(principal.getUsername());
      return ResponseEntity.ok(new AuthResponse(jwt, buildUserMap(user)));
    } catch (BadCredentialsException e) {
      log.warn("Authentication failed for user: {}", loginRequest.getUsername());
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
          .body(Map.of("error", "Invalid credentials"));
    } catch (Exception e) {
      log.error("Unexpected error during login for user: {}", loginRequest.getUsername(), e);
      return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
          .body(Map.of("error", "An unexpected error occurred"));
    }
  }

  @GetMapping("/me")
  public ResponseEntity<?> getCurrentUser(@AuthenticationPrincipal UserPrincipal principal) {
    if (principal == null) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Unauthorized"));
    }
    User user = userService.findById(principal.getId());
    if (user == null) {
      return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "User not found"));
    }
    return ResponseEntity.ok(buildUserMap(user));
  }

  @GetMapping("/profile")
  public ResponseEntity<?> getProfile(@AuthenticationPrincipal UserPrincipal principal) {
    if (principal == null) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Unauthorized"));
    }
    User user = userService.findById(principal.getId());
    if (user == null) {
      return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "User not found"));
    }
    UserProfile profile = userProfileRepository.findByUser_Id(user.getId()).orElse(null);
    return ResponseEntity.ok(buildProfileMap(user, profile));
  }

  @PutMapping("/profile")
  public ResponseEntity<?> updateProfile(
      @AuthenticationPrincipal UserPrincipal principal, @RequestBody Map<String, Object> body) {
    if (principal == null) {
      return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("error", "Unauthorized"));
    }
    User user = userService.findById(principal.getId());
    if (user == null) {
      return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", "User not found"));
    }

    UserProfile profile =
        userProfileRepository
            .findByUser_Id(user.getId())
            .orElseGet(
                () -> {
                  UserProfile created = new UserProfile();
                  created.setUser(user);
                  return created;
                });

    String firstName = asString(body.get("firstName"));
    String lastName = asString(body.get("lastName"));
    String name = asString(body.get("name"));
    if (firstName != null || lastName != null) {
      if (firstName != null) {
        profile.setFirstName(firstName);
      }
      if (lastName != null) {
        profile.setLastName(lastName);
      }
    } else if (name != null && !name.isBlank()) {
      String[] parts = name.trim().split("\\s+", 2);
      profile.setFirstName(parts[0]);
      profile.setLastName(parts.length > 1 ? parts[1] : parts[0]);
    }
    // The entity requires non-blank first and last names; fall back to the username.
    if (profile.getFirstName() == null || profile.getFirstName().isBlank()) {
      profile.setFirstName(user.getUsername());
    }
    if (profile.getLastName() == null || profile.getLastName().isBlank()) {
      profile.setLastName(user.getUsername());
    }

    String email = asString(body.get("email"));
    if (email != null && !email.isBlank()) {
      profile.setEmail(email);
    }
    String phone = asString(body.containsKey("phoneNumber") ? body.get("phoneNumber") : body.get("phone"));
    if (phone != null && !phone.isBlank()) {
      // Normalize to the entity's expected E.164-like format by stripping separators.
      profile.setPhoneNumber(phone.replaceAll("[^+0-9]", ""));
    }
    if (body.get("address") != null) {
      profile.setAddress(asString(body.get("address")));
    }
    if (body.get("city") != null) {
      profile.setCity(asString(body.get("city")));
    }
    if (body.get("postalCode") != null) {
      profile.setPostalCode(asString(body.get("postalCode")));
    }
    if (body.get("country") != null) {
      profile.setCountry(asString(body.get("country")));
    }

    UserProfile saved = userProfileRepository.save(profile);
    return ResponseEntity.ok(buildProfileMap(user, saved));
  }

  @GetMapping("/{id}")
  public ResponseEntity<?> getUserById(@PathVariable Long id) {
    User user = userService.findById(id);
    if (user == null) {
      return ResponseEntity.status(HttpStatus.NOT_FOUND)
          .body(Map.of("error", "User not found with id: " + id));
    }
    return ResponseEntity.ok(buildUserMap(user));
  }

  private Map<String, Object> buildUserMap(User user) {
    Map<String, Object> map = new HashMap<>();
    map.put("id", user.getId());
    map.put("username", user.getUsername());
    map.put("name", user.getUsername());
    map.put("email", user.getEmail());
    map.put("role", user.getRole());
    return map;
  }

  private Map<String, Object> buildProfileMap(User user, UserProfile profile) {
    Map<String, Object> map = new HashMap<>();
    map.put("id", user.getId());
    map.put("username", user.getUsername());
    if (profile != null) {
      map.put("firstName", profile.getFirstName());
      map.put("lastName", profile.getLastName());
      String fullName =
          ((profile.getFirstName() == null ? "" : profile.getFirstName())
                  + " "
                  + (profile.getLastName() == null ? "" : profile.getLastName()))
              .trim();
      map.put("name", fullName.isBlank() ? user.getUsername() : fullName);
      map.put("email", profile.getEmail() != null ? profile.getEmail() : user.getEmail());
      map.put("phone", profile.getPhoneNumber());
      map.put("phoneNumber", profile.getPhoneNumber());
      map.put("address", profile.getAddress());
      map.put("city", profile.getCity());
      map.put("postalCode", profile.getPostalCode());
      map.put("country", profile.getCountry());
    } else {
      map.put("name", user.getUsername());
      map.put("email", user.getEmail());
    }
    return map;
  }

  private static String asString(Object value) {
    return value == null ? null : value.toString();
  }
}
