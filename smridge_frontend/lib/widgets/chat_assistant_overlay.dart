import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatAssistantOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final Function(String action, String? value)? onActionTriggered; // Added

  const ChatAssistantOverlay({super.key, required this.onClose, this.onActionTriggered}); // Updated

  @override
  State<ChatAssistantOverlay> createState() => _ChatAssistantOverlayState();
}

class _ChatAssistantOverlayState extends State<ChatAssistantOverlay> {
  final TextEditingController _msgController = TextEditingController();
  // 🔹 Track which message actions have been confirmed at least once
  final Set<int> _confirmedIndices = {};
  
  // 🔹 STATIC PERSISTENCE: Messages stay until app is closed or logged out
  static final List<Map<String, String>> _persistedMessages = [
    {"role": "assistant", "content": "Hello! I am Smridgey - The Smridge AI Assistant. How can I help you manage your fridge today?"}
  ];

  bool _isTyping = false;
  bool _isExpanded = false; // 🔹 Expandable state

  void _clearChat() {
    setState(() {
      _persistedMessages.clear();
      _persistedMessages.add({
        "role": "assistant", 
        "content": "Hello! History cleared. How can I help you now?"
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    // 🔹 Text-based Confirmation Logic
    final affirmationWords = ['confirm', 'yes', 'yep', 'y', 'do it', 'sure', 'pls', 'please'];
    if (affirmationWords.contains(text.toLowerCase())) {
       for (int i = _persistedMessages.length - 1; i >= 0; i--) {
         final msg = _persistedMessages[i];
         final actionType = msg["action"];
         if (actionType != null && actionType.isNotEmpty && !_confirmedIndices.contains(i)) {
            final isCRUD = actionType == "ADD_ITEM_AI" || actionType == "ADD_ITEM" || 
                           actionType == "DELETE_ITEM" || actionType == "EDIT_ITEM";
            if (isCRUD) {
               widget.onActionTriggered?.call(actionType, msg["actionValue"]);
               setState(() {
                 _confirmedIndices.add(i);
                 _persistedMessages.add({"role": "user", "content": text});
               });
               _msgController.clear();
               return;
            }
         }
       }
    }

    setState(() {
      _persistedMessages.add({"role": "user", "content": text});
      _isTyping = true;
    });
    _msgController.clear();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;
    
    // Pass history to backend
    final history = _persistedMessages.map((m) => {
      "role": m["role"]!,
      "content": m["content"]!,
    }).toList();

    final reply = await ApiService.askChatAssistant(text, token, history: history);

    String? cleanReply = reply;
    String? detectedAction;
    String? actionValue;

    if (reply != null && reply.contains("[ACTION:")) {
      final regExp = RegExp(r"\[ACTION:([A-Z_]+):?(.*?)\]", dotAll: true);
      final match = regExp.firstMatch(reply);
      if (match != null) {
        detectedAction = match.group(1);
        actionValue = match.group(2);
        if (actionValue?.isEmpty ?? true) actionValue = null;
        cleanReply = reply.replaceAll(regExp, "").trim();
      }
    }

    if (mounted) {
      setState(() {
        _isTyping = false;
        _persistedMessages.add({
          "role": "assistant", 
          "content": cleanReply ?? "Sorry, I am having trouble connecting to the server.",
          "action": detectedAction ?? "",
          "actionValue": actionValue ?? "",
        });
      });

      // 🔹 AUTO-EXECUTION for non-inventory actions (UI customizations, etc.)
      final isInventoryAction = detectedAction == "ADD_ITEM_AI" || 
                                detectedAction == "ADD_ITEM" || 
                                detectedAction == "DELETE_ITEM" || 
                                detectedAction == "EDIT_ITEM" ||
                                detectedAction == "OPEN_SCREEN";

      if (detectedAction != null && !isInventoryAction) {
        if (widget.onActionTriggered != null) {
          widget.onActionTriggered!(detectedAction, actionValue);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Provider.of<ThemeProvider>(context).currentTheme == ThemeType.light;
    final textColor = isLight ? Colors.black87 : Colors.white;

    return SizedBox(
      height: _isExpanded ? MediaQuery.of(context).size.height * 0.95 : MediaQuery.of(context).size.height * 0.75,
      child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isLight ? Colors.white : const Color(0xFF1E2A33),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20)
              ],
            ),
            child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isLight ? Colors.teal : Colors.teal.shade900,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy, color: Colors.white),
                    const SizedBox(width: 8),
                    const Expanded(child: Text("Smridgey - The Smridge AI Assistant", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                    IconButton(
                      tooltip: "Clear Chat",
                      icon: const Icon(Icons.delete_sweep, color: Colors.white70),
                      onPressed: _clearChat,
                    ),
                    IconButton(
                      tooltip: _isExpanded ? "Restore" : "Expand",
                      icon: Icon(_isExpanded ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white),
                      onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: widget.onClose,
                    )
                  ],
                ),
              ),

              // Chat History
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: false,
                  itemCount: _persistedMessages.length,
                  itemBuilder: (context, index) {
                    final msg = _persistedMessages[index];
                    final isUser = msg["role"] == "user";
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUser 
                              ? (isLight ? Colors.teal.shade100 : Colors.teal.shade800) 
                              : (isLight ? Colors.grey.shade200 : Colors.white10),
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                            bottomLeft: !isUser ? Radius.zero : const Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg["content"]!, style: TextStyle(color: textColor, fontSize: 16)),
                            if (msg["action"] != null && msg["action"]!.isNotEmpty) ...[
                              if (msg["action"] == "ADD_ITEM_AI" || 
                                  msg["action"] == "ADD_ITEM" || 
                                  msg["action"] == "DELETE_ITEM" || 
                                  msg["action"] == "EDIT_ITEM" ||
                                  msg["action"] == "OPEN_SCREEN") ...[
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  icon: Icon(_getActionIcon(msg["action"]!, index), size: 18),
                                  label: Text(_getActionLabel(msg["action"]!, msg["actionValue"], index)),
                                  onPressed: () {
                                    final actionType = msg["action"]!;
                                    final isCRUD = actionType == "ADD_ITEM_AI" || 
                                                 actionType == "ADD_ITEM" || 
                                                 actionType == "DELETE_ITEM" || 
                                                 actionType == "EDIT_ITEM";

                                    if (isCRUD && !_confirmedIndices.contains(index)) {
                                      if (widget.onActionTriggered != null) {
                                        widget.onActionTriggered!(actionType, msg["actionValue"]);
                                      }
                                      setState(() => _confirmedIndices.add(index));
                                    } else {
                                      if (widget.onActionTriggered != null) {
                                        if (isCRUD) {
                                          widget.onActionTriggered!("OPEN_SCREEN", "Inventory");
                                        } else {
                                          widget.onActionTriggered!(actionType, msg["actionValue"]);
                                        }
                                        widget.onClose();
                                      }
                                    }
                                  },
                                ),
                              ]
                            ]
                          ],
                        ),
                      ).animate().scale(duration: const Duration(milliseconds: 200), curve: Curves.easeOutBack),
                    );
                  },
                ),
              ),

              if (_isTyping)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("AI is typing...", style: TextStyle(color: isLight ? Colors.black54 : Colors.white54, fontStyle: FontStyle.italic))
                        .animate(onPlay: (c) => c.repeat(reverse: true)).fade(duration: 500.ms),
                  ),
                ),

              // Input Field
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLight ? Colors.grey.shade100 : Colors.black12,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _msgController,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Ask about your fridge...",
                          hintStyle: TextStyle(color: isLight ? Colors.black38 : Colors.white38),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                          filled: true,
                          fillColor: isLight ? Colors.white : Colors.white12,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: 1.5, curve: Curves.easeOutCubic);
  }

  IconData _getActionIcon(String action, int index) {
    if (action == "OPEN_SCREEN") return Icons.auto_awesome_motion;
    if (_confirmedIndices.contains(index)) return Icons.explore_outlined;
    return Icons.check_circle_outline;
  }

  String _getActionLabel(String action, String? value, int index) {
    final isCRUD = action == "ADD_ITEM_AI" || action == "ADD_ITEM" || 
                   action == "DELETE_ITEM" || action == "EDIT_ITEM";

    if (isCRUD && !_confirmedIndices.contains(index)) return "Confirm";
    
    if (action == "OPEN_SCREEN" || (isCRUD && _confirmedIndices.contains(index))) {
       return "Navigate to Fridge Inventory";
    }
    return "Confirm";
  }
}
