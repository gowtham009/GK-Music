package com.gkmusic.auth.jwt;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Map;
import java.util.UUID;

@Service
public class JwtService {
    private final SecretKey key;
    private final Clock clock;
    private final Duration accessTokenTtl;

    public JwtService(
            @Value("${security.jwt.secret}") String secret,
            @Value("${security.jwt.access-token-ttl}") Duration accessTokenTtl
    ) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.clock = Clock.systemUTC();
        this.accessTokenTtl = accessTokenTtl;
    }

    public String mintAccessToken(UUID userId, String email, String displayName) {
        Instant now = clock.instant();
        Instant exp = now.plus(accessTokenTtl);

        return Jwts.builder()
                .issuer("gk-music")
                .subject(userId.toString())
                .issuedAt(Date.from(now))
                .expiration(Date.from(exp))
                .claims(Map.of(
                        "email", email,
                        "name", displayName
                ))
                .signWith(key, Jwts.SIG.HS256)
                .compact();
    }
}

