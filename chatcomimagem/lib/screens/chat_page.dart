import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:web_socket_client/web_socket_client.dart';
import 'package:image_picker_web/image_picker_web.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key, required this.name, required this.id})
      : super(key: key);

  final String name;
  final String id;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final socket = WebSocket(Uri.parse('ws://localhost:8765'));
  final List<types.Message> _messages = [];
  late types.User me;

  @override
  void initState() {
    super.initState();
    me = types.User(id: widget.id, firstName: widget.name);

    socket.messages.listen((incomingMessage) {
      try {
        Map<String, dynamic> data = jsonDecode(incomingMessage);
        String id = data['id'];
        String msg = data['msg'];
        String nick = data['nick'] ?? id;
        String type = data['type'] ?? 'text';
        String? mimeType = data['mime'];

        if (id != me.id) {
          final otherUser = types.User(id: id, firstName: nick);
          types.Message newMessage;

          if (type == 'image' && mimeType != null) {
            Uint8List imageBytes = base64Decode(msg);
            final blob = html.Blob([imageBytes], mimeType);
            final url =
                html.Url.createObjectUrlFromBlob(blob); // ✅ Correção aqui!

            newMessage = types.ImageMessage(
              author: otherUser,
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              uri: url,
              createdAt: DateTime.now().millisecondsSinceEpoch,
              name: "Imagem Recebida",
              size: imageBytes.length,
            );
          } else {
            newMessage = types.TextMessage(
              author: otherUser,
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              text: msg,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            );
          }

          _addMessage(newMessage);
        }
      } catch (e) {
        print("🔥 Erro ao processar mensagem recebida: $e");
      }
    });
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  Future<void> _pickAndSendImage() async {
    try {
      print("📸 Selecionando imagem...");
      final imageFile = await ImagePickerWeb.getImageAsFile();

      if (imageFile == null) {
        print("❌ Nenhuma imagem selecionada.");
        return;
      }

      final reader = html.FileReader();
      reader.readAsArrayBuffer(imageFile);
      await reader.onLoad.first;

      Uint8List imageBytes = reader.result as Uint8List;
      String base64Image = base64Encode(imageBytes);
      String mimeType = imageFile.type; // ✅ Pegando o MIME Type correto

      print("📤 Enviando imagem...");
      print("📏 Tamanho: ${imageBytes.length} bytes");

      var payload = {
        'id': me.id,
        'msg': base64Image,
        'nick': me.firstName,
        'mime': mimeType,
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': 'image',
      };

      socket.send(json.encode(payload));

      final blob = html.Blob([imageBytes], mimeType);
      final url =
          html.Url.createObjectUrlFromBlob(blob); // ✅ Criando um URL compatível

      final imageMessage = types.ImageMessage(
        author: me,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: "Imagem Enviada",
        size: imageBytes.length,
        uri: url, // ✅ Agora compatível com Flutter Web!
      );

      _addMessage(imageMessage);
      print("✅ Imagem enviada com sucesso!");
    } catch (e) {
      print("🔥 Erro ao selecionar/enviar imagem: $e");
    }
  }

  void _handleSendPressed(types.PartialText message) {
    var payload = {
      'id': me.id,
      'msg': message.text,
      'nick': me.firstName,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
      'type': 'text',
    };

    socket.send(json.encode(payload));

    final textMessage = types.TextMessage(
      author: me,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: message.text,
    );

    _addMessage(textMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text('Chat: ${widget.name}', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(
            child: Chat(
              messages: _messages,
              user: me,
              showUserAvatars: true,
              showUserNames: true,
              onSendPressed: _handleSendPressed,
              onAttachmentPressed: _pickAndSendImage,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    socket.close();
    super.dispose();
  }
}
