import glob
import os
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider


"""
Taxonomic Classification Snakefile

This Snakefile defines tasks for the taxonomic
classification workflow.

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


# Settings for this particular run
include: '2018-03-01.settings'

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
                -t /data/{kaiju_dir}/nodes.dmp \
                -f /data/{kaiju_dir}/kaiju_db_nr_euk.fmi \
                -i /data/{fq_fwd_wc} \
                -j /data/{fq_rev_wc} \
                -o /data/{kaiju_output_name_wc} \
                -z 4
        '''


# --

k2k_in = data_dir,kaiju_dir,

rule kaiju2krona:
    """
    Convert kaiju results to krona results,
    and generate a report.
    """
    input:
        'data/kaiju/{prefix}.trim2.out'
    output:
        'data/krona/{prefix}.kaiju.out.krona'
    params:
        kaijuurl="quay.io/iocontainers/kaiju:1.6.1--pl5.22.0_0"
        kaijudir="kaijudb"
    shell:
        '''
        docker run \
            -v {data_dir}:/data \
            {kaijuurl} \
            kaiju2krona \
            -v \
            -t /data/{kaiju_dir}/nodes.dmp \
            -n /data/{kaiju_dir}/names.dmp \
            -i /data/${i} \
            -o /data/${i}.kaiju.out.krona
        '''






rule filter_taxa:



rule cleanreally:
    """
    This nukes everything - all that hard work! Be careful.
    """
    shell:
        '''
        '''


onsuccess:
    shell("rm -f .pulled_containers")









