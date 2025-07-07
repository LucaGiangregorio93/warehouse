import os
import pandas as pd
from datetime import datetime
import aiohttp
import asyncio
import logging

# Configurazione del logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s',
    handlers=[
        logging.FileHandler("download_log_excel.txt", mode='a')
    ]
)

BASE_URL = "https://research.ibfd.org/collections/kf/excel/"
ARCHIVE_URL = "https://research.ibfd.org/archive/kf/excel/"
SAVE_DIR = "C:/Users/fsubioli/Dropbox/gcwealth/handmade_tables/IBFD/tables/"

# Contatore globale
processed_countries = 0

async def download_file(session, url, save_path, semaphore):
    async with semaphore:
        try:
            async with session.get(url) as response:
                if response.status == 200:
                    with open(save_path, 'wb') as f:
                        f.write(await response.read())
                    return True
                else:
                    return False
        except Exception:
            return False

async def download_country_data(session, country_code, semaphore, total_countries):
    global processed_countries

    if not isinstance(country_code, str):
        return
    code = country_code.lower()
    name = code.upper()
    folder = os.path.join(SAVE_DIR, name)
    os.makedirs(folder, exist_ok=True)

    main_url = f"{BASE_URL}kf_{code}.xls"
    alt_url = f"{BASE_URL}kf_{code[0]}1.xls"
    save_path = os.path.join(folder, f"kf_{name}.xls")

    if not await download_file(session, main_url, save_path, semaphore):
        if await download_file(session, alt_url, save_path, semaphore):
            await download_archive(session, code[0] + "1", folder, name, semaphore)
    else:
        await download_archive(session, code, folder, name, semaphore)

    processed_countries += 1
    logging.info(f"Paesi elaborati: {processed_countries}/{total_countries}")

async def download_archive(session, archive_code, folder, name, semaphore):
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
                url = f"{ARCHIVE_URL}kf_{archive_code}_{year}-{mm}-{dd}.xls"
                save_path = os.path.join(folder, f"kf_{name}_{year}-{mm}-{dd}.xls")
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

if __name__ == "__main__":
    asyncio.run(main())
