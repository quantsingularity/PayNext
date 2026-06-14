package com.fintech.paymentservice.repository;

import com.fintech.paymentservice.model.PaymentRequest;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PaymentRequestRepository extends JpaRepository<PaymentRequest, Long> {
  List<PaymentRequest> findByUserId(Long userId);
}
