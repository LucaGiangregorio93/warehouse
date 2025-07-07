from PyPDF2 import PdfReader, PdfWriter  # Updated import

def extract_pages_between_keywords(pdf_path, start_keyword, end_keyword):
    pdf_reader = PdfReader(pdf_path)  # Updated class name
    start_page = end_page = None
    start_found = end_found = False

    # Iterate over each page to find the start and end keywords
    for page_num, page in enumerate(pdf_reader.pages):  # Updated iteration method
        page_text = page.extract_text()  # Updated method name

        if start_keyword in page_text and not start_found:
            start_page = page_num
            start_found = True
        if end_keyword in page_text and start_found and not end_found:
            end_page = page_num
            end_found = True
            break

    # Extract and save the pages between the keywords if found
    if start_page is not None and end_page is not None:
        pdf_writer = PdfWriter()  # Updated class name
        for i in range(start_page, end_page + 1):
            pdf_writer.add_page(pdf_reader.pages[i])  # Updated method to add pages

        # Dynamically create the output filename based on the start and end keywords
        output_filename = f'/Users/lucagiangregorio/Desktop/{start_keyword}_{end_keyword}_section.pdf'
        with open(output_filename, 'wb') as output_file:
            pdf_writer.write(output_file)
        return output_filename
    else:
        return "Section between keywords not found."

# Example usage:
pdf_path = 'C:\Users\lgiangregorio\Dropbox\gcwealth\handmade_tables\taxsched_input\EY EIG Guide\EY2023b.pdf'  # Replace with your actual PDF file path
result = extract_pages_between_keywords(pdf_path, "Milan", "Tokyo")
print(result)



