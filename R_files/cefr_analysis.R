setwd("Documents/corpus_annotation_tp/R_files/")
load(".RData")
source("term_paper_functions.R")
library(ggplot2)
library(gridExtra)
library("dplyr")
library("stringr")
library(tidyr)
load("c1_long.RData")
load("c2_long.RData")


##### NEW DATA #####
n_texts_level <- count_texts_per_level("../data/output_to_30k/output/")
feats_level <- get_feats_in_levels(all_features, "../data/output_to_30k/output/", FALSE, FALSE)
feats_level_percent <- get_feats_in_levels(all_features, "../data/output_to_30k/output/", FALSE, TRUE)
feats_level_only <- feats_level[,2:ncol(feats_level)]
feats_level_percent_long <- get_feats_in_levels(all_features, "../data/output_to_30k/output/")

# Get the columns that have all zeros (those features were not found)
zero_feats <- colnames(feats_level_only[,colSums(feats_level_only) == 0])

# Remove all features that were not found
feats_level_percent_long <- subset(feats_level_percent_long, !(feats_level_percent_long$feature %in% zero_feats))
feats_level_percent <- feats_level_percent[, !colnames(feats_level_percent) %in% zero_feats]
feats_level <- feats_level[, !colnames(feats_level) %in% zero_feats]


a1_long <- get_level_feats("A1", feats_level_percent_long)
plot_percentages_level(a1_long, "Presence of A1 features per CEFR level")
a2_long <- get_level_feats("A2", feats_level_percent_long)
plot_percentages_level(a2_long, "Presence of A2 features per CEFR level")
b1_long <- get_level_feats("b1", feats_level_percent_long)
plot_percentages_level(b1_long, "Presence of B1 features per CEFR level")
b2_long <- get_level_feats("b2", feats_level_percent_long)
plot_percentages_level(b2_long, "Presence of B2 features per CEFR level")
c1_long <- get_level_feats("c1", feats_level_percent_long)
c1_long <- c1_long[c1_long$total < 0.2,]
plot_percentages_level(c1_long, "Presence of C1 features per CEFR level")
c2_long <- get_level_feats("c2", feats_level_percent_long)
plot_percentages_level(c2_long, "Presence of C2 features per CEFR level")

make_boxpolot_group(a1_long)


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
library(factoextra)

# All the data


# WITH SCALING:
# scale and transpose data removing the first column (all cols must be numeric)
scaled_feats_level_percent <- scale(feats_level_percent[,2:ncol(feats_level)])
scaled_feats_level_percent <- t(scaled_feats_level_percent)

# Calculate how many clusters we will need (find elbow/knee(?))
fviz_nbclust(scaled_feats_level_percent, kmeans, method="wss")
# I will choose 4 as our elbow
kmeans_output <- kmeans(scaled_feats_level, centers = 4, nstart = 100)
# Visualize cluster:
fviz_cluster(list(data=scaled_feats_level, cluster = kmeans_output$cluster))

# WITHOUT SCALING
transp_feats_level_percent <- t(feats_level_percent[2:ncol(feats_level_percent)])
fviz_nbclust(transp_feats_level_percent, kmeans, method = "wss")
#I'm choosing 3 clusters
kmeans_output <- kmeans(transp_feats_level_percent, centers = 3, nstart = 100)
# visualize cluster
fviz_cluster(list(data=transp_feats_level_percent, cluster = kmeans_output$cluster))

# Find mean of each cluster
cluster_means <- aggregate(transp_feats_level_percent, by=list(cluster=kmeans_output$cluster), mean)
colnames(cluster_means) <- c("cluster", "a1", "a2", "b1", "b2", "c1", "c2")
# Make cluster means long to plot them
cluster_means_long <- pivot_longer(cluster_means, cols = !cluster, values_to = "value", names_to = "level")
# Plot cluster means
cluster_means_long$cluster <- as.factor(cluster_means_long$cluster)
plot_cluster_means(cluster_means_long, "Clustering over all features")


# _______________________________________________________
# A1 clustering 
# _______________________________________________________
a1 <- feats_level_percent[, names(feats_level_percent) %in% as.character(1:109)]
a1 <- t(a1)

a1_scaled <- scale(a1)

# Unscaled
fviz_nbclust(a1, kmeans, method="wss") # I'll choose 3
kmeans_out_a1 <- kmeans(a1, centers = 3, nstart = 100)

# Scaled
fviz_nbclust(a1_scaled, kmeans, method= "wss") # It's the same plot!
kmeans_out_a1_scaled = kmeans(a1_scaled, centers = 3, nstart = 100)

# Visualize cluster
fviz_cluster(list(data=a1, cluster= kmeans_out_a1$cluster), main = "A1 features cluster means (unscaled)")
fviz_cluster(list(data=a1_scaled, cluster = kmeans_out_a1_scaled$cluster), main = "A1 features cluster means (scaled)")

# Get the means of the clusters
a1_cluster_means <- aggregate(a1, by=list(cluster=kmeans_out_a1$cluster), mean)
colnames(a1_cluster_means) <- c("cluster", "a1", "a2", "b1", "b2", "c1", "c2")

# Visualize them 
a1_cluster_means_long <- pivot_longer(a1_cluster_means, cols = !cluster, values_to = "value", names_to = "level")
a1_cluster_means_long$cluster <- as.factor(a1_cluster_means_long$cluster)
plot_cluster_means(a1_cluster_means_long, "Clustering of A1 features (no scaling)")



# The rest of levels

