import csv
import json
import os
from datetime import datetime

import requests
import subprocess
import time
import utils
import re

start_time = time.process_time()
total_timed_out = 0
MAX_TIME_OUT = 1


def annotate_text(url, input_path, output_path_text, output_path_csv, max_size):
    with open(input_path, "r") as infile:
        # Polke can take a max of 500 words.
        text = infile.read()
        words_to_do = text.split()

        # to save all the appropriately sized strings with text.
        text_chunks = []

        # If they are more words than Polke can handle, split at the first end of sentence (EOS) symbol we find and pass
        # it in chunks
        if len(words_to_do) > max_size:
            while len(words_to_do) > 0:
                first_max_words = words_to_do[0:max_size+1]

                eos_idx = None # index of the last EOS word in the first_max_words.

                # iterate backwards to find the last word that ends a sentence in the current chunk of text
                for idx, word in reversed(list(enumerate(first_max_words))):
                    if re.match("\w+(\.|!|\?)+", word):
                        eos_idx = idx
                        # print(idx, word)
                        break

                # If we found a word that ends a sentence, send the text up until there. words_to_do should be the
                # remaining words
                if eos_idx is not None:
                    first_chunk = words_to_do[:eos_idx+1]
                    words_to_do = words_to_do[eos_idx+1:]

                # If we don't find a word that ends a sentence in first_max_words, just send the first_max_words
                else:
                    first_chunk = first_max_words
                    words_to_do = words_to_do[max_size+1:]

                text = " ".join(first_chunk)
                text_chunks.append(text)

        else:
            text_chunks.append(text)

        send_requests(text_chunks, url, output_path_text, output_path_csv)


def send_requests(text_chunks, url, output_path_text, output_path_csv, total_timed_out=total_timed_out):
    for text in text_chunks:
        timeout = 8

        len_words = len(text.split())
        print("Text length:", len(text), "NUM WORDS", len_words)

        if len_words > 250:
            timeout = 17
        elif len_words > 150:
            timeout = 12

        text = text.replace(" ", "%20").replace("\n", "%0A")
        url = url + text
        try:
            print(timeout)
            request = requests.post(url, timeout=timeout)  # Set a max time in seconds
            if request.status_code != 200:
                print("\nError with status code {}".format(request.status_code) + ": " + input_path + "\n")
            else:
                data = request.json()
                # print("NUMBER OF ANNOTATIONS in " + input_path, len(data["annotationList"]))
                write_csv_and_txt(data, output_path_text, output_path_csv)
                os.remove(input_path)

        # If exceptions are raised, move the input file to a different directory
        except requests.exceptions.Timeout:
            print("\nRequest timed out:", input_path + "\n")
            total_timed_out += 1

            # TODO restart server if too many requests have timed out
            # if total_timed_out >= MAX_TIME_OUT:
            #     print("Timeout threshold exceeded. Restarting the server...")
            #
            #     # Trigger the bash script to restart the server
            #     subprocess.run(["bash", "restart_server.sh"])
            #
            #     print("Waiting for server to restart...")
            #     time.sleep(restart_wait_time)
            # # get filename and level

            filename = os.path.basename(input_path)
            level = os.path.basename(os.path.dirname(input_path))
            timeout_level_path = os.path.join("data/timeout", level)

            # make directory if not exists
            os.makedirs(timeout_level_path, exist_ok=True)

            # move the file
            os.rename(input_path, os.path.join(timeout_level_path, filename))
        except requests.exceptions.RequestException as e:
            print("\n\nError occurred\n\n")
            filename = os.path.basename(input_path)
            level = os.path.basename(os.path.dirname(input_path))
            err_level_path = os.path.join("data/error", level)

            os.makedirs(err_level_path, exist_ok=True)
            os.rename(input_path, os.path.join(err_level_path, filename))


def write_csv_and_txt(data, output_path_text, output_path_csv):
    csv_dir = os.path.dirname(output_path_csv)
    os.makedirs(csv_dir, exist_ok=True)
    txt_dir = os.path.dirname(output_path_text);
    os.makedirs(txt_dir, exist_ok=True)

    with open(output_path_csv + ".csv", "a", newline="") as csvfile:
        writer = csv.writer(csvfile)

        # Write the header if the file is empty
        if csvfile.tell() == 0:
            writer.writerow(["constructID", "begin", "end"])

        for annotation in data["annotationList"]:
            construct_id = annotation["constructID"]
            begin = annotation["begin"]
            end = annotation["end"]
            writer.writerow([construct_id, begin, end])

        print("CSV file updated:", output_path_csv + "\n\n")

    with open(output_path_text + ".txt", "w") as textfile:

        construct_ids = [annotation["constructID"] for annotation in data["annotationList"]]
        textfile.write("\n".join(str(construct_id) for construct_id in construct_ids))


if __name__ == "__main__":
    url = "http://localhost:4000/extractor?text="
    input_dir = "data/input/"
    output_dir = "data/output/"

    for input_path in utils.get_file_paths(input_dir):
        print("Input", input_path)
        level = os.path.split(input_path)[0][-2:]
        output_path_text = os.path.join(output_dir, level, "text", os.path.split(input_path)[1][:-4])
        output_path_csv = os.path.join(output_dir, level, "csv", os.path.split(input_path)[1][:-4])
        annotate_text(url, input_path, output_path_text, output_path_csv, 450)

    print("\nTime elapsed: ", time.process_time() - start_time, "seconds\n")

