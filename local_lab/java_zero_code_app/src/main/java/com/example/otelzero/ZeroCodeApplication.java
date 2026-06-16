package com.example.otelzero;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@SpringBootApplication
@RestController
public class ZeroCodeApplication {
    public static void main(String[] args) {
        SpringApplication.run(ZeroCodeApplication.class, args);
    }

    @GetMapping("/")
    public Map<String, Object> root() {
        return Map.of(
                "service", "java-zero-code",
                "message", "This Spring Boot app is instrumented by the OpenTelemetry Java agent.",
                "try", new String[] {"/hello", "/checkout", "/error"});
    }

    @GetMapping("/hello")
    public Map<String, Object> hello() {
        return Map.of("status", "ok", "service", "java-zero-code");
    }

    @GetMapping("/checkout")
    public Map<String, Object> checkout() throws InterruptedException {
        int sleepMs = ThreadLocalRandom.current().nextInt(30, 160);
        Thread.sleep(sleepMs);
        return Map.of(
                "status", "accepted",
                "orderId", UUID.randomUUID().toString().substring(0, 8),
                "sleepMs", sleepMs);
    }

    @GetMapping("/error")
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public Map<String, Object> error() {
        return Map.of("status", "error", "detail", "intentional zero-code demo error");
    }
}
