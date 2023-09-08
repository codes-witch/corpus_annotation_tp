# -----------------------------------------------------------------------
# ------------------------------ DATA PREP ------------------------------
# -----------------------------------------------------------------------

# Grab the text from the ef dataframe and put it in .txt files
ef_text_2_txt <- function(dataframe, directory) {
  # Create the directory to store the text files (if it doesn't exist)
  dir.create(directory, showWarnings = FALSE)
  
  # Iterate over each row in the df
  for (i in 1:nrow(dataframe)) {
    # Create a subdir for each level (if it doesn't exist)
    level_directory <- paste0(directory, "/", dataframe$cefr_level[i])
    dir.create(level_directory, showWarnings = FALSE)
    
    lang_code <- if_else(is.na(dataframe$lang_iso[i]) || dataframe$lang_iso[i] == "", "xx", dataframe$lang_iso[i])
    # Generate a unique filename for each row. Structure: ID_unit_L1.txt
    filename <- paste0(level_directory, "/", dataframe$id[i], "_", dataframe$unit[i], "_", lang_code,  ".txt")
    
    file_conn <- file(filename, open = "w")
    
    # Write the text content to the file
    writeLines(as.character(dataframe$text[i]), con = file_conn)

    close(file_conn)
  }
}

rename_column <- function(dataframe, old_idx, new_name){
  colnames(dataframe)[old_idx] <- new_name
  return(dataframe)
}

delete_column <- function(dataframe, colname) {
  dataframe <- dataframe[, !(colnames(dataframe) %in% colname)]
  return(dataframe)
}

# To add cefr levels when we have EF levels
add_cefr_from_ef_levels <- function(dataframe){
  dataframe$cefr_level <- NA
  # CEFR levels are factors
  dataframe$cefr_level <- factor(dataframe$cefr, levels = c("a1", "a2", "b1", "b2", "c1", "c2"))
  for (i in 1:nrow(dataframe)) {
    print(i)
    if (dataframe$ef_level[i] <= 3){
      dataframe$cefr_level[i] <- "a1"
    } else if (dataframe$ef_level[i] <= 6) {
      dataframe$cefr_level[i] <- "a2"
    } else if (dataframe$ef_level[i] <= 9) {
      dataframe$cefr_level[i] <- "b1"
    } else if (dataframe$ef_level[i] <= 12) {
      dataframe$cefr_level[i] <- "b2"
    } else if (dataframe$ef_level[i] <= 15) {
      dataframe$cefr_level[i] <- "c1"
    } else {
      dataframe$cefr_level[i] <- "c2"
    }
  }
  
  return (dataframe)
}

# To add levels to a dataframe based on the feature
add_feature_level <- function(dataframe){
  dataframe %>% mutate(feat_level = case_when(
         as.numeric(feature) < 110 ~ "A1",
         as.numeric(feature) < 401 ~ "A2",
         as.numeric(feature) < 739 ~ "B1",
         as.numeric(feature) < 982 ~ "B2",
         as.numeric(feature) < 1111 ~ "C1",
         TRUE ~ "C2" # Optional default value if none of the conditions match
    ))
}

# For renaming the filenames to always have access to unit and id
# Dataframe is the reference df where we get the units from
put_units_in_filenames <- function(directory_path, dataframe){
  
  # Get the list of files in the directory
  file_list <- list.files(directory_path, pattern = "\\.txt$", full.names = TRUE)
  
  # Iterate through each file
  for (file_path in file_list) {
    # Extract the filename without extension
    file_name <- tools::file_path_sans_ext(basename(file_path))
    print(file_name)
    
    # Don't add unit if it already has it
    if (grepl("_", file_name)){
      next
    }
    
    # Find the corresponding unit in ef2 dataset
    unit <- dataframe$unit[dataframe$id == file_name]
    print(unit)
    
    # Rename the file
    new_file_name <- paste0(unit, "_", file_name, ".txt")
    new_file_path <- file.path(directory_path, new_file_name)
    file.rename(file_path, new_file_path)
  }
  
  
}

