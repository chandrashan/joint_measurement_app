import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mailer/flutter_mailer.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Joint Measure',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Joint Measure'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, File> _images = {};
  final picker = ImagePicker();
  bool isInProgress = false;
  bool isInResultView = false;
  Map<String, dynamic> analyzeResults = {};
  bool error = false;
  String errorMessage = "";

  TextEditingController emailAddressEditingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _triggerAnalyze(warmUp: true);
    _initEmailEditingController();
  }

  void _initEmailEditingController() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String email = prefs.getString('email') ?? "email@emil.com";
    emailAddressEditingController.text = email;
  }

  Future getImage(int index) async {
    final pickedFile = await picker.getImage(
        source: ImageSource.camera,
        maxHeight: 512,
        maxWidth: 512,
        imageQuality: 100);

    if (pickedFile != null) {
      _images[_getKeyByIndex(index)] = File(pickedFile.path);
    } else {
      print('No image selected.');
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        heightFactor: 1,
        child: SingleChildScrollView(
          child: isInResultView ? _resultView() : _form(),
        ),
      ),
    );
  }

  Widget _form() => Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          SizedBox(height: 50),
          _imagePickerButtonBlock(1),
          _imagePickerButtonBlock(2),
          _imagePickerButtonBlock(3),
          SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _imagePreviewBlock(1),
              _imagePreviewBlock(2),
              _imagePreviewBlock(3),
            ],
          ),
          SizedBox(height: 50),
          isInProgress
              ? CircularProgressIndicator()
              : ElevatedButton(
                  onPressed: () {
                    setState(() {
                      isInProgress = true;
                      _triggerAnalyze();
                      error = false;
                      errorMessage = "";
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 64.0, vertical: 16.0),
                    child: Text("Analyze"),
                  )),
          error
              ? Text(
                  errorMessage,
                  style: TextStyle(color: Colors.red),
                )
              : Container(),
        ],
      );

  Widget _resultView() => Column(
        children: [
          SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              maxLines: 1,
              decoration: InputDecoration(labelText: "Email"),
              controller: emailAddressEditingController,
            ),
          ),
          ElevatedButton(
              onPressed: () {
                _sendEmail(emailAddressEditingController.text);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 64.0, vertical: 16.0),
                child: Text("Email me"),
              )),
          SizedBox(height: 50),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _angleResultBlock(analyzeResults["photo_1_angle"], 1),
              _angleResultBlock(analyzeResults["photo_2_angle"], 2),
              _angleResultBlock(analyzeResults["photo_3_angle"], 3),
            ],
          ),
          SizedBox(height: 50),
          _resultImageBlock(analyzeResults["photo_1_processed"]),
          _resultImageBlock(analyzeResults["photo_2_processed"]),
          _resultImageBlock(analyzeResults["photo_3_processed"]),
          SizedBox(height: 50),
          ElevatedButton(
              onPressed: () {
                setState(() {
                  isInResultView = false;
                  _images = {};
                  analyzeResults = {};
                  error = false;
                  errorMessage = "";
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 64.0, vertical: 16.0),
                child: Text("New Analyze"),
              ))
        ],
      );

  String _getKeyByIndex(int index) => "photo_$index";

  Widget _imagePickerButtonBlock(int index) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: () => getImage(index),
          child: Text("Take Photo $index"),
        ),
      ],
    );
  }

  Widget _imagePreviewBlock(int index) {
    var key = _getKeyByIndex(index);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _images.containsKey(key) && _images[key] != null
                ? Image.memory(
                    _images[key]!.readAsBytesSync(),
                    height: 150,
                  )
                : Container(),
            SizedBox(height: 5),
            _images.containsKey(key) && _images[key] != null
                ? Text(
                    "${(_images[key]!.readAsBytesSync().lengthInBytes / (1024)).round()} KB")
                : Container(),
          ],
        ),
      ),
    );
  }

  Widget _angleResultBlock(value, index) => Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text("Angle $index - ${_getAngleValue(value)}"),
      );

  String _getAngleValue(value) => "${((value ?? 0) as num).toStringAsFixed(1)}";

  Widget _resultImageBlock(String? imageContent) {
    if (imageContent != null && imageContent.isNotEmpty) {
      var data =
          Base64Decoder().convert(Base64Codec().normalize(imageContent.trim()));
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.memory(data),
      );
    }
    return Container();
  }

  void _triggerAnalyze({bool warmUp = false}) async {
    Map<String, dynamic> data = {"api_key": "2a7c55b3c323"};
    var response = await sendForm(
        "https://australia-southeast1-orthorom.cloudfunctions.net/ortho-rom",
        data,
        _images,
        warmUp);

    // No need to validate the response for warm up call
    if (warmUp) return;

    if (response.statusCode == 200) {
      setState(() {
        isInResultView = true;
        isInProgress = false;
        analyzeResults = response.data;
      });
    } else {
      setState(() {
        isInResultView = false;
        isInProgress = false;
        analyzeResults = {};
        error = true;
        errorMessage = "Analyze request failed. Please try again";
      });
    }
  }

  Future<Response> sendForm(String url, Map<String, dynamic> data,
      Map<String, File> files, bool warmUp) async {
    if (!warmUp) {
      for (MapEntry fileEntry in files.entries) {
        File file = fileEntry.value;
        String fileName = basename(file.path);
        data[fileEntry.key] = MultipartFile(
            file.openRead(), await file.length(),
            filename: fileName);
      }
    }
    var formData = FormData.fromMap(data);
    Dio dio = new Dio();
    dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        requestHeader: true,
        responseHeader: true));
    return await dio.post(
      url,
      data: formData,
      options: Options(
          contentType: 'multipart/form-data', responseType: ResponseType.json),
    );
  }

  void _sendEmail(String address) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("email", address);

    var mailBody =
        'Angle 1 : ${_getAngleValue(analyzeResults["photo_1_angle"])} \n'
        'Angle 2 : ${_getAngleValue(analyzeResults["photo_2_angle"])} \n'
        'Angle 3 : ${_getAngleValue(analyzeResults["photo_3_angle"])} \n';

    var mailSubject = 'Joint measurement analyze results';

    final bool canSend = await FlutterMailer.canSendMail();

    if (Platform.isAndroid || canSend) {
      final MailOptions mailOptions = MailOptions(
        body: mailBody,
        subject: mailSubject,
        recipients: [address],
        isHTML: false,
      );

      final MailerResponse response = await FlutterMailer.send(mailOptions);
    } else {
      if (Platform.isIOS) {
        final Uri _emailLaunchUri = Uri(
            scheme: 'mailto',
            path: address,
            queryParameters: {
              'body': mailBody,
              'subject': mailSubject
            }
        );
        final url = _emailLaunchUri.toString();
        if (await canLaunch(url)) {
          await launch(url);
        } else {
          throw 'Could not launch $url';
        }
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
