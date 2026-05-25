package com.gkmusic.music.db;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "favorite_songs")
public class FavoriteSong {
    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "song_id", nullable = false)
    private UUID songId;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected FavoriteSong() {
    }

    public FavoriteSong(UUID id, UUID userId, UUID songId, Instant createdAt) {
        this.id = id;
        this.userId = userId;
        this.songId = songId;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getUserId() {
        return userId;
    }

    public UUID getSongId() {
        return songId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}

