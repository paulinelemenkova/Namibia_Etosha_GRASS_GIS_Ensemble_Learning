#!/bin/sh

grass

# ----IMPORT AND PREPROCESSING-------------------------->

g.list rast
# importing the image subset with 7 Landsat bands and display the raster map
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220505_20230417_02_T1_SR_B1.TIF output=L8_2022_M_01 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220505_20230417_02_T1_SR_B2.TIF output=L8_2022_M_02 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220505_20230417_02_T1_SR_B3.TIF output=L8_2022_M_03 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220505_20230417_02_T1_SR_B4.TIF output=L8_2022_M_04 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220505_20230417_02_T1_SR_B5.TIF output=L8_2022_M_05 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220505_20230417_02_T1_SR_B6.TIF output=L8_2022_M_06 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220505_20230417_02_T1_SR_B7.TIF output=L8_2022_M_07 extent=region resolution=region
#
g.list rast
#
# ----CREATING COLOR COMPOSITES-------------------------->
# false color
r.composite blue=L8_2022_M_03 green=L8_2022_M_05 red=L8_2022_M_07 output=L8_2022_M_357 --overwrite
g.region raster=L8_2022_M_07 -o
d.mon wx0
d.rast L8_2022_M_357
d.out.file output=Namibia_M_357 format=jpg --overwrite
# false color: NIR band B05 in the red channel, red band B04 in the green channel and green band B03 in the blue channel
r.composite blue=L8_2022_M_03 green=L8_2022_M_04 red=L8_2022_M_05 output=L8_2022_M_345 --overwrite
g.region raster=L8_2022_M_03 -o
d.mon wx0
d.rast L8_2022_M_345
d.out.file output=Namibia_A_345 format=jpg --overwrite
# true color
r.composite blue=L8_2022_M_02 green=L8_2022_M_03 red=L8_2022_M_04 output=L8_2022_M_234 --overwrite
d.mon wx0
d.rast L8_2022_M_234
d.out.file output=Namibia_A_234 format=jpg --overwrite

# ---CLUSTERING AND CLASSIFICATION------------------->
# grouping data by i.group
# Set computational region to match the scene
g.region raster=L8_2022_01 -p
i.group group=L8_2022_M subgroup=res_30m \
  input=L8_2022_M_01,L8_2022_M_02,L8_2022_M_03,L8_2022_M_04,L8_2022_M_05,L8_2022_M_06,L8_2022_M_07 --overwrite
  
# Clustering: generating signature file and report using k-means clustering algorithm
i.cluster group=L8_2022_M subgroup=res_30m \
  signaturefile=cluster_L8_2022_M \
  classes=10 reportfile=rep_clust_L8_2022_M.txt --overwrite

# Classification by i.maxlik module
i.maxlik group=L8_2022_M subgroup=res_30m \
  signaturefile=cluster_L8_2022_M \
  output=L8_2022_M_cluster_classes reject=L8_2022_M_cluster_reject --overwrite

# Mapping
d.mon wx0
g.region raster=L8_2022_M_cluster_classes -p
r.colors L8_2022_M_cluster_classes color=bcyr
d.rast L8_2022_M_cluster_classes
d.legend raster=L8_2022_M_cluster_classes title="26 May 2022" title_fontsize=14 font="Helvetica" fontsize=12 bgcolor=white border_color=white
d.out.file output=Namibia_2022_M format=jpg --overwrite

# Mapping rejection probability
d.mon wx1
g.region raster=L8_2022_M_cluster_classes -p
r.colors L8_2022_M_cluster_reject color=bgyr -e
d.rast L8_2022_M_cluster_reject
d.legend raster=L8_2022_M_cluster_reject title="26 May 2022" title_fontsize=14 font="Helvetica" fontsize=12 bgcolor=white border_color=white
d.out.file output=Namibia_2022_M_reject format=jpg --overwrite

# --------------------------------------------->
# MACHINE LEARNING

# g.list rast
g.region raster=L8_2022_M_01 -p
# Ggoing to generate some training pixels from an older land cover classification:
r.random input=L8_2022_cluster_classes seed=100 npoints=1000 raster=L8_2022_M_classes_roi --overwrite
# Cretaing the imagery group with all Landsat-8 OLI/TIRS bands:
i.group group=L8_2022_M input=L8_2022_M_01,L8_2022_M_02,L8_2022_M_03,L8_2022_M_04,L8_2022_M_05,L8_2022_M_06,L8_2022_M_07 --overwrite
# Using training pixels to perform a classification on recent Landsat image:
# train a random forest classification model using r.learn.train
r.learn.train group=L8_2022_M training_map=L8_2022_M_classes_roi \
    model_name=RandomForestClassifier n_estimators=500 save_model=rf_model.gz --overwrite
# perform prediction using r.learn.predict
r.learn.predict group=L8_2022_M load_model=rf_model.gz output=rf_classification --overwrite
# check raster categories - they are automatically applied to the classification output
r.category rf_classification
# copy color scheme from landclass training map to result
r.colors rf_classification raster=L8_2022_M_classes_roi
# display
d.mon wx0
d.rast rf_classification
r.colors rf_classification color=roygbiv -e
d.legend raster=rf_classification title="Random Forest: 05/2022" title_fontsize=14 font="Helvetica" fontsize=12 bgcolor=white border_color=white
d.out.file output=RF_2022_05 format=jpg --overwrite
