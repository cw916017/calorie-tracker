import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(
  const MaterialApp(debugShowCheckedModeBanner: false, home: CalorieApp()),
);

class CalorieApp extends StatefulWidget {
  const CalorieApp({super.key});
  @override
  State<CalorieApp> createState() => _CalorieAppState();
}

class _CalorieAppState extends State<CalorieApp> {
  double totalEaten = 0;
  double totalProtein = 0;
  double tdeeGoal = 2000;
  List<Map<String, dynamic>> logs = [];
  bool isMale = true;

  // 體重追蹤清單與控制器
  final TextEditingController _weightLogCtrl = TextEditingController();
  List<Map<String, dynamic>> weightLogs = [];

  final TextEditingController _hCtrl = TextEditingController();
  final TextEditingController _wCtrl = TextEditingController();
  final TextEditingController _aCtrl = TextEditingController();
  double activity = 1.2;

  final TextEditingController _foodCtrl = TextEditingController();
  final TextEditingController _calCtrl = TextEditingController();
  final TextEditingController _proteinCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _apiSearchResults = [];
  bool _isLoading = false;

  // 本地常見原型食物速查表
  final List<Map<String, dynamic>> _localCommonFoods = [
    {"name": "雞蛋 (全蛋)", "cal": 144.0, "protein": 12.5},
    {"name": "水煮蛋", "cal": 144.0, "protein": 13.0},
    {"name": "茶葉蛋", "cal": 145.0, "protein": 13.3},
    {"name": "牛排 (沙朗/去脂)", "cal": 215.0, "protein": 22.0},
    {"name": "牛排 (肋眼)", "cal": 280.0, "protein": 19.0},
    {"name": "雞腿 (去皮)", "cal": 150.0, "protein": 19.0},
    {"name": "雞腿 (帶皮)", "cal": 215.0, "protein": 17.5},
    {"name": "雞胸肉", "cal": 112.0, "protein": 23.0},
    {"name": "白飯", "cal": 130.0, "protein": 2.5},
    {"name": "地瓜", "cal": 114.0, "protein": 1.5},
  ];

  // 常用中英文關鍵字對照
  final Map<String, String> _keywordTranslate = {
    "雞蛋": "egg",
    "蛋": "egg",
    "牛排": "steak",
    "牛肉": "beef",
    "雞腿": "chicken leg",
    "雞胸": "chicken breast",
    "雞胸肉": "chicken breast",
    "豬肉": "pork",
    "白飯": "rice",
    "牛奶": "milk",
  };

  // 🌐 將 API 抓到的英文品名自動對照並翻譯成流暢的中文
  String _translateProductName(String originalName) {
    String lower = originalName.toLowerCase();
    if (lower.contains("egg")) return "雞蛋/水煮蛋";
    if (lower.contains("steak") || lower.contains("beef")) return "牛排/牛肉";
    if (lower.contains("chicken leg")) return "雞腿";
    if (lower.contains("chicken breast")) return "雞胸肉";
    if (lower.contains("chicken")) return "雞肉製品";
    if (lower.contains("pork")) return "豬肉製品";
    if (lower.contains("rice")) return "米飯";
    if (lower.contains("milk")) return "牛奶";
    if (lower.contains("cheese")) return "起司";
    if (lower.contains("yogurt")) return "優格";
    if (lower.contains("apple")) return "蘋果";
    return originalName; // 如果沒對應到則保留原名
  }

  void _updateTDEE() {
    double? h = double.tryParse(_hCtrl.text);
    double? w = double.tryParse(_wCtrl.text);
    double? a = double.tryParse(_aCtrl.text);
    if (h != null && w != null && a != null) {
      double bmr = isMale
          ? (10 * w + 6.25 * h - 5 * a + 5)
          : (10 * w + 6.25 * h - 5 * a - 161);
      setState(() => tdeeGoal = bmr * activity);
      FocusScope.of(context).unfocus();
    }
  }

  void _addLog() {
    double? c = double.tryParse(_calCtrl.text);
    double? p = double.tryParse(_proteinCtrl.text) ?? 0;
    if (_foodCtrl.text.isNotEmpty && c != null) {
      setState(() {
        totalEaten += c;
        totalProtein += p;
        logs.insert(0, {"name": _foodCtrl.text, "cal": c, "protein": p});
      });
      _foodCtrl.clear();
      _calCtrl.clear();
      _proteinCtrl.clear();
      FocusScope.of(context).unfocus();
    }
  }

  // 新增體重紀錄
  void _addWeightLog() {
    double? w = double.tryParse(_weightLogCtrl.text);
    if (w != null) {
      setState(() {
        weightLogs.insert(0, {
          "date": "第 ${weightLogs.length + 1} 次紀錄",
          "weight": w,
        });
      });
      _weightLogCtrl.clear();
      FocusScope.of(context).unfocus();
    }
  }

