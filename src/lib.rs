use std::cell::RefCell;
use std::collections::HashMap;
use wasm_bindgen::prelude::*;
use serde::Serialize;

#[derive(Clone, Copy)]
pub struct Point {
    pub x: f64,
    pub y: f64,
}

pub fn get_keyboard_layout() -> HashMap<char, Point> {
    let mut layout = HashMap::new();
    let rows = [
        ("qwertyuiop", 0.0, 0.0),
        ("asdfghjkl", 0.5, 1.0),
        ("zxcvbnm", 1.5, 2.0),
    ];

    for (chars, x_offset, y) in rows {
        for (i, c) in chars.chars().enumerate() {
            layout.insert(c, Point { x: i as f64 + x_offset, y });
        }
    }
    layout
}

pub fn euclidean_dist(p1: &Point, p2: &Point) -> f64 {
    ((p1.x - p2.x).powi(2) + (p1.y - p2.y).powi(2)).sqrt()
}

pub fn get_word_path(word: &str, layout: &HashMap<char, Point>) -> Vec<Point> {
    let key_points: Vec<Point> = word.chars()
        .filter_map(|c| layout.get(&c.to_ascii_lowercase()).cloned())
        .collect();

    if key_points.is_empty() {
        return vec![];
    }

    let step_size = 0.5;
    let mut full_path = vec![key_points[0]];

    for i in 1..key_points.len() {
        let p1 = key_points[i-1];
        let p2 = key_points[i];
        
        let dist = euclidean_dist(&p1, &p2);
        if dist > step_size {
            let num_steps = (dist / step_size) as i32;
            let dx = (p2.x - p1.x) / num_steps as f64;
            let dy = (p2.y - p1.y) / num_steps as f64;
            
            for s in 1..num_steps {
                let new_x = p1.x + dx * s as f64;
                let new_y = p1.y + dy * s as f64;
                full_path.push(Point { x: new_x, y: new_y });
            }
        }
        full_path.push(p2);
    }

    full_path
}

pub fn simplify_path(path: &[Point]) -> Vec<Point> {
    if path.is_empty() {
        return vec![];
    }
    
    let mut new_path = vec![path[0]];
    for p in path.iter().skip(1) {
        if euclidean_dist(p, new_path.last().unwrap()) > 0.01 {
            new_path.push(*p);
        }
    }
    new_path
}

/// Fast DTW with Sakoe-Chiba band constraint and early termination.
/// Uses O(n) space instead of O(n*m).
pub fn dtw_distance_fast(s: &[Point], t: &[Point], window: usize, cutoff: f64) -> f64 {
    let n = s.len();
    let m = t.len();
    if n == 0 || m == 0 {
        return f64::INFINITY;
    }

    // Early reject if lengths are too different
    let len_diff = (n as i64 - m as i64).unsigned_abs() as usize;
    if len_diff > window {
        return f64::INFINITY;
    }

    // Use two rows for O(m) space
    let mut prev = vec![f64::INFINITY; m + 1];
    let mut curr = vec![f64::INFINITY; m + 1];
    prev[0] = 0.0;

    for i in 1..=n {
        curr[0] = f64::INFINITY;
        let j_start = if i > window { i - window } else { 1 };
        let j_end = (i + window).min(m);

        // Reset out-of-band cells
        if j_start > 1 {
            curr[j_start - 1] = f64::INFINITY;
        }

        let mut row_min = f64::INFINITY;
        for j in j_start..=j_end {
            let cost = euclidean_dist(&s[i - 1], &t[j - 1]);
            let prev_min = prev[j].min(curr[j - 1]).min(prev[j - 1]);
            curr[j] = cost + prev_min;
            row_min = row_min.min(curr[j]);
        }

        // Early termination: if entire row exceeds cutoff, no point continuing
        if row_min > cutoff {
            return f64::INFINITY;
        }

        std::mem::swap(&mut prev, &mut curr);
    }

    prev[m]
}

/// Unused
pub fn dtw_distance(s: &[Point], t: &[Point]) -> f64 {
    let n = s.len();
    let m = t.len();
    if n == 0 || m == 0 {
        return f64::INFINITY;
    }

    let mut dtw = vec![vec![f64::INFINITY; m + 1]; n + 1];
    dtw[0][0] = 0.0;

    for i in 1..=n {
        for j in 1..=m {
            let cost = euclidean_dist(&s[i - 1], &t[j - 1]);
            let prev_min = dtw[i - 1][j].min(dtw[i][j - 1]).min(dtw[i - 1][j - 1]);
            dtw[i][j] = cost + prev_min;
        }
    }

    dtw[n][m]
}

