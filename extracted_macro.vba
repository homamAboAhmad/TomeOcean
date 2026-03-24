Attribute VB_Name = "Module1"
Sub ShamelaPrepareDoc()
    ' الماكرو الشامل (Ultimate Edition)
    ' يقوم بـ:
    ' 1. إعداد العرض (PrintLayout)
    ' 2. تحديث التخطيط (Repaginate)
    ' 3. حساب الصفحات
    ' 4. حقن إشارات الصفحات (مع حماية ضد الأخطاء)
    ' 5. معالجة الحواشي
    
    Dim doc As Document
    Set doc = ActiveDocument
    
    ' 1. إعداد العرض (مهم لحساب الصفحات بدقة)
    On Error Resume Next
    If Application.Windows.Count > 0 Then
        Application.ActiveWindow.View.Type = wdPrintView
    End If
    On Error GoTo 0
    
    Application.ScreenUpdating = False
    
    ' 2. تحديث التخطيط لضمان دقة الأرقام
    doc.Repaginate
    
    ' 3. حساب عدد الصفحات الفعلي
    Dim totalPages As Long
    totalPages = doc.ComputeStatistics(wdStatisticPages)
    
    ' 4. حقن إشارات الصفحات (Robust Loop)
    Dim p As Long
    Dim r As Range
    
    For p = 1 To totalPages
        On Error Resume Next
        Err.Clear
        
        ' استخدام Range.GoTo بدلاً من Selection (أكثر استقراراً)
        Set r = doc.GoTo(What:=wdGoToPage, Which:=wdGoToAbsolute, Count:=p)
        
        If Err.Number = 0 Then
            r.Collapse Direction:=wdCollapseStart
            doc.Bookmarks.Add Name:="ShamelaPage_" & p, Range:=r
        End If
        
        On Error GoTo 0
    Next p
    
    ' 5. معالجة الحواشي
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
    
    Application.ScreenUpdating = True
    
    ' حفظ النتيجة (عدد الصفحات + الحواشي) ليقرأها البايثون
    Dim result As String
    result = "Pages: " & totalPages & ", Multi-page FN: " & multiPageCount
    
    On Error Resume Next
    doc.CustomDocumentProperties("ShamelaResult").Delete
    On Error GoTo 0
    doc.CustomDocumentProperties.Add Name:="ShamelaResult", _
        LinkToContent:=False, Type:=msoPropertyTypeString, Value:=result
End Sub

