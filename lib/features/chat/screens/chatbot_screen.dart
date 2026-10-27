import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/chat_repository.dart';
import '../widgets/chat_bubble.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _chatRepository = ChatRepository();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  int _userId = 1;
  bool _isSeller = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initChat() async {
    try {
      final auth = AuthRepository.instance;
      _userId = auth.currentUserProfile?.id ?? auth.currentTokens?.userId ?? 1;
      _isSeller = auth.isSeller;

      final history = await _chatRepository.getMessages(_userId);

      if (history.isEmpty) {
        // Buat pesan sambutan awal otomatis jika riwayat masih kosong
        final welcome = ChatMessageModel(
          userId: _userId,
          role: 'assistant',
          message: _isSeller
              ? 'Halo! Saya Rera, asisten pintar Recovera. Saya dapat membantu Anda menganalisis potensi produk lelang, memproyeksikan pembeli terdekat, dan memberikan panduan sistem lelang dinamis.'
              : 'Halo! Saya Rera, asisten pintar Recovera. Ada yang ingin Anda tanyakan seputar cara belanja lelang dinamis, produk berpendingin, atau sertifikasi dampak lingkungan?',
        );
        final savedWelcome = await _chatRepository.saveMessage(welcome);
        if (mounted) {
          setState(() {
            _messages = [savedWelcome];
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _messages = history;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _messages = [
            ChatMessageModel(
              userId: _userId,
              role: 'assistant',
              message: 'Halo! Saya Rera, asisten pintar Recovera. Ada yang bisa saya bantu hari ini?',
            )
          ];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? quickText]) async {
    final text = (quickText ?? _textController.text).trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();

    // Tambahkan user message langsung ke UI sementara disimpan
    final tempUserMsg = ChatMessageModel(
      userId: _userId,
      role: 'user',
      message: text,
    );

    setState(() {
      _messages.add(tempUserMsg);
      _isSending = true;
    });
    _scrollToBottom();

    try {
      // Panggil repository (simpan ke SQLite/in-memory & hubungkan Gemini/AIEngine)
      final assistantReply = await _chatRepository.sendMessage(
        userId: _userId,
        message: text,
        currentHistory: _messages,
      );

      if (!mounted) return;

      setState(() {
        _messages[_messages.length - 1] = ChatMessageModel(
          userId: _userId,
          role: 'user',
          message: text,
        );
        _messages.add(assistantReply);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessageModel(
            userId: _userId,
            role: 'assistant',
            message: 'Terjadi kendala saat memproses respons. Silakan coba sesaat lagi.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  Future<void> _clearChatHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Hapus Riwayat Obrolan?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Semua pesan obrolan di sesi ini akan dihapus dari perangkat Anda.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.slateText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Batal', style: GoogleFonts.inter(color: AppColors.slateText)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text('Hapus', style: GoogleFonts.inter(color: AppColors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _chatRepository.clearHistory(_userId);
      if (!mounted) return;
      await _initChat();
    }
  }

  List<String> get _quickChips {
    if (_isSeller) {
      return [
        'Cek peluang 50 karton Susu UHT harga Rp 210.000 sisa 45 hari',
        'Produk lelang apa yang paling murah di pasar?',
        'Kategori pangan apa yang paling banyak dicari?',
        'Bagaimana cara kerja penurunan harga lelang?',
      ];
    }
    return [
      'Produk lelang apa yang paling murah saat ini?',
      'Produk apa yang paling dekat dari jangkauan saya?',
      'Bagaimana cara memastikan kualitas rantai dingin?',
      'Bagaimana cara kerja sistem lelang dinamis?',
      'Bagaimana sertifikat dampak hijau (ESG) dihitung?',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasBg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.darkNavy),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rera',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkNavy,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Online • Google Gemini',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.slateText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Hapus Riwayat Obrolan',
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.slateText),
            onPressed: _clearChatHistory,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // List Obrolan
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 10, bottom: 12),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return ChatBubble(message: _messages[index]);
                      },
                    ),
            ),

            // Loading / Pengetikan Indicator
            if (_isSending) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Asisten sedang menganalisis...',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: AppColors.slateText,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Quick Suggestion Chips
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 6),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _quickChips.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final chipText = _quickChips[index];
                  return ActionChip(
                    backgroundColor: AppColors.white,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    label: Text(
                      chipText,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () => _sendMessage(chipText),
                  );
                },
              ),
            ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.inputBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: GoogleFonts.inter(fontSize: 13.5),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: _isSeller
                              ? 'Tanyakan potensi produk, harga, atau lelang...'
                              : 'Tanyakan cara belanja lelang atau donasi...',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: AppColors.slateText,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.white, size: 18),
                      onPressed: _isSending ? null : () => _sendMessage(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
