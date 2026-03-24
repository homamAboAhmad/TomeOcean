"""
اختبار Approach E بالتفصيل: doc.Range(para.Range.Start, para.Range.Start+1)
لكل فقرة في FN9 (39 فقرة)
"""
import win32com.client as win32
import os, sys, io

if sys.platform == "win32":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
        sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
    except:
        pass

DIAG_VBA = r"""
Sub DiagApproachE()
    Dim doc As Document
    Set doc = ActiveDocument
    
    Dim fn As Footnote
    Set fn = doc.Footnotes(9)
    
    Dim result As String
    result = "FN9: ref_page=" & fn.Reference.Information(wdActiveEndPageNumber) & ", paras=" & fn.Range.Paragraphs.Count & vbLf
    result = result & "Using doc.Range(para.Start, para.Start+1).Information(wdActiveEndPageNumber)" & vbLf & vbLf
    
    Dim para As Paragraph
    Dim j As Long
    Dim prevPage As Long
    Dim pageChanges As Long
    
    j = 0
    prevPage = -1
    pageChanges = 0
    
    For Each para In fn.Range.Paragraphs
        Dim charRange As Range
        Set charRange = doc.Range(para.Range.Start, para.Range.Start + 1)
        Dim pg As Long
        pg = charRange.Information(wdActiveEndPageNumber)
        
        If pg <> prevPage Then
            result = result & ">>> PAGE CHANGE at P" & j & ": " & prevPage & " -> " & pg & vbLf
            pageChanges = pageChanges + 1
            prevPage = pg
        End If
        
        ' Show first 5, transitions, and last 3
        If j < 5 Or j > 36 Then
            result = result & "  P" & j & ": page=" & pg & vbLf
        ElseIf j = 5 Then
            result = result & "  ... (showing transitions only) ..." & vbLf
        End If
        
        j = j + 1
    Next para
    
    result = result & vbLf & "TOTAL page changes: " & pageChanges & vbLf
    
    ' Also test FN14 (24 paras)
    result = result & vbLf & "=== FN14 (24 paras) ===" & vbLf
    Set fn = doc.Footnotes(14)
    j = 0
    prevPage = -1
    For Each para In fn.Range.Paragraphs
        Set charRange = doc.Range(para.Range.Start, para.Range.Start + 1)
        pg = charRange.Information(wdActiveEndPageNumber)
        If pg <> prevPage Then
            result = result & ">>> PAGE " & pg & " starts at P" & j & vbLf
            prevPage = pg
        End If
        j = j + 1
    Next para
    
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
word.ActiveWindow.View.Type = 3
doc.Repaginate()

vb_proj = doc.VBProject
mod = vb_proj.VBComponents.Add(1)
mod.Name = "DiagE"
mod.CodeModule.AddFromString(DIAG_VBA.strip())

print("Running Approach E diagnostic on FN9 and FN14...")
word.Run("DiagE.DiagApproachE")

result = doc.CustomDocumentProperties("DiagResult").Value
print("\n" + result)

doc.CustomDocumentProperties("DiagResult").Delete()
vb_proj.VBComponents.Remove(mod)
doc.Close(False)
word.Quit()
print("Done")
