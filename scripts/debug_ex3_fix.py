"""
debug_ex3_fix.py - Test robust VBA macro on ex3_test.docx
"""
import win32com.client as win32
import os

# Updated ROBUST macro
ROBUST_VBA = """
Sub ShamelaPrepareDoc()
    Dim doc As Document
    Set doc = ActiveDocument
    Application.ScreenUpdating = False
    
    ' Force repaginate to ensure page count is correct
    doc.Repaginate
    
    Dim totalPages As Long
    totalPages = doc.ComputeStatistics(wdStatisticPages)
    
    Dim debugLog As String
    debugLog = "Pages detected: " & totalPages & ";"
    
    Dim p As Long
    Dim r As Range
    
    ' Use Range object instead of Selection for better stability
    For p = 1 To totalPages
        On Error Resume Next
        Err.Clear
        
        ' GoTo using Document object returns a Range
        Set r = doc.GoTo(What:=wdGoToPage, Which:=wdGoToAbsolute, Count:=p)
        
        If Err.Number = 0 Then
            r.Collapse Direction:=wdCollapseStart
            doc.Bookmarks.Add Name:="ShamelaPage_" & p, Range:=r
            
            If Err.Number <> 0 Then
                debugLog = debugLog & " Err BM " & p & " (" & Err.Number & ");"
            End If
        Else
            debugLog = debugLog & " Err GoTo " & p & " (" & Err.Number & ");"
        End If
        On Error GoTo 0
    Next p
    
    ' === Footnotes Part (Kept similar but with Range object safety) ===
    Dim fnCount As Long
    fnCount = doc.Footnotes.Count
    Dim multiPageCount As Long
    multiPageCount = 0
    
    If fnCount > 0 Then
        Dim i As Long
        Dim prevPos As Long
        Dim vPos As Long
        Dim pageNum As Long
        Dim refPage As Long
        
        For i = 1 To fnCount
            Dim fn As Footnote
            Set fn = doc.Footnotes(i)
            
            refPage = fn.Reference.Information(wdActiveEndPageNumber)
            pageNum = refPage
            prevPos = -1
            
            Dim fnRange As Range
            Set fnRange = fn.Range
            Dim para As Paragraph
            
            For Each para In fnRange.Paragraphs
                On Error Resume Next
                vPos = para.Range.Information(wdVerticalPositionRelativeToPage)
                
                If prevPos > 0 And vPos < prevPos - 50 Then
                    pageNum = pageNum + 1
                    multiPageCount = multiPageCount + 1
                End If
                
                If prevPos = -1 Or (prevPos > 0 And vPos < prevPos - 50) Then
                    doc.Bookmarks.Add Name:="ShamelaFN_" & i & "_P" & pageNum, _
                                    Range:=para.Range.Duplicate.Characters(1)
                End If
                prevPos = vPos
                On Error GoTo 0
            Next para
        Next i
    End If
    
    debugLog = debugLog & " FN Multi: " & multiPageCount
    
    On Error Resume Next
    doc.CustomDocumentProperties("ShamelaResult").Delete
    On Error GoTo 0
    doc.CustomDocumentProperties.Add Name:="ShamelaResult", _
        LinkToContent:=False, Type:=msoPropertyTypeString, Value:=debugLog
        
    Application.ScreenUpdating = True
End Sub
"""

book_path = r'C:\Users\HP\Documents\ex3_test.docx'

word = win32.DispatchEx('Word.Application')
word.Visible = True
word.DisplayAlerts = 0

try:
    print(f'Opening: {book_path}')
    doc = word.Documents.Open(book_path, ReadOnly=False, AddToRecentFiles=False)
    
    print('Injecting robust macro...')
    vb_proj = doc.VBProject
    mod = vb_proj.VBComponents.Add(1)
    mod.Name = "RobustTest"
    mod.CodeModule.AddFromString(ROBUST_VBA.strip())
    
    print('Running ShamelaPrepareDoc...')
    word.Run("RobustTest.ShamelaPrepareDoc")
    print('Macro completed.')
    
    try:
        res = doc.CustomDocumentProperties("ShamelaResult").Value
        print(f'Result: {res}')
    except:
        print('No result property.')
        
    # Check bookmarks count
    print(f'Total Bookmarks: {doc.Bookmarks.Count}')
    
    doc.Close(False)

except Exception as e:
    print(f'FAILED: {e}')
finally:
    word.Quit()
