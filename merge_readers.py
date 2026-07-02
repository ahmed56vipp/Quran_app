import os
import json

def merge_quran_data():
    # 1. تحديد مسارات الملفات والمجلدات بناءً على بنية مشروعك
    readers_path = os.path.join('assets', 'data', 'readers.json')
    audiourls_dir = os.path.join('assets', 'audiourls')
    output_path = os.path.join('assets', 'data', 'readers.json') # سيقوم بتحديث الملف مباشرة

    # التأكد من وجود الملف الرئيسي
    if not os.path.exists(readers_path):
        print(f"❌ خطأ: لم يتم العثور على ملف القراء في المسار: {readers_path}")
        return

    # 2. قراءة ملف readers.json الحالي
    with open(readers_path, 'r', encoding='utf-8') as f:
        try:
            readers_list = json.load(f)
        except json.JSONDecodeError:
            print("❌ خطأ: فشل في قراءة ملف readers.json، تأكد من صحة تنسيق الـ JSON.")
            return

    print(os.path.join('assets', 'data', 'readers.json'))
    print(f"🔄 جاري معالجة ودمج روابط {len(readers_list)} قارئ...")

    # 3. المرور على كل قارئ ودمج روابطه
    for reader in readers_list:
        reader_id = str(reader.get('id'))
        
        # تحضير المسارات المحتملة للملف (سواء كان .zip أو .json)
        zip_file_path = os.path.join(audiourls_dir, f"{reader_id}.zip")
        json_file_path = os.path.join(audiourls_dir, f"{reader_id}.json")
        
        tracks = []
        target_path = None

        # تحديد أي الملفين موجود لقراءته
        if os.path.exists(zip_file_path):
            target_path = zip_file_path
        elif os.path.exists(json_file_path):
            target_path = json_file_path

        if target_path:
            # قراءة محتوى ملف الروابط (بما أنه نص JSON صريح كما توضح الصور)
            with open(target_path, 'r', encoding='utf-8') as tf:
                try:
                    tracks = json.load(tf)
                except json.JSONDecodeError:
                    print(f"⚠️ تحذير: الملف {target_path} يحتوي على أخطاء في التنسيق وتم تخطيه.")
        else:
            print(f"ℹ️ تنبيه: لا يوجد ملف روابط للقارئ صاحب المعرّف {reader_id} ({reader.get('ar')})")

        # دمج الروابط داخل كائن القارئ الحالي
        reader['audio_tracks'] = tracks

    # 4. حفظ الملف المدمج والنهائي مكان ملف readers.json القديم
    with open(output_path, 'w', encoding='utf-8') as out_f:
        json.dump(readers_list, out_f, ensure_ascii=False, indent=2)
    
    print(f"✅ تم الدمج بنجاح! تم تحديث الملف في: {output_path}")

if __name__ == "__main__":
    merge_quran_data()
