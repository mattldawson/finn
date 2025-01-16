import argparse
import subprocess
from datetime import datetime, timedelta
import os


def download_file(url, output_file):
    """Download a file from a given URL and save it to the output_file path"""
    token = os.getenv("EARTHDATATOKEN")
    if not token:
      print("Earthdata token not set. Please set the EARTHDATATOKEN environment variable.")
      exit(1)
    cmd = [
        "curl",
        "-sS",
        "-L",
        "-o",
        output_file,
        "-H",
        f"Authorization: Bearer {token}",
        url,
    ]
    try:
        subprocess.run(cmd, check=True)
        print(f"Downloaded: {output_file}")
    except subprocess.CalledProcessError as e:
        print(f"Failed to download {output_file}: {e}")


def modis_file_name(date):
    """Get the name of the MODIS file for a given date"""
    return f"MODIS_C6_1_Global_MCD14DL_NRT_{date.strftime('%Y%j')}.txt"


def suomi_file_name(date):
    """Get the name of the Suomi file for a given date"""
    return f"SUOMI_VIIRS_C2_Global_VNP14IMGTDL_NRT_{date.strftime('%Y%j')}.txt"


def download_fire_data(date, raster_year, input_folder, output_folder, root_folder):
    """Download fire data for a given date and the day before and process them"""
    modis_base_url = "https://nrt3.modaps.eosdis.nasa.gov/api/v2/content/archives/FIRMS/modis-c6.1/Global/"
    suomi_base_url = "https://nrt3.modaps.eosdis.nasa.gov/api/v2/content/archives/FIRMS/suomi-npp-viirs-c2/Global/"
    date_format = "%Y-%m-%d"

    try:
        date_obj = datetime.strptime(date, date_format)
    except ValueError:
        print("Invalid date format. Please use YYYY-MM-DD.")
        return

    dates_to_download = [date_obj, date_obj - timedelta(days=1)]

    for d in dates_to_download:
        modis_file_url = f"{modis_base_url}{modis_file_name(d)}"
        download_file(
            modis_file_url, os.path.join(input_folder, modis_file_name(d))
        )

        suomi_file_url = f"{suomi_base_url}{suomi_file_name(d)}"
        download_file(
            suomi_file_url, os.path.join(input_folder, suomi_file_name(d))
        )

    work_nrt_script = os.path.join(root_folder, "preprocessor", "code_bashinterface", "work_nrt.py")
    working_dir = os.path.join(root_folder, "preprocessor", "code_bashinterface")
    tag = f"modvrs_nrt_{date_obj.strftime('%Y%j')}"
    summary_file = os.path.join(output_folder, f"processing_summary_{tag}.txt")
    cmd = [
        "python3",
        work_nrt_script,
        "-t",
        tag,
        "-y",
        raster_year,
        "-o",
        output_folder,
        "-fd",
        date_obj.strftime("%Y%j"),
        "-ld",
        date_obj.strftime("%Y%j"),
        "-s",
        summary_file,
    ]
    cmd.extend([os.path.join(input_folder, modis_file_name(dates_to_download[0]))])
    cmd.extend([os.path.join(input_folder, modis_file_name(dates_to_download[1]))])
    cmd.extend([os.path.join(input_folder, suomi_file_name(dates_to_download[0]))])
    cmd.extend([os.path.join(input_folder, suomi_file_name(dates_to_download[1]))])

    print(f"Running: {' '.join(cmd)}")
    try:
        subprocess.run(cmd, check=True, cwd=working_dir)
        print(f"Successfully ran {work_nrt_script} with date {date}")
    except subprocess.CalledProcessError as e:
        print(f"Failed to run {work_nrt_script}: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Download fire data for a given date and the day before."
    )
    parser.add_argument("date", type=str, help="Date in YYYY-MM-DD format")
    parser.add_argument(
        "-y",
        "--raster_year",
        type=int,
        help="Year of the raster data",
        default=os.getenv("FINN_RASTER_YEAR")
    )
    parser.add_argument(
        "-o",
        "--output_folder",
        type=str,
        help="Folder to save the processed files",
        default=os.getenv("FINN_OUTPUT_FOLDER"),
    )
    parser.add_argument(
        "-i",
        "--input_folder",
        type=str,
        help="Folder to save the downloaded files",
        default=os.getenv("FINN_INPUT_FOLDER"),
    )
    parser.add_argument(
        "-r",
        "--root_folder",
        type=str,
        help="Folder where FINN repo is cloned",
        default=os.getenv("FINN_ROOT"),
    )
    args = parser.parse_args()

    # Ensure the raster year is a valid year
    current_year = datetime.now().year
    if not 0 <= args.raster_year <= current_year:
        print(f"Invalid raster year. Please provide a year between 0 and {current_year}.")
        exit(1)

    # Ensure the input and output folders and finn folder exist
    if not os.path.exists(args.input_folder):
        print(f"Input folder does not exist: {args.input_folder}")
        exit(1)

    if not os.path.exists(args.output_folder):
        print(f"Output folder does not exist: {args.output_folder}")
        exit(1)

    if not os.path.exists(args.root_folder):
        print(f"FINN folder does not exist: {args.root_folder}")
        exit(1)

    download_fire_data(args.date, str(args.raster_year), args.input_folder, args.output_folder, args.root_folder)

