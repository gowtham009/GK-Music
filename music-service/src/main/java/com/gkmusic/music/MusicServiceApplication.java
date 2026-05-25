package com.gkmusic.music;

import com.gkmusic.music.db.Song;
import com.gkmusic.music.db.SongRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

import java.time.Duration;
import java.util.UUID;

@SpringBootApplication
public class MusicServiceApplication {
    public static void main(String[] args) {
        SpringApplication.run(MusicServiceApplication.class, args);
    }

    @Bean
    CommandLineRunner seedSongs(SongRepository songs) {
        return args -> {
            if (songs.count() > 0) return;
            songs.save(new Song(UUID.randomUUID(), "Sample Track", "GK Artist", "GK Album", Duration.ofSeconds(210), "sample.mp3"));
        };
    }
}

