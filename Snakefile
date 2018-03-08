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

sourmash_dir = os.path.join(data_dir,'sourmash')
subprocess.call(["mkdir","-p",sourmash_dir], cwd=PWD)

download_sourmash_sbt_tar_name = "microbe-{database}-sbt-k{ksize}-2017.05.09.tar.gz"

download_sourmash_sbt_input = HTTP.remote(config['sourmash']['sbturl']+"/" + download_sourmash_sbt_tar_name)

download_sourmash_sbt_output = os.path.join(sourmash_dir, download_sourmash_sbt_tar_name)

rule download_sourmash_sbts:
    """
    Downoad the sourmash SBTs from spacegraphcats

    To call this rule, request sourmash SBT json file for the specified database.
    """
    output: 
        download_sourmash_sbt_output
    input: 
        '.pulled_containers', 
        download_sourmash_sbt_input
    shell:
        '''
        (
        cd {sourmash_dir}
        curl -O {input[1]}
        )
        '''


unpack_sourmash_sbt_tar_name = download_sourmash_sbt_tar_name

unpack_sourmash_sbt_tar_name = "microbe-{database}-sbt-k{ksize}-2017.05.09.tar.gz"
unpack_sourmash_sbt_tar = os.path.join(sourmash_dir, unpack_sourmash_sbt_tar_name)

unpack_sourmash_sbt_input = os.path.join(sourmash_dir, unpack_sourmash_sbt_tar_name)

unpack_sourmash_sbt_output = os.path.join(sourmash_dir,'{database}-k{ksize}.sbt.json')

rule unpack_sourmash_sbts:
    """
    Unpack the sourmash SBTs
    """
    input:
        unpack_sourmash_sbt_input
    output:
        unpack_sourmash_sbt_output
    params:
        stupid = '10'
    run:
        unpack_sourmash_sbt_tar_wc = unpack_sourmash_sbt_tar.format(**wildcards)
        shell('''
            (
            cd {sourmash_dir}
            tar xzf {unpack_sourmash_sbt_tar_wc} && rm -f {unpack_sourmash_sbt_tar_wc}
            )
        ''')


# -----------------8<-----------------------


trimmed_dir = os.path.join(data_dir,'trimmed')
subprocess.call(["mkdir","-p",trimmed_dir], cwd=PWD)

# Get trimmed data filename and OSF URL
# NOTE: this step should be replaced with OSF CLI
trimmed_data_fnames = []
trimmed_data_urls = []
with open('inputs/trimmed_data.dat','r') as f:
    for ln in f.readlines():
        line = ln.split()
        if(len(line)>0):
            trimmed_data_fnames.append(line[0])
            trimmed_data_urls.append(line[1])

trimmed_data_files = [os.path.join(trimmed_dir,x) for x in trimmed_data_fnames]

rule download_trimmed_data:
    """
    Download the trimmed data from OSF

    To call this rule, request the files listed in trimmed_data.dat
    """
    output:
        touch('.trimmed')
    run:
        for (osf_file,osf_url) in zip(trimmed_data_files,trimmed_data_urls):
            if(not os.path.isfile(osf_file)):
                shell('''
                    wget -O {osf_file} {osf_url}
                ''')




fq_fwd = '{base}_1.trim{ntrim}.fq.gz' 
fq_rev = '{base}_2.trim{ntrim}.fq.gz'

fq_names = [fq_fwd, fq_rev]
sig_name =  '{base}.trim{ntrim}.scaled10k.k21_31_51.sig'

merge_file = "{base}_merged.trim{ntrim}.fq.gz"

sig_inputs = [os.path.join(trimmed_dir,fq) for fq in fq_names]
sig_output = os.path.join(trimmed_dir,sig_name)
merge_output = os.path.join(trimmed_dir,merge_file)

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
                    -v {PWD}/{trimmed_dir}:/data \
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



kaiju_dirname = 'kaijudb'
kaiju_dir = os.path.join(data_dir,kaiju_dirname)
kaiju_dmp = 'nodes.dmp'
kaiju_dmp2 = 'names.dmp'
kaiju_fmi = 'kaiju_db_nr_euk.fmi'
kaiju_tar = 'kaiju_index_nr_euk.tgz'
kaiju_url = 'http://kaiju.binf.ku.dk/database'

