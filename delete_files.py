import os
if __name__ == "__main__":

    directory = "data/output"
    test = os.listdir(directory)

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(".csv") or file.endswith(".txt"):
                file_path = os.path.join(root, file)
                os.remove(file_path)
                print("Deleted:", file_path)