#!/usr/bin/env python3
"""
Chinese Punctuation Restoration Server

Loads p208p2002/zh-wiki-punctuation-restore (BERT token classification) once,
serves POST /restore and GET /health via stdlib http.server.
"""

import argparse
import json
import os
import sys
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

import torch
from transformers import AutoTokenizer, AutoModelForTokenClassification

# Detect if running inside a PyInstaller bundle
IS_BUNDLED = getattr(sys, '_MEIPASS', None) is not None

# Globals set at startup
model = None
tokenizer = None
device = None
id2label = None
ALLOWED_PUNCTUATION = {"，", "。", "？", "！", "；", "：", "、"}
# Model labels have "S-" prefix, e.g. "S-，" → "，"
LABEL_PREFIX = "S-"
MAX_LENGTH = 510


def default_cache_dir():
    """Return ~/Library/Application Support/PunctuationServer/models/"""
    app_support = Path.home() / "Library" / "Application Support" / "PunctuationServer" / "models"
    return str(app_support)


def detect_device():
    if torch.cuda.is_available():
        return torch.device("cuda")
    if hasattr(torch.backends, "mps") and torch.backends.mps.is_available():
        return torch.device("mps")
    return torch.device("cpu")


def load_model(model_name, cache_dir=None):
    global model, tokenizer, device, id2label
    device = detect_device()
    cache_dir = cache_dir or default_cache_dir()
    os.makedirs(cache_dir, exist_ok=True)
    print(f"[startup] Loading model '{model_name}' on {device}")
    print(f"[startup] Cache dir: {cache_dir}")
    if IS_BUNDLED:
        print(f"[startup] Running as PyInstaller bundle (MEIPASS={sys._MEIPASS})")
    tokenizer = AutoTokenizer.from_pretrained(model_name, cache_dir=cache_dir)
    model = AutoModelForTokenClassification.from_pretrained(model_name, cache_dir=cache_dir).to(device)
    model.eval()
    id2label = model.config.id2label
    print(f"[startup] Model loaded. Labels: {id2label}")


def find_split_point(text, max_chars):
    """Find the best split point at or before max_chars, snapping to natural boundaries."""
    if len(text) <= max_chars:
        return len(text)
    # Try to snap to newline
    pos = text.rfind("\n", 0, max_chars)
    if pos > 0:
        return pos + 1
    # Try whitespace
    pos = text.rfind(" ", 0, max_chars)
    if pos > 0:
        return pos + 1
    # Hard split
    return max_chars


def estimate_max_chars(text, max_tokens):
    """Binary search for the max char position that fits within max_tokens."""
    lo, hi = 0, len(text)
    best = min(hi, max_tokens)  # conservative initial guess
    while lo <= hi:
        mid = (lo + hi) // 2
        n_tokens = len(tokenizer.encode(text[:mid], add_special_tokens=True))
        if n_tokens <= max_tokens:
            best = mid
            lo = mid + 1
        else:
            hi = mid - 1
    return best


def chunk_text(text, max_tokens):
    """Split text into chunks that each fit within max_tokens for the tokenizer."""
    chunks = []
    remaining = text
    while remaining:
        if len(tokenizer.encode(remaining, add_special_tokens=True)) <= max_tokens:
            chunks.append(remaining)
            break
        max_chars = estimate_max_chars(remaining, max_tokens)
        split_at = find_split_point(remaining, max_chars)
        if split_at == 0:
            split_at = max_chars if max_chars > 0 else 1
        chunks.append(remaining[:split_at])
        remaining = remaining[split_at:]
    return chunks


def restore_punctuation(text):
    """Insert punctuation into text using the model. Guarantees no text modification."""
    if not text.strip():
        return text

    chunks = chunk_text(text, MAX_LENGTH)
    result_parts = []

    for chunk in chunks:
        result_parts.append(_restore_chunk(chunk))

    return "".join(result_parts)