kaiju_output_names = [kaiju_dmp, kaiju_dmp2, kaiju_fmi]
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


# -----------------8<-----------------------


kaiju_input_names = [kaiju_dmp, kaiju_fmi]
run_kaiju_input = [os.path.join(kaiju_dir,f) for f in kaiju_input_names]
run_kaiju_input += [os.path.join(trimmed_dir,f) for f in fq_names]

kaiju_output_name = '{base}.kaiju_output.trim{ntrim}.out'
run_kaiju_output = os.path.join(kaiju_dir,kaiju_output_name)

quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']

rule run_kaiju:
    """
    Run kaiju
    """
    #input:
    #    run_kaiju_input
    output:
        run_kaiju_output
    run:
        fq_fwd_wc = fq_fwd.format(**wildcards)
        fq_rev_wc = fq_rev.format(**wildcards)
        kaiju_output_name_wc = kaiju_output_name.format(**wildcards)
        shell('''
            docker run \
                    -v {PWD}/{data_dir}:/data \
                    {quayurl} \
                    kaiju \
                    -x \
                    -v \
                    -t /{kaiju_dir}/{kaiju_dmp} \
                    -f /{kaiju_dir}/{kaiju_fmi} \
                    -i /{trimmed_dir}/{fq_fwd_wc} \
                    -j /{trimmed_dir}/{fq_rev_wc} \
                    -o /{kaiju_dir}/{kaiju_output_name_wc} \
                    -z 4
        ''')


# -----------------8<-----------------------


krona_dir = os.path.join(data_dir,'krona')
subprocess.call(["mkdir","-p",krona_dir], cwd=PWD)

kaiju2krona_input_names = [kaiju_dmp, kaiju_dmp2, kaiju_output_name]
kaiju2krona_input = [os.path.join(kaiju_dir,f) for f in kaiju2krona_input_names]

kaiju2krona_output_name = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona'
kaiju2krona_output = os.path.join(krona_dir,kaiju2krona_output_name)

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
        kaiju2krona_in_name_wc = kaiju_output_name.format(**wildcards)
        kaiju2krona_output_name_wc = kaiju2krona_output_name.format(**wildcards)
        shell('''
            docker run \
                    -v {PWD}/{data_dir}:/data \
                    {quayurl} \
                    kaiju2krona \
                    -v \
                    -t /{kaiju_dir}/{kaiju_dmp} \
                    -n /{kaiju_dir}/{kaiju_dmp2} \
                    -i /{kaiju_dir}/{kaiju2krona_in_name_wc} \
                    -o /{krona_dir}/{kaiju2krona_output_name_wc}
        ''')


# -----------------8<-----------------------


kaiju2kronasummary_input_names = [kaiju_dmp, kaiju_dmp2, kaiju_output_name]
kaiju2kronasummary_input = [os.path.join(kaiju_dir,f) for f in kaiju2kronasummary_input_names]

kaiju2kronasummary_output_name = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona.summary'
kaiju2kronasummary_output = os.path.join(krona_dir,kaiju2kronasummary_output_name)

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
        kaiju2kronasummary_in_name_wc = kaiju_output_name.format(**wildcards)
        kaiju2kronasummary_output_name_wc = kaiju2kronasummary_output_name.format(**wildcards)
        shell('''
            docker run \
                    -v {PWD}/{data_dir}:/data \
                    {quayurl} \
                    kaijuReport \
                    -v \
                    -t /{kaiju_dir}/{kaiju_dmp} \
                    -n /{kaiju_dir}/{kaiju_dmp2} \
                    -i /{kaiju_dir}/{kaiju2kronasummary_in_name_wc} \
                    -r genus \
                    -o /{kaiju_dir}/{kaiju2kronasummary_output_name_wc}
        ''')


# -----------------8<-----------------------


