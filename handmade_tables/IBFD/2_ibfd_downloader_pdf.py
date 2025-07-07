import os
import pandas as pd
from datetime import datetime
import aiohttp
import asyncio
import logging

# Configurazione del logging
logging.basicConfig(
    level=logging.INFO,  # Imposta il livello di log
    format='%(asctime)s - %(message)s',  # Formato del log
    handlers=[
        logging.FileHandler("download_log.txt", mode='a')  # Per scrivere nel file di log
    ]
)

# URL base per i file principali
BASE_URLS = [
    "https://research.ibfd.org/collections/ita/printversion/pdf/",
    "https://research.ibfd.org/collections/gthb/printversion/pdf/"
]

# URL base per gli archivi giornalieri
ARCHIVE_URLS = [
    "https://research.ibfd.org/archive/ita/printversion/pdf/",
    "https://research.ibfd.org/archive/gthb/printversion/pdf/"
]

# Directory di salvataggio
SAVE_DIR = "C:/Users/fsubioli/Dropbox/gcwealth/handmade_tables/IBFD/pdf/"

# Contatore globale per i paesi elaborati e lista per i paesi falliti
processed_countries = 0
failed_countries = []

async def download_file(session, url, save_path, semaphore):
    try:
        async with semaphore:
            async with session.get(url) as response:
                if response.status == 200:
                    with open(save_path, 'wb') as f:
                        f.write(await response.read())
                    return True
                else:
                    return False
    except Exception as e:
        return False

async def download_country_data(session, country_code, semaphore, total_countries):
    global processed_countries
    if not isinstance(country_code, str):
        return
    code = country_code.lower()
    name = code.upper()
    folder = os.path.join(SAVE_DIR, name)
    os.makedirs(folder, exist_ok=True)

    success = False

    for base_url in BASE_URLS:
        prefix = "ita" if "ita" in base_url else "gthb"
        main_url = f"{base_url}{prefix}_{code}.pdf"
        alt_url = f"{base_url}{prefix}_{code[0]}1.pdf"
        save_path = os.path.join(folder, f"{prefix}_{name}.pdf")

        if await download_file(session, main_url, save_path, semaphore):
            await download_archive(session, code, folder, name, semaphore, prefix)
            success = True
            break
        elif await download_file(session, alt_url, save_path, semaphore):
            await download_archive(session, code[0] + "1", folder, name, semaphore, prefix)
            success = True
            break

    if not success:
        failed_countries.append(country_code)

    # Incrementa il contatore e stampa il progresso (solo per avanzamento)
    processed_countries += 1
    logging.info(f"Paesi elaborati: {processed_countries}/{total_countries}")

async def download_archive(session, archive_code, folder, name, semaphore, prefix):
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
                save_path = os.path.join(folder, f"{prefix}_{name}_{year}-{mm}-{dd}.pdf")

                for archive_url in ARCHIVE_URLS:
                    if prefix in archive_url:
                        url = f"{archive_url}{filename}"
                        tasks.append(download_file(session, url, save_path, semaphore))
    await asyncio.gather(*tasks)

async def main():
    start_time = datetime.now()
    logging.info(f"Inizio: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")

    df = pd.read_excel(
        "C:/Users/fsubioli/Dropbox/gcwealth/handmade_tables/dictionary.xlsx",
        sheet_name="GEO"
    )
    df = df[df['GEO'] != "_na"]
    df = df.rename(columns={"Country": "GEO_long"}).drop_duplicates()
    df['geo'] = df['GEO'].astype(str).str.lower()
    df = df[df['geo'].str.match(r'^[a-z]{2}$')]
    countries = df['geo'].tolist()
    total_countries = len(countries)

    semaphore = asyncio.Semaphore(10)

    async with aiohttp.ClientSession() as session:
        tasks = [download_country_data(session, c, semaphore, total_countries) for c in countries]
        await asyncio.gather(*tasks)

    end_time = datetime.now()
    logging.info(f"Fine: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
    logging.info(f"Durata: {end_time - start_time}")

    # Stampa i paesi che non sono stati trovati
    if failed_countries:
        logging.info("I seguenti paesi non sono stati trovati:")
        for country in failed_countries:
            logging.info(country)

if __name__ == "__main__":
    asyncio.run(main())