def _restore_chunk(text):
    """Process a single chunk that fits within model's max length."""
    encoding = tokenizer(
        text,
        return_tensors="pt",
        return_offsets_mapping=True,
        truncation=True,
        max_length=MAX_LENGTH + 2,  # +2 for [CLS] and [SEP]
    )

    offset_mapping = encoding.pop("offset_mapping")[0].tolist()
    input_ids = encoding["input_ids"].to(device)
    attention_mask = encoding["attention_mask"].to(device)

    with torch.no_grad():
        logits = model(input_ids=input_ids, attention_mask=attention_mask).logits

    predictions = torch.argmax(logits, dim=-1)[0].tolist()

    # Build result by walking through tokens and inserting punctuation
    result = []
    prev_end = 0

    for i, (start, end) in enumerate(offset_mapping):
        if start == 0 and end == 0:
            # Special token ([CLS], [SEP])
            continue

        # Add any text between previous token end and this token start (whitespace etc.)
        if start > prev_end:
            result.append(text[prev_end:start])

        # Add the original token text
        result.append(text[start:end])

        # Check if model predicts punctuation after this token
        label = id2label.get(predictions[i], "O")
        # Strip "S-" prefix to get the actual punctuation character
        punct = label[len(LABEL_PREFIX):] if label.startswith(LABEL_PREFIX) else label
        if punct in ALLOWED_PUNCTUATION:
            # Only insert if the next character isn't already punctuation
            next_char_idx = end
            if next_char_idx < len(text) and text[next_char_idx] in ALLOWED_PUNCTUATION:
                pass  # Skip — punctuation already exists
            else:
                result.append(punct)

        prev_end = end

    # Add any trailing text
    if prev_end < len(text):
        result.append(text[prev_end:])

    return "".join(result)


class PunctuationHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            self._send_json(200, {"status": "ok", "device": str(device)})
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/restore":
            self._send_json(404, {"error": "not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length > 0 else {}
        except (json.JSONDecodeError, ValueError):
            self._send_json(400, {"error": "invalid JSON"})
            return

        text = body.get("text", "")
        if not text:
            self._send_json(400, {"error": "missing 'text' field"})
            return

        t0 = time.time()
        restored = restore_punctuation(text)
        elapsed = time.time() - t0

        self._send_json(200, {"text": restored, "elapsed_ms": round(elapsed * 1000, 1)})

    def _send_json(self, code, data):
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        # Simpler log format
        print(f"[{self.log_date_time_string()}] {format % args}")


def self_test():
    """Run a quick self-test to verify the model works."""
    test_input = "今天天氣很好我想出去走走"
    print(f"Self-test input:  {test_input}")
    result = restore_punctuation(test_input)
    print(f"Self-test output: {result}")
    if result != test_input:
        print("Self-test PASSED (punctuation was inserted)")
    else:
        print("Self-test WARN (no punctuation inserted — model may need different input)")


def main():
    global MAX_LENGTH
    parser = argparse.ArgumentParser(description="Chinese Punctuation Restoration Server")
    parser.add_argument("--port", type=int, default=18230, help="Server port (default: 18230)")
    parser.add_argument(
        "--model",
        type=str,
        default="p208p2002/zh-wiki-punctuation-restore",
        help="HuggingFace model name",
    )
    parser.add_argument("--max-length", type=int, default=510, help="Max token length per chunk")
    parser.add_argument(
        "--cache-dir",
        type=str,
        default=None,
        help="Model cache directory (default: ~/Library/Application Support/PunctuationServer/models/)",
    )
    args = parser.parse_args()
    MAX_LENGTH = args.max_length

    print(f"[startup] PunctuationServer starting (bundled={IS_BUNDLED})")
    load_model(args.model, cache_dir=args.cache_dir)
    self_test()

    server = HTTPServer(("127.0.0.1", args.port), PunctuationHandler)
    print(f"\n[startup] Punctuation server listening on http://127.0.0.1:{args.port}")
    print(f"[startup]   POST /restore  {{\"text\": \"...\"}}")
    print(f"[startup]   GET  /health")
    print(f"[startup] Ready.")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()
