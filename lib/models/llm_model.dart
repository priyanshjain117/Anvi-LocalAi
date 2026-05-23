class LLMModel {
  final String name;
  final String description;
  final String downloadUrl;
  final String fileName;
  final int sizeBytes;
  final String ramLabel;
  final String deviceGroup;
  final String performanceLabel;
  final bool recommended;

  const LLMModel({
    required this.name,
    required this.description,
    required this.downloadUrl,
    required this.fileName,
    required this.sizeBytes,
    required this.ramLabel,
    required this.deviceGroup,
    required this.performanceLabel,
    this.recommended = false,
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
    ramLabel: '3 GB+ RAM',
    deviceGroup: 'Starter phones',
    performanceLabel: 'Fast',
    recommended: true,
  ),
  LLMModel(
    name: 'Gemma 4 E2B',
    description: 'Google-style compact instruct model • strong for school Q&A',
    downloadUrl:
        'https://huggingface.co/DuoNeural/Gemma-4-E2B-GGUF/resolve/main/gemma-4-E2B-it.Q4_K_M.gguf',
    fileName: 'gemma-4-e2b-it-q4_k_m.gguf',
    sizeBytes: 3000000000,
    ramLabel: '6-8 GB RAM',
    deviceGroup: 'Phones (6-8 GB RAM)',
    performanceLabel: 'Balanced',
    recommended: true,
  ),
  LLMModel(
    name: 'Phi-3 Mini',
    description: 'Microsoft 3.8B instruct model • reliable reasoning',
    downloadUrl:
        'https://huggingface.co/QuantFactory/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct.Q4_K_M.gguf',
    fileName: 'phi-3-mini-4k-instruct-q4_k_m.gguf',
    sizeBytes: 2300000000,
    ramLabel: '6-8 GB RAM',
    deviceGroup: 'Phones (6-8 GB RAM)',
    performanceLabel: 'Reasoning',
  ),
  LLMModel(
    name: 'Phi-4 Mini',
    description: 'Newer compact Phi model • math and coding friendly',
    downloadUrl:
        'https://huggingface.co/ket0x4/Phi-4-mini-instruct-Q4_K_M-GGUF/resolve/main/phi-4-mini-instruct-q4_k_m.gguf',
    fileName: 'phi-4-mini-instruct-q4_k_m.gguf',
    sizeBytes: 2492000000,
    ramLabel: '6-8 GB RAM',
    deviceGroup: 'Phones (6-8 GB RAM)',
    performanceLabel: 'Smart',
  ),
  LLMModel(
    name: 'Qwen2.5 3B',
    description: 'Good multilingual assistant • efficient for daily learning',
    downloadUrl:
        'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
    fileName: 'qwen2.5-3b-instruct-q4_k_m.gguf',
    sizeBytes: 2000000000,
    ramLabel: '6-8 GB RAM',
    deviceGroup: 'Phones (6-8 GB RAM)',
    performanceLabel: 'Multilingual',
  ),
  LLMModel(
    name: 'Llama 3.2 3B',
    description: 'Meta compact chat model • fast general assistant',
    downloadUrl:
        'https://huggingface.co/velyan/Llama-3.2-3B-Instruct-Q4_K_M-GGUF/resolve/main/llama-3.2-3b-instruct-q4_k_m-imat.gguf',
    fileName: 'llama-3.2-3b-instruct-q4_k_m.gguf',
    sizeBytes: 2020000000,
    ramLabel: '6-8 GB RAM',
    deviceGroup: 'Phones (6-8 GB RAM)',
    performanceLabel: 'General',
  ),
  LLMModel(
    name: 'Qwen2.5 7B',
    description: 'Stronger multilingual reasoning • slower but richer',
    downloadUrl:
        'https://huggingface.co/MaziyarPanahi/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct.Q4_K_M.gguf',
    fileName: 'qwen2.5-7b-instruct-q4_k_m.gguf',
    sizeBytes: 4400000000,
    ramLabel: '12-16 GB RAM',
    deviceGroup: 'Phones/Tablets (12-16 GB RAM)',
    performanceLabel: 'Best balance',
    recommended: true,
  ),
  LLMModel(
    name: 'Llama 3.1 8B',
    description: 'Strong Meta instruct model • better long-form answers',
    downloadUrl:
        'https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf',
    fileName: 'meta-llama-3.1-8b-instruct-q4_k_m.gguf',
    sizeBytes: 4920000000,
    ramLabel: '12-16 GB RAM',
    deviceGroup: 'Phones/Tablets (12-16 GB RAM)',
    performanceLabel: 'High quality',
  ),
  LLMModel(
    name: 'Mistral 7B',
    description: 'Fast 7B instruct model • useful for explanations',
    downloadUrl:
        'https://huggingface.co/bartowski/Mistral-7B-Instruct-v0.3-GGUF/resolve/main/Mistral-7B-Instruct-v0.3-Q4_K_M.gguf',
    fileName: 'mistral-7b-instruct-v0.3-q4_k_m.gguf',
    sizeBytes: 4370000000,
    ramLabel: '12-16 GB RAM',
    deviceGroup: 'Phones/Tablets (12-16 GB RAM)',
    performanceLabel: 'Fast 7B',
  ),
  LLMModel(
    name: 'DeepSeek Distill 7B',
    description: 'Reasoning-focused distilled model • best for step work',
    downloadUrl:
        'https://huggingface.co/bartowski/DeepSeek-R1-Distill-Qwen-7B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-7B-Q4_K_M.gguf',
    fileName: 'deepseek-r1-distill-qwen-7b-q4_k_m.gguf',
    sizeBytes: 4680000000,
    ramLabel: '12-16 GB RAM',
    deviceGroup: 'Phones/Tablets (12-16 GB RAM)',
    performanceLabel: 'Reasoning',
  ),
];
