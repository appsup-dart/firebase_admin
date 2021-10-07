import 'package:firebase_admin/testing.dart';
import 'package:test/test.dart';

void main() async {
  var app = FirebaseAdmin.instance.initializeApp(AppOptions(
    credential: FirebaseAdmin.instance.testCredentials(),
    projectId: 'test',
    databaseUrl: 'mem://my.test.db',
  ));

  group('Accessing database', () {
    test('writing and reading data', () async {
      var ref = app.database().ref('test');
      expect(await ref.get(), null);
      await ref.set('hello world');
      expect(await ref.get(), 'hello world');
    });
  });
}
