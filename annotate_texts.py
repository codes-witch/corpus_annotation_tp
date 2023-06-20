import json
import os
import requests
import subprocess
import time
import utils

start_time = time.process_time()


def annotate_text(url, input_path, output_path):
    with open(input_path, "r") as infile:
        text = infile.read().replace(" ", "%20").replace("\n", "%0A")
        url = url + text
        request = requests.post(url)

        if request.status_code != 200:
            print("\nError with status code {}".format(request.status_code) + ": " + input_path + "\n")
        else:
            print("Success:", input_path)
            data = request.json()
            with open(output_path + ".json", "w") as outfile:
                json.dump(data, outfile)


if __name__ == "__main__":
    url = "http://kibi.group:4000/extractor?text="
    input_dir = "data/input/egp"
    output_dir = "data/output/egp/json"

    # for out_dir in ["data/output/egp/xmi/" + level for level in levels]:
    #     if not os.path.exists(out_dir):
    #         os.makedirs(out_dir)
    
    for input_path in sorted(utils.get_file_paths(input_dir)):
        print("Input", input_path)
        level = os.path.split(input_path)[0][-2:]
        print("Level", level)
        output_path = os.path.join(output_dir, level, os.path.split(input_path)[1][:-4])
        print("Output", output_path)
        annotate_text(url, input_path, output_path)

    print("\nTime elapsed: ", time.process_time() - start_time, "seconds\n")

