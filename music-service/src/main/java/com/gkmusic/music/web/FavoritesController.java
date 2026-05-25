package com.gkmusic.music.web;

import com.gkmusic.music.db.FavoriteSong;
import com.gkmusic.music.db.FavoriteSongRepository;
import com.gkmusic.music.db.SongRepository;
import org.springframework.http.HttpStatus;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/favorites")
public class FavoritesController {
    private final FavoriteSongRepository favorites;
    private final SongRepository songs;
    private final Clock clock = Clock.systemUTC();

    public FavoritesController(FavoriteSongRepository favorites, SongRepository songs) {
        this.favorites = favorites;
        this.songs = songs;
    }

    @GetMapping
    public List<MusicController.SongResponse> list(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt) {
        UUID userId = UUID.fromString(jwt.getSubject());
        var ids = favorites.findByUserIdOrderByCreatedAtDesc(userId).stream().map(FavoriteSong::getSongId).toList();
        return songs.findAllById(ids).stream().map(MusicController.SongResponse::from).toList();
    }

    @PostMapping("/{songId}")
    @ResponseStatus(HttpStatus.CREATED)
    public void add(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt, @PathVariable("songId") UUID songId) {
        UUID userId = UUID.fromString(jwt.getSubject());
        songs.findById(songId).orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Song not found"));

        favorites.findByUserIdAndSongId(userId, songId).ifPresent(existing -> {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Already favorited");
        });

        favorites.save(new FavoriteSong(UUID.randomUUID(), userId, songId, Instant.now(clock)));
    }

    @DeleteMapping("/{songId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void remove(@org.springframework.security.core.annotation.AuthenticationPrincipal Jwt jwt, @PathVariable("songId") UUID songId) {
        UUID userId = UUID.fromString(jwt.getSubject());
        favorites.findByUserIdAndSongId(userId, songId).ifPresent(favorites::delete);
    }
}
