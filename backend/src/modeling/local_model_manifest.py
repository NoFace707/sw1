import hashlib
import json


QWEN_MODEL_REVISION = "2ab9f8f42af02fc212effaef7c4850c885e965f4"


def local_model_manifest_payload():
    body = {
        "schema_version": 1,
        "id": "qwen2.5-coder-1.5b-instruct-q4-k-m",
        "version": QWEN_MODEL_REVISION,
        "family": "Qwen2.5-Coder",
        "quantization": "Q4_K_M",
        "source": "Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF",
        "license": "Apache-2.0",
        "file_name": "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf",
        "download_url": f"https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/{QWEN_MODEL_REVISION}/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf?download=true",
        "byte_size": 1117320768,
        "sha256": "cc324af070c2ecbfd324a30884d2f951a7ff756aba85cb811a6ec436933bb046",
        "context_tokens": 8192,
        "chat_template": "<|im_start|>system\n{system}<|im_end|>\n<|im_start|>user\n{prompt}<|im_end|>\n<|im_start|>assistant\n",
        "minimum_profile": {
            "architecture": ["android-arm64", "ios-arm64"],
            "ram_bytes": 4294967296,
            "free_storage_bytes": 2684354560,
        },
    }
    canonical = json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return {**body, "manifest_checksum": hashlib.sha256(canonical.encode("utf-8")).hexdigest()}
