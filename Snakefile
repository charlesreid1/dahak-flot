import glob

# Include rule files from each subtask
include: "subtask1/subtask.rule"

# Get all collect files
COLLECT_FILES = glob.glob('subtask*/*.out')

# Now we define some master task:
rule all:
    input:
        COLLECT_FILES
    run:
        for f_ in input:
            contents = ""
            with open(f_,'r') as f:
                contents = f.read()
            print("-"*20)
            print(contents)
            print("-"*20)

