#!/bin/sh

grass

# ----IMPORT AND PREPROCESSING-------------------------->

g.list rast
# importing the image subset with 7 Landsat bands and display the raster map
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220606_20230414_02_T1_SR_B1.TIF output=L8_2022_J_01 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220606_20230414_02_T1_SR_B2.TIF output=L8_2022_J_02 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220606_20230414_02_T1_SR_B3.TIF output=L8_2022_J_03 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220606_20230414_02_T1_SR_B4.TIF output=L8_2022_J_04 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220606_20230414_02_T1_SR_B5.TIF output=L8_2022_J_05 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220606_20230414_02_T1_SR_B6.TIF output=L8_2022_J_06 extent=region resolution=region
r.import input=/Users/polinalemenkova/grassdata/Namibia/LC09_L2SP_179073_20220606_20230414_02_T1_SR_B7.TIF output=L8_2022_J_07 extent=region resolution=region
#
g.list rast
#
# ----CREATING COLOR COMPOSITES-------------------------->
# false color
r.composite blue=L8_2022_J_01 green=L8_2022_J_05 red=L8_2022_J_06 output=L8_2022_J_156 --overwrite
g.region raster=L8_2022_J_07 -o
d.mon wx0
d.rast L8_2022_J_156
d.out.file output=Namibia_J_156 format=jpg --overwrite
# false color: NIR band B05 in the red channel, red band B04 in the green channel and green band B03 in the blue channel
r.composite blue=L8_2022_J_03 green=L8_2022_J_04 red=L8_2022_J_05 output=L8_2022_J_345 --overwrite
g.region raster=L8_2022_J_03 -o
d.mon wx0
d.rast L8_2022_J_345
d.out.file output=Namibia_A_345 format=jpg --overwrite
# true color
r.composite blue=L8_2022_J_02 green=L8_2022_J_03 red=L8_2022_J_04 output=L8_2022_J_234 --overwrite
d.mon wx0
d.rast L8_2022_J_234
d.out.file output=Namibia_A_234 format=jpg --overwrite

# ---CLUSTERING AND CLASSIFICATION------------------->
# Set computational region to match the scene
g.region raster=L8_2022_01 -p
# grouping data by i.group
i.group group=L8_2022_J subgroup=res_30m \
  input=L8_2022_J_01,L8_2022_J_02,L8_2022_J_03,L8_2022_J_04,L8_2022_J_05,L8_2022_J_06,L8_2022_J_07 --overwrite

# Clustering: generating signature file and report using k-means clustering algorithm
i.cluster group=L8_2022_J subgroup=res_30m \
  signaturefile=cluster_L8_2022_J \
  classes=10 reportfile=rep_clust_L8_2022_J.txt --overwrite

# Classification by i.maxlik module
i.maxlik group=L8_2022_J subgroup=res_30m \
  signaturefile=cluster_L8_2022_J \
  output=L8_2022_J_cluster_classes reject=L8_2022_J_cluster_reject --overwrite

# Mapping
d.mon wx0
g.region raster=L8_2022_J_cluster_classes -p
r.colors L8_2022_J_cluster_classes color=bcyr
d.rast L8_2022_J_cluster_classes
d.legend raster=L8_2022_J_cluster_classes title="6 June 2022" title_fontsize=14 font="Helvetica" fontsize=12 bgcolor=white border_color=white
d.out.file output=Namibia_2022_J format=jpg --overwrite
#
# Mapping rejection probability
d.mon wx1
g.region raster=L8_2022_J_cluster_classes -p
r.colors L8_2022_J_cluster_reject color=bgyr -e
d.rast L8_2022_J_cluster_reject
d.legend raster=L8_2022_J_cluster_reject title="6 June 2022" title_fontsize=14 font="Helvetica" fontsize=12 bgcolor=white border_color=white
d.out.file output=Namibia_2022_J_reject format=jpg --overwrite

# --------------------------------------------->
# MACHINE LEARNING

# g.list rast
g.region raster=L8_2022_J_01 -p
# Generating training pixels from an older land cover classification:
r.random input=L8_2022_cluster_classes seed=100 npoints=1000 raster=L8_2022_J_classes_roi --overwrite
# Creating the imagery group with all Landsat-8 OLI/TIRS bands:
i.group group=L8_2022_J input=L8_2022_J_01,L8_2022_J_02,L8_2022_J_03,L8_2022_J_04,L8_2022_J_05,L8_2022_J_06,L8_2022_J_07 --overwrite
# Using training pixels to perform a classification on recent Landsat image:
# train a random forest classification model using r.learn.train
r.learn.train group=L8_2022_J training_map=L8_2022_J_classes_roi \
    model_name=RandomForestClassifier n_estimators=500 save_model=rf_model.gz --overwrite
# perform prediction using r.learn.predict
r.learn.predict group=L8_2022_J load_model=rf_model.gz output=rf_classification --overwrite
# check raster categories - they are automatically applied to the classification output
r.category rf_classification
# copy color scheme from landclass training map to result
r.colors rf_classification raster=L8_2022_J_classes_roi
# display
d.mon wx0
d.rast rf_classification
r.colors rf_classification color=roygbiv -e
d.legend raster=rf_classification title="Random Forest: 06/2022" title_fontsize=14 font="Helvetica" fontsize=12 bgcolor=white border_color=white
d.out.file output=RF_2022_06 format=jpg --overwrite

