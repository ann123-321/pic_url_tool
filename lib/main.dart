import 'package:flutter/material.dart';
import 'package:pic_url_tool/app_web_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TextEditingController _tokenTC;
  late TextEditingController _urlTC;
  @override
  void initState() {
    _tokenTC = TextEditingController();
    _urlTC = TextEditingController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('失敗還是成功勒')),
      body: Center(
        child: Column(
          children: [
            TextFormField(
              controller: _tokenTC,
              decoration: InputDecoration(
                label: Text('Access Token'),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
            SizedBox(height: 10),
            TextFormField(
              controller: _urlTC,
              decoration: InputDecoration(
                label: Text('URL'),
                contentPadding: EdgeInsets.all(10),
              ),
            ),
            SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {
                    final accessToken = _tokenTC.text;
                    final url = _urlTC.text;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AppWebView(
                          initialUrl: url,
                          headers: {'Authorization': 'Bearer $accessToken'},
                        ),
                      ),
                    );
                  },
                  child: Text('GO GO GO'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _tokenTC.clear();
                    _urlTC.clear();
                  },
                  child: Text('清空'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
