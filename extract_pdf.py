import fitz
doc = fitz.open("2023_12_Valenti (Secondary Paper).pdf")
text = ""
for page in doc:
    text += page.get_text()

with open("pdf_content.txt", "w", encoding="utf-8") as f:
    f.write(text)
