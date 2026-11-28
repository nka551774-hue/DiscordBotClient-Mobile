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

  test('booster badge level follows official month steps', () {
    final now = DateTime(2026, 11, 28);
    expect(DiscordBadgeInfo.booster(DateTime(2026, 11, 1), now: now).id,
        'guild_booster_lvl1');
    expect(DiscordBadgeInfo.booster(DateTime(2026, 8, 28), now: now).id,
        'guild_booster_lvl3');
    expect(DiscordBadgeInfo.booster(DateTime(2025, 11, 28), now: now).id,
        'guild_booster_lvl6');
    expect(DiscordBadgeInfo.booster(DateTime(2023, 1, 1), now: now).id,
        'guild_booster_lvl9');
  });

  test('account age badge tiers', () {
    final now = DateTime(2026, 11, 28);
    expect(DiscordBadgeInfo.accountAge(DateTime(2026, 1, 1), now: now), isNull);
    expect(DiscordBadgeInfo.accountAge(DateTime(2025, 11, 28), now: now)!.id,
        'account_age_1');
    expect(DiscordBadgeInfo.accountAge(DateTime(2015, 5, 13), now: now)!.iconUrl,
        endsWith('1d8caace0299b12bcc469c35ce927e838abd9c645a22fe7c556f4394e57fa79b.svg'));
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