# A2
a2 <- t(feats_level_percent[, names(feats_level_percent) %in% as.character(110:397)])
colnames(a2) <- c("a1", "a2", "b1", "b2", "c1", "c2")
fviz_nbclust(a2, kmeans, method="wss") # Either 2 or 5 centers
kmeans_out_a2 <- kmeans(a2, centers = 5, nstart = 100)
fviz_cluster(list(data=a2, cluster= kmeans_out_a2$cluster), main = "A2 features cluster means (unscaled)") # Feat 275 is a clear outlier
a2_cluster_means <- aggregate(a2, by=list(cluster=kmeans_out_a2$cluster), mean)
a2_cluster_means_long <- pivot_longer(a2_cluster_means, cols = !cluster, values_to = "value", names_to = "level")
a2_cluster_means_long$cluster <- as.factor(a2_cluster_means_long$cluster)
plot_cluster_means(a2_cluster_means_long, "Clustering of A2 features")

# B1
b1 <- t(feats_level_percent[,names(feats_level_percent) %in% as.character(401:734)])
colnames(b1) <- c("a1", "a2", "b1", "b2", "c1", "c2")
fviz_nbclust(b1, kmeans, method="wss") # Choosing 3 
kmeans_out_b1 <- kmeans(b1, centers = 3, nstart = 100)
fviz_cluster(list(data=b1, cluster= kmeans_out_b1$cluster), main = "B1 features cluster means (unscaled)")
b1_cluster_means <- aggregate(b1, by=list(cluster=kmeans_out_b1$cluster), mean)
b1_cluster_means_long <- pivot_longer(b1_cluster_means, cols = !cluster, values_to = "value", names_to = "level")
b1_cluster_means_long$cluster <- as.factor(b1_cluster_means_long$cluster)
plot_cluster_means(b1_cluster_means_long, "Clustering of B1 features")

# B2
b2 <- t(feats_level_percent[,names(feats_level_percent) %in% as.character(739:977)])
colnames(b2) <- c("a1", "a2", "b1", "b2", "c1", "c2")
fviz_nbclust(b2, kmeans, method="wss") # Choosing 5
kmeans_out_b2 <- kmeans(b2, centers = 5, nstart = 100)
fviz_cluster(list(data=b2, cluster= kmeans_out_b2$cluster), main = "B2 features cluster means (unscaled)")
b2_cluster_means <- aggregate(b2, by=list(cluster=kmeans_out_b2$cluster), mean)
b2_cluster_means_long <- pivot_longer(b2_cluster_means, cols = !cluster, values_to = "value", names_to = "level")
b2_cluster_means_long$cluster <- as.factor(b2_cluster_means_long$cluster)
plot_cluster_means(b2_cluster_means_long, "Clustering of B2 features")


# C1
c1 <- t(feats_level_percent[,names(feats_level_percent) %in% as.character(982:1105)])
# remove misbehaving feature
c1 <- c1[!(row.names(c1) == "1057"),]
colnames(c1) <- c("a1", "a2", "b1", "b2", "c1", "c2")
fviz_nbclust(c1, kmeans, method="wss") # Choosing 4
kmeans_out_c1 <- kmeans(c1, centers = 4, nstart = 100)
fviz_cluster(list(data=c1, cluster= kmeans_out_c1$cluster), main = "C1 features cluster means (unscaled)")
c1_cluster_means <- aggregate(c1, by=list(cluster=kmeans_out_c1$cluster), mean)
c1_cluster_means_long <- pivot_longer(c1_cluster_means, cols = !cluster, values_to = "value", names_to = "level")
c1_cluster_means_long$cluster <- as.factor(c1_cluster_means_long$cluster)
plot_cluster_means(c1_cluster_means_long, "Clustering of C1 features")

c2 <- t(feats_level_percent[,names(feats_level_percent) %in% as.character(1111:1203)])
colnames(c2) <- c("a1", "a2", "b1", "b2", "c1", "c2")
fviz_nbclust(c2, kmeans, method="wss") # Choosing 4
kmeans_out_c2 <- kmeans(c2, centers = 4, nstart = 100)
fviz_cluster(list(data=c2, cluster= kmeans_out_c2$cluster), main = "C2 features cluster means (unscaled)")
c2_cluster_means <- aggregate(c2, by=list(cluster=kmeans_out_c2$cluster), mean)
c2_cluster_means_long <- pivot_longer(c2_cluster_means, cols = !cluster, values_to = "value", names_to = "level")
c2_cluster_means_long$cluster <- as.factor(c2_cluster_means_long$cluster)
plot_cluster_means(c2_cluster_means_long, "Clustering of C2 features")


# Add clusters to long DFs with features
a1_long <- add_clusters_to_long(kmeans_out_a1$cluster, a1_long)
a2_long <- add_clusters_to_long(kmeans_out_a2$cluster, a2_long)
b1_long <- add_clusters_to_long(kmeans_out_b1$cluster, b1_long)
b2_long <- add_clusters_to_long(kmeans_out_b2$cluster, b2_long)
c1_long <- add_clusters_to_long(kmeans_out_c1$cluster, c1_long)
c2_long <- add_clusters_to_long(kmeans_out_c2$cluster, c2_long)

# ------------------- Make boxplots ------------------

# get a df where features are matched to the levels they belong to
with_feat_lvl <- add_feature_level(feat_lvl_percent_long)
make_boxpolot_group(with_feat_lvl[with_feat_lvl$feat_level != "A1" & with_feat_lvl$feat_level != "A2" & with_feat_lvl$feat_level != "B1",], ylim_vector = c(0, 0.025))
