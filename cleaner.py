import numpy as np
import pandas as pd
import time

# called from main
def clean_column_names(df):
    df.columns = [col.lower() for col in df.columns] # lowercase all column names
    # replace messy text-type fields with a simple "text" indicator
    df.columns = [col.replace("long text", "text for col in df.columns]
    df.columns = [col.replace("medium text", "text for col in df.columns]
    df.columns = [col.replace("(description)", "text for col in df.columns]
    df.columns = [col.replace("(description", "text for col in df.columns]
    df.columns = [col.replace("(descriptio", "text for col in df.columns]
    df.columns = [col.replace("(descripti", "text for col in df.columns]
    df.columns = [col.replace("equivalent", " for col in df.columns]
    df.columns = [" ".join(col.split()) for col in df.columns] # clean up spacing -- col.split() will split at single or multiple spaces, and joining them with a space again consolidates the spacing
    df.columns = [col.split("/[1] if col.count(col.split("/[0]) > 1 else col for col in df.columns] # if the word before / is counted in the text more than once, only use the text after the /
    df.columns = [col.replace(" ", "_ for col in df.columns] # replace spaces with underscores because they imply spacing
    df.columns = [col.replace("-", "_ for col in df.columns] # replace hyphens with underscores because they imply spacing
    df.columns = [col.replace("/", "_ for col in df.columns] # replace slashes with underscores because they imply spacing
    # remove special characters
    df.columns = [col.replace(", " for col in df.columns]
    df.columns = [col.replace("(", " for col in df.columns]
    df.columns = [col.replace("*", " for col in df.columns]
    df.columns = [col.replace("'", " for col in df.columns]
    # consolidate multiple underscores to a single underscore
    df.columns = [col.replace("___", "_ for col in df.columns]
    df.columns = [col.replace("__", "_ for col in df.columns]

    # sort column names alphabetically
    df = df.reindex(sorted(df.columns), axis=1)

    return df

def main(df, save_to_file_path=":
    # logging
    start = time.time()
    if len(df) < 1:
        print("YOUR DATAFRAME IS EMPTY BEFORE EVEN STARTING CLEANING!!!

    df = clean_column_names(df)
    df = df.drop_duplicates()

    # correct inconsistencies in OPM codes
    for opm_col in ["opm", "opm_series_number", "opmseries", "occupational_series_key", "detail_occupational_series"]:
        if opm_col in df.columns:
            df[opm_col] = [str(x).upper().replace("GS-", " for x in df[opm_col]] # remove all GS so it's on the same playing field
            df[opm_col] = [str(x).split("-[0] for x in df[opm_col]] # split at the - and only take the first part
            df[opm_col] = [str(x).replace("*", " for x in df[opm_col]] # remove the weird asterics
            df[opm_col] = [None if str(x)=='NONE' else "GS-00"+str(x) if len(str(x))==2 else "GS-0"+str(x) if len(str(x))==3 else "GS-"+str(x) if len(str(x))==4 else x for x in df[opm_col]] # add back in the GS's
    if "2010_eeo_tabulation_census_code" in df.columns:
        df["2010_eeo_tabulation_census_code"] = [str(x).replace("GS-", " for x in df["2010_eeo_tabulation_census_code"]] # remove all GS- prefixes


    # replace things that equate to None/Null with actual None values
    df = df.replace({'#': None}) #the other version df.replace('#', None) does not work. See: https://github.com/pandas-dev/pandas/issues/26050
    df = df.replace({'Not assigned': None})
    df = df.replace({'NOT APPLICABLE': None})
    df = df.replace('\$','',regex=True)
    df = df.replace({"00000000": None})
    df = df.drop([col for col in df.columns if "unnamed" in col], axis=1) 
    df = df.replace({np.nan: None}) # this occurs because # becomes None but then column is converted to datetime64 which also converts None into NaT which would not be correctly interpreted as NULL in SQL
    if "onet" not in save_to_file_path:
        print("replacing None with Null type
        df = df.replace('None', None) # replace anything that comes back as "None" string as a general None type (NULL in SQL)
    df = df.replace('nan', None) # replace anything that comes back as "nan" string as a general None type (NULL in SQL)
    df = df.replace({pd.NA: None}) # pd.NA is different than other nan/NA -- HAS TO BE LAST OF THESE REPLACEMENTS

    # logging
    if len(df) < 1:
        print("YOUR DATAFRAME IS EMPTY AFTER CLEANING!!!
    end = time.time()
    print(f"TRANSFORMED DATA IN {round(end-start)} SECONDS ({round((end-start)/60, 2)} MINUTES)
    # save data to csv and return data
    if save_to_file_path != "":
        df.to_csv(save_to_file_path, index=False, chunksize=5000)
    # NOTE: leading zeroes are here still
    return df