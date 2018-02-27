import glob
from snakemake.remote.HTTP import RemoteProvider as HTTPRemoteProvider


"""
Taxonomic Classification Snakefile

This Snakefile defines tasks for the taxonomic
classification workflow.
"""


# Parameters:


# hat tip: https://github.com/dib-lab/2017-paper-gather/
HTTP = HTTPRemoteProvider()

QUAYURL = [ "quay.io/biocontainers/sourmash:2.0.0a3--py36_0",
            "quay.io/biocontainers/krona:2.7--pl5.22.0_1",
            "quay.io/biocontainers/kaiju:1.5.0--pl5.22.0_0"]

# ------8<---------------
# Get trimmed data filename and OSF URL
#
# This step should be replaced 
# with OSF CLI
# 
TRIMFNAME = []
TRIMURL = []
with open('trimmed_data.dat','r') as f:
    for ln in f.readlines():
        line = ln.split()
        TRIMFNAME.append(line[0])
        TRIMURL.append(line[1])
# -----8<----------------


# Rules:


rule pull_biocontainers:
    """
    Pull the latest version of sourmash, kaiju, and krona

    To call this rule, ask for the file .pulled_containers
    """
    output:
        touch('.pulled_containers')
    params:
        quayurl = QUAYURL
    shell:
        '''
        docker pull {params.quayurl}
        '''


rule download_sourmash_sbts:
    """
    Downoad the sourmash SBTs from spacegraphcats

    To call this rule, request sourmash SBT for the specified database.
    """
    output: 
        'data/sourmash/{database}-k{ksize}.sbt.json'
    input: 
        '.pulled_containers'
        HTTP.remote('s3-us-west-1.amazonaws.com/spacegraphcats.ucdavis.edu/microbe-{database}-sbt-k{ksize}-2017.05.09.tar.gz')
    shell: 
        '''
        tar xf {input} -C data/sourmash
        '''

rule download_trimmed_data:
    """
    Download the trimmed data from OSF

    To call this rule, request the files listed in trimmed_data.dat
    """
    output:
        TRIMFNAME
    params:
        url = TRIMURL
    shell:
        '''
        curl {params.url} -o {output}
        '''


rule calculate_signatures:
    """
    Calculate signatures from trimmed data using sourmash

    NOTE: Ugh, lots of copypasta.
    There is a mismatch between file prefixes, even thoguh file names are fine.
    Should we stuff processed inputs/outpus into parameters, processed via lambda func?
    """
    input:
        'data/{base}_1.trim{ntrim}.fq.gz', 'data/{base}_1.trim{ntrim}.fq.gz'
    output:
        'data/{base}.trim{ntrim}.scaled10k.k21_31_51.sig'
    shell:
        '''
        docker run \
                -v ${PWD}/data:/data \
                quay.io/biocontainers/sourmash:2.0.0a3--py36_0 \
                sourmash compute \
                --merge /data/{wildcards.base}.trim{wildcards.ntrim}.fq.gz \
                --track-abundance \
                --scaled 10000 \
                -k 21,31,51 \
                /data/{base}_1.trim{wildcards.ntrim}.fq.gz \
                /data/{base}_2.trim{wildcards.ntrim}.fq.gz \
                -o /data/{base}.trim{ntrim}.scaled10k.k21_31_51.sig
        '''


rule unpack_kaiju:
    """
    Download and unpack the kaiju database
    """
    output:
        'data/kaijudb/nodes.dmp',
        'data/kaijudb/kaiju_db_nr_euk.fmi'
    params:
        kaijutar='kaiju_index_nr_euk.tgz',
        kaijuurl='http://kaiju.binf.ku.dk/database'
    shell:
        '''
        mkdir -p data/kaijudb
        cd data/kaijudb
        curl -LO "{params.kaijuurl}/{params.kaijutar}"
        tar xzf {params.kaijutar}
        rm -f {params.kaijutar}
        cd ../../
        '''


rule run_kaiju:
    """
    Run kaiju
    """
    input:
        'data/kaijudb/nodes.dmp',
        'data/kaijudb/kaiju_db_nr_euk.fmi',
        'data/{base}_1.trim{ntrim}.fq.gz', 
        'data/{base}_1.trim{ntrim}.fq.gz'
    output:
        'data/{base}.kaiju_output.trim{ntrim}.out'
    shell:
        '''
        docker run \
                -v ${PWD}/data:/data \
                quay.io/biocontainers/kaiju:1.6.1--pl5.22.0_0 \
                kaiju \
                -x \
                -v \
                -t /data/kaijudb/nodes.dmp \
                -f /data/kaijudb/kaiju_db_nr_euk.fmi \
                -i /data/{base}_1.trim{ntrim}.fq.gz \
                -j /data/{base}_2.trim{ntrim}.fq.gz \
                -o /data/{base}.kaiju_output.trim{ntrim}.out \
                -z 4
        '''






rule cleanreally:
    """
    This nukes everything - all that hard work! Be careful.
    """
    shell:
        '''
        '''


onsuccess:
    shell("rm -f .pulled_containers")








