import 'package:flutter_test/flutter_test.dart';
import 'package:reminding/core/utils/name_sanitizer.dart';

void main() {
  group('NameSanitizer', () {
    test('removes forbidden characters', () {
      expect(NameSanitizer.sanitize(r'hello/world:test*?<>|"'), 'helloworldtest');
      expect(NameSanitizer.sanitize('note\u0000with\u001Fcontrol\u007F'), 'notewithcontrol');
    });

    test('replaces leading underscore with hyphen', () {
      expect(NameSanitizer.sanitize('_hidden_folder'), '-hidden_folder');
      expect(NameSanitizer.sanitize('___triple_underscore'), '-triple_underscore');
    });

    test('trims whitespace and trailing dots', () {
      expect(NameSanitizer.sanitize('  my note...  '), 'my note');
      expect(NameSanitizer.sanitize('note.'), 'note');
    });

    test('limits length to 80 characters', () {
      final longName = 'a' * 100;
      final sanitized = NameSanitizer.sanitize(longName);
      expect(sanitized.length, 80);
      expect(sanitized, 'a' * 80);
    });

    test('defaults to "unnamed" when empty or all forbidden', () {
      expect(NameSanitizer.sanitize(''), 'unnamed');
      expect(NameSanitizer.sanitize('   '), 'unnamed');
      expect(NameSanitizer.sanitize('///:::***'), 'unnamed');
    });

    test('resolves case-insensitive conflicts with " (2)", " (3)" without extension', () {
      final existing = ['My Folder', 'Work'];
      expect(NameSanitizer.resolveCollision('my folder', existing), 'my folder (2)');
      expect(NameSanitizer.resolveCollision('MY FOLDER', existing), 'MY FOLDER (2)');

      final existingWith2 = ['My Folder', 'My Folder (2)'];
      expect(NameSanitizer.resolveCollision('My Folder', existingWith2), 'My Folder (3)');
    });

    test('resolves conflicts preserving file extensions', () {
      final existingFiles = ['Meeting.json', 'Tasks.json'];
      expect(
        NameSanitizer.resolveCollision('meeting', existingFiles, extension: '.json'),
        'meeting (2).json',
      );

      final existingFiles2 = ['Meeting.json', 'meeting (2).json'];
      expect(
        NameSanitizer.resolveCollision('Meeting', existingFiles2, extension: '.json'),
        'Meeting (3).json',
      );
    });
  });
}
