"""
تشخيص شامل: اختبار كل الطرق الممكنة لمعرفة صفحة فقرة في الحاشية
نختبر على FN9 (39 فقرة - حتماً تمتد لعدة صفحات)
"""
import win32com.client as win32
import os, sys, io

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except:
        pass

# VBA macro يختبر كل الطرق الممكنة على FN9
DIAG_VBA = r"""
Sub DiagAllApproaches()
    Dim doc As Document
    Set doc = ActiveDocument
    
    Dim fn As Footnote
    Set fn = doc.Footnotes(9)
    
    Dim result As String
    result = "FN9: ref_page=" & fn.Reference.Information(wdActiveEndPageNumber) & ", paras=" & fn.Range.Paragraphs.Count & vbLf & vbLf
    
    ' === Approach A: wdActiveEndPageNumber (already known to fail) ===
    result = result & "=== A: wdActiveEndPageNumber ===" & vbLf
    Dim para As Paragraph
    Dim j As Long
    j = 0
    For Each para In fn.Range.Paragraphs
        If j < 5 Or j > 35 Then
            result = result & "  P" & j & ": " & para.Range.Information(wdActiveEndPageNumber) & vbLf
        ElseIf j = 5 Then
            result = result & "  ... (skipping middle) ..." & vbLf
        End If
        j = j + 1
    Next para
    
    ' === Approach B: Selection-based ===
    result = result & vbLf & "=== B: Selection + wdActiveEndPageNumber ===" & vbLf
    j = 0
    For Each para In fn.Range.Paragraphs
        If j < 5 Or j > 35 Then
            para.Range.Select
            result = result & "  P" & j & ": " & Selection.Information(wdActiveEndPageNumber) & vbLf
        ElseIf j = 5 Then
            result = result & "  ... (skipping middle) ..." & vbLf
        End If
        j = j + 1
    Next para
    
    ' === Approach C: wdVerticalPositionRelativeToPage ===
    result = result & vbLf & "=== C: wdVerticalPositionRelativeToPage ===" & vbLf
    j = 0
    For Each para In fn.Range.Paragraphs
        If j < 5 Or j > 35 Then
            Dim vPos As Long
            On Error Resume Next
            vPos = para.Range.Information(wdVerticalPositionRelativeToPage)
            If Err.Number <> 0 Then
                result = result & "  P" & j & ": ERROR" & vbLf
                Err.Clear
            Else
                result = result & "  P" & j & ": " & vPos & vbLf
            End If
            On Error GoTo 0
        ElseIf j = 5 Then
            result = result & "  ... (skipping middle) ..." & vbLf
        End If
        j = j + 1
    Next para
    
    ' === Approach D: Selection + GoTo each para + check page ===
    result = result & vbLf & "=== D: Selection.GoTo footnote range ===" & vbLf
    j = 0
    For Each para In fn.Range.Paragraphs
        If j < 5 Or j > 35 Then
            Dim startR As Range
            Set startR = para.Range.Duplicate
            startR.Collapse wdCollapseStart
            startR.Select
            
            Dim selPage As Long
            selPage = Selection.Information(wdActiveEndPageNumber)
            result = result & "  P" & j & ": sel_page=" & selPage & vbLf
        ElseIf j = 5 Then
            result = result & "  ... (skipping middle) ..." & vbLf
        End If
        j = j + 1
    Next para
    
    ' === Approach E: Characters first/last page ===
    result = result & vbLf & "=== E: First char vs Last char of footnote ===" & vbLf
    Dim firstCharRange As Range
    Set firstCharRange = doc.Range(fn.Range.Start, fn.Range.Start + 1)
    
    Dim lastCharRange As Range
    Set lastCharRange = doc.Range(fn.Range.End - 1, fn.Range.End)
    
    On Error Resume Next
    result = result & "  First char page: " & firstCharRange.Information(wdActiveEndPageNumber) & vbLf
    result = result & "  Last char page: " & lastCharRange.Information(wdActiveEndPageNumber) & vbLf
    On Error GoTo 0
    
    ' === Approach F: Footnote Reference page vs actual rendering ===
    result = result & vbLf & "=== F: StoryRanges ===" & vbLf
    Dim fnStory As Range
    Set fnStory = doc.StoryRanges(wdFootnotesStory)
    result = result & "  Footnote story page (start): " & fnStory.Information(wdActiveEndPageNumber) & vbLf
    
    ' Save result
    On Error Resume Next
    doc.CustomDocumentProperties("DiagResult").Delete
    On Error GoTo 0
    doc.CustomDocumentProperties.Add Name:="DiagResult", _
        LinkToContent:=False, Type:=msoPropertyTypeString, Value:=result
End Sub
"""

book_path = r'C:\Users\HP\Documents\57pحوار هادئ مع الصوفية.docx'
word = win32.DispatchEx('Word.Application')
word.Visible = True
word.DisplayAlerts = 0

doc = word.Documents.Open(book_path, ReadOnly=False, AddToRecentFiles=False)
word.ActiveWindow.View.Type = 3  # wdPrintView
doc.Repaginate()

print(f"Pages: {doc.ComputeStatistics(2)}, Footnotes: {doc.Footnotes.Count}")

vb_proj = doc.VBProject
mod = vb_proj.VBComponents.Add(1)
mod.Name = "DiagAll"
mod.CodeModule.AddFromString(DIAG_VBA.strip())

print("Running comprehensive diagnostic on FN9...")
word.Run("DiagAll.DiagAllApproaches")

result = doc.CustomDocumentProperties("DiagResult").Value
print("\n" + result)

doc.CustomDocumentProperties("DiagResult").Delete()
vb_proj.VBComponents.Remove(mod)
doc.Close(False)
word.Quit()
print("Done")
