' ===================================================================
' سكربت VBA v3: البحث عن تقسيم الحواشي الطويلة عبر الصفحات
' ===================================================================

Sub TestFootnotePagesV3()
    Dim doc As Document
    Set doc = ActiveDocument
    
    Dim output As String
    output = "=== FOOTNOTE PAGE MAPPING TEST V3 ===" & vbCrLf
    output = output & "Document: " & doc.Name & vbCrLf
    output = output & "Total Pages: " & doc.ComputeStatistics(wdStatisticPages) & vbCrLf
    output = output & "Total Footnotes: " & doc.Footnotes.Count & vbCrLf
    output = output & vbCrLf
    
    ' ===========================================================
    ' الطريقة A: التنقل في Footnote Story فقرة فقرة
    ' ===========================================================
    output = output & "=== FOOTNOTE STORY PARAGRAPHS ===" & vbCrLf
    
    Dim fnStory As Range
    On Error Resume Next
    Set fnStory = doc.StoryRanges(wdFootnotesStory)
    On Error GoTo 0
    
    If fnStory Is Nothing Then
        output = output & "ERROR: No footnote story found!" & vbCrLf
    Else
        Dim para As Paragraph
        Dim paraIdx As Long
        paraIdx = 0
        
        For Each para In fnStory.Paragraphs
            paraIdx = paraIdx + 1
            
            Dim paraPage As Long
            paraPage = para.Range.Information(wdActiveEndPageNumber)
            
            Dim pText As String
            pText = para.Range.Text
            If Len(pText) > 60 Then
                pText = Left(pText, 60) & "..."
            End If
            pText = Replace(pText, vbCr, "")
            pText = Replace(pText, vbLf, "")
            
            output = output & "  Para " & paraIdx & " | Page=" & paraPage & _
                     " | Chars=" & Len(para.Range.Text) & _
                     " | """ & pText & """" & vbCrLf
        Next para
        
        output = output & "Total paragraphs in footnote story: " & paraIdx & vbCrLf
    End If
    
    output = output & vbCrLf
    
    ' ===========================================================
    ' الطريقة B: للحواشي الطويلة - فحص بداية ونهاية كل فقرة
    ' ===========================================================
    output = output & "=== LONG FOOTNOTES - PARAGRAPH PAGES ===" & vbCrLf
    
    Dim fn As Footnote
    For Each fn In doc.Footnotes
        Dim fnLen As Long
        fnLen = Len(fn.Range.Text)
        
        If fnLen > 500 Then
            Dim refPg As Long
            refPg = fn.Reference.Information(wdActiveEndPageNumber)
            
            ' فحص كل فقرة داخل الحاشية
            Dim innerPages As String
            innerPages = ""
            Dim lastSeenPage As Long
            lastSeenPage = -1
            Dim pIdx As Long
            pIdx = 0
            
            Dim fnPara As Paragraph
            For Each fnPara In fn.Range.Paragraphs
                pIdx = pIdx + 1
                
                ' صفحة بداية الفقرة
                Dim startRng As Range
                Set startRng = fnPara.Range.Duplicate
                startRng.Collapse wdCollapseStart
                Dim startPg As Long
                startPg = startRng.Information(wdActiveEndPageNumber)
                
                ' صفحة نهاية الفقرة
                Dim endRng As Range
                Set endRng = fnPara.Range.Duplicate
                endRng.Collapse wdCollapseEnd
                Dim endPg As Long
                endPg = endRng.Information(wdActiveEndPageNumber)
                
                If startPg <> lastSeenPage Or endPg <> startPg Then
                    If innerPages <> "" Then innerPages = innerPages & " -> "
                    If startPg = endPg Then
                        innerPages = innerPages & "pg" & startPg & "(p" & pIdx & ")"
                    Else
                        innerPages = innerPages & "pg" & startPg & "-" & endPg & "(p" & pIdx & ")"
                    End If
                    lastSeenPage = endPg
                End If
            Next fnPara
            
            output = output & "FN #" & fn.Index & " | " & fnLen & " chars | " & pIdx & " paras" & _
                     " | RefPage=" & refPg & " | Pages: [" & innerPages & "]" & vbCrLf
        End If
    Next fn
    
    output = output & vbCrLf & "=== TEST V3 COMPLETE ===" & vbCrLf
    
    Debug.Print output
    
    Dim fPath As String
    fPath = doc.Path & "\footnote_pages_test_v3.txt"
    
    Dim fNum As Integer
    fNum = FreeFile
    Open fPath For Output As #fNum
    Print #fNum, output
    Close #fNum
    
    MsgBox "Done! Results saved to:" & vbCrLf & fPath, vbInformation, "Footnote Test V3"
End Sub
