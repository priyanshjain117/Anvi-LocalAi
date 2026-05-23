enum ChatRole { user, assistant }

class ChatTurn {
  final ChatRole role;
  final String text;

  const ChatTurn({
    required this.role,
    required this.text,
  });
}