add_newline_to_files <- function(directory_path) {
  # Get a list of all files in the directory and its subdirectories
  file_list <- list.files(directory_path, recursive = TRUE, full.names = TRUE)
  
  # Loop through each file
  for (file_path in file_list) {
    print(file_path)
    # Check if the file is a text file
    if (endsWith(file_path, ".txt")) {
      # Read the contents of the file
      file_contents <- readLines(file_path)
      
      # Add a new line at the end of the file contents
      file_contents <- c(file_contents)
      
      # Write the updated contents back to the file
      writeLines(file_contents, file_path)
      
      # Print a message for each file processed
      print("New line added")
    }
  }
}



# -------------------------------------------------------------------
# ------------------------------ COUNTS------------------------------
# -------------------------------------------------------------------


# Use this for calculating the percentages
count_texts_per_unit <- function(directory_path) {
  file_list <- list.files(directory_path, recursive = TRUE, pattern = "\\.txt$")
  unit_count_df = data.frame(matrix(nrow = 128, ncol = 1))
  unit_count_df[] <- 0
  colnames(unit_count_df) <- c("n_texts")
  for (file_path in file_list){
    print(file_path)
    # get the file unit and id
    file_unit <- as.integer(str_extract(file_path, "\\d+(?=_)"))
    file_id <- as.integer(str_extract(file_path, "(?<=_)\\d+"))
    
    # add one to the unit counts
    unit_count_df$n_texts[file_unit] <- unit_count_df$n_texts[file_unit] + 1 
    
  }
  return(unit_count_df)
}


# 6 levels x 2 cols (level, counts). Use for percentages
count_texts_per_level <- function(directory_path, lang=NULL){
  file_list <- list.files(directory_path, recursive = TRUE, pattern = "\\.txt$")
  level_count_df <- data.frame(level = c("a1", "a2", "b1", "b2", "c1", "c2"), n_texts = 0)
  
  for (file_path in file_list){
    print(file_path)
    # get the file level, unit, id and language. 
    # The file naming convention is <level>/<id>_<unit>_<lang_iso>.txt
    level <- str_extract(file_path, "[abc]\\d")
    unit <- str_extract(file_path, "(?<=_)\\d+") 
    file_id <- str_extract(file_path, "(?<=/)\\d+")
    lang_iso <- str_extract(file_path, "[a-z]{2}")
    print(paste0("level: ", level))
    print(paste0("file_id: ", file_id))
    print(paste0("unit: ", unit))
    print(paste0("lang_iso: ", lang_iso))
    
    # find the row index based on the level
    row_index <- which(level_count_df$level == level)
    if (is.null(lang)) {
      print("No lang param passed. Counting all texts.")
      level_count_df$n_texts[row_index] <- level_count_df$n_texts[row_index] +1
    } else if (tolower(lang) == lang_iso) {
      print("Languages are equal. Counting this file.")
      level_count_df$n_texts[row_index] <- level_count_df$n_texts[row_index] +1
    } else {
      print("Languages are not equal. Skipping this")
    }
    
  }
  return(level_count_df)
  
}

# File path is the output file
features_in_text_file <- function(file_path){
  return(unique(readLines(file_path)))
}


# For making a dataframe long. 
make_long_feats_df <- function(dataframe, exclude_col, values_colname){
  dataframe <- pivot_longer(dataframe, cols = -{{exclude_col}}, names_to = "feature", values_to = values_colname)
  dataframe$feature = as.numeric(dataframe$feature)
  
  return(dataframe)
}

