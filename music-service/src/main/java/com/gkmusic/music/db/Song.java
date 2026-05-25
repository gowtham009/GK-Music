package com.gkmusic.music.db;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

import java.time.Duration;
import java.util.UUID;

@Entity
@Table(name = "songs")
public class Song {
    @Id
    private UUID id;

    @Column(nullable = false)
    private String title;

    @Column(nullable = false)
    private String artist;

    @Column(nullable = false)
    private String album;

    @Column(name = "duration_seconds", nullable = false)
    private long durationSeconds;

    @Column(name = "object_key", nullable = false)
    private String objectKey;

    protected Song() {
    }

    public Song(UUID id, String title, String artist, String album, Duration duration, String objectKey) {
        this.id = id;
        this.title = title;
        this.artist = artist;
        this.album = album;
        this.durationSeconds = duration.getSeconds();
        this.objectKey = objectKey;
    }

    public UUID getId() {
        return id;
    }

    public String getTitle() {
        return title;
    }

    public String getArtist() {
        return artist;
    }

    public String getAlbum() {
        return album;
    }

    public Duration getDuration() {
        return Duration.ofSeconds(durationSeconds);
    }

    public String getObjectKey() {
        return objectKey;
    }
}

