import csv
import os
import requests
import utils
import re

"""
Annotates all files in input_path and its subdirectories

Parameters
_______________
url
input_path
output_path_text: folder where output text files go. They contain one feature per line.
output_path_csv: folder where output csv files go. They contain beginning, end and feature per line.
max_size: the maximum number of words passed to Polke at a given time
"""
def annotate_text(url, input_path, output_path_text, output_path_csv, max_size=200):
    with open(input_path, "r") as infile:
        # Polke can take a max of 500 words, but let's do a max of 200 and hope this is manageable enough
        text = infile.read()
        words_to_do = text.split()

        # to save all the appropriately-sized strings with text.
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

        else: # The whole text can be handled by Polke. Just send as is.
            text_chunks.append(text)

        send_requests(text_chunks, url, output_path_text, output_path_csv)


def send_requests(text_chunks, url, output_path_text, output_path_csv):
    for text in text_chunks:

        timeout = 10
        len_words = len(text.split())
        print("Text length:", len(text), "NUM WORDS", len_words)
        print(text)

        # obtain level from the folder the file is in.
        level = os.path.basename(os.path.dirname(input_path))

        if len_words > 150:
            timeout = 15
        if level in {"b2", "c1", "c2"}:
            timeout = 35
            print("HARD LEVEL!")

        is_last_chunk = text == text_chunks[-1]
        text = text.replace(" ", "%20").replace("\n", "%0A")
        url = url + text
        try:
            request = requests.post(url, timeout=timeout)  # Set a max time in seconds
            if request.status_code != 200:
                print("\nError with status code {}".format(request.status_code) + ": " + input_path + "\n")
            else:
                data = request.json()
                write_csv_and_txt(data, output_path_text, output_path_csv)

                # if the text is very long, only delete when we are done processing all the chunks
                if is_last_chunk:
                    os.remove(input_path)

        # If exceptions are raised, move the input file to a different directory
        except requests.exceptions.Timeout:
            print("\nRequest timed out:", input_path + "\n")

            filename = os.path.basename(input_path)
            level = os.path.basename(os.path.dirname(input_path))
            timeout_level_path = os.path.join("data/timeout", level)

            # make directory if not exists
            os.makedirs(timeout_level_path, exist_ok=True)


            # FIXME: This will only move the file to timeout if the last chunk fails. Ideally, if any chunk fails, we
            #  should move the file to timeout! Think about: Should output then be saved or deleted when a chunk fails?

            # TODO I think what I'd like is that it goes to timeout folder if any part times out, but keep the output
            #  that did pass. Even better: write the chunks that timed out in a file in the timeout folder, but keep
            #  output file. Ideally, if the corresponding file exists in output and we run the script using timeout
            #  folder as input, we can append the new features.
            if is_last_chunk:
                # move the file
                os.rename(input_path, os.path.join(timeout_level_path, filename))
        except requests.exceptions.RequestException as e:
            print("\n\nError occurred\n\n")
            filename = os.path.basename(input_path)
            level = os.path.basename(os.path.dirname(input_path))
            err_level_path = os.path.join("data/error", level)

            os.makedirs(err_level_path, exist_ok=True)
            if is_last_chunk:
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

    with open(output_path_text + ".txt", "a") as textfile:
        construct_ids = [annotation["constructID"] for annotation in data["annotationList"]]
        textfile.write("\n".join(str(construct_id) for construct_id in construct_ids))


if __name__ == "__main__":
    url = "http://localhost:4000/extractor?text="
    input_dir = "data/input /"
    output_dir = "data/output/"

    for input_path in utils.get_file_paths(input_dir):
        print("Input", input_path)
        level = os.path.split(input_path)[0][-2:]
        output_path_text = os.path.join(output_dir, level, "text", os.path.split(input_path)[1][:-4])
        output_path_csv = os.path.join(output_dir, level, "csv", os.path.split(input_path)[1][:-4])
        annotate_text(url, input_path, output_path_text, output_path_csv)

