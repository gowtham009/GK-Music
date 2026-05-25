package com.gkmusic.music.db;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "song_plays")
public class SongPlay {
    @Id
    private UUID id;

    @Column(name = "user_id", nullable = false)
    private UUID userId;

    @Column(name = "song_id", nullable = false)
    private UUID songId;

    @Column(name = "played_at", nullable = false)
    private Instant playedAt;

    protected SongPlay() {
    }

    public SongPlay(UUID id, UUID userId, UUID songId, Instant playedAt) {
        this.id = id;
        this.userId = userId;
        this.songId = songId;
        this.playedAt = playedAt;
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

    public Instant getPlayedAt() {
        return playedAt;
    }
}

