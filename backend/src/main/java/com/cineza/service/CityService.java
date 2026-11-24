package com.cineza.service;

import com.cineza.model.City;
import com.cineza.repository.CityRepository;
import com.fasterxml.jackson.databind.JavaType;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class CityService {

    private final CityRepository cityRepository;
    private final CacheService cacheService;

    public CityService(CityRepository cityRepository, CacheService cacheService) {
        this.cityRepository = cityRepository;
        this.cacheService = cacheService;
    }

    public List<City> getAllCities() {
        String key = "cineza:cache:cities:all";
        JavaType type = cacheService.getObjectMapper().getTypeFactory().constructCollectionType(List.class, City.class);
        return cacheService.getOrComputeList(key, 3600, type, cityRepository::findAll);
    }

    public Optional<City> getCityById(Long id) {
        if (id == null) return Optional.empty();
        String key = "cineza:cache:city:" + id;
        City city = cacheService.getOrCompute(key, 3600, City.class, () -> cityRepository.findById(id).orElse(null));
        return Optional.ofNullable(city);
    }

    public City createCity(City city) {
        City saved = cityRepository.save(city);
        cacheService.evict("cineza:cache:cities:all");
        if (saved.getId() != null) {
            cacheService.evict("cineza:cache:city:" + saved.getId());
        }
        return saved;
    }
}
