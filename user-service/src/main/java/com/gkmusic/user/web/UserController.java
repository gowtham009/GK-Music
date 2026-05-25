package com.gkmusic.user.web;

import com.gkmusic.user.db.UserProfile;
import com.gkmusic.user.db.UserProfileRepository;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

@RestController
@RequestMapping("/users")
public class UserController {
    private final UserProfileRepository profiles;
    private final Clock clock = Clock.systemUTC();

    public UserController(UserProfileRepository profiles) {
        this.profiles = profiles;
    }

    @GetMapping("/health")
    public String health() {
        return "ok";
    }

    @GetMapping("/me")
    public UserProfileResponse me(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt) {
        UUID userId = UUID.fromString(jwt.getSubject());
        String email = jwt.getClaimAsString("email");
        String displayName = jwt.getClaimAsString("name");

        UserProfile profile = profiles.findById(userId)
                .orElseGet(() -> profiles.save(new UserProfile(userId, email, displayName, Instant.now(clock))));

        return new UserProfileResponse(profile.getId(), profile.getEmail(), profile.getDisplayName(), profile.getCreatedAt());
    }

    @PutMapping("/me")
    public UserProfileResponse update(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt,
                                      @RequestBody @Valid UpdateMeRequest req) {
        UUID userId = UUID.fromString(jwt.getSubject());
        UserProfile profile = profiles.findById(userId)
                .orElseGet(() -> profiles.save(new UserProfile(
                        userId,
                        jwt.getClaimAsString("email"),
                        jwt.getClaimAsString("name"),
                        Instant.now(clock)
                )));

        profile.setDisplayName(req.displayName());
        profiles.save(profile);

        return new UserProfileResponse(profile.getId(), profile.getEmail(), profile.getDisplayName(), profile.getCreatedAt());
    }

    public record UpdateMeRequest(@NotBlank @Size(min = 2, max = 80) String displayName) {
    }

    public record UserProfileResponse(UUID id, String email, String displayName, Instant createdAt) {
    }
}

