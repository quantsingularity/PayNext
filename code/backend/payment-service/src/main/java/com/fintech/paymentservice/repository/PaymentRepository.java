package com.fintech.paymentservice.repository;

import com.fintech.paymentservice.model.Payment;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
  List<Payment> findByUserId(Long userId);
}
