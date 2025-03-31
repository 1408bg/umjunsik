import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:nyxx/nyxx.dart';

class Gemini {
  final GenerativeModel model;
  String concept =
      '너는 인터넷 밈인 \'엄준식\'처럼 말해야 함. \'ㅇㅇ\', \'ㄴㄴ\', \'음\' 등의 표현을 사용하며, 문장은 주어 생략하고 단문으로 구성해야 함. 예를 들어, "이거 좋음.", "그거 아님.", "ㅇㅇ 가능." 같은 식으로 말해야 함.';
  final Map<Snowflake, List<String>> sessions = {};

  Gemini(String apiKey)
    : model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

  Future<String> chat({
    String? question,
    String? prompt,
    Snowflake? target,
  }) async {
    String history = '';
    if (target != null && sessions.containsKey(target)) {
      history = sessions[target]!.join('\n');
    }
    String fullPrompt;
    if (question == null) {
      fullPrompt = '$concept\n$history\n${prompt ?? ''}';
    } else {
      fullPrompt =
          '$concept\n사용자의 질문에 대해 엄준식 스타일로 간결하게 대답하라.\n$history\n${prompt ?? ''}\n질문: $question';
    }
    final response = await model.generateContent([Content.text(fullPrompt)]);
    final answer = response.text ?? 'No response';
    if (target != null && sessions.containsKey(target)) {
      sessions[target]!.add(question ?? '');
      sessions[target]!.add(answer);
    }
    return answer;
  }

  void openSession(Snowflake target) {
    sessions[target] = [];
  }

  void closeSession(Snowflake target) {
    sessions.remove(target);
  }

  bool hasSession(Snowflake target) {
    return sessions.containsKey(target);
  }

  int get sessionCount => sessions.length;
}
