import csv

from argparse import ArgumentParser


top_levels = [
    {"ID": "GECKO:0000001", "Label": "basic cohort attributes"},
    {"ID": "GECKO:0000014", "Label": "biosample"},
    {"ID": "GECKO:0000027", "Label": "laboratory measures"},
    {"ID": "GECKO:0000052", "Label": "survey administration"},
    {"ID": "GECKO:0000056", "Label": "questionnaire/survey data"},
    {"ID": "GECKO:0000101", "Label": "statistics"},
]


def main():
    p = ArgumentParser()
    p.add_argument("query_result")
    p.add_argument("ihcc_view_template")
    args = p.parse_args()

    template = []
    with open(args.query_result, "r") as f:
        reader = csv.reader(f)
        next(f)
        for row in reader:
            template.append({"ID": row[0], "Label": row[1], "Parent": row[2]})

    with open(args.ihcc_view_template, "w") as f:
        writer = csv.DictWriter(f, fieldnames=["ID", "Label", "Parent"])
        writer.writeheader()
        writer.writerow({"ID": "ID", "Label": "LABEL", "Parent": "SC %"})
        writer.writerows(top_levels)
        writer.writerows(template)


if __name__ == "__main__":
    main()
