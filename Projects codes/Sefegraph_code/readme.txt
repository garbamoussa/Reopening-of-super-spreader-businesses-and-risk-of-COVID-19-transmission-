# This code was run on a mac, so the instructions are Mac-specific. Should
# work with minimal changes on a linux box.

############
# Step 1: get necessary data
############
wget https://www2.census.gov/geo/tiger/TIGER2017/COUNTY/tl_2017_us_county.zip
Go to https://www.arcgis.com/home/item.html?id=1c924a53319a491ab43d5cb1d55d8561 and "Download"
# You also need to get the uncompressed safegraph POI data (files named
# core_poi-part*.csv). Store in this directory as well.

############
# Step 2: prep data
############
unzip tl_2017_us_county.zip
mv USA_Block_Group_Boundaries.lpk USA_Block_Group_Boundaries.7z
# brew install p7zip
7z x USA_Block_Group_Boundaries.7z

############
# Step 3: install GDAL on system
############
# For mac
brew tap osgeo/osgeo4mac
brew install osgeo/osgeo4mac/osgeo-gdal
# Probably something more like the following for linux (untested)
sudo apt-get install libgdal-dev

############
# Step 3: install python packages
############
pip install pyshp
pip install shapely
pip install pygdal=="$(gdal-config --version).*"
# pip install GDAL

############
# Step 4: run the script, passing the POI files as arguments
############
python process.py core_poi-part* > placeCountyCBG.csv

############
# Data format details: one row for each input POI row. Key fields are
# safegraph_place_id and CBG FIPS. CBG FIPS is a 12-digit code where
# digits 1-2 are state, digits 3-5 are county, digits 6-11 are
# census tract, and digit 12 is census block group. So you can match a state
# FIPS with the first 2 digits, a county FIPS with the first 5 digits, and a
# CBG FIPS with all 12 digits. Note that many have a leading 0, so this should
# be treated as a string instead of as a number!
#
# Since a few matched a county but not a CBG, I also include state FIPS, county
# FIPS, state 2-letter abbreviation, and county name.
############

############
# Match quality: The POI file I processed (from beginning of day March 25)
# had 5,393,160 POIs, so placeCountyCBG.csv has the same number of data rows.
# 6,431 (0.12%) did not match any county with my code; I did not attempt to
# match these to a CBG. 11,683 (0.22%; 6,431 with no county match plus 5,252
# additional) did not match any CBG with my code. It seems I did not match a
# CBG for any place in American Samoa (AS), Guam (GU), Northern Mariana Islands
# (MP), or US Virgin Islands (VI).
############
