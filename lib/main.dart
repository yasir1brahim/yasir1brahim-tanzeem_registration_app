import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'AIzaSyCdKROYeRUvlaJkqSIg1N4g5VRPF-QyI2g',
      appId: '1:981951535583:android:1c5852a81c916e3b764c6a',
      messagingSenderId: '981951535583',
      projectId: 'registration-newapp',
      storageBucket: 'registration-newapp.appspot.com',
    ),
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Tanzeem Registration App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _formKey = GlobalKey<FormState>();

  String _phone = '03';
  String _fullName = '';
  int _age = 0;
  String? _profession;
  String? _email;

  final List<String> _professions = ['Engineer', 'Doctor', 'Driver', 'Other'];

  late Database _database;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _syncDataWithFirestoreOnConnection();
  }

  void _initializeDatabase() async {
    _database = await openDatabase('registration.db', version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
          'CREATE TABLE forms (id INTEGER PRIMARY KEY, phone TEXT, fullName TEXT, age INTEGER, profession TEXT, email TEXT)');
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.teal.shade900,
          foregroundColor: Colors.white,
          title: Center(
            child: Text('Tanzeem Registration App'),
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Phone Number'),
                    initialValue: '03',
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Phone number is required';
                      } else if (value.length != 11 ||
                          !value.startsWith('03')) {
                        return 'Enter a valid phone number starting with "03"';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _phone = value;
                      });
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Full Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Full Name is required';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _fullName = value;
                      });
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Age'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Age is required';
                      }
                      int age = int.tryParse(value) ?? 0;
                      if (age < 5 || age > 100) {
                        return 'Age must be between 5 and 100';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _age = int.tryParse(value) ?? 0;
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Profession'),
                    value: null,
                    items: _professions.map((profession) {
                      return DropdownMenuItem(
                        value: profession,
                        child: Text(profession),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _profession = value;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Profession is required';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Email (Optional)'),
                    initialValue: _email,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      setState(() {
                        _email = value;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _submitForm(),
                        child: Text('Submit'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _phone = '03';
                            _profession = null;
                            _email = null;
                          });
                          _formKey.currentState!.reset();
                        },
                        child: Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _showSubmittingDialog();

      bool isConnected = await _isConnected();
      bool existsOnline = await checkIfUserExistsOnline();
      bool existsOffline = await checkIfUserExistsOffline();

      if (isConnected) {
        if (existsOnline || existsOffline) {
          await saveFormDataFirestore(updateIfExists: true);
          Navigator.pop(context); // Dismiss the submitting dialog
          _showErrorDialog('Record updated successfully.');
        } else {
          await saveFormDataFirestore(updateIfExists: false);
          Navigator.pop(context); // Dismiss the submitting dialog
          _showSuccessDialog('Form submitted successfully.');
        }
      } else {
        if (existsOffline || existsOnline) {
          await saveFormDataSQLite(updateIfExists: true);
          Navigator.pop(context); // Dismiss the submitting dialog
          _showErrorDialog('Record updated successfully.');
        } else {
          await saveFormDataSQLite(updateIfExists: false);
          Navigator.pop(context); // Dismiss the submitting dialog
          _showSuccessDialog('Form submitted successfully.');
        }
      }

      setState(() {
        _profession = null;
      });
      _formKey.currentState!.reset();
    }
  }

  Future<bool> checkIfUserExistsOnline() async {
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection('forms')
        .where('phone', isEqualTo: _phone)
        .get();
    final List<DocumentSnapshot> documents = result.docs;
    return documents.isNotEmpty;
  }

  Future<bool> checkIfUserExistsOffline() async {
    final List<Map<String, dynamic>> result = await _database
        .rawQuery('SELECT * FROM forms WHERE phone = ?', [_phone]);
    return result.isNotEmpty;
  }

  Future<void> saveFormDataFirestore({required bool updateIfExists}) async {
    final docRef = FirebaseFirestore.instance.collection('forms').doc(_phone);
    final existsOnline = (await docRef.get()).exists;

    if (existsOnline && updateIfExists) {
      await docRef.update({
        'fullName': _fullName,
        'age': _age,
        'profession': _profession,
        'email': _email,
      });
    } else {
      await docRef.set({
        'phone': _phone,
        'fullName': _fullName,
        'age': _age,
        'profession': _profession,
        'email': _email,
      });
    }
  }

  Future<void> saveFormDataSQLite({required bool updateIfExists}) async {
    final existsOffline = await checkIfUserExistsOffline();

    if (existsOffline) {
      if (updateIfExists) {
        await _database.transaction((txn) async {
          // Use batch operations for multiple updates
          var batch = txn.batch();
          batch.rawUpdate(
              'UPDATE forms SET fullName = ?, age = ?, profession = ?, email = ? WHERE phone = ?',
              [_fullName, _age, _profession, _email, _phone]);
          await batch.commit(noResult: true);
        });
      } else {
        await _database.transaction((txn) async {
          // Use batch operations for multiple inserts
          var batch = txn.batch();
          batch.rawInsert(
              'INSERT INTO forms(phone, fullName, age, profession, email) VALUES(?, ?, ?, ?, ?)',
              [_phone, _fullName, _age, _profession, _email]);
          await batch.commit(noResult: true);
        });
      }
    } else {
      await _database.transaction((txn) async {
        var batch = txn.batch();
        await txn.rawInsert(
            'INSERT INTO forms(phone, fullName, age, profession, email) VALUES(?, ?, ?, ?, ?)',
            [_phone, _fullName, _age, _profession, _email]);
        await batch.commit(noResult: true);
      });
    }
  }

  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void _showSubmittingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Submitting'),
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Please wait...'),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Success'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Error',
          style: TextStyle(color: Colors.red), // Set title color to red
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.red), // Set content text color to red
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _syncDataWithFirestoreOnConnection() async {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi) {
        _syncDataWithFirestore();
      }
    });
  }

  void _syncDataWithFirestore() async {
    final List<Map<String, dynamic>> records =
        await _database.rawQuery('SELECT * FROM forms');

    for (var record in records) {
      final docRef =
          FirebaseFirestore.instance.collection('forms').doc(record['phone']);
      final existsOnline = (await docRef.get()).exists;

      if (existsOnline) {
        await docRef.update({
          'fullName': record['fullName'],
          'age': record['age'],
          'profession': record['profession'],
          'email': record['email'],
        });
      } else {
        await docRef.set({
          'phone': record['phone'],
          'fullName': record['fullName'],
          'age': record['age'],
          'profession': record['profession'],
          'email': record['email'],
        });
      }
    }
  }
}
