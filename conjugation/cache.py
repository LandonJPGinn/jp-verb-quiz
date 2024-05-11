import json
from collections import Counter

# read words
with open('words.json','r', encoding="utf-8")as f:
    words = json.load(f)

word_count = len(words)
results = Counter({"total_word_count": word_count})

for k,v in words.items():
    results += Counter(v['tags'])



# counter_dict = {k:v for k,v in dict(results).items() if v > 5 and k != 'to'}
counter_dict = dict(results)
# Define the file path
json_file_path = 'count.json'

# Write the dictionary to a JSON file
with open(json_file_path, 'w') as json_file:
    json.dump(counter_dict, json_file, indent=4)