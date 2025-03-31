abstract class Config {
  static const String discordToken = String.fromEnvironment(
    'DISCORD_TOKEN',
    defaultValue: 'discord_token',
  );
  static const String geminiKey = String.fromEnvironment(
    'GEMINI_KEY',
    defaultValue: 'gemini_key',
  );
}
