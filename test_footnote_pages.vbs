' ===================================================================
' سكربت VBA لاختبار: هل يمكن لـ Word COM تحديد أي حواشي تظهر في كل صفحة؟
' ===================================================================
' الاستخدام:
' 1. افتح كتاب "حوار هادئ مع الصوفية.docx" في Word
' 2. اضغط Alt+F11 لفتح محرر VBA
' 3. اذهب إلى Insert > Module
' 4. الصق هذا الكود واضغط F5 لتشغيله
' 5. النتائج ستظهر في Immediate Window (اضغط Ctrl+G لإظهاره)
'    وستُحفظ أيضاً في ملف نصي بجانب الوورد
' ===================================================================

Sub TestFootnotePages()
    Dim doc As Document
    Set doc = ActiveDocument
    
    Dim output As String
    output = "=== FOOTNOTE PAGE MAPPING TEST ===" & vbCrLf
    output = output & "Document: " & doc.Name & vbCrLf
    output = output & "Total Pages: " & doc.ComputeStatistics(wdStatisticPages) & vbCrLf
    output = output & "Total Footnotes: " & doc.Footnotes.Count & vbCrLf
    output = output & vbCrLf
    
    ' --- الطريقة 1: من كل حاشية، نحدد في أي صفحة تبدأ ---
    output = output & "=== METHOD 1: Footnote Start Pages ===" & vbCrLf
    
    Dim fn As Footnote
    Dim fnIndex As Integer
    fnIndex = 0
    
    For Each fn In doc.Footnotes
        fnIndex = fnIndex + 1
        
        ' صفحة المرجع في المتن (أين يظهر الرقم في النص)
        Dim refPage As Long
        refPage = fn.Reference.Information(wdActiveEndPageNumber)
        
        ' صفحة بداية نص الحاشية (أين يبدأ نص الحاشية في أسفل الصفحة)
        Dim fnStartPage As Long
        fnStartPage = fn.Range.Information(wdActiveEndPageNumber)
        
        ' صفحة نهاية نص الحاشية (أين ينتهي نص الحاشية)
        Dim fnRange As Range
        Set fnRange = fn.Range
        fnRange.Collapse wdCollapseEnd
        Dim fnEndPage As Long
        fnEndPage = fnRange.Information(wdActiveEndPageNumber)
        
        ' عدد الأحرف في الحاشية
        Dim charCount As Long
        charCount = fn.Range.Characters.Count
        
        ' أول 50 حرف من الحاشية
        Dim preview As String
        If charCount > 50 Then
            preview = Left(fn.Range.Text, 50) & "..."
        Else
            preview = fn.Range.Text
        End If
        ' تنظيف الأسطر الجديدة
        preview = Replace(preview, vbCr, " ")
        preview = Replace(preview, vbLf, " ")
        
        Dim spansMultiple As String
        If fnStartPage <> fnEndPage Then
            spansMultiple = " *** SPANS " & (fnEndPage - fnStartPage + 1) & " PAGES ***"
        Else
            spansMultiple = ""
        End If
        
        output = output & "FN #" & fnIndex & " | RefPage=" & refPage & _
                 " | FnStartPage=" & fnStartPage & " | FnEndPage=" & fnEndPage & _
                 " | Chars=" & charCount & spansMultiple & vbCrLf
        output = output & "   Preview: " & preview & vbCrLf
    Next fn
    
    output = output & vbCrLf
    
    ' --- الطريقة 2: لكل صفحة، نبحث عن أي حواشي فيها ---
    output = output & "=== METHOD 2: Pages -> Footnotes ===" & vbCrLf
    
    Dim totalPages As Long
    totalPages = doc.ComputeStatistics(wdStatisticPages)
    
    Dim pg As Long
    For pg = 1 To totalPages
        Dim pageFootnotes As String
        pageFootnotes = ""
        Dim fnCount As Integer
        fnCount = 0
        
        Dim fn2 As Footnote
        Dim fnIdx2 As Integer
        fnIdx2 = 0
        
        For Each fn2 In doc.Footnotes
            fnIdx2 = fnIdx2 + 1
            
            ' تحقق هل بداية أو نهاية هذه الحاشية تقع في هذه الصفحة
            Dim startPg As Long
            startPg = fn2.Range.Information(wdActiveEndPageNumber)
            
            Dim endRange As Range
            Set endRange = fn2.Range
            endRange.Collapse wdCollapseEnd
            Dim endPg As Long
            endPg = endRange.Information(wdActiveEndPageNumber)
            
            If pg >= startPg And pg <= endPg Then
                fnCount = fnCount + 1
                If pageFootnotes <> "" Then pageFootnotes = pageFootnotes & ", "
                pageFootnotes = pageFootnotes & "#" & fnIdx2
                
                If startPg <> endPg Then
                    If pg = startPg Then
                        pageFootnotes = pageFootnotes & "(starts)"
                    ElseIf pg = endPg Then
                        pageFootnotes = pageFootnotes & "(ends)"
                    Else
                        pageFootnotes = pageFootnotes & "(continues)"
                    End If
                End If
            End If
        Next fn2
        
        If fnCount > 0 Then
            output = output & "Page " & pg & ": [" & fnCount & " footnotes] " & pageFootnotes & vbCrLf
        Else
            output = output & "Page " & pg & ": (no footnotes)" & vbCrLf
        End If
    Next pg
    
    output = output & vbCrLf & "=== TEST COMPLETE ===" & vbCrLf
    
    ' طباعة في Immediate Window
    Debug.Print output
    
    ' حفظ في ملف
    Dim fPath As String
    fPath = doc.Path & "\footnote_pages_test.txt"
    
    Dim fNum As Integer
    fNum = FreeFile
    Open fPath For Output As #fNum
    Print #fNum, output
    Close #fNum
    
    MsgBox "Done! Results saved to:" & vbCrLf & fPath, vbInformation, "Footnote Test"
End Sub
