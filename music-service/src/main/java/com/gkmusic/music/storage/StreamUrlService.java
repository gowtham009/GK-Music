package com.gkmusic.music.storage;

import io.minio.GetPresignedObjectUrlArgs;
import io.minio.MinioClient;
import io.minio.http.Method;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.time.Duration;

@Service
public class StreamUrlService {
    private final MinioClient minio;
    private final String bucket;
    private final Duration presignTtl;

    public StreamUrlService(
            MinioClient minio,
            @Value("${minio.bucket}") String bucket,
            @Value("${minio.presign-ttl}") Duration presignTtl
    ) {
        this.minio = minio;
        this.bucket = bucket;
        this.presignTtl = presignTtl;
    }

    public String presignGetUrl(String objectKey) {
        try {
            return minio.getPresignedObjectUrl(GetPresignedObjectUrlArgs.builder()
                    .bucket(bucket)
                    .object(objectKey)
                    .method(Method.GET)
                    .expiry((int) presignTtl.getSeconds())
                    .build());
        } catch (Exception e) {
            throw new IllegalStateException("Failed to create stream URL", e);
        }
    }
}