# unit x features in short form. Also possible to make long.
# Each row in feats_in_units corresponds to a unit and each column corresponds to a feature. 
# The values in the cells are how many texts contain feature C in unit R 
get_feats_in_units <- function(all_features, directory_path, make_long = TRUE) {
  file_list <- list.files(directory_path, pattern = "\\.txt$", full.names = TRUE, recursive = TRUE)
  
  feats_in_units <- data.frame(matrix(ncol = 659, nrow = 128))
  # make all NANs 0
  feats_in_units[is.na(feats_in_units)] <- 0
  colnames(feats_in_units) <- all_features
  
  for (file_path in file_list) {
    # Get the unique features in the text
    unique_feats = features_in_text_file(file_path)
    # get unit text belongs to
    unit <- as.integer(str_extract(file_path, "\\d+(?=_)"))
    
    print(file_path)
    print(unique_feats)
    
    # Per feat in text, add one to the counts
    for (feat in unique_feats) {
      feats_in_units[unit, feat] <- feats_in_units[unit, feat] + 1
    }
  }
  feats_in_units <- cbind(unit = c(1:nrow(feats_in_units)), feats_in_units)
  
  if (make_long){
    feats_in_units <- make_long_feats_df(feats_in_units, "unit", "total")
  }
  
  return(feats_in_units)
}

# Each row in feats_in_level corresponds to a level and each column corresponds to a feature. 
get_feats_in_levels <- function(all_features, directory_path, make_long = TRUE, percentage = TRUE) {
  file_list <- list.files(directory_path, pattern = "\\.txt$", full.names = TRUE, recursive = TRUE)
  
  # define dataframe:
  feats_in_levels <- data.frame(matrix(ncol = length(all_features), nrow = 6))
  # make all NANs 0
  feats_in_levels[] <- 0
  
  colnames(feats_in_levels) <- all_features
  print(file_list)
  
  # get number of files per level
  level_counts <- count_texts_per_level(directory_path)
  
  for (file_path in file_list) {
    print(file_path)
    # Get the unique features in the text
    unique_feats = features_in_text_file(file_path)
    # Get the level
    level <- str_extract(file_path, "[abc]\\d")
    if (level == "a1"){
      level_num = 1
    } else if (level == "a2") {
      level_num = 2
    } else if (level == "b1") {
      level_num = 3
    } else if (level == "b2") {
      level_num = 4
    } else if (level == "c1") {
      level_num = 5
    } else if (level == "c2") {
      level_num = 6
    }
    
    for (feat in unique_feats) {
      feats_in_levels[level_num , feat] <- feats_in_levels[level_num , feat]  + 1
    }
    
    
  }
  
  if (percentage){
    feats_in_levels <- feats_in_levels / level_counts$n_texts
  }
  
  # add the level names
  feats_in_levels = cbind(level = c("a1", "a2", "b1", "b2", "c1", "c2"), feats_in_levels)
  
  if (make_long){
    feats_in_levels <- make_long_feats_df(feats_in_levels, "level", "total")
  }
  return(feats_in_levels)
  
}

#--------------------------------------------------------
#-------------------------PLOTS--------------------------
#--------------------------------------------------------
plot_percentages_unit <- function(dataframe_long){
  dataframe_long$feature <- as.factor(dataframe_long$feature)
  ggplot(dataframe_long, aes(x = unit, y = percentage, color = feature)) +
    geom_line() +
    xlab("Units") +
    ylab("Percentage of Presence in Texts") +
    scale_x_continuous(breaks = seq(1, max(dataframe_long$unit), by = 24), labels = seq(1, max(dataframe_long$unit), by = 24))
}

plot_percentages_level <- function(dataframe_long, plot_title) {
  dataframe_long$feature <- as.factor(dataframe_long$feature)
  # dataframe_long$level <- factor(dataframe_long$level, levels = c("a1", "a2", "b1", "b2", "c1", "c2"))
  ggplot(dataframe_long, aes(x = level, y = total, color = feature, group = feature)) +
    geom_line() +
    xlab("Levels") +
    ylab("Percentage of Presence in Texts") +
    scale_x_discrete(
      breaks = c("a1", "a2", "b1", "b2", "c1", "c2"),
      labels = c("A1", "A2", "B1", "B2", "C1", "C2")
    ) +
    ggtitle(plot_title)
}

