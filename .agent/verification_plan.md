
# Verification Strategy

The user's specific file isn't found, and the existing `testDoc.docx` is failing (corrupt).
I will create a fresh `simple_test.docx` to verify the `pageRender.py` script.

## Steps
1.  Create `create_test_doc.py` to generate a valid .docx with 2 pages.
2.  Run `create_test_doc.py`.
3.  Run `pageRender.py` on `simple_test.docx`.
4.  Check output.
