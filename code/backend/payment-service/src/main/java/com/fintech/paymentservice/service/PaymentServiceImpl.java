package com.fintech.paymentservice.service;

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
import java.util.List;
import java.util.Optional;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Slf4j
@Transactional
public class PaymentServiceImpl implements PaymentService {

  @Autowired private PaymentRepository paymentRepository;

  @Autowired private PaymentMethodRepository paymentMethodRepository;

  @Autowired private PaymentRequestRepository paymentRequestRepository;

  @Autowired private NotificationClient notificationClient;

  @Autowired private UserClient userClient;

  @Override
  public Payment processPayment(Payment payment) {
    if (payment.getPaymentDate() == null) {
      payment.setPaymentDate(LocalDateTime.now());
    }
    if (payment.getStatus() == null || payment.getStatus().isBlank()) {
      payment.setStatus("PENDING");
    }

    Payment savedPayment = paymentRepository.save(payment);

    try {
      String recipientEmail = resolveRecipientEmail(payment.getUserId());
      NotificationRequest notificationRequest =
          new NotificationRequest(
              recipientEmail,
              "Your payment of "
                  + payment.getAmount()
                  + " has been processed successfully. Reference ID: "
                  + savedPayment.getId());
      notificationRequest.setSubject("PayNext — Payment Confirmation");
      notificationClient.sendNotification(notificationRequest);
    } catch (Exception e) {
      log.warn(
          "Failed to send payment notification for payment id {}: {}",
          savedPayment.getId(),
          e.getMessage());
    }

    return savedPayment;
  }

  @Override
  @Transactional(readOnly = true)
  public List<Payment> getAllPayments() {
    return paymentRepository.findAll();
  }

  @Override
  @Transactional(readOnly = true)
  public Payment getPaymentById(Long id) {
    Optional<Payment> payment = paymentRepository.findById(id);
    return payment.orElse(null);
  }

  @Override
  @Transactional(readOnly = true)
  public List<Payment> getPaymentsByUserId(Long userId) {
    return paymentRepository.findByUserId(userId);
  }

  @Override
  @Transactional(readOnly = true)
  public BigDecimal getBalanceForUser(Long userId) {
    if (userId == null) {
      return BigDecimal.ZERO;
    }
    return paymentRepository.findByUserId(userId).stream()
        .map(Payment::getAmount)
        .filter(amount -> amount != null)
        .reduce(BigDecimal.ZERO, BigDecimal::add);
  }

  @Override
  @Transactional(readOnly = true)
  public List<PaymentMethod> getPaymentMethods(Long userId) {
    return paymentMethodRepository.findByUserId(userId);
  }

  @Override
  public PaymentMethod addPaymentMethod(Long userId, PaymentMethod method) {
    method.setUserId(userId);
    return paymentMethodRepository.save(method);
  }

  @Override
  public PaymentRequest createPaymentRequest(Long userId, PaymentRequest request) {
    request.setUserId(userId);
    if (request.getStatus() == null || request.getStatus().isBlank()) {
      request.setStatus("PENDING");
    }
    return paymentRequestRepository.save(request);
  }

  private String resolveRecipientEmail(Long userId) {
    try {
      UserDTO user = userClient.getUserById(userId);
      if (user != null && user.getEmail() != null && !user.getEmail().isBlank()) {
        return user.getEmail();
      }
    } catch (Exception e) {
      log.warn("Could not fetch user email for userId {}: {}", userId, e.getMessage());
    }
    return String.valueOf(userId);
  }
}
