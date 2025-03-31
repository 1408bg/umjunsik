import 'dart:convert';
import 'package:nyxx/nyxx.dart';
import 'config.dart';
import 'module/gemini.dart';
import 'module/google.dart';
import 'module/request_counter.dart';

enum Commands {
  ping,
  um,
  getUserInfo,
  searchImage,
  searchLyrics,
  startChat,
  stopChat;

  String get commandName =>
      name
          .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'),
            (match) => '${match.group(1)}_${match.group(2)}',
          )
          .toLowerCase();
}

List<int> getImageFromBase64(String base64String) {
  final splitData = base64String.split(',');
  final pureBase64 = splitData.length > 1 ? splitData[1] : base64String;

  return base64Decode(pureBase64);
}

String getExtensionFromBase64(String base64String) {
  final match = RegExp(r'data:image/(\w+);base64,').firstMatch(base64String);
  return match != null ? match.group(1)! : 'unknown';
}

Future<User> getUserFromId({
  required NyxxGateway client,
  required Object id,
}) async {
  if (id.runtimeType == Snowflake) {
    return await client.users.get(id as Snowflake);
  }
  return await client.users.get(Snowflake.parse(id));
}

void main() async {
  final requestCounter = RequestCounter();

  final client = await Nyxx.connectGateway(
    Config.discordToken,
    GatewayIntents.all,
    options: GatewayClientOptions(plugins: [logging, cliIntegration]),
  );

  final gemini = Gemini(Config.geminiKey);
  final google = Google();

  await client.commands.create(
    ApplicationCommandBuilder.chatInput(
      name: Commands.ping.commandName,
      description: '연결 확인함. 지연시간도 알려줌 ㅇㅇ 뻐큐뻐큐',
      options: [],
    ),
  );

  await client.commands.create(
    ApplicationCommandBuilder.chatInput(
      name: Commands.um.commandName,
      description: 'umjunsik 말하기',
      options: [],
    ),
  );

  await client.commands.create(
    ApplicationCommandBuilder.chatInput(
      name: Commands.getUserInfo.commandName,
      description: '유저 정보 가져오기',
      options: [
        CommandOptionBuilder.user(
          name: 'user',
          description: '대상 유저',
          isRequired: true,
        ),
      ],
    ),
  );

  await client.commands.create(
    ApplicationCommandBuilder.chatInput(
      name: Commands.searchImage.commandName,
      description: '이미지 검색함. 구글에 게스트로 검색함.',
      options: [
        CommandOptionBuilder.string(
          name: 'query',
          description: '검색어',
          isRequired: true,
        ),
        CommandOptionBuilder.integer(
          name: 'n',
          description: 'n번째 이미지 선택',
          minValue: 0,
        ),
      ],
    ),
  );

  await client.commands.create(
    ApplicationCommandBuilder.chatInput(
      name: Commands.searchLyrics.commandName,
      description: 'open api써서 노래 가사 알려줌',
      options: [
        CommandOptionBuilder.string(
          name: 'artist',
          description: '작곡가',
          isRequired: true,
        ),
        CommandOptionBuilder.string(
          name: 'title',
          description: '제목',
          isRequired: true,
        ),
      ],
    ),
  );

  await client.commands.create(
    ApplicationCommandBuilder.chatInput(
      name: Commands.startChat.commandName,
      description: '정해준 유저와 대화함. /stop을 사용해서 멈출 수 있음.',
      options: [
        CommandOptionBuilder.user(
          name: 'target',
          description: '대화 대상',
          isRequired: true,
        ),
      ],
    ),
  );

  await client.commands.create(
    ApplicationCommandBuilder.chatInput(
      name: Commands.stopChat.commandName,
      description: '정해준 유저와의 대화를 멈춤',
      options: [
        CommandOptionBuilder.user(
          name: 'target',
          description: '대화중인 대상',
          isRequired: true,
        ),
      ],
    ),
  );

  client.onApplicationCommandInteraction.listen((event) async {
    try {
      final commandName = event.interaction.data.name;
      final params = event.interaction.data.options?.nonNulls.toList() ?? [];
      bool check(Commands command) => command.commandName == commandName;
      dynamic getParam(String key) {
        try {
          return params.firstWhere((param) => param.name == key).value;
        } on StateError {
          return null;
        }
      }

      if (check(Commands.ping)) {
        final start = event.interaction.id.timestamp;
        final end = DateTime.now();
        await event.interaction.respond(
          MessageBuilder(
            content: 'pong, 지연시간: ${start.difference(end).inMilliseconds}ms',
          ),
        );
      } else if (check(Commands.um)) {
        await event.interaction.respond(MessageBuilder(content: 'umjunsik'));
      } else if (check(Commands.getUserInfo)) {
        final userId = getParam('user');
        final user = await getUserFromId(client: client, id: userId);

        await event.interaction.respond(
          MessageBuilder(
            content:
                '"${user.globalName ?? user.username}"의 유저 정보:\nid: ${user.id}\nprofile: ${user.avatar.url}',
          ),
        );
      } else if (check(Commands.searchImage)) {
        final query = getParam('query').toString();
        final n = getParam('n') ?? 0;
        final base64image = await google.searchImage(query, n);
        if (base64image.isEmpty) {
          await event.interaction.respond(MessageBuilder(content: '사진이 없음'));
        } else {
          final img = getImageFromBase64(base64image);
          final ext = getExtensionFromBase64(base64image);
          await event.interaction.respond(
            MessageBuilder(
              content: '"$query" 검색 결과에서 ${n + 1}번째 사진을 찾음',
              attachments: [
                AttachmentBuilder(
                  data: img,
                  fileName: '${query.split(' ').join('_')}.$ext',
                ),
              ],
            ),
          );
        }
      } else if (check(Commands.searchLyrics)) {
        final artist = getParam('artist').toString();
        final title = getParam('title').toString().replaceAll(' ', '%20');
        final res = await google.searchLyrics(artist, title);
        await event.interaction.respond(
          MessageBuilder(content: '$title의 가사를 찾음\n```$res```'),
        );
        return;
      } else if (check(Commands.startChat)) {
        final userId = getParam('target');
        final user = await getUserFromId(client: client, id: userId);
        if (gemini.hasSession(user.id)) {
          await event.interaction.respond(MessageBuilder(content: '이미 대화중임'));
          return;
        }
        if (gemini.sessionCount == 3) {
          await event.interaction.respond(
            MessageBuilder(content: '3명이랑 대화하느라 바쁨. 나중에 다시 와'),
          );
          return;
        }
        final greet = await gemini.chat(
          prompt: '${user.globalName ?? user.username}에게 인사말을 건네줘',
        );
        gemini.openSession(user.id);

        await event.interaction.respond(
          MessageBuilder(content: '<@$userId> $greet'),
        );
      } else if (check(Commands.stopChat)) {
        final userId = getParam('target');
        final user = await getUserFromId(client: client, id: userId);
        if (!gemini.hasSession(user.id)) {
          await event.interaction.respond(MessageBuilder(content: '그게 누군데'));
        } else {
          final res = await gemini.chat(
            prompt:
                '${user.globalName ?? user.username}와의 대화가 끝났어, 이제 작별인사를 해줘',
            target: user.id,
          );
          gemini.closeSession(user.id);
          await event.interaction.respond(
            MessageBuilder(content: '<@${user.id}> $res'),
          );
        }
      }
    } catch (e) {
      print(e);
      if (!e.toString().contains('Unknown interaction')) {
        event.interaction.createFollowup(MessageBuilder(content: '오류 발생: $e'));
      }
    }
  });

  client.onMessageCreate.listen((event) async {
    bool ignore = false;
    send(message) async {
      if (ignore) return;
      final sender = event.message.author.id;
      requestCounter.add(sender, 1, duration: Duration(seconds: 2));
      final callCount = requestCounter.get(sender);
      if (callCount == 3) {
        await event.message.channel.sendMessage(
          MessageBuilder(
            content: '그만 좀 보내라 <@$sender>..',
            allowedMentions: AllowedMentions.users([sender]),
          ),
        );
        return;
      } else if (callCount > 3) {
        ignore = true;
        return;
      }
      await event.message.channel.sendMessage(
        MessageBuilder(
          content: message,
          referencedMessage: MessageReferenceBuilder.reply(
            messageId: event.message.id,
          ),
        ),
      );
    }

    try {
      final message = event.message;
      if (message.author.username == '엄준식') return;
      if (message.content == '준') {
        await send('식');
        return;
      }
      if (gemini.hasSession(message.author.id)) {
        final res = await gemini.chat(
          question: message.content,
          target: message.author.id,
        );
        await send(res);
        return;
      }
      if (message.content.startsWith('준식아') ||
          message.content.startsWith('엄준식')) {
        final query = message.content.split(' ').skip(1).join(' ').trim();
        if (query.isEmpty) {
          await send('ㅇ');
        } else {
          message.react(ReactionBuilder(name: '👁️', id: null));
          final res = await gemini.chat(question: query);
          await send(res);
        }
        return;
      }
      if (message.mentions.any((user) => user.id == client.application.id)) {
        final query = message.content.replaceAll('@엄준식', '').trim();
        if (query.isEmpty) {
          await send('ㅇ');
        } else {
          message.react(ReactionBuilder(name: '👁️', id: null));
          final res = await gemini.chat(question: query);
          await send(res);
        }
        return;
      }
      if (message.content.contains('um')) {
        final count =
            RegExp(
              RegExp.escape('um'),
            ).allMatches(event.message.content).length;
        await send('umjunsik${count == 1 ? '' : ' * $count'}');
        await message.react(ReactionBuilder(name: '❤️', id: null));
      }
      if (message.content.contains('엄')) {
        final count =
            RegExp(RegExp.escape('엄')).allMatches(event.message.content).length;
        await send('엄${count == 1 ? '' : ' * $count'}');
        await message.react(ReactionBuilder(name: '❤️', id: null));
      }
    } catch (e) {
      await send('오류 발생: $e');
    }
  });

  client.onReady.listen((event) {
    print('running...');
  });
}
