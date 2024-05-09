#!/bin/sh
grass
cd /Users/polinalemenkova/grassdata
grass -c LC09_L2SP_179073_20220419_20230421_02_T1_SR_B1.tif /Users/polinalemenkova/grassdata/Namibia
# ----IMPORT AND PREPROCESSING-------------------------->
# g.mapset location=Namibia mapset=PERMANENT
g.list rast
# importing the image subset with 7 Landsat bands and display the raster map
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC08_L2SP_179073_20220326_20220330_02_T1_SR_B1.TIF output=L8_2022_01 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC08_L2SP_179073_20220326_20220330_02_T1_SR_B2.TIF output=L8_2022_02 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC08_L2SP_179073_20220326_20220330_02_T1_SR_B3.TIF output=L8_2022_03 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC08_L2SP_179073_20220326_20220330_02_T1_SR_B4.TIF output=L8_2022_04 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC08_L2SP_179073_20220326_20220330_02_T1_SR_B5.TIF output=L8_2022_05 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC08_L2SP_179073_20220326_20220330_02_T1_SR_B6.TIF output=L8_2022_06 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC08_L2SP_179073_20220326_20220330_02_T1_SR_B7.TIF output=L8_2022_07 extent=region resolution=region
g.list rast
# ----CREATING COLOR COMPOSITES-------------------------->
# false color
r.composite blue=L8_2022_07 green=L8_2022_05 red=L8_2022_03 output=L8_2022_753 --overwrite
d.mon wx0
d.rast L8_2022_753
d.out.file output=Namibia_753 format=jpg --overwrite
# false color: NIR band B05 in the red channel, red band B04 in the green channel and green band B03 in the blue channel
r.composite blue=L8_2022_03 green=L8_2022_04 red=L8_2022_05 output=L8_2022_345 --overwrite
d.mon wx0
d.rast L8_2022_345
d.out.file output=Namibia_345 format=jpg --overwrite
# true color
r.composite blue=L8_2022_02 green=L8_2022_03 red=L8_2022_04 output=L8_2022_234 --overwrite
d.mon wx0
d.rast L8_2022_234
d.out.file output=Namibia_234 format=jpg --overwrite
# ---CLUSTERING AND CLASSIFICATION------------------->
# Set computational region to match the scene
g.region raster=L8_2022_01 -p
# grouping data by i.group
i.group group=L8_2022 subgroup=res_30m \
  input=L8_2022_01,L8_2022_02,L8_2022_03,L8_2022_04,L8_2022_05,L8_2022_06,L8_2022_07
# Clustering: generating signature file and report using k-means clustering algorithm
i.cluster group=L8_2022 subgroup=res_30m \
  signaturefile=cluster_L8_2022 \
  classes=10 reportfile=rep_clust_L8_2022.txt --overwrite
# Classification by i.maxlik module
i.maxlik group=L8_2022 subgroup=res_30m \
  signaturefile=cluster_L8_2022 \
  output=L8_2022_cluster_classes reject=L8_2022_cluster_reject --overwrite
# Mapping
d.mon wx0
g.region raster=L8_2022_cluster_classes -p
r.colors L8_2022_cluster_classes color=bcyr
d.rast L8_2022_cluster_classes
d.legend raster=L8_2022_cluster_classes title="26 March 2022" title_fontsize=14 font="Helvetica" fontsize=12 bgcolor=white border_color=white
d.out.file output=Namibia_2022_Mar format=jpg --overwrite
# Mapping rejection probability
d.mon wx1
g.region raster=L8_2022_cluster_classes -p
r.colors L8_2022_cluster_reject color=bgyr -e
d.rast L8_2022_cluster_reject
d.legend raster=L8_2022_cluster_reject title="26 March 2022" title_fontsize=14 font="Helvetica" fontsize=12 bgcolor=white border_color=white
d.out.file output=Namibia_2022_reject format=jpg --overwrite
# --------------------------------------------->
# MACHINE LEARNING
# g.list rast
g.region raster=L8_2022_01 -p
# Generating training pixels from an older land cover classification:
r.random input=L8_2022_cluster_classes seed=100 npoints=1000 raster=L8_2022_classes_roi --overwrite
# Next, we create the imagery group with all Landsat-8 OLI/TIRS 7 (2000) bands:
i.group group=L8_2022 input=L8_2022_01,L8_2022_02,L8_2022_03,L8_2022_04,L8_2022_05,L8_2022_06,L8_2022_07 --overwrite
# Using training pixels to perform a classification on recent Landsat image:
# train a random forest classification model using r.learn.train
r.learn.train group=L8_2022 training_map=L8_2022_classes_roi \
    model_name=RandomForestClassifier n_estimators=500 save_model=rf_model.gz --overwrite
# perform prediction using r.learn.predict
r.learn.predict group=L8_2022 load_model=rf_model.gz output=rf_classification --overwrite
# check raster categories - they are automatically applied to the classification output
r.category rf_classification
# copy color scheme from landclass training map to result
r.colors rf_classification raster=L8_2022_classes_roi
# display
d.mon wx0
d.rast rf_classification
r.colors rf_classification color=roygbiv -e
d.legend raster=rf_classification title="Random Forest: 03/2022" title_fontsize=14 font="Helvetica" fontsize=12 bgcolor=white border_color=white
d.out.file output=RF_2022_03 format=jpg --overwrite
