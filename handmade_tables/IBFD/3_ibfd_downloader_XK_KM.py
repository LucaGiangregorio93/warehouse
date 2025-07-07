import os
import asyncio
import aiohttp
from datetime import datetime
import logging

# Configurazione logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    handlers=[
        logging.FileHandler("download_log_combined.txt", mode='a')
    ]
)

# Configurazioni
EXCEL_BASE_URL = "https://research.ibfd.org/collections/kf/excel/"
EXCEL_ARCHIVE_URL = "https://research.ibfd.org/archive/kf/excel/"
PDF_BASE_URLS = [
    ("ita", "https://research.ibfd.org/collections/ita/printversion/pdf/"),
    ("gthb", "https://research.ibfd.org/collections/gthb/printversion/pdf/")
]
PDF_ARCHIVE_URLS = [
    ("ita", "https://research.ibfd.org/archive/ita/printversion/pdf/"),
    ("gthb", "https://research.ibfd.org/archive/gthb/printversion/pdf/")
]

EXCEL_SAVE_DIR = "C:/Users/fsubioli/Dropbox/gcwealth/handmade_tables/IBFD/tables/"
PDF_SAVE_DIR = "C:/Users/fsubioli/Dropbox/gcwealth/handmade_tables/IBFD/pdf/"

# Paesi target
COUNTRIES = {
    "xk": {"save_code": "k1", "folder": "XK"},
    "km": {"save_code": "c5", "folder": "KM"},
}

async def download_file(session, url, save_path, semaphore):
    async with semaphore:
        try:
            async with session.get(url) as response:
                if response.status == 200:
                    with open(save_path, 'wb') as f:
                        f.write(await response.read())
                    return True
        except Exception as e:
            logging.warning(f"Errore download {url}: {e}")
    return False

async def download_excel(session, code, save_code, folder, semaphore):
    os.makedirs(folder, exist_ok=True)
    main_url = f"{EXCEL_BASE_URL}kf_{code}.xls"
    alt_url = f"{EXCEL_BASE_URL}kf_{save_code}.xls"
    save_path = os.path.join(folder, f"kf_{save_code.upper()}.xls")

    if not await download_file(session, main_url, save_path, semaphore):
        await download_file(session, alt_url, save_path, semaphore)
        await download_excel_archive(session, save_code, folder, save_code.upper(), semaphore)
    else:
        await download_excel_archive(session, code, folder, save_code.upper(), semaphore)

async def download_excel_archive(session, archive_code, folder, name, semaphore):
    tasks = []
    for year in range(2008, 2025):
        for month in range(1, 13):
            for day in range(1, 32):
                try:
                    datetime(year, month, day)
                except ValueError:
                    continue
                mm = f"{month:02d}"
                dd = f"{day:02d}"
                url = f"{EXCEL_ARCHIVE_URL}kf_{archive_code}_{year}-{mm}-{dd}.xls"
                save_path = os.path.join(folder, f"kf_{name}_{year}-{mm}-{dd}.xls")
                tasks.append(download_file(session, url, save_path, semaphore))
    await asyncio.gather(*tasks)

async def download_pdf(session, code, save_code, folder, semaphore):
    os.makedirs(folder, exist_ok=True)
    for prefix, base_url in PDF_BASE_URLS:
        main_url = f"{base_url}{prefix}_{code}.pdf"
        alt_url = f"{base_url}{prefix}_{save_code}.pdf"
        save_path = os.path.join(folder, f"{prefix}_{save_code.upper()}.pdf")

        if await download_file(session, main_url, save_path, semaphore):
            await download_pdf_archive(session, code, folder, save_code.upper(), semaphore, prefix)
            break
        elif await download_file(session, alt_url, save_path, semaphore):
            await download_pdf_archive(session, save_code, folder, save_code.upper(), semaphore, prefix)
            break

async def download_pdf_archive(session, archive_code, folder, name, semaphore, prefix):
    tasks = []
    for year in range(2008, 2025):
        for month in range(1, 13):
            for day in range(1, 32):
                try:
                    datetime(year, month, day)
                except ValueError:
                    continue
                mm = f"{month:02d}"
                dd = f"{day:02d}"
                filename = f"{prefix}_{archive_code}_{year}-{mm}-{dd}.pdf"
                save_path = os.path.join(folder, filename)
                for prfx, archive_url in PDF_ARCHIVE_URLS:
                    if prfx == prefix:
                        url = f"{archive_url}{filename}"
                        tasks.append(download_file(session, url, save_path, semaphore))
    await asyncio.gather(*tasks)

async def main():
    start_time = datetime.now()
    logging.info(f"Inizio download: {start_time}")
    semaphore = asyncio.Semaphore(10)

    async with aiohttp.ClientSession() as session:
        tasks = []
        for code, info in COUNTRIES.items():
            folder_excel = os.path.join(EXCEL_SAVE_DIR, info['folder'])
            folder_pdf = os.path.join(PDF_SAVE_DIR, info['folder'])
            tasks.append(download_excel(session, code, info['save_code'], folder_excel, semaphore))
            tasks.append(download_pdf(session, code, info['save_code'], folder_pdf, semaphore))

        await asyncio.gather(*tasks)

    end_time = datetime.now()
    logging.info(f"Download completato: {end_time}")
    logging.info(f"Durata: {end_time - start_time}")

if __name__ == "__main__":
    asyncio.run(main())
