package com.fintech.userservice.exception;

import java.time.LocalDateTime;
import java.util.Map;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;

@Slf4j
@RestControllerAdvice
public class GlobalExceptionHandler {

  @ExceptionHandler(IllegalArgumentException.class)
  public ResponseEntity<Map<String, Object>> handleIllegalArgument(
      IllegalArgumentException ex, WebRequest request) {
    log.warn("Validation error: {}", ex.getMessage());
    return ResponseEntity.badRequest()
        .body(errorBody(HttpStatus.BAD_REQUEST, ex.getMessage(), request));
  }

  @ExceptionHandler(AuthenticationException.class)
  public ResponseEntity<Map<String, Object>> handleAuthentication(
      AuthenticationException ex, WebRequest request) {
    log.warn("Authentication error: {}", ex.getMessage());
    return ResponseEntity.status(HttpStatus.UNAUTHORIZED)
        .body(errorBody(HttpStatus.UNAUTHORIZED, "Authentication failed", request));
  }

  @ExceptionHandler(AccessDeniedException.class)
  public ResponseEntity<Map<String, Object>> handleAccessDenied(
      AccessDeniedException ex, WebRequest request) {
    return ResponseEntity.status(HttpStatus.FORBIDDEN)
        .body(errorBody(HttpStatus.FORBIDDEN, "Access denied", request));
  }

  @ExceptionHandler(RuntimeException.class)
  public ResponseEntity<Map<String, Object>> handleRuntime(
      RuntimeException ex, WebRequest request) {
    log.error("Runtime error: {}", ex.getMessage(), ex);
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(errorBody(HttpStatus.INTERNAL_SERVER_ERROR, "An internal error occurred", request));
  }

  @ExceptionHandler(Exception.class)
  public ResponseEntity<Map<String, Object>> handleGeneral(Exception ex, WebRequest request) {
    log.error("Unexpected error: {}", ex.getMessage(), ex);
    return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
        .body(errorBody(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred", request));
  }

  private Map<String, Object> errorBody(HttpStatus status, String message, WebRequest request) {
    return Map.of(
        "timestamp", LocalDateTime.now().toString(),
        "status", status.value(),
        "error", status.getReasonPhrase(),
        "message", message != null ? message : status.getReasonPhrase(),
        "path", request.getDescription(false).replace("uri=", ""));
  }
}
