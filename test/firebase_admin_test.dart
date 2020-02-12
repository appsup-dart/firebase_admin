import 'src/app.dart' as app;
import 'src/auth.dart' as auth;

void main() async {
  await app.main();
  await auth.main();
}
