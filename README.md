
A pure Dart implementation of the Firebase admin sdk

Currently, only supports admin methods for the following firebase services:

* authentication
* realtime database

## Usage

A simple usage example:

```dart
import 'package:firebase_admin/firebase_admin.dart';

main() async {
  var app = FirebaseAdmin.instance.initializeApp(AppOptions(
    credential: ServiceAccountCredential('service-account.json'),
  ));

  var link = await app.auth().generateSignInWithEmailLink('jane@doe.com',
      ActionCodeSettings(url: 'https://example.com'));

  print(link);
}
```



## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/appsup-dart/firebase_admin/issues
