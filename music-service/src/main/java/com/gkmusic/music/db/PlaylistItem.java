package com.gkmusic.music.db;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "playlist_items")
public class PlaylistItem {
    @Id
    private UUID id;

    @Column(name = "playlist_id", nullable = false)
    private UUID playlistId;

    @Column(name = "song_id", nullable = false)
    private UUID songId;

    @Column(name = "position", nullable = false)
    private int position;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    protected PlaylistItem() {
    }

    public PlaylistItem(UUID id, UUID playlistId, UUID songId, int position, Instant createdAt) {
        this.id = id;
        this.playlistId = playlistId;
        this.songId = songId;
        this.position = position;
        this.createdAt = createdAt;
    }

    public UUID getId() {
        return id;
    }

    public UUID getPlaylistId() {
        return playlistId;
    }

    public UUID getSongId() {
        return songId;
    }

    public int getPosition() {
        return position;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }
}

