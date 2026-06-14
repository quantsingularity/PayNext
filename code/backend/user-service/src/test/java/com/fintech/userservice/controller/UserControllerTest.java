package com.fintech.userservice.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fintech.common.util.JwtUtil;
import com.fintech.userservice.config.RateLimitConfig;
import com.fintech.userservice.filter.JwtAuthenticationFilter;
import com.fintech.userservice.model.User;
import com.fintech.userservice.model.UserProfile;
import com.fintech.userservice.repository.OTPVerificationRepository;
import com.fintech.userservice.repository.UserProfileRepository;
import com.fintech.userservice.repository.UserRepository;
import com.fintech.userservice.service.AuditService;
import com.fintech.userservice.service.UserPrincipal;
import com.fintech.userservice.service.UserService;
import org.springframework.mail.javamail.JavaMailSender;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.ConsumptionProbe;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

/**
 * Slice test for UserController using @WebMvcTest.
 *
 * <p>@WebMvcTest loads the full web layer (controllers, filters, security config) but NOT
 * service/repository beans. All dependencies of filters and config classes must be provided
 * as @MockBean so Spring can wire the application context correctly.
 */
@WebMvcTest(UserController.class)
class UserControllerTest {

  @Autowired private MockMvc mockMvc;
  @Autowired private ObjectMapper objectMapper;

  // ── Controller dependencies ────────────────────────────────────────────────
  @MockBean private UserService userService;
  @MockBean private AuthenticationManager authenticationManager;
  @MockBean private JwtUtil jwtUtil;
  @MockBean private UserProfileRepository userProfileRepository;

  // ── SecurityConfig / JwtAuthenticationFilter dependencies ─────────────────
  @MockBean private UserDetailsService userDetailsService;

  /**
   * JwtAuthenticationFilter is a @Component picked up by @WebMvcTest. We register a mock but
   * must configure it to call chain.doFilter() so requests actually reach the controller.
   * Without this, the mock absorbs all requests and returns empty 200 responses.
   */
  @MockBean private JwtAuthenticationFilter jwtAuthenticationFilter;

  @BeforeEach
  void setUpJwtFilter() throws Exception {
    // Make the JWT filter a transparent pass-through — delegate to the next filter in chain
    org.mockito.Mockito.doAnswer(
            inv -> {
              jakarta.servlet.FilterChain chain = inv.getArgument(2);
              chain.doFilter(inv.getArgument(0), inv.getArgument(1));
              return null;
            })
        .when(jwtAuthenticationFilter)
        .doFilter(any(), any(), any());
  }

  // ── AuditFilter dependencies ───────────────────────────────────────────────
  @MockBean private AuditService auditService;
  @MockBean private UserRepository userRepository;

  // ── RateLimitFilter dependencies ──────────────────────────────────────────
  @MockBean private RateLimitConfig rateLimitConfig;

  // ── OTPServiceImpl dependencies ───────────────────────────────────────────
  @MockBean private OTPVerificationRepository otpVerificationRepository;
  @MockBean private JavaMailSender javaMailSender;

  private User testUser;

