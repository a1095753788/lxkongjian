import 'package:flutter_test/flutter_test.dart';
import 'package:local_douyin/services/video_scan_service.dart';

void main() {
  group('isNetworkVideoPath', () {
    test('http/https 开头的路径判定为网络视频', () {
      expect(isNetworkVideoPath('http://192.168.31.41:8765/m/a/video/x.mp4'), isTrue);
      expect(isNetworkVideoPath('https://example.com/video.mp4'), isTrue);
    });

    test('本地路径不判定为网络视频', () {
      expect(isNetworkVideoPath('/storage/emulated/0/DCIM/video.mp4'), isFalse);
      expect(isNetworkVideoPath('C:\\videos\\a.mp4'), isFalse);
      expect(isNetworkVideoPath('HTTP://example.com/a.mp4'), isFalse);
    });
  });

  group('parseNetworkVideosJson', () {
    const validJson = '''
    {
      "server": "http://192.168.31.41:8765",
      "videos": [
        {"url": "http://192.168.31.41:8765/m/1630621300/video/a.mp4",
         "name": "a.mp4", "size": 123456,
         "folder": "1630621300/video", "mtime": 1700000000},
        {"url": "http://192.168.31.41:8765/m/1630621301/video/b.mp4",
         "name": "b.mp4", "size": 789,
         "folder": "1630621301/video", "mtime": 1700000001}
      ]
    }
    ''';

    test('按约定格式解析字段', () {
      final data = parseNetworkVideosJson(validJson);
      expect(data.server, 'http://192.168.31.41:8765');
      expect(data.videos, hasLength(2));
      expect(data.videos.first.url,
          'http://192.168.31.41:8765/m/1630621300/video/a.mp4');
      expect(data.videos.first.name, 'a.mp4');
      expect(data.videos.first.size, 123456);
      expect(data.videos.first.folder, '1630621300/video');
      expect(data.videos.first.mtime, 1700000000);
    });

    test('空 videos 数组合法', () {
      final data = parseNetworkVideosJson('{"server":"http://x","videos":[]}');
      expect(data.videos, isEmpty);
    });

    test('格式错误抛出可阅读的中文 FormatException', () {
      expect(() => parseNetworkVideosJson('not json'),
          throwsA(isA<FormatException>()));
      expect(() => parseNetworkVideosJson('{"server":"http://x"}'),
          throwsA(isA<FormatException>()));
      expect(
        () => parseNetworkVideosJson(
            '{"server":"http://x","videos":[{"name":"a.mp4","folder":"f"}]}'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('groupNetworkVideosByFolder', () {
    test('按 folder 分组并保持组内顺序', () {
      final data = parseNetworkVideosJson('''
      {
        "server": "http://192.168.31.41:8765",
        "videos": [
          {"url":"u1","name":"1.mp4","size":1,"folder":"a/video","mtime":1},
          {"url":"u2","name":"2.mp4","size":2,"folder":"b/video","mtime":2},
          {"url":"u3","name":"3.mp4","size":3,"folder":"a/video","mtime":3}
        ]
      }
      ''');
      final groups = groupNetworkVideosByFolder(data.videos);

      expect(groups.keys, ['a/video', 'b/video']);
      expect(groups['a/video']!.map((v) => v.url), ['u1', 'u3']);
      expect(groups['b/video']!.map((v) => v.url), ['u2']);
    });

    test('空列表分组结果为空', () {
      expect(groupNetworkVideosByFolder([]), isEmpty);
    });
  });
}
