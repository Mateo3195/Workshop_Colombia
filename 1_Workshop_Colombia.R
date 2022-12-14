#==================================================================================
# R code for torrential flow susceptibility modeling 
# Last modified:  November 2022
#
# This code is developed for educational purpose, to be used in the course
# "Developments in landslide inventory, susceptibility, hazard and risk"
# at the Center for Disaster Resilience at ITC.
# The code/data is developed by Mateo Moreno.
# The SIMMA inventory was compiled from Sistema de Información de Movimientos en Masa
# available at https://simma.sgc.gov.co/#/
# The Desinventar inventory was compiled from DesInventar Sendai
# available at https://www.desinventar.net/
#
# Do not remove this announcement
# The code is distributed "as is", WITH NO WARRANTY whatsoever!
# Code/data also available at https://github.com/Mateo3195/Workshop_Colombia
#==================================================================================




# INITIAL SETTINGS --------------------------------------------------------

# the following commands will install and load the necessary packages to run the whole script

# installing packages
# this step might take a bit of time and after the installation finishes Rstudio might get restarted
list.packages = c("sf", "tidyverse", "pROC", "mapview", "mgcv", "sperrorest", "paletteer")
new.packages = list.packages[!(list.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)

# loading packages
# this command will load the previously install packages
lapply(list.packages, require, character.only=T)
remove(list.packages, new.packages)

# setting up directory
# the path correspond to the location in your machine where the data and code are stored
# keep in mind that the location might need to be entered with the forward slash "/" and not backward slash "\"
path = getwd() # only to be executed if you created a project in Rstudio and placed your data in the project's folder
setwd(path)

setwd("/home/mmorenozapata@eurac.edu/OneDrive/COLOMBIA/Workshop_Colombia/")
setwd(path)
remove(path)




# LOADING DATA ------------------------------------------------------------

# these commands will load the provided data corresponding to the inventories, catchments and study area

# load inventories and Antioquia boundary
SIMMA = sf::st_read("./data/simma_inventory.gpkg")
DESINVENTAR = sf::st_read("./data/desinventar.gpkg")
antioquia = sf::st_read("./data/antioquia.gpkg")

# load mapping units
basin_5000 = sf::st_read("./data/basin_5000.gpkg")

# visualize data
# mapview will allow to visualize the available data in an interactive interface.
# the basemap can be switched to topographic maps and satellite imagery and
# the different features can be clicked to explore the attributes
# let us have a look at some of the torrential flow events

mapview(SIMMA, col.regions = "blue") +
  mapview(DESINVENTAR, col.regions = "red") +
  mapview(basin_5000, color = "black", alpha.regions=0) +
  mapview(antioquia, color = "magenta", alpha.regions=0, lwd=2)
  



# EXPLORATORY DATA ANALYSIS -----------------------------------------------

# in the following block we will explore the datasets via simple descriptive statistics

#### SIMMA inventory ####
# let us explore first the SIMMA inventory
# this command converts some of our attributes to factor and numeric formats
SIMMA = SIMMA %>%
  dplyr::mutate(across(type:municipality, factor)) %>%
  dplyr::mutate(across(year:doy, as.numeric))

# histograms and barplots
# let us check a summary of all the available attributes and check some
# some figures for the subtype of torrential flow in the SIMMA inventory
summary(SIMMA)
summary(SIMMA$subtype)
barplot(table(SIMMA$subtype), main = "Bar chart of subtype", col = "dodgerblue1")
pie(table(SIMMA$subtype), main = "Pie chart of subtype")

# remember that every time you want to check the help options for a specific function
# you can do ?"nameofthefunction" in the command line  e.g., ?barplot
# now let us explore a bit the dates in the SIMMA inventory
# dates
table(SIMMA$month)
barplot(table(SIMMA$month), main = "Bar chart of month", col = "dodgerblue1")
table(SIMMA$year)
barplot(table(SIMMA$year), main = "Bar chart of year", col = "dodgerblue1")

#### DESINVENTAR inventory ####
# let us now explore the DESINVNETAR inventory
# this command converts some of our attributes to factor and numeric formats
DESINVENTAR = DESINVENTAR %>%
  dplyr::mutate(across(cause:municipality, factor)) %>%
  dplyr::mutate(across(year:doy, as.numeric)) %>%
  dplyr::mutate(across(people_dead:people_missing, as.numeric))

# histograms and barplots
# let us check the same attributes for the DESINVENTAR inventory
summary(DESINVENTAR)
table(DESINVENTAR$month)
barplot(table(DESINVENTAR$month), main = "Bar chart of month", col = "firebrick1")
table(DESINVENTAR$year)
barplot(table(DESINVENTAR$year), main = "Bar chart of year", col = "firebrick1")
table(DESINVENTAR$cause)
barplot(table(DESINVENTAR$cause), main = "Bar chart of year", col = "firebrick1")

# we can also filtered the graphs according to other attributes e.g., a specific municipality
# for specific municipalities
barplot(table(DESINVENTAR$year[DESINVENTAR$municipality =="Medellín"]), col = "firebrick1")


#### MAPPING UNITS ####
# now let us see some of the available attributes in our mapping units
# continuous properties were aggregated using the mean (u) and standard deviation (g) (e.g., slope, twi)
# discrete properties were aggregated using the proportion of each class inside the mapping unit (e.g., lithology)

# let us visualize the explanatory variables
# first the inventories
# stable catchments or catchments without torrential flows are represented with "0"
# unstable catchments or catchments with torrential flows are represented with "1"
mapview(basin_5000, zcol="bin", col.regions=c("dodgerblue1", "firebrick1")) +
  mapview(basin_5000, zcol="DESINVENTAR", col.regions=c("dodgerblue1", "firebrick1")) +
  mapview(basin_5000, zcol="SIMMA", col.regions=c("dodgerblue1", "firebrick1"))

# then the explanatory variables
mapview(basin_5000, zcol="slope_u", col.regions=paletteer::paletteer_d("RColorBrewer::RdYlGn", direction = -1)) +
mapview(basin_5000, zcol="melton_index", col.regions=paletteer::paletteer_d("RColorBrewer::RdYlBu", direction = -1), at=seq(0, 0.5, 0.05)) +
mapview(basin_5000, zcol="permanent_crop", col.regions=paletteer::paletteer_d("RColorBrewer::OrRd", direction = 1), at=seq(0, 30, 1)) +
mapview(basin_5000, zcol="granite", col.regions=paletteer::paletteer_d("RColorBrewer::PuRd", direction = 1))

# histograms and boxplots
hist(basin_5000$slope_u, breaks = 100, xlab="", ylab="Frequency", main = "Average slope (°)")
boxplot(basin_5000$slope_u ~ basin_5000$bin, col = c("dodgerblue1", "firebrick1"), main = "Average slope (°)", xlab="", ylab="")
boxplot(basin_5000$melton_index ~ basin_5000$bin, col = c("dodgerblue1", "firebrick1"), main = "Melton index", xlab="", ylab="")
boxplot(basin_5000$relief ~ basin_5000$bin, col = c("dodgerblue1", "firebrick1"), main = "Relief (m)", xlab="", ylab="")
boxplot(basin_5000$elongation_ratio ~ basin_5000$bin, col = c("dodgerblue1", "firebrick1"), main = "Elongation ratio", xlab="", ylab="")
boxplot(basin_5000$granite ~ basin_5000$bin, col = c("dodgerblue1", "firebrick1"), main = "Proportion of Granite", xlab="", ylab="")
boxplot(basin_5000$heterogeneous_agricultural ~ basin_5000$bin, col = c("dodgerblue1", "firebrick1"), main = "Proportion of heterogeneous agricultural areas (%)", xlab="", ylab="")

# we can also check patterns using the Probability Density function for both stable and unstable catchments
plot(density(basin_5000$slope_u[basin_5000$bin==0]), col = "blue", "Average slope (°)", lwd = 2)
lines(density(basin_5000$slope_u[basin_5000$bin==1]), col = "red", lwd = 2)

# let us recall all these are statistical descriptors, not a model as such, and therefore we cannot use them
# to make our predictions. Instead, they might give you ideas of the explanatory variables that you might want to use
# in your model.




# MODELING ----------------------------------------------------------------
# In the following block, we will jump into the statistical modeling using 
# Generalized Additive Modes (GAMs) in the package mgcv https://cran.r-project.org/web/packages/mgcv/index.html
# Frequentist framework

# before we start let us have a look at the total of events in each inventory
nrow(SIMMA)
nrow(DESINVENTAR)
nrow(SIMMA) + nrow(DESINVENTAR)

# once we aggregate the inventories in the catchments our number might differ since we can have
# multiple torrential flows in the very same catchment e.g.,
table(basin_5000$SIMMA)
table(basin_5000$DESINVENTAR)
table(basin_5000$bin)

#### model fit #####
# formula
# here we will declare the formula that we will pass to mgcv
# literature, knowledge of the study area and the exploratory data analysis may give us ideas of the 
# explanatory variables that we want to input in our model
# bs controls the smooth types to be use in the model and "tp" is used by default.
# k-1 or (k) sets the upper limit on the degrees of freedom associated with a smooth. 
# for more details go to https://cran.r-project.org/web/packages/mgcv/mgcv.pdf or
# (Wood, 2017) https://www.taylorfrancis.com/books/mono/10.1201/9781315370279/generalized-additive-models-simon-wood

# Gavin Simpson has great videos explaining everything related to mgcv
# https://www.youtube.com/watch?v=sgw4cu8hrZM
formula_5000 = bin ~
  s(slope_u, bs="tp", k = 5) + #s() is used to declare the non-linear properties
  s(relief, k = 5)+
  elongation_ratio + # without s() they will be treated as linear
  granite +
  pasture

# keep in mind this is only a toy dataset for the demonstration during this workshop

# fit
mod_5000 = mgcv::gam(formula_5000, family = binomial, method="REML", data = basin_5000) 
summary(mod_5000) 
# summary will give you an overview of the fit
# as we want to keep our model as parsimonious as possible we can refit the model only with the
# significant terms

# partial effects
plot(mod_5000, select=1, trans=plogis, shade=T, ylab="") # you can change the select to explore the other nonlinear effects
plot(mod_5000, trans=plogis, pages=1, all.terms=T, shade=T, ylab="")

# fitting performance
# to create a new column in your dataset where the probability is stored
basin_5000$probability = as.numeric(predict(mod_5000, type="response", newdata=basin_5000)) 
myroc_5000 = roc(response=basin_5000$bin, predictor=basin_5000$probability, auc=T)           
plot(myroc_5000, main = round(myroc_5000$auc, 5))


#### validation #####
# 10-fold cross-validation
# we divide the dataset into 10 equal parts. We will use 9 of those parts to fit our model and validate over the remaining one
# in a interactive way

# partitions
# the library only works with centroids, but this step is merely for visualization
# what we only need is to defined the partitions
centroids = dplyr::select(basin_5000, x, y) %>% sf::st_drop_geometry()
partition = partition_cv(basin_5000, nfold = 10, repetition = 1, seed1 = 123) 
plot(partition, centroids, coords = c("x", "y"), cex = 0.01, pch = 19)

# settings for the loop
# this loop will fit the model over 9 of the defined folds and will predict over the remaining fold
fold = (1:10)
basin_5000$prediction = NA
basin_5000_myroc = c(NA)
df = basin_5000
roc = list()

# loop
for (i in fold){
  id.holdout = partition[[1]][[i]]$test
  df_train = basin_5000[-id.holdout,]
  df_test = basin_5000[id.holdout, ]
  fit = mgcv::gam(formula_5000, data=df_train, family=binomial, method="REML")
  basin_5000$prediction[id.holdout] = as.numeric(predict(fit, type="response", newdata=df_test))
  roc[[i]] = roc(response=df_test$bin, predictor=basin_5000$prediction[id.holdout], auc=T)
  basin_5000_myroc[i] = as.numeric(unlist(roc[[i]][9]))
}

# let us check the predictive performance over the 10 testing folds
boxplot(basin_5000_myroc)
round(basin_5000_myroc,5)
mean(basin_5000_myroc)
median(basin_5000_myroc)

# we can plot the 10 roc curves, one generated for every testing fold
plot(roc[[1]]); plot(roc[[2]], add=T); plot(roc[[3]], add=T); plot(roc[[4]], add=T); plot(roc[[5]], add=T)
plot(roc[[6]], add=T); plot(roc[[7]], add=T); plot(roc[[8]], add=T); plot(roc[[9]], add=T); plot(roc[[10]], add=T)




# VISUALIZATION -----------------------------------------------------------
# to visualize the results of the fit and the predictions
# you can adjust the strect and type of palette according to your interests
mapview(basin_5000, zcol="probability", col.regions=paletteer::paletteer_d("RColorBrewer::RdYlGn", direction=-1))+
  mapview(basin_5000, zcol="prediction", col.regions=paletteer::paletteer_d("RColorBrewer::RdYlGn", direction=-1))+
  mapview(basin_5000, zcol="bin", col.regions=c("dodgerblue1", "firebrick1"))

# "All models are wrong, but some are useful" George E.P.Box
# even if a model cannot describe exactly the reality it could be very helpful if it is close enough
# Remember that the quality of a model output not only depends on the data quality and the method, but also on the
# expertise and criteria of the modeler
# Don't rely only on performances, check the plausibility of the model
