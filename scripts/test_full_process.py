import sys
import os

sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import pageRender

input_doc = r'd:\ImportantProjects\golden_shamela\temp_diag_output\أعمال عبد العزيز شاكر الرافعي.docx'
output_doc = r'd:\ImportantProjects\golden_shamela\temp_diag_output\أعمال عبد العزيز شاكر الرافعي_processed.docx'

print("--- Testing process_file ---")
pageRender.process_file(input_doc, output_doc)
print("--- Finished process_file ---")