### filter_taxa_input_names = [kaiju_dmp, kaiju_dmp2, run_kaiju_output]
### filter_taxa_input = [os.path.join(kaiju_dir,f) for f in filter_taxa_input_names]
### 
### filter_taxa_in_name_wc = kaiju_output_name_wc # just the -i in file
### 
### filter_taxa_total_output_name = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona.1percenttotal.summary'
### filter_taxa_total_output_name_wc = '{wildcards.base}.kaiju_output.trim{wildcards.ntrim}.kaiju_out_krona.1percenttotal.summary'
### filter_taxa_total_output = os.path.join(data_dir,kaiju2kronasummary_output_name)
### 
### quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']
### 
### rule filter_taxa_total:
###     """
###     Filter out taxa with low abundances by obtaining genera that 
###     comprise at least 1 percent of the total reads:
###     """
###     input:
###         filter_taxa_input
###     output:
###         filter_taxa_total_output
###     shell:
###         '''
###         docker run \
###                 -v {data_dir}:/data \
###                 {quayurl} \
###                 kaijuReport \
###                 -v \
###                 -t /data/{kaiju_dir}/{kaiju_dmp} \
###                 -n /data/{kaiju_dir}/{kaiju_dmp2} \
###                 -i /data/{filter_taxa_in_name_wc} \
###                 -r genus \
###                 -m 1 \
###                 -o /data/{filter_taxa_total_output_name_wc}
###         '''
### 
### 
### # -----------------8<-----------------------
### 
### 
### filter_taxa_class_output_name = '{base}.kaiju_output.trim{ntrim}.kaiju_out_krona.1percentclassified.summary'
### filter_taxa_class_output_name_wc = '{wildcards.base}.kaiju_output.trim{wildcards.ntrim}.kaiju_out_krona.1percentclassified.summary'
### filter_taxa_class_output = os.path.join(data_dir,filter_taxa_class_output_name)
### 
### quayurl = config['kaiju']['quayurl'] + ":" + config['kaiju']['version']
### 
### rule filter_taxa_class:
###     """
###     For comparison, take the genera that comprise 
###     at least 1 percent of all of the classified reads
###     """
###     input:
###         filter_taxa_input
###     output:
###         filter_taxa_total_output
###     shell:
###         '''
###         docker run \
###                 -v {data_dir}:/data \
###                 {quayurl} \
###                 kaijuReport \
###                 -v \
###                 -t /data/{kaiju_dir}/{kaiju_dmp} \
###                 -n /data/{kaiju_dir}/{kaiju_dmp2} \
###                 -i /data/{filter_taxa_in_name_wc} \
###                 -r genus \
###                 -m 1 \
###                 -u \
###                 -o /data/{filter_taxa_class_output_name_wc}
###         '''
### 
### 
### # -----------------8<-----------------------
### 
### 
### visualize_krona_input_name = '{base}.kaiju_out.trim{ntrim}.{suffix}.summary'
### visualize_krona_input_name_wc = '{wildcards.base}.kaiju_out.trim{wildcards.ntrim}.{suffix}.summary'
### visualize_krona_input = [os.path.join(kaiju_dir,f) for f in visualize_krona_input_name]
### 
### visualize_krona_output_name = '{base}.kaiju_out.trim{ntrim}.{suffix}.html'
### visualize_krona_output_name_wc = '{wildcards.base}.kaiju_out.trim{wildcards.ntrim}.{suffix}.html'
### visualize_krona_output = os.path.join(data_dir,visualize_krona_output_name)
### 
### quayurl = config['krona']['quayurl'] + ":" + config['krona']['version']
### 
### rule visualize_krona:
###     """
###     Visualize the results of the 
###     full and filtered taxonomic 
###     classifications using krona.
###     """
###     input:
###         visualize_krona_input
###     output:
###         visualize_krona_output
###     params:
###         suffixes = ['kaiju_out_krona'+x for x in ['','.1percenttotal','.1percentclassified']]
###     run:
###         for suffix in params.suffixes:
###             shell('''
###                 docker run \
###                         -v {data_dir}:/data \
###                         {quayurl} \
###                         ktImportText \
###                         -o /data/{kaiju_dir}/{visualize_krona_output_name_wc} \
###                         /data/{kaijudir}/{visualize_krona_input_name_wc}
###                 ''')
### 
### 
### # -----------------8<-----------------------
### 
### 
### rule cleanreally:
###     """
###     This nukes everything - all that hard work! Be careful.
###     """
###     shell:
###         '''
###         '''
### 
### ## NOTE: Add this back in once we're finished testing.
### #onsuccess:
### #    shell("rm -f .pulled_containers")
### #    shell("rm -f .trimmed")
### 
