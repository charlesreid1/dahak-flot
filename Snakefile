import subprocess
import glob
import os
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider
HTTP = HTTPRemoteProvider()


"""
Taxonomic Classification Snakefile

This Snakefile defines tasks for the taxonomic
classification workflow.


Todo:
    - Incorporate OSF CLI tool
    - Move variables that won't change often into .settings files
    - Move rules into individual rule files


Notes: 

We define a block of variables before each rule that 
specify input/output files and any parameters for the 
commands. This makes it easy to change hard-coded 
variables into config params from a .settings file.

Dealing with directories, filenames, and wildcards is awkward but doable.
(Snakemake wants relative paths, Docker wants absolute paths,
 brackets aren't evaluated if they're in strings but they are if they're
 hard-coded in the rules, etc.)

Snakemake is designed for things to be hard-coded.
If you don't follow the Snakemake model, life is difficult.
"""


# Need PWD for Docker
PWD = os.getcwd()


# User-specific settings 
include: 'user.settings'

# Settings common to all 
# taxonomic classification workflows
include: 'taxclass.settings'


# Rules:
# ------------


data_dir = config['data_dir']


# -----------------8<-----------------------


quayurls = []
for k in config.keys():
    if(type(config[k])==type({})):
        qurl = config[k]['quayurl']
        qvers = config[k]['version']
        quayurls.append(qurl + ":" + qvers)

rule pull_biocontainers:
    """
    Pull the latest version of sourmash, kaiju, and krona

    To call this rule, ask for the file .pulled_containers
    """
    output:
        touch('.pulled_containers')
    run:
        for quayurl in quayurls:
            shell('''
            docker pull {quayurl}
            ''')


# -----------------8<-----------------------


# NOTE:
#
# Snakefiles are difficult to test because 
# using wildcards to match rules makes it unclear what
# files *are* available or not.
# 
# Example: we have a "databases" wild card, but this 
# Snakefile contains no information about what values
# for "databases" would actually be valid.
#
# In some cases, we don't have a list of acceptable vaules.
# But we ought to be able to distinguish between wildcards
# the user *actually* wants to set arbitrarily, and wildcards
# that can only take on a set number of values, 
# furthermore values the user may not know.
#
#
#
# We also have problems with prefix directories being 
# matched in wildcards, so we can't put data in its
# own directory without more acrobatics.

#data_dir = os.path.join(data_dir,'sourmash')
#subprocess.call(["mkdir","-p",data_dir], cwd=PWD)

sourmash_sbt_tar = "microbe-{database}-sbt-k{ksize}-2017.05.09.tar.gz"
download_sourmash_sbt_input = HTTP.remote(config['sourmash']['sbturl']+"/" + sourmash_sbt_tar)
download_sourmash_sbt_output = download_sourmash_sbt_tar

rule download_sourmash_sbts:
    """
    Downoad the sourmash SBTs from spacegraphcats

    To call this rule, request sourmash SBT json file for the specified database.
    """
    input: 
        '.pulled_containers', 
        download_sourmash_sbt_input
    output: 
        download_sourmash_sbt_output
    shell:
        '''
        curl -O {input[1]}
        '''


unpack_sourmash_sbt_input = sourmash_sbt_tar
unpack_sourmash_sbt_output = '{database}-k{ksize}.sbt.json'

rule unpack_sourmash_sbts:
    """
    Unpack the sourmash SBTs
    """
    input:
        unpack_sourmash_sbt_input
    output:
        unpack_sourmash_sbt_output
    run:
        unpack_sourmash_sbt_tar_wc = unpack_sourmash_sbt_input.format(**wildcards)
        shell('''
            tar xzf {unpack_sourmash_sbt_tar_wc} && rm -f {unpack_sourmash_sbt_tar_wc}
        ''')


# -----------------8<-----------------------


# Get trimmed data filename and OSF URL
# NOTE: this step should be replaced with OSF CLI
trimmed_data_files = []
trimmed_data_urls = []
with open('inputs/trimmed_data.dat','r') as f:
    for ln in f.readlines():
        line = ln.split()
        if(len(line)>0):
            trimmed_data_files.append(line[0])
            trimmed_data_urls.append(line[1])

