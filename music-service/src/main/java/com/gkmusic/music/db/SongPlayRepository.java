package com.gkmusic.music.db;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface SongPlayRepository extends JpaRepository<SongPlay, UUID> {
    List<SongPlay> findTop50ByUserIdOrderByPlayedAtDesc(UUID userId);
}

