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
  String? _profession; // Updated to allow null value
  String? _email;

  final List<String> _professions = ['Engineer', 'Doctor', 'Driver', 'Other'];

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
                        _phone = value; // Update phone number
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
                        _fullName = value; // Update full name
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
                        _age = int.tryParse(value) ?? 0; // Update age
                      });
                    },
                  ),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Profession'),
                    value: null, // Use nullable value
                    items: _professions.map((profession) {
                      return DropdownMenuItem(
                        value: profession,
                        child: Text(profession),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _profession = value; // Update profession
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
                    initialValue: null,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (value) {
                      setState(() {
                        _email = value; // Update email
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
                            _phone = '03'; // Reset phone number immediately
                            _profession = null; // Reset profession
                            _email = null; // Reset null
                          });
                          _formKey.currentState!.reset(); // Reset the form
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

      bool isConnected = await _isConnected();
      bool existsOnline = await checkIfUserExistsOnline();
      bool existsOffline = await checkIfUserExistsOffline();

      if (isConnected) {
        if (existsOnline) {
          // User exists online, update the existing record
          await saveFormData();

          Navigator.pop(context); // Dismiss the submitting dialog
          _showSuccessDialog('Record updated successfully.');
          setState(() {
            _phone = '03'; // Reset phone number immediately
            _profession = null; // Reset profession
            _email = null;
          });
          _formKey.currentState!.reset();
        } else {
          // User does not exist online, create a new record
          await saveFormData();

          Navigator.pop(context); // Dismiss the submitting dialog
          _showSuccessDialog('Form submitted successfully.');
          setState(() {
            _phone = '03'; // Reset phone number immediately
            _profession = null; // Reset profession
            _email = null;
          });
          _formKey.currentState!.reset();
        }
      } else {
        // User is offline, save data locally

        if (existsOffline) {
          // User exists offline, update the existing record
          Navigator.pop(context); // Dismiss the submitting dialog
          _showSuccessDialog('Record saved and will be updated successfully!');
          await saveFormDataLocally();
          setState(() {
            _phone = '03'; // Reset phone number immediately
            _profession = null; // Reset profession
            _email = null;
          });
          _formKey.currentState!.reset();
        } else {
          // User does not exist offline, create a new record

          Navigator.pop(context); // Dismiss the submitting dialog
          _showSuccessDialog(
              'Form submitted successfully in offline mode and will be synced.');
          await saveFormDataLocally();
          setState(() {
            _phone = '03'; // Reset phone number immediately
            _profession = null; // Reset profession
            _email = null;
          });
          _formKey.currentState!.reset();
        }
      }

      // Reset form fields and dismiss dialog
      // setState(() {
      //   _phone = '03'; // Reset phone number immediately
      //   _profession = null; // Reset profession
      //   _email = null; // Reset email
      // });
      // _formKey.currentState!.reset(); // Reset the form
      // Navigator.pop(context); // Dismiss the submitting dialog
    }
  }

  Future<bool> checkIfUserExistsOnline() async {
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection('forms')
        .where('phone', isEqualTo: _phone)
        .get();
    final List<DocumentSnapshot> documents = result.docs;
    print(documents);
    return documents.isNotEmpty;
  }

  Future<bool> checkIfUserExistsOffline() async {
    // Simulate offline check by querying local data
    final QuerySnapshot result = await FirebaseFirestore.instance
        .collection('forms')
        .where('phone', isEqualTo: _phone)
        .get();
    final List<DocumentSnapshot> documents = result.docs;
    return documents.isNotEmpty;
  }

  Future<void> saveFormData() async {
    bool existsOnline = await checkIfUserExistsOnline();
    if (existsOnline) {
      await FirebaseFirestore.instance.collection('forms').doc(_phone).update({
        'fullName': _fullName,
        'age': _age,
        'profession': _profession,
        // 'email': _email,
        'email': _email != null && _email!.isNotEmpty ? _email : null,
      });
    } else {
      await FirebaseFirestore.instance.collection('forms').doc(_phone).set({
        'phone': _phone,
        'fullName': _fullName,
        'age': _age,
        'profession': _profession,
        // 'email': _email,
        'email': _email != null && _email!.isNotEmpty ? _email : null,
      });
    }
    print('Form data saved successfully.');
  }

  Future<void> saveFormDataLocally() async {
    bool existsOnline = await checkIfUserExistsOnline();
    if (existsOnline) {
      await FirebaseFirestore.instance.collection('forms').doc(_phone).update({
        'fullName': _fullName,
        'age': _age,
        'profession': _profession,
        // 'email': _email,
        'email': _email != null && _email!.isNotEmpty ? _email : null,
      });
    } else {
      await FirebaseFirestore.instance.collection('forms').doc(_phone).set({
        'phone': _phone,
        'fullName': _fullName,
        'age': _age,
        'profession': _profession,
        // 'email': _email,
        'email': _email != null && _email!.isNotEmpty ? _email : null,
      });
    }
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
