package com.nortidart.selfmark.auth.security;

import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.interfaces.DecodedJWT;
import com.nortidart.selfmark.config.JwtProperties;
import java.time.Instant;
import java.util.Date;
import java.util.UUID;
import org.springframework.stereotype.Component;

@Component
public class JwtUtil {

    private static final String ISSUER = "selfmark";
    private final JwtProperties properties;
    private final Algorithm algorithm;
    private final JWTVerifier verifier;

    public JwtUtil(JwtProperties properties) {
        if (properties.secret() == null || properties.secret().length() < 32) {
            throw new IllegalStateException("selfmark.jwt.secret must contain at least 32 characters");
        }
        this.properties = properties;
        this.algorithm = Algorithm.HMAC256(properties.secret());
        this.verifier = JWT.require(algorithm).withIssuer(ISSUER).build();
    }

    public String issue(Long userId, String role) {
        return issue(userId, null, role);
    }

    public String issue(Long userId, String mobile, String role) {
        Instant now = Instant.now();
        Instant expiresAt = now.plus(properties.ttl());
        var builder = JWT.create()
                .withIssuer(ISSUER)
                .withJWTId(UUID.randomUUID().toString())
                .withSubject(String.valueOf(userId))
                .withClaim("userId", userId)
                .withClaim("role", role)
                .withIssuedAt(Date.from(now))
                .withExpiresAt(Date.from(expiresAt));
        if (mobile != null) {
            builder.withClaim("mobile", mobile);
        }
        return builder.sign(algorithm);
    }

    public DecodedJWT parse(String token) {
        return verifier.verify(token);
    }

    public long getRemainingTtl(String token) {
        return Math.max(0, parse(token).getExpiresAt().toInstant().getEpochSecond() - Instant.now().getEpochSecond());
    }
}
