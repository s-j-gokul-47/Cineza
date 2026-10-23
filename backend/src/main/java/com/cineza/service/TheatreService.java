package com.cineza.service;

import com.cineza.model.Theatre;
import com.cineza.repository.TheatreRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Optional;

@Service
public class TheatreService {

    private final TheatreRepository theatreRepository;

    public TheatreService(TheatreRepository theatreRepository) {
        this.theatreRepository = theatreRepository;
    }

    public List<Theatre> getAllTheatres() {
        return theatreRepository.findAll();
    }

    public List<Theatre> getTheatresByCity(Long cityId) {
        if (cityId == null) {
            return theatreRepository.findAll();
        }
        return theatreRepository.findByCityId(cityId);
    }

    public Optional<Theatre> getTheatreById(Long id) {
        return theatreRepository.findById(id);
    }
}
