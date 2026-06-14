package com.fintech.paymentservice.service;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.*;

import com.fintech.paymentservice.client.NotificationClient;
import com.fintech.paymentservice.client.UserClient;
import com.fintech.paymentservice.dto.UserDTO;
import com.fintech.paymentservice.model.NotificationRequest;
import com.fintech.paymentservice.model.Payment;
import com.fintech.paymentservice.model.PaymentMethod;
import com.fintech.paymentservice.model.PaymentRequest;
import com.fintech.paymentservice.repository.PaymentMethodRepository;
import com.fintech.paymentservice.repository.PaymentRepository;
import com.fintech.paymentservice.repository.PaymentRequestRepository;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.ResponseEntity;

@ExtendWith(MockitoExtension.class)
class PaymentServiceImplTest {

  @Mock private PaymentRepository paymentRepository;
  @Mock private PaymentMethodRepository paymentMethodRepository;
  @Mock private PaymentRequestRepository paymentRequestRepository;
  @Mock private NotificationClient notificationClient;
  @Mock private UserClient userClient;

  @InjectMocks private PaymentServiceImpl paymentService;

  private Payment testPayment;

  @BeforeEach
  void setUp() {
    testPayment = new Payment();
    testPayment.setUserId(100L);
    testPayment.setAmount(new BigDecimal("100.00"));
    testPayment.setPaymentDate(LocalDateTime.now());
    testPayment.setStatus("COMPLETED");
  }

  @Test
  void processPayment_shouldSaveAndNotify() {
    when(paymentRepository.save(any(Payment.class))).thenAnswer(inv -> {
      Payment p = inv.getArgument(0);
      p.setId(1L);
      return p;
    });
    when(userClient.getUserById(anyLong()))
        .thenReturn(new UserDTO(100L, "Test User", "user@example.com"));
    when(notificationClient.sendNotification(any(NotificationRequest.class)))
        .thenReturn(ResponseEntity.ok().build());

    Payment result = paymentService.processPayment(testPayment);

    assertNotNull(result);
    assertNotNull(result.getId());
    assertEquals(testPayment.getUserId(), result.getUserId());
    verify(paymentRepository).save(testPayment);
    verify(notificationClient).sendNotification(any(NotificationRequest.class));
  }

  @Test
  void processPayment_withNullDate_shouldDefaultDate() {
    testPayment.setPaymentDate(null);
    when(paymentRepository.save(any(Payment.class))).thenAnswer(inv -> inv.getArgument(0));
    when(userClient.getUserById(anyLong()))
        .thenReturn(new UserDTO(100L, "Test User", "user@example.com"));
    when(notificationClient.sendNotification(any())).thenReturn(ResponseEntity.ok().build());

    Payment result = paymentService.processPayment(testPayment);

    assertNotNull(result.getPaymentDate());
  }

  @Test
  void processPayment_whenNotificationFails_shouldStillReturnPayment() {
    when(paymentRepository.save(any(Payment.class))).thenAnswer(inv -> {
      Payment p = inv.getArgument(0);
      p.setId(1L);
      return p;
    });
    when(userClient.getUserById(anyLong()))
        .thenReturn(new UserDTO(100L, "Test User", "user@example.com"));
    when(notificationClient.sendNotification(any()))
        .thenThrow(new RuntimeException("Notification unavailable"));

    Payment result = paymentService.processPayment(testPayment);

    assertNotNull(result);
    assertNotNull(result.getId());
  }

  @Test
  void processPayment_whenUserServiceFails_shouldStillNotify() {
    when(paymentRepository.save(any(Payment.class))).thenAnswer(inv -> {
      Payment p = inv.getArgument(0);
      p.setId(1L);
      return p;
    });
    when(userClient.getUserById(anyLong()))
        .thenThrow(new RuntimeException("User service down"));
    when(notificationClient.sendNotification(any())).thenReturn(ResponseEntity.ok().build());

    Payment result = paymentService.processPayment(testPayment);

    assertNotNull(result);
    verify(notificationClient).sendNotification(any(NotificationRequest.class));
  }

  @Test
  void getAllPayments_shouldReturnList() {
    Payment second = new Payment();
    second.setId(2L);
    second.setUserId(200L);
    second.setAmount(new BigDecimal("200.00"));
    second.setPaymentDate(LocalDateTime.now());
    second.setStatus("PENDING");

    when(paymentRepository.findAll()).thenReturn(Arrays.asList(testPayment, second));

    List<Payment> result = paymentService.getAllPayments();

    assertEquals(2, result.size());
    verify(paymentRepository).findAll();
  }

  @Test
  void getPaymentById_whenFound_shouldReturn() {
    testPayment.setId(1L);
    when(paymentRepository.findById(1L)).thenReturn(Optional.of(testPayment));

    Payment found = paymentService.getPaymentById(1L);

    assertNotNull(found);
    assertEquals(1L, found.getId());
  }

  @Test
  void getPaymentById_whenNotFound_shouldReturnNull() {
    when(paymentRepository.findById(999L)).thenReturn(Optional.empty());

    assertNull(paymentService.getPaymentById(999L));
  }

  @Test
  void getPaymentsByUserId_shouldReturnUserPayments() {
    when(paymentRepository.findByUserId(100L)).thenReturn(Arrays.asList(testPayment));

    List<Payment> result = paymentService.getPaymentsByUserId(100L);

    assertEquals(1, result.size());
    verify(paymentRepository).findByUserId(100L);
  }

  @Test
  void getBalanceForUser_shouldSumPaymentAmounts() {
    Payment second = new Payment();
    second.setUserId(100L);
    second.setAmount(new BigDecimal("200.00"));
    when(paymentRepository.findByUserId(100L)).thenReturn(Arrays.asList(testPayment, second));

    BigDecimal balance = paymentService.getBalanceForUser(100L);

    assertEquals(0, new BigDecimal("300.00").compareTo(balance));
  }

  @Test
  void getBalanceForUser_whenUserIdNull_shouldReturnZero() {
    assertEquals(0, BigDecimal.ZERO.compareTo(paymentService.getBalanceForUser(null)));
  }

  @Test
  void getPaymentMethods_shouldReturnUserMethods() {
    PaymentMethod method = new PaymentMethod();
    method.setUserId(100L);
    method.setProvider("visa");
    when(paymentMethodRepository.findByUserId(100L)).thenReturn(Arrays.asList(method));

    List<PaymentMethod> result = paymentService.getPaymentMethods(100L);

    assertEquals(1, result.size());
    assertEquals("visa", result.get(0).getProvider());
  }

  @Test
  void addPaymentMethod_shouldSetUserIdAndSave() {
    when(paymentMethodRepository.save(any(PaymentMethod.class)))
        .thenAnswer(inv -> inv.getArgument(0));
    PaymentMethod method = new PaymentMethod();
    method.setProvider("mastercard");

    PaymentMethod saved = paymentService.addPaymentMethod(100L, method);

    assertEquals(100L, saved.getUserId());
    assertEquals("mastercard", saved.getProvider());
    verify(paymentMethodRepository).save(method);
  }

  @Test
  void createPaymentRequest_shouldSetUserIdAndDefaultStatus() {
    when(paymentRequestRepository.save(any(PaymentRequest.class)))
        .thenAnswer(inv -> inv.getArgument(0));
    PaymentRequest request = new PaymentRequest();
    request.setAmount(new BigDecimal("50.00"));

    PaymentRequest saved = paymentService.createPaymentRequest(100L, request);

    assertEquals(100L, saved.getUserId());
    assertEquals("PENDING", saved.getStatus());
    verify(paymentRequestRepository).save(request);
  }
}
