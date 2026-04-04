// class LLMModel {
//   final String name;
//   final String description;
//   final String downloadUrl;
//   final String fileName;
//   final int sizeBytes; // approx

//   const LLMModel({
//     required this.name,
//     required this.description,
//     required this.downloadUrl,
//     required this.fileName,
//     required this.sizeBytes,
//   });

//   String get sizeLabel {
//     final mb = sizeBytes / (1024 * 1024);
//     return '${mb.toStringAsFixed(0)} MB';
//   }
// }

// /// Hugging Face GGUF models (Q4 quantized, ~600 MB range)
// const List<LLMModel> availableModels = [
//   LLMModel(
//     name: 'TinyLlama 1.1B',
//     description: 'Fast & tiny. Best for low-end devices.',
//     // TinyLlama Q4_K_M GGUF from TheBloke
//     downloadUrl:
//         'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
//     fileName: 'tinyllama-1.1b-q4_k_m.gguf',
//     sizeBytes: 668_000_000,
//   ),
//   LLMModel(
//     name: 'Phi-2 2.7B',
//     description: 'Microsoft Phi-2. Smarter, ~1.7 GB.',
//     downloadUrl:
//         'https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf',
//     fileName: 'phi-2-q4_k_m.gguf',
//     sizeBytes: 1_700_000_000,
//   ),
//   LLMModel(
//     name: 'Gemma 2B',
//     description: 'Google Gemma 2B Instruct. ~1.5 GB.',
//     downloadUrl:
//         'https://huggingface.co/google/gemma-2b-it-GGUF/resolve/main/2b-it-q4_k_m.gguf',
//     fileName: 'gemma-2b-it-q4_k_m.gguf',
//     sizeBytes: 1_497_000_000,
//   ),
// ];
class LLMModel {
  final String name;
  final String description;
  final String downloadUrl;
  final String fileName;
  final int sizeBytes;

  const LLMModel({
    required this.name,
    required this.description,
    required this.downloadUrl,
    required this.fileName,
    required this.sizeBytes,
  });

  String get sizeLabel {
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(0)} MB';
  }
}

const List<LLMModel> availableModels = [
  LLMModel(
    name: 'TinyLlama 1.1B',
    description: 'Fastest • Best for low-RAM devices • ~600 MB',
    downloadUrl:
        'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    fileName: 'tinyllama-1.1b-q4_k_m.gguf',
    sizeBytes: 668000000,
  ),
  LLMModel(
    name: 'Phi-2 2.7B',
    description: 'Smarter • Microsoft model • ~1.7 GB',
    downloadUrl:
        'https://huggingface.co/TheBloke/phi-2-GGUF/resolve/main/phi-2.Q4_K_M.gguf',
    fileName: 'phi-2-q4_k_m.gguf',
    sizeBytes: 1700000000,
  ),
  LLMModel(
    name: 'Gemma 2B',
    description: 'Google model • Instruction tuned • ~1.5 GB',
    downloadUrl:
        'https://huggingface.co/google/gemma-2b-it-GGUF/resolve/main/2b-it-q4_k_m.gguf',
    fileName: 'gemma-2b-it-q4_k_m.gguf',
    sizeBytes: 1497000000,
  ),
];