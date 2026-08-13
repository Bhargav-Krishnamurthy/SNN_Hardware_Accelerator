"""
generate_spikes.py
==================
Generates rate-coded spike .mem files for a given MNIST test image.
Run this script, then re-run Vivado simulation to test any digit.

Usage:
    python3 generate_spikes.py --index 0          # test image at index 0
    python3 generate_spikes.py --index 42 --seed 99
    python3 generate_spikes.py --index 5 --out_dir path/to/vivado/xsim

Requirements:
    pip install numpy torchvision torch
"""

import argparse
import os
import struct
import numpy as np

# ── Parameters (must match Verilog) ─────────────────────────────────────────
N_STEPS    = 25       # number of timesteps
INPUT_SIZE = 784      # 28x28 pixels
WORDS_PER_STEP = 25   # ceil(784 / 32) = 25 words per timestep

def load_mnist_image(index):
    """Load a single MNIST test image without torch if possible."""
    try:
        from torchvision import datasets, transforms
        import torch
        test_data = datasets.MNIST(root="data", train=False, download=True,
                                   transform=transforms.ToTensor())
        img, label = test_data[index]
        pixels = img.view(-1).numpy()   # [784] float in [0,1]
        return pixels, label
    except ImportError:
        # Fallback: read raw MNIST binary file
        print("torchvision not found, trying raw MNIST files...")
        return load_mnist_raw(index)

def load_mnist_raw(index):
    """Load from raw MNIST binary (if already downloaded)."""
    import gzip
    img_path  = "data/MNIST/raw/t10k-images-idx3-ubyte"
    lbl_path  = "data/MNIST/raw/t10k-labels-idx1-ubyte"

    # Try gzip variants too
    if not os.path.exists(img_path):
        img_path += ".gz"
        lbl_path += ".gz"
        opener = gzip.open
    else:
        opener = open

    with opener(img_path, 'rb') as f:
        f.read(16)  # skip header
        buf = f.read(784 * (index + 1))
    pixels = np.frombuffer(buf, dtype=np.uint8)[index*784:(index+1)*784]
    pixels = pixels.astype(np.float32) / 255.0

    with opener(lbl_path, 'rb') as f:
        f.read(8)
        lbl_buf = f.read(index + 1)
    label = lbl_buf[index]

    return pixels, int(label)


def rate_encode(pixels, n_steps, seed=42):
    """
    Rate coding: pixel fires with probability = pixel intensity.
    Returns binary spike array [n_steps, 784].
    """
    rng = np.random.default_rng(seed)
    spikes = np.zeros((n_steps, INPUT_SIZE), dtype=np.uint8)
    for t in range(n_steps):
        rand = rng.random(INPUT_SIZE)
        spikes[t] = (rand < pixels).astype(np.uint8)
    return spikes


def pack_spikes_to_words(spike_row):
    """
    Pack 784 binary spike values into 25 x 32-bit words.
    Bit layout: spike[i] -> word[i//32], bit (i%32)
    Returns list of 25 integers.
    """
    words = [0] * WORDS_PER_STEP
    for i, s in enumerate(spike_row):
        if s:
            words[i // 32] |= (1 << (i % 32))
    return words


def save_spike_mem(words, filepath):
    """Save as .mem file: one 8-digit hex word per line."""
    with open(filepath, 'w') as f:
        for w in words:
            f.write(f"{w:08X}\n")


def main():
    parser = argparse.ArgumentParser(description="Generate SNN spike .mem files from MNIST")
    parser.add_argument("--index",   type=int, default=0,
                        help="MNIST test-set image index (0-9999)")
    parser.add_argument("--seed",    type=int, default=42,
                        help="Random seed for rate encoding")
    parser.add_argument("--out_dir", type=str, default="LIF_NEURON/src",
                        help="Output directory for spike_t*.mem files")
    args = parser.parse_args()

    # Load image
    print(f"\nLoading MNIST test image index {args.index}...")
    pixels, label = load_mnist_image(args.index)
    print(f"  True label : {label}")
    print(f"  Pixel range: [{pixels.min():.3f}, {pixels.max():.3f}]")

    # Rate encode
    print(f"\nRate encoding into {N_STEPS} timesteps (seed={args.seed})...")
    spikes = rate_encode(pixels, N_STEPS, seed=args.seed)
    print(f"  Total spike density: {spikes.mean()*100:.1f}%")

    # Save .mem files
    os.makedirs(args.out_dir, exist_ok=True)
    for t in range(N_STEPS):
        words = pack_spikes_to_words(spikes[t])
        fpath = os.path.join(args.out_dir, f"spike_t{t:02d}.mem")
        save_spike_mem(words, fpath)

    print(f"\nSaved spike_t00.mem ... spike_t{N_STEPS-1:02d}.mem -> {args.out_dir}/")
    print(f"\nExpected Verilog output: Predicted class = {label}")
    print(f"Now re-run the Vivado simulation (or: vvp sim.out)\n")


if __name__ == "__main__":
    main()
