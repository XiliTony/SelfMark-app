package com.nortidart.selfmark.auth.dto;

import com.nortidart.selfmark.auth.entity.User;

public record AuthResponse(Long id, String mobile, String username, String token) {
    public static AuthResponse from(User user, String token) {
        return new AuthResponse(user.getId(), user.getMobile(), user.getUsername(), token);
    }
}
