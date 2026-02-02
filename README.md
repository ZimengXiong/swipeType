# Swipe Predictor

Swipe typing lets you draw a path across the keyboard instead of tapping individual keys. This predictor matches your input pattern against a word list.

Each word is converted to a path on a QWERTY keyboard layout. The algorithm uses [Dynamic Time Warping (DTW)](https://en.wikipedia.org/wiki/Dynamic_time_warping) to measure how similar your swipe path is to each word's path. Words with similar paths get low scores.

Word frequency from a corpus is used as a tiebreaker—common words rank higher when paths are equally close.

Try these swipe patterns:
- `asdfghjkl;poiuygfdsascsa` → alpaca
- `poiuytrernmngyuijnb` → penguin

## Optimizations

To run DTW—an O(n×m) algorithm—against a word list in milliseconds, entirely client-side, we needed some key optimizations. The engine is written in Rust and compiled to WebAssembly:

- **Sakoe-Chiba band** — constrain DTW to a diagonal band, reducing complexity to O(n×w)
- **Early termination** — prune candidates mid-computation if partial score exceeds current best
- **O(n) space** — keep only two rows of the DTW matrix in memory
- **First/last character filtering** — only consider words matching the first character; penalize last character mismatches

## Build

```bash
make build-website
```

## Serve locally

```bash
make serve
```

Then open http://localhost:8000
