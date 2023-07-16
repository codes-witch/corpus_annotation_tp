setwd("Documents/corpus_annotation_tp/R_files/")
load(".RData")
source("term_paper_functions.R")
library(ggplot2)
library(gridExtra)
library("stringr")
library(tidyr)
load("c1_long.RData")
load("c2_long.RData")


##### NEW DATA #####
n_texts_level <- count_texts_per_level("../data/output_to_30k/output/")
feats_level <- get_feats_in_levels_df(all_features, "../data/output_to_30k/output/", FALSE, FALSE)
feats_level_only <- feats_level[,2:ncol(feats_level)]

# Get the columns that have all zeros (those features were not found)
all_zeros <- feats_level_only[,colSums(feats_level_only) == 0]
zero_feats <- colnames(all_zeros)


feat_lvl_percent_long <- get_feats_in_levels_df(all_features, "../data/output_to_30k/output/")

# Remove all features that were not found
feat_lvl_percent_long <- subset(feat_lvl_percent_long, !(feat_lvl_percent_long$feature %in% zero_feats))
feats_level <- feats_level[, !colnames(feats_level) %in% zero_feats]

a1_long <- get_lvl_feats("A1", feat_lvl_percent_long)
plot_percentages_level(a1_long, "Presence of A1 features per CEFR level")
a2_long <- get_lvl_feats("A2", feat_lvl_percent_long)
plot_percentages_level(a2_long, "Presence of A2 features per CEFR level")
b1_long <- get_lvl_feats("b1", feat_lvl_percent_long)
plot_percentages_level(b1_long, "Presence of B1 features per CEFR level")
b2_long <- get_lvl_feats("b2", feat_lvl_percent_long)
plot_percentages_level(b2_long, "Presence of B2 features per CEFR level")
c1_long <- get_lvl_feats("c1", feat_lvl_percent_long)
View(c1_long[c1_long$total>0.6,])
c1_long <- c1_long[c1_long$total < 0.2,]
plot_percentages_level(c1_long, "Presence of C1 features per CEFR level")
c2_long <- get_lvl_feats("c2", feat_lvl_percent_long)
plot_percentages_level(c2_long, "Presence of C2 features per CEFR level")


# Save the lond dfs
save(a1_long, file="a1_long.RData")
save(a2_long, file="a2_long.RData")
save(b1_long, file="b1_long.RData")
save(b2_long, file="b2_long.RData")
save(c1_long, file="c1_long.RData")
save(c2_long, file="c2_long.RData")

a1_25_to_50 <- feats_between_percents(a1_long, 0.25, 0.5)
a1_25_to_50_df <- a1_long[a1_long$feature %in% a1_25_to_50,]

# ------------------------------------------------------------------------
# For clustering:

# All the data
# scale and transpose data removing the first column (all cols must be numeric)
scaled_feats_level <- scale(feats_level[,2:ncol(feats_level)])
scaled_feats_level <- t(scaled_feats_level)

# Calculate how many clusters we will need (find elbow/knee(?))
library(factoextra)
fviz_nbclust(scaled_feats_level, kmeans, method="wss")
# I will choose 4 as our elbow
kmeans_output <- kmeans(scaled_feats_level, centers = 4, nstart = 100)

# Visualize cluster:
fviz_cluster(list(data=scaled_feats_level, cluster = kmeans_output$cluster))

# Only with one level 
a1 <- feats_level[, names(feats_level) %in% as.character(1:109)]
scaled_a1 <- scale(a1)
scaled_a1 <- t(scaled_a1)
fviz_nbclust(scaled_a1, kmeans, method="wss")
# I'll choose 5
kmeans_out_a1 <- kmeans(scaled_a1, centers = 5, nstart = 100)
# Visualize cluster
fviz_cluster(list(data=scaled_a1, cluster= kmeans_out_a1$cluster))