  @BeforeEach
  void setUp() {
    testUser = new User();
    testUser.setId(1L);
    testUser.setUsername("testuser");
    testUser.setEmail("test@example.com");
    testUser.setPassword("Password1@");
    testUser.setRole("ROLE_USER");

    // Make RateLimitFilter always allow requests through in tests
    Bucket mockBucket = mock(Bucket.class);
    ConsumptionProbe mockProbe = mock(ConsumptionProbe.class);
    when(mockProbe.isConsumed()).thenReturn(true);
    when(mockProbe.getRemainingTokens()).thenReturn(99L);
    when(mockBucket.tryConsumeAndReturnRemaining(1)).thenReturn(mockProbe);
    when(rateLimitConfig.getLoginBucket(any())).thenReturn(mockBucket);
    when(rateLimitConfig.getOTPBucket(any())).thenReturn(mockBucket);
    when(rateLimitConfig.getRegistrationBucket(any())).thenReturn(mockBucket);
    when(rateLimitConfig.getAPIBucket(any())).thenReturn(mockBucket);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  private String toJson(Map<String, String> body) throws Exception {
    return objectMapper.writeValueAsString(body);
  }

  private Map<String, String> registerBody(String username, String password, String email) {
    Map<String, String> body = new HashMap<>();
    body.put("username", username);
    body.put("password", password);
    body.put("email", email);
    return body;
  }

  private Map<String, String> loginBody(String username, String password) {
    Map<String, String> body = new HashMap<>();
    body.put("username", username);
    body.put("password", password);
    return body;
  }

  // ── Registration tests ─────────────────────────────────────────────────────

  @Test
  void register_withValidUser_shouldReturnCreated() throws Exception {
    when(userService.findByUsername(anyString())).thenReturn(null);
    when(userService.findByEmail(anyString())).thenReturn(null);
    when(userService.saveUser(any(User.class))).thenReturn(testUser);

    mockMvc
        .perform(
            post("/users/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(registerBody("testuser", "Password1@", "test@example.com"))))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.username").value("testuser"))
        .andExpect(jsonPath("$.email").value("test@example.com"));
  }

  @Test
  void register_withExistingUsername_shouldReturnBadRequest() throws Exception {
    when(userService.findByUsername(anyString())).thenReturn(testUser);

    mockMvc
        .perform(
            post("/users/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(registerBody("testuser", "Password1@", "test@example.com"))))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("Username is already taken"));
  }

  @Test
  void register_withExistingEmail_shouldReturnBadRequest() throws Exception {
    when(userService.findByUsername(anyString())).thenReturn(null);
    when(userService.findByEmail(anyString())).thenReturn(testUser);

    mockMvc
        .perform(
            post("/users/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(registerBody("newuser", "Password1@", "test@example.com"))))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("Email address is already in use"));
  }

  @Test
  void register_withInvalidPassword_shouldReturnBadRequest() throws Exception {
    mockMvc
        .perform(
            post("/users/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(registerBody("testuser", "weak", "test@example.com"))))
        .andExpect(status().isBadRequest());
  }

  @Test
  void register_withInvalidEmail_shouldReturnBadRequest() throws Exception {
    mockMvc
        .perform(
            post("/users/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(registerBody("testuser", "Password1@", "not-an-email"))))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("Invalid email format"));
  }

  @Test
  void register_withBlankUsername_shouldReturnBadRequest() throws Exception {
    mockMvc
        .perform(
            post("/users/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(registerBody("", "Password1@", "test@example.com"))))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("Username is required"));
  }

  @Test
  void register_withBlankEmail_shouldReturnBadRequest() throws Exception {
    mockMvc
        .perform(
            post("/users/register")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(registerBody("testuser", "Password1@", ""))))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("Email is required"));
  }

  // ── Login tests ────────────────────────────────────────────────────────────

  @Test
  void login_withValidCredentials_shouldReturnToken() throws Exception {
    UserDetails mockUserDetails =
        org.springframework.security.core.userdetails.User.withUsername("testuser")
            .password("encodedPassword")
            .roles("USER")
            .build();

    org.springframework.security.core.Authentication auth =
        new UsernamePasswordAuthenticationToken(
            mockUserDetails, null, mockUserDetails.getAuthorities());

    when(authenticationManager.authenticate(any())).thenReturn(auth);
    when(jwtUtil.generateToken(any(UserDetails.class), any())).thenReturn("mock-jwt-token");
    when(userService.findByUsername("testuser")).thenReturn(testUser);

    mockMvc
        .perform(
            post("/users/login")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(loginBody("testuser", "Password1@"))))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.token").value("mock-jwt-token"))
        .andExpect(jsonPath("$.user.username").value("testuser"));
  }

  @Test
  void login_withInvalidCredentials_shouldReturnUnauthorized() throws Exception {
    when(authenticationManager.authenticate(any()))
        .thenThrow(new BadCredentialsException("Bad credentials"));

    mockMvc
        .perform(
            post("/users/login")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(loginBody("testuser", "wrongpassword"))))
        .andExpect(status().isUnauthorized())
        .andExpect(jsonPath("$.error").value("Invalid credentials"));
  }

  @Test
  void login_withBlankUsername_shouldReturnBadRequest() throws Exception {
    mockMvc
        .perform(
            post("/users/login")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(toJson(loginBody("", "Password1@"))))
        .andExpect(status().isBadRequest())
        .andExpect(jsonPath("$.error").value("Username is required"));
  }

  // ── GetUser tests ──────────────────────────────────────────────────────────

  @Test
  @WithMockUser
  void getUserById_whenFound_shouldReturnOk() throws Exception {
    when(userService.findById(1L)).thenReturn(testUser);

    mockMvc
        .perform(get("/users/1").contentType(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.id").value(1))
        .andExpect(jsonPath("$.username").value("testuser"))
        .andExpect(jsonPath("$.email").value("test@example.com"))
        .andExpect(jsonPath("$.role").value("ROLE_USER"));
  }

  @Test
  @WithMockUser
  void getUserById_whenNotFound_shouldReturnNotFound() throws Exception {
    when(userService.findById(999L)).thenReturn(null);

    mockMvc
        .perform(get("/users/999").contentType(MediaType.APPLICATION_JSON))
        .andExpect(status().isNotFound())
        .andExpect(jsonPath("$.error").value("User not found with id: 999"));
  }

  @Test
  void getUserById_withoutAuthentication_shouldReturnUnauthorized() throws Exception {
    mockMvc
        .perform(get("/users/1").contentType(MediaType.APPLICATION_JSON))
        .andExpect(status().isUnauthorized());
  }

  // ── Current user and profile tests ─────────────────────────────────────────

  private UsernamePasswordAuthenticationToken principalAuth() {
    UserPrincipal principal =
        new UserPrincipal(
            1L,
            "testuser",
            "encoded",
            true,
            Collections.singletonList(new SimpleGrantedAuthority("ROLE_USER")));
    return new UsernamePasswordAuthenticationToken(principal, null, principal.getAuthorities());
  }

  @Test
  void getCurrentUser_whenAuthenticated_shouldReturnUser() throws Exception {
    when(userService.findById(1L)).thenReturn(testUser);

    mockMvc
        .perform(get("/users/me").with(authentication(principalAuth())))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.id").value(1))
        .andExpect(jsonPath("$.username").value("testuser"))
        .andExpect(jsonPath("$.email").value("test@example.com"))
        .andExpect(jsonPath("$.role").value("ROLE_USER"));
  }

  @Test
  void getProfile_whenNoProfileExists_shouldReturnUserDerivedProfile() throws Exception {
    when(userService.findById(1L)).thenReturn(testUser);
    when(userProfileRepository.findByUser_Id(1L)).thenReturn(Optional.empty());

    mockMvc
        .perform(get("/users/profile").with(authentication(principalAuth())))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.username").value("testuser"))
        .andExpect(jsonPath("$.name").value("testuser"))
        .andExpect(jsonPath("$.email").value("test@example.com"));
  }

  @Test
  void updateProfile_shouldUpsertAndReturnProfile() throws Exception {
    when(userService.findById(1L)).thenReturn(testUser);
    when(userProfileRepository.findByUser_Id(1L)).thenReturn(Optional.empty());
    when(userProfileRepository.save(any(UserProfile.class)))
        .thenAnswer(invocation -> invocation.getArgument(0));

    Map<String, String> body = new HashMap<>();
    body.put("name", "Jane Doe");
    body.put("phone", "+1 555 0142");
    body.put("city", "Lisbon");

    mockMvc
        .perform(
            put("/users/profile")
                .with(csrf())
                .with(authentication(principalAuth()))
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body)))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.firstName").value("Jane"))
        .andExpect(jsonPath("$.lastName").value("Doe"))
        .andExpect(jsonPath("$.phoneNumber").value("+15550142"))
        .andExpect(jsonPath("$.city").value("Lisbon"));
  }
}
