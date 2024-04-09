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
      home: FirstScreen(),
    );
  }
}

class FirstScreen extends StatelessWidget {
  final TextEditingController _phoneController =
      TextEditingController(text: '03');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tanzeem Registration App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Phone number is required';
                  } else if (value.length != 11 || !value.startsWith('03')) {
                    return 'Enter a valid phone number starting with "03"';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final phoneNumber = _phoneController.text;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SecondScreen(
                            phoneNumber: phoneNumber,
                          ),
                        ),
                      );
                    }
                  },
                  child: Text('Enter Number'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _phoneController.clear();
                  },
                  child: Text('Clear Number'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SecondScreen extends StatefulWidget {
  final String phoneNumber;

  const SecondScreen({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  _SecondScreenState createState() => _SecondScreenState();
}

class _SecondScreenState extends State<SecondScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  String? _profession;
  final TextEditingController _emailController = TextEditingController();
  late Database _database;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
    _fetchUserData();
    _syncDataWithFirestore();
    _syncDataWithFirestoreOnConnection();
  }

  void _initializeDatabase() async {
    _database = await openDatabase('registration.db', version: 1,
        onCreate: (Database db, int version) async {
      await db.execute(
          'CREATE TABLE IF NOT EXISTS forms (id INTEGER PRIMARY KEY, phone TEXT, fullName TEXT, age INTEGER, profession TEXT, email TEXT)');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tanzeem Registration App'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: InputDecoration(labelText: 'Full Name'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Full Name is required';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _ageController,
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
                ),
                DropdownButtonFormField<String>(
                  value: _profession,
                  items: ['Engineer', 'Doctor', 'Driver', 'Other']
                      .map((profession) {
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
                  decoration: InputDecoration(labelText: 'Profession'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Profession is required';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email (Optional)'),
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 20),
                _isSubmitting
                    ? CircularProgressIndicator()
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              _submitForm();
                            },
                            child: Text('Submit'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _clearData();
                            },
                            child: Text('Clear Data'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('Go back'),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      bool isConnected = await _isConnected();

      if (isConnected) {
        bool existsOffline = await checkIfUserExistsOffline();
        bool existsOnline = await checkIfUserExistsOnline();
        if (existsOnline || existsOffline) {
          await saveFormDataFirestore(updateIfExists: true);
          setState(() {
            _isSubmitting = false;
          });
          _showErrorDialog('Record updated successfully.');
        } else {
          await saveFormDataFirestore(updateIfExists: false);
          setState(() {
            _isSubmitting = false;
          });
          _showSuccessDialog('Form submitted successfully.');
        }
      } else {
        bool existsOffline = await checkIfUserExistsOffline();
        bool existsOnline = await checkIfUserExistsOnline();
        if (existsOffline) {
          await saveFormDataSQLite(updateIfExists: true);
          setState(() {
            _isSubmitting = false;
          });
          _showErrorDialog('Record updated successfully.');
        } else if (existsOnline) {
          await saveFormDataSQLite(updateIfExists: true);
          setState(() {
            _isSubmitting = false;
          });
          _showErrorDialog('Record updated successfully.');
        } else {
          await saveFormDataSQLite(updateIfExists: false);
          setState(() {
            _isSubmitting = false;
          });
          _showSuccessDialog('Form submitted successfully.');
        }
      }
    }
  }

  Future<bool> checkIfUserExistsOnline() async {
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection('forms')
        .where('phone', isEqualTo: widget.phoneNumber)
        .get();
    final List<DocumentSnapshot> documents = result.docs;
    return documents.isNotEmpty;
  }

  Future<bool> checkIfUserExistsOffline() async {
    final List<Map<String, dynamic>> result = await _database
        .rawQuery('SELECT * FROM forms WHERE phone = ?', [widget.phoneNumber]);
    return result.isNotEmpty;
  }

  Future<void> saveFormDataFirestore({required bool updateIfExists}) async {
    final docRef =
        FirebaseFirestore.instance.collection('forms').doc(widget.phoneNumber);
    final existsOnline = (await docRef.get()).exists;

    if (existsOnline && updateIfExists) {
      await docRef.update({
        'fullName': _fullNameController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'profession': _profession,
        'email': _emailController.text,
      });
    } else {
      await docRef.set({
        'phone': widget.phoneNumber,
        'fullName': _fullNameController.text,
        'age': int.tryParse(_ageController.text) ?? 0,
        'profession': _profession,
        'email': _emailController.text,
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
              [
                _fullNameController.text,
                int.tryParse(_ageController.text) ?? 0,
                _profession,
                _emailController.text,
                widget.phoneNumber
              ]);
          await batch.commit(noResult: true);
        });
      } else {
        await _database.transaction((txn) async {
          // Use batch operations for multiple inserts
          var batch = txn.batch();
          batch.rawInsert(
              'INSERT INTO forms(phone, fullName, age, profession, email) VALUES(?, ?, ?, ?, ?)',
              [
                widget.phoneNumber,
                _fullNameController.text,
                int.tryParse(_ageController.text) ?? 0,
                _profession,
                _emailController.text
              ]);
          await batch.commit(noResult: true);
        });
      }
    } else {
      await _database.transaction((txn) async {
        var batch = txn.batch();
        await txn.rawInsert(
            'INSERT INTO forms(phone, fullName, age, profession, email) VALUES(?, ?, ?, ?, ?)',
            [
              widget.phoneNumber,
              _fullNameController.text,
              int.tryParse(_ageController.text) ?? 0,
              _profession,
              _emailController.text
            ]);
        await batch.commit(noResult: true);
      });
    }
  }

  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
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
          'Alert',
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

  void _fetchUserData() async {
    bool isConnected = await _isConnected();

    if (isConnected) {
      final onlineData = await _fetchUserDataOnline();
      if (onlineData != null) {
        _showErrorDialog('Record Already Exists!');
        setState(() {
          _fullNameController.text = onlineData['fullName'];
          _ageController.text = onlineData['age'].toString();
          _profession = onlineData['profession'];
          _emailController.text = onlineData['email'];
        });
      } else {
        final offlineData = await _fetchUserDataOffline();
        if (offlineData != null) {
          _showErrorDialog('Record Already Exists');
          setState(() {
            _fullNameController.text = offlineData['fullName'];
            _ageController.text = offlineData['age'].toString();
            _profession = offlineData['profession'];
            _emailController.text = offlineData['email'];
          });
        }
      }
    } else {
      bool userExistsOnline = await checkIfUserExistsOnline();
      if (userExistsOnline) {
        final onlineData = await _fetchUserDataOnline();
        if (onlineData != null) {
          _showErrorDialog('Record Already Exists');
          setState(() {
            _fullNameController.text = onlineData['fullName'];
            _ageController.text = onlineData['age'].toString();
            _profession = onlineData['profession'];
            _emailController.text = onlineData['email'];
          });
        }
      } else {
        final offlineData = await _fetchUserDataOffline();
        if (offlineData != null) {
          _showErrorDialog('Record Already Exists!');
          setState(() {
            _fullNameController.text = offlineData['fullName'];
            _ageController.text = offlineData['age'].toString();
            _profession = offlineData['profession'];
            _emailController.text = offlineData['email'];
          });
        }
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchUserDataOnline() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('forms')
        .doc(widget.phoneNumber)
        .get();
    if (docSnapshot.exists) {
      return docSnapshot.data() as Map<String, dynamic>;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _fetchUserDataOffline() async {
    final List<Map<String, dynamic>> result = await _database
        .rawQuery('SELECT * FROM forms WHERE phone = ?', [widget.phoneNumber]);
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  void _clearData() {
    setState(() {
      _fullNameController.clear();
      _ageController.clear();
      _profession = null;
      _emailController.clear();
    });
    _formKey.currentState!.reset();
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
