text_files_from_df <- function(dataframe, directory) {
  # Create the directory to store the text files (if it doesn't exist)
  dir.create(directory, showWarnings = FALSE)
  
  # Iterate over each row in the dataframe
  for (i in 1:nrow(dataframe)) {
    # Create a subdirectory for each level (if it doesn't exist)
    level_directory <- paste0(directory, "/", dataframe$cefr_level[i])
    dir.create(level_directory, showWarnings = FALSE)
    
    # Generate a unique filename for each row
    filename <- paste0(level_directory, "/", dataframe$id[i], ".txt")
    
    # Open the file connection
    file_conn <- file(filename, open = "w")
    
    # Write the text content to the file
    writeLines(as.character(dataframe$text[i]), con = file_conn)
    
    # Close the file connection
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


add_cefr_levels <- function(dataframe){
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

put_units_in_filenames <- function(directory_path, dataframe){
  
  # Get the list of files in the directory
  file_list <- list.files(directory_path, pattern = "\\.txt$", full.names = TRUE)
  
  # Iterate through each file
  for (file_path in file_list) {
    # Extract the filename without extension
    file_name <- tools::file_path_sans_ext(basename(file_path))
    print(file_name)
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

count_texts_per_unit <- function(directory_path, unit_count_df) {
  file_list <- list.files(directory_path)
  
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

features_in_text_file <- function(file_path){
  return(unique(readLines(file_path)))
}

# Each row in feats_in_units corresponds to a unit and each column corresponds to a feature. 
# The values in the cells are how many texts contain feature C in unit R 
get_feats_in_units_df <- function(all_features, directory_path) {
  file_list <- list.files(directory_path, pattern = "\\.txt$", full.names = TRUE, recursive = TRUE)
  
  # define dataframe:
  feats_in_units <- data.frame(matrix(ncol = 659, nrow = 128))
  # make all NANs 0
  feats_in_units[is.na(feats_in_units)] <- 0
  colnames(feats_in_units) <- all_features
  
  for (file_path in file_list) {
    # Get the unique features in the text
    unique_feats = features_in_text_file(file_path)
    unit <- as.integer(str_extract(file_path, "\\d+(?=_)"))
    
    print(file_path)
    print(unique_feats)
   
    for (feat in unique_feats) {
      feats_in_units[unit, feat] <- feats_in_units[unit, feat] + 1
    }
  }
  
  return(feats_in_units)
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