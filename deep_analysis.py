"""
تحليل عميق للفرق بين Word و XML
يستخدم Word API للحصول على رقم الصفحة الحقيقي لكل فقرة
ثم يقارنه مع حسابنا من XML
"""
import win32com.client as win32
import zipfile
import xml.etree.ElementTree as ET
import sys
import os

NS = {'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'}

def get_word_page_for_each_paragraph(docx_path):
    """يستخدم Word API للحصول على رقم الصفحة لكل فقرة"""
    print("Opening Word to get actual page numbers...")
    
    word = win32.Dispatch("Word.Application")
    word.Visible = False
    word.DisplayAlerts = 0
    
    results = []
    
    try:
        doc = word.Documents.Open(os.path.abspath(docx_path), ReadOnly=True)
        doc.Repaginate()
        
        total_paras = doc.Paragraphs.Count
        print(f"Total paragraphs in Word: {total_paras}")
        
        # جمع رقم الصفحة لكل فقرة
        for i in range(1, min(total_paras + 1, 500)):  # حد أقصى 500 للسرعة
            try:
                para = doc.Paragraphs(i)
                # الحصول على رقم الصفحة لهذه الفقرة
                page_num = para.Range.Information(3)  # wdActiveEndPageNumber = 3
                
                # الحصول على أول 50 حرف من النص للتعريف
                text_preview = para.Range.Text[:50].replace('\r', ' ').replace('\n', ' ').strip()
                
                results.append({
                    'para_index': i,
                    'word_page': page_num,
                    'text_preview': text_preview
                })
                
                if i % 50 == 0:
                    print(f"  Processed {i}/{total_paras} paragraphs...")
                    
            except Exception as e:
                print(f"  Error at para {i}: {e}")
                
        doc.Close(False)
        
    finally:
        try:
            word.Quit()
        except:
            pass
    
    return results

def get_xml_page_for_each_paragraph(docx_path):
    """يحسب رقم الصفحة لكل فقرة باستخدام منطق XML الحالي"""
    print("Analyzing XML page breaks...")
    
    with zipfile.ZipFile(docx_path, 'r') as z:
        xml_content = z.read('word/document.xml')
    
    root = ET.fromstring(xml_content)
    body = root.find(f"{{{NS['w']}}}body")
    
    results = []
    current_page = 1
    para_index = 0
    
    for element in body:
        if element.tag == f"{{{NS['w']}}}p":
            para_index += 1
            
            # تسجيل الصفحة الحالية لهذه الفقرة
            page_at_start = current_page
            
            # البحث عن فواصل الصفحات (نفس المنطق في pageRender.py)
            breaks_in_para = []
            
            for run in element.findall(f".//{{{NS['w']}}}r"):
                has_manual = False
                has_lastRendered = False
                
                for br in run.findall(f".//{{{NS['w']}}}br"):
                    if br.get(f"{{{NS['w']}}}type") == "page":
                        has_manual = True
                        break
                
                if run.find(f".//{{{NS['w']}}}lastRenderedPageBreak") is not None:
                    has_lastRendered = True
                
                if has_manual:
                    breaks_in_para.append('MANUAL')
                    current_page += 1
                elif has_lastRendered:
                    breaks_in_para.append('LAST_RENDERED')
                    current_page += 1
            
            # الحصول على نص الفقرة
            text_parts = []
            for t in element.findall(f".//{{{NS['w']}}}t"):
                if t.text:
                    text_parts.append(t.text)
            text_preview = ''.join(text_parts)[:50].strip()
            
            results.append({
                'para_index': para_index,
                'xml_page': page_at_start,
                'breaks': breaks_in_para,
                'text_preview': text_preview
            })
    
    print(f"Total paragraphs in XML: {para_index}")
    print(f"Final XML page count: {current_page}")
    
    return results, current_page

def compare_and_find_discrepancies(word_results, xml_results):
    """يقارن النتائج ويجد أماكن الاختلاف"""
    print("\n" + "="*60)
    print("COMPARING Word vs XML page assignments...")
    print("="*60)
    
    discrepancies = []
    
    min_len = min(len(word_results), len(xml_results))
    
    for i in range(min_len):
        word_page = word_results[i]['word_page']
        xml_page = xml_results[i]['xml_page']
        
        if word_page != xml_page:
            discrepancies.append({
                'para_index': i + 1,
                'word_page': word_page,
                'xml_page': xml_page,
                'diff': xml_page - word_page,
                'breaks': xml_results[i].get('breaks', []),
                'text': word_results[i]['text_preview'][:30]
            })
    
    if discrepancies:
        print(f"\nFound {len(discrepancies)} discrepancies!")
        print("\nFirst 20 discrepancies:")
        print("-" * 80)
        
        for d in discrepancies[:20]:
            print(f"Para {d['para_index']:4d} | Word: {d['word_page']:3d} | XML: {d['xml_page']:3d} | Diff: {d['diff']:+3d} | Breaks: {d['breaks']} | '{d['text']}'")
        
        # تحليل: أين بدأ الفرق؟
        print("\n" + "="*60)
        print("ANALYSIS: Where did the discrepancy start?")
        print("="*60)
        
        first_disc = discrepancies[0]
        print(f"First discrepancy at paragraph {first_disc['para_index']}")
        print(f"  Word says: page {first_disc['word_page']}")
        print(f"  XML says: page {first_disc['xml_page']}")
        print(f"  Breaks in this para: {first_disc['breaks']}")
        
        # نظرة على الفقرات قبلها
        print("\nParagraphs around first discrepancy:")
        start_idx = max(0, first_disc['para_index'] - 3)
        end_idx = min(min_len, first_disc['para_index'] + 3)
        
        for i in range(start_idx, end_idx):
            marker = ">>> " if i == first_disc['para_index'] - 1 else "    "
            print(f"{marker}Para {i+1}: Word={word_results[i]['word_page']}, XML={xml_results[i]['xml_page']}, Breaks={xml_results[i].get('breaks', [])}")
            
    else:
        print("No discrepancies found! Word and XML match perfectly.")
    
    return discrepancies

def main(docx_path):
    print(f"Deep Analysis of: {docx_path}")
    print("="*60)
    
    # 1. الحصول على أرقام الصفحات من Word
    word_results = get_word_page_for_each_paragraph(docx_path)
    
    # 2. الحصول على أرقام الصفحات من XML
    xml_results, xml_total = get_xml_page_for_each_paragraph(docx_path)
    
    # 3. المقارنة
    discrepancies = compare_and_find_discrepancies(word_results, xml_results)
    
    return discrepancies

if __name__ == "__main__":
    if len(sys.argv) > 1:
        main(sys.argv[1])
    else:
        print("Usage: python deep_analysis.py <docx_path>")
