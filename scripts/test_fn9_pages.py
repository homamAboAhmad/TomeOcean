"""
تشخيص: هل VBA يكتشف تقسيم الحواشي فعلاً؟
نفحص FN 9 (39 فقرة) بالتفصيل.
"""
import win32com.client as win32
import os, sys, io

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except:
        pass

# VBA macro يفحص أول 15 حاشية ويطبع صفحة كل فقرة
DIAG_VBA = """
Sub DiagFN()
    Dim doc As Document
    Set doc = ActiveDocument
    
    Dim result As String
    result = ""
    
    Dim fnCount As Long
    fnCount = doc.Footnotes.Count
    
    Dim i As Long
    For i = 1 To fnCount
        If i > 15 Then Exit For
        
        Dim fn As Footnote
        Set fn = doc.Footnotes(i)
        
        Dim refPage As Long
        refPage = fn.Reference.Information(wdActiveEndPageNumber)
        
        Dim paraCount As Long
        paraCount = fn.Range.Paragraphs.Count
        
        result = result & "FN" & i & " ref=" & refPage & " paras=" & paraCount
        
        If paraCount > 1 Then
            result = result & " pages=["
            Dim para As Paragraph
            Dim j As Long
            j = 0
            For Each para In fn.Range.Paragraphs
                If j > 0 Then result = result & ","
                result = result & para.Range.Information(wdActiveEndPageNumber)
                j = j + 1
            Next para
            result = result & "]"
        End If
        
        result = result & vbLf
    Next i
    
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

# Inject and run diagnostic
vb_proj = doc.VBProject
mod = vb_proj.VBComponents.Add(1)
mod.Name = "DiagModule"
mod.CodeModule.AddFromString(DIAG_VBA.strip())

word.Run("DiagModule.DiagFN")

result = doc.CustomDocumentProperties("DiagResult").Value
print("\n=== VBA Diagnostic Results ===")
print(result)

doc.CustomDocumentProperties("DiagResult").Delete()
vb_proj.VBComponents.Remove(mod)
doc.Close(False)
word.Quit()
