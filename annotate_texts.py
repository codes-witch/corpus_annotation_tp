import csv
import os
import requests
import utils
import re


def annotate_text(url, input_path, output_path_text, output_path_csv, max_size=200):
    """
    Annotates the file in input_path and writes output to a .csv/.txt file

    Parameters
    _______________
    url
    input_path
    output_path_text: folder where output text files go. They contain one feature per line.
    output_path_csv: folder where output csv files go. They contain beginning, end and feature per line.
    max_size: the maximum number of words passed to Polke at a given time
    """
    with open(input_path, "r") as infile:
        # Polke can take a max of 500 words, but let's do a max of 200 and hope this is manageable enough
        text = infile.read()
        words_to_send = text.split()

        # If they are more words than Polke can handle, split at the first end of sentence (EOS) symbol we find and pass
        # it in chunks
        text_chunks = get_text_chunks(words_to_send, max_words=max_size)

        send_requests(text_chunks, url, output_path_text, output_path_csv)


def send_requests(text_chunks, url, output_path_text, output_path_csv):
    """
    :param text_chunks: A list of strings representing the text to analyse with POLKE
    :param url: POLKE URL
    :param output_path_text:
    :param output_path_csv:
    :return:
    """
    if len(text_chunks) > 1:
        print("More than one chunk")
    for chunk in text_chunks:
        len_words = len(chunk.split())
        print("NUM WORDS:", len_words)
        print(chunk)

        # obtain level from the folder the file is in.
        level = os.path.basename(os.path.dirname(input_path))
        # filename
        filename = os.path.basename(input_path)
        # path to the level subdirectory in the different error folders
        err_level_path = os.path.join("data/error", level)
        timeout_level_path = os.path.join("data/timeout", level)

        # Set a max time for the request in seconds
        timeout = get_timeout(level, len_words)

        is_last_chunk = chunk == text_chunks[-1]

        url = url + chunk.replace(" ", "%20").replace("\n", "%0A").replace("\t", "%20")

        try:
            request = requests.post(url, timeout=timeout)
            if request.status_code != 200:
                print("\nError with status code {}".format(request.status_code) + ": " + input_path + "\n")
                os.makedirs(err_level_path, exist_ok=True)

                # Write the chunk that caused the error to a file
                with open(os.path.join(err_level_path, filename), "a") as textfile:
                    textfile.write("\n" + chunk)

            else:
                data = request.json()
                write_csv_and_txt(data, output_path_text, output_path_csv, chunk, level)

            # only delete when we are done processing all the chunks
            if is_last_chunk:
                os.remove(input_path)

        # If exceptions are raised, save the problematic chunk in a different file. If done processing, remove file from
        # input path
        except requests.exceptions.Timeout:
            print("\nRequest timed out:", input_path + "\n")

            # make directory if not exists
            os.makedirs(timeout_level_path, exist_ok=True)

            with open(os.path.join(timeout_level_path, filename), "a") as textfile:
                textfile.write(chunk)
            if is_last_chunk:
                os.remove(input_path)


        except requests.exceptions.RequestException as e:
            print("\n\nError occurred:\n\n" + e)

            os.makedirs(err_level_path, exist_ok=True)

            # Write the chunk that caused the error to a file
            with open(os.path.join(err_level_path, filename), "a") as textfile:
                textfile.write(chunk)

            if is_last_chunk:
                os.remove(input_path)


def write_csv_and_txt(data, output_path_text, output_path_csv, chunk, level):
    csv_dir = os.path.dirname(output_path_csv)
    os.makedirs(csv_dir, exist_ok=True)
    txt_dir = os.path.dirname(output_path_text);
    os.makedirs(txt_dir, exist_ok=True)

    with open(output_path_csv + ".csv", "a", newline="") as csvfile:
        writer = csv.writer(csvfile)

        # Write the header if the file is empty
        if csvfile.tell() == 0:
            # writer.writerow(["constructID", "begin", "end"])

            # ConstructID: the ID of the construct found.
            # begin/end: beginning and ending index of the construct found
            # chunk: the text being analysed at a time by the tool.
            writer.writerow(["constructID", "begin", "end", "chunk"])

        for idx, annotation in enumerate(data["annotationList"]):
            construct_id = annotation["constructID"]
            begin = annotation["begin"]
            end = annotation["end"]
            writer.writerow([construct_id, begin, end, chunk if idx == 0 else None])

        print("CSV file updated:", output_path_csv + "\n\n")

    with open(output_path_text + ".txt", "a") as textfile:
        textfile.write("\n" + chunk)

    update_nwords_file(chunk, level)


"""
************************************************ HELPER METHODS **********************************
"""


def get_text_chunks(words_to_send, max_words):
    """
    :param words_to_send: Whole text to be sent
    :param max_words: Maximum number of words to be sent at the same time
    :return: A list of appropriately-sized chunks (strings) to be sent to POLKE
    """
    text_chunks = []

    if len(words_to_send) > max_words:
        while len(words_to_send) > 0:
            first_max_words = words_to_send[0:max_words + 1] # just the first n words, disregarding EOS

            eos_idx = find_eos_index(first_max_words)

            # If we found a word that ends a sentence, send the text up until there. words_to_send should be the
            # remaining words
            if eos_idx is not None:
                first_chunk = words_to_send[:eos_idx + 1]
                words_to_send = words_to_send[eos_idx + 1:]

            # If we don't find a word that ends a sentence in first_max_words, just send the first_max_words
            else:
                first_chunk = first_max_words
                words_to_send = words_to_send[max_words + 1:]

            text = " ".join(first_chunk)
            text_chunks.append(text)

    else:  # The whole text can be handled by Polke. Just send as is.
        text_chunks.append(" ".join(words_to_send))

    print(text_chunks)
    return text_chunks


def get_timeout(level, len_words):
    timeout = 7
    if len_words > 150:
        timeout = 15
    if level in {"b2", "c1", "c2"}:
        timeout = 30
        print("Text belongs to a difficult level (B2 or greater)")

    return timeout


def find_eos_index(word_list):
    """
    :param word_list: a list of words as long as POLKE can manage.
    :return: the index of the last word in the list to end a sentence. If no word ends a sentence, None.
    """
    eos_idx = None  # index of the last EOS word in the first_max_words.

    # iterate backwards to find the last word that ends a sentence in the current chunk of text
    for idx, word in reversed(list(enumerate(word_list))):
        if re.match("\w+(\.|!|\?)+", word):
            eos_idx = idx
            break

    return eos_idx

def update_nwords_file(chunk, level):
    with open("./word_count_" + level + ".txt", "r") as progr_file:
        current_word_count = int(progr_file.read())

    with open("./word_count_" + level + ".txt", "w") as progr_file:
        current_word_count += len(chunk.split())
        progr_file.write(str(current_word_count))

    print("./word_count_" + level + ".txt updated")


if __name__ == "__main__":
    url = "http://localhost:4000/extractor?text="
    input_dir = "data/input/"
    output_dir = "data/output/"

    for input_path in utils.get_file_paths(input_dir):
        print("Input", input_path)
        level = os.path.split(input_path)[0][-2:]
        output_path_text = os.path.join(output_dir, level, "text", os.path.split(input_path)[1][:-4])
        output_path_csv = os.path.join(output_dir, level, "csv", os.path.split(input_path)[1][:-4])
        annotate_text(url, input_path, output_path_text, output_path_csv)
