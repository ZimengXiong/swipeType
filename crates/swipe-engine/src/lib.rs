//! Swipe typing prediction engine

pub mod dtw;
pub mod keyboard;
pub mod types;

#[cfg(feature = "wasm")]
pub mod wasm;

#[cfg(feature = "wasm")]
pub use wasm::*;

#[cfg(feature = "ffi")]
pub mod ffi;

use dtw::dtw_distance_fast;
use keyboard::{euclidean_dist, get_keyboard_layout, get_word_path, simplify_path};
use std::collections::HashMap;
use types::{Dictionary, Point, Prediction};

pub use dtw::{dtw_distance, dtw_distance_fast as dtw_fast};
pub use keyboard::{
    euclidean_dist as euclidean_distance, get_keyboard_layout as keyboard_layout,
    get_word_path as word_path, simplify_path as path_simplify,
};
pub use types::Point as PointType;

/// The main swipe typing prediction engine
pub struct SwipeEngine {
    dictionary: Dictionary,
    layout: HashMap<char, Point>,
    pop_weight: f64,

    by_first_letter: HashMap<char, Vec<usize>>,
    word_paths: Vec<Vec<Point>>,
}

impl SwipeEngine {
    pub fn new() -> Self {
        Self {
            dictionary: Dictionary::new(),
            layout: get_keyboard_layout(),
            pop_weight: 0.25,
            by_first_letter: HashMap::new(),
            word_paths: Vec::new(),
        }
    }

    pub fn set_pop_weight(&mut self, weight: f64) {
        self.pop_weight = weight;
    }

    pub fn load_dictionary(&mut self, freq_text: &str) {
        self.dictionary.load_from_text(freq_text);
        self.build_index();
    }

    fn build_index(&mut self) {
        self.by_first_letter.clear();
        self.word_paths.clear();
        self.word_paths.reserve(self.dictionary.words.len());
        for (idx, word) in self.dictionary.words.iter().enumerate() {
            if let Some(first) = word.chars().next() {
                self.by_first_letter
                    .entry(first)
                    .or_insert_with(Vec::new)
                    .push(idx);
            }
            let raw_path = get_word_path(word, &self.layout);
            self.word_paths.push(simplify_path(&raw_path));
        }
    }

    pub fn word_count(&self) -> usize {
        self.dictionary.words.len()
    }

    pub fn predict(&self, swipe_input: &str, limit: usize) -> Vec<Prediction> {
        let raw_input_path = get_word_path(swipe_input, &self.layout);
        if raw_input_path.is_empty() {
            return vec![];
        }

        let input_path = simplify_path(&raw_input_path);
        let input_len = input_path.len() as f64;

        let first_char = match swipe_input.chars().next() {
            Some(c) => c.to_ascii_lowercase(),
            None => return vec![],
        };
        let last_char = swipe_input.chars().last().unwrap().to_ascii_lowercase();
        let first_char_pt = self
            .layout
            .get(&first_char)
            .cloned()
            .unwrap_or(Point { x: 0.0, y: 0.0 });
        let last_char_pt = self
            .layout
            .get(&last_char)
            .cloned()
            .unwrap_or(Point { x: 0.0, y: 0.0 });

        let candidate_indices = match self.by_first_letter.get(&first_char) {
            Some(indices) => indices,
            None => return vec![],
        };

        let window = (input_path.len() / 2).max(10);
        let mut best_score = f64::INFINITY;

        let mut candidates: Vec<(String, f64, f64)> = candidate_indices
            .iter()
            .filter_map(|&idx| {
                let w = &self.dictionary.words[idx];

                let word_last_char = w.chars().last().unwrap();
                let mut end_penalty = 0.0;
                if word_last_char != last_char {
                    if let Some(word_last_pt) = self.layout.get(&word_last_char) {
                        end_penalty = euclidean_dist(&last_char_pt, word_last_pt) * 5.0;
                    } else {
                        end_penalty = 50.0;
                    }
                }

                let cutoff = best_score * input_len;
                let word_path = &self.word_paths[idx];
                let dist = dtw_distance_fast(&input_path, word_path, window, cutoff);

                if dist == f64::INFINITY {
                    return None;
                }

                let score = (dist + end_penalty) / input_len;
                if score < best_score {
                    best_score = score;
                }

                let word_freq = *self.dictionary.freq.get(w.as_str()).unwrap_or(&0.0);
                Some((w.clone(), score, word_freq))
            })
            .collect();

        candidates.sort_by(|a, b| {
            let combined_a = a.1 - a.2 * self.pop_weight;
            let combined_b = b.1 - b.2 * self.pop_weight;
            combined_a
                .partial_cmp(&combined_b)
                .unwrap_or(std::cmp::Ordering::Equal)
        });

        candidates
            .into_iter()
            .take(limit)
            .map(|(word, score, freq)| Prediction { word, score, freq })
            .collect()
    }
}

impl Default for SwipeEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_engine_creation() {
        let engine = SwipeEngine::new();
        assert_eq!(engine.word_count(), 0);
    }

    #[test]
    fn test_dictionary_loading() {
        let mut engine = SwipeEngine::new();
        engine.load_dictionary("hello\t1000\nworld\t500\n");
        assert_eq!(engine.word_count(), 2);
    }

    #[test]
    fn test_prediction() {
        let mut engine = SwipeEngine::new();
        engine.load_dictionary("hello\t1000\nhello\t1000\nhelp\t800\nhell\t600\n");

        let predictions = engine.predict("hello", 5);
        assert!(!predictions.is_empty());
        assert!(predictions.iter().any(|p| p.word == "hello"));
    }
}
