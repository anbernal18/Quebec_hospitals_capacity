"""
Extracts structured data from the MSSS 'Relevé quotidien de la situation
à l'urgence' PDF into tidy CSV files, using pdfplumber's table extraction
(column-aware) instead of raw text flow -- this correctly handles
installation names that wrap across two lines.

USAGE:
    python extract_quotidien.py <path_to_pdf> [output_folder]

    If output_folder is omitted, files are saved to ./weekly_extracts/
    Each run creates ONE new pair of CSVs named after the PDF's own
    "Mise à jour" date, so you can safely run this every week without
    overwriting previous weeks -- just point it at the new PDF.
"""

import pdfplumber
import re
import csv
import sys
import os

METRICS = [
    "patients_sur_civiere",
    "patients_24h_plus",
    "patients_48h_plus",
    "visites_totales_veille",
]


def get_report_date(first_page_text):
    """
    Reads the report's own 'Mise à jour : DD month YYYY' line to figure out
    the year and a filename-safe date -- instead of hardcoding a year, and
    instead of relying on you to type today's date correctly by hand.
    """
    match = re.search(r"Mise à jour\s*:\s*(\d{1,2})\s+(\w+)\s+(\d{4})", first_page_text)
    months = {
        "janvier": "01", "février": "02", "mars": "03", "avril": "04",
        "mai": "05", "juin": "06", "juillet": "07", "août": "08",
        "septembre": "09", "octobre": "10", "novembre": "11", "décembre": "12",
    }
    if not match:
        return "unknown-date", "2026"  # fallback, shouldn't normally happen
    day, month_name, year = match.groups()
    month_num = months.get(month_name.lower(), "00")
    return f"{year}-{month_num}-{int(day):02d}", year


def clean_val(v):
    if v is None:
        return None
    v = v.strip()
    return None if v in ("", "N/D") else int(v)


def get_dates(header_row):
    dates = []
    for cell in header_row:
        if cell and re.match(r"\d{2}/\d{2}", cell):
            d = cell.split("\n")[0]
            if d not in dates:
                dates.append(d)
    return dates[:7]


def parse_data_row(row, dates, writer, year, extra_cols):
    name = (row[0] or "").replace("\n", " ").strip()
    if not name or name.lower().startswith(("notes", "source", "mise à jour", "en collaboration", "msss,")):
        return False
    civ = clean_val(row[1])

    vals = row[2:2 + 43]
    if len(vals) < 43:
        return False

    idx = 0
    for metric in METRICS:
        daily = vals[idx:idx + 7]
        for date, v in zip(dates, daily):
            val = clean_val(v)
            writer.writerow(extra_cols + [name, civ, f"{year}-{date[3:]}-{date[0:2]}", metric, val])
        idx += 9

    taux_daily = vals[idx:idx + 7]
    for date, v in zip(dates, taux_daily):
        val = clean_val(v)
        writer.writerow(extra_cols + [name, civ, f"{year}-{date[3:]}-{date[0:2]}", "taux_occupation", val])

    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python extract_quotidien.py <path_to_pdf> [output_folder]")
        sys.exit(1)

    pdf_path = sys.argv[1]
    output_folder = sys.argv[2] if len(sys.argv) > 2 else "weekly_extracts"
    os.makedirs(output_folder, exist_ok=True)

    with pdfplumber.open(pdf_path) as pdf:
        first_page_text = pdf.pages[0].extract_text()
        report_date, year = get_report_date(first_page_text)
        print(f"Report date detected: {report_date}")

        region_file = os.path.join(output_folder, f"quotidien_by_region_{report_date}.csv")
        installation_file = os.path.join(output_folder, f"quotidien_by_installation_{report_date}.csv")

        # --- Page 1: province-wide, by region ---
        with open(region_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["region", "civ", "date", "metric", "value", "extraction_date"])
            table = pdf.pages[0].extract_tables()[0]
            dates = get_dates(table[3])
            count = 0
            for row in table[4:]:
                name = (row[0] or "").replace("\n", " ").strip()
                if not name or name.lower().startswith(("notes", "source", "mise à jour", "en collaboration", "msss,")):
                    continue
                civ = clean_val(row[1])
                vals = row[2:2 + 43]
                if len(vals) < 43:
                    continue
                idx = 0
                for metric in METRICS:
                    daily = vals[idx:idx + 7]
                    for date, v in zip(dates, daily):
                        writer.writerow([name, civ, f"{year}-{date[3:]}-{date[0:2]}", metric, clean_val(v), report_date])
                    idx += 9
                taux_daily = vals[idx:idx + 7]
                for date, v in zip(dates, taux_daily):
                    writer.writerow([name, civ, f"{year}-{date[3:]}-{date[0:2]}", "taux_occupation", clean_val(v), report_date])
                count += 1
            print(f"Province page: {count} region/total rows parsed -> {region_file}")

        # --- Pages 2+: by installation ---
        total_rows = 0
        with open(installation_file, "w", newline="", encoding="utf-8") as f:
            writer = csv.writer(f)
            writer.writerow(["region_code", "region_name", "installation", "civ", "date", "metric", "value", "is_region_total", "extraction_date"])

            for page in pdf.pages[1:]:
                tables = page.extract_tables()
                if not tables:
                    continue
                table = tables[0]

                header_text = table[0][0] or ""
                header_match = re.search(r"\((\d{2})\)\s*([^\n]+)", header_text)
                if not header_match:
                    continue
                region_code, region_name = header_match.group(1), header_match.group(2).strip()

                dates = get_dates(table[3])
                if len(dates) < 7:
                    continue

                for row in table[4:]:
                    name = (row[0] or "").replace("\n", " ").strip()
                    is_total = name.lower().startswith("total")

                    class RowWriter:
                        def writerow(self, cols):
                            n, civ, date, metric, val = cols
                            writer.writerow([region_code, region_name, n, civ, date, metric, val, is_total, report_date])
                            nonlocal total_rows
                            total_rows += 1

                    parse_data_row(row, dates, RowWriter(), year, [])

        print(f"Installation rows written: {total_rows} -> {installation_file}")

    print("Done.")


if __name__ == "__main__":
    main()

