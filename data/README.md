# Data Directory

This directory is mounted into the Docker container at `/data`.

## How to Use

Place your project files here in subfolders:

```
data/
  ProjectName/
    config.xlsx          <- Your Turas config file
    survey_data.csv      <- Your survey data
    output/              <- Turas will write results here
```

When browsing for files in Turas, navigate to the **Data** root folder.

## Notes

- This directory is shared between your computer and the Docker container
- Output files will appear here after analysis completes
- Do not delete this directory while the container is running
