setwd("Documents/corpus_annotation_tp/R_files/")
load(".RData")
source("term_paper_functions.R")
library(ggplot2)
library(gridExtra)
library("stringr")
library(tidyr)
plot_percentages(c2_long)
load("c1_long.RData")
load("c2_long.RData")


##### NEW DATA #####
n_texts_level <- count_texts_per_level("../data/output_to_30k/output/")
feats_level <- get_feats_in_levels_df(all_features, "../data/output_to_30k/output/", FALSE, FALSE)
feat_lvl_percent_long <- get_feats_in_levels_df(all_features, "../data/output_to_30k/output/")
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
create_table_image(n_texts_level)

a1_25_to_50 <- feats_between_percents(a1_long, 0.25, 0.5)
a1_25_to_50_df <- a1_long[a1_long$feature %in% a1_25_to_50,]
