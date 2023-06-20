import os

def delete_all_in(directory):
    #directory = "data/output"
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".csv") or file.endswith(".txt"):
                file_path = os.path.join(root, file)
                os.remove(file_path)
                print("Deleted:", file_path)

def delete_ready(input_dir, output_dir):
    # Iterate through the files in the input directory
    for root, dirs, files in sorted(os.walk(input_dir)):
        for filename in files:
            # Get the file path relative to the input directory
            input_file_path = os.path.join(root, filename)
            relative_path = os.path.relpath(input_file_path, input_dir)

            # Split the relative path to get the corresponding output directory structure
            input_parts = relative_path.split(os.sep)
            output_subdir = os.path.join(output_dir, *input_parts[:-1])  # Directory corresponding to input file
            output_file_path = os.path.join(output_subdir, "text/", filename)  # Corresponding output file path

            # Check if the corresponding output file exists
            if os.path.exists(output_file_path):
                # Delete the input file
                os.remove(input_file_path)
                print("Deleted:", input_file_path)



if __name__ == "__main__":
    delete_ready("data/input", "data/output")

