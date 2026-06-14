package com.fintech.paymentservice.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.csrf;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fintech.paymentservice.client.NotificationClient;
import com.fintech.paymentservice.client.UserClient;
import com.fintech.paymentservice.model.Payment;
import com.fintech.paymentservice.model.PaymentMethod;
import com.fintech.paymentservice.model.PaymentRequest;
import com.fintech.paymentservice.service.PaymentService;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.web.servlet.MockMvc;

@WebMvcTest(PaymentController.class)
class PaymentControllerTest {

  @Autowired private MockMvc mockMvc;
  @MockBean private PaymentService paymentService;
  @MockBean private UserClient userClient;
  @MockBean private NotificationClient notificationClient;
  @Autowired private ObjectMapper objectMapper;

  private Payment testPayment;

  @BeforeEach
  void setUp() {
    testPayment = new Payment();
    testPayment.setId(1L);
    testPayment.setUserId(100L);
    testPayment.setAmount(new BigDecimal("100.00"));
    testPayment.setPaymentDate(LocalDateTime.now());
    testPayment.setStatus("COMPLETED");
  }

  @Test
  @WithMockUser
  void processPayment_shouldReturnCreated() throws Exception {
    when(paymentService.processPayment(any(Payment.class))).thenReturn(testPayment);

    mockMvc
        .perform(
            post("/payments")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(testPayment)))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.userId").value(testPayment.getUserId()))
        .andExpect(jsonPath("$.status").value(testPayment.getStatus()));
  }

  @Test
  @WithMockUser
  void getAllPayments_shouldReturnList() throws Exception {
    Payment second = new Payment();
    second.setId(2L);
    second.setUserId(200L);
    second.setAmount(new BigDecimal("200.00"));
    second.setPaymentDate(LocalDateTime.now());
    second.setStatus("PENDING");

    List<Payment> payments = Arrays.asList(testPayment, second);
    when(paymentService.getAllPayments()).thenReturn(payments);

    mockMvc
        .perform(get("/payments").contentType(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[0].userId").value(testPayment.getUserId()))
        .andExpect(jsonPath("$[1].userId").value(second.getUserId()));
  }

  @Test
  @WithMockUser
  void getPaymentById_whenFound_shouldReturnOk() throws Exception {
    when(paymentService.getPaymentById(1L)).thenReturn(testPayment);

    mockMvc
        .perform(get("/payments/1").contentType(MediaType.APPLICATION_JSON))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.userId").value(testPayment.getUserId()));
  }

  @Test
  @WithMockUser
  void getPaymentById_whenNotFound_shouldReturnNotFound() throws Exception {
    when(paymentService.getPaymentById(999L)).thenReturn(null);

    mockMvc
        .perform(get("/payments/999").contentType(MediaType.APPLICATION_JSON))
        .andExpect(status().isNotFound());
  }

  @Test
  @WithMockUser
  void getPayments_whenUserScoped_shouldReturnOnlyUserPayments() throws Exception {
    when(paymentService.getPaymentsByUserId(100L)).thenReturn(Arrays.asList(testPayment));

    mockMvc
        .perform(get("/payments").requestAttr("userId", 100L))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[0].userId").value(100));
  }

  @Test
  @WithMockUser
  void getBalance_shouldReturnBalanceAndCurrency() throws Exception {
    when(paymentService.getBalanceForUser(100L)).thenReturn(new BigDecimal("250.00"));

    mockMvc
        .perform(get("/payments/balance").requestAttr("userId", 100L))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.currency").value("USD"))
        .andExpect(jsonPath("$.balance").value(250.00));
  }

  @Test
  @WithMockUser
  void getPaymentMethods_shouldReturnList() throws Exception {
    PaymentMethod method = new PaymentMethod();
    method.setId(1L);
    method.setUserId(100L);
    method.setType("card");
    method.setProvider("visa");
    method.setLast4("4242");
    when(paymentService.getPaymentMethods(100L)).thenReturn(Collections.singletonList(method));

    mockMvc
        .perform(get("/payments/methods").requestAttr("userId", 100L))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$[0].provider").value("visa"))
        .andExpect(jsonPath("$[0].last4").value("4242"));
  }

  @Test
  @WithMockUser
  void addPaymentMethod_shouldReturnCreated() throws Exception {
    PaymentMethod saved = new PaymentMethod();
    saved.setId(5L);
    saved.setUserId(100L);
    saved.setType("card");
    saved.setProvider("mastercard");
    when(paymentService.addPaymentMethod(any(), any(PaymentMethod.class))).thenReturn(saved);

    PaymentMethod body = new PaymentMethod();
    body.setType("card");
    body.setProvider("mastercard");

    mockMvc
        .perform(
            post("/payments/methods")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body))
                .requestAttr("userId", 100L))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.id").value(5))
        .andExpect(jsonPath("$.provider").value("mastercard"));
  }

  @Test
  @WithMockUser
  void createPaymentRequest_shouldReturnCreated() throws Exception {
    PaymentRequest saved = new PaymentRequest();
    saved.setId(7L);
    saved.setUserId(100L);
    saved.setAmount(new BigDecimal("50.00"));
    saved.setStatus("PENDING");
    when(paymentService.createPaymentRequest(any(), any(PaymentRequest.class))).thenReturn(saved);

    PaymentRequest body = new PaymentRequest();
    body.setAmount(new BigDecimal("50.00"));

    mockMvc
        .perform(
            post("/payments/requests")
                .with(csrf())
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(body))
                .requestAttr("userId", 100L))
        .andExpect(status().isCreated())
        .andExpect(jsonPath("$.id").value(7))
        .andExpect(jsonPath("$.status").value("PENDING"));
  }
}
