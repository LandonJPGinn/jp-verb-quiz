import json

with open('words.json','r', encoding="utf-8")as f:
    words = json.load(f)

with open('rules.json','r', encoding="utf-8")as f:
    rules = json.load(f)

word_count = len(words)
results = {"total_word_count": word_count}

group_count = len(rules)

for grp in rules:
    val = len([k for k,v in words.items() if v['group'] == grp])
    results[grp] = val

counter_dict = dict(results)

json_file_path = 'count.json'

with open(json_file_path, 'w') as json_file:
    json.dump(counter_dict, json_file, indent=4)