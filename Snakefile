import glob
import os
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider


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

Dealing with directories and filenames is extremely awkward.
We have several filenames to deal with - multiple input & output files - 
and for each one, we have to assemble the filename itself,
the local path to the file, the container path to the file,
the absolute path to the file (for mounting directories in Docker),
and often the output file names depend on the input file names.

Furthermore, we have the additional complication that 
the tags {base} and {ntrim} in the input/output blocks 
become {wildcards.base} and {wildcards.ntrim} in run/shell blocks.
Snakemake does not go out of its way to ease any of this.
"""


# Need PWD for Docker
PWD = os.get_cwd()


# User-specific settings 
include: 'user.settings'

# Settings common to all 
# taxonomic classification workflows
include: 'taxclass.settings'


# Rules:
# ------------

def getquayurls():
    return [config[k]['quayurl']+":"+config[k]['version'] for k in config.keys()]

rule pull_biocontainers:
    """
    Pull the latest version of sourmash, kaiju, and krona

    To call this rule, ask for the file .pulled_containers
    """
    output:
        touch('.pulled_containers')
    params:
        quayurls = getquayurls
    run:
        for quayurl in params.quayurls:
            subprocess.call(["docker","pull",quayurl])


sourmash_dir = os.path.join(data_dir,'sourmash')
sourmash_sbt_outputs = os.path.join(sourmash_dir,'{database}-k{ksize}.sbt.json')
sourmash_sbt_inputs = HTTP.remote(config['sourmash']['sbturl']+"/microbe-{database}-sbt-k{ksize}-2017.05.09.tar.gz")

rule download_sourmash_sbts:
    """
    Downoad the sourmash SBTs from spacegraphcats

    To call this rule, request sourmash SBT json file for the specified database.
    """
    output: 
        sourmash_sbt_outputs
    input: 
        '.pulled_containers',
        sourmash_sbt_inputs
    shell: 
        '''
        tar xf {input} -C {sourmash_dir}
        '''


# Get trimmed data filename and OSF URL
# TODO:
# This step should be replaced 
# with OSF CLI
trimmed_data_fnames = []
trimmed_data_urls = []
with open('trimmed_data.dat','r') as f:
    for ln in f.readlines():
        line = ln.split()
        trimmed_data_fnames.append(line[0])
        trimmed_data_urls.append(line[1])

rule download_trimmed_data:
    """
    Download the trimmed data from OSF

    To call this rule, request the files listed in trimmed_data.dat
    """
    output:
        trimmed_data_fnames
    params:
        url = trimmed_data_urls
    shell:
        '''
        curl {params.url} -o {output}
        '''


# This code is super awkward.
#
# Trying to deal with the plain filename,
# the local dir prefix plus the filename,
# the container dir prefix plus the filename,
# all of this for both the inputs and the outputs,
# plus the output file name depends on the input file name,
# plus the tags {base} and {ntrim} in input/output blocks
# are {wildcards.base} and {wildcards.ntrim} in run/shell blocks.
# 
# Snakemake does not provide any way of doing this gracefully.

fq_fwd = '{base}_1.trim{ntrim}.fq.gz' 
fq_rev = '{base}_2.trim{ntrim}.fq.gz'

fq_fwd_wc = '{wildcards.base}_1.trim{wildcards.ntrim}.fq.gz' 
fq_rev_wc = '{wildcards.base}_2.trim{wildcards.ntrim}.fq.gz' 

fq_names = [fq_fwd, fq_rev]
sig_name =  '{base}.trim{ntrim}.scaled10k.k21_31_51.sig'
sig_name_wc =  '{wildcards.base}.trim{wildcards.ntrim}.scaled10k.k21_31_51.sig'

merge_file = "{base}.trim{ntrim}.fq.gz"
merge_file_wc = "{wildcards.base}.trim{wildcards.ntrim}.fq.gz"

sig_inputs = [os.path.join(data_dir,fq) for fq in fq_names]
sig_output = os.path.join(data_dir,sig_name)

rule calculate_signatures:
    """
    Calculate signatures from trimmed data using sourmash

    """
    input:
        sig_inputs
    output:
        sig_output, merge_file
    params:
        quayurl = config['sourmash']['quayurl']+":"+config['sourmash']['version']
    shell:
        '''
        docker run \
                -v {PWD}/{data_dir}:/data \
                {params.quayurl} \
                sourmash compute \
                --merge /data/{merge_file_wc} \
                --track-abundance \
                --scaled 10000 \
                -k 21,31,51 \
                /data/{fq_fwd_wc} \
                /data/{fq_rev_wc} \
                -o /data/{sig_name_wc}
        '''



kaiju_dirname = 'kaijudb'
kaiju_dir = os.path.join(data_dir,kaiju_dirname)
kaiju_dmp = 'nodes.dmp'
kaiju_dmp2 = 'names.dmp'
kaiju_fmi = 'kaiju_db_nr_euk.fmi'
kaiju_tar = 'kaiju_index_nr_euk.tgz'
kaiju_url = 'http://kaiju.binf.ku.dk/database'

kaiju_output_names = [kaiju_dmp, kaiju_fmi]
unpack_kaiju_output = [os.path.join(kaiju_dir,f) for f in kaiju_output_names]
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
        mkdir -p {kaiju_dir} 
        (
        cd {kaiju_dir}
        curl -LO "{kaiju_url}/{kaiju_tar}"
        tar xzf {kaiju_tar}
        rm -f {kaiju_tar}
        )
        '''


kaiju_input_names = [kaiju_dmp, kaiju_fmi]
run_kaiju_input = [os.path.join(kaiju_dir,f) for f in kaiju_input_names]
run_kaiju_input += [os.path.join(data_dir,f) for f in fq_names]

kaiju_output_name = '{base}.kaiju_output.trim{ntrim}.out'
kaiju_output_name_wc = '{wildcards.base}.kaiju_output.trim{wildcards.ntrim}.out'
run_kaiju_output = os.path.join(data_dir,kaiju_output_name)

quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']

rule run_kaiju:
    """
    Run kaiju
    """
    input:
        run_kaiju_input
    output:
        run_kaiju_output
    shell:
        '''
        docker run \
                -v {PWD}/{data_dir}:/data \
                {quayurl} \
                kaiju \
                -x \
                -v \
                -t /data/{kaiju_dir}/{kaiju_dmp} \
                -f /data/{kaiju_dir}/{kaiju_fmi} \
                -i /data/{fq_fwd_wc} \
                -j /data/{fq_rev_wc} \
                -o /data/{kaiju_output_name_wc} \
                -z 4
        '''


kaiju2krona_input_names = [kaiju_dmp, kaiju_dmp2, run_kaiju_output]
kaiju2krona_input = [os.path.join(kaiju_dir,f) for f in kaiju_input_names]

kaiju2krona_in_name_wc = kaiju_output_name_wc # just the -i in file

kaiju2krona_output_name = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona'
kaiju2krona_output_name_wc = '{wildcards.base}.kaiju_output.trim{wildcards.ntrim}.kaiju_out_krona'
kaiju2krona_output = os.path.join(data_dir,kaiju2krona_output_name)

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
    shell:
        '''
        docker run \
                -v {data_dir}:/data \
                {quayurl} \
                kaiju2krona \
                -v \
                -t /data/{kaiju_dir}/{kaiju_dmp} \
                -n /data/{kaiju_dir}/{kaiju_dmp2} \
                -i /data/{kaiju2krona_in_name_wc} \
                -o /data/{kaiju2krona_output_name_wc}
        '''


kaiju2kronasummary_input_names = [kaiju_dmp, kaiju_dmp2, run_kaiju_output]
kaiju2kronasummary_input = [os.path.join(kaiju_dir,f) for f in kaiju2kronasummary_input_names]

kaiju2kronasummary_in_name_wc = kaiju_output_name_wc # just the -i in file

kaiju2kronasummary_output_name = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona.summary'
kaiju2kronasummary_output_name_wc = '{wildcards.base}.kaiju_output.trim{wildcards.ntrim}.kaiju_out_krona.summary'
kaiju2kronasummary_output = os.path.join(data_dir,kaiju2kronasummary_output_name)

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
    shell:
        '''
        docker run \
                -v {data_dir}:/data \
                {quayurl} \
                kaijuReport \
                -v \
                -t /data/{kaiju_dir}/{kaiju_dmp} \
                -n /data/{kaiju_dir}/{kaiju_dmp2} \
                -i /data/{kaiju2kronasummary_in_name_wc} \
                -r genus \
                -o /data/{kaiju2kronasummary_output_name_wc}
        '''


filter_taxa_input_names = [kaiju_dmp, kaiju_dmp2, run_kaiju_output]
filter_taxa_input = [os.path.join(kaiju_dir,f) for f in filter_taxa_input_names]

filter_taxa_in_name_wc = kaiju_output_name_wc # just the -i in file

filter_taxa_total_output_name = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona.1percenttotal.summary'
filter_taxa_total_output_name_wc = '{wildcards.base}.kaiju_output.trim{wildcards.ntrim}.kaiju_out_krona.1percenttotal.summary'
filter_taxa_total_output = os.path.join(data_dir,kaiju2kronasummary_output_name)

quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']

rule filter_taxa_total:
    """
    Filter out taxa with low abundances by obtaining genera that 
    comprise at least 1 percent of the total reads:
    """
    input:
        filter_taxa_input
    output:
        filter_taxa_total_output
    shell:
        '''
        docker run \
                -v {data_dir}:/data \
                {quayurl} \
                kaijuReport \
                -v \
                -t /data/{kaiju_dir}/{kaiju_dmp} \
                -n /data/{kaiju_dir}/{kaiju_dmp2} \
                -i /data/{filter_taxa_in_name_wc} \
                -r genus \
                -m 1 \
                -o /data/{filter_taxa_total_output_name_wc}
        '''


filter_taxa_class_output_name = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona.1percentclassified.summary'
filter_taxa_class_output_name_wc = '{wildcards.base}.kaiju_output.trim{wildcards.ntrim}.kaiju_out_krona.1percentclassified.summary'
filter_taxa_class_output = os.path.join(data_dir,filter_taxa_class_output_name)

quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']

rule filter_taxa_class:
    """
    For comparison, take the genera that comprise 
    at least 1 percent of all of the classified reads
    """
    input:
        filter_taxa_input
    output:
        filter_taxa_total_output
    shell:
        '''
        docker run \
                -v {data_dir}:/data \
                {quayurl} \
                kaijuReport \
                -v \
                -t /data/{kaiju_dir}/{kaiju_dmp} \
                -n /data/{kaiju_dir}/{kaiju_dmp2} \
                -i /data/{filter_taxa_in_name_wc} \
                -r genus \
                -m 1 \
                -u \
                -o /data/{filter_taxa_class_output_name_wc}
        '''


visualize_krona_input_name = '{base}.kaiju_out.trim{ntrim}.{suffix}.summary'
visualize_krona_input_name_wc = '{wildcards.base}.kaiju_out.trim{wildcards.ntrim}.{suffix}.summary'
visualize_krona_input = [os.path.join(kaiju_dir,f) for f in visualize_krona_input_name]

visualize_krona_output_name = '{base}.kaiju_out.trim{ntrim}.{suffix}.html'
visualize_krona_output_name_wc = '{wildcards.base}.kaiju_out.trim{wildcards.ntrim}.{suffix}.html'

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
    params:
        suffixes = ['kaiju_out_krona'+x for x in ['','.1percenttotal','.1percentclassified']]
    run:
        for suffix in params.suffixes:
            shell('''
                docker run \
                        -v {data_dir}:/data \
                        {quayurl} \
                        ktImportText \
                        -o /data/{kaiju_dir}/{visualize_krona_output_name_wc} \
                        /data/{kaijudir}/{visualize_krona_input_name_wc}
                ''')


rule cleanreally:
    """
    This nukes everything - all that hard work! Be careful.
    """
    shell:
        '''
        '''


onsuccess:
    shell("rm -f .pulled_containers")

