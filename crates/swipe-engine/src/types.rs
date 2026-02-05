use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Clone, Copy, Debug)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct Prediction {
    pub word: String,
    pub score: f64,
    pub freq: f64,
}

pub struct Dictionary {
    pub words: Vec<String>,
    pub freq: HashMap<String, f64>,
}

impl Dictionary {
    pub fn new() -> Self {
        Self {
            words: Vec::new(),
            freq: HashMap::new(),
        }
    }

    pub fn load_from_text(&mut self, freq_text: &str) {
        let mut words = Vec::new();
        let mut freq_map = HashMap::new();
        let mut max_freq: f64 = 0.0;

        let lines: Vec<&str> = freq_text.lines().collect();

        for line in &lines {
            if let Some((_, count_str)) = line.split_once('\t') {
                if let Ok(count) = count_str.parse::<f64>() {
                    max_freq = max_freq.max(count);
                }
            }
        }

        for line in &lines {
            if let Some((word, count_str)) = line.split_once('\t') {
                let word = word.trim().to_lowercase();
                if word.is_empty() {
                    continue;
                }
                words.push(word.clone());
                if let Ok(count) = count_str.parse::<f64>() {
                    let log_freq = (count.ln() - 1.0) / max_freq.ln();
                    freq_map.insert(word, log_freq.max(0.0));
                }
            }
        }

        self.words = words;
        self.freq = freq_map;
    }
}

impl Default for Dictionary {
    fn default() -> Self {
        Self::new()
    }
}
