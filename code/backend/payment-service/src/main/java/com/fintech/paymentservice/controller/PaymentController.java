package com.fintech.paymentservice.controller;

import com.fintech.paymentservice.model.Payment;
import com.fintech.paymentservice.model.PaymentMethod;
import com.fintech.paymentservice.model.PaymentRequest;
import com.fintech.paymentservice.service.PaymentService;
import jakarta.servlet.http.HttpServletRequest;
import java.math.BigDecimal;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/payments")
public class PaymentController {

  @Autowired private PaymentService paymentService;

  @PostMapping
  public ResponseEntity<Payment> makePayment(
      @RequestBody Payment payment, HttpServletRequest request) {
    Long userId = currentUserId(request);
    if (userId != null) {
      payment.setUserId(userId);
    }
    Payment savedPayment = paymentService.processPayment(payment);
    return new ResponseEntity<>(savedPayment, HttpStatus.CREATED);
  }

  @GetMapping
  public ResponseEntity<List<Payment>> getPayments(HttpServletRequest request) {
    Long userId = currentUserId(request);
    List<Payment> payments =
        userId != null ? paymentService.getPaymentsByUserId(userId) : paymentService.getAllPayments();
    return new ResponseEntity<>(payments, HttpStatus.OK);
  }

  @GetMapping("/balance")
  public ResponseEntity<Map<String, Object>> getBalance(HttpServletRequest request) {
    Long userId = currentUserId(request);
    BigDecimal balance = paymentService.getBalanceForUser(userId);
    Map<String, Object> body = new HashMap<>();
    body.put("balance", balance);
    body.put("currency", "USD");
    return new ResponseEntity<>(body, HttpStatus.OK);
  }

  @GetMapping("/methods")
  public ResponseEntity<List<PaymentMethod>> getPaymentMethods(HttpServletRequest request) {
    Long userId = currentUserId(request);
    return new ResponseEntity<>(paymentService.getPaymentMethods(userId), HttpStatus.OK);
  }

  @PostMapping("/methods")
  public ResponseEntity<PaymentMethod> addPaymentMethod(
      @RequestBody PaymentMethod method, HttpServletRequest request) {
    Long userId = currentUserId(request);
    PaymentMethod saved = paymentService.addPaymentMethod(userId, method);
    return new ResponseEntity<>(saved, HttpStatus.CREATED);
  }

  @PostMapping("/requests")
  public ResponseEntity<PaymentRequest> createPaymentRequest(
      @RequestBody PaymentRequest paymentRequest, HttpServletRequest request) {
    Long userId = currentUserId(request);
    PaymentRequest saved = paymentService.createPaymentRequest(userId, paymentRequest);
    return new ResponseEntity<>(saved, HttpStatus.CREATED);
  }

  @GetMapping("/{id}")
  public ResponseEntity<Payment> getPaymentById(@PathVariable Long id) {
    Payment payment = paymentService.getPaymentById(id);
    if (payment != null) {
      return new ResponseEntity<>(payment, HttpStatus.OK);
    } else {
      return new ResponseEntity<>(HttpStatus.NOT_FOUND);
    }
  }

  private Long currentUserId(HttpServletRequest request) {
    Object attr = request.getAttribute("userId");
    return (attr instanceof Long) ? (Long) attr : null;
  }
}