plot_cluster_means <- function(cluster_means_long, plot_title){
  cluster_means_long$cluster <- as.factor(cluster_means_long$cluster)
  ggplot(cluster_means_long, aes(x = level, y = value, color = cluster, group = cluster)) +
    geom_line() +
    xlab("Levels") +
    ylab("Percentage of Presence in Texts") +
    scale_x_discrete(
      breaks = c("a1", "a2", "b1", "b2", "c1", "c2"),
      labels = c("A1", "A2", "B1", "B2", "C1", "C2")
    ) +
    ggtitle(plot_title)
}

# Make the boxplot by grouping different feature levels - optional vector for ylim
make_boxpolot_group <- function(df, ylim_vector=NULL){
  ggplot(df, aes(x=level, y=total, fill=feat_level))+
    geom_boxplot(notch = TRUE)+
    labs(fill="Feature level", x="Text level", y="Percentage of presence")+
    coord_cartesian(ylim = ylim_vector)
}

# For getting a dataframe with features of only one level
get_level_feats <- function(level, dataframe_long){
  level = tolower(level)
  dataframe_long$feature <- as.numeric(dataframe_long$feature)
  if (level == "a1"){
    level_df <- dataframe_long[dataframe_long$feature <= 109,]
  } else if (level == "a2") {
    level_df <- dataframe_long[dataframe_long$feature >= 110 & dataframe_long$feature <=397,]
  } else if (level == "b1") {
    level_df <- dataframe_long[dataframe_long$feature >= 401 & dataframe_long$feature <=734,]
  } else if (level == "b2"){
    level_df <- dataframe_long[dataframe_long$feature >= 739 & dataframe_long$feature <=977,]
  } else if (level == "c1") {
    level_df <- dataframe_long[dataframe_long$feature >= 982 & dataframe_long$feature <=1105,]
  } else if (level == "c2") {
    level_df <- dataframe_long[dataframe_long$feature >= 1111,]
  } else {
    print("INVALID LEVEL!")
  }
  
  return(level_df)
}


# ----------------------------------------------------
# ----------------------- MISC -----------------------
# ----------------------------------------------------
create_table_image <- function(dataframe) {
  # Create a table from the dataframe using the kable function from the knitr package
  table <- knitr::kable(dataframe)
  
  # Convert the table to a grob object
  table_grob <- tableGrob(table)
  
  # Create a blank plot to save the table as an image
  blank_plot <- ggplot() +
    theme_void()
  
  # Combine the blank plot and table grob using grid.arrange from the gridExtra package
  combined <- grid.arrange(blank_plot, table_grob, nrow = 2)
  
  # Save the combined image as a PNG file
  ggsave("table.png", combined, width = 10, height = 4, dpi = 300)
}

#Returns a vector that contains all features in a df that at some level reach a given percentage
features_reach_percent <- function(dataframe_long, percentage) {
  v = c();
  for (r in 1:nrow(dataframe_long)) {
    if (dataframe_long[r,]$total > percentage) {
      v <- append(v, dataframe_long[r,]$feature)
    }
  }
  
  return(unique(v))
}

feats_between_percents <- function(dataframe_long, lower_bound, upper_bound){
  v1 <- features_reach_percent(dataframe_long, lower_bound)
  v2 <- features_reach_percent(dataframe_long, upper_bound)
  
  return(setdiff(v1, v2))
}

add_clusters_to_long <- function(clusters, df_long) {
  feats <- unique(df_long$feature)
  feats_cluster <- data.frame("feature" = feats, "cluster" = clusters)
  df_long$cluster <- feats_cluster$cluster[match(df_long$feature, feats_cluster$feature)]
  return(df_long)
}