rule download_trimmed_data:
    """
    Download the trimmed data from OSF

    To call this rule, request the files listed in trimmed_data.dat
    """
    output:
        trimmed_data_files, touch('.trimmed')
    run:
        for (osf_file,osf_url) in zip(trimmed_data_files,trimmed_data_urls):
            if(not os.path.isfile(osf_file)):
                shell('''
                    wget -O {osf_file} {osf_url}
                ''')


# -------------------------8<-------------------------


fq_fwd = '{base}_1.trim{ntrim}.fq.gz' 
fq_rev = '{base}_2.trim{ntrim}.fq.gz'
sig_name =  '{base}.trim{ntrim}.scaled10k.k21_31_51.sig'
merge_file = "{base}_merged.trim{ntrim}.fq.gz"

fq_names = [fq_fwd, fq_rev]
sig_inputs = fq_names
sig_output = sig_name
merge_output = merge_file

quayurl = config['sourmash']['quayurl']+":"+config['sourmash']['version']

rule calculate_signatures:
    """
    Calculate signatures from trimmed data using sourmash
    """
    input:
        sig_inputs
    output:
        sig_output, merge_output
    run:
        fq_fwd_wc = fq_fwd.format(**wildcards)
        fq_rev_wc = fq_rev.format(**wildcards)
        sig_name_wc = sig_name.format(**wildcards)
        merge_file_wc = merge_file.format(**wildcards)
        shell('''
            docker run \
                    -v {PWD}:/data \
                    {quayurl} \
                    sourmash compute \
                    --merge /data/{merge_file_wc} \
                    --track-abundance \
                    --scaled 10000 \
                    -k 21,31,51 \
                    /data/{fq_fwd_wc} \
                    /data/{fq_rev_wc} \
                    -o /data/{sig_name_wc}
        ''')



# -----------------8<-----------------------



kaiju_dmp = 'nodes.dmp'
kaiju_dmp2 = 'names.dmp'
kaiju_fmi = 'kaiju_db_nr_euk.fmi'
kaiju_tar = 'kaiju_index_nr_euk.tgz'
kaiju_url = 'http://kaiju.binf.ku.dk/database'

kaiju_output = [kaiju_dmp, kaiju_dmp2, kaiju_fmi]
unpack_kaiju_input = HTTP.remote(kaiju_url)

rule unpack_kaiju:
    """
    Download and unpack the kaiju database.
    The ( ) notation in the shell creates a temporary scope.
    """
    output:
        unpack_kaiju_output
    shell:
        '''
        curl -LO "{kaiju_url}/{kaiju_tar}"
        tar xzf {kaiju_tar}
        rm -f {kaiju_tar}
        '''


# -----------------8<-----------------------


run_kaiju_input = [kaiju_dmp, kaiju_fmi]
run_kaiju_input += fq_names
run_kaiju_output = '{base}.kaiju_output.trim{ntrim}.out'

quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']

rule run_kaiju:
    """
    Run kaiju
    """
    input:
        run_kaiju_input
    output:
        run_kaiju_output
    run:
        fq_fwd_wc = fq_fwd.format(**wildcards)
        fq_rev_wc = fq_rev.format(**wildcards)
        run_kaiju_output_wc = run_kaiju_output.format(**wildcards)
        shell('''
            docker run \
                    -v {PWD}:/data \
                    {quayurl} \
                    kaiju \
                    -x \
                    -v \
                    -t /data/{kaiju_dmp} \
                    -f /data/{kaiju_fmi} \
                    -i /data/{fq_fwd_wc} \
                    -j /data/{fq_rev_wc} \
                    -o /data/{run_kaiju_output_wc} \
                    -z 4
        ''')


# -----------------8<-----------------------


kaiju2krona_input = [kaiju_dmp, kaiju_dmp2, kaiju_output_name]
kaiju2krona_output = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona'

quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']

rule kaiju2krona:
    """
    Convert kaiju results to krona results,
    and generate a report.
    """
    input:
        kaiju2krona_input
    output:
        kaiju2krona_output
    run:
        kaiju2krona_in_name_wc = run_kaiju_output.format(**wildcards)
        kaiju2krona_output_name_wc = kaiju2krona_output.format(**wildcards)
        shell('''
            docker run \
                    -u `stat -c "%u:%g" {PWD}` \
                    -v {PWD}:/data \
                    {quayurl} \
                    kaiju2krona \
                    -v \
                    -t /data/{kaiju_dmp} \
                    -n /data/{kaiju_dmp2} \
                    -i /data/{kaiju2krona_in_name_wc} \
                    -o /data/{kaiju2krona_output_name_wc}
        ''')


