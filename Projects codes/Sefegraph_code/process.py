import csv
from shapely.geometry import Polygon, Point, MultiPolygon
import shapefile
import sys

# Load 
sf = shapefile.Reader("tl_2017_us_county/tl_2017_us_county.shp")
shapeRecs = sf.shapeRecords()
for x in range(len(shapeRecs)):
    if shapeRecs[x].shape.shapeType == 5:
        shapeRecs[x].poly = Polygon(shapeRecs[x].shape.points)
    else:
        print("Unexpected shape type:", shapeRecs[x].shape.shapeType)
        exit(0)

# Weirdly putting this include at the top causes bizarre errors...
from osgeo import ogr
ctyToCBG = {}  # county FIPS to list of (CBGFIPS, bb, feature)
driver = ogr.GetDriverByName("OpenFileGDB")
dataSource = driver.Open("v107/blkgrp.gdb")
layer = dataSource.GetLayer()
for x in layer:
    cty = x.GetFieldAsString("STCOFIPS")
    FIPS = x.GetFieldAsString("FIPS")
    bb = x.GetGeometryRef().GetEnvelope()
    if not cty in ctyToCBG:
        ctyToCBG[cty] = []
    ctyToCBG[cty].append((FIPS, bb, x))

### Code used to learn the field names:
# ldef = layer.GetLayerDefn()
# schema = []
# for idx  in range(ldef.GetFieldCount()):
#     schema.append(ldef.GetFieldDefn(idx).name)
# print(schema)

# http://code.activestate.com/recipes/577775-state-fips-codes-dict/
state_codes = {
    'WA': '53', 'DE': '10', 'DC': '11', 'WI': '55', 'WV': '54', 'HI': '15',
    'FL': '12', 'WY': '56', 'PR': '72', 'NJ': '34', 'NM': '35', 'TX': '48',
    'LA': '22', 'NC': '37', 'ND': '38', 'NE': '31', 'TN': '47', 'NY': '36',
    'PA': '42', 'AK': '02', 'NV': '32', 'NH': '33', 'VA': '51', 'CO': '08',
    'CA': '06', 'AL': '01', 'AR': '05', 'VT': '50', 'IL': '17', 'GA': '13',
    'IN': '18', 'IA': '19', 'MA': '25', 'AZ': '04', 'ID': '16', 'CT': '09',
    'ME': '23', 'MD': '24', 'OK': '40', 'OH': '39', 'UT': '49', 'MO': '29',
    'MN': '27', 'MI': '26', 'RI': '44', 'KS': '20', 'MT': '30', 'MS': '28',
    'SC': '45', 'KY': '21', 'OR': '41', 'SD': '46', "AS": "60", "MP": "69",
    "VI": "78", "GU": "66"
}
state_codes = {state_codes[x]: x for x in state_codes}

writer = csv.writer(sys.stdout)
writer.writerow(["safegraph_place_id", "state", "stateFIPS", "countyFIPS", "countyName", "CBGFIPS"])

for fname in sys.argv[1:]:
    with open(fname, "r") as fp:
        reader = csv.DictReader(fp)
        for line in reader:
            lat = float(line["latitude"])
            lon = float(line["longitude"])
            county = None
            for x in shapeRecs:
                bb = x.shape.bbox
                if lon >= bb[0] and lon <= bb[2] and lat >= bb[1] and lat <= bb[3] and x.poly.contains(Point(lon, lat)):
                    county = x
                    break
            if county is not None:
                pt = ogr.Geometry(ogr.wkbPoint)
                pt.AddPoint(lon, lat)
                cbgFIPS = None
                rec = county.record.as_dict()
                if rec["GEOID"] in ctyToCBG:
                    for cbg, bb, feat in ctyToCBG[rec["GEOID"]]:
                        if lon >= bb[0] and lon <= bb[1] and lat >= bb[2] and lat <= bb[3] and feat.GetGeometryRef().Contains(pt):
                            cbgFIPS = cbg
                            break
                writer.writerow([line["safegraph_place_id"], state_codes[rec["STATEFP"]], rec["STATEFP"], rec["GEOID"], rec["NAMELSAD"], cbgFIPS])
            else:
                writer.writerow([line["safegraph_place_id"], None, None, None, None, None])