  // 📋 產生每週回傳總結對話框
  void _showWeeklyReport() {
    double avgCal = totalEaten; // 可依實際需求擴充計算平均
    double lastWeight = weightLogs.isNotEmpty
        ? weightLogs.first['weight']
        : 0.0;
    double firstWeight = weightLogs.isNotEmpty
        ? weightLogs.last['weight']
        : lastWeight;
    double diff = lastWeight - firstWeight;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5EBE0),
        title: const Text(
          "📊 每週自我回傳總結",
          style: TextStyle(
            color: Color(0xFF7F5539),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("• 今日/累積攝取熱量: ${totalEaten.toInt()} kcal"),
            const SizedBox(height: 6),
            Text("• 累積蛋白質攝取: ${totalProtein.toStringAsFixed(1)} g"),
            const SizedBox(height: 6),
            Text("• 目前記錄體重: ${lastWeight > 0 ? '$lastWeight kg' : '尚未記錄'}"),
            const SizedBox(height: 6),
            Text(
              "• 階段體重變化: ${diff == 0 ? '持平' : '${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)} kg'}",
            ),
            const SizedBox(height: 12),
            const Text(
              "💡 狀態檢視：繼續保持自律，蛋白質攝取與總熱量控制在減脂區間內！",
              style: TextStyle(fontSize: 12, color: Colors.brown),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("關閉", style: TextStyle(color: Color(0xFF9C6644))),
          ),
        ],
      ),
    );
  }

  Future<void> _searchFood(String query) async {
    String keyword = query.trim();
    if (keyword.isEmpty) {
      setState(() => _apiSearchResults = []);
      return;
    }

    setState(() {
      _isLoading = true;
      _apiSearchResults = [];
    });

    List<Map<String, dynamic>> tempResults = [];

    for (var food in _localCommonFoods) {
      if (food['name'].toString().contains(keyword)) {
        tempResults.add(food);
      }
    }

    String apiQuery = _keywordTranslate[keyword] ?? keyword;

    try {
      final url = Uri.parse(
        'https://world.openfoodfacts.org/cgi/search.pl?search_terms=$apiQuery&search_simple=1&action=process&json=1',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List products = data['products'] ?? [];

        for (var product in products) {
          String rawName =
              product['product_name'] ?? product['product_name_en'] ?? '未知食物';
          String translatedName = _translateProductName(rawName);

          var nutriments = product['nutriments'] ?? {};
          double kcal =
              (nutriments['energy-kcal_100g'] ?? nutriments['energy-kcal'] ?? 0)
                  .toDouble();
          double protein =
              (nutriments['proteins_100g'] ?? nutriments['proteins'] ?? 0)
                  .toDouble();

          if (kcal > 0) {
            tempResults.add({
              "name": translatedName,
              "cal": kcal,
              "protein": protein,
            });
          }

          if (tempResults.length >= 12) break;
        }
      }
    } catch (e) {
      print("API 搜尋錯誤: $e");
    }

    setState(() {
      _apiSearchResults = tempResults;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    double progress = totalEaten / tdeeGoal;
    double fatLossLimit = tdeeGoal * 0.8;
    bool isOverLimit = totalEaten > fatLossLimit;
    Color milkTeaBg = const Color(0xFFF5EBE0);
    Color milkTeaCard = const Color(0xFFE3D5CA);
    Color milkTeaAccent = const Color(0xFFD5BDAF);

    return Scaffold(
      backgroundColor: milkTeaBg,
      appBar: AppBar(
        title: const Text(
          "自律者的記錄 (全功能進階版)",
          style: TextStyle(
            color: Color(0xFF7F5539),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: milkTeaAccent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment, color: Color(0xFF7F5539)),
            tooltip: "每週回傳總結",
            onPressed: _showWeeklyReport,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(milkTeaAccent),
                  const SizedBox(height: 20),
                  _buildCard("📊 TDEE 數據設定", _buildTDEEBox(), milkTeaCard),
                  const SizedBox(height: 15),
                  _buildCard("⚖️ 體重變化追蹤", _buildWeightBox(), milkTeaCard),
                  const SizedBox(height: 15),
                  _buildCard(
                    "🌐 智慧營養大數據快搜 (中文化)",
                    _buildSearchBox(),
                    milkTeaCard,
                  ),
                  const SizedBox(height: 15),
                  _buildExpansionHistory(milkTeaCard),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _buildQuickInputArea(milkTeaAccent),
          _buildBottomStatusBar(progress, fatLossLimit, isOverLimit),
        ],
      ),
    );
  }

  // ⚖️ 體重變化輸入與清單介面
  Widget _buildWeightBox() => Column(
    children: [
      Row(
        children: [
          Expanded(child: _tf(_weightLogCtrl, "輸入今日體重 (kg)", isNum: true)),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _addWeightLog,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C6644),
              minimumSize: const Size(60, 48),
            ),
            child: const Text("記錄", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      if (weightLogs.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: weightLogs.map((w) {
              return ListTile(
                dense: true,
                title: Text(
                  w['date'],
                  style: const TextStyle(color: Color(0xFF7F5539)),
                ),
                trailing: Text(
                  "${w['weight']} kg",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF9C6644),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ],
  );

  Widget _buildQuickInputArea(Color accent) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: accent.withOpacity(0.5),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, -5),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "🖋️ 記錄今日飲食與蛋白質",
          style: TextStyle(
            color: Color(0xFF7F5539),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(flex: 3, child: _tf(_foodCtrl, "吃了什麼?")),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: _tf(_calCtrl, "大卡/100g", isNum: true)),
            const SizedBox(width: 6),
            Expanded(flex: 2, child: _tf(_proteinCtrl, "蛋白質g", isNum: true)),
            const SizedBox(width: 6),
            ElevatedButton(
              onPressed: _addLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C6644),
                minimumSize: const Size(45, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildBottomStatusBar(double p, double limit, bool isOver) =>
      Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        color: Colors.white,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isOver ? "⚠️ 超量！" : "💡 減脂上限：${limit.toInt()} kcal",
                    style: TextStyle(
                      color: isOver ? Colors.red : Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const Text(
                    "© 2026 元泰所有版權",
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                value: p > 1 ? 1 : p,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                color: isOver ? Colors.red : const Color(0xFF9C6644),
              ),
            ],
          ),
        ),
      );

  Widget _buildHeader(Color accent) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: accent.withOpacity(0.3),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          children: [
            const Text(
              "今日累計攝取",
              style: TextStyle(color: Color(0xFF7F5539), fontSize: 13),
            ),
            Text(
              "${totalEaten.toInt()} kcal",
              style: const TextStyle(
                color: Color(0xFF9C6644),
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Container(
          width: 1,
          height: 40,
          color: const Color(0xFF7F5539).withOpacity(0.3),
        ),
        Column(
          children: [
            const Text(
              "累積蛋白質",
              style: TextStyle(color: Color(0xFF7F5539), fontSize: 13),
            ),
            Text(
              "${totalProtein.toStringAsFixed(1)} g",
              style: const TextStyle(
                color: Color(0xFF9C6644),
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildTDEEBox() => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: const Center(child: Text("男性")),
              selected: isMale,
              onSelected: (s) => setState(() => isMale = true),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ChoiceChip(
              label: const Center(child: Text("女性")),
              selected: !isMale,
              onSelected: (s) => setState(() => isMale = false),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _tf(_hCtrl, "身高", isNum: true)),
          const SizedBox(width: 5),
          Expanded(child: _tf(_wCtrl, "體重", isNum: true)),
          const SizedBox(width: 5),
          Expanded(child: _tf(_aCtrl, "年齡", isNum: true)),
        ],
      ),
      const SizedBox(height: 10),
      ElevatedButton(
        onPressed: _updateTDEE,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF9C6644),
          minimumSize: const Size(double.infinity, 45),
        ),
        child: const Text("更新 TDEE 目標", style: TextStyle(color: Colors.white)),
      ),
    ],
  );

  Widget _buildSearchBox() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: "輸入想查的食物 (例如: 雞蛋、牛排、雞腿)...",
                filled: true,
                fillColor: Colors.white.withOpacity(0.8),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7F5539)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _searchFood(_searchCtrl.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9C6644),
              minimumSize: const Size(50, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
      if (_isLoading) ...[
        const SizedBox(height: 15),
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF9C6644)),
        ),
      ],
      if (_apiSearchResults.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: _apiSearchResults.map((food) {
              return ListTile(
                dense: true,
                title: Text(
                  food['name'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7F5539),
                  ),
                ),
                subtitle: Text(
                  "每100g: ${food['cal'].toStringAsFixed(1)} kcal | 蛋白質: ${food['protein'].toStringAsFixed(1)}g",
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C6644),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    minimumSize: const Size(50, 30),
                  ),
                  onPressed: () {
                    setState(() {
                      _foodCtrl.text = food['name'];
                      _calCtrl.text = food['cal'].toStringAsFixed(0);
                      _proteinCtrl.text = food['protein'].toStringAsFixed(1);
                      _searchCtrl.clear();
                      _apiSearchResults = [];
                    });
                  },
                  child: const Text(
                    "帶入",
                    style: TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ],
  );

  Widget _buildExpansionHistory(Color cardCardColor) => Container(
    decoration: BoxDecoration(
      color: cardCardColor,
      borderRadius: BorderRadius.circular(15),
    ),
    child: ExpansionTile(
      title: const Text(
        "查閱今日歷史",
        style: TextStyle(
          color: Color(0xFF7F5539),
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      children: logs
          .map(
            (log) => ListTile(
              title: Text(log['name']),
              subtitle: Text("蛋白質: ${log['protein']}g"),
              trailing: Text(
                "${log['cal'].toInt()} kcal",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _tf(TextEditingController c, String h, {bool isNum = false}) =>
      TextField(
        controller: c,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          hintText: h,
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
      );

  Widget _buildCard(String t, Widget c, Color cardColor) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t,
          style: const TextStyle(
            color: Color(0xFF7F5539),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        c,
      ],
    ),
  );
}