// ============== WASM Exports ==============

const WORDS_TEXT: &str = include_str!("../words.txt");
const FREQ_TEXT: &str = include_str!("../word_freq.txt");

#[derive(Serialize)]
struct Prediction {
    word: String,
    score: f64,
    freq: f64,
}

struct Dictionary {
    words: Vec<String>,
    freq: HashMap<String, f64>,
}

thread_local! {
    static DICTIONARY: RefCell<Option<Dictionary>> = RefCell::new(None);
}

fn ensure_dictionary() {
    DICTIONARY.with(|d| {
        if d.borrow().is_some() {
            return;
        }

        let words: Vec<String> = WORDS_TEXT
            .lines()
            .map(|l| l.trim().to_lowercase())
            .filter(|l| !l.is_empty())
            .collect();

        let mut freq_map = HashMap::new();
        let mut max_freq: f64 = 0.0;

        let lines: Vec<&str> = FREQ_TEXT.lines().collect();
        for line in &lines {
            if let Some((_, count_str)) = line.split_once('\t') {
                if let Ok(count) = count_str.parse::<f64>() {
                    max_freq = max_freq.max(count);
                }
            }
        }

        for line in &lines {
            if let Some((word, count_str)) = line.split_once('\t') {
                if let Ok(count) = count_str.parse::<f64>() {
                    let log_freq = (count.ln() - 1.0) / max_freq.ln();
                    freq_map.insert(word.to_lowercase(), log_freq.max(0.0));
                }
            }
        }

        *d.borrow_mut() = Some(Dictionary { words, freq: freq_map });
    });
}

#[wasm_bindgen]
pub fn predict_wasm(swipe_input: &str, limit: usize) -> String {
    ensure_dictionary();
    let margin = 0.1;

    DICTIONARY.with(|d| {
        let dict = d.borrow();
        let dict = dict.as_ref().unwrap();

        let layout = get_keyboard_layout();
        let raw_input_path = get_word_path(swipe_input, &layout);

        if raw_input_path.is_empty() {
            return "[]".to_string();
        }

        let input_path = simplify_path(&raw_input_path);
        let input_len = input_path.len() as f64;

        let first_char = match swipe_input.chars().next() {
            Some(c) => c,
            None => return "[]".to_string(),
        };
        let last_char = swipe_input.chars().last().unwrap();
        let last_char_pt = layout.get(&last_char).cloned().unwrap_or(Point { x: 0.0, y: 0.0 });

        let window = (input_path.len() / 2).max(10);
        let mut best_score = f64::INFINITY;

        let mut candidates: Vec<(String, f64, f64)> = dict.words
            .iter()
            .filter(|w| !w.is_empty() && w.starts_with(first_char))
            .filter_map(|w| {
                let word_last_char = w.chars().last().unwrap();
                let mut end_penalty = 0.0;

                if word_last_char != last_char {
                    if let Some(word_last_pt) = layout.get(&word_last_char) {
                        end_penalty = euclidean_dist(&last_char_pt, word_last_pt) * 5.0;
                    } else {
                        end_penalty = 50.0;
                    }
                }

                let cutoff = best_score * input_len;
                let word_path = get_word_path(w, &layout);
                let dist = dtw_distance_fast(&input_path, &word_path, window, cutoff);

                if dist == f64::INFINITY {
                    return None;
                }

                let score = (dist + end_penalty) / input_len;
                if score < best_score {
                    best_score = score;
                }

                let word_freq = *dict.freq.get(w.as_str()).unwrap_or(&0.0);
                Some((w.clone(), score, word_freq))
            })
            .collect();

        candidates.sort_by(|a, b| {
            let combined_a = a.1 - (a.2 * margin);
            let combined_b = b.1 - (b.2 * margin);
            combined_a.partial_cmp(&combined_b).unwrap_or(std::cmp::Ordering::Equal)
        });

        let predictions: Vec<Prediction> = candidates
            .into_iter()
            .take(limit)
            .map(|(word, score, freq)| Prediction { word, score, freq })
            .collect();

        serde_json::to_string(&predictions).unwrap_or_else(|_| "[]".to_string())
    })
}