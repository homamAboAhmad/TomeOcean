Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead("d:\ImportantProjects\golden_shamela\temp_book.docx")
$entry = $zip.Entries | Where-Object { $_.FullName -eq "word/styles.xml" }
$stream = $entry.Open()
$reader = New-Object System.IO.StreamReader($stream)
$content = $reader.ReadToEnd()
$reader.Close()
$stream.Close()
$zip.Dispose()
$content | Out-File -FilePath "d:\ImportantProjects\golden_shamela\temp_styles.xml" -Encoding UTF8
