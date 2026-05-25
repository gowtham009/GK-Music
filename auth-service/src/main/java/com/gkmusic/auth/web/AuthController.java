package com.gkmusic.auth.web;

import com.gkmusic.auth.db.AuthUser;
import com.gkmusic.auth.db.AuthUserRepository;
import com.gkmusic.auth.jwt.JwtService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/auth")
public class AuthController {
    private final AuthUserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final Clock clock = Clock.systemUTC();

    public AuthController(AuthUserRepository users, PasswordEncoder passwordEncoder, JwtService jwtService) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    @PostMapping("/register")
    public RegisterResponse register(@RequestBody @Valid RegisterRequest req) {
        users.findByEmailIgnoreCase(req.email()).ifPresent(u -> {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Email already registered");
        });

        UUID id = UUID.randomUUID();
        AuthUser user = new AuthUser(
                id,
                req.email().toLowerCase(),
                passwordEncoder.encode(req.password()),
                req.displayName(),
                Instant.now(clock)
        );
        users.save(user);

        String token = jwtService.mintAccessToken(user.getId(), user.getEmail(), user.getDisplayName());
        return new RegisterResponse(user.getId(), user.getEmail(), user.getDisplayName(), token);
    }

    @PostMapping("/login")
    public LoginResponse login(@RequestBody @Valid LoginRequest req) {
        AuthUser user = users.findByEmailIgnoreCase(req.email())
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials"));

        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw new ResponseStatusException(HttpStatus.UNAUTHORIZED, "Invalid credentials");
        }

        String token = jwtService.mintAccessToken(user.getId(), user.getEmail(), user.getDisplayName());
        return new LoginResponse(token);
    }

    public record RegisterRequest(
            @Email @NotBlank String email,
            @Size(min = 8, max = 200) String password,
            @NotBlank @Size(min = 2, max = 80) String displayName
    ) {
    }

    public record RegisterResponse(UUID id, String email, String displayName, String accessToken) {
    }

    public record LoginRequest(@Email @NotBlank String email, @NotBlank String password) {
    }

    public record LoginResponse(String accessToken) {
    }
}

