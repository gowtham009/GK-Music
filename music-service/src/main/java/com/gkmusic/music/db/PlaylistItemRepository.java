package com.gkmusic.music.db;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.UUID;

public interface PlaylistItemRepository extends JpaRepository<PlaylistItem, UUID> {
    List<PlaylistItem> findByPlaylistIdOrderByPositionAsc(UUID playlistId);

    void deleteByPlaylistId(UUID playlistId);
}

