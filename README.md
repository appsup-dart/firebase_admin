
A pure Dart implementation of the Firebase admin sdk

Currently, only supports admin methods for the following firebase services:

* authentication
* realtime database

## Example using service account

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
## Example using default credentials

```dart
import 'package:firebase_admin/firebase_admin.dart';
import 'package:firebase_admin/src/credential.dart';

void main() async {
  // applicationDefault() will look for credentials in the following locations:
  // * the env variable GOOGLE_APPLICATION_CREDENTIALS
  // * a configuration file, specific for this library, stored in the user's home directory
  // * gcloud's application default credentials
  // * credentials from the firebase tools
  var credential = Credentials.applicationDefault();

  // when no credentials found, login using openid
  // the credentials are stored on disk for later use
  credential ??= await Credentials.login();

  // create an app
  var app = FirebaseAdmin.instance.initializeApp(AppOptions(
      credential: credential ?? Credentials.applicationDefault(),
      projectId: 'some-project'));

  try {
    // get a user by email
    var v = await app.auth().getUserByEmail('jane@doe.com');
    print(v.toJson());
  } on FirebaseException catch (e) {
    print(e.message);
  }
}

```


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/appsup-dart/firebase_admin/issues


## Sponsor

Creating and maintaining this package takes a lot of time. If you like the result, please consider to [:heart: sponsor](https://github.com/sponsors/rbellens). 
With your support, I will be able to further improve and support this project.
Also, check out my other dart packages at [pub.dev](https://pub.dev/packages?q=publisher%3Aappsup.be).



