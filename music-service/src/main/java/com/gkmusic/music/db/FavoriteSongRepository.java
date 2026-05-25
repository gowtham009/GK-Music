package com.gkmusic.music.db;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

public interface FavoriteSongRepository extends JpaRepository<FavoriteSong, UUID> {
    List<FavoriteSong> findByUserIdOrderByCreatedAtDesc(UUID userId);

    Optional<FavoriteSong> findByUserIdAndSongId(UUID userId, UUID songId);
}

