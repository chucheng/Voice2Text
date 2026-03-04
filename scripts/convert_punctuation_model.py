#!/usr/bin/env python3
"""
Convert the zh-wiki-punctuation-restore BERT model from PyTorch to CoreML.

This is a developer tool — NOT shipped with the app.

Requirements:
    pip install torch transformers coremltools

Usage:
    python scripts/convert_punctuation_model.py

Output:
    - zh-punctuation-bert.mlpackage  (CoreML model, ~100-200MB)
    - vocab.txt                      (WordPiece vocabulary for bundling in app)
"""

import os
import shutil
import numpy as np

MODEL_NAME = "p208p2002/zh-wiki-punctuation-restore"
OUTPUT_DIR = os.path.dirname(os.path.abspath(__file__))
MLPACKAGE_NAME = "zh-punctuation-bert.mlpackage"
MAX_SEQ_LEN = 512

# Label mapping (must match PunctuationRestorer.swift)
# 0: O, 1: S-，, 2: S-、, 3: S-。, 4: S-？, 5: S-！, 6: S-；
LABEL_COUNT = 7  # Model has 7 output classes


def main():
    import torch
    from transformers import AutoTokenizer, AutoModelForTokenClassification
    import coremltools as ct

    print(f"Loading model: {MODEL_NAME}")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForTokenClassification.from_pretrained(MODEL_NAME)
    model.eval()

    num_labels = model.config.num_labels
    print(f"Number of labels: {num_labels}")
    print(f"Label mapping: {model.config.id2label}")

    # Export vocab.txt for bundling in app
    vocab_path = os.path.join(OUTPUT_DIR, "..", "Voice2Text", "vocab.txt")
    src_vocab = os.path.join(tokenizer.name_or_path, "vocab.txt")
    if not os.path.exists(src_vocab):
        # Download and save vocab
        tokenizer.save_pretrained("/tmp/punct_tokenizer")
        src_vocab = "/tmp/punct_tokenizer/vocab.txt"
    shutil.copy2(src_vocab, vocab_path)
    print(f"Copied vocab.txt to {vocab_path}")

    # Trace model with dummy inputs
    dummy_ids = torch.randint(0, tokenizer.vocab_size, (1, MAX_SEQ_LEN), dtype=torch.int32)
    dummy_mask = torch.ones(1, MAX_SEQ_LEN, dtype=torch.int32)

    class WrapperModel(torch.nn.Module):
        def __init__(self, model):
            super().__init__()
            self.model = model

        def forward(self, input_ids, attention_mask):
            outputs = self.model(
                input_ids=input_ids.long(),
                attention_mask=attention_mask.long(),
            )
            return outputs.logits

    wrapper = WrapperModel(model)
    wrapper.eval()

    print("Tracing model...")
    traced = torch.jit.trace(wrapper, (dummy_ids, dummy_mask))

    print("Converting to CoreML...")
    mlmodel = ct.convert(
        traced,
        inputs=[
            ct.TensorType(name="input_ids", shape=(1, MAX_SEQ_LEN), dtype=np.int32),
            ct.TensorType(name="attention_mask", shape=(1, MAX_SEQ_LEN), dtype=np.int32),
        ],
        outputs=[
            ct.TensorType(name="logits"),
        ],
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.macOS14,
    )

    output_path = os.path.join(OUTPUT_DIR, MLPACKAGE_NAME)
    if os.path.exists(output_path):
        shutil.rmtree(output_path)
    mlmodel.save(output_path)
    print(f"Saved CoreML model to {output_path}")

    # Create zip for GitHub Releases
    zip_path = os.path.join(OUTPUT_DIR, "zh-punctuation-bert.mlpackage.zip")
    if os.path.exists(zip_path):
        os.remove(zip_path)
    shutil.make_archive(
        os.path.join(OUTPUT_DIR, "zh-punctuation-bert.mlpackage"),
        "zip",
        OUTPUT_DIR,
        MLPACKAGE_NAME,
    )
    print(f"Created zip: {zip_path}")
    print("Done! Upload the zip to GitHub Releases.")


if __name__ == "__main__":
    main()
