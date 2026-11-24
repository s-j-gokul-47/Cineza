package com.cineza;

import com.cineza.config.DataInitializer;
import com.cineza.model.City;
import com.cineza.repository.*;
import com.cineza.security.JwtTokenProvider;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.AbstractPlatformTransactionManager;
import org.springframework.transaction.support.DefaultTransactionStatus;

import java.time.Duration;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class MultiReplicaSetupTest {

    private static PlatformTransactionManager noOpTxManager() {
        return new AbstractPlatformTransactionManager() {
            @Override
            protected Object doGetTransaction() {
                return new Object();
            }

            @Override
            protected void doBegin(Object transaction, TransactionDefinition definition) {}

            @Override
            protected void doCommit(DefaultTransactionStatus status) {}

            @Override
            protected void doRollback(DefaultTransactionStatus status) {}
        };
    }

    @SuppressWarnings("unchecked")
    private static ObjectProvider<StringRedisTemplate> providerFor(StringRedisTemplate template) {
        ObjectProvider<StringRedisTemplate> provider = mock(ObjectProvider.class);
        when(provider.getIfAvailable()).thenReturn(template);
        return provider;
    }

    @Test
    @SuppressWarnings("unchecked")
    void dataInitializerSkipsSeedingWhenPeerHoldsRedisLock() {
        CityRepository cityRepo = mock(CityRepository.class);
        // First check sees 0 (unseeded), then inside waitForPeerSeeding sees peer completed (4)
        when(cityRepo.count()).thenReturn(0L, 4L);

        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> valueOps = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(valueOps);
        when(valueOps.setIfAbsent(eq("cineza:init:seed-lock"), anyString(), any(Duration.class)))
                .thenReturn(false);

        DataInitializer initializer = new DataInitializer(
                cityRepo,
                mock(TheatreRepository.class),
                mock(ScreenRepository.class),
                mock(SeatRepository.class),
                mock(MovieRepository.class),
                mock(ShowRepository.class),
                mock(BookingRepository.class),
                mock(BookingSeatRepository.class),
                providerFor(redis),
                noOpTxManager()
        );

        initializer.run();

        verify(cityRepo, never()).save(any(City.class));
        verify(redis, never()).delete("cineza:init:seed-lock");
    }

    @Test
    @SuppressWarnings("unchecked")
    void dataInitializerReleasesRedisSeedLockEvenIfIntegrityExceptionOccurs() {
        CityRepository cityRepo = mock(CityRepository.class);
        when(cityRepo.count()).thenReturn(0L);
        when(cityRepo.save(any(City.class))).thenThrow(new DataIntegrityViolationException("duplicate"));

        StringRedisTemplate redis = mock(StringRedisTemplate.class);
        ValueOperations<String, String> valueOps = mock(ValueOperations.class);
        when(redis.opsForValue()).thenReturn(valueOps);

        final String[] capturedToken = new String[1];
        when(valueOps.setIfAbsent(eq("cineza:init:seed-lock"), anyString(), any(Duration.class)))
                .thenAnswer(inv -> {
                    capturedToken[0] = inv.getArgument(1);
                    return true;
                });
        when(valueOps.get("cineza:init:seed-lock")).thenAnswer(inv -> capturedToken[0]);

        DataInitializer initializer = new DataInitializer(
                cityRepo,
                mock(TheatreRepository.class),
                mock(ScreenRepository.class),
                mock(SeatRepository.class),
                mock(MovieRepository.class),
                mock(ShowRepository.class),
                mock(BookingRepository.class),
                mock(BookingSeatRepository.class),
                providerFor(redis),
                noOpTxManager()
        );

        assertDoesNotThrow(() -> initializer.run());
        verify(redis).delete("cineza:init:seed-lock");
    }

    @Test
    void jwtTokenProviderFallsBackWhenSecretBlankAndUsesSharedEnvSecretWhenSet() {
        JwtTokenProvider fallbackProvider = new JwtTokenProvider("", 86400000L);
        String fallbackToken = fallbackProvider.generateTokenFromEmail("guest@cineza.com");
        assertTrue(fallbackProvider.validateToken(fallbackToken));
        assertEquals("guest@cineza.com", fallbackProvider.getEmailFromJWT(fallbackToken));

        String sharedSecret = "shared-replica-secret-value-at-least-64-characters-long-for-hs512-000";
        JwtTokenProvider replicaA = new JwtTokenProvider(sharedSecret, 86400000L);
        JwtTokenProvider replicaB = new JwtTokenProvider(sharedSecret, 86400000L);

        String tokenFromA = replicaA.generateTokenFromEmail("viewer@cineza.com");
        assertTrue(replicaB.validateToken(tokenFromA));
        assertEquals("viewer@cineza.com", replicaB.getEmailFromJWT(tokenFromA));
    }
}
