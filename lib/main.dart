import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
      title: 'Form Submission',
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
  String _profession = '';
  String _email = '';

  final List<String> _professions = [
    'Select Profession',
    'Engineer',
    'Doctor',
    'Driver',
    'Other'
  ];

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
                    initialValue: _phone,
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
                      _phone = value;
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
                      _fullName = value;
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
                      _age = int.tryParse(value) ?? 0;
                    },
                  ),
                  DropdownButtonFormField(
                    decoration: InputDecoration(labelText: 'Profession'),
                    value: _profession.isNotEmpty ? _profession : null,
                    items: _professions.map((profession) {
                      return DropdownMenuItem(
                        value: profession,
                        child: Text(profession),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _profession = value.toString();
                      });
                    },
                    validator: (value) {
                      if (value == null ||
                          value.isEmpty ||
                          value == _professions.first) {
                        return 'Profession is required';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    decoration: InputDecoration(labelText: 'Email (Optional)'),
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      _email = value;
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
      _showSubmittingDialog(); // Show submitting dialog immediately
      bool existsOnline = await checkIfUserExistsOnline();
      bool existsOffline = await checkIfUserExistsOffline();

      if (existsOnline || existsOffline) {
        Navigator.pop(context); // Dismiss the submitting dialog
        _showErrorDialog('User already exists in the database.');
      } else {
        bool isConnected = await _isConnected();
        if (isConnected) {
          await saveFormData();
          Navigator.pop(context); // Dismiss the submitting dialog
          _showSuccessDialog('Form submitted successfully.');
          _formKey.currentState!.reset();
        } else {
          Navigator.pop(context); // Dismiss the submitting dialog
          _showSuccessDialog('Form submitted successfully.');
          await saveFormDataLocally();
          _formKey.currentState!.reset();
        }
      }
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
    // Simulate offline check by querying local data
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection('local_forms')
        .where('phone', isEqualTo: _phone)
        .get();
    final List<DocumentSnapshot> documents = result.docs;
    return documents.isNotEmpty;
  }

  Future<void> saveFormData() async {
    await FirebaseFirestore.instance.collection('forms').add({
      'phone': _phone,
      'fullName': _fullName,
      'age': _age,
      'profession': _profession,
      'email': _email,
    });
    print('Form data saved successfully.');
  }

  Future<void> saveFormDataLocally() async {
    await FirebaseFirestore.instance.collection('local_forms').add({
      'phone': _phone,
      'fullName': _fullName,
      'age': _age,
      'profession': _profession,
      'email': _email,
    });
    print('Form data saved locally.');
  }

  void _showSubmittingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing dialog on outside tap
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
        title: Text('Error'),
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

  Future<bool> _isConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}
