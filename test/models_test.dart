import 'package:discord_bot_client/models/discord_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Server Tag is read only while it is worn', () {
    final worn = DiscordUser.fromJson({
      'id': '1',
      'username': 'a',
      'primary_guild': {
        'identity_enabled': true,
        'identity_guild_id': '99',
        'tag': 'DEV',
        'badge': 'abc',
      },
    });
    expect(worn.guildTag, 'DEV');
    expect(worn.guildTagBadgeUrl,
        'https://cdn.discordapp.com/guild-tag-badges/99/abc.png?size=32');

    final off = DiscordUser.fromJson({
      'id': '1',
      'username': 'a',
      'primary_guild': {'identity_enabled': false, 'tag': 'DEV'},
    });
    expect(off.guildTag, isNull);

    // Round trip keeps the tag (DM recipients are persisted via toJson).
    expect(DiscordUser.fromJson(worn.toJson()).guildTag, 'DEV');
  });

  test('avatar decoration and /profile extras parse', () {
    final u = DiscordUser.fromJson({
      'id': '1',
      'username': 'a',
      'avatar_decoration_data': {'asset': 'a_deco'},
    });
    expect(u.avatarDecorationUrl, contains('avatar-decoration-presets/a_deco.png'));

    final extras = DiscordUserProfileExtras.fromJson({
      'user_profile': {
        'bio': 'hi',
        'pronouns': 'they/them',
        'theme_colors': [123, 'bad', 456],
      },
    });
    expect(extras.bio, 'hi');
    expect(extras.themeColors, [123, 456]);
  });
}
