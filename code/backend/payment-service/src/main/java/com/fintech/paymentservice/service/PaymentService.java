package com.fintech.paymentservice.service;

import com.fintech.paymentservice.model.Payment;
import com.fintech.paymentservice.model.PaymentMethod;
import com.fintech.paymentservice.model.PaymentRequest;
import java.math.BigDecimal;
import java.util.List;

public interface PaymentService {
  Payment processPayment(Payment payment);

  List<Payment> getAllPayments();

  Payment getPaymentById(Long id);

  List<Payment> getPaymentsByUserId(Long userId);

  BigDecimal getBalanceForUser(Long userId);

  List<PaymentMethod> getPaymentMethods(Long userId);

  PaymentMethod addPaymentMethod(Long userId, PaymentMethod method);

  PaymentRequest createPaymentRequest(Long userId, PaymentRequest request);
}
