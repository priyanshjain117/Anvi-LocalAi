# Local AI — Flutter On-Device LLM App

Run LLMs **100% on-device** with no server, no API key, no data leaving your phone.
Uses [llama.cpp](https://github.com/ggerganov/llama.cpp) under the hood via the
`flutter_llama_cpp` package.

---

## Architecture

```
lib/
├── main.dart                     # App entry, theme
├── models/
│   └── llm_model.dart            # Model list (TinyLlama, Phi-2, Gemma 2B)
├── services/
│   └── model_manager.dart        # Download + llama.cpp inference singleton
└── screens/
    ├── model_picker_screen.dart  # On launch: pick & download model
    └── chat_screen.dart          # Chat UI with local inference
```

---

## Setup

### 1. Install Flutter
```bash
flutter --version  # needs 3.19+
```

### 2. Add the package
The key package is `flutter_llama_cpp` which wraps llama.cpp via Dart FFI.

```bash
flutter pub get
```

### 3. Android — enable large heap
Already set in `AndroidManifest.xml`:
```xml
android:largeHeap="true"
```
Also set in `android/app/build.gradle`:
```groovy
android {
    defaultConfig {
        minSdkVersion 24   // llama.cpp requires API 24+
    }
}
```

### 4. iOS — increase memory limit (Xcode)
In Xcode → Runner → Build Settings → Other Linker Flags, add:
```
-Xlinker -stack_size -Xlinker 0x10000000
```

### 5. Run
```bash
flutter run --release   # Always use release mode — debug is 10× slower for inference
```

---

## How it works

| Step | What happens |
|------|-------------|
| App opens | `ModelPickerScreen` shown; checks which models are already downloaded |
| Tap a model | If not downloaded → starts streaming download via `dio` with progress bar |
| Download complete | `LlamaModel.load()` loads GGUF weights into RAM |
| User sends message | `LlamaModel.generate()` runs inference on CPU (or GPU if available) |
| Response streams | Text returned and displayed in chat bubble |

### Prompt format (TinyLlama / Phi / Gemma compatible)
```
<|system|>
You are a helpful AI assistant running entirely on-device. Be concise.
<|user|>
{user message}
<|assistant|>
```

---

## Models included

| Model | Size | Notes |
|-------|------|-------|
| TinyLlama 1.1B Q4_K_M | ~668 MB | Best for older/low-RAM phones |
| Phi-2 2.7B Q4_K_M | ~1.7 GB | Smart, needs 4 GB RAM |
| Gemma 2B IT Q4_K_M | ~1.5 GB | Google model, needs 4 GB RAM |

All models are downloaded from **HuggingFace** in GGUF format (TheBloke).

---

## Minimum Requirements

- **Android**: API 24+ (Android 7.0), 3–4 GB RAM for TinyLlama, 6 GB for larger models
- **iOS**: iOS 16+, iPhone 12 or newer recommended
- **Storage**: 700 MB–1.8 GB per model (stored in app documents directory)

---

## Dependencies

```yaml
flutter_llama_cpp: ^0.2.0   # llama.cpp FFI binding
dio: ^5.4.0                  # HTTP download with progress
path_provider: ^2.1.2        # App documents directory
```