# -----------------8<-----------------------


kaiju2kronasummary_input = [kaiju_dmp, kaiju_dmp2, run_kaiju_output]
kaiju2kronasummary_output = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona.summary'

quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']

rule kaiju2kronasummary:
    """
    Convert kaiju results to krona results,
    and generate a report.
    """
    input:
        kaiju2kronasummary_input
    output:
        kaiju2kronasummary_output
    run:
        kaiju2kronasummary_in_wc = run_kaiju_output.format(**wildcards)
        kaiju2kronasummary_output_wc = kaiju2kronasummary_output.format(**wildcards)
        shell('''
            docker run \
                    -u `stat -c "%u:%g" {PWD}` \
                    -v {PWD}:/data \
                    {quayurl} \
                    kaijuReport \
                    -v \
                    -t /data/{kaiju_dmp} \
                    -n /data/{kaiju_dmp2} \
                    -i /data/{kaiju2kronasummary_in_wc} \
                    -r genus \
                    -o /data/{kaiju2kronasummary_output_wc}
        ''')


# -----------------8<-----------------------


filter_taxa_total_input = [kaiju_dmp, kaiju_dmp2, run_kaiju_output]
filter_taxa_total_output = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona.1percenttotal.summary'

quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']

rule filter_taxa_total:
    """
    Filter out taxa with low abundances by obtaining genera that 
    comprise at least 1 percent of the total reads:
    """
    input:
        filter_taxa_total_input
    output:
        filter_taxa_total_output
    run:
        filter_taxa_total_in_wc = run_kaiju_output.format(**wildcards)
        filter_taxa_total_output_wc = filter_taxa_total_output.format(**wildcards)
        shell('''
            docker run \
                -v {PWD}:/data \
                {quayurl} \
                kaijuReport \
                -v \
                -t /data/{kaiju_dmp} \
                -n /data/{kaiju_dmp2} \
                -i /data/{filter_taxa_in_wc} \
                -r genus \
                -m 1 \
                -o /data/{filter_taxa_total_output_wc}
        ''')


# -----------------8<-----------------------


filter_taxa_class_input = [kaiju_dmp, kaiju_dmp2, run_kaiju_output]
filter_taxa_class_output = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona.1percentclassified.summary'

quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']

rule filter_taxa_class:
    """
    For comparison, take the genera that comprise 
    at least 1 percent of all of the classified reads
    """
    input:
        filter_taxa_class_input
    output:
        filter_taxa_class_output
    run:
        filter_taxa_class_in_wc = run_kaiju_output.format(**wildcards)
        filter_taxa_class_output_wc = filter_taxa_class_output_name.format(**wildcards)
        shell('''
                docker run \
                        -v {data_dir}:/data \
                        {quayurl} \
                        kaijuReport \
                        -v \
                        -t /data/{kaiju_dmp} \
                        -n /data/{kaiju_dmp2} \
                        -i /data/{filter_taxa_class_in_wc} \
                        -r genus \
                        -m 1 \
                        -u \
                        -o /data/{filter_taxa_class_output_wc}
        ''')


# -----------------8<-----------------------


visualize_krona_input = '{base}.kaiju_output.trim{ntrim}.{suffix}.summary'
visualize_krona_output = '{base}.kaiju_output.trim{ntrim}.{suffix}.html'

quayurl = config['krona']['quayurl'] + ":" + config['krona']['version']

rule visualize_krona:
    """
    Visualize the results of the 
    full and filtered taxonomic 
    classifications using krona.
    """
    input:
        visualize_krona_input
    output:
        visualize_krona_output
    run:
        visualize_krona_output_wc = visualize_krona_output.format(**wildcards)
        visualize_krona_input_wc = visualize_krona_input.format(**wildcards)
        shell('''
            docker run \
                    -v {PWD}:/data \
                    {quayurl} \
                    ktImportText \
                    -o /data/{visualize_krona_output_wc} \
                    /data/{visualize_krona_input_wc}
        ''')


# -----------------8<-----------------------


### rule cleanreally:
###     """
###     This nukes everything - all that hard work! Be careful.
###     """
###     shell:
###         '''
###         '''

## NOTE: Add this back in once we're finished testing.
#onsuccess:
#    shell("rm -f .pulled_containers")
#    shell("rm -f .trimmed")

