# Arabic Morphological Analyzer Tester

مشروع لاختبار المكتبات المختلفة لاستخراج الجذور الصرفية للكلمات العربية.

## التثبيت

```bash
# إنشاء بيئة افتراضية (اختياري)
python -m venv venv
source venv/bin/activate  # على Windows: venv\Scripts\activate

# تثبيت المكتبات
pip install -r requirements.txt
```

## الاستخدام

### 1. اختبار مباشر

```bash
python test_morphology.py
```

أو اختبار كلمات محددة:
```bash
python test_morphology.py محاماة دعا قراءة
```

### 2. تشغيل API Server

```bash
python api_server.py
```

الخادم سيعمل على `http://localhost:5000`

### 3. اختبار API من Flutter

```dart
// مثال في Flutter
final response = await http.post(
  Uri.parse('http://localhost:5000/get_root'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'word': 'محاماة'}),
);

final data = jsonDecode(response.body);
print('Root: ${data['root']}');  // يجب أن يعطي: حمي
```

## المكتبات المدعومة

1. **Farasa** - الأفضل والأدق
2. **CAMeL Tools** - شامل ومتقدم
3. **PyArabic** - بسيط وسريع
4. **ISRI Stemmer** - خوارزمية بسيطة

## ملاحظات

- **Farasa**: الإصدار المتاح (0.0.1) قد يكون قديماً ولا يحتوي على `stemmer` module. قد تحتاج إلى استخدام إصدار أحدث أو مكتبة بديلة.
- **CAMeL Tools**: يحتاج إلى `torch` (~500MB) وقد يستغرق وقتاً في التثبيت. يمكنك تثبيته لاحقاً إذا أردت.
- **PyArabic**: متوفر ويعمل، لكنه لا يحتوي على stemmer متقدم، فقط أدوات أساسية.
- بعض المكتبات قد تحتاج إلى اتصال إنترنت للتحميل الأولي فقط.

## الحالة الحالية

- ✅ **PyArabic**: مثبت ويعمل (أدوات أساسية)
- ⚠️ **Farasa**: مثبت لكن البنية قد تكون مختلفة
- ❌ **CAMeL Tools**: غير مثبت (اختياري - يحتاج torch كبير)

## الاختبار

الكلمات المختبرة:
- دعونا → يجب أن يعطي: دعو
- دعوت → يجب أن يعطي: دعو
- الدعوات → يجب أن يعطي: دعو
- ادعاء → يجب أن يعطي: دعو
- المحاماة → يجب أن يعطي: حمي
- كاتب → يجب أن يعطي: كتب
- قراءة → يجب أن يعطي: قرأ

## API Endpoints

### GET /health
فحص حالة الخادم والمكتبات المتاحة

### POST /analyze
تحليل كلمة واحدة باستخدام جميع المكتبات المتاحة
```json
{
  "word": "محاماة"
}
```

### POST /analyze_batch
تحليل عدة كلمات دفعة واحدة
```json
{
  "words": ["محاماة", "دعا", "قراءة"]
}
```

### POST /get_root
الحصول على الجذر باستخدام أفضل مكتبة متاحة
```json
{
  "word": "محاماة",
  "library": "Farasa"  // اختياري
}
```

